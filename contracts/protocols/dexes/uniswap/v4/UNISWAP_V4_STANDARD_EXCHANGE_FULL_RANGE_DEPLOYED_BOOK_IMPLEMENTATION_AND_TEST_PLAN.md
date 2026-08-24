# Implementation & Test Plan: Uniswap V4 SE — Full-Range Deployed Book + Multi Join/Exit

**Status:** Implemented (phases 1–6 coded; hermetic v4 spec suite green)  
**Date:** 2026-08-23  
**Product law (normative):** [`UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md`](./UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md) (**v1.2**, D30–D52)  
**Sleeve law (normative, do not reopen):** [`UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md`](./UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md) (D1–D29)  
**Sleeve coding plan:** [`UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md)  
**Bring-up plan (historical):** [`UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md`](./UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md)  
**Package path:** `contracts/protocols/dexes/uniswap/v4/`

This document is the **coding plan**. Do not re-open locked PRD decisions without a PRD revision. When product text and this plan conflict, **the PRD wins**.

Do not implement Uni v3 / Slipstream Multi facets in this epic (D51). Do not recast ticks. Do not add rebalance swaps (D28).

---

## 0. Mission (one sentence)

Put this vault’s **deployed** inventory in a **single full-range** Uniswap v4 position (always in range, keep the 20% sleeve), and add **exact-in dual join** / **exact-out dual proportional exit** via `IStandardExchangeInMulti` / `IStandardExchangeOutMulti` without removing existing single-token `IStandardExchange` zaps.

---

## 1. Authority & constraints

| Layer | Role |
|-------|------|
| Full-range PRD v1.2 | Product law D30–D52 |
| Liquid-buffer PRD | Sleeve / lock D1–D29 |
| **This plan** | Phases, files, algorithms, test matrix, DoD |
| `crane-testing` / `indexedex-testing` | Production-first: CREATE3 facets, `indexedexManager.deployUniswapV4StandardExchangeDFPkg`, `pkg.deployVault`; no mock SUT |
| Foundry | Default hermetic `forge test`. **`via_ir` forbidden.** Forge patience: first compile can take tens of minutes; do not kill. |

### Hard rules

1. Never `new` facets/DFPkgs. CREATE3 + FactoryService + registry `deployPkg`.
2. Never mock vault / manager / registry / fee oracle / PoolManager as SUT.
3. Existing `IStandardExchangeIn` / `Out` selectors stay. Multi is **new cuts**.
4. Multi arrays: **exactly two pool currencies**, address-sorted, amounts > 0. Length 1 reverts.
5. Dual **exit** proportional only (`S0 == S1`). Unbalanced exit reverts. No token0↔token1 swap on Multi.
6. Dual **join** may be unbalanced. User pays both `amountsIn` in full. Surplus stays sleeve.
7. Sleeve-then-deploy-excess (D27). Idle amount-out / dual exit uses PoolManager even if sleeve covers (D3). Preview ignores rebalance (D24).
8. `widthMultiplier` stays on `deployVault` (`>= 1`) and does **not** size ticks.
9. Do not implement `IStandardExchangeMultiAssetLiquidity`.
10. Account for premature in-tree edits (PRD §9): finish or rewrite them against this law; they are not DoD.

---

## 2. Current state (baseline)

| Area | Today (including premature edits) | Required after this work |
|------|-----------------------------------|--------------------------|
| Tick derive | Premature pass may already use `minUsableTick` / `maxUsableTick`; historical law was `widthMultiplier` ± center/wings | **D30:** one full-range center only |
| Liquidity plan | Premature: 100% center budgets; historical 10/90 wings | 100% deployable to center; **do not create wings** |
| Position create | Premature: center only | Center only; wing storage slots may remain unused |
| Routes_Test tick helpers | Still reconstruct center+wings from `widthMultiplier` | Full-range center only |
| Multi ABI | Interfaces exist; Out file misspelled `IStandaardExchangeOutMulti.sol` | Renamed file; facets cut; ERC165 |
| Join/exit dual | Only single-token zap | `exchangeInManyToOne` / `exchangeOutOneToMany` |
| Sleeve | D1–D29 implemented (buffer plan) | Unchanged |

Treat premature Common/Repo edits as **draft**. Phase 1 re-reads them against D30–D35 and either keeps or rewrites.

---

## 3. Target architecture

```text
IStandardExchangeIn / Out          IStandardExchangeInMulti / OutMulti
  one pool token ↔ shares            exactly two pool tokens ↔ shares
  zap-out MAY swap other token       NO swap
  length-1 only                      length === 2, sorted addresses
                                     join: unbalanced OK
                                     exit: S0 == S1 or revert
                │                              │
                └──────────┬───────────────────┘
                           ▼
              sleeve-then-mint / burn (D9/D13/D27)
                           │
              idle: tail-rebalance add/remove L
                    on FULL-RANGE center only
              blocked: no unlock; join stays sleeve;
                       exit pays from free of BOTH tokens
```

### 3.1 Module split

| Module | Responsibility |
|--------|----------------|
| `UniswapV4PositionRepo` | `widthMultiplier >= 1` ABI-only; `activeLiquidityBps = 10000`; wing salts unused |
| `UniswapV4StandardExchangeCommon` | Full-range `_deriveManagedTicks`; center-only create/deploy/refill; D52 `S0`/`S1`; dual-token sort/validate helpers |
| Existing In/Out | Unchanged routes |
| **New** In Multi Target + Query Target + Facets | `exchangeInManyToOne` / `previewExchangeInManyToOne` |
| **New** Out Multi Target + Query Target + Facets | `exchangeOutOneToMany` / `previewExchangeOutOneToMany` |
| DFPkg / FactoryService / TestBase | Four new CREATE3 facets + `PkgInit` fields + ERC165 |
| Interfaces | Rename Out Multi file; fix NatSpec (D39/D40) |

Delegates: **do not** add InMulti/OutMulti CREATE3 delegates in Phase 2. Add only if Phase 3/4 hits stack-too-deep (mirror existing In/Out).

---

## 4. Concrete APIs

### 4.1 Interface file (D39 / D40)

1. `git mv` `contracts/interfaces/IStandaardExchangeOutMulti.sol` → `contracts/interfaces/IStandardExchangeOutMulti.sol`.
2. Keep `interface IStandardExchangeOutMulti`.
3. Rewrite NatSpec to exact-out: preview takes `tokensOut` + `amountsOut`, returns **shares** `amountIn`. Execute returns **`uint256 amountIn`** (shares burned). Do not change signatures.

### 4.2 Validation helper (shared, Common or Multi base)

```text
_requireDualPoolCurrencies(address[] tokens):
  require length == 2
  require tokens[0] < tokens[1]          // strictly ascending
  require tokens[0] == token0 && tokens[1] == token1
        // V4 PoolKey is already address-sorted, so this is the only valid pair
```

Amounts: each `> 0`. `tokenOut` on join = `address(this)`. `tokenIn` on exit = `address(this)`. Else `ExchangeInNotAvailable` / `ExchangeOutNotAvailable`.

### 4.3 D52 share burns

Use rounding-up muldiv (Uniswap `FullMath.mulDivRoundingUp` or Crane equivalent). Do **not** use overflowing `amount * supply`.

```text
if (total0 == 0 || total1 == 0 || supply == 0) revert
S0 = mulDivRoundingUp(amount0, supply, total0)
S1 = mulDivRoundingUp(amount1, supply, total1)
if (S0 != S1) revert   // unbalanced exit
if (S0 > maxAmountIn) revert  // ME5; TooMuchInput / existing Out insufficient-input
S = S0
```

Preview uses the same `S` and **does not** simulate tail-rebalance (D24). Blocked preview still requires D52; if free of either token `< amountsOut[i]`, preview reverts `InsufficientLocalReserve` (same as exec).

### 4.4 Join algorithm (`exchangeInManyToOne`)

```text
1. deadline / not-disabled / dual-pool validate
2. Map amountsIn[0]→amount0, amountsIn[1]→amount1 (token order is currency0, currency1)
3. Pull both via _secureTokenTransfer (D49). Either pretransferred for BOTH or false for BOTH
   (single bool on the ABI). If pretransferred=true, both tokens must already be delivered.
4. sharesOut = _sharesOutForDeposit(amount0, amount1, supply, reserve0Before, reserve1Before)
   empty supply: amount0+amount1 (+ dead-share residual already on zap-in)
5. minAmountOut check (min shares)
6. mint to recipient; _syncVaultReserves
7. if canOpenPoolManagerUnlock(): _rebalanceLiquidReserveBestEffort()  // D11: must not revert mint
   else: LocalDepositWhileBlocked (optional; may emit twice or a dual variant — plan: emit once per token or skip extra events)
8. return sharesOut
```

Preview: steps 1–4 only (view: reserves are pre-deposit; do not assume tokens already pulled).

### 4.5 Exit algorithm (`exchangeOutOneToMany`)

```text
1. deadline / not-disabled / dual-pool validate / tokenIn == this
2. (total0, total1) = _totalVaultReserves(); supply = totalSupply
3. S = D52(amount0, amount1); require S <= maxAmountIn
4. Pull shares: _secureShareDelivery(maxAmountIn, pretransferred)
5. Blocked:
     require free0 >= amount0 && free1 >= amount1 else InsufficientLocalReserve
     burn S; send amount0 and amount1 to recipient
     refund leftover shares (maxAmountIn - S) to msg.sender
     sync; return S
6. Idle (D3, even if sleeve covers):
     remove L fraction S/supply from CENTER only (imported: center NFT)
     also the user is owed S/supply of free; combined inventory after remove >= amountsOut
     transfer exact amount0, amount1 to recipient
     burn S; refund leftover shares
     sync; _rebalanceLiquidReserveBestEffort(); return S
```

If after idle remove the vault cannot pay exact `amountsOut` (rounding): revert slippage / insufficient output. Proportional D52 plus remove of `S/supply` of L plus `S/supply` of free should cover; implementers must measure balances, not assume.

**Refund leftover shares** when `maxAmountIn > S` (assumed in PRD review; this plan locks it). Same as existing zap-out unused-share refund.

### 4.6 Errors

| Error | When |
|-------|------|
| `IStandardExchangeIn.ExchangeInNotAvailable()` | Bad join arrays / `tokenOut != shares` |
| `IStandardExchangeOut.ExchangeOutNotAvailable()` | Bad exit arrays / `tokenIn != shares` **or unbalanced exit (`S0 != S1`)** |
| `UniswapV4Exchange_InsufficientLocalReserve` | Blocked exit short on either token |
| `UniswapV4Exchange_PoolManagerInteractionBlocked` | Not used for Multi join (join works blocked). Idle-only paths that wrongly unlock: existing guard. |
| Existing deadline / slippage / zero / too much input / disabled | Unchanged |

Do **not** invent a second unbalanced-exit error unless Out already has a clearer selector; default `ExchangeOutNotAvailable`.

### 4.7 Facet selectors

| Facet | `facetInterfaces` | `facetFuncs` |
|-------|-------------------|--------------|
| `UniswapV4StandardExchangeInMultiFacet` | `IStandardExchangeInMulti` | `exchangeInManyToOne` |
| `UniswapV4StandardExchangeInMultiQueryFacet` | `IStandardExchangeInMulti` | `previewExchangeInManyToOne` |
| `UniswapV4StandardExchangeOutMultiFacet` | `IStandardExchangeOutMulti` | `exchangeOutOneToMany` |
| `UniswapV4StandardExchangeOutMultiQueryFacet` | `IStandardExchangeOutMulti` | `previewExchangeOutOneToMany` |

`nonReentrant` on mutate. Query facets view-only, no unlock.

In Facet currently also cuts `unlockCallback`. **Do not** duplicate `unlockCallback` on Multi facets (already on In Facet).

---

## 5. Full-range book (D30–D35)

### 5.1 Ticks

```solidity
int24 spacing = UniswapV4PoolKeyAwareRepo._tickSpacing();
centerLower = TickMath.minUsableTick(spacing);
centerUpper = TickMath.maxUsableTick(spacing);
```

Do not use `widthMultiplier` / `centerWidthMultiplier` in tick math. NatSpec on `_deriveManagedTicks` and `rebalanceLiquidReserve`: deployed book is full-range; rebalance does not move ticks; sleeve is lock-safe free inventory.

### 5.2 Create / plan / rebalance

- `_createManagedPositionsIfNeededCommon`: **Center only**.
- `_managedLiquidityBudgets`: `centerBudget* = available*`; wing budgets 0.
- `_managedLiquidityPlanAtState`: **only** `_setCenterPlan`. Stop calling lower/upper wing plan setters (PRD open item 1: **delete those call sites**; wing `PositionKind` + storage salts stay so slots do not move).
- `_deployExcessLiquidity`: add center if `centerLiquidity > 0`; skip wing unlocks.
- `_refillDeficitLiquidity`: burn center (and imported center) only.
- `_burnPositionLiquidity` on zap-out may still loop kinds; wings with `!created` / L=0 no-op. Optional cleanup: zap-out burns center only.

Imported: do not rewrite NFT ticks (D34). Rebalance add/remove on imported range only.

### 5.3 Repo init

Keep `require(widthMultiplier_ >= 1)`. Set `activeLiquidityBps = MAX_BPS` (10000). Comment: ABI-only width; 100% center.

---

## 6. File impact map

### 6.1 Production

| File | Work |
|------|------|
| `contracts/interfaces/IStandaardExchangeOutMulti.sol` | Rename to `IStandardExchangeOutMulti.sol`; NatSpec D40 |
| `UniswapV4PositionRepo.sol` | Init / comments D30–D31 |
| `UniswapV4StandardExchangeCommon.sol` | Ticks, budgets, create, D52 helper, dual-token validate, NatSpec |
| `UniswapV4StandardExchangeInBase.sol` | Zap-out may burn center only; no behavior change required if wings L=0 |
| **New** `UniswapV4StandardExchangeInMultiTarget.sol` | Mutate join |
| **New** `UniswapV4StandardExchangeInMultiQueryTarget.sol` | Preview join |
| **New** `UniswapV4StandardExchangeInMultiFacet.sol` | IFacet |
| **New** `UniswapV4StandardExchangeInMultiQueryFacet.sol` | IFacet |
| **New** `UniswapV4StandardExchangeOutMultiTarget.sol` | Mutate exit |
| **New** `UniswapV4StandardExchangeOutMultiQueryTarget.sol` | Preview exit |
| **New** `UniswapV4StandardExchangeOutMultiFacet.sol` | IFacet |
| **New** `UniswapV4StandardExchangeOutMultiQueryFacet.sol` | IFacet |
| `UniswapV4StandardExchangeDFPkg.sol` | `PkgInit` +4 facets; `facetCuts` 11→15; `facetInterfaces` +2; `facetAddresses` |
| `UniswapV4_Component_FactoryService.sol` | CREATE3 deploy* + `buildArgs*` params |
| Manager typed `deployUniswapV4StandardExchangeDFPkg` if it lists facets | Pass new facets (search `buildArgsUniswapV4StandardExchangePkgInit` call sites) |
| `interfaces/IUniswapV4StandardExchangeLiquidReserve.sol` | NatSpec already notes full-range; keep consistent |

Optional later: InMulti/OutMulti execution delegates if stack-too-deep.

### 6.2 Tests

| Path | Work |
|------|------|
| `contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol` | Deploy 4 Multi facets; extend `buildArgs` / `setUp` |
| `UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol` (peer) | Four new `*_IFacet_Test.t.sol` for Multi facets |
| `UniswapV4StandardExchangeDFPkg_Deploy.t.sol` | Assert new interface ids on vault; `widthMultiplier` still stored |
| `UniswapV4StandardExchangeRoutes_Test.t.sol` | `_vaultManagedTicks` → min/max usable; fee growth on **center only** |
| `UniswapV4StandardExchange_LocalLiquidBuffer.t.sol` | Must stay green; no wing assertions |
| **New** `UniswapV4StandardExchange_FullRangeBook.t.sol` | FR1–FR6 |
| **New** `UniswapV4StandardExchange_MultiJoinExit.t.sol` | MJ1–MJ6, ME1–ME5 |
| Adversarial secure-pull suite | MJ5 on Multi join (or extend `Adversarial_UniswapV4SE_SecurePull.t.sol`) |

Hermetic gold path only. No `FOUNDRY_PROFILE` other than default unless already used by this tree.

### 6.3 Docs

| File | Work |
|------|------|
| This plan | Living checklist |
| Full-range PRD | Related row points here (v1.2 already names this file) |
| Vault bring-up plan | Tick Range Plan already D30; confirm |
| Buffer impl plan §5.2 | Deploy center only (may already say so) |

---

## 7. Algorithms (normative for implementors)

### 7.1 Map Multi arrays to token0/token1

After `_requireDualPoolCurrencies`:

```text
amount0 = amounts[0]; amount1 = amounts[1];
// tokens[0] == currency0, tokens[1] == currency1
```

Do not accept `{token1, token0}` even if amounts would match; unsorted **reverts** (D41/D42).

### 7.2 Proportional join amounts (tests MJ2)

Empty vault: any `amount0 > 0`, `amount1 > 0`.

Non-empty:

```text
amount1 = amount0 * total1 / total0   // floor
// if amount1 == 0, bump amount0 until both > 0
```

That is **vault total ratio**, not `LiquidityAmounts` at spot (D44). After rebalance, leftover vs sleeve deadband is allowed if totals were skewed.

### 7.3 Idle exit inventory

Burning `S` shares entitles the user to `S/supply` of **each** `total_i`. D52 guarantees `ceil(amount_i * supply / total_i) = S` for both i, so `S * total_i / supply >= amount_i`.

Implementation order (idle):

1. Record free and position balances.
2. Remove `floor(S * centerL / supply)` liquidity (imported: decrease NFT).
3. `pay_i = amountsOut[i]`; require `balanceOf(token_i) >= pay_i` after remove (include pre-existing free).
4. Transfer `pay_i` to recipient.
5. Burn `S` shares; refund extra shares; sync; tail-rebalance.

Do **not** swap leftover of the other token to the recipient.

### 7.4 Blocked dual exit

No remove L. `free_i >= amountsOut[i]` for both. Burn S, transfer both, refund extra shares. D52 still applies (cannot take an unbalanced mix from the sleeve via Multi).

---

## 8. Phased delivery

Each phase ends with **compile + listed tests green**. Do not start the next phase red unless blocked by a PRD gap.

### Phase 0 — Spec freeze (this document)

- [x] PRD v1.2 D30–D52 locked  
- [x] This implementation plan authored  

**Exit:** product + plan authority clear.

---

### Phase 1 — Interface rename + full-range book (D30–D35, D39–D40)

**Status:** done.

**Goal:** New managed positions are one full-range center; Out Multi file name/NatSpec correct; existing buffer/route tests still mean the same sleeve law.

**Tasks:**

1. Rename `IStandaardExchangeOutMulti.sol`; fix NatSpec; grep all imports.
2. Reconcile `UniswapV4PositionRepo` / `Common` with §5 (ticks, budgets, create center only, no wing plan calls).
3. NatSpec on derive/rebalance/liquid-reserve.
4. Fix `Routes_Test` tick/fee helpers to full-range center only.
5. Run: `UniswapV4StandardExchangeRoutes_Test`, `UniswapV4StandardExchange_LocalLiquidBuffer`, `*_LocalLiquidBuffer_H2`, DFPkg deploy, existing IFacet tests.

**Exit:** Idle dual-token zap-in (existing single zaps in sequence) can create L on min/max ticks; wings not created; T1–T16 still pass.

**Risk:** Routes_Test fee-growth helpers summing wings will fail until pointed at center only.

---

### Phase 2 — Facet scaffold + DFPkg cuts (D48)

**Status:** done.

**Goal:** Diamond exposes Multi selectors (may still revert `Exchange*NotAvailable` if logic not filled; prefer wiring real Targets in the same phase if small).

**Tasks:**

1. Four Facets + four Targets (query vs mutate).
2. FactoryService `deployUniswapV4StandardExchangeInMultiFacet` (etc.).
3. `PkgInit` + `facetCuts` + `facetInterfaces` + `facetAddresses`.
4. `TestBase_UniswapV4StandardExchange.setUp` deploys and passes new facets into `buildArgs*`.
5. Four `TestBase_IFacet` suites (CREATE3, no manager required for IFacet tests).
6. DFPkg deploy spec: vault `supportsInterface` InMulti + OutMulti; existing In/Out still true.

**Exit:** New vault from registry has 15 facet cuts; IFacet metadata green.

---

### Phase 3 — Dual join (D41, D43–D47, D49)

**Status:** done.

**Goal:** `exchangeInManyToOne` / preview.

**Tasks:**

1. Validation + pull + `_sharesOutForDeposit` + mint + tail-rebalance.
2. Preview parity for **user-returned shares** (D24).
3. Tests MJ1–MJ6 (blocked via existing `PoolManagerUnlockSeCaller`; extend harness if Multi needs a `runExchangeInManyToOne`).

**Exit:** MJ2 idle proportional join produces full-range L and ~20% sleeve; MJ1 length≠2 reverts; MJ5 I1 holds.

---

### Phase 4 — Dual proportional exit (D42, D45, D52)

**Status:** done.

**Goal:** `exchangeOutOneToMany` / preview.

**Tasks:**

1. D52 helper in Common; used by preview and exec.
2. Idle remove + exact pays; blocked sleeve cover; share refund.
3. Tests ME1–ME5. Preview == exec for `amountIn` (shares) under the same gate.

**Exit:** Proportional dual exit delivers both tokens; unbalanced reverts with no balance change; blocked short reverts whole tx.

---

### Phase 5 — Full-range book tests (FR1–FR6)

**Status:** done.

**Goal:** Range law independent of Multi, plus import.

**Tasks:**

1. `UniswapV4StandardExchange_FullRangeBook.t.sol` on the same TestBase.
2. FR2: external swapper (copy `UniswapV4ExternalSwapper` from Routes_Test) walks price; assert `tickLower < tick < tickUpper`; fee growth or total reserves increase.
3. FR3: after FR2, `rebalanceLiquidReserve`; ticks unchanged; sleeve deadband.
4. FR4: blocked single `exchangeIn` then idle rebalance onto **same** full-range ticks.
5. FR5: single-token first mint L may be 0; second token + rebalance mints L.
6. FR6: import path if TestBase already binds PositionManager; otherwise skip with explicit comment **only if** import tests already live elsewhere and this file cannot mint an NFT without new infra. Prefer implement FR6 if import suite exists (`UniswapV4StandardExchangePositionImport*`).

**Exit:** FR1–FR6 green (FR6 waived only if import TestBase gap is documented in the test file header).

---

### Phase 6 — Docs + DoD checklist

**Status:** done.

1. Vault-plan tick paragraph already D30; confirm.
2. Buffer impl plan deploy-excess “center only”.
3. NatSpec sweep D21 + D30 + Multi.
4. Mark this plan phases done.

**Exit:** PRD §7.4 DoD items 1–7 true.

---

## 9. Test matrix (IDs)

Gold: `TestBase_UniswapV4StandardExchange` → manager DFPkg → `deployVault(poolKey, widthMultiplier)` (`widthMultiplier = 60` or `1` is fine; ignored for ticks).

Production-first. No mock SUT.

### 9.1 Existing (must remain green)

| Suite | Note |
|-------|------|
| LocalLiquidBuffer T1–T16 + H1/H2 | Sleeve law |
| Routes_Test | Tick helpers full-range |
| DFPkg_Deploy | + Multi interface ids |
| In/Out/Import/LiquidReserve IFacet | Unchanged |
| Adversarial E6 / SecurePull | Single-token still; add MJ5 |

### 9.2 Full-range (FR)

As PRD §7.2 FR1–FR6.

### 9.3 Multi join (MJ) / exit (ME)

As PRD §7.2 MJ1–MJ6, ME1–ME5.

Additional (this plan, not new product):

| ID | Assertion |
|----|-----------|
| MJ7 | Preview join shares == exec shares (idle and blocked); free/deployed may differ after idle exec |
| ME6 | Preview exit shares == exec shares (idle and blocked) |
| ME7 | `maxAmountIn > S` refunds unused shares to `msg.sender` |
| MJ8 | `tokenIn` `[token1, token0]` (descending) reverts even if both pool tokens |

---

## 10. Definition of done

Copied from PRD §7.4, operationalized:

1. New managed (non-imported) vaults: one full-range center; wings not created / L=0.
2. Idle ops: sleeve ~20% within D22 deadband.
3. Existing In/Out blocked nested behavior unchanged.
4. FR1–FR6, MJ1–MJ6, ME1–ME5, MJ7–MJ8, ME6–ME7, buffer T1–T16, Routes_Test green on gold deploy path.
5. NatSpec D30–D35, D39–D52.
6. Diamond cuts InMulti + OutMulti mutate and preview; existing In/Out still work.
7. Out Multi file is `IStandardExchangeOutMulti.sol`.

---

## 11. Plan-level resolutions of PRD §10 open items

| Open item | Resolution |
|-----------|------------|
| Wing plan functions | Remove call sites from `_managedLiquidityPlanAtState`. Leave `PositionKind` + wing storage. |
| Test file split | FR* in `UniswapV4StandardExchange_FullRangeBook.t.sol`; MJ/ME in `UniswapV4StandardExchange_MultiJoinExit.t.sol`; buffer suite stays. |
| `_snapTick` | Do not reintroduce unless import/quote needs it. |
| Multi delegates | None unless stack-too-deep in Phase 3/4. |

---

## 12. Suggested forge commands

```bash
# After Phase 1
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeRoutes_Test.t.sol
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_LocalLiquidBuffer.t.sol

# After Phase 2
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiFacet_IFacet_Test.t.sol
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg_Deploy.t.sol

# After Phase 3–5
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol
forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_MultiJoinExit.t.sol
```

First compile in a worktree: seed `cache_forge/` + `out/` from a warm checkout; set tool timeouts to hours, not minutes.

---

## 13. Out of scope (do not sneak in)

- Recast / JIT / D28 carve-out
- Multi on Uni v3 / Slipstream
- `IStandardExchangeMultiAssetLiquidity`
- Merging Multi into `IStandardExchange`
- Native ETH
- Live-book migration of old center+wings vaults
