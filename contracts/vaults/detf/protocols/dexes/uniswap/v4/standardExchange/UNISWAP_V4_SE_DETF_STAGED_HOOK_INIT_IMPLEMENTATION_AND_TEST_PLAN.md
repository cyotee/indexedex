# Implementation & Test Plan: Uni V4 SE DETF staged hook init

**PRD (product law SoT):** [`UNISWAP_V4_SE_DETF_STAGED_HOOK_INIT_PRD.md`](./UNISWAP_V4_SE_DETF_STAGED_HOOK_INIT_PRD.md) (**Draft v0.2**)  
**This plan (implementor SoT):** file map, phases, exact edits, test commands, DoD. **No product choices.**  
**Date:** 2026-08-18  
**Status:** Ready to implement.

| Layer | Role |
|-------|------|
| **PRD v0.2** | Product law. Wins on any conflict. Patch this plan if the PRD changes. |
| **This plan** | Phases, file map, commit order, `forge test --match-path` set, grep DoD |
| **Mine-nonce PRD / plan** | Unchanged. `deployVault(PkgArgs, uint256)` + `UniswapV4DetfHookPremineLib` stay |
| **CLAUDE.md / INDEXEDEX_AGENT_LAW** | Crane first; never `new` DFPkgs; DETF role names; no `via_ir`; production-first tests; forge patience |
| **Skills** | `crane-deployment`, `crane-architecture`, `crane-testing`, `indexedex-testing` |

**Process:** If this plan and the PRD disagree, **PRD wins** and this plan must be patched before coding continues. Do not invent a third layout.

**Role names only:** `rateAsset`, `pairToken`, `standardExchangeVault`, `vaultShare`, `detfToken`, `reserveHook` / `reservePool`, `rebasingClaimToken`. No product brands.

**Worktree:** implement in `indexedex-worktrees/v4-hook-staged-pool-init` (or a child seeded from it). Hook staged init is already landed here: SE buffer hook `postDeploy` returns `true` with zero `PoolManager.initialize`. If you are on a tree where hook `postDeploy` still calls `ensure*PairPools`, **stop**. This plan assumes `IUniswapV4HookStagedPairInit` is live on those hooks.

---

## Launch (paste into `/goal`)

```text
/goal Implement Uni V4 SE DETF compatibility with staged hook initialization from the locked PRD and this plan. No product choices. No half measures.

LAW (read fully before coding):
- contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UNISWAP_V4_SE_DETF_STAGED_HOOK_INIT_PRD.md (v0.2 — D1–D17, §§4–12)
- contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UNISWAP_V4_SE_DETF_STAGED_HOOK_INIT_IMPLEMENTATION_AND_TEST_PLAN.md (this file)
- Claude.md + docs/agent/INDEXEDEX_AGENT_LAW.md
- skills: crane-deployment, crane-architecture, crane-testing, indexedex-testing

SCOPE: four Uni V4 SE DETF families only (CP Single, Orbital, Weighted, Curve Quad). Deploy sequence: DETF.deployVault = hook bootstrap only; callers open product doors on IUniswapV4HookStagedPairInit (one TX per deployPair); finalize on the hook; completeReserveBondNft then completeReserveClaim on the DETF. First bond still sets isReserveLive and reverts ReserveNotWired until both children exist.

DO:
- Follow this plan’s file map, function bodies, TestBase/script edits, and §5 forge commands.
- Seed cache_forge/ + out/ if this is a new worktree (Claude.md worktree seed).
- Wait for forge/solc exit. First compile 20–40+ minutes is normal. Timeout 2–4 hours. Never kill forge.

DO NOT:
- Change hook factory, hook DFPkg staged-init, IUniswapV4HookStagedPairInit, or mine-nonce law.
- Change mint/bond/threshold/expansion economics.
- Add wiring surface to IDetf.
- Call ensureReserveReady* from scripts.
- Reintroduce CP _initPool or doors/finalize/children inside DETF postDeploy.
- via_ir. new facets/DFPkgs. SUT mocks. Live 46630 broadcast.

DONE when this plan §7 checkboxes and §6 greps are green.
```

---

## 0. Starting state

