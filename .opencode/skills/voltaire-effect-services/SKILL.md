---
name: Voltaire Effect Services
description: This skill should be used when the user asks about "ProviderService", "SignerService", "TransportService", "HttpTransport", "WebSocketTransport", "JSON-RPC Effect", "getBalance", "getBlock", "getBlockNumber", "sendTransaction", "voltaire-effect provider", "Layer.provide", or needs to understand the voltaire-effect service system.
version: 0.1.0
---

# Voltaire Effect Services

## Overview

Services in voltaire-effect are typed dependencies declared in Effect signatures and injected via layers at program boundaries. This eliminates hidden globals and enables seamless test substitution.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SERVICE ARCHITECTURE                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Application Code                                                           │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  const bal = yield* getBalance(addr)                                  │  │
│  │  // Type: Effect<bigint, GetBalanceError, ProviderService>           │  │
│  └────────────────────────────────┬──────────────────────────────────────┘  │
│                                   │                                          │
│                      Effect.provide(layers)                                 │
│                                   │                                          │
│  Service Implementations          ▼                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                     │
│  │  Provider     │  │  Signer      │  │  Transport   │                     │
│  │  ─────────    │  │  ─────────   │  │  ──────────  │                     │
│  │  getBalance   │  │  sign        │  │  HTTP        │                     │
│  │  getBlock     │  │  signMessage │  │  WebSocket   │                     │
│  │  call         │  │  signTyped   │  │  Browser     │                     │
│  │  getLogs      │  │  sendTx      │  │  Test        │                     │
│  └──────────────┘  └──────────────┘  └──────────────┘                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Provider Service

The primary service for reading blockchain state via JSON-RPC:

### Free Functions (Preferred)

Use free functions instead of yielding ProviderService directly:

```typescript
import { getBlockNumber, getBalance, getBlock, getLogs } from 'voltaire-effect'

const program = Effect.gen(function* () {
  const blockNum = yield* getBlockNumber()
  const balance = yield* getBalance(addr)
  const block = yield* getBlock({ blockNumber: blockNum })
  const logs = yield* getLogs({ fromBlock: 0n, toBlock: 'latest' })
  return { blockNum, balance, block, logs }
})
```

### Provider Operations

| Category | Functions |
|----------|-----------|
| **Blocks** | `getBlockNumber`, `getBlock`, `getBlockReceipts`, `getUncleCount` |
| **Accounts** | `getBalance`, `getTransactionCount`, `getCode`, `getStorageAt` |
| **Transactions** | `getTransaction`, `getTransactionReceipt`, `waitForTransactionReceipt` |
| **Simulation** | `readContract`, `multicall`, `simulateContract`, `simulateV1`, `simulateV2` |
| **Gas** | `getGasPrice`, `getMaxPriorityFeePerGas`, `getFeeHistory` |
| **Events** | `getLogs` |
| **Streaming** | `watchBlocks`, `subscribe`, `unsubscribe` |

### Layer Setup

```typescript
import { Provider, HttpTransport } from 'voltaire-effect'

const ProviderLayer = Provider.pipe(
  Layer.provide(HttpTransport('https://eth.llamarpc.com'))
)
```

## Transport Service

Manages the network connection. Three production transports and one test transport:

### HttpTransport

```typescript
import { HttpTransport } from 'voltaire-effect'

HttpTransport('https://eth.llamarpc.com')

// With options
HttpTransport({
  url: 'https://eth.llamarpc.com',
  timeout: '30 seconds',
  headers: { 'Authorization': 'Bearer ...' },
  retrySchedule: Schedule.exponential('500 millis').pipe(
    Schedule.jittered,
    Schedule.compose(Schedule.recurs(5))
  )
})
```

HTTP transport supports automatic request batching - concurrent requests are batched into a single HTTP call.

### WebSocketTransport

```typescript
import { WebSocketTransport } from 'voltaire-effect'
WebSocketTransport('wss://eth.llamarpc.com')
```

### BrowserTransport

```typescript
import { BrowserTransport } from 'voltaire-effect'
BrowserTransport()  // Uses window.ethereum
```

### TestTransport

```typescript
import { TestTransport } from 'voltaire-effect'

TestTransport({
  eth_blockNumber: '0x10',
  eth_getBalance: '0xde0b6b3a7640000'
})
```

## Signer Service

For state-changing operations. Unlike Provider, Signer still requires direct yielding:

```typescript
import { Signer } from 'voltaire-effect'

const program = Effect.gen(function* () {
  const signer = yield* Signer
  const txHash = yield* signer.sendTransaction({
    to: recipient,
    value: 1000000000000000000n
  })
  return txHash
})
```

### Signer from Provider

Create a Signer from an existing Provider and Account:

```typescript
const SignerLayer = Signer.fromProvider
// Requires ProviderService + AccountService
```

## Layer Composition

### Independent Services

```typescript
const AppLayer = Layer.mergeAll(TransportLayer, CryptoLayer)
```

### Dependent Services

```typescript
// Provider depends on Transport
const ProviderLayer = Provider.pipe(
  Layer.provide(HttpTransport('https://eth.llamarpc.com'))
)
```

### Full Stack

```typescript
import { Secp256k1Live } from 'voltaire-effect/crypto/Secp256k1'
import { KeccakLive } from 'voltaire-effect/crypto/Keccak256'

const FullLayer = Layer.mergeAll(
  ProviderLayer,
  Secp256k1Live,
  KeccakLive,
  SignerLayer
)

await Effect.runPromise(program.pipe(Effect.provide(FullLayer)))
```

## Per-Request Configuration

Override settings for individual calls using FiberRef helpers:

```typescript
import { withTimeout, withRetrySchedule, withoutCache, withTracing } from 'voltaire-effect'

// Timeout
const fast = yield* getBalance(addr).pipe(withTimeout("5 seconds"))

// Custom retry
const resilient = yield* getBalance(addr).pipe(
  withRetrySchedule(Schedule.recurs(1))
)

// Bypass cache
const fresh = yield* getBlockNumber().pipe(withoutCache)

// Debug tracing
const traced = yield* getBlock(n).pipe(withTracing())
```

## Multicall Batching

Reduce network overhead by batching contract reads:

```typescript
import { multicall } from 'voltaire-effect'

const results = yield* multicall({
  contracts: [
    { address: usdc, abi: erc20Abi, functionName: 'balanceOf', args: [user] },
    { address: dai, abi: erc20Abi, functionName: 'balanceOf', args: [user] },
    { address: weth, abi: erc20Abi, functionName: 'balanceOf', args: [user] },
  ],
  allowFailure: true  // Returns Either[] instead of throwing
})
```

## Reference Files

For detailed service method signatures, see:
- [references/service-catalog.md](references/service-catalog.md)

## Reference

- Provider docs: https://voltaire-effect.tevm.sh/services/provider
- Signer docs: https://voltaire-effect.tevm.sh/services/signer
- Transport docs: https://voltaire-effect.tevm.sh/services/presets
