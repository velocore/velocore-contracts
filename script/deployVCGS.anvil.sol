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

contract Airdrop3 is LinearVesting {
    using SafeERC20 for IERC20;

    bytes32 public constant root = 0xf70d938c09046ac1a8cb87317b5150481176d84c30d74cb6c16b69202b52766d;
    VelocoreGirls public immutable girls;

    event ClaimNFT(address addr, uint256 a1, uint256 a2, uint256 a3, uint256 a4);

    constructor(VelocoreGirls girls_, IERC20 rewardToken_, uint256 vestBeginning_, uint256 vestDuration_)
        LinearVesting(rewardToken_, vestBeginning_, vestDuration_)
    {
        girls = girls_;
    }

    function claimNFT(bytes32[] memory proof, bool p1, bool p2, bool p3, bool p4, uint256 airdrop, uint256 premining)
        public
    {
        require(!registered[msg.sender], "Already claimed");

        uint256 total = airdrop;

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, p1, p2, p3, p4, airdrop, premining))));
        require(MerkleProof.verify(proof, root, leaf), "Invalid proof");

        _grantVestedReward(msg.sender, total * 0.465556e18 / 1e18);
    }
}

contract UpgradeScript is Script {
    function setUp() public {}

    function run() public returns (IVault, VC, VeVC) {
        uint256 deployerPrivateKey = vm.envUint("VELOCORE_DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        Airdrop3 airdrop2 =
        new Airdrop3(VelocoreGirls(address(0)), IERC20(0xCE62Ce405e264E85D547d891845Aa975FECa2590), block.timestamp, 5184000);

        IERC20(0xCE62Ce405e264E85D547d891845Aa975FECa2590).transfer(address(airdrop2), 1_000_000e18);

        console.log(address(airdrop2));
        vm.stopBroadcast();
    }

    function grant(address factory, bytes4 selector, address who) internal {
        SimpleAuthorizer(address(0x0978112d4Ea277aD7fbf9F89268DEEdDeB743996)).grantRole(
            keccak256(abi.encodePacked(bytes32(uint256(uint160(address(factory)))), selector)), who
        );
    }

    function placeholder() internal returns (address) {
        Deployer deployer = new Deployer();
        return deployer.deployAndCall(vm.getCode("DumbProxy.yul:DumbProxy"), abi.encode(address(new Placeholder())));
    }
}