| Item | Status |
|------|--------|
| PRD v0.2 | Locked, co-located |
| Four SE buffer hooks | Staged: `postDeploy` returns true; doors via `deployPair`; ERC20 unmatched until finalize |
| CP DETF DFPkg | `_initPool` still does `deployPair` + `finalizeInitialization` then deploys children in `postDeploy` |
| Orbital / Weighted / Quad DETF DFPkg | `_deployReserveHook` then `_deployBondNftVault` in `postDeploy` (will revert on `decimals()`) |
| Instance `I*DETF` | No wiring functions |
| `UniswapV4DetfHookStagedInitLib` | **Does not exist** |
| Shared staged-init spec | **Does not exist** |
| Gold TestBases | `_deployDetfInstance` = premine + `deployVault`; `setUp` does not open doors / wire |
| Anvil Stage_06–08 | `deployVault` then `RichnessLib.firstBond*` in the same broadcast window |
| Script_13 inert demos | `deployVault` only (expects children from `postDeploy`) |
| Script_06d_M7W | Skipped on purpose (`n=8` stall). Do **not** unskip. |

---

## 1. Goals / non-goals

### Goals

1. DETF `postDeploy` deploys bootstrap hook + writes core Repo. No doors, no finalize, no children.  
2. Delete CP `_initPool`.  
3. Instance: `isReserveHookFinalized`, `isReserveWired`, `completeReserveBondNft`, `completeReserveClaim`.  
4. First bond reverts `ReserveNotWired` until both children exist.  
5. Shared `UniswapV4DetfHookStagedInitLib` (granular + TestBase-only `ensureReserveReady*`).  
6. TestBases `setUp` wires via the bundle. Scripts send one external `deployPair` per door, then finalize, then the two wiring calls.  
7. Family PRDs / Anvil README patched. Hermetic suites green. Grep DoD green.

### Non-goals (do not do)

Copied from PRD §11. Do not: stage DETF facets; wrap `deployPair` / `finalize` on the DETF; change hook staged-init; skip bond-NFT `decimals()`; hard-code LP decimals 18; auto-wire inside first bond; auto-finalize inside wiring; auto-claim inside bond-NFT step; `bool reserveWired`; attach-existing-child / CREATE2-reuse; child pkgs in `PkgArgs`; add surface to `IDetf`; Dual / Balancer Quad DETFs; `via_ir`; change mint/bond/threshold/expansion; live 46630 broadcast.

---

## 2. Read order for implementors

1. PRD §0–§2 (D1–D17)  
2. PRD §4–§7 (lifecycle, instance ABI, Repo, lib signatures + token lists)  
3. PRD §8–§12 (tests, scripts, docs, DoD)  
4. **This plan** §3–§8  
5. Current `_postDeployProxyContext` on CP (template for the strip) and Orbital (template for moving children)

---

## 3. File map (complete)

### 3.1 Create

| Path | What |
|------|------|
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4DetfHookStagedInitLib.sol` | PRD §7. SPDX `BSL-1.1`, `pragma solidity ^0.8.0;`. No `console2`. |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4SeDetfStagedHookInit.t.sol` | Four contracts, units A–E each. |

### 3.2 Delete

None. CP `_initPool` is a **function delete** inside the DFPkg, not a file delete.

### 3.3 Edit — interfaces (`I*DETF` only)

On each of the four instance interfaces (not `I*DETDFPkg`, not `IDetf`), append PRD §5 events, five errors, and four functions. Exact ABI is PRD §5. Do not reorder existing functions more than appending.

| File |
|------|
| `…/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol` |
| `…/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol` |
| `…/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol` |
| `…/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol` |

### 3.4 Edit — Repos (four)

| File |
|------|
| `…/constantProduct/single/UniswapV4SingleStandardExchangeDETFRepo.sol` |
| `…/orbital/UniswapV4StandardExchangeOrbitalDETFRepo.sol` |
| `…/weighted/UniswapV4StandardExchangeWeightedDETFRepo.sol` |
| `…/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFRepo.sol` |

On each:

1. Append to `Storage` (end only): `address bondNftVaultPkg;` `address rebasingClaimTokenPkg;`  
2. Append to `CoreInit` (end only): same two fields.  
3. `_initializeCore` writes them.  
4. Add errors: `ReserveNotWired()`, `ReserveHookNotFinalized()`, `ReserveBondNftNotWired()`, `ReserveBondNftAlreadyWired()`, `ReserveClaimAlreadyWired()`, and `ZeroAddress()` if that Repo does not already have it.  
5. Add `_setBondNft` and `_setClaim` **exactly** as PRD §6.

