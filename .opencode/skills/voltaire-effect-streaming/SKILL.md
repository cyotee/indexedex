---
name: Voltaire Effect Streaming
description: This skill should be used when the user asks about "voltaire-effect streaming", "watchBlocks", "block streaming", "event streaming", "reorg detection", "BlockStream", "TransactionStream", "subscribe", "real-time blockchain", or needs to understand how voltaire-effect handles real-time blockchain data.
version: 0.1.0
---

# Voltaire Effect Streaming

## Overview

voltaire-effect provides streaming services for real-time blockchain monitoring with built-in reorg detection, typed errors, and Effect composition. Two primary streams are available: block streaming and event/transaction streaming.

## Block Streaming

Watch for new blocks in real time:

```typescript
import { watchBlocks } from 'voltaire-effect'

const program = Effect.gen(function* () {
  const unsubscribe = yield* watchBlocks((block) => {
    console.log(`New block: ${block.number}`)
  })

  // Later: unsubscribe to stop watching
  return unsubscribe
})
```

## Event Streaming

Query and stream contract events:

```typescript
import { getLogs } from 'voltaire-effect'

// Historical query
const logs = yield* getLogs({
  fromBlock: 18000000n,
  toBlock: 'latest',
  address: contractAddress,
  topics: [transferEventTopic]
})
```

## Stream Error Types

Five typed errors for streaming operations:

| Error | When | Properties |
|-------|------|-----------|
| `StreamAbortedError` | AbortSignal triggered | - |
| `EventStreamAbortedError` | Event stream aborted | - |
| `BlockStreamAbortedError` | Block stream aborted | - |
| `BlockRangeTooLargeError` | RPC rejects range | `fromBlock`, `toBlock` |
| `UnrecoverableReorgError` | Deep chain reorg | `reorgDepth`, `trackedDepth` |

## Handling Stream Errors

### Targeted Recovery

```typescript
const program = streamEvents(config).pipe(
  Effect.catchTag('BlockRangeTooLargeError', (e) => {
    // Retry with smaller range
    const midBlock = (e.fromBlock + e.toBlock) / 2n
    return Effect.all([
      streamEvents({ ...config, toBlock: midBlock }),
      streamEvents({ ...config, fromBlock: midBlock + 1n })
    ])
  })
)
```

### Exhaustive Matching

```typescript
import { Match } from 'effect'

const handled = streamProgram.pipe(
  Effect.catchAll(
    Match.value.pipe(
      Match.tag('BlockStreamAbortedError', () => reconnect()),
      Match.tag('BlockRangeTooLargeError', () => reduceRange()),
      Match.tag('UnrecoverableReorgError', () => resetFromSafeBlock()),
      Match.exhaustive
    )
  )
)
```

## Reorg Detection

The `UnrecoverableReorgError` fires when a chain reorganization exceeds the tracked history depth:

```
  Normal operation:
  Block 100 → 101 → 102 → 103  (sequential, no reorg)

  Shallow reorg (handled automatically):
  Block 100 → 101 → 102 → 101' → 102' → 103'
                              ↑ reorgDepth = 2

  Deep reorg (UnrecoverableReorgError):
  Block 100 → 101 → ... → 110 → 95' → 96' → ...
                                   ↑ reorgDepth > trackedDepth
```

## WebSocket Subscriptions

For lower-latency streaming, use WebSocket transport:

```typescript
import { WebSocketTransport, Provider } from 'voltaire-effect'

const WsProvider = Provider.pipe(
  Layer.provide(WebSocketTransport('wss://eth.llamarpc.com'))
)

// subscribe/unsubscribe for raw JSON-RPC subscriptions
const program = Effect.gen(function* () {
  const subId = yield* subscribe('newHeads')
  // ... handle subscription messages
  yield* unsubscribe(subId)
})
```

## Composing Streams with Effect

Leverage Effect's concurrency primitives:

```typescript
// Run multiple streams concurrently
const program = Effect.all({
  blocks: watchBlocks(handleBlock),
  events: streamEvents(eventConfig),
  txs: streamTransactions(txConfig)
})

// With timeout
watchBlocks(handler).pipe(withTimeout("30 seconds"))

// With retry on disconnect
watchBlocks(handler).pipe(
  withRetrySchedule(Schedule.exponential("1 second").pipe(
    Schedule.jittered,
    Schedule.compose(Schedule.recurs(10))
  ))
)
```

## Reference

- Stream docs: https://voltaire-effect.tevm.sh/stream
- Block streaming example: https://voltaire-effect.tevm.sh/examples/block-streaming
- Event streaming example: https://voltaire-effect.tevm.sh/examples/event-streaming
