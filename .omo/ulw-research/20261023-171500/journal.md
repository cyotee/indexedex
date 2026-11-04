# Journal

## Wave 0 scoping

Search tool returned repeated summaries, not page text. Those summaries are not observations. Primary reads start with the first wave.

Rate interface confirmed in-repo at lib/crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol:

```solidity
function getRate() external view returns (uint256);
```

NatSpec: an 18-decimal fixed point number that is the exchange rate of the token to some other underlying token. The meaning depends on context.

## Wave 1 launch

2026-10-23. Brief written before workers started. Goal registered. Criteria retargeted to the cited comparison, a primary postmortem exclusion, and a fee-earning view rate.

Collection workers started as background tasks. Team channel is being stood up in the same wave so debate mail has a home. Lanes:

- explore-rate-provider st_01a16a3b
- explore-wings-quote st_01a16a3c
- librarian-arrakis-v2 st_01a16a3d
- web-github-nav st_01a16a46
- web-incidents st_01a16a47
- web-balancer-rates st_01a16a48
- web-v4-hooks st_01a16a49
- web-design-papers st_01a16a4a
- web-remaining-alms st_01a16a4b

Axis owners started first as tasks, then moved to the team if team_create succeeds:

- arrakis-family st_01a16a3e
- manager-vaults st_01a16a3f
- single-sided st_01a16a40
- v4-native st_01a16a41
- rate-oracles st_01a16a42
- pricing-math st_01a16a43
- incidents st_01a16a44
- skeptic st_01a16a45
