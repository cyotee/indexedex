# PRD: Uniswap V4 Standard Exchange — Full-Range Deployed Book (Keep Liquid Sleeve)

**Name:** Uniswap V4 Standard Exchange full-range deployed book  
**Date:** 2026-08-23  
**Status:** **Draft v1.2 — product law for planning**  
**v1.1:** Additive `IStandardExchangeInMulti` / `IStandardExchangeOutMulti` facets. Existing `IStandardExchangeIn` / `IStandardExchangeOut` stay.  
**v1.2:** Dual Multi is **exactly two pool currencies** (no length-1 alias). Dual **exit** is proportional-only (unbalanced reverts). “Proportional” = vault `total_i` ratio. This vault is family gold; other SEs copy later.  
**Process:** Product law. Implementors use the co-located implementation and test plan. Do not treat in-tree code as accepted until that plan’s DoD is met.  
**Package path:** `contracts/protocols/dexes/uniswap/v4/`  
**Package kind:** Production change to the existing **Uniswap V4 Standard Exchange** vault (multi-asset SE shares over one managed V4 position + local ERC-20 sleeve).

**Related (do not conflate):**

| Artifact | Role |
|----------|------|
| [`UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md`](./UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md) | **Sleeve / PoolManager lock product law** (D1–D29). This PRD does **not** reopen those gates. |
| [`UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md) | Sleeve coding plan. Range geometry is out of that plan’s job except as it consumes D30. |
| [`UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md`](./UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md) | Original bring-up plan (one canonical position, zap routes, manager deploy). |
| [`UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_IMPLEMENTATION_AND_TEST_PLAN.md) | **Coding plan** — phases, file map, algorithms, test matrix, DoD. |
| Uni v3 SE / Slipstream SE | Same historical 10/90 center+wings pattern. **Out of scope.** |
| [`IStandardExchangeInMulti.sol`](../../../../interfaces/IStandardExchangeInMulti.sol) | Exact-in many→one. Canonical join ABI. |
| [`IStandardExchangeOutMulti.sol`](../../../../interfaces/IStandardExchangeOutMulti.sol) | Exact-out one→many. File renamed from `IStandaardExchangeOutMulti.sol` (D39). |
| [`IStandardExchangeMultiAssetLiquidity.sol`](../../../../interfaces/IStandardExchangeMultiAssetLiquidity.sol) | **Do not implement** on this vault (D50). Different ABI (`joinProportional` / `exitProportional` / …). |

**Authority:**

| Layer | Role |
|-------|------|
| **This PRD (v1.2)** | Product law for **managed tick geometry**, **fee-exposure book**, and **Multi join/exit facets** |
| **Local liquid buffer PRD** | Product law for sleeve size, interaction gate, share math, D28 no rebalance swaps |
| **Implementation plan** | File list, algorithms, test matrix, DoD. PRD wins on product conflicts |

This PRD does **not** prescribe a coding sequence. That lives in the implementation plan.

---

## 0. Terminology (normative)

Terms from the liquid-buffer PRD apply. Additions and restatements:

| Term | Meaning |
|------|---------|
| **Sleeve / free inventory** | ERC-20 balances of the pool currencies on the vault diamond. Target fraction of **total** reserve via fee-oracle `liquidReservePercentageOfVault` (type default **20%**). Earns **no** Uniswap v4 swap fees. Required for nested `AlreadyUnlocked` safety. |
| **Deployed inventory** | Token0/token1 amounts locked in this vault’s Uniswap v4 position(s). |
| **Managed book** | Non-imported positions this vault creates on PoolManager (`owner = vault`, `salt` = center salt). |
| **Imported book** | A PositionManager NFT transferred in. Ticks come from the NFT. This PRD does not rewrite them. |
| **In range** | Current pool tick is strictly inside `[tickLower, tickUpper]`. Only in-range liquidity earns swap fees (Uniswap v3/v4). |
| **Full range** | `tickLower = TickMath.minUsableTick(tickSpacing)`, `tickUpper = TickMath.maxUsableTick(tickSpacing)`. Contains every tradable price for that spacing. |
| **Fee exposure (this PRD)** | **Time that deployed capital is in range**, so it can earn a pro-rata share of swap fees. Not the same as maximizing L per dollar at the current tick. |
| **Center** | The one managed position this PRD keeps. Historical name; it is no longer a tight band around first-deposit tick. |
| **Wings** | Historical lower/upper one-sided positions. This PRD forbids creating them and requires 0 liquidity if storage slots still exist. |
| **Join** | Pool currencies → vault shares. User pays **exact** `amountsIn` (`IStandardExchangeIn` / `InMulti`). |
| **Exit** | Vault shares → pool currencies. User demands **exact** `amountsOut` (`IStandardExchangeOut` / `OutMulti`). |
| **Proportional** | Dual amounts in the same ratio as current vault `total_i` (free + deployed), D44 / D52. |
| **Unbalanced join** | Dual exact-in amounts **not** in that ratio. User pays every `amountsIn[i]`; surplus stays vault free inventory (D45). |
| **Unbalanced exit** | Dual exact-out amounts **not** in that ratio. **Forbidden** (D45). Use existing single-token zap-out if the mix must change. |
| **Single-token zap** | Existing `IStandardExchangeIn` / `Out`: one pool token ↔ shares. Idle zap-out may swap the other pool token. **Unchanged.** |

