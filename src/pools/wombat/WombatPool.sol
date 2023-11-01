// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {SD59x18, sd, exp2, log2, convert, pow} from "@prb/math/src/SD59x18.sol";
import "contracts/lib/Token.sol";
import "contracts/lib/UncheckedMemory.sol";
import "contracts/lib/PoolBalanceLib.sol";
import {rpow} from "contracts/lib/RPow.sol";

import "contracts/pools/SingleTokenGauge.sol";

struct TokenInfo {
    uint8 indexPlus1;
    uint8 scale;
    IGauge gauge;
}

contract WombatPool is ISwap, IBribe, Pool, ERC1155 {
    using Strings for address;
    using Strings for uint256;
    using UncheckedMemory for uint256[];
    using UncheckedMemory for int128[];
    using UncheckedMemory for Token[];
    using SafeCast for int256;
    using SafeCast for uint256;
    using TokenLib for Token;

    event FeeChanged(uint256 fee1e18);
    event DecayChanged(uint256 decay);

    uint96 public fee1e18;
    uint96 public decayRate = 79227950644264186636284806541;
    Token[] public tokenList;
    mapping(Token => TokenInfo) public tokenInfo;

    int256 immutable amp;
    int256 immutable cAmp;

    function setFee(uint96 fee1e18_) external authenticate {
        require(fee1e18_ <= 0.1e18);
        fee1e18 = fee1e18_;
        emit FeeChanged(fee1e18);
    }

    function setDecayRate(uint96 decayRate_) external authenticate {
        decayRate = decayRate_;
        emit DecayChanged(decayRate);
    }

    constructor(address factory, IVault vault_, uint96 fee1e18_, int256 amp_)
        Pool(vault_, address(this), factory)
        ERC1155(
            string(
                abi.encodePacked(
                    "https://static.velocore.xyz/metadata/",
                    block.chainid.toString(),
                    "/",
                    address(this).toHexString(),
                    "/{id}.json"
                )
            )
        )
    {
        fee1e18 = fee1e18_;
        amp = amp_;
        cAmp = 1e18 - amp;
        emit FeeChanged(fee1e18);
        emit DecayChanged(decayRate);
    }

    function addToken(Token t, uint8 decimal) external authenticate {
        require(tokenInfo[t].indexPlus1 == 0, "already added");
        uint8 index = tokenList.length.toUint8();
        tokenList.push(t);
        tokenInfo[t].indexPlus1 = index + 1;
        tokenInfo[t].scale = 18 - (decimal == 255 ? t.decimals() : decimal);
        _mint(address(vault), index, type(uint128).max, "");
        vault.notifyInitialSupply(lpToken(index), 0, type(uint128).max);

        tokenInfo[t].gauge = new SingleTokenGauge(vault, lpToken(index), this);
    }

    function lpToken(uint88 i) internal view returns (Token) {
        return toToken(TokenSpec.ERC1155, i, address(this));
    }

    function lpToken(Token t) internal view returns (Token) {
        return toToken(TokenSpec.ERC1155, tokenInfo[t].indexPlus1 - 1, address(this));
    }

    function velocore__execute(address, Token[] calldata t, int128[] memory r, bytes calldata data)
        external
        returns (int128[] memory deltaGauge, int128[] memory deltaPool)
    {
        require(t.length == 2, "unsupported operation");
        uint256 iu = r.u(0) == type(int128).max ? 0 : 1;
        uint256 ik = iu == 0 ? 1 : 0;

        require(r.u(iu) == type(int128).max && r.u(ik) != type(int128).max, "no unknowns or knowns");

        bool isKnownTokenLP = t.u(ik).addr() == address(this);
        bool isUnknownTokenLP = t.u(iu).addr() == address(this);

        require(!isUnknownTokenLP || !isKnownTokenLP, "can't swap between LP tokens");

        deltaPool = new int128[](2);
        deltaGauge = new int128[](2);
        if (!isUnknownTokenLP && !isKnownTokenLP) {
            if (r.u(ik) < 0) {
                int128 plusFee = ((r.u(ik) * int256(1e18)) / (1e18 - int96((fee1e18)))).toInt128();
                deltaPool.u(iu, _swap(t.u(ik), t.u(iu), plusFee));
                deltaGauge.u(ik, r.u(ik) - plusFee);
                deltaPool.u(ik, plusFee);
            } else {
                deltaPool.u(ik, r.u(ik));
                deltaPool.u(iu, _swap(t.u(ik), t.u(iu), r.u(ik)));
                deltaGauge.u(iu, -int128((int256(deltaPool.u(iu)) * int96(fee1e18)) / 1e18));
            }
        } else if (isUnknownTokenLP) {
            require(tokenInfo[t.u(ik)].indexPlus1 == t.u(iu).id() + 1, "wrong lp token");
            deltaPool.u(ik, r.u(ik));
            deltaPool.u(iu, -_deposit(t.u(ik), r.u(ik)));
        } else if (isKnownTokenLP) {
            require(tokenInfo[t.u(iu)].indexPlus1 == t.u(ik).id() + 1, "wrong lp token");
            deltaPool[ik] = r.u(ik);
            deltaPool[iu] = _withdraw(t.u(iu), -r.u(ik));
        } else {
            revert("unsupported operation");
        }
    }

    function partial_invariant(int256 a, int256 l) internal returns (int256) {
        if (a == 0) {
            require(l == 0);
            return 0;
        }
        return a - (((l * amp) / 1e18) * l) / a;
    }

    function tokenStat_scaled(Token t) internal returns (int256, int256, int256) {
        uint256 scale = 10 ** tokenInfo[t].scale;
        int256 l = int256(uint256(type(uint128).max - _getPoolBalance(lpToken(t))) * scale);
        int256 a = int256(uint256(_getPoolBalance(t) * scale));
        return (a, l, partial_invariant(a, l));
    }

    function upscale(Token t, int128 x) internal returns (int256) {
        unchecked {
            return int256(x) * int256(10 ** tokenInfo[t].scale);
        }
    }

    function downscale(Token t, int256 x) internal returns (int128) {
        unchecked {
            return (x / int256(10 ** tokenInfo[t].scale)).toInt128();
        }
    }

    function _swap(Token k, Token u, int128 dAk) internal returns (int128 dAu) {
        (int256 Au, int256 Lu, int256 Du) = tokenStat_scaled(u);

        int256 newAu;
        {
            (int256 Ak, int256 Lk, int256 Dk) = tokenStat_scaled(k);
            int256 newDk = partial_invariant(Ak + upscale(k, dAk), Lk);

            int256 newDu = Dk + Du - newDk;
            int256 _4ac;
            unchecked {
                _4ac = ((4 * amp * Lu) / 1e18) * Lu;
            }
            newAu = (newDu + int256(Math.sqrt((newDu * newDu + _4ac).toUint256(), Math.Rounding.Up)) + 1) / 2;
        }
        return downscale(u, (newAu - Au));
    }

    function _withdraw(Token t, int128 dL) internal returns (int128 dA) {
        (int256 A, int256 L, int256 D) = tokenStat_scaled(t);
        int256 sdL = upscale(t, dL);
        int256 newL = L + sdL;
        int256 dD;
        unchecked {
            dD = ((sdL * cAmp) / 1e18);
        }
        int256 newD = D + dD;

        int256 b = newD / 2;
        return downscale(
            t, -A + b + int256(Math.sqrt((b * b + (((newL * amp) / 1e18) * newL)).toUint256(), Math.Rounding.Up))
        );
    }

    function _deposit(Token t, int128 dA) internal returns (int128 dL) {
        (int256 A, int256 L, int256 D) = tokenStat_scaled(t);
        int256 newA = A + upscale(t, dA);

        int256 LA;
        int256 b;
        unchecked {
            LA = (L * amp) / 1e18;
            b = ((newA * cAmp) / 1e18) + (2 * LA);
        }
        int256 _4ac = (4 * amp * (newA * (D - newA) + (L * LA))) / 1e18;
        return downscale(t, (int256(Math.sqrt((b * b - _4ac).toUint256())) - b) * 1e18 / (2 * amp));
    }

    function listedTokens() external view override returns (Token[] memory) {
        return tokenList;
    }

    function swapType() external view override returns (string memory) {
        return "wombat";
    }

    function lpTokens() external view override returns (Token[] memory) {
        Token[] memory ret = new Token[](tokenList.length);
        for (uint88 i = 0; i < tokenList.length; i++) {
            ret[i] = lpToken(i);
        }
        return ret;
    }

    function poolParams() external view override(IPool, Pool) returns (bytes memory) {
        return abi.encode(fee1e18, amp);
    }

    function velocore__bribe(IGauge gauge, uint256 elapsed)
        external
        override
        onlyVault
        returns (
            Token[] memory bribeTokens,
            int128[] memory deltaGauge,
            int128[] memory deltaPool,
            int128[] memory deltaExternal
        )
    {
        Token underlying = tokenList[gauge.stakeableTokens()[0].id()];
        require(tokenInfo[underlying].gauge == gauge, "wrong gauge");

        uint256 decay = 2 ** 96 - rpow(decayRate, elapsed, 2 ** 96);
        uint256 decayed = (_getGaugeBalance(underlying) * decay) / 2 ** 96;

        bribeTokens = new Token[](1);
        bribeTokens[0] = underlying;
        deltaGauge = new int128[](1);
        deltaPool = new int128[](1);
        deltaExternal = new int128[](1);

        deltaGauge.u(0, -int128(int256(decayed)));
    }

    function bribeTokens(IGauge gauge) external view override returns (Token[] memory bribeTokens) {
        Token underlying = tokenList[gauge.stakeableTokens()[0].id()];
        require(tokenInfo[underlying].gauge == gauge, "wrong gauge");

        bribeTokens = new Token[](1);
        bribeTokens[0] = underlying;
    }

    function underlyingTokens(Token tok) external view returns (Token[] memory) {
        require(tok == lpToken(tokenList[tok.id()]));
        Token underlying = tokenList[tok.id()];

        Token[] memory ret = new Token[](1);
        ret[0] = underlying;
        return ret;
    }

    function bribeRates(IGauge gauge) external view override returns (uint256[] memory ret) {
        Token underlying = tokenList[gauge.stakeableTokens()[0].id()];
        require(tokenInfo[underlying].gauge == gauge, "wrong gauge");

        ret = new uint256[](1);
        ret[0] = _getGaugeBalance(underlying) * (2 ** 96 - uint256(decayRate)) / 2 ** 96;
    }

    function totalSupply(uint256 i) external view returns (uint256) {
        return type(uint128).max - _getPoolBalance(lpToken(i.toUint88()));
    }

    function tokenListLength() external view returns (uint256) {
        return tokenList.length;
    }

    function getTokenList() external view returns (Token[] memory ret) {
        ret = new Token[](tokenList.length);
        for (uint256 i = 0; i < ret.length; i++) {
            ret[i] = tokenList[i];
        }
    }

    function gauges(Token t) external view returns (IGauge) {
        return tokenInfo[t].gauge;
    }

    function setFeeToZero() external onlyVault {
        fee1e18 = 0;
    }
}
