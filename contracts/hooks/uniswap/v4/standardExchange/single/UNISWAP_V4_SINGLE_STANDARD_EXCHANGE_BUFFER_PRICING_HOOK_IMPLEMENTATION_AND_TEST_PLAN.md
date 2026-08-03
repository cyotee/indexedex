# Uniswap V4 Single Standard Exchange Buffer Pricing Hook — Implementation and Testing Plan

**Date:** 2026-08-02  
**Status:** READY TO IMPLEMENT  
**Normative product:** [`UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md`](./UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md)  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/single/`  
**SE dependency path:** `contracts/vaults/standard/erc4626/` (+ shared MultiAsset vault Targets under `contracts/vaults/basic/` / `contracts/vaults/standard/`)  

**Methodology skills:** `crane-deployment`, `crane-architecture`, `crane-testing`, `indexedex-testing`, `crane-adversarial-testing`, `indexedex-adversarial-testing`, `crane-uniswap` (V4 settle patterns — behavioral reference only)

Ordered for incremental delivery. Each phase leaves a green, reviewable slice. **Do not reopen PRD-locked decisions D1–D74 without a PRD revision.**

**Stack law (D63):** land **P0.SE green before** claiming hook phases complete. Hook code may be drafted in parallel but must not claim DoD on incomplete SE routes.

---

## 0. Locked decisions (copy — PRD is source of truth)

| Topic | Decision |
|-------|----------|
| Product | **`UniswapV4SingleStandardExchangeBufferPricingHook`** — CREATE3-mined single contract |
| Package shape | **Repo + Target + Common + FactoryService**; **no** Facet / DFPkg / diamond for **hook** |
| SE binding | One SE + one `underlying` + PoolManager; **ctor immutables**; no post-deploy binding init |
| Pool vault currency | **`address(SE)`** always (D30) |
| Pricing | SE `previewExchangeIn` / `previewExchangeOut` on **underlying ↔ SE only**; no Morpho/pro-rata in hook |
| Quote matrix | **Exact-in + exact-out both ways** (wrap + unwrap) |
| Execution | SE `exchangeIn` / `exchangeOut` only; `recipient = hook`; **`deadline = block.timestamp` (D59)** |
| Pool fee / CL | **fee = 0**; **`beforeAddLiquidity` reverts** |
| Inheritance | **No** `BaseTokenWrapperHook` / `BaseHook` / `DeltaResolver` — **full pattern-copy (D51 / D67)** |
| Deploy | Existing **`create3Factory`** + **`HookMinerCreate3.computeAddress`** + FactoryService binding-aware mine loop |
| Salt | `namespace, pm, se, underlying, mineNonce` → `encodePacked(...)._hash()` via FactoryService only |
| Default namespace | `"uv4-single-se-buffer-pricing-hook-"`; multi-instance via different namespace (D58) |
| Idempotency | Same namespace+binding → return existing if `isExpectedHook` (views only — D53); wrong occupant **reverts** |
| Fees (ERC-4626 SE) | **Dilution mint on mint routes only** (D40); WAD + `BetterMath._percentageOfWAD` (D40a/D57); **exit: no usage fee (D42)** |
| Dust | Unrefundable residual ≤ **`MAX_DUST_WEI = 10`** → oracle **`feeTo` only** if non-zero (D50/D66); **skip if `feeTo == 0` (D71)** |
| Under-delivery | Delivered out &lt; `amountOut` → **`Slippage` (D69)** — not dust |
| Zero amounts | **Revert** on zero `amountIn` / exact-out zero `amountOut` (D74) |
| Exact-out take | Hook takes **exactly** SE-previewed `amountIn` from PoolManager (D43) |
| SE bounds from hook | `minOut` / `maxIn` **= preview** (D46); outer router owns user slippage |
| `wrapZeroForOne` | Ctor address sort → **Repo only**; **no public getter (D70/D73)** |
| First deposit | **Do not rework** existing SE donation protection (D48) |
| Hook test matrix | **ERC-4626 / Morpho only** (D45) |
| Fork priority | **Robinhood P0** then **Base P1**; pin Morpho-official/curated WETH Vault V2 (D68/D72) |
| Uni V4 DETF | **Fully independent (D64)** — no shared TestBases/helpers/product code |
| SE co-work | **In scope** — §6.0 is hard DoD for this program |

### 0.1 Clarification locks (implementor edges)

| # | Topic | Lock |
|---|--------|------|
| D40a/D57 | Fee unit | Rocket Pool peer: `_percentageOfWAD` |
| D50/D55 | Dust bound | `MAX_DUST_WEI = 10` |
| D53 | `isExpectedHook` | Views only: `poolManager` / `standardExchange` / `underlying` |
| D54 | MultiAsset regression | Compile + **ERC-4626 suite only** |
| D52/D61 | Interest | Real accrual only; strict increase DoD |
| D56/D60 | Test pool | `tickSpacing = 60`, 1:1 mid `sqrtPriceX96` |
| D65 | Mine exhaustion | `deployHook` reverts past `MAX_LOOP` |
| D71 | `feeTo == 0` | Skip dust absorb; skip fee mint (Rocket peer) |

---

## 1. Goals and non-goals

### Goals

1. **Fix generic ERC-4626 SE** so full underlying ↔ SE exact-in/out matrix works via `IStandardExchangeIn` / `IStandardExchangeOut` only (PRD §6.0).  
2. **Wire `vaultTokens`** via standard MultiAsset **Targets** + Facets **IFacet-only**, cut **both** Basic + Standard multi-asset facets into the SE proxy; storage already inits `[protocolVault, asset()]` — keep that.  
3. Ship **`UniswapV4SingleStandardExchangeBufferPricingHook`**: pattern-copy wrapper hook; SE-priced wrap/unwrap exact-in/out; public previews.  
4. **FactoryService** library on existing `create3Factory`: binding-aware mine, idempotent `deployHook`, multi-namespace multi-instance.  
5. **Hermetic** Morpho + real V4 PoolManager; **fork** RH then Base with pinned curated Morpho Vault V2.  
6. Prove: preview == execution (fees on mint), real interest strict increase, zero-amount reverts, dust/`Slippage` law, deploy flags + idempotency.

### Non-goals (v1)

- Morpho-specific SE package.  
- Hook Facet/DFPkg/diamond instance.  
- Permit2 on hook paths.  
- Native ETH pool currency.  
- CL liquidity / non-zero pool fee.  
- Package-owned pool `initialize`.  
- Multi-hop routes outside bound pair.  
- Levered LP / Morpho borrow / dual-sleeve strategies.  
- Uni V4 Single SE DETF coupling (D64).  
- Rework of SE first-deposit / donation protection (D48).  
- Deadline-skew admin surface (D59).  
- Peer SE product rewrites (Camelot/Aero/etc.) beyond **compile** after MultiAsset extract (D41/D54).  
- Shared scaffolding with DETF packages.

---

## 2. Current-state gap audit (as of plan write)

Use this as the starting worklist. Re-verify if code moves before implementation.

### 2.1 ERC-4626 SE routes

| Route | SE API | Status | Work |
|-------|--------|--------|------|
| Wrap exact-in | `previewExchangeIn(U, ain, SE)` + `exchangeIn` | **Present** | Add D40 dilution fee mint; zero guards; fees in preview model |
| Wrap exact-out | `previewExchangeOut(U, SE, aout)` + `exchangeOut` | **Missing** | Out currently forces `tokenIn == SE` |
| protocolVault → SE exact-out | `previewExchangeOut(PV, SE, aout)` + `exchangeOut` | **Missing** | SE completeness (D44); not a hook path |
| Unwrap exact-out | `previewExchangeOut(SE, U, aout)` + `exchangeOut` | **Buggy** | Execute uses `amountIn = maxAmountIn` then floor `amountOut` — **must** true exact-out (D38) |
| Unwrap exact-in | `previewExchangeIn(SE, seIn, U)` + `exchangeIn` | **Missing** | In has vault→underlying but not SE→underlying |
| `pretransferred` on Out | Interface law | **Ignored** | Out burns `msg.sender` only; must honor pretransfer + refund |
| Usage fee | Dilution mint mint-routes | **Not applied** | DFPkg wires fee oracle storage; In/Out never mint fee |
| Zero amounts | D74 | **Weak/absent** | Revert on zero in/out |

**Files:**  
`contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol`  
`contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutTarget.sol`  
`contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol`

### 2.2 `vaultTokens` / MultiAsset

| Item | Status | Work |
|------|--------|------|
| Storage init `[protocolVault, asset()]` | **Present** in DFPkg `initAccount` | Keep; assert in tests |
| `MultiAssetBasicVaultFacet` cut into SE | **Present** in `facetCuts()` | After Target extract, still cut |
| `MultiAssetStandardVaultFacet` cut into SE | **Missing** — stored on DFPkg, **not** in `facetCuts()` | **Add cut** (PRD §6.0.B) |
| `IBasicVault` / `IStandardVault` in `facetInterfaces()` | Partial — marker set may lack them | Register per peer Camelot pattern |
| `MultiAsset*Target` existence | **None** — domain logic **inline** on Facets | Extract Targets; Facets `is Target, IFacet` only (D41) |

**Files:**  
`contracts/vaults/basic/MultiAssetBasicVaultFacet.sol`  
`contracts/vaults/standard/MultiAssetStandardVaultFacet.sol`  
`contracts/vaults/standard/erc4626/ERC4626StandardExchangeDFPkg.sol`

### 2.3 Hook package

| Item | Status |
|------|--------|
| PRD | Present |
| Implementation plan | **This file** |
| Hook production sources | **None yet** |
| Hook TestBase / specs | **None yet** |

### 2.4 Fee peer (copy shape, do not import package coupling)

Canonical dilution pattern:  
`contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol` → `_mintWithUsageFee`  
(`usageFeeOfVault` → `_percentageOfWAD` → mint user full + mint `feeTo` fee shares; skip if feePct/feeTo/feeShares zero).

### 2.5 Crane V4 references (behavioral only)

| Asset | Path | Use |
|-------|------|-----|
| `BaseTokenWrapperHook` | `lib/crane/.../hooks/public/base/BaseTokenWrapperHook.sol` | Permissions, pair/fee init, delta settle **order** |
| `WstETHHook` | `lib/crane/.../hooks/public/WstETHHook.sol` | Dynamic rate helper **shape** |
| `DeltaResolver` / `BaseHook` | same tree | Pattern-copy take/settle/pay — **no inheritance** |
| `HookMinerCreate3` | `lib/crane/.../hooks/public/utils/HookMinerCreate3.sol` | `computeAddress` + `MAX_LOOP` spirit |
| `BetterEfficientHashLib` | Crane utils | Salt `encodePacked(...)._hash()` |

---

## 3. Error surface

### 3.1 Shared / SE (ERC-4626)

| Error | When |
|-------|------|
| `UnsupportedRoute` / prefer `InvalidRoute` if peer already uses it | Unsupported pair |
| `DeadlineExpired` | `block.timestamp > deadline` |
| `Slippage` | `amountIn > maxAmountIn`; delivered out &lt; `amountOut` (D69); minOut miss |
| Zero-amount error or `Slippage` | `amountIn == 0` or exact-out `amountOut == 0` (D74) — pick one clear error; document in NatSpec |
| `InsufficientDeposit` (if peer has it) | Pretransfer shortfall |
| Protocol bubbles | Morpho/4626 pause, liquidity, redeem shortfall |

**Forbidden:** silent no-op success on zero amounts; burn full `maxAmountIn` when calculated `amountIn` is smaller.

### 3.2 Hook

| Error | When |
|-------|------|
| Hook permission / init validation | Wrong pair, non-zero fee, CL add liquidity |
| Propagate SE errors | Route / Slippage / Deadline from SE |
| Zero amount | Same D74 law on public previews + swap paths |
| Deploy / FactoryService | Collision (non-expected code at predicted address); mine loop exhaustion (D65); zero addresses; `underlying ∉ vaultTokens()` |

Prefer small custom errors on FactoryService for deploy failures (e.g. `HookDeployCollision`, `HookMineExhausted`, `InvalidUnderlying`) — implementor choice if not already present.

---

## 4. Layout

### 4.1 Hook package (new)

```text
contracts/hooks/uniswap/v4/standardExchange/single/
  UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md
  UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # this file
  UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_MOVE_AND_RENAME_PLAN.md

  interfaces/
    IUniswapV4SingleStandardExchangeBufferPricingHook.sol

  UniswapV4SingleStandardExchangeBufferPricingHookRepo.sol
  UniswapV4SingleStandardExchangeBufferPricingHookCommon.sol
  UniswapV4SingleStandardExchangeBufferPricingHookTarget.sol
  UniswapV4SingleStandardExchangeBufferPricingHook.sol
  UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService.sol

  # FORBIDDEN: *Facet.sol, *DFPkg.sol, I*DFPkg.sol

  # optional TestBase: contracts/test/bases/
  #   TestBase_UniswapV4SingleStandardExchangeBufferPricingHook.sol
