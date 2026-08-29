# Product Requirements Document (PRD)

## Title

**Unified DETF deprecation test coverage**: hermetic Foundry proof that `UniswapV4DetfDFPkg` covers the product-law, I/O, claim, donation, and adversarial depth of the four hook-specific Uni V4 DETF packages, so those packages and the scripts that deploy them can be deprecated

---

## 1. Header

| Field | Value |
|-------|--------|
| **Status** | **OPEN** (2026-08-28; tests first. Critical-flaw CODE is **stop and report**. Do **not** restore family DETF function names). Review locks in **§0** are part of this sheet |
| **Kind** | Test PRD. Authorizes tests + TestBases + deprecation of family packages, leftover Uni V4 NFT/claim packages, instances, and scripts. Comparable **behavior**, not comparable **ABI**. Layered **SE × hook × unified DETF** coverage (§7.0) |
| **Date** | 2026-08-28 |
| **Home** | `contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_PRD.md` |
| **Product law** | [`DETF_INSTANCE_IO_ROUTING_PRD.md`](./DETF_INSTANCE_IO_ROUTING_PRD.md) **§16 wins**. Alignment [`DETF_ALIGNMENT_PRD.md`](./DETF_ALIGNMENT_PRD.md) **D1–D31**. Donation [`DETF_RESERVE_DONATION_PRD.md`](./DETF_RESERVE_DONATION_PRD.md) with Uni V4 booking **R12a**. Opening price [`UNISWAP_V4_SE_DETF_PEG_AND_OPENING_PRICE_PRD.md`](./protocols/dexes/uniswap/v4/standardExchange/UNISWAP_V4_SE_DETF_PEG_AND_OPENING_PRICE_PRD.md) **N1–N18**. Compound/expansion [`docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](../../../docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) |
| **Already green (do not re-litigate)** | [`UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md`](./UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md) Stage 11: 26 fixtures × firstBond/mint/burn/close. Keep those files green. They are **not** this PRD’s acceptance |
| **Skills** | `crane-testing`, `indexedex-testing`, `indexedex-adversarial-testing`, `crane-adversarial-testing`, `crane-deployment`, `indexedex-uniswap-v4-hook-packages`, `indexedex-launch-scripts` |
| **Law** | Root `Claude.md`; [`docs/agent/INDEXEDEX_AGENT_LAW.md`](../../docs/agent/INDEXEDEX_AGENT_LAW.md) |
| **Worktree prefix** | `unified_detf_pl_` |
| **Execute** | [`UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md) (`/goal` kickoff, DAG, child prompts). This PRD stays product law. §0 / §7.0 win on IDs, ABI, layers. Do not invent extra hooks, SE classes, n-arity, or Policy/Custom mixes beyond §5–§7. Do not add family DETF entrypoints onto `IUniswapV4Detf`. Critical flaw: stop and report |

**Short name:** unified DETF deprecation coverage.

---

## 0. Locked review decisions (2026-08-28)

These close the contradictions that were in the first draft. They win over any leftover “or” / “if” phrasing elsewhere in this file.

| ID | Decision |
|----|----------|
| **R-1** | **Layered catalog**, not “every §7 ID on every Stage 11 file.” Four gold hooks get full gold §7. Stage 11 Open and Stage 11 Policy get the ID sets in §7.0. Gold-only IDs never run on Stage 11 |
| **R-2** | D15 gold ports family names `test_D15_1` … `test_D15_9`. **D15-5** is Orbital/Weighted/Quad gold only (CP gold NatSpec `D15-5 N/A single leftover pair`). Stage 11 gets the four D15 IDs in §7.0, not the full 1–9 set |
| **R-3** | **DN15 N/A** (R12a supersedes family N10 `convertToAssets` stasis; DN1 already asserts NAV rises). Add **DN21** and **DN22**. Keep DN19/DN20. DN3 remains N/A |
| **R-4** | Stage 11 **always** sibling files `*_ProductLaw.t.sol` and `*_Policy.t.sol`. Never add §7 tests into existing firstBond/mint/burn/close contracts |
| **R-5** | **H-CP-P2** stays `pons/UniswapV4Detf_PonsV2Se.t.sol` + `contracts/test/bases/TestBase_UniswapV4Detf_PonsV2Se.sol`. Fix hook pair and `mintToken` to the pons v2 **launch token**. Keep T10.8–T10.10 green on that token. Do **not** create `TestBase_UniswapV4Detf_Cp_PonsV2Se` |
| **R-6** | Do **not** edit `TestBase_UniswapV4Detf.sol`. POLICY adds `TestBase_UniswapV4Detf_Policy.sol`. ADV adds `TestBase_UniswapV4Detf_Adversarial.sol`. H-CP-P2 pair fix is only the pons TestBase in R-5 |
| **R-7** | Each CP WP ships **abstract `*Base.sol` + CP gold concrete**. IO is not abstracts-only. n-leg WPs add n-leg concretes only (plus Quad T8.3 execute, Weighted T8.4 / T6) |
| **R-8** | **CLAIM waits for POLICY** green (D15-7 realize). Remove the old “if redeem must realize” hedge |
| **R-9** | **D18 is not tested.** `IRebasingClaimToken.mintFromNFTSale` is `onlyOwner`. No public DETF deposit. Do not add `buyClaim` / `depositClaim` tests or DETF selectors |
| **R-10** | **E6 N/A.** Unified `mint` / `bond` / `donate` have no unused-inbound refund. NatSpec on the adversarial suite: `E6 N/A no residual-return`. Do not add a refund |
| **R-11** | Nested SE: **T-NEST-1, T-NEST-2, T-NEST-3, T-LOCAL-I1** only. Defer T-NEST-4..8 in suite NatSpec. Those four IDs run on gold ERC-4626 **and** every Stage 11 bound SE |
| **R-12** | Custom close **execute**: CP gold T7.11 (IO) and Quad gold T8.3 (QD). Orbital/Weighted stay table-only for custom close. Not on Stage 11 |
| **R-13** | Weighted **T8.4** is a Policy instance driven by real reserve skew / donate, **not** a Custom mint table. Weighted gold + every Weighted Stage 11 Policy sibling |
| **R-14** | `test_compound_raises_protocolLp`: public `compoundProtocolRewards` must not revert. `lpOut==0` is **success** when lazy compound on mint/bond already consumed protocol pending. If `lpOut>0`, Bond NFT hook-LP must rise. Not a third time on Stage 11 Policy siblings. **Amended 2026-08-28** |
| **R-15** | **K1** = `test_K1_donationNotMintCredit` on `Adversarial_TrustFlags.t.sol` (same economic assert as I1/DN9). **F1** = `test_F1_satellitesUnowned` on `Adversarial_A0Crops.t.sol` |
| **R-16** | FC names: `test_FC1_univ4Detf_<hook>_…` with `<hook>` in `{cp, orbital, weighted, quad}` on gold; Stage 11 Policy uses `test_FC1_univ4Detf_<FixtureId>_…` (example `H_CP_GV3`). Alignment §20.1 asserts. `assertGt(claimed,0)` alone fails. **FC4** new-shares event is a later `bond`, not family `buyClaim` |
| **R-17** | Fee oracle: `p = 5e16`, `f = 12e16`, `c = 28e16` (Alignment D6). Not “copy whatever the family TestBase has” |
| **R-18** | Launch-rich opening starts at `1.1e18` each slot, then `+0.05e18` and redeploy until `isMintingAllowed` is true, **max 24 steps** (final slot `2.25e18`). If still false after 24, that is §6.1, not another step. Record the final WAD in that TestBase NatSpec. **Amended 2026-08-28** (was 10 / 1.55e18) |
| **R-19** | WP DONE regression matchers are exactly three paths plus the WP path: `prod-se/**`, `pons/**`, `UniswapV4Detf_*.t.sol` |
| **R-20** | L2 FoT (`test_T7_15`) once on CP gold as **NatSpec N/A**: FoT is forbidden as a product claim (UI/docs). There is no consistent on-chain FoT detector, so **no deploy-time `processArgs` check** and no deploy-revert assert. Never a FoT-success money path. J1–J3 once per hook gold. Reentrancy `IsLocked` on gold mint (burn/bond only if a hostile callback exists on that gold ERC-4626 path). Not on Stage 11. **Amended 2026-08-28** |
| **R-21** | D22 (`test_D22_claimUngated` / `test_D15_9_ungatedVsPolicy`) runs on **Policy** instances only (needs a deadband). Open instances do not run D22 |
| **R-22** | D15 preview: `IRebasingClaimToken.previewRedeem` exists. `test_D15_1_previewEqualsExecute` must `assertEq` preview and exec. Do not add a new preview on the DETF |
| **R-23** | Owner-only: IO = CP gold. OR / WE / QD = that hook’s gold. Stage 11 Open siblings run the same two asserts |
| **R-24** | Do not inherit gold-full suite abstracts onto Stage 11. Stage 11 siblings inherit the **Open** or **Policy** layer abstracts in §8 that contain only that layer’s IDs (no skip-empty test bodies) |

---

## 2. Intent

