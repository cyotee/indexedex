# Bounded NFT recovery local source commit receipt

Date: 2026-11-11.

**Source delivery: verified.** Exact accepted source/test bytes were committed locally. This is the producer commit receipt; the separately scoped independent delivery audit may write `verification.md`. It is not full Migration acceptance or release authorization.

## Commit and scope

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery`.
- Branch: `work/dtf-migration-phase-07-recovery`.
- Full source/test commit: `421072a7630a0d3d47a6f36e1062d9eae98c93e2`.
- Sole parent: `6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`.
- Exact changed path count: **18** (4 modified, 14 added; all mode `100644`).
- Diff: 1,602 insertions, 11 deletions.
- Fully inspected staged diff SHA-256: `7fbb25388ed43eee8b4b031a6a98e99fb2191f92a6c1c384b30eb6d2915fe374`.
- Manifest SHA-256: `9213fb095a1f64c27021fb1525433a55bfa77d406e49c96baf43cf8c5acd3bde`.
- Only listed production/test paths were staged; no broad directory staging. The initial index had no staged changes.
- Manifest, this receipt and all prior evidence are deliberately outside the source/test commit. No source/test edits were made by this delivery task.
- Upstream is not configured; pushed status is unknown. No push, fetch, merge, rebase, public action or history rewrite was performed.

Actual commit message (exactly one required coauthor trailer):

```text
Add verified bounded NFT Migration recovery

Retain selected weighted and earlier claim stages, fixed reserve donations, and separately accounted attributable receipt growth. Earlier liquidation and full Migration gates remain open.

