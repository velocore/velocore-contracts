// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../PoolWithLPToken.sol";
import "contracts/lib/RPow.sol";
import "contracts/interfaces/IConverter.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

interface IUniswapPair {
    function burn(address to) external;
}

contract UniswapUnwrapper is IConverter, Pool {
    using TokenLib for Token;
    using SafeCast for uint256;
    using SafeCast for int256;
    using UncheckedMemory for Token[];
    using UncheckedMemory for int128[];

    constructor(IVault vault_) Pool(vault_, address(this), address(this)) {}

    function velocore__convert(address, Token[] calldata t, int128[] memory r, bytes calldata) external onlyVault {
        for (uint256 i = 0; i < t.length; i++) {
            Token token = t.u(i);
            int128 delta = r.u(i);
            if (delta > 0 && delta != type(int128).max) {
                token.transferFrom(address(this), token.addr(), uint256(int256(delta)));
                IUniswapPair(token.addr()).burn(address(vault));
            }
        }
    }

    receive() external payable {}
}
