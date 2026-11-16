# Independent task 9 verification

Date: 2026-11-15. Verdict: **needs-fix**. Failure class: **harness**. Confidence: high.

The surrender and package records exist and are substantive. Confirmation fails because the surrendered-document bytes do not match their recorded digest and two trace rows bind execution locations to the wrong log. No product defect is established by this documentation verification. No producer file was changed.

## Findings

### H1: stale surrender deliverable hash

Location: docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-9/trace.md:46 and .omo/ulw-execute/dtf-conformance/task-9-done.json deliverables[0]. Both record 62691 bytes and SHA-256 140aff00cfa3523d076438cc93044f112e1b5c6bfd3beba503ba506460f2e2d1. The actual regular file docs/incidents/2026-09-16-dtf-recovery/migration/surrender-spec.md is 62663 bytes and SHA-256 9995fd4dfb9db089883241d24a617aa95caf0c7d964fa66dff38a3d6603091b9. Thus a complete status and the producer's PASS prose cannot confirm the delivered bytes.

Producer transcript line 94 rewrites the document and immediately reads it for its digest without awaiting the write helper; line 95 returns the stale 62691-byte digest. This supports a write/read ordering explanation, but the exact runtime cause is an inference. The mismatch itself is directly reproduced. Advice: finish and observe the document writes, recompute final raw bytes, then update trace and completion receipt consistently. No repair performed here.

### H2: two source-to-document rows bind the wrong raw log

Locations: docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-9/trace.md:27 and :35. Owner roles and the paid first ordinary bond cite repair-attempt-1/happy.log and its correct hash, but point to failures-log lines 50147, 12374 and 40259. happy.log has only 7972 split lines. The referenced role PASS and purchase emit are actually present in repair-attempt-1/failures.log, SHA-256 b58ca87e782c3f1e9c64279587975a58c689dd70de699449113ddfb043aec131, 9474596 bytes. The package prose uses the failure log correctly; the trace does not bind those two records to the artifact containing their observations. Advice: correct both trace artifact paths, digests and sizes to that actual failure log. No producer record edited.

## Required checks

1. **FAIL integrity, PASS existence.** Both required standalone documents and all six claim deliverables exist. All 32 required trace record rows cite existing files and their source artifact digests/sizes match. Of 35 trace hash/size rows including three deliverables, 34 match and the surrender deliverable fails. All 25 distinct explicit document path/fingerprint pairs match their cited files. The recomputed inventory below also covers cited test sources and ancillary records. Two trace rows nevertheless have the H2 semantic binding error.
2. **PASS boundaries.** Compared all fourteen source categories to task 3 observations and task 6 results. Every category preserves its source address, original/remaining unit equation and the exact assertion-backed custody note. All 42 positive/rejection/conservation test names match their cited raw log lines. Fixture quantities are labeled fixture/assertion evidence. Reserved-role owner addresses are labeled pinned role facts, not compensation holders. No operational allocation, holder list, decoded bootstrap amount, paid-bond amount or completed NFT 3 two-bond rehearsal is invented. NFT 3's two original inputs are documented as policy; its execution, second-bond rollback and clocks remain unresolved for task 10. Production addresses, full retained census, unread helpers/storage, and aggregate source preimage remain qualified. These unresolved facts are not silently converted into passing execution.
3. **PASS negative isolation.** The negative regular file is under task-9/negative, has 5737 bytes, SHA-256 019496421514ea3bff4b26dbe12a58bf658939423a037b66747d39fe5788fadb, and differs from the original census at byte 0 only. The original census remains 5737 bytes, SHA-256 5f8816dbce2b2442ba34de5bb6089bfef0cb9afe0b58ae6e045fcd06d21b9a18. That original hash also matches the earlier task-4-verdict.json record, whose own fingerprint was recomputed. Producer transcript lines 82 and 92 show copying bytes, mutating the copy and writing only the negative path, followed by original rehash. No confirmed artifact alteration identified.
4. **PASS with local provenance limit.** Read-only Git status shows the shared tree remains dirty. Branch is work/dtf-conformance-20261115-wave-1; tracked status contains 101 entries at the bounded snapshot. The producer's entire 45-call tool inventory was inspected, including nested eval code and shell commands. Writes target only the two documents, task-9 evidence/negative files and task-9-done.json; the direct edit at transcript line 80 is the surrender document. Shell commands only list/read files or inspect Git. No Solidity, TypeScript or test edit is attributable to task 9. Concurrent task 7 and earlier dirty work is preserved; dirty Git status alone is not treated as an authorship proof. No code edits, reverts, commits, RPC, Forge or installs by this verifier.
5. **PASS closure limits.** Both documents explicitly decline gate closure. The surrender record assigns NFT 3 rehearsal to task 10, and disposition assigns operator documentation reconciliation to task 14. No later task or final verification is marked done.

