---
name: Voltaire Effect Architecture
description: This skill should be used when the user asks about "voltaire-effect architecture", "voltaire-effect overview", "how does voltaire-effect work", "what is voltaire-effect", "Effect.ts Ethereum library", "Voltaire Effect layers", "decode use provide pattern", "voltaire-effect vs viem", "voltaire-effect vs ethers", "voltaire-effect getting started", or needs a high-level understanding of how voltaire-effect integrates Voltaire Ethereum primitives with Effect.ts.
version: 0.1.0
---

# Voltaire Effect Architecture

## Overview

voltaire-effect integrates Voltaire Ethereum primitives with Effect.ts, providing typed errors, dependency injection, and composable workflows for Ethereum development. It wraps Voltaire's branded `Uint8Array` types in Effect schemas for robust error handling and service-based composition.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    VOLTAIRE-EFFECT ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        APPLICATION CODE                                │ │
│  │                                                                        │ │
│  │   Effect.gen(function* () {                                           │ │
│  │     const addr = yield* S.decode(Address.Hex)(input)  // Schema      │ │
│  │     const bal  = yield* getBalance(addr)               // Effect     │ │
│  │     return bal                                                        │ │
│  │   })                                                                  │ │
│  └──────────────────────────────┬─────────────────────────────────────────┘ │
│                                 │                                            │
│                    Effect.provide(layers)                                    │
│                                 │                                            │
│  ┌──────────────────────────────▼─────────────────────────────────────────┐ │
│  │                         SERVICE LAYERS                                  │ │
│  │                                                                        │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐             │ │
│  │  │ Provider │  │  Signer  │  │ Transport│  │  Crypto  │  ...        │ │
│  │  │ Service  │  │ Service  │  │ Service  │  │ Services │             │ │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘             │ │
│  │                                                                        │ │
│  │  Production: *Live layers    Testing: *Test layers                    │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                 │                                            │
│  ┌──────────────────────────────▼─────────────────────────────────────────┐ │
│  │                      VOLTAIRE PRIMITIVES                                │ │
│  │                                                                        │ │
│  │  Branded Uint8Array types: Address, Hash, Signature, Transaction...   │ │
│  │  WASM-compiled crypto: keccak256 (9.2x faster than viem JS)           │ │
│  │  150+ Effect Schema wrappers for Ethereum data types                  │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Three-Layer Model

Organize applications using three composable layers:

### 1. Schema Layer - Validation & Type Coercion

Effect Schema wrappers decode raw input into Voltaire's branded types with typed errors:

```typescript
import * as Address from 'voltaire-effect/primitives/Address'
import * as S from 'effect/Schema'

// Decode returns Effect<AddressType, ParseError, never>
const addr = S.decodeSync(Address.Hex)('0x742d35Cc6634C0532925a3b844Bc9e7595f251e3')

// Checksummed encoding requires KeccakService
const checksummed = S.encode(Address.Checksummed)(addr)
// Effect<string, ParseError, KeccakService>
```

### 2. Effect Layer - Composable Operations

Free functions return Effects with typed errors and service requirements:

```typescript
import { getBalance, getBlockNumber } from 'voltaire-effect'

const program = Effect.gen(function* () {
  const block = yield* getBlockNumber()
  const balance = yield* getBalance(addr)
  return { block, balance }
})
// Type: Effect<{ block: bigint, balance: bigint }, GetBalanceError, ProviderService>
```

### 3. Services Layer - Dependency Injection

Declare services in type signatures and provide them at program boundaries:

```typescript
import { Provider, HttpTransport } from 'voltaire-effect'

const ProviderLayer = Provider.pipe(
  Layer.provide(HttpTransport('https://eth.llamarpc.com'))
)

// Provide at the edge - not scattered through code
await Effect.runPromise(program.pipe(Effect.provide(ProviderLayer)))
```

## Core Pattern: Decode → Use → Provide

```
  Input (string/hex)
        │
        ▼
  ┌─────────────┐
  │   DECODE     │  S.decode(Address.Hex)(input)
  │   (Schema)   │  → Effect<AddressType, ParseError>
  └──────┬──────┘
         │
         ▼
  ┌─────────────┐
  │    USE       │  getBalance(addr)
  │  (Effects)   │  → Effect<bigint, GetBalanceError, ProviderService>
  └──────┬──────┘
         │
         ▼
  ┌─────────────┐
  │   PROVIDE    │  Effect.provide(ProviderLayer)
  │  (Layers)    │  → Effect<bigint, GetBalanceError>
  └──────┬──────┘
         │
         ▼
  Effect.runPromise → bigint
```

