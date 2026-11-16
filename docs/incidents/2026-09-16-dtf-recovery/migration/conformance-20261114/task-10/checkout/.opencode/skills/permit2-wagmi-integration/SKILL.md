---
name: permit2-wagmi-integration
description: Integration patterns for Permit2 with wagmi hooks. Use when building UI components that interact with Permit2.
---

# Permit2 Wagmi Integration

Complete patterns for integrating Permit2 with wagmi/viem.

## Setup

```typescript
import { useWriteContract, useReadContract, useAccount, useChainId } from 'wagmi'
import { usePublicClient, useWalletClient } from 'wagmi'
import { erc20Abi } from 'viem'
import { SignatureTransfer, PERMIT2_ADDRESS } from '@uniswap/permit2-sdk'
```

## Reading Allowances

```typescript
function useTokenAllowance(token: string, owner: string) {
  const { data } = useReadContract({
    address: token,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [owner, PERMIT2_ADDRESS],
    query: { staleTime: 0 }
  })
  return data ?? 0n
}

function usePermit2Allowance(token: string, owner: string, spender: string) {
  const { data } = useReadContract({
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
    args: [owner, token, spender],
    query: { staleTime: 0 }
  })
  return data
}
```

## Signing with useSignTypedData

```typescript
import { useSignTypedData } from 'wagmi'
import { keccak256, encodePacked } from 'viem'

const WITNESS_TYPE: Record<string, TypedDataField[]> = {
  Witness: [{ name: 'actionId', type: 'bytes32' }]
}

function usePermitSignature() {
  const { signTypedDataAsync } = useSignTypedData()
  const chainId = useChainId()

  const signPermit = async (
    token: string,
    amount: bigint,
    spender: string,
    nonce: bigint,
    witness?: { actionId: `0x${string}` }
  ) => {
    const permit: SignatureTransfer.PermitTransferFrom = {
      permitted: { token, amount },
      nonce,
      deadline: BigInt(Math.floor(Date.now() / 1000)) + 1800n
    }

    const witnessData = witness
      ? { witness: witness.actionId, witnessTypeName: 'Witness', witnessType: WITNESS_TYPE }
      : undefined

    const { domain, types, values } = SignatureTransfer.getPermitData(
      permit,
      PERMIT2_ADDRESS,
      chainId,
      witnessData
    )

    return signTypedDataAsync(domain, types, values)
  }

  return { signPermit }
}
```
