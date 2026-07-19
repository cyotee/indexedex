# SingleStandardExchangeDETF — Adversarial Test Plan

## Status

**IMPLEMENTED (P0/P1)** — suite under `test/foundry/spec/vaults/detf/standardExchange/single/adversarial/`.

## Applicable catalog

| Pri | IDs | Notes |
|-----|-----|-------|
| P0 | A1, A3*, C1–C3, D2*, D3*, E1, E5, F2, H3, B1, B3 | *No rebasing claim — D2/D3 map to sellPositionToProtocol / free BPT authority |
| P1 | A2, D5, E4, F1, F4 | |
| Deferred | D6 claim over-redeem N/A (no claim token v1); H2 claim atomicity N/A → sellPosition fail instead; G1 optional |

## Run

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/standardExchange/single/adversarial/**'
forge test --match-path 'test/foundry/spec/vaults/detf/standardExchange/single/**'
```
