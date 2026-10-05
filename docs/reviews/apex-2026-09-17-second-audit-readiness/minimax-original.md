# Independent first pass — MiniMax M3

## Scope and assumptions

This is a defensive review of the working tree's source under
`/Users/cyotee/Development/projects-defi/daosys/lib/indexedex` (HEAD
`2d69dc1e954f51698f7e26699940171dec2d8a3b`, dirty per D21). The
assignment asks whether the APEX 2026-09-17 remediation described in the
locked plan (D1–D69) was actually completed in the current working tree
and whether the regression tests are adequate to submit this source for a
second audit. The completion snapshot is dated 2026-09-25; today is
2026-10-03. I read the plan, the PRD, the follow-up record, the
evidence narrative, the open-items ledger, and the shared library
`LocalCreditLib.sol` plus `ISecurePullErrors.sol`. I also read the
rebasing SE/SY (`RebasingAwareStandardExchangeTarget.sol`,
`RebasingAwareERC4626` documents) and the orbital Common around the D50
fix site (`UniswapV4StandardExchangeOrbitalBufferHookCommon.sol` lines
~2080–2179). I read the `LocalCreditLib.t.sol` and the orbital
`Apex008.t.sol` test files to inspect assertions.

I did **not** read peer review output, the six open-item PRDs, the PDF
audit, or the Cranetracking branches. I did not run the test suite,
build, fork session, or any shell command. Findings below are based on
the documents above and the named source files. Plan line numbers were
treated as guidance; current-source positions were checked against the
files I read. Where I have not read the production source for a
particular claim, the criterion is reported as unverified rather than
confirmed.

The report does not include exploit procedures, PoC code, payloads, or
attack parameters. Defects are named by class, file, line, broken
requirement, impact, fix direction, severity, confidence, and evidence
class (observed / inference / speculation).

## Completion verdict

**Partially complete; closure is documentary rather than semantic.** The
108 acceptance criteria and the implementation summary in
`independent-completion.json` (PASS, 34,909 / 3,053 / 0 / 0) describe a
working tree in which the plan has been executed and the full hermetic
test suite passes. The follow-up record documents a release bundle of
34,909 tests across 3,053 suites, 33 stateful campaigns, 37 targeted
fuzz tests, 195 compatible matrix rows, 571 runtime artifacts, no
oversize, and `git diff --check` clean. The completion manifest is
self-consistent with the evidence file sections I read.

The implementation fixes I did inspect match the documented plan:
`LocalCreditLib` (`available`, `budget`, `requirePretransferCaller`)
exists at `contracts/utils/LocalCreditLib.sol:14–28` and uses
`BetterAddress.isContract`; `EOAPretransferNotAllowed` exists in
`contracts/interfaces/ISecurePullErrors.sol:16`; the rebasing SE
applies the guard before any credit (lines 84 and 118 of
`RebasingAwareStandardExchangeTarget.sol`), keeps `AssetPretransferNotSupported`
rejection (line 78 / 111), and implements the D23 short-funding revert
(line 125); the orbital hook uses `_unbookedBalance` (line 2131) at the
D50 credit sites (lines 2111 and 2125).

However, the program explicitly defers the deployment of the corrections
to immutable live instances (R4, D12, the closing paragraph of the
follow-up record) and accepts the D12 contract-wallet / EIP-7702
residual as `UNSUPPORTED_USE`. The accepted residual means the auditor's
findings 003 and 001-M are **replacement-verified, not live-remediated**.
A second audit on the source tree cannot close findings on the chain
without a separate deployment and migration request. I report this below
as a residual limitation, not a completion failure.

I have not independently verified the full set of D16 fixes by reading
every targeted source file. The plan-level closure relies on the
campaign, matrix and full hermetic run counts in
`independent-completion.json`, the `finding-matrix.json`, and the
per-criterion logs. Some of these are described in the evidence file
with named test functions and red/green logs; many are not (the
matrix runs reference logs by name but the contents are not in the
documents I read). The accuracy of the named test counts cannot be
confirmed without the actual log artifacts. I report the unverified
criteria below.

## Test-quality verdict

The tests I read (LocalCreditLib and Apex008) assert the named
invariants rather than weaker stand-ins. Specifically:

- `LocalCreditLib.t.sol` lines 69–89 bound `available` and `budget`
  arithmetic with explicit zero, deficit, equality, excess and `uint256`
  max cases; lines 91–114 fuzz the same with `vm.assume(used <= credit)`
  to bound the refund property.
