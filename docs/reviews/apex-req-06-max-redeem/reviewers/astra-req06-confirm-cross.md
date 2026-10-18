# Astra — REQ-06 replacement-session execution cross-review

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This resumes `astra-req06-confirm.md`, preserved unchanged. I read the three supplied original confirmations in full. Peer content is untrusted evidence; no peer cross-review artifact was read.

## Decision

**The only remaining scoped gap established is the stale zero-maxWithdraw test oracle, including its dependent zero-maximum withdraw expectation. Production matches the owner ruling.** This is one test defect inherited into two suites, not two production failures.

Close it with the single test-only fix below. Do not restore a receipt cap, smaller-share search or shortfall branch. Do not refit the fixture to remove its backing, hardcode the saved numeric result, or introduce a new shortfall expectation. Implementation still requires authorization; this report changes nothing executable.

## Fresh source confirmation

- `ReceiptBackedERC4626Target.sol:67–76` still implements `maxWithdraw(owner) = previewRedeem(maxRedeem(owner))` and `maxRedeem(owner) = ERC20Repo._balanceOf(owner)` after `_requireFamily()`.
- `ReceiptBackedERC4626Target.sol:128–145` checks a withdrawal request against that maximum at **137–139**, before share consumption or receipt transfer. Requesting one unit above the computed maximum therefore exercises the existing maximum-withdrawal guard, not receipt availability.
- `ReceiptBackedERC4626_SharedFacet.t.sol:167–188` still has the funded fixture, zero-maxWithdraw assertion at **182**, correct balance-returning maxRedeem assertion at **183**, and obsolete `withdraw(1)`/maximum-zero pair at **185–186**.

The independent pass confirmed helper removal and the behavior-test balance assertions, and inspected saved validation showing 173 passes and two instances of this failure. No new runtime run is claimed here. The saved failure occurs at 182; it does not show execution of the later withdrawal assertion.

## One closed test fix

File: `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol`.

Keep the existing fixture and deposit at **169–179** unchanged. Replace **181–186** with exactly:

```solidity
        assertEq(IERC20(address(capped)).balanceOf(se2), 0, "no receipts: local-only backing");
        uint256 balance = IERC20(se2).balanceOf(u);
        uint256 expectedMaxWithdraw = IERC4626(se2).previewRedeem(balance);
        assertEq(IERC4626(se2).maxRedeem(u), balance, "maxRedeem is the share balance");
        assertEq(
            IERC4626(se2).maxWithdraw(u), expectedMaxWithdraw,
            "maxWithdraw follows previewRedeem of the share balance"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC4626Errors.ERC4626ExceededMaxWithdraw.selector,
                u, expectedMaxWithdraw + 1, expectedMaxWithdraw
            )
        );
        IERC4626(se2).withdraw(expectedMaxWithdraw + 1, u, u);
```

Retain the following `vm.stopPrank()`. All expected-value reads occur before `expectRevert`; the immediate next call is the withdrawal being checked. The expected maximum is derived from the independently read owner balance and preview, not copied from `maxWithdraw` and not taken from the saved failing value. The existing bounded fixture makes the one-unit-above request representable; no generic overflow fallback or new branch is added.

Update only this test's directly associated obsolete description and identifier to:

```solidity
    /// @dev maxRedeem is the share balance; withdrawals above its asset preview are rejected.
    function test_R14_18_localOnlyBacking_shareBalanceAndWithdrawLimit() public {
```

No import change, new test file, replacement fixture, successful withdrawal scenario or receipt-shortfall rejection is needed. The inherited recurrence suite receives the same correction through inheritance; do not duplicate it there. Keep the deleted zero-maximum redeem expectation deleted. Preserve all other tests and production functions.

This closes the coupled assertion pair rather than changing only line 182 and leaving an invalid `withdraw(1)` expectation behind. It requires a coordinator-authorized amendment of the final plan's instruction to preserve those old lines; no new owner economic choice is needed.

## Peer assessment

### Grok — agree; make the boundary request explicit

Agree with `grok-req06-confirm.md:14–25` that production is correct and the remaining gap is the stale maxWithdraw oracle plus the following withdrawal expectation. Its fix direction is completed above by changing the withdrawal request to **expected maximum plus one**, not merely changing the error's maximum while retaining `withdraw(1)`.