---

## 1. Problem

### 1.1 What the vault does today (pre-this-PRD product)

The Uniswap V4 Standard Exchange:

1. Keeps a **policy sleeve** (~20% of each token’s total) so deposits and covered amount-out work while PoolManager is already unlocked.
2. Deploys the rest into Uniswap v4 concentrated liquidity.
3. Historically sized that CL book as **center + two wings**, frozen at first create:
   - Center: `centerWidthMultiplier = 2` → about **±1 `tickSpacing`** around the then-current tick.
   - Wings: outer envelope from `widthMultiplier`; **90%** of deployable token1 in the lower wing, **90%** of deployable token0 in the upper wing (`activeLiquidityBps = 1000`).
4. “Rebalance” moves **free ↔ deployed** on those **same ticks**. It does not recast the range.

Steady-state fee engine under that book, while price is still near the mint tick:

- ~20% of inventory is sleeve (no swap fees).
- ~72% of inventory is one-sided wings that are **out of range at mint**.
- ~8% is the tight center (high L per dollar **only while** price stays inside ±1 spacing).

If price walks away, the center goes idle the same way any neglected tight v4 position does. The vault still add/removes L on the dead ticks when topping the sleeve.

### 1.2 What “maximize fee exposure” was asking

Keep the sleeve. Change the **deployed** book so more of the ~80% that is allowed in the pool actually **earns fees**.

Uniswap v4 rule (unchanged): only in-range L earns, pro-rata to L at the ticks a swap crosses.

Two different maxima:

| Maximum | How | Cost |
|---------|-----|------|
| Fees **per dollar** while in range | Tight range on the current tick, recast when price leaves | Recast gas; after a trend, a two-sided mint needs both tokens (often a swap); D28 forbids rebalance swaps |
| **Time** in range | Range wide enough that tradable prices stay inside | Lower L density at spot; smaller share of each swap than a tight in-range center |

### 1.3 Locked product choice (operator)

Use the **protocol-maximum range** so the managed position is **always in range**. Do **not** recast ticks. Do **not** carve D28.

That is the time-in-range maximum. It is **not** the L-density maximum. Both are recorded here so later agents do not “fix” full range back into a tight recast book.

---

## 2. Goals

1. **Keep the liquid sleeve** exactly as the local-buffer PRD specifies: oracle `liquidReservePercentage`, type default 20%, D1–D29 (gate, deadband, sleeve-then-deploy, no rebalance swaps, share math on free+deployed, blocked vs free paths).
2. Put **all deployable inventory** (total minus target free, per token, best-effort under D28) into **one** managed Uniswap v4 position that is **full range** for the pool’s `tickSpacing`.
3. After first create, that position **stays in range** for every tradable price. No tick recast, no wing book.
4. Idle rebalance continues to add/remove L on **those** ticks only, to hold the sleeve target.
5. Public SE surface, DFPkg ABI `deployVault(PoolKey, uint24 widthMultiplier)`, and imported-NFT path stay compatible.
6. Existing **`IStandardExchangeIn` / `IStandardExchangeOut`** (single-token zap and direct pool swap) **stay** on the deployed diamond. Selectors, economics, and sleeve gates do not change.
7. Add **`IStandardExchangeInMulti` / `IStandardExchangeOutMulti`** facets so callers can **join and exit with both pool currencies in one call**: exact-in two tokens→shares (join), exact-out shares→two tokens (exit). Join may be unbalanced. Exit must be proportional to vault totals (D45/D52). Single-token zap stays on existing In/Out only.

