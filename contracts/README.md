# Contracts

## Prereqs
- Foundry (forge, cast, anvil)

## Install
```bash
cd contracts
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2
forge install foundry-rs/forge-std
```

## Build
```bash
forge build
```

## Test
```bash
forge test -vvv
```

## Deploy
Set env vars and run the script:
```bash
export PRIVATE_KEY=0x...
export ADMIN_ADDRESS=0xYourAdmin
forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --broadcast --verify
```

Contracts:
- `src/USDToken.sol`: Mintable 6-decimal settlement token.
- `src/PredictionMarket.sol`: Markets with create, buy, resolve, claim; admin oracle; fees.
