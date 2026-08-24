# PRD: Uniswap V3 Standard Exchange — Full-Range Deployed Book, Liquid Sleeve, and Multi Join/Exit

**Name:** Uniswap V3 Standard Exchange parity with Uni V4 SE (full-range book + sleeve + Multi)  
**Date:** 2026-08-24  
**Status:** **Draft v1.2 — product law. No open items.**  
**v1.1:** A0 dead-share residual on first mint (copy V4). Ship bar is hermetic **and** Base-main fork **and** Robinhood Chain fork.  
**v1.2:** Closed former §10 leftovers. Crane V3 `TickMath` grows `minUsableTick` / `maxUsableTick`. Wing storage deleted. Existing Out splits to query. CREATE3 In/Out execution delegates (Multi uses Target helpers). 4663 fork pins and `profile.fork` tooling locked.  
**Process:** Product law. Coding sequence: [`UNISWAP_V3_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V3_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_IMPLEMENTATION_AND_TEST_PLAN.md). That plan may choose **order** only. It may not choose storage, diamond cuts, helpers, delegates, test paths, or fork pins. Do not treat in-tree V3 code as accepted until that plan’s DoD is met.  
**Package path:** `contracts/protocols/dexes/uniswap/v3/`  
**Package kind:** Production change to the existing **Uniswap V3 Standard Exchange** vault (multi-asset SE shares over vault-owned Uniswap V3 pool positions).

**Family gold (copy, do not reopen):** [`../uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md`](../uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md) (v1.2, D30–D52) and [`../uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md`](../uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md) (v1.6, D1–D29). This file restates those IDs for **this package**. Same numbers mean the same product choice. V3-only mechanics (bound pool lock, NPM import vehicle, no PoolManager) are written out below.

**Related (do not conflate):**

| Artifact | Role |
|----------|------|
| [`UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PRD.md`](./UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PRD.md) | v1 bring-up law. **Superseded** on range geometry (v1 D3), rebalance (v1 D10), fee-first full deploy (v1 D6), and share SoT that ignored free ERC-20. Unchanged: factory check, ERC-20-only, NPM import converts to vault-owned pool positions and leaves the empty NFT, no native ETH, no ERC-4626. |
| [`UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PLAN.md`](./UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PLAN.md) | Historical coding plan for v1 (center+wings, no rebalance). Tick/rebalance sections yield to this PRD. |
| [`UNISWAP_V3_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V3_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_IMPLEMENTATION_AND_TEST_PLAN.md) | **Coding plan** — phases, file map, algorithms, test matrix, DoD. This PRD wins on product conflicts. |
| Uni V4 SE full-range + buffer PRDs | Family gold. Do not implement V4 `unlock` here. |
| Slipstream SE | Still its own later PRD (V4 D51). Out of scope. |
| [`IStandardExchangeInMulti.sol`](../../../../interfaces/IStandardExchangeInMulti.sol) | Exact-in many→one. Canonical join ABI. |
| [`IStandardExchangeOutMulti.sol`](../../../../interfaces/IStandardExchangeOutMulti.sol) | Exact-out one→many. Already renamed (V4 D39 done). |
| [`IStandardExchangeMultiAssetLiquidity.sol`](../../../../interfaces/IStandardExchangeMultiAssetLiquidity.sol) | **Do not implement** on this vault (D50). |

**Authority:**

| Layer | Role |
|-------|------|
| **This PRD (v1.2)** | Product law for V3 sleeve, full-range book, Multi, storage, diamond cuts, TickMath helpers, delegates, errors, test paths, fork pins |
| Co-located implementation plan | Coding sequence, algorithms spelled to this law, test matrix wired to the files named here. This PRD wins on product conflicts |
| V3 v1 vault PRD | Bring-up remainder only where this file is silent |

Operator lock (2026-08-24): **parity with Uni V4 SE.** One epic: ~20% fee-oracle sleeve, one full-range center, dual InMulti/OutMulti. No token0↔token1 rebalance swaps. First mint copies V4 A0 dead shares. Ship tests: hermetic + Base fork + Robinhood fork.

Operator lock (2026-08-24, v1.2): Crane V3 `TickMath.minUsableTick` / `maxUsableTick`. Delete wing storage (D36 makes layout change acceptable). Split existing Out to query. CREATE3 single-token In/Out execution delegates; Multi uses Target-local helpers. 4663 fork uses `ROBINHOOD_MAIN` factory + WETH/USDG under `[profile.fork]` only.

---

## 0. Terminology (normative)

