# Kimi K3 — requirements review of the draft remediation PRD

- **Question asked:** Are there open items, or requirements questions, that would force an implementer to invent product law before executing `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`?
- **Answer:** No blocking owner decisions are required. Every choice that changes the correction or the acceptance test is already answered by the draft PRD or by the APEX remediation PRD it cites. The remaining choices are implementer details that do not change observable product law. Two editorial tightenings are recommended below so the implementer does not read a fork back into the draft; neither needs a new ruling.
- **Scope rule honored:** already-deployed instances are out of scope; fresh deployments are the release unit; preserved Uniswap V3/V4 trees must not be selected for new deployment (draft PRD, Owner follow-up, lines 53-55). Nothing below reopens migration or live-instance inventory.

## Per-item classification

### RC-01 — Standalone Balancer adapter reentrancy guard

1. **Whether to bound the in-flight approvals to the operation amount, given the in-code note "Infinite approve for this consume only; ... (M3)" at `BalancerV3SinglePoolStandardExchange.sol:262`.**
   - **Already answered by the draft PRD.** RC-01 acceptance criteria (draft lines 79-80) require the approval to be "limited to the amount that route will spend, and is cleared before the call returns, including on revert," and require zero allowances after a successful call. That supersedes the recorded infinite-approve-then-clear note. The stale "(M3)" comment itself is the kind of text RC-04 exists to clean up; recommend the implementer update it as part of the RC-01 edit. Not an owner question: bounding the allowance changes no honest-flow economics.
2. **Which lock primitive to use on a non-diamond standalone contract.**
   - **Implementer detail.** The adapter has no Diamond storage repo, so a minimal storage-slot lock (the same reentrancy-lock pattern Crane uses) satisfies "reject reentry from funding through approval reset, router return, refund, payout, and reserve sync" (draft lines 78-81). Any implementation meeting those criteria is conformant.
3. **Callback-token fixture for the red/green test.**
   - **Implementer detail.** Existing fixtures (`contracts/test/stubs/ReentrantMockERC20.sol`, `HostileCallbackERC20.sol`) are test stubs, not SUT mocks, and the draft explicitly allows a callback-capable token fixture (draft line 82). The pool used by `TestBase`/the adversarial suite must contain the callback token; that is fixture wiring.

### RC-02 — ERC-4626 local-first payout exactness

4. **Fix shape: exact-asset `withdraw` vs redeem-to-self-then-pay-exactly.**
   - **Already answered by the draft PRD.** The acceptance criteria (draft lines 93-96) permit either and pin the observable: recipient receives exactly the accounted due amount, any rounding remainder stays booked on the SE, and the exact-input return equals the recipient delta. Both permitted shapes satisfy the same assertions, so the choice does not change the acceptance test. The APEX PRD's D15 exactness law is the authority; no new ruling is needed to pick one shape.
5. **Which orbital suite hosts the added capped-unwrap recipient-delta assertion.**
   - **Implementer detail.** The draft says "one orbital capped-unwrap route that uses this SE, in the existing orbital suite" (draft line 228). The D26 matrix naming (`<HookFamilyPrefix>_SeMatrix_<SeFamily>.t.sol`) gives the location; the ERC-4626 SE is a compatible matrix SE. No product law involved.

### RC-03 — Stata backing: include or exclude booked aToken

6. **The include/exclude fork in the draft's wording ("included, or excluded, by both", draft lines 108-109).**
   - **Already answered by the existing APEX PRD; recommend tightening the draft's wording.** R14's shared-accounting rule states: "Stata also counts any already-booked local aToken value at its underlying-equivalent accounting value" (`docs/audits/apex-2026-09-17-remediation-and-regression-tests.md`, R14 shared-adapter bullet; D45 locks one shared backing calculation across IERC4626, SE, SY and transition quotes). The shared adapter already implements inclusion (`ReceiptBackedERC4626Target.sol:187-198`), and the package registers the aToken in the expected-hold set (`AaveV3StataStandardExchangeDFPkg.sol:245-258`), so exclusion would contradict both the law and the existing deployed-shape code. The correction is: make `_stataBacking` (`AaveV3StataStandardExchangeCommon.sol:52-58`) include booked aToken at underlying-equivalent value. This is the one place where the draft's "either/or" phrasing could mislead an implementer into inventing law; the authority already says "include," so no owner question is required — only a draft edit. Flagging rather than asking, per the instruction to prefer the latest recorded ruling still reflected as a requirement.

### RC-04 — Stale comments

7. **Which exact replacement wording for each stale comment.**
   - **Implementer detail.** The draft enumerates the executable rules the text must describe (draft lines 126-128) and forbids changing code to match a comment. No ruling.

### RC-05 — Orphaned single-CP HookTarget

