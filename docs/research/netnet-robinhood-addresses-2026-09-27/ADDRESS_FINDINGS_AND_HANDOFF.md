# Robinhood NetNet/Pendle discovery addresses — findings and implementation handoff

Date: 2026-09-27. Research completed, then the authorized constants edit was applied on the same date.

## Result

The full 679-line `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol` contains the core NetNet bindings needed for this strategy, but no Pendle constants. Official Pendle chain-4663 deployment records provide the missing factory/router anchors. A current API-listed unexpired NetNet market is documented below as a dated candidate, not a perpetual constant or verified executable market.

This advances NN-01's address inventory, not its deployment-verification gates. Source publication, API metadata and deployed bytecode verification remain different evidence classes.

## 1. Existing relevant constants

Moderator directly compared these NetNet entries with https://docs.netnet.capital/official-channels, fetched 2026-09-27:

| Existing constant | Local line | Address |
| --- | --- | --- |
| USDG | 60 | `0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168` |
| NET | 70 | `0xCA9c78Dd337A67F6e0077F65F5E9218719d30eDf` |
| SNET / NETNET_SNET | 432–433 | `0xb773ec2C326B7f98a5a83fc098825492F020a4c7` |
| NETNET_STAKING | 437 | `0xB078cc304A0B264C5F3680DC0488954ACcd02E87` |
| NETNET_BOND_DEPOSITORY | 440 | `0xff32a969A0c567129eECD926D04657728E1980C1` |
| NETNET_NET_USDG_PAIR | 447 | `0x59F95461E68e0c77605299791E1449f175165B54` |
| WSNET / NETNET_WSNET | 469–470 | `0x63C12667638f2Ae6fC6ae09B43D98Ec84a8586eA` |

No duplicate additions are needed for these roles. wsNET is a separate face, not a replacement for the selected sNET binding. `RH_NET` at line 309 is Cloudflare stock, not NetNet.

Also already present, observed locally but not newly externally verified here:

- Uniswap V2 factory/router: lines 143–144.
- IndexedEx manager `0x09682b00D873D913ada0bB69B4D4c9631810d0bc`: line 636.
- `VAULT_FEE_ORACLE = INDEXEDEX_MANAGER`: line 638; distinct from NetNet PairOracle.

Newer unrelated NetNet desks appear in current official documentation but are outside this discovery task. They are not all already in the library. New custom SE/hook/DETF components remain future implementation dependencies, not missing externally published addresses to invent.

## 2. Recommended focused Pendle additions

**Primary immutable source:** https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/3bb1bc056296aad10544502e5c663c0874ce13e9/deployments/4663-core.json

Moderator fetched that exact revision on 2026-09-27 and observed `network.chainId = 4663`. Context7 was consulted first, resolving `/websites/pendle_finance`; the deployment query returned no matching documentation. Researchers additionally used official documentation/search and independently fetched the deployment record.

| Proposed constant name | Published JSON key | Exact published address | Purpose |
| --- | --- | --- | --- |
| PENDLE_MARKET_FACTORY_V6 | marketFactoryV6 | `0x544BF81c855AE84c1e8b65d5E38770898D01EeE2` | Principal discovery/provenance anchor |
| PENDLE_YIELD_CONTRACT_FACTORY_V6 | yieldContractFactoryV6 | `0xa543BF1ac6441822E95eD408076bB53090a0a9d7` | PT/YT integration identity |
| PENDLE_ROUTER | router | `0x888888888889758F76e7103c6CbF23ABbF58F946` | Execution router; preserve quotation fee identity |
| PENDLE_ROUTER_STATIC | routerStatic | `0x6813d43782395A1F2AAb42f39aeEDE03ac655e09` | Selected quotation-helper integration |

The first is the core factory anchor for market discovery; the remaining entries support the strategy integration rather than enumeration itself. These are recommended names, not implemented declarations.

Optional relevant inventory, **not necessary merely to find markets**:

| Role | Address |
| --- | --- |
| PENDLE reward token | `0x5E49E1f85813F2B65858860A3FA231b4186f2e0E` |
| SY factory | `0x466CeD3b33045Ea986B2f306C8D0aA8067961CF8` |

PENDLE is not SY and does not exhaust possible reward tokens. The SY factory is not the current market's SY. Do not add governance, cross-chain hubs, administrative helpers or a different oracle just because they occur in the manifest. In particular, no new Pendle oracle is selected to replace the custom family's two TWAPs.

**Version caution:** the chain-specific source calls these factories V6. Generic Pendle Market Factory documentation discusses V7Upg. Preserve V6 naming; do not infer that it is V7, the only factory on the chain, or universally the latest version. Runtime implementation, upgrade configuration and ABI compatibility remain unverified.

Documentation landing pages referenced by researchers, accessed 2026-09-27:

- https://docs.pendle.finance/pendle-v2-dev/Deployments
- https://docs.pendle.finance/pendle-v2-dev/Contracts/PendleMarket/MarketFactory
- https://docs.pendle.finance/pendle-v2-dev/Backend/ApiOverview

The deployments page's chain table omission of Robinhood does not negate the official `4663-core.json` record.

## 3. Dated API-listed NetNet market — do not make this a permanent constant

Moderator fetched https://api-v2.pendle.finance/core/v1/4663/markets/0xab0093949fefa432bfb1a0ba8943ee4aebc898a8 on 2026-09-27. Response `dataUpdatedAt` was **2026-09-27T18:22:00.000Z**; this is an API update time, not an observation block or code verification.

The response says `protocol: NetNet`, `isActive: true`, chain 4663:

