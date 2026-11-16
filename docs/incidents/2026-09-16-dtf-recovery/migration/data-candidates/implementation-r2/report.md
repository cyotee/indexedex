# Phase27 R2 stopped implementation report

Date: 2026-11-13. Status: **implemented and proved for offline, non-issuable historical review candidates**. This is the requested preparation increment, not all Migration implementation, historical eligibility approval, or a live loader dataset.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-27-data-candidates`.
HEAD remains `0856a5c56e5d09b81c669f59b613efef79133e19`; branch remains `work/dtf-migration-phase-27-data-candidates`. No commit was created.

## Delivered behavior and source boundary

The existing CLI now implements:

```sh
bun scripts/recovery/dtf-migration/cli.ts derive-candidates \
  --input "$COMPLETE_HISTORICAL_TREE" --output "$NEW_DIRECTORY"
```

It creates a versioned `candidates.json`, exclusively in a fresh directory. Its version is `dtf-historical-review-candidates-v1`; its status is `NON-ISSUABLE-REVIEW-CANDIDATES`. No RPC, signer, provider acquisition, chain refresh, live snapshot or execution environment is needed by this command. Signing/broadcast flags and ambiguous arguments reject.

The source changes are confined to the existing operator directory and existing runbook:

| Source | Responsibility |
| --- | --- |
| `candidate-input.ts` | Authenticate every manifest/source binding before raw-table parsing; regular-file/path checks; strict CSV and exact integer boundaries |
| `candidate-nfts.ts` | Weighted S006/S008/S011 joins and all earlier CP purchase observations |
| `candidate-inventory.ts` | Complete historical record census, typed quantities, account/source/position/exclusion/custody/recovery/conversion/index links and unresolved records |
| `candidate-proofs.ts` | Event-time staking indices, signed funding/claim gons, NFT snapshot conservation and same-unit account sums |
| `candidate-reconciliation.ts` | Supported reported-total checks and all sixteen source/provenance coverage rows |
| `candidates.ts` | Typed candidate document, canonical ordering, explicit input identities and exclusive offline publication |
| `candidates.test.ts`, `candidate-inventory.test.ts` | Nineteen new behavioral boundary tests |
| `cli.ts` | Narrow command dispatch and help addition |
| `migration/operator-runbook.md` | Offline invocation, interpretation, reproduction and remaining review/acquisition/funding steps |

Existing preparation, payload/hash, execution, journal, pricing and source-policy implementations were not edited. No Solidity, configuration, dependency, Foundry artifact or frozen input was changed. Final tracked diff and staged diff are retained; the latter is empty. The new files are uncommitted.

## Input recovery and preservation

The complete current main-checkout plan r5, PRD r22, provenance report, F1 requirements report, task brief, actual source indexes, raw tables/JSON and operator boundary were inspected. Authority copies and exact identities are retained under `authorities/` and `source-manifest.json`. Historical policy prose is not current authority.

Positive derivation used the explicitly supplied recovered tree:

```text
/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery
```

Both supplied recovery records were read completely. Independent checks found exactly one dated November 10 paragraph in each current Markdown. Removing only that paragraph and its following blank line reproduced the historical bytes exactly:

| Body | Removed bytes | Historical bytes | Historical SHA-256 |
| --- | ---: | ---: | --- |
| `LOSS_AND_RECOVERY_LEDGER.md` | 635 | 15308 | `8564764d3d2140b25a9de361c49606c2e4d3d53cc404309ccc00bb955f572f07` |
| `CUSTODY_AND_HARVEST.md` | 563 | 7357 | `0ddb0eb30523e26551dce653d3f3bfb2e439f7b0c83fe2c8c93aaf953d6f42cd` |

All **36 declarations across 27 unique paths** independently match their written raw lengths and hashes. `sources.json` is authenticated from the manifest before parsing its source declarations; every declared raw body, including Markdown, authenticates before any CSV is parsed. The supplied recovery/validation declarations agree independently.

These are **hash-authenticated recovered historical bodies, not located original captures**. No economic quantity was reconstructed or guessed. No hash was changed, no prose binding excluded, and no P1 artifact was recovered. The original manifest and current annotated primary files remain untouched.

The annotated primary tree is an actual negative CLI case in both proof lanes, exiting 1 on its historical Markdown binding mismatch. The original complete-tree failure is still valid. Original `implementation/` and `verification/` remain frozen failed-intake histories: their existing seals, manifests and every manifest entry still authenticate. Their identities are recorded in `preservation-audit.json`.

## Complete real-data result

The final accepted producer proof is `proof02/`, not `attempt04-output/` or `proof01/`. Those earlier outputs remain preserved and are identified below.

| Final canonical output | Identity |
| --- | --- |
| `proof02/full-a/candidates.json` | 16570240 bytes |
| SHA-256 | `76f56c067084e04931a335ceef45ee5725153db9a39fb1619c9eab78f46ed278` |
| `proof02/full-b/candidates.json` | Byte-identical repeated CLI derivation |
| `proof02/full-relocated/candidates.json` | Byte-identical, separate CWD and complete relocated raw tree |

The relocated tree preserves every original raw byte and manifest-relative path, including the pre-exploit sibling. Its complete raw inputs and identities remain under `proof02/raw-input-tree/` and `proof02/raw-input-identities.json`. It is an evidence archive, not a template presented as original capture. Canonical candidates contain source-derived cutoffs/relative paths, no workstation path, wall clock or random identity.

Independent proof code uses a different CSV decoder to compare every original row with its emitted historical fields and quantities. It checks every inventory/unresolved link and all NFT purchase inputs, not a sample. The executed first proof source is preserved as `prove-executed01.ts.txt`; final typed support is `prove.ts`. All commands and exit records are retained beside their complete stdout/stderr.

### NFT attribution

The final pipeline independently derives **43 weighted purchase rows, 43 unique purchase transactions and 43 matching mints**, with payer observations matching purchase recipients. There are **41 pre-incident and 2 post-incident** purchase observations. That classification approves or denies none.

Each weighted candidate retains chain/collection/token ID, purchase row/transaction, recipient/payer observations, mint and input locators, S006 corroboration, historical owner observation and principal basis. DTF/WETH input components stay separate exact native18 strings. Multiple direct transfers are summed only inside their asset and uniquely attributable purchase transaction. Sharing, mint, payer or corroboration conflicts hold attribution unresolved rather than allocating a full transaction total to each NFT/receiver.

Observed inbound zero is distinct from an unknown value and does not prove zero native cost, refunds or net contribution. Historical ownership does not prove current control. The 41 snapshot NFTs and 41 later held NFTs are different cohorts; the records retain the individual identities.

All **16 earlier CP NFT observations** retain original LP-accounting shares, direct DTF, direct WETH and routed intermediate DTF separately. CP NFT 3 therefore retains direct WETH `2000000000000000000`, direct DTF `0`, and routed DTF `1778859964387451305574664`; the routed amount is not added as a contribution. Original older raw receipts remain unavailable. No LP-accounting field is treated as physical fungible LP, funded principal or an approved contribution.

### Full inventory

All **18044 CSV records across 22 tables**, not merely the seven primary inventory tables, are preserved in the typed review census:

| Table | Records |
| --- | ---: |
| Pre-exploit purchase details / payer aggregate | 819 / 244 |
| Pre-exploit receipt holders / raw stakers / SY holders | 200 / 92 / 18 |
| Accounts / positions / held exclusions | 435 / 411 / 411 |
| Custody inventory / recoveries / conversions | 403 / 69 / 250 |
| Weighted screening / weighted purchases | 422 / 43 |
| Earlier CP purchases / wallets | 16 / 13 |
| Normalized transfers | 12191 |
| Bond accounting / post-incident claim proofs | 57 / 7 |
| Pre-incident / all-period index records | 847 / 1077 |
| Exceptions / rounding | 14 / 5 |

Account observations link to original payer/recipient/source rows without assigning a unique economic origin. Weighted and earlier-product records stay separate. Position/exclusion identities are one-to-one; account position/holding/recovery lists cannot duplicate or misattribute records. All referenced source IDs and exception IDs resolve. Recoveries link to exact recorded output transfers; conversions retain representation-change evidence, not another recovery or contribution. Index subsets reconcile, and duplicate event keys reject.

There are 527 explicit historical proof links: event-time amount/index gons, funding minus signed claim debits per snapshot NFT, seven later principal-plus-reward/gon/transfer checks, and same-unit weighted account sums. Signed `gons_delta` is preserved exactly; ordinary quantities remain unsigned. Unknown blanks remain null. Snapshot/current native balances do not become original Q0. Gons, raw weights, LP accounting, physical LP and native9/18/19/28 are not added together.

Seventeen supported reported totals match. Independent exact sums also reproduce:

| Historical diagnostic | Exact integer |
| --- | ---: |
| Weighted nominal DETF exposure | 2237832428068 |
| Held lower bound | 1674947599807 |
| Unresolved snapshot remainder | 562884828261 |
| Observed DTF outputs | 59027441289824656686224552 |

The first three remain historical native9-equivalent diagnostics; the last is DTF native18. None is an award. Other reported keys are explicitly listed as not recomputed rather than blindly approved.

### Coverage and unresolved work

All sixteen coverage rows remain: W-L, E-L, W-N, E-N, W-R, E-R, W-Y, T, C, E-S, W-SW, W-SD, E-P, W-P, ETH and WETH. Direct claim-vault, SE and physical LP user exposure is unobserved, not proven absent. WETH has 27 saved transfer-provenance observations; ETH/WETH are contribution/recovery provenance, not new compensated surrender routes.

Every one of the **1240 unresolved records** was inspected through its complete machine record and link validation. They are retained without suppression in both `candidates.json` and `proof02/unresolved-review.json`:

| Class | Records |
| --- | ---: |
| Independent basis unresolved | 435 |
| Original contribution unknown | 411 |
| Conversion origin unresolved | 250 |
| Recovery attribution unresolved | 69 |
| Aggregate/event-replay source reference | 34 |
| Missing original raw claim-event archive | 18 |
| Unknown earlier-product recovery count | 13 |
| Ten global coverage/policy/review qualifications | 10 |

The global qualifications cover missing original inputs/wallet review, partial claims/previous delivery, aliases/overlap, incomplete WETH/native/recovery history, stale state, earlier receipt supply discrepancy, missing CP receipts, unobserved accepted categories, historical-policy precedence and remaining acquisition/review/funded-snapshot steps. The receipt discrepancy remains `57880198310224980583` observed balances versus `57898677945502333609` reported supply. No gap is allocated.

Independent recipient observations deliberately contain null original economic origin, Q0, ETH/DTF basis and prior delivered credit. Historical zero-upfront fields do not become zero prior credit. No loss formula, nominal exposure or old bearer policy becomes an award. Current configured original-wallet/control requirements govern; complete intermediate-holder ancestry is not introduced as a surrender prerequisite.

## Verification and actual command exits

`command-index.json` contains exact executable, argv, CWD, exit code and full-stream paths for every recorded subprocess. `run.ts` subscribes to completion before collecting streams and waits for actual child exit. No running command is presented as a passing handoff.

Final gates, after the last operator source change:

```sh
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext \
  --moduleResolution Bundler --strict --noUncheckedIndexedAccess \
  --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck \
  --types node scripts/recovery/dtf-migration/*.ts \
  "$EVIDENCE/run.ts" "$EVIDENCE/prove.ts"

bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
```

`types-final03` exited **0**. The single final complete invocation after the final source freeze is `operator-tests-final02`: **128 pass, 0 fail, 13 files**, exit **0**, Bun **1.4.2**. This includes the existing 109 tests plus 19 new tests; the old baseline is not presented as feature proof.

The new tests cover exact multi-input NFT sums, shared transactions, payer conflicts, direct versus routed CP values, unknown/zero/malformed quantities, strict CSV, changed/missing raw bindings including prose, duplicate account attribution, missing links, source IDs, held partitions, index consistency, recovery event amounts, signed/event-time gons, unit separation and loader rejection.

The actual complete final candidate document is rejected by unchanged `prepare`, `validate` and default execution `verify` boundaries, each exit **1** before provider construction/signing. The primary annotated tree likewise exits **1**. All three positive final CLI derivations exit **0**, as does the independent proof. No unchanged Forge, Solidity, chain or full repository suite was replayed.

The test-junk pattern audit exited **0**, no findings. A separate optional no-excuse AST checker exited **2** before auditing because it requires `typescript/unstable/async` and `typescript/unstable/ast` APIs unavailable in the installed project TypeScript. No install, dependency change or suppression was used. The required real TypeScript gate passes. Native LSP requests also timed out; this is not represented as clean LSP evidence. Final `git diff --check` passes and the staged diff is empty.

Each new module owns one named responsibility, uses parsed file-boundary data rather than unchecked unknown objects, and introduces no `any`, type assertion, non-null assertion, error suppression, retries or economic fallback. New operator modules/tests remain below 200 nonblank/noncomment lines. Existing execution files were not refactored.

## Preserved attempts and corrections

No failed attempt was overwritten or deleted:

1. Initial displayed JSON contained tool elision and failed parsing before the binding loop. The full raw `read` path then authenticated both transformations and every declaration. Original tool records remain the operation history.
2. Initial module evaluation found `.extend` called on a readonly Zod wrapper. The raw binding object was corrected before the first CLI run.
3. `attempt01` exited 1 on a blank earlier-product recovery count. `debug01` retained its precise stack. Unknown recovery counts now remain unknown with explicit records, not zero.
4. `candidate-tests01` had 9 pass/1 fail because macOS's temporary directory has a symlinked ancestor. The test fixture now resolves its temporary parent; production symlink rejection was not loosened.
5. `attempt02` and `attempt03` exited 1 on the actual signed historical claim gons. The source-specific signed delta was parsed and conserved correctly; ordinary economic quantities were not made signed.
6. `attempt04` exited 0 and produced the first complete candidate. `candidate-tests02` passed all 19 focused tests.
7. `proof01` completed actual repeat/relocation/negative proofs. Temporary guard mutations then produced five intended focused failures for binding, sharing, payer, partition and index checks; all mutated guards were restored byte-for-byte. Mutation identities and restoration records remain.
8. `types-final` exited 2 on strict typing in evidence support, not operator source. Its exact executed support bytes remain in `prove-executed01.ts.txt`; explicit parsed path types and Buffer annotations fixed it. `types-final02` and the then-current complete 128-test run passed.
9. Final source review added missing account-to-payer/recipient/source observation links, without assigning economic origin. Earlier executed source bytes remain under `executed-source01/`. This justified a new full-data proof and final gate, rather than falsely reusing the earlier output hash.
10. `proof02`, `types-final03` and `operator-tests-final02` are the final accepted lane. Earlier positive outputs and all negative outputs/logs remain preserved. The optional AST audit incompatibility is retained, not hidden.

## Cleanup, remaining limits and stopped handoff

All 18 owned background terminal/monitor sessions have completed. All recorder/proof children exited before their parent completed. No operation, subagent, signer, Anvil, Forge, provider acquisition, public action or held09 work remains pending. Existing test wire fixtures are offline/local test infrastructure, not fresh chain evidence.

Only the two empty owned relocated-CWD directories were removed. Expected rejected output/checkpoint directories were never created. Test fixture cleanup completed. Raw relocation trees, complete positive/failed outputs, source histories and command streams are intentionally retained as evidence. Shared services, warm artifacts, dependencies and frozen histories are untouched. `cleanup.json` records actual cleanup and zero pending operations.

This increment does not close E-S implementation, broader TokenStaking claim conservation, disabled conversions, approved operational datasets, selected real reserve composition, target deployment feasibility or **45116678 > 32000000 gas**. P1 remains an unresolved historical preservation issue, not a current behavior defect. No missing P1 bytes were reconstructed.

Before operational loader preparation, separately authorized acquisition must fill missing originals/receipts/current-state coverage; independent review must reconcile exact original wallet, source units, contribution components, aliases, partial claims and previous delivery; actual recovery funding and a supported immutable mint-preview snapshot must then be established. These candidates do not authorize any of those actions and are not live loader inputs.

The scoped implementation and producer evidence are complete. Independent verification remains a separate role; this report does not claim that an R2 independent verifier has run. `manifest.json` binds the full stopped handoff and every retained evidence byte. `seal.json` is published last, after cleanup and all operations stop; it attests to this bounded offline deliverable only.
