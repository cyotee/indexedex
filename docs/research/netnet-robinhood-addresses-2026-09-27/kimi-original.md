# Kimi K3 — ORIGINAL: Robinhood 4663 NetNet/Pendle address evidence for NN-01 manifest

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only, not provider attestation |
| Date | 2026-09-27 |
| Scope | RESEARCH ONLY. No Solidity edit, no RPC/shell/tests, no code execution. Evidence and handoff recommendations for the NN-01 manifest. |
| Method | Read `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol` (all 679 lines incl. tail); Context7 attempted (no deployments doc match); official primary sources fetched: Pendle Deployments docs, `pendle-core-v2-public` `deployments/4663-core.json` (main branch), Pendle hosted API `api-v2.pendle.finance/core/v1/4663/markets` (all 10 markets, ~18:07–18:11 UTC). |

## 1. What ROBINHOOD_MAIN.sol already pins (NetNet + infrastructure)

Present and consistent with the PRD: `NET` 0xCA9c78Dd337A67F6e0077F65F5E9218719d30eDf (:70); `SNET` 0xb773ec2C326B7f98a5a83fc098825492F020a4c7 (:432); `USDG` 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168 (:60); canonical pair `NETNET_NET_USDG_PAIR` 0x59F95461E68e0c77605299791E1449f175165B54 (:447) — **exactly the PRD §8 candidate**; `NETNET_STAKING` 0xB078cc304A0B264C5F3680DC0488954ACcd02E87 (:437); `NETNET_BOND_DEPOSITORY` 0xff32a969A0c567129eECD926D04657728E1980C1 (:440); distributor/treasury/oracle/tax-collector/guardian-safe (:438–449). Also present: Uniswap V2 factory 0x8bcEaA40B9AcdfAedF85AdF4FF01F5Ad6517937f (:143) — the §8 factory-identity check target; V4 PoolManager (:165); IndexedEx `INDEXEDEX_MANAGER` = vault registry **and** Vault Fee Oracle 0x09682b00D873D913ada0bB69B4D4c9631810d0bc (:636–638) — the R55/R36 oracle binding; `FEE_COLLECTOR` 0x20af9A1e21a59a411cd3b0C40E70AF9084770b2E (:623); `HOOK_FACTORY` 0x8BB5FCC67e8CCa44DC41dd08A5e2b2B392C22945 (:583); CREATE3 root (:573). Header records NetNet pins verified **2026-08-28** from Official Channels (:9) — matching PRD §16's vendor snapshot date.

**Gap: zero Pendle addresses.** No market factory, router, RouterStatic, SY, oracle or market is pinned anywhere in the file.

## 2. Pendle core anchors (documentation attestation, fetched 2026-09-27)

Pendle's Deployments docs page lists 12 chains and **omits 4663** (table lags), but `deployments/4663-core.json` exists on `main` of `pendle-core-v2-public` (unpinned branch — recommend commit-hash pin):

| Role (PRD binding) | Address (docs attestation) |
| --- | --- |
| Trusted Pendle Market Factory (PkgInit candidate) — `marketFactoryV6` | 0x544BF81c855AE84c1e8b65d5E38770898D01EeE2 |
| YieldContractFactory (PT/YT; interest fee, treasury) — `yieldContractFactoryV6` | 0xa543BF1ac6441822E95eD408076bB53090a0a9d7 |
| Execution router (readState fee identity, Keep-YT entry) — `router` | 0x888888888889758F76e7103c6CbF23ABbF58F946 |
| RouterStatic (quote helper; identity NOT equivalent per §7.1.2) — `routerStatic` | 0x6813d43782395A1F2AAb42f39aeEDE03ac655e09 |
| PYLpOracle — `pyYtLpOracle` | 0x5542be50420E88dd7D5B4a3D488FA6ED82F6DAc2 |
| SY factory — `syFactory` | 0x466CeD3b33045Ea986B2f306C8D0aA8067961CF8 |
| PENDLE reward token | 0x5E49E1f85813F2B65858860A3FA231b4186f2e0E |
| Pendle treasury (interest-fee destination) | 0xCbcb48e22622a3778b6F14C2f5d258Ba026b05e6 |

**Factory-version caveat:** the deployment names factories `V6` (PRD §16 notes YT v6 / market v7 source review — factory version ≠ market contract version). A future factory version would be a *different address*; the PkgInit factory pin binds one factory, and a Pendle-side factory migration is a material dependency change requiring re-validation, not a silent rollover input.

## 3. Current NetNet markets (Pendle hosted API, fetched 2026-09-27 ~18:07–18:11 UTC)

