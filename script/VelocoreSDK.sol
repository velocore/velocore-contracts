pragma solidity ^0.8.19;

import "src/lib/Token.sol";
import "src/interfaces/IVault.sol";
import "src/interfaces/IFactory.sol";
import "src/interfaces/IPool.sol";

contract VelocoreSDK {
    using TokenLib for Token;

    Token constant NATIVE_TOKEN = Token.wrap(0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);

    IVault immutable vault;
    IFactory immutable factory;

    uint8 constant SWAP = 0;
    uint8 constant GAUGE = 1;

    uint8 constant EXACTLY = 0;
    uint8 constant AT_MOST = 1;
    uint8 constant ALL = 1;

    constructor(IVault vault_) {
        vault = vault_;
        factory = IFactory(vault.factory());
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
        vault.execute{value: value}(tokens, new int128[](3), ops);
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
        vault.execute{value: value}(tokens, new int128[](2), ops);
    }
}
