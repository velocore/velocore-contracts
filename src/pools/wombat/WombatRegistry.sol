import "../Satellite.sol";
import "./WombatPool.sol";
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

contract WombatRegistry is Satellite {
    WombatPool[] pools;

    function register(WombatPool pool) external authenticate {
        pools.push(pool);
    }

    function getPools() external view returns (WombatPool[] memory) {
        return pools;
    }

    constructor(IVault vault) Satellite(vault, address(this)) {}
}
