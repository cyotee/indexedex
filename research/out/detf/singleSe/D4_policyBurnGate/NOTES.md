# D4_policyBurnGate

## One-line story
Policy burn gate: free DETF from product bond mint-split (or capital mint after production drive); burn when synth < burnThreshold; preview~=execution within documented dust bound.

## Setup
- DETF: Single SE Policy
- Free DETF: product bond mint-split free DETF when present; else capital mint after production drive (free-DETF burns when burn-allowed + Uni trades)
- Synthetic: post-bond often already burn-allowed (~0.625); if re-entry needed after mint, capital dilution + Uni trades
- No deal seed

## Key numbers
- previewOut: 39587853078519101088987041180
- execOut: 39587853078519101075769820640
- |preview-exec|: 13217220540
- Bound: abs <= 1e15 OR relative <= 1e-6

## Commands
```bash
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/detf/singleSe/Script_D4_PolicyBurnGate.s.sol:Script_D4_PolicyBurnGate -vv
```
