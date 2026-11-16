---
name: voltaire-effect-error-handling
description: Typed error handling with Effect Schema and services. Use when handling parse errors, network failures, or contract reverts.
---

# Error Handling

Typed errors with Effect Schema - errors are values, not exceptions.

## Schema Errors (ParseError)

```typescript
import * as S from 'effect/Schema'
import * as Address from 'voltaire-effect/primitives/Address'
import * as Effect from 'effect/Effect'

// Sync - throws
try {
  S.decodeSync(Address.Hex)('invalid')
} catch (e) {
  // e is ParseError
}

// Effect - typed error in signature
const result = S.decode(Address.Hex)('invalid')
// Effect<AddressType, ParseError, never>
```

## Handle with catchTag

```typescript
import * as Address from 'voltaire-effect/primitives/Address'

const program = S.decode(Address.Hex)(input).pipe(
  Effect.catchTag('ParseError', (e) => 
    Effect.succeed(Address.zero())  // fallback
  )
)
```

## Provider Errors

```typescript
import { getBlock, withTimeout } from 'voltaire-effect'
import { ProviderNotFoundError, ProviderTimeoutError, TransportError } from 'voltaire-effect'

const program = Effect.gen(function* () {
  return yield* getBlock({ blockTag: 'latest' }).pipe(
    withTimeout('5 seconds')
  )
}).pipe(
  Effect.catchTags({
    TransportError: (e) => Effect.succeed(null),
    ProviderTimeoutError: (e) => Effect.succeed(null),
    ProviderNotFoundError: (e) => Effect.succeed(null)
  })
)
```

## Contract Errors

```typescript
import { ContractCallError, ContractWriteError } from 'voltaire-effect'

program.pipe(
  Effect.catchTag('ContractCallError', (e) => 
    Effect.succeed({ error: e.message })
  ),
  Effect.catchTag('ContractWriteError', (e) => 
    Effect.succeed({ error: e.message })
  )
)
```

## Error Types

| Error | Tag | Source |
|-------|-----|--------|
| ParseError | ParseError | Schema decode |
| TransportError | TransportError | Network failure |
| ProviderResponseError | ProviderResponseError | Invalid response |
| ProviderNotFoundError | ProviderNotFoundError | Missing block/tx |
| ProviderTimeoutError | ProviderTimeoutError | Timeout |
| SignerError | SignerError | Signing failure |
| CryptoError | CryptoError | Crypto operation |

## Retry with Schedule

```typescript
import { Schedule } from 'effect'
import { getBalance, withRetrySchedule } from 'voltaire-effect'

const retrySchedule = Schedule.exponential('500 millis').pipe(
  Schedule.jittered,
  Schedule.recurs(5)
)

getBalance(addr).pipe(
  withRetrySchedule(retrySchedule)
)
```

## Either for Partial Failures

For multicall where some calls may fail:

```typescript
import { Either, Array } from 'effect'

const results = yield* multicall({ contracts: [...] })

// Transform to Either
const transformed = results.map(r =>
  r.status === 'success'
    ? Either.right(r.result)
    : Either.left({ error: r.error })
)

// Filter successes
const successes = transformed.filter(Either.isRight).map(r => r.right)
```