## Installation

```bash
pnpm add voltaire-effect @tevm/voltaire effect
```

Requirements: Effect 3.x, Voltaire 0.x, TypeScript 5.4+

## Comparison with Alternatives

| Aspect | voltaire-effect | viem | ethers |
|--------|-----------------|------|--------|
| **Type Safety** | Branded Uint8Array | `0x${string}` | String |
| **Errors** | Typed values in signatures | Hidden exceptions | Hidden exceptions |
| **Composition** | `pipe` / `Effect.gen` | Manual chaining | Class methods |
| **Testing** | Layer swap (no code changes) | Mock imports | Mock classes |
| **Dependencies** | Explicit in types | Implicit globals | Implicit globals |
| **Bundle** | ~15KB Effect runtime overhead | Minimal | Heavier |

### When to Choose voltaire-effect

Adopt it for complex workflows requiring typed errors, composable operations, service dependency testing, or when already leveraging Effect in your application. For simpler scripts or bundle-size-critical apps, base Voltaire or viem may suffice.

## Layer Composition Rules

Compose layers once before providing, avoiding multiple chained `Effect.provide` calls:

```typescript
// Independent layers → mergeAll
const AppLayer = Layer.mergeAll(TransportLayer, CryptoLayer)

// Dependent layers → pipe + provide
const ProviderLayer = Provider.pipe(Layer.provide(TransportLayer))

// Add services while preserving existing → provideMerge
const FullLayer = Layer.provideMerge(ProviderLayer, CryptoLayer)
```

## Data-First API

Pass data as the first argument to enable pipeline composition:

```typescript
// voltaire-effect style (data-first)
Address.toHex(addr)
pipe(addr, Address.toHex)

// NOT OOP style
addr.toHex()  // not used
```

## Complete Example

End-to-end program demonstrating Decode → Use → Provide:

```typescript
import { Effect, Layer } from 'effect'
import * as S from 'effect/Schema'
import * as Address from 'voltaire-effect/primitives/Address'
import { getBalance, getBlockNumber, Provider, HttpTransport } from 'voltaire-effect'

// 1. DECODE: Validate input at the boundary
const program = Effect.gen(function* () {
  const addr = yield* S.decode(Address.Hex)('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045')

  // 2. USE: Compose operations with typed errors
  const blockNumber = yield* getBlockNumber()
  const balance = yield* getBalance(addr)

  return { blockNumber, balance }
})
// Type: Effect<{ blockNumber: bigint, balance: bigint }, ParseError | GetBalanceError, ProviderService>

// 3. PROVIDE: Inject services at the edge
const ProviderLayer = Provider.pipe(
  Layer.provide(HttpTransport('https://eth.llamarpc.com'))
)

const result = await Effect.runPromise(program.pipe(Effect.provide(ProviderLayer)))
console.log(`Block ${result.blockNumber}: ${result.balance} wei`)
```

Errors propagate through the type signature as the program composes. The `ParseError` from `S.decode` and the `GetBalanceError` from `getBalance` both appear in the final type, enabling exhaustive handling with `Effect.catchTag`. See `voltaire-effect-error-handling` for patterns.

## WASM-Compiled Crypto

Voltaire ships WASM-compiled cryptographic primitives. Keccak256 hashing runs 9.2x faster than viem's JavaScript implementation for 32-byte inputs. Import individual services (`KeccakLive`, `Secp256k1Live`) for tree-shaking, or use the combined `CryptoLive` layer for convenience. See `voltaire-effect-crypto` for the full service catalog.

## Progressive Disclosure

For deeper understanding, see these related skills:

| Skill | Topic |
|-------|-------|
| `voltaire-effect-schemas` | Branded types and Schema validation |
| `voltaire-effect-services` | Provider, Signer, Transport services |
| `voltaire-effect-error-handling` | Typed errors, catchTag, Either patterns |
| `voltaire-effect-crypto` | Cryptographic services (hashing, signing, encryption) |
| `voltaire-effect-contracts` | Type-safe contract read/write/simulate |
| `voltaire-effect-testing` | Test layers and mocking patterns |
| `voltaire-effect-streaming` | Block and event streaming with reorg detection |

## Reference

- Documentation: https://voltaire-effect.tevm.sh
- API Reference: https://voltaire-effect.tevm.sh/api-reference
- Cheatsheet: https://voltaire-effect.tevm.sh/cheatsheet
