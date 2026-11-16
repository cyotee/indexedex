---
name: voltaire-effect-provider
description: JSON-RPC provider operations with Effect.ts. Use when reading blockchain data, making contract calls, or estimating gas.
---

# Provider Service

JSON-RPC operations with Effect.ts composition.

## Setup

```typescript
import { Effect, Layer } from 'effect'
import { Provider, HttpTransport } from 'voltaire-effect'

const ProviderLayer = Provider.pipe(
  Layer.provide(HttpTransport('https://eth.llamarpc.com'))
)
```

## Block Operations

```typescript
import { getBlockNumber, getBlock, getBlockReceipts } from 'voltaire-effect'

const program = Effect.gen(function* () {
  const blockNum = yield* getBlockNumber()
  const block = yield* getBlock({ blockTag: 'latest', includeTransactions: true })
  const receipts = yield* getBlockReceipts({ blockTag: 'latest' })
  return { blockNum, block, receipts }
})
```

## Account State

```typescript
import { getBalance, getTransactionCount, getCode, getStorageAt } from 'voltaire-effect'

const state = yield* Effect.all({
  balance: getBalance('0x123...', 'latest'),
  nonce: getTransactionCount('0x123...'),
  code: getCode('0x123...'),
  slot: getStorageAt('0x123...', '0x0')
})
```

## Read Contract

```typescript
import { readContract } from 'voltaire-effect'

const erc20Abi = [
  { type: 'function', name: 'balanceOf', stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: 'balance', type: 'uint256' }]
  }
] as const

const balance = yield* readContract({
  address: '0x6B175474E89094C44Da98b954EecdEfaE6E286AB',
  abi: erc20Abi,
  functionName: 'balanceOf',
  args: ['0x1234567890123456789012345678901234567890']
})
```

## Multicall

```typescript
import { multicall } from 'voltaire-effect'

const results = yield* multicall({
  contracts: [
    { address: tokenA, abi: erc20Abi, functionName: 'balanceOf', args: [user] },
    { address: tokenB, abi: erc20Abi, functionName: 'balanceOf', args: [user] }
  ]
})
// results: [{ status: 'success', result: 1000n }, { status: 'success', result: 500n }]
```

## Timeout & Retry

```typescript
import { withTimeout, withRetrySchedule } from 'voltaire-effect'
import { Schedule } from 'effect'

const balance = yield* getBalance(addr).pipe(
  withTimeout('5 seconds'),
  withRetrySchedule(Schedule.exponential('500 millis').pipe(
    Schedule.jittered,
    Schedule.compose(Schedule.recurs(3))
  ))
)
```

## Simulate Contract

```typescript
import { simulateContract } from 'voltaire-effect'

const { result, request } = yield* simulateContract({
  address: tokenAddress,
  abi: erc20Abi,
  functionName: 'transfer',
  args: [recipient, amount],
  account: senderAddress
})
```

## Event Logs

```typescript
import { getLogs } from 'voltaire-effect'

const logs = yield* getLogs({
  address: '0x123...',
  topics: ['0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'],
  fromBlock: 18000000n,
  toBlock: 'latest'
})
```
