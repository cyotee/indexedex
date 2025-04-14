---
name: Voltaire Effect Crypto Services
description: This skill should be used when the user asks about "voltaire-effect crypto", "KeccakService", "Secp256k1", "BLS12-381", "AES-GCM", "HDWallet", "BIP-39", "CryptoLive", "CryptoTest", "keccak256 Effect", "ECDSA Effect", "voltaire hashing", "voltaire signing", or needs to understand the cryptographic services in voltaire-effect.
version: 0.1.0
---

# Voltaire Effect Crypto Services

## Overview

voltaire-effect wraps cryptographic operations as Effect services, enabling dependency injection and test substitution. Use `CryptoLive` for production (WASM-compiled, high performance) or `CryptoTest` for testing (deterministic, zero crypto overhead).

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      CRYPTO SERVICE ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  CryptoLive (all production services)                                │   │
│  │  CryptoTest (all deterministic test services)                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  Or import individually for tree-shaking:                                   │
│                                                                              │
│  Hashing          Signatures        Encryption        Key Derivation        │
│  ┌──────────┐    ┌──────────┐      ┌──────────┐     ┌──────────┐          │
│  │ Keccak256│    │ Secp256k1│      │  AES-GCM │     │ HDWallet │          │
│  │ SHA256   │    │ Ed25519  │      │ ChaCha20 │     │ BIP-39   │          │
│  │ Blake2   │    │ P256     │      │ Poly1305 │     │ Keystore │          │
│  │ RIPEMD160│    │ BLS12-381│      │ X25519   │     │ HMAC     │          │
│  └──────────┘    └──────────┘      └──────────┘     └──────────┘          │
│                                                                              │
│  Zero Knowledge                                                             │
│  ┌──────────┐                                                               │
│  │  BN254   │                                                               │
│  │  KZG     │                                                               │
│  └──────────┘                                                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Combined Layers

### CryptoLive

Bundles all production crypto services:

```typescript
import { CryptoLive } from 'voltaire-effect/crypto'

const program = Effect.gen(function* () {
  const keccak = yield* KeccakService
  const hash = yield* keccak.hash(data)
  return hash
})

await Effect.runPromise(program.pipe(Effect.provide(CryptoLive)))
```

### CryptoTest

Deterministic outputs for testing without crypto overhead:

```typescript
import { CryptoTest } from 'voltaire-effect/crypto'

// Same code, different layer - no code changes needed
await Effect.runPromise(program.pipe(Effect.provide(CryptoTest)))
// Returns predictable, deterministic values
```

## Individual Services

### Keccak256 (Hashing)

WASM-compiled, 9.2x faster than viem's JavaScript implementation for 32-byte inputs:

```typescript
import { KeccakService, KeccakLive } from 'voltaire-effect/crypto/Keccak256'

const program = Effect.gen(function* () {
  const keccak = yield* KeccakService
  return yield* keccak.hash(data)  // Uint8Array → HashType
})

Effect.runPromise(program.pipe(Effect.provide(KeccakLive)))
```

### Secp256k1 (ECDSA)

For Ethereum signatures and key recovery:

```typescript
import { Secp256k1Service, Secp256k1Live } from 'voltaire-effect/crypto/Secp256k1'

const program = Effect.gen(function* () {
  const secp = yield* Secp256k1Service
  const signature = yield* secp.sign(messageHash, privateKey)
  const publicKey = yield* secp.recover(messageHash, signature)
  return publicKey
})
```

### BLS12-381 (Aggregate Signatures)

For beacon chain / validator operations:

```typescript
import { BLS12381Service, BLS12381Live } from 'voltaire-effect/crypto/BLS12381'
```

### AES-GCM (Symmetric Encryption)

```typescript
import { AesGcmService, AesGcmLive } from 'voltaire-effect/crypto/AesGcm'

const program = Effect.gen(function* () {
  const aes = yield* AesGcmService
  const encrypted = yield* aes.encrypt(key, plaintext, nonce)
  const decrypted = yield* aes.decrypt(key, encrypted, nonce)
  return decrypted
})
```

### HDWallet (Key Derivation)

Hierarchical deterministic wallets:

```typescript
import { HDWalletService, HDWalletLive } from 'voltaire-effect/crypto/HDWallet'

const program = Effect.gen(function* () {
  const hd = yield* HDWalletService
  const seed = yield* hd.fromMnemonic(mnemonic)
  const key = yield* hd.derivePath(seed, "m/44'/60'/0'/0/0")
  return key
})
```

**Note**: HDWallet requires native FFI, available in Node/Bun only (not browser).

### BIP-39 (Mnemonic Phrases)

```typescript
import { BIP39Service, BIP39Live } from 'voltaire-effect/crypto/BIP39'

const program = Effect.gen(function* () {
  const bip39 = yield* BIP39Service
  const mnemonic = yield* bip39.generate(128)  // 12 words
  const seed = yield* bip39.toSeed(mnemonic)
  return { mnemonic, seed }
})
```

## EIP-712 Typed Data

Structured data signing per EIP-712:

```typescript
import { EIP712 } from 'voltaire-effect/crypto/EIP712'
```

## Signers Module

Unified signing interface supporting EIP-191, EIP-712, EIP-1559, EIP-4844, and EIP-7702:

```typescript
import { Signers } from 'voltaire-effect/crypto/Signers'
```

## Composing Crypto Layers

Import only what you need:

```typescript
// Just hashing + signatures
const MinimalCrypto = Layer.mergeAll(KeccakLive, Secp256k1Live)

// Full crypto stack
const FullLayer = Layer.mergeAll(
  ProviderLayer,
  KeccakLive,
  Secp256k1Live,
  SignerLayer
)
```

## Runtime Support

| Service | Browser/WASM | Node/Bun |
|---------|-------------|----------|
| Keccak256 | WASM | WASM |
| Secp256k1 | WASM | WASM |
| HDWallet | Not available | Native FFI |
| BIP-39 | Available | Available |
| AES-GCM | WebCrypto | Native |
| BLS12-381 | WASM | WASM |

## Reference

- Crypto overview: https://voltaire-effect.tevm.sh/crypto
- Individual services: https://voltaire-effect.tevm.sh/crypto/{service-name}