| Term | Meaning |
|------|---------|
| **Bound pool** | The Uniswap V3 pool in `PkgArgs`. Factory must match `PkgInit.uniswapV3Factory` (v1 D14, unchanged). |
| **Idle (pool unlocked)** | `slot0.unlocked == true`. The pool’s `lock` modifier will accept `mint` / `burn` / `swap` / `flash`. |
| **In-session (pool locked)** | `slot0.unlocked == false`. Nested `mint` / `burn` / `swap` on **this** pool reverts `LOK`. |
| **Interaction-free / can open pool ops** | Product gate: bound pool is idle. Predicate: `canOpenBoundPoolOps() == true`. |
| **Interaction-blocked** | Product gate: bound pool is in-session. Predicate: `canOpenBoundPoolOps() == false`. |
| **Sleeve / free inventory** | ERC-20 balances of the two pool currencies on the vault diamond. SoT: `IERC20(token).balanceOf(address(this))` (D29). Target fraction of **total** via fee-oracle `liquidReservePercentageOfVault` (type default **20%**). Earns **no** Uniswap v3 swap fees. |
| **Deployed inventory** | Token0/token1 amounts in this vault’s **direct pool positions** (`owner = vault`). After this change: one center (full-range or imported ticks). Not NPM NFT liquidity (import converts to pool positions). |
| **Total vault reserve** | Free + deployed. Shares represent all vault-controlled pool-currency inventory (D9). After collect, do not also add `tokensOwed` on top of `balanceOf`. |
| **Managed book** | Positions this vault `mint`s on the bound pool. Position key is Uniswap V3 `(owner, tickLower, tickUpper)`. |
| **Imported book** | First deposit via NPM NFT: liquidity is moved onto a vault-owned **center** pool position at the NFT’s ticks. Empty NFT stays on the vault (v1 D15). This PRD does **not** rewrite those ticks to full range (D34). |
| **Full range** | `tickLower = TickMath.minUsableTick(tickSpacing)`, `tickUpper = TickMath.maxUsableTick(tickSpacing)` on **Crane V3** `TickMath` (D54). Formula matches Uniswap V4: `(MIN_TICK / tickSpacing) * tickSpacing` and `(MAX_TICK / tickSpacing) * tickSpacing`. Contains every tradable price for that spacing. |
| **In range** | Current pool tick is strictly inside `[tickLower, tickUpper)`. Only in-range L earns swap fees. |
| **Center** | The one managed position this vault stores. Not a tight band around first-deposit tick. |
| **Wings** | Historical lower/upper one-sided positions. **Deleted from storage** (D55). Do not keep unused wing slots or `PositionKind` wing variants. |
| **Join / Exit / Proportional / Unbalanced** | Same as Uni V4 family gold. Join = exact `amountsIn`. Exit = exact `amountsOut`. Proportional = vault `total_i` ratio (D44 / D52). |
| **Single-token zap** | Existing `IStandardExchangeIn` / `Out`. Idle zap-out may swap the other pool token. Unchanged. |

**V3 lock naming (LOCKED for NatSpec):**

Uniswap V3 `slot0.unlocked == true` means the pool is **idle** (safe to `mint`/`swap`). That is the **opposite** of Uniswap V4 `isUnlocked == true` (mid-batch). Product copy must use `canOpenBoundPoolOps`. Do not write “if unlocked, use the sleeve” without saying which flag.

---

## 1. Problem

### 1.1 What the vault does today

The Uniswap V3 Standard Exchange (v1, implemented):

1. Binds one initialized V3 pool (`deployVault(pool, widthMultiplier)`). Direct `pool.mint` / `burn` / `collect` / `swap` plus mint/swap callbacks. No PoolManager.
2. Sizes a **center + two wings** at first organic create (`widthMultiplier`, `centerWidthMultiplier = 2`, `activeLiquidityBps = 1000`). Ticks freeze. v1 D10: **no rebalance**.
3. Share SoT `_totalVaultReserves` is **position amounts + tokensOwed**, not free ERC-20. Free working inventory is only added in `_totalVaultValue`.
4. `_feeFirstCompound` collects fees and **mints all free inventory into the book** before a new zap-in (v1 D6). There is no policy sleeve.
5. Import converts an NPM NFT into a vault-owned **center** at the NFT ticks; wings stay uncreated; empty NFT remains.
6. Public surface is single-token In/Out (In split mutate/query; Out is one facet) plus import. No Multi facets. No liquid-reserve facet.

That book has the same fee-idle shape as pre-change Uni V4: most deployable inventory sits in one-sided wings that are out of range at mint; the tight center dies if price walks. Nested `mint`/`swap` on the **bound** pool while it is already in `lock()` reverts `LOK`. There is no sleeve path, so a same-pool nested `exchangeIn` / amount-out cannot complete.

### 1.2 What “same as Uni V4 SE” means here

Keep a **policy sleeve**. Put the rest in **one full-range** vault-owned position so deployed capital stays in range. Add **dual join/exit**. Do not recast. Do not add rebalance swaps.

This package has **no** prior sleeve PRD, so this file owns sleeve + book + Multi together (Uni V4 split those across two PRDs).

### 1.3 Locked product choice

Use the **protocol-maximum range** (always in range). Type-default **20%** free sleeve via the existing fee-oracle cascade. Dual Multi join may be unbalanced; dual Multi exit must be proportional (D52). Existing single-token zaps stay.

That is time-in-range, not L-density at spot. Later agents must not “fix” full range back into center+wings or recast.

---

## 2. Goals