```

### 4.2 ERC-4626 SE / MultiAsset (modify)

```text
contracts/vaults/basic/
  MultiAssetBasicVaultTarget.sol          # NEW — domain from Facet
  MultiAssetBasicVaultFacet.sol           # EDIT — inherit Target; IFacet body only

contracts/vaults/standard/
  MultiAssetStandardVaultTarget.sol       # NEW
  MultiAssetStandardVaultFacet.sol        # EDIT — inherit Target; IFacet body only

contracts/vaults/standard/erc4626/
  ERC4626StandardExchangeCommon.sol       # EDIT — shared mint fee, dust, exact-out helpers
  ERC4626StandardExchangeInTarget.sol     # EDIT — unwrap exact-in; zero guards; fee
  ERC4626StandardExchangeOutTarget.sol    # EDIT — wrap exact-out; true exact-out; pretransferred; dust
  ERC4626StandardExchangeDFPkg.sol        # EDIT — cut MultiAssetStandard; interface ids
  ERC4626StandardExchange*Facet.sol       # thin; no route logic changes if Targets hold it
  IERC4626StandardExchange.sol            # NatSpec if needed
```

### 4.3 Tests (suggested)

```text
# SE fixes
test/foundry/spec/vaults/standard/erc4626/
  ERC4626StandardExchange_Routes.t.sol
  ERC4626StandardExchange_Fees.t.sol
  ERC4626StandardExchange_VaultTokens.t.sol
  ERC4626StandardExchange_DustAndZero.t.sol
  # extend existing sfrxETH/Morpho hermetic if present

