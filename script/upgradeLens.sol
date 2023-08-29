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
        vm.startBroadcast(deployerPrivateKey);
        Lens(0xaA18cDb16a4DD88a59f4c2f45b5c91d009549e06).upgrade(
            address(
                new VelocoreLens(toToken(IERC20(0x176211869cA2b568f2A7D4EE941E073a821EE1ff)), VC(0xcc22F6AA610D1b2a0e89EF228079cB3e1831b1D1), ConstantProductPoolFactory(0xBe6c6A389b82306e88d74d1692B67285A9db9A47), WombatRegistry(0x111A6d7f5dDb85776F1b6A6DEAbe552815559f9E), VelocoreLens(0xaA18cDb16a4DD88a59f4c2f45b5c91d009549e06))
            )
        );
        // add voterfactory
        vm.stopBroadcast();

        VelocoreLens(0xaA18cDb16a4DD88a59f4c2f45b5c91d009549e06).canonicalPools(address(this), 0, 1000);
    }

    function grant(address factory, bytes4 selector, address who) internal {
        SimpleAuthorizer(address(0x0978112d4Ea277aD7fbf9F89268DEEdDeB743996)).grantRole(
            keccak256(abi.encodePacked(bytes32(uint256(uint160(address(factory)))), selector)), who
        );
    }
}
