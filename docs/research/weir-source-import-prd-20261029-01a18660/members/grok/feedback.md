# Grok requirements advisory — weir-import-prd-r1

Verdict: SUPPORT WITH CORRECTIONS.

The draft is implementable and is the right fidelity baseline. It keeps the first `modifyLiquidity` return, the 10,000 performance-fee denominator, residual zap outputs, native settlement without an added `sync`, the configured Robinhood aliases, and end-of-successful-transaction invariants. It does not need another advisory round. This advisory does not replace the original and does not authorize implementation.

apply_patch is not active. This response is the complete feedback.

## Material corrections

### C-1. AC66 must not require a cast revert

WI-27, WI-31, and AC67 are right. AC66 contradicts them.

Source is `v.idle0 = uint256(int256(v.idle0) + net0)` and the same for idle1, then `_settle`. In the pinned 0.8 language, `int256(idle) + net` reverts only if that checked addition overflows. The explicit `uint256(...)` cast does not revert because the sum is negative or out of range. A negative in-range sum becomes a huge idle. Settlement then either pays that negative net from the shared token balance, which can consume a donation or another pool's inventory, or reverts if it cannot be paid, in which case the huge idle rolls back with the transaction.

AC66 currently says a compound hook that makes the add cost more than this pool's idle plus harvest reverts "on the idle cast" and restores both pools. That is not the source. A test written from AC66 would fail against the faithful copy or pressure a repair that makes the cast revert. Do not add that repair.

Replace AC66's expected result with the same split as AC67: checked-addition overflow rolls back; an in-range negative sum persists as a huge idle if settlement can be paid from shared inventory, and rolls back only if settlement cannot be paid. Do not state an idle-at-most-2 or cross-pool-conservation property for this path.

### C-2. AC51's sync condition is the manager's open sync, not only an outer caller

WI-22 correctly forbids adding `sync` on the native pay path. `WeirBase._pay` calls `poolManager.settle{value: amount}()` for native and does not sync. Crane `PoolManager._settle` reverts `NonzeroNativeValue` when the synced currency is nonzero and `msg.value > 0`. `unlock` does not clear `CurrencyReserves`, so the same condition is reachable from an outer `sync` before `unlock` and from a hook or token callback that `sync`s an ERC20 during the unlock before a later native pay.

Keep AC51 as characterization, not a fix. Widen the precondition from "outer caller" to any still-open ERC20 sync, including one opened inside the callback. Do not add `sync(address(0))`.

### C-3. AC63's equalities are successful-transaction claims, not callback or hook safety

WI-28, WI-29, WI-30, and AC61 already say callback views are awkward and that a hook which changes position liquidity is recorded, not patched. AC63 should say the same in the row, so the handler cannot be read as an unsupported safety property.

Condition AC63 as: after a successful transaction, outside the callback, for the standard-token no-liquidity-mutating-hook handler, `sum(sharesOf) + 1000 == totalShares` after the first successful deposit, `perfFeeBps <= 1000`, `treasury != 0`, and salt-zero position liquidity equals `v.liquidity`. The balance-versus-idle inequality stays standard-token only. Do not require those equalities at AC61's mid-withdraw window, under AC64's guarded-reentry revert, or under a hook that changes position liquidity. Rollback rows already require full restoration when the transaction reverts. Do not add a callback-time conservation invariant.

## Checks that hold

Versioned OZ V5 route. WI-02 and WI-03 are the right binding. The existing tree `lib/crane/contracts/external/openzeppelin-contracts-v5/` is present. Its `Pausable` header is v5.0.0 and its `ReentrancyGuard` header is v5.1.0, matching the frozen headers rather than the generic mixed tree or `lib/crane/lib/openzeppelin-contracts` 5.6.1. Coordinator source-notes say the nine compared files are byte-identical; this pass confirmed the path and those two headers, not a second body audit. Import rewrites to `@crane/contracts/external/openzeppelin-contracts-v5/...` use the existing `@crane/` remap. That is not a private clone, a new submodule, a `foundry.toml` edit, or a behavior-changing upgrade. Do not send this back to the generic tree.

Free-struct adjustment. WI-04's five sites are the source sites: `IPoolManager.ModifyLiquidityParams` at W:264, W:292, W:323, and W:349, and `IPoolManager.SwapParams` at W:397. Field order matches `PoolOperation`. Replacing only the qualification is an encoding-identical edit. No sixth site needs the same edit.

