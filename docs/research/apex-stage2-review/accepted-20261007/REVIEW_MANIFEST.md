# Stage 2 review manifest

Report state: `PARTIAL_REPORT`. Report delivered after the authorized independent and bounded cross-review waves; expanded inventory and detailed coverage limits remain explicit in REPORT.md.

## Owner decisions and permissions

On 2026-10-07 the owner explicitly confirmed Stage 1 complete and instructed execution of the Stage-2 plan, including reading source and writing the report. Acceptance and launch are established, not pending. The decision is permanently recorded in the controlling plan/PRD and Stage-1 evidence note. Ordinary read-only shell inspection, searches and content-identity inspection are permitted for this run. No builds, tests, simulations, RPC, deployments, production/test/config edits or remediation PRD are authorized.

The prior `launch-20261007T194845Z` report is preserved as a historical launch attempt; its missing-acceptance/read-permission blockers are resolved by the subsequent owner message. This run uses native collaboration, not the synchronous historical research council.

## Source identity and stability

- IndexedEx HEAD: `5709cb3507a9df72b11ec476d27b79ef88696c3a` plus existing Stage-1 working-tree changes and the explicit authorization notes.
- Crane HEAD: `b35609951b4951a3c107e267e22844a50c4dc043`; `git -C lib/crane status --short` returned no changes.
- Working-tree content identity: SHA-256 `379d2c49ead26ad701503c419ca486ddcd0ae9158e2d879f9f0720129c721439` over **15,552 files**. Each record is relative path + NUL + lowercase SHA-256(file bytes) + newline, sorted by relative path; the recorded identity hashes their UTF-8 concatenation.
- Scope: recursive regular files with extensions `.sol`, `.md`, `.py`, `.sh`, `.json`, `.toml`, `.pdf`, `.txt`, `.log` beneath `contracts`, `test`, `scripts`, `docs/audits`, `docs/plans`, `docs/agent`, `docs/reviews/apex-2026-09-17-second-audit-readiness`, `.claude/skills`, `lib/crane/contracts`, `lib/crane/.claude/skills`, excluding `__pycache__`; also existing `CLAUDE.md`, `foundry.toml`, `remappings.txt`, `lib/crane/AGENTS.md`, `lib/crane/foundry.toml`. This includes relevant untracked production/test files. It excludes evolving review outputs under `docs/research`.
- Stability arrangement: reviewers only read these inputs, write distinct reports, and notify the coordinator of observed source drift. Coordinator repeats the identical content calculation before delivery. This is a bound working-tree snapshot, not a claim of an immutable archive.
- Historical audited source and Stage-1 source remain separately labeled. The Stage-1 note identifies `5709cb35` plus uncommitted edits and explicitly says it is not a release identity. Acceptance does not manufacture missing artifact provenance.

## Required input references

- `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md`: source map, named repair runs and selector/size results.
- `selector-size-compare-stage1-current.json` in that directory: current supplied compare; earlier compare filenames are stale per note.
- Four `test_outsidePoolTradeDoesNotRefreshVaultBook` references: V3 `UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol`; hookless and Pons-family `AttributionAndBooking.t.sol`; wings `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol`. Exact test-root paths and assertions are reviewer A's responsibility.
- Original APEX PRD/plan, audit PDF, evidence/follow-up/open-item documents and current family laws are read as source evidence. OD-01–08, current family owner addenda and the recorded execution authorization govern conflicting older text.

## Assignment ownership before fan-out

| Assignment | Primary groups / original criteria | Supplements | Shared seams | Output |
| --- | --- | --- | --- | --- |
| A-vaults | C02–C05; all R3 | S2-ADD-005 four outside trades; S2-ADD-009 wings law; S2-ADD-010 split binding | Credit/refunds, receipt adapter, hook consumers, surface cuts; cooperate R13/R14 | `reviewers/A-vaults-original.md`, later `A-vaults-cross.md` |
| B-credit-lending | C06–C08; all R5, R7, R8, R9; R14.2–4 and family portions of R14 | S2-ADD-003 custody negatives/scanner; S2-ADD-006 receipt cap | All LocalCreditLib consumers, SE/SY books, capacity and prechecks, AMM/staking, facets | `reviewers/B-credit-lending-original.md`, later `B-credit-lending-cross.md` |
| C-hooks-matrix | C09–C11; all R6, R10; hook/Balancer portions of R14 | S2-ADD-004 matrix controls; S2-ADD-007 live rate | All seven hook families × current SE configurations/routes, rate/transition quotes, D41/D48/D49/D68/D69 | `reviewers/C-hooks-matrix-original.md`, later `C-hooks-matrix-cross.md` |
| D-coordinator | C01/C12/C13; all R1, R2, R4, R11, R12, R13; R14.1 and R14.5 onward with above cooperation | S2-ADD-001/002 residual semantics; S2-ADD-008 evidence/source map | DETF prepaid and residual consumers; release/campaign/source provenance; audit mapping | `reviewers/D-coordinator-original.md`, later `D-coordinator-cross.md` |

Every R1–R14 criterion has one primary owner as specified above; R14.2–4 belong to B, every other R14 criterion to D. Cross-family portions are explicit cooperation, not duplicate ownership. Each agent reads the full text of its assigned criteria and records individual dispositions. Matrix region primary ownership is C for all seven families and current configurations. Original baseline reconciliation and ledger preparation are maintained by the coordinator before substantive review results are adopted.

## Independence and concurrency protocol

