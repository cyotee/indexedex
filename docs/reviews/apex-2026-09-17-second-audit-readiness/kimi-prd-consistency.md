# Kimi K3 — REMEDIATION_PRD consistency check (post OD-01–OD-07)

Reviewer: Kimi K3. Read: the updated PRD in full (2026-10-06 revision). Verified against
current source where the PRD re-cites it: `UniswapV4DetfCommon.sol` lines 550–724
(REQ-01's cited catches at 578–584, 610–616, 633–655, the deferred probe catch at
669–678, and `_pairQuoteIsZero` at 700–705 all match the current file); the wings vault
tree `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/` (exists,
~35 sources including Common, In/Out targets/facets, DFPkg, and a TestBase). OD-01
through OD-07 are treated as closed.

## Verdict

**Stage 1 is implementable for REQ-01, REQ-02, REQ-03, REQ-04, REQ-06, REQ-07, and
REQ-08 without further owner input.** REQ-05 has two blocking ambiguities, below. My
earlier questions K-Q1 through K-Q4 are answered by OD-01, OD-04, OD-02, and OD-05
respectively; REQ-06/OD-03 is internally consistent (I re-checked the
`maxWithdraw = previewRedeem(maxRedeem)` direction against the ceil-floor pairing in
`sharesForWithdraw`/`receiptUnitsFromShares` — the cap cannot strand a payable
withdraw, and the "at least one receipt" clause is fully covered by the acceptance
criteria).

## Blocking clarifications

### K-C1 — REQ-05: which FullSpread variant(s) carry the outside-trade test?

- **Affects:** REQ-05 acceptance criterion 1 ("FullSpread has an outside-trade test"),
  interacting with OD-04 item 3 and OD-05.
- **Contradiction/ambiguity:** "FullSpread" is singular, but the current tree has three
  FullSpread implementations: V3 (`uniswap/v3/UniswapV3FullSpreadStandardExchangeVault*`)
  and the two OD-05-ratified V4 packages (`fullSpread/hookless/`,
  `fullSpread/ponsFamilyV2Hook/`). The original R3.3 mis-citation (Astra-03) concerned
  the V3 supplement, but the product direction and REQ-08's evidence remapping concern
  the V4 variants. The PRD never names the variant.
- **Outcomes that change the fix:**
  - (a) All three variants → three outside-trade tests, one per package accounting path
    (V3 sleeve accounting and the two V4 variants' separate inventory/protection units
    are not the same code; a test on one proves nothing about the others).
  - (b) V3 only (literal successor to the mis-cited supplement) → one test; the
    OD-05-ratified V4 variants ship without this control.
  - (c) The two V4 variants only → two tests; V3 covered by historical evidence.
  Each outcome changes the acceptance test count, the target packages, and what stage 1
  can claim closed.

### K-C2 — REQ-05/OD-06: is the wings outside-trade test a stage-1 deliverable?

- **Affects:** REQ-05 acceptance criterion 2, OD-06 stage split.
- **Contradiction/ambiguity:** REQ-05 acceptance requires "The wings vault has the same
  outside-trade test against its own accounting," and OD-06 says stage 1 implements "the
  repairs stated in this PRD." But OD-06 also says "Stage 1 does not certify the 108
  original criteria, the wings vault, or audit readiness," and stage 2 "covers the
  broader APEX standard and the new vaults." The wings vault source and TestBase exist in
  the tree, so the test is physically writable — the question is which stage owes it. If
  stage 1 owes it, stage 1 necessarily exercises the new vault's money path, which reads
  against "stage 1 does not certify the wings vault." If stage 2 owes it, REQ-05's
  acceptance criteria should be split so stage 1 can pass without it.
- **Outcomes that change the fix:**
  - (a) Stage 1 → the wings test is written and run now (with OD-06's iterate-or-alternate
    escape hatch if the wings vault cannot yet execute the scenario); stage 1 results
    include a wings money-path test but no certification claim.
  - (b) Stage 2 → REQ-05 acceptance is amended to mark the wings row stage-2, and stage 1
    closes on the FullSpread test(s) alone.

## Non-blocking quality notes

1. **Deferred `supportsInterface` probe catch is untracked.** REQ-01 and OD-01 explicitly
   decline to decide the catch at `UniswapV4DetfCommon.sol:669–678` (verified present,
   `catch { return false; }`). D37's letter still forbids it (D16 DETF production catch,
   not D41/D48/D49). Nothing in the PRD's Unverified section or stage-2 description
   schedules its disposition. Suggest adding it to the stage-2 scope list so it is not
   silently ratified by omission.
2. **Preserved-source deletion ambiguity.** OD-04 item 1 ("not kept in the tree merely to
   prove the new vaults") and REQ-05 acceptance 4 ("not required to keep the old source
   compiling") gesture at removal, while the whole-PRD non-goal still says "No change to
   preserved historical Uniswap V3/V4 implementations except as read-only reproduction
   evidence." Reading them together, the non-goal controls stage 1 (no deletion) — but
   stating that explicitly would prevent an implementer from treating OD-04 as a deletion
   mandate or, conversely, as a retention mandate.
3. **Zero-LP successful join path unspecified.** After REQ-01's catch removal, the retry
   loops in `_joinResidualCapped`/`_joinResidualUnbalanced` still break-and-continue when
   a join *succeeds* with `lpOut_ == 0` (lines 588, 620), and `_entryJoinResidualAtomic`
   reverts `ResidualJoinUnavailable` on a zero-LP success (657) which the removed outer
   catch used to absorb. OD-01 governs zero *previews* and *reverts*; a nonzero-preview,
   non-reverting, zero-LP outcome is neither. Stage-1 tests will surface which behavior
   results; a one-line note in REQ-01 naming the intended outcome would remove the guess.
4. **Dead code after REQ-07.** Deleting the branch at
   `StandardExchangeRateProviderFacet.sol:69–85` leaves `_supportsUnlockContext`
   (lines 168–170) with no caller. Cosmetic; the implementer can remove it, but the PRD
   is silent.
5. **REQ-04 acceptance criterion 4 mechanics.** "A row is not marked COMPATIBLE on the
   strength of the catch-all control alone" does not say who re-derives the row states
   after the controls are fixed (the matrix evidence script exists per the open-items
   ledger). Presumably fixing the control and re-running the generator suffices; a
   pointer to the generator command would make it mechanical.
6. **REQ-01 line citations verified accurate** against the 2026-10-06 tree (catches at
   578–584, 610–616, 633–655; probe catch at 669–678; `_pairQuoteIsZero` at 700–705).
   No action; recorded so a later reader knows the cites were checked, and so any further
   pre-implementation edits are known to invalidate them.
