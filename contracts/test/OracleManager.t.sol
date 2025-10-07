// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {OracleManager} from "../src/OracleManager.sol";

contract OracleManagerTest is Test {
    OracleManager oracle;
    address admin = address(0xA);
    address oracle1 = address(0xB);
    address oracle2 = address(0xC);
    address oracle3 = address(0xD);
    address disputer = address(0xE);

    function setUp() public {
        oracle = new OracleManager(admin);
        
        // Add oracles
        vm.startPrank(admin);
        oracle.addOracle(oracle1);
        oracle.addOracle(oracle2);
        oracle.addOracle(oracle3);
        oracle.grantRole(oracle.DISPUTE_ROLE(), disputer);
        vm.stopPrank();
    }

    function testOracleManagement() public {
        // Test adding oracle
        assertTrue(oracle.isOracle(oracle1), "Oracle1 should be oracle");
        assertTrue(oracle.isOracle(oracle2), "Oracle2 should be oracle");
        
        // Test removing oracle
        vm.prank(admin);
        oracle.removeOracle(oracle1);
        assertFalse(oracle.isOracle(oracle1), "Oracle1 should not be oracle");
    }

    function testSubmitResolution() public {
        uint256 marketId = 0;
        
        // Oracle1 votes YES
        vm.prank(oracle1);
        oracle.submitResolution(marketId, OracleManager.Outcome.YES, false);
        
        // Check vote was recorded
        (OracleManager.Outcome outcome, uint256 timestamp, bool isDisputed) = 
            oracle.getOracleVote(marketId, oracle1);
        assertTrue(outcome == OracleManager.Outcome.YES, "Vote should be YES");
        assertTrue(timestamp > 0, "Timestamp should be set");
        assertFalse(isDisputed, "Should not be disputed");
    }

    function testMultipleVotes() public {
        uint256 marketId = 0;
        
        // Oracle1 votes YES
        vm.prank(oracle1);
        oracle.submitResolution(marketId, OracleManager.Outcome.YES, false);
        
        // Oracle2 votes YES
        vm.prank(oracle2);
        oracle.submitResolution(marketId, OracleManager.Outcome.YES, false);
        
        // Check resolution status
        (uint256 confirmations, uint256 disputeWindow, bool isResolved, OracleManager.Outcome finalOutcome, bool isInvalid) = 
            oracle.getResolutionStatus(marketId);
        
        assertEq(confirmations, 2, "Should have 2 confirmations");
        assertTrue(disputeWindow > 0, "Dispute window should be set");
        assertFalse(isResolved, "Should not be resolved yet");
    }

    function testFinalizeResolution() public {
        uint256 marketId = 0;
        
        // Get enough votes
        vm.prank(oracle1);
        oracle.submitResolution(marketId, OracleManager.Outcome.YES, false);
        
        vm.prank(oracle2);
        oracle.submitResolution(marketId, OracleManager.Outcome.YES, false);
        
        // Fast forward past dispute window
        vm.warp(block.timestamp + 25 hours);
        
        // Finalize resolution
        vm.prank(oracle1);
        oracle.finalizeResolution(marketId);
        
        // Check resolution
        (,, bool isResolved, OracleManager.Outcome finalOutcome, bool isInvalid) = 
            oracle.getResolutionStatus(marketId);
        
        assertTrue(isResolved, "Should be resolved");
        assertTrue(finalOutcome == OracleManager.Outcome.YES, "Final outcome should be YES");
        assertFalse(isInvalid, "Should not be invalid");
    }

    function testDisputeResolution() public {
        uint256 marketId = 0;
        
        // Get enough votes
        vm.prank(oracle1);
        oracle.submitResolution(marketId, OracleManager.Outcome.YES, false);
        
        vm.prank(oracle2);
        oracle.submitResolution(marketId, OracleManager.Outcome.YES, false);
        
        // Dispute before finalization
        vm.prank(disputer);
        oracle.disputeResolution(marketId);
        
        // Check resolution was reset
        (uint256 confirmations, uint256 disputeWindow, bool isResolved, OracleManager.Outcome finalOutcome, bool isInvalid) = 
            oracle.getResolutionStatus(marketId);
        
        assertEq(confirmations, 0, "Confirmations should be reset");
        assertEq(disputeWindow, 0, "Dispute window should be reset");
        assertFalse(isResolved, "Should not be resolved");
    }

    function testInvalidResolution() public {
        uint256 marketId = 0;
        
        // Oracle1 votes invalid
        vm.prank(oracle1);
        oracle.submitResolution(marketId, OracleManager.Outcome.NONE, true);
        
        // Oracle2 votes invalid
        vm.prank(oracle2);
        oracle.submitResolution(marketId, OracleManager.Outcome.NONE, true);
        
        // Fast forward and finalize
        vm.warp(block.timestamp + 25 hours);
        vm.prank(oracle1);
        oracle.finalizeResolution(marketId);
        
        // Check resolution
        (,, bool isResolved, OracleManager.Outcome finalOutcome, bool isInvalid) = 
            oracle.getResolutionStatus(marketId);
        
        assertTrue(isResolved, "Should be resolved");
        assertTrue(isInvalid, "Should be invalid");
    }

    function testCannotVoteTwice() public {
        uint256 marketId = 0;
        
        // Oracle1 votes
        vm.prank(oracle1);
        oracle.submitResolution(marketId, OracleManager.Outcome.YES, false);
        
        // Try to vote again
        vm.prank(oracle1);
        vm.expectRevert("already voted");
        oracle.submitResolution(marketId, OracleManager.Outcome.NO, false);
    }

    function testOnlyOracleCanVote() public {
        uint256 marketId = 0;
        
        // Non-oracle tries to vote
        vm.prank(address(0x999));
        vm.expectRevert();
        oracle.submitResolution(marketId, OracleManager.Outcome.YES, false);
    }

    function testOnlyDisputerCanDispute() public {
        uint256 marketId = 0;
        
        // Get enough votes
        vm.prank(oracle1);
        oracle.submitResolution(marketId, OracleManager.Outcome.YES, false);
        
        vm.prank(oracle2);
        oracle.submitResolution(marketId, OracleManager.Outcome.YES, false);
        
        // Non-disputer tries to dispute
        vm.prank(address(0x999));
        vm.expectRevert();
        oracle.disputeResolution(marketId);
    }
}
