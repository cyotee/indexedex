# DETF diagrams for X

Dark lab boards. Labels follow product voice. Do not generate these in an image model.

## Layout (locked)

- Width **1920px**. Height **hugs content**.
- Bottom padding **36px**. No empty 1080 canvas under the last row.
- Screenshot `#board` at 2x PNG.
- Discuss the claim and boxes first. Draw after sign-off. Drill-downs use the same $DTF / ETH Single SE example as the architecture board.

## Current series

| File | Use |
|------|-----|
| `out/architecture-single-se.png` | Full stack: SE vault, buffer hook reserve, Bond NFT, DETF token, rebasing claim. |
| `out/se-vault-zap.png` | SE vault drill-down: double-sided LP, zap in, zap out, cost vs a full pool trade. |
| `out/reserve-pool.png` | Reserve pool: listed $DTF / $DTF-DETF, vault tokens plus rate provider, CP sell vs linear acquire, fee loop. |
| `out/mint-burn-expansion.png` | Mint and burn on the reserve curve with an incentive vs the market. A cut of minted DETF goes to bonds. |
| `out/bonding.png` | Bond NFT, creator’s permanent bond, mint-to-join LP, time-weighted claimable rewards, close keeps DETF for the protocol. |
| `out/rebasing-claim.png` | Claim token owns Bond NFT ID 0. Give $DTF-DETF to buy into protocol LP. Earns minted DETF, less than timed bonds. |

## Export

From the repo root, with DTF Playwright installed:

```bash
node docs/marketing/x-diagrams/export-architecture.mjs
```

Edit the HTML, re-run the export.
