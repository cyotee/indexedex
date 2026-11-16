# Independent bounded-core commit verification

Date: 2026-11-11.

**AdversarialVerify: confirmed** for actual committed-byte provenance and
preservation of the accepted bounded core. No unexplained hash, path, mode,
parent, trailer, index or protected-ref difference was found.

This is not full Migration acceptance or full-plan completion. All original
legacy/source/attribution/custody, recovery, surrender, harvest, operator/resume,
release and production-authorization gates remain open. No original plan
checkbox is closed.

## Scope and required evidence

Only `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-04` was audited.
The explicitly required main-checkout commit brief and its core/correction
briefs were read; no main-checkout Git command or write was performed.
Repository router, Git skill and repository assistant rules were read.
The actual implementation report, correction report, complete 591-line
correction-verification report, source manifest and receipt were read.

The independent correction verdict remains confirmed for bounded F1/V1;
its report SHA-256 is
`58582a7f3cca411267560297caf547367dc40661e1bf017b3886539a671070a9`.
Its finite-coverage and callback-regression-oracle qualifications remain
unchanged; this Git audit does not expand behavioral acceptance.

Producer evidence SHA-256:

| File | SHA-256 |
| --- | --- |
| `source-manifest.json` | `4e67da609a1be5bb4eee2f86994e3be84ae7ec4f8e93d5373636d6aee77da6f5` |
| `receipt.md` | `11c6ed002a0b61cf9d12cae5ebaa3344c7675dbf92dbb0c1e476020b76e5081e` |
| `preservation-baseline.json` | `241103da28e3a21464accbacef04b85dabd51a7920ff8a0f559f896a856c1bf4` |
| `postcommit-checks.json` | `5a708407810e1aa34a5c0eb472ad37407f6035dcf566691bc86d42a9a8394f9f` |

Independent supporting evidence is
`independent-verification-evidence.json`, SHA-256
`74d77c44beee7a0d413411c8edb784e89d0d92c3f0c6d6622e43bc54b70697ad`.
It contains the complete 57-path comparison, command exits, acceptance
document fingerprints, preservation counts, full before/after ref maps and
exact serialization hashes. It is independent recomputation, not a copy of
the producer's pass flags.

## Actual commit and committed-byte provenance

| Check | Independently observed |
| --- | --- |
| Branch | `work/dtf-migration-phase-04` |
| Commit / current HEAD | `5021e8d4a62bcbddc555f580ef98f8666d993aab` |
| Sole parent | `6e27ecaa242c4acca132e3575a160514aad07b11` |
| Tree | `8e19ea9645031d3fedada2520a69b67f0b189059` |
| Subject | `Add verified bounded DETF Migration core` |
| Changed paths | Exactly 57: nine modified common/ordinary extensions and 48 additions |
| Modes | All 57 are regular `100644` in commit, index and filesystem |
| Byte equivalence | Independent accepted hash = manifest accepted/current/staged hashes = actual committed blob SHA-256 = current filesystem SHA-256, for every path |
| Git object equivalence | Actual committed blob ID = manifest staged blob ID = current stage-zero index blob ID, for every path |

The actual commit message contains exactly one occurrence and exactly one
parsed trailer:

```text
Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>
```

The actual complete parent-to-commit path set equals the manifest set, with
no missing or extra path. The seven named common files and two ordinary V4
extensions are the only modified existing paths. All additions fall within
the authorized new Migration contracts/interfaces/tests or the two exact
local-QA paths. Existing snapshot paths, dependencies, control files,
generated artifacts/caches/broadcasts and incident evidence are absent from
the commit.

All 56 Solidity/test/QA hashes were independently looked up in the accepted
correction verifier's actual `artifact-source-binding.json`. The shell
guard's hash was independently looked up in the original verifier's actual
`reviewed-input-identities.json`:
`fe484531f12b1d11d467415aa20b30e04855e938e8f00c9068aa0df6f6183af6`.
The shell guard is not incorrectly claimed to be a Solidity artifact source.
Every acceptance locator resolves to the exact path being checked.

The regenerated full Git diff is 371,707 bytes, SHA-256
`139c79163d56a29f089824a71d7cedbdb5da0a607f082c2c282ca7f110eaa0fc`,
equal to both the retained staged diff and its manifest identity.

## Index, unrelated work and protected refs

Index comparisons use the original **raw NUL-delimited**
`git ls-files --stage -z` serialization, without JSON or newline conversion.
The parent tree's mode/blob/path entries were independently reconstructed
into this exact serialization; its fingerprint equals the recorded original
index. This establishes the original index baseline rather than incorrectly
expecting the pre-stage and postcommit index fingerprints to be equal.