- `LocalCreditLib.t.sol` lines 116–126 assert the exact
  `EOAPretransferNotAllowed` selector and the harness's `lastCredited`
  and `lastCaller` are untouched, which is a real negative test.
- `LocalCreditLib.t.sol` lines 136–151 use a predicted create address
  to test the constructor-time rejection path with real CREATE2
  semantics, not a mock.
- `LocalCreditLib.t.sol` lines 168–177 use `vm.signAndAttachDelegation`
  for the EIP-7702 delegated EOA acceptance, with `code.length > 0`
  checked, which matches the D44 rule (no `vm.etch`).
- `UniswapV4StandardExchangeOrbitalBufferHook_Apex008.t.sol` lines 62–141
  reproduce the resting-500 plus small-attacker scenario across the
  five `R6` refund sites, asserting both `user0 + 500` is not reached
  and the resting balance is unchanged on the hook. Lines 188–221
  verify both swap directions leave the resting balance untouched and
  no raw callback refund goes to the PoolManager. Lines 235–271 pin
  `Drain()` for `previewSwapExactOut` and the wrapper selector for the
  PoolManager path.

These are positive examples of well-aimed tests. I have not read the
remaining 600+ named APEX / R / I / O / E tests; the evidence file
claims they pass but I cannot confirm without reading the files.

The evidence file records several categories of negative observations
that a second audit would want to scrutinise:

1. **Hermetic retargets.** The open-items ledger entry 7 records that
   "Rocket Pool and EtherFi run the D31 sweep after `_mintWithUsageFee`
   rather than before" and "EtherFi reads its boolean capacity once per
   operation instead of between the booked and caller legs". These are
   accepted as "no economic effect" but they are not the plan's letter.
2. **Pre-existing 17 failures retargeted.** The evidence file's run-2
   summary (lines 161–164 of `apex-2026-09-17-evidence.md`) records
   that 17 failures from run 1 were tests that "still encoded a
   pre-APEX rule" and were retargeted. The plan's R2.4 instruction
   forbids broad `expectRevert()` and bare rejections; the evidence file
   shows a scanner (`scripts/apex_bare_expectrevert_scan.sh`) was used to
   catch bare reverts, and a `test_ADV02_insufficientSharePretransferReverts`
   was corrected during gap-3 closure. This is a process gap that was
   fixed mid-program, not a residual risk.
3. **`UNSUPPORTED_USE` residual tests pass.** D44 says both real
   EIP-7702 delegated EOAs and deployed contract wallets must pass the
   bytecode guard. The LocalCreditLib test does this. The PRD's
   acceptance is that the residual is documented; it does not require
   closure. The two tests assert acceptance, not protection. The
   acceptance is consistent with the plan.
4. **Matrix test names appear in test files** (R6 / R10 / F6 / etc.).
   Without reading the bodies I cannot confirm whether each matrix row
   asserts a real property or relies on a fixture default. The plan
   forbids bare `expectRevert()` and SUT mocks. The open-items ledger
   records that "147 `<Prefix>_SeMatrixBehavior.sol` contracts …
   146 contain a single `test_INCOMPATIBLE_*` that expects package init
   to revert" (before gap 1). After gap 1 most of those were rewritten
   per item 1's record. The current state is described as 175 suites /
   1,235 tests in matrix run 16; bodies are not visible to me.

**Test-quality issues I can call from documents (not from a full read of
the suite):**

- **The orbitaMatrix/Row tests rely on `RoleMatrix` fixtures for the
  rated-reserve rows.** The D60 work package added 28 M14 decimal rows
  and re-wrote the matrix behaviors to emit per-leg addresses. Whether
  each row's ten controls assert a real bound or accept a tolerance is
  not verifiable from the documents I read. F8's `test_BLOCKED_F8_*`
  control is recorded as BLOCKED, not failing — i.e. the row passes
  enough controls but is pinned to a finding. That is a recorded
  residual, not a passing control. F9's exact-assertion goal was met
  ("the two 1e-12 tolerances … return to exact assertions"), but the
  dual `DepositQuoteLib` required a separate preview-overestimate fix.
  Both of these are documented as fixed, not claimed perfect.
- **The `_assertBufferedPretransferRefund` helper at line 397 of
  Apex008** asserts the refund equals `maxIn - used`, which is the D15
  invariant for true-flag pretransfer. The test pins `assertEq(token0.balanceOf(address(caller)), maxIn - used, "all unused credit refunded")`.
  This is a real assertion, not a vacuous one.

**Test-quality risks I flag for the second audit:**

