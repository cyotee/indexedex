# PRD consistency and quality — MiniMax M3

The human asked whether the council needs to clarify anything in
`REMEDIATION_PRD.md` (with owner decisions OD-01 through OD-07 recorded)
before a later implementer fixes the discovered errors.

## Verdict

The PRD is consistent enough to implement stage 1. OD-01 through OD-07
close the choices that the earlier PRD left open (catch exception vs.
removal, snapshot vs. no-snapshot, OpenZeppelin direction vs. ad-hoc
floor, etc.), and each REQ follows one OD. There are no contradictions
between the recorded owner decisions and the older requirement text
that would change a required fix, an acceptance test, or a non-goal.

One blocking clarification remains on REQ-05's scope, and a small set
of non-blocking quality notes is listed below it.

I checked the existence of the paths REQ-05 names. The wings vault
source exists at `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`
(30 files including `UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol`
and the `_Accounting`, `_DFPkg`, `_Money`, `_Projection` units). The
FullSpread split is `fullSpread/hookless/` and `fullSpread/ponsFamilyV2Hook/`,
matching OD-05. The V3 reserve-reconcile supplement lives under
`release/v3/UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol`
as REQ-05 cites. None of the seven REQs names a path that does not
exist.

## Blocking clarifications

### Q1. REQ-05 — which FullSpread files the outside-trade test must cover

