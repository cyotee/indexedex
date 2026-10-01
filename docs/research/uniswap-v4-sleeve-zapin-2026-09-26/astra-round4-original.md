# Astra — round 4 independent original

**2026-09-27; research only.** Latest owner overrides earlier swap-free public-rebalance and hook-admission recommendations. Existing deposit route, post-swap B, entire caller basket, proportional issuance, mint-last and literal 20%-of-owned-deployed remain. No peers/cross-reviews read; no execution performed. **V/** means `contracts/protocols/dexes/uniswap/v4/`; **Common** is its `UniswapV4StandardExchangeCommon.sol`.

## 1. Explicit correction: pretransfer is settled, not a provenance question

I withdraw my earlier provenance-witness, pull-only and donation-capture objections. `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:21,35–47,294–303` permits eligible contract callers to claim `amount<=held−localSnapshot`, including unbooked surplus. Atomic transfer+operation is integrator responsibility; origin identification is not required. Exact-in credits the declared amount, refunds nothing, and absorbs unclaimed surplus at end sync.

**Implementation gaps, not new owner decisions:**
- `contracts/vaults/basic/BasicVaultRepo.sol:23–27,91–109` specifies local held inventory, not economic reserves. `MultiAssetBasicVaultRepo.sol:21–26` uses the same slot. Yet V4 `_syncVaultReserves` stores deployed+held+fees (`Common:605–630`), then pretransfer subtracts **current** deployed from that historical total (`:1274–1288`). Price changes and uncollected fees mean this is not a durable held-balance snapshot. Separate economic accounting from local credit accounting; preserve required public economic views rather than blindly overwrite their meaning.
- `BasicVaultCommon.sol:73–76` requires the public caller guard; `LocalCreditLib.sol:24–27` implements it. None appears in the inspected V4 entry/override (`InTarget:37–67`, `Common:1270–1288`); package-local search found none. Record an EOA-guard code/law gap, not authority to add provenance restrictions.
- Determine credit **before** internal fee collection/sync. End-sync every expected held token after all settlements/transfers on deposits, exits, swaps and public repair. Current mint-before-tail sync (`InBase:306–311`) is not the required final checkpoint. Tests distinguish intentionally claimable unbooked units from protected booked sleeve.

## 2. Recommended numeric defaults—proposals, not measured safe constants

| Control | Recommended starting value and meaning |
|---|---|
| Terminal spot impact | **50 bp per operation**, `max(P_after/P_before,P_before/P_after)-1<=0.005`; 25 bp conservative, >100 bp public repair discouraged without evidence |
| Execution slippage | **10 bp** adverse shortfall against the same-state, fee-inclusive executable quote; not another price-impact allowance |
| Fees | **100 bp maximum aggregate effective swap charges** as a configurable starting ceiling; includes protocol/LP/hook charges, excluding impact; higher-fee markets need deliberate configuration |
| Anchor deviation | **200 bp** start/end deviation from a independently validated reference; candidate **30-minute TWAP**, newest observation **≤5 minutes old**, sufficient history and no same-block-only seeding |
| Numerical alignment | **1 bp**, including final share-flooring loss as below |
| Sleeve deadband | Existing **5% of F*** plus token absolute floor; do not confuse this with trading tolerance |

P is token1/token0 price, not sqrtPrice: applying 50 bp directly to sqrtPrice approximately doubles the intended price move. These conservative starting limits trade liveness for safety; they are not empirical calibration. A pool quote already incorporates impact/fees, so its 10 bp check must not subtract those costs twice. minShares remains an additional count bound, not independent fair-price protection.

## 3. Repeated public repair: allowed, but per-call caps are insufficient

Explicitly supersede local D28 and draft ZR-5/PZ-8's swap-free-public clauses. **Deposit swaps** still spend only the credited caller basket. **Permissionless repair swaps** spend vault-owned imbalanced inventory, mint no shares and charge incumbent holders the resulting costs; own-LP fees return only the vault's earned fraction. Do not automatically run whole-book trading from every deposit tail or bill its costs to the new depositor.

Choose direction/amount internally, preserve required sleeve coverage after coupled placement, and make a bounded progress step. Repeated calls may continue until a target, dust threshold or risk budget binds. No guaranteed convergence under changing markets; no reward for pointless churn.

**Preferred anti-splitting policy:** per-vault shared **100 bp cumulative absolute log-price travel per 30-minute repair window**, plus gross input turnover capped at **10% of each token's window-start owned book**. Count both directions without netting and aggregate callers; do not reset budgets/anchors per call. Combined with the reference check above, this limits same-block splitting and fee churn. The independent reference validates resets; a fresh manipulated spot is not a safe reset anchor. Thin/young pools without valid reference defer swaps, while feasible add/remove work remains available.

Without cumulative controls, twenty consecutive +0.5% moves permit approximately **10.5%** total movement; reversing trades can charge fees even with little net price displacement. A finite anchored budget without independent reference still needs a trusted reset policy and cannot establish fair starting price. Permissionless repeated progress and unlimited immediate repair cannot both be promised safely.

Measure improvement against a consistent anchored composition/feasible-deployment metric, not raw token-unit sums; stop when marginal progress is below dust or costs dominate. Exact metric and gas bounds are engineering specifications, not new share NAV.

## 4. Hook flags cannot prove Universal Router compatibility

Context7 consulted first (`/uniswap/docs`). Primary sources below confirm:

- Universal Router `Dispatcher.dispatch` sends `V4_POSITION_MANAGER_CALL` through `_checkV4PositionManagerCall`. `V3ToV4Migrator` restricts it to `modifyLiquidities` and rejects increase, decrease and burn actions: **mint-only among position-altering actions**, not a general existing-position liquidity interface.
- PositionManager itself supports mint/increase/decrease/burn via `_handleAction`, with ownership checks and hookData forwarding.
- Core `Hooks.isValidHookAddress` validates flag relationships; callbacks execute arbitrary hook logic with sender/hookData. Flags describe callbacks, not their acceptance conditions, pricing or future behavior.

No liquidity-callback flags gives limited evidence that those hook callbacks cannot veto add/remove. It proves neither initialization/swap compatibility, token settlement success, caller permissions nor Universal Router command support. Successful simulation proves only the tested context/time.

Our vault uses **direct PoolManager** swap/modifyLiquidity with empty hookData (`Common:1015–1062`), not Universal Router/PositionManager routing. A hook may accept PositionManager but reject the vault sender, or require nonempty data. Universal Router mint success therefore does not certify the vault lifecycle.

**Apply owner's fallback:** deployer assumes supplied PoolKey compatibility; no discretionary hook whitelist or flag-based admission rejection. Runtime settlement, actual-fill/accounting and protection checks remain mandatory. Admission assumption does not make vanilla quotes accurate: arbitrary/dynamic hooks require faithful projection/simulation or an explicit quote failure, not fabricated output guarantees.

## 5. Alignment and best effort

For positive post-swap incumbent B and actual caller C, let `r_i=C_i/B_i` and existing `m=floor(S*min(r0,r1))`. Use unitless realized uncompensated-contribution bound:

`epsilon = max_i(1 - m*B_i/(S*C_i)) <= 0.0001`.

It includes alignment and share-flooring loss; compute safely by cross-products. Caller sleeve stays in C. **Best effort** means bounded search, acceptable small mismatch, partial feasible deployment and disclosed residual—not unlimited donation when a price cap prevents alignment. Exact-in retains/credits the entire basket without refund. If positive C cannot produce nonzero m within the approved economic bound, revert; do not silently mint an invariant-growth fallback. Public repair can instead stop with residual and no new shares. Placement-only failures may defer when funds/accounting remain sound; settlement/protection failures remain atomic.

## Sources, limits and remaining decisions

Primary URLs accessed **2026-09-27** (moving main, not deployment pins):
- https://raw.githubusercontent.com/Uniswap/universal-router/main/contracts/base/Dispatcher.sol
- https://raw.githubusercontent.com/Uniswap/universal-router/main/contracts/modules/V3ToV4Migrator.sol
- https://raw.githubusercontent.com/Uniswap/v4-periphery/main/src/PositionManager.sol
- https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/Hooks.sol

Observed pragmas: Router ^0.8.24; PositionManager 0.8.26; Hooks ^0.8.0. Local compiler 0.8.35; exact upstream/local deployed revisions unverified. Initial guessed upstream `contracts/modules/V4PositionManager.sol` returned 404; not retried. Canonical hook skill and current authority read directly.

**Only remaining owner decisions:** approve/configure numeric risk envelope; choose configuration authority/source and anchor/reference/reset availability policy; explicitly accept cumulative throttling versus per-call-only exposure. Pretransfer and deployer hook responsibility are settled. Confidence high on source/law findings and formulas; medium/low on uncalibrated risk defaults. No security/economic tests were run.