Native collaboration permits four simultaneously active agents including the coordinator. A/B/C will perform substantive first-pass inspection concurrently. Task IDs, observed progress and completion events will be appended here. Prior review outputs under `docs/research/apex-stage2-review/` are excluded from every fresh first pass. No peer conclusions are shared before all four originals are frozen. A single later cross-review packet contains all four originals together; same reviewer sessions resume and write only their cross files.

No timestamps or provider identities are inferred. Source findings and evidence limitations are separate; preserved runtime logs are never rerun under this task.

## Observed execution and global freeze

- Native sessions: `/root/vaults`, `/root/credit_lending`, `/root/hooks_matrix`, coordinator `/root`. No model override, substitute session or external reviewer service was used.
- At 2026-10-07 20:00:17 UTC, all three child sessions and the coordinator were active in substantive source inspection. Contemporaneous updates described A tracing four vault books/outside-trade fixtures, B tracing custody/adapter/capacity paths, and C reconciling seven hook families and concrete matrix files. This is observed overlap, not a claim based only on simultaneous task registration.
- At 20:09:22 UTC A and C supplied further substantive inspection/drafting updates while B and D continued source review. C then completed its independent original; A completed next, D saved its own original before reading any peer original, and B explicitly confirmed its saved original complete with no further edits.
- Coordinator read A/C/B originals only after preserving D's original. No peer conclusions were delivered to any independent reviewer before the global barrier. Progress notifications were received but were not relayed as peer findings during first passes.
- Global original-set freeze: **2026-10-07 20:21:34 UTC**. All four assignments produced originals; no missing or failed session. They remain unchanged. Full originals, not summaries, are the common packet for one bounded same-session cross-review wave.

| Original | SHA-256 at global freeze |
| --- | --- |
| reviewers/A-vaults-original.md | `191534f040c3e5d9c3b4cfb5ab69da15cb36e118c638a732e25c4d09b2220b8d` |
| reviewers/B-credit-lending-original.md | `cef252fec0a04611a7f5052ebe5c5c31bd8c36d63a9c4cdfafbf30b308f78a4e` |
| reviewers/C-hooks-matrix-original.md | `385af7c166db03354ba80fc7a45e6a9d684776aab2509830a3e6b5c7f7e57951` |
| reviewers/D-coordinator-original.md | `70c7a53fbcaf8b140d5af9aa84182ce0d1ad4bf2792b979d0383e50a6ba60ae3` |

Cross-review packet for each A/B/C: all four frozen originals in `reviewers/`, plus cited source and controlling requirements. A owns cross-check of B's two code findings and D's residual/cut findings; B owns A's vault findings, D's manager/provenance findings and corrections to its own cooperative criterion mapping; C owns D's residual/size findings, B's hook/receipt seams and current matrix scope. Coordinator independently rechecks all material findings and coverage claims. Reviewers may challenge any original, but must not read peers' cross files or rewrite originals. Remaining uncorroborated breadth is explicit rather than filled with agreement.

## Collected cross reports and delivery reconciliation

All four same-session cross reports were collected in this single wave. Each preserves source citations, counterevidence and bounded corroboration. Originals were not changed; the four original SHA-256 values were rechecked and exactly matched the freeze table.

| Cross report | SHA-256 at collection |
| --- | --- |
| reviewers/A-vaults-cross.md | `0a090a33afe77fe593f2e13ebaac9cc1f8c80e6659e8b0be8a312386db5d457f` |
| reviewers/B-credit-lending-cross.md | `87da3639ff9566373b8840183c471dd623ce08b054625fe400330cba9929e5b2` |
| reviewers/C-hooks-matrix-cross.md | `7ddbe7487563899c2da1cbef711e9bb35680138b50db32fceac84f5f8cae969a` |
| reviewers/D-coordinator-cross.md | `13210d3d63f2dbbcae3784f8335bbd599c09808a1a5a50a66cf37dfe08d70391` |

The closing content calculation, collected at **2026-10-07 20:34:00 UTC**, returned **15,552 files** and the identical digest `379d2c49ead26ad701503c419ca486ddcd0ae9158e2d879f9f0720129c721439`. Only excluded review-output Markdown was written after that check. No reviewed-source drift was detected. Existing user source/test/tool changes remain untouched.

Final reconciliation: 108 original rows (83 INSPECTED, 25 PARTIAL; 49 MATCHES, 41 INDETERMINATE, 18 CONTRADICTS), ten supplemental rows, nine historical audit-item mappings. Twenty consolidated findings: 11 Medium, nine Low; four CODE_DEFECT, fourteen TEST_DEFICIENCY and two EVIDENCE_GAP. A-F04's Informational provenance observation merges into D-F02 with attribution retained. C-002 narrows to Low after tracing the earlier preview guard. D-X01 records the independently inspected Aave R14.7 test gap after B/C original numbering mistakes were corrected in cross-review.

Finite ordinary matrix: 217 records, consisting of 210 wrappers and seven external-BPT exclusions; 202 COMPATIBLE within stated route domains (including 21 control-role records), eight INCOMPATIBLE and seven DEPRECATED. Expanded Wings/H/P configurations, routes and economic states remain unresolved. This inventory limit and disclosed detailed partial criteria prevent INSPECTION_COMPLETE; missing current runtime alone is not the reason for the partial label.

All source modifications in the worktree predate this review. Stage2 wrote this report package and, before snapshot capture, the three owner-authorized acceptance/permission notes. No build/test/scanner/RPC execution, production/test/config edit, tool installation, remediation PRD, commit or deployment occurred. The final owner checkpoint is in REPORT.md §10; Stage1 acceptance is not among the questions.
