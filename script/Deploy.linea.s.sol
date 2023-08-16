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
        uint256 deployerPrivateKey = vm.envUint("VELOCORE_DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);
        deployer = new Deployer();
        placeholder_ = new Placeholder();
        IAuthorizer auth = new SimpleAuthorizer();
        AdminFacet adminFacet = new AdminFacet(auth, 0x1234561fEd41DD2D867a038bBdB857f291864225);
        vault = IVault(adminFacet.deploy(vm.getCode("Diamond.yul:Diamond")));
        vc = VC(placeholder());
        veVC = VeVC(placeholder());
        oldVC = new MockERC20("Velocore", "VC (old)");
        WombatRegistry reg = new WombatRegistry(vault);
        wombat = new WombatPool(address(reg), vault, 0.01e18, 0.00025e18);
        reg.register(wombat);
        wethConverter = new WETHConverter(vault, IWETH(0x2C1b868d6596a18e32E61B901E4060C872647b6C));
        LinearBribeFactory lbf = new LinearBribeFactory(vault);
        lbf.setFeeToken(toToken(veVC));
        lbf.setFeeAmount(1e18);

        SimpleAuthorizer(address(auth)).grantRole(
            keccak256(abi.encodePacked(bytes32(uint256(uint160(address(vault)))), IVault.attachBribe.selector)),
            address(lbf)
        );
        oldVC.mint(200000000e18);
        oldVC.mint(20000000000e18);
        oldVC.approve(address(vault), type(uint256).max);

        ConstantProductLibrary cpl = new ConstantProductLibrary();

        cpf = new ConstantProductPoolFactory(vault, cpl);
        cpf.setFee(0.01e9);
        VelocoreLens lens = VelocoreLens(address(new Lens(vault)));

        Lens(address(lens)).upgrade(
            address(
                new VelocoreLens(toToken(IERC20(0xf56dc6695cF1f5c364eDEbC7Dc7077ac9B586068)), vc, ConstantProductPoolFactory(address(cpf)), reg)
            )
        );

        vault.admin_addFacet(new SwapFacet(vc, toToken(veVC)));
        vault.admin_addFacet(new NFTHolderFacet());

        Placeholder(address(vc)).upgradeToAndCall(
            address(new VC(address(vc), vault, toToken(IERC20(oldVC)), address(veVC))),
            abi.encodeWithSelector(VC.initialize.selector)
        );

        Placeholder(address(veVC)).upgradeToAndCall(
            address(new VeVC(address(veVC), vault, IVotingEscrow(oldVeVC), vc)),
            abi.encodeWithSelector(VeVC.initialize.selector)
        );
        IERC20(0x7d43AABC515C356145049227CeE54B608342c0ad).approve(address(vault), type(uint256).max);
        IERC20(0x8741Ba6225A6BF91f9D73531A98A89807857a2B3).approve(address(vault), type(uint256).max);
        IERC20(0xf56dc6695cF1f5c364eDEbC7Dc7077ac9B586068).approve(address(vault), type(uint256).max);
        IERC20(0x1990BC6dfe2ef605Bfc08f5A23564dB75642Ad73).approve(address(vault), type(uint256).max);

        migrateVC(1000000e18);
        lockVC(10000e18);

        deployPool(0xeEfF322f4590A1A84BB3486d4BA0038669A811aD);
        deployPool(0xD2340c4ec834bf43c05B9EcCd60EeD3a20892Dcc);
        deployPool(0xa55C7E1274bE5db2275a0BDd055f81e8263b7954);
        deployPool(0x265B25e22bcd7f10a5bD6E6410F10537Cc7567e8);
        deployPool(0x5471ea8f739dd37E9B81Be9c5c77754D8AA953E4);
        deployPool(0x384b939A2A99D50150823dcCA91167aCe716Ad5b);
        deployPool(0xDbcd5BafBAA8c1B326f14EC0c8B125DB57A5cC4c);
        deployPool(address(vc));

        wombat.addToken(toToken(IERC20(0x7d43AABC515C356145049227CeE54B608342c0ad)), 255);
        wombat.addToken(toToken(IERC20(0x8741Ba6225A6BF91f9D73531A98A89807857a2B3)), 255);
        wombat.addToken(toToken(IERC20(0xf56dc6695cF1f5c364eDEbC7Dc7077ac9B586068)), 255);
        wombat.addToken(toToken(IERC20(0x1990BC6dfe2ef605Bfc08f5A23564dB75642Ad73)), 255);
        wombat.setApprovalForAll(address(vault), true);
        wombatSwap(wombat.listedTokens()[0], wombat.lpTokens()[0], 1e6, type(int128).max);
        wombatSwap(wombat.listedTokens()[1], wombat.lpTokens()[1], 1e6, type(int128).max);
        wombatSwap(wombat.listedTokens()[2], wombat.lpTokens()[2], 1e6, type(int128).max);
        wombatSwap(wombat.listedTokens()[3], wombat.lpTokens()[3], 1e6, type(int128).max);
        vm.stopBroadcast();
        lens.wombatGauges(address(this));

        console.log("authorizer: %s", address(auth));
        console.log("IVault: %s", address(vault));
        console.log("Lens: %s", address(lens));

        console.log("cpf: %s", address(cpf));
        console.log("wombatR: %s", address(reg));
        console.log("oldvc: %s", address(oldVC));
        console.log("vc: %s", address(vc));
        console.log("veVC: %s", address(veVC));
        console.log("WETHConverter: %s", address(wethConverter));
        console.log("LinearBribeFactory: %s", address(lbf));

        return (vault, vc, veVC);
    }

    function deployPool(address addr) internal {
        IERC20(addr).approve(address(vault), type(uint256).max);
        cpf.deploy(NATIVE_TOKEN, toToken(IERC20(addr)));
        vote(cpf.pools(NATIVE_TOKEN, toToken(IERC20(addr))), 100e18);
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
