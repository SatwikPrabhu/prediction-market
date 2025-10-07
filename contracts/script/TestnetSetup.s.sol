// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {USDToken} from "../src/USDToken.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";

contract TestnetSetup is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        address marketAddr = vm.envAddress("MARKET_ADDRESS");

        vm.startBroadcast(pk);

        USDToken token = USDToken(tokenAddr);
        PredictionMarket market = PredictionMarket(marketAddr);

        // Mint test tokens to admin
        token.mint(msg.sender, 1_000_000e6);
        console2.log("Minted 1,000,000 USDT to admin");

        // Create a sample market ending in 7 days with 1% fee
        uint64 endTime = uint64(block.timestamp + 7 days);
        uint256 marketId = market.createMarket(
            "Will Bitcoin reach $100,000 by end of 2024?", 
            endTime, 
            100 // 1% fee
        );
        console2.log("Created market ID:", marketId);
        console2.log("Market question: Will Bitcoin reach $100,000 by end of 2024?");
        console2.log("Market ends at:", endTime);

        vm.stopBroadcast();
    }
}
