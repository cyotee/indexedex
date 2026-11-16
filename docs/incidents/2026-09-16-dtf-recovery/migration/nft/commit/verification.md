# Independent NFT committed-byte verification

Date: 2026-11-11.

**AdversarialVerify: confirmed.** The actual committed increment matches the accepted bounded two-generation NFT implementation and its qualified execution evidence. Preservation checks pass. This is not full Migration, recovery, operational-data, deployment or release acceptance.

## Commit and exact scope

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-05`.
- Branch: `work/dtf-migration-phase-05`.
- Actual commit: `6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`.
- Sole actual parent: `5021e8d4a62bcbddc555f580ef98f8666d993aab`.
- Actual tree: `7a7cfe1e494a26e49e2347afde5e435f234593c9`.
- Subject: `Add verified two-generation NFT Migration surrender`, consistent with recent local imperative subjects.
- Exact coauthor trailer occurs once, as a standalone message line and once in the complete body: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`.
- Actual parent-to-commit path set is exactly the manifest's 18 source/test candidates: 11 Migration files (including TestBase), four specification files and three fork files. Every committed/index mode is 100644; current files have no executable bits. No evidence, witness, dependency, configuration, cache or unrelated path is in the commit.

Commands independently executed with `GIT_MASTER=1`, `GIT_OPTIONAL_LOCKS=0`, `git --no-pager` and the named worktree as cwd include `show -s --format=raw HEAD`, `diff-tree --no-commit-id --raw -r --no-abbrev HEAD`, `ls-tree`, `show HEAD:<path>`, `show :<path>`, `ls-files --stage -z`, `for-each-ref`, and submodule-ignored cached/working diffs. All completed inspection commands exited 0. Actual raw outputs, all blob/mode/hash rows, metadata joins and preservation hashes are in `verification-evidence.json`, SHA-256 `ebdda0d97717fa7a1ea836aa94ac1487bd11c9287690210d8f40ae691980d052`. No producer pass flag substitutes for those comparisons.

## Exact blob equivalence

For every row below, committed blob bytes = actual indexed bytes = current file bytes by separately computed SHA-256. Git object IDs were obtained from the actual commit tree, not copied from the manifest. Each also matches its manifest blob ID and current SHA-256. All 18 modes are 100644.

