// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "script/Deploy.generic.s.sol";
import "src/MockERC20.sol";
import "src/pools/constant-product/ConstantProductPool.sol";
import "src/pools/constant-product/ConstantProductLibrary.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockVC is IVC, ERC20 {
    constructor() ERC20("lol", "lol") {}
    function notifyMigration(uint128 n) external {}

    function dispense() external override returns (uint256) {
        _mint(msg.sender, 1e18 * 100);
        return 1e18 * 100;
    }

    function emissionRate() external view override returns (uint256) {}
}

contract ConstantProductPoolTest is Test {
    using TokenLib for Token;

    MockERC20 public usdc;
    MockERC20 public btc;
    ConstantProductPool pool;

    Token usdcT;
    Token btcT;
    Token poolT;

    DeployScript v;

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC");
        btc = new MockERC20("BTC", "BTC");

        v = new DeployScript();
        v.run();

        usdc.mint(type(uint128).max);
        btc.mint(type(uint128).max);
        usdc.approve(address(v.vault()), type(uint256).max);
        btc.approve(address(v.vault()), type(uint256).max);

        v.cpf().deploy(toToken(usdc), toToken(btc));

        btcT = toToken(btc);
        usdcT = toToken(usdc);
        pool = v.cpf().pools(toToken(usdc), toToken(btc));
        poolT = toToken(pool);
    }

    function testFuzz_deposit2withdrawAll(uint64 balA, uint64 balB, uint64 balC, uint64 balD) public {
        run3(
            0,
            pool,
            0,
            usdcT,
            0,
            int128(int256(uint256(balA) + 1000000)),
            btcT,
            0,
            int128(int256(uint256(balB) + 1000000)),
            poolT,
            1,
            0
        );
        run3(
            0,
            pool,
            0,
            usdcT,
            0,
            int128(int256(uint256(balC) + 1000000)),
            btcT,
            0,
            int128(int256(uint256(balD) + 1000000)),
            poolT,
            1,
            0
        );
        run3(0, pool, 0, usdcT, 1, 0, btcT, 1, 0, poolT, 0, int128(int256(poolT.balanceOf(address(this)))));
    }

    function testFuzz_depositswapwithdrwal(uint64 balA, uint64 balB, uint64 balC) public {
        run3(
            0,
            pool,
            0,
            usdcT,
            0,
            int128(int256(uint256(balA) + 1000000)),
            btcT,
            0,
            int128(int256(uint256(balB) + 1000000)),
            poolT,
            1,
            0
        );
        run2(
            0,
            pool,
            0,
            usdcT,
            0,
            int128(int256(balA * uint256(balC) / uint256(type(uint64).max))),
            btcT,
            1,
            0
        );
        run3(0, pool, 0, usdcT, 1, 0, btcT, 1, 0, poolT, 0, int128(int256(poolT.balanceOf(address(this)))));
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
    ) internal {
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
        v.vault().execute{value: value}(tokens, new int128[](3), ops);
    }

    function run2(uint256 value, IPool pool, uint8 method, Token t1, uint8 m1, int128 a1, Token t2, uint8 m2, int128 a2)
        internal
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
        v.vault().execute{value: value}(tokens, new int128[](2), ops);
    }
}