`UniswapV4DetfDFPkg` at `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` is the v1 Uni V4 DETF. One DFPkg binds CP, Orbital, Weighted, or Quad SE-buffer hooks via `PkgArgs.hook`.

Robinhood **main** already deploys that package (`Phase_06_Stage_07_UniswapV4DetfPkg`). The four hook-specific DETF diamonds still exist and still have the deep suites:

- Policy thresholds, natural expansion D31, protocol compound
- Sell-to-claim, redeem D15, ids 1–2 (D17/D28)
- Mature close D25 (rejoin DETF to id 0, not only "basket paid")
- Donation N/DN suite
- Nested SE fund / trust-flag I, surface J, A0, CROPS
- Opening vs creation price
- Remaining Stage 07 T7.* holes (share mint, later bond, custom close **execute**, FoT, Default table shape)

Those family tests run against **different DFPkgs** and almost all use `SimpleYieldERC4626`. They do not prove the unified diamond. The Stage 11 matrix proves production SE unwrap for mint/burn/bond/close only.

The unified ABI is the new standard. Family diamonds exposed `sellPositionToDetfNft`, `buyClaim` / `depositClaim`, and `redeemClaim` on the DETF. Unified does not. Sell is on the R12a Bond NFT. Redeem is on `IRebasingClaimToken`. This PRD requires **the same economic outcomes** (D10/D15/D17/D22/D28) through those peers. It does **not** require the old selectors on `IUniswapV4Detf`.

When every WP is green, hook-specific Uni V4 DETF packages, their tests, and every script that still deploys those packages or instances (testnet stages, `anvil_robinhood_fee_detf` Chir, demo instance libs) may be removed.

`contracts/vaults/detf/common/` is shared libs, not the SUT.

---

## 3. Product under test (LOCKED)

| Item | Value |
|------|--------|
| DETF DFPkg | `UniswapV4DetfDFPkg` |
| Interface | `IUniswapV4Detf` / `IUniswapV4DetfDFPkg` |
| Bond NFT | `contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/` (R12a). Not common `DETFNFTVaultDFPkg` for Uni V4 instances |
| Claim token | `contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg` wired in `postDeploy` |
| Hook ABI | `IUniswapV4SeBufferHook` / §15.12 |
| Discovery | `hook.tokens()`, `hook.standardExchangeOf`, route-table getters. Not `pairToken()` / `rateAsset()` / `underlyingVault()` |
| `reservePool()` | hook address |
| Deploy | Hook DFPkg first (predicted DETF as raw/owner). DETF via `indexedexManager.deploy*` / registry. Never `new` facets/DFPkgs. Never Dual as `PkgArgs.hook` |

**Not this PRD’s SUT:** old CP / Orbital / Weighted / Quad **DETF packages** under `…/uniswap/v4/standardExchange/**`. Copy test **logic** from those files. Do not inherit their TestBases. Do not treat their green runs as acceptance.

**Not this PRD’s SUT:** Balancer-hosted DETFs.

---

## 4. In scope / out of scope (LOCKED)

### 4.1 In

1. Full **gold** product-law behavior on every unified DETF × hook pair: CP (`n=2`), Orbital (`n=3`), Weighted (`n=3`, equal `0.5e18` / `0.5e18` on the two pairs), Quad (`n=4`, `baseAmp=100`). Not CP-full / n-leg smoke.
2. Fill Stage 07 T7 holes as named specs. Split gold-only vs Open-layer per §7.0 / §7.1. I/O table shape is CP-pathfinder plus n-leg asserts where arity differs.
3. Execute Custom close leftover swaps: CP T7.11 and Quad T8.3 only (R-12).
4. Policy + D31-1..4 + compound + opening vs creation on **all four gold** hooks, then the Policy layer on every Stage 11 Policy sibling (R-1).
5. Claim **behavior** on the unified instance through Bond NFT + claim token. Gold D15-1..9 (D15-5 n-leg only). Stage 11 D15 subset in §7.0. D18 is out (R-9).
6. Donation DN1–DN14, DN16–DN22 with **R12a** booking. DN3 N/A. DN15 N/A (R-3).
7. Adversarial P0 on the unified **gold** proxy per hook: A0, I1–I3, J1–J3 (once per hook gold), K1, F1, CROPS, L2 FoT once on CP gold, reentrancy `IsLocked` on gold mint. Stage 11 Open gets I1–I3, A0, CROPS, nested four IDs only (R-1, R-11, R-15, R-20).
8. Nested **SE** fund (T-NEST-1..3 + T-LOCAL-I1) against the bound SE, gold ERC-4626 and every Stage 11 fixture. Not a nested DETF diamond. Not T-NEST-4..8.
9. Layered catalog (§7.0) on every Stage 11 fixture: 4 hooks × (G-V3, G-V4, P1-V3, P2-V4, MB-BLUE) plus the 6 mixed rows. Gold ERC-4626 is the **pathfinder only**, not acceptance for an SE class.
10. Fix H-CP-P2 hook pair to the **launch token** (matrix PRD §8.2) on the existing pons TestBase (R-5). Current Stage 10 CP row treats the pair as WETH.
11. After tests green: retarget packages and instances (testnet, `fee_detf` Chir and later stages, WireLib, `ProtocolDetfInstanceLib`), then **delete** family DETF Solidity, leftover `uniswap/v4/common/{nft,rebasing}`, SAF/fork/research that import family DETF TestBases.

### 4.2 Out (do not add)

| Item | Reason |
|------|--------|
| Re-run Stage 11 26×4 firstBond/mint/burn/close | Already DONE. Regression matcher only |
| Dual as `PkgArgs.hook` | T7.1 already reverts |
| Balancer DETFs / Balancer buffer hook | Out of Uni V4 v1 |
| Weighted `n=8` all-SE | Unified v1 locks Weighted `n=3` |
| Morpho-loop DETF, Morpho Vault V2 | Later package |
| Native ETH quote | R20 v1: WETH quote only |
| FoT success path / rebasing underlyings | Token policy. L2 is forbidden only, CP gold once |
| Fork 4663 | Hermetic is the bar |
| Fuzz / invariant handlers | Family Uni V4 packages did not have them. Optional P1 after deprecation, not this gate |
| `via_ir`, `vm.mockCall` of SUT, `new` DFPkg | Forbidden |
| Editing family DETF production Solidity except to keep compiles until WP-UDPL-DEPRECATE | This PRD ports tests, then deletes |
| Reopening mint/burn quote D8, D11 join, D13 burn sizing, Policy 1.05/0.95 | Alignment locked |
| Restoring family DETF ABI on `IUniswapV4Detf` (`buyClaim`, `depositClaim`, `redeemClaim`, `sellPositionToDetfNft` on the DETF, `pairToken()`, `rateAsset()`, family multi-arity `bond`) | New ABI is the standard. Call Bond NFT and claim token for those behaviors |
| D18 `buyClaim` / public DETF→claim convenience | Gone by design (R-9) |
| E6 refund recipe as a production path | No residual-return on unified mint/bond/donate (R-10) |
| T-NEST-4..8 | Deferred NatSpec (R-11) |
| Custom close execute on Orbital, Weighted, or Stage 11 | R-12 |
| Editing `TestBase_UniswapV4Detf.sol` | R-6 |
| Adding §7 tests into existing Stage 11 firstBond files | R-4 |
| CODE on a red §7 test without a user go-ahead | Critical flaw: stop the WP and report |

---

## 5. Fixture constants (LOCKED)

Use these unless a row overrides.

### 5.1 Gold (product-law host)

| Constant | Value |
|----------|--------|
| SE class | Existing gold `SimpleYieldERC4626` via `TestBase_UniswapV4Detf` (CP) / `_Orbital` / `_Weighted` / `_Quad` |
| Open-mode rows | `ThresholdMode.Open`, expansion fields 0, all five `RouteTableMode.Default` (same as Stage 11) |
| Policy-mode rows | `ThresholdMode.Policy`, `mintThreshold = 1.05e18`, `burnThreshold = 0.95e18` |
| Peg | `creationPairPerDetfWad` length `n-1`, each `1e18` |
| Opening at peg | `openingPairPerDetfWad` empty or zeros (resolves to creation) |
| Launch-rich (Policy mint-open after first bond) | `openingPairPerDetfWad` each `1.1e18`. If `isMintingAllowed` is still false after first bond, raise every slot by `0.05e18` and redeploy. **Max 24 steps** (final slot `2.25e18`). If still false, §6.1. Record the final WAD in that TestBase NatSpec. Do not `prank(detf)` to LP the hook before first bond (opening-price N11) |
| Policy expansion (D31 rows only) | `expansionEpochLength = 1 days`, `expansionClosureRatePerYearWad = 0.05e18`, `expansionMaxCatchUpEpochs = 4` |
| Open expansion | all expansion fields 0 |
| `creator` | `makeAddr("creator")` nonzero. FC11 deploys a **second** instance with `creator = address(0)` |
| Fee oracle `p` / `f` / `c` | `p = 5e16`, `f = 12e16`, `c = 28e16` (Alignment D6). FC3 must see `Δ > 0` and `E > 0` |
| `DEFAULT_MIN_LOCK` / `MAX` | 30 days / 180 days |
| First bond | `100 ether` of each non-DETF `hook.tokens()` entry, full book (D16) |
| Live mint | `10 ether` of `mintToken` = first non-DETF `hook.tokens()` address |
| Later bond (T7.10) | `20 ether` of `mintToken` after live |
| Deadline | `block.timestamp + 1 hours` |
| I1 claimed amount | `10 ether` while vault/hook already holds ≥ that from a prior donate or first-bond residual **without** a new user transfer |
| I2 short delivery | claim `10 ether`, transfer `1 ether` |

