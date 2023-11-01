// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "../src/AdminFacet.sol";
import "../src/SwapFacet.sol";
import "../src/SwapAuxillaryFacet.sol";
import "../src/pools/vc/LVC.sol";
import "src/pools/vc/VeVC.sol";
import "src/pools/linear-bribe/LinearBribeFactory.sol";
import "src/pools/converter/WETHConverter.sol";
import "src/pools/wombat/WombatPool.sol";
import "src/MockERC20.sol";
import "src/lens/Lens.sol";
import "src/NFTHolderFacet.sol";
import "src/InspectorFacet.sol";
import "src/lens/VelocoreLens.sol";
import "src/pools/constant-product/ConstantProductPoolFactory.sol";
import "src/pools/constant-product/ConstantProductLibrary.sol";
import "src/sale/VoterFactory.sol";

//address constant oldVC = 0x85D84c774CF8e9fF85342684b0E795Df72A24908;
address constant oldVeVC = 0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F;

contract UpgradeScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("VELOCORE_DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        WombatRegistry reg = WombatRegistry(0x111A6d7f5dDb85776F1b6A6DEAbe552815559f9E);
        IVault vault = IVault(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535);
        WombatPool wombat = new WombatPool(address(reg), vault, 0.0005e18, 0.00125e18);
        wombat.addToken(toToken(IERC20(0x68592c5c98C4F4A8a4bC6dA2121E65Da3d1c0917)), 255);
        wombat.addToken(toToken(IERC20(0x176211869cA2b568f2A7D4EE941E073a821EE1ff)), 255);
        reg.register(wombat);
        vm.stopBroadcast();
    }
}
