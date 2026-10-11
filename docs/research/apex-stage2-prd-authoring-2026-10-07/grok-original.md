# Grok — Stage 2 review PRD recommendations

Independent recommendations for the moderator’s `docs/plans/APEX_STAGE2_REVIEW_PRD.md`. Not that PRD. Inspection-only. No peer artifacts.

## Outcome

Stage 2 reopens the locked APEX acceptance program on one identified current tree, including changed and new vaults, and stops at a coordinated report. It does not fix code, run tests, author tests, edit config, deploy, or emit a remediation PRD. Audit submission stays blocked. Giving an auditor open source is not acceptance (`REMEDIATION_PRD.md:18-22`, `:160-162`).

## Launch gate

Two recorded owner acts, neither implied by this note: satisfaction with Stage 1, and a separate launch that names a future coordinator able to run the lanes below concurrently. Today’s research council and `/review-council` are not that coordinator. Review-council sends the same target to four reviewers; synchronous calls may be sequential; `task` is limited to those four; shell, test edits, and background are denied (`REVIEW_COUNCIL.md:57-62`, `:102-106`). Do not silently replace real concurrency with that roster. Do not edit config to create the coordinator. If no capable coordinator is authorized, Stage 2 does not start.

## What reviewers may do

Read the snapshot, locked plan R1–R14, OD-01–OD-08, and cited tests. OD-08 controls older OD-01, OD-04, and OD-06 sentences (`REMEDIATION_PRD.md:179-186`). Reconcile each criterion to current files. Count the current hook × SE matrix from files; do not adopt 195/1/7 or 165/3/7 (`:316-320`). Apply catalog A–K and A0/L/M/N/O only where the surface exists (`.claude/skills/indexedex-adversarial-testing/SKILL.md:146-174`). No forge, RPC, fork, fuzz, campaigns, or new tests. Missing execution blocks readiness and is not a code defect (`apex-2026-09-17-remediation-and-regression-tests.plan.md:244-245`, `:568-573`).

## Coverage lanes

Assign every lane a disjoint file set and the same snapshot. Cross-family rules (D15, D34, D37, LocalCreditLib) are a coordinator merge, not a reason to drop a lane. One variant does not prove another.

| Lane | Close by inspection | Do not treat as a new defect |
| --- | --- | --- |
| L0 Provenance | R1 identity: revision, dirty paths, old vs current FullSpread names | September green counts |
| L1 Credit core | `LocalCreditLib` vs D11; consumer inventory still open (`plan.md:101`, `:172`) | Library match closing 003/008/009/004B |
| L2 FullSpread V3 | Current U3 tree vs R3/D15/D17; outside-trade test present and aimed | Stored-total red cases; preserved `contracts/protocols/dexes/uniswap/v3/` edits |
| L3 V4 hookless | `fullSpread/hookless/`; not the old single Common path (`REMEDIATION_PRD.md:145-151`) | Merging packages |
| L4 V4 Pons-family | Separate package, fees, protection, registration | Wings-to-Pons binding (`:153`) |
| L5 Wings | `upperLowerWings/` against its own accounting; preferred, not a FullSpread substitute | Using wings to close L2–L4 |
| L6 Custody | CU public-share path; cited adversarial tests must reach the named check (`:222-234`) | Weakening the EOA guard |
| L7 Receipt adapter | `maxRedeem` / `maxWithdraw` vs OD-03 (`:112-129`) | Virtual-share port |
| L8 ERC-4626, Morpho, Stata, Aave loop | R7/R8/R14; D32 true-flag reject stays reject (`plan.md:106`) | New public sweep |
| L9 Lido, Rocket, EtherFi | D34/D46 catch and precheck sites | Fixture gaps counted as production fixes |
| L10 V2, Camelot, Aerodrome | D15/D28/D37 on those SEs | Slipstream rewrite; D57 is a residual (`REMEDIATION_PRD.md:79`) |
| L11 Balancer SE and rate providers | D48 length rule; empty-state `quoteState` gas branch absent after Stage 1 (`:291-304`) | Deleting caller-supplied `quoteRate` |
| L12 Seven SE buffer hooks | Orbital, weighted, curve quad, Balancer quad, single-CP, dual-CP, non-CP `single/` (`plan.md:222-234`) | Non-SE hooks outside D16; catch-all row marked COMPATIBLE |
| L13 DETF prepaid | Uni V4 DETF, single, multi-vault, mixed-buffer, composed/rebasing, bond prepaid pull, sDETF (`plan.md:182`) | Vesting, thresholds; `supportsInterface` probe (`REMEDIATION_PRD.md:203`) |
| L14 Matrix ledger | Current files vs D20/D26; INCOMPATIBLE rows stay incompatible, including standalone Balancer adapter (`plan.md:224`) | A recount that was not read from current tests |
| L15 Law and residuals | R13 NatSpec; D12 `UNSUPPORTED_USE`; immutable chain-4663 inventory as documentary only | Migration, D12 removal |

Stage 1 REQ-01–REQ-08 are checked as already specified work. If still open on the snapshot, mark `STAGE1_OPEN`, not a newly discovered program gap.

## Row schema

`criterion_id`, `od_override`, `lane`, `snapshot`, `path:line` or `ABSENT`, `cited_test` or `ABSENT`, `disposition`, `severity`, `impact_class`, `fix_direction`, `confidence`, `blocks_readiness`.

Dispositions: `CONFIRMED_MISMATCH` (source or cited test contradicts the locked property or a later OD); `STAGE1_OPEN`; `UNVERIFIED` (not run, or inspection cannot see the runtime result); `RESIDUAL`; `UNDECIDED`; `NOT_APPLICABLE` with reason; `INSPECTION_MATCH` (text matches; not a green run).

Report every mismatch severity. No Low filter. `fix_direction` names the property to restore, never an exploit procedure, payload, or attack parameter (`REMEDIATION_PRD.md:175`).

`blocks_readiness` is true for any `CONFIRMED_MISMATCH`, `STAGE1_OPEN`, or required-execution `UNVERIFIED` (R2 red/green, R11 campaigns, R12 build/selector/size/hermetic run, historical fork when the criterion requires it). It is false for `RESIDUAL`, `UNDECIDED`, and `NOT_APPLICABLE`. `INSPECTION_MATCH` does not clear an execution criterion.

## Report acceptance

The review is complete only when every R-id and every L2–L5 variant has a row, disagreements are preserved, and the header says inspection is not OD-07 proof (`REMEDIATION_PRD.md:166-177`). Zero mismatches is not submission permission. Stop for the owner either way.

A later remediation PRD is a new request after that discussion. Its only default input is `CONFIRMED_MISMATCH`, plus any `STAGE1_OPEN` the owner chooses to restate. `UNVERIFIED` stays a readiness blocker, not automatic repair scope.

## Pitfalls

Do not file the hookless/Pons split as unauthorized. Do not revive stored-total cases or old-source red runs (`:136-141`). Do not let `LocalCreditLib` close consumer families. Do not mark a matrix row COMPATIBLE on a catch-all revert. Do not carry Stage 1 evidence onto a different dirty tree (`REMEDIATION_PRD.plan.md:93-95`). Do not call serialized four-reviewer passes “the parallel lanes.” Shared read-only lanes need no `out/` lock; inventing a build race is out of scope because this stage does not build.