| Index checkpoint | SHA-256 |
| --- | --- |
| Original, independently reconstructed | `2dcff68860a4f16e66f9afba1f870507c64eb3e98b7aeeb7011702ad09a3fc69` |
| Actual current, equal to recorded staged/postcommit | `2f991d84d21e7647d73a329bda0a0b479e08e5f3dd849c4a474e505cd49b9a41` |
| Unrelated entries, identical before/after authorized changes | `f6ca2130268f20ac4f9a434e52a38ed1cf96896faa1d286cb80a0bc9ce0bc196` |

Both staged diff and tracked diff against HEAD are empty, explicitly ignoring
the preexisting shared submodule symlink. No index entries outside the 57
authorized paths changed. Reconstructing original porcelain-v1 NUL status
from the original baseline also reproduces its recorded fingerprint
`47c50540182ef4d7d22f43823a0b10c9b268f3f3469d040d53c1dde27cc24aeb`.

All **7,949 preexisting dirty paths** were independently rehashed and their
filesystem modes/types compared: zero differences or missing files.
Of these, 57 are now committed; all **7,892 unrelated untracked paths**
remain present with their original status. Before this verifier's two
evidence files were written, actual status contained 7,898 untracked files:
those 7,892 plus the six producer commit-evidence files. The worktree is
therefore tracked-clean, not globally empty.

All **2,482 accepted sources, 932 artifacts and 101 historical evidence
files** were independently rehashed: zero mismatches. All six acceptance
documents fingerprinted in the manifest match. Original adverse witnesses,
failed attempts, receipts, logs and current accepted bytes remain retained.

`lib/crane` remains a symlink to
`/Users/cyotee/Projects/indexedex/lib/crane`; its index entry remains
`160000 fc0618bf5c34d0564f4367130feff443bd4efc89 0`.
The link was neither repaired nor staged.

Every ref was compared with the pre-stage snapshot. The only changed ref is
the authorized owned phase04 branch, from the expected parent to the source
commit. In particular:

| Protected ref | Unchanged object |
| --- | --- |
| `refs/heads/main` | `90ff0307a7a8e084aa073e02eff125e9c7973933` |
| `refs/heads/work/dtf-migration` | `6e27ecaa242c4acca132e3575a160514aad07b11` |
| `refs/remotes/origin/main` | `90ff0307a7a8e084aa073e02eff125e9c7973933` |

## Commands, validation and stop

All commands ran from the scoped worktree, with `GIT_MASTER=1` and optional
Git locks disabled. All required commands completed with exit 0:

```sh
GIT_MASTER=1 git rev-parse HEAD
GIT_MASTER=1 git branch --show-current
GIT_MASTER=1 git cat-file commit 5021e8d4a62bcbddc555f580ef98f8666d993aab
GIT_MASTER=1 git diff-tree --no-commit-id --no-renames --name-status -r 5021e8d4a62bcbddc555f580ef98f8666d993aab
GIT_MASTER=1 git ls-tree -r -z 5021e8d4a62bcbddc555f580ef98f8666d993aab
GIT_MASTER=1 git ls-tree -r -z 6e27ecaa242c4acca132e3575a160514aad07b11
GIT_MASTER=1 git ls-files --stage -z
GIT_MASTER=1 git status --porcelain=v1 -z --untracked-files=all --ignore-submodules=all
GIT_MASTER=1 git diff --cached --name-status --ignore-submodules=all
GIT_MASTER=1 git diff HEAD --name-status --ignore-submodules=all
GIT_MASTER=1 git for-each-ref '--format=%(refname) %(objectname)'
GIT_MASTER=1 git diff --no-ext-diff --no-textconv 6e27ecaa242c4acca132e3575a160514aad07b11 5021e8d4a62bcbddc555f580ef98f8666d993aab --
```

Each of the 57 blobs was read with `GIT_MASTER=1 git cat-file blob <blob>`.
`GIT_MASTER=1 git interpret-trailers --parse` received the actual commit
message on stdin and returned the exact trailer once. Python SHA-256 and
filesystem-stat checks supplied the independent byte/mode comparisons.

The supporting JSON was parsed and its values validated against these
observations. Biome JSON LSP is unavailable; no installation or configuration
change was made and no clean LSP result is claimed. Markdown and evidence
were inspected after writing. No source changes require compilation.

No redundant suite was run on unchanged accepted bytes. The earlier
24 independent tests, 83 focused tests, 10,102 combined tests and 246 mined
local-QA receipts remain prior source-bound evidence, not fresh executions
by this commit verifier.

This verifier wrote only this report and its supporting JSON in the commit
directory. It made no commit, source/producer/control edit, push, PR, merge,
history rewrite, production action or destructive Git operation. No node,
compiler, background command or other owned runtime was started; no required
command or cleanup remains pending.

**Final verdict: confirmed for bounded-core committed-byte provenance and
preservation only; all original full-plan gates remain open.**
