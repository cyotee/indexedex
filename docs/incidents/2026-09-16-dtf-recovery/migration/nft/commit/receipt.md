# Scoped NFT source commit receipt

Date: 2026-11-11. Local delivery confirmed by producer postcommit checks, not a separate independent commit-review verdict.

## Actual commit

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-05`
- Branch: `work/dtf-migration-phase-05`
- Commit: `6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`
- Sole parent: `5021e8d4a62bcbddc555f580ef98f8666d993aab`
- Subject: Add verified two-generation NFT Migration surrender
- Trailer, exactly once: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`
- 18 source/test paths; 1,108 insertions and 20 deletions. One coherent two-generation NFT surrender increment; no evidence, logs, caches, dependencies or configuration committed.
- Commit command exited 0: `GIT_MASTER=1 git -c trailer.ifexists=addIfDifferent commit -m "Add verified two-generation NFT Migration surrender" --trailer "Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>"`. All Git calls used GIT_MASTER=1; no push, PR, merge or rewrite.

## Source and execution binding

Read the entire implementation and independent runtime reports and phase05 briefs. Inspected the complete existing tracked delta and all new source/test files, then the entire 1,432-line staged patch. Current 215 production dependency SHA-256 values match independent evidence; all ten changed production source entries match both accepted SHA-256 and Keccak-256. The changed TestBase is bound as a test dependency, not falsely claimed among those ten.

Independent metadataSourceBindings contains production dependencies, not tests or the TestBase. For those files the accepted identity is current compiled metadata keccak256, independently recomputed from source bytes, joined by compilation target and test method names to exact successful saved logs. TestBase and fork base are dependencies of those targets. Saved logs attest execution; they are not independent historical cryptographic hashes of untracked tests. No missing test SHA-256 is invented. Existing Core, Surface and HostileContribution use audited producer spec-02 execution, not an independent rerun. Current test artifacts are inspected now; no historical test-artifact file hash was recorded in independent evidence.

The exact executed test contracts and all their test method names were matched to successful log PASS lines: 10 legacy-source fork cases, six lifecycle fork cases, eight independent configuration cases, nine Core cases, two HostileContribution cases and four Surface cases. TestBase and fork-base source Keccak-256 identities match the applicable compiled target metadata. The independent fork/configuration logs and prolonged-Stage1 witness hashes match evidence.json. Saved 91-spec and 9,932-regression log hashes and passing counts also match the independent audit. Prior failed attempts remain preserved and are not counted as current passing results. No valid suite, compiler or runtime was rerun. Compiler warnings and prior unavailable LSP diagnostics remain qualified in the original reports.

All four production artifact files match the verifier's recorded finalFileSha256. The documented source-ID/source-map envelope drift did not alter the verifier-confirmed executable bytecode or metadata. Raw tracked diff SHA-256 is `72f77e4bf77e5505e6a8aa2e27f2c9db8a074e811dd1aabee166c282102114a2`; trimming only its final newline reproduces accepted `63237a9a5f2aeb462d762509abb556bfe2f1fd8e790f1003a174c82f526c2cc1`. That tracked diff does not bind new untracked tests.

## Exact committed path and hash equivalence

All modes are 100644. In every row, current bytes, precommit staged blob bytes and actual committed blob bytes have the identical SHA-256 shown. Git blob IDs and all three separately computed hashes are recorded in checks.json; accepted source identities and provenance locators are in source-manifest.json.

