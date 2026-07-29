# SeigniorageDETF — Adversarial Test Plan

## Status

**IMPLEMENTED (P0)** — `test/.../seigniorage/adversarial/Adversarial_Seigniorage_P0.t.sol`  
Plus existing: peg gates, onlyOwner NFT, dust/FOT transfer.

**Threshold modes (DETF_Threshold_Modes PRD):** formal **Out** of implement scope — see [`THRESHOLD_MODES_OUT.md`](./THRESHOLD_MODES_OUT.md) (2026-07-28). Peg-regime gates remain; no Policy/Open wiring.

## Deferred P2

- C hostile-share reentrancy (underwrite is onlyOwner/lock-gated)

## Run

```bash
forge test --match-path 'test/foundry/spec/protocol/vaults/seigniorage/adversarial/**'
```
