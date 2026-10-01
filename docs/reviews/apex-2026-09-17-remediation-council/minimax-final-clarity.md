# MiniMax M3 final clarity review — APEX 2026-09-17 remediation PRD

- **Reviewer:** MiniMax M3 (`minimax/MiniMax-M3`).
- **Scope:** Final consistency, quality, and clarity review of the draft PRD at
  `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`. Check for
  contradictions between requirements, acceptance criteria, test rows, non-goals, and the
  owner ruling that already-deployed instances are out of scope. No reading of peer files.
  No edits to source, tests, config, or scripts. No writing of the final remediation PRD.
- **Method:** Re-read the whole current draft (256 lines). Cross-checked each RC's
  corrections, acceptance criteria, non-goals, and test row against the cited source lines
  read in this session. Verified the audit disposition table against the PRD's R1.2 states
  (`WITHDRAWN`, `Downgraded to informational`, `Refuted in current replacement source`,
  `Out of scope`). Confirmed the owner follow-up scope at line 54-55 is consistent with the
  rest of the PRD.
- **Out of scope:** Already-deployed instances, migration, registry disablement, historical
  fork replay, live-instance inventory. Preserved Uniswap V3/V4 trees as the bytecode for
  a new deployment. Per the owner follow-up in the draft PRD.

---

## Headline answer

The draft PRD is consistent, clear, and executable without a new product-law ruling.
There are no contradictions between requirements, acceptance criteria, test rows, non-goals,
and the owner ruling that already-deployed instances are out of scope.

No human question remains. The implementer can proceed. RC-03's tightened language
("Exclusion is not an implementer choice") and RC-08's focused-test fallback are explicit
implementer choices that do not need owner clarification.

A small number of wording items are listed below as "wording cleanup that does not change
the requirement." None block handoff.

---

## Must fix before handoff

None.

The PRD's structure is sound:

- `Inputs used` (line 9-17) lists the audit, PRD, plan, follow-up, router, and skills
  with their roles. The audit and plan are flagged as claims, not proof.
- `Reviewer originals and cross-reviews` (line 19-28) lists all eight reviewer files.
- `Astra participation` (line 32-39) and the other-sessions table (line 41-47) record
  session metadata. The "four-member round" claim at line 49 is consistent with the
  four originals.
- `Owner follow-up` (line 53-55) is explicit: "Already-deployed instances are not in
  scope. No migration, registry disablement, historical fork replay, or live-instance
  inventory is required. Fresh deployments of the corrected source are the release unit.
  Preserved Uniswap V3/V4 trees remain historical source and must not be the bytecode
  selected for a new deployment."
- `Required outcome` (line 57-67) names the correction standard and the accepted product
  law (D12/D28, D44, D32, D6, preserved Uniswap).
- Eight RC entries (line 71-186) each name file/line, intended behavior, broken
  invariant, acceptance criteria, non-goals, and attribution.
- `Audit disposition` (line 188-202) covers all eight audit items with disposition
  labels consistent with the PRD's R1.2 states.
- `Dissent and items that are not requirements` (line 204-213) records the dissents
  and explicitly bounds them.
- `Evidence gaps` (line 215-222) records unverified claims and out-of-scope items.
- `Test coverage` (line 224-237) names existing suites per RC and shared rules.
- `Requirements follow-up` (line 246-252) records the no-blocking-question outcome and
  cites the targeted Astra session that agreed.
- `Coordinator notes` (line 254-256) marks coordinator-only content.

## Consistency checks between requirements, acceptance, test rows, and non-goals

### RC-01 (Standalone Balancer adapter reentrancy)
- **Acceptance #1** (line 78): "Both money entries reject reentry from funding through
  approval reset, router return, refund, payout, and reserve sync." Six entry points.
