# MiniMax M3 final cross-review — APEX 2026-09-17 remediation PRD clarity

- **Reviewer:** MiniMax M3 (`minimax/MiniMax-M3`).
- **Scope:** Cross-review of the final clarity pass against untrusted peer claims from
  Grok, Astra, Kimi. No reading of peer files. No edits to the remediation PRD or
  source. No exploit procedures.
- **Method:** Re-check each peer claim against the draft PRD at
  `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`. State
  agree / dissent / unverified for each. State whether any human question remains.

---

## Peer claims

### Grok — "must fix line 231 so exact-asset withdrawal is not required to leave a booked remainder; must fix line 142 so a guarded shared helper is not banned. No human question."

#### Grok sub-claim 1: "must fix line 231 so exact-asset withdrawal is not required to leave a booked remainder"

- **Disposition:** Agree the test row should be flexible enough to cover both alternatives.
  Disagree this is a must-fix.
- **What the PRD says at line 231:** "On a non-unit receipt rate, exact-in and exact-out
  local-first exits pay the recipient exactly the accounted amount. Any redemption
  remainder stays booked on the SE. The returned exact-in amount equals the
  recipient delta. Add the same recipient-delta assertion to one orbital capped-unwrap
  route that uses this SE, in the existing orbital suite, so a successful swap does
  not leave operation-created face above the opening balance."