### 5.2 SE × hook × DETF (LOCKED)

Stage 11 already deploys 26 Open fixtures. This PRD **reuses those TestBases**. It does not invent a 27th SE class.

| Layer | What runs |
|-------|-----------|
| Pathfinder | Gold ERC-4626 `TestBase_UniswapV4Detf` (CP), then `_Orbital`, `_Weighted`, `_Quad`. Fast compile. Proves gold §7 once |
| Acceptance for an SE class | That class’s Stage 11 TestBase must pass the **§7.0 Open + Policy ID sets** via siblings. Not firstBond/mint/burn/close alone |

Homogeneous (20) + mixed (6) = 26. H-CP-P2 is the existing pons file (R-5), not a new `prod-se/` CP PonsV2 contract.

Each fixture gets **exactly two new contracts** (R-4):

1. `UniswapV4Detf_<Fixture>_ProductLaw.t.sol` under `test/…/detf/prod-se/` (H-CP-P2: under `test/…/detf/pons/`). Inherits that fixture’s TestBase + Open-layer abstracts. Runs §7.0 Open IDs.
2. `UniswapV4Detf_<Fixture>_Policy.t.sol` in the same directory. Inherits that fixture’s TestBase + `TestBase_UniswapV4Detf_Policy` helpers + Policy-layer abstracts. Deploys one extra Policy instance with §5.1 Policy constants. Runs §7.0 Policy IDs.

`<Fixture>` Solidity stem matches the existing money-path contract without the `.t.sol` suffix, e.g. `UniswapV4Detf_Cp_Univ3Se_ProductLaw.t.sol`. H-CP-P2 stems: `UniswapV4Detf_PonsV2Se_ProductLaw.t.sol` and `UniswapV4Detf_PonsV2Se_Policy.t.sol`.

Do not skip mixed rows. Do not skip Morpho or pons.

Anti-theater on every Uni V3/V4 SE bound on that fixture: `allowance(hook, se)==0` before burn, close, and I1 mint that pulls shares.

### 5.3 Skew after live (Policy)

Use **donate** of `mintToken` (R12a) to move synthetic. If donate cannot cross the 1.05/0.95 band on that hook, then `vm.prank(detf)` + hook `ownerSwapExactIn` (D30 production path). Never `depositSingle` as a fake launch before first bond. Never change `mintThreshold` to fake Policy.

### 5.4 Copy, do not subclass, family tests

Gold copy sources (logic only):

| Capability | Copy from |
|------------|-----------|
| D25 | `…/standardExchange/**/UniswapV4*DETF_Alignment_CloseD25.t.sol` |
| D15 | `…/constantProduct/single/UniswapV4SingleStandardExchangeDETF_Alignment_RedeemD15.t.sol` (D15-1..4, D15-6..9; D15-5 N/A there). n-leg leftover dump from Quad/Orbital family D15-5 if present; else implement D15-5 from Alignment plan row “multi-leg: snapshot DETF-buying power once; largest first” |
| D31 | CP `…_Alignment_D31_ExpansionGate.t.sol` (D31-1..4). Port **all four** to unified, all four gold hooks, then Stage 11 Policy |
| D28 | `…_Alignment_FeeCreatorClaim.t.sol` FC1–FC12. Rewrite FC4 (`buyClaim` → later `bond`). Rewrite FC8 sell onto Bond NFT |
| Donation | `…_ReserveDonation.t.sol` rewritten for R12a. Family `test_N*` map to `test_DN*` below. Skip family `test_N15_n10_userConvertUnchanged` (DN15 N/A). Port `test_N21` / `test_N22` as DN21 / DN22 |
| Policy / expansion / compound | CP `PriceMovement.t.sol`, `Expansion.t.sol`; Orbital `PolicyNotZap.t.sol` |
| Opening | `…_OpeningPrice.t.sol` T1/T2/T5 (and Weighted/Quad T6 length) |
| Nested SE | `…_NestedPush.t.sol` T-NEST-1..3 and `test_T_LOCAL_I1_*` only |
| Adversarial | family `adversarial/Adversarial_{A0Crops,Surface,TrustFlag*}.t.sol` |
| Later bond / claim / owner-only | family `Bond.t.sol`, `Claim.t.sol`, `OwnerOnlyLiquidity.t.sol` |

Rewrite callers to `IUniswapV4Detf` / R12a `IDETFNFTVault` / `IRebasingClaimToken`. Inherit `TestBase_UniswapV4Detf*` (or the Stage 11 fixture TestBase). Never family DETF TestBases.

**File shape (LOCKED):**

- One **gold** abstract per suite under `test/…/detf/`, named `UniswapV4Detf_<Suite>Base.sol`, **no `setUp` deploy**.
- One **Open-layer** abstract (or set of abstracts) that contains **only** §7.0 Open IDs, named `UniswapV4Detf_<Suite>OpenBase.sol` when that suite splits.
- One **Policy-layer** abstract set that contains **only** §7.0 Policy IDs, named `UniswapV4Detf_<Suite>PolicyBase.sol` when that suite splits.
- Four gold concretes per gold suite (`UniswapV4Detf_<Suite>.t.sol` plus Orbital/Weighted/Quad).
- Stage 11: the two siblings in §5.2. They inherit layer abstracts, not gold-full abstracts (R-24).
- Do not copy-paste assert bodies between gold and layer abstracts: put shared bodies on an internal helper library or on the gold abstract as `internal` functions that both gold tests and layer tests call. Do not leave empty `test_*` stubs on Stage 11.
- Do not put abstracts under `contracts/` unless they need deploy helpers. Those stay `TestBase_UniswapV4Detf_Policy.sol` and `TestBase_UniswapV4Detf_Adversarial.sol` next to the package.

---

## 6. New ABI vs family ABI (LOCKED)

Do **not** add family DETF functions onto `IUniswapV4Detf`.

| Behavior (law) | Family diamond (do not port names) | Unified call (LOCKED) |
|----------------|------------------------------------|------------------------|
| D10 sell NFT → rebasing claim | `detf.sellPositionToDetfNft` | `IDETFNFTVault(detf.bondNftVault()).sellPositionToDetfNft(tokenId, seller, rewardsRecipient)` |
| D15 redeem claim → DETF only | `detf.redeemClaim` | `IRebasingClaimToken(detf.rebasingClaimToken()).redeem(amount, recipient, pretransferred)`. Assert payout token is DETF. Pair/share/SE out reverts |
| D17/D28 `claimRewards` ids 1–2 | `detf.claimRewards` | Bond NFT `claimRewards(tokenId, recipient)` |
| D18 free DETF → claim (`buyClaim`) | `detf.buyClaim` / `depositClaim` | **Not tested** (R-9). `mintFromNFTSale` is `onlyOwner`. D10 sell still mints claim |
| D22 claim ungated | `redeemClaim` ignores Policy | Claim-token `redeem` succeeds in Policy deadband |
| Live mint/burn | often `exchangeIn` | `IUniswapV4Detf.mint` / `burn` (and existing `exchangeIn` mint/burn only) |
| FC4 new shares | family `buyClaim` | Later `bond` of `mintToken` after the first pot is pending (R-16) |

### 6.1 Critical flaw (LOCKED)

Do not change hooks or `IUniswapV4Detf` to match family names.

If a mandatory §7 assert fails because unified DETF, R12a NFT, claim token, or an in-scope hook is wrong:

1. Leave the test **red**.
2. **Stop the WP.** Do not patch production CODE.
3. Report: §7 ID, matcher, selector, and a short trace.
4. Wait for an explicit go-ahead before any CODE.

Do not convert leftover-pretransfer spend (L-GAPS-11). Do not add Dual bind. Do not add `buyClaim` to the DETF. Do not add an inbound refund to satisfy E6.

---

## 7. Exact test catalog

Every test name below is mandatory on the layers marked in §7.0. Prefix with `test_` as written.

### 7.0 ID × layer matrix (LOCKED)

