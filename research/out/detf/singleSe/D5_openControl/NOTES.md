# D5_openControl

## One-line story
Open-mode Single SE DETF: live mint/burn independent of synthetic; warp shows no natural expansion.

## Key numbers
- supply pre/post warp: 505205472000000000000 / 505205472000000000000
- pending pre/post warp: 63087533315999999902 / 63087533315999999902

## Non-claims
- Open does not advertise a peg; no APY claim.

## Commands
```bash
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/detf/singleSe/Script_D5_OpenControl.s.sol:Script_D5_OpenControl -vv
```