All 10 chain-4663 markets enumerated; exactly two are protocol "NetNet" (sNET):

**Current, unexpired (expires in ~4 days):**
- Market: `0xab0093949fefa432bfb1a0ba8943ee4aebc898a8` — expiry **2026-10-01T00:00:00Z**
- PT `0x0be486bd185844a282690ea0f84ca628c8b67935` (PT-sNET-1OCT2026); YT `0xa20bf3e1abf0dd3927566dd776aaa9b388e4376b`; SY `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` (SY-sNET). PT/YT/SY all **18 decimals**.

**Expired (matches PRD §16's 2026-09-17 note):**
- Market `0x23c68474e3cd533a2f952a0fb998f1867e57d27f` (expiry 2026-09-17, `isActive:false`), PT `0x72b8e8c226848ceb35ba51d193f4f962dee957c1`, YT `0xfb2d72fc9c378a73b4e03abac48194367447fa5a`, **same SY** `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5`. This is the retained historical-series/claim-locator example.

**Scaled-18 structure (material for §4.5/NN-10):** the sNET series' accounting asset is `NET-scaled18` `0xba46fc84409589f369c107e869c06809df3d9727` and underlying asset `sNET-scaled18` `0x53176cadd446700fa6b89f840357ac586d7e33db` — raw sNET is 9 decimals, SY/PT/YT are 18 decimals via a decimals-wrapper layer. The expired series shows a **5% interest feeRate**. This confirms §4.5's "rebasing/scaled-unit conversion" is a real configured case, not a hypothetical: SY units are NOT raw sNET units, and sNET rebases underneath the SY.

**No successor series exists today:** no sNET market with expiry after 2026-10-01 is listed. Under §11 (successor must be compatible **and unexpired**), rollover currently has no valid target; the current market itself expires 2026-10-01. Record as a dated, blocking observation for the rollover path (NN-14), not a design defect — series creation is external.

## 4. Evidence classification (per the council's NN-01 standard)

- **Class A (design):** ROBINHOOD_MAIN.sol pins (NetNet core, infra, oracle) — repo file, commit-hash pinnable.
- **Class B (live verification, PENDING):** everything in §§2–3 above is **documentation/hosted-API attestation, not on-chain verification**. §8's before-implementation checks still owed: pair token0/token1/factory/fees; NET tax state; depository vesting (2d code vs 5d prose); factory recognition of `0xab00…98a8` via `marketFactoryV6`; SY-sNET `getTokensIn/getTokensOut`/`exchangeRate`/scaled18 conversion semantics; code-hash comparison of 4663-core.json addresses vs deployed bytecode.
- **Class D (rollover-changing):** active market/PT/YT pinned by discovery rule (factory recognition → `readTokens()`); SY may change at rollover (today both sNET series share one SY — evidence that reuse happens, not that it must).
- **Class E (dynamic):** interest feeRate (5% on expired series — varies per factory config), oracle terms, feeTo, tax/exemption state.

## 5. Recommended manifest additions (not code)

1. Add the §2 table as **PkgInit/reference candidates** labeled "docs attestation 2026-09-27, on-chain verification pending" — plus a commit-hash pin of `4663-core.json` once fetched from a pinned ref.
2. Record `0xab00…98a8` (expiry 2026-10-01) as the **evidence-backed current market lead** with explicit expiry imminence; record the expired `0x23c6…d27f` series as the historical-claim locator example. Neither is a perpetual pin.
3. Record the **scaled18 layer** (`0xba46…9727`, `0x5317…33db`) and 9-vs-18 decimal boundary as a required NN-10 verification input; SY units ≠ sNET units.
4. Record the **missing successor series** as a blocking gap for rollover liveness, with re-check method (factory events / hosted API) and date.
5. Note the docs-page/JSON discrepancy (Deployments table omits 4663) — provenance caveat, not an error to silently fix.

## 6. Limits

No on-chain call was made; every address above is either (a) the repo's own constants file or (b) official Pendle documentation/deployment-file/hosted-API attestation fetched 2026-09-27. The hosted API is off-chain aggregated data (`dataUpdatedAt` 2026-09-27 ~18:07 UTC) and can lag or err; factory recognition, token relationships, decimals and code identity remain unverified on-chain. NetNet addresses were not re-fetched from docs.netnet.capital this round — ROBINHOOD_MAIN.sol's 2026-08-28 Official-Channels verification stands as the existing attestation; refresh is a manifest task. No addresses were invented; where evidence is absent (successor series, vesting duration, live tax state) the gap is stated. One tool artifact (truncated API page) was worked around by paginated re-fetch; no read failures required retry of an identical path.