| Layer | Fixtures | IDs |
|-------|----------|-----|
| **Gold CP** | `TestBase_UniswapV4Detf` | Full §7.1–§7.8 for CP, including gold-only T7 holes, L2 FoT, J1–J3, F1, K1, reentrancy, D15-1..4+6..9 (D15-5 N/A NatSpec), DN1–DN14+DN16–DN22 (DN3/DN15 N/A NatSpec), T7.11 execute, owner-only, Policy/opening/compound/D31/FC |
| **Gold Orbital / Weighted / Quad** | matching gold TestBase | Same as Gold CP except: no T7.15 FoT; no T7.11 (Quad has T8.3 execute instead); T6 on Weighted and Quad; T8.4 on Weighted Policy; D15-5 required |
| **Stage 11 Open** | 26 ProductLaw siblings | T7.2, T7.10, T7.14, T7.19; owner-only two asserts; I1/I2/I3 mint + later bond + donate; A0; CROPS; K1; T-NEST-1..3 + T-LOCAL-I1; D25-1..7; sell/claimRewards/D15 subset (`test_D15_redeem_paysDetf_only`, `test_D15_8_nonDetfPayoutForbidden`, `test_D15_1_previewEqualsExecute`); DN1, DN2, DN4–DN14, DN16–DN22; `test_compound_raises_protocolLp` |
| **Stage 11 Policy** | 26 Policy siblings | T7.8; `test_policy_mint_blocked_in_deadband_then_allowed_after_push`; `test_policy_burn_allowed_when_synthetic_below_burnThreshold`; D31-1..3; D22 / D15-9; FC1–FC12; T1, T2, T5; T6 on Weighted and Quad fixtures only; T8.4 on Weighted fixtures only; D15 subset (`test_D15_redeem_paysDetf_only`, `test_D15_8_nonDetfPayoutForbidden`, `test_D15_1_previewEqualsExecute`) |
| **Not on Stage 11** | | T7.1, T7.3, T7.4, T7.7, T7.11, T7.15, T7.16, T7.17, T7.18, T7.21, J1–J3, L2 FoT, reentrancy, F1, E6, D15-2/3/4/5/6/7, custom close execute, D18, T-NEST-4..8 |

`test_open_never_expands` runs on gold Open (all four hooks) and Stage 11 Open. `test_D31_4_openMintDoesNotExpand` runs on gold Open (all four hooks) only.

H8 on Weighted: mint allowed on pair A and not B must be **Policy synthetics plus a live mint attempt** on the Policy instance (R-13). Keep existing T8.4; add `test_T8_4_policy_pairA_not_pairB_via_trades` on Weighted gold Policy and every Weighted Stage 11 Policy sibling.

### 7.1 Stage 07 holes

CP gold file: `UniswapV4Detf_IoTables.t.sol` inherits `UniswapV4Detf_IoTablesGoldBase` + `UniswapV4Detf_IoTablesOpenBase`.

T7.2 and T7.10 also run on Orbital/Weighted/Quad gold (Open base) and on every Stage 11 Open sibling.

T7.11 Custom close **execute** is CP gold in `UniswapV4Detf_IoTables.t.sol`. Quad gold T8.3 execute is `UniswapV4Detf_Quad.t.sol` (edit existing `test_T8_3_customClose_onePair` to call `closeBondMature`). WP-UDPL-IO owns CP T7.11. WP-UDPL-QD owns Quad T8.3 execute. Do not leave either as table-only. Orbital/Weighted: do not add execute.

| ID | Must execute | Layer |
|----|--------------|-------|
| `test_T7_1_bareStandardExchange_reverts` | `standardExchangeOf` zero on a non-DETF `tokens()` entry → deploy revert | Gold CP |
| `test_T7_2_defaultTables_pairAndShare_noUnderlyings` | Default mint/burn/bond rows = each hook pair + that SE’s share. No SE `vaultTokens()` extra underlyings | Gold all four + Stage 11 Open |
| `test_T7_3_customMint_seUnderlying_allowed` | Custom mint token in the bound SE’s `tokens()` but not in `hook.tokens()`; vault is that hook SE. Default instance still omits it | Gold CP |
| `test_T7_4_customVault_notHookSe_reverts` | Custom vault not in hook SE set → deploy revert | Gold CP |
| `test_T7_7_liveMint_share_pairEqFromPreviewExchangeOut` | After first bond, mint the **SE share**. `pairEq` from `previewExchangeOut`; Gross still `previewSwapExactIn(pair, detf, pairEq*(1+p))` | Gold CP |
| `test_T7_10_laterBond_joinUnbalanced_unboostedG` | After live, one later `bond` of `mintToken`; one `joinUnbalanced`; G unboosted mix (D24) | Gold all four + Stage 11 Open |
| `test_T7_11_customClose_leftoverOwnerSwap` | Custom close length 1; **call** `closeBondMature`; leftovers `ownerSwapExactIn` in `tokens()` order; user receives the close-route pair; DETF slot 0 | Gold CP only |
| `test_T7_14_commonNftUnused_claimHoldsNoHookLp` | After mint, diamond and claim token `balanceOf(hook LP)==0`. Bond NFT is R12a package | Gold all four + Stage 11 Open |
| `test_T7_15_L2_FoT_forbidden` | **N/A NatSpec.** FoT forbidden as a product claim (UI/docs). No consistent on-chain FoT detector; no deploy-time check; no deploy-revert assert. Never a FoT-success money path | Gold CP only (NatSpec) |
| `test_T7_16_exactOut_absent` | Unified ABI has no exact-out mint/burn. Loupe: those selectors are **not** on the proxy (J) | Gold CP (J covers other hooks) |
| `test_T7_17_joinUnbalanced_pairAndShareSameLeg_reverts` | Pair + share of the same SE in one `joinUnbalanced` reverts | Gold CP |
| `test_T7_18_noFamilyGetters` | `reservePool()==hook`. `pairToken()` / `rateAsset()` / `underlyingVault()` are **unknown selector** on the proxy | Gold CP (J covers other hooks) |
| `test_T7_21_failedDustJoin_doesNotRevertMint` | Seed a non-joinable leftover; mint still succeeds; public `sweepDust` later no-ops or clears joinable dust | Gold CP |

Keep existing T7.1 Dual/custom-close-length, T7.5, T7.6, T7.9, T7.12, T7.13, T7.19, T7.20. Do not delete them. `test_T7_19_afterMint_diamondHasNoJoinableBalances` is also Stage 11 Open (dust assert).

### 7.2 Policy, expansion, compound, opening (all four gold hooks, then Stage 11 Policy)

Abstracts under `test/…/detf/`:

- `UniswapV4Detf_PolicyBase.sol` (gold-full Policy IDs)
- `UniswapV4Detf_PolicyLayerBase.sol` (Stage 11 Policy IDs only)
- `UniswapV4Detf_OpeningPriceBase.sol` / `UniswapV4Detf_OpeningPriceLayerBase.sol`

Gold concretes:

- `UniswapV4Detf_Policy.t.sol` (CP)
- `UniswapV4Detf_Orbital_Policy.t.sol`
- `UniswapV4Detf_Weighted_Policy.t.sol`
- `UniswapV4Detf_Quad_Policy.t.sol`
- `UniswapV4Detf_OpeningPrice.t.sol` and `UniswapV4Detf_{Orbital,Weighted,Quad}_OpeningPrice.t.sol` (T6 length on Weighted and Quad)

| ID | Must prove | Layer |
|----|------------|-------|
| `test_T7_8_policy_isMintingAllowed_token` | Policy instance. `isMintingAllowed(token)` per H8. No-arg true iff some `mintRoutes` token passes | Gold all four + Stage 11 Policy |
| `test_policy_mint_blocked_in_deadband_then_allowed_after_push` | First bond launch-rich so mint can pass; skew into deadband → `MintingNotAllowed`; donate/push until mint allowed | Gold all four + Stage 11 Policy |
| `test_policy_burn_allowed_when_synthetic_below_burnThreshold` | After skew below 0.95, burn succeeds | Gold all four + Stage 11 Policy |
| `test_open_never_expands` | Open mode: warp epochs; `pendingExpansionDetf()==0`; mint does not mint expansion | Gold all four Open + Stage 11 Open |
| `test_D31_1_policyMint_realizesThenGates` | Policy mint realizes expansion first; if post-realize synthetic fails mint gate, **whole tx reverts** and expansion does not stick | Gold all four + Stage 11 Policy |
| `test_D31_2_realizeWouldCloseMint_revertsUnchanged` | Pending that would pull below mint threshold → revert, state unchanged | Gold all four + Stage 11 Policy |
| `test_D31_3_policyBurn_realizesThenGates` | Same realize-then-gate on burn | Gold all four + Stage 11 Policy |
| `test_D31_4_openMintDoesNotExpand` | Open mint does not expand | Gold all four Open only. Stage 11 Open runs `test_open_never_expands`. Stage 11 Policy does not run D31-4 |
| `test_compound_raises_protocolLp` | After live mint, public `compoundProtocolRewards` does not revert. `lpOut==0` is OK when lazy compound already consumed protocol pending. If `lpOut>0`, Bond NFT hook-LP rises | Gold all four + Stage 11 Open. Not Stage 11 Policy |
| `test_donate_doesNotRealizeExpansion` | Same as DN12 | Gold donation suite; Stage 11 Open via DN12 |
| `test_T1_openingZero_storesAsCreation_firstBondGAtPeg` | Opening 0 → stored opening = creation; first-bond G at peg | Gold all four + Stage 11 Policy |
| `test_T2_openingUsesG_creationViewUnchanged` | Opening `1.1e18`; first-bond G uses opening; `creationPairPerDetfWad` unchanged | Gold all four + Stage 11 Policy |
| `test_T5_creationZero_revertsInvalidCreationRate` | Deploy revert | Gold all four + Stage 11 Policy |
| `test_T6_openingLengthMismatch_reverts` | Weighted and Quad only | Gold Weighted/Quad + those Stage 11 Policy siblings |

