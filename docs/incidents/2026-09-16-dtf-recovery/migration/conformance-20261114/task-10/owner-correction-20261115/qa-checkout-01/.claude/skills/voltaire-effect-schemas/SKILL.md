---
name: Voltaire Effect Schemas & Branded Types
description: This skill should be used when the user asks about "voltaire branded types", "Effect Schema Ethereum", "Address schema", "Hash schema", "Uint8Array branded", "S.decode address", "ParseError", "voltaire primitives", "type safety Ethereum", or needs to understand how voltaire-effect handles type-safe Ethereum data.
version: 0.1.0
---

# Voltaire Effect Schemas & Branded Types

## Overview

voltaire-effect provides 150+ Effect Schema wrappers that decode raw input into Voltaire's branded `Uint8Array` types. This gives compile-time type safety (Address vs Hash are distinct types) with zero runtime overhead, validated once at the boundary.

## Branded Types

Branded types add a nominal tag to `Uint8Array`, preventing type confusion at compile time:

```typescript
type AddressType = Uint8Array & { readonly __tag: "Address" }
type HashType = Uint8Array & { readonly __tag: "Hash" }

// TypeScript prevents mixing:
function transfer(to: AddressType, txHash: HashType) { ... }
transfer(myHash, myAddress)  // ← Compile error! Types don't match
```

At runtime both are plain `Uint8Array` - brands exist only in the type system.

## Schema Decode Patterns

### Basic Decoding

```typescript
import * as Address from 'voltaire-effect/primitives/Address'
import * as Hash from 'voltaire-effect/primitives/Hash'
import * as S from 'effect/Schema'

// Synchronous (throws on failure)
const addr = S.decodeSync(Address.Hex)('0x742d35Cc6634C0532925a3b844Bc9e7595f251e3')
// Returns: AddressType (branded Uint8Array)

// Effectful (typed ParseError)
const addrEffect = S.decode(Address.Hex)(input)
// Type: Effect<AddressType, ParseError, never>

// Either for branching
const addrEither = S.decodeEither(Address.Hex)(input)
// Type: Either<AddressType, ParseError>
```

### Checksummed Addresses

Encoding to checksummed hex requires the Keccak service:

```typescript
import { KeccakLive } from 'voltaire-effect/crypto/Keccak256'

const checksummed = await Effect.runPromise(
  S.encode(Address.Checksummed)(addr).pipe(Effect.provide(KeccakLive))
)
// "0x742d35Cc6634C0532925a3b844Bc9e7595f251e3"
```

### Handling Parse Errors

```typescript
const parseAddress = (input: string) =>
  S.decode(Address.Hex)(input).pipe(
    Effect.catchTag('ParseError', () =>
      Effect.succeed(Address.zero())
    )
  )
```

`ParseError` contains a structured issue tree describing exactly what went wrong - field path, expected type, received value.

## Primary Schema Categories

### Primitives

| Schema | Input | Output | Size |
|--------|-------|--------|------|
| `Address.Hex` | `0x${string}` (40 hex chars) | `AddressType` | 20 bytes |
| `Hash.Hex` | `0x${string}` (64 hex chars) | `HashType` | 32 bytes |
| `Signature.Hex` | `0x${string}` (130 hex chars) | `SignatureType` | 65 bytes |
| `Address.Checksummed` | EIP-55 checksummed | `AddressType` | 20 bytes |

### Numeric Types

Integer schemas cover the full Solidity range:

| Schema | Range |
|--------|-------|
| `Uint8` - `Uint256` | 0 to 2^N - 1 |
| `Int8` - `Int256` | -2^(N-1) to 2^(N-1) - 1 |

### Transaction & Block Types

Schemas for complex Ethereum structures:

- `Transaction` - Full transaction object with EIP-1559/4844/7702 support
- `Block` - Block header and body
- `Log` - Event log entries
- `TransactionReceipt` - Execution receipt

## Single Validation Point

Decode once at the boundary; downstream operations skip re-validation:

```
  Raw input ("0xabc...")
       │
       ▼ S.decode(Address.Hex)
  AddressType (branded, validated)
       │
       ├──▶ getBalance(addr)        ← no re-validation
       ├──▶ Contract.read(addr)      ← no re-validation
       └──▶ Address.toHex(addr)      ← no re-validation
```

## Interoperability

Decoded branded values work directly with both Voltaire and Effect functions:

```typescript
// Works with Voltaire's native functions
import { keccak256 } from '@tevm/voltaire'
const hash = keccak256(addr)  // Accepts Uint8Array

// Works with Effect Schema encoding
const hex = S.encodeSync(Address.Hex)(addr)  // "0x742d..."
```

## Reference

- Primitives index: https://voltaire-effect.tevm.sh/api-reference
- Branded types concept: https://voltaire-effect.tevm.sh/concepts/branded-types