test/foundry/fork/eth_main/vaults/standard/erc4626/
  ERC4626StandardExchange_SfrxETH_Fork.t.sol   # retain/extend

# Hook hermetic
test/foundry/spec/hooks/uniswap/v4/standardExchange/single/
  UniswapV4SingleStandardExchangeBufferPricingHook_Deploy.t.sol
  UniswapV4SingleStandardExchangeBufferPricingHook_Routes.t.sol
  UniswapV4SingleStandardExchangeBufferPricingHook_Interest.t.sol
  UniswapV4SingleStandardExchangeBufferPricingHook_InitGuards.t.sol

# Hook fork
test/foundry/fork/robinhood_main/.../UniswapV4SingleStandardExchangeBufferPricingHook_*_Fork.t.sol
test/foundry/fork/base_main/.../UniswapV4SingleStandardExchangeBufferPricingHook_*_Fork.t.sol

# Constants
contracts/constants/ (or ROBINHOOD_MAIN peer): pin Morpho Vault V2 WETH instance (D68/D72)
```

### 4.4 TestBase chain (hook)

```text
CraneTest
  → IndexedexTest
    → TestBase_VaultComponents
      → TestBase_ERC4626StandardExchange   # after §6.0
        → TestBase_UniswapV4SingleStandardExchangeBufferPricingHook
            # + Crane Morpho / Uni V4 PoolManager ports as peer TestBases require
