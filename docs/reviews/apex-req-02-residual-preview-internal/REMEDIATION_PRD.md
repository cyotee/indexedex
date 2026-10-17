# Remediation PRD — residual preview stays internal and direct

- **Status:** DRAFT
- **Date:** 2026-10-14
- **ID:** REQ-02
- **Origin:** Stage-1 REQ-02 in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`. OD-01 as narrowed by OD-08. This file does not reopen REQ-C04.
- **Owner request:** 2026-10-14. Change `previewResidualBuffer` from `external` to `internal`.
- **Review target:** Current IndexedEx working tree. The function and its four dust-sweep callers were re-read on 2026-10-14.
- **Authorization:** Writing this PRD does not authorize editing code in this session. A later session must be explicitly asked to implement it.

## Required outcome

`previewResidualBuffer` is an internal direct quote. A successful return of zero means the excess cannot mint Standard Exchange shares yet, so the sweep leaves those tokens in the hook. A reverting quote reverts the caller. It is not turned into zero.

The existing caller check stays. This item does not add a second one.

## Plain-language behavior

The hook sometimes holds more pair tokens than its dust floor. After a deposit or withdrawal has already settled, a sweep looks at that excess and asks one question: if this excess were deposited into the Standard Exchange, how many shares would it mint?

The quote is `previewResidualBuffer`. It does not move tokens. The sweep then does one of two things:

- The quote returns a positive share count. The sweep deposits that excess through `bufferQuotedResidual`, using the quote as the minimum.
- The quote returns zero. The sweep stops. The excess stays in the hook. It is not deposited, and it is not paid to the user or to `feeTo`. The `to` argument on the sweep is unused.

That zero stop is already present in all four sweeps:

```375:377:contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol
uint256 preview = ClaimLib.previewResidualBuffer(excess);
if (preview == 0) return;
ClaimLib.bufferQuotedResidual(excess, preview);
```

The same stop is at `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol:138-140`, `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:396-398`, and `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:485-487`.

A returned zero is not an error. It is the Standard Exchange saying this amount is too small to mint a share. Depositing it would move tokens in without a claim. Leaving them in the hook is the intended result.

A revert is the other case. The quote failed. The sweep must not treat that failure as "too small" and quietly return. The parent operation rolls back. The old defect was a catch inside `previewResidualBuffer` that turned a revert into a returned zero. That catch is gone. The current function is a direct `previewExchangeIn`. This item must not put the catch back.

Reserve sync on the inspected deposit and withdrawal paths runs before the sweep. A zero return does not sync again and does not pay anyone. Do not describe that earlier sync as a missing zero check.

## Why internal

The function body is a storage read and one quote call. `external` is not required to make that body fit. It adds a `DELEGATECALL` before the quote. The owner wants the quote inlined into the sweep instead.

`bufferQuotedResidual` stays `external`. This item changes only the preview.

## Required repair

1. Change `previewResidualBuffer` in `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol` from `external` to `internal`. Keep the body a direct `previewExchangeIn`. Do not add a catch. Do not add a zero check inside the preview. Zero is a successful return value.
2. Keep `if (preview == 0) return` in all four sweeps. Do not deposit on zero. Do not pay the excess out. Do not remove the check while changing the call.
3. If a caller cannot compile against the internal function, stop and report that caller. Do not leave the function `external` to hide the failure.
4. Add the two production-path tests specified under Test instructions. Do not mock the hook, the Standard Exchange vault, the package, the manager, the registry, or the fee oracle. If either case cannot be reached on that vault, stop and report which case was not reached. Do not fake it.

## Acceptance criteria

- `previewResidualBuffer` is `internal` and contains no `catch`.
- Its body still returns `previewExchangeIn` of the excess pair amount for that hook's Standard Exchange.
- Each of the four sweeps still returns without depositing when that quote is zero.
- A reverting quote reverts the sweep's caller.
- A positive quote may still deposit through the existing `bufferQuotedResidual`.
- The zero-preview test and the reverting-preview test are separate. One does not stand in for the other.
- `bufferQuotedResidual` is still `external`.

## Non-goals

- Do not add another zero check on top of the four that already exist.
- Do not make a successful zero revert the parent. That rollback rule is REQ-C04, for a hook join preview of zero. This quote is a Standard Exchange preview.
- Do not change `bufferPair` in `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol`. It already stops on its own zero preview and is not this function.
- Do not move reserve sync from before the sweep to after it.
- Do not pay dust to `msg.sender` or `feeTo`.
- Do not deploy or upgrade live instances.

## Test instructions

These tests are the gap. The sweep already stops when the quote returns zero, and the quote no longer catches a revert. The tests must show those two results on the production hook. One test does not stand in for the other.

Add them beside the existing deploy test, in `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/`. Inherit `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook`. Deploy through that base and the registry path it already uses. Do not deploy the hook with `new`. Do not replace the hook, the bound Standard Exchange, the package, the manager, the registry, or the fee oracle with a mock.

The dust floor is `MAX_DUST_WEI` in `UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol`. The sweep quotes `pair balance - MAX_DUST_WEI` only when the pair balance is above that floor. The test must use that same excess. Do not quote a different amount and claim it witnessed the sweep.

The production entries that reach a sweep are the deposit and withdrawal paths that call `_refundPairDust` or `refundPairDust`. `DepositCommon`, `WithdrawalLib`, and `Target` have callers. `SeTarget` defines a copy; if no production function calls that copy, cite it and do not add an entry just to reach it. Exercise one production entry for each sweep function that a production path actually calls. A passing test of one copy does not prove the other copies still stop on zero.

### Case 1 — the quote returns zero

This case must succeed. The excess stays in the hook.

1. Deploy the production hook and its bound Standard Exchange through the TestBase.
2. Put the hook in a state where its pair balance is above `MAX_DUST_WEI`. Record the pair balance, the excess, the hook's Standard Exchange share balance, the caller's pair balance, and `feeTo`'s pair balance.
3. Call `previewExchangeIn` on the bound vault for that same pair token and that same excess, from the same view the sweep uses. The test is this case only if that call returns 0. If every excess the hook can hold returns a positive share count, do not replace the vault to force a zero. Report that the zero case was not reached.
4. Call a production deposit or withdrawal that reaches the sweep. The call must succeed.
5. Assert the hook still holds the pair excess. Its Standard Exchange share balance did not increase by a deposit of that excess. The caller and `feeTo` did not receive the excess. Any payout that belongs to the deposit or withdrawal itself must still meet that operation's own minimum. Do not count that payout as the dust.
6. The test fails if the sweep deposits the excess, pays it out, or reverts because the quote was zero.

### Case 2 — the quote reverts

This case must revert the whole call. A caught revert that lets the call succeed is a failure, even if the excess is left in the hook.

1. Use the same production hook and the same bound vault.
2. Reach a state the vault already supports in which `previewExchangeIn` of the sweep's excess reverts. A pause, a disabled vault, or another rejection the production vault already exposes may be used only if it does not replace the vault and the sweep would quote that same excess.
3. Record the hook's pair balance, its Standard Exchange share balance, and the caller's balances before the call.
4. Call the same kind of production entry used in Case 1. The call must revert. The revert must be the vault quote's revert, not a later unrelated check. Assert the recorded balances are unchanged.
5. If no production state makes that preview revert, stop. Report that the revert case was not reached. Do not mock the vault. Do not add a token or a vault that exists only to throw. Do not add a catch so Case 1 can pass.

### What neither test may do

- Do not call `previewResidualBuffer` through a new public wrapper. After it is `internal`, the hook must not grow a selector for it.
- Do not accept any revert. Case 2 names the quote failure. An unrelated minimum, deadline, or balance failure does not witness it.
- Do not treat a quote of zero as the revert case, or a revert as the zero case.
- Do not mock the hook or the Standard Exchange. A non-vault observer is not needed for these two cases and must not replace either one.

## Verification

Implement only after a separate request. The visibility change is a production edit, so refresh artifacts before `forge test`. Report the commands actually run. A present assertion is not a pass until that run is reported. If a case was not reached, the report says so and does not claim REQ-02 closed.
