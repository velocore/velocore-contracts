pragma solidity ^0.8.19;

import "src/lib/Token.sol";
import "src/interfaces/IVault.sol";
import "src/interfaces/IFactory.sol";
import "src/interfaces/IPool.sol";

contract Example {
    using TokenLib for Token;

    IVault vault = IVault(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535);

    uint8 constant SWAP = 0;
    uint8 constant GAUGE = 1;

    uint8 constant EXACTLY = 0;
    uint8 constant AT_MOST = 1;
    uint8 constant ALL = 2;

    function run() external {
        address usdc = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;
        address vc = 0xcc22F6AA610D1b2a0e89EF228079cB3e1831b1D1;
        address eth = address(0);
        address usdc_eth_pool = vault.getPair(usdc, eth);
        address usdc_eth_lp = usdc_eth_pool;

        IERC20(0x176211869cA2b568f2A7D4EE941E073a821EE1ff).approve(address(vault), type(uint256).max);
        // you can optimize gas by batching operations.
        // this example will execute them separately for clarity

        //swap usdc->eth
        vault.execute2(usdc_eth_pool, SWAP, usdc, EXACTLY, 0.1e6, eth, AT_MOST, 0, "");

        //add lp and stake
        vault.execute3{value: 0.001e18}(
            usdc_eth_pool, SWAP, usdc, EXACTLY, 0.1e6, eth, EXACTLY, 0.001e18, usdc_eth_lp, AT_MOST, 0, ""
        );
        vault.execute2(
            usdc_eth_pool,
            GAUGE,
            usdc_eth_lp,
            EXACTLY,
            int128(int256(IERC20(usdc_eth_lp).balanceOf(address(this)))),
            vc,
            AT_MOST,
            0,
            ""
        );
    }
}