- **What the PRD says at line 94 (RC-02 acceptance #2):** "Any protocol-vault rounding
  remainder stays booked on the SE, **or** the route uses an exact-asset withdrawal
  whose share charge matches the preview." Two alternatives joined by "or".
- **Analysis:** The test row says "Any redemption remainder stays booked on the SE"
  which reads as if the fix uses the redeem-then-pay-local pattern (where the redeem
  can over-deliver). If the implementer picks the exact-asset-withdrawal alternative
  (e.g., `vault.withdraw(shortfall, recipient, address(this))`), there is no
  over-delivery and no remainder to book. The test as written still passes (no
  remainder to assert against — the assertion is trivially satisfied), but the
  wording implicitly assumes one of the two alternatives.
- **Why this is a wording cleanup, not a must-fix:** The implementer can adapt the test
  to their chosen fix path. If they pick the redeem path, the test as written
  exercises the remainder booking. If they pick the exact-asset-withdrawal path, the
  test asserts the recipient delta equals exactly `shortfall` and that no SE-side
  over-delivery remains. Both are correct. The PRD does not need a wording change to
  be executable; the implementer chooses a path and adapts the assertion.
- **Wording cleanup suggestion (if the implementer wants both alternatives covered by
  one test):** "On a non-unit receipt rate, exact-in and exact-out local-first exits
  pay the recipient exactly the accounted amount. If the redeem path is used, any
  rounding remainder stays booked on the SE. If the exact-asset-withdrawal path is
  used, the recipient delta equals exactly `shortfall` and no SE-side remainder is
  created. The returned exact-in amount equals the recipient delta." No requirement
  change.
- **Evidence label:** observed fact.

#### Grok sub-claim 2: "must fix line 142 so a guarded shared helper is not banned"

- **Disposition:** Agree the wording at line 142 could be clearer to align with line 140.
  Disagree this is a must-fix.
- **What the PRD says at line 140 (RC-05 acceptance #1):** "The unused function is
  deleted, **or** it calls the same guarded pull and refund helper as the installed
  SE target." Redirect is explicitly allowed.
- **What the PRD says at line 142 (RC-05 acceptance #3):** "A comment or package
  cut cannot be the only evidence that the unsafe function is unreachable; the source
  itself must not retain a second public money implementation."
- **Analysis:** The phrase "second public money implementation" is ambiguous between:
  - Reading A: "no second `external` function that does unsafe money logic." If the
    HookTarget.exchangeOut redirects to the guarded helper, the function body no
    longer does the unsafe thing — it delegates. Reading A is satisfied.
  - Reading B: "no second public money entry of any kind, even if it delegates."
    This reading would ban redirect and require deletion only. This reading
    conflicts with line 140 which explicitly allows redirect.
- **Why this is a wording cleanup, not a must-fix:** The intent is clear from the
  conjunction of #1 (redirect allowed) and #3 (no second unsafe implementation).
  Reading A is the intent: the function exists but no longer contains a second unsafe
  money logic. The implementer who reads #1 and #3 together will not mistakenly
  delete when redirect is also acceptable.
- **Wording cleanup suggestion (if the implementer wants explicit alignment):**
  "A comment or package cut cannot be the only evidence that the unsafe function is
  unreachable; the source itself must not retain a second unsafe money implementation.
  A redirect to the installed guarded helper satisfies this because the unsafe
  pattern is removed from the source even though the function entry remains." No
  requirement change.
- **Evidence label:** observed fact.

#### Grok's "No human question"

- **Disposition:** Agree. No human question remains from Grok's items. Both are wording
  cleanups that the implementer can resolve without an owner ruling.

---

### Astra — "those are wording cleanups, not new requirements. No human question."

- **Disposition:** Agree with Astra's classification.
- **Analysis:** Grok's two items (line 231 test row flexibility, line 142 second-
  implementation wording) are wording cleanups, not new product-law requirements. The
  implementer can execute both alternatives in line 231 and align line 142 with line
  140 without an owner ruling.
- **"No human question":** Agree.
- **Evidence label:** observed fact.

---

### Kimi — "must fix an include-or-exclude RC-03 branch. Current lines 108-109 and row 232 already require inclusion."

- **Disposition:** Agree with Kimi's assessment.
- **What the PRD says at line 108 (RC-03 acceptance #1):** "Every Stata issuance,
  redemption, preview, and transition quote uses the same backing function as the
  shared adapter **and includes already-booked aToken at its underlying-equivalent
  value**. D45 / R14 already require that inclusion. **Exclusion is not an
  implementer choice.**"
- **What the PRD says at line 109 (RC-03 acceptance #2):** "**If aToken is absent
  from the expected-hold set, the shared helper contributes zero.** Do not invent a
  second aToken balance."
- **What the PRD says at row 232 (test row for RC-03):** "On one production Stata
  proxy, nonzero booked aToken is included by both the adapter and the SE preview
  and exchange paths. A later deposit is priced on that same basis. Generic
  ERC-4626 mode still has no aToken term."
- **Analysis:** The current RC-03 acceptance already requires inclusion unconditionally.
  The phrase "Exclusion is not an implementer choice" (line 108) closes any
  hypothetical exclude branch. The conditional at line 109 ("If aToken is absent
  from the expected-hold set, the shared helper contributes zero") is not an
  exclude branch — it is the corner case where aToken is not in expected-hold and
  there is nothing to include. The helper returns 0 naturally because
  `_bookedATokenEquiv` iterates `_vaultTokens()` and aToken is not in that list
  when it is not registered. No open branch.
- **"Must fix an include-or-exclude RC-03 branch":** There is no open include-or-
  exclude branch. The PRD already requires inclusion. No fix needed.
- **Evidence label:** observed fact.

---

## Summary

| Peer claim | Disposition |
| --- | --- |
| Grok sub-claim 1 (line 231 test row flexibility) | Agree wording could be clearer; disagree it is a must-fix |
| Grok sub-claim 2 (line 142 second-implementation wording) | Agree wording could be clearer; disagree it is a must-fix |
| Grok's "No human question" | Agree |
| Astra's "those are wording cleanups, not new requirements" | Agree |
| Astra's "No human question" | Agree |
| Kimi's "must fix an include-or-exclude RC-03 branch" | Disagree — no open branch exists |
| Kimi's "Current lines 108-109 and row 232 already require inclusion" | Agree |

## Human question remains

None.

The draft PRD is executable. All three peer conclusions land in one of two buckets:
- Wording cleanups (Grok 1 and 2, Astra's classification) — implementer can resolve
  without an owner ruling.
- No fix needed (Kimi) — the PRD already requires inclusion.

No new owner decision is required. The implementer proceeds.

---

## Reviewer notes for the coordinator

- The contested points are closed. Grok's items are wording cleanups; Kimi confirms
  no fix needed. Astra's classification aligns with my own analysis.
- The "must fix" framing from Grok and Kimi is acceptable as PRD-text feedback but does
  not block execution. The implementer can proceed with the corrections as written and
  apply minor wording refinements at the same time.
- I did not re-read any peer files (`docs/reviews/` peer files or other reviewers'
  outputs) per the prompt instruction. I did not edit source or the final remediation
  PRD.

Saved to `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/reviews/apex-2026-09-17-remediation-council/minimax-final-cross.md`.