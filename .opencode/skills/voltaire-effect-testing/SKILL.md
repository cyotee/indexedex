---
name: Voltaire Effect Testing
description: This skill should be used when the user asks about "voltaire-effect testing", "CryptoTest", "TestTransport", "mock provider", "test layers", "layer swap testing", "Effect test patterns", "deterministic crypto", or needs to understand how to test programs built with voltaire-effect.
version: 0.1.0
---

# Voltaire Effect Testing

## Overview

voltaire-effect's service model makes testing straightforward - swap production layers with test layers at program boundaries without changing application code. Test layers provide deterministic outputs and mock responses.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TESTING STRATEGY                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Same application code:                                                      │
│  ┌────────────────────────────────────────────────────────┐                 │
│  │  const program = Effect.gen(function* () {             │                 │
│  │    const balance = yield* getBalance(addr)             │                 │
│  │    const hash = yield* keccak.hash(data)               │                 │
│  │    return { balance, hash }                            │                 │
│  │  })                                                    │                 │
│  └────────────────────────────────────────────────────────┘                 │
│                                                                              │
│  Production:                          Testing:                              │
│  ┌──────────────────────┐            ┌──────────────────────┐              │
│  │ Effect.provide(       │            │ Effect.provide(       │              │
│  │   Layer.mergeAll(     │            │   Layer.mergeAll(     │              │
│  │     ProviderLive,     │            │     TestTransport,    │              │
│  │     CryptoLive        │            │     CryptoTest        │              │
│  │   )                   │            │   )                   │              │
│  │ )                     │            │ )                     │              │
│  └──────────────────────┘            └──────────────────────┘              │
│   ↓ Real HTTP, real crypto            ↓ Mock responses, deterministic      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Schema Testing

Schema decode is pure - test directly without services:

```typescript
import * as Address from 'voltaire-effect/primitives/Address'
import * as S from 'effect/Schema'

// Valid input
test('decodes valid address', () => {
  const addr = S.decodeSync(Address.Hex)('0x742d35Cc6634C0532925a3b844Bc9e7595f251e3')
  expect(addr).toBeInstanceOf(Uint8Array)
  expect(addr.length).toBe(20)
})

// Invalid input (throws synchronously)
test('rejects invalid address', () => {
  expect(() => S.decodeSync(Address.Hex)('not-an-address')).toThrow()
})

// Using Either for non-throwing tests
test('returns Left for invalid input', () => {
  const result = S.decodeEither(Address.Hex)('bad')
  expect(Either.isLeft(result)).toBe(true)
})
```

## TestTransport

Mock JSON-RPC responses by method name:

```typescript
import { TestTransport } from 'voltaire-effect'

const MockTransport = TestTransport({
  eth_blockNumber: '0x10',
  eth_getBalance: '0xde0b6b3a7640000',  // 1 ETH
  eth_call: '0x0000000000000000000000000000000000000000000000000000000005f5e100'
})

const TestProvider = Provider.pipe(Layer.provide(MockTransport))
```

### Mocking Errors

```typescript
import { TransportError } from 'voltaire-effect'

const ErrorTransport = TestTransport({
  eth_getBalance: new TransportError({
    code: -32000,
    message: 'execution reverted'
  })
})
```

## CryptoTest

Deterministic crypto outputs for reproducible tests:

```typescript
import { CryptoTest } from 'voltaire-effect/crypto'

// CryptoTest provides all crypto services with deterministic output
// No actual cryptographic computation - fast and predictable
const TestLayer = Layer.mergeAll(TestProvider, CryptoTest)

const result = await Effect.runPromise(
  program.pipe(Effect.provide(TestLayer))
)
```

## Composing Test Layers

```typescript
// Minimal test environment
const UnitTestLayer = Layer.mergeAll(
  TestTransport({ eth_blockNumber: '0x1' }),
  CryptoTest
)

// Full test environment with provider
const IntegrationTestLayer = Layer.mergeAll(
  Provider.pipe(Layer.provide(
    TestTransport({
      eth_blockNumber: '0x10',
      eth_getBalance: '0xde0b6b3a7640000'
    })
  )),
  CryptoTest
)
```

## Testing Error Handling

Verify error branches are handled:

```typescript
test('handles transport errors gracefully', async () => {
  const ErrorLayer = Provider.pipe(
    Layer.provide(TestTransport({
      eth_getBalance: new TransportError({ code: -32000, message: 'reverted' })
    }))
  )

  const program = getBalance(addr).pipe(
    Effect.catchTag('TransportError', () => Effect.succeed(0n))
  )

  const result = await Effect.runPromise(program.pipe(Effect.provide(ErrorLayer)))
  expect(result).toBe(0n)
})
```

## Integration Testing

For end-to-end validation against live networks:

```typescript
const LiveLayer = Provider.pipe(
  Layer.provide(HttpTransport('https://eth.llamarpc.com'))
)

test('reads real block number', async () => {
  const blockNumber = await Effect.runPromise(
    getBlockNumber().pipe(Effect.provide(LiveLayer))
  )
  expect(blockNumber).toBeGreaterThan(0n)
})
```

## Service Mocking Pattern

Create custom mock services for fine-grained control:

```typescript
const MockProvider = Layer.succeed(ProviderService, {
  request: (method, params) => {
    switch (method) {
      case 'eth_blockNumber':
        return Effect.succeed('0x10')
      case 'eth_getBalance':
        return Effect.succeed('0xde0b6b3a7640000')
      default:
        return Effect.fail(new ProviderResponseError({ message: `Unexpected: ${method}` }))
    }
  }
})
```

## Testing Best Practices

1. **Schema tests** - Test decode/encode directly with `decodeSync` or `decodeEither`
2. **Service tests** - Use `TestTransport` + `CryptoTest` for fast, deterministic unit tests
3. **Error tests** - Mock failures with `TransportError` and verify `catchTag` handling
4. **Integration tests** - Use `HttpTransport` to a live RPC for end-to-end validation
5. **No code changes** - Same program code works with both production and test layers

## Reference

- Testing docs: https://voltaire-effect.tevm.sh/testing
- Effect testing guide: https://effect.website/docs/testing
