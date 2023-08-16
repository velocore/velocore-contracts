// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "../src/AdminFacet.sol";
import "../src/SwapFacet.sol";
import "../src/pools/vc/VC.sol";
import "src/pools/vc/VeVC.sol";
import "src/pools/converter/WETHConverter.sol";
import "src/pools/wombat/WombatPool.sol";
import "src/MockERC20.sol";
import "src/lens/Lens.sol";
import "src/NFTHolderFacet.sol";
import "src/lens/VelocoreLens.sol";
import "src/pools/constant-product/ConstantProductPoolFactory.sol";
import "src/pools/constant-product/ConstantProductLibrary.sol";
import "src/pools/linear-bribe/LinearBribeFactory.sol";
import "../src/authorizer/SimpleAuthorizer.sol";
import "./Deployer.sol";
import "./Placeholder.sol";

//address constant oldVC = 0x85D84c774CF8e9fF85342684b0E795Df72A24908;
address constant oldVeVC = 0x0000000000000000000000000000000000000000;

contract DeployScript is Script {
    Deployer deployer;
    Placeholder placeholder_;
    IVault vault;
    VC vc;
    VeVC veVC;
    MockERC20 oldVC;
    WombatPool wombat;
    ConstantProductPoolFactory cpf;
    WETHConverter wethConverter;

    function setUp() public {}

    function run() public returns (IVault, VC, VeVC) {
        deployer = Deployer(0xeC215066585842184656c24D4a4C0D41986c2b57);
        uint256 deployerPrivateKey = vm.envUint("VELOCORE_DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);
        vm.stopBroadcast();
        return (vault, vc, veVC);
    }

    function deployPool(address addr) internal {
        IERC20(addr).approve(address(vault), type(uint256).max);
        cpf.deploy(NATIVE_TOKEN, toToken(IERC20(addr)));
    }

    function run3(
        uint256 value,
        IPool pool,
        uint8 method,
        Token t1,
        Token t2,
        Token t3,
        int128 a1,
        int128 a2,
        int128 a3
    ) public {
        Token[] memory tokens = new Token[](3);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = t1;
        tokens[1] = t2;
        tokens[2] = t3;

        ops[0].poolId = bytes32(bytes1(method)) | bytes32(uint256(uint160(address(pool))));
        ops[0].tokenInformations = new bytes32[](3);
        ops[0].data = "";

        ops[0].tokenInformations[0] = bytes32(bytes2(0x0000) | bytes32(uint256(uint128(uint256(int256(a1))))));
        ops[0].tokenInformations[1] = bytes32(bytes2(0x0100) | bytes32(uint256(uint128(uint256(int256(a2))))));
        ops[0].tokenInformations[2] = bytes32(bytes2(0x0200) | bytes32(uint256(uint128(uint256(int256(a3))))));
        vault.execute{value: value}(tokens, new int128[](3), ops);
    }

    function migrateVC(int128 amount) public {
        Token[] memory tokens = new Token[](2);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = toToken(vc);
        tokens[1] = toToken(oldVC);

        ops[0].poolId = bytes32(uint256(uint160(address(vc))));
        ops[0].tokenInformations = new bytes32[](tokens.length);
        ops[0].data = "";

        ops[0].tokenInformations[0] = bytes32(bytes2(0x0000) | bytes32(uint256(uint128(uint256(int256(-amount))))));
        ops[0].tokenInformations[1] = bytes32(bytes2(0x0100) | bytes32(uint256(uint128(uint256(int256(amount))))));

        vault.execute(tokens, new int128[](2), ops);
    }

    function lockVC(int128 amount) public {
        Token[] memory tokens = new Token[](2);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = toToken(veVC);
        tokens[1] = toToken(vc);

        ops[0].poolId = bytes32(uint256(uint160(address(veVC))));
        ops[0].tokenInformations = new bytes32[](tokens.length);
        ops[0].data = "";

        ops[0].tokenInformations[0] = bytes32(bytes2(0x0000) | bytes32(uint256(uint128(uint256(int256(-amount))))));
        ops[0].tokenInformations[1] = bytes32(bytes2(0x0100) | bytes32(uint256(uint128(uint256(int256(amount))))));

        vault.execute(tokens, new int128[](2), ops);
    }

    function vote(IGauge gauge, int128 amount) public {
        Token[] memory tokens = new Token[](1);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = toToken(veVC);

        ops[0].poolId = bytes32(bytes1(0x03)) | bytes32(uint256(uint160(address(gauge))));
        ops[0].tokenInformations = new bytes32[](tokens.length);
        ops[0].data = "";

        ops[0].tokenInformations[0] = bytes32(bytes2(0x0000) | bytes32(uint256(uint128(uint256(int256(amount))))));

        vault.execute(tokens, new int128[](1), ops);
    }

    function wombatSwap(Token t1, Token t2, int128 a1, int128 a2) public {
        Token[] memory tokens = new Token[](2);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = t1;
        tokens[1] = t2;

        ops[0].poolId = bytes32(uint256(uint160(address(wombat))));
        ops[0].tokenInformations = new bytes32[](tokens.length);
        ops[0].data = "";

        ops[0].tokenInformations[0] = bytes32(bytes2(0x0000) | bytes32(uint256(uint128(uint256(int256(a1))))));
        ops[0].tokenInformations[1] = bytes32(bytes2(0x0100) | bytes32(uint256(uint128(uint256(int256(a2))))));
        vault.execute(tokens, new int128[](2), ops);
    }

    function placeholder() internal returns (address) {
        return deployer.deployAndCall(vm.getCode("DumbProxy.yul:DumbProxy"), abi.encode(placeholder_));
    }
}