First caller-delta return. The poke, add, and remove calls bind `(BalanceDelta x,)` and ignore `feesAccrued`. WI-17 is faithful. The performance fee is `f * perfFeeBps / BPS` with `BPS = 10_000`, not 1,000,000. WI-31 correctly separates that checked division from explicit narrowing casts.

Residual outputs. WI-20 and AC25 correctly refuse a one-token exit and a full-consumption claim. A nonzero opposite-side residual after `zapTo` 1 or 2 is faithful.

Native sync. Do not insert `sync` before native `settle`. ERC20 pay remains `sync`, transfer, `settle`. AC51 stays a limitation test after C-2.

Robinhood aliases. Root `foundry.toml` already has `robinhood_mainnet`, `robinhood_mainnet_public`, and `robinhood_mainnet_alchemy`. WI-33 is right to name those and to treat presence as not proof of a working RPC or a pinned block. Chain 4663 does not need a new endpoint. A missing RPC stays missing evidence, not a skip-pass and not a hermetic failure.

Callback, rollback, and invariants. Deposit credits shares after unlock. Withdraw burns shares before unlock. Compound runs before deposit and withdraw inside the callback. Guarded reentry is `ReentrancyGuardReentrantCall`. Nested `unlock` remains `AlreadyUnlocked`. Direct `unlockCallback` remains `NotPoolManager`. Revert rows roll back. Those conditions should stay. C-3 only stops AC63 from being applied inside them.

## Original-proposal dispositions

Adopted, and should stay adopted:

- Grok, Astra, and Kimi fidelity classes, the three-file copy, GPL `LiquidityAmounts` retention, no namesake substitution, no viaIR, no bytecode-equality gate, and no ERC20, ERC4626, Diamond, registry, dead-share, or single-token work.
- Grok and Astra's rejection of the generic mixed OpenZeppelin tree. The draft's resolution is the existing versioned v5 tree, which neither original had found. That resolution stands.
- Grok's first-return, 10,000 denominator, payer-versus-recipient, pause-only-on-deposit, and shared-balance limitation, except where Grok treated a negative idle sum as an automatic revert. WI-31 and AC67 correct that. Do not restore it.
- Kimi's 88-line WeirBase and 68-line LiquidityAmounts aliases, ABI surface, and "do not describe an unguarded function as guarded."
- MiniMax's free-struct compile break, GPL retention, FullMath differential gate, and license-closure recording, except the items below.

Correctly not adopted:

- MiniMax B-14 and R-01, which treat the performance fee as the second `modifyLiquidity` return, `feesAccrued`. The source discards that return. Adopting it would change settlement.
- MiniMax R-03's claim that a successful compound keeps idle at most 2. That is not a source invariant. WI-27 is the replacement.
- MiniMax's statement that chain 4663 is absent from `foundry.toml` `[rpc_endpoints]`. The three Robinhood aliases are configured. WI-33 stands.
- MiniMax's WeirBase 93-line and LiquidityAmounts 61-line counts, and its shifted behavioral locators. Use the draft's aliases and the verified W:264, W:292, W:323, W:349, and W:397 sites.
- Astra's free-struct lines W:293 and W:398. The qualifications are at W:292 and W:397.
- Astra and Grok storage-slot gates and any requirement to reshuffle inheritance. WI-32 is enough.
- Astra's still-open OZ release blocker as a reason not to bind the versioned v5 tree.
- Any behavior-changing move onto generic Pausable v4.7 strings, ReentrancyGuard v5.5 ERC-7201 storage, SafeERC20 v4.9 strings, or OpenZeppelin 5.6.1.
- Adding native `sync`, a cast revert, escrow, preview-equals-withdraw, or a strict single-token exit.
- Kimi's generic "compare dependencies later" gate as a substitute for WI-02 through WI-06. The route is already chosen. WI-05's FullMath proof remains a release check, not a new research round.
- Another advisory round.

## What was not adopted from this advisory

No new safety property. No dependency change. No sixth source edit. No request to re-diff the nine versioned OpenZeppelin files before the coordinator publishes. C-1 through C-3 are row and precondition alignments with WI-22, WI-27, WI-29, and WI-31.

## Limits

This pass read the complete frozen draft through line 555, the three peer originals, and the admitted source-notes. Narrow rechecks were the five qualification lines, the versioned Pausable and ReentrancyGuard headers, `PoolManager.sync`, and `PoolManager._settle`. No Forge, Git, shell, build, test, install, deploy, or file write was run. Selector predictions and hand-derived storage slots from the original were not re-litigated. Coordinator byte-identity of the versioned OpenZeppelin files was not independently recomputed. No legal conclusion is added.

Stop here.
