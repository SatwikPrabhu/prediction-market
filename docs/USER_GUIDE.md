# User Guide - Prediction Market

This guide explains how to use the prediction market system as both a trader and an administrator.

## 🎯 For Traders

### Getting Started

1. **Connect Your Wallet**
   - Open the frontend at `http://localhost:5173`
   - Click "Connect Wallet" in the top right corner
   - Select your preferred wallet (MetaMask, WalletConnect, etc.)
   - Approve the connection request

2. **Get USDT Tokens**
   - For local development: Tokens are automatically minted to your account
   - For testnet: Use the admin scripts to mint tokens to your address

### Trading Process

#### Step 1: Browse Markets
- View all available prediction markets in the "Markets" section
- Each market shows:
  - Question/description
  - Current YES/NO prices
  - Liquidity levels
  - Trading status (open/closed)
  - Time remaining until resolution

#### Step 2: Select a Market
- Click on any market to select it
- View detailed information including:
  - Current prices for YES and NO outcomes
  - Your current balances
  - Market countdown timer

#### Step 3: Buy Positions
1. **Enter Amount**: Type the amount in USDT (6 decimals)
   - Example: `1000000` = 1 USDT
   - Example: `5000000` = 5 USDT

2. **Select Outcome**: Choose either YES or NO

3. **Approve Token** (if needed):
   - Click "Approve" to allow the contract to spend your USDT
   - This is a one-time approval for the contract

4. **Buy Position**:
   - Click "Buy YES" or "Buy NO"
   - Wait for transaction confirmation
   - Your position will be updated in real-time

#### Step 4: Monitor Your Positions
- View your YES/NO balances for each market
- Track current prices and how they change
- Monitor the countdown to market resolution

#### Step 5: Claim Winnings (After Resolution)
1. Wait for the market to be resolved by the oracle
2. If you have winning positions, a "Claim Winnings" button will appear
3. Click to claim your payout in USDT
4. For invalid markets, you'll receive a refund of your original investment

### Understanding Prices

- **Initial Price**: Both YES and NO start at 1.0 (50/50 odds)
- **Dynamic Pricing**: Prices change based on trading activity
- **AMM Formula**: Uses constant-product formula (x*y=k)
- **Price Impact**: Larger trades have more price impact

### Market States

- **Open**: Trading is active, you can buy positions
- **Closed**: Trading has ended, waiting for resolution
- **Resolved**: Outcome determined, you can claim winnings
- **Invalid**: Market was invalidated, refunds available

## 🔧 For Administrators

### Market Creation

#### Using Scripts
```bash
cd contracts
forge script script/AdminActions.s.sol:AdminActions --rpc-url $RPC_URL --broadcast
```

#### Manual Creation
```bash
# Create a new market
cast send $MARKET_ADDRESS "createMarket(string,uint64,uint16,uint256)" \
  "Will BTC reach $100k by end of year?" \
  $(date -d "+30 days" +%s) \
  100 \
  100000000000 \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

### Oracle Management

#### Adding Oracles
```bash
# Add a new oracle
cast send $ORACLE_MANAGER "addOracle(address)" $ORACLE_ADDRESS \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

#### Resolving Markets

1. **Submit Resolution**:
```bash
# Oracle 1 votes YES
cast send $ORACLE_MANAGER "submitResolution(uint256,uint8,bool)" \
  0 1 false --rpc-url $RPC_URL --private-key $ORACLE1_KEY

# Oracle 2 votes YES
cast send $ORACLE_MANAGER "submitResolution(uint256,uint8,bool)" \
  0 1 false --rpc-url $RPC_URL --private-key $ORACLE2_KEY
```

2. **Finalize Resolution**:
```bash
# Wait for dispute window (24 hours)
cast send $ORACLE_MANAGER "finalizeResolution(uint256)" 0 \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

3. **Push to Market**:
```bash
# Push resolution to the market contract
cast send $ORACLE_MANAGER "pushResolutionToMarket(address,uint256)" \
  $MARKET_ADDRESS 0 --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

### Fee Management

#### Withdraw Protocol Fees
```bash
# Withdraw accumulated fees
cast send $MARKET_ADDRESS "withdrawFees(address,uint256)" \
  $ADMIN_ADDRESS $AMOUNT --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## 🔐 Security Best Practices

### Private Key Management
- **NEVER** share your private keys with anyone
- **NEVER** use example keys in production
- **ALWAYS** generate your own secure keys
- **ALWAYS** use environment variables for sensitive data

### Generating Secure Keys
```bash
# Generate a new private key
cast wallet new --unsafe

# Get address for a private key
cast wallet address <private_key>
```

### Secure Deployment
```bash
# Use your own keys
export PRIVATE_KEY=<your_secure_private_key>
export ADMIN_ADDRESS=<your_secure_address>

# Deploy with secure keys
forge script script/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
```

> ⚠️ **Security Warning**: Never use example private keys! See [Security Guide](SECURITY_GUIDE.md) for detailed security practices.

## 🚨 Troubleshooting

### Common Issues

#### Frontend Issues
- **Wallet not connecting**: Ensure you're on the correct network
- **"Transaction failed"**: Check you have enough ETH for gas
- **"Contract not found"**: Verify contract addresses in `.env`

#### Trading Issues
- **"Insufficient allowance"**: Click "Approve" before buying
- **"Trading ended"**: Market has passed its end time
- **"Not resolved"**: Market hasn't been resolved yet

#### Admin Issues
- **"Insufficient funds"**: Get testnet ETH from faucet
- **"Access denied"**: Ensure you're using the admin account
- **"Oracle not found"**: Add oracles before resolving

### Getting Help

1. **Check Logs**: Look at terminal output for error messages
2. **Verify Addresses**: Ensure contract addresses are correct
3. **Network Issues**: Check RPC URL and network connectivity
4. **Dependencies**: Ensure all packages are installed correctly

## 📊 Understanding the System

### AMM Pricing
- Uses constant-product formula: `x * y = k`
- Prices change based on liquidity and trading
- Larger trades have more price impact
- Initial 50/50 odds (1.0 price for both outcomes)

### Oracle Resolution
- Multi-signature system with dispute mechanisms
- Requires 2 confirmations to trigger dispute window
- 24-hour dispute window before finalization
- Can be disputed during the window

### Security Features
- Reentrancy protection on all state changes
- Role-based access control
- Safe token transfers
- Time-locked resolutions

## 🔗 Useful Commands

### Check Market Status
```bash
# Get market details
cast call $MARKET_ADDRESS "getMarket(uint256)" 0 --rpc-url $RPC_URL

# Check user balances
cast call $MARKET_ADDRESS "getBalances(uint256,address)" 0 $USER_ADDRESS --rpc-url $RPC_URL

# Get current prices
cast call $MARKET_ADDRESS "getCurrentPrice(uint256,uint8)" 0 1 --rpc-url $RPC_URL
```

### Check Oracle Status
```bash
# Get resolution status
cast call $ORACLE_MANAGER "getResolutionStatus(uint256)" 0 --rpc-url $RPC_URL

# Check oracle votes
cast call $ORACLE_MANAGER "getOracleVote(uint256,address)" 0 $ORACLE_ADDRESS --rpc-url $RPC_URL
```

This guide should help you understand and use the prediction market system effectively. For technical details, see the [System Design Document](SYSTEM_DESIGN.md).
