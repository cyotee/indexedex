# D3_policyMintAllowed

## One-line story
Production synthetic drive (free-DETF primary burns when burn-allowed + Uni V2 trades) opened mint; capital mint preview==execution.

## Synthetic drive (honest)
Post-bond product mint-split issues free DETF, diluting synthetic below burnThreshold.
Drive (TestBase Phase A+B-aligned, no Open/deal):
1. Primary-market burn of free DETF while burn-allowed
2. Real Uni V2 trades (SE rate providers)

RQ5: Uni trades alone do not clear mintThreshold from post-bond synth ~0.625; free-DETF burns are required co-path.

## Key numbers
- driveSteps: 32
- supply drive: 505205472000000000000 -> 321270140643256150349
- preview/exec/diff: 332354104227370659 / 332354104227370659 / 0

## Commands
```bash
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/detf/singleSe/Script_D3_PolicyMintAllowed.s.sol:Script_D3_PolicyMintAllowed -vv
```
