---
name: tevm-contract-deployment
description: Deploy contracts using ethers ContractFactory with Tevm. Use when deploying contracts in tests or local development.
---

# Contract Deployment with Tevm

## Using Ethers ContractFactory

```typescript
import { ContractFactory } from 'ethers'
import { Wallet } from 'ethers'
import { createMemoryClient } from 'tevm'
import { parseEther } from 'viem'

const client = createMemoryClient()

// Create signer
const signer = Wallet.createRandom().connect(
  new ethers.BrowserProvider(client)
)

// Fund the account
await client.setBalance({
  address: signer.address,
  value: parseEther('10')
})

// Create factory
const factory = new ContractFactory(abi, bytecode, signer)

// Deploy
const contract = await factory.deploy(...constructorArgs)

// Mine the deployment
await client.mine({ blocks: 1 })

// Get address
const address = await contract.getAddress()
console.log('Deployed to:', address)
```

## Using tevmDeploy Action

```typescript
import { tevmDeploy } from 'tevm/actions'

const result = await tevmDeploy(client, {
  abi,
  bytecode,
  args: [arg1, arg2],
  from: deployerAddress,
  gasLimit: 1000000n
})

console.log('Address:', result.address)
console.log('Gas used:', result.gasUsed)
```

## With Constructor Arguments

```typescript
// If constructor takes arguments, include in bytecode or pass as args
const contract = await factory.deploy(arg1, arg2)

// Or with tevmDeploy
const result = await tevmDeploy(client, {
  abi,
  bytecode: bytecodeWithConstructor,
  args: [arg1, arg2]
})
```

## Working with Events

```typescript
// Listen for deployment events
contract.on('Transfer', (from, to, amount, event) => {
  console.log('Transfer:', from, to, amount)
  console.log('Block:', event.blockNumber)
  console.log('Tx:', event.transactionHash)
})

// Query past events
const filter = contract.filters.Transfer()
const events = await contract.queryFilter(filter, -1000, 'latest')
```

## State Manipulation After Deployment

```typescript
// Set initial storage
await client.setAccount({
  address: contractAddress,
  state: {
    [slot0]: value0,
    [slot1]: value1
  }
})
```
