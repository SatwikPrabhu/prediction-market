# Testnet Deployment Guide

This guide walks you through deploying the prediction market to Base Sepolia testnet and using it.

## Prerequisites

1. **Get Base Sepolia ETH**: Visit [Base Sepolia Faucet](https://bridge.base.org/deposit) to get testnet ETH
2. **Set up environment variables**: Copy `.env.example` to `.env` and fill in your values
3. **Get BaseScan API key** (optional, for verification): Visit [BaseScan](https://basescan.org/apis)
4. **Install dependencies**: Ensure Foundry and Node.js are installed

## Environment Setup

Create a `.env` file in the `contracts/` directory:

```bash
# Base Sepolia Testnet
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASE_SEPOLIA_CHAIN_ID=84532

# Your private key (without 0x prefix) - GENERATE YOUR OWN!
PRIVATE_KEY=your_private_key_here

# Admin address (will be set as the deployer) - GENERATE YOUR OWN!
ADMIN_ADDRESS=your_admin_address_here

# For contract verification (optional)
BASESCAN_API_KEY=your_basescan_api_key_here
```

> ⚠️ **Security Warning**: Never use example private keys! Generate your own secure keys.

## Deployment Steps

### 1. Deploy Contracts

```bash
cd contracts

# Deploy to Base Sepolia
forge script script/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

### 2. Setup Test Market

After deployment, set the contract addresses and run setup:

```bash
# Set the deployed addresses
export TOKEN_ADDRESS=0x...  # From deployment output
export MARKET_ADDRESS=0x... # From deployment output
export ORACLE_MANAGER_ADDRESS=0x... # From deployment output

# Create test market and mint tokens
forge script script/TestnetSetup.s.sol:TestnetSetup \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast
```

### 3. Update Frontend

Update the contract addresses in `frontend/src/App.tsx`:

```typescript
const TOKEN: Address = '0x...' // Your deployed USDToken address
const MARKET: Address = '0x...' // Your deployed PredictionMarket address
```

### 4. Wire OracleManager to Market

From your admin account:

```bash
# Point market to OracleManager
cast send $MARKET_ADDRESS "setOracleManager(address)" $ORACLE_MANAGER_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Register market in OracleManager (so it can push resolutions)
cast send $ORACLE_MANAGER_ADDRESS "registerMarket(address)" $MARKET_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

## Verification

After deployment, verify your contracts on BaseScan:

```bash
# Verify USDToken
forge verify-contract <TOKEN_ADDRESS> src/USDToken.sol:USDToken \
  --chain-id 84532 \
  --etherscan-api-key $BASESCAN_API_KEY

# Verify PredictionMarket/AMM
forge verify-contract <MARKET_ADDRESS> src/PredictionMarket.sol:PredictionMarket \
  --chain-id 84532 \
  --etherscan-api-key $BASESCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address,address)" <ADMIN_ADDRESS> <TOKEN_ADDRESS>)

# Or, if using the AMM variant
forge verify-contract <MARKET_ADDRESS> src/PredictionMarketAMM.sol:PredictionMarketAMM \
  --chain-id 84532 \
  --etherscan-api-key $BASESCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address,address)" <ADMIN_ADDRESS> <TOKEN_ADDRESS>)

# Verify OracleManager
forge verify-contract <ORACLE_MANAGER_ADDRESS> src/OracleManager.sol:OracleManager \
  --chain-id 84532 \
  --etherscan-api-key $BASESCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address)" <ADMIN_ADDRESS>)
```

## Testing

1. **Connect to Base Sepolia**: Add Base Sepolia to your wallet
   - Network Name: Base Sepolia
   - RPC URL: https://sepolia.base.org
   - Chain ID: 84532
   - Block Explorer: https://sepolia.basescan.org

2. **Get Test ETH**: Use the [Base Sepolia Faucet](https://bridge.base.org/deposit)

3. **Test the Frontend**: Update contract addresses and test the full flow

## Using the Deployed System

### For Traders

1. **Access the Frontend**:
   ```bash
   cd frontend
   npm run dev
   # Open http://localhost:5173
   ```

2. **Connect Your Wallet**:
   - Click "Connect Wallet"
   - Select your wallet
   - Switch to Base Sepolia network

3. **Get USDT Tokens**:
   ```bash
   # Mint USDT to your address
   cast send $TOKEN_ADDRESS "mint(address,uint256)" $YOUR_ADDRESS 1000000000 \
     --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   ```

4. **Trade on Markets**:
   - Select a market from the list
   - Enter amount in USDT (6 decimals)
   - Choose YES or NO outcome
   - Click "Approve" then "Buy"

### For Administrators

1. **Create New Markets**:
   ```bash
   # Create a market with 100k USDT liquidity
   cast send $MARKET_ADDRESS "createMarket(string,uint64,uint16,uint256)" \
     "Will ETH reach $5000 by end of month?" \
     $(date -d "+30 days" +%s) \
     100 \
     100000000000 \
     --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   ```

2. **Resolve Markets**:
   ```bash
   # Add oracles
   cast send $ORACLE_MANAGER "addOracle(address)" $ORACLE1_ADDRESS \
     --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   cast send $ORACLE_MANAGER "addOracle(address)" $ORACLE2_ADDRESS \
     --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   
   # Submit resolutions
   cast send $ORACLE_MANAGER "submitResolution(uint256,uint8,bool)" 0 1 false \
     --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $ORACLE1_KEY
   cast send $ORACLE_MANAGER "submitResolution(uint256,uint8,bool)" 0 1 false \
     --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $ORACLE2_KEY
   
   # Finalize and push
   cast send $ORACLE_MANAGER "finalizeResolution(uint256)" 0 \
     --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   cast send $ORACLE_MANAGER "pushResolutionToMarket(address,uint256)" $MARKET_ADDRESS 0 \
     --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   ```

3. **Monitor System**:
   ```bash
   # Check market status
   cast call $MARKET_ADDRESS "getMarket(uint256)" 0 --rpc-url $BASE_SEPOLIA_RPC_URL
   
   # Check user balances
   cast call $MARKET_ADDRESS "getBalances(uint256,address)" 0 $USER_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL
   
   # Check oracle status
   cast call $ORACLE_MANAGER "getResolutionStatus(uint256)" 0 --rpc-url $BASE_SEPOLIA_RPC_URL
   ```

## Troubleshooting

- **Insufficient funds**: Make sure you have Base Sepolia ETH
- **Verification fails**: Check constructor arguments and contract source
- **RPC errors**: Ensure RPC URL is correct and accessible