### 2.1 Non-goals (v1)

1. Active market-making recast / recenter / JIT of ticks.
2. Any new token0↔token1 swap used to rebuild a two-sided book (D28 stays).
3. Maximizing L per dollar at the current tick (rejected in favor of always-in-range).
4. Changing sleeve percentage, deadband, or blocked/free gates.
5. Implementing Multi on Uni v3 / Slipstream / other SEs **in this epic** (D51). Those packages copy this law in their own PRDs later. Full-range book remains Uni V4-only.
6. Migrating **already created** vaults that froze a tight center+wings book. Geometry is init-time. No on-chain recast of live books.
7. Removing `widthMultiplier` from `deployVault` / `PkgArgs`.
8. Rewriting imported PositionManager ticks to min/max usable.
9. Native `address(0)` currency (buffer D26).
10. Joining an outer PoolManager unlock (buffer non-goal).
11. Implementing `IStandardExchangeMultiAssetLiquidity` (`joinProportional`, `exitProportional`, `joinUnbalanced`, single-asset aliases) on this vault.
12. Multi-in swap to a **pool** token (many pool tokens → one pool token) or one pool token → many pool tokens. Multi on this vault is **join/exit vs shares only** (D41–D42).
13. Merging Multi selectors into the existing In/Out facets, or extending `IStandardExchange` to include Multi.
14. Using a token0↔token1 swap inside Multi join/exit to force a ratio (D45). Single-token zap-out on the existing In/Out surface may still swap.

---

## 3. Design decisions (LOCKED for planning)

Sleeve decisions D1–D29 live in the liquid-buffer PRD. This table is **range / fee-exposure** law only.

