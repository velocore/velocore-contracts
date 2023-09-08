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
import "src/sale/VelocoreGirls.sol";
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

        VelocoreGirls(0xB63A18241A49398eA1e959B5a115e87d424C16eE).upgradeTo(
            address(new VelocoreGirls(IVault(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535), 0xB63A18241A49398eA1e959B5a115e87d424C16eE))
        );
        VelocoreGirls2(0x71bb6DeE96cB736B93ACD51Efb563050496290C5).upgradeTo(
            address(new VelocoreGirls2(IVault(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535), 0x71bb6DeE96cB736B93ACD51Efb563050496290C5))
        );

        vm.stopBroadcast();
    }

}
