# Task 3 source and recovery evidence completion

The fourteen required fixed source categories are indexed in `source-manifest.json`, `source-route-matrix.md` and `recovery-route-disposition.md`. Every indexed route has an exact target, selector, delegated facet/code hash and input/return schema reference. All 34 selected proxy/facet runtimes recomputed to their recorded EVM keccak. Original raw archives and all three old index byte streams are preserved; the preliminary blocked DoneClaim is retained as `initial-blocked-claim.json`.

Earlier E-N IDs 0, 1 and 2 are existing reserved protocol/fee-recipient/creator positions, not nonexistent IDs or ordinary user LP-lock positions. This comes from runtime-bound deployed initialization/constants, live `reservedBondNftsWired=true`, exact source ownership/position reads and the independent ordinary ID-3 acquisition receipt. ID 0 has protocol principal; IDs 1/2 have reward weights but zero original shares. The numeric guard in current Migration code and the new bond child were not used to infer those facts. Task 3 changes no eligibility guard or financial allocation.

E-P permanent protocol custody is bound to the actual owner-only withdrawal facet, all three live native exit routes, parent accepted intake/claimLiquidity, NFT forwarding roles and collector paths. W-P alone retains the actual current-fee-recipient removal exception. Disabled source, dust or no incoming rewards is recorded as conditional availability. Raw code/source excerpts and exact hashes are in `recovery-authority.json` and `source-observations.json`.

## Current checks

The exact plan command was executed through the existing login-shell credential and accepted final task-owned HOME/cache roots:

```bash
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyNftLib.sol --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacyLpExit.t.sol -- -vv
```

Actual final process exit **0**; **13 passed, 0 failed, 0 skipped**. `source-state-assertions.log` is the final raw stdout/stderr. The source-only test change adds five lines to the existing invalid-ID case, using its original helper to explicitly assert unchanged ownership, custody/consumption, supply/backing, gons and allowances after burned/reserved/nonexistent-ID rejection. Wrong-wallet and unauthorized E-P exit assertions remain unchanged and passed. No test was weakened, removed or skipped. `source-negative.log` is a labelled excerpt and assertion binding, not a reconstructed verbose trace.

The verified task-2 helper inventoried an unchanged runtime descriptor and passed delivery (exit **0**). After replacing only that owned descriptor's expected runtime hash with zeros, delivery reported stale source inventory, `completed=false`, and exit **1**, as expected. The real raw archive was not changed. The helper checks descriptor bytes; the separate runtime checks establish EVM identity. Exact inputs and receipts survive cleanup in `integrity-inputs-and-results.json`.

`artifact-validation.json` records successful JSON/schema-reference diagnostics: **14 rows**, **118 route references**, **3 reserved roles**, **34 matching runtime checks**. All **26 selected raw archive files** retain identical before/after SHA-256; all three old indexes and the original source test are byte-exact in their baseline files. The source fingerprint covers 50 task-related files. The current production migration diff is empty; the final allowed test diff has five added lines; scoped diff check exited **0**. The actual worktree remains dirty/untracked, including the concurrent task-1 PRD and delivered task-2 files, which were preserved.

The preserved historical category integration witness is `final-fork-20261113/03.log`, 181 passed, paired with `final-source-20261113.json`; relevant raw source comparisons and the independently verified recorder-helper extension are explicitly qualified. It is not relabelled as a new full-tree regression or evidence for the future manual-pricing ABI.

## Preserved failures and limits

- Initial nonlogin fork setup failed because ALCHEMY_KEY was absent. Existing archived documentation identified the existing login-shell credential; no credential was requested, written to disk, displayed or replaced.
- One login attempt had 13 passing cases but a shell quoting error left its exit marker empty and produced process exit 255. That command is rejected as acceptance; literal shell quoting was corrected, with the failed log retained.
- The deployed E-N collection has no owner() route; two attempted read logs retain NoTargetFor. The corrected supported source reads passed. These are source-read limitations, not predecessor product defects.
- The exact collection/from-zero/IDs-0-1-2 mint-log query was rejected by the approved RPC's ten-block free-tier range limit. The exact reserved mint transaction receipt remains supplemental unavailable provenance. No range scan, provider switch, service purchase or refused historical trace followed. The initialized-role finding uses the independent successful source facts and does not claim that failed request succeeded. No wallet-wide no-exposure conclusion is drawn.
- Initial attempts did not explicitly override HOME; their HOME-derived RPC cache isolation is not claimed. Final accepted source QA explicitly set HOME/FOUNDRY_DIR/FOUNDRY_HOME/XDG_CACHE_HOME/TMPDIR to owned paths and populated owned HOME/.foundry. No shared cache was deleted or copied back.
- Forge emitted existing fmt.skip/lint warnings and automatically attempted a missing-submodule installation, which failed because the populated plain Crane directory already exists. No dependency install succeeded. The actual local binaries and successful Solar invocation are recorded in both version logs; no solc fallback or install was selected.
- Configured Biome LSP is unavailable. No install was attempted. JSON parse/reference diagnostics, successful Solar test compilation and scoped Git diff diagnostics are recorded instead.

No actual source/custody/conservation gate remains unidentified in these fourteen rows. Operational original contributions, eligibility/exposure partitions and exact source-role/public execution approvals remain inputs to later plan work; none are invented here. The lead's independent source verification is still required before downstream implementation uses this DoneClaim.

## Artifacts and cleanup

`commands.json` contains exact command strings, actual exits, accepted/rejected attempts, source bindings and runtime versions. `manual-qa.json`, `adversarial-results.json`, `source-preservation.json` and `artifact-validation.json` bind the evidence. `cleanup.log` and `cleanup-receipt.json` record teardown of only the owned temporary HOME/cache and descriptor fixture roots. Runtime helper inventories/delivery receipts, all failed/successful logs, the baseline files and source observations remain delivered. Task-local out/cache_forge are retained as required load-bearing artifacts. No commit, merge, push, public transaction, external message or delegation was performed.

## Confirmed local specification reference follow-up

The task-1 amendment is independently confirmed per the user. The local P raw bytes match SHA-256 `93fdd2f045885e00304ec36aa62215127dc1a957f514605129751dd3ae45218e` (98213 bytes). The source manifest, route matrix, recovery disposition and source observations now cite that local authority, including section 1.10's pricing precedence and the unchanged source/custody requirements at 1.9, E1/E2 and implementation task 1. Completed runtime, fork, integrity, recovery and cleanup checks are retained without repetition. The DoneClaim and artifact inventory are refreshed only to bind these metadata changes; the prior completion claim is preserved in `task-3-done-before-spec-amendment.json`.
