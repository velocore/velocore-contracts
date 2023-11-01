// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "contracts/lib/Token.sol";

interface IPool {
    function poolParams() external view returns (bytes memory);
}
