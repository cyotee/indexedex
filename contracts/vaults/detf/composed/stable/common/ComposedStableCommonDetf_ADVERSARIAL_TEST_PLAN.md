# ComposedStableCommonDetf — Adversarial Test Plan

## Status

**IMPLEMENTED (P0)** — suite under `test/foundry/spec/vaults/detf/composed/stable/common/adversarial/`.

## Applicable catalog

| Pri | IDs | Notes |
|-----|-----|-------|
| P0 | A1, A3, D2, D3, E5, F2, H2, H3 | Production integrated graph |
| P1 | A2, E4, F1 | |
| Deferred P2 | C1–C3 hostile multi-leg (complex; claim atomicity covered H2); B route grief |

## Run

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/common/adversarial/**'
```
