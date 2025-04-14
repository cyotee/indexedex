---
name: wagmi-read-contract
description: Read contract data with type-safe ABI. Use when querying smart contract view/pure functions.
---

# Read Contract

Type-safe contract reads.

## Basic Read

```typescript
import { readContract } from '@wagmi/core'
import { config } from './config'

const abi = [
  { type: 'function', name: 'balanceOf', stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }]
  },
  { type: 'function', name: 'totalSupply', stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }]
  }
] as const

const balance = await readContract(config, {
  abi,
  address: '0x6B175474E89094C44Da98b954EecdEfaE6E286AB',
  functionName: 'balanceOf',
  args: ['0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045']
})
```

## Read with Block Tag

```typescript
const balance = await readContract(config, {
  abi,
  address: tokenAddress,
  functionName: 'balanceOf',
  args: [address],
  blockTag: 'latest'     // 'latest', 'safe', 'finalized', 'earliest', 'pending'
})

// Or specific block
const balanceAtBlock = await readContract(config, {
  abi,
  address: tokenAddress,
  functionName: 'balanceOf',
  args: [address],
  blockNumber: 17829139n
})
```

## Read with Chain ID

```typescript
import { mainnet } from '@wagmi/core/chains'

const balance = await readContract(config, {
  abi,
  address: tokenAddress,
  functionName: 'balanceOf',
  args: [address],
  chainId: mainnet.id
})
```

## Multiple Reads

```typescript
import { readContracts } from '@wagmi/core'

const [balance, supply, decimals] = await readContracts(config, {
  contracts: [
    { abi, address: tokenAddress, functionName: 'balanceOf', args: [address] },
    { abi, address: tokenAddress, functionName: 'totalSupply' },
    { abi, address: tokenAddress, functionName: 'decimals' }
  ]
})
```

## TypeScript Types

With `as const` on ABI, types are inferred:

```typescript
// functionName is type-safe (only functions in abi)
abi: [...] as const

// args are type-safe (inferred from function params)
args: ['0x...']  // ✅ correct
args: [123n]     // ❌ type error for address param

// return type is inferred
const result: bigint = await readContract(config, { ... })
```
