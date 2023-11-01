// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "contracts/interfaces/IAuthorizer.sol";

contract SimpleAuthorizer is IAuthorizer, AccessControl {
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function canPerform(bytes32 actionId, address account, address where) external view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account) || hasRole(actionId, account);
    }
}
