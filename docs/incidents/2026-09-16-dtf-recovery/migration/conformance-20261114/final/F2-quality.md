# F2 code quality review

Date: 2026-11-15. Disposition: **NOT-APPROVE**.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
Plan: `/Users/cyotee/Projects/indexedex/.omo/plans/dtf-migration-conformance-remediation-20261114.md`.
Reviewed baseline: `c33f7068` (`Complete Migration recovery, claim intake, and bounded deployment`) plus the delivered dirty and untracked source changes.

Two new findings require correction. Neither is the already recorded claimed-SY witness-pin mismatch or the absence of task-10 receipts. Findings below are established by source tracing; no reproduction, test, build, RPC call or public transaction was run in this review.

## New blockers

### F2-01 / P1: A later SY configuration invalidates an immutable historical manifest

Locations:

- `scripts/recovery/dtf-migration/preparation.ts:223-249,253-270`
- `scripts/recovery/dtf-migration/execution-domain.ts:163-180`
- `scripts/recovery/dtf-migration/quotes.ts:241-249`
- `scripts/recovery/dtf-migration/claimed-sy.ts:108-126`
- Entry and downstream effects: `scripts/recovery/dtf-migration/execution.ts:113-128`.

`validateAcceptedRows` opens each retained/replaced row's original execution context. `acceptedContext` calls `loadExecution`, which calls `validateManifest` on that original prepared manifest. `validatePrepared` then invokes `quoteOriginals(..., "evidence")`. Although that mode correctly avoids regenerating prices, `quoteOriginals` calls `authenticateClaimedSy` before returning. That function queries all SY configurations from deployment through `"latest"` and requires every observed origin to be present in the manifest currently being authenticated.

Consequently, current census completeness is imposed on immutable historical context A, rather than only on the complete current context B. A valid progression fails:

1. Prepare and configure claimed-SY original X under A. A contains X.
2. Prepare B retaining X through its accepted A reference and adding distinct SY original Y. Before Y is configured, both current and historical census checks pass.
3. Configure Y successfully.
4. Reload B for verification, activation, resume or another replacement. B contains both X and Y, but recursive authentication of A encounters Y's later configuration event and throws `previously configured SY origin omitted from complete census`.

This fails before receipt reconciliation or current B verification. Adding Y to A is not a valid recovery: it changes the historical preparation and signed journal preimage. The same issue can affect a historical configure/issuance context that contains a claimed-SY row even when the accepted row being verified belongs to another category.

This contradicts the plan's separate historical/current verification contracts at lines 244, 253-258 and 263, together with task 7 at lines 442-445. The requirement to census all current SY originals from deployment remains necessary; it does not make future configurations part of an earlier immutable manifest.

Requested correction: distinguish historical source/receipt authentication from current complete-census validation. Authenticate A against its own appropriate historical boundary and preserve its exact bytes; enforce the full deployment-to-current census against B. Keep member signatures, fixed source/facet identities, measured units, duplicate-origin checks and current census completeness. Add a case where a current complete manifest retains claimed-SY X through A, successfully adds Y, and can then verify/resume/activate without rewriting A. Also retain the negative case where the current manifest actually omits X.

### F2-02 / P2: Required-original-field tests have an unrelated guaranteed failure

Locations:

- `scripts/recovery/dtf-migration/claim-vault.test.ts:15-19`
- `scripts/recovery/dtf-migration/dtf-custody-se.test.ts:15-19`
- `scripts/recovery/dtf-migration/weighted-liquid.test.ts:15-19`
- `scripts/recovery/dtf-migration/weighted-sy.test.ts:136-140`
- Required row pricing: `scripts/recovery/dtf-migration/schema.ts:100,156-159,180-184`.

Each loop removes one of seven original fields and creates its replacement row with only `original` and `proof`. The v2 schema now requires `pricing` on every such row. All 28 omission assertions therefore have an independent reason to return `success:false`, even if the corresponding original-field requirement is accidentally removed.

The existing tests previously exercised omission of the named field; introducing mandatory pricing without carrying the valid fixture's pricing into these negative inputs weakens that coverage. The loops assert only a boolean, so the retained passing operator log cannot reveal the wrong rejection reason. This finding does not claim that production validation currently accepts those malformed originals.

Requested correction: preserve the complete valid row, including its pricing directive, and remove only the intended original field. Check the resulting issue path/reason and include a valid control, so restoring the omitted field makes that candidate valid and weakening its validator is detected. Preserve the other source/provenance assertions and the unchanged witness-pin test.

