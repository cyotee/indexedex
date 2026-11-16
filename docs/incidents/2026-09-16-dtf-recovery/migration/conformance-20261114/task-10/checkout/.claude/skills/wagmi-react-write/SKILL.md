---
name: wagmi-react-write
description: useWriteContract hook for sending transactions. Use when executing state-changing contract functions in React.
---

# Wagmi-React Write

useWriteContract and related hooks.

## Basic Write

```typescript
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'

function Transfer({ tokenAddress }) {
  const { writeContract, isPending } = useWriteContract()

  const handleTransfer = () => {
    writeContract({
      abi: [...],
      address: tokenAddress,
      functionName: 'transfer',
      args: [recipient, amount]
    })
  }

  return (
    <button onClick={handleTransfer} disabled={isPending}>
      {isPending ? 'Confirming...' : 'Transfer'}
    </button>
  )
}
```

## With Simulation

Validate before sending:

```typescript
import { useSimulateContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'

function Transfer() {
  const { data: simData } = useSimulateContract({
    abi,
    address,
    functionName: 'transfer',
    args: [to, amount]
  })

  const { writeContract } = useWriteContract()

  return (
    <button
      onClick={() => writeContract(simData?.request)}
      disabled={!simData}
    >
      Transfer
    </button>
  )
}
```

## Wait for Receipt

```typescript
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'

function Transfer() {
  const { data: hash, writeContract } = useWriteContract()

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash
  })

  const handleTransfer = () => {
    writeContract({ abi, address, functionName: 'transfer', args: [to, amount] })
  }

  return (
    <div>
      <button onClick={handleTransfer}>Transfer</button>
      {isConfirming && <div>Confirming...</div>}
      {isSuccess && <div>Confirmed!</div>}
    </div>
  )
}
```

## writeContractAsync

```typescript
const { writeContractAsync } = useWriteContract()

async function handleTransfer() {
  try {
    const hash = await writeContractAsync({
      abi,
      address,
      functionName: 'transfer',
      args: [to, amount]
    })
    console.log('Transaction hash:', hash)
  } catch (error) {
    console.error('Transaction failed:', error)
  }
}
```

## Parameters

```typescript
import { parseEther, parseGwei } from 'viem'

writeContract({
  abi,
  address,
  functionName: 'transfer',
  args: [to, amount],
  
  // Gas options
  gas: 50000n,
  maxFeePerGas: parseGwei('20'),
  maxPriorityFeePerGas: parseGwei('2'),
  
  // Value for payable functions
  value: parseEther('0.01')
})
```

## Chain ID Validation

```typescript
import { mainnet } from 'wagmi/chains'

// Will throw if not on correct chain
writeContract({
  abi,
  address,
  functionName: 'transfer',
  args: [to, amount],
  chainId: mainnet.id
})
```
