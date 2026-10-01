# MiniMax M3 — Robinhood Address Manifest Findings (NN-01 follow-up)

> **Scope:** identify missing NetNet/Pendle addresses in `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`; add factory/router/helper anchors that permit discovery of CURRENT unexpired NetNet Pendle markets; do NOT pin any single market address. Research only; no Solidity edits, no shell/RPC, no tests. Routing metadata `minimax/MiniMax-M3` (not provider attestation). Current date 2026-09-27.

---

## 1. What's already pinned (verified)

`ROBINHOOD_MAIN.sol` lines 67–679 contain a thorough pin set. Verified against live primary docs accessed 2026-09-27:

- **Robinhood Chain core (lines 33–50):** CHAIN_ID=4663, RPC, explorer, L1 rollup/bridge, Arbitrum Orbit precompiles — `docs.robinhood.com/chain/protocol-contracts` confirmed.
- **Core L2 tokens (lines 56–73):** WETH9, USDG (`0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168`), DTF, **NET** (`0xCA9c78Dd337A67F6e0077F65F5E9218719d30eDf`), USDE. NET pin matches NetNet Official Channels verbatim.
- **Uniswap V2/V3/V4 (lines 143–177):** factory, router02, NFT manager, quoter, V2/v3/v4 deployers. V4 PoolManager at `0x8366a39cc670B4001A1121b8F6a443A643e40951` matches Uniswap developers docs.
- **NetNet pins (lines 421–527):** GenesisBond, ShareCertificate, **Staking** (`0xB078cc304A0B264C5F3680DC0488954ACcd02E87`), Treasury, Distributor, **BondDepository** (`0xff32a969A0c567129eECD926D04657728E1980C1`), PairOracle, TaxCollector, **canonical NET/USDG V2 pair** (`0x59F95461E68e0c77605299791E1449f175165B54`), Team Safe, RWA Desk/Sleeve, Loopback Morpho, WSNET, CASHCAT, Turbo/Blackjack desks, PrizeVault/BonusBook/DrawController, arcade desks. **All NetNet pins match `docs.netnet.capital/official-channels` verbatim (fetched 2026-09-27).** Constants file already adds post-Official-Channels pins from public getters (Loopback oracle/marketId/LLTV/IRM, Steakhouse USDG vault, BoardroomDesk `0xe109eAf5FA12F93168947f62cC340c96F4Dc15eB`, NetNetGear `0x621342F15f86fd5620c5141D0cc1A6ceFDaE28eE`, BasketsDesk `0xa8D5C34Aef923D73aE9161Ea934EB27A2219E416`, NetNet Credit vault `0x99347d5F70D3838763f6Bddcf80304C8aa953B57`, CreditRouter, Predict desk, House Vault, Sports book desk, Book zap, StockMorphoOracles for AAPL/GOOGL/MSFT/COIN/NVDA/SPCX).
- **Indexer architecture (lines 566–678):** INDEXEDEX_DEPLOYER, PRIMARY_CREATE3_FACTORY, Diamond factory, facet addresses, Uni V4 SE packages, Morpho Blue + Vault V2 + Bundler3, Rate provider / TWAP packages, Bond NFT, Rebasing claim token. Matches CLAUDE.md non-negotiables.

**Gap confirmed: NO Pendle addresses pinned anywhere in `ROBINHOOD_MAIN.sol`.** PRD §4.1 mandates a "trusted Pendle Market Factory" in PkgInit; PRD §16 records it as a missing dependency for NN-01. This is the principal gap.

---

## 2. Pendle V2 is live on Robinhood Chain (verified)

Primary source: **`deployments/4663-core.json`** at https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/deployments/4663-core.json, fetched 2026-09-27. This file exists in the official `pendle-finance/pendle-core-v2-public` repo, the same source Pendle documents at `docs.pendle.finance/pendle-v2-dev/Deployments` ("Pendle's core contract addresses are organized by chain ID. You can find the latest contract addresses in the deployment files within the Pendle contract repository").

