# Cast Command Patterns

Common patterns and recipes for using Cast in development workflows.

## Token Operations

### Check ERC20 Balance

```bash
# Get balance in wei
cast call $TOKEN "balanceOf(address)(uint256)" $ADDRESS --rpc-url mainnet

# Get balance as decimal
BALANCE=$(cast call $TOKEN "balanceOf(address)(uint256)" $ADDRESS --rpc-url mainnet)
DECIMALS=$(cast call $TOKEN "decimals()(uint8)" --rpc-url mainnet)
cast to-unit $BALANCE $DECIMALS
```

### Get Token Info

```bash
# Name, symbol, decimals
cast call $TOKEN "name()(string)" --rpc-url mainnet
cast call $TOKEN "symbol()(string)" --rpc-url mainnet
cast call $TOKEN "decimals()(uint8)" --rpc-url mainnet
cast call $TOKEN "totalSupply()(uint256)" --rpc-url mainnet
```

### Approve Token Spending

```bash
# Approve max
cast send $TOKEN "approve(address,uint256)" $SPENDER $(cast max-uint) \
    --rpc-url mainnet --private-key $PK

# Approve specific amount
cast send $TOKEN "approve(address,uint256)" $SPENDER 1000000000000000000 \
    --rpc-url mainnet --private-key $PK
```

### Transfer Tokens

```bash
# Direct transfer
cast send $TOKEN "transfer(address,uint256)" $TO $AMOUNT \
    --rpc-url mainnet --private-key $PK

# Transfer from (requires approval)
cast send $TOKEN "transferFrom(address,address,uint256)" $FROM $TO $AMOUNT \
    --rpc-url mainnet --private-key $PK
```

## DeFi Interactions

### Uniswap V2 Queries

```bash
# Get pair reserves
cast call $PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url mainnet

# Get pair tokens
cast call $PAIR "token0()(address)" --rpc-url mainnet
cast call $PAIR "token1()(address)" --rpc-url mainnet

# Quote swap
cast call $ROUTER "getAmountsOut(uint256,address[])(uint256[])" \
    1000000000000000000 "[$WETH,$USDC]" --rpc-url mainnet
```

### Uniswap V3 Queries

```bash
# Get pool slot0 (price, tick, etc.)
cast call $POOL "slot0()(uint160,int24,uint16,uint16,uint16,uint8,bool)" --rpc-url mainnet

# Get pool liquidity
cast call $POOL "liquidity()(uint128)" --rpc-url mainnet
```

### Aave Queries

```bash
# Get user account data
cast call $LENDING_POOL "getUserAccountData(address)(uint256,uint256,uint256,uint256,uint256,uint256)" \
    $USER --rpc-url mainnet

# Get reserve data
cast call $LENDING_POOL "getReserveData(address)(uint256,uint128,uint128,uint128,uint128,uint128,uint40,address,address,address,address,uint8)" \
    $ASSET --rpc-url mainnet
```

### Chainlink Price Feeds

```bash
# Get latest price
cast call $PRICE_FEED "latestRoundData()(uint80,int256,uint256,uint256,uint80)" --rpc-url mainnet

# Extract just the price
cast call $PRICE_FEED "latestAnswer()(int256)" --rpc-url mainnet
```

## Contract Analysis

### Check Contract Type

```bash
# Check if ERC20
cast call $CONTRACT "totalSupply()(uint256)" --rpc-url mainnet

# Check if ERC721
cast call $CONTRACT "supportsInterface(bytes4)(bool)" 0x80ac58cd --rpc-url mainnet

# Check if ERC1155
cast call $CONTRACT "supportsInterface(bytes4)(bool)" 0xd9b67a26 --rpc-url mainnet
```

### Read Storage Directly

```bash
# Slot 0 (often owner or implementation)
cast storage $CONTRACT 0 --rpc-url mainnet

# ERC1967 implementation slot
cast storage $CONTRACT 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url mainnet

# ERC1967 admin slot
cast storage $CONTRACT 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 --rpc-url mainnet
```

### Decode Proxy Implementation

```bash
# Get implementation address from ERC1967 proxy
IMPL=$(cast storage $PROXY 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url mainnet)
echo "Implementation: $(cast to-checksum-address $(cast to-hex $(cast to-dec $IMPL)))"
```

## Transaction Analysis

### Decode Transaction Input

