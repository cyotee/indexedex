# Astra — targeted requirements retry

## Answer

**Agree. No product-law question must still be asked of the human before implementing the current draft.** Implementation still requires the separate authorization specified by `REMEDIATION_PRD.md:7`; this review does not authorize it.

This is a fresh-session requirements check, not a resumed session, a new exploit review, or a claim to have obtained the other reviewers' original answers. The earlier Astra answer and peer conclusions were supplied as summaries. I checked the relevant claims against the current draft and source rather than treating those summaries as authority.

## Decisions and remaining implementation work

### Astra RQ-01 — RC-08 evidence fallback does not require an owner ruling

- **Disposition:** Agree with the supplied peer conclusion. The earlier Astra position, as supplied, left fallback approval as a possible human question. On the current text, I do not retain that objection. This correction does not rewrite the earlier record.
- **Severity / impact class:** Low underlying defect; diagnostic quality and regression-evidence adequacy, not a newly established backing loss.
- **Location:** `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:575-580`; draft RC-08, lines 177-185 and test row 237.
- **Fact / broken requirement:** The production backing comparison still uses an empty revert. RC-08 requires the same comparison to raise a named error carrying both compared values, with atomic rollback and no change to refunds.
- **Fix direction:** Implement that named-error correction. First seek an allowed supported-route regression. If that route cannot reach the branch without mocking the subject or writing its storage, document the attempted preconditions and use the expressly permitted focused assertion of the production check. Keep successful production-route controls. Do not substitute copied test-only logic for the production check, weaken the comparison, or label focused evidence as an end-to-end failure demonstration.
- **Inference:** RC-08's specific fallback qualifies the draft's general production-route/red-green language (lines 59, 226 and 241). It changes the evidence method, not economic behavior or the backing invariant. No additional completion gate or human approval is needed.
- **Unverified:** Whether an allowed production route actually reaches this branch, and the exact focused-test construction. Those remain implementer investigation and evidence obligations; no tests were run here. Failure to construct compliant evidence must be reported, not hidden with a mock or storage fabrication.
- **Confidence:** High on requirements interpretation; no claim of executed reachability.

### Astra RQ-02 — Already-booked aToken inclusion is mandatory

- **Disposition:** Agree; no new economic ruling.
- **Severity / impact class:** Medium underlying defect; inconsistent share valuation and potential dilution.
- **Location:** `AaveV3StataStandardExchangeCommon.sol:52-58` versus `ReceiptBackedERC4626Target.sol:183-198`; full paths are listed below. Draft RC-03, lines 105-111.
- **Fact / intended behavior:** The original remediation requirements explicitly say Stata counts already-booked local aToken at underlying-equivalent accounting value (`docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:249`); D45 at line 364 requires the common calculation across IERC4626, SE, SY and transition quotes.
- **Fact / broken invariant:** `_stataBacking` includes held Stata and booked underlying only; the shared adapter additionally includes the booked aToken-equivalent term. Package initialization registers the aToken when present (`AaveV3StataStandardExchangeDFPkg.sol:245-258`), and the full-set sync books registered balances (`BasicVaultCommon.sol:43-50`).
- **Fix direction:** Use common backing accounting including already-booked aToken. Do not choose exclusion, invent another balance, or reinterpret this as permission to retain new aToken input instead of `depositATokens`. Preserve receipt delivery limits, fees and reward forwarding. Supply the funded parity control required by RC-03.
- **Inference:** A nonzero booked aToken makes the valuation discrepancy material. Execution of that funded state is not verified in this session.
- **Confidence:** High.

### Other closed readings

| Item | Disposition and evidence |
| --- | --- |
| RC-01 rollback | **Agree.** Draft line 79 explicitly requires transaction rollback, including allowances, rather than `try`/`catch` cleanup and continuation. On success allowances return to zero; on revert they return to pre-transaction state. No new owner choice. |
| RC-05 structure | **Agree.** Draft lines 140-143 authorize deletion or reuse of the guarded helper while preserving installed selectors. The implementer chooses within those constraints. |
| RC-06 structure | **Agree.** Draft lines 153-156 authorize a truthful consumed-share return or removal of the unused return with callers updated; approval reset and short-delivery rollback remain mandatory. |
| Deployment scope | **Agree.** Owner follow-up at draft line 55 excludes existing deployments and makes corrected fresh deployments the release unit. Preserved Uniswap V3/V4 source must not supply new-deployment bytecode. No migration, live inventory or historical replay question remains. |

RC-02, RC-04 and RC-07 also specify the required behavior and bounded implementation choices in their acceptance criteria. I found no additional product-law fork in the current draft. RC-07's consumer inventory and the required regression tests are work to perform, not decisions to delegate back to the owner.

## Handoff and evidence limits

The coordinator may append this result to the participation/requirements record, particularly draft lines 5, 184 and 250. Preserve the historical first-pass position; record that this fresh-session check now agrees with the explicit RC-08 fallback. That is provenance maintenance, not a blocker or a request to change product law. I did not edit the PRD.

No source, tests, configuration or scripts were edited. No shell commands, tests, chain reads, deployments, delegation or external documentation queries were used. This was repository requirements interpretation, not a library/API documentation question. No supplied assignment path was missing. I did not reopen peer artifacts or re-audit the PDF and the draft's other historical inputs.

### Files examined without an additional defect identified in the examined scope

- `CLAUDE.md`.
- `docs/agent/SKILL_CATALOG.md`.
- `lib/crane/.claude/skills/crane-testing/SKILL.md`.
- `.claude/skills/indexedex-testing/SKILL.md`.
- `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` — entire draft; no blocking requirements gap identified.
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md` — relevant R14 and D45 passages.
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeDFPkg.sol:230-269` — examined registration; no additional defect identified.

### Source passages confirming existing requirements, not new findings

- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:490-599` — existing RC-08.
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:1-100` — existing RC-03.
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:145-224` — RC-03 comparison and synchronization.
- `contracts/vaults/basic/BasicVaultCommon.sol:1-60` — booking trace; existing RC-07 subtraction also visible, not newly reviewed as an exploit.

**Human questions still required: none.** Readiness of the requirements is not evidence that remediation is implemented, tested or secure.