| ID | Decision | Choice |
|----|----------|--------|
| **D30** | Managed range (non-imported) | **One** full-range position: `tickLower = TickMath.minUsableTick(tickSpacing)`, `tickUpper = TickMath.maxUsableTick(tickSpacing)`, salt = existing center salt (`bytes32(0)`). Wings are **not** created. If wing storage slots remain, they must report **not created** and **0 liquidity**. Ticks freeze at first create. No recast. |
| **D31** | `widthMultiplier` | Remains on `PkgArgs` / `deployVault` with `>= 1`. **Does not size ticks.** Historical `centerWidthMultiplier` and `activeLiquidityBps` are not operator knobs for this book. Allocation of deployable inventory is **100% to the full-range center**. |
| **D32** | In-range mint ratio | Full-range in-range L needs **both** tokens at the current price. `LiquidityAmounts.getLiquidityForAmounts` consumes the binding token. Leftover of the other token **stays free** (may push that token’s sleeve above target). No swap to absorb leftover (D28). |
| **D33** | First single-token mint | Shares mint against total reserves (buffer D9/D13). In-range L **may be 0** until the vault also holds the other pool currency. That is accepted. Do not recreate wings as a limit-order parking lot for the leftover. |
| **D34** | Imported positions | D15 unchanged: NFT ticks stay. Sleeve add/remove only. Import does **not** rewrite the NFT to full range. |
| **D35** | Rebalance vs ticks | Idle `rebalanceLiquidReserve` / tail-rebalance **must not** change `tickLower` / `tickUpper`. It only add/removes L on the existing full-range (or imported) ticks toward `targetFree_i`. |
| **D36** | Existing instances | Vaults already created with tight center+wings are **out of migration scope**. This law applies to **new** managed books (first `_createPositionIfNeeded` after the change). |
| **D37** | Fee accounting | Swap fees still accrue on the position and settle onto the diamond on `modifyLiquidity` (existing v4 behavior). They become free inventory, then tail-rebalance may deploy excess above the sleeve target into the **same** full-range ticks. No auto-compound special path. |
| **D38** | Testing | Production-first. No mock of vault, manager, registry, fee oracle, or PoolManager as SUT. Gold path: `indexedexManager.deployUniswapV4StandardExchangeDFPkg` then `pkg.deployVault(poolKey, widthMultiplier)`. |
| **D39** | Out Multi file name | Interface type is **`IStandardExchangeOutMulti`**. On-disk file is currently `contracts/interfaces/IStandaardExchangeOutMulti.sol` (typo). Implementation plan **renames** that file to `IStandardExchangeOutMulti.sol`. Do not change the Solidity type name. |
| **D40** | Out Multi preview NatSpec | **Signatures win.** `previewExchangeOutOneToMany(tokenIn, tokensOut, amountsOut) → amountIn` is an **exact-out** quote (shares required to pay the listed `amountsOut`). The comment that says it previews amountsOut from a given amountIn is wrong; correct NatSpec when touching the file. Execute returns **`amountIn`** (shares burned), not `amountsOut`. |
| **D41** | In Multi = join | `exchangeInManyToOne` / preview: `tokenOut` **must** be vault shares (`address(this)`). `tokenIn[]` is **exactly the two pool currencies**, unique, **strictly ascending by address**, `amountsIn.length == 2`, every `amountsIn[i] > 0`. Length 1, extra tokens, unsorted, duplicates, or `tokenOut != shares` → `ExchangeInNotAvailable` (or equivalent). |
| **D42** | Out Multi = exit | `exchangeOutOneToMany` / preview: `tokenIn` **must** be vault shares. `tokensOut[]` is **exactly the two pool currencies**, unique, strictly ascending, `amountsOut.length == 2`, every `amountsOut[i] > 0`. Length 1 or any other set → `ExchangeOutNotAvailable` (or equivalent). |
| **D43** | Existing single-token surface | **Keep** current In/Out facets as the **only** one-pool-token zap. Multi is never an alias of those routes. |
| **D44** | Proportional ratio | Dual amounts are proportional iff they match current vault **`total_i`** (free + deployed), not the Uniswap spot add-liquidity ratio. Same SoT as share math (D9). After a skewed sleeve this may leave leftover free on join (D32). |
| **D45** | Join unbalanced OK; exit unbalanced reverts | Multi **must not** swap token0↔token1. **Join:** user pays every `amountsIn[i]` in full; shares from `_sharesOutForDeposit` (dual-sided min-ratio; first mint `sum(amountsIn)`); surplus stays vault free inventory. **Exit:** both `amountsOut` must be proportional to `total_i` (D52). If not, **revert**. Do not over-burn and keep residual. Do not swap. Callers who want a different mix use existing single-token zap-out. |
| **D46** | Share math | Same SoT as D9/D13: totals = free + deployed. First Multi join at `totalSupply == 0`: shares = `sum(amountsIn)` (plus dead-share residual rule already on zap-in). Subsequent dual join: `ConstProdUtils._depositQuote` on the two added amounts vs pre-deposit totals. |
| **D47** | Sleeve / lock on Multi | Same gates as single-token. **Blocked join:** pull all `amountsIn`, mint shares, **no** `unlock`, no rebalance. **Blocked exit:** every `amountsOut[i]` fully covered by **free** balance of that token; else revert `InsufficientLocalReserve` (no partial pay). **Idle join:** mint first, then tail-rebalance (D27/D11). **Idle exit:** take inventory via PoolManager remove as needed (even if sleeve would cover — D3), pay exact outs, then tail-rebalance. Preview ignores post-op rebalance (D24). |
| **D48** | Facet layout | **New** facets, not merged into existing In/Out: `UniswapV4StandardExchangeInMultiFacet` + `InMultiQueryFacet` (mutate vs `previewExchangeInManyToOne`); `UniswapV4StandardExchangeOutMultiFacet` + `OutMultiQueryFacet`. Targets + CREATE3 `FactoryService`; `PkgInit` / diamond cuts / ERC165 `interfaceId`s. Follow existing In vs InQuery split. Delegates only if stack-too-deep. |
| **D49** | `pretransferred` / pull | Same I1 / `_secureTokenTransfer` law **per** listed pool token. All pulls succeed or the whole call reverts. `pretransferred=true` without delivery of every listed token must not mint from inventory (negative path). Shares on Out: same `_secureShareDelivery` as today. |
| **D50** | Not MultiAssetLiquidity | Do **not** cut `IStandardExchangeMultiAssetLiquidity` onto this vault. |
| **D51** | Family gold | D39–D50 and D52 are the **standard** Multi join/exit law for IndexedEx SEs. **This epic implements them only on Uni V4 SE.** Uni v3, Slipstream, and other SEs copy in their own PRDs later. Do not add Multi facets to those packages in the forthcoming Uni V4 plan. |
| **D52** | Dual-exit proportion check | Dual `amountsOut` is proportional iff the implied exact-out share burns match: `S0 = ceil(amount0 * supply / total0)`, `S1 = ceil(amount1 * supply / total1)` (zero total on a listed token → revert). Require **`S0 == S1`**. Burn that `S` (must be `<= maxAmountIn`). Pay the exact `amountsOut`. Integer dust that remains from floor remove stays in the vault. If `S0 != S1`, revert (unbalanced exit). |

