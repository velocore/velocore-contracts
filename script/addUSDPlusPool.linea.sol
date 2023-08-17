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
import "src/pools/converter/RebaseWrapper.sol";
import "../src/authorizer/SimpleAuthorizer.sol";

//address constant oldVC = 0x85D84c774CF8e9fF85342684b0E795Df72A24908;
address constant oldVeVC = 0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F;

contract UpgradeScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("VELOCORE_DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        RebaseWrapper wUSDp =
        new RebaseWrapper(IVault(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535), toToken(IERC20(0xB79DD08EA68A908A97220C76d19A6aA9cBDE4376)), true);
        RebaseWrapper wUSDTp =
        new RebaseWrapper(IVault(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535), toToken(IERC20(0x1E1F509963A6D33e169D9497b11c7DbFe73B7F13)), true);
        WombatPool wombat =
        new WombatPool(0x111A6d7f5dDb85776F1b6A6DEAbe552815559f9E, IVault(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535), 0.0005e18, 0.00125e18);
        wombat.addToken(toToken(IERC20(0x176211869cA2b568f2A7D4EE941E073a821EE1ff)), 255);
        wombat.addToken(toToken(IERC20(address(wUSDp))), 255);
        wombat.addToken(toToken(IERC20(address(wUSDTp))), 255);

        console.log(address(wUSDp));
        console.log(address(wUSDTp));
        WombatRegistry(0x111A6d7f5dDb85776F1b6A6DEAbe552815559f9E).register(wombat);

        // add voterfactory
        vm.stopBroadcast();
    }

    function grant(address factory, bytes4 selector, address who) internal {
        SimpleAuthorizer(address(0x0978112d4Ea277aD7fbf9F89268DEEdDeB743996)).grantRole(
            keccak256(abi.encodePacked(bytes32(uint256(uint160(address(factory)))), selector)), who
        );
    }
}
