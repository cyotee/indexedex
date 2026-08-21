# Implementation & Test Plan: Uni V4 SE DETF peg vs opening price

**PRD (product law SoT):** [`UNISWAP_V4_SE_DETF_PEG_AND_OPENING_PRICE_PRD.md`](./UNISWAP_V4_SE_DETF_PEG_AND_OPENING_PRICE_PRD.md) (**Accepted v0.1**, N1–N18)  
**This plan (implementor SoT):** file map, phases, exact edits, test commands, DoD. **No product choices.**  
**Date:** 2026-08-20  
**Status:** READY FOR EXECUTION (goal-command agent)

| Layer | Role |
|-------|------|
| **PRD v0.1** | Product law. Wins on any conflict. Patch this plan if the PRD changes. |
| **This plan** | Phases, file map, commit order, `forge test --match-path` set, grep DoD |
| **CLAUDE.md / INDEXEDEX_AGENT_LAW** | Crane first; never `new` DFPkgs; DETF role names; no `via_ir`; production-first tests; forge patience |
| **Skills** | `crane-deployment`, `crane-architecture`, `crane-testing`, `indexedex-testing`, `indexedex-uniswap-v4-hook-packages` |

**Process:** If this plan and the PRD disagree, **PRD wins** and this plan must be patched before coding continues. If a PkgArgs field or formula is in neither, **STOP and ask**. Do not invent. Do not reintroduce Anvil diamond `depositSingle` richness (PRD N11).

**Role names only:** `rateAsset`, `pairToken`, `standardExchangeVault`, `vaultShare`, `detfToken`, `reservePool` / `reserveHook`, `rebasingClaimToken`.

---

## Goal-command bootstrap (paste to a new agent)

```text
Implement
contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UNISWAP_V4_SE_DETF_PEG_AND_OPENING_PRICE_IMPLEMENTATION_AND_TEST_PLAN.md
against
contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UNISWAP_V4_SE_DETF_PEG_AND_OPENING_PRICE_PRD.md
v0.1 (N1–N18).

Read both files fully before editing. PRD wins on product. This plan wins on
file map / phases / DoD.

Split peg and first-bond opening price on all four Uni V4 hook DETFs:
CP Single, Curve Quad, Weighted, Orbital.

creationPairPerDetfWad = peg (synthetic 1.0).
openingPairPerDetfWad = first-bond pair per DETF (0 → creation).
First-bond empty-book G = pair * 1e18 / opening.
Synthetic / Policy mint-burn / expansion use creation only.
Live quotes after isReserveLive use the live curve.

Default tests: opening = 0 (at peg).
Launch-rich hermetic: creation 1e18, opening 1.1e18 then PRD N10
until isMintingAllowed after first bond. Record the WAD.

Do NOT impersonate the DETF diamond. Do NOT hook depositSingle as the
diamond. Do NOT change mint threshold to fake mint-open.
Do NOT edit Balancer DETFs. Do NOT public 46630 broadcast.
Do NOT via_ir. Never `new` facets/DFPkgs.

Skills: crane-deployment, crane-architecture, crane-testing,
indexedex-testing, indexedex-uniswap-v4-hook-packages.

Forge patience: 20–40+ min cold compile is normal. Do not kill.
Seed cache_forge/ + out/ from a warm checkout before first forge
in a new worktree (CLAUDE.md worktree compile seed).
```

---

## 0. Starting state

| Item | Status |
|------|--------|
| Four `I*DETDFPkg.PkgArgs` | Peg only (`creationPairPerDetfWad` / pair0+pair1). No opening field |
| First-bond empty-book quote | `G = pair * 1e18 / creation` in each `*DETFCommon._quoteBondJoinDetf` |
| Synthetic | `(fd/supply)/creation` |
| TestBases | `DEFAULT_CREATION = 1e18`; no opening key |
| 46630 `Stage_06` | creation `1e18`; RichnessLib impersonates diamond for D47 |
| Hook `deployPair` | `TickMath.getSqrtPriceAtTick(0)` (1:1) |

---

## 1. Goals / non-goals

### Goals