| Path | Actual committed Git blob | Committed = index = current SHA-256 |
| --- | --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol` | `af34dbdab9bbfc3c040818fd3c45c5ddb59e3bac` | `3fc1997e34be0d40e6fb638fc6cc759d9333546df97ebebc97583522666dab4e` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` | `e953ad8e364ffcf91979b046ec0fa65fd0928b21` | `903c1911a54398ef3a16a2f5007526530163aa68c502730f9cfd6581e388acdf` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol` | `c45f5e9f99bccaea7a9f1372848af412af2f4784` | `a6835808e586eed607b91aa6ec545189026a3a0d7a1ad1609af38e2ffcde6532` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationFacet.sol` | `28b1796d39fa812ac039a4664c272175cd7d069c` | `7f5365fcf5f4d91b3b08963a7239300ef6962a64eb95a9055b97f5ae6c8073d7` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol` | `1674f1c98a5486b9ec94354552364dca773d735c` | `a18a4e44c739873a694c0caa27abbc1e0e1515f22d6391a81f0d2ab689bbe40e` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationTarget.sol` | `5d08568f17fe789d67b3bb42ea810c80d07ce74b` | `93b12ed360332a3b78649407002a43f207fc8dfdeaadf9f1e0c6608584f4c8e3` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/IUniswapV4DetfMigrationBondNFTVault.sol` | `f98e487ab7a8afda0fcce7c23e61cf8b6980dd11` | `1feaa1299df7459978cacc8eea70a63e20f9f0cbe66dc807efe29e098bae7e53` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol` | `6edcb45c6cc06533bc81f134d4a65d2c3ba5c7e0` | `bc6162ee4c60cd23a44337f1c9dc57cfbd37258d7ae591c47db1da49878e325d` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol` | `5b18890f8918458e91ab188f3f685cdfb06fa792` | `dc0fd10bd5b3d345cfecbc5d9282884c1c2d3b0d983eeef846a8aff33cf79c2d` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyNft.sol` | `21d3ea5a38730b25c232ee2de46e0a60724013b3` | `282903679430d3be4a6f2e0370a6be0dbaedf34c5e50dfa7c7243f69c26be395` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyNftLib.sol` | `0cbc1b15e5dadce4d83287e2ca8d8591204a5bca` | `aa927b281d84741b7e71f47bcfea0fe1ca8c0dc5d12b18e6bcf3787d1ec994c3` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol` | `4c075d289693e4a59bcd3f6a818dfa9c66571222` | `098bc174b787a504757e455d242de9b4df279f21d56a554172556e2fdb0d966c` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftForkBase.sol` | `8a076100a9cd17d5c10e589771868e101a97ab50` | `cab0fddc254598c5b8307a73d98fdd316aae7428ada96ef912920de49e0d6660` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftLifecycle.t.sol` | `804646499b2b6681b28bacbcdf9fed980cecc6e9` | `d86e60fe414ec3bbbd5e6716369b5ec786c2f88dffc52cd435251f7577f977fa` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationCore.t.sol` | `8fb34aa2fe1b837b86c20d97d6d69b5b26c0672b` | `804bacac1d4323f83e8087aea2f6e0c75dda7389aafd2ad5a53d6d29eaaa9eec` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHostileContribution.t.sol` | `04742b97934fe4ac620ca80231f911d9e935fc01` | `b35e791ba05df2d7b9988e9e346ea6b8c76c83dd1307ecb05894fca326c2215e` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftConfiguration.t.sol` | `d73705dcba4febaae5b95d2258a2d23015c04338` | `b0443d9613a28e015ff893c09a857e4372e0c19249d3b7c9d0b9866065e256d4` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationSurface.t.sol` | `3e0d5f52744583850d3c780c05ff9145c0f5935b` | `75aa15aea842b5a8e3ea2d356d653b35efed96652be91294e49949abb53c6a9b` |

## Binding to accepted production and execution

Read the complete commit brief, phase05 scope brief, implementation report and independent runtime report, and parsed the actual complete `source-manifest.json`, `receipt.md` and independent `verification/evidence.json`. Input hashes are recorded below and in supporting evidence.

**Production:** independently recomputed SHA-256 and Keccak-256 for all 215 dependencies in the independent `metadataSourceBindings.sources`; all match. The ten changed production files (not TestBase) match those independent accepted hashes directly. The four current production artifacts' raw metadata source maps contain exactly those 215 unique identities. This includes the two newly tracked adapter files, which are not covered by the old tracked-diff hash.

**Tests and TestBase:** independently inspected six current executable test artifacts, their `rawMetadata`, compilation targets, method identifiers and source Keccak-256 values. Every committed test/TestBase/fork-base source has the matching compiled metadata identity. All test methods match actual PASS names in the hash-checked saved logs: LegacySources 10, Lifecycle 6, Configuration 8, Core 9, HostileContribution 2, Surface 4. The TestBase is a dependency of all six targets; fork base is a dependency of the two fork targets. Core/HostileContribution/Surface use the audited producer `spec-02.log`; the fork/configuration targets use independent execution logs.

**Test-binding qualification retained:** the independent 215-source map does not contain test files or TestBase. Current compiled test metadata plus exact successful suite/method joins support this delivery; they are not an independently recorded historical cryptographic seal of the untracked tests or test-artifact JSON at execution time. Current artifact-file hashes match the manifest's later inspection hashes, not a fabricated earlier verifier hash. The report confirms this explicitly qualified evidence chain, not a stronger historical test-byte attestation. Missing historical hashes remain missing.

