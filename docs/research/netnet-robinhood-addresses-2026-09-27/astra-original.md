# Astra — Robinhood NetNet/Pendle address research ORIGINAL

Date/access date: **2026-09-27**. Research-only handoff; no Solidity edits. Prior session retained; no new-round peer artifacts read. Assigned routing label `openai/gpt-6-astra`, not provider-attested.

## Finding

**The missing discovery infrastructure is Pendle, not the core NetNet bindings.** Read all 679 lines of `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`, including the truncated tail via offset. It contains no Pendle constants. NET/USDG, sNET, staking, depository and related core addresses already exist. The tail also already aliases the IndexedEx manager as `VAULT_FEE_ORACLE` (`635–638`); do not confuse it with NetNet's PairOracle.

**Exact chain-4663 Pendle anchors were found in the official deployment manifest. No current unexpired NetNet market was established in this pass.** These are repository/documentation attestations, not live bytecode or executable-capability verification.

## Recommended Pendle additions — proposal, not code

All rows below are explicitly present in the official `4663-core.json` [P1], read at both `main` and pinned commit **`3bb1bc056296aad10544502e5c663c0874ce13e9`**. GitHub's path-specific commit response dates that change 2026-09-04 [P2].

| Manifest key / suggested role | Exact address | Recommendation |
| --- | --- | --- |
| `marketFactoryV6` / version-labelled market discovery anchor | `0x544BF81c855AE84c1e8b65d5E38770898D01EeE2` | Add first; preserve V6 label |
| `yieldContractFactoryV6` / PT-YT factory | `0xa543BF1ac6441822E95eD408076bB53090a0a9d7` | Add supporting identity anchor |
| `router` / Pendle execution router | `0x888888888889758F76e7103c6CbF23ABbF58F946` | Add; official router docs identify RouterV4 and upgradeability |
| `routerStatic` / static helper | `0x6813d43782395A1F2AAb42f39aeEDE03ac655e09` | Add if selected quotation path uses it |
| `PENDLE` / reward-token identity | `0x5E49E1f85813F2B65858860A3FA231b4186f2e0E` | Useful optional pin; not an exhaustive reward list |
| `syFactory` | `0x466CeD3b33045Ea986B2f306C8D0aA8067961CF8` | Optional infrastructure, not the market's SY token |
| `commonDeploy` | `0x2Ed473F528E5B320f850d17ADfe0e558f0298aA9` | Optional deployment helper; not needed merely to discover markets |

**Version caveat:** the generic Market Factory page describes `PendleMarketFactoryV7Upg`, while the chain-specific manifest names **V6**. Do not relabel the manifest address V7, import another chain's factory, or assume this is the only factory ever deployed on 4663. Two guessed V6 source URLs returned 404 (root `Market/` and `Market/v6/`); neither was retried. Runtime version/implementation and compatible ABI remain evidence gaps.

The generic deployments page omits Robinhood from its displayed chain table but directs readers to `/deployments/{chainId}-core.json`; the actual 4663 file exists. Table omission is not evidence of absence.

## Existing relevant NetNet pins match official channels

Comparison against NetNet's chain-4663 Official Channels [N1], not RPC:

| Existing constant / local line | Exact address |
| --- | --- |
| `NET`, `70` | `0xCA9c78Dd337A67F6e0077F65F5E9218719d30eDf` |
| `SNET`, `432` | `0xb773ec2C326B7f98a5a83fc098825492F020a4c7` |
| `USDG`, `60` | `0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168` |
| `NETNET_STAKING`, `437` | `0xB078cc304A0B264C5F3680DC0488954ACcd02E87` |
| `NETNET_BOND_DEPOSITORY`, `440` | `0xff32a969A0c567129eECD926D04657728E1980C1` |
| `NETNET_NET_USDG_PAIR`, `447` | `0x59F95461E68e0c77605299791E1449f175165B54` |
| `WSNET`, `469` | `0x63C12667638f2Ae6fC6ae09B43D98Ec84a8586eA` |

The existing core Treasury/Distributor/PairOracle/TaxCollector pins also match that page. NetNet docs identify wsNET as wrapped non-rebasing sNET [N2]; this does **not** establish which SY backs a current Pendle market or authorize replacing selected NET/sNET routes. `RH_NET` at local line 309 is Cloudflare, not NetNet. New unrelated NetNet credit/arcade addresses appear in Official Channels; omit them from this narrowly scoped Pendle-discovery handoff.

## Discovery handoff, not perpetual market pin

1. Obtain market **candidates** from Pendle's documented paginated `GET https://api-v2.pendle.finance/core/v2/markets/all`; filter chain 4663 and inspect expiry/underlying identity. API docs specify `skip`/`limit` and deprecate `/v1/markets/all` [P3]. No candidate API response was fetched here.
2. Alternatively index the version-appropriate factory's `CreateNewMarket` events. Official `IPMarketFactory` exposes the event and `isValidMarket`; do not invent a `getAllMarkets` getter [P4]. Event-start block is not established here.
3. Before acceptance, independently validate the configured trusted factory first, then `readTokens()`, expiry greater than the observation block timestamp, PT/YT/SY relationships, actual NetNet backing, directional conversion and usable liquidity. `isValidMarket` proves factory membership, **not** active status or NetNet compatibility [P5/P6].
4. Preserve PRD `246,705–721`: initial market is PkgArgs; factory is PkgInit; SY is discovered and may change on rollover. Inventorying multiple factory versions does not authorize broadening the selected trusted factory. Multiple valid candidates require explicit selection, not “first API result.” Record selected series separately with block/hash/expiry; never add a timeless `NETNET_PENDLE_MARKET` constant.

## Sources, limits and next gate

- **P1:** https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/3bb1bc056296aad10544502e5c663c0874ce13e9/deployments/4663-core.json
- **P2:** https://api.github.com/repos/pendle-finance/pendle-core-v2-public/commits?path=deployments/4663-core.json&per_page=1
- **P3:** https://docs.pendle.finance/pendle-v2-dev/Backend/ApiOverview
- **P4:** https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/interfaces/IPMarketFactory.sol
- **P5:** https://docs.pendle.finance/pendle-v2-dev/Contracts/PendleMarket/MarketFactory
- **P6:** https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/interfaces/IPMarket.sol
- **P7:** https://docs.pendle.finance/pendle-v2-dev/Deployments and https://docs.pendle.finance/pendle-v2-dev/Contracts/PendleRouter/PendleRouterOverview
- **N1:** https://docs.netnet.capital/official-channels
- **N2:** https://docs.netnet.capital/mechanism

All accessed 2026-09-27. Context7 resolved Pendle first; two focused queries returned no matching documentation, then official web sources were used. Current CLAUDE, catalog, canonical Crane architecture/deployment and local launch guidance read. No shell/RPC/tests/browser/delegation or private payloads sent externally. No ordinary local read misses. High confidence in published address matches; no runtime hashes, active market, current fees, exemptions or deployed equivalence verified. PRD §8's canonical-pair verification **before implementation** remains unmet by documentation alone. New custom-family components still need no deployed addresses for design. Proposed constants additions require separately authorized Solidity work; only this report was saved.