1. Add opening fields per PRD §2. Resolve 0 → creation at init. Persist resolved.  
2. Empty-book first-bond quote uses **opening**. Synthetic/gates/expansion stay on **creation**.  
3. Hermetic T1–T7 (PRD §4). N10 if mint still closed at 1.1e18 opening.  
4. 46630 leaf scripts: set opening; first bond as EOA; delete diamond impersonation richness.  
5. Every `PkgArgs({...})` literal in-repo compiles (opening `0` unless launch-rich).  
6. Docs in PRD §6 patched. Grep DoD green.

### Non-goals (do not do)

PRD §7. Plus: do not change `deployVault(args, mineNonce)` arity; do not put opening into hook `PkgArgs` unless N12 requires sqrtPrice at init (DETF opening only, mapped in DETF `_deployReserveHook` / `deployPair` caller).

---

## 2. Read order for implementors

1. PRD §0–§3 (N1–N18 + formulae)  
2. CP Single: `UniswapV4SingleStandardExchangeDETFCommon._quoteBondJoinDetf`, `_syntheticPrice`, `DETFBondingTarget.bond`, `*Repo` `Storage` / `CoreInit`, `I*DETDFPkg.PkgArgs`, `*DETDFPkg` `initAccount` / `DeployConfig`  
3. Repeat the same four functions on Quad, Weighted, Orbital  
4. This plan §3–§9  
5. Then code CP as the template; clone the pattern

---

## 3. File map

Base: `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/`

### 3.1 CP Single (template)

| File | Edits |
|------|--------|
| `constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol` | Info: `function openingPairPerDetfWad() external view returns (uint256);`. `PkgArgs`: add `uint256 openingPairPerDetfWad;` immediately after `creationPairPerDetfWad` with NatSpec from PRD §2. |
| `constantProduct/single/UniswapV4SingleStandardExchangeDETFRepo.sol` | `Storage` + `CoreInit`: `openingPairPerDetfWad`. `_initializeCore` writes it. |
| `constantProduct/single/UniswapV4SingleStandardExchangeDETDFPkg.sol` | `DeployConfig` + decode/init: resolve N6 (`opening == 0 ? creation : opening`). Pass into `CoreInit`. |
| `constantProduct/single/UniswapV4SingleStandardExchangeDETFCommon.sol` | `_quoteBondJoinDetf` empty-book branch: divide by **opening**. `_syntheticPrice` / `_syntheticPriceSpot` / live `_quoteDetfAgainstReserve` **unchanged** (creation). Add `_openingPairPerDetfWad()` view helper if needed. |
| `constantProduct/single/UniswapV4SingleStandardExchangeDETFBondingTarget.sol` | `openingPairPerDetfWad()` view → storage. |
| `constantProduct/single/UniswapV4SingleStandardExchangeDETFFacet.sol` | Add selector next to `creationPairPerDetfWad`. Grow the `bytes4[]` length by 1. |
| `constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol` | `openingPairPerDetfWad: 0` in `PkgArgs`. Optional helper to deploy with explicit opening. |

### 3.2 Curve Quad

| File | Edits |
|------|--------|
| `stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol` | `openingPairPerDetfWad(uint256)` + `openingPairPerDetfWads()`. `PkgArgs`: `uint256[] openingPairPerDetfWad` after creation array. Length 3. |
| `…/UniswapV4StandardExchangeCurveQuadStableDETFRepo.sol` | Storage + init. |
| `…/UniswapV4StandardExchangeCurveQuadStableDETDFPkg.sol` | Resolve per slot (N9). Length must match creation / `m`. |
| `…/UniswapV4StandardExchangeCurveQuadStableDETFCommon.sol` | Empty-book `_quoteBondJoinDetf(productIndex_, pairNative_)` uses opening[i]. Synthetic vs pair still `/ creation[i]`. |
| `…/UniswapV4StandardExchangeCurveQuadStableDETFInfoTarget.sol` (and Bonding if views live there) | Opening views. |
| `…/UniswapV4StandardExchangeCurveQuadStableDETFFacet.sol` + `DETFInfoFacet.sol` | Selectors. |
| `…/TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol` | `openingPairPerDetfWad: new uint256[](3)` (zeros). |

### 3.3 Weighted

Same pattern as Quad: array opening beside creation. Files: interface, Repo, DFPkg, Common (`_quoteBondJoinDetf`), InfoTarget, Facet(s), TestBase, adversarial/core tests that construct `PkgArgs`.

### 3.4 Orbital

Scalar pair0/pair1:

