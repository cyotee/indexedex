# Implementation plan — previewResidualBuffer stays internal

- **Date:** 2026-10-14
- **Status:** draft. Does not authorize code edits.
- **Controlling PRD:** `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.md`. The PRD controls on conflict.
- **Origin:** Stage-1 REQ-02 / OD-01 as narrowed by OD-08. This file does not reopen REQ-C04.
- **Owner request:** 2026-10-14. Change `previewResidualBuffer` from `external` to `internal`.

## Objective

Inline `previewResidualBuffer` into each of the four `_refundPairDust` / `refundPairDust` sweeps so the quote is a direct `previewExchangeIn` call on the production hook. A successful return of zero means the excess stays in the hook. A revert rolls the parent caller back. The function no longer carries an external selector.

## Read first

Read `CLAUDE.md`, `.github/ASSISTANT_RULES.md` and its coding and testing documents, `docs/testing/ARTIFACT_BUILDS.md`, and the controlling PRD. Use `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook`. Do not mock the hook, the bound Standard Exchange, the package, the manager, the registry, or the fee oracle.

## Scope (current production sweep copies)

Four `_refundPairDust` / `refundPairDust` definitions were re-read. Three are reached by production entries; one is uncalled.

| File | Function | Production callers |
|---|---|---|
| `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:367-379` | `_refundPairDust` | `single.deposit` (line 491), `single.depositWithSeShares` (line 582), `single.depositSingle` (line 712) |
| `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol:131-142` | `refundPairDust` | `withdrawSingle` inside the same library at line 66; `WithdrawTarget._refundPairDust` at `...WithdrawTarget.sol:338-341` which calls into this library's `refundPairDust` and which is reached from `single.withdrawSingle` (line 536, 575) |
| `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:388-400` | `_refundPairDust` | `single.deposit` (line 846), `single.depositSingle` (line 971), `single.withdraw` (line 1139), `single.withdrawSingle` (line 1215) |
| `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:477-489` | `_refundPairDust` | none found in `contracts/` |

Per PRD test instructions, the SeTarget copy is uncalled production code; cite it and do not add an entry to reach it. Three sweeps remain to exercise: `DepositCommon._refundPairDust`, `WithdrawalLib.refundPairDust` (reached via `WithdrawTarget._refundPairDust`), and `Target._refundPairDust`.

## Production entries that reach each sweep

| Sweep | Production entry | Function name on the proxy |
|---|---|---|
| `DepositCommon._refundPairDust` | dual proportional deposit, deposit-with-SE-shares, deposit-single | `single.deposit`, `single.depositWithSeShares`, `single.depositSingle` |
| `WithdrawalLib.refundPairDust` (via `WithdrawTarget._refundPairDust`) | single-token withdraw | `single.withdrawSingle` |
| `Target._refundPairDust` | dual deposit, deposit-single, dual withdraw, withdraw-single | `single.deposit`, `single.depositSingle`, `single.withdraw`, `single.withdrawSingle` |

`single` here means `IHook` as bound by `TestBase._bindProductPoolKey()` and the rest of the deploy path. The deposit-side SE shares helper is `_depositBothSeShares` in the TestBase.

## Order

The change is one visibility flip plus the call-site glue. Compile after each numbered step. Do not start step 3 until step 1 compiles.

| Step | Work | Why this order |
|---|---|---|
| 1 | Make `previewResidualBuffer` `internal` and remove the `external` selector | The signature change must land before any caller can compile against the new visibility |
| 2 | Inline the quote in each of the three reached sweeps; keep the four `if (preview == 0) return` branches | Each sweep is a separate copy and must be edited in place |
| 3 | Add Case 1 and Case 2 tests on the production TestBase | Production-path tests are the required acceptance evidence |
| 4 | Refresh artifacts; run the named suite; report | A green run on one suite is not a sweep-by-sweep proof |

## Step 1 — visibility flip

In `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol`:

- Lines 382-389: change `function previewResidualBuffer(uint256 amount) external view returns (uint256 shares)` to `internal view returns (uint256 shares)`.
- Keep the body as the direct `IStandardExchangeIn(l.standardExchange).previewExchangeIn(IERC20(l.pairToken), amount, IERC20(l.standardExchange))`.
- Do not add a `try/catch`. Do not add a zero check inside the preview.
- Update the NatSpec at lines 382-383 only if the existing text is unchanged: "Residual maintenance only. A zero quote means the amount cannot enter the vault yet and stays owned locally."

