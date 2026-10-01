# Astra — Robinhood address combined cross-review

2026-09-27. Read all three complete originals together (Grok 126 lines; MiniMax M3 129; Kimi K3 65), as untrusted evidence. No peer cross-review read. Originals unchanged. Assigned routing: `openai/gpt-6-astra`, not provider verification.

## Agreement and minimal additions

All agree on the four useful missing Pendle anchors. Recommend a separately authorized constants update with version-labelled names and **official-repository attestation; on-chain verification pending**:

| Role | Exact address |
| --- | --- |
| Market Factory V6 | `0x544BF81c855AE84c1e8b65d5E38770898D01EeE2` |
| Yield Contract Factory V6 | `0xa543BF1ac6441822E95eD408076bB53090a0a9d7` |
| Execution Router V4 | `0x888888888889758F76e7103c6CbF23ABbF58F946` |
| RouterStatic | `0x6813d43782395A1F2AAb42f39aeEDE03ac655e09` |

Immutable source read in Astra's original: [4663-core.json at `3bb1bc056296aad10544502e5c663c0874ce13e9`](https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/3bb1bc056296aad10544502e5c663c0874ce13e9/deployments/4663-core.json), accessed 2026-09-27. This improves on peers' floating `main` references; it does not pin deployed bytecode.

Only the market factory is the direct candidate-provenance anchor; yield factory and routers support validation/integration. PENDLE, SY factory, common deployment helper, governance, cross-chain utilities and facet addresses are not required merely to discover markets. My original optional rows remain optional, not minimum scope. Do not turn PYLpOracle into this family's selected custom TWAP source or use router facets as substitute execution entrypoints.

## Evidence changing Astra's original

Grok/Kimi supplied a current API candidate. I independently fetched the active list and individual market response on 2026-09-27 after another Context7 query returned no matching documentation:

- https://api-v2.pendle.finance/core/v1/4663/markets/active
- https://api-v2.pendle.finance/core/v1/4663/markets/0xab0093949fefa432bfb1a0ba8943ee4aebc898a8

The individual response reports `protocol: NetNet`, `isActive: true`, `dataUpdatedAt: 2026-09-27T18:12:00Z` and:

| API field | Value |
| --- | --- |
| Market; expiry | `0xab0093949fefa432bfb1a0ba8943ee4aebc898a8`; **2026-10-01 00:00 UTC** |
| PT | `0x0be486bd185844a282690ea0f84ca628c8b67935` |
| YT | `0xa20bf3e1abf0dd3927566dd776aaa9b388e4376b` |
| SY | `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` |
| Accounting asset, NET-scaled18 | `0xba46fc84409589f369c107e869c06809df3d9727` |
| Underlying asset, sNET-scaled18 | `0x53176cadd446700fa6b89f840357ac586d7e33db` |

API metadata lists PT/YT/SY as 18 decimals and both official NET/sNET addresses as 9-decimal input/output tokens. This strengthens the scaled18 integration lead and explains the reported underlying-address mismatch; it does **not** prove wrapper backing or executable conversion. My original “no current market established” remains true for on-chain validation; **there is now an independently checked, dated API-listed unexpired candidate**. Record it in series-specific evidence, not perpetual network constants.

## Corrections

- **Kimi:** retract “no successor exists” and “rollover has no valid target.” Absence from an API listing does not establish absence on-chain. Also, the current source market is still active, so the PRD already forbids rolling it now. API `feeRate` is not sufficient evidence of native YT interest-fee configuration. Scaled18 metadata supports investigation, not verified contract semantics. The canonical V2 pair is selected, not merely a PRD candidate. A future factory version also need not necessarily imply a different address where upgradeability exists.
- **MiniMax:** the user never claimed Pendle was absent. Claims about “two peers” are unsupported in this independent-pass record. The assertion that BoardroomDesk, NetNetGear, BasketsDesk, Credit/Predict/Sports-book extras already exist in the constants is false: Astra's full 679-line read, with `504–539` rechecked, does not contain them. Nor do all existing getter-derived pins appear in Official Channels. Core relevant NetNet pins do match; unrelated omissions do not expand this task.
- **MiniMax:** reject the claim that V6 is necessarily latest/recommended or older versions deprecated. The chain manifest labels V6; generic docs describe V7Upg. Establish actual deployed implementation/version before binding; do not auto-upgrade the PRD's trusted factory. Reject mandatory governance/helper expansion and a newly selected PYLpOracle. `getPT(sy, expiry)` requires known inputs; it is not market enumeration.
- **Grok:** its denied constants read remains a limitation, not evidence of missing NetNet pins, V2 router or fee oracle. They already appear locally (`143–144,432–447,635–638`). Its caution about the different underlying face is justified, now refined by the API's scaled18 metadata.

## Safe discovery and unresolved gates

**Enumerate candidates** through the documented paginated `/core/v2/markets/all` or version-compatible factory creation events; API coverage is not an exhaustive on-chain registry. **Validate candidates** using the configured trusted factory's `isValidMarket`, then token relationships, NetNet backing, expiry at a recorded block, conversion support and liquidity. `isValidMarket` itself enumerates nothing. SY may change on rollover; no perpetual market/SY pin.

No RPC/codehash/ABI-equivalence or wrapper relationship was checked. A large all-markets response was truncated; I used the individual response rather than claiming exhaustive coverage. §8's selected-pair checks **before implementation** remain outstanding. High confidence in source/API transcription; deployed compatibility unverified. No code, tests, shell, browser or delegation; only this report written. Return to moderator.