1. **Lock-safe deposits:** When `canOpenBoundPoolOps() == false`, pool-currency `exchangeIn` / Multi join **must succeed** without `pool.mint` / `swap` / `burn`, by retaining tokens in the sleeve.
2. **Lock-safe amount-out from sleeve (blocked only):** When blocked, pay pool currencies only if free of each requested token covers the full amount; else revert the whole tx. When **idle**, amount-out **always** uses the pool (burn/collect and swap as today) even if the sleeve would cover, then tail-rebalance (D3).
3. **Target sleeve in steady state:** Idle ops finish the user action first, then rebalance toward `targetFree_i = total_i * liquidReservePercentageOfVault(this) / 1e18` with type default **`0.20e18`**. Live oracle read every time (D20). Deposits are sleeve-then-deploy-excess (D27).
4. **Permissionless rebalance:** Public `rebalanceLiquidReserve()` when idle; **revert** when blocked. Add/remove L only. No token0↔token1 rebalance swap (D28).
5. **Shares = vault-controlled assets:** Mint/burn against **free + deployed** (D9). Preview ignores post-op rebalance (D24).
6. **One full-range center** for new non-imported books. **No wing storage.** Ticks freeze. `widthMultiplier` stays on `deployVault` and does not size ticks.
7. **Keep** `IStandardExchangeIn` / `Out` selectors. **Split** existing Out into mutate + query. **Add** InMulti / OutMulti facets (exactly two pool currencies, sorted) and the liquid-reserve facet.
8. **Import:** still NPM → vault-owned center at **NFT ticks**. No rewrite to min/max. Sleeve add/remove on that range when idle. Import that needs `mint` while blocked **hard-reverts**.
9. **Production-first tests** on `TestBase_UniswapV3StandardExchange` (manager DFPkg + `deployVault`). No mock of vault, manager, registry, fee oracle, or bound pool as SUT.

### 2.1 Non-goals (v1)

1. Recast / recenter / JIT of ticks.
2. Any new token0↔token1 swap as a rebalance tool (D28).
3. Maximizing L per dollar at the current tick.
4. Implementing this epic on Slipstream or other SEs.
5. Migrating **already created** V3 vaults that froze center+wings. Geometry is init-time. Those instances are out of scope, which is why wing **storage** may be deleted (D55).
6. Removing `widthMultiplier` from `PkgArgs`.
7. Rewriting imported center ticks to full range.
8. Native ETH / `address(0)`.
9. Joining an in-flight V3 pool lock as a co-minter (no piggyback callback protocol).
10. `IStandardExchangeMultiAssetLiquidity`.
11. Multi as many→one **pool token** swap. Multi here is join/exit vs **shares** only.
12. Merging Multi into existing In/Out facets.
13. ERC-4626.
14. Changing Uniswap V3 factory validation or leaving-empty-NFT import rules (v1 D14/D15).
15. `via_ir`.
16. A third Foundry profile. Only `default` (hermetic) and `fork`.
17. Silent skip of the 4663 fork when RPC or pool is missing.

---

## 3. Design decisions (LOCKED)

IDs match Uni V4 family gold. V3-specific restatements are in the Choice column. D54–D61 are V3-only closures of surfaces that must not be left to an implementor.

### 3.1 Sleeve and bound-pool lock (D1–D29)

