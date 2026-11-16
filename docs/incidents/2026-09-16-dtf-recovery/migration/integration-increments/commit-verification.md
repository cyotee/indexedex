# Combined integration commit verification

Date: 2026-11-10. **AdversarialVerify: needs-fix.**

The completed commit is independently confirmed for identity, ancestry,
message, and its exact five-file path inventory. Preservation is not fully
confirmed: the current index fingerprint differs from the pre-commit
fingerprint recorded in `verification/initial-binding.json`, and Git status
cannot complete because `lib/crane` is a symbolic link at a submodule path.
No repair was attempted.

## Commit identity and scope

Read-only Git commands, each prefixed `GIT_MASTER=1`, returned:

```text
branch --show-current: work/dtf-migration
rev-parse HEAD:        6e27ecaa242c4acca132e3575a160514aad07b11
rev-parse HEAD^:       215c2bba6aa75e3e79bf68b7980b730927a85817
```

The subject is `Integrate verified DETF initialization and funded child
dispatch`. The commit message has exactly one
`Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`
trailer. `diff-tree --no-commit-id --name-status -r HEAD` reports exactly:

```text
M contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol
M contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol
M contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol
A contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol
M test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol
```

Current commit blob IDs for those five paths are respectively
`b6af20cc6274755126fd52ada1993e79dca2d272`,
`c26f9e1aaf6d7c5ddc4664f429e8e06bd7b50823`,
`520c4b0df67a78122744c0e06a780ebea933c8e5`,
`70eb97e7d9e184d842d3055a4b068f04d7e226c7`, and
`ab5a27c60c40afb7f844fe54288fafa59d82bff4`.

`verification/initial-binding.json` records accepted hashes and states all
24 admitted files matched their original increment commit blobs, staged
index blobs, and then-current bytes. This verifier did not independently
re-hash all 24 current files against those manifests. The four preparation
files besides the added library have no subsequent commit-path changes;
the added library is present as the commit's added blob.

## Preservation and current workspace

The current staged diff is empty. The current index serialization hash from
`GIT_MASTER=1 git ls-files -z --stage | shasum -a 256` is
`2dcff68860a4f16e66f9afba1f870507c64eb3e98b7aeeb7011702ad09a3fc69`,
which differs from the recorded pre-commit value
`6f89eed8752023335d4f0b2463c02346f3ef9c710ce94ed2b6f4683c51ef5c08`.
The recorded fingerprint is from before the commit, so this difference may
reflect the expected clearing of the five staged paths after commit; without
a comparable post-commit baseline it does not establish index damage.

`GIT_MASTER=1 git status --short --branch` and the same command with
`--ignore-submodules=all` both fail with:

```text
error: expected submodule path 'lib/crane' not to be a symbolic link
```

The main tracked diff check, `GIT_MASTER=1 git diff --ignore-submodules=all
--name-status`, is empty. The untracked status check with
`--untracked-files=all --ignore-submodules=all` shows the existing
`commit-receipt.md`, `preparation-apply.md`, `pricing-land.md`, and
verification evidence files retained. The new report is the only file this
verification added. Because status itself cannot complete, a clean-index and
complete untracked-preservation claim is not made.

`verification/preservation.json` is the pre-commit snapshot: it records
branch `work/dtf-migration`, HEAD `215c2bba6aa75e3e79bf68b7980b730927a85817`,
main `90ff0307a7a8e084aa073e02eff125e9c7973933`, five staged preparation
paths, and unchanged source/untracked hashes at that earlier point. Current
HEAD is the requested child of the pricing HEAD; no merge or push was
performed by this verifier. Main was not independently queried in this
verification.

## Test and artifact receipts

No build or test was rerun, as instructed. The prior actual-run evidence in
`verification/results.json` records the combined command's exit `0`,
`10,035` passing tests across `602` suites, zero failures and skips, plus
successful artifact-first and test compilation. `verification/report.md`
records the underlying raw-log SHA-256 as
`cf835cab6754df1072d64ac7c6c0f8b8eebdf868c4e4a9263fb047529c4ce5b2`
and the 882-artifact / 2,435-source binding result with no reported
mismatches. These are inspected existing receipts, not rerun or
independently recomputed by this commit verifier.

The commit was independently verified at the Git object/path level, but the
workspace preservation checks are incomplete due to the status error and
pre/post index-fingerprint difference. Retain **needs-fix** until status and
preservation can be established without modifying this worktree.

No runtime resources were created by this verifier. No index, branch,
source, test, configuration, or commit was changed.
