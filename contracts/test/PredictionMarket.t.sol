// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {USDToken} from "../src/USDToken.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";
import {OracleManager} from "../src/OracleManager.sol";

contract PredictionMarketTest is Test {
    USDToken token;
    PredictionMarket market;
    OracleManager oracle;
    address admin = address(0xA);
    address alice = address(0xB);

    function setUp() public {
        token = new USDToken(admin);
        market = new PredictionMarket(admin, token);
        oracle = new OracleManager(admin);

        // Wire oracle manager to market
        vm.startPrank(admin);
        market.setOracleManager(address(oracle));
        oracle.registerMarket(address(market));
        vm.stopPrank();

        vm.startPrank(admin);
        token.mint(alice, 1_000_000e6);
        vm.stopPrank();
    }

    function testBuyResolveClaimYes() public {
        // Admin creates a market
        vm.prank(admin);
        uint256 id = market.createMarket("Will it rain?", uint64(block.timestamp + 1 days), 100);

        // Alice approves and buys YES
        vm.startPrank(alice);
        token.approve(address(market), type(uint256).max);
        market.buy(id, PredictionMarket.Outcome.YES, 100e6); // 1% fee -> 99e6 shares
        vm.stopPrank();

        // Fast-forward time and resolve YES
        vm.warp(block.timestamp + 2 days);
        // Multi-sig flow: oracles vote and finalize, then push to market
        address oracle1 = address(0x111);
        address oracle2 = address(0x222);
        vm.startPrank(admin);
        oracle.addOracle(oracle1);
        oracle.addOracle(oracle2);
        vm.stopPrank();

        vm.prank(oracle1);
        oracle.submitResolution(id, OracleManager.Outcome.YES, false);
        vm.prank(oracle2);
        oracle.submitResolution(id, OracleManager.Outcome.YES, false);

        vm.warp(block.timestamp + 25 hours);
        vm.prank(oracle1);
        oracle.finalizeResolution(id);
        vm.prank(oracle1);
        oracle.pushResolutionToMarket(address(market), id);

        // Alice claims
        uint256 balBefore = token.balanceOf(alice);
        vm.prank(alice);
        market.claim(id);
        uint256 balAfter = token.balanceOf(alice);

        assertEq(balAfter - balBefore, 99e6, "payout should equal shares after fee");
    }

    function testBuyResolveClaimNo() public {
        vm.prank(admin);
        uint256 id = market.createMarket("Will ETH > 5k?", uint64(block.timestamp + 1 days), 200); // 2% fee

        vm.startPrank(alice);
        token.approve(address(market), type(uint256).max);
        market.buy(id, PredictionMarket.Outcome.NO, 200e6); // fee 4e6 -> shares 196e6
        vm.stopPrank();

        vm.warp(block.timestamp + 2 days);
        vm.prank(admin);
        market.resolve(id, PredictionMarket.Outcome.NO, false);

        uint256 balBefore = token.balanceOf(alice);
        vm.prank(alice);
        market.claim(id);
        uint256 balAfter = token.balanceOf(alice);

        assertEq(balAfter - balBefore, 196e6, "NO payout equals shares after fee");
    }

    function testInvalidRefund() public {
        vm.prank(admin);
        uint256 id = market.createMarket("Invalid test?", uint64(block.timestamp + 1 days), 100); // 1%

        vm.startPrank(alice);
        token.approve(address(market), type(uint256).max);
        market.buy(id, PredictionMarket.Outcome.YES, 50e6); // fee 0.5e6 -> 49.5e6 shares
        vm.stopPrank();

        vm.warp(block.timestamp + 2 days);
        vm.prank(admin);
        market.resolve(id, PredictionMarket.Outcome.YES, true); // invalid

        uint256 balBefore = token.balanceOf(alice);
        vm.prank(alice);
        market.claim(id);
        uint256 balAfter = token.balanceOf(alice);

        // Refund equals credited shares (amount - fee) under current implementation
        assertEq(balAfter - balBefore, 49_500_000, "invalid refund equals credited shares");
    }

    function testWithdrawFees() public {
        vm.prank(admin);
        uint256 id = market.createMarket("Fees?", uint64(block.timestamp + 1 days), 100); // 1%

        // Alice buys to generate fees
        vm.startPrank(alice);
        token.approve(address(market), type(uint256).max);
        market.buy(id, PredictionMarket.Outcome.YES, 1_000_000); // 1 USDT (6dps). fee=10_000
        vm.stopPrank();

        // Admin withdraws fees before resolution
        uint256 adminBefore = token.balanceOf(admin);
        vm.prank(admin);
        market.withdrawFees(admin, 10_000);
        uint256 adminAfter = token.balanceOf(admin);

        assertEq(adminAfter - adminBefore, 10_000, "admin received exact fees");
    }
}
