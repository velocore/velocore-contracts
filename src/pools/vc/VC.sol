// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../PoolWithLPToken.sol";
import "contracts/lib/RPow.sol";
import "contracts/interfaces/IVC.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../SatelliteUpgradeable.sol";

/**
 * @dev The emission token of Velocore.
 *
 * implemented as a pool. VC is its "LP" token.
 * - takes old version of VC token and gives the same amount of new VC token.
 * - when called by vault, emits VC on an exponentially decaying schedule
 *
 */
contract VC is IVC, PoolWithLPToken, ISwap, SatelliteUpgradeable {
    uint256 constant DECAY = 999999983382381333; // (0.99)^(1/(seconds in a week)) * 1e18

    event Migrated(address indexed user, uint256 amount);

    using TokenLib for Token;
    using SafeCast for uint256;
    using SafeCast for int256;

    uint128 _totalSupply;
    uint128 lastEmission;

    Token immutable oldVC;
    address immutable veVC;
    bool initialized;

    constructor(address selfAddr, IVault vault_, Token oldVC_, address veVC_) Pool(vault_, selfAddr, address(this)) {
        oldVC = oldVC_;
        veVC = veVC_;
    }

    function totalSupply() public view override(IERC20, PoolWithLPToken) returns (uint256) {
        return _totalSupply;
    }

    function initialize() external {
        if (!initialized) {
            lastEmission = uint128(block.timestamp);
            PoolWithLPToken._initialize("Velocore", "VC");
            initialized = true;
        }
    }

    /**
     * the emission schedule depends on total supply of veVC + VC.
     * therefore, on veVC migration, this function should be called to nofity the change.
     */
    function notifyMigration(uint128 n) external {
        require(msg.sender == veVC);
        _totalSupply += n;
        _balanceOf[address(vault)] += n; // mint vc to the vault to simulate vc locking.
        _simulateMint(n);
    }

    /**
     * called by the vault.
     * (maxSupply - mintedSupply) decays 1% by every week.
     * @return newlyMinted amount of VCs to be distributed to gauges
     */
    function dispense() external onlyVault returns (uint256) {
        unchecked {
            if (block.timestamp <= 1694995200) {
                lastEmission = 1694995200;
                return 0;
            }
            if (_totalSupply >= 200_000_000e18) return 0;
            if (lastEmission == block.timestamp) return 0;
            uint256 decay1e18 = 1e18 - rpow(DECAY, block.timestamp - lastEmission, 1e18);
            uint256 decayed = (decay1e18 * (200_000_000e18 - _totalSupply)) / 1e18;
            lastEmission = uint128(block.timestamp);
            _totalSupply += uint128(decayed);
            _simulateMint(decayed);
            return decayed;
        }
    }

    /**
     * VC emission rate per second
     */
    function emissionRate() external view override returns (uint256) {
        if (block.timestamp <= 1694995200) {
            return 0;
        }
        if (_totalSupply >= 200_000_000 * 1e18) return 0;

        uint256 a = ((200_000_000 * 1e18 - _totalSupply) * rpow(DECAY, block.timestamp - lastEmission, 1e18)) / 1e18;

        return a - ((a * DECAY) / 1e18);
    }

    function velocore__execute(address user, Token[] calldata tokens, int128[] memory r, bytes calldata)
        external
        onlyVault
        returns (int128[] memory, int128[] memory)
    {
        uint256 iOldVC = _binarySearch(tokens, oldVC);
        uint256 iVC = _binarySearch(tokens, toToken(this));

        require(
            (tokens.length == 2) && (iOldVC != type(uint256).max) && (iVC != type(uint256).max), "unsupported tokens"
        );

        int128[] memory deltaPool = new int128[](2);

        deltaPool[iOldVC] = r[iOldVC] == type(int128).max ? -r[iVC] : r[iOldVC];
        deltaPool[iVC] = r[iVC] == type(int128).max ? -r[iOldVC] : r[iVC];

        require(deltaPool[iOldVC] >= 0 && deltaPool[iVC] <= 0, "wrong direction");
        require(deltaPool[iOldVC] + deltaPool[iVC] == 0, "VC can only be exchanged 1:1");

        uint128 minted = int256(-deltaPool[iVC]).toUint256().toUint128();
        emit Migrated(user, minted);
        _totalSupply += minted;
        _simulateMint(minted);
        return (new int128[](2), deltaPool);
    }

    function swapType() external view override returns (string memory) {
        return "VC";
    }

    function listedTokens() external view override returns (Token[] memory ret) {
        ret = new Token[](1);
        ret[0] = oldVC;
    }

    function lpTokens() external view override returns (Token[] memory ret) {
        ret = new Token[](1);
        ret[0] = toToken(this);
    }

    function underlyingTokens(Token lp) external view override returns (Token[] memory) {
        return new Token[](0);
    }
}