| ID | Decision | Choice (this package) |
|----|----------|------------------------|
| **D1** | Interaction gate | `canOpenBoundPoolOps() :=` bound pool `slot0().unlocked` (**true = idle**). Not a PoolManager flag. |
| **D2** | When blocked | **Never** `mint` / `burn` / `swap` on the bound pool. Deposits stay in the sleeve. Amount-out: pay from free of the requested token(s) if fully covered; else revert (D18). |
| **D3** | When idle — amount-out / direct swaps | **Always use the pool** (burn/collect and/or swap). Do not pay amount-out from the sleeve just because free would cover. Then tail-rebalance (D10). |
| **D4** | Blocked deposit vs target | Accept the full deposit into the sleeve regardless of target %. Mint against total reserves. |
| **D5** | Oracle knob | Reuse `liquidReservePercentageOfVault`. No parallel field. |
| **D6** | Units | WAD. Same oracle validation. |
| **D7** | Default sleeve size | **Type-level default for Uni V3 SE = `0.20e18` (20%).** Key the USAGE fee type **and** the liquid-reserve type default on **`IUniswapV3StandardExchangeLiquidReserve`** (D59). Do **not** hang the 20% default on `IStandardVault.interfaceId`. Vault override still allowed. |
| **D8** | Stored `0` | Unset / fall through, not 0% liquid. |
| **D9** | Reserve + share SoT | `_totalVaultReserves()` = **free `balanceOf` + deployed position amounts**. Collect fees onto the diamond **before** a totals read used for mint/burn so `tokensOwed` is not a second copy of the same wei. **Supersedes** today’s position+owed-only SoT. |
| **D10** | Rebalance placement | After every idle state-changing SE entry (zap-in, zap-out, **direct pool swap**, Multi join/exit): user op first, then best-effort rebalance. Public `rebalanceLiquidReserve()` when idle. When blocked: public rebalance **reverts**. **Supersedes** v1 D10 (rebalance non-goal). |
| **D11** | Rebalance failure | Must not revert the already-finalized user mint/burn/swap. |
| **D12** | Direct pool swaps | Require idle. Blocked: revert interaction-blocked (not a sleeve swap). Idle: pool swap, then tail-rebalance. |
| **D13** | Share deltas | Placement free vs deployed does not change the user’s share math for that op. |
| **D14** | Usage fee | Unchanged domain. Sleeve is not a new fee. Collect-then-totals **replaces** v1 D6. **Delete** `_feeFirstCompound` and `_feeFirstCompoundReservingPrincipal` (D57). Do not keep a path that drives free to ~0. |
| **D15** | Import vs lock | Same gate. Import that must `decreaseLiquidity` / `collect` / `mint` while the bound pool is in-session **hard-reverts**. No partial free-only import. |
| **D16** | Testing | Production-first. Gold: `indexedexManager.deployUniswapV3StandardExchangeDFPkg` then `pkg.deployVault(pool, widthMultiplier)`. No mock SUT. **Ship bar (LOCKED):** (1) hermetic `[profile.default]`, files in D60, (2) Base-main fork `[profile.fork]`, extend `test/foundry/fork/base_main/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_Fork.t.sol` (existing WETH/USDC fee 500 pin), (3) Robinhood Chain **4663** fork `[profile.fork]`, file and pins in D60. **No new Foundry profile.** If 4663 factory has no code or the pinned pair has no pool, that is an **env blocker** (`require` / test fail), not `vm.skip`. |
| **D17** | Target shape | Per token: `targetFree_i = total_i * liquidPct / 1e18`. |
| **D18** | Blocked amount-out | Cover on the requested currency (both currencies on Multi exit) or revert `UniswapV3Exchange_InsufficientLocalReserve`. No blocked swap. |
| **D19** | Compatibility / DoD | Concern is **same-pool nested `LOK`**. DoD harness: an external swapper whose `uniswapV3SwapCallback` calls this diamond while the bound pool is locked. Do not invent a PoolManager. A V4-style hook matrix is N/A. |
| **D20** | Live oracle | Re-read `liquidReservePercentageOfVault(this)` on every rebalance / target compute. No vault cache of the pct. |
| **D21** | NatSpec | Gate, blocked deposit/out, and rebalance must say: sleeve is for when the **bound pool** cannot be entered; cover → pay; short → revert; idle path uses the pool then rebalances. Error names in D58. |
| **D22** | Deadband | Same as V4: rebalance token `i` only if `\|free_i - targetFree_i\| > max(ABSOLUTE_FLOOR_i, targetFree_i * 0.05e18 / 1e18)`. Floor: `10^max(0, decimals-6)` (1 wei if decimals ≤ 6). Once tripped, move **to target**. Within band: skip pool ops on public rebalance. |
| **D23** | Existing single-token routes | Unchanged set. Blocked amount-out is per requested `tokenOut`. |
| **D24** | Preview | Quotes the user route under the current idle/blocked gate. Does **not** simulate tail-rebalance. |
| **D25** | No outer-context tracking | No list of which router/pool held `lock()`. Preventative sleeve only. |
| **D26** | Native currency | Out of scope. |
| **D27** | Free-path deposit | Sleeve-then-deploy-excess. Pull → mint against totals → deploy only `free_i - targetFree_i` (beyond deadband) as center L. Do not fully deploy then pull 20% back as the primary shape. |
| **D28** | No rebalance swaps | Add L or burn L only. Best-effort per token. |
| **D29** | Free SoT | `balanceOf` on the diamond for pool currencies. Donations count. |

### 3.2 Full-range book (D30–D38)

| ID | Decision | Choice (this package) |
|----|----------|------------------------|
| **D30** | Managed range (non-imported) | **One** full-range center on the bound pool. Ticks from Crane V3 `TickMath.minUsableTick` / `maxUsableTick` (`pool.tickSpacing()`). **No wings.** Ticks freeze at first create. No recast. |
| **D31** | `widthMultiplier` | Stays on `PkgArgs` / `deployVault` (`>= 1`). **Does not size ticks.** `UniswapV3VaultRepo.StrategyConfig` stores **only** `widthMultiplier`. Delete `centerWidthMultiplier` and `activeLiquidityBps` from storage. Deployable inventory is **100% to the center**. |
| **D32** | In-range mint ratio | Full-range in-range L needs **both** tokens at spot. Leftover of the other token stays free. No swap to absorb leftover (D28). |
| **D33** | First single-token mint | Shares > 0 against totals. In-range L **may be 0** until the other pool currency exists. Do not recreate wings as a parking lot. Residual inventory at empty supply is **D53**, not first-minter NAV. |
| **D34** | Imported positions | NFT ticks become the **center pool position** ticks (already v1). Do **not** rewrite to min/max usable. Do **not** `_snapTick` them. Sleeve add/remove on that range only. |
| **D35** | Rebalance vs ticks | Idle rebalance / tail-rebalance **must not** change `tickLower` / `tickUpper`. |
| **D36** | Existing instances | Vaults already created with center+wings are **out of migration**. Law applies to **new** managed books after this change. This is why D55 may delete wing slots. |
| **D37** | Fee accounting | `collect` onto the diamond (free). Then D9/D27. No separate “compound 100% of free into L” path (D57). |
| **D38** | Testing | See D16 / D60. All three gates are merge-blocking for this epic. |

### 3.3 Multi join/exit (D39–D53)

