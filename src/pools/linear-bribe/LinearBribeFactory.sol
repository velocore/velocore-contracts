// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/interfaces/IBribe.sol";
import "contracts/interfaces/IVault.sol";
import "contracts/lib/Token.sol";
import "contracts/lib/UncheckedMemory.sol";
import "contracts/lib/PoolBalanceLib.sol";
import "contracts/pools/Pool.sol";
import "./LinearBribe.sol";

contract LinearBribeFactory is Pool, ISwap {
    using UncheckedMemory for uint256[];
    using UncheckedMemory for int128[];
    using UncheckedMemory for Token[];
    using SafeCast for int256;
    using SafeCast for uint256;
    using TokenLib for Token;

    event BribeCreated(Token indexed t, LinearBribe indexed b);

    mapping(Token => IBribe) public bribes;
    Token feeToken;
    int128 feeAmount;
    address treasury;

    function setFeeAmount(int128 feeAmount_) external authenticate {
        feeAmount = feeAmount_;
    }

    function setFeeToken(Token feeToken_) external authenticate {
        feeToken = feeToken_;
    }

    function setTreasury(address treasury_) external authenticate {
        treasury = treasury_;
    }

    function contains(Token[] memory ts, Token t) internal returns (bool) {
        for (uint256 i = 0; i < ts.length; i++) {
            if (ts[i] == t) return true;
        }
        return false;
    }

    function velocore__execute(address user, Token[] calldata tokens, int128[] memory r, bytes calldata data)
        external
        onlyVault
        returns (int128[] memory, int128[] memory)
    {
        (IGauge gauge, Token bribeToken) = abi.decode(data, (IGauge, Token));

        if (user == treasury && address(gauge) == address(0)) {
            return (new int128[](tokens.length), r);
        }
        if (address(bribes[bribeToken]) == address(0)) {
            _deployBribe(bribeToken);
        }
        vault.attachBribe(gauge, bribes[bribeToken]);

        if (contains(gauge.naturalBribes(), bribeToken)) {
            return (new int128[](tokens.length), new int128[](tokens.length));
        } else {
            require((tokens.length == 1 && tokens[0] == feeToken));
            r.u(0, feeAmount);
            return (new int128[](1), r);
        }
    }

    constructor(IVault vault_) Pool(vault_, address(this), address(this)) {}

    function _deployBribe(Token bribeToken) internal {
        require(address(bribes[bribeToken]) == address(0), "bribe already deployed");
        bribes[bribeToken] = new LinearBribe(vault, bribeToken);
        emit BribeCreated(bribeToken, LinearBribe(address(bribes[bribeToken])));
    }

    function listedTokens() public view override returns (Token[] memory) {
        Token[] memory ret = new Token[](1);
        ret[0] = feeToken;
        return ret;
    }

    function swapType() external view override returns (string memory) {
        return "linear-bribe-factory";
    }

    function lpTokens() public view override returns (Token[] memory ret) {
        return new Token[](0);
    }

    function poolParams() external view override(IPool, Pool) returns (bytes memory) {
        return "";
    }

    function underlyingTokens(Token tok) external view returns (Token[] memory) {
        return new Token[](0);
    }
}
