# Independent first pass — Grok

Reviewer: Grok (xai/grok-4.7), independent first pass. Not a replacement session. No other reviewer output was read. No tests, forge, git, or deployments were run. Completion JSON, acceptance stamps, and historical logs are not treated as proof.

Date of review: 2026-10-03. Claimed completion snapshot: 2026-09-25.

## Scope and assumptions

Intended behavior is taken only from the locked plan, the remediation PRD path named in the assignment, the follow-up record, the open-items ledger, and the evidence narrative. The audit PDF was not opened in this pass. Canonical Crane skill files under `lib/crane/.claude/skills/` were blocked by an external-directory guard; the local mirrors `.claude/skills/crane-adversarial-testing/SKILL.md` and `.claude/skills/crane-testing/SKILL.md` were read instead, plus `.claude/skills/indexedex-adversarial-testing/SKILL.md` and `.claude/skills/indexedex-testing/SKILL.md`.

This pass stopped before a full walk of the 108 criteria, the hook × SE matrix sources, invariant handlers, and most money-path bodies. Where source was not read, the completion claim is **unverified**, not confirmed. Current source supersedes older narrative inside `docs/audits/apex-2026-09-17-evidence.md`. The header and follow-up record claim later completion; those claims were not re-executed.

Accepted residuals that this pass does not treat as missed source fixes: D12 non-atomic contract pretransfer; D57 Slipstream deprecation (not a rewrite); live immutable instances are out of scope for a source patch (`replacement verified` is not `deployment remediated`).

## Completion verdict

**Not confirmed complete.**

Observed as present and aligned with the locked text that was read:

- `LocalCreditLib.available`, `budget`, and `requirePretransferCaller` match D11 / R9.2 (`contracts/utils/LocalCreditLib.sol`).
- FullSpread V4 hookless exact-in pretransfer credits exactly `amountIn` after an unbooked-availability check and calls the EOA guard before credit (`UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol` `_secureTokenTransfer`). False-flag pull requires measured delta equality. `_pretransferCredit` is `budget(available(balance, reserveOfToken), maximum)`.
- Named helpers `_absorbDustToFeeTo` and `_refundOrAbsorbAbove` have no matches under `contracts/`.
- No `catch (` matches under `contracts/protocols/dexes/balancer/v3/rateProviders` (negative search only; the D48 staticcall bodies were not read).
- D49-named Balancer buffer-hook files still contain `staticcall` probes at the files named in D49. Probe bodies were not read, so D49 conformance is unverified.
- Follow-up and evidence header state that live instances were not migrated. That limitation is consistent with D7 / R4.6 and is not a source-completion failure.

Observed as **not** matching a locked decision:

- D37 catch removal is not complete in current Uni V4 DETF production source, and a D16 hook production library still catches a dependency revert. See findings.

Not verified, so not closed by this pass:

- The 108 nested acceptance criteria. `acceptance.json` stamps them `EVIDENCED` and points at `independent-completion.json`. That stamp is a claim. Several criterion evidence strings still describe earlier incomplete states (for example R1.2 still says 003/009/004B/005 are `FIX_IMPLEMENTED` and that hermetic is not a green release).
- Hook × SE matrix completion (R10.3 / D20 / D69). The evidence file's execution-gates section still describes 6 compatible ERC-4626 rows and 148 incompatible rows, and says compatible evidence is not a Cartesian D20 row. The follow-up record claims 195 compatible / 1 incompatible / 7 deprecated. Current matrix tests were not read.
- Release fuzz (10,000) and stateful campaigns (256 × 64), success-counter non-vacuity, and red/green identity of prefixed vs current artifacts.
- Historical fork inventory (R4) and EtherFi fork prechecks (R14.20) against current tests.
- Receipt-backed adapter, Morpho, Stata, Aave loop, custody `takeShares`, orbital credit math, and DETF prepaid entries beyond the Uni V4 DETF residual helpers that were read.

A code edit, a green-count narrative, or a completion JSON is not closure.

## Test-quality verdict