| ID | Decision | Choice (this package) |
|----|----------|------------------------|
| **D39** | Out Multi file | Already `IStandardExchangeOutMulti.sol`. Do not resurrect `IStandaardExchangeOutMulti.sol`. |
| **D40** | Out preview NatSpec | Exact-out: preview returns **shares** `amountIn`. Execute returns shares burned. Signatures unchanged. |
| **D41** | In Multi = join | `tokenOut` = vault shares. `tokenIn[]` = **exactly** the two pool currencies, unique, **strictly ascending by address**, `amountsIn.length == 2`, every `amountsIn[i] > 0`. Else `ExchangeInNotAvailable`. |
| **D42** | Out Multi = exit | `tokenIn` = vault shares. `tokensOut[]` same dual-pool rules. Else `ExchangeOutNotAvailable`. |
| **D43** | Existing single-token surface | **Keep** selectors. Split Out mutate/query (D48). Multi is never a length-1 alias. Only existing zap-out may swap the other pool token. |
| **D44** | Proportional ratio | Vault `total_i` (free + deployed), not Uniswap spot add-liquidity ratio. |
| **D45** | Unbalanced | Join: pay both `amountsIn` in full; surplus stays sleeve; no Multi swap. Exit: `S0 == S1` or revert; no tokens sent; no swap. |
| **D46** | Share math | D9/D13. First Multi join at empty supply: user shares = `sum(amountsIn)` (D53 residual is extra dead shares, not added into the user’s amount). Later: `ConstProdUtils._depositQuote` vs pre-deposit totals. |
| **D47** | Sleeve / lock on Multi | Same D1–D4. **Blocked join:** pull both, mint, **no** pool mint/burn/swap. **Blocked exit:** D52 plus free of **both** tokens or `UniswapV3Exchange_InsufficientLocalReserve`. **Idle join:** mint then tail-rebalance. **Idle exit:** burn/remove via the pool even if sleeve would cover (D3), pay exact `amountsOut`, then tail-rebalance. Preview ignores rebalance (D24). |
| **D48** | Facet layout | **New** cuts, not merged into In/Out. Required CREATE3 facets (never `new`): liquid-reserve; Out query; InMulti + InMultiQuery; OutMulti + OutMultiQuery. Existing OutFacet keeps **`exchangeOut` only**. Cuts **9 → 15**. `PkgInit` fields and FactoryService deploy helpers for every new facet. ERC165 `facetInterfaces()`. Attach helper for the four Multi facets (same arity pattern as V4 `attachUniswapV4StandardExchangeMultiFacets`). Execution delegates: D56. |
| **D49** | `pretransferred` | I1 per listed token. One flag for both join tokens. `pretransferred=true` without delivery of **both** must not mint from inventory. Out shares: existing secure share delivery + refund `maxAmountIn - S`. |
| **D50** | Not MultiAssetLiquidity | Do not cut it. |
| **D51** | Family gold | This **is** the Uni V3 copy of V4 D39–D52. Do not implement Slipstream Multi in this epic. |
| **D52** | Dual-exit shares | `S0 = ceil(amount0 * supply / total0)`, `S1 = ceil(amount1 * supply / total1)` (rounding-up muldiv, not overflowing `amount * supply`). Zero total on a listed token or zero supply → revert. Require `S0 == S1` and `S <= maxAmountIn`. Pay exact `amountsOut`. |
| **D53** | First-mint residual (A0) | **Copy Uni V4.** Sink: `address(0x000000000000000000000000000000000000dEaD)` (not `address(this)`). When `totalSupply == 0` and residual vault-controlled inventory exists at first share mint (donation, uncollected dust after collect, leftover from import remint, etc.), mint shares equal to that residual (same units as D9 totals) **to the sink** so the first minter is not 100% of supply over that inventory. Applies to single-token zap-in, Multi join, and import-at-empty-supply. User shares still follow D46 / import quote. |

### 3.4 Closed surfaces (D54–D61) — not implementor choice

