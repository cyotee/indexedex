# Independent first pass — Kimi K3

Date: 2026-10-03. Reviewer: Kimi K3 (independent first pass; no peer output read).

## Scope and assumptions

Assignment: judge whether the APEX 2026-09-17 remediation is complete in the current
working tree, whether tests are adequate for a second audit, and name remaining
threat-model coverage gaps. Documents read in full or in part:

- Plan `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md`
  (lines 1–556 of the file; the remaining acceptance-criteria tail, R11–R14 detail,
  was not reached before the coordinator stopped broad exploration).
- Follow-up record `apex-2026-09-17-followup-fixes.md` (full).
- Open-items ledger `apex-2026-09-17-review-open-items.md` (full).
- `CLAUDE.md` router (full).
- Evidence `catch-sites.json` (partial: lines 1–120 and 630–789; state-field scan).

Current source actually opened and read (not merely grepped):

- `contracts/utils/LocalCreditLib.sol` (full, 29 lines).
- `contracts/interfaces/ISecurePullErrors.sol` (full).
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol`
  lines 2020–2139 (`_faceSnap`, `_refundConservation`, `_refundThisCallSurplus`,
  `_freeTokenBalance`, `_securePull`, `_pullExactOutInput`, `_unbookedBalance`).
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol`
  lines 200–299 (including the `previewResidualBuffer` try/catch at 248–257).

Repository-wide `try`/`catch` content scans were run over: `contracts/hooks/uniswap/v4/standardExchange`,
`contracts/vaults/detf`, `contracts/protocols/dexes/balancer/v3/pools`,
`contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange`,
`contracts/vaults/standard`, `contracts/protocols/staking`, `contracts/protocols/lending`,
`contracts/protocols/dexes`, and a symbol scan for `_absorbDustToFeeTo`,
`_refundOrAbsorbAbove`, `_refundConservation`, `_refundBufferedDust`, `_refundPairDust`.

**Not read** (therefore unverified, not refuted): the audit PDF, `evidence.md`,
`acceptance.json` (the glob tool errored on broken `lib/crane/.grok/skills/*` symlink
targets before returning a path; I did not retry by direct path), the open-item PRDs,
the four canonical skills, `INDEXEDEX_AGENT_LAW.md`, and **every test file**. No test
was opened. Nothing was executed; this is a read-only source review. ReceiptBackedERC4626,
custody RebasingAware, ERC-4626 SE, Morpho, Stata, Aave cross-version loop, Lido/Rocket/
EtherFi prechecks, Balancer pool SE transition-quote (D68/D69), DETF guard wiring, and all
matrix/fuzz/invariant suites are unverified by this pass.

## Completion verdict

**Partially verified; not confirmable as complete from this pass.**

Observed consistent with the locked plan:

- D11/R9.2: `LocalCreditLib` exists with exactly `available` (balance > booked ?
  balance − booked : 0), `budget` (min), and `requirePretransferCaller` reverting
  `EOAPretransferNotAllowed()` via `BetterAddress.isContract`. `ISecurePullErrors` carries
  both errors. Matches the decision text exactly. (observed)
- D34 SE-family catch removal: content scans of `contracts/vaults/standard` (FullSpread
  V3/V4, ERC-4626, Morpho) and `contracts/protocols/lending` (Stata, cross-version loop)
  show no `try`/`catch` in production `.sol` — the D34 inventory sites are gone from
  current source. (observed)
- D37 Balancer pool packages: no `try`/`catch` in production `.sol` under
  `contracts/protocols/dexes/balancer/v3/pools`. (observed)
- D48: both rate-provider packages now use `staticcall` probes
  (`StandardExchangeRateProviderFacet.sol` lines 78/153/183;
  `wrapped/WrappedStandardExchangeRateProviderTarget.sol:117`; wrapped DFPkg staticcall
  at 132). Consistent with the staticcall rewrite. (observed)
- R6/D14/D15 orbital corrections: `_refundConservation` refunds only balance above the
  opening per-leg face snapshot on non-identity buffered legs; identity and raw legs
  refund 0; `_securePull` enforces `requirePretransferCaller` and
  `TransferDeltaInsufficient(claimed, U)` with `_unbookedBalance`; `_pullExactOutInput`
  pulls `used` on false-flag and refunds only `credit − used` on true-flag. The five
  call sites (1211, 1365, 1403, 1747, 1883) match the plan's five-site count.
  `_refundBufferedDust` is absent from the orbital file. (observed)

Observed inconsistent or unresolved against the locked plan — see Findings F1–F3.
Everything else in D1–D69 and the 108 acceptance criteria is **unverified** by this pass
(see "Criteria checked and unverified").

