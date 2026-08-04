# D9_protocolCompound

## One-line story
Open DETF + seigniorage mints build protocol NFT reward inventory; compound (lazy and/or public) raises protocol BPT principal. No deal seed.

## Accounting
- Metric: `bondNftVault.originalSharesOf(detfNFTId)`
- Reward source: production seigniorage inventory on mint (20% incentive)
- Single-sided DETF join skew accepted in v1 product law

## Key numbers
- protocolBpt after sell: 191437075850521434877
- protocolBpt before seigniorage mint: 192256350554047864167
- protocolBpt after compound path: 192296872191317323113
- public compound detfIn / bptOut: 1 / 40521637269458946

## Non-claims
- No claim APY / mainnet yield claim

## Commands
```bash
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/detf/singleSe/Script_D9_ProtocolCompound.s.sol:Script_D9_ProtocolCompound -vv
```