- `openingPair0PerDetfWad`, `openingPair1PerDetfWad` after the two creation fields.  
- Files: interface, Repo, DFPkg, Common empty-book quote, InfoTarget, Facet(s), TestBase, Deploy.t.sol.

### 3.5 Tests to add

| Path | What |
|------|------|
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETF_OpeningPrice.t.sol` | T1–T5, T7 for CP. T3 mint-open. |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETF_OpeningPrice.t.sol` | T1–T3, T6 |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETF_OpeningPrice.t.sol` | T1–T2, T6 |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETF_OpeningPrice.t.sol` | T1–T2 |

Extend gold TestBase rather than mocking. First bond through the real `bond` path.

### 3.6 PkgArgs literals (compile)

Add `openingPairPerDetfWad: 0` / empty-or-zero arrays / orbital zeros wherever `PkgArgs({` is built:

- Four family TestBases  
- `UniswapV4*DETF_Adversarial.t.sol`, `_Core.t.sol`, `_Deploy.t.sol` under each family  
- `UniswapV4*DETDFPkg.sol` internal `PkgArgs` copies if any  
- `scripts/foundry/anvil_robinhood_testnet/Stage_06_LeafDETFs.sol`  
- `scripts/foundry/anvil_robinhood_main/Script_13_DeployInertDemos.s.sol`  
- `scripts/foundry/anvil_robinhood_main/Script_18_DeployChirInstance.s.sol`  
- `scripts/foundry/anvil_robinhood_fee_detf/Script_09_DeployChirInstance.s.sol`  
- Research fixtures under `scripts/foundry/research/uniswapV4/detf/**` if they construct PkgArgs  

Grep after: `creationPairPerDetfWad:` every hit must have a sibling opening field in the same struct literal.

### 3.7 46630 scripts (behavior)

| File | Edits |
|------|--------|
| `scripts/foundry/anvil_robinhood_testnet/FixtureEconomics.sol` | Keep `CREATION_PAIR_PER_DETF = 1e18`. Add `OPENING_PAIR_PER_DETF` start `1.1e18`. Comment: N10 may raise this; not a D47 impersonation target. Remove reliance on `RICH_TARGET` for diamond LP. |
| `scripts/foundry/anvil_robinhood_testnet/Stage_06_LeafDETFs.sol` | Set opening on CP + Quad args (N17/N10). |
| `scripts/foundry/anvil_robinhood_testnet/RichnessLib.sol` | **Delete** `_unlockAnvilAccount`, `_depositPairOnHook`, and any `enrichCp` / `enrichMulti` that LP as the diamond. First bond functions stay. If enrich is only nest inventory via `exchangeIn`, keep that and say so in a one-line comment. |
| `scripts/foundry/anvil_robinhood_testnet/README.md` | First bond opens; opening WAD is launch-rich; no impersonation. |

### 3.8 Docs (PRD §6)