### 3.5 Edit — DFPkgs (four)

| File | Extra vs the common strip |
|------|---------------------------|
| `…/constantProduct/single/UniswapV4SingleStandardExchangeDETDFPkg.sol` | **Delete** `_initPool` and its call. Delete the `IUniswapV4HookStagedPairInit` import if unused. |
| `…/orbital/UniswapV4StandardExchangeOrbitalDETDFPkg.sol` | Common strip only |
| `…/weighted/UniswapV4StandardExchangeWeightedDETDFPkg.sol` | Common strip only |
| `…/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETDFPkg.sol` | Common strip only |

**`_postDeployProxyContext` (all four)** — keep validate + `_deployReserveHook` + `_initVaultTokens` + `_initRepo`. Remove every call to `_deployBondNftVault` / `_tryInitDetfNft` / `_tryInitFeeRecipientNft` / `_deployRebasingClaimToken`.

**`_initRepo`** — pass zeros for children; pass package immutables into the new CoreInit tail:

```solidity
bondNftVault: IDETFNFTVault(address(0)),
rebasingClaimToken: IRebasingClaimToken(address(0)),
detfNftId: 0,
feeRecipientNftId: 0,
bondNftVaultPkg: address(BOND_NFT_VAULT_PKG),
rebasingClaimTokenPkg: address(REBASING_CLAIM_TOKEN_PKG),
```

Keep `_initializePolicy` and `ThresholdModeSet` as today.

**Delete from each DFPkg** once the bodies have been copied onto the instance (§3.6): `_deployBondNftVault`, `_tryInitDetfNft`, `_tryInitFeeRecipientNft`, `_deployRebasingClaimToken`, `_minLockOrDefault` (if only used by those). `_deployReserveHook` stays.

Do **not** change `deployVault` / `calcSalt` / `processArgs` / `initAccount` mine-nonce decode.

### 3.6 Edit — instance mutators / views / first-bond gate

**Views** (`isReserveHookFinalized`, `isReserveWired`) — PRD §5.1–§5.2 bodies.

| Family | Put views on | Put both mutators on |
|--------|----------------|----------------------|
| CP | `UniswapV4SingleStandardExchangeDETFBondingTarget` | same file |
| Orbital | `UniswapV4StandardExchangeOrbitalDETFInfoTarget` | `…OrbitalDETFBondingTarget` |
| Weighted | `…WeightedDETFInfoTarget` | `…WeightedDETFBondingTarget` |
| Curve Quad | `…CurveQuadStableDETFInfoTarget` | `…CurveQuadStableDETFBondingTarget` |

**Mutator bodies:** copy today’s DFPkg child-deploy helpers bit-identically. Read `s.bondNftVaultPkg` / `s.rebasingClaimTokenPkg` / `s.reserveHook` / `s.feeOracle` from Repo (not DFPkg immutables). Then `Repo._setBondNft` / `Repo._setClaim` and emit the PRD events.

Need these imports on the mutator target (add if missing): `IDetfSelfNftInventoryDFPkg`, `IRebasingClaimTokenDFPkg`, `IDetf`, `ERC20Repo`, `IUniswapV4HookStagedPairInit` (views on InfoTarget need the hook init interface).

**`_requireReserveWired`** — add on each family `*DETFCommon.sol`:

```solidity
function _requireReserveWired() internal view {
    Repo.Storage storage s = Repo._layoutStruct();
    if (address(s.bondNftVault) == address(0) || address(s.rebasingClaimToken) == address(0)) {
        revert Repo.ReserveNotWired();
    }
}
```

Call it at the **start** of the first-bond helper, before any hook `depositSingle` / `addLiquidity` / `join*`:

| Family | Call site |
|--------|-----------|
| CP | `UniswapV4SingleStandardExchangeDETFBondingTarget._firstBondJoin` |
| Orbital | `…OrbitalDETFBondingTarget._firstBondJoin` |
| Weighted | `…WeightedDETFBondingTarget._firstBond` |
| Curve Quad | `…CurveQuadStableDETFBondingTarget._firstBond` |

Do **not** call it on later-bond paths.

### 3.7 Edit — facetFuncs

