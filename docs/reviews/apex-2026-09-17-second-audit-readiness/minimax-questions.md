# Council questions — MiniMax M3

The human asked whether the council has any clarifying questions
before a later implementer fixes the discovered errors. The
remediation PRD is specific enough on REQ-03, REQ-04, REQ-05, REQ-08
and on the non-goals. The following four questions identify the
points where the implementer would otherwise have to make an
owner choice that would change the required fix, the acceptance
test, or an explicit non-goal. They are ordered by REQ.

## Q1. REQ-01 — site-by-site disposition of the cited DETF catches

- **REQ affected:** REQ-01 ("Remove or explicitly amend Uni V4 DETF residual catches")
- **Ambiguity:** REQ-01 lists seven line ranges in `UniswapV4DetfCommon.sol`
  (`:572-578`, `:604-610`, `:628-635`, `:642-649`, `:664-685`,
  `:699-706`, `:718-721`) and gives the implementer an "OR":
  remove so the dependency reverts propagate, OR cover by a
  written amendment with D49 specificity. The cited range
  `:664-685` contains both (i) interface-detection probes that
  the D41 / D48 amendments plainly authorise (the
  `supportsInterface`, `previewExchangeIn`, `quoteInputForExactShares`
  probes around the SE sub-share pair query) and (ii) the catch
  bodies at `:670-672` and `:676-678` whose fall-through to
  `return false` is what makes the interface detection work.
  `:699-706` and `:718-721` are an `AlignmentNotAchievable`
  recognition path used by `_parkUnmintablePairDust`. The PRD
  does not say which of these are interface-detection amendments
  and which are D37 / D30 violations, only that each site must
  be either removed or amended.
- **Outcomes that would change the fix:**
  (a) Owner rules that `:664-685` are interface-detection
      amendments and stay (with D49-specific language);
      `:572-578`, `:604-610`, `:628-635`, `:642-649`, `:699-706`,
      `:718-721` are removed (hard call). The fix removes six
      catches and re-records two amendments.
  (b) Owner rules that all cited sites are removed. The fix
      deletes every catch in the file, including the interface
      probes, which would change the D41 / D48 amendment
      applicability for this file.
  (c) Owner rules that one or more of `:572-578`,
      `:604-610`, `:699-706` are retained as a different kind
      of amendment (residual-maintenance exception) and writes
      the amendment text. The fix keeps those catches and adds
      a D70-style entry to the plan.
- **Why the PRD does not already decide it:** REQ-01 says "either
  removed or amended with the same specificity as D49" but does
  not name which sites are interface-detection probes (D41 / D48
  analogues) and which are dependency-error catches that D30
  forbids. Without that ruling the implementer either deletes
  everything (over-correcting) or keeps everything (under-
  correcting). The cross-review noted that lines `:664-678` and
  `:680-685` are interface-detection and should not be flagged
  as D37 deviations, but the PRD treats them in one bucket.

## Q2. REQ-02 — approved local retention when `previewResidualBuffer` returns zero

- **REQ affected:** REQ-02 ("Make the single-CP residual preview obey the catch rule or record an exception")
- **Ambiguity:** REQ-02 says the implementer may either propagate
  the dependency revert OR record an amendment that "names this
  selector, forbids using the zero result as credit, and states
  what local retention is allowed." The PRD does not specify
  what "local retention" is approved.
- **Outcomes that would change the fix:**
  (a) Owner approves: zero return means the residual stays on
      the hook as D6 retained residual, and `bufferQuotedResidual`
      (the operative `exchangeIn` at lines 262-268) is unchanged
      because it never runs. Fix is one amendment entry plus
      tests that the residual stays on the hook and no share
      movement occurs.
  (b) Owner approves: zero return means the residual stays on
      the SE and the hook reverts the entire residual-
      maintenance operation. Fix is the same amendment plus a
      revert in the surrounding caller when the preview returns
      zero.
  (c) Owner disapproves the soft path: the function reverts on
      `AlignmentNotAchievable`. Fix is to remove the catch and
      make `previewExchangeIn` propagate.