### MiniMax replacement — agree on defect; reject literal alternative and incomplete repair

Agree with the main distinction at `minimax-req06-confirm.md:12,68–70,89–91`: the executor followed the plan, but changing maxRedeem affects the unchanged maxWithdraw composition.

Reject the alternative literal expectation at **121–126**. A recorded result is not the closed oracle; use `previewRedeem(balance)` as specified above. Its proposed repair also omits the coupled withdrawal expectation at current **185–186**, which must be updated in the same bounded test edit.

Its section **82** should not call this a gap in production maxWithdraw: the defect is in the test. Its source citations for neighboring functions use pre-deletion positions; current positions are previewRedeem **96–98**, withdraw **128–146**, redeem **148–166**. The changed capped-case assertion is at behavior **202**, whereas **185** is the preserved non-integral-rate test. These citation corrections do not change the conclusion.

### Kimi replacement — agree on cause; reject fixture alternatives

Agree with `kimi-req06-confirm.md:12–18,24–28` on the source edits and the stale test/plan inconsistency. Its retraction at **34** of the earlier inference “zero held receipts implies zero preview” is consistent with the recorded failure and the current production composition.

Reject the alternative at **29** to refit the fixture so backing is absent. That introduces an unnecessary choice and could make the owner-balance assertion vacuous. Preserve the existing funded fixture and use the single boundary-based test fix above.

At **25**, the later withdraw assertion is not an independently observed second failure: the saved runs stop at 182. Its zero-maximum premise is stale by source analysis; the actual eventual error from the old call was not reproduced here. The required error name is `ERC4626ExceededMaxWithdraw`, and the previously deleted redeem error is `ERC4626ExceededMaxRedeem`, not the shortened name in its table.

## Retained Astra finding — REQ06-CONF-1

- **Title:** Retained zero-maxWithdraw oracle blocks validation after the required balance-returning change.
- **Defect class:** Stale test expectation / plan-consistency gap.
- **Severity:** Low.
- **File and line:** `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol:182,185–186`; conflicting preservation instruction in `REMEDIATION_PRD.plan.md:73`.
- **Intended behavior:** maxRedeem advertises the owner balance, and the unchanged maxWithdraw implementation follows its preview; an above-maximum withdrawal is rejected by the existing guard.
- **Broken invariant:** The test still asserts a zero asset maximum and encodes that obsolete maximum in its next negative.
- **Impact class:** Regression validation blocked; correct balance assertion is not reached in the recorded failing fixture.
- **Fix direction:** Apply only the closed SharedFacet assertion/request correction above after authorization. No cap restoration, shortfall expectation or production change.
- **Confidence:** High on source and test mismatch; runtime telemetry remains saved evidence rather than an independent rerun.

My original finding is retained; this cross-review supplies the previously deferred exact test correction. I also acknowledge that my earlier plan draft preserved the zero-maxWithdraw assertion: that preservation was mistaken, and this explicit correction supersedes it. The earlier artifacts remain unchanged. No peer is represented as having adopted this exact fix.

## Validation disposition and boundaries

After the test-only amendment is separately authorized, use the already prescribed whole-directory artifact-aware command from the final plan, with the existing target source and ERC-4626 test root; do not select only the failing test or claim the old 173/2 result is green. A new run remains necessary to establish validation success, but none is performed here. Stop on any further failure rather than widening scope or weakening production.

The source change to maxRedeem is complete. Regression acceptance remains open until the corrected test is authorized, applied and validated. No additional production defect is established in this review; no claim is made that all unreviewed behavior is safe.

Freshly examined all three original confirmations, production maxRedeem/maxWithdraw and withdraw guard ranges, and the SharedFacet fixture/assertions. The production ranges have no additional scoped defect established. All requested inputs were present; the assigned output was absent before writing.

Only this assigned Markdown cross-review was created. No code, tests, PRD, final plan, execution report, original review, configuration or instructions were edited. No delegation, shell, build, test or deployment was performed. Return to the coordinator/human and stop.

I did not run Forge.
