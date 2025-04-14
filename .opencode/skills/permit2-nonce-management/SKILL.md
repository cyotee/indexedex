---
name: permit2-nonce-management
description: Bitmap nonce patterns for Permit2 signature replay protection. Use when generating nonces for SignatureTransfer permits.
---

# Permit2 Nonce Management

Permit2 uses a **bitmap nonce system** for replay protection (not sequential).

## Understanding Bitmap Nonces

- 256 nonces per "word" (bitmap)
- Nonce = `(wordIndex << 8) | bitIndex`
- Must verify nonce bit is unused before signing

## Simple Nonce Patterns

### Pattern 1: Timestamp-based (Recommended)

```typescript
// Simple, low collision risk for user-initiated flows
const nonce = BigInt(Date.now()) << 8n
// Shift by 8 = room for 256 retries within same timestamp second
```

### Pattern 2: Sequential with Retry

```typescript
let nonce = nextNonce++
try {
  signature = await signTypedData(...)
} catch {
  nonce = nextNonce++
}
```

### Pattern 3: Query Bitmap (Most Robust)

```typescript
async function getFreeNonce(owner: string): Promise<bigint> {
  for (let wordPos = 0; wordPos < 100; wordPos++) {
    const bitmap = await publicClient.readContract({
      address: PERMIT2_ADDRESS,
      abi: [{
        inputs: [
          { name: 'owner', type: 'address' },
          { name: 'wordPos', type: 'uint256' }
        ],
        name: 'nonceBitmap',
        outputs: [{ name: 'bitmap', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function'
      }],
      functionName: 'nonceBitmap',
      args: [owner, BigInt(wordPos)]
    })

    if (bitmap !== MaxUint256) {
      for (let bitPos = 0; bitPos < 256; bitPos++) {
        if ((bitmap >> BigInt(bitPos)) & 1n === 0n) {
          return (BigInt(wordPos) << 8n) | BigInt(bitPos)
        }
      }
    }
  }
  throw new Error('No free nonce')
}
```

## Usage with Signature Transfer

```typescript
const nonce = BigInt(Date.now()) << 8n

const permit: SignatureTransfer.PermitTransferFrom = {
  permitted: { token: tokenAddress, amount: amount },
  nonce,
  deadline: BigInt(Math.floor(Date.now() / 1000) + 1800n)
}
```

## Best Practices

1. **For swap UX**: Use timestamp-based - simple, works well
2. **For high-frequency**: Query bitmap - ensures uniqueness
3. **Include in witness**: Bind nonce to action to prevent cross-function replay
4. **Handle expiration**: 30 min typical (1800 seconds)
