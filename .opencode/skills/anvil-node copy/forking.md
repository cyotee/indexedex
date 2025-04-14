# Anvil Forking Patterns

Detailed patterns for forking mainnet and other networks with Anvil.

## Basic Forking

### Latest Block

```bash
# Fork mainnet at latest
anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY
```

### Specific Block (Reproducible)

```bash
# Fork at specific block for reproducible tests
anvil --fork-url $RPC --fork-block-number 18000000

# With retry for rate limits
anvil --fork-url $RPC --fork-block-number 18000000 --fork-retry-backoff 1000
```

## Impersonation Patterns

### Impersonate Whale

```bash
# Start with whale unlocked
anvil --fork-url $RPC --unlocked 0xWhaleAddress

# Send whale's tokens
cast send $TOKEN "transfer(address,uint256)" $RECIPIENT $AMOUNT \
    --from 0xWhaleAddress \
    --rpc-url http://localhost:8545 \
    --unlocked
```

### Impersonate Contract Owner

```bash
# Get owner address
OWNER=$(cast call $CONTRACT "owner()(address)" --rpc-url http://localhost:8545)

# Impersonate owner
cast rpc anvil_impersonateAccount $OWNER --rpc-url http://localhost:8545

# Execute as owner
cast send $CONTRACT "setFee(uint256)" 100 \
    --from $OWNER \
    --rpc-url http://localhost:8545 \
    --unlocked

# Stop impersonating
cast rpc anvil_stopImpersonatingAccount $OWNER --rpc-url http://localhost:8545
```

### Impersonate Multisig

```bash
# For Gnosis Safe - impersonate the safe address
SAFE=0xMultisigAddress
cast rpc anvil_impersonateAccount $SAFE

# Execute as multisig
cast send $CONTRACT "execute(bytes)" $CALLDATA \
    --from $SAFE \
    --unlocked
```

## State Manipulation

### Set Balance

```bash
# Give address ETH
cast rpc anvil_setBalance 0xAddress $(cast to-hex $(cast to-wei 1000 ether))

# Verify
cast balance 0xAddress
```

### Set Token Balance

```solidity
// In test
function test_WithTokenBalance() public {
    deal(address(usdc), alice, 1_000_000e6);
    assertEq(usdc.balanceOf(alice), 1_000_000e6);
}
```

Or with cast:

```bash
# Find balance slot (varies by token)
# For many tokens, slot 0 or mapping at slot 0

# USDC balance mapping is at slot 9
SLOT=$(cast keccak $(cast abi-encode "f(address,uint256)" $ADDRESS 9))
cast rpc anvil_setStorageAt $USDC $SLOT $(cast to-hex 1000000000)
```

### Set Storage Directly

```bash
# Set storage slot
cast rpc anvil_setStorageAt $CONTRACT 0x0 $(cast to-hex 100)

# Verify
cast storage $CONTRACT 0x0
```

### Replace Contract Code

```bash
# Get bytecode from another deployment
BYTECODE=$(cast code $OTHER_CONTRACT --rpc-url mainnet)

# Replace target contract code
cast rpc anvil_setCode $TARGET_CONTRACT $BYTECODE
```

## Time Travel

### Skip Forward

```bash
# Skip 1 day
cast rpc evm_increaseTime 86400

# Mine block to apply
cast rpc evm_mine
```

### Set Specific Timestamp

```bash
# Set next block timestamp
cast rpc evm_setNextBlockTimestamp 1700000000

# Mine block
cast rpc evm_mine
```

### Test Time-Locked Functions

```bash
# Fork at block before timelock expires
anvil --fork-url $RPC --fork-block-number 17999999

# Skip past timelock
cast rpc evm_increaseTime 604800  # 1 week

# Execute time-locked function
cast send $TIMELOCK "execute()" --from $ADMIN --unlocked
```

## Snapshot and Revert

### Basic Snapshot

```bash
# Take snapshot
SNAPSHOT=$(cast rpc evm_snapshot)
echo "Snapshot ID: $SNAPSHOT"

# Make changes
cast send $CONTRACT "doSomething()"

# Revert to snapshot
cast rpc evm_revert $SNAPSHOT
```

### Multiple Snapshots

