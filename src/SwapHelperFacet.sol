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
import "contracts/pools/constant-product/ConstantProductPoolFactory.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract SwapHelperFacet is VaultStorage, IFacet {
    using UncheckedMemory for Token[];
    using PoolBalanceLib for PoolBalance;

    address immutable thisImplementation;
    ConstantProductPoolFactory public immutable factory;

    constructor(ConstantProductPoolFactory factory_) {
        factory = factory_;
        thisImplementation = address(this);
    }
    /**
     * @dev called by AdminFacet.admin_addFacet().
     * doesnt get added to the routing table, hence the lack of access control.
     */

    function initializeFacet() external {
        _setFunction(SwapHelperFacet(this).execute1.selector, thisImplementation);
        _setFunction(SwapHelperFacet(this).execute2.selector, thisImplementation);
        _setFunction(SwapHelperFacet(this).execute3.selector, thisImplementation);
        _setFunction(SwapHelperFacet(this).query1.selector, thisImplementation);
        _setFunction(SwapHelperFacet(this).query2.selector, thisImplementation);
        _setFunction(SwapHelperFacet(this).query3.selector, thisImplementation);
        _setFunction(SwapHelperFacet(this).swapExactTokensForTokens.selector, thisImplementation);
        _setFunction(SwapHelperFacet(this).swapTokensForExactTokens.selector, thisImplementation);
        _setFunction(SwapHelperFacet(this).swapExactETHForTokens.selector, thisImplementation);
        _setFunction(SwapHelperFacet(this).swapTokensForExactETH.selector, thisImplementation);
        _setFunction(SwapHelperFacet(this).swapExactTokensForETH.selector, thisImplementation);
        _setFunction(SwapHelperFacet(this).swapETHForExactTokens.selector, thisImplementation);
        _setFunction(SwapHelperFacet(this).getPair.selector, thisImplementation);
        _setFunction(SwapHelperFacet(this).allPairs.selector, thisImplementation);
        _setFunction(SwapHelperFacet(this).allPairsLength.selector, thisImplementation);
    }

    function execute1(IPool pool, uint8 method, address t1, uint8 m1, int128 a1, bytes memory data)
        public
        payable
        returns (int128[] memory)
    {
        Token[] memory tokens = new Token[](1);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = t1 == address(0) ? NATIVE_TOKEN : toToken(IERC20(t1));

        ops[0].poolId = bytes32(bytes1(method)) | bytes32(uint256(uint160(address(pool))));
        ops[0].tokenInformations = new bytes32[](1);
        ops[0].data = data;

        ops[0].tokenInformations[0] =
            bytes32(bytes1(0x00)) | bytes32(bytes2(uint16(m1))) | bytes32(uint256(uint128(uint256(int256(a1)))));
        return execute(tokens, new int128[](1), ops);
    }

    function query1(IPool pool, uint8 method, address t1, uint8 m1, int128 a1, bytes memory data)
        public
        returns (int128[] memory)
    {
        Token[] memory tokens = new Token[](1);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = t1 == address(0) ? NATIVE_TOKEN : toToken(IERC20(t1));

        ops[0].poolId = bytes32(bytes1(method)) | bytes32(uint256(uint160(address(pool))));
        ops[0].tokenInformations = new bytes32[](1);
        ops[0].data = data;

        ops[0].tokenInformations[0] =
            bytes32(bytes1(0x00)) | bytes32(bytes2(uint16(m1))) | bytes32(uint256(uint128(uint256(int256(a1)))));
        return query(tokens, new int128[](1), ops);
    }

    function execute2(
        IPool pool,
        uint8 method,
        address t1,
        uint8 m1,
        int128 a1,
        address t2,
        uint8 m2,
        int128 a2,
        bytes memory data
    ) public payable returns (int128[] memory) {
        Token[] memory tokens = new Token[](2);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = t1 == address(0) ? NATIVE_TOKEN : toToken(IERC20(t1));
        tokens[1] = t2 == address(0) ? NATIVE_TOKEN : toToken(IERC20(t2));

        ops[0].poolId = bytes32(bytes1(method)) | bytes32(uint256(uint160(address(pool))));
        ops[0].tokenInformations = new bytes32[](2);
        ops[0].data = data;

        ops[0].tokenInformations[0] =
            bytes32(bytes1(0x00)) | bytes32(bytes2(uint16(m1))) | bytes32(uint256(uint128(uint256(int256(a1)))));
        ops[0].tokenInformations[1] =
            bytes32(bytes1(0x01)) | bytes32(bytes2(uint16(m2))) | bytes32(uint256(uint128(uint256(int256(a2)))));
        return execute(tokens, new int128[](2), ops);
    }

    function query2(
        IPool pool,
        uint8 method,
        address t1,
        uint8 m1,
        int128 a1,
        address t2,
        uint8 m2,
        int128 a2,
        bytes memory data
    ) public returns (int128[] memory) {
        Token[] memory tokens = new Token[](2);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = t1 == address(0) ? NATIVE_TOKEN : toToken(IERC20(t1));
        tokens[1] = t2 == address(0) ? NATIVE_TOKEN : toToken(IERC20(t2));

        ops[0].poolId = bytes32(bytes1(method)) | bytes32(uint256(uint160(address(pool))));
        ops[0].tokenInformations = new bytes32[](2);
        ops[0].data = data;

        ops[0].tokenInformations[0] =
            bytes32(bytes1(0x00)) | bytes32(bytes2(uint16(m1))) | bytes32(uint256(uint128(uint256(int256(a1)))));
        ops[0].tokenInformations[1] =
            bytes32(bytes1(0x01)) | bytes32(bytes2(uint16(m2))) | bytes32(uint256(uint128(uint256(int256(a2)))));
        return query(tokens, new int128[](2), ops);
    }

    function execute3(
        IPool pool,
        uint8 method,
        address t1,
        uint8 m1,
        int128 a1,
        address t2,
        uint8 m2,
        int128 a2,
        address t3,
        uint8 m3,
        int128 a3,
        bytes memory data
    ) public payable returns (int128[] memory) {
        Token[] memory tokens = new Token[](3);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = t1 == address(0) ? NATIVE_TOKEN : toToken(IERC20(t1));
        tokens[1] = t2 == address(0) ? NATIVE_TOKEN : toToken(IERC20(t2));
        tokens[2] = t3 == address(0) ? NATIVE_TOKEN : toToken(IERC20(t3));

        ops[0].poolId = bytes32(bytes1(method)) | bytes32(uint256(uint160(address(pool))));
        ops[0].tokenInformations = new bytes32[](3);
        ops[0].data = data;

        ops[0].tokenInformations[0] =
            bytes32(bytes1(0x00)) | bytes32(bytes2(uint16(m1))) | bytes32(uint256(uint128(uint256(int256(a1)))));
        ops[0].tokenInformations[1] =
            bytes32(bytes1(0x01)) | bytes32(bytes2(uint16(m2))) | bytes32(uint256(uint128(uint256(int256(a2)))));
        ops[0].tokenInformations[2] =
            bytes32(bytes1(0x02)) | bytes32(bytes2(uint16(m3))) | bytes32(uint256(uint128(uint256(int256(a3)))));
        return execute(tokens, new int128[](3), ops);
    }

    function query3(
        IPool pool,
        uint8 method,
        address t1,
        uint8 m1,
        int128 a1,
        address t2,
        uint8 m2,
        int128 a2,
        address t3,
        uint8 m3,
        int128 a3,
        bytes memory data
    ) public returns (int128[] memory) {
        Token[] memory tokens = new Token[](3);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = t1 == address(0) ? NATIVE_TOKEN : toToken(IERC20(t1));
        tokens[1] = t2 == address(0) ? NATIVE_TOKEN : toToken(IERC20(t2));
        tokens[2] = t3 == address(0) ? NATIVE_TOKEN : toToken(IERC20(t3));

        ops[0].poolId = bytes32(bytes1(method)) | bytes32(uint256(uint160(address(pool))));
        ops[0].tokenInformations = new bytes32[](3);
        ops[0].data = data;

        ops[0].tokenInformations[0] =
            bytes32(bytes1(0x00)) | bytes32(bytes2(uint16(m1))) | bytes32(uint256(uint128(uint256(int256(a1)))));
        ops[0].tokenInformations[1] =
            bytes32(bytes1(0x01)) | bytes32(bytes2(uint16(m2))) | bytes32(uint256(uint128(uint256(int256(a2)))));
        ops[0].tokenInformations[2] =
            bytes32(bytes1(0x02)) | bytes32(bytes2(uint16(m3))) | bytes32(uint256(uint128(uint256(int256(a3)))));
        return query(tokens, new int128[](3), ops);
    }

    function execute(Token[] memory tokens, int128[] memory deposits, VelocoreOperation[] memory ops)
        internal
        returns (int128[] memory ret)
    {
        bytes memory cd = abi.encodeWithSelector(IVault.execute.selector, tokens, deposits, ops);
        ret = new int128[](tokens.length);
        uint256 len = tokens.length * 32;
        assembly {
            let success := delegatecall(gas(), address(), add(cd, 32), mload(cd), 0, 0)

            if iszero(success) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            returndatacopy(ret, 32, add(32, len))
        }
    }

    function query(Token[] memory tokens, int128[] memory deposits, VelocoreOperation[] memory ops)
        internal
        returns (int128[] memory ret)
    {
        bytes memory cd = abi.encodeWithSelector(IVault.query.selector, msg.sender, tokens, deposits, ops);
        ret = new int128[](tokens.length);
        uint256 len = tokens.length * 32;
        assembly {
            let success := delegatecall(gas(), address(), add(cd, 32), mload(cd), 0, 0)

            if iszero(success) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            returndatacopy(ret, 32, add(32, len))
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) public returns (uint256[] memory amounts) {
        require(to == msg.sender, "'to' must be msg.sender");
        require(deadline > block.timestamp, "deadline");
        require(path.length >= 2 && path.length < 256, "invalid path length");
        require(
            amountIn < uint256(int256(type(int128).max)) && amountOutMin < uint256(int256(type(int128).max)) - 1,
            "invalid path length"
        );
        Token[] memory tokens;
        assembly {
            tokens := path
        }

        VelocoreOperation[] memory ops = new VelocoreOperation[](path.length - 1);

        for (uint256 i = 0; i < path.length; i++) {
            if (path[i] == address(0)) {
                tokens.u(i, NATIVE_TOKEN);
            }
        }
        for (uint256 i = 0; i < ops.length; i++) {
            ops[i].poolId = bytes32(uint256(uint160(address(factory.pools(tokens.u(i), tokens.u(i + 1))))));
            ops[i].tokenInformations = new bytes32[](2);
            ops[i].data = "";

            ops[i].tokenInformations[0] = bytes32(bytes1(uint8(i))) | bytes32(bytes2(uint16(2)))
                | bytes32(uint256(uint128(uint256(int256(type(int128).max)))));
            ops[i].tokenInformations[1] = bytes32(bytes1(uint8(i + 1))) | bytes32(bytes2(uint16(1)));
        }

        ops[ops.length - 1].tokenInformations[1] = bytes32(bytes1(uint8(ops.length))) | bytes32(bytes2(uint16(1)))
            | bytes32(uint256(uint128(uint256(-int256(amountOutMin)))));

        int128[] memory deposit = new int128[](tokens.length);

        deposit[0] = int128(int256(amountIn));

        amounts = new uint256[](tokens.length);

        amounts[tokens.length - 1] = uint256(int256(execute(tokens, deposit, ops)[tokens.length - 1]));
        amounts[0] = amountIn;
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) public returns (uint256[] memory amounts) {
        require(to == msg.sender, "'to' must be msg.sender");
        require(deadline > block.timestamp, "deadline");
        require(path.length >= 2 && path.length < 256, "invalid path length");
        require(
            amountInMax < uint256(int256(type(int128).max)) && amountOut < uint256(int256(type(int128).max)) - 1,
            "invalid path length"
        );
        Token[] memory tokens;
        assembly {
            tokens := path
        }

        VelocoreOperation[] memory ops = new VelocoreOperation[](path.length - 1);

        for (uint256 i = 0; i < path.length; i++) {
            if (path[i] == address(0)) {
                tokens.u(i, NATIVE_TOKEN);
            }
        }
        for (uint256 i = 0; i < ops.length; i++) {
            ops[i].poolId = bytes32(
                uint256(uint160(address(factory.pools(tokens.u(ops.length - i - 1), tokens.u(ops.length - i)))))
            );
            ops[i].tokenInformations = new bytes32[](2);
            ops[i].data = "";

            ops[i].tokenInformations[0] = bytes32(bytes1(uint8(ops.length - i - 1))) | bytes32(bytes2(uint16(1)))
                | bytes32(uint256(uint128(uint256(int256(type(int128).max)))));
            ops[i].tokenInformations[1] = bytes32(bytes1(uint8(ops.length - i))) | bytes32(bytes2(uint16(2)));
        }

        ops[ops.length - 1].tokenInformations[0] = bytes32(bytes1(uint8(0))) | bytes32(bytes2(uint16(1)))
            | bytes32(uint256(uint128(uint256(int256(amountInMax)))));
        ops[0].tokenInformations[1] = bytes32(bytes1(uint8(ops.length))) | bytes32(bytes2(uint16(0)))
            | bytes32(uint256(uint128(uint256(-int256(amountOut)))));

        int128[] memory deposit = new int128[](tokens.length);

        amounts = new uint256[](tokens.length);

        amounts[0] = uint256(int256(execute(tokens, deposit, ops)[0]));
        amounts[tokens.length - 1] = amountOut;
    }

    function swapExactETHForTokens(uint256 amountOutMin, address[] memory path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts)
    {
        require(to == msg.sender, "'to' must be msg.sender");
        require(deadline > block.timestamp, "deadline");
        require(path.length >= 2 && path.length < 256, "invalid path length");
        require(
            msg.value < uint256(int256(type(int128).max)) && amountOutMin < uint256(int256(type(int128).max)) - 1,
            "invalid path length"
        );
        Token[] memory tokens;
        assembly {
            tokens := path
        }

        VelocoreOperation[] memory ops = new VelocoreOperation[](path.length - 1);

        for (uint256 i = 0; i < path.length; i++) {
            if (path[i] == address(0)) {
                tokens.u(i, NATIVE_TOKEN);
            }
        }
        for (uint256 i = 0; i < ops.length; i++) {
            ops[i].poolId = bytes32(uint256(uint160(address(factory.pools(tokens.u(i), tokens.u(i + 1))))));
            ops[i].tokenInformations = new bytes32[](2);
            ops[i].data = "";

            ops[i].tokenInformations[0] = bytes32(bytes1(uint8(i))) | bytes32(bytes2(uint16(2)))
                | bytes32(uint256(uint128(uint256(int256(type(int128).max)))));
            ops[i].tokenInformations[1] = bytes32(bytes1(uint8(i + 1))) | bytes32(bytes2(uint16(1)));
        }

        ops[ops.length - 1].tokenInformations[1] = bytes32(bytes1(uint8(ops.length))) | bytes32(bytes2(uint16(1)))
            | bytes32(uint256(uint128(uint256(-int256(amountOutMin)))));

        int128[] memory deposit = new int128[](tokens.length);

        amounts = new uint256[](tokens.length);

        amounts[tokens.length - 1] = uint256(int256(execute(tokens, deposit, ops)[tokens.length - 1]));
        amounts[0] = msg.value;
    }

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        return swapTokensForExactTokens(amountOut, amountInMax, path, to, deadline);
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        return swapTokensForExactTokens(amountIn, amountOutMin, path, to, deadline);
    }

    function swapETHForExactTokens(uint256 amountOut, address[] memory path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts)
    {
        require(to == msg.sender, "'to' must be msg.sender");
        require(deadline > block.timestamp, "deadline");
        require(path.length >= 2 && path.length < 256, "invalid path length");
        require(
            msg.value < uint256(int256(type(int128).max)) && amountOut < uint256(int256(type(int128).max)) - 1,
            "invalid path length"
        );
        Token[] memory tokens;
        assembly {
            tokens := path
        }

        VelocoreOperation[] memory ops = new VelocoreOperation[](path.length - 1);

        for (uint256 i = 0; i < path.length; i++) {
            if (path[i] == address(0)) {
                tokens.u(i, NATIVE_TOKEN);
            }
        }
        for (uint256 i = 0; i < ops.length; i++) {
            ops[i].poolId = bytes32(
                uint256(uint160(address(factory.pools(tokens.u(ops.length - i - 1), tokens.u(ops.length - i)))))
            );
            ops[i].tokenInformations = new bytes32[](2);
            ops[i].data = "";

            ops[i].tokenInformations[0] = bytes32(bytes1(uint8(ops.length - i - 1))) | bytes32(bytes2(uint16(1)))
                | bytes32(uint256(uint128(uint256(int256(type(int128).max)))));
            ops[i].tokenInformations[1] = bytes32(bytes1(uint8(ops.length - i))) | bytes32(bytes2(uint16(2)));
        }

        ops[ops.length - 1].tokenInformations[0] = bytes32(bytes1(uint8(0))) | bytes32(bytes2(uint16(1)))
            | bytes32(uint256(uint128(uint256(int256(msg.value)))));
        ops[0].tokenInformations[1] = bytes32(bytes1(uint8(ops.length))) | bytes32(bytes2(uint16(0)))
            | bytes32(uint256(uint128(uint256(-int256(amountOut)))));

        int128[] memory deposit = new int128[](tokens.length);

        amounts = new uint256[](tokens.length);

        amounts[0] = uint256(int256(execute(tokens, deposit, ops)[0]));
        amounts[tokens.length - 1] = amountOut;
    }

    function getAmountsOut(uint256 amountIn, address[] memory path) external returns (uint256[] memory amounts) {
        Token[] memory tokens;
        assembly {
            tokens := path
        }

        VelocoreOperation[] memory ops = new VelocoreOperation[](path.length - 1);

        for (uint256 i = 0; i < path.length; i++) {
            if (path[i] == address(0)) {
                tokens.u(i, NATIVE_TOKEN);
            }
        }
        for (uint256 i = 0; i < ops.length; i++) {
            ops[i].poolId = bytes32(uint256(uint160(address(factory.pools(tokens.u(i), tokens.u(i + 1))))));
            ops[i].tokenInformations = new bytes32[](2);
            ops[i].data = "";

            ops[i].tokenInformations[0] = bytes32(bytes1(uint8(i))) | bytes32(bytes2(uint16(2)))
                | bytes32(uint256(uint128(uint256(int256(type(int128).max)))));
            ops[i].tokenInformations[1] = bytes32(bytes1(uint8(i + 1))) | bytes32(bytes2(uint16(1)));
        }

        int128[] memory deposit = new int128[](tokens.length);

        deposit[0] = int128(int256(amountIn));

        amounts = new uint256[](tokens.length);

        amounts[tokens.length - 1] = uint256(int256(query(tokens, deposit, ops)[tokens.length - 1]));
        amounts[0] = amountIn;
    }

    function getAmountsIn(uint256 amountOut, address[] memory path) external returns (uint256[] memory amounts) {
        Token[] memory tokens;
        assembly {
            tokens := path
        }

        VelocoreOperation[] memory ops = new VelocoreOperation[](path.length - 1);

        for (uint256 i = 0; i < path.length; i++) {
            if (path[i] == address(0)) {
                tokens.u(i, NATIVE_TOKEN);
            }
        }
        for (uint256 i = 0; i < ops.length; i++) {
            ops[i].poolId = bytes32(
                uint256(uint160(address(factory.pools(tokens.u(ops.length - i - 1), tokens.u(ops.length - i)))))
            );
            ops[i].tokenInformations = new bytes32[](2);
            ops[i].data = "";

            ops[i].tokenInformations[0] = bytes32(bytes1(uint8(ops.length - i - 1))) | bytes32(bytes2(uint16(1)))
                | bytes32(uint256(uint128(uint256(int256(type(int128).max)))));
            ops[i].tokenInformations[1] = bytes32(bytes1(uint8(ops.length - i))) | bytes32(bytes2(uint16(2)));
        }

        ops[0].tokenInformations[1] = bytes32(bytes1(uint8(ops.length))) | bytes32(bytes2(uint16(0)))
            | bytes32(uint256(uint128(uint256(-int256(amountOut)))));

        int128[] memory deposit = new int128[](tokens.length);

        amounts = new uint256[](tokens.length);

        amounts[0] = uint256(int256(query(tokens, deposit, ops)[0]));
        amounts[tokens.length - 1] = amountOut;
    }

    function getPair(address t0, address t1) external view returns (address) {
        return address(
            factory.pools(
                t0 == address(0) ? NATIVE_TOKEN : toToken(IERC20(t0)),
                t1 == address(0) ? NATIVE_TOKEN : toToken(IERC20(t1))
            )
        );
    }

    function allPairs(uint256 i) external view returns (address) {
        return address(factory.poolList(i));
    }

    function allPairsLength() external view returns (uint256) {
        return factory.poolsLength();
    }
}