---

## 4. Relationship to the sleeve

The sleeve and the full-range book are complementary, not substitutes.

```text
total_i = free_i + deployed_i
targetFree_i = total_i * liquidReservePercentageOfVault(this) / 1e18   // default 20%

idle:
  keep free_i ≈ targetFree_i (deadband D22)
  deployable_i = max(0, free_i - targetFree_i)  // deploy excess
  or remove L so free_i rises toward target

blocked (PoolManager already unlocked):
  never unlock
  deposits stay in sleeve
  amount-out from sleeve if covered, else revert
  no range work
```

Full range does **not** reduce the need for the sleeve. Nested hook `exchangeIn` still cannot open a second `unlock`. The 20% free inventory is still the nested cover.

Full range **does** mean that once capital is deployed, it keeps earning fees when the pool trades, instead of sitting OOR on a frozen tight center and idle wings.

---

## 5. Runtime (normative)

### 5.1 First managed create (interaction-free)

1. Derive ticks: `minUsableTick` / `maxUsableTick` for the bound pool’s `tickSpacing`.
2. Create **center only**.
3. Mint L from deployable amounts (excess above target free). Both tokens at spot ratio. Leftover of one token remains free.

### 5.2 Later idle ops

Same ticks. Add L on excess free; remove L on free deficit. Best-effort per token. Remove returns both tokens; a following pass may redeploy the other token’s overshoot into the same full-range position.

### 5.3 Price moves

No action on ticks. Position remains in range. Fees accrue. Next idle `modifyLiquidity` (rebalance or user zap) checkpoints fees onto the diamond.

### 5.4 Blocked ops

Unchanged from the liquid-buffer PRD.

### 5.5 Direct pool swaps

Unchanged: require idle; execute via PoolManager; tail-rebalance sleeve vs deployed. Not a recast tool.

### 5.6 Multi join / exit (`IStandardExchangeInMulti` / `IStandardExchangeOutMulti`)

House rule: **In** = user sets exact amounts paid; **Out** = user sets exact amounts received.

```text
Join  (In Multi):  tokenIn[] = exactly 2 pool currencies, sorted, amountsIn[] exact
                   tokenOut  = vault shares
                   return    = shares minted

Exit  (Out Multi): tokenIn     = vault shares
                   tokensOut[] = exactly 2 pool currencies, sorted, amountsOut[] exact
                   maxAmountIn = max shares to burn
                   return      = shares burned
```

**Proportional join (idle):** `amountsIn` in the same ratio as current `total_i` (empty vault: any dual amounts; first shares = sum). Mint shares. Tail-rebalance deploys excess of **both** into the full-range center. This is the bootstrap that actually creates in-range L in one call (unlike single-token zap-in).

**Unbalanced join:** same mint path. Dual-sided share quote uses min ratio. User still pays every listed `amountsIn`. Surplus token stays free. Tail-rebalance deploys what the spot ratio can take (D32/D45).

**Proportional exit (idle):** `amountsOut` pass D52 (`S0 == S1`). Burn that `S`. Remove that fraction of L (and the matching sleeve slice). Send both exact `amountsOut`. No swap.

**Unbalanced exit:** **revert**. No over-burn. No swap. Single-token mix changes stay on existing zap-out.

