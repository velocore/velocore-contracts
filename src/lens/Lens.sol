// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "contracts/interfaces/IVault.sol";
import "contracts/VaultStorage.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

contract Lens is VaultStorage {
    address lensImplementation;
    IVault immutable vault;
    address immutable admin;

    function upgrade(address newImplementation) external {
        require(msg.sender == admin, "not admin");
        lensImplementation = newImplementation;
    }

    constructor(IVault vault_) {
        vault = vault_;
        admin = msg.sender;
    }

    fallback() external {
        address vaultAddress = address(vault);
        address lensAddress = lensImplementation;
        assembly {
            mstore(0, 0x7669657700000000000000000000000000000000000000000000000000000000)
            mstore(4, lensAddress)
            calldatacopy(36, 0, calldatasize())
            let success := call(gas(), vaultAddress, 0, 0, add(calldatasize(), 36), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if success { revert(0, returndatasize()) }
            return(0, returndatasize())
        }
    }
}