8. **Delete vs fix-to-parity.**
   - **Implementer detail.** The draft permits either (draft lines 138-141). Deletion is verified safe: a repository-wide inheritance search found no `is UniswapV4SingleStandardExchangeBufferConstantProductHookTarget` inheritor, and the installed cut serves `exchangeOut` from the SeFacet (`facets/UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet.sol:86`; corrected helper at `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:836-864`). No selector change either way (the function is not on any cut).

### RC-06 — Orbital unwrap return value

9. **Truthful return vs removing the return.**
   - **Implementer detail.** The draft permits either (draft lines 151-154) and the function is internal-facing with all current callers ignoring the value (`UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:586,604,1899`; `UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:125,185,250`). No external selector or behavior change.

### RC-07 — `BasicVaultCommon` availability math

10. **Global helper edit vs D16-scoped edit, and the historical-consumer inventory.**
    - **Implementer detail, with a useful fact already established.** The draft requires listing non-D16 consumers before any base edit (draft lines 167-168). The review already established that exactly four contracts inherit `BasicVaultCommon` — `UniswapV2StandardExchangeCommon.sol:36`, `CamelotV2StandardExchangeCommon.sol:22`, `AerodromeStandardExchangeCommon.sol:35`, `AaveV3StataStandardExchangeCommon.sol:36` — all D16, all overriding `_secureTokenTransfer` with guarded versions. The inventory the draft asks for is therefore expected to be empty of non-D16 heirs, making either permitted option conformant; the implementer must still produce the inventory as the draft requires. The DETF families define their own same-named helpers and are not heirs. No product-law fork remains.
11. **Replacement behavior on a deficit: family insufficient-credit error vs zero-credit-then-reject.**
    - **Already answered by the draft PRD.** Draft line 168 permits either, with the invariant pinned: zero new credit, no booked-inventory payout, no empty panic. D23's uniform-error rule covers caller short funding; a book deficit is not caller short funding, which is why the draft allows the zero-credit form. No ruling needed.

### RC-08 — Named error for the Uni V2 backing check

12. **Error name and parameter order.**
    - **Implementer detail.** Custom errors are not function selectors (APEX PRD R12), so adding one does not touch the selector-set gate.

## Cross-cutting items already closed

13. **Selector-set invariance.** No RC item adds or removes a proxy selector: RC-01/06/07/08 are internal or error-only changes; RC-05 deletes an uncut function. APEX PRD R12's gate ("any added or removed proxy selector is a release blocker"; custom errors are not selectors) already governs this. Already answered.
14. **Code-size limit.** RC-01's lock and RC-07's edit add small runtime to existing artifacts; the 24,576-byte limit and the D19 Ext-split remedy already govern any overflow. Already answered; implementer re-runs the existing size checker (571-artifact manifest per the follow-up record).
15. **Red-then-green baseline.** The draft's Required outcome (line 59) and Test coverage rules (lines 223, 236-241) already state the current source is the red baseline, forbid loosened assertions, and restrict to the hermetic profile with no fork of deployed instances. Already answered, including the owner follow-up that removes any fork/RPC question.
16. **Stata LM rewards to `feeTo` (Kimi K3-7).** Explicitly out of scope (draft line 206). Already answered.
17. **D12 / D28 / D44 / D32 / D6 accepted law.** Enumerated as not-to-be-fixed (draft lines 61-67). Already answered.
18. **Grok-5 (helper lacks its own `used > credit` revert) and MiniMax F-M3-01 (refund-cap enlargement).** Dispositioned as not-a-requirement / not confirmed (draft lines 203-204). I agree with both dispositions (see `kimi-cross.md`); no requirement gap.

## Questions for the human

None. The two items below are recommendations to the PRD editor, not rulings:

- **Tighten RC-03's "included, or excluded, by both" to "included by both"** so the draft matches APEX R14/D45 (item 6). If the owner actually prefers exclusion, that *would* be an owner decision — but nothing in the record supports it, and the existing adapter code already includes the aToken term.
- **Add the `BalancerV3SinglePoolStandardExchange.sol:262` "(M3)" approval comment** to RC-04's stale-text list or handle it inside RC-01 (item 1), so a later reader does not treat the superseded infinite-approve note as current law.

## What would have required an owner ruling (and does not arise)

- Excluding booked aToken from Stata backing (contradicts APEX R14/D45).
- Enabling public pretransfer on the D32 surfaces as part of RC-01's fix (forbidden by draft line 83 and APEX D32).
- Sending any residual to `feeTo`, or attributing D12 resting credit to a sender (forbidden by draft lines 66, 83, 98).
- Selecting preserved Uniswap V3/V4 source for any new deployment (forbidden by the owner follow-up, draft line 55).

End of requirements review. No blocking open items; the draft is executable without inventing product law once the two editorial notes above are applied.