If any caller still names the public selector after this edit, the implementation session stops and reports that caller. Do not keep `external` to hide a compile error.

## Step 2 — inline the quote in each reached sweep

Each sweep's body is the loop:

```
for (uint256 i; i < 3; ++i) {
    uint256 bal = IERC20(l.pairToken).balanceOf(address(this));
    if (bal <= Repo.MAX_DUST_WEI) return;
    uint256 excess = bal - Repo.MAX_DUST_WEI;
    uint256 preview = ClaimLib.previewResidualBuffer(excess);
    if (preview == 0) return;
    ClaimLib.bufferQuotedResidual(excess, preview);
}
```

After inlining, each becomes:

```
for (uint256 i; i < 3; ++i) {
    uint256 bal = IERC20(l.pairToken).balanceOf(address(this));
    if (bal <= Repo.MAX_DUST_WEI) return;
    uint256 excess = bal - Repo.MAX_DUST_WEI;
    uint256 preview = IStandardExchangeIn(l.standardExchange).previewExchangeIn(
        IERC20(l.pairToken), excess, IERC20(l.standardExchange)
    );
    if (preview == 0) return;
    ClaimLib.bufferQuotedResidual(excess, preview);
}
```

Files and lines:

- `UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:367-379`
- `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol:131-142`
- `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:388-400`

`UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:477-489` is left untouched. Cite the file in the implementation report as the dead copy.

`bufferQuotedResidual` (line 393 in `ClaimLib`) stays `external`. Only `previewResidualBuffer` changes visibility.

Do not change the loop count. Do not change the `MAX_DUST_WEI` reference. Do not add a `try/catch` around the inlined call. Do not change the comment that says a zero quote retains the booked remainder.

After step 2, search the whole `contracts/` tree for `previewResidualBuffer`. The only hits must be the `internal` declaration in `ClaimLib`. Any `external` reference or any external call to the function is a regression. Remove and report.

## Step 3 — production-path tests

Add one test file at:

```
test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol
```

Inherit `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook`. Use the existing deploy path and the registry the TestBase already wires up. Do not use `new` for the hook. Do not replace the hook, the bound vault, the package, the manager, the registry, or the fee oracle.

The dust floor is `MAX_DUST_WEI = 10` (`UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol:19`). The excess the sweep quotes is `bal - MAX_DUST_WEI` only when `bal > MAX_DUST_WEI`. The tests must use that same excess.

### Test 1 — Case 1: zero quote

This case must succeed. The excess stays in the hook.

1. Deploy via the TestBase. Use `_seedLiveLiquidity()` or equivalent so the SE has supply and totalAssets above zero. Confirm the hook is live.
2. Reach a hook pair balance strictly above `MAX_DUST_WEI`. The accepted pairing is to transfer pair tokens directly to the hook (e.g. `pairToken.transfer(hook, excess)`) where `excess <= balanceOf(hook) - MAX_DUST_WEI`.
3. From the same view the sweep uses, call `IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), excess, IERC20(se))`. The test is this case only if that call returns 0. If every excess the hook can hold returns a positive share count, do not replace the vault to force a zero. Stop and report that Case 1 was not reached.
4. Record pre-call state: hook pair balance, hook SE share balance, caller pair balance, `feeTo` pair balance.
5. Call one production entry per reached sweep:
   - `DepositCommon._refundPairDust` → call `single.deposit` (or `depositSingle` or `depositWithSeShares`).
   - `WithdrawalLib.refundPairDust` → call `single.withdrawSingle`.
   - `Target._refundPairDust` → call `single.deposit` (or `single.withdraw`).
   Pick one production entry per reached sweep. A passing test of one entry does not prove the other entries' sweep copy still stops on zero.
6. Assert: hook pair balance is unchanged from the recorded excess; hook SE share balance did not increase from the dust sweep; caller pair balance is unchanged (no payout to caller); `feeTo` pair balance is unchanged. The legitimate payout from the deposit or withdraw must still meet that operation's own minimum; do not count that payout as the dust.
7. The test fails if the sweep deposits the excess, pays it out, or reverts because the quote was zero.

### Test 2 — Case 2: reverting quote

This case must revert the whole call.