## F2 mechanism coverage

Paths abbreviated below use `M = contracts/vaults/detf/protocols/dexes/uniswap/v4/migration` and `S = scripts/recovery/dtf-migration`.

| Required area | Source assessment |
| --- | --- |
| ABI and tuple | `M/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol:8-39` follows the required Leg/Inputs/Book order. The existing deposit tuple and enum encodings are retained from `contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol:6-25`. `M/interfaces/IUniswapV4DetfMigration.sol:700-772` exposes the setter and twelve array-plus-final-book-ID loaders. No stale one-argument overload was found in the two implementing targets. |
| Book/configuration preimages | The setter constructs the instance-bound v2 envelope with zero ID and hashes `abi.encode(string, Book)` at `M/UniswapV4DetfMigrationAllocationTarget.sol:44-56`. `S/quotes.ts:37-54` uses the getter tuple, zeros its ID and checks canonical encoding. `S/execution-domain.ts:112-120` derives the same setter ID. `S/payloads.ts:44-57` retains per-row book IDs, the claimed-SY nested tuple and the NFT separate-contribution boolean. |
| Canonical math and branch distinctions | `M/UniswapV4DetfMigrationWeightedPricingLib.sol:18-145` validates roles, modes, inactive operands and decimal scales, derives rated balances, and reuses Weighted fee/rate/scaling, frozen V3 evaluation, Claim budget/raw output and the live gross split. RawRate floors the incoming rate product before scaling; DisabledBuffer rates held SE inventory but not incoming raw units. The output is restricted to Raw/RawRate and uses the canonical raw inventory cap. Supporting implementations were read at Weighted math lines 48-68 and 99-105, Claim library lines 63-90 and 150-185, `StandardExchangeFrozenQuoteLib.sol:39-55`, and `DETFMintSplitLib.sol:18-25`. No parallel evaluator, editable output-credit alias or live pricing dependency was found. |
| All loader guards | Allocation target lines 59-62, 152-155, 166-169 and 219-222; claim-vault allocation target lines 15-24, 79-82, 108-111, 164-167, 196-199, 236-239 and 277-280. Every loader obtains `_weightedPricing(expectedBookId_)` after administration/reentrancy guards and before quotation, origin clearing or writes, including empty batches and both NFT entrypoints. The shared comparison is in `M/UniswapV4DetfMigrationRepo.sol:76-89`. |
| Stable originals and immutable issuance | `M/legacy/MigrationLegacyNftLib.sol:20-24` and `S/payloads.ts:65-67` exclude pricing from NFT origin identity. The configuration/issued-original collision maps remain checked in both allocation targets. Allocation target lines 69-98 replace configuration without changing the separate issuance record; lines 105-147 reject a second issuance and retain issued originals. Stored-credit surrender remains in the renamed retained target, with measured custody and original-wallet checks. |
| Actual removal and artifact rename | The two allocation facets declare eight selectors each, and allocation target lines 267-302 remove the actual owning facets' sixteen administration selectors and clear allocation-interface support. There is no pricing-readiness condition in activation. The retained weighted facet declares the new getter and 28 retained functions. Package cuts consume actual `facetFuncs()` at `M/UniswapV4DetfMigrationDFPkg.sol:230-237`. The renamed facet is deployed at `M/TestBase_UniswapV4DetfMigration.sol:253`, with name-derived artifact and release salt in the component factory at lines 15-20. Active Solidity/operator searches found no old capture/getter/target/facet references in the searched production and caller paths. |
| Per-record proofs and B configuration/A issuance | `S/preparation.ts:223-250` reassembles saved payloads rather than calling current-price preparation. `S/execution-domain.ts:163-209` reconstructs original execution/preparation/journal domains and checks signed operations. `S/execution-rpc.ts:13-38` checks canonical transaction order and complete ordered logs; lines 127-172 provide transaction-prefix reads. `S/execution-state.ts:69-75,285-353` compares exact configured records and their stored components; lines 388-408 compare current B separately from authenticated A issuance. `S/execution-owner-bond.ts:27-73` checks continuing bond principal, claims and escrow solvency. F2-01 prevents these mechanisms from completing for the described growing claimed-SY census. No direct comparison of A issuance credit with B configuration credit was found. |
| Source and authority boundaries | The setter uses only current-owner, Stage 1 and idle-child authority. `S/claimed-sy-member.ts:47-153` retains signed member, fixed source/facet, transaction-local routing and economic-effect authentication. `S/claimed-sy-witness.ts:11` retains the fixed pin. `S/provenance.ts:64-139` preserves full reviewed-original comparison and rejects stripping a claimed-origin certificate. `S/execution-plan.ts:28-48` preserves donation-specific operation IDs. `S/execution-rpc.ts:68-119` retains explicit local/public execution checks; CLI default execution remains read-only. No source-authentication bypass was found in these reviewed changes. |

