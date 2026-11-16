# Hyperplan orchestration checkpoint: Migration conformance

This is an orchestration checkpoint, not an executable work plan.

- Request: "We need to fix the current implementation from the plan in /Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md so it actually conforms with the plan."
- Workspace: /Users/cyotee/Projects/indexedex
- Mode: hyperplan; planning only. No product edits, tests, builds, installs, deployments, commits, or public actions.
- Original requirements: docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md, including sections 1.1-1.9 and section 11.
- Review input: docs/reviews/dtf-migration-plan-execution-20261114/REMEDIATION_PRD.md. Findings are claims to check, not replacement requirements.
- Team run: bf630f63-f4c0-424c-8a3c-46725fa3a352
- Roster: skeptic / unspecified-low / st_01a1da17; validator / unspecified-high / st_01a1da18; researcher / deep-low / st_01a1da19; architect / ultrabrain / st_01a1da1a; creative / artistry / st_01a1da1b.
- Current phase: owner selected externally calculated per-original credit; awaiting revised planner approval brief. No executable plan yet.
- Round 1 assignment: delivered to all five members through team mail.
- Round 1 findings received: all five; skeptic 7, validator 7, researcher 6, architect 6, creative 7. The shared condensed bundle is hyperplan-dtf-conformance-round1-20261114.md in this directory.
- Round 2: all five replies received and attacks routed by original finding. The researcher emitted a transport/terminal error after delivering its complete reply, then successfully resumed for round 3; no findings were inferred from silence.
- Round 3: all five replies received. Condensed complete rounds are in hyperplan-dtf-conformance-debate-20261114.json.
- Distillation: complete; hyperplan-dtf-conformance-insights-20261114.md is the planner input, not an executable plan. Creative6 was conceded; skeptic3's four-file-only delivery restriction failed original requirements and user direction. Other findings survived with their narrowed scope.
- Planner handoff: st_01a1da2f received the owner's clarification and explicit choice, "Pricing: Per-original calculated credit". The current boundary reuses ordinary Uniswap V4 DETF reserve machinery and loads externally calculated exact original credits, rather than implementing reserve-specific frozen pricing inside Migration. The earlier concrete reserve-composition question no longer blocks this plan. Delivery of the continuation message is pending in the task host; do not resend it. The planner must reconcile its draft and return the approval brief without repeating the debate. Plan-writing approval and implementation authorization remain absent.
- Cleanup: team bf630f63-f4c0-424c-8a3c-46725fa3a352 deleted successfully with force true after question delivery; zero active member tasks needed cancellation.

## Context that must not be lost

- The prior implementation was integrated into main at c33f70683cbaabfedc2dbce1142fdd65660d4cf3, with 24 linear commits from 90ff0307a7a8e084aa073e02eff125e9c7973933.
- Earlier completion reporting was too broad: missing delivered records, unresolved actual-composition quote closure, stale operator status and missing named adversarial base must not be hidden by passing aggregate tests.
- Retained local results are in /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/docs/incidents/2026-09-16-dtf-recovery/migration/. Existing recorded tests and gas runs may be reused when their scope and source identity match; do not assume they certify the whole plan.
- Current two-step local gas receipts exist: preparation 19746568/19595700 and final publication 29905302/29344006, each with a signed 32000000 envelope. They are not public target-chain receipts or universal batch-size proof.
- Do not restore zero direct-pair outputs: the old implementation already reverted on zero.
- Earlier NFT IDs below 3 are an unresolved source-occupancy question, not an established defect.
- TokenStaking preparation is allowed through claimed SY; do not invent an ERC20 raw-weight pull.
- Routine recovery retains matured old principal and NFTs while harvesting rewards repeatedly. Permanent custody requires concrete absence of an existing authorized recovery route, not just present disablement or one failed candidate.
- Do not silently exclude task-created files from eventual integration. The user's earlier instruction to stop auditor paperwork did not authorize omitting existing work. Preserve unrelated files.
- No executable plan was created by the interrupted ulw-plan turn; it read workflow references only.

## Round 1 researcher findings (condensed for forwarding)