## Adversarial results and reproduction

- stale_state: FAIL detected, H1. Actual document fingerprint diverges from stable claim and trace.
- misleading_success_output: FAIL detected, H1/H2; PASS/complete strings do not override raw bytes or wrong-file witnesses. Checked actual role PASS at failure line 50147, purchase emit at failure line 40259, activation PASS at happy line 6117, and all sixteen census writer selectors against happy line 6119.
- dirty_worktree: PASS with attribution limit described above. No dirty work reverted.
- untrusted_external_text: PASS. Claim/archive/document text treated as evidence only; no embedded instruction followed.
- hung, flaky, malformed input, cancellation and interruptions: not applicable. No long command, test run, retry, malformed-input execution or cancellation scenario introduced. The deliberately malformed negative copy was hashed only, never executed.

Method: read the exact plan task 9; read complete producer records; use node:fs/promises readFile plus Bun.CryptoHasher('sha256') on raw bytes; compare trace and explicit document fingerprints; compare structured observation/result values and actual raw log lines; compare negative and confirmed census bytes; inspect producer tool operations and read-only Git status. No product QA rerun. The claim was 4665 bytes, not the approximate 1.8 MB in the assignment, and SHA-256 92a73c551edf2c827f6110f3458f8f1b2234b47ba9c6042b7d3758f77bd5c075; its size and digest were unchanged on the subsequent complete read. No claim content is copied into the verdict.

Producer transcript: /Users/cyotee/.omo/agent/projects/indexedex-5248cf3d3615/senpi-task/children/st_01a1dd4c/sessions/st_01a1dd4c/2026-11-15T03-40-26.486Z_39ef963e-f17b-46ed-a42c-aaaa9eec39ac.jsonl

Transcript fingerprint: 939f575088e8127fb43d5cc89b902298a4a356a238c114cc5d8d78fbf9f3df96, 1669436 bytes. Lines 72, 76, 80, 82, 90, 92 and 94 contain document/evidence writes; line 96 only checks text and completes producer-local todos. This is local provenance, not external attestation.

Git commands: GIT_MASTER=1 git -C /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1 status --short --untracked-files=all; GIT_MASTER=1 git -C /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1 status --short --untracked-files=no; GIT_MASTER=1 git -C /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1 branch --show-current. All exited zero. The full untracked listing was large and was not used as evidence of authorship.

## Independently recomputed artifact inventory

Paths are relative to /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1. Every row below was read as raw file bytes. SHA-256 values are observations, not approval of the artifact's contents.