The follow-up record's own history justifies caution about documentary closure: D61
records an earlier "green" that was stale `out/` bytecode masking 22 reverting exact-out
E2E instances; D67 records one bare-revert mispin in R2.4 found on re-audit. Both were
self-reported and corrected, but they demonstrate that green-run and acceptance-ledger
claims in this program have been wrong before at the snapshot date. I treated
`acceptance.json`/`independent-completion.json` as claims, per instructions.

## Test-quality verdict

**Unverified.** I read zero test files, so I cannot confirm or refute the absence of
vacuous tests, bare `expectRevert()`, setup-only assertions, SUT mocks, or weak stand-in
properties in the current tree. The documentary record itself flags historical instances
of exactly the failure classes the assignment asks about (stale-bytecode green in D61;
a mis-pinned bare revert in R2.4; an inherited UniV4 DETF fixture that had exhausted its
user funding and allowance during bootstrap — follow-up record, "latest integrated
matrix/regression run"). Those were reportedly corrected, but correction is a documentary
claim I did not verify against test source. The plan's own requirements (R2.4 exact
errors and exact deltas; R11 counters that setup cannot satisfy; D24 release counts via
env overrides) are the right bar; whether the current suites meet it is untested by me.

## Second-audit readiness

**Not ready on what this pass could verify — verdict: NOT-READY (insufficient verification),
with one apparent production-rule deviation (F1/F2) requiring reconciliation before
submission.** This is not a claim that defects exist across the remediation; it is a
statement that the largest completion claims (ReceiptBackedERC4626, custody R5, ERC-4626
R7/R8, Morpho R7, Aave D43/D61, staking prechecks D39/D40/D47, Balancer D68/D69, DETF
guard wiring R13, the 195-row matrix, 33 campaigns, 37 fuzz properties) rest on documents
I did not validate against current source, and that the one broad production scan I could
run (try/catch) surfaced current-source catches in a D16 DETF file and one hook library
that the letter of D37/D30 does not obviously permit. Passing tests and completion JSONs
were not treated as proof, per instructions.

## Findings

### F1 — Residual `try`/`catch` sites in D16 DETF production source (`UniswapV4DetfCommon.sol`)

