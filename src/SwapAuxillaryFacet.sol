// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "contracts/lib/Token.sol";
import "contracts/lib/PoolBalanceLib.sol";
import "contracts/interfaces/IPool.sol";
import "contracts/interfaces/ISwap.sol";
import "contracts/interfaces/IConverter.sol";
import "contracts/interfaces/IVC.sol";
import "contracts/interfaces/IVault.sol";
import "contracts/interfaces/IFacet.sol";
import "contracts/VaultStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @dev a Facet for handling swap, stake and vote logic.
 *
 *
 * please refer to the tech docs below for its intended behavior.
 * https://velocore.gitbook.io/velocore-v2/technical-docs/exchanging-tokens-with-vault
 *
 *
 */

contract SwapAuxillaryFacet is VaultStorage, IFacet {
    using PoolBalanceLib for PoolBalance;
    using TokenLib for Token;
    using UncheckedMemory for Token[];
    using UncheckedMemory for int128[];
    using UncheckedMemory for bytes32[];
    using UncheckedMemory for uint256[];
    using SafeCast for uint256;
    using SafeCast for int256;
    using EnumerableSet for EnumerableSet.AddressSet;

    IVC immutable vc;
    Token immutable ballot; // veVC
    address immutable thisImplementation;

    constructor(IVC vc_, Token ballot_) {
        vc = vc_;
        ballot = ballot_;
        thisImplementation = address(this);
    }

    /**
     * @dev called by AdminFacet.admin_addFacet().
     * doesnt get added to the routing table, hence the lack of access control.
     */
    function initializeFacet() external {
        _setFunction(SwapAuxillaryFacet.notifyInitialSupply.selector, thisImplementation);
        _setFunction(SwapAuxillaryFacet.attachBribe.selector, thisImplementation);
        _setFunction(SwapAuxillaryFacet.killBribe.selector, thisImplementation);
        _setFunction(SwapAuxillaryFacet.killGauge.selector, thisImplementation);
        _setFunction(SwapAuxillaryFacet.emissionToken.selector, thisImplementation);
    }

    /**
     * @return vc Token representation of VC.
     */
    function emissionToken() external view returns (Token) {
        return toToken(IERC20(address(vc)));
    }

    /**
     * @dev called by pools to notify "virtually minted" lp tokens.
     * please refer to src/pools/PoolsWithLPToken.sol for why this need to exist.
     *
     * This function trusts msg.sender and just credit given amount to its pool balances,
     * as long as the token equals the pool.
     *
     * This introduce no security concern as the pool would have full control over its lp tokens anyway
     */
    function notifyInitialSupply(Token tok, uint128 gaugeAmount, uint128 poolAmount) external {
        require(tok.addr() == msg.sender);

        _poolBalances()[IPool(msg.sender)][tok] =
            _poolBalances()[IPool(msg.sender)][tok].credit(int256(uint256(gaugeAmount)), int256(uint256(poolAmount)));
    }

    function attachBribe(IGauge gauge, IBribe bribe) external {
        if (msg.sender != address(gauge)) authenticateCaller();
        if (_e().gauges[gauge].bribes.contains(address(bribe))) return;

        _e().gauges[gauge].bribes.add(address(bribe));
        emit BribeAttached(gauge, bribe);
    }

    function killBribe(IGauge gauge, IBribe bribe) external {
        if (msg.sender != address(gauge)) authenticateCaller();
        if (!_e().gauges[gauge].bribes.contains(address(bribe))) return;
        _e().gauges[gauge].bribes.remove(address(bribe));
        emit BribeKilled(gauge, bribe);
    }

    function killGauge(IGauge gauge, bool kill) external authenticate {
        // we use (lastBribeUpdate == 1) to represent killed bribes.
        if (kill && _e().gauges[gauge].lastBribeUpdate != 1) {
            _e().gauges[gauge].lastBribeUpdate = 1;
            _e().totalVotes -= _e().gauges[gauge].totalVotes;
        } else if (!kill && _e().gauges[gauge].lastBribeUpdate == 1) {
            _e().gauges[gauge].lastBribeUpdate = uint32(block.timestamp);
            _e().totalVotes += _e().gauges[gauge].totalVotes;
        }
        emit GaugeKilled(gauge, kill);
    }

    function balanceDelta(Token[] memory tokens, uint256[] memory balancesBefore)
        external
        returns (int128[] memory delta)
    {
        delta = new int128[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            int128 diff = (tokens.u(i).balanceOf(address(this)).toInt256() - balancesBefore.u(i).toInt256()).toInt128();
            delta.u(i, diff);
            if (diff > 0) {
                tokens.u(i).transferFrom(address(this), address(0xDEADBEEF), uint256(int256(diff)));
            }
        }
    }
}