Reconstructed the accepted delta using the actual parent/commit and only the 12 paths tracked at the parent. Raw SHA-256 is `72f77e4bf77e5505e6a8aa2e27f2c9db8a074e811dd1aabee166c282102114a2`; removing the final newline reproduces independent `63237a9a5f2aeb462d762509abb556bfe2f1fd8e790f1003a174c82f526c2cc1`. No new untracked source/test file is falsely included in that hash. The complete actual committed patch equals `staged.patch` byte-for-byte, SHA-256 `9efa4e03221bcc6878e215226472c205847f07d88a4243dc158836f65ba17a1d`.

## Artifact envelope and actual runtime trace

All four current production JSON files equal the independent verifier's recorded final file SHA-256 values. Recomputed creation/runtime-object Keccak-256 and runtime lengths match independent recorded identities. Decoded the actual escaped JSON arguments at all seven `stage1-independent-r2.log` trace locators (6792, 7134, 7136, 7206, 7208, 7254, 7425): their raw JSON hashes, creation/runtime objects, rawMetadata and parsed metadata match current artifacts directly. This verifies what the deployment helper actually read, rather than trusting `creationEqual` or similar booleans.

| Artifact | Runtime bytes | Actual current/final artifact SHA-256 |
| --- | ---: | --- |
| UniswapV4DetfMigrationFacet | 20886 | `12b1d084f66d8c11e2df09c4c442ce5225320095c98a274ae115f570b9c14a5e` |
| UniswapV4DetfMigrationAllocationFacet | 21204 | `1d7f5cfc08790c5501d6cc91a4e9aa5f7fe1b8303e878e41889e754be2d2cbb6` |
| UniswapV4DetfMigrationDFPkg | 16646 | `9a755e9af6a88423d74fcca45dc2b9f6202d7fec06a529fd17216e171283db31` |
| UniswapV4DetfMigrationBondNFTVaultFacet | 9496 | `039ebf6cb0c83420244a8d8098ffdb94343419d9f5eef6ea63fcaf6a099a1f42` |

The earlier witness compilation changed source IDs/maps and artifact JSON envelopes. Those earlier producer file hashes are not current file hashes. Unchanged executable objects and metadata are supported by the independent recorded executable identities and direct trace/current comparison; this audit does not invent retained copies of the earlier envelopes. Runtime-object hashes are not fully linked, immutable-populated on-chain runtime hashes.

## Saved execution evidence, not redundant execution

Independently hashed the actual logs, counted PASS lines and checked summaries/sentinels:

| Saved evidence | Observed outcome | SHA-256 |
| --- | --- | --- |
| `verification/fork-independent.log` | 16 passes; two suites; zero failed/skipped; VERIFIER_FORK_EXIT=0 | `c34d17d7fc436a3aad72f15231845df6e956bc54b28e41be73be9d3a0eb85406` |
| `verification/configuration-independent.log` | 8 passes; VERIFIER_CONFIG_EXIT=0 | `0b9ef1503a06a0730bc921abb988304658b1866533ac77ed99e8501dfca1b2b1` |
| `verification/stage1-independent-r2.log` | Script ran successfully; VERIFIER_STAGE1_EXIT=0; actual VerifiedNftLifecycle event at line 15396 | `45b9a9baca4e55677c364e0bcdb097a755dbaf4720bfe3ac0dc80933c91ef009` |
| `implementation/spec-02.log` | 91 passes; 14 suites; zero failed/skipped | `bf2e040d6eb6280c443bf1fd57419f1b109f305dd5ce3adf91d8dd4b3c6f81b5` |
| `implementation/regression-01.log` | 9,932 passes; 589 suites; zero failed/skipped | `b894a0e9e80c36c2566f6e2301f0adbc91e28d42cbe1088c791f1e37ee74e032` |

The prolonged-Stage1 event records first start 1794110901, later start 1804478901, original weighted/earlier credits 16965232709984 / 2566655548570 and later credits 17785729540 / 711428507. The initial witness's VERIFIER_STAGE1_EXIT=1 remains preserved, not counted as a pass. Producer spec/regression logs do not independently seal shell exit codes; their recorded exit-0 provenance remains the implementation report. No tests, build, compiler, RPC or runtime were launched by this audit. Existing compiler/LSP qualifications remain unchanged.

