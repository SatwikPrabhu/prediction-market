// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {OracleManager} from "../src/OracleManager.sol";

contract DeployOracleManager is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        vm.startBroadcast(pk);
        OracleManager om = new OracleManager(admin);
        vm.stopBroadcast();

        console2.log("OracleManager deployed:", address(om));
        console2.log("Admin:", admin);
    }
}


