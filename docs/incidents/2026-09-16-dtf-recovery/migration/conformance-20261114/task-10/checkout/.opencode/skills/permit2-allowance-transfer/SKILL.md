---
name: permit2-allowance-transfer
description: Uses AllowanceTransfer for persistent token approvals. Use when user grants recurring spend authority to the protocol.
---

# Permit2 Allowance Transfer

Two-step approval pattern: (1) ERC20→Permit2, (2) Permit2→spender. Used when you want persistent allowance without per-tx signatures.

## Current Implementation Pattern

This is what the frontend currently uses for swaps:

```typescript
import { useWriteContract, useReadContract, useAccount } from 'wagmi'
import { erc20Abi } from 'viem'

// Step 1: ERC20 → Permit2 (one-time or recurring)
const tokenApproveWrite = useWriteContract()
await tokenApproveWrite.writeContractAsync({
  address: tokenAddress,
  abi: erc20Abi,
  functionName: 'approve',
  args: [PERMIT2_ADDRESS, BigInt(amount)]
})

// Step 2: Permit2 → Router (persistent)
const permit2Write = useWriteContract()
await permit2Write.writeContractAsync({
  address: PERMIT2_ADDRESS,
  abi: permit2ApproveAbi,
  functionName: 'approve',
  args: [
    tokenAddress,
    routerAddress,
    BigInt(amount),
    BigInt(expiration)
  ]
})
```

## Reading Allowances

```typescript
// ERC20 allowance (token → Permit2)
const tokenAllowance = await publicClient.readContract({
  address: tokenAddress,
  abi: erc20Abi,
  functionName: 'allowance',
  args: [owner, PERMIT2_ADDRESS]
})

// Permit2 allowance (Permit2 → router)
const permit2Allowance = await publicClient.readContract({
  address: PERMIT2_ADDRESS,
  abi: [{
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'token', type: 'address' },
      { name: 'spender', type: 'address' }
    ],
    name: 'allowance',
    outputs: [
      { name: 'amount', type: 'uint160' },
      { name: 'expiration', type: 'uint48' },
      { name: 'nonce', type: 'uint48' }
    ],
    stateMutability: 'view',
    type: 'function'
  }],
  functionName: 'allowance',
  args: [owner, tokenAddress, routerAddress]
})
```

## When to Use This vs Signature Transfer

| Scenario | Use |
|----------|-----|
| User doing frequent trades | AllowanceTransfer |
| One-time signature-based swap | SignatureTransfer |
| Gas optimization for repeated ops | AllowanceTransfer |
| Max security / no pre-approval | SignatureTransfer |

## Full Approval Flow

See `permit2-allowance-flow` skill for complete implementation with reset-to-zero pattern.
