# Scoped bounded-core local commit receipt

Date: 2026-11-10 (local -0800); generated 2026-11-11T00:04:12.558Z.

## Delivered source commit

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-04`.
- Branch: `work/dtf-migration-phase-04`. No upstream configured; remote pushed status was not queried. No fetch or push performed.
- Commit: `5021e8d4a62bcbddc555f580ef98f8666d993aab`.
- Sole parent: `6e27ecaa242c4acca132e3575a160514aad07b11` (exact expected integration base).
- Subject: `Add verified bounded DETF Migration core`.
- Exact trailer, present once: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`.
- Exactly **57 source/test/local-QA paths**, 5,719 insertions and 67 deletions; all modes `100644`. Parent and integrated children remain one coherent increment.
- Evidence is deliberately outside the source commit, retained in this incident directory. No snapshot source/test, dependency symlink, generated cache/artifact/broadcast or foreign staged edit was included.

## Acceptance and byte provenance

`source-manifest.json` was written and parsed **before** committing. It enumerates every staged path, exact accepted SHA-256, current/staged SHA-256, Git blob, mode, expected parent and acceptance locator. Its SHA-256 is `4e67da609a1be5bb4eee2f86994e3be84ae7ec4f8e93d5373636d6aee77da6f5`.

For every one of 57 paths, accepted = pre-stage/current = staged blob = committed blob = postcommit current SHA-256, and filesystem/index/commit modes agree. `postcommit-checks.json` records the full per-path comparison. No source bytes were changed to prepare this commit.

The complete 371,707-byte / 6,530-line staged diff was inspected in contiguous chunks and retained as `staged.diff`; SHA-256 `139c79163d56a29f089824a71d7cedbdb5da0a607f082c2c282ca7f110eaa0fc`. The actual commit path list equals the exact staged allowlist. The nine tracked common/ordinary extension edits and 48 new paths are the intersection of authorized candidates, actual initial status and independent hash evidence.

The corrected independent `correction-verification/artifact-source-binding.json` supplies 56 candidate hashes. The shell guard is not Solidity and is absent from that artifact source list: its exact unchanged hash `fe484531f12b1d11d467415aa20b30e04855e938e8f00c9068aa0df6f6183af6` is independently recorded in `verification/reviewed-input-identities.json`; the corrected independent audit also executes that guard. This is existing independent acceptance, not a newly manufactured source hash. Acceptance documents themselves are fingerprinted in the manifest.

Retained, not rerun: **83 focused tests / 10,102 combined tests / 246 successful mined local QA receipts / 24 independent tests**. Corrected independent verdict remains bounded-core confirmed. All 2,482 source, 932 artifact and 101 historical evidence hashes were checked before and after the commit; zero mismatches. No compile, test, broadcast, node or operational action was started.

## Preservation and actual status

`preservation-baseline.json` fingerprints **7,949 preexisting dirty paths** by bytes and modes before staging. Every one remains unchanged. After committing the 57 selected paths, **7,892 preexisting untracked incident evidence/cache files remain** outside this commit directory; no unrelated tracked modifications or foreign staged changes existed. All are retained, not cleaned or staged. `remaining-status.txt` lists the full remaining status, including this delivery directory.

The index has no staged changes; tracked source state is clean. Consistent raw `git ls-files --stage -z` serialization hashes are: initial `2dcff68860a4f16e66f9afba1f870507c64eb3e98b7aeeb7011702ad09a3fc69`; staged and postcommit `2f991d84d21e7647d73a329bda0a0b479e08e5f3dd849c4a474e505cd49b9a41`. The latter two are equal; comparing initial index bytes directly with the staged index would incorrectly treat the authorized additions/updates as preservation drift.

Shared `lib/crane` is still the original symlink to `/Users/cyotee/Projects/indexedex/lib/crane`, with its unchanged recorded gitlink. Plain `git status` initially rejected that preexisting symlink with exit 128; subsequent status/diff reads explicitly used `--ignore-submodules=all`. No link or dependency was repaired or staged.

All refs except this owned branch are unchanged, including:

- `refs/heads/main`: `90ff0307a7a8e084aa073e02eff125e9c7973933`.
- `refs/heads/work/dtf-migration` (integration): `6e27ecaa242c4acca132e3575a160514aad07b11`.
- `refs/remotes/origin/main`: `90ff0307a7a8e084aa073e02eff125e9c7973933`.

The manifest and machine receipt include the complete before/after ref snapshots and dependency identity. No reset, stash, merge, rebase, amend, push or destructive Git occurred.

JSON Biome LSP is not installed; no tool/dependency/configuration change was made. Both JSON records were parsed and validated against actual Git objects and source bytes instead; no fresh Solidity diagnostics are claimed for unchanged source. The configured `.husky/_` hook directory is absent; the commit completed normally with exit 0 and no hook bypass.

An attempted optional reviewer spawn was rejected by the nesting limit and launched nothing. No reviewer acceptance was required or awaited; root already has the independent commit verifier queued. This producer does not replace that queued check.

## Open gates and stop

This is only the authorized local delivery of independently accepted bounded core. **No original plan checkbox is closed.** All original legacy attribution/custody/source, recovery, surrender, harvest, operator/resume, release and production authorization gates remain open. No public deployment, funding, activation or compensation is authorized here.

Producer provenance/preservation checks pass; no source mismatch, pending command or owned runtime remains. Root retains its queued independent commit verification.
