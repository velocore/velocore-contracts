// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./PoolWithLPToken.sol";
import "contracts/interfaces/IGauge.sol";
import "contracts/lib/RPow.sol";
import "contracts/lib/UncheckedMemory.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @dev a base contract for gauges with single stakes.
 *
 * pretty standard Masterchef-like design.
 *
 */

struct StakerInformation {
    uint128 staked;
    uint128 emissionPerStake1e9AtLastClaim;
}

contract SingleTokenGauge is Pool, IGauge {
    using UncheckedMemory for uint256[];
    using UncheckedMemory for int128[];
    using UncheckedMemory for Token[];
    using TokenLib for Token;
    using SafeCast for uint256;
    using SafeCast for int256;

    uint128 emissionPerStake1e9;

    mapping(address => StakerInformation) stakerInformation;
    Token internal immutable emissionToken;
    Token public immutable stake;

    constructor(IVault vault_, Token stake_, IBribe bribe) Pool(vault_, address(this), msg.sender) {
        emissionToken = vault_.emissionToken();
        vault_.attachBribe(this, bribe);
        stake = stake_;
    }

    /**
     * called by the vault to nofity new emission
     */
    function velocore__emission(uint256 newEmissions) external onlyVault {
        if (newEmissions > 0) {
            uint256 totalStakes = _getGaugeBalance(stake);
            if (totalStakes > 0) {
                unchecked {
                    // totalSupply of emissionToken * 1e9 < uint128_max
                    emissionPerStake1e9 += uint128(newEmissions * 1e9 / totalStakes);
                }
            }
        }
    }

    function velocore__gauge(address user, Token[] calldata tokens, int128[] memory amounts, bytes calldata)
        external
        virtual
        onlyVault
        returns (int128[] memory deltaGauge, int128[] memory deltaPool)
    {
        deltaGauge = new int128[](tokens.length);
        deltaPool = new int128[](tokens.length);
        uint256 stakeIndex = _binarySearch(tokens, stake); // assumed to exist
        uint256 emissionIndex = _binarySearch(tokens, emissionToken);

        unchecked {
            // total emissions cannot be greater than the total supply of the emissionToken (200Me18). log10(2^128) - 18 - 9 - 8 > 0; therefore it doesnt overflow.
            uint256 claimed = (emissionPerStake1e9 - stakerInformation[user].emissionPerStake1e9AtLastClaim)
                * stakerInformation[user].staked / 1e9;

            // the total supply of the emissionToken = 200Me18 < int128_max
            deltaGauge.u(emissionIndex, -int128(int256(claimed)));
        }

        if (stakeIndex != type(uint256).max) {
            stakerInformation[user].staked =
                (int256(uint256(stakerInformation[user].staked)) + amounts.u(stakeIndex)).toUint256().toUint128();

            deltaGauge.u(stakeIndex, amounts.u(stakeIndex));
        }
        stakerInformation[user].emissionPerStake1e9AtLastClaim = emissionPerStake1e9;
    }

    function stakeableTokens() external view virtual returns (Token[] memory) {
        Token v = stake;
        assembly {
            mstore(0, 0x20)
            mstore(0x20, 1)
            mstore(0x40, v)
            return(0, 0x60)
        }
    }

    function stakedTokens(address user) external view virtual returns (uint256[] memory) {
        uint256 v = stakerInformation[user].staked;
        assembly {
            mstore(0, 0x20)
            mstore(0x20, 1)
            mstore(0x40, v)
            return(0, 0x60)
        }
    }

    function stakedTokens() external view virtual returns (uint256[] memory) {
        uint256 v = _getGaugeBalance(stake);
        assembly {
            mstore(0, 0x20)
            mstore(0x20, 1)
            mstore(0x40, v)
            return(0, 0x60)
        }
    }

    function emissionShare(address user) external view virtual returns (uint256) {
        uint256 gb = _getGaugeBalance(stake);
        if (gb == 0) return 0;
        unchecked {
            return (stakerInformation[user].staked * uint256(1e18)) / gb;
        }
    }

    function naturalBribes() external view returns (Token[] memory) {
        return ISwap(stake.addr()).listedTokens();
    }
}
