# Claim-vault EOF formatting follow-up

Date: 2026-11-12. Status: **local formatting commit complete**. This is not a new runtime acceptance, not target-gas acceptance, and not a public delivery.

## Exact local commit

- Commit: `a96f0fd26c1a1fdba35750cff74d866afa3a9796`
- Subject: `Remove trailing blank lines from claim-vault delivery`
- Parent: `9c227900b280713305d4a1a1d1cdc3d8d273f23d`
- Parent tree, unchanged: `d0729eb87d2ab3c5f22b12e2bef0549226ba4239`
- Tree: `a8501a387801b15c7dabad6f5498893b439ba028`
- Author and committer: `Cyotee Doge <not_cyotee@proton.me>`
- Author and commit date: `Wed Nov 11 19:47:59 2026 -0800`
- Branch: `work/dtf-migration-phase-16-claim-vault`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-16-claim-vault`
- Exactly one parent. `git rev-list --count 9c227900b280713305d4a1a1d1cdc3d8d273f23d..HEAD` is 1. `4a53299b490343ed904d70c92ecbc7360fcb7659..HEAD` contains exactly two commits: the retained needs-fix delivery and this follow-up.
- Exactly **9 paths**, 0 insertions, 9 deletions. Each deletion is the one trailing blank line named by the original D1 audit.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`. It was passed with `--trailer`, not embedded in `-m`. `trailer.ifexists=addIfDifferent` was set. The committed message contains that trailer once.
- No amend, reset, rebase, or other history rewrite. `9c227900b280713305d4a1a1d1cdc3d8d273f23d` remains intact.
- No upstream is configured. No fetch, push, PR, or merge was attempted.
- This manifest, this receipt, and the follow-up baselines are excluded evidence. They are not in the commit.
- `source-manifest.json` raw SHA-256: `3f1540442e07c845a1ea0d9e9c21d34333da7e4577906a59b9e9a0a933a55220`.

## Admission used

The commit was made only after reading the original needs-fix audit and the actual F1 closure.

- `commit/verification.md` remains needs-fix for `9c227900b280713305d4a1a1d1cdc3d8d273f23d`. SHA-256 `55a9eb3f128addf8f10d668015ff7c97985418bb2726534cc86e4bcab73751a3`.
- `format-verification/report.md` remains the historical needs-fix F1 bookkeeping report. SHA-256 `c18b2c9adbddaa6190bda525c8f2302e6276b35ce44b4f8ba50bbcd7cbd16656`.
- `format-verification/f1-closure.md` is the admitting record. Disposition: confirmed. F1 closed. Corrected-source candidate admitted for this separate nine-file commit. SHA-256 `6b05e38451153544db3021508104ca08687c786abe3c931c6ff6980639be227b`. Supporting `f1-closure-evidence.json` SHA-256 `10d598360b2f5cd59b764cf64953164e987fa68aa97df698a26637cf7c789e61`.
- `format-correction/report.md` SHA-256 `0f1249a50b5a210df8ef77967ad00b8096c89ebbb2e143ac9406adc4797dd8fb`. Its seal still binds 411 files and SHA-256 `d0c49aac0d178f589d626a8639ce9790db92abcebc5eb6a287543057a3885934`.
- `format-evidence-correction/` is the admitted additive correction and was not edited.
- The negative `format-commit/verification.md`, `audit-checks.json`, `audit-preservation.json`, and `audit-closure.json` were retained. Their pre-commit SHA-256 values are `54d4df79b8d769d685061506dd26d2acf5466284d552bbab54f3732f5d6c9167`, `6b2bd5db3426c0532a7586b44c37c71c4e9bf58cfb777031a6bab09cdaefe687`, `e4e588b466e6b25de6a507891ad3082ebfce5bd7c93b4ac286ff303621806eaf`, and `a7119a66bd1002119c1807415815863ed582fccaaeede3627d5baef0d079144d`.

Verifier writes had stopped before staging: the closure and its evidence were not open, no matching forge/anvil/worktree process was running, and port 18566 had no listener. This commit did not rerun specs, forks, operator tests, types, stages, or the fixed18566 CLI.

## Source binding

`source-manifest.json` binds all 40 accepted paths. The nine corrected paths are the D1 files. For each, current bytes, the committed blob, and the corrected accepted SHA-256 are equal, and the parent blob is those bytes plus one final `0x0a`. The other 31 paths are byte-identical across current, committed, parent, and prior accepted hashes. All 40 modes are `100644`. `core.autocrlf` is unset. No other source byte was modified.