### 7.3 Claim, sell, D15, D17, D28

Call **Bond NFT** and **claim token**. Do not call missing DETF selectors.

Gold files (abstract + four concretes):

- `UniswapV4Detf_Claim.t.sol` and `UniswapV4Detf_{Orbital,Weighted,Quad}_Claim.t.sol`
- `UniswapV4Detf_Alignment_RedeemD15.t.sol` and n-leg copies
- `UniswapV4Detf_Alignment_FeeCreatorClaim.t.sol` and n-leg copies

| ID | Must prove | Layer |
|----|------------|-------|
| `test_preMaturity_sell_reverts` | Bond NFT sell before lock ends reverts | Gold all four + Stage 11 Open |
| `test_postMaturity_sell_mintsRebasingClaim` | Mature NFT `sellPositionToDetfNft` mints claim; user originalShares → id 0; no LP withdraw | Gold all four + Stage 11 Open |
| `test_claimRewards_whileLocked` | NFT `claimRewards` pays pending DETF while locked | Gold all four + Stage 11 Open |
| `test_D15_1_previewEqualsExecute` | `IRebasingClaimToken.previewRedeem(amount) == redeem(...)` (R-22) | Gold all four + Stage 11 Open + Stage 11 Policy |
| `test_D15_2_smallRedeemConsumesPending` | Small redeem consumes pending DETF first | Gold all four |
| `test_D15_3_pendingCoversOwed_skipsLpWithdraw` | When pending covers the owed DETF, no protocol LP withdraw | Gold all four |
| `test_D15_4_shortfallResidualBuy_otherBondersUnchanged` | Shortfall: proportional withdraw, buy DETF on residual, other bonders’ originalShares unchanged | Gold all four |
| `test_D15_5_multiLegLeftoverDump` | Multi-leg: snapshot DETF-buying power once; dump largest leftover first (Alignment D15-5) | Gold Orbital/Weighted/Quad only. CP gold NatSpec `D15-5 N/A single leftover pair` |
| `test_D15_6_lastExitRejoinsLeftover` | Last claim exit rejoins leftover to id 0 | Gold all four |
| `test_D15_7_realizeExpansionFirst_paysFromId0Slice` | Realize-then-pay from id 0 slice (needs POLICY green, R-8) | Gold all four |
| `test_D15_8_nonDetfPayoutForbidden` | Redeem increases recipient **DETF** only. Pair, SE share, and hook LP of the recipient do not increase. No `tokenOut` argument on the new ABI | Gold all four + Stage 11 Open + Stage 11 Policy |
| `test_D15_redeem_paysDetf_only` | Same payout-token assert as D15-8, kept as its own function (Stage 11 listed this name) | Gold all four + Stage 11 Open + Stage 11 Policy |
| `test_D15_pendingFirst_thenZapOutToDetf` | Redeem pays pending DETF first; remaining value from protocol id 0 LP unwind **to DETF**. If unwind pays pair, §6.1 | Gold all four |
| `test_D15_9_ungatedVsPolicy` | Alias body of D22 on gold Policy | Gold all four Policy |
| `test_D17_ids1and2_cannotSellOrClose` | FC8 via NFT sell and DETF `closeBondMature` | Gold all four + Stage 11 Policy (covered by FC8; do not skip FC8) |
| `test_D22_claimUngated` | Policy deadband does not block claim-token `redeem` | Gold all four Policy + Stage 11 Policy. Not Open |
| `test_FC1_univ4Detf_<hook>_feeToAndCreatorCanClaim` | Alignment §20.1 FC1. NFT `claimRewards`. Both id 1 and id 2 `claimed > 0` and equal pending | Gold all four + Stage 11 Policy (`<hook>` or `<FixtureId>` per R-16) |
| `test_FC2_univ4Detf_<hook>_claimEqualsPendingAndBalance` | claim == pending and balance delta | same |
| `test_FC3_univ4Detf_<hook>_dueAmountsFloor` | id 1 / id 2 pending within 1 wei of `acc * F / T` and `acc * C / T` | same |
| `test_FC4_univ4Detf_<hook>_newSharesDoNotClaimOldPot` | After pot pending, a later **`bond`** (not `buyClaim`) does not let new shares claim the old pot beyond 1e13 wei | same |
| `test_FC5_univ4Detf_<hook>_newPotAtNewWeights` | New pot slice at current weights | same |
| `test_FC6_univ4Detf_<hook>_secondClaimZero` | Second `claimRewards` on id 1 is 0 | same |
| `test_FC7_univ4Detf_<hook>_nonOwnerCannotClaim` | Non-owner `claimRewards` on id 1 reverts | same |
| `test_FC8_univ4Detf_<hook>_ids1and2CannotSellOrClose` | `closeBondMature` on ids 1–2 reverts. Bond NFT `sellPositionToDetfNft` on ids 1–2 reverts | same |
| `test_FC9_univ4Detf_<hook>_d2NoOriginalShares` | ids 1–2 `originalShares == 0`, `effectiveShares > 0` | same |
| `test_FC10_univ4Detf_<hook>_feeToChangeDoesNotMoveId1` | `setFeeTo` does not move id 1 owner; original still claims; new feeTo cannot | same |
| `test_FC11_univ4Detf_<hook>_creatorZeroFeeToOwnsBoth` | Second instance `creator = 0`: `feeTo` owns ids 1 and 2; both claims succeed | same |
| `test_FC12_univ4Detf_<hook>_conservationTwoWaves` | Two mint waves: claimed DETF conservation vs supply | same |

Do not add `test_D18_buyClaim_*`. Do not revive family redeem-to-pair. Do not `expectRevert` unknown selector on the DETF for `buyClaim` as the only proof.

### 7.4 D25 close alignment (all four gold hooks + Stage 11 Open)

Files: `UniswapV4Detf_Alignment_CloseD25.t.sol` plus `UniswapV4Detf_{Orbital,Weighted,Quad}_Alignment_CloseD25.t.sol`. Stage 11 Open inherits `UniswapV4Detf_Alignment_CloseD25OpenBase.sol`.

| ID | Must prove | Layer |
|----|------------|-------|
| `test_D25_1_userDetfOnlyFromClaimRewards` | Close pays user DETF only via `claimRewards` on that id, not withdrawn self-leg | Gold all four + Stage 11 Open |
| `test_D25_2_withdrawnDetfNotBurned` | Withdrawn DETF rejoined; supply of that DETF not burned for the self-leg | same |
| `test_D25_3_id0OriginalSharesRise` | Id 0 originalShares increase | same |
| `test_D25_4_userReceivesNonDetfBasket` | Default: every non-DETF `hook.tokens()` slot can be paid (some may be 0 dust). DETF slot 0 | same |
| `test_D25_5_ids1and2CannotClose` | Revert | same |
| `test_D25_6_previewEqualsExecute` | `previewCloseBondMature` = exec | same |
| `test_D25_7_minRejoinLpOutGt0` | DETF rejoin at MIN liquidity still `lpOut>0` or revert (D30) | same |
| `test_D25_lastClose_feeCreatorPendingDoesNotJump` | Last user close does not jump ids 1–2 pending unfairly | same |

Existing `UniswapV4Detf_Close.t.sol` T7.12 stays as Default basket smoke. It does **not** replace D25-1..7.

### 7.5 Donation (all four gold hooks + Stage 11 Open DN set)

Files: `UniswapV4Detf_ReserveDonation.t.sol` and `UniswapV4Detf_{Orbital,Weighted,Quad}_ReserveDonation.t.sol`. Stage 11 Open inherits `UniswapV4Detf_ReserveDonationOpenBase.sol`.

R12a wins over donation PRD DN1/DN6/DN11 “convertToAssets unchanged / id 0 originalShares mint while O>0”.

