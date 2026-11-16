---
name: wagmi-write-contract
description: Write to contracts and send transactions. Use when executing state-changing contract functions.
---

# Write Contract

Send transactions to contract functions.

## Basic Write

```typescript
import { writeContract } from '@wagmi/core'
import { config } from './config'

const abi = [
  { type: 'function', name: 'transfer', stateMutability: 'nonpayable',
    inputs: [{ name: 'to', type: 'address' }, { name: 'amount', type: 'uint256' }],
    outputs: [{ type: 'bool' }]
  }
] as const

const hash = await writeContract(config, {
  abi,
  address: tokenAddress,
  functionName: 'transfer',
  args: [recipientAddress, 1000000n]
})
```

## Simulate Before Write

Validate transaction before sending:

```typescript
import { simulateContract, writeContract } from '@wagmi/core'

const { request } = await simulateContract(config, {
  abi,
  address: tokenAddress,
  functionName: 'transfer',
  args: [recipient, 1000000n]
})

const hash = await writeContract(config, request)
```

## With Gas Settings

```typescript
import { parseGwei, parseEther } from 'viem'

const hash = await writeContract(config, {
  abi,
  address: tokenAddress,
  functionName: 'transfer',
  args: [to, amount],
  
  // EIP-1559
  maxFeePerGas: parseGwei('20'),
  maxPriorityFeePerGas: parseGwei('2'),
  
  // Or legacy
  gasPrice: parseGwei('10'),
  
  // Or set gas manually
  gas: 50000n,
  
  // Value (for payable functions)
  value: parseEther('0.01')
})
```

## writeContractSync (Wait for Receipt)

```typescript
import { writeContractSync } from '@wagmi/core'

const receipt = await writeContractSync(config, {
  abi,
  address: tokenAddress,
  functionName: 'transfer',
  args: [to, amount]
})

console.log(receipt.status)  // 'success' | 'reverted'
console.log(receipt.blockNumber)
```

## With Account

```typescript
const hash = await writeContract(config, {
  abi,
  address: tokenAddress,
  functionName: 'transfer',
  args: [to, amount],
  account: '0x...'  // specific account (must be connected)
})
```

## Chain Validation

```typescript
import { mainnet } from '@wagmi/core/chains'

// Ensure transaction goes to specific chain
const hash = await writeContract(config, {
  abi,
  address: tokenAddress,
  functionName: 'transfer',
  args: [to, amount],
  chainId: mainnet.id  // will throw if wrong chain
})
```
