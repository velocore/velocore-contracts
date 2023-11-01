// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "contracts/lib/Token.sol";
import "contracts/lib/PoolBalanceLib.sol";
import "contracts/interfaces/IAuthorizer.sol";
import "contracts/interfaces/IVC.sol";
import "contracts/interfaces/IFacet.sol";
import "contracts/VaultStorage.sol";
import "./Diamond.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @dev a Facet for administrative and deployment logic.
 *
 * Diamond.yul does not contrain functions for modifying the routing table.
 * this facet is special because it deploys Diamond.yul and bootstraps such functions.
 * the flow of bootstrapping is:
 *                   AdminFacet.deploy()
 *       --create--> Diamond.yul constructor
 * --delegatecall--> AdminFacet.fallback()
 * --delegatecall--> AdminFacet.initializeFacet()
 */

contract AdminFacet is VaultStorage, IFacet {
    event AuthorizerChanged(IAuthorizer indexed authorizer);
    event TreasuryChanged(address indexed addr);

    address immutable deployer;
    IAuthorizer immutable initialAuth;
    address immutable thisImplementation;

    constructor(IAuthorizer auth_, address deployer_) {
        deployer = deployer_;
        initialAuth = auth_;
        thisImplementation = address(this);
    }

    /**
     * @dev deploy any bytecode given. used to deploy Diamond.yul
     *
     * @param bytecode expected to be compiled Diamond.yul bytecode.
     *
     */
    function deploy(bytes memory bytecode) external returns (address) {
        require(msg.sender == deployer);
        address deployed;
        assembly ("memory-safe") {
            deployed := create(0, add(bytecode, 32), mload(bytecode)) // Diamond.yul constructor will delegatecall msg.sender.fallback(). see fallback() below.
        }
        require(deployed != address(0));
        return deployed;
    }

    function deploy_zksync() external returns (address) {
        require(msg.sender == deployer);
        address deployed = address(new Diamond());
        require(deployed != address(0));
        return deployed;
    }

    /**
     * to be called by Diamond.yul constructor.
     *
     * delegatecalls this.initializeFacet()
     */
    fallback() external {
        require(address(this) != address(thisImplementation));
        bytes memory data = abi.encodeWithSelector(IFacet.initializeFacet.selector);
        address this_ = thisImplementation;
        assembly ("memory-safe") {
            let success := delegatecall(gas(), this_, add(data, 32), mload(data), 0, 0)
            if iszero(success) { revert(0, 0) }
        }
    }

    /**
     * initializeFacet() is called only once by IVault.admin_addFacet().
     * but in this case, it will be
     */
    function initializeFacet() external {
        if (StorageSlot.getAddressSlot(SSLOT_HYPERCORE_AUTHORIZER).value == address(0)) {
            StorageSlot.getAddressSlot(SSLOT_HYPERCORE_AUTHORIZER).value = address(initialAuth);
            emit AuthorizerChanged(initialAuth);
        }
        _setFunction(AdminFacet.admin_setFunctions.selector, thisImplementation);
        _setFunction(AdminFacet.admin_addFacet.selector, thisImplementation);
        _setFunction(AdminFacet.admin_setAuthorizer.selector, thisImplementation);
        _setFunction(AdminFacet.admin_pause.selector, thisImplementation);
        _setFunction(AdminFacet.admin_setTreasury.selector, thisImplementation);
    }

    function admin_setFunctions(address implementation, bytes4[] calldata sigs) external authenticate {
        for (uint256 i = 0; i < sigs.length; i++) {
            _setFunction(sigs[i], implementation);
        }
    }

    function admin_pause(bool t) external authenticate {
        StorageSlot.getUint256Slot(SSLOT_PAUSABLE_PAUSED).value = t ? 1 : 0;
    }

    /**
     * @dev delegatecalls the implementation's initializeFacet()
     */
    function admin_addFacet(IFacet implementation) external authenticate {
        bytes memory data = abi.encodeWithSelector(IFacet.initializeFacet.selector);
        assembly ("memory-safe") {
            let success := delegatecall(gas(), implementation, add(data, 32), mload(data), 0, 0)
            if iszero(success) { revert(0, 0) }
        }
    }

    function admin_setAuthorizer(IAuthorizer auth_) external authenticate {
        StorageSlot.getAddressSlot(SSLOT_HYPERCORE_AUTHORIZER).value = address(auth_);
        emit AuthorizerChanged(auth_);
    }

    function admin_setTreasury(address treasury) external authenticate {
        StorageSlot.getAddressSlot(SSLOT_HYPERCORE_TREASURY).value = address(treasury);
        emit TreasuryChanged(treasury);
    }
}