```

**Do not** import Uni V4 DETF TestBases (D64).

---

## 5. Route matrix checklists

### 5.1 ERC-4626 SE (mandatory before hook DoD)

Assets: `U` = underlying (`protocolVault.asset()`), `V` = protocolVault, `S` = SE.

| # | Intent | API | Exact-in | Exact-out | Notes |
|---|--------|-----|----------|-----------|-------|
| SE1 | Wrap U→S | In / Out | ☐ | ☐ | Dilution fee on mint (D40); Out = `tokenOut = S` |
| SE2 | V→S mint | In / Out | ☐ (existing In) | ☐ (new Out) | D44 completeness; fee on mint |
| SE3 | Unwrap S→U | In / Out | ☐ (new In) | ☐ (true Out) | **No exit fee (D42)**; exact-out burn only amountIn |
| SE4 | S→V | Out (existing) | — | ☐ | True exact-out if present; no exit fee |
| SE5 | U↔V pass-through | In | ☐ keep | — | Existing deposit/redeem helpers |

For each closed-form row: `assertEq(preview, executed)` (user-facing amounts).  
Fees: user receipt remains full due; `feeTo` balance ↑ separately on mint routes.

### 5.2 Hook (v1 — underlying ↔ SE only)

| # | Intent | Hook preview | SE call | Exact-in | Exact-out |
|---|--------|--------------|--------|----------|-----------|
| H1 | Wrap | `previewWrap` / `previewWrapExactOut` | In / Out | ☐ | ☐ |
| H2 | Unwrap | `previewUnwrap` / `previewUnwrapExactOut` | In / Out | ☐ | ☐ |

All via real V4 swap (or PoolManager unlock path consistent with BaseTokenWrapperHook settle).  
Hook test matrix: **Morpho ERC-4626 only** (D45).

---

## 6. Implementation phases

### Phase P0 — Docs gate (this PR)

- [x] PRD locked (D1–D74)  
- [ ] This implementation + test plan reviewed  
- [ ] No product law changes without PRD revision  

**Exit:** Plan accepted; implementors start P0.SE.

---

### Phase P0.SE — ERC-4626 SE fixes (**blocking**)

Split into reviewable PRs if desired; **all** green before hook DoD.

#### P0.SE.A — MultiAsset Targets + DFPkg cuts (D41 / D54)

**Deliverables**

1. Create `MultiAssetBasicVaultTarget` with domain: `vaultTokens`, `reserveOfToken`, `reserves` (Repo-backed).  
2. Create `MultiAssetStandardVaultTarget` with domain from current Standard facet (fee/type/config getters as present).  
3. Facets: `is *Target, IFacet` — **only** `IFacet` surface in Facet body.  
4. ERC-4626 DFPkg: **cut** `MULTI_ASSET_STANDARD_VAULT_FACET` into `facetCuts()`; keep Basic cut.  
5. Register `IBasicVault` / `IStandardVault` in `facetInterfaces()` as peers do.  
6. Confirm `initAccount` still initializes MultiAsset with `[protocolVault, asset()]`.  

**Tests**

| ID | Case |
|----|------|
| VT1 | Deploy SE → `vaultTokens()` contains protocolVault + asset() |
| VT2 | Membership assert for underlying (hook D36 dependency) |
| VT3 | `forge build` green for peer packages that cut MultiAsset facets |
| VT4 | Existing ERC-4626 suite still compiles/runs (regression floor D54) |

**Exit:** Targets extracted; both multi-asset facets cut on SE; VT* green; **no** peer SE rewrites.

---

#### P0.SE.B — Common helpers: fee, dust, zero, exact-out calc

**Deliverables**

1. `_mintWithUsageFee(recipient, userShares)` — Rocket peer shape (D40/D40a/D57/D71).  
2. `MAX_DUST_WEI = 10` constant + NatSpec (D55).  
3. `_absorbDustToFeeTo(token, amount)` — transfer residual ≤ 10 to `feeTo` if non-zero; **skip if `feeTo == 0`** (D71); never absorb &gt; 10.  
4. Shared exact-out amountIn calculators for mint and exit (single source for preview + execute).  
5. Zero-amount guards reusable from In/Out.  

**Tests**

| ID | Case |
|----|------|
| F1 | Non-zero usage fee: user gets full shares; feeTo minted; totalSupply ↑ user+fee |
| F2 | feePct=0 / feeTo=0 / feeShares=0: no fee mint, no revert |
| F3 | Exit under non-zero fee: **no** fee mint / no skim (D42) |
| Z1 | amountIn=0 / amountOut=0 revert on preview + execute |

**Exit:** Common helpers unit-tested via SE surface.

---

#### P0.SE.C — Out Target: wrap exact-out + true exact-out exit + pretransferred

**Deliverables**

1. **Wrap exact-out:** `tokenIn = underlying`, `tokenOut = SE`  
   - `amountIn = preview` for full user `amountOut` SE (fee does **not** increase amountIn)  
   - deposit protocol vault; `_mint(recipient, amountOut)` + fee mint  
   - spend only amountIn; refund refundable excess  
2. **protocolVault → SE exact-out** (same mint inverse; no underlying deposit)  
3. **Unwrap exact-out:** calculate `amountIn` SE; **burn only that**; redeem; if delivered U &lt; amountOut → `Slippage` (D69)  
4. **S→V exact-out:** true amountIn; burn only that  
5. Honor **`pretransferred`**: use balance delta; consume amountIn; **refund** surplus to caller  
6. Unrefundable multi-leg residual ≤ 10 → feeTo (D50/D66/D71)  
7. Rewrite NatSpec: Out is **not** “exit only”  

**Forbidden regression:** `amountIn = maxAmountIn` burn pattern.

**Tests**

| ID | Case |
|----|------|
| O1 | Wrap exact-out preview == spend; user SE == amountOut; feeTo feeShares |
| O2 | protocolVault→SE exact-out preview == spend |
| O3 | Unwrap exact-out: burn &lt; maxAmountIn when excess pretransferred; refund |
| O4 | Under-delivery redeem → Slippage (force via hostile/controlled rounding if needed — still production SE) |
| O5 | pretransferred wrap exact-out refund path |
| O6 | Dust absorb to feeTo when residual ≤ 10 and feeTo set; skip when feeTo=0 |

**Exit:** SE1 exact-out, SE2 exact-out, SE3 exact-out green.

---

#### P0.SE.D — In Target: unwrap exact-in + fee on mint routes

**Deliverables**

1. `previewExchangeIn(SE, seIn, underlying)` + `exchangeIn` using pro-rata vault claim + `previewRedeem` / redeem (expose current internal `_previewRedeemShares` path if needed).  
2. Mint routes (U→S, V→S): use `_mintWithUsageFee`; preview returns **user** amount (full due).  
3. Zero guards; deadline; reentrancy consistent with existing.  
4. Keep existing U↔V and U→S wrap exact-in working.  

**Tests**

| ID | Case |
|----|------|
| I1 | Unwrap exact-in preview == execution (no exit fee) |
| I2 | Wrap exact-in with non-zero fee: user full; feeTo ↑; preview == user out |
| I3 | Wrap exact-in zero fee still works (control) |
| I4 | Real interest (Morpho/sfrxETH hermetic): claim ↑ after accrual (D52) |

**Exit:** SE3 exact-in + SE1 exact-in fee-aware green.

---

#### P0.SE.E — SE suite gate (PRD §6.0.C / §10.0)

Checklist (all required):

1. [ ] Wrap exact-out preview == spend; refunds; dust law  
2. [ ] protocolVault→SE exact-out  
3. [ ] Unwrap exact-out burn only amountIn  
4. [ ] Unwrap exact-in preview == exec  
5. [ ] Fees in previews where execute applies  
6. [ ] Non-zero oracle usage fee tests (D24a)  
7. [ ] Wrap exact-in regression + real interest  
8. [ ] vaultTokens cut + Target extract  
9. [ ] Production-first (no SUT mocks)  
10. [ ] No Morpho-only SE package  
11. [ ] No first-deposit rework (D48)  
12. [ ] Zero amounts revert (D74)  

**Exit:** **P0.SE complete.** Hook P1 may claim SE dependency.

---

### Phase P1 — Hook core (Repo / Target / Common / FactoryService)

**Depends on:** P0.SE green (or merged stack with SE green as prerequisite).

#### P1.A — Scaffold + interface

**Deliverables**

- `IUniswapV4SingleStandardExchangeBufferPricingHook`: views `poolManager`, `standardExchange`, `underlying`, `wrapper`; previews wrap/unwrap exact-in/out  
- **No** `wrapZeroForOne()` public (D73)  
- Repo layout: immutables for binding (or immutable fields on contract + Repo for `wrapZeroForOne` only — match PRD D29/D70)  
- Ctor: non-zero checks; `underlying ∈ vaultTokens()`; set Repo `wrapZeroForOne` from address sort; `Hooks.validateHookPermissions`  
- Single mined contract wires Target  

**Exit:** Compiles; unit deploy without pool optional.

---

#### P1.B — Common: previews + SE call helpers

**Deliverables**

- Preview helpers = pure SE passthroughs (D5–D9)  
- Zero-amount reverts on previews  
- SE call helpers: `deadline = block.timestamp`; tight minOut/maxIn = preview (D46); prefer `pretransferred = true`  
- Currency order helpers (internal only)  

**Tests**

| ID | Case |
|----|------|
| HP1 | Each preview matches SE direct call for same amounts |
| HP2 | Zero in/out reverts on all four previews |

---

#### P1.C — Target: IHooks pattern-copy (D39 / D51 / D67)

**Deliverables**

| Hook | Behavior |
|------|----------|
| `beforeInitialize` | Bound pair only; fee == 0 |
| `beforeAddLiquidity` | Revert always |
| `beforeSwap` + return delta | Wrap/unwrap exact-in **and** exact-out via SE |
| Exact-out take | Take **exactly** previewed amountIn from PM (D43) |
| Settlement | Pattern-copy BaseTokenWrapperHook / DeltaResolver order — **no inheritance** |

Map zeroForOne to wrap vs unwrap using Repo `wrapZeroForOne`.

**Tests** (need PoolManager + SE + pool init external):

| ID | Case |
|----|------|
| HS1–HS4 | Four swap modes: balances correct; preview == execution |
| HS5 | Non-zero fee / wrong pair init reverts |
| HS6 | `beforeAddLiquidity` reverts |
| HS7 | Usage fee non-zero on SE: wrap user full shares; unwrap no exit fee |
| HS8 | Exact-out: hook took exactly amountIn (balance / event / accounting assert) |

**Exit:** Four-route hermetic green on Morpho SE.

---

#### P1.D — FactoryService mine + deployHook (D18–D22, D32, D37, D53, D58, D65)

**Deliverables**

```text
library UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService
  DEFAULT_SALT_NAMESPACE = "uv4-single-se-buffer-pricing-hook-"
  hookSalt(namespace, pm, se, underlying, mineNonce) → encodePacked(...)._hash()
  deployHook(create3Factory, pm, se, underlying)
  deployHook(..., saltNamespace)
  isExpectedHook(addr, pm, se, underlying)  // views only
