// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "../src/AdminFacet.sol";
import "../src/SwapFacet.sol";
import "../src/SwapAuxillaryFacet.sol";
import "../src/pools/vc/LVC.sol";
import "../src/InspectorFacet.sol";
import "src/pools/vc/VeVC.sol";
import "src/pools/converter/WETHConverter.sol";
import "src/pools/linear-bribe/LinearBribeFactory.sol";
import "src/pools/wombat/WombatPool.sol";
import "src/pools/converter/RebaseWrapper.sol";
import "src/MockERC20.sol";
import "src/lens/Lens.sol";
import "src/NFTHolderFacet.sol";
import "src/sale/VoterFactory.sol";
import "src/lens/VelocoreLens.sol";
import "src/pools/constant-product/ConstantProductPoolFactory.sol";
import "src/pools/constant-product/ConstantProductLibrary.sol";
import "../src/authorizer/SimpleAuthorizer.sol";

contract WETH9 is IWETH {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8 public decimals = 18;

    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        (bool success,) = msg.sender.call{value: wad}("");
        require(success);
        emit Withdrawal(msg.sender, wad);
    }

    function totalSupply() public view returns (uint256) {
        return address(this).balance;
    }

    function approve(address guy, uint256 wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint256 wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint256 wad) public returns (bool) {
        require(balanceOf[src] >= wad);

        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }
}

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
    WETH9 weth;
    WETHConverter wethConverter;
    LinearBribeFactory lbf;

    function setUp() public {}

    function run() public returns (IVault, VC, VeVC) {
        uint256 deployerPrivateKey = vm.envUint("VELOCORE_DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);
        deployer = new Deployer();

        placeholder_ = new Placeholder();
        IAuthorizer auth = new SimpleAuthorizer();
        AdminFacet adminFacet = new AdminFacet(auth, 0x1234561fEd41DD2D867a038bBdB857f291864225);
        vault = IVault(adminFacet.deploy(vm.getCode("Diamond.yul:Diamond")));
        VelocoreLens lens = VelocoreLens(placeholder());
        ConstantProductPoolFactory cpf = ConstantProductPoolFactory(placeholder());
        vc = VC(placeholder());
        veVC = VeVC(placeholder());
        oldVC = new MockERC20("Velocore", "VC (old)");
        placeholder();
        weth = new WETH9();
        wethConverter = new WETHConverter(vault, weth);
        lbf = new LinearBribeFactory(vault);
        WombatRegistry wombatRegistry = new WombatRegistry(vault);

        VoterFactory vf = new VoterFactory(vault, toToken(veVC));

        MockERC20 busd = new MockERC20("cBUSD", "cBUSD");
        MockERC20 dai = new MockERC20("DAI", "DAI");
        MockERC20 axlUSDC = new MockERC20("Axelar USDC", "axlUSDC");

        RebaseWrapper rw = new RebaseWrapper(vault, toToken(dai), true);
        RebaseWrapper rw2 = new RebaseWrapper(vault, toToken(IERC20(0xb7A4C531ca096C4b36E754663a76173287E34eE0)), true);

        busd.mint(100000e18);
        busd.mint(100000e18);
        busd.transfer(0x12345206bb098B4E4B899732A6221d39e8721Fb9, 100000e18);

        dai.mint(100000e18);
        dai.mint(100000e18);
        dai.transfer(0x12345206bb098B4E4B899732A6221d39e8721Fb9, 100000e18);

        axlUSDC.mint(100000e18);
        axlUSDC.mint(100000e18);
        axlUSDC.transfer(0x12345206bb098B4E4B899732A6221d39e8721Fb9, 100000e18);

        lbf.setFeeToken(toToken(veVC));
        lbf.setFeeAmount(1e18);
        oldVC.mint(200000000e18);
        oldVC.mint(20000000000e18);
        oldVC.approve(address(vault), type(uint256).max);
        oldVC.transfer(0x12345206bb098B4E4B899732A6221d39e8721Fb9, 10000000e18);
        ConstantProductLibrary cpl = new ConstantProductLibrary();
        SimpleAuthorizer(address(auth)).grantRole(
            bytes32(0xe9f50993b740a8ba09d8faf797515bfe5a43e1c73f79380e5936592096cdd140), address(lbf)
        );

        Placeholder(address(lens)).upgradeTo(address(new Lens(vault)));
        wombat = new WombatPool(address(wombatRegistry), vault, 0.0001e18, 0.00025e18);

        Lens(address(lens)).upgrade(
            address(
                new VelocoreLens(toToken(IERC20(0xA74f301f527e949bEC8F8c711646BF46fbCb08da)), vc, ConstantProductPoolFactory(address(cpf)), wombatRegistry, VelocoreLens(address(lens)))
            )
        );
        Placeholder(address(cpf)).upgradeTo(address(new ConstantProductPoolFactory(vault, cpl)));
        vault.admin_addFacet(new SwapFacet(vc, toToken(veVC)));
        vault.admin_addFacet(new SwapAuxillaryFacet(vc, toToken(veVC)));
        vault.admin_addFacet(new NFTHolderFacet());
        vault.admin_addFacet(new InspectorFacet());

        Placeholder(address(vc)).upgradeToAndCall(
            address(new LVC(address(vc), vault, toToken(IERC20(oldVC)), address(veVC))),
            abi.encodeWithSelector(VC.initialize.selector)
        );

        Placeholder(address(veVC)).upgradeToAndCall(
            address(new VeVC(address(veVC), vault, IVotingEscrow(oldVeVC), vc)),
            abi.encodeWithSelector(VeVC.initialize.selector)
        );

        vault.admin_setTreasury(0x1234561fEd41DD2D867a038bBdB857f291864225);
        weth.approve(address(vault), type(uint256).max);
        cpf.setFee(0.01e9);
        cpf.setDecay(4294955811);

        cpf.deploy(NATIVE_TOKEN, toToken(IERC20(0xA74f301f527e949bEC8F8c711646BF46fbCb08da)));
        cpf.deploy(NATIVE_TOKEN, toToken(IERC20(0xFfE9fd6a97DEF0e0611993A1ac5cE8E9C70685de)));
        cpf.deploy(NATIVE_TOKEN, toToken(IERC20(0xdF7142eFE69ae90831911D6Ae6A043e80a87DB61)));
        cpf.deploy(NATIVE_TOKEN, toToken(vc));
        cpf.deploy(NATIVE_TOKEN, toToken(IERC20(0xb7A4C531ca096C4b36E754663a76173287E34eE0)));

        Token[] memory aaa = new Token[](2);
        aaa[0] = toToken(vc);
        aaa[1] = toToken(veVC);

        uint256[] memory www = new uint256[](2);
        www[0] = 1;
        www[1] = 4;

        cpf.deploy(toToken(veVC), toToken(vc));
        IERC20(0xA74f301f527e949bEC8F8c711646BF46fbCb08da).approve(address(vault), type(uint256).max);
        IERC20(0xFfE9fd6a97DEF0e0611993A1ac5cE8E9C70685de).approve(address(vault), type(uint256).max);
        IERC20(0xdF7142eFE69ae90831911D6Ae6A043e80a87DB61).approve(address(vault), type(uint256).max);
        IERC20(0xb7A4C531ca096C4b36E754663a76173287E34eE0).approve(address(vault), type(uint256).max);
        run3(
            10e18,
            cpf.pools(NATIVE_TOKEN, toToken(IERC20(0xA74f301f527e949bEC8F8c711646BF46fbCb08da))),
            0,
            toToken(cpf.pools(NATIVE_TOKEN, toToken(IERC20(0xA74f301f527e949bEC8F8c711646BF46fbCb08da)))),
            NATIVE_TOKEN,
            toToken(IERC20(0xA74f301f527e949bEC8F8c711646BF46fbCb08da)),
            type(int128).max,
            10e18,
            20000e18
        );
        run3(
            1e18,
            cpf.pools(NATIVE_TOKEN, toToken(IERC20(0xb7A4C531ca096C4b36E754663a76173287E34eE0))),
            0,
            toToken(cpf.pools(NATIVE_TOKEN, toToken(IERC20(0xb7A4C531ca096C4b36E754663a76173287E34eE0)))),
            toToken(IERC20(0xb7A4C531ca096C4b36E754663a76173287E34eE0)),
            NATIVE_TOKEN,
            type(int128).max,
            100e18,
            1e18
        );
        run3(
            1e18,
            cpf.pools(NATIVE_TOKEN, toToken(IERC20(0xdF7142eFE69ae90831911D6Ae6A043e80a87DB61))),
            0,
            toToken(cpf.pools(NATIVE_TOKEN, toToken(IERC20(0xdF7142eFE69ae90831911D6Ae6A043e80a87DB61)))),
            toToken(IERC20(0xdF7142eFE69ae90831911D6Ae6A043e80a87DB61)),
            NATIVE_TOKEN,
            type(int128).max,
            1e18,
            1e18
        );
        run3(
            1e18,
            cpf.pools(NATIVE_TOKEN, toToken(IERC20(0xFfE9fd6a97DEF0e0611993A1ac5cE8E9C70685de))),
            0,
            toToken(cpf.pools(NATIVE_TOKEN, toToken(IERC20(0xFfE9fd6a97DEF0e0611993A1ac5cE8E9C70685de)))),
            toToken(IERC20(0xFfE9fd6a97DEF0e0611993A1ac5cE8E9C70685de)),
            NATIVE_TOKEN,
            type(int128).max,
            2000000e18,
            1e18
        );

        migrateVC(1000000e18);
        lockVC(10000e18);

        run3(
            1e18,
            cpf.pools(NATIVE_TOKEN, toToken(vc)),
            0,
            toToken(cpf.pools(NATIVE_TOKEN, toToken(vc))),
            toToken(vc),
            NATIVE_TOKEN,
            type(int128).max,
            20000e18,
            1e18
        );

        vc.transfer(0x12345206bb098B4E4B899732A6221d39e8721Fb9, 100e18);
        vc.balanceOf(address(vault));
        wombat.addToken(toToken(IERC20(0xA74f301f527e949bEC8F8c711646BF46fbCb08da)), 18);
        wombat.addToken(toToken(IERC20(address(rw2))), 18);
        wombat.addToken(toToken(IERC20(address(rw))), 18);

        IERC20(0xA74f301f527e949bEC8F8c711646BF46fbCb08da).approve(address(vault), type(uint256).max);
        IERC20(0xb7A4C531ca096C4b36E754663a76173287E34eE0).approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        wombat.setApprovalForAll(address(vault), true);
        WombatPool wombat2 = new WombatPool(address(wombatRegistry), vault, 0.0001e18, 0.00025e18);
        wombat2.setApprovalForAll(address(vault), true);
        wombat2.addToken(toToken(IERC20(0xA74f301f527e949bEC8F8c711646BF46fbCb08da)), 18);
        wombat2.addToken(toToken(busd), 18);

        WombatPool wombat3 = new WombatPool(address(wombatRegistry), vault, 0.0001e18, 0.00025e18);
        wombat3.setApprovalForAll(address(vault), true);
        wombat3.addToken(toToken(IERC20(0xA74f301f527e949bEC8F8c711646BF46fbCb08da)), 18);
        wombat3.addToken(toToken(axlUSDC), 18);

        wombatRegistry.register(wombat);
        wombatRegistry.register(wombat2);
        wombatRegistry.register(wombat3);

        cpf.deploy(
            toToken(IERC20(0xFfE9fd6a97DEF0e0611993A1ac5cE8E9C70685de)),
            toToken(IERC20(0xA74f301f527e949bEC8F8c711646BF46fbCb08da))
        );
        veVC.approve(address(vf), type(uint256).max);
        address voter = vf.deploy(0x12345206bb098B4E4B899732A6221d39e8721Fb9, 100e18);
        dai.approve(address(rw), type(uint256).max);
        dai.mint(100000e18);

        vm.stopBroadcast();
        //vm.stopBroadcast();

        console.log("authorizer: %s", address(auth));
        console.log("IVault: %s", address(vault));
        console.log("Lens: %s", address(lens));

        console.log("cpf: %s", address(cpf));
        console.log("wombat: %s", address(wombat));
        console.log("oldvc: %s", address(oldVC));
        console.log("vc: %s", address(vc));
        console.log("veVC: %s", address(veVC));
        console.log("WETH: %s", address(weth));
        console.log("WETHConverter: %s", address(wethConverter));
        console.log("lbf: %s", address(lbf));
        console.log("voter: %s", voter);
        console.log("rw: %s", address(rw));
        console.log("rw2: %s", address(rw2));

        return (vault, vc, veVC);
    }

    function run2(uint256 value, IPool pool, uint8 method, Token t1, uint8 m1, int128 a1, Token t2, uint8 m2, int128 a2)
        public
    {
        Token[] memory tokens = new Token[](2);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = (t1);
        tokens[1] = (t2);

        ops[0].poolId = bytes32(bytes1(method)) | bytes32(uint256(uint160(address(pool))));
        ops[0].tokenInformations = new bytes32[](2);
        ops[0].data = "";

        ops[0].tokenInformations[0] =
            bytes32(bytes1(0x00)) | bytes32(bytes2(uint16(m1))) | bytes32(uint256(uint128(uint256(int256(a1)))));
        ops[0].tokenInformations[1] =
            bytes32(bytes1(0x01)) | bytes32(bytes2(uint16(m2))) | bytes32(uint256(uint128(uint256(int256(a2)))));
        vault.execute{value: value}(tokens, new int128[](2), ops);
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

    function migrateVC(int128) public {
        Token[] memory tokens = new Token[](1);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = toToken(vc);

        ops[0].poolId = bytes32(uint256(uint160(address(vc))));
        ops[0].tokenInformations = new bytes32[](tokens.length);
        ops[0].data = "";

        ops[0].tokenInformations[0] = bytes32(bytes2(0x0001));

        vault.execute(tokens, new int128[](1), ops);
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

    function attachBribe(IGauge gauge, Token tok) public {
        Token[] memory tokens = new Token[](1);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = toToken(veVC);

        ops[0].poolId = bytes32(uint256(uint160(address(lbf))));
        ops[0].tokenInformations = new bytes32[](1);
        ops[0].data = abi.encode(gauge, tok);

        ops[0].tokenInformations[0] = bytes32(bytes2(0x0000) | bytes32(uint256(uint128(uint256(int256(1e18))))));
        vault.execute(tokens, new int128[](1), ops);
    }

    function addBribe(IGauge gauge, Token tok, uint256 amount) public {
        Token[] memory tokens = new Token[](1);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = tok;

        ops[0].poolId = bytes32(uint256(uint160(address(lbf.bribes(tok)))));
        ops[0].tokenInformations = new bytes32[](1);
        ops[0].data = abi.encode(gauge, block.timestamp + 86400, 0, type(uint32).max - 1, 0);

        ops[0].tokenInformations[0] = bytes32(bytes2(0x0000) | bytes32(amount));
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

    function doConvert(int128 a1, int128 a2) public {
        Token[] memory tokens = new Token[](2);

        VelocoreOperation[] memory ops = new VelocoreOperation[](1);

        tokens[0] = NATIVE_TOKEN;
        tokens[1] = toToken(weth);

        ops[0].poolId = bytes32(bytes1(0x02)) | bytes32(uint256(uint160(address(wethConverter))));
        ops[0].tokenInformations = new bytes32[](tokens.length);
        ops[0].data = "";

        ops[0].tokenInformations[0] = bytes32(bytes2(0x0000) | bytes32(uint256(uint128(uint256(int256(a1))))));
        ops[0].tokenInformations[1] = bytes32(bytes2(0x0100) | bytes32(uint256(uint128(uint256(int256(a2))))));

        int128[] memory a = new int128[](2);
        a[1] = a2;
        vault.execute{value: uint128(a1)}(tokens, a, ops);
    }

    function placeholder() internal returns (address) {
        return deployer.deployAndCall(vm.getCode("DumbProxy.yul:DumbProxy"), abi.encode(placeholder_));
    }
}
