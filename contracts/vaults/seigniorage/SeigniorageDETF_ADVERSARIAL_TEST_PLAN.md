# SeigniorageDETF — Adversarial Test Plan

## Status

**IMPLEMENTED (P0)** — `test/.../seigniorage/adversarial/Adversarial_Seigniorage_P0.t.sol`  
Plus existing: peg gates, onlyOwner NFT, dust/FOT transfer.

## Deferred P2

- C hostile-share reentrancy (underwrite is onlyOwner/lock-gated)

## Run

```bash
forge test --match-path 'test/foundry/spec/protocol/vaults/seigniorage/adversarial/**'
```