| ID | Decision | Choice (this package) |
|----|----------|------------------------|
| **D54** | Tick helpers | Add `minUsableTick(int24)` and `maxUsableTick(int24)` to Crane **`lib/crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol`**, same bodies as V4 TickMath (unchecked `(MIN_TICK / tickSpacing) * tickSpacing` and max counterpart). Do **not** change `getSqrtRatioAtTick` / `getTickAtSqrtRatio`. V3 SE Common calls **those** helpers. Do **not** inline a second copy in IndexedEx. Do **not** import V4 TickMath into the V3 package. Add Crane tests in `lib/crane/test/foundry/spec/protocols/dexes/uniswap/v3/libraries/TickMath.t.sol` covering spacings 1, 10, 60, 200 (divisible, within MIN/MAX, next spacing step outside MIN/MAX). |
| **D55** | Wing storage | **Delete** `lowerWingPosition`, `upperWingPosition`, and `PositionKind` (`Center` / `LowerWing` / `UpperWing`) from `UniswapV3VaultRepo`. Storage is one `centerPosition` plus import metadata plus `StrategyConfig { uint24 widthMultiplier }` plus last tick/price/timestamp. Delete `_setLowerWingPlan`, `_setUpperWingPlan`, and any `_createPositionIfNeeded` wing branch. `_isPositionCreated()` is center `created` only. Layout change is allowed because D36: no live-book migration. |
| **D56** | CREATE3 delegates | Copy V4: CREATE3 `UniswapV3StandardExchangeInExecutionDelegate` and `UniswapV3StandardExchangeOutExecutionDelegate` for existing single-token zap In/Out (FactoryService deploy + Target call). **Multi:** no extra CREATE3 delegates. Stack-too-deep on Multi is Target-local structs / helper frames (V4 `DualExitLocal` pattern). **Never `via_ir`.** **Never `new`** delegates or facets. |
| **D57** | Fee-first compound | **Delete** `_feeFirstCompound` and `_feeFirstCompoundReservingPrincipal`. Idle In/import collect bound-pool fees onto the diamond, then D9/D27. Blocked paths do not `collect` / `mint` / `burn` / `swap` on the bound pool. |
| **D58** | Errors | Gate revert: `UniswapV3Exchange_BoundPoolInteractionBlocked()`. Covered-fail amount-out: `UniswapV3Exchange_InsufficientLocalReserve(address token, uint256 requested, uint256 available)`. Do not reuse V4 `PoolManagerInteractionBlocked` names on this package. |
| **D59** | Liquid-reserve interface | New `contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol`. Methods: `canOpenBoundPoolOps() → bool`, `localReserve(address) → uint256`, `deployedReserve() → (uint256,uint256)`, `targetLiquidReservePercentage() → uint256`, `actualLiquidReservePercentage(address) → uint256`, `rebalanceLiquidReserve()`. Events peer of V4: `LiquidReserveRebalanced`, `LocalDepositWhileBlocked`. Interface id keys USAGE type **and** 20% type default. Target + Facet + CREATE3. |
| **D60** | Test files and fork pins | **Hermetic** (`[profile.default]`, under `test/foundry/spec/protocol/dexes/uniswap/v3/`): `UniswapV3StandardExchange_LocalLiquidBuffer.t.sol` (T1–T16 analog), `UniswapV3StandardExchange_FullRangeBook.t.sol` (FR1–FR6), `UniswapV3StandardExchange_MultiJoinExit.t.sol` (MJ1–MJ8, ME1–ME7, A0), plus IFacet tests for every new facet and an updated DFPkg deploy test. Existing V3 route/import/adversarial suites stay and drop center+wings asserts. **Base fork:** extend `test/foundry/fork/base_main/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_Fork.t.sol` (factory `BASE_MAIN.UNISWAP_V3_FACTORY` / WETH/USDC fee 500 as today) with at least FR1 or MJ2, one blocked sleeve path, and A0. **Robinhood 4663 fork:** `test/foundry/fork/robinhood_4663/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_Robinhood.t.sol`. `FOUNDRY_PROFILE=fork`. RPC: `robinhood_mainnet_alchemy`, else `robinhood_mainnet` (`foundry.toml`). Factory: `ROBINHOOD_MAIN.UNISWAP_V3_FACTORY` (`0x1f7d7550B1b028f7571E69A784071F0205FD2EfA`). Pool: `ROBINHOOD_MAIN.WETH9` × `ROBINHOOD_MAIN.USDG` at fee **500**, else **3000**, else **100**. Missing factory code or `getPool == 0` → fail (env blocker), not skip. Same FR1-or-MJ2 + blocked sleeve + A0. Do not reimplement share math in fork tests. |
| **D61** | PkgInit construction sites | Every in-tree `IUniswapV3StandardExchangeDFPkg.PkgInit` writer must pass the new fields (liquid-reserve, OutQuery, four Multi). Required: `UniswapV3_Component_FactoryService`, `UniswapV3StandardExchangeDFPkg`, `TestBase_UniswapV3StandardExchange`, Base fork test `_buildPkgInit`, `scripts/foundry/anvil_robinhood_testnet/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol`, `scripts/foundry/anvil_robinhood_fee_detf/Script_05_DeployUniV3SeOnRichPool.s.sol`. Do **not** invent a new Stage. Do **not** add a 4663 launch tree in this epic. `anvil_robinhood_main` is untouched unless it already constructs this PkgInit (it does not today). |

---

## 4. Relationship of sleeve and book

```text
total_i = free_i + deployed_i
targetFree_i = total_i * liquidReservePercentageOfVault(this) / 1e18   // default 20%

idle (slot0.unlocked == true):
  keep free_i ≈ targetFree_i (deadband D22)
  deploy excess as full-range (or imported) center L
  or burn center L so free rises toward target

blocked (slot0.unlocked == false):
  never mint/burn/swap on the bound pool
  deposits stay sleeve
  amount-out from sleeve if covered, else revert
  no range work
```

Full range does **not** remove the sleeve. Nested `exchangeIn` during a swap on **this** pool still cannot `mint`.

Full range **does** mean deployed capital stays in range when the pool trades.

---

## 5. Runtime (normative)

### 5.1 First managed create (idle)

1. Derive full-range ticks: `TickMath.minUsableTick(pool.tickSpacing())` / `maxUsableTick` (D54).
2. Create **center only**. No wing types.
3. Mint L from deployable excess above target free. Spot ratio. Leftover stays free.

### 5.2 Later idle ops

Same ticks. Add L on excess; burn L on deficit. Remove returns both tokens; a later pass may redeploy the other token’s overshoot into the same center.

### 5.3 Price moves

No tick action. Position stays in range. Fees accrue as `tokensOwed` until `collect`. Next idle collect+rebalance or user zap checkpoints them as free, then D27.

### 5.4 Blocked ops

D2 / D18 / D47. Harness: an external swapper whose `uniswapV3SwapCallback` calls this vault while the bound pool is locked.

### 5.5 Direct pool swaps