**Blocked:** join stays in sleeve (both tokens). Exit: D52 still required; both `amountsOut` fully covered by free of each token or the whole call reverts.

**Length ≠ 2:** revert. Existing `IStandardExchange` remains the only one-token zap, including the only path that **swaps** a residual pool token to produce a single `tokenOut`.

---

## 6. Rejected alternatives (do not revive without a new PRD)

| Alternative | Why rejected |
|-------------|--------------|
| Tight center, recast when OOR | Operator chose maximum range so the book is always in range; recast is a non-goal. |
| Recast + minimum abundant→scarce swap | Would raise L density after a trend; violates D28; not chosen. |
| Keep 10% center / 90% wings | That is the current fee-idle problem. |
| Wide-but-not-full range via `widthMultiplier` | Operator asked for maximum possible range. `widthMultiplier` stays ABI-only (D31). |
| Dip the sleeve of the scarce token to mint more in-range L | Nested amount-out cover of that token would go below policy. Sleeve target stays. |
| Apply the same book to Uni v3 / Slipstream SE in this change | Separate packages, separate PRDs. |
| Cut `IStandardExchangeMultiAssetLiquidity` or fold Multi into `IStandardExchange` | User locked InMulti/OutMulti as additive facets. |

---

## 7. Requirements for the later implementation plan

The implementation plan (not this file) must specify, at least:

### 7.1 Code surfaces (expected; plan may adjust after review)

| Area | Intent |
|------|--------|
| Tick derivation | `_deriveManagedTicks` (or successor) uses only `minUsableTick` / `maxUsableTick`. No `widthMultiplier` in the tick math. |
| Create | Center only. Do not `_createPositionIfNeeded` for wings. |
| Deploy excess | 100% of deployable budgets to center. Skip wing `modifyLiquidity` when L is 0. |
| Refill deficit | Burn center only (imported path unchanged). |
| Repo init | `widthMultiplier >= 1` preserved. Allocation constant consistent with 100% center. Wing salts may remain in storage so slots do not move. |
| NatSpec | Gate, rebalance, and tick derivation state: sleeve is lock-safe free inventory; deployed book is full-range; rebalance does not move ticks. |
| In Multi | `UniswapV4StandardExchangeInMultiFacet` / `InMultiQueryFacet` / Target(s). CREATE3 via `UniswapV4_Component_FactoryService`. `PkgInit` field + diamond cut. ERC165 `type(IStandardExchangeInMulti).interfaceId`. |
| Out Multi | Same pattern: `OutMultiFacet` / `OutMultiQueryFacet`. Rename `IStandaardExchangeOutMulti.sol` → `IStandardExchangeOutMulti.sol` (D39). Fix Out preview NatSpec (D40). |
| Existing In/Out | **Do not** remove cuts, selectors, or tests. |

### 7.2 Tests the plan must include (production-first)

Existing liquid-buffer T1–T16 and route suites must still pass, with tick helpers pointed at full range (not reconstructed center+wings).

New assertions (IDs for the later plan):

| ID | Assertion |
|----|-----------|
| FR1 | After first dual-sided deploy (or two single-sided deploys that jointly allow L), stored center ticks equal `minUsableTick` / `maxUsableTick` for the pool spacing; wings not created or L = 0 |
| FR2 | Move spot many spacings. Center still in range. A subsequent pool swap increases position fee growth and/or vault total reserves |
| FR3 | Public `rebalanceLiquidReserve` after FR2 still targets ~20% free per token within deadband; ticks unchanged |
| FR4 | Blocked `exchangeIn` still sleeve-only; later idle rebalance deploys excess into the **same** full-range ticks |
| FR5 | Single-token first mint: shares > 0; in-range L may be 0; depositing the other token then idle rebalance can mint full-range L |
| FR6 | Imported NFT: ticks unchanged; sleeve add/remove only; no rewrite to min/max |
| MJ1 | Length-1 (or length ≠ 2) `exchangeInManyToOne` reverts; existing `exchangeIn` zap-in still works |
| MJ2 | Dual proportional join (idle, `amountsIn` in `total_i` ratio): shares minted; after tail-rebalance, center L > 0 on full-range ticks; sleeve within deadband |
| MJ3 | Dual unbalanced join: both `amountsIn` pulled; shares = min-ratio quote; surplus token free increases; no token0↔token1 swap |
| MJ4 | Dual join while blocked: shares minted; no nested `unlock`; both amounts sit in sleeve; later idle rebalance deploys toward full-range |
| MJ5 | `pretransferred=true` on Multi join with no delivery: revert or zero shares; inventory unchanged (I1) |
| MJ6 | Unsorted / duplicate / non-pool `tokenIn`, or `tokenOut != shares`: revert |
| ME1 | Length-1 (or length ≠ 2) Out Multi reverts; existing shares→one-token Out still works |
| ME2 | Dual proportional exit (idle, D52): recipient gets both `amountsOut`; `S0 == S1`; ticks unchanged; tail-rebalance toward sleeve |
| ME3 | Dual unbalanced exit (`S0 != S1`): **reverts**; no tokens sent; no swap |
| ME4 | Dual proportional exit blocked: both free covers → pay; one short → whole tx reverts `InsufficientLocalReserve` |
| ME5 | `maxAmountIn` too low on proportional Out Multi: revert; no partial send |

