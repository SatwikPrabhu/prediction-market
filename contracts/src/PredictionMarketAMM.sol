// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PredictionMarketAMM is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Outcome { NONE, YES, NO }

    struct Market {
        string question;
        uint64 endTime;
        bool resolved;
        bool invalid;
        Outcome winningOutcome;
        uint16 feeBps; // e.g., 100 = 1%
        uint256 protocolFeesAccrued;
        // AMM Pools
        uint256 yesLiquidity;  // Settlement token in YES pool
        uint256 noLiquidity;   // Settlement token in NO pool
        // User balances (internal accounting)
        mapping(address => uint256) yesBalance;
        mapping(address => uint256) noBalance;
    }

    IERC20 public immutable settlementToken;

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant LIQUIDITY_PROVIDER_ROLE = keccak256("LIQUIDITY_PROVIDER_ROLE");

    // Optional external oracle manager allowed to resolve markets via resolveFromOracle
    address public oracleManager;

    Market[] private markets;

    event MarketCreated(uint256 indexed marketId, string question, uint64 endTime, uint16 feeBps);
    event Bought(
        uint256 indexed marketId,
        address indexed user,
        Outcome outcome,
        uint256 amountIn,
        uint256 sharesOut,
        uint256 fee,
        uint256 newYesLiquidity,
        uint256 newNoLiquidity
    );
    event Resolved(uint256 indexed marketId, Outcome winningOutcome, bool invalid);
    event Claimed(
        uint256 indexed marketId,
        address indexed user,
        uint256 payout
    );
    event FeesWithdrawn(address indexed to, uint256 amount);
    event LiquidityAdded(
        uint256 indexed marketId,
        address indexed provider,
        uint256 yesAmount,
        uint256 noAmount
    );
    event OracleManagerUpdated(address indexed oracleManager);

    constructor(address admin, IERC20 _settlementToken) {
        settlementToken = _settlementToken;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_ROLE, admin);
        _grantRole(LIQUIDITY_PROVIDER_ROLE, admin);
    }

    function setOracleManager(address _oracleManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        oracleManager = _oracleManager;
        emit OracleManagerUpdated(_oracleManager);
    }

    function numMarkets() external view returns (uint256) {
        return markets.length;
    }

    function getMarket(uint256 marketId)
        external
        view
        returns (
            string memory question,
            uint64 endTime,
            bool resolved,
            bool invalid,
            Outcome winningOutcome,
            uint16 feeBps,
            uint256 protocolFeesAccrued,
            uint256 yesLiquidity,
            uint256 noLiquidity
        )
    {
        Market storage m = markets[marketId];
        return (
            m.question,
            m.endTime,
            m.resolved,
            m.invalid,
            m.winningOutcome,
            m.feeBps,
            m.protocolFeesAccrued,
            m.yesLiquidity,
            m.noLiquidity
        );
    }

    function getBalances(uint256 marketId, address user)
        external
        view
        returns (uint256 yesShares, uint256 noShares)
    {
        Market storage m = markets[marketId];
        return (m.yesBalance[user], m.noBalance[user]);
    }

    function createMarket(
        string calldata question,
        uint64 endTime,
        uint16 feeBps,
        uint256 initialLiquidity
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 marketId) {
        require(endTime > block.timestamp, "endTime past");
        require(feeBps <= 1000, "fee too high"); // max 10%
        require(initialLiquidity > 0, "liquidity required");

        marketId = markets.length;
        Market storage m = markets.push();
        m.question = question;
        m.endTime = endTime;
        m.feeBps = feeBps;

        // Initialize AMM pools with equal liquidity (50/50 initial price)
        uint256 halfLiquidity = initialLiquidity / 2;
        m.yesLiquidity = halfLiquidity;
        m.noLiquidity = halfLiquidity;

        // Transfer initial liquidity from admin
        settlementToken.safeTransferFrom(msg.sender, address(this), initialLiquidity);

        emit MarketCreated(marketId, question, endTime, feeBps);
        emit LiquidityAdded(marketId, msg.sender, halfLiquidity, halfLiquidity);
    }

    function buy(
        uint256 marketId,
        Outcome outcome,
        uint256 amountIn
    ) external nonReentrant {
        require(marketId < markets.length, "bad id");
        require(outcome == Outcome.YES || outcome == Outcome.NO, "bad outcome");
        Market storage m = markets[marketId];
        require(block.timestamp < m.endTime, "trading ended");
        require(amountIn > 0, "zero amount");

        // Calculate fee
        uint256 fee = (amountIn * m.feeBps) / 10_000;
        uint256 amountAfterFee = amountIn - fee;

        // Calculate AMM pricing
        (uint256 sharesOut, uint256 newYesLiquidity, uint256 newNoLiquidity) = 
            calculateAMMPricing(marketId, outcome, amountAfterFee);

        // Transfer tokens from user
        settlementToken.safeTransferFrom(msg.sender, address(this), amountIn);

        // Update pools
        m.yesLiquidity = newYesLiquidity;
        m.noLiquidity = newNoLiquidity;

        // Update user balances
        if (outcome == Outcome.YES) {
            m.yesBalance[msg.sender] += sharesOut;
        } else {
            m.noBalance[msg.sender] += sharesOut;
        }

        // Track fees
        m.protocolFeesAccrued += fee;

        emit Bought(marketId, msg.sender, outcome, amountIn, sharesOut, fee, newYesLiquidity, newNoLiquidity);
    }

    function calculateAMMPricing(
        uint256 marketId,
        Outcome outcome,
        uint256 amountIn
    ) public view returns (uint256 sharesOut, uint256 newYesLiquidity, uint256 newNoLiquidity) {
        Market storage m = markets[marketId];
        
        if (outcome == Outcome.YES) {
            // Buying YES shares: add liquidity to YES pool, remove from NO pool
            newYesLiquidity = m.yesLiquidity + amountIn;
            newNoLiquidity = (m.yesLiquidity * m.noLiquidity) / newYesLiquidity; // Maintain k = x*y
            sharesOut = m.noLiquidity - newNoLiquidity;
        } else {
            // Buying NO shares: add liquidity to NO pool, remove from YES pool
            newNoLiquidity = m.noLiquidity + amountIn;
            newYesLiquidity = (m.yesLiquidity * m.noLiquidity) / newNoLiquidity; // Maintain k = x*y
            sharesOut = m.yesLiquidity - newYesLiquidity;
        }
    }

    function getCurrentPrice(uint256 marketId, Outcome outcome) external view returns (uint256 price) {
        Market storage m = markets[marketId];
        
        if (outcome == Outcome.YES) {
            // Price of YES = NO liquidity / YES liquidity
            price = (m.noLiquidity * 1e18) / m.yesLiquidity;
        } else {
            // Price of NO = YES liquidity / NO liquidity
            price = (m.yesLiquidity * 1e18) / m.noLiquidity;
        }
    }

    function resolve(
        uint256 marketId,
        Outcome winningOutcome,
        bool invalid
    ) external onlyRole(ORACLE_ROLE) {
        _resolve(marketId, winningOutcome, invalid);
    }

    // Called by the external OracleManager contract after finalization
    function resolveFromOracle(
        uint256 marketId,
        Outcome winningOutcome,
        bool invalid
    ) external {
        require(msg.sender == oracleManager, "not oracle mgr");
        _resolve(marketId, winningOutcome, invalid);
    }

    function _resolve(
        uint256 marketId,
        Outcome winningOutcome,
        bool invalid
    ) internal {
        require(marketId < markets.length, "bad id");
        require(winningOutcome == Outcome.YES || winningOutcome == Outcome.NO || invalid, "bad win");
        Market storage m = markets[marketId];
        require(!m.resolved, "resolved");
        require(block.timestamp >= m.endTime, "before end");

        m.resolved = true;
        m.invalid = invalid;
        m.winningOutcome = invalid ? Outcome.NONE : winningOutcome;

        emit Resolved(marketId, m.winningOutcome, invalid);
    }

    function claim(uint256 marketId) external nonReentrant {
        require(marketId < markets.length, "bad id");
        Market storage m = markets[marketId];
        require(m.resolved, "not resolved");

        uint256 payout;
        uint256 yesBal = m.yesBalance[msg.sender];
        uint256 noBal = m.noBalance[msg.sender];

        if (m.invalid) {
            // Refund both sides fully
            payout = yesBal + noBal;
            m.yesBalance[msg.sender] = 0;
            m.noBalance[msg.sender] = 0;
        } else if (m.winningOutcome == Outcome.YES) {
            require(yesBal > 0, "no win bal");
            payout = yesBal;
            m.yesBalance[msg.sender] = 0;
        } else {
            require(noBal > 0, "no win bal");
            payout = noBal;
            m.noBalance[msg.sender] = 0;
        }

        settlementToken.safeTransfer(msg.sender, payout);
        emit Claimed(marketId, msg.sender, payout);
    }

    function withdrawFees(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "to zero");
        uint256 accrued = _totalFeesAccrued();
        require(amount <= accrued, "exceeds fees");
        _decreaseAccrued(amount);
        settlementToken.safeTransfer(to, amount);
        emit FeesWithdrawn(to, amount);
    }

    // --- Internal fee accounting ---
    function _totalFeesAccrued() internal view returns (uint256 total) {
        uint256 len = markets.length;
        for (uint256 i = 0; i < len; i++) {
            total += markets[i].protocolFeesAccrued;
        }
    }

    function _decreaseAccrued(uint256 amount) internal {
        uint256 remaining = amount;
        uint256 len = markets.length;
        for (uint256 i = 0; i < len && remaining > 0; i++) {
            uint256 fees = markets[i].protocolFeesAccrued;
            if (fees == 0) continue;
            uint256 dec = fees > remaining ? remaining : fees;
            markets[i].protocolFeesAccrued = fees - dec;
            remaining -= dec;
        }
        require(remaining == 0, "accounting err");
    }
}