| Path | Parent SHA-256 | Corrected SHA-256 | Parent blob | Commit blob |
| --- | --- | --- | --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationClaimVaultAllocationFacet.sol` | `68feefdf017cfe787974c064aec7d0d503afcbe6e628ceabf7ede2ac92d9faff` | `007efb814785b8a5a28336785a74ff80b135ecc236f023f3e679aac15938f788` | `0d205254a2b4a13383150445adae1523fadf2384` | `4babbc5128d6cd264699a52f83c97856e30ce29e` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol` | `334ae5220153279d0efec14358eaea3557c07e816abd681b238f29c61156832e` | `f575db5e7baa8acd986772963124e07d914cc79125598fcd70f47ac7a1632945` | `54a211604ae8996575f8113affd2e5a31af076e0` | `aa1d49db10dcf185707feea84d0d1402c4937302` |
| `scripts/recovery/dtf-migration/claim-vault.test.ts` | `c69bb69a7d4bba7da3d0fdcbdfecc10726513adac13867a5768b7744af9d03c3` | `08983f862f6f5ebd0b679f87e43d6a62f4b475bfbd34fce38be4450998c8d3ae` | `dfde1879ba2ed1d946cb2db4476f4bd411526d31` | `0900d108b61881dcdb5deb013c33988fcadd3569` |
| `scripts/recovery/dtf-migration/rehearsal-claim-vault-source.ts` | `1d425490f4174715a38fee71911a8620253ea14c0a6813120faae8316c7baa1a` | `80bc8e357b774890b83e03707eeacafd566ef35c66ff9fc02483fb25e844a93f` | `7727b062b9b004d58356555a67a48a3867f73165` | `7b267457c349f7fabed066086b2137d28fa68ce3` |
| `scripts/recovery/dtf-migration/rehearsal-claim-vault.ts` | `fa01045025033561fcc8b20b667e1b564ec3503edf5c074a1aa7a001ed1b0eae` | `71211c2c3ace5f7735a9f85d315e03d9749f52754ac6ada3b60fc2b54053a6f6` | `07833b37a53267ce2cd0f56d163faa7fd4fbd62b` | `70c955c5c10670f1c13d2687f651869a62f93ce2` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationClaimVault.t.sol` | `cb8d4ec86caed7cfae6b0f99aeae7aeef978bedfb524423b800f6a0673000d78` | `7be0cc5440fee63ff9bbdcdd7c3397dde0b545889e83c5e19462b30c4917e425` | `3d7b2bcde51365ed6f5cdd397372abd3011e921d` | `e99f4de01e3aef5cd736fa1fcd30403ceda72550` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationClaimVaultForkBase.sol` | `5f6c38945129eaaf66c7f03bd41dc4f91f7d19b7a43f70fc678c20bb53a20cbd` | `33e9f1b77ece6b8804e79816b1df462a3818c9ea1d4f05059047963f8c214dfe` | `ec83b05a2e9f7db4fa886f23f3b4e5fa98d1fee1` | `aeada9d4759d88e943b9166d2615ddab4bb112c0` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryClaimVault.t.sol` | `59737e67042cf409e75fb23bd484b497ed7db879a805066a67c301d40103dc7f` | `374dcaaeaf0ce1fc1de10ae53a1bf4865ff2e25389c0265ab7596f4954c4b5f2` | `5c5fa07c4e2367e8d6e81894ea273eaf7bd218ae` | `3e2110371d40a8781c8875b0bbfd1b28464bf4cd` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationClaimVaultConfiguration.t.sol` | `50673dc339dad69e04755637445b4b6611ca37c364624b2d6b56700af5abf3c4` | `cc2b903a19fdb08e4fe854fab8c772596ca899b9d1b3c20edb22c80b0768ae9f` | `7c0fc6dcfe86d325e3d57e78f4416f96227d13f2` | `71dc4566a31a2690f4a4834ea97502993cc0b2e8` |

The full pre-commit diff is `followup-precommit-diff.txt`, 5139 bytes, SHA-256 `65fb195742633308293bf728601a0d507de0a5c5efc68b73936cab4af858511e`. It contains nine deleted blank lines and no other hunks. `git diff --numstat HEAD^ HEAD` is `0` additions and `1` deletion on each of the nine paths.

## Whitespace gate

Failed whitespace was treated as blocking. Accepted hashes were not a waiver. Every Git command used `GIT_MASTER=1`. Status and diff used `--ignore-submodules=all`.

Before commit, after staging only the nine paths:

