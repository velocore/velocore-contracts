// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/sale/OverflowICO.sol";

//address constant oldVC = 0x85D84c774CF8e9fF85342684b0E795Df72A24908;
address constant oldVeVC = 0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F;

contract DeployICOScript is Script {
    function setUp() public {
        uint256 deployerPrivateKey = vm.envUint("VELOCORE_DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);
        OverflowICO a = new OverflowICO(
            IERC20(0xcc22F6AA610D1b2a0e89EF228079cB3e1831b1D1),
            21_600_000e18,
            450e18,
            150e18,
            1692788400,
            1692961200,
            1692961500,
            1692961500,
            5259486,
            0.3e18,
            0.001e18,
            type(uint256).max,
            IERC20(0xcc22F6AA610D1b2a0e89EF228079cB3e1831b1D1),
            1_000_000e18,
            address(0xdead)
        );
        IERC20(0xcc22F6AA610D1b2a0e89EF228079cB3e1831b1D1).approve(address(a), type(uint256).max);
        a.start();
        vm.stopBroadcast();
        console.log(address(a));
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("VELOCORE_DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        vm.stopBroadcast();
    }
}
