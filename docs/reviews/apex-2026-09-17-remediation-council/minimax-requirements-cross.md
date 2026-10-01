# MiniMax M3 requirements follow-up cross-review

- **Reviewer:** MiniMax M3 (`minimax/MiniMax-M3`).
- **Scope:** Cross-review of the requirements follow-up answer at
  `docs/reviews/apex-2026-09-17-remediation-council/minimax-requirements.md` against
  untrusted peer conclusions from Astra, Grok, Kimi. Resume only my own answer. No
  edits to source or the final remediation PRD. No re-reading of peer files
  (`docs/reviews/` peer files, other reviewers' outputs).
- **Method:** Read the peer conclusions. State agree / dissent / unverified for each. The
  only contested point is whether RC-08's evidence fallback is an owner decision. State
  whether any human question remains.

---

## Peer conclusions

### Astra — "No new economic ruling. RC-03 must include already-booked aToken. RC-01 revert means rollback, not catch-and-continue. Sole human question: if RC-08 cannot be reached on an allowed production route, may acceptance use a focused test of the production check, or must it remain incomplete until an end-to-end trigger is shown?"

- **"No new economic ruling"** — Agree. The PRD's `Required outcome`, the eight RC
  entries, the `Audit disposition` table, and the `Accepted product law` block are
  sufficient. No new economic ruling is required.
- **"RC-03 must include already-booked aToken"** — Agree. The PRD's RC-03 acceptance
  #1 at `REMEDIATION_PRD.md:108` already states "Every Stata issuance, redemption,
  preview, and transition quote uses the same backing function as the shared adapter,
  including booked aToken when aToken is in the expected-hold set." This is the
  included-by-both default. The current behavior — `AaveV3StataStandardExchangeDFPkg.sol:245-258`
  puts aToken in the expected-hold set when `aToken()` returns one, and the end-of-route
  sync at `BasicVaultCommon.sol:43-50` books that balance — already requires both
  surfaces to include aToken. The fix is for the SE to mirror the adapter's
  `_bookedATokenEquiv` at `ReceiptBackedERC4626Target.sol:191-198`.
- **"RC-01 revert means rollback, not catch-and-continue"** — Agree. D30 requires the
  prechecked operative call to revert directly without `try`/`catch`, and the PRD's
  RC-01 acceptance at `REMEDIATION_PRD.md:78-82` matches: "Both money entries reject
  reentry from funding through approval reset, router return, refund, payout, and
  reserve sync." A nested call must revert; the outer operation rolls back. No
  catch-and-continue.
- **Astra's sole human question — RC-08 evidence fallback** — Dissent that this is an
  owner decision. The PRD's RC-08 acceptance at `REMEDIATION_PRD.md:234` already says
  "Force the pass-through backing check to fail on the production route." A focused test
  that crafts state to trigger the production check (e.g., setting `_vaultLpReserve` in
  the storage above the actual pool balance, or arranging for the pool balance to drop
  below the recorded LP reserve) is a focused test of the production check, not an
  end-to-end trigger. The acceptance test:
    - Calls the production route (the production function).
    - Crafts the precondition that activates the production check.
    - Verifies the new named error fires and the LP reserve is unchanged.
  This is the PRD's existing wording. No new owner ruling is needed; the implementer
  follows the PRD's text as written. If the implementer chooses to corrupt state in a
  controlled way to force the check to fail, that is a focused test of the production
  check. The check is `if (indexSource.pool.balanceOf(address(this)) < vault.vaultLpReserve)
  revert();` at `UniswapV2StandardExchangeOutTarget.sol:578-580` — a forced failure
  path is reachable in the test by setting `_vaultLpReserve` higher than the live pool
  balance, or by simulating a transient state.
- **Conclusion:** Dissent on the contested point. RC-08's evidence fallback is not an
  owner decision. The PRD's existing acceptance wording supports a focused test of the
  production check.

### Grok — "No owner question. RC-01 revert does not authorize try/catch. RC-02 is withdraw-the-shortfall. RC-03 exclusion is not an open branch. RC-08 error name is implementer detail. Questions for the human: none."

- **"No owner question"** — Agree.
- **"RC-01 revert does not authorize try/catch"** — Agree. D30 requires direct revert.
- **"RC-02 is withdraw-the-shortfall"** — Agree. The fix is
  `vault.withdraw(shortfall, recipient, address(this))` at
  `ERC4626StandardExchangeCommon.sol:88`, replacing the current
  `vault.redeem(vault.previewWithdraw(shortfall), recipient, address(this))` which can
  over-deliver when yield accrues between `previewWithdraw` and `redeem`. The Stata
  `_payUnderlying` at `AaveV3StataStandardExchangeCommon.sol:87-97` already uses
  `withdraw(shortfall_, to_, address(this))`.
- **"RC-03 exclusion is not an open branch"** — Agree. The PRD's RC-03 conditional at
  `REMEDIATION_PRD.md:109` ("If product law instead excludes aToken from holder backing,
  both the adapter and the SE exclude it") is a hypothetical fork that the PRD author
  pre-answers. The implementer follows the included-by-both default. When aToken is not
  in expected-hold, `_bookedATokenEquiv` (which iterates `_vaultTokens()` and skips
  receipt/underlying) returns 0 naturally. Both surfaces align without a separate
  ruling.
- **"RC-08 error name is implementer detail"** — Agree. The PRD's RC-08 acceptance
  #1 says "reverts a named error carrying both compared values." The implementer picks
  the name (e.g., `PassThroughZapOutUnderwaterLP(uint256 poolBalance, uint256 vaultLpReserve)`).
  No owner ruling needed.
- **"Questions for the human: none"** — Agree.

### Kimi — "No blocking owner decisions. Tighten RC-03 to included-by-both as a draft edit. Questions for the human: none."

- **"No blocking owner decisions"** — Agree.
- **"Tighten RC-03 to included-by-both as a draft edit"** — Partial agreement. The PRD's
  RC-03 acceptance #1 at `REMEDIATION_PRD.md:108` already requires inclusion by both
  surfaces "when aToken is in the expected-hold set." Removing the "when aToken is in
  the expected-hold set" qualifier (Kimi's tightening) would be wrong if a future
  deployment intentionally configures without aToken in expected-hold: the SE would
  be forced to count aToken that is not booked, causing a backing mismatch in the
  opposite direction (over-counting). The PRD's conditional #2 at line 109 pre-answers
  this hypothetical. The current wording is the safe framing.
  However, the PRD could be tightened by stating that the implementer must mirror
  `_bookedATokenEquiv` from the shared adapter into the SE (a copy or a shared
  helper), with no conditional; if aToken is not in expected-hold, the helper returns
  0 naturally. This is the operational implementation; the PRD's conditional language
  is a clarification, not an open branch.
  I agree that no PRD edit is required for the implementer to execute; the current
  wording is sufficient.
- **"Questions for the human: none"** — Agree.

---

## Summary of contested and resolved points

The only contested point in the peer conclusions was Astra's question about RC-08's
evidence fallback (focused test vs end-to-end trigger). I dissent that this is an owner
decision. The PRD's RC-08 acceptance at `REMEDIATION_PRD.md:234` ("Force the pass-through
backing check to fail on the production route. Expect the new named error and unchanged
LP reserve. A funded control still succeeds.") supports a focused test that crafts
state to trigger the production check. No new ruling needed.

All other peer conclusions agree with my own answer. Grok's "no questions for the human"
and Kimi's "no blocking owner decisions" stand.

---

## Open items to resolve with the human

None. The draft PRD, as written, is sufficient for the implementer to execute without
inventing product law.

- The accepted product law at `REMEDIATION_PRD.md:61-67` is bounded (D12/D28, D44, D32,
  D6, preserved Uniswap).
- The eight RC entries each name file/line, intended behavior, broken invariant,
  acceptance criteria, non-goals, and attribution.
- The audit disposition table at `REMEDIATION_PRD.md:185-199` covers all eight audit
  items.
- The test coverage table at `REMEDIATION_PRD.md:221-241` names existing suites to extend
  per RC and forbids mocks of the subject, `expectRevert` placeholders, and `via_ir`.
- The `Either... or...` branches in the RC acceptance criteria are implementer choices
  within the PRD's framing. No PRD edit is required to execute.

If the owner wants to reopen any of the following, a new ruling would be needed; they
are NOT open today:
- Migration of already-deployed instances (out of scope by owner follow-up at
  `REMEDIATION_PRD.md:54-55`).
- Live-instance inventory for APEX-2026-001-M2 (out of scope by owner follow-up).
- Removal of aToken from Stata expected-hold (PRD's RC-03 conditional #2 pre-answers:
  "both the adapter and the SE exclude it"; no current ask).
- Whether `_payUnderlyingLocalFirst` should also be re-examined in Stata (PRD's RC-02
  cites the Stata file but the Stata `_payUnderlying` already uses `withdraw`; no
  change needed).

---

## Reviewer notes for the coordinator

- The contested point is closed. RC-08's evidence fallback is a focused test of the
  production check, which the PRD's existing acceptance wording supports. No PRD edit
  required.
- Kimi's "tighten RC-03" suggestion is a PRD-text refinement, not an owner decision.
  The current wording at `REMEDIATION_PRD.md:108-109` is safe and sufficient.
- Grok's "no questions for the human" aligns with my conclusion.
- I did not re-read any peer files (`docs/reviews/` peer files or other reviewers'
  outputs) per the prompt instruction. I did not edit source or the final remediation
  PRD.

Saved to `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/reviews/apex-2026-09-17-remediation-council/minimax-requirements-cross.md`.