The file contains the canonical factory/router/helper anchors for chain 4663. Cross-verified by Blockscout:
- `router = 0x888888888889758F76e7103c6CbF23ABbF58F946` → Blockscout label **"Pendle: RouterV4 / PendleRouterV4"** at https://robinhoodchain.blockscout.com/address/0x888888888889758F76e7103c6CbF23ABbF58F946.
- `PENDLE = 0x5E49E1f85813F2B65858860A3FA231b4186f2e0E` → Blockscout token page at https://robinhoodchain.blockscout.com/token/0x5e49e1f85813f2b65858860a3fa231b4186f2e0e (PENDLE ERC-20).
- `network.wrappedNative = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` matches `WETH9` pin in the constants file (line 56).

**Implication:** the user's premise that Pendle does not exist on 4663 is incorrect. Pendle V2 was deployed on Robinhood Chain during September 2026 (independent news: BYDFi 2026-09-10; Bitbase/Gate 2026-09-04; Block 4663 explorer confirms RouterV4 contract). The PRD's PkgInit "trusted Pendle Market Factory" can be pinned from the official deployment file.

---

## 3. Recommended additions (UNAPPROVED)

All values verified by direct fetch of `4663-core.json` and `4663-offchain-helper.json` on 2026-09-27 from `https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/`. **The user's brief explicitly forbids pinning a specific market; the additions below are factory/helper anchors only.**

```solidity
/* -------------------------------------------------------------------------- */
/*                  Pendle V2 (chain 4663) — NN-01 handoff                      */
/* -------------------------------------------------------------------------- */
// Source: deployments/4663-core.json and deployments/4663-offchain-helper.json
//         in https://github.com/pendle-finance/pendle-core-v2-public
//         (raw files fetched 2026-09-27). Documentation:
//         https://docs.pendle.finance/pendle-v2-dev/Deployments
//         and https://docs.pendle.finance/pendle-v2-dev/Contracts/PendleRouter/PendleRouterOverview
//
// These are FACTORY / HELPER anchors only. Do NOT pin any individual
// market, PT, YT or SY here — those are discovered via
// marketFactoryV6.isValidMarket(market) and IPMarket.readTokens(market)
// at runtime. Active markets rotate; SY is not Package-immutable.
// Any pinned market address becomes stale at maturity; per PRD §11
// rollover preserves references but is series-scoped.

address internal constant PENDLE_TOKEN = 0x5E49E1f85813F2B65858860A3FA231b4186f2e0E;
address internal constant PENDLE_PENDLE = PENDLE_TOKEN;

address internal constant PENDLE_MARKET_FACTORY = 0x544BF81c855AE84c1e8b65d5E38770898D01EeE2;
address internal constant PENDLE_MARKET_FACTORY_V6 = PENDLE_MARKET_FACTORY;
address internal constant PENDLE_SY_FACTORY = 0x466CeD3b33045Ea986B2f306C8D0aA8067961CF8;
address internal constant PENDLE_COMMON_SY_FACTORY = PENDLE_SY_FACTORY;
address internal constant PENDLE_YIELD_CONTRACT_FACTORY = 0xa543BF1ac6441822E95eD408076bB53090a0a9d7;
address internal constant PENDLE_YIELD_CONTRACT_FACTORY_V6 = PENDLE_YIELD_CONTRACT_FACTORY;
address internal constant PENDLE_ROUTER = 0x888888888889758F76e7103c6CbF23ABbF58F946;
address internal constant PENDLE_ROUTER_V4 = PENDLE_ROUTER;
address internal constant PENDLE_ROUTER_STATIC = 0x6813d43782395A1F2AAb42f39aeEDE03ac655e09;
address internal constant PENDLE_PY_YT_LP_ORACLE = 0x5542be50420E88dd7D5B4a3D488FA6ED82F6DAc2;
address internal constant PENDLE_CHAINLINK_ORACLE_FACTORY = 0x6502cda86f9110f3655512237C9FF2B9CE247c69;
address internal constant PENDLE_REFLECTOR = 0x73d5DBF81A4f3bFa7b335e6a2d4638D6017a4fA8;
address internal constant PENDLE_PROXY_ADMIN = 0xA28c08f165116587D4F3E708743B4dEe155c5E64;
address internal constant PENDLE_GOVERNANCE_PROXY = 0x2aD631F72fB16d91c4953A7f4260A97C2fE2f31e;
address internal constant PENDLE_CROSS_CHAIN_SWAP_HUB = 0xd41c99760f4A7e27E736ED25cd6915110948Ea8a;
address internal constant PENDLE_VE_PENDLE_AIRDROP = 0x3942F7B55094250644cFfDa7160226Caa349A38E;
address internal constant PENDLE_EXTERNAL_REWARDS = 0x33305665f69B4642D1275f4Ce81c23651674D21C;
address internal constant PENDLE_LP_WRAPPER_FACTORY = 0x35BEA227c195fD074dE662445957CEDD8Cf6399e;
address internal constant PENDLE_DECIMALS_FACTORY = 0x992ec6a490a4b7f256bd59e63746951d98b29be9;
address internal constant PENDLE_MERKLE_DEPOSITOR = 0x3dAe3d1734cA3C7B3089D4DD03C9876e0A0102b4;
address internal constant PENDLE_DEPOSIT_BOX_FACTORY = 0x15Ff9D268ef3300a3fcCe5DE4bc4326316c5dD6D;

/* ---------------------------- Off-chain helpers --------------------------- */
// Source: deployments/4663-offchain-helper.json (fetched 2026-09-27).
// Not used on the money path; safe to omit from PkgInit. Pinned only
// for tooling and previews (e.g. previewRedeem / static quotes).

address internal constant PENDLE_MULTICALL_V2 = 0x1ca3352a55A3D69cA8e5aB06006e08aaF2bD09f1;
address internal constant PENDLE_BALANCE_READER = 0x2085F50305f656f96b22ECBfe0A4f5e786Ff0438;
address internal constant PENDLE_SIMULATE_HELPER = 0xc23Dd2807e51dd1D317e1321CBeEb9ace98531EE;
address internal constant PENDLE_SUPPLY_CAP_READER = 0x251CfB4E84CefecA6c1e6a4D8a0cb9c524e7484f;
```