| Facet | Append |
|-------|--------|
| `…/constantProduct/single/UniswapV4SingleStandardExchangeDETFFacet.sol` | All four selectors (`isReserveHookFinalized`, `isReserveWired`, `completeReserveBondNft`, `completeReserveClaim`). Extend `_funcsB` (or add `_funcsC` if a 16/17 cap is already tight). |
| `…/orbital/UniswapV4StandardExchangeOrbitalDETFFacet.sol` | The two **mutator** selectors only. Grow `_allFuncs` from 10 to 12. |
| `…/orbital/UniswapV4StandardExchangeOrbitalDETFInfoFacet.sol` | The two **view** selectors. Append to `_funcsB`. |
| `…/weighted/UniswapV4StandardExchangeWeightedDETFFacet.sol` | Two mutators |
| `…/weighted/UniswapV4StandardExchangeWeightedDETFInfoFacet.sol` | Two views |
| `…/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFFacet.sol` | Two mutators |
| `…/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFInfoFacet.sol` | Two views |

Do **not** add a new facet. Do **not** put mutators on Info facets.

### 3.8 Shared lib (create — signatures are law)

Path and signatures: PRD §7.

Private helpers allowed (and required — do not add others):

| Helper | Role |
|--------|------|
| `_sort(address[] memory a) private pure` | PRD §7.1 insertion sort (same loop as mine-nonce `_sort`) |
| `_orbitalTokens(IUniswapV4StandardExchangeOrbitalDETF detf) private view returns (address[] memory)` | Binding-order length 3; PRD §7.1 Orbital |
| `_openAllPairs(address hook, address[] memory tokens) private` | `i<j` `openProductPair` |

`productTokensCp`: `tokens = new address[](2); tokens[0]=address(detf); tokens[1]=detf.pairToken();`  
`productTokensWeighted` / `productTokensQuad`: build then `_sort`.  
`openProductPair` / `finalizeHook`: one-liners as PRD §7.  
`ensureReserveReady*`: PRD §7 steps 1–6. **Do not** expose a fifth family wrapper.

Imports (only these):

- `contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol`
- Four `I*DETF` interface files

### 3.9 Gold TestBases

| File |
|------|
| `…/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol` |
| `…/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol` |
| `…/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol` |
| `…/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol` |

In each:

1. Import `UniswapV4DetfHookStagedInitLib`.  
2. `_deployDetfInstance` **unchanged** (premine + `deployVault` + `require` + label). It must **not** open doors or wire.  
3. After `detf = _deployDetfInstance(_defaultDetfArgs());` in `setUp`, call `UniswapV4DetfHookStagedInitLib.ensureReserveReady*(I*DETF(detf));` **before** user funding is fine; must run before any test that first-bonds.  
4. Add `_deployDetfBootstrapOnly` = copy of `_deployDetfInstance` body (or have `_deployDetfInstance` stay bootstrap and name the alias). PRD: `_deployDetfBootstrapOnly(args)` is deploy-only. Simplest: `_deployDetfBootstrapOnly` calls `_deployDetfInstance`.  
5. Add `_assertWired` per PRD §8.1.  
6. Keep `_assertInert` / `_assertLive`.

CP `setUp` comment “hermetic assert feeRecipientNftId != 0 after deploy”: that NFT is created in `completeReserveBondNft`. After `ensureReserveReady*` in `setUp`, the assert still holds. Do not move `_setDefaultBondTerms` (it must stay **before** deploy so the fee-recipient try sees terms).

### 3.10 Shared staged-init spec (create)

**Path:** `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4SeDetfStagedHookInit.t.sol`

Four contracts:

| Contract | Inherits |
|----------|----------|
| `UniswapV4SeDetfStagedHookInit_Cp` | `TestBase_UniswapV4SingleStandardExchangeDETF` |
| `UniswapV4SeDetfStagedHookInit_Orbital` | `TestBase_UniswapV4StandardExchangeOrbitalDETF` |
| `UniswapV4SeDetfStagedHookInit_Weighted` | `TestBase_UniswapV4StandardExchangeWeightedDETF` |
| `UniswapV4SeDetfStagedHookInit_Quad` | `TestBase_UniswapV4StandardExchangeCurveQuadStableDETF` |

Each **overrides `setUp`**: run the parent’s package / SE / terms setup **without** the parent’s `ensureReserveReady*` call. Do that by splitting the gold TestBase `setUp` if needed:

