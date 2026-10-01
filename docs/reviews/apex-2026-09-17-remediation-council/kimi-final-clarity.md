# Kimi K3 — final consistency, quality and clarity review of the draft remediation PRD

- **Draft reviewed:** `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` (245 lines, read in full).
- **Question asked:** Is the draft consistent, clear, and executable without a new product-law ruling? Any remaining open items the human must answer?
- **Answer:** Yes, executable without a new product-law ruling, subject to **one must-fix wording correction** (RC-03's either/or branch contradicts existing law). No human question remains: the single contested branch is already decided by the APEX PRD, so the fix is draft text, not a ruling.

## Issue 1 — RC-03 presents an "include or exclude" branch that existing law has already closed — **must fix before handoff**

- **Draft lines:** 108-109 ("included, or excluded, by both"), and the test row at 229 ("a nonzero booked aToken balance is included, or excluded, by both `totalAssets` / convert paths and the SE preview and exchange paths").
- **Conflict:** APEX PRD R14's shared-accounting rule states Stata "counts any already-booked local aToken value at its underlying-equivalent accounting value," and D45 locks one shared backing calculation across IERC4626, SE, SY and transition quotes (`docs/audits/apex-2026-09-17-remediation-and-regression-tests.md`, R14 shared-adapter bullet and D45). The deployed-shape code already implements inclusion on one side: `_totalReceiptBacking` adds `_bookedATokenEquiv` (`ReceiptBackedERC4626Target.sol:187-198`), and the package registers the aToken in the expected-hold set (`AaveV3StataStandardExchangeDFPkg.sol:245-258`). The two draft branches are not behaviorally equivalent: "include" means editing `_stataBacking` (`AaveV3StataStandardExchangeCommon.sol:52-58`); "exclude" means editing the adapter and removing a token the package deliberately registers. Because the branches produce different corrections, this is not cosmetic; because existing law already picks "include," it is not a new ruling.
- **Internal tension:** line 110 already leans toward inclusion ("a later depositor does not receive shares priced on the smaller basis"), so the draft is mildly inconsistent with itself as well.
- **Fix:** change lines 108-109 to require inclusion by both surfaces, and change the test row (line 229) to assert that a funded nonzero booked aToken is *included* identically by the adapter and the SE paths. Keeps the acceptance test aligned with APEX R14/D45 and the existing adapter behavior.
- **Classification:** must fix before handoff (draft-text fix applying existing law). **No human question.**

## Issue 2 — RC-01's superseded "(M3)" infinite-approve note is not in the stale-text inventory — **wording cleanup that does not change the requirement**

- **Draft lines:** 79-80 (approval bounded to the route's spend and cleared before return) vs the in-code comment at `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:262` ("Infinite approve for this consume only; ... (M3)").
- The criterion is explicit and controls; the comment is stale text of exactly the kind RC-04 (lines 118-122) exists to clean up, but that site is not listed there. An implementer reading the comment mid-edit could treat it as a standing decision.
- **Fix:** add that comment to RC-04's site list, or state in RC-01 that the "(M3)" note is superseded by the bounded-approval criterion. **Classification:** wording cleanup.

## Issue 3 — RC-06 non-goal phrasing — **wording cleanup that does not change the requirement**

- **Draft line:** 155 ("Do not pay unused approval to the caller"). "Approval" here refers to the share-amount cap; the operative criteria (lines 151-154: honest or removed return value; approve-to-cap then approve-to-zero retained; short delivery reverts) are unambiguous and verified against `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-566`.
- **Fix:** rephrase to "Do not pay unused shares or allowance value to the caller," or delete the sentence. **Classification:** wording cleanup.

## Items checked with no issue

- **Owner ruling consistency:** the owner follow-up (lines 53-55) — deployed instances out of scope, fresh deployment is the release unit, preserved Uni V3/V4 not selectable — is consistent with the audit disposition (lines 191-193, which say "out of scope" and "refuted in current source" without claiming live remediation) and with the test rules (line 241: hermetic only, no fork of an already-deployed instance). No residual migration or inventory requirement appears anywhere in RC-01..RC-08.
- **Required outcome vs comment-only defects:** line 59 (production-route red/green for money/control defects; comment-only defects closed by text edits with existing tests green) matches the RC-04 test row (line 230, "No new money test") and the RC-05 row (line 231, source search plus existing surface suite).
- **RC-05 internal consistency:** delete-or-parity (line 139), no cut change (line 140), and "the source itself must not retain a second public money implementation" (line 141) are mutually consistent; verified no inheritor exists and the installed cut serves the corrected helper (`facets/UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet.sol:86`; `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:836-864`).
- **RC-08 vs selector law:** the fix adds a custom error, which is not a function selector (APEX PRD R12), so the D13 selector freeze is untouched; the acceptance criteria (lines 178-181) match.
- **RC-01 fixture vs token law:** the callback-capable-token fixture could be read as tension with the universal token law (FoT/rebasing forbidden); the draft resolves it explicitly ("A callback-capable token fixture is allowed," line 82) and the fixture is not a product token. No issue.
- **RC-02 acceptance vs test row:** lines 93-97 and 228 agree (exact recipient payment, remainder booked on the SE, exact-in return equals recipient delta, one orbital capped-unwrap assertion).
- **RC-07 inventory ordering:** line 167 requires listing historical consumers before any base-helper edit. Verified during review that exactly four contracts inherit `BasicVaultCommon` (`UniswapV2StandardExchangeCommon.sol:36`, `CamelotV2StandardExchangeCommon.sol:22`, `AerodromeStandardExchangeCommon.sol:35`, `AaveV3StataStandardExchangeCommon.sol:36`), all D16 with guarded overrides, so the criterion is satisfiable and the constraint is expected to be vacuous. No issue.
- **Disposition citations spot-checked:** line 122's `README.md:32-38` — the stale pull-semantics sentence is at line 36, inside the cited range; line 198's Balancer-quad claim — `UniswapV4StandardExchangeBalancerQuadStableBufferHookBeforeInitializeLib.sol:23-25` does check PoolManager identity (`NotPoolManager()`), and the hooks target holds `_onlyPoolManager()` on its callback entries (`...BalancerQuadStableBufferHookHooksTarget.sol:71,92,172`). Both accurate.
- **Dissent and evidence-gap sections:** lines 201-210 match the cross-review record (F-M3-01 not confirmed; Grok-5 informational; RC-01 severity Medium with the dissent recorded; RC-06 functional dissent recorded). Lines 214-219 accurately record unexecuted evidence. Line 49-51's roster/participation description matches this session's history. No contradictions.

## Human questions

**None.** The only branch that would change a correction (RC-03 include vs exclude) is already decided by APEX R14/D45 and the existing adapter code, so it is resolved by fixing draft text, not by asking the owner. Every other ambiguity found above is wording cleanup pinned by an explicit criterion elsewhere in the draft.

## Bottom line

Apply the one must-fix (RC-03 wording and test row → inclusion) and the two wording cleanups (RC-01 "(M3)" note; RC-06 non-goal phrasing). After that, the draft is consistent, internally cross-referenced, and executable without inventing product law or asking the human anything further.

End of review. Stopping here.
