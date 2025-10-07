# Documentation Index

This directory contains comprehensive documentation for the Prediction Market system.

## 📚 Documentation Overview

### Getting Started
- **[Quick Start Guide](QUICK_START.md)** - Get running in 5 minutes
- **[User Guide](USER_GUIDE.md)** - Complete usage instructions for traders and admins
- **[Testnet Deployment](TESTNET_DEPLOYMENT.md)** - Deploy to Base Sepolia testnet

### Technical Documentation
- **[System Design](SYSTEM_DESIGN.md)** - Architecture, trade-offs, and design decisions
- **[Deployment Status](DEPLOYMENT_STATUS.md)** - Current deployment status and addresses

### Diagrams
- **[Architecture Diagram](diagrams/architecture.mmd)** - System architecture overview
- **[Buy Sequence](diagrams/buy-sequence.mmd)** - User trading flow
- **[Claim Sequence](diagrams/claim-sequence.mmd)** - Winnings claim flow

## 🚀 Quick Navigation

### For Developers
1. Start with [Quick Start Guide](QUICK_START.md)
2. Read [System Design](SYSTEM_DESIGN.md) for architecture
3. Follow [Testnet Deployment](TESTNET_DEPLOYMENT.md) for production

### For Users
1. Follow [Quick Start Guide](QUICK_START.md) for local setup
2. Read [User Guide](USER_GUIDE.md) for detailed usage
3. Check [Testnet Deployment](TESTNET_DEPLOYMENT.md) for testnet access

### For Admins
1. Read [User Guide](USER_GUIDE.md) for admin operations
2. Follow [Testnet Deployment](TESTNET_DEPLOYMENT.md) for deployment
3. Check [System Design](SYSTEM_DESIGN.md) for oracle management

## 📋 Documentation Structure

```
docs/
├── README.md                    # This file
├── QUICK_START.md              # 5-minute setup guide
├── USER_GUIDE.md               # Complete usage instructions
├── SYSTEM_DESIGN.md            # Architecture and design decisions
├── TESTNET_DEPLOYMENT.md       # Testnet deployment guide
├── DEPLOYMENT_STATUS.md        # Current deployment status
└── diagrams/
    ├── architecture.mmd        # System architecture
    ├── buy-sequence.mmd        # Trading flow
    └── claim-sequence.mmd      # Claim flow
```

## 🎯 Key Features Documented

### Trading System
- Dynamic AMM pricing with real-time price discovery
- YES/NO position trading with USDT settlement
- Real-time balance updates and market monitoring
- Secure wallet integration with RainbowKit

### Oracle System
- Multi-signature oracle with dispute mechanisms
- Time-locked resolutions with 24-hour dispute window
- Production-ready security with role-based access control
- Automated resolution pushing to market contracts

### Admin Operations
- Market creation with liquidity seeding
- Oracle management and resolution workflows
- Fee collection and protocol management
- Comprehensive monitoring and status checking

## 🔧 Technical Stack

### Smart Contracts
- **Solidity**: ^0.8.24 with OpenZeppelin libraries
- **Testing**: Foundry with comprehensive test suite (27 tests)
- **Security**: ReentrancyGuard, SafeERC20, AccessControl
- **Gas Optimization**: Packed structs and efficient storage patterns

### Frontend
- **React**: TypeScript with modern hooks
- **Web3**: wagmi/viem for blockchain interaction
- **Wallet**: RainbowKit for wallet connection
- **Build**: Vite for fast development and building

### Deployment
- **Local**: Anvil for development and testing
- **Testnet**: Base Sepolia with contract verification
- **Scripts**: Foundry scripts for automated deployment
- **Monitoring**: BaseScan integration for transaction tracking

## 📖 Reading Order

### New to the Project
1. [Quick Start Guide](QUICK_START.md) - Get running quickly
2. [User Guide](USER_GUIDE.md) - Learn how to use the system
3. [System Design](SYSTEM_DESIGN.md) - Understand the architecture

### Deploying to Production
1. [System Design](SYSTEM_DESIGN.md) - Understand architecture decisions
2. [Testnet Deployment](TESTNET_DEPLOYMENT.md) - Deploy to testnet
3. [Deployment Status](DEPLOYMENT_STATUS.md) - Check current status

### Contributing to Development
1. [Quick Start Guide](QUICK_START.md) - Set up development environment
2. [System Design](SYSTEM_DESIGN.md) - Understand the codebase
3. [User Guide](USER_GUIDE.md) - Learn admin operations

## 🆘 Getting Help

### Common Issues
- Check the troubleshooting sections in each guide
- Verify contract addresses and network configuration
- Ensure you have the latest dependencies installed

### Support Resources
- **Documentation**: This comprehensive guide set
- **Code Comments**: Well-documented smart contracts
- **Test Suite**: 27 tests covering all functionality
- **Examples**: Working examples in deployment scripts

### Contact
- Check the main [README](../README.md) for project overview
- Review [Deployment Status](DEPLOYMENT_STATUS.md) for current status
- Follow the [Quick Start Guide](QUICK_START.md) for immediate setup

---

This documentation provides everything needed to understand, deploy, and use the prediction market system. Start with the [Quick Start Guide](QUICK_START.md) for immediate results!