| Field | API value |
| --- | --- |
| Market / LP | `0xab0093949fefa432bfb1a0ba8943ee4aebc898a8` |
| Expiry | **2026-10-01T00:00:00.000Z** |
| PT | `0x0be486bd185844a282690ea0f84ca628c8b67935` |
| YT | `0xa20bf3e1abf0dd3927566dd776aaa9b388e4376b` |
| SY | `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` |
| NET-scaled18 accounting asset | `0xba46fc84409589f369c107e869c06809df3d9727` |
| sNET-scaled18 underlying asset | `0x53176cadd446700fa6b89f840357ac586d7e33db` |

API metadata reports PT/YT/SY as 18 decimals and lists the official raw NET/sNET addresses as 9-decimal input/output tokens. This is evidence to investigate the scaled18/rebasing conversion in NN-10, not proof of the deployed wrappers' backing or finite-size executability. Do not replace raw sNET with the scaled18 address merely because the names are similar.

Researchers also observed the expired 2026-09-17 market `0x23c68474e3cd533a2f952a0fb998f1867e57d27f`. Neither historical nor currently listed market belongs in a timeless `NETNET_PENDLE_MARKET` constant. SY may change across future rollovers even if two observed series share it.

No claim is made that this is the sole unexpired compatible market. Absence of later series in an API result does not prove on-chain absence or establish a rollover impossibility. API `feeRate` is not, without source mapping, proof of native YT interest-fee configuration.

## 4. Durable discovery procedure for a separately authorized implementation

1. **Enumerate candidates**, using the documented paginated `GET https://api-v2.pendle.finance/core/v2/markets/all` or the appropriate factory's `CreateNewMarket` events. Apply chain 4663 and inspect all relevant pages. Establish the factory event start block separately. The dated single-market v1 response above is evidence, not the proposed permanent enumeration endpoint.
2. **Validate provenance first** against the configured trusted factory using its verified `isValidMarket` interface. That method validates a supplied candidate; it does not enumerate candidates.
3. Discover `readTokens()` relationships and expiry; verify expiry against the observation block timestamp, PT/YT/SY relationships, actual NetNet backing, conversion support, units and required liquidity.
4. If multiple candidates pass, select explicitly under the deployment/rollover specification, not by API order. Do not silently broaden the configured trusted factory to accommodate a candidate.
5. Record the selected market as instance/series configuration with expiry and observation evidence. Repeat appropriate discovery/validation for future series.

Interface references used by researchers: https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/interfaces/IPMarketFactory.sol and https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/interfaces/IPMarket.sol (accessed 2026-09-27; floating references, not a deployed ABI proof). Do not invent `getAllMarkets`, and do not mistake a lookup requiring known SY/expiry for enumeration.

## 5. Council disposition and limits

Four independent originals followed by four original-session combined cross-reviews completed. All agreed on the core published factory/router addresses and against a perpetual market pin. Agreement is not code or security certification.

- Astra provided an immutable source pin and, during cross-review, independently verified the API candidate; moderator independently fetched both.
- Grok's ordinary constants-file read failed with reported RC_UNAVAILABLE; its session and continuation completed. It did not independently verify existing file inventory. Other participants' reads and moderator inspection supplement that gap.
- MiniMax recommended a broader administrative/helper inventory and made incorrect claims that unrelated newer NetNet pins were already in the file. Those recommendations/claims are rejected. The user never claimed Pendle was absent from Robinhood.
- Kimi found the dated candidate and scaled18 metadata, then corrected its initial overstatement that absence of an API successor proved no valid on-chain successor. MiniMax's retained version of that overstatement is also rejected.
- Minor residual disagreement is scope of optional helpers; moderator chooses the four focused entries above, with token/SY-factory entries optional, not a full deployment dump.

Preserved artifacts/sessions:

| Researcher | Original | Cross-review | Session |
| --- | --- | --- | --- |
| Astra | [Original](astra-original.md) | [Cross-review](astra-cross-review.md) | `ses_f1c499b6bffe6RiNjZZUSMsP8S` |
| Grok | [Original](grok-original.md) | [Cross-review](grok-cross-review.md) | `ses_f1c4384d7ffeZX74uV9yhIXbVq` |
| MiniMax M3 | [Original](minimax-original.md) | [Cross-review](minimax-cross-review.md) | `ses_f1c3f57edffedYs43k2PBvA5xU` |
| Kimi K3 | [Original](kimi-original.md) | [Cross-review](kimi-cross-review.md) | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` |

Originals remain unchanged; peers received the other three complete originals, never earlier cross-reviews. Prior session context is retained. Routing metadata: openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3, kimi-code-plan-global/k3; not provider attestation. Findings are evidence, not permission changes.

Confidence is high in transcription of the official published addresses and current local inventory. No deployed bytecode/hash/implementation verification, factory recognition of the candidate, RPC execution, tests or live tax/vesting checks were performed. The local constants file has pragma `^0.8.24`; repository compiler baseline previously read is configured 0.8.35, not a runtime check. PRD §8's pre-implementation pair verification remains outstanding.

## 6. Implementation status

**Completed 2026-09-27:** the four focused Pendle constants were added to `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol` after the Universal Router section. Published V6 labels, checksums and the `3bb1bc056296aad10544502e5c663c0874ce13e9` source annotation were preserved. Existing NetNet constants were not duplicated, and no market, PT, YT or SY address was pinned.

`solc` 0.8.35 compiled that constants file successfully. This is a parse/typecheck of the library, not deployed-bytecode verification, a monorepo `forge build`, or a live factory-recognition test. PRD §8's before-implementation pair checks and NN-01's remaining evidence gates stay open. NN-02 was not started.
