# D6_capitalSeigniorage

## One-line story
Sequence of primary mints (capital seigniorage) increases DETF totalSupply; not natural expansion (D8).

## Key numbers
- supply start: 302476652376377739019
- supply end: 304036211397410542818

## Labeling
- Capital seigniorage only - external SE shares for DETF.
- Natural expansion is D8 (time + mint-rich Policy).

## Commands
```bash
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/detf/singleSe/Script_D6_CapitalSeigniorageDilution.s.sol:Script_D6_CapitalSeigniorageDilution -vv
```
