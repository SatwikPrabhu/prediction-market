// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {USDToken} from "../src/USDToken.sol";
import {PredictionMarketAMM} from "../src/PredictionMarketAMM.sol";
import {OracleManager} from "../src/OracleManager.sol";

contract PredictionMarketAMMTest is Test {
    USDToken token;
    PredictionMarketAMM market;
    OracleManager oracle;
    address admin = address(0xA);
    address alice = address(0xB);
    address bob = address(0xC);

    function setUp() public {
        token = new USDToken(admin);
        market = new PredictionMarketAMM(admin, token);
        oracle = new OracleManager(admin);

        // Wire oracle manager to market
        vm.startPrank(admin);
        market.setOracleManager(address(oracle));
        oracle.registerMarket(address(market));
        vm.stopPrank();

        vm.startPrank(admin);
        token.mint(admin, 10_000_000e6); // 10M USDT
        token.mint(alice, 1_000_000e6);  // 1M USDT
        token.mint(bob, 1_000_000e6);    // 1M USDT
        vm.stopPrank();
    }

    function testCreateMarketWithLiquidity() public {
        vm.startPrank(admin);
        token.approve(address(market), 100_000e6);
        
        uint256 marketId = market.createMarket(
            "Will ETH reach $5000?", 
            uint64(block.timestamp + 7 days), 
            100, // 1% fee
            100_000e6 // 100k USDT initial liquidity
        );
        vm.stopPrank();

        // Check market was created with proper liquidity
        (,,,,,,, uint256 yesLiquidity, uint256 noLiquidity) = market.getMarket(marketId);
        assertEq(yesLiquidity, 50_000e6, "YES liquidity should be 50k");
        assertEq(noLiquidity, 50_000e6, "NO liquidity should be 50k");
    }

    function testAMMPricing() public {
        // Create market with liquidity
        vm.startPrank(admin);
        token.approve(address(market), 100_000e6);
        uint256 marketId = market.createMarket(
            "Will BTC reach $100k?", 
            uint64(block.timestamp + 7 days), 
            100, 
            100_000e6
        );
        vm.stopPrank();

        // Test AMM pricing calculation
        (uint256 sharesOut, uint256 newYesLiquidity, uint256 newNoLiquidity) = 
            market.calculateAMMPricing(marketId, PredictionMarketAMM.Outcome.YES, 10_000e6);
        
        // Should get shares based on AMM formula
        assertTrue(sharesOut > 0, "Should get shares");
        assertTrue(newYesLiquidity > 50_000e6, "YES liquidity should increase");
        assertTrue(newNoLiquidity < 50_000e6, "NO liquidity should decrease");
        
        // Check constant product is maintained
        uint256 k = newYesLiquidity * newNoLiquidity;
        uint256 originalK = 50_000e6 * 50_000e6;
        assertTrue(k <= originalK, "K should decrease or stay same (due to fees)");
    }

    function testBuyWithAMM() public {
        // Create market
        vm.startPrank(admin);
        token.approve(address(market), 100_000e6);
        uint256 marketId = market.createMarket(
            "Will ETH reach $5000?", 
            uint64(block.timestamp + 7 days), 
            100, 
            100_000e6
        );
        vm.stopPrank();

        // Alice buys YES shares
        vm.startPrank(alice);
        token.approve(address(market), 10_000e6);
        
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        market.buy(marketId, PredictionMarketAMM.Outcome.YES, 10_000e6);
        uint256 aliceBalanceAfter = token.balanceOf(alice);
        
        // Check Alice's balances
        (uint256 yesShares, uint256 noShares) = market.getBalances(marketId, alice);
        assertTrue(yesShares > 0, "Alice should have YES shares");
        assertEq(noShares, 0, "Alice should have no NO shares");
        
        // Check liquidity pools changed
        (,,,,,,, uint256 yesLiquidity, uint256 noLiquidity) = market.getMarket(marketId);
        assertTrue(yesLiquidity > 50_000e6, "YES liquidity should increase");
        assertTrue(noLiquidity < 50_000e6, "NO liquidity should decrease");
        
        vm.stopPrank();
    }

    function testPriceDiscovery() public {
        // Create market
        vm.startPrank(admin);
        token.approve(address(market), 100_000e6);
        uint256 marketId = market.createMarket(
            "Will BTC reach $100k?", 
            uint64(block.timestamp + 7 days), 
            100, 
            100_000e6
        );
        vm.stopPrank();

        // Get initial price (should be 1:1)
        uint256 initialYesPrice = market.getCurrentPrice(marketId, PredictionMarketAMM.Outcome.YES);
        uint256 initialNoPrice = market.getCurrentPrice(marketId, PredictionMarketAMM.Outcome.NO);
        
        assertEq(initialYesPrice, 1e18, "Initial YES price should be 1.0");
        assertEq(initialNoPrice, 1e18, "Initial NO price should be 1.0");

        // Alice buys YES shares (should make YES more expensive)
        vm.startPrank(alice);
        token.approve(address(market), 20_000e6);
        market.buy(marketId, PredictionMarketAMM.Outcome.YES, 20_000e6);
        vm.stopPrank();

        // Check prices changed
        uint256 newYesPrice = market.getCurrentPrice(marketId, PredictionMarketAMM.Outcome.YES);
        uint256 newNoPrice = market.getCurrentPrice(marketId, PredictionMarketAMM.Outcome.NO);
        
        // When buying YES, YES becomes more expensive (price > 1.0), NO becomes cheaper (price < 1.0)
        assertTrue(newYesPrice < initialYesPrice, "YES price should decrease (becomes more expensive to buy)");
        assertTrue(newNoPrice > initialNoPrice, "NO price should increase (becomes cheaper to buy)");
    }

    function testMultipleTrades() public {
        // Create market
        vm.startPrank(admin);
        token.approve(address(market), 100_000e6);
        uint256 marketId = market.createMarket(
            "Will ETH reach $5000?", 
            uint64(block.timestamp + 7 days), 
            100, 
            100_000e6
        );
        vm.stopPrank();

        // Alice buys YES
        vm.startPrank(alice);
        token.approve(address(market), 10_000e6);
        market.buy(marketId, PredictionMarketAMM.Outcome.YES, 10_000e6);
        vm.stopPrank();

        // Bob buys NO
        vm.startPrank(bob);
        token.approve(address(market), 10_000e6);
        market.buy(marketId, PredictionMarketAMM.Outcome.NO, 10_000e6);
        vm.stopPrank();

        // Check both have shares
        (uint256 aliceYes, uint256 aliceNo) = market.getBalances(marketId, alice);
        (uint256 bobYes, uint256 bobNo) = market.getBalances(marketId, bob);
        
        assertTrue(aliceYes > 0, "Alice should have YES shares");
        assertEq(aliceNo, 0, "Alice should have no NO shares");
        assertEq(bobYes, 0, "Bob should have no YES shares");
        assertTrue(bobNo > 0, "Bob should have NO shares");
    }

    function testResolveAndClaim() public {
        // Create market
        vm.startPrank(admin);
        token.approve(address(market), 100_000e6);
        uint256 marketId = market.createMarket(
            "Will ETH reach $5000?", 
            uint64(block.timestamp + 7 days), 
            100, 
            100_000e6
        );
        vm.stopPrank();

        // Alice buys YES
        vm.startPrank(alice);
        token.approve(address(market), 10_000e6);
        market.buy(marketId, PredictionMarketAMM.Outcome.YES, 10_000e6);
        vm.stopPrank();

        // Fast forward and resolve YES
        vm.warp(block.timestamp + 8 days);
        // Multi-sig flow via oracle manager
        address oracle1 = address(0x111);
        address oracle2 = address(0x222);
        vm.startPrank(admin);
        oracle.addOracle(oracle1);
        oracle.addOracle(oracle2);
        vm.stopPrank();

        vm.prank(oracle1);
        oracle.submitResolution(marketId, OracleManager.Outcome.YES, false);
        vm.prank(oracle2);
        oracle.submitResolution(marketId, OracleManager.Outcome.YES, false);

        vm.warp(block.timestamp + 25 hours);
        vm.prank(oracle1);
        oracle.finalizeResolution(marketId);
        vm.prank(oracle1);
        oracle.pushResolutionToMarket(address(market), marketId);

        // Alice claims
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        market.claim(marketId);
        uint256 aliceBalanceAfter = token.balanceOf(alice);

        assertTrue(aliceBalanceAfter > aliceBalanceBefore, "Alice should receive payout");
    }

    function testInvalidMarketRefund() public {
        // Create market
        vm.startPrank(admin);
        token.approve(address(market), 100_000e6);
        uint256 marketId = market.createMarket(
            "Invalid market?", 
            uint64(block.timestamp + 7 days), 
            100, 
            100_000e6
        );
        vm.stopPrank();

        // Alice buys both YES and NO
        vm.startPrank(alice);
        token.approve(address(market), 20_000e6);
        market.buy(marketId, PredictionMarketAMM.Outcome.YES, 10_000e6);
        market.buy(marketId, PredictionMarketAMM.Outcome.NO, 10_000e6);
        vm.stopPrank();

        // Resolve as invalid
        vm.warp(block.timestamp + 8 days);
        vm.prank(admin);
        market.resolve(marketId, PredictionMarketAMM.Outcome.YES, true);

        // Alice claims (should get refund for both)
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        market.claim(marketId);
        uint256 aliceBalanceAfter = token.balanceOf(alice);

        assertTrue(aliceBalanceAfter > aliceBalanceBefore, "Alice should get refund");
    }

    // --- Access control: admin-only functions ---
    function testOnlyAdminCanCreateMarket() public {
        // Non-admin attempt should revert
        vm.startPrank(alice);
        token.approve(address(market), 100_000e6);
        vm.expectRevert();
        market.createMarket(
            "Non-admin",
            uint64(block.timestamp + 7 days),
            100,
            100_000e6
        );
        vm.stopPrank();

        // Admin can create
        vm.startPrank(admin);
        token.approve(address(market), 100_000e6);
        market.createMarket(
            "Admin",
            uint64(block.timestamp + 7 days),
            100,
            100_000e6
        );
        vm.stopPrank();
    }

    function testOnlyAdminCanSetOracleManager() public {
        // Non-admin cannot set
        vm.prank(alice);
        vm.expectRevert();
        market.setOracleManager(address(0xDEAD));

        // Admin can set
        vm.prank(admin);
        market.setOracleManager(address(0xBEEF));
    }

    // --- Trading window restriction ---
    function testTradingDisabledAfterEndTime() public {
        // Create market ending soon
        vm.startPrank(admin);
        token.approve(address(market), 100_000e6);
        uint256 marketId = market.createMarket(
            "Soon ends",
            uint64(block.timestamp + 1),
            100,
            100_000e6
        );
        vm.stopPrank();

        // Move past endTime
        vm.warp(block.timestamp + 2);

        // Attempt buy should revert
        vm.startPrank(alice);
        token.approve(address(market), 1_000e6);
        vm.expectRevert(bytes("trading ended"));
        market.buy(marketId, PredictionMarketAMM.Outcome.YES, 1_000e6);
        vm.stopPrank();
    }

    // --- Oracle hook authorization ---
    function testResolveFromOracleOnlyOracleManager() public {
        // Create market
        vm.startPrank(admin);
        token.approve(address(market), 100_000e6);
        uint256 marketId = market.createMarket(
            "Oracle hook",
            uint64(block.timestamp + 1 days),
            100,
            100_000e6
        );
        vm.stopPrank();

        // Fast forward to after end
        vm.warp(block.timestamp + 2 days);

        // Random address cannot call resolveFromOracle
        vm.expectRevert(bytes("not oracle mgr"));
        vm.prank(address(0xDEAD));
        market.resolveFromOracle(marketId, PredictionMarketAMM.Outcome.YES, false);

        // Set oracle manager and then it can call
        vm.prank(admin);
        market.setOracleManager(address(oracle));

        vm.prank(address(oracle));
        market.resolveFromOracle(marketId, PredictionMarketAMM.Outcome.NO, false);
    }

    // --- Fee withdrawal permissions and accounting ---
    function testWithdrawFeesAdminOnlyAndAccurate() public {
        // Create market
        vm.startPrank(admin);
        token.approve(address(market), 100_000e6);
        uint256 marketId = market.createMarket(
            "Fees AMM",
            uint64(block.timestamp + 7 days),
            100, // 1%
            100_000e6
        );
        vm.stopPrank();

        // Generate fees via buys
        vm.startPrank(alice);
        token.approve(address(market), 10_000e6);
        market.buy(marketId, PredictionMarketAMM.Outcome.YES, 10_000e6); // fee = 100e6 (1% of 10k USDT)
        vm.stopPrank();

        // Non-admin cannot withdraw
        vm.prank(alice);
        vm.expectRevert();
        market.withdrawFees(alice, 100e6);

        // Admin withdraws exact fee
        uint256 adminBefore = token.balanceOf(admin);
        vm.prank(admin);
        market.withdrawFees(admin, 100e6);
        uint256 adminAfter = token.balanceOf(admin);
        assertEq(adminAfter - adminBefore, 100e6, "admin received accrued fees");
    }

    // --- Claim preconditions ---
    function testClaimRevertsIfNotResolvedOrNoWinningBalance() public {
        // Create market
        vm.startPrank(admin);
        token.approve(address(market), 100_000e6);
        uint256 marketId = market.createMarket(
            "Claim preconditions",
            uint64(block.timestamp + 7 days),
            100,
            100_000e6
        );
        vm.stopPrank();

        // Alice buys YES
        vm.startPrank(alice);
        token.approve(address(market), 1_000e6);
        market.buy(marketId, PredictionMarketAMM.Outcome.YES, 1_000e6);
        vm.stopPrank();

        // Before resolution, claim should revert
        vm.prank(alice);
        vm.expectRevert(bytes("not resolved"));
        market.claim(marketId);

        // After resolution NO wins, YES holder cannot claim
        vm.warp(block.timestamp + 8 days);
        vm.prank(admin);
        market.resolve(marketId, PredictionMarketAMM.Outcome.NO, false);

        vm.prank(alice);
        vm.expectRevert();
        market.claim(marketId);
    }

    // --- AMM invariants / monotonicity ---
    function testAMMMonotonicityAndInvariantApprox() public {
        // Create market
        vm.startPrank(admin);
        token.approve(address(market), 100_000e6);
        uint256 marketId = market.createMarket(
            "Invariant",
            uint64(block.timestamp + 7 days),
            100,
            100_000e6
        );
        vm.stopPrank();

        // Snapshot initial
        (,,,,,,, uint256 yesL0, uint256 noL0) = market.getMarket(marketId);
        uint256 k0 = yesL0 * noL0;

        // YES buy increases YES liquidity and decreases NO liquidity
        (uint256 sharesYes, uint256 yesL1, uint256 noL1) = market.calculateAMMPricing(marketId, PredictionMarketAMM.Outcome.YES, 5_000e6);
        assertTrue(sharesYes > 0, "shares must be > 0");
        assertTrue(yesL1 > yesL0, "YES liquidity increases");
        assertTrue(noL1 < noL0, "NO liquidity decreases");
        assertTrue(yesL1 * noL1 <= k0, "k should not increase");

        // NO buy symmetric
        (uint256 sharesNo, uint256 yesL2, uint256 noL2) = market.calculateAMMPricing(marketId, PredictionMarketAMM.Outcome.NO, 5_000e6);
        assertTrue(sharesNo > 0, "shares must be > 0");
        assertTrue(noL2 > noL0, "NO liquidity increases from baseline");
        assertTrue(yesL2 < yesL0, "YES liquidity decreases from baseline");
        assertTrue(yesL2 * noL2 <= k0, "k should not increase");
    }
}