| Path | Current = staged = committed SHA-256 |
| --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol` | `3fc1997e34be0d40e6fb638fc6cc759d9333546df97ebebc97583522666dab4e` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` | `903c1911a54398ef3a16a2f5007526530163aa68c502730f9cfd6581e388acdf` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol` | `a6835808e586eed607b91aa6ec545189026a3a0d7a1ad1609af38e2ffcde6532` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationFacet.sol` | `7f5365fcf5f4d91b3b08963a7239300ef6962a64eb95a9055b97f5ae6c8073d7` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol` | `a18a4e44c739873a694c0caa27abbc1e0e1515f22d6391a81f0d2ab689bbe40e` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationTarget.sol` | `93b12ed360332a3b78649407002a43f207fc8dfdeaadf9f1e0c6608584f4c8e3` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/IUniswapV4DetfMigrationBondNFTVault.sol` | `1feaa1299df7459978cacc8eea70a63e20f9f0cbe66dc807efe29e098bae7e53` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol` | `bc6162ee4c60cd23a44337f1c9dc57cfbd37258d7ae591c47db1da49878e325d` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol` | `dc0fd10bd5b3d345cfecbc5d9282884c1c2d3b0d983eeef846a8aff33cf79c2d` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyNft.sol` | `282903679430d3be4a6f2e0370a6be0dbaedf34c5e50dfa7c7243f69c26be395` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyNftLib.sol` | `aa927b281d84741b7e71f47bcfea0fe1ca8c0dc5d12b18e6bcf3787d1ec994c3` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol` | `098bc174b787a504757e455d242de9b4df279f21d56a554172556e2fdb0d966c` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftForkBase.sol` | `cab0fddc254598c5b8307a73d98fdd316aae7428ada96ef912920de49e0d6660` |
| `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftLifecycle.t.sol` | `d86e60fe414ec3bbbd5e6716369b5ec786c2f88dffc52cd435251f7577f977fa` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationCore.t.sol` | `804bacac1d4323f83e8087aea2f6e0c75dda7389aafd2ad5a53d6d29eaaa9eec` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHostileContribution.t.sol` | `b35e791ba05df2d7b9988e9e346ea6b8c76c83dd1307ecb05894fca326c2215e` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationNftConfiguration.t.sol` | `b0443d9613a28e015ff893c09a857e4372e0c19249d3b7c9d0b9866065e256d4` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationSurface.t.sol` | `75aa15aea842b5a8e3ea2d356d653b35efed96652be91294e49949abb53c6a9b` |

## Preservation and final state

- Exact committed path set, modes, sole parent and trailer verified using actual Git objects. Committed full diff equals the inspected staged patch byte-for-byte.
- Cached diff is empty; scoped source/test working tree is clean. The final logical index exactly equals the captured staged logical index. Outside-candidate index fingerprint remains `529d459ee9188ad60856d352d4f193dfe00dd60971a9fe30ea23a4a4be2ce56e`. Consistent serialization is raw UTF-8 `git ls-files --stage -z` stdout, retaining NUL terminators and original order; no newline-substitution or trimming. Full baseline index SHA-256: `2f991d84d21e7647d73a329bda0a0b479e08e5f3dd849c4a474e505cd49b9a41`; staged/final SHA-256: `dfb2087191eee7ee31af3502c765b2d06969c9923a8a9a4025272711160c3d49`.
- All 23 pre-existing NFT evidence files, including ignored logs, remain byte-identical; all 17 independently fingerprinted historical/plan inputs remain byte-identical. Every baseline untracked noncandidate path is retained. The only remaining Git-visible untracked paths are incident evidence and these commit records.
- The pre-existing `lib/crane` symlink still targets `/Users/cyotee/Projects/indexedex/lib/crane`, with unchanged index gitlink `fc0618bf5c34d0564f4367130feff443bd4efc89`. Plain status fails with the known symlink/submodule limitation; status/diff with `--ignore-submodules=all` succeed. This is not represented as a globally clean worktree.
- Warm `out/` and `cache_forge/` remain in place, unstaged; this task ran no build/test/cache operation and made no production/test edit.
- Main unchanged: `90ff0307a7a8e084aa073e02eff125e9c7973933`. Integration `work/dtf-migration` unchanged: `6e27ecaa242c4acca132e3575a160514aad07b11`. All baseline refs except the authorized phase05 branch are unchanged.
- A concurrent sibling ref `work/dtf-migration-phase-06-e2` appeared at `5021e8d4a62bcbddc555f580ef98f8666d993aab`. An initial overly broad all-ref-equality assertion stopped before committing; comparison showed only this new, nonprotected sibling ref. No accepted source, existing ref, parent, index or evidence mismatch existed. The sibling ref was preserved, never changed by this task.
- No upstream is configured. No remote action occurred. No owned command, runtime, listener or cleanup remains pending.

## Evidence records

- `source-manifest.json`: written before staging; exact 18 paths, modes, current/accepted source identities, execution joins and baseline preservation fingerprints. SHA-256: `d409d4de9526c06a379eb16ce7040948e2a4bc70bbbbce7f2e8f56bcd2d98fd0`.
- `staged.patch`: complete reviewed staged diff, retained outside commit. SHA-256: `9efa4e03221bcc6878e215226472c205847f07d88a4243dc158836f65ba17a1d`.
- `checks.json`: actual postcommit blob/hash/mode/path/parent/trailer/index/reference preservation results.
- This receipt and all commit evidence remain outside the source commit. No independent commit verifier was delegated or impersonated.

## Limits

Only the independently accepted bounded NFT increment is delivered. All non-NFT categories, ancestry/exposure reconciliation, operational funding and quote inputs, harvest/recovery, operator workflows, invariants/gas and full-release gates remain open. No original full-plan checkbox is closed; this is not full Migration or deployment acceptance.