| ID | Unified assert | Layer |
|----|----------------|-------|
| `test_DN1_donate_pair_Ogt0_unassignedLp` | O>0: no originalShares mint; user `convertToAssets` **rises**; DETF supply unchanged; T7.13 remains the pathfinder | Gold all four + Stage 11 Open |
| `test_DN2_donate_vaultShare` | Same booking for SE share | same |
| `test_DN3_donate_lpToken_thisCallInboundOnly` | **N/A on Uni V4.** Hook LP is owner-only (D9). Do not steal NFT LP. Do not `prank(detf)` to mint LP to an EOA for this test. NatSpec: `DN3 N/A Uni V4 owner-only LP` | NatSpec only, all donation suites |
| `test_DN4_donate_detf_selfLeg_noMint` | No DETF print; self-leg join | Gold all four + Stage 11 Open |
| `test_DN5_inert_reverts` | Inert donate reverts | same |
| `test_DN6_twoBonders_navRisesTogether` | R12a: both user `convertToAssets` rise; originalShares unchanged; ids 1–2 still 0 originalShares | same |
| `test_DN7_detf_donate_forwardsToNft` | `IUniswapV4Detf.donate` is required. Pull lands on the NFT. Event donor is the EOA (or FeeCollector when that is `msg.sender`), not the diamond | same |
| `test_DN8_joinDonatedCapital_eoaReverts` | EOA `joinDonatedCapital` reverts | same |
| `test_DN9_pretransferred_noSurplus_reverts` | I1 | same |
| `test_DN10_previewEqualsExecute` | preview donate = exec | same |
| `test_DN11_ownerOnlyLiquidity_donateStillWorks` | Third party hook add reverts; donate succeeds | same |
| `test_DN12_donate_doesNotRealizeExpansion` | lastExpansionTimestamp / pendingExpansionDetf unchanged | same |
| `test_DN13_burn_afterDonate_usesDonatedLp` | Burn formula includes donated LP | same |
| `test_DN14_closeAfterDonate_userBasketUnchanged` | After donate, mature close of a **pre-donate** bond: user non-DETF out matches the pre-donate snapshot (same bond); withdrawn DETF rejoined to id 0 | same |
| `test_DN15_n10_userConvertUnchanged` | **N/A.** R12a supersedes family N10 stasis. NatSpec: `DN15 N/A R12a convertToAssets rises (see DN1)` | NatSpec only |
| `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture` | After last user close, donate, next bond does not capture donated LP via empty-share originalShares = G | Gold all four + Stage 11 Open |
| `test_DN17_d2_ids12_effectiveShares` | After donate, ids 1 and 2 effectiveShares still `f` and `c` of the new total | same |
| `test_DN18_disabled_donateReverts_closeWorks` | CROPS via `IVaultRegistryDisableManager(indexedexManager).setVaultAddressDisabled(detf, true)`. Inbound mint/bond/donate revert. Mature close, claim `redeem`, and burn still succeed. Unified uses `_requireNotDisabled` on inbound; do not add a DETF-local disable setter | same |
| `test_DN19_permit2_allowance` | Donation N15 allowance path | same |
| `test_DN20_permit2_signature` | Donation N15 signature path | same |
| `test_DN21_d2_afterDonate` | Family `test_N21_d2_afterDonate`: D2 identity after donate (effectiveShares / no originalShares on ids 1–2). Keep as a distinct function from DN17 | same |
| `test_DN22_donate_whilePoolManagerUnlocked` | Family `test_N22_donate_whilePoolManagerUnlocked`: donate succeeds while PoolManager is unlocked (D30 host path still owner-only for LP) | same |

### 7.6 Adversarial (unified proxy)

