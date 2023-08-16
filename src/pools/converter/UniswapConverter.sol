// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../PoolWithLPToken.sol";
import "src/lib/RPow.sol";
import "src/interfaces/IConverter.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

contract UniswapConverter is IConverter, Pool {
    using TokenLib for Token;
    using SafeCast for uint256;
    using SafeCast for int256;

    constructor(IVault vault_) Pool(vault_, address(this), address(this)) {}

    function velocore__convert(address, Token[] calldata t, int128[] memory r, bytes calldata data)
        external
        onlyVault
    {}

    receive() external payable {}
}
