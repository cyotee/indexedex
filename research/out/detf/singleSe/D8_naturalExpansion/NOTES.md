# D8_naturalExpansion

## One-line story
Policy + live + mint-rich + warp + touch -> natural expansion mints free DETF; Open twin does not expand.

## Key numbers
- expansionClosureRatePerSecond: 3170979198
- warpSeconds: 43200
- supply pre/post: 323531031889496482499 / 323533269971346029699
- pending pre/post: 0 / 173103736288405

## Non-claims
- No APY / mainnet yield claim.

## Commands
```bash
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/detf/singleSe/Script_D8_NaturalExpansion.s.sol:Script_D8_NaturalExpansion -vv
```