**Required TestBase split (all four):** extract everything currently in `setUp` *except* `_deployDetfInstance` + `ensureReserveReady*` + post-deploy pointer assigns into `_setUpPlatform()`. Default `setUp` becomes:

```solidity
function setUp() public virtual {
    _setUpPlatform();
    detf = _deployDetfInstance(_defaultDetfArgs());
    UniswapV4DetfHookStagedInitLib.ensureReserveReady*(I*DETF(detf));
    _bindDetfPointers(); // detfInfo / detfExchangeIn / fund user / _setBondTerms as today
}
```

Staged-init spec `setUp`:

```solidity
function setUp() public override {
    _setUpPlatform();
    detf = _deployDetfBootstrapOnly(_defaultDetfArgs());
    _bindDetfPointers();
}
```

Units (same names on all four). Law is PRD §8.2. Implement these exact names:

| Test | Notes |
|------|--------|
| `test_deployOnly_bootstrapHook` | Unit A |
| `test_bondNftBeforeFinalizeReverts` | Unit B first half. `vm.prank(stranger); vm.expectRevert(I*DETF.ReserveHookNotFinalized.selector); I*DETF(detf).completeReserveBondNft();` |
| `test_claimBeforeBondNftReverts` | Unit B second half. `ReserveBondNftNotWired` |
| `test_finalizeWithoutWiring` | Unit C. Use `productTokens*` + loop `openProductPair` + `finalizeHook`. No `ensureReserveReady*`. |
| `test_twoStepWiringAndFirstBond` | Unit D. Stranger does both wiring steps. Assert mid-state after bond NFT only. Then `_firstBond` / family first-bond helper. |
| `test_productPairCount` | Unit E. Open doors, **before** finalize, count `isPairPoolLive` over `i<j` of `productTokens*`. |

`stranger` = `address(0xB0B)` or the TestBase’s existing non-owner / non-`detfUser` if one exists. Do not use `owner` for Unit D’s first wiring calls.

No SUT mocks. No extra tests in this file.

### 3.11 Existing tests to grep-and-fix

After `setUp` uses `ensureReserveReady*`, most suites compile and pass.

Fix any test that **itself** calls `_deployDetfInstance` / `deployVault` and then first-bonds or asserts `bondNftVault() != 0` **without** wiring.

Known trees (grep-verify; fix every hit):

```text
test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/**/*Deploy*.t.sol
test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/**/*Core*.t.sol
test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/**/*Adversarial*.t.sol
```

Rule: extra deploys in those files go through `_deployDetfInstance` + `ensureReserveReady*` (tests may use the bundle). Deploy-only assertions become Unit A semantics.

### 3.12 Scripts — 46630 testnet

Foundry `vm.startBroadcast()` already emits **one transaction per external call**. Keep doors as separate externals. Do **not** wrap the loop in an external helper contract (that would be one TX). An `internal` Stage function that loops `openProductPair` is legal.

| File | Edit |
|------|------|
| `scripts/foundry/anvil_robinhood_testnet/Stage_06_LeafDETFs.sol` | After each successful `deployVault` + `require`, **before** `RichnessLib.firstBond*`, run §3.13 sequence for that family. Import the staged-init lib. |
| `scripts/foundry/anvil_robinhood_testnet/Stage_07_NestDETFs.sol` | Same for `deployBetaO` (orbital) and `deployIdxWrap` (CP). |
| `scripts/foundry/anvil_robinhood_testnet/Stage_08_FeeSink.sol` | Same for `ttRichS` (CP). |
| `scripts/foundry/anvil_robinhood_testnet/Script_06*.s.sol` | No control-flow change required if Stage_06 does the externals. Update comments: deploy ≠ ready reserve. |
| `scripts/foundry/anvil_robinhood_testnet/Script_06d_M7W.s.sol` | **Leave skipped.** Do not add a weighted leaf deploy. |
| `scripts/foundry/anvil_robinhood_testnet/README.md` | PRD §9: replace “hook postDeploy inits doors” / “DETF deploy leaves a ready reserve” with §4 sequence. |

`RichnessLib.firstBond*` / enrich: **do not change** except that they now run after wiring.

### 3.13 Script door+wire sequence (template)

Use this after every Uni V4 SE DETF `deployVault` in scripts (including inert demos that do **not** first-bond):