**Not adequate to submit, on the evidence this pass could check. Full test-quality judgment is incomplete.**

What was checked:

- A filename-scoped search for bare `vm.expectRevert()` under `*APEX*` tests and under `*SeMatrix*` tests returned no matches. That does not prove those suites assert exact selectors, balance deltas, or the locked refund rules. The bodies were not read.
- Repo-wide bare `vm.expectRevert()` exists in many non-APEX fork and spec files. Those hits were not reviewed as APEX regressions and are not cited as APEX vacuous tests.
- Invariant success-counter patterns were not read. Whether a campaign can be satisfied by setup or by skipping the money path is **unverified**.
- The plan's own test law (R2.4, R2.5, indexedex-adversarial I1–I3 / E6) requires exact errors, unchanged state on rejection, exact transfer and share deltas, and a same-state integrating-contract positive control. This pass did not confirm those assertions in current tests.

Inference: a second auditor cannot rely on the 34,909 / 0 narrative. The evidence file still contains an earlier hermetic result of 25,737 passed / 6,424 failed, and it explicitly says that run is not a green release suite. The later zero-failure claim was not re-run here.

## Second-audit readiness

**not-ready**

Reason, separated by evidence class:

- Observed: D37's hard-call / propagate rule is broken in current D16 DETF source (and one D16 hook library). Submitting "remediation complete" would hide that deviation.
- Observed: the evidence bundle contradicts itself. The header and follow-up claim a finished local remediation. Historical sections and some `acceptance.json` evidence strings still describe an incomplete matrix, a failing hermetic run, and findings that are only `FIX_IMPLEMENTED`.
- Inference: test adequacy for the locked money-path rules is unproven in this pass. Passing-count claims and `acceptance.json` are not proof.
- Speculation: none used for the verdict.

Documented residuals that would remain even after a source re-audit, and that do **not** by themselves justify "ready":

- Live chain-4663 instances are immutable. Replacement tests do not remediate them.
- D12: a contract caller, contract wallet, or EIP-7702 delegated account can consume resting unbooked credit. Accepted if NatSpec still matches; NatSpec on the Crane interfaces was not re-read in this pass (external Crane tree was not opened).
- D57: Slipstream is deprecated, not rewritten.

## Findings

### 1. Uni V4 DETF residual helpers still catch dependency failures