Packaging follows .github/ASSISTANT_DEPLOYMENT.md.

Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>
```

## Exact committed paths and byte equality

For every row, accepted SHA-256 = current file SHA-256 = actual committed blob SHA-256. Modes and Git blob object IDs were checked against `git ls-tree`; blob bytes were read with `git show COMMIT:PATH`. The manifest records each independent acceptance locator and metadata binding.

| Path | Accepted = current = committed SHA-256 | Git blob |
| --- | --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol` | `f174b8f04e56cd888e9552c8cb6612f7395a234a1d4690af2c0e20fc781878c3` | `19a753c3c387c93c29fb17bdc4edb7255634d6e4` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol` | `1d7adbe6ca125e296393ea7e474e4adfa891faba24bd65e40fc9bacafd7136e0` | `bc385446ee7938b870067353de1c12a025225107` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryFacet.sol` | `c022a0bb1e493414e783b88c859f48f0f417a26ada6e00fcf9d9f68df86eb05c` | `0c73d52743d195a51ea80a7feead911292644bd4` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryRepo.sol` | `5ac4ffeb5305ba674f3c2c826e0cdc04b838de84a1be7f924175835fbdef4d96` | `7fe98307d5dba2114de769cec75ccaf8aa227fd2` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol` | `6b2df5595199f88260341cff22900cbac1702763dabad8e274e6bdb4f0a21ca6` | `e4e163ac13d5a05d8b44d55aa574291a4b9aa1f7` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationDFPkg.sol` | `33c8eaac6075c7ef6f2dc7fa1c1cb278c4c9baae1dfeb690d0213cbad0a3cad9` | `98d65e1de4552e171ad4017ef1e15a91ef5fb04b` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol` | `7f592439b07701e7e1e605390970b9aa1777d150df416688073e9c85a73f5afe` | `16ed17704d6eba469fe70224f6329dd44cd837ba` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol` | `0bf3b258a2d509d7d8809aafdd4b8b03c9f5e776b6608794f47343adc99cd024` | `1e9e2fb7af460436bd3f8e6513e03da28aeb6fc3` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol` | `4254b5152d6a051e75cdf321097c4da8ed5499e77e976c224bf86077d28f2169` | `e4b7d4e90e8d430336a657cec54dd92d471608cc` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftForkBase.sol` | `9de63a02c15f02074e7677957a8ae60063c46fd8229eb175eedea81712410bce` | `491df519b835649c6f52ecba945fac44beebe12d` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryAccrual.t.sol` | `5cbf23c014a59eca21a0559d234e8fece1b1b54b7fce198573d7bbeda07d6a54` | `d0540aebd8d6bf0e7643f632369d370c2dfce600` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryAccrualRollback.t.sol` | `9924864974c40195532228d12a126edc78ba1b76a70b7baf91f7a4697161daeb` | `7cc716cf7c2298913be9a736b88f6a035b45d77d` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryDonation.t.sol` | `249adb97389119c06be4c3a747c26ca581d8711c11dc3011c3f5172fc9a425f9` | `2da0c26491ea91ce7cff3ae5a71a5c908d6d41e2` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryEarlier.t.sol` | `8f2daa439790573ddabec030ddea5b32ffad39e066cd7ecabb30558820b6ea93` | `8d0438bd617a26b45eb5c4abadbff59a906efdc4` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryForkBase.sol` | `d91fa3ede91902214d7cd539b39fd5672b56d23652d7c6f2235014db11cb69c4` | `2ba13a54057c12a4d0c158d04fecbc3d8d4f4719` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryGas.t.sol` | `f660ec8d78f2dd2bb98f33cfe25da47355b273d35fa889d26d368a29b1cee6ef` | `d0fbeb47695ddbb606f7dd928213bc5049d560f3` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryWeighted.t.sol` | `c7cdb93f6989c229b9f30ecf0d07fe38154b412467d32eb2e632bd26ee800778` | `877caea59afa46836f5fb9dbc73c30a21385d870` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecovery.t.sol` | `d8d31dae7a71ca7bd81c59d64bdb3178e5629ebb0f8d14eb05d66d32aa9fc56f` | `470a09ae3aeae760468d068a51690ac6651b9998` |

## Accepted execution retained, not rerun

The complete `correction-verification/report.md` gives **confirmed** for R1 and the preserved bounded recovery. Its SHA-256 is `6e8277a67bea6851ea6eac0e218577c5a07d1f833c14f339263f65ea1bad452b`; its machine evidence SHA-256 is `6181888337481a732cd68e17bad293641f58708fd890d3bb8d10f33d32734a0d`. The historical `verification/report.md` remains needs-fix evidence, not overwritten or relabeled.

- Recomputed all 193 independent current-source fingerprints and 226 production metadata/source comparisons; each matches. All 18 candidates have exact independent source identity plus applicable production or test metadata bindings. Recomputed 87 candidate-source references in current saved test metadata.
- Production creation-bytecode, runtime-object and metadata fingerprints match the independently accepted values. Complete artifact-envelope, metadata, source and executable hashes are explicitly distinguished in the manifest. Current test artifact fingerprints are not falsely presented as previously saved independent test executable hashes.
- Rehashed nine retained producer/independent logs. Independent execution remains 22 pinned cases, five focused hermetic cases and one composition witness; retained producer execution remains 96 Migration specs and 39 pinned cases.
- The original 9,932 ordinary/common passes remain bound to `implementation/regression-01.log`, SHA-256 `89a4da6fa44bfdd43233a5293dc1ea6152b9204cb5b714518f3436ccbc810fb0`; no rerun is claimed. Deliberately failed before-correction and historical adverse evidence remains preserved.
- **Zero builds, suites or runtime witnesses were rerun solely to commit identical bytes.** Staged whitespace checking passed with exit 0. Manifest JSON parses successfully. JSON LSP remains unavailable because `biome` is not installed; no install/configuration change was made.

The saved accepted tracked diff omits one terminal LF; the actual diff includes it. Only this presentation delimiter differs; trimming trailing newlines yields identical diff content, and every exact file-byte acceptance hash matches. This is recorded rather than treated as a source change.

## Preservation and protected refs

- The initial index serialization was raw `git ls-files --stage -z` (NUL delimiters retained). Full initial SHA-256: `dfb2087191eee7ee31af3502c765b2d06969c9923a8a9a4025272711160c3d49`.
- Both before and after, removing exactly the 18 candidate entries from that same serialization yields SHA-256 `c76b95893bd5cf8e470d6d18993737340aca78ca60edcaf82a758d6b077a8d25`. No unrelated index entry changed; the final staged delta is empty. Index stat-cache byte differences are not confused with entry identity.
- Tracked worktree diff is empty after commit. All 23 pre-existing unrelated/untracked files remain unchanged and uncommitted; their exact paths/hashes and original status are in the manifest. The new commit artifacts remain untracked too.
- All 45 pre-existing recovery evidence files (including ignored full logs, adverse witnesses and reports) retain exact path, mode, size and SHA-256. All 38 previously accepted evidence fingerprints were also checked. Nothing historical was edited, moved, staged or deleted.
- Warm `out/` (7,299 entries) and `cache_forge/` (511 entries) retain exactly the original recursive path/mode/size/mtime stat inventories. This is a stat-inventory preservation check, not a claim to hash every cache byte. Accepted production executable hashes and saved test artifact hashes were checked separately.
- Existing `lib/crane` symlink remains `/Users/cyotee/Projects/indexedex/lib/crane`; dependencies and configuration were untouched.
- All refs except this task branch match the complete baseline. Main and integration references specifically remain:

```text
refs/heads/main 90ff0307a7a8e084aa073e02eff125e9c7973933
refs/heads/work/dtf-migration 6e27ecaa242c4acca132e3575a160514aad07b11
refs/remotes/origin/main 90ff0307a7a8e084aa073e02eff125e9c7973933
```

Complete before-ref serialization is preserved in `source-manifest.json`; the target branch alone advances from the stated parent to the stated source commit.

## Remaining gates and cleanup

R1 and the bounded weighted/earlier claim-holding, admitted conversion and supported donation stages are delivered. Earlier disabled exits, missing earlier liquid conversion/source coverage, masked legacy authorization exposure, E2 attribution, general harvest, other source categories, operator/resume, full integration/invariant/gas and all original full-plan release gates remain open. Nothing here enables a blocked route or authorizes deployment, funding, activation or compensation execution.

No owned runtime, compiler, suite, node, port, public operation or cleanup is pending. Prior accepted executions already terminated; this task started none. Warm artifacts, prior evidence and unrelated work are preserved. No push or merge occurred.
