// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {USDToken} from "../src/USDToken.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        address admin = vm.envAddress("ADMIN_ADDRESS");
        USDToken token = new USDToken(admin);
        PredictionMarket market = new PredictionMarket(admin, token);

        // Example: grant roles if needed beyond constructor (constructor already grants to admin)
        // token.grantRole(token.MINTER_ROLE(), admin);

        vm.stopBroadcast();

        // Log addresses
        console2.log("USDToken:", address(token));
        console2.log("PredictionMarket:", address(market));
    }
}
