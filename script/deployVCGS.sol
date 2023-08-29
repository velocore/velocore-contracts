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
import "src/authorizer/SimpleAuthorizer.sol";
import "src/sale/VelocoreGirls.sol";
import "src/sale/Airdrop.sol";

//address constant oldVC = 0x85D84c774CF8e9fF85342684b0E795Df72A24908;
address constant oldVeVC = 0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F;

contract Placeholder is ERC1967Upgrade {
    address immutable admin;

    constructor() {
        admin = msg.sender;
    }

    function upgradeTo(address newImplementation) external {
        require(msg.sender == admin, "not admin");
        ERC1967Upgrade._upgradeTo(newImplementation);
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) external {
        require(msg.sender == admin, "not admin");
        ERC1967Upgrade._upgradeToAndCall(newImplementation, data, true);
    }
}

contract Deployer {
    function deployAndCall(bytes memory bytecode, bytes memory cd) external returns (address) {
        address deployed;
        bool success;
        assembly ("memory-safe") {
            deployed := create(0, add(bytecode, 32), mload(bytecode))
            success := call(gas(), deployed, 0, add(cd, 32), mload(cd), 0, 0)
        }
        require(deployed != address(0) && success);
        return deployed;
    }
}

contract UpgradeScript is Script {
    function setUp() public {}

    function run() public returns (IVault, VC, VeVC) {
        uint256 deployerPrivateKey = vm.envUint("VELOCORE_DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        VelocoreGirls vcgs = VelocoreGirls(placeholder());

        Placeholder(address(vcgs)).upgradeToAndCall(
            address(new VelocoreGirls(IVault(0x1d0188c4B276A09366D05d6Be06aF61a73bC7535), address(vcgs))),
            abi.encodeWithSelector(VelocoreGirls.initialize.selector)
        );

        Airdrop airdrop = new Airdrop(vcgs, IERC20(0xcc22F6AA610D1b2a0e89EF228079cB3e1831b1D1), 1693566000, 5184000);
        Airdrop2 airdrop2 = new Airdrop2(vcgs, IERC20(0xAeC06345b26451bdA999d83b361BEaaD6eA93F87), 1693566000, 5184000);
        vcgs.addMinter(address(airdrop));

        console.log(address(vcgs));
        console.log(address(airdrop));
        console.log(address(airdrop2));
        vm.stopBroadcast();
    }

    function grant(address factory, bytes4 selector, address who) internal {
        SimpleAuthorizer(address(0x0978112d4Ea277aD7fbf9F89268DEEdDeB743996)).grantRole(
            keccak256(abi.encodePacked(bytes32(uint256(uint160(address(factory)))), selector)), who
        );
    }

    function placeholder() internal returns (address) {
        Deployer deployer = Deployer(0x61d8b49FA46F747c4512474749dddC1902d6eA9D);
        return deployer.deployAndCall(
            vm.getCode("DumbProxy.yul:DumbProxy"), abi.encode(address(0x3DC531557935fF04F1756ba46319BE90745e52A6))
        );
    }
}