## Preservation and actual index

- Actual cached and tracked working diffs are empty with `--ignore-submodules=all`; committed whitespace check exits 0. This is not a globally clean-worktree claim: incident evidence remains untracked and ignored logs remain on disk.
- Consistent logical-index serialization throughout: raw UTF-8 stdout of `git ls-files --stage -z`, exact original order and NUL terminators retained. Outside-candidate filtering retains the original records and one NUL each; no trimming/newline substitution.
- Reconstructed the precommit baseline from the actual parent's `ls-tree -r -z` as mode/blob/stage-0 records: SHA-256 `2f991d84d21e7647d73a329bda0a0b479e08e5f3dd849c4a474e505cd49b9a41`, equal to the manifest baseline. Actual current logical index SHA-256 `dfb2087191eee7ee31af3502c765b2d06969c9923a8a9a4025272711160c3d49`, equal to the recorded staged/final fingerprint. Actual outside-candidate index SHA-256 `529d459ee9188ad60856d352d4f193dfe00dd60971a9fe30ea23a4a4be2ce56e`, unchanged from baseline. No foreign staged increment exists.
- Independently rehashed all 23 baseline NFT evidence files (including ignored logs), plus all 17 historical/plan inputs; all unchanged. Every baseline untracked noncandidate remains present. Unrelated tracked index entries are unchanged; actual parent-to-commit scope contains no unrelated path and the current tracked diff is empty.
- `lib/crane` still points to `/Users/cyotee/Projects/indexedex/lib/crane`; index gitlink remains `fc0618bf5c34d0564f4367130feff443bd4efc89`. Warm `out/` and `cache_forge/` remain present; production artifact identities were inspected, not regenerated. Plain status's previously documented symlink/submodule limitation is not asserted fixed.
- Actual main remains `90ff0307a7a8e084aa073e02eff125e9c7973933`; integration `work/dtf-migration` remains `6e27ecaa242c4acca132e3575a160514aad07b11`. Every baseline ref except the authorized phase05 branch is unchanged. The sibling `work/dtf-migration-phase-06-e2` was independently observed at `5021e8d4a62bcbddc555f580ef98f8666d993aab` and preserved. Root explicitly confirmed its concurrent creation in `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2` for authorized evidence-only E2 DAG `dag_6b26aa26-68c9-41da-b346-82b9f7ab053f`; it is not a producer mutation of a preexisting/protected ref. No ref was written by this audit.
- Commit inputs retained unchanged: manifest `d409d4de9526c06a379eb16ce7040948e2a4bc70bbbbce7f2e8f56bcd2d98fd0`; receipt `3c0b7dd2e689df12924f32e27404ea849c9d97264a96a383c104b66e28d8a693`; producer checks `69c4e1b658d612a100ad8fffde3e181b55ad19d73c33e56fb894496f912938bc`. The producer's checks are corroborating records, not the independent oracle.

## Disposition and limits

Confirmed for this local bounded NFT source delivery, with the test temporal-provenance and artifact-envelope qualifications above. No missing production binding, blob/mode/path/parent/trailer mismatch or preservation defect was found. Only `commit/verification.md` and its supporting `commit/verification-evidence.json` are authored. JSON parsing and report/evidence consistency checks pass; JSON LSP diagnostics are unavailable because the existing Biome server is not installed. No installation or clean-LSP claim is made. No source/test/producer/control edits, staging, commit, delegation, public action, merge, push, PR or history rewrite occurred. No owned command, listener, runtime or cleanup remains pending.

All non-NFT source categories, authenticated ancestry/exposure reconciliation, operational allocation/quote/funding inputs, TokenStaking composition, restricted/disabled recovery and LP/SE exits, harvest/conversion, resumable operator workflows, complete-product invariants/gas and full-release F1-F4 gates remain open. No original full-plan checkbox is closed or product policy changed by this verification.
