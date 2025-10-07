// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {USDToken} from "../src/USDToken.sol";
import {PredictionMarketAMM} from "../src/PredictionMarketAMM.sol";

contract DeployAMM is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");

        // Optional params with defaults
        uint256 initialLiquidity = vm.envOr("INITIAL_LIQUIDITY", uint256(1_000_000_000)); // 1,000 USDT (6dp)
        uint64 endTime = uint64(block.timestamp + vm.envOr("END_SECONDS", uint256(7 days)));
        uint16 feeBps = uint16(vm.envOr("FEE_BPS", uint256(100))); // 1%
        string memory question = vm.envOr("QUESTION", string("Will BTC > $60k by EOM?"));

        vm.startBroadcast(pk);

        // Deploy AMM
        PredictionMarketAMM amm = new PredictionMarketAMM(admin, USDToken(tokenAddr));
        console2.log("AMM deployed to:", address(amm));

        // Approve initial liquidity from admin to AMM
        USDToken token = USDToken(tokenAddr);
        token.approve(address(amm), initialLiquidity);
        console2.log("Approved initial liquidity:", initialLiquidity);

        // Create market with seeded liquidity
        uint256 marketId = amm.createMarket(question, endTime, feeBps, initialLiquidity);
        console2.log("Created AMM market ID:", marketId);
        console2.log("Question:", question);
        console2.log("EndTime:", endTime);
        console2.log("FeeBps:", feeBps);

        vm.stopBroadcast();

        console2.log("=== AMM DEPLOY COMPLETE ===");
        console2.log("AMM:", address(amm));
        console2.log("Token:", tokenAddr);
        console2.log("Admin:", admin);
    }
}