```solidity
I*DETF d = I*DETF(deployed);
address hook = d.reserveHook();
address[] memory tokens = UniswapV4DetfHookStagedInitLib.productTokens*(d);
for (uint256 i; i < tokens.length; ++i) {
    for (uint256 j = i + 1; j < tokens.length; ++j) {
        UniswapV4DetfHookStagedInitLib.openProductPair(hook, tokens[i], tokens[j]);
    }
}
UniswapV4DetfHookStagedInitLib.finalizeHook(hook);
d.completeReserveBondNft();
d.completeReserveClaim();
```

Family mapping:

| Deploy | `productTokens*` | Typed `I*DETF` |
|--------|------------------|----------------|
| NvdaS, IdxWrap, RichS, Chir | `productTokensCp` | `IUniswapV4SingleStandardExchangeDETF` |
| NvdaSmhO, BetaO | `productTokensOrbital` | `IUniswapV4StandardExchangeOrbitalDETF` |
| IdxQ, DolQ | `productTokensQuad` | `IUniswapV4StandardExchangeCurveQuadStableDETF` |
| Script_13 weighted gentle / launch-rich | `productTokensWeighted` | `IUniswapV4StandardExchangeWeightedDETF` |

A private Stage helper `_wireCp(address detf)` / `_wireOrbital` / `_wireQuad` / `_wireWeighted` that is `internal` and contains only the block above is required so the four Stage files do not inline a second algorithm. Those helpers **must not** be named `ensureReserveReady*`.

### 3.14 Scripts — main + fee DETF

| File | Edit |
|------|------|
| `scripts/foundry/anvil_robinhood_main/Script_13_DeployInertDemos.s.sol` | After **each** Uni V4 SE DETF `deployVault` (CP, orbital, weighted n=8 ×2), run §3.13. Inert means `!isReserveLive`, **not** unwired. Weighted n=8 is 28 `deployPair` externals + finalize + two wiring calls. Expected. |
| `scripts/foundry/anvil_robinhood_main/Script_18_DeployChirInstance.s.sol` | After CP `deployVault`, §3.13 `productTokensCp`, then existing first-bond if any. |
| `scripts/foundry/anvil_robinhood_fee_detf/Script_09_DeployChirInstance.s.sol` | Same as Script_18. |

Do **not** call `ensureReserveReady*` from these files.

### 3.15 Docs (same change set)

| File | Edit |
|------|------|
| Four family `*_PRD.md` | § Deploy / postDeploy spirit: hook `postDeploy` does **not** init doors; DETF `postDeploy` deploys bootstrap hook only; scripts use `productTokens*` + one TX per door + two wiring fns; TestBase `setUp` uses `ensureReserveReady*`. Point at the staged-init PRD. Delete sentences that say hook `postDeploy` creates all pair doors. |
| Four family `*_IMPLEMENTATION_AND_TEST_PLAN.md` | Same. TestBase `setUp` no longer assumes children at the end of `deployVault`. |
| `docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md` and its impl plan | Only sentences that claim DETF deploy inits hook doors or children. |
| `docs/ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_PRD.md` | Same rule. |
| `scripts/foundry/anvil_robinhood_testnet/README.md` | §3.12 |
| This PRD | Stays SoT. Do not rewrite hook-factory or hook-package staged-init PRDs. |

---

## 4. Phases / commit slices

One change set is acceptable. If slicing commits, use this order (later phases will not compile until earlier ones land):

| Phase | Contents | Compile? |
|-------|----------|----------|
| **P0** | Four `I*DETF` ABIs + four Repos (§3.3–§3.4) | Breaks implementors of `I*DETF` until P2 |
| **P1** | Four DFPkgs strip children / `_initPool`; `_initRepo` writes pkg addresses + zero children | `deployVault` compiles; first bond will fail until P2+P4 |
| **P2** | Views, mutators, facetFuncs, `_requireReserveWired` | Instance compiles |
| **P3** | Create `UniswapV4DetfHookStagedInitLib.sol` | Lib compiles |
| **P4** | TestBase `setUp` split + `ensureReserveReady*` + `_assertWired` | Family tests compile |
| **P5** | Shared `UniswapV4SeDetfStagedHookInit.t.sol` + grep-fix existing specs | New units compile |
| **P6** | Stage_06–08, Script_13/18, fee-detf Script_09 | Scripts compile |
| **P7** | Docs §3.15 | n/a |