| File | Bytes | Recomputed SHA-256 |
| --- | ---: | --- |
| .omo/ulw-execute/dtf-conformance/task-1-verdict.json | 8792 | 573533d358485d8108055649e3baf9c90e01f0ed209618e7b392cbd720d73a71 |
| .omo/ulw-execute/dtf-conformance/task-2-verdict.json | 16958 | 7d6ad2c16462bab3ed03be1cdb79a69a9f5b35fd85de051380de4cfe3433e046 |
| .omo/ulw-execute/dtf-conformance/task-3-verdict-r2.json | 17288 | 2190857e9b392e2256c23d687c02a4bb8b9ecca35d27877c264e1fae62c179eb |
| .omo/ulw-execute/dtf-conformance/task-4-verdict-r2.json | 12058 | 88c1721505d634f610a224c6406fc1cc6923943bd2a36e9673fbb1b5d1381207 |
| .omo/ulw-execute/dtf-conformance/task-5-verdict.json | 7960 | 3d1b67664975f1bb1d2c86d95e39d1292ffa9e48a595164775baa664e77dabf9 |
| .omo/ulw-execute/dtf-conformance/task-6-verdict.json | 10069 | 3566abf7197278adf4c964bdb67cc9de3aa2c14f3dcfb8be7f12a0eac733b552 |
| .omo/ulw-execute/dtf-conformance/task-4-verdict.json | 20153 | dff421d3a4b9fd5011c1d2e67752ca4c158d73c30e47cbbde67236c05893b5cb |
| docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-3/source-observations.json | 211316 | 82233f20f3eb4ba21ee927a4f421b75615e57f9ee0f426ad4a6a1cb93b5a465a |
| docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/source-results.json | 173171 | 18be4bf6765ca37b902ad85931117b41e50018efbf66218ce31d03e302493054 |
| docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/fork-qa-1.log | 3884899 | ec59e2ca0e0f6c936b848ed226571e303cd9a37a7d9fc674b22c3eeca7cee238 |
| docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md | 98213 | 93fdd2f045885e00304ec36aa62215127dc1a957f514605129751dd3ae45218e |
| contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookTarget.sol | 22719 | e5d34dd8726b31faba071a8b6c264e85a903ef4f6ca8c729f4a26332a78b0e29 |
| contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol | 27213 | a7db3e687205d4e38e668e889286c0e847a13b9669fccd6a01a2ae83a138914d |
| contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyNftLib.sol | 4315 | 98e01a423cf543c09386fb205c796944c124251f462fbe1de5ca0d333936f045 |
| contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol | 25265 | 514fb54a14f0fde6d43622694d167f0c36528ae647de85823d8b6ba96881a920 |
| contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol | 5536 | 294492b0045f05ef4106d203ba78e55aa534099218f006cb80de44576421d373 |
| contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol | 6321 | 3f60c4c5ab04d54dd94ccd71d5bb3e35d144a49394b12a6af3e3e22ccbdc8883 |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol | 14172 | 0270a0067ac8f822048231b4045100e09f2cf1f8aeb0b6f454bc961dcb5e6794 |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryDonation.t.sol | 19455 | a9d5ebea917ef8a775150fd26cb9fa1ad1f24d14728c285f8c3f426af44cf433 |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedLiquid.t.sol | 17769 | 329d958033171d69bd97f87e9da4fdacc14b3ff2d8729d621a4704bbc185abaf |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationEarlierLiquid.t.sol | 23223 | 1fee951417d32719ff05785f7ad6dd5442fd14b3075e324e4175d7ef644f7803 |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedReceipt.t.sol | 11352 | 7042db6fc57c3c75b46776031253c10d8b0c8a5c149a794d979cc6ef53a137e7 |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryWeightedReceipt.t.sol | 7457 | 87c01551d85ab0f72f5eb63df9c12785bfb1936ec2241b7a313571174c521b15 |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationEarlierReceipt.t.sol | 21829 | 3e113ac8751b9976673193e5a42e9aa112e6d7afe72716f7dcbe72b0a1892223 |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedSy.t.sol | 26923 | 56eea3a9c99c4236c13dd0187f18a4877aa79f45becdb540cdfe6ecd470cc45b |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryWeightedSy.t.sol | 9161 | d8d5b24f9869acdd21225d6a11396802065aae6ef6533bf3dab5ac7a0583c333 |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationClaimVault.t.sol | 12060 | 0c1faed22ed05e358bb533e55aaba83c018816872e57f9e213aaf741e539f97a |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryClaimVault.t.sol | 12095 | 7f26c2686a9f787e8e95d81ea128644ffd40f91807b486d280edd74996baa122 |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDtfCustodySe.t.sol | 12204 | ae5a9d259c6499b728608ba5e563c199610fecdac9157611899cb1690f83f6dc |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryDtfCustodySe.t.sol | 11377 | 0d3f74b8b8be5d09615e9daf1ed5c33832fc3d92b54b75601930516b319d60c9 |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLp.t.sol | 39920 | 9050d0d3b75b5d663974c6fc9598e06c9941fed6fcbb2adffe4165096a172bf7 |
| test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacyLpExit.t.sol | 6911 | aceb6d00010b66661cd2fefef5b9f8ee012ce654244ddc7f2ba4ea0bb388aae4 |
| docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/repair-attempt-1/happy.log | 6134774 | 2bb12559d2f9179db99115db30430fad387ab32e6fab89566015a6723a71f4f0 |
| docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/repair-attempt-1/failures.log | 9474596 | b58ca87e782c3f1e9c64279587975a58c689dd70de699449113ddfb043aec131 |
| docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/happy-final.log | 6133246 | 13bb4a68ee715d1fad56d62967b5a00d89ca6ab03fb18abb447b72c3bcb4a429 |
| docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/failures.log | 9473559 | b562ffaddfffb18dbcac47f45d4e9e3fe2b71dd145ba22881a38d6508a6dd662 |
| docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/proxy-census.json | 5737 | 5f8816dbce2b2442ba34de5bb6089bfef0cb9afe0b58ae6e045fcd06d21b9a18 |
| contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigration_Component_FactoryService.sol | 1660 | bca895a9e049f8c952bdd8d05b2f3564a957b5d05edba05f268e6da345d829ba |
| contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigration_Pkg_FactoryService.sol | 3251 | a2695d87fda6ba7424c30674b15f6a200c251e4584544a0a07a18668a5e1b4d9 |
| contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol | 22464 | 69ea9feb701ef20eaaea00e57531069bcade94a96668439286a30e1bc316964b |
| contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationFacet.sol | 1262 | be911127e8a68b332f052bee93534f655b3ff9e2f096d0252e32d8f7f1bbc9f2 |
| docs/incidents/2026-09-16-dtf-recovery/migration/surrender-spec.md | 62663 | 9995fd4dfb9db089883241d24a617aa95caf0c7d964fa66dff38a3d6603091b9 |
| docs/incidents/2026-09-16-dtf-recovery/migration/package-evidence.md | 21926 | cd9e62951d4e635db2bb482908a20b53b0c0b97a3c7f130c8e23f46822723f5f |
| docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-9/traceability-disposition.md | 1552 | afd81c16d9072d0fff03f4dd41a6e3632567aef47363b2e52c8015789669df08 |
| docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-9/trace.md | 10045 | 4ca638ed0a8d487c601549c586350418b9af951d7ae5f8a396527e7b52ad795a |
| docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-9/evidence-review.md | 1633 | 83b3f611e425c0662c20512c0018aae0e682c47d6e1a9705d670e8b96cde3f35 |
| docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-9/reference-failures.md | 1189 | f4d78e6bcb16f5bda1e1f50b17302b6548788700f329cfb6c4aeddef5ea0f438 |
| docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-9/negative/proxy-census.one-byte-off.json | 5737 | 019496421514ea3bff4b26dbe12a58bf658939423a037b66747d39fe5788fadb |

Only this report and the final task-9-verdict.json are verifier-owned outputs. The verdict is written last. No fixes implemented, no delegation, no broader implementation or later-task confirmation.