1. Use the same production hook and bound vault as Test 1.
2. Reach a state the vault already supports in which `previewExchangeIn` of the sweep's excess reverts. The accepted ways without replacing the vault are:
   - The bound vault is `ERC4626StandardExchangeInTargetExt` wrapping `SimpleYieldERC4626`. `SimpleYieldERC4626` has no `previewExchangeIn` revert in its `convertToShares` path (it returns `assets` when supply is zero or totalAssets is zero, otherwise the proportional share). The `_previewExchangeIn` route it serves returns `vault.previewDeposit(amountIn)` for `address(tokenIn) == underlying && address(tokenOut) == address(vault)`, which does not revert on positive assets for this fixture.
   - No accepted fixture state in the TestBase or its helper bases produces a `previewExchangeIn` revert for a positive excess on the bound vault.
3. If no production state produces that revert, stop. Report that Case 2 was not reached. Do not mock the vault. Do not add a token or a vault that exists only to throw. Do not add a `catch` so Test 1 can pass.

If a future implementer finds an acceptable production state — for example, by routing the quote through a `se` whose `quoteState` probe reverts for the live state — Case 2 is reachable and Test 2 is added.

### What neither test may do

- Do not call `previewResidualBuffer` through a new public wrapper. After it is `internal`, the hook must not grow a selector for it.
- Do not accept any revert in Test 1. Test 2 names the quote failure. An unrelated minimum, deadline, or balance failure does not witness it.
- Do not treat a quote of zero as the revert case, or a revert as the zero case.
- Do not mock the hook or the Standard Exchange.

## Step 4 — build, run, report

After the production edit, refresh artifacts with `python3 scripts/forge-artifacts.py` before `forge test`. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`. Wait for compiler completion.

Run the new `UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol` and the existing `UniswapV4SingleStandardExchangeBufferConstantProductHook_Deploy.t.sol` (positive deploy proof). Report the commands actually run, the toolchain version, and any test that did not pass.

## What must not change

- `bufferQuotedResidual` stays `external`.
- The `if (preview == 0) return` branches stay in all four sweeps. Do not remove the check while changing the call.
- The `for (uint256 i; i < 3; ++i)` loop count stays at 3 in all four sweeps.
- The `bal <= Repo.MAX_DUST_WEI` early-out stays.
- `MAX_DUST_WEI = 10` stays.
- `_refundPairDust` in `SeTarget` is left alone (dead copy). Cite it.
- `bufferPair` in `WithdrawalLib` is left alone (it has its own zero check).
- Reserve sync on the deposit and withdrawal paths is not moved.
- No payouts to `msg.sender` or `feeTo` are added on a zero quote.
- No new catch is added.
- No production deploy, migration, or live-instance upgrade is performed.

## Done when

- `previewResidualBuffer` is `internal` and contains no `catch`. Its body still returns `IStandardExchangeIn(l.standardExchange).previewExchangeIn(IERC20(l.pairToken), amount, IERC20(l.standardExchange))`.
- Each of the three reached sweeps (`DepositCommon`, `WithdrawalLib`, `Target`) inlines the quote and keeps its `if (preview == 0) return`.
- The SeTarget copy is left as-is; the implementation report cites it as the dead copy.
- Test 1 (zero quote) passes for one production entry per reached sweep on the production proxy. Test 1 is the case only when the inlined call returns `0`; if not reachable, the implementation session reports and does not claim REQ-02 closed.
- Test 2 (reverting quote) passes if a production state exists; otherwise the implementation session reports that Case 2 was not reached and does not claim REQ-02 closed.
- The implementation session reports the commands actually run, the toolchain, and any test that did not pass.
- Stop after the report. Do not deploy.

## Blocking question

- Can the bound `ERC4626StandardExchangeInTargetExt` wrapping `SimpleYieldERC4626` reach a production state where `previewExchangeIn(IERC20(pairToken), excess, IERC20(se))` returns zero for some `excess > 0`? In the current TestBase, the SE has positive supply and totalAssets after seeding, and `SimpleYieldERC4626.convertToShares` returns positive for any positive assets in that regime. Case 1 may not be reachable on this fixture. The implementer is asked to confirm and either:
  (a) extend the TestBase or its helper bases to expose a production state that yields a zero quote (e.g., a disabled-vault state the bound vault already supports, an `if (amountIn > maxDeposit)` boundary in the SE), or
  (b) record that Case 1 was not reached and stop.
- Without an acceptable Case 1, REQ-02 is partial and the implementation session reports the gap.

I did not run Forge.