- **Severity:** Medium
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:572-578`, `:604-610`, `:628-635`, `:642-649`, `:664-684`, `:699-706`
- **Intended behavior:** D37. Every `try`/`catch` in D16 DETF production source is removed except the D41 and D48 staticcall exceptions. The wrapped call is made directly. The dependency revert propagates. D30: unexpected failures revert the whole operation; no catch-body booking; no family-specific recognized-error list.
- **Broken requirement or invariant:** Current production source still catches. `_retainSubSharePairResidual` has empty catches that return false and continue. `_joinResidualCapped` / `_joinResidualUnbalanced` defer on `AlignmentNotAchievable` (`return true`) instead of propagating. `_parkUnmintablePairDust` treats `AlignmentNotAchievable` as a reason to keep or donate residual rather than revert. Other selectors are rethrown via `_requireAlignmentFailure` (line 718). That is still a catch, and it is not D41 or D48.
- **Impact class:** Error propagation and residual accounting. A dependency failure on these residual-maintenance probes does not roll back the parent operation. Alignment-domain failures can defer a join or park/donate residual. Empty probe catches do not themselves book, but they also do not propagate.
- **Fix direction:** Remove these catches or obtain an explicit locked exception with the same specificity as D41/D48/D49 (which calls stay probes, which errors may be recognized, and which tests prove other reverts still propagate and that booked inventory is not paid out). Do not leave an informal comment as the exception.
- **Confidence:** High that the catches exist and are outside D41/D48/D49. Medium on economic severity, because callers of these helpers were not fully traced.
- **Evidence class:** Observed (source). Inference on whether a later unwritten owner ruling intended this; the follow-up record that was read does not authorize these catches.

### 2. Single-CP hook residual preview converts one dependency revert into a zero quote

- **Severity:** Medium
- **File and line:** `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:246-257`
- **Intended behavior:** D37. Hook production `try`/`catch` is removed except D41. D30: a precheck or dependency revert propagates unchanged. D37's note that ClaimLib IERC-165 probes stay hard calls does not authorize a new residual-preview catch.
- **Broken requirement or invariant:** `previewResidualBuffer` catches `previewExchangeIn`. Only `AlignmentNotAchievable` is turned into a zero return. Every other revert is rethrown. A zero return is not propagation of that dependency error.
- **Impact class:** Quote / execute divergence and error propagation. Callers that treat zero as "no shares" can take the residual-maintenance branch instead of failing closed.
- **Fix direction:** Propagate the dependency revert, or record a locked exception that names this selector, forbids using the zero result as credit, and tests that every other revert still surfaces unchanged.
- **Confidence:** High on the catch and the zero return. Medium on caller impact; `bufferQuotedResidual` (line 262) was read and is a hard `exchangeIn`, but other callers of the preview were not enumerated.
- **Evidence class:** Observed.

### 3. Completion ledger stamps EVIDENCED over evidence that still describes an incomplete remediation

- **Severity:** High (audit-readiness / evidence integrity; not a direct theft primitive)
- **File and line:** `docs/audits/apex-2026-09-17-evidence/acceptance.json:17-23` (R1.2 evidence string versus `state: EVIDENCED`); `docs/audits/apex-2026-09-17-evidence.md:1-3` versus `:43-45` and `:90-107`; `docs/audits/apex-2026-09-17-followup-fixes.md:104-110`
- **Intended behavior:** R1.2 / R1.3. A code edit is not `VERIFIED_FIXED`. Each criterion is checked only when evidence contains the exact test name, command, outcome, and source/artifact identity. Historical and corrected builds stay distinct. The plan says unresolved archive or pre-existing failures remain explicit blockers rather than a completion claim.
- **Broken requirement or invariant:** The ledger marks criteria `EVIDENCED` by pointing at `independent-completion.json`. The same R1.2 evidence string still says 003/009/004B/005 are `FIX_IMPLEMENTED`, that prefixed rebuild is pending, and that hermetic is not claimed green. The evidence narrative header claims 34,909 tests, 0 failures, and all 108 criteria referenced to the final release. The execution-gates section of the same file still records a hermetic run of 25,737 passed / 6,424 failed and a hook × SE matrix of 6 compatible / 148 incompatible, and says that run is not a green release suite. The follow-up record asserts the later zero-failure run. This pass did not re-run it and does not treat the JSON as proof. Current source was not shown to match the later claim for the matrix or the campaigns.
- **Impact class:** Evidence integrity. A second audit that accepts the header or the JSON can miss both an incomplete control set and the D37 deviation above.
- **Fix direction:** Re-derive the 108-row ledger from current source and current tests. Replace superseded log citations. Keep historical sections labeled so they cannot be read as the current disposition. Do not stamp `EVIDENCED` or `VERIFIED_FIXED` from a completion manifest alone.
- **Confidence:** High that the documents contradict each other. The later run may have happened; it was not independently confirmed here.
- **Evidence class:** Observed (document contradiction). Inference that the later count is unverified.

## Criteria checked and unverified

| Item | Result |
| --- | --- |
| D11 / R9.2 `LocalCreditLib` arithmetic and EOA helper | Checked against source. Matches the locked formulas. Family routing through the library was not inventoried. |
| D9 / D15 FullSpread V4 hookless exact-in pretransfer | Checked `_secureTokenTransfer` and `_pretransferCredit`. Exact-in credits `amountIn` and does not refund in that function. Exact-out refund call sites and the V3 twin were not read. Pons-family Common has the same function names; body not compared. |
| D6 named dust-to-fee helpers | No matches for `_absorbDustToFeeTo` or `_refundOrAbsorbAbove` under `contracts/`. Other residual-to-fee paths were not searched beyond those names. |
| D12 | Documented as accepted `UNSUPPORTED_USE` in the evidence integration notes. Current Crane NatSpec not re-read. |
| D32 public-pretransfer rejects | Unverified in current Aave loop and Balancer pool SE targets. |
| D34 / D37 / D41 catch inventory | D37 refuted for Uni V4 DETF Common and single-CP ClaimLib residual preview. Rate-provider directory: no `catch (` matches (bodies unread). Balancer pool directory: no `catch (` matches. Lending and staking protocol trees: no `catch (` matches in the search that completed. Preserved `contracts/protocols/dexes/uniswap/v3/` still has catches; that tree is inventory-only and was not treated as a missed edit. |
| D48 staticcall rewrite | Unverified beyond absence of `catch (` in the rate-provider directory. |
| D49 buffer-hook probes | `staticcall` present at the six D49 file sites named in the plan. Length checks and "operative calls stay hard" were not read. |
| D50 orbital `_unbookedBalance` | Function exists at `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:2131`. Body not read. |
| D57 Slipstream deprecation | Not treated as a missed rewrite. Current deprecation markers not re-read. |
| R1 finding matrix / R4 live inventory | Unverified against current fork tests. Evidence text still separates replacement verified from deployment remediated. PDF not opened. |
| R2 red/green before each fix | Unverified. Prefixed logs are cited; not re-run; assignment forbids treating logs as proof. |
| R3–R9 money-path regressions | Unverified in tests. Partial source check only for FullSpread V4 hookless exact-in and the shared helper. |
| R10.3 / D20 / D69 matrix | Unverified. Narrative conflict between historical 6/148 and follow-up 195/1/7. |
| R11 campaigns and R2.4 exact assertions | Unverified. |
| R13 NatSpec / law updates | Unverified, except indexedex adversarial skill text that was read still states the EOA guard, exact-in no refund, and exact-out `credit - used` rule. |
| R14 capacity book-and-sweep | Unverified in ERC-4626, Stata, Rocket, EtherFi, Lido, and Aave loop source. |
| Open-items ledger | Read as a historical record through D69 claims. Those execution claims were not re-checked in current tests. |

## Vacuous or weak tests

No APEX or SeMatrix test body was confirmed vacuous in this pass. Do not treat that as a clean bill.

Not established, and therefore still open for cross-review:

- Bare `expectRevert()` with no selector inside APEX suites (filename search found none; bodies unread).
- Assertions only on setup.
- Tests that swallow the production revert.
- Names that claim an accounting property but assert a weaker one.
- SUT mocks.
- Success inferred only from a return value.
- Matrix stubs counted as compatible.
- Invariant campaigns whose success counter can be satisfied by setup or by skipping the money path.
- Fuzz tests that do not bind the claimed property.

The evidence file itself records an earlier class of weak or mis-aimed tests (EOA prepaid still expecting `TransferDeltaInsufficient`, gift surplus still expecting a refund, dual-exit still asserting an unused-max leftover). The follow-up says those were corrected. Current tests were not read to confirm the correction. That class stays **unverified**, not closed.

## Threat-model coverage gaps

Compared with what this pass actually read, not with a claim of total coverage.

| Control class | This pass |
| --- | --- |
| APEX-2026-001-M stale reserve / phantom delivery | FullSpread V4 hookless exact-in no longer credits from booked reserve in the function that was read. Preserved V3/V4 trees were not re-read. Reproduction tests not read. Live instances not remediated. |
| APEX-2026-001-M2 instance inventory | Unverified. |
| APEX-2026-003 custody public-share burn/refund | `takeShares` exists. Body not read. Tests not read. |
| APEX-2026-008 orbital prior-face refund | Refund helper names were not re-located. `_securePull` / `_pullExactOutInput` / `_unbookedBalance` exist. Bodies not read. |
| APEX-2026-009 self-share sweep | ERC-4626 `_burnSeShares` exists at `ERC4626StandardExchangeCommon.sol:282`. Body not read. Morpho path not read. |
| APEX-2026-004B idle underlying sweep | Named refund-or-absorb helpers are gone from `contracts/`. Replacement booking/sweep behavior not read. |
| APEX-2026-005 canonical availability | Helper matches the spec. Consumer inventory not re-derived. |
| `beforeSwap` guard retraction | Not re-tested. No invented guard fix was looked for. |
| Weighted dust retraction / D36 | Not read. |
| Catalog I1–I3 / E6 on D16 surfaces | Skill law was read. Production-route tests were not. Coverage is unverified. |
| A0 / L / M / N / O | Not mapped to current suites in this pass. |
| A–K remainder (donation, reentrancy, access, composition, griefing) | Not mapped. Absence of a test name in this pass is not proof the test is missing. |
| D12 contract-caller residual | Accepted limitation if NatSpec matches. Not re-verified on the Crane interfaces. |
| D32 reject surfaces | Unverified. |
| D34/D37 unexpected dependency revert | **Gap confirmed** on Uni V4 DETF residual helpers and single-CP residual preview (findings 1 and 2). Other D16 families were only negative-searched for `catch (`. |
| Hook × SE matrix threat coverage | Unverified. Historical evidence says most rows were incompatible stubs. Later claim says that was replaced. Current files not read. |

Missing control classes that can be named without inventing attacks:

- Proof that every D16 public pretransfer entry rejects a code-less caller with the exact error, and that a same-state contract caller is credited only under D15.
- Proof that exact-in refunds nothing and exact-out refunds only credit minus used, with balance and share deltas, on the families whose bodies were not read.
- Proof that booked inventory is not paid out (E6 / I1) on those same families.
- Proof that capacity shortfall is booked and later swept, rather than refunded or silently dropped.
- Proof that unexpected dependency reverts propagate on the D16 surfaces that still catch, and on the D41/D48/D49 probe boundaries.
- Proof that residuals are not sent to the fee recipient after the named helpers were removed.
- A current, non-superseded matrix disposition for each hook × SE cell (compatible, incompatible, or deprecated), not a historical stub count.

"All possible attacks" is not a finite claim. This list is the gap relative to the PRD, plan, and the adversarial catalog as far as this pass could see.

## Notes reserved for cross-review

- Canonical Crane skills were not read from `lib/crane/.claude/skills/` (external-directory guard). Local mirrors were used. If those mirrors are stale, cross-review should say so from the canonical files.
- Audit PDF was not read. Finding dispositions in the evidence table were not checked against PDF page text.
- `acceptance.json` is 1,921 lines. Only the first criteria and the R1.2 contradiction were read. A peer who walked later rows may have criterion-level evidence this pass marks unverified.
- FullSpread README section "Activation and ownership" still says a failing `decimals()` call falls back to 18. D34 forbids that fallback. The current `decimals()` implementation was not read, so this is a documentation conflict, not a confirmed code defect. No line number was captured.
- `_refundUnusedShares` in the V4 hookless Common refunds `delivered - used` to `recipient` (lines 964-967). Whether callers pass a D15 credit cap was not traced. Do not treat that as a confirmed over-refund.
- Morpho `catch (` search hit a comment ("No try/catch"), not a catch. Not a finding.
- Open-items ledger items 1–10 and D50–D69 are historical claims of later execution. This pass does not adopt them as verified.
- No exploit procedure, reproduction, or parameter is included. Cross-review should not add one.

## Files examined with no defect found in the portion read

- `CLAUDE.md` (router only; no production defect).
- `contracts/utils/LocalCreditLib.sol` (matches D11 in the functions read).
- `.claude/skills/indexedex-adversarial-testing/SKILL.md` and `.claude/skills/indexedex-testing/SKILL.md` (law text read; not a production defect review).
- `.claude/skills/crane-adversarial-testing/SKILL.md` and `.claude/skills/crane-testing/SKILL.md` (local mirrors; catalog text only).

## Files examined where a defect or contradiction was found

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol`
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol`
- `docs/audits/apex-2026-09-17-evidence.md`
- `docs/audits/apex-2026-09-17-evidence/acceptance.json`
- `docs/audits/apex-2026-09-17-followup-fixes.md` (claim only; not treated as proof)
