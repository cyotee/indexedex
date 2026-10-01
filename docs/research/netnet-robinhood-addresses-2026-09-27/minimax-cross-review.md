# MiniMax M3 — Robinhood Addresses Cross-Review (NN-01 follow-up)

> Cross-review of three peer originals for the Robinhood 4663 NetNet/Pendle address handoff. Read together; no peer cross-review artifacts consulted. My `minimax-original.md` is the baseline. Research-only; routing metadata `minimax/MiniMax-M3` only (not provider attestation). Date 2026-09-27.

---

## 1. Convergence (all four agree)

1. **Pendle V2 IS deployed on Robinhood Chain (4663).** Verified via `raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/deployments/4663-core.json` and cross-checked via Blockscout labels (e.g., `router = 0x8888…F946` → "Pendle: RouterV4 / PendleRouterV4"). No peer claimed "Pendle absent"; the user's brief premise is settled. The docs page table omits 4663 but the file exists.
2. **`ROBINHOOD_MAIN.sol` has zero Pendle anchors** (lines 1–679 verified). NetNet pins already in the file match `docs.netnet.capital/official-channels` verbatim (fetched 2026-09-27), including the constants file's post-Official-Channels additions (Loopback oracle/marketId/LLTV/IRM, Steakhouse USDG vault, BoardroomDesk `0xe109eAf5…15eB`, NetNetGear, BasketsDesk, NetNet Credit vault, Predict desk, House Vault, Sports book desk, Book zap, StockMorphoOracles).
3. **No specific market, PT, YT, or SY pin** — discovery only via factory + `IPMarket.readTokens()`. Per PRD §4.1 line 246, §11 line 709, and the user's explicit brief.
4. **All evidence is documentation/hosted-API attestation; no on-chain bytecode verification was performed.**

---

## 2. Reconciled address list (verified across peers)

| Role | Address | Source class |
| --- | --- | --- |
| `marketFactoryV6` | `0x544BF81c855AE84c1e8b65d5E38770898D01EeE2` | REPO |
| `yieldContractFactoryV6` | `0xa543BF1ac6441822E95eD408076bB53090a0a9d7` | REPO |
| `router` (RouterV4) | `0x888888888889758F76e7103c6CbF23ABbF58F946` | REPO + Blockscout |
| `routerStatic` | `0x6813d43782395A1F2AAb42f39aeEDE03ac655e09` | REPO |
| `syFactory` | `0x466CeD3b33045Ea986B2f306C8D0aA8067961CF8` | REPO (same address on all chains per docs) |
| `pyYtLpOracle` | `0x5542be50420E88dd7D5B4a3D488FA6ED82F6DAc2` | REPO |
| `PendleChainlinkOracleFactory` | `0x6502cda86f9110f3655512237C9FF2B9CE247c69` | REPO |
| `PENDLE` (governance token, not an SY) | `0x5E49E1f85813F2B65858860A3FA231B4186f2e0E` | REPO + Blockscout |
| `treasury` (interest-fee destination) | `0xCbcb48e22622a3778b6F14C2f5d258Ba026b05e6` | REPO |
| `governanceProxy` | `0x2aD631F72fB16d91c4953A7f4260A97C2fE2f31e` | REPO |
| `reflector` | `0x73d5DBF81A4f3bFa7b335e6a2d4638D6017a4fA8` | REPO |
| `proxyAdmin` | `0xA28c08f165116587D4F3E708743B4dEe155c5E64` | REPO |
| `crossChainSwapHub` | `0xd41c99760f4A7e27E736ED25cd6915110948Ea8a` | REPO |

API-derived candidates (Kimi, Grok; **not constants, but manifest rows for discovery**):

| Role | Address | Notes |
| --- | --- | --- |
| Current sNET market candidate | `0xab0093949fefa432bfb1a0ba8943ee4aebc898a8` | API-fetched 2026-09-27; expiry 2026-10-01T00:00:00Z (~4 days) |
| PT-sNET-1OCT2026 | `0x0be486bd185844a282690ea0f84ca628c8b67935` | 18 decimals |
| YT-sNET-1OCT2026 | `0xa20bf3e1abf0dd3927566dd776aaa9b388e4376b` | 18 decimals |
| SY-sNET (shared by both series) | `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` | 18 decimals; SY units ≠ raw sNET units |
| `underlyingAsset` (`sNET-scaled18`) | `0x53176cadd446700fa6b89f840357ac586d7e33db` | 18 decimals; ≠ official `SNET 0xb773…a4c7` (9 decimals) |
| `accountingAsset` (`NET-scaled18`) | `0xba46fc84409589f369c107e869c06809df3d9727` | decimals-wrapper layer |
| Expired sNET market (historical) | `0x23c68474e3cd533a2f952a0fb998f1867e57d27f` | expiry 2026-09-17; `isActive:false`; historical-claim locator |

---

## 3. Where my original needs correction (attributed)

