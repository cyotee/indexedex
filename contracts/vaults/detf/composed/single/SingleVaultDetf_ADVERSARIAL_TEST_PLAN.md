# SingleVaultDetf — Adversarial Test Plan

## Status

**IMPLEMENTED (P0 partial)** — `test/.../composed/single/adversarial/Adversarial_SingleVaultDetf_P0.t.sol`

## Deferred

- C1–C3 hostile reentrancy: deferred P2 (Uni V4 share wiring); C gold on MultiVault + Single SE
- Full D claim matrix: covered partially via existing MintSellRedeem happy + F2 onlyOwner

## Run

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/single/adversarial/**'
```
