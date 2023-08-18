// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "src/lib/Token.sol";
import "src/lib/PoolBalanceLib.sol";
import "src/interfaces/IPool.sol";
import "src/interfaces/ISwap.sol";
import "src/interfaces/IConverter.sol";
import "src/interfaces/IVC.sol";
import "src/interfaces/IVault.sol";
import "src/interfaces/IFacet.sol";
import "src/interfaces/IFactory.sol";
import "src/VaultStorage.sol";
import "src/pools/constant-product/ConstantProductPoolFactory.sol";
import "src/pools/wombat/WombatRegistry.sol";
import "src/lens/VelocoreLens.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";

uint256 constant GAUGE_FLAG_KILLED = 1;

/**
 * @dev a Facet for handling swap, stake and vote logic.
 *
 *
 * please refer to the tech docs below for its intended behavior.
 * https://velocore.gitbook.io/velocore-v2/technical-docs/exchanging-tokens-with-vault
 *
 *
 */

contract BeaconFacet is VaultStorage, IFacet {
    ConstantProductPoolFactory immutable factory__;
    WombatRegistry immutable wombatRegistry__;
    VelocoreLens immutable lens__;

    address immutable thisImplementation;

    constructor(ConstantProductPoolFactory factory_, WombatRegistry wombatRegistry_, VelocoreLens lens_) {
        factory__ = factory_;
        wombatRegistry__ = wombatRegistry_;
        lens__ = lens_;
        thisImplementation = address(this);
    }
    /**
     * @dev called by AdminFacet.admin_addFacet().
     * doesnt get added to the routing table, hence the lack of access control.
     */

    function initializeFacet() external {
        _setFunction(BeaconFacet.factory.selector, thisImplementation);
    }

    function wombatRegistry() external view returns (WombatRegistry) {
        return wombatRegistry__;
    }

    function lens() external view returns (VelocoreLens) {
        return lens__;
    }

    function factory() external view returns (ConstantProductPoolFactory) {
        return factory__;
    }
}
