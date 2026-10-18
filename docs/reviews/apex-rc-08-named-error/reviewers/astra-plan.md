# Astra — RC-08 named-error implementation draft

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. No other reviewers' notes were read. Read `docs/reviews/apex-rc-08-named-error/REMEDIATION_PRD.md` in full. The owner-selected error and its library placement control over my earlier requirements recommendation to declare it in the target. This draft does not authorize implementation.

## 1. Preconditions and fixed scope

The two current OutTarget equality guards still match the PRD: original **879–881** and **1007** are blank reverts on held LP not equal to `vaultLpReserve`. The existing `InsufficientLPBacking` declaration/check at **1015–1018** remains a distinct less-than guard. No cited production drift was observed.

Change only:

- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`.
- One new test file: `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol`.

Before later authorized implementation, recheck the exact predicates, surrounding order and error-library contents. If a named guard has moved or changed, or the new test path already exists with other content, stop and report. Do not select another revert or expand to InTarget.

## 2. Exact production changes

### Declaration

Inside the existing `UniswapV2LpBacking` library at the bottom of OutTarget, immediately after `InsufficientLPBacking(uint256 held, uint256 required)`, add exactly:

```solidity
    /// @notice Held LP differs from the booked LP reserve, in either direction.
    error LPReserveMismatch(uint256 held, uint256 booked);
```

Do not rename or modify `InsufficientLPBacking`, `requireHeld`, `_requireLpBacking`, or the existing less-than call. Add no new comparator/helper or public selector. Do not guess a numeric error selector.

### First equality guard

Replace original **879–881** with:

```solidity
        {
            uint256 heldLp = indexSource.pool.balanceOf(address(this));
            uint256 bookedLp = vault.vaultLpReserve;
            if (heldLp != bookedLp) revert UniswapV2LpBacking.LPReserveMismatch(heldLp, bookedLp);
        }
```

Keep this block after `_calcAndMintVaultFee` and before the exact-output zap-in quote, at the same point as the existing guard.

### Second equality guard

Replace original **1007** with:

```solidity
        {
            uint256 heldLp = indexSource.pool.balanceOf(address(this));
            uint256 bookedLp = vault2.vaultLpReserve;
            if (heldLp != bookedLp) revert UniswapV2LpBacking.LPReserveMismatch(heldLp, bookedLp);
        }
```

Keep it after the existing `_loadStrategyVault(vault2, tokenIn)`, payout and refund sequence. Each block reads the compared values once, reports held first/booked second, and keeps `!=`. Do not move the checks, weaken them to `<`, correct the balances, change refund/payout amounts or catch either revert. The small local scopes avoid extending the added locals across the surrounding arithmetic.

## 3. Existing-test search result: do not rewrite a different route

No existing test was positively identified as expecting the blank error from either of these **OutTarget** sites.

There is a tempting but incorrect match:

- `UniswapV2StandardExchange_SecRemediation.t.sol:408–432` contains `vm.expectRevert(bytes(""))` at **425**, but its next call at **426–428** is **`vault_.exchangeIn`**, not exchangeOut.
- The decimals counterpart at `decimals/UniswapV2StandardExchange_SecRemediation_Decimals.sol:83–107` likewise uses a bare expectation at **100** followed by **exchangeIn**.
- Current `UniswapV2StandardExchangeInTarget.sol:730–731` has a separate blank LP equality guard. That source is not an edit target in the owner-selected PRD. Do not update those existing expectations to the new OutTarget error or change InTarget to make such an update pass.

Other inspected candidates included the existing lower-bound focused check in SecRemediation **608–627**, pass-through quote/execution controls, and generic slippage/zero-input negatives. The lower-bound test already expects `InsufficientLPBacking`; leave it unchanged. Generic `expectRevert()` matches do not by themselves identify the guard reached. Searches covered the Uni V2 test directory and the exact empty-bytes pattern across `test/`; this is a positive route classification, not a claim that every indirect negative in the repository was executed.

## 4. One new test file, using the existing production fixture

Create `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol` with concrete contract `UniswapV2StandardExchangeOut_LPReserveMismatch_Test` inheriting the existing `TestBase_UniswapV2StandardExchange_MultiPool`. Use its balanced pool and registry-deployed vault. Import `UniswapV2LpBacking` from the production OutTarget file for the exact selector. Do not copy the equality predicate into a fake SUT, add a mocked vault, expose a new production selector or write production storage.

Add these fixed production-route cases:

1. `test_zapInVaultDeposit_lpMismatch_reportsHeldAndBooked`: exercise the existing OutTarget route whose input is a pool constituent and output is the vault share, using the established fresh-vault LP-custody fixture pattern. The expected booked LP is the fixture's initial zero checkpoint, not a live totalAssets quote. Capture the actual held LP immediately before the operation, require a nonzero mismatch precondition, and expect the new error. Keep the caller properly funded/approved so an earlier funding check is not substituted for the equality check.
2. `test_passThroughZapIn_lpMismatch_reportsHeldAndBooked`: exercise the OutTarget route whose input is a pool constituent and output is the pool LP token, on the same independently initialized fixture state. Assert the output recipient is separate from the vault. Capture the opening held LP and initial booked checkpoint; require the mismatch precondition and the same exact error. Its equality check is after settlement, so assert the whole operation rolls back: both underlying token balances, pool LP balances, caller/recipient/vault shares, and recorded reserves return to the pre-call values.
3. `test_zapInVaultDeposit_matchingLp_preservesSuccess`: retain a fresh matched-book control on the first route; quote through `previewExchangeOut`, execute the funded false-flag operation and require the normal requested share delivery and input debit.
4. `test_passThroughZapIn_matchingLp_preservesSuccess`: matching-book funded control on the second route, checking the route's existing output and input semantics without changing them. Do not impose a new exact-LP-payout rule on a pass-through route that currently allows at-least output.

For each mismatch test, the exact assertion is:

```solidity
        vm.expectRevert(abi.encodeWithSelector(
            UniswapV2LpBacking.LPReserveMismatch.selector, heldBefore_, bookedBefore_
        ));
