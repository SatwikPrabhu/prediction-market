// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {OracleManagerQuick} from "../src/OracleManagerQuick.sol";

contract DeployOracleManagerQuick is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        vm.startBroadcast(pk);
        OracleManagerQuick omq = new OracleManagerQuick(admin);
        vm.stopBroadcast();

        console2.log("OracleManagerQuick deployed:", address(omq));
        console2.log("Admin:", admin);
    }
}


