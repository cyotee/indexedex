---
name: tevm-account-management
description: Get and set account state including balances, nonces, and storage. Use when manipulating EVM state for testing.
---

# Account Management

## getAccountHandler

Get current account state:

```typescript
import { getAccountHandler } from 'tevm/actions'

const account = await getAccountHandler(node)({
  address: '0x...',
  blockTag: 'latest',
  returnStorage: true
})
```

**Returns:**
```typescript
{
  address: Address
  nonce: bigint
  balance: bigint
  deployedBytecode: Hex
  storageRoot: Hex
  codeHash: Hex
  isContract: boolean
  isEmpty: boolean
  storage?: { [key: Hex]: Hex }
}
```

## setAccountHandler

Modify account state:

```typescript
import { setAccountHandler } from 'tevm/actions'

// Set balance
await setAccountHandler(node)({
  address: '0x...',
  balance: parseEther('100')
})

// Deploy contract code
await setAccountHandler(node)({
  address: contractAddress,
  deployedBytecode: '0x...',
  state: { '0x0': '0x1' }
})

// Multiple properties
await setAccountHandler(node)({
  address: '0x...',
  nonce: 5n,
  balance: parseEther('10'),
  state: { [slot]: value }
})
```

## Account Impersonation (Fork Mode)

```typescript
// Impersonate an account
node.setImpersonatedAccount('0x123...')

// Now JSON-RPC calls execute as that account
const result = await node.request({
  method: 'eth_sendTransaction',
  params: [{ from: '0x123...', to: '0x456...', ... }]
})

// Stop impersonating
node.setImpersonatedAccount(undefined)
```

## State Snapshots

```typescript
// Take snapshot
const snapshotId = await client.snapshot()

// Make changes
await setAccountHandler(node)({ address: '0x...', balance: 0n })

// Revert to snapshot
await client.revert({ id: snapshotId })
```
