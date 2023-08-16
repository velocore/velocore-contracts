// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "../src/AdminFacet.sol";
import "../src/SwapFacet.sol";
import "../src/SwapAuxillaryFacet.sol";
import "../src/pools/vc/VC.sol";
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
import "../src/authorizer/SimpleAuthorizer.sol";

//address constant oldVC = 0x85D84c774CF8e9fF85342684b0E795Df72A24908;
address constant oldVeVC = 0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F;

contract UpgradeScript is Script {
    function setUp() public {}

    function run() public returns (IVault, VC, VeVC) {
        uint256 deployerPrivateKey = vm.envUint("VELOCORE_DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        AdminFacet(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535).admin_addFacet(
            new AdminFacet(IAuthorizer(0x0978112d4Ea277aD7fbf9F89268DEEdDeB743996), address(0))
        );
        AdminFacet(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535).admin_addFacet(
            new SwapFacet(VC(0xcc22F6AA610D1b2a0e89EF228079cB3e1831b1D1), toToken(IERC20(0xAeC06345b26451bdA999d83b361BEaaD6eA93F87)))
        );
        AdminFacet(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535).admin_addFacet(
            new SwapAuxillaryFacet(VC(0xcc22F6AA610D1b2a0e89EF228079cB3e1831b1D1), toToken(IERC20(0xAeC06345b26451bdA999d83b361BEaaD6eA93F87)))
        );
        AdminFacet(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535).admin_addFacet(new NFTHolderFacet());
        AdminFacet(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535).admin_addFacet(new InspectorFacet());
        // add voterfactory
        vm.stopBroadcast();
    }

    function grant(address factory, bytes4 selector, address who) internal {
        SimpleAuthorizer(address(0x0978112d4Ea277aD7fbf9F89268DEEdDeB743996)).grantRole(
            keccak256(abi.encodePacked(bytes32(uint256(uint160(address(factory)))), selector)), who
        );
    }
}
