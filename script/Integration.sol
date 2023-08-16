pragma solidity ^0.8.19;

import "src/lib/Token.sol";
import "src/interfaces/IVault.sol";
import "src/interfaces/IFactory.sol";
import "src/interfaces/IPool.sol";

contract Example {
    using TokenLib for Token;

    IVault vault = IVault(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535);
    IFactory factory = IFactory(0xBe6c6A389b82306e88d74d1692B67285A9db9A47);

    uint8 constant SWAP = 0;
    uint8 constant GAUGE = 1;

    uint8 constant EXACTLY = 0;
    uint8 constant AT_MOST = 1;
    uint8 constant ALL = 1;

    function run() external {
        Token usdc = toToken(IERC20(0x176211869cA2b568f2A7D4EE941E073a821EE1ff));
        Token vc = toToken(IERC20(0xcc22F6AA610D1b2a0e89EF228079cB3e1831b1D1));
        Token eth = Token.wrap(0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);
        IPool usdc_eth_pool = IPool(factory.pools(usdc, eth));
        Token usdc_eth_lp = toToken(IERC20(address(usdc_eth_pool)));

        IERC20(0x176211869cA2b568f2A7D4EE941E073a821EE1ff).approve(address(vault), type(uint256).max);
        // you can optimize gas by batching operations.
        // this example will execute them separately for clarity

        //swap usdc->eth
        run2(0, usdc_eth_pool, SWAP, usdc, EXACTLY, 0.1e6, eth, AT_MOST, 0);

        //add lp and stake
        run3(0.001e18, usdc_eth_pool, SWAP, usdc, EXACTLY, 0.1e6, eth, ALL, type(int128).max, usdc_eth_lp, AT_MOST, 0);
        run2(
            0,
            usdc_eth_pool,
            GAUGE,
            usdc_eth_lp,
            EXACTLY,
            int128(int256(usdc_eth_lp.balanceOf(address(this)))),
            vc,
            AT_MOST,
            0
        );
    }

    function run3(
        uint256 value,
        IPool pool,
        uint8 method,
        Token t1,
        uint8 m1,
        int128 a1,
        Token t2,
        uint8 m2,
        int128 a2,
        Token t3,
        uint8 m3,
        int128 a3
    ) public {
        Token[] memory tokens = new Token[](3);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = (t1);
        tokens[1] = (t2);
        tokens[2] = (t3);

        ops[0].poolId = bytes32(bytes1(method)) | bytes32(uint256(uint160(address(pool))));
        ops[0].tokenInformations = new bytes32[](3);
        ops[0].data = "";

        ops[0].tokenInformations[0] =
            bytes32(bytes1(0x00)) | bytes32(bytes2(uint16(m1))) | bytes32(uint256(uint128(uint256(int256(a1)))));
        ops[0].tokenInformations[1] =
            bytes32(bytes1(0x01)) | bytes32(bytes2(uint16(m2))) | bytes32(uint256(uint128(uint256(int256(a2)))));
        ops[0].tokenInformations[2] =
            bytes32(bytes1(0x02)) | bytes32(bytes2(uint16(m3))) | bytes32(uint256(uint128(uint256(int256(a3)))));
        vault.execute{value: value}(tokens, new int128[](3), ops);
    }

    function run2(uint256 value, IPool pool, uint8 method, Token t1, uint8 m1, int128 a1, Token t2, uint8 m2, int128 a2)
        public
    {
        Token[] memory tokens = new Token[](2);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = (t1);
        tokens[1] = (t2);

        ops[0].poolId = bytes32(bytes1(method)) | bytes32(uint256(uint160(address(pool))));
        ops[0].tokenInformations = new bytes32[](2);
        ops[0].data = "";

        ops[0].tokenInformations[0] =
            bytes32(bytes1(0x00)) | bytes32(bytes2(uint16(m1))) | bytes32(uint256(uint128(uint256(int256(a1)))));
        ops[0].tokenInformations[1] =
            bytes32(bytes1(0x01)) | bytes32(bytes2(uint16(m2))) | bytes32(uint256(uint128(uint256(int256(a2)))));
        vault.execute{value: value}(tokens, new int128[](2), ops);
    }
}
