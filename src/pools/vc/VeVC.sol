// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "contracts/interfaces/IVC.sol";
import "contracts/lib/RPow.sol";
import "contracts/pools/PoolWithLPToken.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../SatelliteUpgradeable.sol";

interface IVotingEscrow {
    struct LockedBalance {
        int128 amount;
        uint256 end;
    }

    function locked(uint256) external view returns (LockedBalance memory);
}

contract VeVC is PoolWithLPToken, ISwap, SatelliteUpgradeable {
    event MigratedNFT(uint256 indexed id, address indexed user, uint256 amount);
    event Lock(address indexed user, uint256 indexed amount);

    using UncheckedMemory for int128[];
    using TokenLib for Token;
    using SafeCast for uint256;
    using SafeCast for int256;

    IVotingEscrow immutable oldVeVC;
    IVC immutable vc;
    bool initialized;

    constructor(address selfAddr, IVault vault_, IVotingEscrow oldVeVC_, IVC vc_)
        Pool(vault_, selfAddr, address(this))
    {
        oldVeVC = oldVeVC_;
        vc = vc_;
    }

    function initialize() external {
        if (!initialized) {
            PoolWithLPToken._initialize("Locked VC", "veVC");
            initialized = true;
        }
    }

    function isValid(uint256 id) internal pure returns (bool) {
        if (id > 739) return true;
        if (id == 401 || id == 695 || id == 781 || id == 634 || id == 739) return false;
        if (id >= 330 && id <= 348) return (id != 330 && id != 331 && id != 343 && id != 345 && id != 348);
        if (id <= 13) return (id != 3 && id != 11 && id != 13);

        return true;
    }

    function velocore__execute(address user, Token[] calldata tokens, int128[] memory r, bytes calldata)
        external
        override
        onlyVault
        returns (int128[] memory, int128[] memory)
    {
        uint256 iVeVC = _binarySearch(tokens, toToken(this));
        uint256 iVC = _binarySearch(tokens, toToken(IERC20(address(vc))));
        int128[] memory deltaPool = new int128[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            if (i == iVeVC) {
                continue;
            } else if (i == iVC) {
                require(r[i] >= 0, "VC cannot be withdrawn");
                deltaPool[iVC] += r.u(i);
                deltaPool[iVeVC] -= r.u(i);
                emit Lock(user, uint256(int256(r.u(i))));
                _simulateMint(uint256(int256(r.u(i))));
            } else {
                Token t = tokens[i];

                require(r[i] == 1, "wrong amount");
                require(t.addr() == address(oldVeVC), "unsupported token");
                require(t.spec() == TokenSpec.ERC721, "unsupported token");
                require(isValid(t.id()), "please contact us");
                int128 amt = oldVeVC.locked(t.id()).amount;
                require(amt >= 0, "negative veNFT");
                deltaPool[i] += 1;
                deltaPool[iVeVC] -= amt;
                vc.notifyMigration(int256(amt).toUint256().toUint128());
                _simulateMint(uint256(int256(amt)));
                emit MigratedNFT(t.id(), user, uint256(int256(amt)));
            }
        }
        return (new int128[](tokens.length), deltaPool);
    }

    function swapType() external view override returns (string memory) {
        return "veVC";
    }

    function listedTokens() external view override returns (Token[] memory ret) {
        ret = new Token[](2);
        ret[0] = toToken(vc);
        ret[1] = Token.wrap(TokenSpecType.unwrap(TokenSpec.ERC721) | bytes32(uint256(uint160(address(oldVeVC)))));
    }

    function lpTokens() external view override returns (Token[] memory ret) {
        ret = new Token[](1);
        ret[0] = toToken(this);
    }

    function underlyingTokens(Token lp) external view override returns (Token[] memory) {
        return new Token[](0);
    }
}
