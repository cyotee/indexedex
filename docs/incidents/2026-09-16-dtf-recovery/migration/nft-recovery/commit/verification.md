# Independent bounded recovery source commit verification

Date: 2026-11-11.

**Verdict: confirmed.** Commit `421072a7630a0d3d47a6f36e1062d9eae98c93e2`
delivers exactly the independently accepted bounded NFT recovery source and
tests, including R1. No blob, mode, path-set, parent, accepted-source binding,
executable binding, unrelated-file, index or protected-ref mismatch was found.
This is a local source-delivery verdict, not full Migration acceptance,
permission to execute an operator graph, or release authorization.

No commit, source/test edit, suite, build, cache removal, public action, push,
merge or history rewrite was performed by this verifier. This report is the
only authored file. All audit commands have finished; no owned runtime is pending.

## 1. Scope and observed Git facts

The complete commit brief, phase07 NFT recovery brief, R1 correction mandate,
repository router, git-master instructions, implementation report, historical
needs-fix report, correction report, final independent runtime report, manifest
and producer receipt were read. The incident-relative prefix is
`docs/incidents/2026-09-16-dtf-recovery/migration/nft-recovery/`;
there is no root-level `migration/nft-recovery/` directory in this worktree.

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery`.
- Actual branch: `work/dtf-migration-phase-07-recovery`.
- Actual HEAD: `421072a7630a0d3d47a6f36e1062d9eae98c93e2`.
- Actual sole parent: `6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`.
- Exact changed set: 18 paths, four modified and 14 added, all mode `100644`.
- No report, witness, log, archive, cache, link or configuration path is committed.
- Current tracked and staged diffs are empty with submodules ignored.
- Commit whitespace checking completed with exit 0 and no output.

Every Git invocation used `GIT_MASTER=1`. Read-only evidence commands included
`git branch --show-current`, `git rev-parse HEAD`, `git show -s --format=%P HEAD`,
`git show -s --format=%B HEAD`,
`git diff-tree --no-commit-id --raw -r --no-abbrev HEAD`,
`git ls-tree -r COMMIT -- PATHS`, `git show COMMIT:PATH`,
`git ls-files --stage -z`, `git for-each-ref --format=%(refname) %(objectname)`,
`git status --porcelain=v1 --untracked-files=all --ignore-submodules=all`,
`git diff --ignore-submodules=all`, and
`git diff --cached --ignore-submodules=all`.
These commands were run with `-C` pointing to the worktree above.

The actual commit message is:

```text
Add verified bounded NFT Migration recovery

Retain selected weighted and earlier claim stages, fixed reserve donations, and separately accounted attributable receipt growth. Earlier liquidation and full Migration gates remain open.

