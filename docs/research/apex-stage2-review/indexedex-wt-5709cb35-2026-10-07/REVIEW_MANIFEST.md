# Stage 2 review manifest

Report state: `IN_PROGRESS`

Date: 2026-10-07

This run supersedes the launch attempt at `docs/research/apex-stage2-review/blocked-at-launch-2026-10-07/`. That earlier file is preserved. It is not a review result.

## Owner Stage-1 satisfaction reference

Recorded in the owner message of 2026-10-07, after the blocked launch:

> Yes, Stage 1 is completed. That's why I'm telling you start Stage 2. Write whatever record you need to satisfy yourself.

That sentence is the Stage-1 satisfaction record. It accepts `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md`, including the disclosed scanner limitation in that note. This review does not reopen Stage 1 and does not rerun its commands.

## Separate launch request reference

Same owner message, same date:

> start Stage 2
> Review only the Indexedex code in this effort, use the correct state of the repo, including uncommitted work.

The earlier message, "Please execute the plan in `docs/plans/APEX_STAGE2_REVIEW_PRD.plan.md`", is the plan-execution request. The later message supplies the missing satisfaction decision, the IndexedEx-only scope, and the working-tree snapshot instruction.

## Owner scope narrowing

Inspection targets are IndexedEx source, IndexedEx tests, and IndexedEx product documents. Crane is recorded as a dependency identity only. Crane contract bodies are not a review target. If an IndexedEx call site cannot be closed without reading Crane, the row stays limited to the IndexedEx call and is not converted into a Crane audit finding.

No builds, tests, forks, RPC calls, or code edits are authorized. Reviewer writes are Markdown under this run root only.

## Selected snapshot / IndexedEx / Crane / dirty-source identity

Owner instruction overrode the plan's no-git identity rule for this binding only. The coordinator ran read-only `git rev-parse`, `git status --porcelain`, `git submodule status`, `git diff --stat`, and `git log -1`. No content hashes of dirty files were computed. No build or test was run.

| Identity | Value |
| --- | --- |
| IndexedEx HEAD | `5709cb3507a9df72b11ec476d27b79ef88696c3a` |
| Branch | `feat/uniswap-v4-upper-lower-wings` |
| HEAD subject | Add the upper and lower Wings standard exchange vault and its measured records. |
| HEAD commit date | 2026-10-06 12:34:59 -0700 |
| Crane submodule | `b35609951b4951a3c107e267e22844a50c4dc043` at `lib/crane` (`heads/main`), matching the recorded gitlink |
| Review snapshot | That HEAD plus the dirty and untracked IndexedEx paths listed below, as present in the working tree when this manifest was written |
| What this is not | Not a content hash of uncommitted files. Not a claim that the tree stayed unchanged after this record. |

Dirty tracked paths at binding:

- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol`
- `contracts/test/bases/DETFFundedStakingArtifacts.sol`
- `contracts/test/bases/TestBase_ERC4626StandardExchange.sol`
- `contracts/test/stubs/ApexD48QuoteReplyFixture.sol`
- `contracts/test/stubs/ReentrantERC20Harness.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_ProdSe.sol`
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeDFPkg.sol`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacet.sol`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchange_Component_FactoryService.sol`
- `contracts/vaults/standard/erc4626/IERC4626StandardExchangeDFPkg.sol`
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol`
- `docs/audits/apex-2026-09-17-evidence/bare-expectrevert.txt`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/CLARIFYING_QUESTIONS.md`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`
- `scripts/apex_bare_expectrevert_scan.sh`
- `scripts/r12_selector_size_compare.py`
- `scripts/test_r12_selector_size_compare.py`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol`
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol`
- `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol`
- `test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol`
- `test/foundry/spec/vaults/standard/erc4626/behaviors/ReceiptBackedERC4626_CrossInterface.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_RateProvider.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol`

Untracked paths that are in-scope evidence or Stage-1 outputs, not review targets to rewrite:

- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacetExt.sol`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTargetExt.sol`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/selector-size-compare-stage1-current.json`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/selector-size-compare-stage1-post-split.json`
- `docs/reviews/apex-2026-09-17-second-audit-readiness/selector-size-compare-stage1.json`

Other untracked documentation under `docs/plans/` and `docs/research/apex-stage2-*` is review-program paperwork. It is not production source.

Diff stat at binding: 37 tracked files, 804 insertions, 277 deletions. Nothing staged.

Historical audited source, Stage-1 note identity, and this review snapshot are the same HEAD citation (`5709cb35`) plus uncommitted stage-1 edits. The Stage-1 note itself says that citation is not a release identity. This manifest does not upgrade it into one.

## Evidence manifest and authority-document versions

| Input | Path | Version note |
| --- | --- | --- |
| Stage 2 PRD | `docs/plans/APEX_STAGE2_REVIEW_PRD.md` | Untracked draft, 2026-10-07. Controls this review where the plan conflicts. |
| Stage 2 plan | `docs/plans/APEX_STAGE2_REVIEW_PRD.plan.md` | Untracked, 2026-10-07. |
| Stage-1 PRD | `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` | Dirty relative to HEAD. OD-01–OD-08. OD-08 controls listed older text. |
| Stage-1 plan | `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.plan.md` | Untracked. |
| Stage-1 evidence | `docs/reviews/apex-2026-09-17-second-audit-readiness/STAGE1_EVIDENCE.md` | Untracked. Owner accepted as Stage-1 completion. |
| Original APEX PRD | `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md` | Not re-hashed. |
| Original APEX plan | `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` | Source of the 108-ID baseline. Inventory not yet copied into the ledger. |
| Router | `CLAUDE.md` | Read at launch. DETF alignment and funded-staking documents govern DETF naming. Slipstream SE is deprecated. |

Family-document versions for wings and other products are assigned to the lanes that must read them. They are not pre-judged here.

## Stage-1 note and four outside-trade test references

From `STAGE1_EVIDENCE.md`, accepted by the owner, not rerun:

| Vault | Test | Cited file |
| --- | --- | --- |
| V3 FullSpread | `test_outsidePoolTradeDoesNotRefreshVaultBook` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol` |
| V4 hookless FullSpread | same name | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol` |
| V4 Pons-family FullSpread | same name | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol` |
| Wings | same name | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol` |

`UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol` remains a local-reserve supplement. It is not the outside-trade proof.

## Stage-1 source-map / build / selector / size / regression evidence

Present as the accepted note plus `selector-size-compare-stage1-current.json`. Not opened for recomputation and not rerun. The note's narrative lists custody, receipt-cap, rate-provider, residual, outside-trade, and rounding runs as passed. Toolchain versions are only those the note reports. No matrix count is inherited.

## Authorized coordinator mechanism / actual limits / write root

- Coordinator: this Sisyphus session.
- Write root: `docs/research/apex-stage2-review/indexedex-wt-5709cb35-2026-10-07/`.
- Delegation mechanism: session `task` tool, `run_in_background=true`, independent subagents. Overlap is real only when substantive review tasks are in flight together. Discovery tasks are not S2-AC-02 evidence.
- Exact concurrency ceiling: not published by the runtime and not invented.
- Research council and review council are not the executor.
- S2-AC-02 is not yet satisfied.

## Assignments

First-pass originals were requested together after ledger skeletons existed. No reviewer was given another reviewer's output. Session IDs below are the ones the runtime returned at launch. Missing session IDs are recorded as not returned, not invented.

| assignment_id | primary coverage | task id | session | original path | cross path | state |
| --- | --- | --- | --- | --- | --- | --- |
| C02 | V3 FullSpread, R3, V3 outside-trade | bg_ecfc1ffd | ses_ee93e3e3cffexCETtAvcaJAAdt | reviewers/C02-v3-original.md | reviewers/C02-v3-cross.md | collected; not frozen |
| C03 | V4 hookless FullSpread | bg_7b3d0456 | ses_ee93e2459ffe8sh0oMgsj0FPiQ | reviewers/C03-hookless-original.md | reviewers/C03-hookless-cross.md | collected; not frozen |
| C04 | V4 Pons-family FullSpread | bg_82b9599e | ses_ee93e1344ffeDWTDAjyaGYyHis | reviewers/C04-pons-original.md | reviewers/C04-pons-cross.md | collected; not frozen |
| C05 | Wings | bg_aae615c8 | ses_ee93dff29ffeJ47q6rbymuO6F0 | reviewers/C05-wings-original.md | reviewers/C05-wings-cross.md | collected; not frozen |
| C06 | LocalCreditLib and RebasingAware custody | bg_216092b1 | ses_ee93de787ffeHFuOsRl7gOjvFi | reviewers/C06-credit-custody-original.md | reviewers/C06-credit-custody-cross.md | collected; not frozen |
| C07 | Receipt, ERC-4626, Morpho, Stata, Aave loop | bg_33f782af queued-timeout; replacement bg_619b5add | replacement session not returned at launch | reviewers/C07-receipt-lending-original.md | reviewers/C07-receipt-lending-cross.md | replacement requested; not continuity |
| C09-C10 | Seven hook families and matrix behaviors | bg_d3b6d2ca queued-timeout; replacement bg_08efa740 | replacement session not returned at launch | reviewers/C09-C10-hooks-matrix-original.md | reviewers/C09-C10-hooks-matrix-cross.md | replacement requested; not continuity |
| C11-C12 | Balancer rate provider and DETF residual accounting | bg_b9d54a7d queued-timeout; replacement bg_e734e1d6 | replacement session not returned at launch | reviewers/C11-C12-balancer-detf-original.md | reviewers/C11-C12-balancer-detf-cross.md | replacement requested; not continuity |
| C01 | Provenance, R1/R4, residuals | bg_4924edaa queued-timeout; replacement bg_2568d318 | replacement session not returned at launch | reviewers/C01-provenance-original.md | reviewers/C01-provenance-cross.md | replacement requested; not continuity |
| C08 | V2, Camelot, Aerodrome, Lido, Rocket, EtherFi; Slipstream deprecated | bg_9e53e0af queued-timeout; replacement bg_555a0a62 | replacement session not returned at launch | reviewers/C08-amm-staking-original.md | reviewers/C08-amm-staking-cross.md | replacement requested; not continuity |
| C13 | Release, selector/size evidence, fuzz claims | bg_60b07bfb queued-timeout; replacement bg_a7765ff6 | replacement session not returned at launch | reviewers/C13-release-original.md | reviewers/C13-release-cross.md | replacement requested; not continuity |

Shared seams: credit helper versus family books (C06 with C02–C05, C07, C09); outside-trade tests are per vault and must not be substituted; rate provider versus DETF residual (C11-C12); matrix hosts versus hook targets (C09-C10 with C02–C04).

## Concurrency events

| assignment_id | event | limitation |
| --- | --- | --- |
| discovery-criteria | background explore `bg_7e0fe8b5`, session `ses_ee951e35fffecFLqLPstB1dL92` | Inventory only. Not a first-pass review. |
| discovery-paths | background explore `bg_a7eb1efc`, session `ses_ee951c1a1ffeCNgI5zwKm605mb` | Path discovery only. Not a first-pass review. |
| C02–C07, C09–C12 | Eight `task` calls with `run_in_background=true` issued in one coordinator turn | Request batching is not yet proof of overlapping execution. Completion notices will be the overlap evidence. |
| C01, C08, C13 | Follow-up batch issued while the first eight were still pending, before any original was read by the coordinator | Same limitation. These prompts did not include peer findings. |

S2-AC-02 is partly evidenced, not closed. When C02 completed, the runtime reported 10 other tasks still in progress, including C03, C04, C05, and C06. When C03 completed, 9 remained in progress. That is observed overlap, not a full-wave completion record. No timestamps were invented.

Queue timeouts, recorded after the owner said to return to the plan: `bg_33f782af`, `bg_d3b6d2ca`, `bg_b9d54a7d`, `bg_4924edaa`, `bg_9e53e0af`, and `bg_60b07bfb` died while queued and wrote no original. Replacements `bg_619b5add`, `bg_08efa740`, `bg_e734e1d6`, `bg_2568d318`, `bg_555a0a62`, and `bg_a7765ff6` are new sessions. They were not given C02 or C03 findings.

## Original freeze index

Not frozen. Global barrier is still open. Collected originals stay at their assigned paths and will not be revised into cross-review files until every scheduled first pass is collected or recorded failed.

| assignment_id | preserved path | complete/missing | cross-review packet |
| --- | --- | --- | --- |
| C02 | reviewers/C02-v3-original.md | collected, substantive | not released |
| C03 | reviewers/C03-hookless-original.md | collected, substantive | not released |
| C04 | reviewers/C04-pons-original.md | collected after C03; substantive | not released |
| C05 | reviewers/C05-wings-original.md | collected after C03; substantive | not released |
| C06 | reviewers/C06-credit-custody-original.md | collected after C03; substantive | not released |
| C01, C07, C08, C09-C10, C11-C12, C13 | assigned paths | first attempt queued-timeout; replacement in flight | not released |

## Incidents, source drift and owner decisions

| Event | Evidence | Affected rows | Required action | Disposition |
| --- | --- | --- | --- | --- |
| Owner recorded Stage-1 satisfaction and ordered Stage 2 | Message quoted above | Launch gate | Proceed to preparation | Cleared |
| Owner narrowed review to IndexedEx code and the dirty working tree | Same message | All lanes | Do not audit Crane bodies. Inspect working-tree IndexedEx files. | Controlling for this run |
| Identity captured with read-only git because the owner required the uncommitted tree | Commands listed above | Snapshot | Do not treat HEAD as the whole snapshot. Do not invent dirty-file hashes. | Bound |
| Earlier launch block | `blocked-at-launch-2026-10-07/REVIEW_MANIFEST.md` | Historical | Leave intact | Superseded, not deleted |
| Editor diagnostic on a dirty matrix test, not a Stage-2 run | While writing this manifest, the editor reported undeclared-identifier errors in `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol` at lines 293, 303, and 311 (`fx` suggested). No `forge` command was run. | Matrix / orbital lane | Assigned reviewer inspects the working-tree file. Do not treat the editor note as a passing or failing test. | Open for the matrix assignment |
| Six first passes died in the queue | Task ids listed in the concurrency section. No originals from those ids. | C01, C07, C08, C09-C10, C11-C12, C13 | Owner authorized return to the plan. New sessions launched. Not treated as continuity. | Replacement batch in flight |

## Source-drift handling

Reviewers read the working tree identified above. If a later read shows an in-scope IndexedEx file changed after this binding, record the path and invalidate only the affected conclusion. Do not mix snapshots. Do not recompute hashes.
