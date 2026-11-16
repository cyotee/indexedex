# Combined integration commit verification (r2)

Date: 2026-11-10. **AdversarialVerify: confirmed.**

This read-only follow-up resolves both preservation observations in
`commit-verification.md`. The first was an incomparable index serialization;
the second was not reproducible with the independent status commands below.
The original report remains the historical first review and was not changed.

## Independent command results

All Git commands below ran from
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-integration`, with
`GIT_MASTER=1`. Exit values are the observed shell command exits.

| Check | Literal command | Exit | Result |
| --- | --- | ---: | --- |
| Branch | `GIT_MASTER=1 git branch --show-current` | 0 | `work/dtf-migration` |
| HEAD | `GIT_MASTER=1 git rev-parse HEAD` | 0 | `6e27ecaa242c4acca132e3575a160514aad07b11` |
| Pricing parent | `GIT_MASTER=1 git rev-parse HEAD^` | 0 | `215c2bba6aa75e3e79bf68b7980b730927a85817` |
| Main | `GIT_MASTER=1 git rev-parse main` | 0 | `90ff0307a7a8e084aa073e02eff125e9c7973933` |
| Commit paths | `GIT_MASTER=1 git diff-tree --no-commit-id --name-status -r HEAD` | 0 | Exactly the five preparation paths listed below |
| Staged tracked diff | `GIT_MASTER=1 git diff --cached --ignore-submodules=all --exit-code` | 0 | Empty |
| Unstaged tracked diff | `GIT_MASTER=1 git diff --ignore-submodules=all --exit-code` | 0 | Empty |
| Porcelain status | `GIT_MASTER=1 git status --porcelain=v1 --untracked-files=normal --ignore-submodules=all` | 0 | Only the owned integration-increments evidence directory is untracked |
| Branch-format status | `GIT_MASTER=1 git status --short --branch --ignore-submodules=all` | 0 | Branch and owned evidence directory reported |
| Branch-format porcelain | `GIT_MASTER=1 git status --porcelain=v1 --untracked-files=normal --ignore-submodules=all --branch` | 0 | Branch and owned evidence directory reported |

`git ls-files --stage` serialization was recomputed with the original,
non-NUL-delimited command and `pipefail`:

```sh
set -o pipefail && GIT_MASTER=1 git ls-files --stage | shasum -a 256
```

Exit: **0**. SHA-256: **`6f89eed8752023335d4f0b2463c02346f3ef9c710ce94ed2b6f4683c51ef5c08`**,
exactly matching `verification/initial-binding.json`. The earlier review
instead used `git ls-files -z --stage`, which hashes a different byte
serialization and produced `2dcff68860a4f16e66f9afba1f870507c64eb3e98b7aeeb7011702ad09a3fc69`.
That difference does not indicate that committing cleared or damaged the
index. The current staged and unstaged tracked diffs are both empty.

The earlier `git status --short --branch` failure and its
`expected submodule path 'lib/crane' not to be a symbolic link` message are
retained as historical tooling evidence, not hidden. Independent reruns of
both branch-format variants above exited 0; the no-`--branch` porcelain
command also exited 0. No shared symlink, configuration, or dependency was
changed.

## Commit identity and committed scope

`GIT_MASTER=1 git show -s --format='%H%n%P%n%s%n%b' HEAD` exited **0**.
The commit is `6e27ecaa242c4acca132e3575a160514aad07b11`, parent
`215c2bba6aa75e3e79bf68b7980b730927a85817`, subject
`Integrate verified DETF initialization and funded child dispatch`. Its
message contains exactly one required trailer:

```text
Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>
```

`GIT_MASTER=1 git diff-tree --no-commit-id --name-status -r HEAD` exited
**0** and reported exactly:

```text
M contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol
M contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol
M contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol
A contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol
M test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol
```

## Independent path-hash verification

The original binding declares 24 accepted path/SHA-256 pairs. For each pair,
the verifier independently computed SHA-256 over the current file and over
`git show HEAD:<path>`, compared both values with the accepted hash, and
exited **0** after all 24 matched. The command used an allowlist of only the
declared `sourceChecks[].path` and `sourceChecks[].expected` fields:

```sh
node -e 'const {sourceChecks}=require("./docs/incidents/2026-09-16-dtf-recovery/migration/integration-increments/verification/initial-binding.json"); for(const {path,expected} of sourceChecks) console.log(expected+"  "+path)' |
while IFS= read -r row; do
  expected="${row%%  *}"
  path="${row#*  }"
  current=$(shasum -a 256 "$path" | awk '{print $1}') || exit
  committed=$(GIT_MASTER=1 git show "HEAD:$path" | shasum -a 256 | awk '{print $1}') || exit
  printf '%s %s %s %s\n' "$expected" "$current" "$committed" "$path"
  [ "$expected" = "$current" ] && [ "$expected" = "$committed" ] || exit 1
