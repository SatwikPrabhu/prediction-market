# Quick Start Guide

Get the prediction market running in 5 minutes!

## 🚀 Local Development (Fastest)

### 1. Start Local Blockchain
```bash
# Terminal 1: Start Anvil
# If you get "Address already in use" error, kill existing processes first:
pkill -f anvil
anvil -p 8545
```

### 2. Deploy Contracts
```bash
# Terminal 2: Deploy and setup
cd contracts
export RPC_URL=http://127.0.0.1:8545

# Generate your own private key and admin address
export PRIVATE_KEY=0x$(openssl rand -hex 32)
export ADMIN_ADDRESS=$(cast wallet address $PRIVATE_KEY)

# Deploy contracts
forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --broadcast

# Create sample market
forge script script/AdminActions.s.sol:AdminActions --rpc-url $RPC_URL --broadcast
```

> ⚠️ **Security Note**: Never share your private keys! Generate your own for each deployment.

### 3. Start Frontend
```bash
# Terminal 3: Start frontend
cd frontend
npm install
npm run dev
# Open http://localhost:5173
```

### 4. Start Trading!

#### Frontend Trading
1. Open http://localhost:5173
2. Click "Connect Wallet" 
3. **Add Localhost Network** (if not already added):
   - Network Name: `Localhost`
   - RPC URL: `http://127.0.0.1:8545`
   - Chain ID: `31337`
4. **Get USDT Tokens** (for testing):
   ```bash
   # In a new terminal
   cd contracts
   export TOKEN_ADDRESS=0x...  # From deployment output
   cast send $TOKEN_ADDRESS "mint(address,uint256)" $YOUR_WALLET_ADDRESS 1000000000 \
     --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
   ```
5. **Trade on Markets**:
   - Select the sample market
   - Enter amount (e.g., 1000000 for 1 USDT)
   - Choose YES or NO
   - Click "Approve" then "Buy"

#### Command-Line Trading
```bash
# Set up environment
cd contracts
export RPC_URL=http://127.0.0.1:8545
export TOKEN_ADDRESS=0x...  # From deployment
export MARKET_ADDRESS=0x...  # From deployment
export USER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Approve and buy
cast send $TOKEN_ADDRESS "approve(address,uint256)" $MARKET_ADDRESS 1000000000 \
  --rpc-url $RPC_URL --private-key $USER_PRIVATE_KEY

cast send $MARKET_ADDRESS "buy(uint256,uint8,uint256)" 0 1 100000000 \
  --rpc-url $RPC_URL --private-key $USER_PRIVATE_KEY

# Check balances
cast call $MARKET_ADDRESS "getBalances(uint256,address)" 0 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url $RPC_URL
```

## 🌐 Testnet Deployment

### 1. Get Testnet ETH
- Visit [Base Sepolia Faucet](https://bridge.base.org/deposit)
- Get testnet ETH for gas fees

### 2. Deploy to Base Sepolia
```bash
cd contracts
export BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# Set your own admin address and private key
export ADMIN_ADDRESS=<your_admin_address>
export PRIVATE_KEY=<your_private_key>

# Deploy contracts
forge script script/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
```

> ⚠️ **Security Warning**: Use your own private keys! Never use example keys in production.

### 3. Update Frontend
```bash
cd frontend
# Update .env with deployed addresses
echo "VITE_TOKEN_ADDRESS=0x..." > .env
echo "VITE_MARKET_ADDRESS=0x..." >> .env
npm run dev
```

## 📱 Using the Frontend

### For Traders
1. **Connect Wallet**: Click "Connect Wallet" and select your wallet
2. **Select Market**: Choose from available markets
3. **Buy Position**: 
   - Enter amount in USDT (6 decimals)
   - Select YES or NO
   - Click "Approve" then "Buy"
4. **Claim Winnings**: After resolution, click "Claim Winnings"

### For Admins
1. **Create Markets**: Use deployment scripts
2. **Resolve Markets**: Use oracle commands
3. **Monitor System**: Check contract states

## 🔧 Common Commands

### Check Market Status
```bash
cast call $MARKET_ADDRESS "getMarket(uint256)" 0 --rpc-url $RPC_URL
```

### Check User Balances
```bash
cast call $MARKET_ADDRESS "getBalances(uint256,address)" 0 $USER_ADDRESS --rpc-url $RPC_URL
```

### Create New Market
```bash
cast send $MARKET_ADDRESS "createMarket(string,uint64,uint16,uint256)" \
  "Will BTC reach $100k?" \
  $(date -d "+30 days" +%s) \
  100 \
  100000000000 \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

### Resolve Market
```bash
# Add oracles
cast send $ORACLE_MANAGER "addOracle(address)" $ORACLE_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Submit resolution
cast send $ORACLE_MANAGER "submitResolution(uint256,uint8,bool)" 0 1 false --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Finalize and push
cast send $ORACLE_MANAGER "finalizeResolution(uint256)" 0 --rpc-url $RPC_URL --private-key $PRIVATE_KEY
cast send $ORACLE_MANAGER "pushResolutionToMarket(address,uint256)" $MARKET_ADDRESS 0 --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## 🚨 Troubleshooting

### Frontend Issues
- **Wallet not connecting**: Check network (localhost:8545 for local)
- **Transaction failed**: Ensure you have enough ETH for gas
- **Contract not found**: Verify addresses in `.env`

### Contract Issues
- **"Insufficient allowance"**: Click "Approve" before buying
- **"Trading ended"**: Market has passed its end time
- **"Not resolved"**: Market hasn't been resolved yet

### Deployment Issues
- **"Insufficient funds"**: Get testnet ETH from faucet
- **"RPC error"**: Check RPC URL is correct
- **"Verification failed"**: Ensure constructor arguments match

## 📚 Next Steps

- Read the [User Guide](USER_GUIDE.md) for detailed usage
- Check [System Design](SYSTEM_DESIGN.md) for architecture details
- See [Testnet Deployment](TESTNET_DEPLOYMENT.md) for production setup

## 🎯 What You Can Do

- **Trade**: Buy YES/NO positions on prediction markets
- **Create**: Set up new markets as an admin
- **Resolve**: Use oracle system to resolve outcomes
- **Monitor**: Track prices, liquidity, and balances
- **Claim**: Get winnings after market resolution

Happy trading! 🚀