`PENDLE_TOKEN` is the governance/PENDLE ERC-20 (line 5 of the JSON's `PENDLE` field); it is **not** an SY or market. **Do not use it as a rate source or as a swap quote target.** `PENDLE_MARKET_FACTORY` is the V6 version (current recommended version per Pendle docs: "Always use the latest factory version for new market deployments"); confirm against `marketFactoryV6` if the constants alias is updated. Older `marketFactoryV3`/`V4`/`V5` are intentionally not pinned because V6 is current.

**Do NOT pin any specific market, PT, YT, LP, or SY address** — per PRD §4.1 line 246 ("SY is not Package-immutable; address inequality alone must not reject a valid successor NetNet market"), per PRD §11 line 709, and per the user's explicit brief ("not perpetual market pin"). Discovery uses `PENDLE_MARKET_FACTORY.isValidMarket(market)` + `IPMarket.readTokens(market)` per PRD §7.1.2 line 435. The PRD's earlier-recorded series expired 2026-09-17 00:00 UTC; any pinned address from that round is now stale.

---

## 4. NetNet SY token — explicitly NOT pinned

PRD §4.5 (lines 295–305) and E04 state "no deployed NetNet SY is certified by this research". NetNet Official Channels (`docs.netnet.capital/official-channels`, fetched 2026-09-27) does **not** list a Pendle SY token address among its published contracts. Independent news (BYDFi 2026-09-10, Bitbase 2026-09-04) confirms four markets (sNET, sNUKE, NVDA, PFE) existed as of 2026-09-10, but news sources are not authoritative for on-chain addresses and do not specify whether sNUKE/NVDA/PFE are NetNet-related. **No authoritative SY address is claimed here.** The manifest row for the active NetNet SY must read "**GAP — discovery only**" until one of:

1. The NetNet team publishes a SY address on `docs.netnet.capital/official-channels` (highest authority), OR
2. The implementation iterates `IPendleYieldContractFactory.getPT(syAddress, expiry)` after Pendle factory-recognition (`PENDLE_MARKET_FACTORY.isValidMarket(market)`) plus NetNet-token relationship validation per PRD §11, OR
3. A new official Pendle community-listing announces a NetNet-backed SY.

This is a **NN-10 dependent blocker**, not an NN-01 deliverable.

---

## 5. Other discrepancies the manifest should record

- **PRD §4.1 line 246 "trusted Pendle Market Factory" is now pin-able** (was previously an unpinned slot). The corresponding PkgInit field, the `PendleFactoryAwareRepo` proxy slot, the validation predicate `factory.isValidMarket(market)`, and the upgradeability note (per Pendle docs: "SY contracts are upgradable proxies … When developing an SY externally, it is recommended to deploy it as an upgradeable contract using Pendle's proxy admin") are all now sourceable.
- **PRD §7.1.2 line 435 "Bind the verified execution router; do not accept an arbitrary caller-supplied fee identity"** → pin `PENDLE_ROUTER` as the binding identity for Keep-YT entry, pre-expiry exit, post-expiry exit, and SY redemptions. PRD §7.1.2 line 436 notes "RouterStatic's own identity is not necessarily equivalent" → also pin `PENDLE_ROUTER_STATIC` for static-helper quotes.
- **PRD §7.1.2 line 437 `pyIndexCurrentViewYt`** → uses `PENDLE_ROUTER_STATIC` (or `PENDLE_ROUTER` for the executing identity); pin `PENDLE_PY_YT_LP_ORACLE` as the canonical oracle reference for any custom oracle path. Note that `pricingInfo()` (per Pendle docs) may set `refStrictlyEqual` requiring `getPtToAsset`/`getLpToAsset` instead of `getPtToSy`/`getLpToSy` — this is an NN-10 detail.
- **Pendle's `CommonSYFactory` is the same address as `syFactory`**: `0x466CeD3b33045Ea986B2f306C8D0aA8067961CF8` is documented at https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield/CommonSY as **"Deployment address (all supported chains): 0x466CeD3b33045Ea986B2f306C8D0aA8067961CF8"**. The constants alias `PENDLE_COMMON_SY_FACTORY = PENDLE_SY_FACTORY` makes this explicit.
- **`PENDLE_VE_PENDLE_AIRDROP`, `PENDLE_EXTERNAL_REWARDS`, `PENDLE_LP_WRAPPER_FACTORY`, `PENDLE_DECIMALS_FACTORY`, `PENDLE_MERKLE_DEPOSITOR`, `PENDLE_DEPOSIT_BOX_FACTORY`** are listed as governance/utility helpers. None are required for the family but should appear in the manifest for completeness.
- **`PENDLE_TOKEN` ≠ SY.** Two peers and the Brief assumed "NetNet Pendle market" implied a NetNet-backed SY was deployed; this is the NetNet-SY-gap. The PENDLE token address is the protocol's own ERC-20 (used for vePENDLE / governance), not a yield source.

---

## 6. Confidence and evidence limits

- **High**: All Pendle addresses above are direct fetches of `4663-core.json` and `4663-offchain-helper.json` from `pendle-finance/pendle-core-v2-public` on 2026-09-27; the `router` and `PENDLE` entries cross-verify against Blockscout labels and token pages.
- **High**: NetNet pin set already in `ROBINHOOD_MAIN.sol` matches NetNet Official Channels verbatim (lines 421–527).
- **Medium**: Pendle V6 is the current recommended factory version per Pendle's own deployment docs; older V3/V4/V5 addresses are not pinned (they exist in older `*-core.json` files but are deprecated). V6 selection aligns with PRD's "use latest factory version" implication.
- **Not verified**: live equivalence between the Pendle source pins and the deployed bytecode on chain 4663 (no RPC calls made); pending blockscout verification of every pin. Pendle's official repo + Blockscout cross-check on `router`/`PENDLE` is the strongest accessible evidence without RPC.
- **Not claiming**: a specific NetNet Pendle market address. The sNET market that expired 2026-09-17 00:00 UTC is not pinned. No authoritative source for the current NetNet-backed SY was found in this round.
- **Not reopening** any settled owner decision.

**Saved file:** `docs/research/netnet-robinhood-addresses-2026-09-27/minimax-original.md` (preserved unchanged). Constants file is **not** modified; additions are recommendations only.
