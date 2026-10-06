# Grok — UniswapV4UpperLowerWingsStandardExchangeVault PRD draft

**Author:** Grok (xai/grok-4.7). Independent first pass, 2026-10-05. Research only. No git, shell, tests, or peer artifacts. Commit `35f47b5195d16fdf90fd7c032a10f8d3b916fd90` was not read. User instruction, not a source inspection: restored `92cdf89a^` is center-only full-range, not three wings. Prior ~1.28M whole-test gas and prior security claims are unverified and do not measure wings.

This is a proposed PRD for a **new** product. It does not restore unseen history and does not amend FullSpread.

## 1. Identity

| Item | Requirement |
|---|---|
| Product | `UniswapV4UpperLowerWingsStandardExchangeVault` |
| Path | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/` |
| Kind | IndexedEx vault diamond / Standard Exchange. Not a V4 hook diamond. Not FullSpread. |
| Deploy | Facets CREATE3 via FactoryService. Package via `indexedexManager.deploy*DFPkg`. Instance via vault registry. `PkgInit` / `PkgArgs` on the interface. Never `new` for the SUT. Never the hook-factory path (`indexedex-uniswap-v4-hook-packages` is the wrong factory). |
| Compiler | `solc 0.8.35`, optimizer runs 1, `via_ir` forbidden (`foundry.toml:29-36`). Runtime ≤ 24,576 bytes per deployed facet/package. |
| Preserved | `v4/fullSpread/hookless/` and `v4/fullSpread/ponsFamilyV2Hook/` stay byte-unchanged. No in-place migration of live FullSpread instances. |

Full type names only. No `ULW` production alias.

## 2. What current source actually is

Fact. Hookless FullSpread stores one `centerPosition` and reads only those ticks (`UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo.sol:121-124`). `deployedReserve()` is that one position (`LiquidReserveTarget.sol:59-60`, `:87-89`: “Does not move ticks. Non-imported deployed book is full-range”). Sleeve is free local ERC-20, not position math (`Common.sol:312-320`). `canOpenPoolManagerUnlock` is `!TransientStateLibrary.isUnlocked` (`Common.sol:300-301`). A blocked call reverts `UniswapV4Exchange_PoolManagerInteractionBlocked` (`:290`, `:354-357`) unless a funded sleeve path pays locally.

External fact, Context7 `/uniswap/v4-core`, accessed 2026-10-05: `PoolManager.unlock` reverts `AlreadyUnlocked` if already unlocked. Nested unlock is forbidden. Source: https://github.com/uniswap/v4-core/blob/main/_autodocs/api-reference/pool-manager.md.

Inference. A consumer that has already unlocked the same PoolManager cannot have this vault open another unlock. The sleeve is the only settlement path in that state. That is a hard constraint, not an economic policy.

## 3. Geometry — not selected

The name requires three distinct positions on one `PoolKey`: lower wing, center, upper wing. It does **not** say widths, gaps, tick alignment, or liquidity weights. Current FullSpread’s one full-range position is not this geometry. Copying MIN/MAX as “center” would erase the wings. Inventing symmetric widths would be a new design disguised as a default.

**OD-1 (blocking).** Owner must specify, in tick-spacing units, for a declared `tickSpacing`:

- center `[cLower, cUpper)`, lower `[lLower, lUpper)`, upper `[uLower, uUpper)`;
- whether ranges are contiguous, gapped, or overlapping;
- alignment rule (multiples of `tickSpacing`, inside `TickMath.MIN_TICK` / `MAX_TICK`);
- whether bounds are absolute, or offsets from the activation tick;
- liquidity weights `wL + wC + wU = 1e18`, each `w >=` a stated minimum, or another rule.

Until OD-1, no implementation plan and no “safe” width. Empty wings at activation are also OD-1, not a silent default.

## 4. Custody versus economic backing

Require the FullSpread separation, extended to three positions. Do not book deployed liquidity into `reserveOfToken`.

- `F_i`: spendable local ERC-20 of currency `i` after excluding this caller’s unbooked credit. This is the sleeve. `reserveOfToken` reports booked local custody only.
- `D_i = D_i^L + D_i^C + D_i^U`: owned principal of the three positions at the **current** sqrt price, using finite-range math and source rounding. Each position’s liquidity, salt, and ticks are stored separately. Donations to the pool are not `D`.
- `E_i`: uncollected **own** LP fees of the three positions, counted once. Not protocol fees, not another hook’s fees.
- Share backing `B_i = F_i + D_i + E_i`.
- Placeable inventory `T_i = F_i + D_i` only after a successful collection moves `E` into `F` once.

A balance increase is not caller principal. Unsolicited transfers remain donor risk under existing pretransfer law (`docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md`, cited by the zap PRD). FoT and rebasing underlyings stay forbidden (agent law).

**OD-2.** Whether an imported NFT may seed one or more wings. FullSpread import credits only assets delivered from the caller’s NFT and keeps the empty NFT. Extending that to three ranges is not authorized by that sentence. Default for this PRD: no import surface until the owner adds one.

## 5. Scalar issuance, redemption, manipulation

Concentrated value moves sharply with spot. Minting shares on spot `B_i` lets an attacker move the pool, deposit, and redeem against holders. FullSpread uses spot inventory for issuance and TWAP as an oracle, not as issuance NAV (package README, “issuance is not switched to oracle NAV”). That choice is **not** automatically safe for wings.

**OD-3 (blocking for any mint/redeem that uses spot).** Owner must pick one:

- A. Spot inventory backing, and accept same-transaction manipulation; or
- B. A stated max divergence between spot and a named TWAP before mint/redeem reverts; or
- C. Issuance on a TWAP-valued book, with the exact window and rounding written down.

This draft does not choose A, B, or C and does not invent a basis-point band. Execution-protection constants in the zap PRD (25/50/10/1 bp, D20) apply to FullSpread maintenance, not to this product, until the owner copies them.

Subsequent proportional join, if OD-3 is settled, uses `m = min_i floor(S * C_i / B_i)` on the complete three-position book, not on one wing. Exit pays `floor(shares * inventory_i / S)` of each concrete inventory component, then converts only through routes the owner has allowed. Single-token first mint is not authorized. FullSpread first mint requires both currencies (`zap PRD` §3; plan §2.1). Wings do not get a quieter exception.

**OD-4.** Whether v1 has a single-token zap at all. A zap must name which positions it composes against. “Proportional to the whole book” is not defined until OD-1 weights exist. Do not ship a zap by copying FullSpread’s one-range formula.

## 6. Sleeve and nested unlock

When `isUnlocked` is true, the vault must not call `unlock`. Blocked deposits use only the local sleeve. Blocked withdrawals pay only if `F_i` covers the quoted currency; otherwise revert `InsufficientLocalReserve`. The sleeve does not promise unlimited exit liquidity. Rebalance that needs `modifyLiquidity` or `swap` is forbidden while blocked.

**OD-5.** Sleeve target. FullSpread D3 is the fee-oracle percentage of **that vault’s one deployed principal**, default 20% (`zap PRD:32`). For three positions the base could be sum of `D`, center only, or a new parameter. Do not reuse 20% until the owner names the base. Deadband (max of token floor and 5% of target free) is likewise FullSpread D22, not yet this product’s law.

Fee-on collection while unlocked is impossible. Uncollected fees stay in `B` and out of `F` until an unlocked session collects them. Skipping collection is not a fee waiver; it is the lock constraint.

## 7. Fees and management bounds

Own LP fees accrue per position. Protocol fee, if any, is the vault fee oracle, not a new admin setter. No tick-migration function, no operator who can move ranges, and no permissionless swap-repair, until OD-6.

**OD-6.** After activation, are the three ranges immutable? If not, who may move them, by how many spacings per call, and what share-backing invariant must hold after the move? Permissionless rebalance that swaps holder inventory (FullSpread D9) is a different attack on three concentrated ranges. Do not copy D9.

First mint, if OD-1 and OD-3 are set, still requires both currencies positive and mints a decimal-scaled minimum to `address(0xdEaD)`, matching FullSpread’s sink rule only as a candidate. **OD-7:** confirm that sink and the `mean < 3 ? 1 : 10^(mean-3)` minimum, or replace them. Do not invent a new minimum.

## 8. Interfaces, SY, registry, DETF

DETFs may compose an eligible SE vault or a bare token. This product is not automatically eligible, and FullSpread is not the only eligible SE.

To be bufferable under existing APEX D68, an SE must implement `IStandardExchangeIn`, `IStandardExchangeOut`, and `IStandardExchangeTransitionQuote` (`quoteState` / `quoteTransition`). That is eligibility machinery, not a promise that DETF packages will bind this vault.

**OD-8.** v1 surface: In/Out only, plus transition quote, plus native SY, or a stated subset. FullSpread native SY is not inherited by a new package. No Pendle market deployment in this PRD.

Registry: new package salt from the full type name. Do not reuse a FullSpread salt. Instances immutable after `postDeploy`. No human `diamondCut`.

## 9. Adversarial and consumer matrix

Acceptance is specified here; it is not a claim that tests pass.

- Donation, exact-in push, exact-out refund, and pretransfer credit must not spend booked `F` or another caller’s residual.
- Spot move immediately before mint/redeem, under whichever OD-3 rule is chosen.
- Nested unlock: consumer already inside `unlock` on the same PoolManager; vault must not `unlock`; sleeve path or revert only.
- Three-position fee collection counted once; removing one position’s liquidity must not erase another’s salt.
- Reentrancy through the PoolManager callback and through ERC-20 hooks.
- Disabled vault: exits of existing shares allowed; new deposits blocked. Same shape as FullSpread unless OD-8 says otherwise.

Weighted consumer (`UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md:87`): `n ∈ [2, 8]`, at least one SE leg, raw legs allowed. A full 2^8 raw/SE grid is not required by that sentence.

**OD-9.** Name the minimum rows: for each `n` in 2..8, at least one all-raw row, one single-leg this-vault row, and one mixed row. Do not claim the Cartesian product is in v1. Orbital (3) and quad (4) rows are separate owner options, not implied.

## 10. Gas

`foundry.toml:38` `gas_limit = 30000000000` is a Foundry ceiling, not a chain block limit. A harness that reports `gasleft` around an internal call is not a transaction gas measurement. The cited ~1.28M figure is not evidence for three positions, three fee collections, or a nested-unlock sleeve path.

**OD-10.** Name the target chain and its block gas limit. Acceptance is a top-level transaction measurement, cold and warm, for: dual first mint that places all approved positions, one proportional join, one proportional exit, one blocked sleeve exit, and one public rebalance if OD-6 allows it. No numeric pass line until that limit and a measured baseline exist. Do not raise the Foundry ceiling to hide a hot path.

## 11. Non-goals

No FullSpread edit. No restore of unread commit `35f47b51`. No hook-factory deploy. No single-token bootstrap. No arbitrary tick recast. No in-place migration. No claim that this draft’s open decisions are economically safe.

## 12. Blocking owner decisions

OD-1 geometry and weights. OD-3 issuance manipulation rule. OD-4 zap in or out of v1. OD-5 sleeve base. OD-6 tick immutability and repair. OD-7 first-mint minimum. OD-8 interface/SY scope. OD-9 consumer rows. OD-10 chain gas limit. OD-2 import, only if import is wanted.

Implementation planning starts after OD-1, OD-3, OD-5, and OD-6. The others can follow, but they are not implied by FullSpread.
