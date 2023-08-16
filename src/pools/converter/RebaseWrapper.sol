// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../PoolWithLPToken.sol";
import "src/lib/RPow.sol";
import "src/interfaces/IConverter.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

// un
contract RebaseWrapper is IConverter, Pool, ReentrancyGuard, ERC20 {
    using TokenLib for Token;
    using UncheckedMemory for int128[];
    using UncheckedMemory for Token[];
    using SafeCast for uint256;
    using SafeCast for int256;

    Token immutable raw;
    uint256 immutable iR;
    uint256 immutable iW;
    bool immutable allowSkimming;

    constructor(IVault vault_, Token raw_, bool allowSkimming_)
        Pool(vault_, address(this), address(this))
        ERC20(string(abi.encodePacked("Wrapped ", ERC20(raw_.addr()).name())), string(abi.encodePacked("w", raw_.symbol())))
    {
        raw = raw_;
        allowSkimming = allowSkimming_;
        uint256 iir;
        uint256 iiw;

        if (raw < toToken(IERC20(address(this)))) {
            iir = 0;
            iiw = 1;
        } else {
            iir = 1;
            iiw = 0;
        }

        iR = iir;
        iW = iiw;
    }

    function velocore__convert(address, Token[] calldata tokens, int128[] memory r, bytes calldata)
        external
        nonReentrant
        onlyVault
    {
        require(tokens.length == 2);
        require(tokens.u(iR) == raw && tokens.u(iW) == toToken(IERC20(address(this))));

        int256 rR = r.u(iR);
        int256 rW = r.u(iW);

        if (rW == type(int128).max) {
            require(rR != type(int128).max && rR >= 0);
            if (totalSupply() == 0) {
                _mint(address(vault), uint256(int256(rR)));
            } else {
                _mint(
                    address(vault),
                    totalSupply() * uint256(int256(rR)) / (raw.balanceOf(address(this)) - uint256(int256(rR)))
                );
            }
        } else if (rR == type(int128).max) {
            require(rW != type(int128).max && rW >= 0);
            _burn(address(this), uint256(int256(rW)));
            raw.transferFrom(
                address(this),
                address(vault),
                raw.balanceOf(address(this)) * uint256(int256(rW)) / (totalSupply() + uint256(int256(rW)))
            );
        } else if (rW <= 0 && rR >= 0) {
            uint256 requiredDeposit;
            if (totalSupply() != 0) {
                requiredDeposit = Math.ceilDiv(raw.balanceOf(address(this)) * uint256(int256(-rW)), totalSupply());
            } else {
                requiredDeposit = uint256(int256(-rW));
            }
            _mint(address(vault), uint256(int256(-rW)));
            require(requiredDeposit <= uint256(int256(rR)));
            raw.transferFrom(address(this), address(vault), uint256(int256(rR)) - requiredDeposit);
        } else if (rW >= 0 && rR <= 0) {
            uint256 diff = Math.ceilDiv(totalSupply() * uint256(int256(-rR)), raw.balanceOf(address(this)));
            require(diff <= uint256(int256(rW)));
            _burn(address(this), diff);
            raw.transferFrom(address(this), address(vault), uint256(int256(-rR)));
            transfer(address(vault), balanceOf(address(this)));
        }
    }

    function decimals() public view override returns (uint8) {
        return raw.decimals();
    }

    function skim() external nonReentrant {
        require(allowSkimming, "no skim allowed");
        raw.transferFrom(address(this), msg.sender, raw.balanceOf(address(this)) - totalSupply());
    }
}