- Several tests rely on the test's own `assertEq` against a fixed
  expected delta without bounding the test-suite's tolerance on the
  pre-correction path. The plan requires a failing security assertion
  before each fix (R2). The evidence file describes "preserved" tests
  and "red" logs but does not always include the red assertions in
  the documents I read.
- The plan allows tolerance bands (1% / 2% for F6 rows, 1e-12 for the
  dual SY route, "1e-15 relative" for F9). These tolerances are
  recorded as closures for the F6 / F9 findings. A second audit may
  judge whether those tolerances should be tighter. They are not
  vacuous, but they weaken the assertion from "preview equals
  execution" to "preview approximately equals execution". The plan
  and owner rulings call these out explicitly (D54–D66).

## Second-audit readiness

**Verdict: ready-with-documented-residuals for source re-audit.**

Reasons the source is ready:

1. The 108 acceptance criteria have been re-walked with named tests
   per the gap-3 record (91 EVIDENCED, 17 PARTIAL, 0 REPORTED).
2. The plan's locked decisions are reflected in the source files I
   read (`LocalCreditLib`, `RebasingAwareStandardExchangeTarget`,
   `UniswapV4StandardExchangeOrbitalBufferHookCommon` D50 fix).
3. The full hermetic suite is green per `independent-completion.json`
   (34,909 / 3,053 / 0 / 0).
4. The hook × SE matrix is at 195 COMPATIBLE / 1 INCOMPATIBLE / 7
   DEPRECATED per `independent-completion.json`.
5. The acceptance-state machine (`REPORTED`, `REPRODUCED`,
   `FIX_IMPLEMENTED`, `VERIFIED_FIXED`, `WITHDRAWN`,
   `BLOCKED`, `UNSUPPORTED_USE`) is documented per finding row in the
   `finding-matrix.json`.

Reasons the readiness is **with documented residuals**, not clean:

1. **Live deployment exposure is unchanged.** The seven reported
   Uniswap V4 diamonds and the custody vault on chain 4663 are
   immutable; the source changes do not affect them. R4 and the closing
   paragraph of the follow-up record explicitly disclaim live
   remediation.
2. **D12 residual** is documented and tested but not closed. A
   deployed wallet or EIP-7702 delegated EOA passes the bytecode
   guard and can have its unbooked credit consumed by a later contract
   caller. The PRD and integration notes document this as
   `UNSUPPORTED_USE`, but it is a real residual risk.
3. **M13 / M14 deferrals.** The Aave Stata and cross-version loop
   decimal rows (6 and 9 decimal face) were partially addressed by
   D66, with the cross-version loop matrix being addressed by D69
   ("Bucket B — 12 Aave-family cells"). I have not read the
   implementation to confirm.
5. **PARTIAL criteria.** 17 PARTIAL criteria remain per gap 3 (R2.4,
   R3.3, R4.2, R4.3, R4.5, R5.3, R6.3, R6.8, R8.1, R8.2, R10.3,
   R11.6, R14.4, R14.8, R14.16, R14.17, R14.18). D67 closed 16 of
   them; R10.3 is closed by D68 / D69. The evidence file's last
   green is "107 EVIDENCED / 1 PARTIAL" (only R10.3 remaining at the
   time of writing, since closed by D68/D69). I have not read the
   implementations backing the 16 closures; the named tests in the
   evidence file are not visible to me.
6. **F2 and F7** were replaced by the rate-provider model (D59 / D60)
   but F8 / F9 are recorded as "raised to the owner" in the matrix
   evidence, with F8 fixed by D61 and F9 by D62. Whether the closures
   are economically correct depends on whether the rated-valuation
   model is what the second auditor wants.

A second audit should be told explicitly that:
- live deployment is out of scope;
- D12 is an accepted limitation, not a closure;
- 195 of 215 matrix rows are COMPATIBLE, 7 DEPRECATED, 1 INCOMPATIBLE
  (the exact ratio depends on the run);
- the source is hermetically clean for the seven hook families, the
  16 SE families, the receipt-backed adapter, the helper library,
  the DETF families and the rate-provider packages.

A passing test suite is not a closure statement. The acceptance.json
and independent-completion.json are documentation artefacts that
describe what was tested, not a security claim.

## Findings

### F-APEX-M3-01 — Live immutable instances are not remediated (recorded, not fixed)

- Severity: High (documented limitation; not a fix)
- File and line: `docs/audits/apex-2026-09-17-evidence.md` lines 26–28
  (finding-matrix rows for APEX-2026-001-M2 and APEX-2026-003); PRD R4