done
```

For every path, accepted SHA-256 = current-file SHA-256 = committed-blob
content SHA-256:

| Path | SHA-256 |
| --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshotLib.sol` | `b7af401436bf14cd4cde351b5b3af70b27a7cb1a166f06fc23c515e2bff5b618` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationSnapshot.sol` | `6c2a26b7c85e9f075ec0b8188efed41d9d40f6fccd9aaf8b91447a5c613a9d00` |
| `contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol` | `ba05e7db8175d42a9e24b809772bfa03f54db02a1cd9f163e04148b7f84ceafc` |
| `contracts/utils/StandardExchangeFrozenQuoteLib.sol` | `210d5df7a3c7fc69937c37473770bc34c24146993b1ee3a9527136fa58547137` |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookCapture.sol` | `138137b39a8f2df0e0b8d922649a8d49d7caf7eb8945927513aabb77eae0f4f2` |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol` | `1dc6ff685e9159b6114bfc67f3a8f8e100ecdabd48bbbc179d957c1bc7eba7b6` |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol` | `ff8ce788a7d065928512b633aca06ba858aecc5345d17d76d0bd8f909f6a265c` |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/facets/UniswapV4StandardExchangeWeightedBufferHookHooksFacet.sol` | `a1db24f94e177bedd3f8e8fb438783e0048de393d93513a27ecef99698707267` |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol` | `b6bf0d3c0d119b378d391cd281b9c2af0942011eef84f76337615d42960f7ff3` |
| `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol` | `0e7504ac790f6934df323567d665c1fe25dd5dc51874309e8c0ca72b817d4483` |
| `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol` | `04aabbc91ebc34af967171e259396ede574c9c518795bb9cf8c34aab72aaaba6` |
| `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol` | `255386a415233a101edb04233cf10ee3f213694baf22b9e19290d826bb1bc1a5` |
| `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol` | `e518a13530090733f850435f2ca04ef138d9f8716019c48feff11008665bd944` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol` | `984241e3393db5d6892ace87bd001ec57c5f53d9c7e179ba03d339c3d722d1b3` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshot.t.sol` | `5b35b910d22182ee81884c702e53a6ef8869e91e2f3c82752b782f5a77198acc` |
| `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet_IFacet_Test.t.sol` | `bccccaca4c9941b5865c02be487d5850b87a8ec610f52371389939df80e72a38` |
| `scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol` | `835f94e84920865b29b4236be04020cf3bf54a4dbc0834bb2e7c30b0bc20f037` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol` | `6e3a8c25dad4c01ca1e0b517ebe365b8340520237ca8bc269a9ac3eceb94af7c` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol` | `14112eb68aac3f67bcbae5d41d1a5e76fe3b526033f6dab782df5c1d396b899d` |
| `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol` | `ff3c95b45adec74973aabcb874be2a8d86aa79a9af8770949b0b7e635fbcc360` |
| `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol` | `fed9bd4bf324c8e1c3d71e1809c3ae516320d05beb580085b2deedb83bb24f82` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol` | `d1a4a227847c32bb5b5f3a4b97d9fed8114d2fca47c4c4ff0106b8332248b41e` |
| `scripts/recovery/dtf-migration/pricing-local-qa.sh` | `29de90e5b906195447f7fab8ca9f64f5430d6341687ce5142c9314e9aff17f76` |
| `docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md` | `629feb9a4f1452f0209a9f0dd4647673209eae52c67e6c1f6f358ad48bb24b8d` |

The two pre-existing untracked evidence files also retain the accepted
`untrackedBefore` hashes:

```text
6e3e51f652d459b7f6e37398f8e9153884d701c5fd8723c2a19f42663acfca0b  docs/incidents/2026-09-16-dtf-recovery/migration/integration-increments/preparation-apply.md
5d4c306a0d3fb2cd18559256760d8f753681f7c068da1b5c84901c4502292c53  docs/incidents/2026-09-16-dtf-recovery/migration/integration-increments/pricing-land.md
```

`commit-receipt.md` and the original `commit-verification.md` remain present
as authorized evidence additions. This r2 report is the only file added by
this review; no existing evidence was edited or removed.

## Existing combined-run evidence and limits

No build or test was rerun. `verification/results.json` records the actual
combined command and monitor exits as **0**, with **10,035 passing tests in
602 suites, zero failures, zero skips**. The archived `verification/combined.log`
was independently hashed with `shasum -a 256`; it matches the recorded
`cf835cab6754df1072d64ac7c6c0f8b8eebdf868c4e4a9263fb047529c4ce5b2`.
`verification/source-artifact-binding.json`, checked at
`2026-11-10T19:50:20.638Z`, records **882 artifact checks** and **2,435
dependency checks**, with zero artifact issues and zero dependency
mismatches. These existing receipts support the already completed combined
checkpoint; they are not new runtime test results.

No new runtime resources were created by this review. No index, branch,
commit, source, test, configuration, shared dependency, or original report
was modified. No production-behavior or original task-10 completion claim is
made.