- **Acceptance #2** (line 79): "An approval opened for an operation is limited to the
  amount that route will spend. A successful return leaves router and Permit2 allowances
  at zero. A revert rolls the whole transaction back, including allowances. Do not add
  `try`/`catch` to clear allowances after a revert." Aligns with D30 (no catch-body
  booking) and the R10.6 (focused on operation-wide guards).
- **Acceptance #2** also names "The stale '(M3)' infinite-approve comment at line 262
  is updated with this change." This is a comment fix coordinated with RC-04 (see line
  122-123). The coordination is consistent: the comment is corrected as part of
  RC-01's guard fix, and is listed under RC-04 because it's a stale comment.
- **Non-goals** (line 83): "Do not enable public pretransfer on D32 surfaces." The
  standalone adapter is not a D32 surface (D32 lists `BalancerV3PoolStandardExchangeTarget`
  and Aave Cross-Version Loop). The non-goal is a general reminder, not a constraint
  on this RC. Slightly misplaced but not a contradiction.
- **Test row** (line 230): Tests must cover all six entry points. Aligns with
  acceptance #1.
- **No contradiction.**

### RC-02 (ERC-4626 local-first rounding)
- **Acceptance #1** (line 93): "The recipient of a local-first underlying payout
  receives exactly the accounted due amount."
- **Acceptance #2** (line 94): "Any protocol-vault rounding remainder stays booked on
  the SE, or the route uses an exact-asset withdrawal whose share charge matches the
  preview." Two alternative fixes both acceptable.
- **Non-goals** (line 98): "Do not send residual to `feeTo`. Do not reintroduce an
  exact-input refund." Aligns with D6 and D15.
- **Test row** (line 231): "Add the same recipient-delta assertion to one orbital
  capped-unwrap route that uses this SE, in the existing orbital suite." Aligns with
  acceptance #5 (line 97).
- **No contradiction.** The PRD's RC-02 file list cites the Stata file
  (`AaveV3StataStandardExchangeCommon.sol:87-97`) but the Stata `_payUnderlying` already
  uses `withdraw(shortfall_, to_, address(this))` at line 94. The implementer fixes
  only the ERC-4626 file. This is consistent with the test row's focus on ERC-4626 and
  orbital.

### RC-03 (Stata backing aToken)
- **Acceptance #1** (line 108): "Every Stata issuance, redemption, preview, and
  transition quote uses the same backing function as the shared adapter and includes
  already-booked aToken at its underlying-equivalent value. D45 / R14 already require
  that inclusion. Exclusion is not an implementer choice."
- **Acceptance #2** (line 109): "If aToken is absent from the expected-hold set, the
  shared helper contributes zero. Do not invent a second aToken balance." Clarifies
  the corner case.
- **Non-goals** (line 112): "Do not change Aave liquidity-mining reward forwarding to
  `feeTo`." Aligns with the LM rewards stream not being this defect.
- **Test row** (line 232): Tests must show the same share entitlement across adapter
  and SE routes when booked aToken is nonzero.
- **No contradiction.** The "Exclusion is not an implementer choice" language at line 108
  tightens the previous conditional #2 (which said "If product law instead excludes
  aToken"). This tightening is consistent with Kimi's cross-review suggestion.

### RC-04 (Stale comments)
- **Acceptance** (line 126-128): Comments must describe executable rules. No executable
  change is made to match a comment.
- **File list** (line 119-123): Five comment sites. The line 262 comment in
  `BalancerV3SinglePoolStandardExchange.sol` is listed with the note "corrected with
  RC-01." This is a coordination note: the line 262 comment is corrected as part of
  RC-01's guard fix, and is listed under RC-04 because it's a stale comment.
- **No contradiction.** The line 262 comment correction is named in both RC-01
  acceptance #2 and RC-04 file list. The implementer corrects it once.

### RC-05 (Unused HookTarget exchangeOut)
- **Acceptance #1** (line 140): "The unused function is deleted, or it calls the
  same guarded pull and refund helper as the installed SE target."
