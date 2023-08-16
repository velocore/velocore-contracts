// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/MockERC20.sol";

contract DeployMockScript is Script {
    function setUp() public {}

    function run() public returns (MockERC20, MockERC20, MockERC20, MockERC20) {
        uint256 deployerPrivateKey = vm.envUint("VELOCORE_DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        MockERC20 usdc = new MockERC20("USD Coin", "USDC");
        MockERC20 usdt = new MockERC20("Tether", "USDT");
        MockERC20 btc = new MockERC20("Bitcoin", "BTC");
        MockERC20 pepe = new MockERC20("Pepe", "PEPE");

        usdc.mint(100000e18);
        usdc.mint(100000e18);
        usdc.transfer(0x12345206bb098B4E4B899732A6221d39e8721Fb9, 100000e18);

        usdt.mint(100000e18);
        usdt.mint(100000e18);
        usdt.transfer(0x12345206bb098B4E4B899732A6221d39e8721Fb9, 100000e18);

        btc.mint(10e18);
        btc.mint(10e18);
        btc.transfer(0x12345206bb098B4E4B899732A6221d39e8721Fb9, 1e18);

        pepe.mint(1000e36);
        pepe.mint(1000e36);
        pepe.transfer(0x12345206bb098B4E4B899732A6221d39e8721Fb9, 1000e36);

        vm.stopBroadcast();
        return (usdc, usdt, btc, pepe);
    }
}
