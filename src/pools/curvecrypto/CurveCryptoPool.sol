// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/console.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "src/lib/Token.sol";
import "src/lib/UncheckedMemory.sol";
import "src/lib/PoolBalanceLib.sol";

import {rpow} from "src/lib/RPow.sol";
import "src/pools/SingleTokenGauge.sol";
// unfinished

struct CurveCryptoParam {
    int256 a;
    int256 g_e18;
    int256 midFee_e18;
    int256 outFee_e18;
    int256 gammaFee_e18;
    Token baseToken;
    Token quoteToken;
    int256 initialPrice;
    string symbol;
    string name;
}

function max(int256 a, int256 b) pure returns (int256) {
    return a < b ? b : a;
}

function abs(int256 d) pure returns (int256) {
    return d > 0 ? d : -d;
}

contract CurveCryptoPool is ISwap, IBribe, SingleTokenGauge, PoolWithLPToken {
    using UncheckedMemory for uint256[];
    using UncheckedMemory for int128[];
    using UncheckedMemory for Token[];
    using SafeCast for int256;
    using SafeCast for uint256;
    using TokenLib for Token;

    int256 immutable _midFee_e18;
    int256 immutable _outFee_e18;

    int256 immutable _4a_g2_e18;
    int256 immutable _g_plus_1_e18;
    int256 immutable _constant_term_coefficient_e18;
    int256 immutable _coefficient_2;
    int256 immutable _coefficient_neg_2;

    int256 immutable _a_g2_e18;
    int256 immutable _2g_plus_3_e18;
    int256 immutable _g_plus_1__mul__g__plus_3_e18;
    int256 immutable _minus__g_plus_1_squared_e18;
    int256 immutable _g_plus_1_squared_e18;

    int256 immutable _gfee_div_4_e36;
    int256 immutable _gfee_plus_1__div_4_e18;

    Token immutable baseToken;
    Token immutable quoteToken;

    int128 immutable scale_base;
    int128 immutable scale_quote;

    uint256 immutable _3token_lp_index;
    uint256 immutable _3token_base_index;
    uint256 immutable _3token_quote_index;

    int128 oraclePrice;
    int128 internalPrice;
    int128 invariantLastBlock;
    int128 invariant;
    uint32 lastTimestamp;

    constructor(IVault vault_, CurveCryptoParam memory param) SingleTokenGauge(vault_, toToken(this), this) {
        unchecked {
            _4a_g2_e18 = 4 * param.a * param.g_e18 * param.g_e18 / 1e18;
            _a_g2_e18 = param.a * param.g_e18 * param.g_e18 / 1e18;
            _2g_plus_3_e18 = 2 * param.g_e18 + 3e18;
            _g_plus_1__mul__g__plus_3_e18 = (param.g_e18 + 1e18) * (param.g_e18 + 3e18) / 1e18;
            _minus__g_plus_1_squared_e18 = -(param.g_e18 + 1e18) * (param.g_e18 + 1e18) / 1e18;
            _g_plus_1_squared_e18 = (param.g_e18 + 1e18) * (param.g_e18 + 1e18) / 1e18;

            _constant_term_coefficient_e18 = 3e18 + param.g_e18 * (4e18 + (1 - 4 * param.a) * param.g_e18) / 1e18;
            _coefficient_2 = -(1e18 + param.g_e18) * (1e18 + param.g_e18) / 64e18;
            _coefficient_neg_2 = (-12e18 - 8 * param.g_e18) / 16;
            _g_plus_1_e18 = param.g_e18 + 1e18;

            _gfee_div_4_e36 = param.gammaFee_e18 * 0.25e18;
            _gfee_plus_1__div_4_e18 = (param.gammaFee_e18 + 1e18) / 4;

            _midFee_e18 = param.midFee_e18;
            _outFee_e18 = param.outFee_e18;

            baseToken = param.baseToken;
            quoteToken = param.quoteToken;
            uint256 iBase;
            uint256 iLP;
            uint256 iQuote;
            if (baseToken < quoteToken) {
                iQuote += 1;
            } else {
                iBase += 1;
            }
            if (toToken(this) < param.baseToken && toToken(this) < param.quoteToken) {
                iQuote += 1;
                iBase += 1;
            } else if (toToken(this) < param.baseToken != toToken(this) < param.quoteToken) {
                iLP = 1;
                if (iQuote == 1) ++iQuote;
                if (iBase == 1) ++iBase;
            } else {
                iLP = 2;
            }
            _3token_lp_index = iLP;
            _3token_base_index = iBase;
            _3token_quote_index = iQuote;

            scale_base = int128(int256(10 ** (18 - param.baseToken.decimals())));
            scale_quote = int128(int256(10 ** (18 - param.quoteToken.decimals())));
            internalPrice = int128(param.initialPrice);
            oraclePrice = internalPrice;

            lastTimestamp = uint32(block.timestamp);
            invariant = 2;

            PoolWithLPToken._initialize(param.name, param.symbol);
        }
    }

    function _update_oracle() internal {
        console.log("zzzlol");
        console.logInt(_p());
        console.logInt(oraclePrice);
        int256 alpha = int256(rpow(998845421738030153, block.timestamp - lastTimestamp, 1e18));
        oraclePrice = int128((alpha * oraclePrice + (1e18 - alpha) * _p()) / 1e18);
        console.log("zzzz");
    }

    function _repeg() internal {
        unchecked {
            int256 a_base = int256(_getPoolBalance(baseToken)) * scale_base;
            int256 a_quote = int256(_getPoolBalance(quoteToken)) * scale_quote;

            int256 _2xcp_liability = int256(totalSupply());

            int256 old_price_sqrt = int256(Math.sqrt(uint256(int256(internalPrice) * 1e18)));
            int256 best_price_sqrt = old_price_sqrt;
            int256 old_2xcp = invariant * int256(1e18) / old_price_sqrt;
            uint256 best_score = uint256(old_2xcp - _2xcp_liability);
            int256 old_d = int256(invariant);
            int256 best_d = old_d;
            int256 new_price_sqrt = int256(Math.sqrt(uint256(int256(oraclePrice) * 1e18)));
            int256 new_d = _D(
                a_quote + a_base * new_price_sqrt / 1e18 * new_price_sqrt / 1e18,
                a_quote * a_base / 1e18 * new_price_sqrt / 1e18 * new_price_sqrt / 1e18,
                int256(invariant),
                int256(invariant) * 99 / 100
            );
            int256 new_2xcp = new_d * 1e18 / new_price_sqrt;
            if (new_2xcp >= _2xcp_liability) {
                internalPrice = int128(new_price_sqrt * new_price_sqrt / 1e18);
                invariant = new_d.toInt128();
                return;
            }
        }
    }

    function velocore__execute(address, Token[] calldata t, int128[] memory r, bytes calldata)
        external
        onlyVault
        returns (int128[] memory deltaGauge, int128[] memory deltaPool)
    {
        if (lastTimestamp != block.timestamp) {
            _update_oracle();
            _repeg();
            invariantLastBlock = invariant;
            lastTimestamp = uint32(block.timestamp);
        }
        deltaGauge = new int128[](t.length);
        deltaPool = new int128[](t.length);

        if (t.length == 3) {
            require(
                t.u(_3token_lp_index) == toToken(this) && t.u(_3token_base_index) == baseToken
                    && t.u(_3token_quote_index) == quoteToken
            );

            int256 r_lp = r.u(_3token_lp_index);
            int256 r_base = r.u(_3token_base_index);
            int256 r_quote = r.u(_3token_quote_index);

            if (r_lp != type(int128).max) {
                if (r_base != type(int128).max) {
                    r_quote = _exchange_for_quote(r_base, r_lp);
                } else if (r_quote != type(int128).max) {
                    r_base = _exchange_for_base(r_quote, r_lp);
                } else {
                    (r_base, r_quote) = _exchange_from_lp(r_lp);
                }
            } else {
                require(r_base != type(int128).max || r_quote != type(int128).max);
                if (r_base == type(int128).max) {
                    int256 a_base = int256(_getPoolBalance(baseToken));
                    int256 a_quote = int256(_getPoolBalance(quoteToken));
                    r_base = r_quote * a_base / a_quote;
                } else if (r_quote == type(int128).max) {
                    int256 a_base = int256(_getPoolBalance(baseToken));
                    int256 a_quote = int256(_getPoolBalance(quoteToken));
                    r_quote = r_base * a_quote / a_base;
                }
                r_lp = _exchange_for_lp(r_base, r_quote);
            }
            deltaPool.u(_3token_base_index, r_base.toInt128());
            deltaPool.u(_3token_quote_index, r_quote.toInt128());
            deltaPool.u(_3token_lp_index, r_lp.toInt128());
            return (deltaGauge, deltaPool);
        } else if (t.length == 2) {
            require((r.u(0) == type(int128).max) != (r.u(1) == type(int128).max));

            uint256 i_lp = 2;
            uint256 i_base = 2;
            uint256 i_quote = 2;

            Token tt = t.u(0);
            if (tt == toToken(this)) i_lp = 0;
            else if (tt == baseToken) i_base = 0;
            else if (tt == quoteToken) i_quote = 0;

            tt = t.u(1);
            if (tt == toToken(this)) i_lp = 1;
            else if (tt == baseToken) i_base = 1;
            else if (tt == quoteToken) i_quote = 1;

            int256 r_lp = i_lp == 2 ? int256(0) : r.u(i_lp);
            int256 r_base = i_base == 2 ? int256(0) : r.u(i_base);
            int256 r_quote = i_quote == 2 ? int256(0) : r.u(i_quote);

            if (r_lp == type(int128).max) {
                r_lp = _exchange_for_lp(r_base, r_quote);
            } else if (r_quote == type(int128).max) {
                r_quote = _exchange_for_quote(r_base, r_lp);
            } else {
                r_base = _exchange_for_base(r_quote, r_lp);
            }

            if (i_lp != 2) {
                deltaPool.u(i_lp, r_lp.toInt128());
            }

            if (i_base != 2) {
                deltaPool.u(i_base, r_base.toInt128());
            }

            if (i_quote != 2) {
                deltaPool.u(i_quote, r_quote.toInt128());
            }

            return (deltaGauge, deltaPool);
        }
    }

    function _exchange_from_lp(int256 r_lp) internal returns (int256 r_base, int256 r_quote) {
        int256 price = internalPrice;
        int256 a_base = int256(_getPoolBalance(baseToken));
        int256 a_quote = int256(_getPoolBalance(quoteToken));

        int256 r_invariant =
            r_lp * (int256(Math.sqrt(uint256(price) * 1e18, r_lp > 0 ? Math.Rounding.Down : Math.Rounding.Up))) / 1e18;
        if (a_base == 0 && a_quote == 0) {
            r_base = r_invariant * scale_base * 0.5e18 / price;
            r_quote = r_invariant * scale_quote / 2;
        } else {
            r_base = a_base * -r_invariant / invariant + 1;
            r_quote = a_quote * -r_invariant / invariant + 1;
        }
        invariant -= r_invariant.toInt128();
        require(invariant >= 0, "invariant below 0");
    }

    function _exchange_for_lp(int256 r_base, int256 r_quote) internal returns (int256 delta_lp) {
        int256 price = internalPrice;
        int256 a_base = int256(_getPoolBalance(baseToken));
        int256 a_quote = int256(_getPoolBalance(quoteToken));
        a_base = a_base * scale_base * price / 1e18;
        a_quote = a_quote * scale_quote;
        r_base = r_base * scale_base * price / 1e18;
        r_quote *= scale_quote;

        int256 b_base = r_base + a_base;
        int256 b_quote = r_quote + a_quote;
        int256 new_d_with_fee =
            _D(b_base + b_quote, b_base * b_quote / 1e18, b_base + b_quote, (b_base + b_quote) * 99 / 100);

        if (invariant != 0) {
            int256 k = 1e18 * new_d_with_fee / invariant;

            int256 fee_rate = _fee(b_base + b_quote, b_base * b_quote / 1e18) * int256(invariantLastBlock) / invariant;

            if (k >= 1e18) {
                b_base -= fee_rate * max((b_base * 1e18 / k - a_base), 0) / 1e18;
                b_quote -= fee_rate * max((b_quote * 1e18 / k - a_quote), 0) / 1e18;
            } else {
                b_base -= fee_rate * max((b_base - a_base * k / 1e18), 0) / 1e18;
                b_quote -= fee_rate * max((b_quote - a_quote * k / 1e18), 0) / 1e18;
            }
        }
        int256 new_d_without_fee =
            _D(b_base + b_quote, b_base * b_quote / 1e18, new_d_with_fee * 101 / 100, new_d_with_fee);

        int256 sqrt_price = int256(
            Math.sqrt(uint256(price) * 1e18, invariant > new_d_without_fee ? Math.Rounding.Down : Math.Rounding.Up)
        );
        delta_lp = (int256(invariant) - new_d_without_fee) * 1e18 / sqrt_price + 1;

        invariant = new_d_with_fee.toInt128();
    }

    function _exchange_for_quote(int256 r_base, int256 r_lp) internal returns (int256 delta_quote) {
        int256 price = internalPrice;
        int256 a_base = int256(_getPoolBalance(baseToken)) * scale_base * price / 1e18 + 1;
        int256 a_quote = int256(_getPoolBalance(quoteToken)) * scale_quote + 1;
        r_base = r_base * scale_base * price / 1e18;
        int256 b_base = r_base + a_base;

        return _exchange_for_y(a_quote, b_base, r_lp) / scale_quote;
    }

    function _exchange_for_base(int256 r_quote, int256 r_lp) internal returns (int256 delta_base) {
        int256 price = internalPrice;
        int256 a_base = int256(_getPoolBalance(baseToken)) * scale_base * price / 1e18 + 1;
        int256 a_quote = int256(_getPoolBalance(quoteToken)) * scale_quote + 1;
        r_quote = r_quote * scale_quote;
        int256 b_quote = r_quote + a_quote;

        return _exchange_for_y(a_base, b_quote, r_lp) * 1e18 / price / scale_base;
    }

    function _exchange_for_y(int256 a_y, int256 b_x, int256 r_lp) internal returns (int256 delta_y) {
        int256 price = internalPrice;
        r_lp = r_lp * int256(Math.sqrt(uint256(price) * 1e18)) / 1e18;

        int256 b_y = _y(b_x, invariant - r_lp);

        int256 fee_rate = _fee(b_y + b_x, b_y * b_x / 1e18) * int256(invariantLastBlock) / invariant;
        int256 k = 1e18 * (invariant - r_lp) / invariant;

        int256 taxable;
        if (k >= 1e18) {
            taxable = b_y * 1e18 / k - a_y;
        } else {
            taxable = b_y - a_y * k / 1e18;
        }

        if (taxable > 0) {
            b_y += fee_rate * taxable / (1e18 - taxable);
        } else {
            b_y += fee_rate * (-taxable) / 1e18;
        }
        console.logInt(b_x);
        console.logInt(b_y);
        int256 new_d = _D(b_x + b_y, b_x * b_y / 1e18, b_x + b_y, (b_x + b_y) * 99 / 100);

        delta_y = b_y - a_y;

        invariant = new_d.toInt128();
    }

    function swapType() external view override returns (string memory) {
        return "curvecrypto";
    }

    function lpTokens() external view override returns (Token[] memory ret) {
        ret = new Token[](1);
        ret[0] = toToken(this);
    }

    function listedTokens() public view override returns (Token[] memory) {
        Token[] memory ret = new Token[](2);
        ret[0] = baseToken;
        ret[1] = quoteToken;
        return ret;
    }

    function poolParams() external view override(IPool, Pool) returns (bytes memory) {
        return "";
    }

    function velocore__bribe(IGauge gauge, uint256 elapsed)
        external
        override
        onlyVault
        returns (
            Token[] memory bribeTokens,
            int128[] memory deltaGauge,
            int128[] memory deltaPool,
            int128[] memory deltaExternal
        )
    {}

    function bribeTokens(IGauge gauge) external view returns (Token[] memory ret) {
        require(address(gauge) == address(this));
        ret = new Token[](1);
        ret[0] = toToken(this);
    }

    function bribeRates(IGauge gauge) external view returns (uint256[] memory ret) {
        require(address(gauge) == address(this));
        ret = new uint256[](1);
        ret[0] = 0;
    }

    function underlyingTokens(Token tok) external view returns (Token[] memory) {
        require(tok == toToken(this));
        return listedTokens();
    }

    function _p() internal view returns (int256) {
        int256 y = int256(_getPoolBalance(baseToken)) * scale_base * internalPrice / 1e18;
        int256 x = int256(_getPoolBalance(quoteToken)) * scale_quote;

        if (x == 0 || y == 0) return internalPrice;
        int256 d = invariant;

        int256 k0 = 4 * x * y / d * 1e18 / d;
        int256 k0_2 = (k0 * k0 / 1e18);
        int256 gk = (2 * k0 - _2g_plus_3_e18) * k0_2 / 1e18 + _g_plus_1_squared_e18;
        return internalPrice * x / 1e18 * (gk + _4a_g2_e18 * k0 / 1e18 * y / d) / y * 1e18
            / (gk + _4a_g2_e18 * k0 / 1e18 * x / d);
    }

    function _D(int256 s, int256 p, int256 d, int256 d_new) internal view returns (int256) {
        unchecked {
            if (s == 0 || p == 0) return 0;

            int256 _constant_term = _constant_term_coefficient_e18 / 16;
            int256 _coefficient_neg_1_e36 = _4a_g2_e18 / 16 * s;

            //int256 d_old;
            //int256 d = s;
            int256 d_old;
            int256 f_old;
            int256 f = (
                (((1e18 * p / d * p / d * 1e18 + _coefficient_neg_2 * p) / d * 1e18) + _coefficient_neg_1_e36) / d
            ) + (_coefficient_2 * d / 1e18 * d / p) + _constant_term;
            assembly {
                mstore(0, 0)
            }
            for (uint256 i = 0; i < 255; i++) {
                d_old = d;
                f_old = f;

                d = d_new;
                f = ((((1e18 * p / d * p / d * 1e18 + _coefficient_neg_2 * p) / d * 1e18) + _coefficient_neg_1_e36) / d)
                    + (_coefficient_2 * d / 1e18 * d / p) + _constant_term;
                if (f_old == f) {
                    return d;
                }
                d_new = d - f * (d - d_old) / (f - f_old);
                if (uint256(d_new) ^ uint256(d) < 128) {
                    return d_new;
                }
            }
            revert("D did not converge");
        }
    }

    function _y(int256 x_e18, int256 d_e18) internal view returns (int256) {
        unchecked {
            int256 b = _a_g2_e18 * d_e18 / x_e18 - _2g_plus_3_e18;
            int256 c = _g_plus_1__mul__g__plus_3_e18 + _4a_g2_e18 * (x_e18 - d_e18) / d_e18;
            int256 d = _minus__g_plus_1_squared_e18;

            int256 d0 = b * b / 1e18 - 3 * c;
            int256 d1 = (2 * b * b * b - 9e18 * b * c + 27e36 * d) / 1e36;

            int256 sqrt_arg = d1 * d1 - 4 * d0 * d0 * d0 / 1e18;

            if (sqrt_arg < 0) return _y_newton(x_e18, d_e18);
            int256 C = -(int256(cbrt(1e36 * uint256((int256(Math.sqrt(uint256(sqrt_arg))) - d1)) / 2)));

            int256 k0 = -(b + C + d0 * 1e18 / C) / 3;
            return k0 * d_e18 / x_e18 * d_e18 / 4e18;
        }
    }

    function _y_newton(int256 x_e18, int256 d_e18) internal view returns (int256) {
        unchecked {
            int256 b = _a_g2_e18 * d_e18 / x_e18 - _2g_plus_3_e18;
            int256 c = _g_plus_1__mul__g__plus_3_e18 + _4a_g2_e18 * (x_e18 - d_e18) / d_e18;
            int256 d_e36 = _minus__g_plus_1_squared_e18 * 1e18;

            int256 k0 = d_e18 * d_e18 / x_e18 / 4;
            int256 k0_old = -1000000;
            int256 i;
            while (uint256(k0) ^ uint256(k0_old) > 65535) {
                int256 f_e36 = (((k0 + b) * k0 / 1e18 + c) * k0) + d_e36;
                int256 fp = ((3 * k0 + 2 * b) * k0) / 1e18 + c;
                k0_old = k0;
                k0 -= f_e36 / fp;
                if (++i > 256) {
                    revert("y_newton did not converge");
                }
            }
            return k0 * d_e18 / x_e18 * d_e18 / 4e18;
        }
    }

    function _fee(int256 s, int256 p) internal view returns (int256) {
        unchecked {
            int256 g = _gfee_div_4_e36 / (_gfee_plus_1__div_4_e18 - p * 1e18 / s * 1e18 / s);
            return (g * _midFee_e18 + (1e18 - g) * _outFee_e18) / 1e18;
        }
    }

    function cbrt(uint256 k) internal pure returns (uint256) {
        unchecked {
            uint256 scale = 1;
            if (k < 3646765219114266673707828955929954266) {
                // 2**256 / 1e18 / 31752
                scale *= 1e6;
                k *= 1e18;
            }
            if (k < 3646765219114266673707828955929954266) {
                scale *= 1e6;
                k *= 1e18;
            }
            uint256 log2 = Math.log2(k);
            uint256 rem = log2 % 3;
            uint256 x = 2 ** (log2 / 3);

            if (rem == 2) x = x * 31752 / 10000;
            else if (rem == 1) x = x * 126 / 100;
            x = (k / (x * x) + 2 * x) / 3;
            x = (k / (x * x) + 2 * x) / 3;
            x = (k / (x * x) + 2 * x) / 3;
            x = (k / (x * x) + 2 * x) / 3;
            x = (k / (x * x) + 2 * x) / 3;
            x = (k / (x * x) + 2 * x) / 3;
            x = (k / (x * x) + 2 * x) / 3;

            return x / scale;
        }
    }
}