Idle only. Then tail-rebalance. Not a recast tool.

### 5.6 Multi join / exit

Same house rule as V4: In = exact paid; Out = exact received.

```text
Join:  tokenIn[] = two pool currencies, sorted; tokenOut = shares; return shares
Exit:  tokenIn = shares; tokensOut[] = two pool currencies, sorted; return shares burned
```

Idle proportional join is the one-call bootstrap that actually mints full-range L (unlike single-token zap-in, D33). Unbalanced join still pulls both amounts. Unbalanced exit reverts. Length ≠ 2 reverts.

### 5.7 Import

Unchanged vehicle: NPM `decreaseLiquidity` + `collect` + vault `mint` at NFT ticks as center. Blocked: revert (D15). Idle rebalance grows/shrinks **that** center only. No `_snapTick`.

---

## 6. Rejected alternatives (do not revive without a new PRD)

| Alternative | Why rejected |
|-------------|--------------|
| Tight center, recast when OOR | Operator chose maximum range; recast is a non-goal. |
| Recast + abundant→scarce swap | Violates D28. |
| Keep 10/90 center+wings | That is the fee-idle problem. |
| Wide-but-not-full `widthMultiplier` | Operator asked for protocol-max range. Width stays ABI-only. |
| Dip the scarce-token sleeve to mint more L | Nested amount-out cover of that token would go below policy. |
| Skip the sleeve (book + Multi only) | Rejected 2026-08-24: parity with V4 includes the 20% sleeve. |
| Hang 20% type default on `IStandardVault` | Would change every standard vault. Use a V3 liquid-reserve interface id. |
| Keep `_feeFirstCompound` as 100% deploy | Conflicts with D7/D27. Deleted (D57). |
| Rewrite imported ticks to min/max | D34. |
| Cut `IStandardExchangeMultiAssetLiquidity` or fold Multi into `IStandardExchange` | Family gold D50 / D43. |
| Slipstream Multi in this epic | D51. |
| Skip A0 / first minter absorbs residual | Rejected 2026-08-24: copy V4 dead-share sink (**D53**). |
| Hermetic-only ship | Rejected 2026-08-24: Base fork **and** Robinhood 4663 fork are merge-blocking (**D16** / **D38**). |
| Inline D30 ticks in IndexedEx Common, or import V4 TickMath | Rejected 2026-08-24: extend Crane V3 TickMath (**D54**). |
| Keep unused wing slots / `PositionKind` wings | Rejected 2026-08-24: delete wing storage (**D55**). |
| Keep combined OutFacet (preview+mutate) | Rejected 2026-08-24: split Out to match V4 (**D48**). |
| No CREATE3 In/Out execution delegates, or extra Multi delegates | Rejected 2026-08-24: copy V4 single-token delegates; Multi helpers only (**D56**). |
| New Foundry profile for 4663, or WETH/USDC as the RH pin | Rejected 2026-08-24: `[profile.fork]` + `ROBINHOOD_MAIN` WETH/USDG (**D60**). |
| Silent `vm.skip` when 4663 pool is missing | Rejected 2026-08-24: env blocker. |
| `via_ir` for stack-too-deep | Forbidden. Structs / helper frames / D56 delegates. |

---

## 7. Requirements for the later implementation plan

The co-located implementation plan specifies **coding sequence** and algorithm walkthroughs. It does **not** reopen D1–D61.

### 7.1 Code surfaces (locked)

| Area | Law |
|------|-----|
| Gate | `canOpenBoundPoolOps` from bound pool `slot0.unlocked`. Revert `UniswapV3Exchange_BoundPoolInteractionBlocked`. |
| Tick derive | Crane V3 `TickMath.minUsableTick` / `maxUsableTick` (D54). No `widthMultiplier` in tick math. No `_snapTick`. |
| Repo | One `centerPosition`. No wing slots. `StrategyConfig.widthMultiplier` only (`>= 1` at init). |
| Share SoT | Free `balanceOf` + deployed. Collect before totals used in mint/burn. |
| Liquid reserve | `IUniswapV3StandardExchangeLiquidReserve` (D59) + Target + Facet + CREATE3. USAGE / type default = that interface id. Type default 20% in TestBase. |
| Rebalance | Public `rebalanceLiquidReserve`; tail-rebalance on idle In/Out/Multi/direct swap. Center only. |
| Existing In | Keep mutate/query split. Mutate **calls** CREATE3 `InExecutionDelegate` (D56). Copy V4: `InExecutionDelegate` in FactoryService; Out mutate uses `OutExecuteTarget` constructor-injected delegate. |
| Existing Out | Split: `UniswapV3StandardExchangeOutFacet` (`exchangeOut`) + `UniswapV3StandardExchangeOutQueryFacet` (`previewExchangeOut`) + OutQueryTarget + `OutExecuteTarget`. Mutate **calls** CREATE3 `OutExecutionDelegate`. |
| In Multi / Out Multi | Four new facets + Targets. No Multi execution delegates. FactoryService attach helper. |
| DFPkg | `PkgInit` + diamond cuts 9 → 15 + ERC165. |
| Import | Keep selectors. Blocked-revert when pool locked. |
| Compound | D57: deleted. Collect + D27. |
| PkgInit writers | D61 list. |
| Crane | D54 TickMath helpers + Crane unit tests. Additive only. |