- **I missed the API fetch for the current sNET market.** Kimi and Grok both fetched `api-v2.pendle.finance/core/v1/4663/markets` and found an unexpired sNET market at `0xab00…98a8` (expiry 2026-10-01). The user's brief explicitly asked for "discovery of CURRENT unexpired NetNet Pendle markets." I should have included the API result and explicitly noted it as a **manifest row, not a constant**. Adding now.
- **I missed the scaled18 layer.** Kimi clarified that SY/PT/YT are 18 decimals while raw sNET is 9; the API's `underlyingAsset` `0x5317…33db` is `sNET-scaled18` (decimals wrapper), distinct from `SNET 0xb773…a4c7`. Grok noted the mismatch but didn't name it scaled18. Kimi's framing is sharper — a real NN-10 input.
- **I missed the V6 vs V7Upg discrepancy.** Astra flagged it; the generic `PendleMarketFactoryV7Upg` docs describe a different version than the chain-specific V6 manifest. Pin as `marketFactoryV6`; do not relabel V7; verify by bytecode if V7 actually deployed.
- **I missed the 5% interest feeRate** (Kimi) and the no-successor observation (Kimi): the current sNET market expires 2026-10-01 (~4 days); under PRD §11, rollover currently has no valid target. This is a blocking observation, not a design defect.
- **I over-extended the helper list.** My list of 21+ anchors (including LP_WRAPPER_FACTORY, DECIMALS_FACTORY, MERKLE_DEPOSITOR, DEPOSIT_BOX_FACTORY, and the off-chain helpers MULTICALL_V2/BALANCE_READER/SIMULATE_HELPER/SUPPLY_CAP_READER) is broader than the user's "minimum additions" framing. Astra's recommendation (just the seven factory/router anchors) is more focused. Recommend trimming to: the 7 essential anchors; the treasury, governanceProxy, reflector, proxyAdmin, crossChainSwapHub (governance/infrastructure); defer the others.
- **I missed the commit-hash pin.** Astra pinned `4663-core.json` to commit `3bb1bc056296aad10544502e5c663c0874ce13e9` (GitHub path-specific commit response dated 2026-09-04). Per NN-01 standard (Kimi Class A provenance), vendor-tree files need upstream URL + commit hash, not just snapshot date.

---

## 4. Genuine dissent (none on product)

None of the four peers opened a settled owner decision. One classification difference: Grok's tool failure (`RC_UNAVAILABLE` on ROBINHOOD_MAIN.sol) is recorded honestly; he could not compare against existing Crane pins but his proposed additions match Kimi's and mine.

---

## 5. Reconciliation recommendations (consolidated)

**Safe constant additions** (all four agree; documentation attestation 2026-09-27):
- The 7 essential anchors: `marketFactoryV6`, `yieldContractFactoryV6`, `router` (RouterV4), `routerStatic`, `syFactory`, `pyYtLpOracle`, `PENDLE` token.
- Plus: `treasury`, `governanceProxy`, `reflector`, `proxyAdmin`, `crossChainSwapHub` (governance/utility).

**Not constants, but mandatory manifest rows:**
- Current sNET market candidate `0xab00…98a8` (expiry 2026-10-01, ~4 days from today), with PT/YT/SY addresses and explicit expiry imminence.
- Scaled18 layer addresses (`0x5317…33db` underlying, `0xba46…9727` accounting, `0x5d44…aaf5` SY) and the 9→18 decimal boundary.
- Expired sNET series `0x23c6…d27f` as historical-claim locator only.
- 5% interest feeRate on the expired series (Kimi evidence) → varies per factory config.

**Provenance requirements (per NN-01 Class A standard):**
- Pin `4663-core.json` to upstream commit `3bb1bc056296aad10544502e5c663c0874ce13e9` (Astra), not just snapshot date.

**Do NOT add as constants** (per Kimi's distinction, do not infer "no on-chain successor" from absent API result):
- Any specific market, PT, YT, LP, or SY address as a perpetual pin.
- NetNet extras beyond what's in the constants file (PRD already approved scope; extras belong to a separate manifest row, not this handoff).

**V6 vs V7Upg caveat:** pin as `marketFactoryV6`. Generic docs describe V7Upg; chain-specific manifest names V6. Do not relabel as V7; verify by bytecode if V7 is actually deployed. PkgInit binds one factory; a Pendle-side factory migration is a material dependency change requiring re-validation, not silent rollover.

**Rollover blocker (Kimi):** the current sNET market expires 2026-10-01; no successor series is listed. Under PRD §11, successor must be compatible AND unexpired — rollover currently has no valid target. This is a dated, blocking observation for NN-14, not a design defect.

**`isValidMarket` vs API distinction (Grok):** API results are off-chain aggregated data. `isValidMarket` proves factory membership only, not active status, not NetNet backing, not decimals, not codehash equivalence. The PRD §11.1 factory-first validation chain (factory recognition → `readTokens()` → NetNet-token relationship → expiry > observation block → PT/YT/SY relationships → actual NetNet backing) remains the closure path.

---

## 6. Confidence and evidence limits

- **High** on the factory/router anchor addresses (direct fetch of `4663-core.json`; cross-checked `router`/`PENDLE` via Blockscout).
- **High** on NetNet pin consistency with Official Channels.
- **Medium** on the API candidate `0xab00…98a8` being the "current NetNet market" — confirmed by Kimi and Grok independently; not yet on-chain verified.
- **Medium** on the scaled18 layer identification — Kimi's interpretation is consistent with `sNET 9 decimals vs SY 18 decimals`.
- **Low** on `isValidMarket` semantics for V6 (not re-verified this round).
- **Not verified**: bytecode equivalence on 4663; live codehashes; active market through factory events; tax state; depository vesting (NN-02 still open).
- **Not asserting** that V7 is or isn't deployed.
- **Not reopening**: any settled owner decision.

**Saved file:** `docs/research/netnet-robinhood-addresses-2026-09-27/minimax-cross-review.md`. Originals untouched.
