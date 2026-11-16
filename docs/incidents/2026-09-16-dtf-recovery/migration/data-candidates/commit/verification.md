# Phase27 immutable local-delivery verification

Date: 2026-11-13.

**Verdict: confirmed for the completed ten-file offline source delivery.** No needs-fix finding was established within this bounded immutable-verification scope. The local commit, source/index/tested identities, complete immutable whitespace, sealed offline evidence, recovered-input bindings, and every original preservation row authenticate. The only original-baseline differences are the expected local commit's own ref/index and the documented additive directory-size change. This is not a new runtime run, operational approval, eligibility decision, full Task 9 acceptance, P1 recovery, or full Migration-plan acceptance.

## 1. Subject and evidence boundary

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-27-data-candidates`.
Branch: `work/dtf-migration-phase-27-data-candidates`.
Actual commit: `789fced820ed494d9651c598fb8f75c646d727a7`.
Sole parent: `0856a5c56e5d09b81c669f59b613efef79133e19`.
Tree: `cbdb3081d1264ba05c3b9f1345aaff3c66cacf2e`.
Subject: `Add verified bounded historical review candidate derivation`.

Read the complete commit brief and accepted source JSON, original scope and r2 workflow, actual receipt and delivery manifest, original blocked histories, complete implementation-r2 and verification-r2 reports, manifests, seals, cleanup and required actual command/proof records. The eight added bodies and both test bodies were read, together with the complete two-modification diff. The full candidate, independent proof including all unresolved records, source manifests, input declarations and original per-entry inventories were parsed completely from raw files; no displayed/elided read rendering was used as input to hashing. The preserved Python oracles were inspected, not executed.

This audit uses the accepted verifier report binding: 25267 bytes, SHA-256 `75f5b24fb6f84e873ea348eb9a774ed9006e3f4aa84f835354f73f67a61dfaa5`. It matches the actual report and seal. The actual delivery source manifest is 6135 bytes, SHA-256 `5cb5eed809e86eed79bb80a98805ba288330d3183c7eca234fee56c36d2180be`; its claims were compared with Git and filesystem observations rather than accepted on assertion. Receipt bytes are independently bound in `verification-support/source-identities.json`.

Only this new report and new `commit/verification-support/` files are this auditor's deliverables. No source, input, old evidence, authority, ref, index, configuration or dependency was edited. No test, strict-type check, CLI derivation, oracle, build, Forge, chain, signer, provider, held09-worktree or public action was run. Read-only Git subprocesses completed before their results were used. No subagent, monitor, server or background operation was started.

## 2. Commit and exact source delivery

`rev-list --parents -n 1 HEAD` returns exactly the commit and sole parent above. `rev-list --count PARENT..HEAD` returns 1. `diff-tree --name-status -r` reports exactly two modifications and eight additions, with no evidence/data path. Numstat is 955 insertions and 0 deletions. The two parent blobs are `9202bed8ea7d8ade48c95f38a81b07ea46daffe7` (runbook) and `28784724aa049e128b70f693081f04418d18af9c` (CLI). All eight new paths are absent in the actual parent tree.

Raw commit object: 1207 bytes, SHA-256 `6ecdf3c0e26a92d950e27b08430ef9ed99fcced205dbaa0b85f16291a9d06217`. It contains exactly one coauthor line, and it is exactly:

`Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`.

Author and committer are Cyotee Doge <not_cyotee@proton.me>; both object timestamps are 1794543292, offset -0800 (November 12, 2026 at 20:14:52 -0800; November 13 at 04:14:52 UTC). The receipt reports a successful signature verification and the creation invocation's one-shot flags. This audit confirms the raw object's signature field and trailer cardinality, but does not rerun GnuPG or infer the original command-line flags from the object.

Every row below matches raw current filesystem bytes, stage-0 index blob, committed blob, accepted binding, producer-tested manifest and independent-tested manifest, in both SHA-256 and byte length. Full blob IDs and mode records are in `verification-support/source-identities.json`.

| Path | Bytes in every compared body | SHA-256 in every compared body | Delta |
| --- | ---: | --- | --- |
| `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md` | 59669 | `3e757d019f9769e25db54c1350fba54e4ed22397bd194a177150925a7b21c575` | M |
| `scripts/recovery/dtf-migration/candidate-input.ts` | 6757 | `2602f19276967c81f776665a1393936387078d7113512f24f1a85f08ec07fee8` | A |
| `scripts/recovery/dtf-migration/candidate-nfts.ts` | 7120 | `0ce1b2535082a69702d72f52fc8c3206f0de8a3c5dd86fcd1ab6caf49ddcc63e` | A |
| `scripts/recovery/dtf-migration/candidate-inventory.ts` | 11872 | `d2946bbc4d8bd5637d46dce39ce9a754f4762f7bc66b7d4c9f23f0a70fc2ae8d` | A |
| `scripts/recovery/dtf-migration/candidate-proofs.ts` | 5443 | `8bbdc80e124a185d21a51557ac3237910496e23339a918fd3b1d27a50bae64d8` | A |
| `scripts/recovery/dtf-migration/candidate-reconciliation.ts` | 8096 | `90c1f6f2fd852af4257e925b223fae91e5e65b7c8db1dc28736659906b6b11a0` | A |
| `scripts/recovery/dtf-migration/candidates.ts` | 3399 | `5e8f7a7b6cbc43abc88ef5d6356eec133189b273c4713603aa7d72c8d5587026` | A |
| `scripts/recovery/dtf-migration/candidates.test.ts` | 9086 | `3f5466255a68c34fafead08a148930bd4ea36d3369910f92caedbd12e1295ab5` | A |
| `scripts/recovery/dtf-migration/candidate-inventory.test.ts` | 6421 | `8fdd4761206fc3a32d006c1c217bc441690fedef38100f35ca02e49fa32d9f74` | A |
| `scripts/recovery/dtf-migration/cli.ts` | 11960 | `fd0993fd3315bd1b883bf01bee1b0a1abf4120269387762cac996f0c0e0479c3` | M |

All ten current files have full filesystem `st_mode=33188`, permission `0o644`; their actual committed and index Git modes are `100644`. Both tested manifests omit filesystem modes, permissions and Git modes. Those historical tested modes are **not available** and are not invented from current observations. The precommit mode captures and this audit's current `lstat` observations agree, including all 62 frozen source/runbook rows. Predicted Git modes from executable bits are not a substitute for actual index/tree modes or historical tested modes.

All 62 frozen raw identities still match both tested manifests; 52 are outside this commit. Producer and independent source-manifest file arrays agree. All 13087 stage-0 index entries match the commit tree's path/blob/mode entries; no unresolved index stage exists. Staged and unstaged tracked diffs are empty, ignoring submodules. The worktree is not globally empty: excluded/untracked evidence remains intentionally local.

Complete immutable whitespace was checked against the actual parent-to-commit delta, including all eight added bodies, not only the old two-file tracked diff. Both commands exit 0 with empty stdout/stderr:

`git diff --ignore-submodules=all --check 0856a5c56e5d09b81c669f59b613efef79133e19 HEAD`

`git show --check --format= HEAD`

All audit Git calls use environment `GIT_MASTER=1 GIT_OPTIONAL_LOCKS=0 GIT_PAGER=cat PAGER=cat`, `git --no-pager -C "$WT"`; status/diff ignore submodules. No write-tree, refresh-index, add, commit, checkout, reset, amend, fetch, push or history mutation was used. `verification-support/git-evidence.json` retains exact argv, exits, raw small outputs and identities of the large full-index/tree listings.

## 3. Complete seal closure and historical failures

Every listed file in all four actual manifests and every direct seal binding was rehashed at its bound path and length. Manifest-to-producer-seal cross-links were also checked.

| Evidence directory | Manifest file entries | Direct seal bindings | Mismatches |
| --- | ---: | ---: | ---: |
| `implementation/` | 3 | 1 | 0 |
| `verification/` | 10 | 2 | 0 |
| `implementation-r2/` | 208 | 3 | 0 |
| `verification-r2/` | 105 | 5 | 0 |

The original blocked reports, binding audits, all later failed attempts, intermediate positive outputs, executed old oracle/support bodies, command streams, cleanup and seals remain preserved. `verification-support/seal-authentication.json` contains **every** expected/actual member identity, not an aggregate-only claim. Hash closure authenticates retained content; it does not independently prove historical write chronology or process absence. Stopped-history claims are supported by the actual retained exit and cleanup records, not by assuming a seal proves execution.

The original intake really has 34 matches and two Markdown failures across 36 declarations/27 paths. Original implementation was blocked before implementation; original verification's 109-pass baseline was not feature proof. Those verdicts remain unchanged. R2 supplies separate evidence; it does not rewrite failure into success.

Retained later histories include blank recovery-count rejection (attempt01 exit 1), signed-gon rejections (attempt02/03 exit 1), macOS symlink-ancestor fixture failure (9 pass/1 fail), earlier complete outputs distinct from proof02, deliberate five-guard failures (14 pass/5 fail, exit 1), proof-support strict typing failure (exit 2), and the verifier's first case-sensitive payer comparison (exit 1). The corrected independent address-normalization run exits 0 without a producer source edit. The final source-observation-link addition explains why the producer ran a new final proof and gate; old hashes are not relabeled final hashes.

The receipt also preserves the initial wrong-executable inventory-capture launch killed with exit 137 before inventory production. The retained original baseline is from the subsequent capture that completed; it is not replaced here. This auditor did not repeat that launch or hide it.

**Optional audit qualification:** producer `source-audit.json` exits 2; its actual stderr says `error: cannot resolve "typescript" from the caller project`. The more specific unstable-API explanation in producer prose/metadata is not established by that error. The optional AST audit is not clean and its deeper cause remains unproven. Required strict types passed independently. Prior Biome/basedpyright and this audit's JSON editor diagnostics are unavailable, not clean; the patch diagnostic reports Biome is not installed. No install or configuration change was attempted.

## 4. Recovered-input authentication

Recovery and validation records were read completely at the supplied `phase27-frozen-input-recovery/` root. The 15 sources declarations and 21 manifest declarations all authenticate in the recovered tree: 36/36 matches across 27 unique declared paths. Candidate declarations and supplied validation entries agree entry by entry. The additional manifest body is bound in candidate input identities; the preserved relocated archives include all 28 physical input bodies and the pre-exploit sibling.

The current annotated primary tree remains 34/36, with only these original failures:

| Document | Declared/recovered bytes | Primary bytes | Declared/recovered SHA-256 | Primary SHA-256 |
| --- | ---: | ---: | --- | --- |
| `LOSS_AND_RECOVERY_LEDGER.md` | 15308 | 15943 | `8564764d3d2140b25a9de361c49606c2e4d3d53cc404309ccc00bb955f572f07` | `52758ad2bbfa4efce31668ba1079aff608a8c72798280512e0247a0fb1747a71` |
| `CUSTODY_AND_HARVEST.md` | 7357 | 7920 | `0ddb0eb30523e26551dce653d3f3bfb2e439f7b0c83fe2c8c93aaf953d6f42cd` | `ab837ca952449a6d9ac155f5cd641329134ed92c0b9a610007ad7cd9b33698d8` |

Each exact declared November 10 annotation occurs once in its current document. Removing only that paragraph plus its following blank line, **in memory for comparison**, yields the supplied recovered body byte for byte: 635 and 563 removed bytes respectively. No source file was transformed or written by this audit. These are hash-authenticated recovered historical bodies, not located original raw captures, not guessed economic data, not P1 recovery and not current policy. Original annotated files/manifests and recovered files remain preserved. `verification-support/input-authentication.json` retains all original/recovered per-declaration observations and exact transform checks.

## 5. Actual executed offline evidence, not a replay

Actual complete command metadata, stdout and stderr were read and authenticated. The accepted final producer lane is proof02/types-final03/operator-tests-final02, not attempt04 or proof01. The accepted independent lane is verification-r2. The evidence records:

| Gate | Retained actual result |
| --- | --- |
| Producer final strict types | Exit 0, empty streams |
| Independent strict types over every operator TS file plus recorder | Exit 0, empty streams; strict, unchecked-index, exact-optional and verbatim-module flags present |
| Producer and independent final complete operator invocations | Each exit 0, 128 pass / 0 fail / 13 files; Bun 1.4.2 |
| Independent full-a, full-b and relocated CLI derivations | Each exit 0; relocated CWD is verification-r2, not repo root |
| Independent corrected raw-row/NFT oracle | Exit 0; Python stdlib CSV/arbitrary-precision integers, no producer imports |
| Independent relations/gons oracle | Exit 0; complete relation and diagnostic proof |
| Primary annotated tree | Expected/actual exit 1, raw-binding PROVENANCE failure |
| Actual full candidate prepare, validate and default execution verify | Expected/actual exit 1 each; unsupported schema before provider/signing work |

The complete 128-test stderr was inspected, not only its summary. It contains the 19 new boundary tests as well as the 109 prior tests. No test was rerun in this delivery audit. Existing local wire fixtures are not chain acquisition or provider replay.

All six retained final candidate bodies (producer proof02 full-a/full-b/full-relocated, independent full-a/full-b/full-relocated) were directly byte-compared and rehashed: **16570240 bytes**, SHA-256 **`76f56c067084e04931a335ceef45ee5725153db9a39fb1619c9eab78f46ed278`**, all byte-identical. This authenticates already executed repeated/different-CWD/relocated evidence; it is not a new derivation. Earlier candidate outputs retain their different identities.

The actual parsed candidate contains all 18044 inventory records, all 39507 quantity fields and all 1240 unresolved records. The independently executed proof records those same complete counts, not a sample. All unresolved objects agree with the proof's full `allUnresolved` array, and full records are reproduced in `verification-support/unresolved-records.json`. No unresolved question was resolved by counting it. Complete table coverage is:

| Raw table | Records |
| --- | ---: |
| `../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf-details.csv` | 819 |
| `../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf.csv` | 244 |
| `../2026-09-16-dtf-pre-exploit/sdtf-detf-holders.csv` | 200 |
| `../2026-09-16-dtf-pre-exploit/stakers.csv` | 92 |
| `../2026-09-16-dtf-pre-exploit/sy-sdtf-detf-holders.csv` | 18 |
| `account-ledger.csv` | 435 |
| `conversions.csv` | 250 |
| `custody-inventory.csv` | 403 |
| `evidence/all-index-events.csv` | 1077 |
| `evidence/bond-accounting.csv` | 57 |
| `evidence/earlier-cp-bonds.csv` | 16 |
| `evidence/earlier-cp-wallets.csv` | 13 |
| `evidence/index-events.csv` | 847 |
| `evidence/post-incident-bond-claims.csv` | 7 |
| `evidence/transfers.csv` | 12191 |
| `evidence/weighted-bonds.csv` | 43 |
| `evidence/weighted-candidates.csv` | 422 |
| `exceptions.csv` | 14 |
| `held-exclusions.csv` | 411 |
| `observed-recoveries.csv` | 69 |
| `positions.csv` | 411 |
| `rounding.csv` | 5 |

The retained independent proof reconstructs all 43 weighted purchases/transactions/mints (41 pre-incident, 2 later), all 16 earlier CP observations, 382 weighted position/lower-bound diagnostics, 57 event-time gon records, seven later claims and 250 conversion-output matches. Proof links partition as 422 account sums + 57 event-index products + 7 later claims + 41 NFT snapshot conservations = 527. All 69 recovery outputs and complete account memberships were checked by those recorded oracles. This audit inspects and authenticates their results; it does not rerun economic arithmetic or claim a fresh chain proof.

Direct DTF/WETH stay separate; routed CP DTF is not another contribution. Native/refund/net inputs, original CP receipts, original Q0 and current control remain unproved. Historical gons, raw weights, LP-accounting, physical LP and native9/18/19/28 are not promoted into interchangeable units or awards. Reported totals are limited to the 17 actually supported matches; unrecomputed keys remain unverified. The earlier receipt discrepancy remains 57880198310224980583 observed versus 57898677945502333609 supply, unallocated.

All 16 category rows are retained: W-L, E-L, W-N, E-N, W-R, E-R, W-Y, T, C, E-S, W-SW, W-SD, E-P, W-P, ETH, WETH. No observed row is not proof of absence. ETH/WETH remain contribution/recovery provenance, not invented standalone compensated surrender routes. Current configured original-wallet/control rules govern, not old bearer prose; no intermediate-holder ancestry runtime prerequisite is introduced.

| Unresolved class | Complete records |
| --- | ---: |
| `aggregate-source-reference` | 34 |
| `conversion-origin-unresolved` | 250 |
| `earlier-receipt-discrepancy` | 1 |
| `historical-policy-not-authority` | 1 |
| `incomplete-WETH-native-recovery` | 1 |
| `independent-basis-unresolved` | 435 |
| `missing-earlier-raw-receipts` | 1 |
| `missing-original-inputs-wallet-review` | 1 |
| `original-contribution-unknown` | 411 |
| `partial-claims-prior-delivery` | 1 |
| `raw-claim-event-archive-missing` | 18 |
| `recovery-attribution-unresolved` | 69 |
| `representation-overlap-aliases` | 1 |
| `review-acquisition-funded-snapshot-open` | 1 |
| `stale-current-state` | 1 |
| `unknown-recovery-count` | 13 |
| `unobserved-accepted-categories` | 1 |

Candidate status remains `NON-ISSUABLE-REVIEW-CANDIDATES`, version `dtf-historical-review-candidates-v1`. Actual negative stderr is structured INPUT rejection: 191 preparation issues, six validation issues, fifteen execution issues, each including the unsupported version. The stored negative command argv points to the full canonical candidate. Rejected output/checkpoint directories are absent. These records are not a live loader dataset, approved eligibility, final C0/configuration, fabricated zero prior credit or operational authority.

## 6. Every original preservation row reproduced

The baseline remains **the original precommit inventories** under `commit/precommit/`, captured before staging and before commit/ existed. Original `recipe.txt`, `capture.mjs`, roots, summary and pre/post-support comparison were read. No newer baseline substitutes for them.

Each original JSONL row is reproduced in `verification-support/preservation-<original-name>` with its full `baseline`, independently computed `observed`, and explicit `mismatchedFields`. All original file/symlink SHA-256, lengths, permissions, full modes, Git-mode collapses where captured, and target strings are retained. Permission inventories include all original directories. Regular-file hashes use raw bytes; symlink hashes use raw UTF-8 target strings, without opening targets. Original/recovered input roots use the exact original roots from roots.json, not relocated replacements. Aggregates below bind the original inventory bytes but are **not** the per-entry proof.

| Original inventory | Rows | Original raw bytes | Original inventory SHA-256 |
| --- | ---: | ---: | --- |
| `docs-incidents.jsonl` | 348 | 101196 | `c53b6a14a58564f8254508490a35ff5d2300ba12cb8deecfbf9da1fa60d02a2d` |
| `docs-incidents-perms.jsonl` | 383 | 101235 | `eb2e996d05c5ab9433cc30039f61c2babe7b62220c3f75111f28b729d8ef21a9` |
| `out.jsonl` | 7376 | 1960530 | `6673598e3a68c4b3dd7d747ffea0027f9c55f566c259faff4453b299a9db1771` |
| `out-perms.jsonl` | 13856 | 2721030 | `6c69936bfe945823dca2d1b60a81897870c422a976d4b8a9d638e4c2c9dfb72a` |
| `cache_forge.jsonl` | 6502 | 2297269 | `167a70ddc88be51f57510a8ed99510b778850e635a26f64009b0c64c73750744` |
| `cache_forge-perms.jsonl` | 12368 | 3518453 | `ad05142c9779921a1abba60f51f25985a4caf985568a18a64702422e24237e4c` |
| `original-recovery.jsonl` | 25 | 5668 | `a29c461c60b788748e935c485444eec646d677becabf9f967752f8bceada12de` |
| `original-recovery-perms.jsonl` | 27 | 5438 | `ab1a9b57ce7c852fcbcd67ac75e24e6c8f14923e50922f8859f80e7486f6ac25` |
| `original-pre-exploit.jsonl` | 12 | 2692 | `236335672b9491a04f5eef60bf3542e49bef7cbf145a1aea918d36aea36acf3f` |
| `original-pre-exploit-perms.jsonl` | 13 | 2585 | `e6d6c3b596584a8f76be9d62bd9a3cf3a09228a77f1862174de63c9b168d119b` |
| `recovered-input.jsonl` | 30 | 7898 | `a28a29eb85372bf3c41c3f4d461475b7b0aaba7d9bfbdb8ead12b2f222c44800` |
| `recovered-input-perms.jsonl` | 35 | 8076 | `1caf7f698a7113d62eed6c92b73d4f70115c89439137a5a9e311b13291145e73` |

All **14293 content rows** match. Of **26682 permission rows**, exactly one differs, in size only: `docs/incidents/2026-09-16-dtf-recovery/migration/data-candidates`, before 192, observed 224, unchanged directory kind, `st_mode=16877`, `0o755`, null directory hash. This is the documented additive commit/ child. No original file/symlink content or mode changed. The precommit inventories themselves match their original summary hashes/lengths.

Membership checks find no missing baseline path and no new path in out, cache_forge, either original input tree or recovered-input tree. Before this auditor's additions, docs/incidents had exactly 41 added entries, all within the new commit/ directory. This report/support adds only inside that already excluded directory; it cannot be silently folded into the older preservation baseline. Foundry cache/ remains absent; cache_path is cache_forge. No artifacts/cache were rebuilt, deleted, restored or moved.

The other **original per-entry** rows are fully reproduced in support:

- `preservation-indexes.json`: 29 indexes. All 28 foreign indexes match raw hashes, lengths and full modes. The expected own index changed only as the delivered commit requires: 2076635 bytes / `3f65220769feadf707b9ddfa503bb70d78d9520666fe414f7220e51c47814937` to 2077579 bytes / `6a2e636d68083c83d543b6518661ad323f07faa728dcdcb9f58f9717302d543b`, mode 33188. It is now clean and matches the actual commit tree. The phase09 index was read only as a raw file under .git/worktrees; its held09 worktree was not opened.
- `preservation-refs.json`: all 54 original ref/HEAD rows. Only this worktree's branch-ref raw hash changed, from `6074490d00a3f530e8e310d74b23232e632f0f4d581b5191e3ec790b661fc401` to `dcd150d26b0ed9bfa44f3993987b3b3257ee4c57cd500a55f785cd5cd86890a5`, still 41 bytes/mode 33188, naming parent then delivered commit. Exact show-ref outputs are both 6482 bytes and differ only in that branch's one line. Reflogs are not in the original preservation set.
- `preservation-host-deps.json`: both original symlinks, lib/crane and node_modules, retain full mode 41453, target-string bytes/hash/length and inodes 20382958 and 20382959. Targets were not opened for preservation hashing. No dependency/configuration install or alteration occurred. The unchanged source tree retains the lib/crane gitlink.
- `preservation-authorities.json`: every original row for the four named authority files matches its regular-file raw hash, length and full mode. Those files are not symlink-target substitutes.
- `source-identities.json`: all 62 original frozen-source mode rows, separately qualified from mode-less tested manifests.

Classification fields such as own/foreign and openedTarget are capture/audit metadata, not bytes inferred from a file. Directory hashes remain null, not invented content digests. The receipt's pre-support/post-support comparison claims agree with the original-row audit; no aggregate count is used to excuse a row mismatch.

## 7. Limits, cleanup and stopped result

The sealed producer cleanup records 18/18 completed sessions and zero pending work. Independent cleanup records 8/8 completed monitors, 20/20 exited subprocesses and zero pending work. Failed and positive outputs/raw relocation archives are intentionally retained. This audit creates no runtime/temporary tree, starts no service and adopts no historical process. All its finite read-only subprocesses have exited. No broad deletion or shared-service cleanup was attempted. The only verifier-owned filename correction was replacing a newly created ref-support .jsonl name with .json for its JSON-object format; no old evidence was changed.

No source fix, ref/index/commit mutation, authority/configuration change, provider/held09/public action or runtime replay occurred. New JSON support is parseable and its identities are recorded separately; unavailable Biome diagnostics are not relabeled passing. `verification-support/manifest.json` binds the new support files, and `verification-support/final-state.json` records the final bounded clean source/index and stopped state. These new local audit artifacts are uncommitted.

Operational/source limits remain: E-S and broader eligible T claim domains/conservation; disabled downstream conversions; actual reviewed original inputs/receipts, deployed identity/routing/units and pinned current control/recoveries; partial claims/previous delivery and representation aliases; actual funding and supported immutable mint-preview snapshot; selected real composition; and the retained target registration **45116678 > 32000000 gas** constraint. Exact universal historic build pedigree is not required, but used deployed identity/routing/units still are.

P1 still names two missing historical raw artifact versions, not current behavior failures or permission to reconstruct:

| Historical artifact | Required bytes | Required SHA-256 |
| --- | ---: | --- |
| `out/TestBase_UniswapV4DetfMigrationSnapshot.sol/MigrationSnapshotConsumer.json` | 466441 | `e7e44f1c9dd1feae73302f69cc50182b084c3e156ff63108f9e1206f52b201bf` |
| `out/MigrationNativeHandler.sol/MigrationNativeHandler.json` | 266621 | `3628e086cdf17079f06aa157c414326519ba5de6d7a60df05e7deaa59e91d013` |

No search/reconstruction of P1 was performed. Recovered/bundled flags, the local source commit and this confirmed immutable audit do not approve operational use or full-plan completion.

**Stopped result: complete confirmed bounded immutable delivery verification; no owned operation or cleanup is pending.**