```text
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check 4a53299b490343ed904d70c92ecbc7360fcb7659
GIT_MASTER=1 git diff --ignore-submodules=all --check 4a53299b490343ed904d70c92ecbc7360fcb7659
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check
```

All three exited 0 with empty output. The staged set was exactly the nine paths, and each staged blob matched the working-tree bytes.

After commit:

```text
GIT_MASTER=1 git diff --ignore-submodules=all --check 4a53299b490343ed904d70c92ecbc7360fcb7659 HEAD
```

exited 0 with empty output. Staged and unstaged tracked diffs were empty. The immutable `4a53299b..9c227900` check still fails, as required: that historical commit was not rewritten.

## Preservation

Recipe: `followup-recipe.txt`, SHA-256 `034a65e8fa66b74caa77257f5cea6bbdcbdbfc9f2ef213514c450ffa01ecbf8e`. Walks finished before any `followup-*` file existed. Those files, this receipt, and `source-manifest.json` are excluded evidence. No build, deletion, chmod, cache write, or runtime rerun was performed.

| Baseline | Entries | SHA-256 | Post-commit rewalk |
| --- | ---: | --- | --- |
| `followup-docs-incidents.jsonl` | 1434 | `f0064eb25bb02ee41afb468b8fe6679a6f6591a64106a5d0f2523443092dea97` | 0 missing, 0 changed; 10 excluded follow-up files added |
| `followup-docs-incidents-perms.jsonl` | 1654 | `b5b65236323e280afebae7d4f293e526c4d9c2fac0257042790829f0f3a49a8a` | 0 missing, 0 changed sealed modes or file hashes |
| `followup-out.jsonl` | 7329 | `4a15a2bcaf9c7a58737488f7555bc7cc81ceee1a6f40892c0150b6c760bd7e15` | 0 missing, 0 changed, 0 added |
| `followup-cache-forge.jsonl` | 596 | `b43394f01976318bbaf8fa412628def718da9b2db2fbcba9dff5f9a7ce09847b` | 0 missing, 0 changed, 0 added |
| `followup-refs.txt` | 5319 bytes | `e01625e90063ad6f5d84e2aafd2a43c4471fda28a1a7024c78079f07843cfa6c` | only this branch moved |

The only permission-inventory directory-size change is `format-commit/` itself, `192 -> 512`, permission still `0o755`, caused by the ten excluded baseline files present at the rewalk. This receipt and `source-manifest.json` were written after that rewalk and are also excluded. No sealed file was rewritten or chmodded.

- Phase15 archive `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-15-dtf-custody-se/docs/incidents/2026-09-16-dtf-recovery/migration/dtf-custody-se/implementation/source-archive.json` remains 1047506 bytes, mode `0644`, SHA-256 `600c072adccc5e624333fd3dfd511787a3d89868193b320efdb8cbfc912483e7`.
- `lib/crane` remains a symlink to `/Users/cyotee/Projects/indexedex/lib/crane`, inode `18755930`, mode `0755`. `node_modules` remains a symlink to `/Users/cyotee/Projects/indexedex/node_modules`, inode `18755931`, mode `0755`.
- Sixteen foreign worktree indexes are unchanged. This worktree index changed from `90fcbe92225a40a47f145bb8f9ef2efffc3d395d9df343dd424f0830b69a3221` to `f18d287fdf541739bd300e9ab60fd0ebc93dba805b542a16a65c80d94d1e8b59`, size still 2070332, mode `0644`. The index matches the new commit: staged diff empty.
- The only ref movement is `refs/heads/work/dtf-migration-phase-16-claim-vault` from `9c227900b280713305d4a1a1d1cdc3d8d273f23d` to `a96f0fd26c1a1fdba35750cff74d866afa3a9796`. No new ref exists.
- No merge, cherry-pick, revert, rebase, or index lock is present. Incoming staged set was empty. No assume-unchanged or skip-worktree entry was present.

## Limits that remain open

Exact archived or deployed claim-vault source equivalence is unestablished. The retained phase15 W-SD archive dependency remains. Operational originals, other source categories, full hermetic/full-plan/portable-F3 completion, and target-gas acceptance remain open. The recorded parent deployment receipt of 44,099,850 gas was not rerun and is not target-gas acceptance. Root's 130 specs, 81 forks, 64 operator tests, strict types, both operator stages, and the actual fixed18566 CLI with three decoded resumes are existing reviewed execution results. They were not replayed for this whitespace-only commit.

No held09 content was inspected, imported, or committed. No dependency, configuration, or provider change was made. No public action occurred.

**No pending operation.**