```

Mine loop per PRD §5.2:

- `deployer = address(create3Factory)` only  
- flags = BaseTokenWrapperHook set  
- empty → deploy; expected → return; wrong code → revert; loop end → revert  

**Tests**

| ID | Case |
|----|------|
| HD1 | Deployed address flags match; `validateHookPermissions` |
| HD2 | Second deploy same namespace+binding → same address |
| HD3 | Different namespace same binding → second instance |
| HD4 | Collision: etch/wrong code at predicted → revert (hermetic setup) |
| HD5 | Predicted address == create3 formula |
| HD6 | Wrong underlying at ctor reverts |

**Exit:** Deploy path production-ready; no `new` hook; no bare `find`/`findWithPrefix`.

---

### Phase P2 — Hermetic completeness (hook DoD §10.1)

| ID | Requirement |
|----|-------------|
| H-DoD-1 | V4 PM + Morpho Blue/Vault V2 ports + fixed ERC-4626 SE |
| H-DoD-2 | vaultTokens + reject wrong underlying |
| H-DoD-3 | FactoryService deploy + flag bits |
| H-DoD-4 | Idempotent deploy (D53) |
| H-DoD-5 | External pool init `tickSpacing=60`, 1:1 mid sqrtPrice (D56/D60) |
| H-DoD-6 | All four routes Morpho-only matrix (D45) |
| H-DoD-7 | Real interest strict increase unwrap (D52/D61) — **no** claim-growth cheats |
| H-DoD-8 | Preview == exec with non-zero usage fee on mint |
| H-DoD-9 | Exact take (D43); tight bounds (D46); deadline = now (D59) |
| H-DoD-10 | Init guards + no CL |
| H-DoD-11 | Same create3Factory as facets |
| H-DoD-12 | Empty SE deploy allowed (D48) |
| H-DoD-13 | Pattern-copy only; Repo wrapZeroForOne; no public getter |
| H-DoD-14 | Multi-namespace multi-instance |
| H-DoD-15 | No DETF imports (D64) |
| H-DoD-16 | Dust / Slippage / zero-amount laws |

**Exit:** Full hermetic hook suite green.

---

### Phase P3 — DX polish (optional)

- [ ] Thin script/helper wrapping `deployHook` for anvil/local  
- [ ] NatSpec / AsciiDoc include-tags if repo convention requires  
- [ ] Public preview naming polish only if needed  

**Exit:** Optional; not blocking P4.

---

### Phase P4 — Fork

#### P4.0 — Pin vault instances (before RH DoD)

- [ ] Research Morpho-official / curated **WETH Morpho Vault V2** for Robinhood  
- [ ] Pin address into `ROBINHOOD_MAIN` (preferred) or IndexedEx constants (D68/D72)  
- [ ] Same spirit for Base when P1 fork lands  
- [ ] **Forbidden:** TVL scan / arbitrary first instance as sole pin  

#### P4.A — Robinhood P0

- [ ] Existing RH foundry profile + Morpho **infra** constants (D47)  
- [ ] Deploy SE on pinned vault; deploy hook; external init; smoke all four routes if liquidity allows  
- [ ] Interest smoke if accrual observable in test window  

#### P4.B — Base P1

- [ ] Morpho docs / curated vault pin (D72)  
- [ ] Same smoke matrix  

**Exit:** RH fork green; Base optional-but-planned same release train.

---

### Phase P5 — Optional scripts / docs hygiene

- [ ] Deploy scripts outside PRD product surface  
- [ ] Cross-link research docs if needed  
- [ ] Still **no** second CREATE3 factory  

---

## 7. Implementation notes (normative algorithms)

### 7.1 Dilution fee (mint routes only)

```text
userShares = full shares due from exchange math
feeShares  = BetterMath._percentageOfWAD(userShares, usageFeeOfVault(SE))
_mint(user, userShares)
if feePct != 0 && feeTo != 0 && feeShares != 0:
  _mint(feeTo, feeShares)