| File | Edits |
|------|--------|
| Four `*_PRD.md` (CP, Quad, Weighted, Orbital) | Peg vs opening. First bond uses opening. |
| `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` §16.2 | Uni V4 empty-pool quote = **opening**; synthetic peg = creation. |
| `docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md` | D38: creation remains peg 1e18. Add opening as launch-rich. Rescind D47 diamond `depositSingle`. |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` | One paragraph: Uni V4 DETF PkgArgs peg vs opening. |
| Four family `*_IMPLEMENTATION_AND_TEST_PLAN.md` | One line pointing at this PRD/plan. Do not rewrite those whole files. |

### 3.9 Hook init (N12, only if needed)

If CP/Quad first bond at `opening = 1.1e18` reverts or joins 1:1 anyway:

- Find `deployPair` / `TickMath.getSqrtPriceAtTick(0)` on the matching **reserve hook** init target.  
- Initialize sqrtPrice from opening (pair/DETF), respecting token0/token1 order.  
- Gold test: first join used amounts match opening ratio (reserves, not tick-0 1:1 leftover).  

Do not change hook `ownerOnlyLiquidity`. Do not make `depositSingle` public.

---

## 4. Resolve helper (copy onto each DFPkg init)

```solidity
function _resolveOpening(uint256 creation_, uint256 opening_) internal pure returns (uint256) {
    if (creation_ == 0) revert InvalidCreationRate();
    return opening_ == 0 ? creation_ : opening_;
}
```

Arrays: revert if `opening.length != 0 && opening.length != creation.length`. Then for each `i`, `resolved[i] = _resolveOpening(creation[i], opening.length == 0 ? 0 : opening[i])`.

Use the family’s existing creation-length error if one exists; do not invent a second error name unless none exists.

---

## 5. Empty-book quote (pattern)

**Before (CP):**

```solidity
detfOut_ = Math.mulDiv(pairWad_, ONE_WAD, s.creationPairPerDetfWad);
```

**After:**

```solidity
detfOut_ = Math.mulDiv(pairWad_, ONE_WAD, s.openingPairPerDetfWad);
```

Only in the `!s.isReserveLive || !_hookIsLive()` (and equivalent empty-reserve) branches of `_quoteBondJoinDetf`. Live branches unchanged.

Quad/Weighted/Orbital: same, index into `openingPairPerDetfWad[i]` / pair0/pair1.

---

## 6. Phase order

| Phase | Work | Exit |
|-------|------|------|
| A | CP Single: PkgArgs → Repo → DFPkg resolve → quote → views → facet selector → TestBase `opening: 0` | CP compiles; existing CP hermetic still green with opening 0 |
| B | CP `*_OpeningPrice.t.sol` T1–T5, T7, T3+N10 | Mint-open WAD recorded if not 1.1e18 |
| C | Quad (same pattern + T6) | Quad OpeningPrice + existing Quad hermetic green |
| D | Weighted | same |
| E | Orbital | same |
| F | Scripts 3.6–3.7 | `forge build` of script files that construct PkgArgs; 46630 RichnessLib has no anvil_rpc impersonate |
| G | N12 only if B/C first-bond at opening ≠ 1e18 fails | Opening ratio actually in the reserve |
| H | Docs 3.8 | Grep DoD |

Do not start D until C is green. Do not start F until E is green (PkgArgs shape stable).

---

## 7. Test commands

Default profile only. No `via_ir`. Wait for process exit.

```bash
# After phase B
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/*'

# After phase C
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/*'

# After phase D
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/*'

# After phase E
forge test --match-path \
  'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/*'

# OpeningPrice files only (faster inner loop once cache is warm)
forge test --match-contract UniswapV4SingleStandardExchangeDETF_OpeningPrice
forge test --match-contract UniswapV4StandardExchangeCurveQuadStableDETF_OpeningPrice
forge test --match-contract UniswapV4StandardExchangeWeightedDETF_OpeningPrice
forge test --match-contract UniswapV4StandardExchangeOrbitalDETF_OpeningPrice
```

Adversarial suites in those folders must still compile and run after PkgArgs grows.

---

## 8. Grep DoD

From repo root:

```bash
# Every Uni V4 DETF PkgArgs has opening beside creation
rg -n "struct PkgArgs" -A 40 \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange \
  | rg -n "creationPair|openingPair"

# Empty-book first-bond quote must mention opening (not only creation)
rg -n "_quoteBondJoinDetf" -A 20 \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange \
  | rg "openingPairPerDetfWad|creationPairPerDetfWad"

# No impersonation richness in 46630 lib
rg -n "anvil_impersonateAccount|anvil_setBalance" \
  scripts/foundry/anvil_robinhood_testnet/
# expect: no hits (or only comments forbidding it)

# Literal PkgArgs still compiling: every creationPair assignment in sol PkgArgs
# should have opening in the same constructor (manual scan of rg hits)
rg -n "creationPairPerDetfWad:" --glob '*.sol'
```

Synthetic still divides by creation:

```bash
rg -n "creationPairPerDetfWad" \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFCommon.sol
```

`_syntheticPrice` / `_syntheticPriceSpot` must still use creation, not opening.

---

## 9. Agent checklist

- [x] PRD N1–N18 read; no extra PkgArgs fields  
- [x] Phase A–E green with commands in §7  
- [x] N10 WAD written in FixtureEconomics + OpeningPrice test comments if not 1.1e18  
- [x] Phase F: 46630 first bond only; no diamond LP  
- [x] Phase G only if required  
- [x] Phase H docs  
- [x] Grep DoD  
- [x] Role names only; no `via_ir`; no `new` DFPkg  

**Done when:** all boxes ticked and OpeningPrice tests plus existing family hermetic paths are green.
