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
import "src/lens/VelocoreLens.sol";
import "src/pools/constant-product/ConstantProductPoolFactory.sol";
import "src/pools/constant-product/ConstantProductLibrary.sol";
import "../src/authorizer/SimpleAuthorizer.sol";

//address constant oldVC = 0x85D84c774CF8e9fF85342684b0E795Df72A24908;
address constant oldVeVC = 0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F;

contract UpgradeScript is Script {
    function setUp() public {}

    function run() public returns (IVault, VC, VeVC) {
        uint256 deployerPrivateKey = vm.envUint("VELOCORE_DEPLOYER");
        ConstantProductPool[] memory pools =
            ConstantProductPoolFactory(0xBe6c6A389b82306e88d74d1692B67285A9db9A47).getPools(0, 1000);

        vm.startBroadcast(deployerPrivateKey);

        ConstantProductPoolFactory(0xBe6c6A389b82306e88d74d1692B67285A9db9A47).setFee(0.003e9);

        for (uint256 i = 0; i < pools.length; i++) {
            pools[i].setParam(0.003e9, 4294955811);
        }

        WombatPool(0x61cb3a0C59825464474Ebb287A3e7D2b9b59D093).setFee(0.0005e18);
        WombatPool(0x131D56758351C9885862ADA09A6a7071735C83b3).setFee(0.0005e18);
        // add voterfactory
        vm.stopBroadcast();
    }

    function grant(address factory, bytes4 selector, address who) internal {
        SimpleAuthorizer(address(0x0978112d4Ea277aD7fbf9F89268DEEdDeB743996)).grantRole(
            keccak256(abi.encodePacked(bytes32(uint256(uint160(address(factory)))), selector)), who
        );
    }
}