- **Affects:** REQ-05 acceptance criterion 1 ("FullSpread has an
  outside-trade test").
- **Ambiguity:** REQ-05 names `release/v3/UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol`
  as the file that is *not* the proof, and says "new tests are
  required for FullSpread and for `…/v4/upperLowerWings/`". OD-05
  splits FullSpread V4 into `fullSpread/hookless/` and
  `fullSpread/ponsFamilyV2Hook/` as separate products and says
  "FullSpread" includes both. The PRD does not say whether the
  outside-trade test covers (a) V3 FullSpread only, (b) V3 +
  V4 hookless, (c) V3 + V4 hookless + V4 Pons-family, or (d) only
  the V4 products. The implementer has to guess.
- **Outcomes that change the fix or acceptance test:**
  (a) If V3 only: a single outside-trade test against
      `UniswapV3FullSpreadStandardExchangeVaultCommon.sol` and
      its pool. Acceptance is one test.
  (b) If V3 + V4 hookless: two tests. The V4 hookless
      `UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol`
      already exists, so this is two production fixtures.
  (c) If V3 + V4 hookless + V4 Pons-family: three tests. The
      Pons-family package `UniswapV4FullSpreadPonsFamilyHookCommon.sol`
      also exists. OD-05 says Pons-family is a separate product
      and should not be merged with the hookless package.
  (d) If V4 only: the V3 supplement's status as
      "custody-synchronization, not outside-trade credit" needs
      to be made explicit.
- **Why the PRD does not already decide it:** REQ-05 names the
  V3 supplement by file and the V4 wings package by directory
  but does not enumerate the FullSpread V4 products. OD-05 lists
  hookless and Pons-family as the V4 split but does not direct
  REQ-05 to cover both, only one, or V3 too. The implementer
  cannot tell from the text whether "FullSpread" in REQ-05
  means the V3 family, the V4 hookless family, both, or all
  three. The number of stage-1 deliverables depends on the
  answer.

## Non-blocking quality notes

These are documentation gaps the implementer can resolve by reading
the cited source or by owner follow-up. They are not blocking.

### N1. REQ-01 — translation-catch enumeration inside the cited ranges

- **Affects:** REQ-01 acceptance criteria 2 ("The catch that
  translates `ZeroAmount` or `ResidualJoinUnavailable` into a
  retained success is removed.").
- **Gap:** REQ-01 cites line ranges `:578-584`, `:610-616`, and
  `:633-655` and says the `supportsInterface` probe at `:669-678`
  is outside OD-01. It does not enumerate which catch within
  each cited range is the translation catch and which (if any)
  is another kind. The implementer reads the file and applies
  the principle; the PRD only excludes the `supportsInterface`
  probe explicitly. This is a documentation gap, not a fix
  ambiguity, because the rule "do not catch a revert and
  continue" and the named errors are specific enough to identify
  the translation catches.

### N2. REQ-02 — caller name for the reverting-preview regression

- **Affects:** REQ-02 acceptance criterion 3 ("A regression shows
  a reverting preview reverts the caller and does not book the
  amount as a successful zero.").
- **Gap:** "The caller" of `previewResidualBuffer` is unnamed.
  The same file contains `bufferQuotedResidual` at line 262,
  which calls `exchangeIn` directly rather than going through
  `previewResidualBuffer`. The hook-level caller is not named
  in REQ-02 either. The implementer picks a test fixture
  (the PRD points at the file but not the test) and writes the
  regression. The PRD does not change behaviour; it just makes
  the test scope a judgment call.

### N3. REQ-07 — test fixtures for empty-state and snapshot paths

- **Affects:** REQ-07 acceptance criteria 3 ("A test shows the
  empty-state path does not change when the vault's `quoteState`
  would fail or when the call budget is low.") and 4 ("A test
  shows a failed caller-supplied snapshot is not reported as the
  live rate.").
- **Gap:** The PRD names `StandardExchangeRateProviderFacet.sol`
  and `quoteState` / `quoteRate` but does not name the test
  fixture that exposes `quoteState` to be made to fail and a
  fixture that lets a snapshot be passed into `quoteRate`. The
  implementer has to find a vault fixture (the rate provider
  is paired with a vault) or construct one. OD-02's product
  note points at the wings vault as a holder of the unlock-context
  interface, but the wings vault source is not strictly required
  for the rate-provider test.

### N4. REQ-08 — stage-1 vs stage-2 split of acceptance criteria

- **Affects:** REQ-08 acceptance criteria 3 ("Build, selector,
  size, and the named APEX regressions are regenerated against
  that tree under a separate execution request.") and 4 ("The
  hook × SE matrix disposition used for submission is one current
  count.").
- **Gap:** OD-06 puts stage 1 as "implement and test the
  repairs in this PRD" and stage 2 as "reopens the APEX
  program and checks that the broader changes and the new
  vaults meet the same standard". REQ-08 criteria 3 and 4
  span both stages. Criterion 3 says "separate execution
  request" (deferred). Criterion 4 is about the submission
  count, which is stage 2. Criteria 1 and 2 (snapshot-to-current
  map, historical evidence labelled) are stage 1. The PRD
  does not split these explicitly; the implementer can do 1
  and 2 in stage 1 and defer 3 and 4 to stage 2.

### N5. REQ-05 — authorization wording on writing the new tests

- **Affects:** REQ-05 non-goal ("Do not treat this review as
  authorization to write the tests now.").
- **Gap:** The PRD documents REQ-05's acceptance criteria,
  including tests to be written. The non-goal says this PRD
  review is not authorization. The next-stage implementer
  treats the PRD as the requirement source but needs explicit
  session authorization to write the tests. This is consistent
  with the PRD's overall "no code changes" framing in the
  document header, but the wording inside REQ-05's non-goal
  is the only place that says it; the document-level
  "required outcome" does not re-state it.

### N6. PRD's "Dissent" — matrix 195/1/7 vs 165/3/7 not resolved

- **Affects:** REQ-08 acceptance criterion 4 (one current count).
- **Gap:** The dissent section records that the follow-up
  record's 195/1/7 and the earlier 165/3/7 figures are
  unresolved and the coordinator disposition is "tie one to
  the submission tree". The implementer must run the matrix
  against the current tree to determine the count. This is
  not a PRD contradiction; it is a documented step that the
  PRD did not pre-resolve.

## Files examined

- `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/contracts/vaults/standard/exchange/protocols/uniswap/v4/`
  (directory listing) — confirms the FullSpread split and the
  existence of `upperLowerWings/`.
- `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`
  (directory listing) — confirms 30 files including the
  wings-vault's `_Accounting`, `_DFPkg`, `_Money`, `_Projection`
  units REQ-05 acceptance criterion 2 needs.
- `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`
  (directory listing) — confirms `hookless/` and
  `ponsFamilyV2Hook/` per OD-05.

No source files were edited. No test was run. No peer reviewer
output was read.

(End of consistency review.)