```

`heldBefore_` is the actual pool-token `balanceOf(address(vault_))`; `bookedBefore_` is explicitly `uint256(0)` for the fresh-vault checkpoint fixture. Assert the fixture is initially unissued and use the existing initial-checkpoint setup, not an arbitrary replacement value or `reserveOfToken` assumed interchangeable with ERC4626 bookkeeping. `_loadStrategyVault` uses `ERC4626Repo._lastTotalAssets()` at Common **139**. The test must not silently use a different backing quantity.

Use the production `exchangeOut` public entry for both mismatch cases, from the funded test contract with `pretransferred=false`; no EOA pretransfer negative and no changed refund rule. Cache all views/quotes before the expected-revert call. Include unchanged-state assertions in both mismatch tests. Do not merely assert the selector or accept any revert.

These are defensive regression specifications, not a live-system reproduction recipe. If a selected production route rejects earlier, yields different compared values, or cannot reach its equality check with the existing fixture, **stop and report** the precise failure; do not broaden the expected error, fabricate state or pick another route. The fixed implementation choice remains the two inline named guards, not a menu of helper designs. Compilation and runtime reachability have not been exercised by this reviewer.

The preserved `!=` source predicates cover both surplus and deficit directions; the funded production mismatch cases need not manufacture a balance deficit through storage writes merely to exercise both signs. Static review must confirm both predicates remain inequality checks and the lower-bound helper remains unchanged.

## 5. One validation command

From IndexedEx root in a later authorized implementation session:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2 \
  -- -vv
```

This explicitly refreshes the changed production source and its deployable dependents before running the whole existing Uni V2 test directory, including the new file and unchanged lower-bound/exact-input controls. No test-name filter. Use the default hermetic profile; do not enable `via_ir`, delete `out/` or `cache_forge/`, change source/test paths, or deploy/broadcast anything.

If compilation or a test fails, stop and report. Do not amend another production route, convert unrelated blank expectations, loosen `!=` or change refunds to obtain a green run. Record the actual command/result in a separately authorized execution record; a saved log is not an independent reviewer rerun.

## Acceptance and evidence boundaries

- One new error declaration in the owner-selected library, with held/booked argument order.
- Two in-place equality guards use it; no less-than substitution or change to the existing lower-bound error.
- Correct production-route tests expect the complete encoded error and preserve rollback/success controls; the existing exchangeIn blank-revert tests are not misidentified as these OutTarget cases.
- No unrelated production or fixture changes.

Read the controlling PRD, both current guards and surrounding routes, the local error library, existing explicit blank-revert and decimals tests, the existing lower-bound test references, a pass-through success suite, and strategy-book loading references. No separate audit report or implementation plan was supplied. Input paths were present; the assigned report was absent before writing. No peer artifacts were opened. Repository routing, canonical testing guidance and artifact workflow were read directly earlier in this session.

Only this assigned Markdown draft was created. No code, tests, PRD, final plan, configuration or instructions were edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop.

I did not run Forge.