- **Why the PRD does not already decide it:** REQ-02 deliberately
  defers the retention behavior to the amendment ("states what
  local retention is allowed"). The plan's D30 forbids family-
  specific recognized-error lists; an amendment analogous to D49
  must name the permitted behavior, and the implementer cannot
  write that amendment without owner direction. The PRD also
  does not say whether `bufferQuotedResidual` may still be called
  with `minimum == 0` when the preview returned zero, which is
  the actual money consequence of the chosen retention rule.

## Q3. REQ-06 — rounding direction for the `maxRedeem` share cap

- **REQ affected:** REQ-06 ("Do not double-floor a deliverable receipt redemption")
- **Ambiguity:** REQ-06 acceptance says "`maxRedeem` returns the
  full owner balance when that balance's rounded receipt payout
  is within actual receipt inventory. Otherwise the share cap
  is computed from the receipt-liquidity inequality with one
  consistent rounding direction and an owner-balance bound." The
  PRD does not say which rounding direction is "consistent".
- **Outcomes that would change the fix:**
  (a) Floor in both places (the current behavior in `maxWithdraw`
      against receipts, then in `maxRedeem` against shares).
      Owner-conservative: caps `maxRedeem` strictly below the
      owner's balance whenever rounding loses. Rejects some
      valid redemptions; no over-pay risk.
  (b) Floor in `maxWithdraw` only, ceiling in `maxRedeem`.
      Redeemer-friendly: when an owner has the receipts to back
      their full balance, `maxRedeem` returns that balance.
      Floor at the `redeem` call (`previewWithdraw` is already
      used as `shares`) catches any over-pull.
  (c) Floor in `maxWithdraw`, ceil the conversion of receipt
      units to shares by the same direction `previewRedeem` uses
      (which is the existing `convertToAssets` floor), then
      cap by `balanceOf(owner)`. Owner-friendly with a single
      rounding pass and parity with `previewRedeem`.
- **Why the PRD does not already decide it:** REQ-06 names "one
  consistent rounding direction" but does not commit to floor or
  ceil. The three outcomes change which user is favored (redeemer
  vs. vault), which is a product decision, not a mechanical fix.
  The implementer needs that direction before writing the
  cap function and the acceptance test. Acceptance criterion
  bullet 4 ("non-integral-rate test for a full-balance redeem
  that is deliverable") passes under (b) and (c) and fails under
  (a); bullet 5 ("a test that still rejects a redeem above
  actual receipt inventory") passes under (a) and the current
  code and may pass under (b) and (c) depending on edge
  selection.

## Q4. REQ-07 — rate-equivalence tolerance for the soft `quoteState` probe

- **REQ affected:** REQ-07 ("Keep the rate-provider fallback inside the locked exception")
- **Ambiguity:** REQ-07 acceptance says the amendment must
  "name this probe, the gas bound, the fall-through, and the
  required rate equivalence" and that tests must cover "success,
  failed call, short return data, and a call budget that cannot
  pay for the snapshot, and assert the approved rate or the
  approved revert." The PRD does not say what "rate equivalence"
  means in practice.
- **Outcomes that would change the fix:**
  (a) Bit-exact equivalence required: any path (soft snapshot,
      live-supply probe, fall-through-to-zero) must return the
      same `out` value as the locked D48 `_safePreviewExchangeIn`
      path would, or revert. Fix is to revert when paths
      disagree, which effectively keeps only one path.
  (b) Tolerance within 1 wei: the soft snapshot and live-supply
      paths may differ by 1 wei; a divergent path returns the
      same rate after rounding to integer shares. Fix is to add
      a rounding step and a single-rate-per-subject test.
  (c) Tolerance within 1e-12 relative (the F9 ruling's relative
      tolerance): the rate may differ by up to 1e-12. Fix is to
      keep the soft path and add tolerance-based assertions.
  (d) "Matches D48's existing search behavior": rate equivalence
      means the same `(false, 0)` fall-through on failure, and
      success returns whatever the live supply probe or the
      `quoteState` reply returned. Fix is the current behavior
      with no rate-equivalence test beyond "no revert".
- **Why the PRD does not already decide it:** REQ-07 names
  "required rate equivalence" but does not quantify it. The four
  outcomes change the acceptance test and the fix: (a) is a hard
  revert, (d) is the current code unchanged. None is
  mechanically derivable from the locked text. The implementer
  also needs to know whether the amendment is approved at all
  (option (a)/(b)/(c)) or whether the soft path must be removed
  (REQ-07's first branch). The PRD presents both branches; the
  owner choice is which branch.

## Items the PRD already specifies without owner choice

For completeness, the following REQs are specific enough to
implement without further questions and are not raised here:

- REQ-03 acceptance criteria are explicit: contract-caller
  ownership test with exact share-accounting error; nested-
  guard error and no partial credit on reentrancy; exact
  short-funding error on minimality fuzz; scanner covers the
  full D16 regression inventory. The owner choice is implicit
  in the PRD's wording.
- REQ-04 acceptance criteria are explicit: family-specific
  rounding errors or measured zero-output outcome; partial-
  consumption reconciliation; D33 nonzero unpaired inventory
  precondition; COMPATIBLE not marked on catch-all alone.
- REQ-05 acceptance criteria are explicit: the cited
  supplement may remain as a custody-synchronization test but
  is not labeled the boundary; the evidence row must cite a
  test that actually creates the stale-book boundary on the
  preserved implementation and checks replacement credit
  after an external pool action that does not synchronize the
  vault.
- REQ-08 acceptance criteria are explicit: snapshot-to-current
  map of every current package, source file, selector-set
  change, and covering tests; current section labelled;
  historical evidence preserved; new build/selector/size/
  regression run against the submission tree; matrix figure
  resolved to a single current count.

The four questions above are the only owner choices I found that
would change a fix, an acceptance test, or an explicit non-goal.
If the council has no further questions on these four, a later
implementer can begin work. The non-goals in the PRD's "Non-goals
for the whole PRD" section remain in force and are not
revisited here.

(End of questions.)