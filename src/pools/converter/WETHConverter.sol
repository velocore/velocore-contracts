// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../PoolWithLPToken.sol";
import "contracts/lib/RPow.sol";
import "contracts/interfaces/IConverter.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256) external;
}

contract WETHConverter is IConverter, Pool {
    using TokenLib for Token;
    using UncheckedMemory for int128[];
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeERC20 for IWETH;

    IWETH immutable weth;

    constructor(IVault vault_, IWETH weth_) Pool(vault_, address(this), address(this)) {
        weth = weth_;
    }

    function velocore__convert(address, Token[] calldata tokens, int128[] memory r, bytes calldata)
        external
        onlyVault
    {
        require(tokens.length == 2);
        uint256 iN = 1;
        uint256 iW = 0;

        int256 rN = r.u(iN);
        int256 rW = r.u(iW);

        if (rN == type(int128).max) {
            rN = -rW;
        } else if (rW == type(int128).max) {
            rW = -rN;
        }

        if (rN == 0 && rW == 0) return;

        require(rN > 0 != rW > 0);
        if (rN > 0) {
            weth.deposit{value: uint256(-rW)}();
            weth.safeTransfer(address(vault), uint256(-rW));
            rN += rW;
            if (rN > 0) {
                (bool success,) = address(vault).call{value: uint256(rN)}("");
                require(success, "failed to send Ether");
            }
        } else if (rW > 0) {
            weth.withdraw(uint256(-rN));
            (bool success,) = address(vault).call{value: uint256(-rN)}("");
            require(success, "failed to send Ether");
            rW += rN;
            if (rW > 0) {
                weth.safeTransfer(address(vault), uint256(rW));
            }
        }
    }

    receive() external payable {}
}
