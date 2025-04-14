---
name: voltaire-effect-overview
description: Type-safe Ethereum library with Effect.ts integration. Use when building TypeScript Ethereum apps with typed errors, composable operations, and full type safety.
---

# Voltaire-Effect Overview

Effect.ts integration for Ethereum with typed errors and composable operations.

## Install

```bash
pnpm add voltaire-effect @tevm/voltaire effect
```

## Quick Start

```typescript
import { Effect, Layer } from 'effect'
import { getBlockNumber, Provider, HttpTransport } from 'voltaire-effect'

const ProviderLayer = Provider.pipe(
  Layer.provide(HttpTransport('https://eth.llamarpc.com'))
)

const program = Effect.gen(function* () {
  return yield* getBlockNumber()
})

const blockNumber = await Effect.runPromise(program.pipe(Effect.provide(ProviderLayer)))
```

## Core Concepts

- **Schema** - Validation with typed errors
- **Effect** - Composable async operations
- **Services** - Stateful resources (Provider, Signer)

## Skills

- **Provider**: `voltaire-effect-provider` - JSON-RPC operations
- **Contracts**: `voltaire-effect-contracts` - Type-safe contract interaction
- **Signer**: `voltaire-effect-signer` - Transaction signing
- **Layers**: `voltaire-effect-layers` - Dependency composition
- **Errors**: `voltaire-effect-error-handling` - Typed error handling

## Key Features

- **Branded types** - Zero-cost type safety
- **Typed errors** - No more untyped exceptions
- **Retry/timeout** - Built-in Effect patterns
- **Multicall** - Batch reads efficiently
