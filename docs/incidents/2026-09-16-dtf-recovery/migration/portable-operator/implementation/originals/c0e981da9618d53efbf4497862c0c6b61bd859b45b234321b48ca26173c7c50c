# Verified bounded claimed-SY local source delivery

Date: 2026-11-12. Status: **complete for this bounded local source delivery only**.

## Exact local commit

- Commit: `15fd629375edeb361f6a39262795bdc66723ca3a`
- Subject: `Add verified bounded claimed SY intake and credit`
- Parent: `4eaa7decab80d24cf37cb3781eff5ffaf9362942`
- Tree: `5125cfcf55a6269931a7017070b76bf1dad0abc5`
- Author: `Cyotee Doge <not_cyotee@proton.me>`
- Author date: `2026-11-12T08:08:38-08:00`
- Committer: `Cyotee Doge <not_cyotee@proton.me>`
- Committer date: `2026-11-12T08:08:38-08:00`
- Branch: `work/dtf-migration-phase-23-claimed-sy-integration`
- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-23-claimed-sy-integration`
- Exactly **28 operator/runbook/adjacent-test paths**: 25 modifications and 3 additions, 1170 insertions and 33 deletions.
- Exactly one coauthor trailer: `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>`. It was passed with `--trailer`, not embedded in `-m`. `trailer.ifexists=addIfDifferent` was set. The committed message contains that trailer once and no other trailer.
- Signature: good, RSA key `55EB42889513051267BC55A395206404A78FB7F3`. `git verify-commit` exit 0 using `gpg.program=/usr/local/bin/gpg` (GnuPG/MacGPG2 2.2.41). GnuPG also prints unknown ownertrust; that is not a bad signature. Stored `gpg.program` remains unset. PATH `gpg` is `/opt/homebrew/bin/gpg` and was not the signer.
- Exactly one commit after the required parent. `git rev-list --parents -n 1 HEAD` is `15fd629375edeb361f6a39262795bdc66723ca3a 4eaa7decab80d24cf37cb3781eff5ffaf9362942`. No amend, reset, rebase, push, PR, merge, public action, or source fix.
- No upstream is configured (`rev-parse @{upstream}` exit 128). No fetch or push was attempted.
- The source commit excludes this manifest, this receipt, the precommit inventories, and all other evidence. Evidence remains local and uncommitted.
- `source-manifest.json` raw SHA-256: `2d26886a4694ab7a570b5d7bfd521b20ef388a5568b9b3909b0ed6a63a2fd443`. This receipt does not claim its own raw digest.

## Source provenance

`source-manifest.json` binds every candidate path, mode, accepted SHA-256, producer SHA-256, both independent-audit SHA-256 values, current SHA-256, committed SHA-256, Git blob, and parent blob. The candidate set was derived from `verification-r2/audit.ts` reexecuting `implementation/probe/bindings.ts`, which rebinds `implementation/source-manifest.json` `source` ahead of immutable and authority into `verification-r2/audit-01.json` `results[0].bound.preserved[0:28]` and `results[1].bound.preserved[0:28]`. That slice was cross-checked to the producer source array, producer seal `sourceAndPreservation[0:28]`, and the actual parent/index/worktree delta. It was not taken from a directory listing. All 28 current bytes match the verifier accepted SHA-256, the producer binding, both audit bindings, and `git cat-file blob HEAD:path`. There is no post-runtime source-hash exception.

Producer `acceptedMode` 420 is decimal `st_mode & 0o777`, which is `0o644`. Full `st_mode` 33188 is `0o100644`. Every tracked parent mode and all three new files are regular non-executable files and were committed as `100644`. `core.autocrlf` is unset (exit 1). Worktree bytes, committed blob bytes, and accepted SHA-256 values match for all 28 paths, so no newline conversion was observed.

Before staging, `git diff --ignore-submodules=all --check` on the tracked candidate exited 0. That did not cover the three untracked files. After staging only the 28 accepted paths, these gates exited 0 with empty output:

```text
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check 4eaa7decab80d24cf37cb3781eff5ffaf9362942
GIT_MASTER=1 git diff --cached --ignore-submodules=all --check
```

After the commit, `git diff --ignore-submodules=all --check 4eaa7decab80d24cf37cb3781eff5ffaf9362942 HEAD` exited 0 with empty output. Accepted hashes were not a waiver. No source byte was edited to satisfy whitespace.

Independent acceptance is the complete `verification-r2/report.md`, raw SHA-256 `14750c64ed29a92ddf36b8c68fd6ec8b9fcdd39b7bc61e612662b1ff617a3f41`, 24548 bytes, disposition confirmed for bounded complete-original, known-zero-prior-compensation, direct-signed-EOA claimed-SY integration. That hash was recomputed from the file after the commit and still matches the admitted value. Producer seal `implementation/seal.json` remains `c62c02fe8640ce62f12e3af089d6abddeb060f97ff5e55e42a7edbe823417d2a`. Producer report remains `49fab644f20998227e1c30013c07e2895a8feeda1e0714ae481a860b4d11e0dd`. Producer source manifest remains `712421fc20a28931542887604e45a0138db0cce7354e2cabb59e275e839a2390`. Verifier seal `verification-r2/seal.json` remains `9cf7ecd19efa7e06bb2f343a19926a157e3ec7a4b9ba2b06110704ab93134547`.

The three additions are `claimed-sy.ts`, `rehearsal-claimed-sy-source.ts`, and `rehearsal-claimed-sy.ts`. Their parent blobs are absent. No production contract, ordinary/common/Crane source, dependency, configuration, provider, or held09 path is in the commit.

## Verification performed here

- Read the complete commit brief, the amended implementation brief, the complete producer report, the complete independent r2 report, the original needs-fix verification report, source22 contract and admission, and the phase21 immutable delivery context. Verified the r2 report hash, branch, sole required parent `4eaa7decab80d24cf37cb3781eff5ffaf9362942`, empty incoming staged set, and recent subject-only commit convention.
- Read the entire tracked candidate diff (68660 bytes, 25 files, 549 insertions, 33 deletions) and all three added files. The tracked diff is `commit/precommit/tracked-diff.txt`. The diff is confined to the existing operator/runbook home and the adjacent Migration weighted-SY test. No production ABI, credit mechanism, conversion, debit, or collector-owner method was installed.
- URL/signing-material inspection found no resolved endpoint and no embedded private key. The public Anvil mnemonic is inside the accepted addition `rehearsal-claimed-sy-source.ts` and in pre-existing context lines; it was not stripped. Claimed-SY signing is gated to `127.0.0.1` port `18573`. Inherited signers remain gated to `127.0.0.1` and now also admit that owned port. The runbook names the archive alias `robinhood_mainnet_alchemy` and does not embed a resolved endpoint.
- Staged blob hashes and modes matched worktree bytes and the accepted SHA-256 set before the commit. After the commit, sole parent, one-child count, subject, exactly one coauthor trailer, `diff-tree` path set, and each committed `ls-tree` mode/blob plus committed/current/accepted SHA-256 all match. Final staged and unstaged tracked diffs are empty. The index tree equals the new commit tree `5125cfcf55a6269931a7017070b76bf1dad0abc5`.
- Prior independent runtime evidence was corroborated from its sealed report and audit JSON, not rerun: 167 specifications, 142 pinned forks, 91 operator tests, strict operator and probe types, both operator-stage builds, and the actual fresh 18573 CLI with three real mined-before-checkpoint resumes. `audit-01.json` is 19484166 bytes, SHA-256 `9ae4c6692341df43c270ba5efc5f72a1d02050bf0f6e3b0971c56b620eed0fff`. No unchanged suite was replayed.

## Qualifications that remain explicit

This is a bounded local immutable delivery of the stopped candidate, not full-plan acceptance, target-gas acceptance, operational allocation approval, full raw-category closure, or a public operation. Partial, prior-delivered, and unknown-delivery originals remain unsupported. E-S, blocked conversions, standalone native/WETH exposure, host/archive portability, and full hermetic reconstruction remain open.

Only authenticated direct signed EOA source claims with isolated canonical blocks, fixed source/vault/SY identities, and complete unique members are supported. No contract-wallet source form, delegation, or special account execution was added. The isolated direct-EOA subset is the whole admitted source form.

Historical original wallet, E0, D0, W0, known-zero prior delivery, and semantic disjointness remain reviewed owner inputs. Current signatures, canonical receipts, certificate hashes, and owner-review flags do not prove those facts. Opaque aliases remain unapproved operational reconciliation inputs. The onchain loader trusts owner loading; it does not independently authenticate offchain certificates.

The operator fixture commits an actual zero-output slice: consumed native18 weight `1`, measured native9 SY `0`, retained in complete coverage and not paid again as surviving raw weight. Aggregate zero remains rejected. The adjacent Foundry split test aggregates two positive claims and does not itself mine that one-weight slice; the operator and CLI proof does.

Each eligible original has measured Q0 `18077396`, excluded preexisting floor `5416` SY, and unrelated raw weight `7000000000000000000`. Complete reviewed E0 is `10000000000000000` wei and D0 is `1000000000000000000`. Frozen C0 is `466690583`. Partial quantity `6025798` delivers `155563510`; terminal quantity `12051598` delivers `311127073`. These are the independently measured quantities, not a new credit formula.

Two genuine late child-funding failures remain bound: full `0xe51ff544a86d82f17e014ac78528919c1251be8242a6896afacda4eca3530aa4` and split `0x9906c79f9521ee997003c7f4c1d47cd0288ada97478e5c38bc9f33266e44a653`. Earlier consumed raw weight stays consumed. The unchanged ordinary-SY rejecting-contract receiver/reentry test is shared onchain-path coverage, not a claimed-origin callback witness.

Independent wire capture retains 2531 HTTP response bodies, 840 canonical transactions, and 840 canonical receipts over 849 mined blocks. Of these, 666 signatures recover cryptographically and 174 are Anvil synthetic fixture transactions with r=s=1. Within those captures, 184 originally retained raw signed records and four offline deterministic reconstructions are separately reconciled. Those subsets are not additional transactions, and reconstructed signatures are not original captures. Every eligible claimed-source signature is an original raw capture. This commit lane did not recapture or reclassify them.

All 68 original prepared-input references across 35 unique paths reproduce exact lossless captures. Both current runs have zero prepared-input drift. Earlier artifact-ID drift and ABI reconstruction qualifications remain historical. No artifact was restored, normalized, or presented as an original capture.

The three genuine independent mined-before-checkpoint resumes remain donation `0x586e41d34bd72bf0022a1af49ce868dde50598ba53f4e8c80301b31562f1aa15`, independent issuance `0x4c5b14ccc9c71abc4b6c359af33f6686ca25dba9abead32c3f8ba78d2c74d74b`, and paid owner-first bond `0xa88006f70cbbd0709f30e93031211d450a998d2b147ec0501ad3b7719b5fb9c3`. The producer's three original resume witnesses are separate and were not substituted for these. They were not replayed.

Actual runtime sizes remain principal 24408, allocation 24100, recovery 22704, claim-vault allocation 11221, and package 16714. Actual registration gas **45116678** exceeds **32000000**. Neither figure was rerun or relabeled as target-gas acceptance.

The original `verification/report.md` needs-fix admission remains `cece39c3cf16befd94d403f3dedd14755be092a9f1e626a271dbbe56befdbdfb` and its seal remains `fc7ecbf562d3410eb47e62d907a3a28ccc9699fa3646f8a7accbf6b482db3276`. r2 does not erase that missing-candidate result or the later root receiver-scope correction. Source22 contract remains `b0785175919f4eb6e5dd53f94bdb343b3c88dee1aa9fde190bcd9d52354911c7` and its independent admission remains `be8f520ad99ad3db5757e5452440a5113ad7aeefe62d9adbe9dd88724961cd6b`. Both are outside this commit. `source22-preservation.json` remains the r2 membership check; this lane did not rewrite it.

Foundry warnings remain visible. Biome diagnostics are unavailable and some editor diagnostics timed out. Strict command-line types passed. Those tooling gaps are not claimed as passes. No dependency was installed or cleaned. Existing failed attempts remain preserved.

## Preservation

Precommit inventories were captured before any `commit/` file existed and before staging. They are retained under `commit/precommit/`. Recipe: `commit/precommit/recipe.txt`, SHA-256 `347b5e46cdcc20f0ef347e306c9c862d077fbaff6713ceaea593662d779bebe8`. The git-mode serialization is UTF-8 JSON Lines, one object per line, keys `path`, `kind`, `mode`, `size`, `sha256`, `target`, sorted by POSIX path. That git-mode field collapses non-executable regular files to `100644` and is not a read-only-mode proof. The permission inventory `docs-incidents-perms.jsonl` records `perm` as `oct(st_mode & 0o777)` and is the encoding for sealed read-only modes. Host rows include `role`. No absolute host path has more than one role in this delivery. Producer immutable and authority rows may omit mode; observed perm was recorded and bytes/lengths matched. An absent binding mode is not a mismatch.

- All **2165 pre-commit `docs/incidents` git-mode entries** retain identical path/kind/mode/size/SHA-256/target inventories. Inventory hash `4fa4014aa7e2e4fa6ede8ff823fe966fe2f56fa75c98d9d7c0786ff56bae36fc`. Post-commit rewalk, before this receipt and `source-manifest.json`: 0 missing, 0 changed, 14 new paths, all under excluded `commit/precommit/`. This receipt, `source-manifest.json`, `extra.json`, and `preservation-compare.json` were written after that rewalk and are also excluded.
- All **2272 pre-commit permission entries** retain identical path/kind/perm/size/SHA-256 except the directory-size change caused by creating `commit/`: `docs/incidents/2026-09-16-dtf-recovery/migration/claimed-sy-integration` 160 to 192. Inventory hash `417de7ea34d887f0e98a98f66f024f0853d25e1786f36e6096702e45d8138c48`. Post-commit rewalk: 0 missing, 0 file changes, 16 new paths. Those new paths are the excluded `commit` directory, `commit/precommit`, and the 14 precommit files. Sealed file modes and hashes are unchanged. No historical report, binding, snapshot, witness, log, journal, or seal was rewritten or chmodded.
- All **7355 `out/` entries** retain inventory hash `8ea9bf1ce27f5337dc3970a2b71cc2034bd20c462aeafbfa58a660224423bab9`. Post-commit rewalk: 0 missing, 0 changed, 0 new. No build, deletion, or artifact restoration was performed.
- All **611 `cache_forge/` entries** retain inventory hash `00a05ab2cc2e2f71af454e16cc7c86a2d46272de4914a803fa8361855a4fe826`. Post-commit rewalk: 0 missing, 0 changed, 0 new.
- All refs other than `work/dtf-migration-phase-23-claimed-sy-integration` remain identical. The only ref movement is this branch from `4eaa7decab80d24cf37cb3781eff5ffaf9362942` to `15fd629375edeb361f6a39262795bdc66723ca3a`. `show-ref` baseline SHA-256 `8e9930ef9e6aa4575fa8f4bfe46d0e0773ec362cafebb05e29c37d612a5ee8c1`. No held phase09 candidate was read, imported, tested, or committed.
- All **24 foreign worktree indexes** are unchanged. This worktree index changed from `abb0cf0714e143fa32653761a9bab8251dc4253c6965a18213fbfdc5850fa75e` to `0621887e8015e8df54a193b0edcc1798efb9780cf14826007de76e77c626f6d3`. The index matches the new commit: staged diff empty and `git write-tree` equals `5125cfcf55a6269931a7017070b76bf1dad0abc5`. The baseline records 25 indexes: 24 foreign and 1 own.
- All **34 bound external host-input rows** — 3 authority and 31 external immutable, 34 unique paths, 0 parent-preserved rows — retain identical size, mode, permission, and SHA-256. Inventory hash `b639126b6a5bda0c8cecf937f5ff5c1412dd1a76f2ef715a173ed9430163b9b2`. The 2 in-worktree immutable files are the original needs-fix verification report and seal. They are covered by the docs/incidents walks and were unchanged. They were not deleted, relocated, or rewritten.
- The incoming staged set was empty. The final staged set is empty. The commit changes only the 28 accepted paths. No merge, cherry-pick, rebase, or index lock is present.
- Port 18573 listener check exit 1 with empty output. The checkpoint `.omo-runtime/dtf-migration-claimed-sy/checkpoints` and its runtime parent are absent. Commit and inspection processes completed. **No pending operation.**
