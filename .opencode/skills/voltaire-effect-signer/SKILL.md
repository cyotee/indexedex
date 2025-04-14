---
name: voltaire-effect-signer
description: Transaction signing with local keys or wallets. Use when sending transactions or signing messages.
---

# Signer Service

Transaction signing with local accounts.

## From Private Key

```typescript
import { Effect, Layer } from 'effect'
import { Signer, Provider, HttpTransport } from 'voltaire-effect'
import { Secp256k1Live, KeccakLive } from 'voltaire-effect/crypto'
import { Hex } from '@tevm/voltaire'

const privateKey = Hex.fromHex('0xac0974bec...')

const CryptoLayer = Layer.mergeAll(Secp256k1Live, KeccakLive)
const TransportLayer = HttpTransport('https://eth.llamarpc.com')

const SignerLayer = Signer.fromPrivateKey(privateKey, Provider).pipe(
  Layer.provide(Layer.mergeAll(CryptoLayer, TransportLayer))
)
```

## From Mnemonic

```typescript
import { MnemonicAccount } from 'voltaire-effect/native'

const mnemonic = 'word1 word2 word3 ...'

const AccountLayer = MnemonicAccount(mnemonic).pipe(
  Layer.provide(CryptoLayer)
)

const SignerLayer = Layer.mergeAll(Signer.Live, AccountLayer)
```

## Send Transaction

```typescript
import { sendTransaction } from 'voltaire-effect'

const program = Effect.gen(function* () {
  const txHash = yield* sendTransaction({
    to: recipientAddress,
    value: 1000000000000000000n, // 1 ETH
    data: '0x...'
  })
  return txHash
}).pipe(Effect.provide(SignerLayer))
```

## Sign Message

```typescript
import { sign, signTypedData } from 'voltaire-effect'

const signature = yield* sign('Hello world', signerAddress)

const typedSig = yield* signTypedData({
  domain: { name: 'Example', version: '1', chainId: 1, verifyingContract: '0x...' },
  types: { Person: [{ name: 'name', type: 'string' }] },
  message: { name: 'Bob' }
})
```

## With Contract Write

```typescript
import { Contract } from 'voltaire-effect'

const program = Effect.gen(function* () {
  const token = yield* Contract(tokenAddress, erc20Abi)
  
  // Simulate first
  const success = yield* token.simulate.transfer(recipient, amount)
  if (!success) return yield* Effect.fail(new Error('Would fail'))
  
  // Send transaction
  const txHash = yield* token.write.transfer(recipient, amount)
  return txHash
}).pipe(Effect.provide(SignerLayer))
```

## Full Wallet Setup

```typescript
import { Effect, Layer } from 'effect'
import { Signer, Provider, HttpTransport, MnemonicAccount } from 'voltaire-effect'
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

const program = Effect.gen(function* () {
  return yield* sendTransaction({ to: '0x...', value: 1n })
}).pipe(Effect.provide(WalletLayer))
```