The pricing/storage rename leaves the pricing bytes in their original storage position. No shared canonical pricing primitive was changed in the delivered diff. Representative real-proxy tests for stale empty loaders, stable collisions, immutable issuance, post-purchase setter use and actual selector removal were inspected in `MigrationWeightedPricing.t.sol:191-335`; they were not rerun.

## Existing diagnostics and freshness

`GIT_MASTER=1 git diff --check`, run in the review worktree, exited 0 with no output. It checks the tracked diff; the new source files were separately included in source inspection. No staging or Git mutation occurred.

The 114 added or modified `.sol`, `.ts` and `.py` files selected from the tracked contracts/scripts/test changes and untracked source inventory all match their raw SHA-256 entries in `task-13/source-final.json`; no missing entry or mismatch was found. Deleted snapshot/target/facet files were reviewed as deletions, not counted as existing hashed files. This is scoped source freshness evidence, not a clean-worktree claim or a claim to have rerun all tests.

Existing results under `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-13/`:

| Command/evidence | Recorded result inspected |
| --- | --- |
| `hermetic-r2/results.json`, `hermetic-r2/03.log:13-15` | `forge build --use solar`, exit 0; 3,237 files compiled, warnings retained. |
| `hermetic-r2/results.json`, `hermetic-r2/04.log:64138` | Full hermetic command, exit 0; 28,641 passed, 0 failed, 0 skipped across 2,691 suites. |
| `fork/results.json`, `fork/03.log:5677` | Migration fork artifact-helper command, exit 0; 183 passed, 0 failed, 0 skipped across 30 suites. |
| `operator-r2/03.log.command.json` | Strict operator TypeScript invocation, exit 0. |
| `operator-r2/results.json`, `operator-r2/04.log:88-110,326-331` | Full operator invocation, exit 1; 240 passed and 1 failed. The failure is the known fixed witness runtime hash mismatch. |
| `helper-typecheck.exit.log:1` and `verification/report-r2.md:37-39` | Separate helper exit receipt is 0; its original stdout is empty and the previously recorded provenance qualification remains. |

The compiler log also retains failed dependency-bootstrap messages before successful compilation (`hermetic-r2/03.log:4-15`). Reviewed migration warnings include deadlines, events after guarded external operations, administration-before-reentrancy ordering, fixed WETH deposit, and linked pure math calls in bounded leg loops. Their relevant source was inspected; those diagnostics do not establish another new defect. This is not a warning-free build claim, nor a disposition of every monorepo warning.

## Existing gaps, assumptions and limits

The known witness mismatch remains exactly as recorded in `.omo/ulw-execute/dtf-conformance/task-13-verdict-r2.json`: expected `0x4ae06bcb278766df6529bcd60e05453fee6c853f6536b9f18d2a4d0dac8fd899`, actual `0x33a0fe038a5d441aa3d9fe48b841bcfc0d0f00f0b085e44b9c41b9b0a7aab2bc`. It was neither retuned nor counted as a new F2 finding.

Task 10's complete current-chain lifecycle and dependent real portable proofs remain absent as qualified by `task-13/verification/report-r2.md:41-43`. That report identifies an authority-bundle provenance-contract blocker, not proof of global DTF scarcity. No task-10 receipts are inferred from unit tests, static tracing, or gas witnesses.

F2-01 assumes the expressly supported operation of adding a distinct original after an earlier accepted configuration, while retaining immutable prior manifests. F2-02 is a static rejection-path defect; no mutation test was run. Neither finding asserts a completed exploit or an observed on-chain loss.

This review made no implementation change, delegated no work, ran no tests/builds/recorder/rehearsal, made no RPC call, committed nothing and sent no transaction. Only this report and the following F2 verdict are authored. **NOT-APPROVE** follows from F2-01 and F2-02; known `[~]` gaps are recorded separately and are not presented as newly discovered defects.
