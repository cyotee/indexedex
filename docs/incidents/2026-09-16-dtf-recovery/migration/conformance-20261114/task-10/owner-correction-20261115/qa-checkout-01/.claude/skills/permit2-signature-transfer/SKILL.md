---
name: permit2-signature-transfer
description: Uses permitWitnessTransferFrom for gasless token transfers with EIP-712 signatures. Use when implementing swap/deposit/withdraw with Permit2 signature-based authorization.
---

# Permit2 Signature Transfer

The recommended pattern for IndexedEx operations. Users sign **one EIP-712 message** off-chain - no pre-approval needed.

## Quick Start

```typescript
import { SignatureTransfer, PERMIT2_ADDRESS } from '@uniswap/permit2-sdk'
import { useSignTypedData, useWriteContract } from 'wagmi'
import { parseUnits, keccak256, encodePacked } from 'viem'

// Build permit (what user authorizes)
const permit: SignatureTransfer.PermitTransferFrom = {
  permitted: { token: tokenInAddress, amount: parseUnits('100', 6) },
  nonce: BigInt(Date.now()) << 8n,
  deadline: BigInt(Math.floor(Date.now() / 1000) + 1800n)
}

// Build witness (binds signature to this specific action)
const witness = {
  actionId: keccak256(encodePacked(
    ['address', 'address', 'address', 'uint256'],
    [tokenIn, tokenOut, vaultAddress, amountIn]
  )),
}

// Get EIP-712 data
const { domain, types, values } = SignatureTransfer.getPermitData(
  permit,
  PERMIT2_ADDRESS,
  chainId,
  { witness, witnessTypeName: 'Witness', witnessType: WITNESS_TYPE }
)

// User signs
const signature = await signTypedDataAsync(domain, types, values)
```

## Witness Types

### For exchangeIn (Exact In Swap)

```typescript
const WITNESS_TYPE: Record<string, TypedDataField[]> = {
  Witness: [{ name: 'actionId', type: 'bytes32' }]
}
```

### For exchangeOut (Exact Out Swap)

```typescript
// actionId includes maxAmountIn since that's variable
const witness = {
  actionId: keccak256(encodePacked(
    ['address', 'address', 'address', 'uint256', 'uint256'],
    [tokenIn, tokenOut, vaultAddress, amountOut, maxAmountIn]
  ))
}
```

## Contract Integration

See `permit2-signature-transfer-contract` skill for Solidity implementation.