- **Acceptance #2** (line 141): "Installed selectors and the production diamond cut
  do not change if the function is not currently exposed."
- **Acceptance #3** (line 142): "A comment or package cut cannot be the only evidence
  that the unsafe function is unreachable; the source itself must not retain a second
  public money implementation."
- **No contradiction.** The DFPkg at
  `UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol:215` confirms
  `SE_FACET` is the production cut. Deletion or redirect to the guarded helper both
  satisfy the requirement.

### RC-06 (Orbital capped unwrap return)
- **Acceptance #1** (line 153): "The returned share count equals the shares the SE
  pulled, measured by the SE return or by the share-balance delta around the call,
  or the unused return is removed and every caller is updated."
- **Acceptance #2** (line 154): "The existing approve-to-cap and approve-back-to-zero
  sequence remains."
- **Acceptance #3** (line 155): "A short SE delivery still reverts and rolls back."
- **Non-goals** (line 156): "Do not change the exact-output SE call into a
  surplus-creating unwrap. Do not pay unused approval to the caller. MiniMax dissents
  that the assignment is unused and therefore not a functional defect; the requirement
  is limited to making the return truthful or removing it."
- **No contradiction.** The "every caller is updated" wording at line 153 could be
  tighter ("every caller that uses the return is updated; unused-return callers require
  no change"), but the intent is clear.

### RC-07 (Shared vault availability math)
- **Acceptance #1** (line 166): "Every live D16 refund path that calls
  `_unbookedSurplus` returns zero credit when balance is below book, and does not pay
  booked inventory."
- **Acceptance #2** (line 167): "Either the base pull enforces the contract-caller
  check when `pretransferred` is true, or a test names each D16 public entry and
  shows it cannot reach the unguarded base branch."
- **Acceptance #3** (line 169): "The opaque panic is replaced, on D16 paths, by the
  family's existing insufficient-credit error or by a zero-credit result that the
  caller then rejects."
- **Non-goals** (line 170): "Do not mechanically replace every historical caller.
  Do not treat this as a demonstrated booked-inventory payout. Do not reopen
  preserved Uniswap V3/V4 delivery accounting."
- **No contradiction.** The three acceptance criteria are three separate fixes:
  helper returns 0, base pull enforces guard or test names entries, panic replaced.
  All three are required. Lines 167 and 169 overlap (the panic replaces produces the
  zero-credit result), but the implementer can satisfy both with one fix at the
  helper.

### RC-08 (Uniswap V2 pass-through zap-out backing check)
- **Acceptance #1** (line 180): "The same comparison reverts a named error carrying
  both compared values."
- **Acceptance #2** (line 181): "The transaction rolls back. Booked LP is not
  spent."
- **Acceptance #3** (line 182): "Existing successful zap-out routes still pass."
- **Acceptance #4** (line 183): "If a supported production route can make
  pool-token balance fall below `vaultLpReserve` without mocking the vault or writing
  its storage, that route is the required red/green test."
- **Acceptance #5** (line 184): "If it cannot, record the attempted preconditions
  and assert the production check itself reverts the named error. Do not mock the
  subject, fabricate storage, or hold the named-error edit until a later end-to-end
  trigger is authorized. Grok, MiniMax, and Kimi read this as existing evidence
  law. Astra's first requirements pass asked the owner to confirm it. A later targeted
  Astra session agreed that this fallback is an evidence choice, not an owner
  decision. That correction does not erase the earlier unanswered cross-review."
- **Test row** (line 237): "If a supported route can reach the check, that route
  must fail before the fix and pass the named error after it, with unchanged LP
  reserve and a funded success control. If it cannot be reached without mocking or
  storage writes, document that attempt and assert the production check. Do not
  invent a completion gate beyond that."
- **No contradiction.** Acceptance #4 and #5 plus the test row align: focused test
  of the production check is acceptable when no production route can reach the check.

### Audit disposition table (line 188-202)
- **APEX-2026-001-M**: "Refuted in FullSpread replacement source. Still present in
  preserved historical source by design. Already-deployed instances are out of
  scope." Aligns with the owner follow-up.
- **APEX-2026-001-M2**: "Out of scope." Aligns.
- **APEX-2026-003**: "Refuted in current custody source. Already-deployed custody is
  out of scope." Aligns.
- **APEX-2026-008**: "Original whole-face payout refuted at checked orbital sites.
  Callback exactness is not closed." Aligns with the dissent recorded at line 206
  (MiniMax F-M3-01) and the requirement that the refund cap is `credit - used`.
- **APEX-2026-009**: "Refuted in current ERC-4626 and Morpho source." Aligns.
- **APEX-2026-004B**: "Refuted in current ERC-4626 source for the idle-underlying
  sweep." Aligns.
- **APEX-2026-005**: "Missing-helper claim refuted. Complete consumer conformance not
  closed." Aligns with the PRD's RC-07 which addresses the conformance gap.
- **Withdrawn `beforeSwap` guard claim**: "Refuted. Not an accepted residual." Aligns
  with the PRD's R1.2 states (`WITHDRAWN`).
- **Weighted-dust High claim**: "Refuted as High. Unconvertible remainder is the
  accepted D12 / D36 residual." Aligns with the PRD's R1.2 states (`Downgraded to
  informational`).
- **No contradiction.**

---

## Test rows vs acceptance criteria

| Test row | Acceptance criteria covered | Status |
| --- | --- | --- |
| RC-01 (line 230) | Acceptance #1 (reentry across six entry points), #2 (allowance cap and rollback), #4 (non-reentering route completes) | Aligned |
| RC-02 (line 231) | Acceptance #1 (recipient gets exact amount), #3 (exact-input return equals recipient delta), #4 (non-unit rate and mixed shortfall) | Aligned |
| RC-03 (line 232) | Acceptance #3 (same share entitlement across adapter and SE) | Aligned |
| RC-04 (line 233) | Comments-only; "No new money test" | Aligned |
| RC-05 (line 234) | Acceptance #1 (delete or redirect), #3 (no second public money implementation) | Aligned |
| RC-06 (line 235) | Acceptance #1 (return equals SE pull or removed) | Aligned |
| RC-07 (line 236) | Acceptance #1 (helper returns 0), #2 (base pull or test names entries), #3 (panic replaced) | Aligned |
| RC-08 (line 237) | Acceptance #4 and #5 (focused test fallback) | Aligned |

All test rows align with their RC acceptance criteria.

---

## Owner follow-up consistency check

The owner follow-up at line 53-55 says:
> "Already-deployed instances are not in scope. No migration, registry disablement,
> historical fork replay, or live-instance inventory is required. Fresh deployments of
> the corrected source are the release unit. Preserved Uniswap V3/V4 trees remain
> historical source and must not be the bytecode selected for a new deployment."

This is consistent with:

- The `Accepted product law that must not be "fixed" away` block at line 61-67.
- The audit disposition table at line 188-202 (each disposition notes "Already-deployed
  instances are out of scope" where applicable).
- RC-01's "Fresh deployments of corrected source" framing.
- The "fresh-deployment source plus tests that fail on the current defect and pass after
  the correction" at line 5.

No contradiction.

---

## Accepted product law consistency check

The accepted product law at line 61-67 lists:
- D12 / D28: later contract caller may consume unbooked credit.
- D44: bytecode check accepts EIP-7702 and contract wallets.
- D32: Aave Cross-Version Loop and `BalancerV3PoolStandardExchangeTarget` keep rejecting
  public pretransfer.
- D6: protocol residual stays booked, not paid to `feeTo`.
- Preserved Uniswap V3/V4 trees stay inventory, not the replacement fix.

This is consistent with:
- RC-01 non-goal "Do not add sender attribution for D12 resting credit" (line 83).
- RC-02 non-goal "Do not send residual to `feeTo`" (line 98).
- RC-03 non-goal "Do not change Aave liquidity-mining reward forwarding to `feeTo`"
  (line 112).
- RC-04 non-goal "Do not revive `_absorbDustToFeeTo`" (line 130).
- RC-07 non-goal "Do not treat this as a demonstrated booked-inventory payout" (line
  170).
- The audit disposition table (line 188-202), which respects these accepted
  invariants.

No contradiction.

---

## Wording cleanup that does not change the requirement

These are minor wording items that do not block execution. Each is consistent with the
PRD's intent.

1. **Line 123 — RC-04 file list**: "stale infinite-approve comment, corrected with
   RC-01." This is a coordination note that says the line 262 comment in
   `BalancerV3SinglePoolStandardExchange.sol` is corrected as part of RC-01's guard
   fix, and is listed under RC-04 because it's a stale comment. The wording could be
   clearer: "The line 262 stale comment in
   `BalancerV3SinglePoolStandardExchange.sol` is corrected as part of the RC-01 guard
   fix; it appears in this file list because it is a stale comment." No requirement
   change.

2. **Line 153 — RC-06 acceptance #1**: "every caller is updated." Since current
   callers do not use the return, "every caller is updated" is a non-action. The
   wording could be: "every caller that uses the return is updated; callers that ignore
   the return require no change." No requirement change.

3. **Line 184 — RC-08 acceptance #5**: "That correction does not erase the earlier
   unanswered cross-review." This is a process note. The PRD's intent is clear:
   the focused-test fallback is acceptable; the earlier cross-review is on record as
   process history but does not block implementation. The wording could be: "The
   earlier unanswered cross-review is recorded as process history; the focused-test
   fallback is the implementer choice and does not block." No requirement change.

4. **Line 250 — Requirements follow-up**: "Astra's cross-review resume returned no
   review text." This is process bookkeeping. The next sentence ("A later
   human-requested Astra session, ses_f242ff120ffeJtOYk5QvnC0chn, returned a
   substantive agreement") completes the picture. No requirement change.

5. **Line 109 — RC-03 acceptance #2**: "If aToken is absent from the expected-hold
   set, the shared helper contributes zero. Do not invent a second aToken balance."
   Clear and consistent. No wording change needed.

---

## Open items to resolve with the human

None.

The draft PRD is executable without a new product-law ruling. The implementer can
proceed with the corrections named in RC-01 through RC-08.

- The "Exclusion is not an implementer choice" language in RC-03 acceptance #1 (line 108)
  is explicit: aToken is included in both surfaces unconditionally when in
  expected-hold. The conditional at acceptance #2 (line 109) is the corner case
  (aToken not in expected-hold), which is naturally handled by the helper returning 0.
  No owner clarification needed.

- The RC-08 focused-test fallback at acceptance #5 (line 184) is explicit: the
  implementer proceeds with a focused test of the production check when no production
  route can reach the check. The earlier unanswered cross-review is recorded but does
  not block. No owner clarification needed.

- The RC-05 deletion-or-redirect choice (line 140), RC-06 return-truthful-or-remove
  choice (line 153), and RC-08 named-error wording (line 180) are implementer
  choices within the PRD's framing. No owner clarification needed.

---

## Reviewer notes for the coordinator

- The PRD is consistent and executable. No must-fix items.
- A small number of wording items are listed as "wording cleanup that does not change
  the requirement." None block handoff. The implementer can proceed.
- No human question remains. RC-03's tightened language and RC-08's focused-test
  fallback are explicit implementer choices that do not need owner clarification.
- I did not re-read any peer files (`docs/reviews/` peer files or other reviewers'
  outputs) per the prompt instruction. I did not edit source or the final remediation
  PRD.

Saved to `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/reviews/apex-2026-09-17-remediation-council/minimax-final-clarity.md`.