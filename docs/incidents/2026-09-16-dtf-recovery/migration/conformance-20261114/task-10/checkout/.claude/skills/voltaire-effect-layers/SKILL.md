---
name: voltaire-effect-layers
description: Layer composition patterns for dependency injection. Use when composing providers, signers, and crypto services.
---

# Layer Composition

Three-layer architecture: Schema, Effect, Services.

## Layer Types

| Layer | Purpose |
|-------|---------|
| Schema | Validation, type coercion |
| Effect | Composable operations |
| Services | Stateful resources |

## Basic Composition

```typescript
import { Layer } from 'effect'
import { Provider, HttpTransport, Signer } from 'voltaire-effect'

// Combine layers
const AppLayer = Layer.mergeAll(
  Provider,
  Signer
).pipe(
  Layer.provide(HttpTransport('https://eth.llamarpc.com'))
)

// Provide once at edge
program.pipe(Effect.provide(AppLayer))
```

## Common Patterns

### Merge Independent Layers

```typescript
Layer.mergeAll(Provider, Signer, CryptoLive)
```

### A Depends on B

```typescript
// Provider depends on Transport
const ProviderLayer = Provider.pipe(
  Layer.provide(HttpTransport(url))
)
```

### Add Services While Keeping Existing

```typescript
Layer.provideMerge(AdditionalService)
```

## Full Setup Example

```typescript
import { Effect, Layer } from 'effect'
import { Signer, Provider, HttpTransport } from 'voltaire-effect'
import { MnemonicAccount } from 'voltaire-effect/native'
import { Secp256k1Live, KeccakLive } from 'voltaire-effect/crypto'

const CryptoLayer = Layer.mergeAll(Secp256k1Live, KeccakLive)
const TransportLayer = HttpTransport('https://eth.llamarpc.com')
const ProviderLayer = Provider.pipe(Layer.provide(TransportLayer))

const WalletLayer = Layer.mergeAll(
  Signer.Live,
  CryptoLayer,
  ProviderLayer
).pipe(
  Layer.provideMerge(MnemonicAccount(mnemonic).pipe(Layer.provide(CryptoLayer)))
)

// Single provide
await Effect.runPromise(program.pipe(Effect.provide(WalletLayer)))
```

## Anti-Pattern

```typescript
// ❌ Don't chain provides
program.pipe(
  Effect.provide(Signer.Live),
  Effect.provide(Provider),
  Effect.provide(HttpTransport(url))
)

// ✅ Compose first, then provide
const AppLayer = Layer.mergeAll(Signer.Live, Provider).pipe(
  Layer.provide(HttpTransport(url))
)
program.pipe(Effect.provide(AppLayer))
```
