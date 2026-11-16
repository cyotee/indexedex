---
name: permit2-allowance-flow
description: Complete approval flow with reset-to-zero pattern. Use when implementing full ERC20 and Permit2 approval workflow.
---

# Permit2 Allowance Transfer - Complete Flow

Full implementation with reset-to-zero pattern for tokens that require it.

## Constants

```typescript
const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3'

const PERMIT2_APPROVE_ABI = [
  {
    inputs: [
      { name: 'token', type: 'address' },
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint160' },
      { name: 'expiration', type: 'uint48' }
    ],
    name: 'approve',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  }
] as const
```

## Complete Approval Function

```typescript
async function ensureSpendingLimits(
  tokenAddress: string,
  spenderAddress: string,
  amountNeeded: bigint,
  writeContractAsync: (config: WriteContractParameters) => Promise<Hash>,
  publicClient: PublicClient,
  address: string
) {
  // Step 1: Ensure ERC20 → Permit2 allowance
  const currentErc20Allowance = await publicClient.readContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [address, PERMIT2_ADDRESS]
  })

  if (currentErc20Allowance < amountNeeded) {
    // Some tokens (like USDT) require resetting to 0 first
    try {
      const hash = await writeContractAsync({
        address: tokenAddress,
        abi: erc20Abi,
        functionName: 'approve',
        args: [PERMIT2_ADDRESS, amountNeeded]
      })
      await publicClient.waitForTransactionReceipt({ hash })
    } catch {
      // Reset to 0, then approve
      const hash0 = await writeContractAsync({
        address: tokenAddress,
        abi: erc20Abi,
        functionName: 'approve',
        args: [PERMIT2_ADDRESS, 0n]
      })
      await publicClient.waitForTransactionReceipt({ hash: hash0 })

      const hash1 = await writeContractAsync({
        address: tokenAddress,
        abi: erc20Abi,
        functionName: 'approve',
        args: [PERMIT2_ADDRESS, amountNeeded]
      })
      await publicClient.waitForTransactionReceipt({ hash: hash1 })
    }
  }

  // Step 2: Ensure Permit2 → Spender allowance
  const currentPermit2Allowance = await publicClient.readContract({
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
    args: [address, tokenAddress, spenderAddress]
  })

  if (currentPermit2Allowance[0] < amountNeeded) {
    const threeDaysSecs = 3n * 24n * 60n * 60n
    const expiration = BigInt(Math.floor(Date.now() / 1000)) + threeDaysSecs

    const hash = await writeContractAsync({
      address: PERMIT2_ADDRESS,
      abi: PERMIT2_APPROVE_ABI,
      functionName: 'approve',
      args: [tokenAddress, spenderAddress, amountNeeded, expiration]
    })
    await publicClient.waitForTransactionReceipt({ hash })
  }
}
```