### 7.2 Tests (production-first)

Existing V3 routes, previews, import, fee-compound, DFPkg, IFacet, and adversarial suites must stay green **after** they stop asserting center+wings and after share SoT includes free. Call sites of `_feeFirstCompound` are gone.

New IDs (same meaning as V4 §7.2, V3 harness for “blocked”):

| ID | Assertion |
|----|-----------|
| T1–T16 analog | Sleeve ~20% on idle dual-sided deploy; blocked join sleeve-only; blocked amount-out cover/short; deadband; donations count as free; public rebalance reverts when pool locked |
| FR1 | After dual-sided deploy (or two single-sided that jointly allow L), center ticks = `TickMath.minUsableTick` / `maxUsableTick` for `pool.tickSpacing()`; no wing storage to query |
| FR2 | Walk spot many spacings; center still in range; a later pool swap increases fee owed and/or totals |
| FR3 | `rebalanceLiquidReserve` after FR2: ticks unchanged; sleeve within deadband |
| FR4 | Blocked `exchangeIn` sleeve-only; later idle rebalance onto the **same** full-range ticks |
| FR5 | Single-token first mint: shares > 0; L may be 0; other token + idle rebalance can mint full-range L |
| FR6 | Import: center ticks = NFT ticks, not min/max; sleeve add/remove only |
| MJ1–MJ8 | Dual join validation, proportional/unbalanced, blocked, I1, preview parity, descending revert |
| ME1–ME7 | Dual exit validation, D52, unbalanced revert with no send, blocked cover/short, low `maxAmountIn`, preview parity, share refund |
| A0 | Donate or seed residual at `totalSupply == 0`; first mint (zap-in, Multi join, or import) leaves dead-sink shares > 0; first minter is not 100% of supply over that residual; redeem cannot take the donation |

Do not mock the bound pool, vault, manager, registry, or fee oracle as SUT.

Fork suites (Base + Robinhood 4663) must drive **production** DFPkg + a real pool on that chain: at least FR1 or MJ2, one blocked sleeve path, and A0. They must not reimplement share math.

Blocked harness: a swap on the **bound** pool whose `uniswapV3SwapCallback` calls this diamond.

### 7.3 Docs the plan must keep aligned

- This PRD.
- V3 v1 vault PRD: range/rebalance/compound rows point here.
- V3 vault plan tick section: first organic create is full-range center only; wing storage gone.
- Uni V4 D51: this file is the V3 copy.
- Crane V3 TickMath NatSpec for the new helpers.

### 7.4 Definition of done (for the later plan)

1. New non-imported vaults: one full-range center; no wing storage.
2. Idle ops: sleeve ~20% within D22 after dual-sided inventory exists.
3. Blocked nested In/Out: sleeve deposit; amount-out cover or revert; no nested pool `mint`/`burn`/`swap`.
4. FR1–FR6, MJ1–MJ8, ME1–ME7, A0, T1–T16 analog, and updated route/import/adversarial suites green on the hermetic gold path.
5. Base-main fork and Robinhood 4663 fork suites green (D16/D60), or a **failing** env blocker if 4663 has no V3 pool (not a skip).
6. NatSpec matches D1–D61 (V3 gate wording).
7. Diamond cuts: liquid-reserve, OutQuery, InMulti, InMultiQuery, OutMulti, OutMultiQuery; existing In/Out/Import still work; Out preview lives on OutQueryFacet.
8. Liquid-reserve interface id is the USAGE / type-default key; 20% type default set in TestBase.
9. Out Multi on-disk file remains `IStandardExchangeOutMulti.sol`.
10. Crane V3 TickMath helpers + Crane unit tests green.
11. CREATE3 In/Out execution delegates exist; Multi has none.
12. Every D61 PkgInit writer compiles with the new fields.
13. No `via_ir`. No new Foundry profile.

---

## 8. Economics (normative honesty)

Do not describe this as “max fee APR.”

- **Gained:** ~80% of inventory (when both tokens allow L) is always in range. No recast gas. Nested same-pool calls can complete via the sleeve.
- **Given up:** L at spot is thinner than a tight in-range center. v1 “compound every wei of free into L” is gone; 20% stays idle by policy.
- **Still idle:** the sleeve; leftover of one token that cannot mint two-sided L (D32).
- **Join that seeds L:** dual `exchangeInManyToOne`, or two single-token zaps that jointly allow L.

---

## 9. Supersession of V3 v1 (normative)

| V3 v1 ID | This PRD |
|----------|----------|
| D3 center + wings | **D30 / D55** one full-range center; wing storage deleted |
| D6 compound all free into L before mint | **D14 / D27 / D37 / D57** collect, then sleeve-then-deploy-excess; fee-first functions deleted |
| D8 / D18 import center-only, no wing create | **Kept.** Center ticks stay the NFT ticks (**D34**). No wing types left to leave uncreated. |
| D10 no rebalance | **D10** idle add/remove toward 20% sleeve |
| Share SoT position + tokensOwed only | **D9** free + deployed |

Factory check, ERC-20-only, empty NFT retained, no pool creation inside the vault, no ERC-4626: **unchanged**.

---

## 10. Open items

None. v1.2 of this PRD is complete product law for this epic. The later implementation plan may order the work; it may not choose among alternatives already rejected in §6.