Directory: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/`

Harness: `TestBase_UniswapV4Detf_Adversarial.sol` on CP gold. Orbital/Weighted/Quad gold adversarial concretes inherit the same abstract tests. Stage 11 Open siblings inherit Open-layer I1/I2/I3 + A0 + CROPS + K1 + nested-SE IDs from `UniswapV4Detf_AdversarialOpenBase.sol`. J1–J3 run **once per hook gold** (same DETF facet cuts). Not a second J suite per SE.

E6: **N/A** (R-10). NatSpec on `Adversarial_A0Crops.t.sol`: `E6 N/A no residual-return`. Do not add a refund.

| File | IDs | Layer |
|------|-----|-------|
| `Adversarial_A0Crops.t.sol` | `test_A0_donateBeforeFirstBond_cannotFreeMint`; CROPS disable: inbound gated, mature close / redeem / burn still work; `test_F1_satellitesUnowned` (after `postDeploy`, Bond NFT and claim token have no leftover owner/minter an attacker can use) | Gold all four. Stage 11 Open: A0 + CROPS only (not F1) |
| `Adversarial_TrustFlags.t.sol` | I1/I2/I3 on `mint`, later `bond`, `donate`. `test_K1_donationNotMintCredit` (donation inventory cannot be consumed as another user’s mint credit). Happy-path pretransfer is **not** I1 | Gold all four + Stage 11 Open |
| `Adversarial_Surface.t.sol` | J1–J3: Target/interface ⊆ `facetFuncs` ⊆ cuts ⊆ loupe; smoke every product selector on the **proxy** | Gold all four only |
| `Adversarial_Reentrancy.t.sol` | `IsLocked` on mint, required. Port burn/bond reentrancy only if the family Uni V4 CP `Adversarial_Reentrancy.t.sol` already has those tests with a production-path hostile share. If that family file tests mint only, unified tests mint only and NatSpecs `reentrancy burn/bond N/A family had mint only`. Do not invent a new hostile token | Gold all four only |
| `Adversarial_NestedSe.t.sol` | `test_T_NEST_1_nestedHappy_pushTrue_hostReservesSync`; `test_T_NEST_2_nestedShort_hostRevertsTransferDeltaInsufficient`; `test_T_NEST_3_nestedI1_bookedHost_trueWithoutPushReverts`; `test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts`. NatSpec defer T-NEST-4..8 | Gold all four + Stage 11 Open (against that fixture’s bound SE, not a second ERC-4626) |

Defer in suite NatSpec (do not silently omit): M* if no calldata forwarder; Morpho-illiquid close; nested DETF G1; T-NEST-4..8; E6; D18.

### 7.7 Owner-only liquidity

Four gold files: `UniswapV4Detf_OwnerOnlyLiquidity.t.sol` (CP gold) and `UniswapV4Detf_{Orbital,Weighted,Quad}_OwnerOnlyLiquidity.t.sol`. Each: `hook.owner()==detf`; third-party `joinSingleAssetExactIn` / add reverts. Same two asserts on every Stage 11 Open sibling (`UniswapV4Detf_OwnerOnlyLiquidityOpenBase.sol`).

IO owns CP gold. OR / WE / QD own that hook’s gold. SE WPs attach the Open base.

### 7.8 H-CP-P2 launch token

In `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/UniswapV4Detf_PonsV2Se.t.sol` and `contracts/test/bases/TestBase_UniswapV4Detf_PonsV2Se.sol` only (R-5):

- Hook pair = **pons v2 launch token**, not WETH (§8.2 of the matrix PRD).
- `mintToken` after `hook.tokens()` is that launch token.
- Keep T10.8–T10.10 and H-CP-P2 firstBond/mint/burn/close green under that token (retarget any WETH pair asserts).
- ProductLaw / Policy siblings for this fixture live under `pons/`, not `prod-se/`.

Orbital/Weighted/Quad P2 TestBases already bind launch token; do not change them except if a shared helper in the pons CP TestBase is the one they call.

WP-UDPL-SE-CP owns this fix.

---

## 8. Files to create (LOCKED)

Do not put TestBases under `test/` if the gold unified TestBase lives under `contracts/…/detf/`.

### 8.1 New TestBases (`contracts/…/detf/`)

| Path | WP |
|------|----|
| `…/detf/TestBase_UniswapV4Detf_Adversarial.sol` | ADV |
| `…/detf/TestBase_UniswapV4Detf_Policy.sol` | POLICY. Virtual `_policyArgs()` used by gold and Stage 11 Policy siblings |

Do not create `TestBase_UniswapV4Detf_Cp_PonsV2Se.sol`.

### 8.2 Gold abstracts and concretes (`test/…/detf/`)

| Path | WP |
|------|----|
| `UniswapV4Detf_IoTablesGoldBase.sol` | IO |
| `UniswapV4Detf_IoTablesOpenBase.sol` | IO |
| `UniswapV4Detf_IoTables.t.sol` | IO |
| `UniswapV4Detf_OwnerOnlyLiquidityBase.sol` / `…OpenBase.sol` | IO (CP concrete) then OR / WE / QD concretes |
| `UniswapV4Detf_PolicyBase.sol` / `UniswapV4Detf_PolicyLayerBase.sol` | POLICY |
| `UniswapV4Detf_Policy.t.sol` | POLICY |
| `UniswapV4Detf_OpeningPriceBase.sol` / `UniswapV4Detf_OpeningPriceLayerBase.sol` | POLICY |
| `UniswapV4Detf_OpeningPrice.t.sol` | POLICY |
| `UniswapV4Detf_ClaimBase.sol` / `UniswapV4Detf_ClaimOpenBase.sol` | CLAIM |
| `UniswapV4Detf_Claim.t.sol` | CLAIM |
| `UniswapV4Detf_Alignment_RedeemD15Base.sol` / `…OpenBase.sol` / `…PolicyBase.sol` | CLAIM |
| `UniswapV4Detf_Alignment_RedeemD15.t.sol` | CLAIM |
| `UniswapV4Detf_Alignment_FeeCreatorClaimBase.sol` / `…PolicyBase.sol` | CLAIM |
| `UniswapV4Detf_Alignment_FeeCreatorClaim.t.sol` | CLAIM |
| `UniswapV4Detf_Alignment_CloseD25Base.sol` / `…OpenBase.sol` | D25 |
| `UniswapV4Detf_Alignment_CloseD25.t.sol` | D25 |
| `UniswapV4Detf_ReserveDonationBase.sol` / `…OpenBase.sol` | DONATE |
| `UniswapV4Detf_ReserveDonation.t.sol` | DONATE |
| `adversarial/*.t.sol` + `UniswapV4Detf_AdversarialOpenBase.sol` | ADV |

n-leg gold concretes (same stems with `_Orbital_` / `_Weighted_` / `_Quad_`): OR / WE / QD.

### 8.3 Stage 11 siblings

For each of the 25 `prod-se/*.t.sol` money-path contracts, add `*_ProductLaw.t.sol` and `*_Policy.t.sol` next to it.

For H-CP-P2, add `pons/UniswapV4Detf_PonsV2Se_ProductLaw.t.sol` and `pons/UniswapV4Detf_PonsV2Se_Policy.t.sol`.

WP-UDPL-SE-CP / SE-OR / SE-WE / SE-QD own those siblings for their fixtures. They do not invent a third sibling.

### 8.4 Edit in place

| File | What | WP |
|------|------|----|
| `UniswapV4Detf_Quad.t.sol` `test_T8_3_customClose_onePair` | Call `closeBondMature`; leftover `ownerSwapExactIn`; user receives close-route pair; DETF slot 0 | QD |
| `contracts/test/bases/TestBase_UniswapV4Detf_PonsV2Se.sol` + `pons/UniswapV4Detf_PonsV2Se.t.sol` | Launch token pair / `mintToken`; keep T10.8–T10.10 and H-CP-P2 four paths | SE-CP |
| Weighted Policy gold + Weighted Stage 11 Policy siblings | `test_T8_4_policy_pairA_not_pairB_via_trades` | WE (gold) then SE-WE |

Keep existing T7.1 Dual/custom-close-length, T7.5, T7.6, T7.9, T7.12, T7.13, T7.19, T7.20 files.

---

## 9. Work packages (LOCKED packing)

Max **3** concurrent implementers. CP pathfinder before n-leg copies. Do not split a WP across two agents.

| WP | Worktree | Scope | Depends on |
|----|----------|-------|------------|
| **WP-UDPL-IO** | `unified_detf_pl_io` | §7.1 CP gold T7 holes including T7.11 execute + CP owner-only. Ships IoTables gold+Open abstracts **and** CP concretes. No Stage 11 siblings | none |
| **WP-UDPL-POLICY** | `unified_detf_pl_policy` | §7.2 CP gold Policy/D31/compound/opening + `TestBase_UniswapV4Detf_Policy.sol` | none |
| **WP-UDPL-DONATE** | `unified_detf_pl_donate` | §7.5 CP gold donation R12a (DN3/DN15 N/A NatSpec; DN21/DN22 included) | none |
| **WP-UDPL-CLAIM** | `unified_detf_pl_claim` | §7.3 CP gold claim/D15/D28 via NFT + claim token | **POLICY green** (R-8) |
| **WP-UDPL-D25** | `unified_detf_pl_d25` | §7.4 CP gold D25-1..7 | POLICY (realize on close) |
| **WP-UDPL-ADV** | `unified_detf_pl_adv` | §7.6 CP gold adversarial + J once + F1 + K1 + nested four IDs | IO |
| **WP-UDPL-OR** | `unified_detf_pl_or` | Orbital **gold** full gold §7 (concretes only) | POLICY + D25 + CLAIM + DONATE + ADV CP green |
| **WP-UDPL-WE** | `unified_detf_pl_we` | Weighted **gold** full gold §7 + T8.4 + T6 | same |
| **WP-UDPL-QD** | `unified_detf_pl_qd` | Quad **gold** full gold §7 + T8.3 execute + D15-5 | same |
| **WP-UDPL-SE-CP** | `unified_detf_pl_se_cp` | ProductLaw + Policy siblings for H-CP-GV3/GV4/P1/MB + pons H-CP-P2. H-CP-P2 launch-token fix | OR/WE/QD gold green (abstracts stable) |
| **WP-UDPL-SE-OR** | `unified_detf_pl_se_or` | Same siblings on H-OR-* + M-OR-* | same |
| **WP-UDPL-SE-WE** | `unified_detf_pl_se_we` | Same siblings on H-WE-* + M-WE-* | same |
| **WP-UDPL-SE-QD** | `unified_detf_pl_se_qd` | Same siblings on H-QD-* + M-QD-* | same |
| **WP-UDPL-DEPRECATE** | `unified_detf_pl_deprec` | §11 | **all** test WPs green |

First wave: IO + POLICY + DONATE. Second: CLAIM + D25 + ADV. Third: OR + WE + QD gold. Fourth: SE-CP + SE-OR + SE-WE (SE-QD after or in a following trio). Last: DEPRECATE.

Do not edit Dual Common, Balancer DETFs, or `frontend/**`. `fee_detf` Script_13 may rewrite exported addresses/ABI names to `IUniswapV4Detf` only.

---

## 10. Acceptance matchers

```bash
# This PRD (add files as WPs land)
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_IoTables.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Policy.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OpeningPrice.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Claim.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_*.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonation.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/**'

# n-leg gold
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Orbital*.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Weighted*.t.sol'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Quad*.t.sol'

# Stage 11 money paths plus this PRD product-law siblings
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/**'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/**'
forge test --offline -vv --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_*.t.sol'
```

`--match-test test_C` / `test_A0` under a wide path will pull extras. Prefer `--match-contract` per WP file.

A WP is **DONE** only when its matcher is green **and** these three regression matchers still pass (R-19):

1. `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/**`
2. `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/**`
3. `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_*.t.sol`

This PRD is **closed** when every WP including **WP-UDPL-DEPRECATE** is done.

---

## 11. Deprecation gate (WP-UDPL-DEPRECATE)

Do not start this WP until §10 this-PRD matchers and Stage 11 regression are green.

### 11.1 Launch scripts and instances (in)

Replace family DETF **package and instance** deploys with `UniswapV4DetfDFPkg` + `IUniswapV4Detf.PkgArgs` (hook address, route tables). Same pattern as `scripts/foundry/anvil_robinhood_main/Phase_06_Stage_07_UniswapV4DetfPkg.sol`. Premine helpers that still take `IUniswapV4SingleStandardExchangeDETDFPkg` must take the unified DFPkg.

| Tree | Remove or retarget |
|------|---------------------|
| `scripts/foundry/anvil_robinhood_testnet/Phase_06_Stage_07_CpDetfPkg.{sol,s.sol}` | Remove. One unified DETF pkg stage |
| `…/Phase_06_Stage_08_WeightedDetfPkg.{sol,s.sol}` | Remove |
| `…/Phase_06_Stage_09_OrbitalDetfPkg.{sol,s.sol}` | Remove |
| `…/Phase_06_Stage_10_CurveQuadDetfPkg.{sol,s.sol}` | Remove |
| `scripts/foundry/anvil_robinhood_testnet/README.md` | Catalog rows 06-07..10 → unified DETF pkg |
| Testnet **instance** stages / libs that still `deployVault` a family DETF | Retarget to `IUniswapV4DetfDFPkg.deployVault` with `PkgArgs.hook` |
| `scripts/foundry/anvil_robinhood_fee_detf/Script_08_DeployFeeDetfPackage.s.sol` | Deploy `UniswapV4DetfDFPkg`, not `UniswapV4SingleStandardExchangeDETDFPkg` |
| `scripts/foundry/anvil_robinhood_fee_detf/Script_09_DeployChirInstance.s.sol` | Instance `IUniswapV4Detf.PkgArgs` (no `pairToken` / `standardExchangeVault` fields). Keep launch-rich opening economics |
| `scripts/foundry/UniswapV4DetfScriptWireLib.sol` / premine | Keep hook wiring. Stop typing family DETF DFPkg |
| `scripts/foundry/anvil_robinhood_fee_detf/Script_10_*.s.sol` through `Script_13_*.s.sol` | Retarget any `IUniswapV4SingleStandardExchangeDETF` casts to `IUniswapV4Detf`. Keep bootstrap economics |
| `scripts/foundry/anvil_robinhood_testnet/ProtocolDetfInstanceLib.sol` | Unified `PkgArgs` + `IUniswapV4Detf` |
| `scripts/foundry/UniswapV4DetfScriptWireLib.sol` | Call `IUniswapV4SeBufferHook` / unified DETF `hook()`. Delete family DETF interface imports |
| `scripts/foundry/research/uniswapV4/detf/**` | **Delete** (imports family TestBases) |
| `test/foundry/spec/saf/T01_FacetSelectors.t.sol` … `T11_BrandStrip.t.sol` | **Delete** each file whose imports include a family Uni V4 DETF TestBase (`…/standardExchange/**/*DETF*`). Keep files that already use unified or non-DETF SUT. T06b PreviewParity: delete family-DETF contracts only |
| `test/foundry/fork/**` Uni V4 family DETF specs | **Delete** every fork spec that imports family Uni V4 DETF packages or TestBases |
| `scripts/foundry/anvil_robinhood_main/` | Already unified package stage. Do not resurrect family stages. Instance phases that import family DETF ABI: retarget. Instance phases that already use `IUniswapV4Detf`: leave |

Hook **packages** (CP/Orbital/Weighted/Quad buffer hooks) stay. Only DETF **diamonds** go away.

### 11.2 Solidity family DETF packages (in, after scripts)

Only after no launch **or instance** script imports them:

**Delete** (not archive). Research docs under `research/scenarios/uniswapV4/detf/**` that still name family packages get a superseded banner in this WP; do not keep the Solidity alive for them.

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/*DETF*`
- `…/orbital/*DETF*`
- `…/weighted/*DETF*`
- `…/stable/quad/curve/*DETF*`
- Matching `test/foundry/spec/…/standardExchange/**` family DETF specs
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/**` (`UniV4DetfBondNft*`)
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/**` (`UniV4DetfRebasingClaim*`)
- FactoryService helpers that exist only to deploy those leftovers or family DETF DFPkgs
- `test/foundry/spec/saf/T0*.t.sol` that inherit family DETF TestBases
- Family fork specs under `test/foundry/fork/**` that import those packages
- `scripts/foundry/research/uniswapV4/detf/**`

Keep: hook packages, `UniswapV4DetfHookPremineLib`, `UniswapV4DetfHookStagedInitLib`, unified `…/detf/` and `…/bondNft/`.

### 11.3 Docs (in)

Point Uni V4 v1 DETF at `…/uniswap/v4/detf/`:

- [`docs/agent/INDEXEDEX_AGENT_LAW.md`](../../docs/agent/INDEXEDEX_AGENT_LAW.md) family table (Uni V4 rows → one unified DFPkg + four hooks)
- [`docs/agent/AGENT_NAVIGATION_INDEX.md`](../../docs/agent/AGENT_NAVIGATION_INDEX.md)
- [`docs/agent/INDEXEDEX_CONTENT_INVENTORY.md`](../../docs/agent/INDEXEDEX_CONTENT_INVENTORY.md)
- [`DETF_INSTANCE_IO_ROUTING_PROGRAM.md`](./DETF_INSTANCE_IO_ROUTING_PROGRAM.md) add **Stage 12** = this PRD
- Family co-located `*_PRD.md` under `standardExchange/**`: banner **superseded** by §16 + this coverage PRD. Do not rewrite their product law.

### 11.4 Explicitly not deprecated

- Uni V4 **hooks**
- Uni V3 / V4 / Morpho Blue **Standard Exchange** packages
- `detf/common/**`
- Balancer DETFs
- Stage 11 prod-se tests (kept and **extended** by this PRD’s ProductLaw/Policy siblings)
- `contracts/test/bases/TestBase_UniswapV4Detf_PonsV2Se.sol` (kept; pair retargeted to launch token)

---

## 12. Constraints (copy onto every implementer prompt)

1. Production-first. No `MockStandardExchange`. No `new` facets/DFPkgs. No `vm.mockCall` of SUT.
2. `via_ir` forbidden.
3. DETF role names only.
4. Inherit `TestBase_UniswapV4Detf*` or the Stage 11 fixture TestBase. Do not diamond-inherit family DETF TestBases.
5. Family tests are copy-logic, not acceptance.
6. ERC-4626 gold is the pathfinder. Acceptance for an SE class is that class’s Stage 11 ProductLaw + Policy siblings (WP-UDPL-SE-*).
7. R12a donate booking (unassigned LP when O>0). Do not assert family N4 “id 0 originalShares mint” on a live unified instance with O>0. DN15 is N/A.
8. Anti-theater on any Univ4Se/Univ3Se burn/close: `allowance(hook, se)==0`.
9. Dual is not a DETF hook.
10. Seed `cache_forge/` + `out/` in a new worktree. Do not kill `forge`/`solc`. Timeout hours.
11. `--match-contract` unique WP files. Do not treat colliding extras as this change.
12. Morpho types stay out of DETF **production** sources.
13. New ABI only. Tests call `IUniswapV4Detf`, R12a Bond NFT, and `IRebasingClaimToken`. Do not add `buyClaim` / `redeemClaim` / `sellPositionToDetfNft` onto the DETF diamond.
14. Critical flaw: stop the WP and report. No production CODE until an explicit go-ahead.
15. DN3 and DN15 are N/A on Uni V4. Do not steal hook LP. Do not restore N10 convertToAssets stasis.
16. Custom close execute: IO WP = CP T7.11. QD WP = T8.3 `closeBondMature`.
17. Do not edit `TestBase_UniswapV4Detf.sol`. Do not add §7 tests to existing Stage 11 firstBond contracts.
18. Layer matrix §7.0 is the ID list. Do not run gold-only IDs on Stage 11. Do not skip Open/Policy IDs listed there.
19. CLAIM does not start until POLICY is green.
20. Fee oracle `p=5e16`, `f=12e16`, `c=28e16`. Launch-rich opening max 24 steps of `+0.05e18` from `1.1e18`.
21. FC4 uses later `bond`, not `buyClaim`. FC names follow R-16.
22. E6 N/A. D18 not tested. Nested only four IDs in R-11.

---

## 13. Ready-to-paste implementer prompt

`/goal` kickoff and per-WP child prompts live in the [implementation plan](./UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_IMPLEMENTATION_AND_TEST_PLAN.md) Launch section. Compact reminder if a child only has this PRD:

```text
Implement contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_PRD.md
for worktree assignment: <WP-UDPL-IO | WP-UDPL-POLICY | WP-UDPL-DONATE |
WP-UDPL-CLAIM | WP-UDPL-D25 | WP-UDPL-ADV | WP-UDPL-OR | WP-UDPL-WE |
WP-UDPL-QD | WP-UDPL-SE-CP | WP-UDPL-SE-OR | WP-UDPL-SE-WE | WP-UDPL-SE-QD |
WP-UDPL-DEPRECATE>.

Read §0 (review locks) and §7.0 (ID × layer matrix) before any file create.
Those tables win over family tests and over any leftover “or” in this PRD.

SUT is UniswapV4DetfDFPkg only. Unified ABI is the standard.
Copy behavioral asserts from family standardExchange/** DETF tests. Do not inherit
those TestBases. Do not put sell/buyClaim/redeemClaim on IUniswapV4Detf.
Sell = Bond NFT. Redeem = RebasingClaimToken (pays DETF). D18 is not tested.
E6 N/A. DN3 and DN15 N/A NatSpec. Add DN21 and DN22. FC4 = later bond.

Gold CP/Orbital/Weighted/Quad get gold §7. Stage 11 gets only the Open and
Policy ID sets in §7.0, via siblings *_ProductLaw.t.sol and *_Policy.t.sol.
Never edit existing firstBond/mint/burn/close contracts. Never edit
TestBase_UniswapV4Detf.sol. H-CP-P2 stays the pons TestBase; pair = launch token.

Keep Stage 11 firstBond/mint/burn/close names. Do not bind Dual. Do not touch
Balancer DETFs. Critical flaw: stop and report; no CODE. R12a donate: O>0
unassigned LP, convertToAssets rises. Policy: opening 1.1e18 then +0.05e18
max 24 steps. Fee oracle p=5e16 f=12e16 c=28e16. Do not prank(detf) to LP
before first bond.

WP-UDPL-DEPRECATE deletes family DETFs, leftover common/nft and rebasing,
SAF/fork/research that import family TestBases, and retargets testnet +
fee_detf 08–13 + WireLib + ProtocolDetfInstanceLib.

When done: paste forge match-path results for this WP plus the three
regression matchers: prod-se/**, pons/**, and UniswapV4Detf_*.t.sol.
```

---

## 14. Status table (update when a WP lands)

| WP | Status |
|----|--------|
| WP-UDPL-IO | go-ahead: T7.15 NatSpec N/A (no deploy FoT check) |
| WP-UDPL-POLICY | go-ahead: R-18 max 24 steps; R-14 lpOut==0 OK |
| WP-UDPL-DONATE | go-ahead: cut `claimLiquidity` / `previewClaimLiquidity` |
| WP-UDPL-CLAIM | green: D15 11/11, Claim 3/3, FC 12/12. `claimLiquidity` harvests pending first (D15-3); previewRedeem two-step identity (D15-1) |
| WP-UDPL-D25 | green (8/8 + R-19) |
| WP-UDPL-ADV | green 21/21. I1 donate = DETF-booked pair (DN7 is honest NFT pretransfer). J1–J3 include `claimLiquidity` / `previewClaimLiquidity` |
| WP-UDPL-OR | **§6.1 halt** 106/109. Red: D15-1 (1 wei), D15-5 dump order, D25-6 preview. See `critical-flaw-wave3.txt` |
| WP-UDPL-WE | **§6.1 halt** gold 106/111. T8.4 + D31-3 + burn-allowed now green (test-side). Still red: D15-1 (1 wei), D15-5 |
| WP-UDPL-QD | 108/108 gold run used D15-1 `approxEqAbs(2)` and D15-5 without first-dump order. R-22 `assertEq` restored. Not honest-green until re-run |
| WP-UDPL-SE-CP | open |
| WP-UDPL-SE-OR | open |
| WP-UDPL-SE-WE | open |
| WP-UDPL-SE-QD | open |
| WP-UDPL-DEPRECATE | blocked on tests |

Family hook-specific Uni V4 DETF packages remain in-tree until WP-UDPL-DEPRECATE.

`foundry.toml` `via_ir = false`.