- Severity: Medium (rule-compliance; security impact depends on catch bodies).
- File and line: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol`
  lines 572, 604, 628, 642, 664, 667, 670, 676, 680, 683, 699 (current tree).
- Intended behavior (plan D37): "every `try`/`catch` in D16 hook, DETF and Balancer
  buffer-hook package production source except D41 and D48: the wrapped call is made
  directly and the dependency's revert propagates"; D49 later added twelve named Balancer
  buffer-hook staticcall probes as the only further exceptions. Uniswap V4 DETF is a named
  D16 DETF family. The plan's final verification scan (Verification §3) runs
  `rg '\b(try|catch)\b' contracts/vaults/detf` and expects only classified exceptions.
- Broken requirement/invariant: current source retains at least seven distinct
  `try`/`catch` constructs in this file, including `catch {}`-style soft fallbacks around
  SE `previewExchangeIn` / interface probes (lines 664–701 region) and residual-join
  self-calls (572, 604, 628, 642). D30 additionally forbids "a family-specific
  recognized-error list". No D41/D48/D49 exception covers this file.
- Impact class: error-propagation / potential mispricing-if-preview-fails-soft; primarily
  an audit-readiness and rule-conformance defect.
- Fix direction: reconcile each site against the recorded D37 disposition in
  `evidence.md`; remove the catches (hard calls) or obtain and record an explicit owner
  exception with the same formality as D49. Note: `catch-sites.json` lists eight
  `UniswapV4DetfCommon.sol` sites (lines 170/176/482/560/594/633/638/663) with state
  `REPORTED` — that file is a baseline inventory, not a disposition record, so it does not
  close these.
- Confidence: Medium that a D37 deviation exists; Low on whether any owner exception was
  recorded in the unread portions of `evidence.md`.
- Evidence class: Observed (catches present in current source) + inference (that D37
  forbids them absent an exception).

### F2 — Catch-body recognized-error soft return in single-CP hook ClaimLib

- Severity: Low–Medium.
- File and line: `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:248–257`
  (`previewResidualBuffer`): `try IStandardExchangeIn(...).previewExchangeIn(...)` with a
  `catch (bytes memory reason)` that returns 0 when the reason is exactly
  `AlignmentNotAchievable()` and rethrows otherwise.
- Intended behavior: D30 — "No catch-body booking and no family-specific recognized-error
  list"; D37 — every D16 hook catch becomes a hard call except D41/D48 (and D49's named
  Balancer probes). The function NatSpec says "Residual maintenance only."
- Broken requirement/invariant: this is precisely a recognized-error catch
  (`AlignmentNotAchievable` → 0). It is the only remaining production `try`/`catch` in the
  entire `standardExchange` hooks tree, which suggests either an undocumented exception or
  an oversight during D37 sweep.
- Impact class: quote-path correctness; a 0 residual quote changes residual-buffering
  behavior rather than reverting. No direct fund movement is caused by this view alone.
- Fix direction: confirm whether the owner ruled this site an exception; if not, convert
  to a hard call per D37 or record a D49-style amendment. Verify the matrix/behavior
  suites pin both branches (rejected remainder stays locally owned per the NatSpec).
- Confidence: Medium.
- Evidence class: Observed.

### F3 — Silent `try/catch {}` on rewards synchronization in `TokenStakingTarget`

- Severity: Low.
- File and line: `contracts/protocols/staking/token/TokenStakingTarget.sol:452`:
  `try IDETFFundedRewards(address(claimToken)).synchronizeRewards() {} catch {}`.
- Intended behavior: unspecified for this file — `contracts/protocols/staking/token/` is
  not among the D16 SE families (lido, rocket-pool, etherfi, rebasingVault) nor the named
  D16 DETF entries (`StakedDETFTarget` is under `vaults/detf/common/claimToken`, a
  different file). D37's blanket rule is scoped to D16 production source.
- Broken requirement/invariant: none assigned by the supplied documents; flagged because a
  fully silent catch on a rewards-synchronization call is the same defect class D34/D37
  removed elsewhere, and the second auditor will likely ask whether it was considered.
- Impact class: reward-accounting liveness (a failed sync is invisible).
- Fix direction: confirm scope classification; if in any D16/D37 consumer set, remove or
  document; otherwise record an explicit out-of-scope note in the evidence file.
- Confidence: High that the site exists; Low that it violates a locked decision.
- Evidence class: Observed + speculation (on intended disposition).

### F4 — Broken skill-mirror symlink targets under `lib/crane/.grok/skills/`

- Severity: Low (repository hygiene / evidence tooling).
- File and line: `lib/crane/.grok/skills/reactive-architecture`, `reactive-deployment`,
  `reactive-integrations`, `reactive-callbacks`, `reactive-family`, `reactive-contracts`,
  and `lib/crane/contracts/external/layerzero/oft-evm*` (dangling symlink targets reported
  by the search tool on 2026-10-03).
- Intended behavior: D58 / CLAUDE.md claim `sync-codex-skills.py --check` passes and skill
  mirrors are maintained; the open-items ledger records that gate as green.
- Broken requirement/invariant: dangling mirror links contradict a clean mirror state;
  they also broke my glob over `docs/audits/...` (tool traversed them), which is why
  `acceptance.json` was not located by pattern in this pass.
- Impact class: tooling/evidence reliability; no contract impact.
- Fix direction: re-run the mirror sync scripts and `--check`; remove or repair dangling
  links.
- Confidence: Medium (tool-reported; not independently stat'ed).
- Evidence class: Observed (tool error output).

## Criteria checked and unverified

Checked against current source (spot checks, not exhaustive):

- D11/R9.2 library shape — confirmed.
- D9 error existence — confirmed (`EOAPretransferNotAllowed` present; its per-family
  wiring **not** checked).
- D34 catch removal (U3/U4 FullSpread, ER quote target, MO DFPkg, ST reward catches, RP/EF
  sites) — confirmed absent by scan of `contracts/vaults/standard` and
  `contracts/protocols/lending`; RP/EF files not individually opened.
- D37 balancer pool packages — confirmed absent by scan.
- D48 staticcall rewrite — confirmed present.
- R6 orbital five-site refund rewrite, `_refundBufferedDust` deletion, D50/D15
  `_unbookedBalance` credit — confirmed by reading current functions.
- D37 DETF / hook-library completeness — **refuted pending exception evidence** (F1, F2).

Unverified (no current-source confirmation in this pass): R1–R14 acceptance criteria other
than the above; D45 ReceiptBackedERC4626 (files not opened); R5 custody SE/SY corrections;
R7/R8 ERC-4626 and Morpho; D35 UniV2/Camelot refund caps; D36 weighted/dual dust-transfer
removal (bodies of retained `_refundBufferedDust`/`_refundPairDust` not opened);
D39/D40/D47 staking prechecks; D43/D61 Aave loop; D68/D69 Balancer transition-quote and
hook execution-gap fixes; D56 dead-selector removal; D57 Slipstream deprecation markings;
R13 EOA guard on every D16 entry; R12 selector/size gates; D20/R10.3 matrix contents;
R11/D24 fuzz/invariant release counts; R2 red/green pairs; all fork evidence (R4, R14.20);
NatSpec/law updates (step 20). The completion snapshot is dated 2026-09-25; I did not
diff the tree against that snapshot, so post-snapshot drift is unchecked except where my
scans touched it.

## Vacuous or weak tests

None observed directly — no test files were read, so no test is named here. Documentary
signals that a second pass should re-verify against test source (not findings):

- D61 follow-up: 22 hermetic loop E2E instances once "passed" on stale `out/` bytecode
  while actually reverting `AmountOutNotMet` — a vacuous-green mechanism. The record says
  identity-before/after-release hashes now guard this; unverified.
- D67: one R2.4 negative test had been pinned to the wrong revert
  (`EOAPretransferNotAllowed` instead of the named `TransferDeltaInsufficient`) and was
  rewritten; the record claims a full re-audit of R2.4 pins found no others; unverified.
- Follow-up record: an inherited UniV4 DETF test whose replacement fixture had exhausted
  user funding/allowance during bootstrap (setup-failure-adjacent); reportedly fixed.
- Open-items item 7: on ERC-4626/Morpho/FullSpread exact-out, the `used > credit` check
  runs before the bytecode guard, so a short-funded EOA sees `TransferDeltaInsufficient`
  instead of `EOAPretransferNotAllowed` — recorded as an accepted letter-of-the-plan
  deviation; any test asserting exact error selection must encode this ordering.

## Threat-model coverage gaps

I could not perform the test-vs-catalog comparison (catalog classes A–K, A0/L/M/N/O,
I1–I3/E6/K/J on D16 surfaces; the seven audit findings plus both retractions) because no
test files and no skill/catalog files were read. Everything in this section is therefore
"unverified", not "absent". Documented residual exposures and known-not-green items from
the supplied records themselves:

- D12 resting-credit risk is accepted (`UNSUPPORTED_USE`): any contract caller with a
  declared amount within available credit can consume a resting unbooked balance; EIP-7702
  delegated accounts and contract wallets pass the guard. Accepted by ruling, but it is a
  live integrator-facing hazard that a second audit must see documented as accepted, not
  fixed.
- Live immutable instances (seven Uni V4 diamonds + custody vault on chain 4663) are
  replacement-verified, not deployment-remediated (R4.6 distinction; out of source scope).
- Open-items item 3: `EtherFiStandardExchangeProjectionFork` reverts in `setUp` at its
  pinned block 24,000,000 (parked; needs re-pin or a D40 production change); FK6 fails by
  design on zero live instant-redeem capacity. Fork suite is therefore not fully green by
  the record's own account.
- Open-items F4 fork note: `RocketPoolStandardExchangeProjectionFork` at block 26,023,844
  fails three of its own tests; "recorded here for the owner, not acted on" — an
  unresolved recorded failure.
- D60 notes F8 and the rated first-mint / `kLast` interpretation "remain for the owner"
  at signing time; D61/D63 later address F8/first-mint, but whether the owner ever closed
  the `kLast` interpretation item is unverified.
- R10.3's 12 Aave × hook multi-reserve cells were a follow-up workstream (D69 bucket B
  claims delivery); current-source confirmation not done here.
- No claim of "all possible attacks" coverage is made or supportable; the above are the
  gaps visible from documents alone.

## Notes reserved for cross-review

- My F1/F2 rest on the letter of D37/D30 plus the plan's own final scan command; if
  `evidence.md` (unread by me) records an owner exception for the `UniswapV4DetfCommon`
  residual-join catches or the single-CP `previewResidualBuffer` catch, these downgrade to
  documentation-consistency items. Peers who read the full evidence file should confirm or
  refute.
- The `catch-sites.json` states are all `REPORTED` except twelve `D49_STATICCALL_PROBE`
  entries — i.e., it is a baseline inventory, not a disposition ledger; do not cite it as
  proof of removal.
- I did not verify a single test. Any peer test-quality findings should be treated as
  primary over my unverified status.
- The broken `.grok` symlink targets (F4) interfered with repository globbing; peers using
  ripgrep-based tools may have hit the same errors and should say whether they did.
- This session began with broad document reading and was stopped by the coordinator before
  the acceptance-criteria tail (R11–R14 detail), the audit PDF, the skills, and all test
  source were reached; the unverified lists above are the exact consequence, not
  discretion.
