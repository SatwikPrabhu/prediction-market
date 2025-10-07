// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {USDToken} from "../src/USDToken.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";

contract AdminActions is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        address marketAddr = vm.envAddress("MARKET_ADDRESS");

        vm.startBroadcast(pk);

        USDToken token = USDToken(tokenAddr);
        PredictionMarket market = PredictionMarket(marketAddr);

        // Mint 1,000,000 units with 6 decimals
        token.mint(admin, 1_000_000e6);
        console2.log("Minted to", admin);

        // Create a market ending in ~24 hours with 1% fee
        uint64 endTime = uint64(block.timestamp + 1 days);
        uint256 id = market.createMarket("Will BTC > $60k by EOM?", endTime, 100);
        console2.log("Created market id", id);

        vm.stopBroadcast();
    }
}
