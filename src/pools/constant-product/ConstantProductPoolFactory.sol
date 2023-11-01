// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "contracts/pools/constant-product/ConstantProductLibrary.sol";
import "../Satellite.sol";

contract ConstantProductPoolFactory is Satellite {
    event PoolCreated(ConstantProductPool indexed pool, Token t1, Token t2);

    using TokenLib for Token;
    using UncheckedMemory for Token[];
    using UncheckedMemory for uint256[];

    ConstantProductLibrary immutable lib;
    uint32 fee1e9;
    uint32 decay = 4294955811;

    ConstantProductPool[] public poolList;
    mapping(Token => mapping(Token => ConstantProductPool)) public pools;
    mapping(ConstantProductPool => bool) public isPool;

    event FeeChanged(uint256 fee1e18);
    event DecayChanged(uint256 decay);

    function setFee(uint32 fee1e9_) external authenticate {
        fee1e9 = fee1e9_;
        require(fee1e9 <= 0.1e9);
        emit FeeChanged(fee1e9 * uint256(1e8));
    }

    function setDecay(uint32 decay_) external authenticate {
        decay = decay_;
        emit DecayChanged(decay_);
    }

    function getPools(uint256 begin, uint256 maxLength) external view returns (ConstantProductPool[] memory pools) {
        uint256 len = poolList.length <= begin ? 0 : Math.min(poolList.length - begin, maxLength);
        pools = new ConstantProductPool[](len);
        unchecked {
            for (uint256 i = begin; i < begin + len; i++) {
                pools[i] = poolList[i];
            }
        }
    }

    function poolsLength() external view returns (uint256) {
        return poolList.length;
    }

    constructor(IVault vault_, ConstantProductLibrary lib_) Satellite(vault_, address(this)) {
        lib = lib_;
    }

    function deploy(Token quoteToken, Token baseToken) external returns (ConstantProductPool) {
        Token[] memory tokens = new Token[](2);
        require(!(baseToken == quoteToken));
        require(address(pools[quoteToken][baseToken]) == address(0));
        if (quoteToken < baseToken) {
            tokens.u(0, quoteToken);
            tokens.u(1, baseToken);
        } else {
            tokens.u(0, baseToken);
            tokens.u(1, quoteToken);
        }

        uint256[] memory weights = new uint256[](2);
        weights.u(0, 1);
        weights.u(1, 1);

        ConstantProductPool ret = new ConstantProductPool(
            lib,
            vault,
            string(abi.encodePacked("Velocore LP: ", tokens.u(0).symbol(), " + ", tokens.u(1).symbol())),
            string(abi.encodePacked(tokens.u(0).symbol(), "-", tokens.u(1).symbol(), "-VLP")),
            tokens,
            weights,
            fee1e9,
            decay
        );

        poolList.push(ret);
        isPool[ret] = true;
        pools[baseToken][quoteToken] = ret;
        pools[quoteToken][baseToken] = ret;
        emit PoolCreated(ret, quoteToken, baseToken);
        return ret;
    }
}