// preview return == userShares (not userShares - fee)
// exact-out wrap: amountIn covers user claim only; fee is extra supply
```

### 7.2 Exact-out spend law (SE Out)

```text
0. require amountOut > 0 else revert
1. amountIn = shared preview calc
2. require amountIn <= maxAmountIn else Slippage
3. consume ONLY amountIn
4. execute; if delivered out < amountOut → Slippage
5. refund refundable surplus
6. residual ≤ 10 unrefundable → feeTo if non-zero else skip
7. return amountIn
```

### 7.3 Hook exact-out take

```text
amountIn = SE.previewExchangeOut(...)
take exactly amountIn from PoolManager
SE.exchangeOut(..., maxIn=amountIn, amountOut, recipient=hook, pretransferred, block.timestamp)
settle net deltas per pattern-copied BaseTokenWrapperHook order
```

### 7.4 FactoryService salt

```solidity
// only in UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService
salt = abi.encodePacked(namespace, poolManager, standardExchange, underlying, mineNonce)._hash();
// empty namespace → DEFAULT_SALT_NAMESPACE
```

### 7.5 Interest test method (D52 / D61)

1. Seed Morpho vault + SE with real deposits.  
2. Record `previewUnwrap(seAmount)`.  
3. Advance time + drive **real** Morpho interest path (Crane Morpho TestBase helpers OK).  
4. Assert `previewUnwrap(seAmount) >` pre-accrual.  
5. **Forbidden:** `vm.store` / balance deal solely to fake claim growth.

---

## 8. Testing inventory summary

### 8.1 SE (minimum)

| Suite | Focus |
|-------|-------|
| Routes | SE1–SE4 matrix; preview == exec |
| Fees | D24a mint dilution; D42 exit clean |
| VaultTokens | Membership; cuts; Target extract |
| Dust/Zero | D50/D66/D71/D74/D69 |
| Interest | Real accrual claim ↑ |
| Fork | sfrxETH retain; Morpho where available |

### 8.2 Hook (minimum)

| Suite | Focus |
|-------|-------|
| Deploy | Flags, idempotency, multi-namespace, collision, validation |
| Routes | Four V4 swaps; fee-aware mint; exact take |
| Interest | Strict increase unwrap |
| InitGuards | fee≠0, wrong pair, addLiquidity |
| Fork RH/Base | Pinned vault smoke |

### 8.3 Production-first rules

| Allowed | Forbidden |
|---------|-----------|
| Real SE DFPkg + registry deploy | Mock SE / mock hook SUT |
| Crane Morpho + Uni V4 ports | `vm.mockCall` on SUT |
| Mintable ERC20 only as non-SUT funding | Fake Standard Exchange for lifecycle |
| Reentrancy hostile ERC20 for attack tests only | Etch-only production addresses for deploy DoD |
| Real accrual helpers | Claim-growth cheats (D52) |

### 8.4 Suggested forge commands

```bash
# SE
forge test --match-path 'test/foundry/spec/vaults/standard/erc4626/*' -vv
forge test --match-contract ERC4626StandardExchange -vv

