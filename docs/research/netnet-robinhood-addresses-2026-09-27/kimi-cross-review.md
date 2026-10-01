# Kimi K3 — Robinhood addresses CROSS-REVIEW (Astra / Grok / MiniMax M3 originals)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Basis | Full reads of the three originals (untrusted evidence); my unchanged original. No peer cross-reviews. |

## 1. Four-way agreement (high confidence)

- **NetNet core pins exist and match Official Channels; Pendle is entirely absent from `ROBINHOOD_MAIN.sol`** (me, Astra, MiniMax read all 679 lines with identical line cites — NET:70, SNET:432, USDG:60, Staking:437, Depository:440, pair:447; Grok's read failed `RC_UNAVAILABLE`, so his agreement is conditional).
- **Identical Pendle anchor addresses** from `deployments/4663-core.json` across all four: `marketFactoryV6` 0x544BF81c…D01EeE2, `yieldContractFactoryV6` 0xa543BF1a…0a0a9d7, `router` 0x888888888889758F76e7103c6CbF23ABbF58F946, `routerStatic` 0x6813d437…ac655e09, `syFactory` 0x466CeD3b…7961CF8, `PENDLE` 0x5E49E1f8…86f2e0E, `pyYtLpOracle` 0x5542be50…F6DAc2. Zero address drift — strongest possible cross-check.
- Docs Deployments table omits 4663 while the JSON exists — all four note it; Astra's phrasing is canonical: "table omission is not evidence of absence."
- No perpetual market/SY pin; discovery = factory recognition → `readTokens()`; SY may change at rollover; §8's before-implementation verification remains unmet by documentation alone.

## 2. Corrections (including to myself)

- **C1 (self, per Astra + task guard): my "rollover currently has no valid target" overstates.** That inference rests on the hosted API listing. API absence ≠ on-chain absence; factory events/`isValidMarket` are authoritative. Corrected statement: *no sNET series with expiry after 2026-10-01 appears in Pendle's hosted API as of 2026-09-27 ~18:11 UTC; on-chain factory-event verification pending.* The expiry-imminence observation itself (current series ends 2026-10-01) stands and is corroborated by Grok's independent `/markets/active` fetch.
- **C2 (MiniMax, factual mischaracterization):** "the user's premise that Pendle does not exist on 4663 is incorrect" — **no user claimed Pendle absent**; the brief states the constants file lacks Pendle addresses and asks for discovery anchors. The invented-premise framing should be struck; the underlying evidence (Pendle IS deployed on 4663) is nonetheless correct and consistent with all four.
- **C3 (MiniMax, unsupported inventory claim):** MiniMax asserts the constants file "already adds post-Official-Channels pins" (BoardroomDesk, NetNetGear, BasketsDesk, Credit vault/router, Predict/House/Sports desks, StockMorphoOracles). The 679-line file read independently by me and Astra contains **none of these** (NetNet section ends at BLACKJACK_LOGIC :527). Treat as unverified/erroneous; do not carry those addresses into the manifest from MiniMax's text.
- **C4 (MiniMax, factory-version overconfidence):** "V6 is the current recommended version per Pendle docs" conflicts with Astra's and Grok's verified note that the generic docs describe **`PendleMarketFactoryV7Upg`** while the 4663 file names **V6**. Correct rule (Astra): pin the address actually attested for 4663 with its V6 label preserved; do not relabel it V7, do not import another chain's factory, and record "whether a V7 factory exists on 4663" as an open evidence gap (Astra's two guessed V6 source URLs 404'd — recorded, not retried).
- **C5 (adopt from Astra):** the JSON was read at both `main` and pinned commit **`3bb1bc056296aad10544502e5c663c0874ce13e9`** (GitHub commits API dates it 2026-09-04). Peer-reported but trivially checkable; recommend the manifest cite that commit. Upgrades my "recommend a pin" to a concrete one. Also adopt: v1 markets API is deprecated per Pendle API docs in favor of `/core/v2/markets/all` with skip/limit — cite v2 in the manifest's discovery method.
- **C6 (adopt from Grok, sharpening my scaled18 note):** the API-attested market's `underlyingAsset` 0x53176cad…7e33db is **not** official sNET 0xb773…a4c7 — it is the scaled18 face. Grok's explicit "underlying ≠ official sNET; candidate to validate, not a constant" is the correct framing; MiniMax's stricter "no authoritative SY — GAP, discovery only" is directionally right but under-inclusive, since the API *is* Pendle-hosted attestation of a candidate. Merged position: SY-sNET `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` and both scaled18 addresses are **API-attested candidates** pending on-chain validation — never constants.
- **C7 (adopt from Astra, the moderator's key distinction):** `isValidMarket` proves **factory membership only** — not active status, not NetNet backing, not executable conversion. Candidate enumeration (API, `CreateNewMarket` events; no invented `getAllMarkets`) and candidate validation (factory-first → `readTokens()` → expiry > observation block → NetNet backing → directional conversion → liquidity) are separate steps. Multiple valid candidates require explicit selection, never "first API result."

## 3. Safe minimal additions (merged; supersedes MiniMax's broad block)

Money-path anchors only, labeled REPO attestation 2026-09-27 / LIVE pending: `PENDLE_MARKET_FACTORY_V6`, `PENDLE_YIELD_CONTRACT_FACTORY_V6`, `PENDLE_ROUTER`, `PENDLE_ROUTER_STATIC`; optional clearly-labeled: `PENDLE_TOKEN`, `PENDLE_SY_FACTORY`, `PENDLE_PY_YT_LP_ORACLE`. **Excluded as unnecessary scope** (Astra's minimalism governs): vePENDLE airdrop, externalRewardsDistributor, lpWrapperFactory, decimalsFactory, merkleDepositor, depositBoxFactory, crossChainSwapHub, reflector, proxyAdmin, governanceProxy, chainlinkOracleFactory, commonDeploy, and the off-chain-helper set (multicall/balanceReader/simulate/supplyCap). MiniMax's Blockscout label cross-checks (RouterV4 label, PENDLE token page, wrappedNative == WETH9 :56) are worth recording as a third, weaker attestation class (explorer metadata, not code). Router facets (ActionMiscV3/AddRemoveLiqV3, Grok) optional; addresses match the JSON I read.

## 4. Unresolved evidence (all four agree none is closed)

On-chain `isValidMarket` for `0xab00…98a8`; SY-sNET `getTokensIn/Out`, `exchangeRate` and rebasing-sNET-under-scaled18 semantics (NN-10); deployed code hashes vs repo attestation; §8 pair token/factory/fee checks; depository vesting 2d-code vs 5d-prose; V7-factory existence on 4663; factory event start block; whether any successor sNET series exists on-chain post-2026-10-01; live tax/exemption state; feeRate on the current series (5% observed only on the expired one).

## 5. Limits

Peer claims treated as untrusted; all shared addresses cross-matched against my own fetches (4663-core.json, paginated v1 API, constants file full read). Astra's commit hash and P3 deprecation, MiniMax's Blockscout labels, and the §C3 extra-address inventory were not independently re-fetched this turn — flagged accordingly. No RPC/shell/tests; no Solidity edits proposed by me; originals unchanged.
