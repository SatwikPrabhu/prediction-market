// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract OracleManager is AccessControl, ReentrancyGuard {
    enum Outcome { NONE, YES, NO }

    struct OracleResolution {
        address oracle;
        Outcome outcome;
        uint256 timestamp;
        bool isDisputed;
    }

    struct MarketResolution {
        uint256 confirmations;
        uint256 disputeWindow;
        bool isResolved;
        Outcome finalOutcome;
        bool isInvalid;
        mapping(address => bool) hasVoted;
        mapping(address => OracleResolution) votes;
        address[] voters; // Track all voters for proper vote counting
    }

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant DISPUTE_ROLE = keccak256("DISPUTE_ROLE");

    uint256 public constant REQUIRED_CONFIRMATIONS = 2;
    uint256 public constant DISPUTE_WINDOW = 24 hours;
    uint256 public constant RESOLUTION_DELAY = 1 hours;

    mapping(uint256 => MarketResolution) public marketResolutions;
    // Registered market contracts that can be resolved by this oracle
    mapping(address => bool) public isRegisteredMarket;
    mapping(address => bool) public isOracle;

    event OracleVoted(uint256 indexed marketId, address indexed oracle, Outcome outcome);
    event MarketResolved(uint256 indexed marketId, Outcome outcome, bool invalid);
    event ResolutionDisputed(uint256 indexed marketId, address indexed disputer);
    event OracleAdded(address indexed oracle);
    event OracleRemoved(address indexed oracle);
    event MarketRegistered(address indexed market);
    event MarketUnregistered(address indexed market);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_ROLE, admin);
        _grantRole(DISPUTE_ROLE, admin);
        isOracle[admin] = true;
    }

    function registerMarket(address market) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(market != address(0), "zero market");
        isRegisteredMarket[market] = true;
        emit MarketRegistered(market);
    }

    function unregisterMarket(address market) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isRegisteredMarket[market] = false;
        emit MarketUnregistered(market);
    }

    function addOracle(address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!isOracle[oracle], "already oracle");
        _grantRole(ORACLE_ROLE, oracle);
        isOracle[oracle] = true;
        emit OracleAdded(oracle);
    }

    function removeOracle(address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isOracle[oracle], "not oracle");
        _revokeRole(ORACLE_ROLE, oracle);
        isOracle[oracle] = false;
        emit OracleRemoved(oracle);
    }

    function submitResolution(
        uint256 marketId,
        Outcome outcome,
        bool invalid
    ) external onlyRole(ORACLE_ROLE) {
        require(isOracle[msg.sender], "not oracle");
        require(outcome == Outcome.YES || outcome == Outcome.NO || invalid, "invalid outcome");
        
        MarketResolution storage resolution = marketResolutions[marketId];
        require(!resolution.hasVoted[msg.sender], "already voted");
        require(!resolution.isResolved, "already resolved");

        resolution.hasVoted[msg.sender] = true;
        resolution.votes[msg.sender] = OracleResolution({
            oracle: msg.sender,
            outcome: outcome,
            timestamp: block.timestamp,
            isDisputed: false
        });
        
        // Track voter for proper vote counting
        resolution.voters.push(msg.sender);
        resolution.confirmations++;

        emit OracleVoted(marketId, msg.sender, outcome);

        // Check if we have enough confirmations
        if (resolution.confirmations >= REQUIRED_CONFIRMATIONS) {
            resolution.disputeWindow = block.timestamp + DISPUTE_WINDOW;
        }
    }

    function finalizeResolution(uint256 marketId) external onlyRole(ORACLE_ROLE) {
        MarketResolution storage resolution = marketResolutions[marketId];
        require(resolution.confirmations >= REQUIRED_CONFIRMATIONS, "insufficient confirmations");
        require(block.timestamp >= resolution.disputeWindow, "dispute window active");
        require(!resolution.isResolved, "already resolved");

        // Determine final outcome based on majority vote
        Outcome finalOutcome = _determineMajorityOutcome(marketId);
        bool isInvalid = (finalOutcome == Outcome.NONE);

        resolution.isResolved = true;
        resolution.finalOutcome = finalOutcome;
        resolution.isInvalid = isInvalid;

        emit MarketResolved(marketId, finalOutcome, isInvalid);
    }

    // Resolve a specific registered market contract on-chain using the finalized outcome
    function pushResolutionToMarket(address market, uint256 marketId) external onlyRole(ORACLE_ROLE) nonReentrant {
        require(isRegisteredMarket[market], "market not registered");
        MarketResolution storage resolution = marketResolutions[marketId];
        require(resolution.isResolved, "not finalized");

        // Call resolveFromOracle on the market contract
        (bool ok, ) = market.call(
            abi.encodeWithSignature(
                "resolveFromOracle(uint256,uint8,bool)",
                marketId,
                uint8(resolution.finalOutcome),
                resolution.isInvalid
            )
        );
        require(ok, "market resolve failed");
    }

    function disputeResolution(uint256 marketId) external onlyRole(DISPUTE_ROLE) {
        MarketResolution storage resolution = marketResolutions[marketId];
        require(resolution.confirmations >= REQUIRED_CONFIRMATIONS, "no resolution to dispute");
        require(block.timestamp < resolution.disputeWindow, "dispute window closed");
        require(!resolution.isResolved, "already resolved");

        // Reset resolution to allow new votes
        resolution.confirmations = 0;
        resolution.disputeWindow = 0;
        
        // Clear all votes
        // Clear all votes by resetting the voters array and confirmations
        delete marketResolutions[marketId].voters;
        marketResolutions[marketId].confirmations = 0;

        emit ResolutionDisputed(marketId, msg.sender);
    }

    function getResolutionStatus(uint256 marketId) external view returns (
        uint256 confirmations,
        uint256 disputeWindow,
        bool isResolved,
        Outcome finalOutcome,
        bool isInvalid
    ) {
        MarketResolution storage resolution = marketResolutions[marketId];
        return (
            resolution.confirmations,
            resolution.disputeWindow,
            resolution.isResolved,
            resolution.finalOutcome,
            resolution.isInvalid
        );
    }

    function getOracleVote(uint256 marketId, address oracle) external view returns (
        Outcome outcome,
        uint256 timestamp,
        bool isDisputed
    ) {
        OracleResolution storage vote = marketResolutions[marketId].votes[oracle];
        return (vote.outcome, vote.timestamp, vote.isDisputed);
    }

    function _determineMajorityOutcome(uint256 marketId) internal view returns (Outcome) {
        MarketResolution storage resolution = marketResolutions[marketId];
        
        uint256 yesVotes = 0;
        uint256 noVotes = 0;
        uint256 invalidVotes = 0;

        // Count votes by iterating through all voters
        for (uint256 i = 0; i < resolution.voters.length; i++) {
            address voter = resolution.voters[i];
            OracleResolution storage vote = resolution.votes[voter];
            
            if (vote.outcome == Outcome.YES) {
                yesVotes++;
            } else if (vote.outcome == Outcome.NO) {
                noVotes++;
            } else {
                invalidVotes++;
            }
        }

        // Determine majority outcome
        if (invalidVotes > yesVotes && invalidVotes > noVotes) {
            return Outcome.NONE; // Invalid
        } else if (yesVotes > noVotes) {
            return Outcome.YES;
        } else if (noVotes > yesVotes) {
            return Outcome.NO;
        } else {
            // Tie - return NONE for safety
            return Outcome.NONE;
        }
    }
}