Packaging follows .github/ASSISTANT_DEPLOYMENT.md.

Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>
```

The required trailer occurs exactly once, and there is no additional coauthor
trailer. The subject follows the observed recent `Add verified ...` convention.
Upstream/pushed status is not established by this audit; no remote operation
was used to establish it.

## 2. Exact paths, blobs and independently accepted bytes

For every row below, the SHA-256 of the actual committed blob equals the
current file-byte SHA-256, the manifest's accepted SHA-256, and the independent
`correction-verification/evidence.json` source fingerprint. Actual tree mode
and blob ID also equal the manifest, and current file permissions are `0644`.
The source indices are independently checked array positions in
`sourceBeforeAndAfter`, not producer success flags.

Prefixes:

- `M` = `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- `F` = `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- `S` = `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`

| Exact path using prefix | Change | Git blob | Accepted = current = committed SHA-256 | Independent source index |
| --- | --- | --- | --- | ---: |
| M/TestBase_UniswapV4DetfMigration.sol | M | `19a753c3c387c93c29fb17bdc4edb7255634d6e4` | `f174b8f04e56cd888e9552c8cb6612f7395a234a1d4690af2c0e20fc781878c3` | 171 |
| M/UniswapV4DetfMigrationDFPkg.sol | M | `bc385446ee7938b870067353de1c12a025225107` | `1d7adbe6ca125e296393ea7e474e4adfa891faba24bd65e40fc9bacafd7136e0` | 14 |
| M/UniswapV4DetfMigrationRecoveryFacet.sol | A | `0c73d52743d195a51ea80a7feead911292644bd4` | `c022a0bb1e493414e783b88c859f48f0f417a26ada6e00fcf9d9f68df86eb05c` | 13 |
| M/UniswapV4DetfMigrationRecoveryRepo.sol | A | `7fe98307d5dba2114de769cec75ccaf8aa227fd2` | `5ac4ffeb5305ba674f3c2c826e0cdc04b838de84a1be7f924175835fbdef4d96` | 1 |
| M/UniswapV4DetfMigrationRecoveryTarget.sol | A | `e4e163ac13d5a05d8b44d55aa574291a4b9aa1f7` | `6b2df5595199f88260341cff22900cbac1702763dabad8e274e6bdb4f0a21ca6` | 0 |
| M/interfaces/IUniswapV4DetfMigrationDFPkg.sol | M | `98d65e1de4552e171ad4017ef1e15a91ef5fb04b` | `33c8eaac6075c7ef6f2dc7fa1c1cb278c4c9baae1dfeb690d0213cbad0a3cad9` | 137 |
| M/interfaces/IUniswapV4DetfMigrationRecovery.sol | A | `16ed17704d6eba469fe70224f6329dd44cd837ba` | `7f592439b07701e7e1e605390970b9aa1777d150df416688073e9c85a73f5afe` | 2 |
| M/legacy/IMigrationLegacyRecovery.sol | A | `1e9e2fb7af460436bd3f8e6513e03da28aeb6fc3` | `0bf3b258a2d509d7d8809aafdd4b8b03c9f5e776b6608794f47343adc99cd024` | 4 |
| M/legacy/MigrationLegacyRecoveryLib.sol | A | `e4b7d4e90e8d430336a657cec54dd92d471608cc` | `4254b5152d6a051e75cdf321097c4da8ed5499e77e976c224bf86077d28f2169` | 3 |
| F/MigrationNftForkBase.sol | M | `491df519b835649c6f52ecba945fac44beebe12d` | `9de63a02c15f02074e7677957a8ae60063c46fd8229eb175eedea81712410bce` | 11 |
| F/MigrationRecoveryAccrual.t.sol | A | `d0540aebd8d6bf0e7643f632369d370c2dfce600` | `5cbf23c014a59eca21a0559d234e8fece1b1b54b7fce198573d7bbeda07d6a54` | 175 |
| F/MigrationRecoveryAccrualRollback.t.sol | A | `7cc716cf7c2298913be9a736b88f6a035b45d77d` | `9924864974c40195532228d12a126edc78ba1b76a70b7baf91f7a4697161daeb` | 188 |
| F/MigrationRecoveryDonation.t.sol | A | `2da0c26491ea91ce7cff3ae5a71a5c908d6d41e2` | `249adb97389119c06be4c3a747c26ca581d8711c11dc3011c3f5172fc9a425f9` | 8 |
| F/MigrationRecoveryEarlier.t.sol | A | `8d0438bd617a26b45eb5c4abadbff59a906efdc4` | `8f2daa439790573ddabec030ddea5b32ffad39e066cd7ecabb30558820b6ea93` | 7 |
| F/MigrationRecoveryForkBase.sol | A | `2ba13a54057c12a4d0c158d04fecbc3d8d4f4719` | `d91fa3ede91902214d7cd539b39fd5672b56d23652d7c6f2235014db11cb69c4` | 5 |
| F/MigrationRecoveryGas.t.sol | A | `d0fbeb47695ddbb606f7dd928213bc5049d560f3` | `f660ec8d78f2dd2bb98f33cfe25da47355b273d35fa889d26d368a29b1cee6ef` | 9 |
| F/MigrationRecoveryWeighted.t.sol | A | `877caea59afa46836f5fb9dbc73c30a21385d870` | `c7cdb93f6989c229b9f30ecf0d07fe38154b412467d32eb2e632bd26ee800778` | 6 |
| S/MigrationRecovery.t.sol | A | `470a09ae3aeae760468d068a51690ac6651b9998` | `d8d31dae7a71ca7bd81c59d64bdb3178e5629ebb0f8d14eb05d66d32aa9fc56f` | 10 |

All 193 independently captured current source/configuration/helper fingerprints
were recomputed and match. Every candidate's source locator resolves to its
own path and accepted hash. Applicable production metadata locators were
checked against the independent evidence, and all 226 compiler metadata/source
comparisons were independently recomputed.

The accepted independent baseline is
`correction-verification/baseline.json`, SHA-256
`e9f179017a97c76256cb974afcbb8f8baadba632666110eff8dfb95ee1f1f618`.
The committed four-file tracked delta equals its saved `trackedDiff` plus
exactly one terminal LF; there is no other difference. The actual tracked-diff
SHA-256 is `bc7aaf2c8ce24b64713ab9d288af081eb611bb9fbbe35832981ef9e0ff66b7a1`;
the saved string hashes to
`38f99f34ba84063d0f157107d05854a73ddd0ab113af51f0e6ab462904af0a00`.
Added files are bound by their exact independent file fingerprints, not
incorrectly claimed to be present in that unstaged tracked-only diff.

The complete actual committed diff hashes to
`7fbb25388ed43eee8b4b031a6a98e99fb2191f92a6c1c384b30eb6d2915fe374`,
matching the producer's staged-diff receipt.

## 3. Execution provenance and its qualifications

The independent runtime verdict is confirmed for R1 and preserved bounded
recovery. Its unchanged report SHA-256 is
`6e8277a67bea6851ea6eac0e218577c5a07d1f833c14f339263f65ea1bad452b`;
its machine evidence SHA-256 is
`6181888337481a732cd68e17bad293641f58708fd890d3bb8d10f33d32734a0d`.
The manifest itself hashes to
`9213fb095a1f64c27021fb1525433a55bfa77d406e49c96baf43cf8c5acd3bde`.

The two production artifacts were independently decoded and hashed. Actual
creation bytecode returned by the witness loader was separately read from
`correction-verification/witness-independent.log:7942,8045` and hashes to
the same accepted executable identities:

| Artifact | Creation-bytecode Keccak-256 | Runtime-object Keccak-256 | Metadata SHA-256 |
| --- | --- | --- | --- |
| Recovery facet | `0xb5c728e1d786308228f9d92388fc5483226229b9207f27d36dbde5f8f0ef1c02` | `0xaaf2fd3eb176808eb5d75442e3e1539f6ecc3520e2a150d6bfb13d5748f3401a` | `6c2b27369a773e253bd7b8068618ec4f0954dc279dd3562c8df2c6e5a4957ea3` |
| Migration package | `0xf9a8cc0c49ddc52cd96274b7354c089f66462f33243654970986e0d844a426c3` | `0x9af2487766db6cda2c85c8029ef698b7ee7a021d1cf21aa45588fc1da616dba5` | `1472c4d5c9944f5dc023b66953639f9eea43040347daae81e1c0316ffc12b36b` |

Ten current test artifacts match the manifest's envelope, metadata, creation
and own-source fingerprints. All 87 candidate-source references in their
compiler metadata were checked against actual source Keccak-256. These checks
connect current saved artifacts to exact accepted test/fixture sources.
They do not manufacture previously captured independent test executable
fingerprints: the independent evidence saved production executables and
source identities, not a historical executable hash for every test artifact.
This qualification does not leave a missing candidate-source binding.

Source SHA-256, compiler source Keccak-256, metadata SHA-256, complete artifact
envelope SHA-256 and executable Keccak-256 are distinct checks. Package
runtime-object identity is not the identity of immutable-populated deployed
runtime. The witness wrapper's `tee` captures its script, not the preceding
third build's stdout; the two saved test-driver transcripts and actual loader
bytes establish the accepted artifact-first chain. No third complete build
transcript or new execution is claimed.

All nine retained execution logs were rehashed and their actual terminal
result lines read, rather than copying producer result flags:

| Saved evidence | Actual retained result |
| --- | --- |
| correction-verification/fork-independent.log | 22 passed, zero failed/skipped, five suites |
| correction-verification/spec-independent.log | Five passed, zero failed/skipped, two suites |
| correction-verification/witness-independent.log | Script ran successfully |
| correction/fail-before.log | Zero passed, one failed; deliberate original R1 failure |
| correction/passing-after.log | One passed, zero failed/skipped |
| correction/fork-current.log | 39 passed, zero failed/skipped, eight suites |
| correction/spec-current.log | 96 passed, zero failed/skipped, 16 suites |
| correction/terminal-current.log | One passed, zero failed/skipped; traced existing case, not an additional distinct case |
| implementation/regression-01.log | 9,932 passed, zero failed/skipped, 589 suites |

The ordinary/common log retains SHA-256
`89a4da6fa44bfdd43233a5293dc1ea6152b9204cb5b714518f3436ccbc810fb0`.
Its results are historical, source-bound retained results, not a rerun by the
correction verifier or this commit verifier. All current accepted captured
source inputs match; no ordinary/common production path enters this commit.
Recorded successful wrapper exits remain historical execution evidence,
not newly observed execution exits from this audit.

The historical needs-fix report and original failure witnesses remain
unchanged. They are superseded for corrected R1 acceptance, not relabeled as
successful harvestability evidence. Historical chain 4663 / block 108944663
executions remain in-process local-fork evidence; no public or mined Anvil
transaction is implied. Archive `match` versus `exact_match` qualifications,
missing earlier source, and the absence of an independent complete legacy
recompilation/transitive audit remain intact.

## 4. Preservation independently checked

Index serialization is consistently raw `git ls-files --stage -z`, including
NUL separators, excluding stat-cache implementation bytes.

- Reconstructing stage-zero entries from the actual parent tree yields
  `dfb2087191eee7ee31af3502c765b2d06969c9923a8a9a4025272711160c3d49`,
  matching the recorded initially unstaged index. The recorded initial status
  has only unstaged modifications/untracked candidates, not foreign staged work.
- Removing exactly the 18 candidate entries from the current index yields
  `c76b95893bd5cf8e470d6d18993737340aca78ca60edcaf82a758d6b077a8d25`,
  matching the precommit outside-candidate baseline.
- The full postcommit index hashes to
  `bb0dd80914f47c59fb1ab7286c41268856c1ab1907747f96ec6f15d8bfd04383`.
  The verifier's initial and final serializations are byte-identical.
  Current staged diff is empty.
- All 23 baseline unrelated/untracked files retain their exact hashes and
  untracked status. The status set outside `commit/` equals the baseline
  outside the committed candidates. The receipt and manifest remain untracked.
- All 45 pre-existing recovery evidence files, including ignored logs,
  retain exact path, permission mode, size and SHA-256 against the manifest.
  All 38 independently captured prior evidence fingerprints also match.
- Warm recursive inventories were recomputed with the declared directory-wise
  `localeCompare` order and `{path,mode,size,mtimeMs}` serialization:
  `out/`, 7,299 entries, SHA-256
  `edb26d8e6e16079e0d5b157d3ec3a0ad53715a26e8d816d386e81eaea0f99a10`;
  `cache_forge/`, 511 entries, SHA-256
  `9ac15aad215cd2f0815b2218922e5b25d4fe14e08002f474accd219c8d706443`.
  Both match exactly. These are stat inventories, not every-cache-byte hashes;
  accepted executable and test artifact identities were separately checked.
- `lib/crane` remains the symlink
  `/Users/cyotee/Projects/indexedex/lib/crane`.
- The complete current ref serialization equals the producer's baseline with
  only the required recovery branch advanced from the parent to this commit.
  It also remains identical between the verifier's initial and final reads.

Protected refs specifically remain:

```text
refs/heads/main 90ff0307a7a8e084aa073e02eff125e9c7973933
refs/heads/work/dtf-migration 6e27ecaa242c4acca132e3575a160514aad07b11
refs/remotes/origin/main 90ff0307a7a8e084aa073e02eff125e9c7973933
```

## 5. Limits, audit issues and completion

The initial report-path lookup omitted the documented incident prefix and
returned ENOENT; the correct files were subsequently read. An unsupported
resident Keccak algorithm and missing module paths were replaced with the
already installed local `@noble/hashes` implementation. One helper binding
was restored before continuing. Large-file grep explicitly reported partial
coverage; no absence was inferred, and actual log tails were read instead.
The production artifact JSON exceeds read-tool line limits; its cryptographic
and metadata comparisons used resident parsing, with actual trace-return bytes
checked independently. These were audit harness issues, not source mismatches.

No duplicate runtime suite was run, and no broader code review was substituted
for this source-delivery audit. Current process inspection found no Forge or
Anvil process, and this verifier started no persistent process, listener or port.

R1 and the bounded W1-W3, ER1-ER2 and supported DTF W4 delivery are confirmed.
Earlier disabled close/receipt exits, unproved earlier liquid conversion,
masked legacy authorization exposure, missing source, E2 attribution, general
harvest, other original source categories, operator/resume, broader
integration/invariant/gas and all original full-plan release gates remain open.
This report neither enables those routes nor authorizes public execution.

**Final disposition: confirmed for this exact bounded local source commit.
No mismatch and no pending owned runtime.**