Do not mock PoolManager, vault, manager, registry, or fee oracle as SUT.

### 7.3 Docs the plan must keep aligned

- This PRD (product law).
- Liquid-buffer PRD: range non-goal and D30/D31 remain consistent with this file (this file wins on range conflicts).
- Vault bring-up plan tick section: first deposit is full-range, not `widthMultiplier * tickSpacing` around spot.

### 7.4 Definition of done (for the later plan, not this PRD)

The change is done when:

1. New managed (non-imported) vaults create one full-range center and never mint wings.
2. Sleeve policy still holds on idle ops (default 20%, deadband).
3. Blocked nested deposit/amount-out behavior is unchanged on **existing** In/Out.
4. FR1–FR6, MJ1–MJ6, ME1–ME5, and existing buffer/route suites pass on the gold deploy path.
5. NatSpec matches D30–D35 and D39–D52.
6. Diamond cuts `IStandardExchangeInMulti` and `IStandardExchangeOutMulti` (mutate + preview). Existing `IStandardExchangeIn` / `Out` selectors still work.
7. Out Multi source file name is `IStandardExchangeOutMulti.sol`.

---

## 8. Economics (normative honesty)

Operators and later agents must not describe this as “max fee APR.”

- **Gained:** ~80% of inventory (the deployed part, when both tokens allow L) is **always** in range. Time earning fees on deployed capital goes to 100% of that slice. No recast gas. D28 intact. Nested sleeve intact.
- **Given up:** L at the current tick is far thinner than a tight in-range center. Share of each swap is smaller while a tight book would have stayed in range.
- **Still idle:** the ~20% sleeve, by policy. Leftover of one token that cannot mint dual-sided L, by D28/D32.
- **Join path that actually seeds L:** dual `exchangeInManyToOne` of both pool tokens. Single-token `exchangeIn` still mints shares but may leave L = 0 until the other token exists.

That is the intended trade.

---

## 9. Tree note (not DoD)

A premature coding pass may already have edited:

- `UniswapV4PositionRepo.sol`
- `UniswapV4StandardExchangeCommon.sol`
- liquid-reserve facet/interface NatSpec
- fragments of the liquid-buffer PRD, its impl plan, and the vault bring-up plan

Those edits are **not** an accepted implementation. They do not replace this PRD or the missing implementation plan. Reviewers accept or reject **this document** first. The later plan accounts for whatever is already in the tree (complete it, or rewrite it) against this law.

Do not expand that coding pass until the implementation plan exists.

---

## 10. Open items (not product forks)

These are plan-level, not PRD forks:

1. Whether unused `_setLowerWingPlan` / `_setUpperWingPlan` stay as dead internals or are deleted in the same change (behavior must remain 0 L either way).
2. Exact Foundry `--match-path` list and whether FR* live in `UniswapV4StandardExchange_LocalLiquidBuffer.t.sol` or a sibling file.
3. Whether `_snapTick` remains anywhere for imported or quote helpers.
4. Whether Multi mutate/query share CREATE3 delegates with existing In/Out delegates or get their own (stack-too-deep only).

No remaining product question on range width, recast, D28, Multi arity, dual-exit mix, or proportional SoT for v1.2 of this PRD.