# Hook hermetic
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/single/**' -vv

# Fork (profiles as repo defines)
FOUNDRY_PROFILE=robinhood_main forge test --match-path 'test/foundry/fork/robinhood_main/**/UniswapV4SingleStandardExchangeBufferPricingHook*' -vv
FOUNDRY_PROFILE=base_main forge test --match-path 'test/foundry/fork/base_main/**/UniswapV4SingleStandardExchangeBufferPricingHook*' -vv
```

---

## 9. Definition of done (program)

Matches PRD §14. Ship gate when **all** hold:

1. User can swap U ↔ SE on Uni V4 (exact-in + exact-out both ways) with correct balances.  
2. After real Morpho interest, same SE amount quotes/delivers **strictly more** underlying.  
3. Hook deploys via existing create3Factory + FactoryService mine; idempotent; multi-namespace; collision/exhaustion reverts.  
4. Permission bits match BaseTokenWrapperHook set; full pattern-copy; Repo currency order; deadline = now.  
5. Works with fixed generic ERC-4626 SE; no Morpho-specific SE; no DETF coupling.  
6. Preview == execution on four routes with non-zero mint usage fee; unwrap no exit fee.  
7. Exact-out never burns full max by default; exact take; dust/Slippage/zero laws.  
8. No CL; fee=0; test pool tickSpacing 60 + 1:1 mid.  
9. SE §6.0 complete first (D63); vaultTokens via Targets + both cuts.  
10. RH pin Morpho-official/curated WETH Vault V2 before P0 fork DoD.  
11. No open product/implementor questions (PRD §13).

---

## 10. Anti-patterns (do not ship)

| Anti-pattern | Why |
|--------------|-----|
| `new UniswapV4SingleStandardExchangeBufferPricingHook` | CREATE3 + mine required |
| Second CREATE3 factory | PRD D19/D20 |
| Bare `HookMinerCreate3.find` / `findWithPrefix` as product entry | Breaks D37 |
| Inherit `BaseTokenWrapperHook` / `BaseHook` / `DeltaResolver` | D51/D67 |
| Hook-local Morpho / convertToAssets NAV | D5 |
| Burn `maxAmountIn` as default exact-out | D38 |
| Absorb under-delivery as dust | D69 |
| Usage fee skim from user shares | D40 |
| Exit usage fee in v1 | D42 |
| Public `wrapZeroForOne()` | D73 |
| Permit2 on hook v1 | D31 |
| Facet/DFPkg for hook instance | D15 |
| Rework first-deposit protection in §6.0 | D48 |
| Import Uni V4 DETF TestBases | D64 |
| Full Camelot/Aero rewrite for MultiAsset extract | D41/D54 |
| TVL-scanned Morpho vault as sole pin | D72 |
| Claim-growth `vm.store` for interest DoD | D52 |

---

## 11. PR / sequencing recommendation

| PR | Contents | Gate |
|----|----------|------|
| **PR-SE-1** | MultiAsset Targets + DFPkg Standard cut + vaultTokens tests | VT* green; build green |
| **PR-SE-2** | Common fee/dust/zero + Out routes + In unwrap | §6.0.C checklist |
| **PR-HOOK-1** | Hook scaffold + FactoryService + deploy tests | HD* green |
| **PR-HOOK-2** | Target swaps + hermetic four routes + interest | §10.1 green |
| **PR-FORK** | RH pin + RH/Base fork smokes | P4 green |

Prefer **SE-first stack** (D63). Mixed mega-PR allowed only if CI still gates SE suite before hook DoD claims.

---

## 12. Open questions

**None** for product/implementor-edge law — see PRD §13.

**Operational (resolve during P4.0, not PRD reopen):**

1. Exact Morpho-official WETH Vault V2 address for Robinhood main.  
2. Exact Morpho-official/curated WETH Vault V2 for Base.  
3. Foundry profile names if they differ from `robinhood_main` / `base_main` in live `foundry.toml`.

---

## Changelog

| Date | Change |
|------|--------|
| 2026-08-03 | **Move + rename under `single/`:** package path `contracts/hooks/uniswap/v4/standardExchange/single/`; product `UniswapV4SingleStandardExchangeBufferPricingHook`; salt `"uv4-single-se-buffer-pricing-hook-"`; storage id `"indexedex.hooks.uv4.single.se.buffer.pricing.storage"`; Deploy-test override `"uv4-single-se-buffer-pricing-hook-test-"`; hermetic tests under `test/.../standardExchange/single/`. Dual package untouched. |
| 2026-08-02 | Initial implementation + test plan from locked PRD D1–D74; gap audit of ERC-4626 Out/In, MultiAsset cuts, fee absence |
