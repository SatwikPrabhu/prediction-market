// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Quick-dispute-window variant for demos
contract OracleManagerQuick is AccessControl, ReentrancyGuard {
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
        address[] voters;
    }

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant DISPUTE_ROLE = keccak256("DISPUTE_ROLE");

    uint256 public constant REQUIRED_CONFIRMATIONS = 2;
    uint256 public constant DISPUTE_WINDOW = 60; // 60 seconds for demo

    mapping(uint256 => MarketResolution) public marketResolutions;
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

    function addOracle(address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!isOracle[oracle], "already oracle");
        _grantRole(ORACLE_ROLE, oracle);
        isOracle[oracle] = true;
        emit OracleAdded(oracle);
    }

    function submitResolution(uint256 marketId, Outcome outcome, bool invalid) external onlyRole(ORACLE_ROLE) {
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
        resolution.voters.push(msg.sender);
        resolution.confirmations++;
        emit OracleVoted(marketId, msg.sender, outcome);

        if (resolution.confirmations >= REQUIRED_CONFIRMATIONS) {
            resolution.disputeWindow = block.timestamp + DISPUTE_WINDOW;
        }
    }

    function finalizeResolution(uint256 marketId) external onlyRole(ORACLE_ROLE) {
        MarketResolution storage resolution = marketResolutions[marketId];
        require(resolution.confirmations >= REQUIRED_CONFIRMATIONS, "insufficient confirmations");
        require(block.timestamp >= resolution.disputeWindow, "dispute window active");
        require(!resolution.isResolved, "already resolved");

        Outcome finalOutcome = _determineMajorityOutcome(marketId);
        bool isInvalid = (finalOutcome == Outcome.NONE);
        resolution.isResolved = true;
        resolution.finalOutcome = finalOutcome;
        resolution.isInvalid = isInvalid;
        emit MarketResolved(marketId, finalOutcome, isInvalid);
    }

    function pushResolutionToMarket(address market, uint256 marketId) external onlyRole(ORACLE_ROLE) nonReentrant {
        require(isRegisteredMarket[market], "market not registered");
        MarketResolution storage resolution = marketResolutions[marketId];
        require(resolution.isResolved, "not finalized");
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

    function _determineMajorityOutcome(uint256 marketId) internal view returns (Outcome) {
        MarketResolution storage resolution = marketResolutions[marketId];
        uint256 yesVotes; uint256 noVotes; uint256 invalidVotes;
        for (uint256 i = 0; i < resolution.voters.length; i++) {
            OracleResolution storage vote = resolution.votes[resolution.voters[i]];
            if (vote.outcome == Outcome.YES) yesVotes++;
            else if (vote.outcome == Outcome.NO) noVotes++;
            else invalidVotes++;
        }
        if (invalidVotes > yesVotes && invalidVotes > noVotes) return Outcome.NONE;
        if (yesVotes > noVotes) return Outcome.YES;
        if (noVotes > yesVotes) return Outcome.NO;
        return Outcome.NONE;
    }
}


