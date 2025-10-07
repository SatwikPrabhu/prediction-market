# Security Guide

This guide explains how to securely generate and manage private keys for the prediction market system.

## 🔐 Private Key Management

### ⚠️ **CRITICAL SECURITY WARNINGS**

- **NEVER** share your private keys with anyone
- **NEVER** commit private keys to version control
- **NEVER** use example keys in production
- **ALWAYS** generate your own secure keys
- **ALWAYS** use environment variables for sensitive data

## 🔑 Generating Secure Keys

### Method 1: Using Cast (Recommended)
```bash
# Generate a new private key
cast wallet new --unsafe

# Get the address for a private key
cast wallet address <private_key>

# Example output:
# Private key: 0x1234567890abcdef...
# Address: 0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6
```

### Method 2: Using Foundry Anvil
```bash
# Start anvil to get test accounts
anvil

# Anvil provides 10 test accounts with known private keys
# Account #0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
# Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Method 3: Using MetaMask
1. Create a new account in MetaMask
2. Export the private key (Settings > Security & Privacy > Reveal Private Key)
3. **Never share this key!**

## 🛡️ Secure Deployment Practices

### Environment Variables
```bash
# Create a .env file (never commit this!)
echo "PRIVATE_KEY=your_private_key_here" > .env
echo "ADMIN_ADDRESS=your_admin_address_here" >> .env
echo "BASESCAN_API_KEY=your_api_key_here" >> .env

# Load environment variables
source .env
```

### Production Deployment
```bash
# For production, use hardware wallets or secure key management
export ADMIN_ADDRESS=<your_secure_address>
export PRIVATE_KEY=<your_secure_private_key>

# Deploy with secure keys
forge script script/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
```

## 🔒 Multi-Signature Security

### For Production Oracle
```bash
# Create a multi-signature wallet for oracle management
# Use tools like Gnosis Safe for production deployments

# Add multiple oracles for security
cast send $ORACLE_MANAGER "addOracle(address)" $ORACLE1_ADDRESS \
  --rpc-url $RPC_URL --private-key $ADMIN_KEY

cast send $ORACLE_MANAGER "addOracle(address)" $ORACLE2_ADDRESS \
  --rpc-url $RPC_URL --private-key $ADMIN_KEY
```

## 🚨 Security Checklist

### Before Deployment
- [ ] Generated your own private keys
- [ ] Never used example keys
- [ ] Set up environment variables
- [ ] Verified network configuration
- [ ] Tested on local network first

### During Deployment
- [ ] Used secure RPC endpoints
- [ ] Verified contract addresses
- [ ] Checked gas estimates
- [ ] Monitored transaction status

### After Deployment
- [ ] Verified contracts on block explorer
- [ ] Tested all functionality
- [ ] Secured admin keys
- [ ] Set up monitoring

## 🔐 Key Storage Best Practices

### Local Development
```bash
# Use environment variables
export PRIVATE_KEY=$(cast wallet new --unsafe | grep "Private key:" | cut -d' ' -f3)
export ADMIN_ADDRESS=$(cast wallet address $PRIVATE_KEY)
```

### Production
- Use hardware wallets (Ledger, Trezor)
- Use secure key management services
- Implement multi-signature wallets
- Use key rotation policies

## 🛠️ Secure Development Workflow

### 1. Generate Keys
```bash
# Generate new keys for each deployment
export PRIVATE_KEY=$(cast wallet new --unsafe | grep "Private key:" | cut -d' ' -f3)
export ADMIN_ADDRESS=$(cast wallet address $PRIVATE_KEY)
```

### 2. Fund Account
```bash
# Get testnet ETH from faucet
# For mainnet, ensure sufficient ETH for gas
```

### 3. Deploy Securely
```bash
# Use secure RPC endpoints
# Verify all parameters
# Monitor deployment process
```

### 4. Verify Contracts
```bash
# Verify on block explorer
# Test all functionality
# Secure admin keys
```

## 🚨 Common Security Mistakes

### ❌ Don't Do This
```bash
# NEVER hardcode private keys
export PRIVATE_KEY=0x1234567890abcdef...

# NEVER commit private keys to git
git add .env  # If .env contains private keys

# NEVER share private keys in documentation
echo "PRIVATE_KEY=0x..." >> README.md
```

### ✅ Do This Instead
```bash
# Generate keys securely
export PRIVATE_KEY=$(cast wallet new --unsafe | grep "Private key:" | cut -d' ' -f3)

# Use environment variables
echo "PRIVATE_KEY=your_key_here" > .env
echo ".env" >> .gitignore

# Use placeholder values in documentation
echo "PRIVATE_KEY=<your_private_key>" >> README.md
```

## 🔍 Security Monitoring

### Check for Exposed Keys
```bash
# Search for potential key exposure
grep -r "0x[0-9a-fA-F]\{64\}" . --exclude-dir=node_modules
grep -r "private.*key" . --exclude-dir=node_modules
```

### Verify Security
```bash
# Check environment variables
env | grep -i private
env | grep -i key

# Verify no keys in git history
git log --all --full-history -- "*.env"
```

## 📚 Additional Resources

- [Foundry Security Best Practices](https://book.getfoundry.sh/security/)
- [OpenZeppelin Security Guidelines](https://docs.openzeppelin.com/contracts/security)
- [Ethereum Security Best Practices](https://consensys.github.io/smart-contract-best-practices/)

Remember: **Security is your responsibility!** Always generate your own keys and never share them.