Do not merge P6 before P3 (scripts import the new lib). Do not keep CP `_initPool` “until scripts are done.”

---

## 5. Test execution (normative)

**Forge patience:** first compile in a cold or near-cold tree commonly takes 20–40+ minutes with little output. That is normal. Wait for process exit. Never kill `forge` / `solc`. If a tool requires a timeout, set **2–4 hours**, not 10–20 minutes. If this is a new worktree, seed `cache_forge/` and `out/` from the warm checkout first (CLAUDE.md worktree seed).

Default profile only (`forge test`). No `via_ir`. No package-specific profile. Do not run `FOUNDRY_PROFILE=fork` for this DoD.

Run in this order (stop and fix on first failure):

```bash
# 1. New staged-init units (all four family contracts in one file)
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4SeDetfStagedHookInit.t.sol' \
  -vv

# 2. Mine-nonce units still green (do not regress arity)
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4SeDetfDeployMineNonce.t.sol' \
  -vv

# 3. CP family hermetic
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/**' \
  -vv

# 4. Orbital family hermetic
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/**' \
  -vv

# 5. Weighted family hermetic
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/**' \
  -vv

# 6. Curve Quad family hermetic
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/**' \
  -vv
```

Script compile check after P6 (does not broadcast):

```bash
forge build --skip test
```

`foundry.toml` already compiles `scripts/`. A green `forge build --skip test` is the script DoD. Do **not** run 46630 live / public broadcast.

---

## 6. Grep DoD (run after P6, before declaring done)

```bash
# CP _initPool gone
rg _initPool \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange

# No deployPair / finalize from DETF packages
rg 'deployPair|finalizeInitialization' \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange --glob '*DETDFPkg.sol'

# Old one-shot name gone
rg completeReserveWiring

# Scripts must not call the TestBase bundle
rg ensureReserveReady scripts/foundry

# New surface exists on instance interfaces only
rg 'completeReserveBondNft|completeReserveClaim|isReserveHookFinalized|isReserveWired' \
  contracts/interfaces

# Shared IDetf untouched
rg 'completeReserveBondNft|isReserveHookFinalized|isReserveWired' \
  contracts/interfaces/detf
```

Pass criteria:

- `rg _initPool` under the four DETF package directories: clean.  
- `rg deployPair|finalizeInitialization` on the four `*DETDFPkg.sol`: clean.  
- `rg completeReserveWiring`: clean in this repo.  
- `rg ensureReserveReady scripts/foundry`: clean.  
- `contracts/interfaces/detf` (shared `IDetf`): no new wiring symbols.  
- `git diff` must not change hook factory sources or hook DFPkg `deployVault` / `postDeploy` / `IUniswapV4HookStagedPairInit` except if a DETF test was wrongly calling hook `ensure*PairPools` (then only the call site).

If grep finds another DETF `postDeploy` child deploy or a script `ensureReserveReady*`, **change it**. Do not waive.

---

## 7. Definition of done

All of PRD §12, plus:

- [ ] Four `I*DETF`: PRD §5 ABI. Four `I*DETDFPkg` unchanged. `IDetf` unchanged.  
- [ ] Four Repos: D15 append + `_setBondNft` + `_setClaim`.  
- [ ] Four packages: D6; CP `_initPool` gone; no children in `postDeploy`.  
- [ ] Mutators + views + facetFuncs per §3.6–§3.7. First-bond `_requireReserveWired`.  
- [ ] `UniswapV4DetfHookStagedInitLib.sol` exists with the locked signatures.  
- [ ] Four TestBases: `setUp` wires via `ensureReserveReady*`; `_deployDetfInstance` does not.  
- [ ] Shared spec exists with units A–E on all four contracts.  
- [ ] Listed scripts compile (`forge build --skip test`) and use §3.13 (not `ensureReserveReady*`).  
- [ ] §5 `forge test --match-path` set all green (default profile).  
- [ ] §6 greps pass.  
- [ ] §3.15 docs patched.  
- [ ] No `via_ir`. No `new` DFPkg/facet. No SUT mocks.

---

## 8. Open questions

None. Product locks are PRD v0.2. This plan names every file, function body, script sequence, test contract, and `forge` command.