```bash
# Initial state
INITIAL=$(cast rpc evm_snapshot)

# After setup
cast send $CONTRACT "setup()"
AFTER_SETUP=$(cast rpc evm_snapshot)

# Test scenario 1
cast send $CONTRACT "scenario1()"
cast rpc evm_revert $AFTER_SETUP

# Test scenario 2
cast send $CONTRACT "scenario2()"
cast rpc evm_revert $INITIAL
```

## Multi-Chain Forking

### Run Multiple Forks

```bash
# Terminal 1: Mainnet fork on default port
anvil --fork-url $MAINNET_RPC --port 8545

# Terminal 2: Arbitrum fork on different port
anvil --fork-url $ARBITRUM_RPC --port 8546 --chain-id 42161

# Terminal 3: Base fork
anvil --fork-url $BASE_RPC --port 8547 --chain-id 8453
```

### Cross-Chain Simulation

```bash
# Start both forks
anvil --fork-url $MAINNET_RPC --port 8545 &
anvil --fork-url $ARBITRUM_RPC --port 8546 &

# Simulate bridge from mainnet
cast send $BRIDGE "sendToL2()" --value 1ether --rpc-url http://localhost:8545

# Check arrival on L2 (manual state manipulation)
cast rpc anvil_setBalance $RECIPIENT $(cast to-hex 1ether) --rpc-url http://localhost:8546
```

## Testing Specific Scenarios

### Liquidation Testing

```bash
# Fork at block where position is healthy
anvil --fork-url $RPC --fork-block-number $BLOCK

# Manipulate oracle price (if oracle is mutable)
cast rpc anvil_impersonateAccount $ORACLE_ADMIN
cast send $ORACLE "setPrice(int256)" -50000000000 --from $ORACLE_ADMIN --unlocked

# Or advance time to trigger conditions
cast rpc evm_increaseTime 86400

# Attempt liquidation
cast send $LENDING_POOL "liquidate(address)" $UNDERWATER_USER
```

### Governance Testing

```bash
# Fork mainnet
anvil --fork-url $RPC

# Impersonate large token holder
WHALE=0xLargeHolder
cast rpc anvil_impersonateAccount $WHALE

# Create proposal
cast send $GOVERNOR "propose(...)" --from $WHALE --unlocked

# Skip voting delay
cast rpc evm_increaseTime 172800  # 2 days

# Vote
cast send $GOVERNOR "castVote(uint256,uint8)" $PROPOSAL_ID 1 --from $WHALE --unlocked

# Skip voting period
cast rpc evm_increaseTime 604800  # 1 week

# Queue
cast send $GOVERNOR "queue(uint256)" $PROPOSAL_ID

# Skip timelock
cast rpc evm_increaseTime 172800  # 2 days

# Execute
cast send $GOVERNOR "execute(uint256)" $PROPOSAL_ID
```

### Flash Loan Testing

```bash
# Fork at block with sufficient liquidity
anvil --fork-url $RPC --fork-block-number 18000000

# Deploy flash loan receiver
RECEIVER=$(forge create FlashLoanReceiver --rpc-url http://localhost:8545 --private-key $PK --json | jq -r '.deployedTo')

# Execute flash loan
cast send $AAVE_POOL "flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)" \
    $RECEIVER \
    "[$USDC]" \
    "[1000000000000]" \
    "[0]" \
    $RECEIVER \
    "0x" \
    0 \
    --rpc-url http://localhost:8545
```

## Performance Optimization

### Reduce RPC Calls

```bash
# Cache more aggressively
anvil --fork-url $RPC --fork-block-number 18000000 \
    --compute-units-per-second 100
```

### State Caching

```bash
# Save state after setup
anvil --fork-url $RPC --dump-state setup-state.json

# Load cached state (faster startup)
anvil --load-state setup-state.json
```

### Limit Block Range

```bash
# Fork recent block to minimize state
anvil --fork-url $RPC --fork-block-number $(cast block latest --field number --rpc-url $RPC)
```

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Start Anvil
  run: |
    anvil --fork-url ${{ secrets.RPC_URL }} \
          --fork-block-number 18000000 &
    sleep 5

- name: Run Fork Tests
  run: forge test --rpc-url http://localhost:8545

- name: Stop Anvil
  run: pkill anvil
```

### Docker Compose

```yaml
services:
  anvil:
    image: ghcr.io/foundry-rs/foundry
    command: anvil --fork-url ${RPC_URL} --host 0.0.0.0
    ports:
      - "8545:8545"

  tests:
    build: .
    depends_on:
      - anvil
    environment:
      - RPC_URL=http://anvil:8545
```
