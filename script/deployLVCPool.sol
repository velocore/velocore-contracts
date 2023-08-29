// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "../src/AdminFacet.sol";
import "../src/SwapFacet.sol";
import "../src/pools/vc/VC.sol";
import "src/pools/vc/VeVC.sol";
import "src/pools/linear-bribe/LinearBribeFactory.sol";
import "src/pools/converter/WETHConverter.sol";
import "src/pools/wombat/WombatPool.sol";
import "src/MockERC20.sol";
import "src/lens/Lens.sol";
import "src/NFTHolderFacet.sol";
import "src/sale/OverflowICO.sol";
import "src/lens/VelocoreLens.sol";
import "src/pools/constant-product/ConstantProductPoolFactory.sol";
import "src/pools/constant-product/ConstantProductLibrary.sol";
import "../src/authorizer/SimpleAuthorizer.sol";

//address constant oldVC = 0x85D84c774CF8e9fF85342684b0E795Df72A24908;
address constant oldVeVC = 0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F;

contract UpgradeScript is Script {
    using TokenLib for Token;

    function setUp() public {}

    function run() public returns (IVault, VC, VeVC) {
        uint256 deployerPrivateKey = vm.envUint("VELOCORE_DEPLOYER");

        uint256 tc = OverflowICO(0xA0d4334152fDd9a8498ad97a67fBC3389814715c).totalCommitments();
        uint256 lpETH = Math.mulDiv(210e18, (4_800_000e18 + Math.mulDiv(21_600_000e18, tc, 450e18)), 26_400_000e18);
        uint256 lpLVC =
            Math.mulDiv(9_600_000e18, (4_800_000e18 + Math.mulDiv(21_600_000e18, tc, 450e18)), 26_400_000e18);
        console.log(lpETH);
        console.log(lpLVC);

        Token vc = toToken(IERC20(0xcc22F6AA610D1b2a0e89EF228079cB3e1831b1D1));
        Token vevc = toToken(IERC20(0xAeC06345b26451bdA999d83b361BEaaD6eA93F87));

        ConstantProductPool vcethpool =
            ConstantProductPoolFactory(0xBe6c6A389b82306e88d74d1692B67285A9db9A47).pools(NATIVE_TOKEN, vc);
        ConstantProductPool vcvevcpool =
            ConstantProductPoolFactory(0xBe6c6A389b82306e88d74d1692B67285A9db9A47).pools(vevc, vc);
        vm.warp(1692961200 + 1);
        vm.startBroadcast(deployerPrivateKey);
        // add voterfactory
        run3(
            lpETH,
            IPool(address(vcethpool)),
            0,
            vc,
            0,
            int128(int256(lpLVC)),
            NATIVE_TOKEN,
            0,
            int128(int256(lpETH)),
            toToken(vcethpool),
            1,
            0
        );
        run3(0, IPool(address(vcvevcpool)), 0, vc, 0, 1_000_000e18, vevc, 0, 1_000_000e18, toToken(vcvevcpool), 1, 0);
        vc.transferFrom(address(this), address(0xdead), 9_600_000e18 - lpLVC);
        vm.stopBroadcast();
    }

    function grant(address factory, bytes4 selector, address who) internal {
        SimpleAuthorizer(address(0x0978112d4Ea277aD7fbf9F89268DEEdDeB743996)).grantRole(
            keccak256(abi.encodePacked(bytes32(uint256(uint160(address(factory)))), selector)), who
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
        IVault(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535).execute{value: value}(tokens, new int128[](3), ops);
    }
}
