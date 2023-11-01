// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "contracts/interfaces/IBribe.sol";
import "contracts/interfaces/IVault.sol";
import "contracts/lib/Token.sol";
import "contracts/lib/UncheckedMemory.sol";
import "contracts/lib/PoolBalanceLib.sol";
import "contracts/pools/Pool.sol";

struct Emission {
    uint128 per_second;
    uint32 cursor;
    uint32 last_bribe;
    mapping(uint32 => Point) points;
}

struct Point {
    uint32 prev;
    uint32 next;
    int128 per_second_delta;
}

library EmissionLib {
    using EmissionLib for Emission;
    using SafeCast for uint256;
    using SafeCast for int256;

    function initialized(Emission storage self) internal view returns (bool) {
        return self.points[0].next != 0;
    }

    function initialize(Emission storage self) internal {
        if (self.initialized()) return;
        self.points[0].next = type(uint32).max;
        self.points[0].prev = type(uint32).max;
        self.last_bribe = uint32(block.timestamp);
    }

    function update_bribe(Emission storage self) internal returns (uint256) {
        uint256 period_start = self.last_bribe;
        uint256 emission = 0;
        while (period_start < block.timestamp) {
            Point storage cursor = self.points[self.cursor];
            uint256 period_end = Math.min(block.timestamp, cursor.next);
            emission += (period_end - period_start) * self.per_second;

            if (period_end == cursor.next) {
                self.cursor = cursor.next;
                self.per_second = (int256(uint256(self.per_second)) + self.points[self.cursor].per_second_delta)
                    .toUint256().toUint128();
            }
            period_start = period_end;
        }
        self.last_bribe = uint32(block.timestamp);
        return emission;
    }

    function add_bribe(Emission storage self, uint32 begin, uint32 beginPrev, uint32 end, uint32 endPrev, uint256 total)
        internal
    {
        require(begin >= block.timestamp, "begin must be in the future");

        self.insert(begin, self.seek(begin, beginPrev));
        self.insert(end, self.seek(end, endPrev));
        int128 per_second_delta = (total / (end - begin)).toInt256().toInt128();
        self.points[begin].per_second_delta += per_second_delta;
        self.points[end].per_second_delta -= per_second_delta;
    }

    function seek(Emission storage self, uint256 target, uint32 cursor) internal view returns (uint32) {
        require(cursor <= target, "cursor less than target");
        while (self.points[cursor].next <= target) {
            cursor = self.points[cursor].next;
        }
        return cursor;
    }

    function insert(Emission storage self, uint32 point, uint32 prev) internal {
        if (prev != point) {
            uint32 next = self.points[prev].next;

            self.points[point].prev = prev;
            self.points[point].next = next;
            self.points[prev].next = point;
            self.points[next].prev = point;
        }
    }
}

contract LinearBribe is Pool, IBribe, ISwap {
    event BribeAdded(IGauge gauge, uint256 begin, uint256 end, uint256 per_second);

    using UncheckedMemory for uint256[];
    using UncheckedMemory for int128[];
    using UncheckedMemory for Token[];
    using SafeCast for int256;
    using SafeCast for uint256;
    using TokenLib for Token;
    using EmissionLib for Emission;

    mapping(IGauge => Emission) emissions;
    Token immutable bribeToken;

    function velocore__execute(address user, Token[] calldata tokens, int128[] memory r, bytes calldata data)
        external
        onlyVault
        returns (int128[] memory, int128[] memory)
    {
        require(tokens.length == 1 && tokens[0] == bribeToken && r[0] >= 0, "length mismatch");
        (IGauge gauge, uint32 begin, uint32 beginPrev, uint32 end, uint32 endPrev) =
            abi.decode(data, (IGauge, uint32, uint32, uint32, uint32));
        require(begin % 3600 == 0 && end % 3600 == 0);
        emissions[gauge].initialize();
        emissions[gauge].add_bribe(begin, beginPrev, end, endPrev, uint256(uint128(r[0])));

        emit BribeAdded(gauge, begin, end, uint256(int256(r[0])) / (end - begin));

        r[0] = int128(int256((uint256(int256(r[0])) / (end - begin)) * (end - begin)));
        return (new int128[](1), r);
    }

    constructor(IVault vault_, Token bribeToken_) Pool(vault_, address(this), msg.sender) {
        bribeToken = bribeToken_;
    }

    function seek(IGauge gauge, uint32 timestamp) external view returns (uint32) {
        if (!emissions[gauge].initialized()) return 0;
        return (emissions[gauge].seek(timestamp, 0));
    }

    function listedTokens() public view override returns (Token[] memory) {
        Token[] memory ret = new Token[](1);
        ret[0] = bribeToken;
        return ret;
    }

    function swapType() external view override returns (string memory) {
        return "linear-bribe";
    }

    function lpTokens() public view override returns (Token[] memory ret) {
        return new Token[](0);
    }

    function poolParams() external view override(IPool, Pool) returns (bytes memory) {
        return "";
    }

    function velocore__bribe(IGauge gauge, uint256 elapsed)
        external
        onlyVault
        returns (
            Token[] memory bribeTokens,
            int128[] memory deltaGauge,
            int128[] memory deltaPool,
            int128[] memory deltaExternal
        )
    {
        bribeTokens = new Token[](1);
        bribeTokens[0] = bribeToken;
        deltaGauge = new int128[](1);
        deltaPool = new int128[](1);
        deltaExternal = new int128[](1);
        emissions[gauge].initialize();

        deltaPool.u(0, -emissions[gauge].update_bribe().toInt256().toInt128());
    }

    function bribeTokens(IGauge gauge) external view returns (Token[] memory ret) {
        ret = new Token[](1);
        ret[0] = bribeToken;
    }

    function bribeRates(IGauge gauge) external view returns (uint256[] memory ret) {
        ret = new uint256[](1);
        if (!emissions[gauge].initialized()) return ret;
        uint256 r = emissions[gauge].per_second;

        uint256 period_start = emissions[gauge].last_bribe;
        Point storage cursor = emissions[gauge].points[emissions[gauge].cursor];
        while (period_start < block.timestamp) {
            uint256 period_end = Math.min(block.timestamp, cursor.next);

            if (period_end == cursor.next) {
                r = (int256(r) + emissions[gauge].points[cursor.next].per_second_delta).toUint256().toUint128();
                cursor = emissions[gauge].points[cursor.next];
            }
            period_start = period_end;
        }

        ret[0] = r;
    }

    function underlyingTokens(Token tok) external view returns (Token[] memory) {
        return new Token[](0);
    }

    function totalBribes(IGauge gauge) external view returns (uint256) {
        if (!emissions[gauge].initialized()) return 0;
        uint256 r = emissions[gauge].per_second;

        uint256 emission = 0;
        uint256 period_start = emissions[gauge].last_bribe;
        Point storage cursor = emissions[gauge].points[emissions[gauge].cursor];
        while (cursor.next < type(uint32).max) {
            emission += (cursor.next - period_start) * r;

            period_start = cursor.next;
            cursor = emissions[gauge].points[cursor.next];
            r = (int256(uint256(r)) + cursor.per_second_delta).toUint256().toUint128();
        }
        return emission;
    }
}
