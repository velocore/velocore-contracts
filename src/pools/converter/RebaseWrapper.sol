// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../PoolWithLPToken.sol";
import "src/lib/RPow.sol";
import "src/interfaces/IConverter.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

// unfinished
contract RebaseWrapper is IConverter {
    using TokenLib for Token;
    using UncheckedMemory for int128[];
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeERC20 for IWETH;

    Token immutable raw;
    uint256 immutable iR;
    uint256 immutable iW;
    uint256 wrapperSupply;

    constructor(IVault vault_, Token raw_) Pool(vault_, address(this), address(this)) {
        raw = raw_;
        if (raw < toToken(this)) {
            iR = 0;
            iW = 1;
        } else {
            iR = 1;
            iW = 0;
        }
    }

    function velocore__convert(address, Token[] calldata tokens, int128[] memory r, bytes calldata)
        external
        onlyVault
    {
        require(tokens.length == 2);
        require(tokens.u(iR) == raw && tokens.u(iW) == toToken(this));

        int256 rR = r.u(iR);
        int256 rW = r.u(iW);

        if (rW == type(int128).max) {} else if (rW > 0) {
            uint256 amount = raw.balanceOf(address(this)) * uint256(int256(rW)) / wrapperSupply;
            raw.transfer(address(vault), amount);
            wrapperSupply -= uint256(int256(rW));
            if (rR != type(int128).max) {
                rR += amount.toInt256().toInt128();
            }
        }
    }

    function balanceOf(address addr) external view returns (uint256) {
        if (addr == address(vault)) return wrapperSupply;
        else return 0;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        return true;
    }
}
