// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {USDToken} from "../src/USDToken.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";

contract DeployTestnet is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        
        vm.startBroadcast(pk);

        // Deploy USDToken
        USDToken token = new USDToken(admin);
        console2.log("USDToken deployed to:", address(token));

        // Deploy PredictionMarket
        PredictionMarket market = new PredictionMarket(admin, token);
        console2.log("PredictionMarket deployed to:", address(market));

        vm.stopBroadcast();

        // Log deployment info for documentation
        console2.log("=== DEPLOYMENT COMPLETE ===");
        console2.log("Network: Base Sepolia");
        console2.log("USDToken:", address(token));
        console2.log("PredictionMarket:", address(market));
        console2.log("Admin:", admin);
        console2.log("===========================");
    }
}
