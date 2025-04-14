---
name: wagmi-react-hooks
description: React hooks for blockchain queries and mutations. Use when reading/writing contracts or querying chain data.
---

# Wagmi-React Hooks

Overview of React hooks.

## Query vs Write Hooks

- **Query hooks** - Read data (useReadContract, useBalance, etc.)
- **Write hooks** - Send transactions (useWriteContract, useSendTransaction)

## Common Query Hooks

```typescript
// Contract reads
useReadContract({ abi, address, functionName, args })
useReadContracts({ contracts: [...] })

// Chain data
useBlockNumber({ chainId })
useBalance({ address, chainId })
useChainId()

// Transactions
useTransactionReceipt({ hash })
useWaitForTransactionReceipt({ hash })
```

## Common Write Hooks

```typescript
// Contract writes
useWriteContract()
useSimulateContract()

// Transactions
useSendTransaction()
useSignMessage()
useSignTypedData()
```

## Watching for Changes

```typescript
// Re-fetch on block changes
useReadContract({
  abi,
  address,
  functionName: 'balanceOf',
  args: [address],
  watch: true  // re-fetch when block changes
})
```

## Query Options

```typescript
useReadContract({
  abi,
  address,
  functionName: 'balanceOf',
  args: [address],
  query: {
    enabled: !!address,        // only fetch when address exists
    staleTime: 5 * 60 * 1000, // cache for 5 minutes
    refetchOnWindowFocus: false,
  }
})
```

## Return Values

```typescript
const { data, error, isError, isLoading, isPending, refetch } = useReadContract({
  abi, address, functionName, args
})

// data - the result (if successful)
// error - error object (if failed)
// isLoading / isPending - loading state
// isError - error state
// refetch - function to manually re-fetch
```
