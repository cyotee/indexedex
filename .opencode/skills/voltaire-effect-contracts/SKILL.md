---
name: voltaire-effect-contracts
description: Type-safe contract interaction with Contract factory. Use when reading or writing to smart contracts.
---

# Contract Factory

Type-safe contract interaction with Effect.ts.

## Basic Usage

```typescript
import { Effect, Layer } from 'effect'
import { Contract, Provider, HttpTransport } from 'voltaire-effect'

const erc20Abi = [
  { type: 'function', name: 'balanceOf', stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: 'balance', type: 'uint256' }] },
  { type: 'function', name: 'transfer', stateMutability: 'nonpayable',
    inputs: [{ name: 'to', type: 'address' }, { name: 'amount', type: 'uint256' }],
    outputs: [{ name: 'success', type: 'bool' }] },
] as const

const ProviderLayer = Provider.pipe(
  Layer.provide(HttpTransport('https://eth.llamarpc.com'))
)

const program = Effect.gen(function* () {
  const token = yield* Contract('0x6B175474E89094C44Da98b954EecdEfaE6E286AB', erc20Abi)
  const balance = yield* token.read.balanceOf(userAddress)
  return balance
}).pipe(Effect.provide(ProviderLayer))
```

## Read (View Functions)

```typescript
const balance = yield* contract.read.balanceOf(userAddress)
```

## Write (State-Changing)

```typescript
const txHash = yield* contract.write.transfer(recipientAddress, 1000n)
```

## Simulate

```typescript
const success = yield* contract.simulate.transfer(recipientAddress, 1000n)
if (!success) {
  return yield* Effect.fail(new Error('Transfer would fail'))
}
```

## Events

```typescript
const transfers = yield* contract.getEvents('Transfer', {
  fromBlock: 18000000n,
  toBlock: 'latest',
  args: { from: userAddress }
})
```

## Type Safety

Types are inferred from ABI:

```typescript
contract.read.balanceOf(address)     // ✅ takes address
contract.read.balanceOf(123n)        // ❌ type error
contract.write.balanceOf(address)    // ❌ type error - balanceOf is view
```

## With Signer

```typescript
import { Effect, Layer } from 'effect'
import { Contract, Signer, LocalAccount, Provider, HttpTransport } from 'voltaire-effect'
import { Secp256k1Live, KeccakLive } from 'voltaire-effect/crypto'
import { Hex } from '@tevm/voltaire'

const privateKey = Hex.fromHex('0xac0974bec...')

const CryptoLayer = Layer.mergeAll(Secp256k1Live, KeccakLive)
const TransportLayer = HttpTransport('https://eth.llamarpc.com')
const SignerLayer = Signer.fromPrivateKey(privateKey, Provider).pipe(
  Layer.provide(Layer.mergeAll(CryptoLayer, TransportLayer))
)

const program = Effect.gen(function* () {
  const token = yield* Contract(tokenAddress, erc20Abi)
  const balance = yield* token.read.balanceOf(user)
  const txHash = yield* token.write.transfer(recipient, 100n)
  return { balance, txHash }
}).pipe(Effect.provide(SignerLayer))
```