1. Main omits substantive retained verification/source/recovery records required by original-plan tasks1/3/10. Comparing91 snapshot contents to main found86 matches,two absent recorder/verifier files,and three differing files: claimed-sy-member.ts,rehearsal-claimed-sy-intake.ts,operator-runbook.md. Reconcile exact versions; neither discard retained work nor attribute every old record to main.
2. SnapshotLib:45-47 rejects buffered DETF output;65-88 requires direct contribution-to-pair routes and recognized enabled-buffer deposit models;135-174 evaluates frozen inputs without live repricing. quote-evidence.md:6,165-167 establishes fixtures,not actual recovery composition. E3 needs actual configured-route closure,not arbitrary models or invented configuration.
3. Retained source-manifest has three null runtimeCodeHash fields and repeated proxy hashes without selector-to-facet bindings. Source-route matrix lacks exact selector/return schema,ownership/remaining-unit reads and fixture links required at original plan446-453. Underlying evidence may exist; incomplete summary is not proof of absent adapters.
4. RecoveryTarget:353-365 installs earlier/SE/weighted-LP/receipt conversions; retained recovery-route-disposition:9-17 records conditional permissions/income. This defeats blanket historical blocked-table readings,without authorizing public governance. Earlier physical LP has different owner-only immutable constraints at disposition19-31; independently verify them.
5. Actual signed32m local construction receipts exist: preparation19746568/19595700 and publication29905302/29344006. Historical44353454 is not current measured failure. Original plan542 still requires loading/issuance/harvest batch limits,not just two deployment arguments.
6. Retained hermetic/operator/fork results pass,including181forks,despite verification.md71 still saying forks pending. fullTask9='open' and stale RecoveryTarget comments must be reconciled to actual behavior; missing full53-row/E1-E5 reconciliation is the completion issue,not literals alone.
Limits: read-only,no tests/builds/RPC/Git commands/edits/subagents; no new production defect established and no rejected zero-output/ID-floor allegation reopened.

Lead verification so far: read SnapshotLib lines25-99 and confirmed raw-output/direct-pair admission restrictions; read retained source manifest and confirmed missing runtime hashes for weighted-nft,weighted-receipt,earlier-receipt and repeated common proxy hashes. These observations are not a full source-route or E3 verdict.

## Round 1 skeptic findings (condensed for forwarding)

1. Existing architecture should not be rebuilt: package,snapshot,claimed-SY loader and recovery stages already exist at c33f7068. Reject unjustified nested-quote frameworks,generic routers,new facets/adapters; allocation split already cites EIP-170.
2. Completion is not fixed by editing strings. F1-F6 are claims,not replacement requirements; quote-evidence6 refuses E3 and bundle31/execution98,185 hardcode open. Do not merely flip them or restore zero-output returns.
3. Integrate retained source-manifest,source-route-matrix,verification,recovery-route-disposition without inventing an evidence platform or fabricated surrender/package records. Retained verification names1694e68 plus uncommitted work; reconcile its source identity. Signed32m local measurements are not public target-chain receipts.
4. SnapshotLib21-23,45-47 bounds routing/output; allocation162 and source-matrix already use claimed-SY preparation. Do not invent quote models,financial data,or raw-weight pulls. Pin actual reserve or retain concrete E3 blocker.
5. tokenId<3 is not proven wrong until earlier occupancy is read. Do not remove it or invent exclusions merely from the weighted-only plan wording.
6. Existing separate reward/principal/combined stages and sole earlier-physical-LP permanent-custody disposition already exist. Synthetic rehearsal-data272 still selects WeightedClaim; change only if represented as routine policy,not by adding stages.
7. Missing named adversarial TestBase is not resolved by an empty alias or duplicate catalog. Existing hostile tests such as MigrationRecoveryAccrualRollback already cover some behavior.

Lead verification: rehearsal-data.ts255-275 does contain a synthetic WeightedClaim selection. However rehearsal-recovery.ts25-45 writes a fresh harvest selection and clears configuration arrays, and lines68-69/97-98 explicitly use WeightedRewards. Treat the fixture observation as conditional; it is not proof that the actual retention rehearsal consumes matured principal.

Further lead observations: execution.ts120-179 bounds simulation/estimate/buffer only for deploy and applies estimate*3/2 uncapped to other stages. execution-plan.ts60-62 chooses the NFT contribution loader only when separateContributions is true. ClaimVaultAllocationTarget15-78 supports both combined and separate configurations; schema36-48 makes separation optional. rehearsal-data147-160 omits weighted NFT3. These are candidates for adversarial refinement, not final design decisions.

Lead checked runbook840-861: historical getMaxTxGasLimit provenance already records32m. Phase_08_Stage_00_OperatorEnvironment.s.sol explicitly constructs synthetic infrastructure, new local WETH, a mintable rate fixture and two V3 buffers with30/30/40 weights; its real historical DTF input does not make the whole composition an approved operational selection. PRD composition search confirms weighted mint pricing and ETH/DTF funding but did not identify an approved concrete buffer/route binding.