```bash
# Get transaction
TX_INPUT=$(cast tx $TX_HASH --field input --rpc-url mainnet)

# Get function selector
echo ${TX_INPUT:0:10}

# Lookup selector
cast 4byte ${TX_INPUT:0:10}

# Decode full calldata (if you know the signature)
cast calldata-decode "transfer(address,uint256)" $TX_INPUT
```

### Analyze Gas Usage

```bash
# Get gas used
cast receipt $TX_HASH --field gasUsed --rpc-url mainnet

# Get effective gas price
cast receipt $TX_HASH --field effectiveGasPrice --rpc-url mainnet

# Calculate total cost
GAS_USED=$(cast receipt $TX_HASH --field gasUsed --rpc-url mainnet)
GAS_PRICE=$(cast receipt $TX_HASH --field effectiveGasPrice --rpc-url mainnet)
echo "Total cost: $(cast to-unit $(($GAS_USED * $GAS_PRICE)) ether) ETH"
```

### Extract Events

```bash
# Get all logs from transaction
cast receipt $TX_HASH --field logs --rpc-url mainnet

# Get Transfer events
cast logs "Transfer(address,address,uint256)" \
    --address $TOKEN \
    --from-block $(cast receipt $TX_HASH --field blockNumber --rpc-url mainnet) \
    --to-block $(cast receipt $TX_HASH --field blockNumber --rpc-url mainnet) \
    --rpc-url mainnet
```

## Scripting Patterns

### Batch Read

```bash
#!/bin/bash
TOKENS=(
    "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"  # USDC
    "0xdAC17F958D2ee523a2206206994597C13D831ec7"  # USDT
    "0x6B175474E89094C44Da98b954EesdfeCaE69310"  # DAI
)

for TOKEN in "${TOKENS[@]}"; do
    NAME=$(cast call $TOKEN "name()(string)" --rpc-url mainnet)
    SUPPLY=$(cast call $TOKEN "totalSupply()(uint256)" --rpc-url mainnet)
    echo "$NAME: $SUPPLY"
done
```

### Wait for Transaction

```bash
# Send and wait for confirmation
TX_HASH=$(cast send $CONTRACT "doSomething()" \
    --rpc-url mainnet --private-key $PK --json | jq -r '.transactionHash')

echo "Waiting for confirmation..."
cast receipt $TX_HASH --rpc-url mainnet --confirmations 3

echo "Transaction confirmed!"
```

### Simulate Then Execute

```bash
# Simulate first
cast call $CONTRACT "riskyFunction(uint256)" 1000 \
    --from $MY_ADDRESS \
    --rpc-url mainnet

# If successful, execute
cast send $CONTRACT "riskyFunction(uint256)" 1000 \
    --rpc-url mainnet --private-key $PK
```

## Debugging

### Trace Failed Transaction

```bash
# Get full trace
cast run $TX_HASH --rpc-url mainnet

# Quick trace (just errors)
cast run $TX_HASH --quick --rpc-url mainnet
```

### Simulate at Block

```bash
# Call at specific block
cast call $CONTRACT "getPrice()(uint256)" \
    --block 18000000 \
    --rpc-url mainnet
```

### Find Storage Slot

```bash
# Brute force check slots
for i in {0..10}; do
    VALUE=$(cast storage $CONTRACT $i --rpc-url mainnet)
    if [ "$VALUE" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
        echo "Slot $i: $VALUE"
    fi
done
```

## Address Utilities

### Checksum Conversion

```bash
# Lowercase to checksum
cast to-checksum-address 0xd8da6bf26964af9d7eed9e03e53415d37aa96045
```

### Predict CREATE Address

```bash
# Next deployment address
NONCE=$(cast nonce $DEPLOYER --rpc-url mainnet)
cast compute-address $DEPLOYER --nonce $NONCE
```

### Predict CREATE2 Address

```bash
# Deterministic address
cast create2 \
    --deployer 0x4e59b44847b379578588920cA78FbF26c0B4956C \
    --salt 0x$(cast keccak "my-salt") \
    --init-code-hash $(cast keccak $(cat bytecode.txt))
```

## Environment Setup

### Recommended .bashrc/.zshrc

```bash
# Default RPC
export ETH_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"

# Aliases
alias mainnet="--rpc-url mainnet"
alias sepolia="--rpc-url sepolia"

# Functions
function token-balance() {
    cast call $1 "balanceOf(address)(uint256)" $2 --rpc-url mainnet | cast to-dec
}

function eth-balance() {
    cast balance $1 --rpc-url mainnet -e
}
```