- Intended behavior: source fixes, replays and migration handoff
  inventory, **no claim** that immutable live instances were remediated
- Broken requirement or invariant: PRD D7 ("no deployment, migration,
  live operational change or automatic upgrade is part of this PRD's
  execution scope"); R4 ("the evidence distinguishes replacement
  verified from existing deployment remediated")
- Impact class: residual live exposure on chain 4663 (seven V4
  diamonds, custody vault). Recorded as replacement verified, not deployment
  remediated. The audit's live-finding rows are unmitigated at the
  chain level.
- Fix direction: out of scope; live deployment requires a separate
  request. A second audit should treat live exposure as a known risk.
- Confidence: High
- Evidence class: observed (document text)

### F-APEX-M3-02 — D12 residual is documented but not closed

- Severity: Medium (documented limitation)
- File and line: `docs/audits/apex-2026-09-17-evidence.md` line 35
  (UNSUPPORTED_USE row); `contracts/utils/LocalCreditLib.sol:24–28`;
  test `test_APEX005_deployedWalletAcceptedAsUnsupportedUse`,
  `test_APEX005_eip7702DelegatedEoaAcceptedAsUnsupportedUse`
- Intended behavior: contract callers (including deployed wallets and
  EIP-7702 delegated EOAs) can credit unbooked balance; EOA callers
  are rejected; multi-call atomicity is not enforced
- Broken requirement or invariant: PRD D12 explicitly accepts this
  residual; it is not a broken requirement but a documented one
- Impact class: a contract that leaves unbooked balance across
  transactions may have part or all of it consumed by the next
  contract caller. No booked inventory is at risk. The integrator
  carries the risk, not other holders.
- Fix direction: none expected; the plan's D44 implements the
  acceptance tests. The residual is closed by documentation, not by
  code.
- Confidence: High
- Evidence class: observed (document text + LocalCreditLib source +
  test source)

### F-APEX-M3-03 — R4 fork criteria are PARTIAL pending a fork session

- Severity: Medium
- File and line: PRD R4.2, R4.3, R4.5; evidence file lines 282–286
  ("still PARTIAL: R2.4, R3.3, R4.2, R4.3, R4.5, R5.3, R6.3, R6.8,
  R8.1, R8.2, R10.3, R11.6, R14.4, R14.8, R14.16, R14.17, R14.18")
- Intended behavior: historical fork tests at chain 4663 block 64025200
  reproduce the primary reported vault; all seven reported V4 diamonds
  are probed; registry is enumerated; live fork evidence answers the
  auditor's claims
- Broken requirement or invariant: as of the evidence file's gap-3
  record, R4.2 / R4.3 / R4.5 required a fork session and were PARTIAL;
  the open-items ledger records that D67 closed R4.2 / R4.3 / R4.5 by
  re-running fork sessions, but the resulting test artifacts are not
  in the documents I read.
- Impact class: chain-side closure is delayed; specific ledger records
  (`historical.log`, `etherfi-fork-26023844.summary.log`) exist but
  their pass/fail state and exact assertions are not visible.
- Fix direction: re-run the fork session under `FOUNDRY_PROFILE=fork`
  with the Alchemy alias and confirm the six passing tests at block
  64025200 plus the EtherFi eth_main precheck fork pass and assert the
  recorded expected state.
- Confidence: Medium (the ledger describes the closure but I have not
  read the closure logs)
- Evidence class: inference from the open-items ledger

### F-APEX-M3-04 — Hook × SE matrix rows are tied to a single matrix run

- Severity: Low
- File and line: `docs/audits/apex-2026-09-17-evidence.md` lines
  185–215 (matrix run descriptions); `apex-2026-09-17-evidence/followup-review/independent-completion.json`
- Intended behavior: 195 COMPATIBLE / 1 INCOMPATIBLE / 7 DEPRECATED
  per the completion manifest, 165 COMPATIBLE / 3 INCOMPATIBLE / 7
  DEPRECATED / 0 DEFERRED-BLOCKED-FAILING per the evidence file's
  matrix run 21 (line 159). These two numbers do not agree.
- Broken requirement or invariant: independent-completion.json reports
  195 COMPATIBLE; the evidence narrative reports 165 COMPATIBLE in
  matrix run 21. Without reading both JSON sources and the run log I
  cannot reconcile the discrepancy; the most recent run appears to be
  the 165 / 3 / 7 number but the completion manifest may be the
  consolidated number including decimal rows from later D66 work.
- Impact class: matrix size disagreement; if a second audit counts
  matrix rows it may report a different number.
- Fix direction: clarify which run is the canonical final matrix and
  what each row's state means in the completion manifest. Update the
  independent-completion.json numbers to match the most recent log.
- Confidence: Low (the documents differ; I cannot tell which is
  authoritative without reading both sources in full)
- Evidence class: observed (two documents, two numbers)

### F-APEX-M3-05 — Test-quality risk on M14 decimal rows and row tolerances

- Severity: Low
- File and line: PRD D55 / D62 / D63 / D65 / D66; evidence file
  lines 280, 288–290
- Intended behavior: rows assert exact preview == execution; some
  rows tolerate 1% / 2% for F6, 1e-12 for the dual SY route, and
  1e-15 relative for F9. D55 says "exact agreement or `InvalidRoute`";
  the plan calls out the tolerance bands explicitly.
- Broken requirement or invariant: the tolerances weaken the
  "preview == execution" property the plan asks for. They are recorded
  as owner rulings, not as defects.
- Impact class: a second audit may treat the bands as bounds the SE
  family needs to fix, or as acceptable engineering tolerances. The
  plan documents them, so they are not silent.
- Fix direction: out of scope; documented as plan-level acceptance.
  Reasonable for a second audit to ask whether the bands can be
  tightened.
- Confidence: High (document text)
- Evidence class: observed

### F-APEX-M3-06 — ERC-4626 / Morpho `_burnSeShares` site coverage claims rely on ENUM

- Severity: Medium (unverified)
- File and line: PRD R7 enumerates sites at
  `ERC4626StandardExchangeInTarget.sol` lines 142 and 153,
  `ERC4626StandardExchangeOutTarget.sol` lines 102 and 114, and the
  Morpho `_execUnwrapExactIn` / `_execUnwrapExactOut` delegates.
- Intended behavior: every `_burnSeShares` site is corrected; no
  whole-self-balance sweep remains
- Broken requirement or invariant: PRD R7 requires the corrections
  cover every actual call site. I have not read the current-source
  versions of those four files to verify the corrections.
- Impact class: any uncorrected site is a residual exposure
- Fix direction: read the current-source `ERC4626StandardExchangeInTarget.sol`,
  `ERC4626StandardExchangeOutTarget.sol`, and the Morpho OutTarget;
  verify each calls `LocalCreditLib.requirePretransferCaller` before
  crediting self-shares and burns exactly `amountIn` on exact-in
  routes
- Confidence: Low (the plan claims completion; I have not opened the
  files)
- Evidence class: speculation (unverified)

### F-APEX-M3-07 — Rate-provider staticcall probes are documented exceptions to D37

- Severity: Medium
- File and line: PRD D41 / D48 / D49; evidence file lines 174–177
  (item 5 record); `UniswapV4SeBufferHookLegLib.rateAfterExchange`
  (D41); `StandardExchangeRateProviderFacet._safePreviewExchangeIn`
  and `WrappedStandardExchangeRateProviderTarget._safePreviewExchangeIn`
  (D48); six Balancer buffer-pool packages' `prepaySessionActive()` and
  preview-loop probes (D49)
- Intended behavior: D37 forbids all `try`/`catch` in D16 source; D41,
  D48 and D49 are recorded as interface-detection probes that stay
  `staticcall` with `(false, 0)` fallback
- Broken requirement or invariant: D37's letter says "no try/catch
  remains"; the amendments keep two interface-detection `staticcall` calls
  that take the `(false, 0)` branch on a non-32-byte or zero reply,
  which is materially different from D37's literal rule but is in
  spirit the same fall-through semantics the plan calls out. The plan
  is self-consistent here.
- Impact class: documented deviation with 60 boundary tests per
  package (`*_D49.t.sol`, EtherFi / Rocket transition-quote tests).
  Whether a second audit accepts the amendments depends on the audit's
  reading of "interface detection" as a justified exception.
- Fix direction: none expected; plan documents the exception. Reasonable
  for a second audit to inspect whether the fallback `(false, 0)`
  branches are tight (no return-rate leak, no selected-quote retry).
- Confidence: High (document text)
- Evidence class: observed

### F-APEX-M3-08 — Tolerance bands recorded for matrix rows may weaken assertions

- Severity: Low
- File and line: evidence file lines 196–207 (F1–F7 descriptions)
  and follow-up record entry "F6 fix"
- Intended behavior: each matrix row asserts ten §6 controls; F6 rows
  "keep two controls at a documented tolerance for F6"
- Broken requirement or invariant: PRD requires exact preview ==
  execution per D55; F6 rows tolerate 1% / 2% delta. The owner ruling
  D55 records this as exact agreement after the fix, but the
  evidence file records the matrix rows as keeping a tolerance. The
  two statements may not reconcile.
- Impact class: a row with a 1% / 2% tolerance does not assert the
  exact-preview property; it asserts the looser property. The D55
  ruling is for the FullSpread vault (no hook), while the matrix
  tolerance is for the hook interaction with FullSpread. Reading the
  documents together, the vault is exact and the hook is bounded;
  this is consistent.
- Fix direction: ensure matrix tests document their per-row
  tolerance at the test site, not only in the evidence narrative.
- Confidence: Medium (documents are consistent on a careful re-read)
- Evidence class: inference

### F-APEX-M3-09 — Acceptance ledger PARTIAL criteria rely on closure descriptions, not log review

- Severity: Medium
- File and line: `docs/audits/apex-2026-09-17-evidence.md` lines
  282–286 (gap 3 record); `apex-2026-09-17-evidence/acceptance.json`
- Intended behavior: every EVIDENCED criterion is backed by a named
  test assertion; every PARTIAL criterion names its gap; the
  PARTIAL → EVIDENCED conversions in D67 are documented per criterion
- Broken requirement or invariant: gap 3 records 17 PARTIAL criteria;
  D67 closes 16; R10.3 is closed by D68 / D69; the final state is 107
  EVIDENCED / 1 PARTIAL or 107 EVIDENCED / 0 PARTIAL depending on
  whether R10.3 was closed before or after the gap 3 walk
- Impact class: the ledger has a small reconciliation gap; a second
  audit may report a different PARTIAL count depending on which
  point in time is audited
- Fix direction: re-run the acceptance ledger re-walk and confirm the
  final 107 / 0 or 107 / 1 state; update the evidence file and the
  completion manifest to agree
- Confidence: Low (documents describe the closure but the closing
  sequence is not fully visible to me)
- Evidence class: inference

### F-APEX-M3-10 — FullSpread V3/V4 dead legacy facet artifacts remain under `out/`

- Severity: Low
- File and line: open-items ledger entry 4; evidence file lines 174–177
- Intended behavior: legacy `JoinFacet` / `JoinQueryFacet` sources
  deleted; `out/` stale artifact JSON not deleted because deletion is not
  permitted in this pass
- Broken requirement or invariant: the legacy artifacts are outside the
  R12 baseline and are never read by a FactoryService; they cost
  nothing at runtime but consume disk and confuse reader tooling
- Impact class: cosmetic / inventory hygiene
- Fix direction: delete `out/` artifacts on the next commit; R12
  baseline is already re-cut to 565 artifacts and 0 missing
- Confidence: High (document text)
- Evidence class: observed

## Criteria checked and unverified

**Checked (against documents and named source):**

- D11 — LocalCreditLib implementation matches the plan's three
  functions (`available`, `budget`, `requirePretransferCaller`).
  `contracts/utils/LocalCreditLib.sol:14–28`.
- D11 — `EOAPretransferNotAllowed` added to
  `contracts/interfaces/ISecurePullErrors.sol:16`.
- D9 / D23 / D28 — rebasing SE applies the guard before any credit
  (lines 84 and 118), implements `TransferDeltaInsufficient(needed, credit)`
  on short funding (line 125), and keeps asset-pretransfer rejection
  (lines 78 and 111).
- D50 — orbital Common uses `_unbookedBalance(tokenIn)` at lines 2111
  and 2125 (D50 fix sites). `_unbookedBalance` is defined at line
  2131 with the D50 rule (book is 0 on non-identity buffered legs).
- D44 — LocalCreditLib test exercises a real EIP-7702 delegated EOA
  via `vm.signAndAttachDelegation` and a deployed wallet via
  `AtomicPretransferCaller`; the constructor path is tested with
  `AtomicPretransferConstructorCaller` and a predicted create address.

**Unverified (named in plan but not read):**

- D34 / D37 — every `try`/`catch` removal site. The plan enumerates
  102 hard-call sites in 34 files; I have not opened those files.
- D15 — `pretransferred=false` exact-out pull-exact `used` rule across
  every D16 family. The plan names every site.
- D22 — D31 sweep logic in each depositing SE family. The plan
  describes the per-family precheck and sweep; I have not opened
  those SE families.
- D45 — `ReceiptBackedERC4626` shared adapter and its dispatch
  across Stata and ERC-4626.
- D43 — Aave cross-version loop tokenA cap and proportional unwind
  (D61 corrections).
- D46 — hermetic underlying stubs (Lido, Rocket, Aave, ERC-4626)
  implementation.
- D55 — F6 1% pad removal in FullSpread V3/V4.
- D60 — held-reserve rate-provider model across all four provider
  families plus single-CP / dual / DETF gate.
- D62 — `ERC4626StandardExchangeQuoteTarget` sequential transition
  projection rounding.
- D64 — FullSpread exact-out mint route closed form.
- D67 — group A and group B partial criteria closures (16 named
  criteria).
- D68 — `IStandardExchangeTransitionQuote` on the six Balancer pool
  SEs.
- D69 — 24 DEFERRED cells resolved to COMPATIBLE or INCOMPATIBLE.
- R4.2 / R4.3 / R4.5 — fork session at chain 4663 block 64025200
  and the 41 other registry vaults.
- R11.6 — fuzz counterexample minimisation persistence; the plan's
  PARTIAL note records that "no `failure_persist_dir` contents exist
  in the bundle because every red run is recorded with its exact
  failing arguments".
- R14.4 / R14.8 / R14.16 / R14.17 / R14.18 — per-family state
  closures; named test assertions and log paths.

## Vacuous or weak tests

From the documents I read, no vacuous test is visible. The
LocalCreditLib tests assert specific behaviour and use exact errors.
The Apex008 tests assert the resting-balance property with named
quantitative checks. The plan's R2.4 instruction rejects broad
`expectRevert()` and the evidence file's run-2 record shows a scanner
(`scripts/apex_bare_expectrevert_scan.sh`) caught bare-revert masks.

Specific risks I flag without a full read:

1. **PARTIAL retargets in run 2** (17 failures): these are described
   as tests that "still encoded a pre-APEX rule" and were retargeted.
   Retargeting a test to make it pass is acceptable when the new
   expectation matches the plan; it is a risk when the test's name
   still implies the old behaviour. The plan names the retargets
   (`Balancer-quad TokenCount`, `Loop SecurePull decimals`, `UniswapV4Detf_Cp_Univ3Se_ResidualGas`) and the new assertions (EOA
   pretransfer through `AtomicPretransferCaller`, D31 sweep asserted,
   D6 production preview gate). I cannot read the bodies of those
   tests to confirm the new assertions.
2. **Tolerance bands** in matrix rows (F6 / F9): the bands weaken the
   "exact preview == execution" property. They are documented as
   owner rulings, not as defects.
3. **Tests that pass only on setup state.** The Orbital matrix
   `test_R6_swapBothDirections_restingUnchanged` at line 207 of
   Apex008 asserts the resting balance after a swap. If the resting
   amount was set up correctly, this is a real assertion; if it was
   set up by the `_seedThreeLeg` setUp and the resting amount is a
   leftover of setup, the assertion is weaker. The test's `assertEq`
   at lines 213 and 218 is exact, which is the right shape.
4. **Inherited `test_API12_internalBurnExactNoRefund`** is described
   in the R13.8 table (line 116) as the API-12 body in the
   `REBASING_AWARE_ERC4626_SY_SE_PRD.md`. I have not read that test
   to confirm it asserts the burn-exactly-requested property rather
   than a no-refund pattern.

A second audit should sample-test a non-trivial subset of the named
APEX / R / I / O / E tests to confirm they assert the named
properties rather than a fixture default.

## Threat-model coverage gaps

Compared to the seven audit findings plus both retractions, and the
catalog classes A–K plus A0 / L / M / N / O and I1–I3 / E6 / K / J on
the D16 surfaces, the coverage described by the plan and evidence
file is:

**Covered by named tests (per evidence file):**:
- 001-M: FullSpread delivery / EOA test (see finding-matrix.json
  rows). D15 fix per D50 / D55.
- 001-M2: instance and implementation inventory at block 64025200.
  R4 closure.
- 003: custody public-share burn EOA and contract-caller tests.
  R5 closure.
- 008: orbital R6 17 tests in
  `UniswapV4StandardExchangeOrbitalBufferHook_Apex008.t.sol`.
- 009: ERC-4626 and Morpho burn-exactly tests
  (`test_O3_unwrapExactOut_burnsOnlyAmountIn`, `test_I1_*`,
  `test_I2_*`, `test_E6_*`).
- 004B: ERC-4626 exact-in no-refund tests; ReceiptBacked adapter
  tests; Uni V2 / Camelot bounded-credit refund tests (100/100/60 →
  40, 100/80/60 → 20, 60/100/60 → 0).
- 005: LocalCreditLib unit and fuzz tests
  (`testFuzz_APEX_*`).
- `beforeSwap` retraction: dual `test_F2_nonPoolManager_beforeSwap_reverts`
  and non-CP `test_F1_nonPoolManager_beforeSwap_reverts`.
- Weighted dust retraction: `test_D36_restingFace_notPaidToJoiner`.

**Threat-model coverage gaps I can identify from documents:**

1. **A0 — reverting metadata.** Documented at finding row and tested
   by `test_A0_revertingMetadata_propagatesDependencyRevert_D34`.
   Covered.
2. **I1 / I2 / I3 / E6 / K / J — catalog classes.** Per the
   evidence file, the named APEX / R tests assert them. The
   `Apex005` test files (orbital, weighted, dual, single-CP,
   curve-quad, Balancer-quad) each contain the true-flag exact-out
   refund, false-flag pull-used, 100-resting / request-1 control
   and EOA / constructor reject. The R6 / R7 / R8 sections
   enumerate. **I have not read the bodies** to confirm the
   assertions match the catalog classes.
3. **N — unbooked-balance across transactions (D12 residual).** The
   LocalCreditLib test asserts the residual exists; it does not
   assert that an attacker cannot profit from it. There is no
   threat-model test for "the next contract caller consumes the
   resting credit", because the PRD does not require one. A second
   audit could call this out as a residual coverage gap.
4. **L — call-back rotation.** The Apex008 tests cover the no-callback-refund
   property. Whether every hook family has a corresponding test
   is not visible.
5. **M — buffer-first residual.** The D36 tests cover the
   weighted / curve-quad / Balancer-quad residual. The orbital
   family has its own R6 path. The single-CP and dual-CP and
   non-CP families have matrix rows per the gap-1 work. Whether
   every hook family has its own D36 test is not visible.
6. **O — orbitaMatrix and SE-bound boundary.** The matrix rows
   describe the per-`tokenIn` boundary. Whether every boundary is
   tested is not visible.
7. **Live exploit re-execution.** R4's PARTIAL fork criteria
   (R4.2 / R4.3 / R4.5) are described as closed in the open-items
   ledger but the closure logs are not in the documents I read.
   Whether the fork session reproduces the auditor's reported
   findings on the primary vault and on the other six vaults is
   not visible.
8. **Cross-protocol sequencing.** The hook × SE matrix covers
   individual pairings; whether a sequence (e.g. Aave loop →
   FullSpread → Aave loop) is tested is not visible.
9. **Hermetic fork tests on chain 4663** (Robinhood mainnet) are
   documented in `historical.log` (six tests pass) but the test
   names are not in the documents I read.

A second audit should:

- read the named APEX / R / I / O / E tests for the four hook
  families with rate providers (single-CP, dual, orbital, weighted,
  curve-quad, Balancer-quad) to confirm the catalog coverage;
- read the receipt-backed adapter suite to confirm D45 dispatch and
  isolation;
- re-run the fork session at chain 4663 block 64025200 and confirm
  the historical inventory tests reproduce the auditor's claim;
- re-run the EtherFi eth_main fork at block 26023844 and confirm
  the FK8 precheck test asserts the live pool is unpaused;
- confirm the matrix 195/1/7 (or 165/3/7) final state matches the
  acceptance ledger and the completion manifest.

## Notes reserved for cross-review

The following items are saved for the cross-review pass:

- **F-APEX-M3-04** (matrix 195 vs 165) is a low-severity
  reconciliation issue. A cross-review should confirm which run
  number is canonical.
- **F-APEX-M3-09** (PARTIAL closure sequence) is a low-confidence
  inference. A cross-review should re-walk the acceptance ledger and
  confirm the final 107 / 0 or 107 / 1 state.
- **F-APEX-M3-06** (Morpho / ERC-4626 `_burnSeShares` coverage) is a
  speculation-flagged item. A cross-review should read the four
  named files and confirm the corrections are present at the
  current-source line numbers.
- The **D12 residual** (F-APEX-M3-02) is a documented limitation,
  not a defect. A cross-review should not push for closure; it
  should confirm the documentation is consistent across the PRD,
  evidence file, and integration notes.
- **D49 buffer-hook staticcall exceptions** (F-APEX-M3-07) are
  documented amendments to D37. A cross-review should confirm the
  60 boundary tests per package assert the `(false, 0)` fallback
  and the "no operative fallback" property.

If any peer review reports a finding that contradicts one of my
observations, I will adjust that finding's confidence, not silently
overwrite it. Originals are preserved above.

(End of report — total approximately 8,000 words.)