#!/bin/bash

# Verification script for prediction market setup
# This script tests if the README instructions work correctly

set -e

echo "🔍 Verifying Prediction Market Setup..."
echo "======================================"

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check Node.js
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo "✅ Node.js: $NODE_VERSION"
else
    echo "❌ Node.js not found. Please install Node.js 20.19+ or 22.12+"
    exit 1
fi

# Check Foundry
if command -v forge &> /dev/null; then
    FORGE_VERSION=$(forge --version | head -n1)
    echo "✅ Foundry: $FORGE_VERSION"
else
    echo "❌ Foundry not found. Please install Foundry"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "contracts/foundry.toml" ]; then
    echo "❌ Not in prediction-market directory. Please run from project root."
    exit 1
fi

echo "✅ Project structure looks good"

# Check if Anvil is running
if lsof -Pi :8545 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  Anvil is already running on port 8545"
    echo "   If you get 'Address already in use' error, run: pkill -f anvil"
else
    echo "✅ Port 8545 is available"
fi

# Check if frontend directory exists
if [ -d "frontend" ]; then
    echo "✅ Frontend directory exists"
else
    echo "❌ Frontend directory not found"
    exit 1
fi

# Check if frontend has package.json
if [ -f "frontend/package.json" ]; then
    echo "✅ Frontend package.json exists"
else
    echo "❌ Frontend package.json not found"
    exit 1
fi

echo ""
echo "🎯 Setup Verification Complete!"
echo "================================"
echo ""
echo "📝 Next steps:"
echo "1. Start Anvil: anvil -p 8545"
echo "2. Deploy contracts: cd contracts && forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast"
echo "3. Start frontend: cd frontend && npm run dev"
echo ""
echo "🔧 If you encounter issues:"
echo "- Kill existing Anvil: pkill -f anvil"
echo "- Check you're in the right directory"
echo "- Ensure all dependencies are installed"
echo ""
echo "📚 For detailed instructions, see README.md"
