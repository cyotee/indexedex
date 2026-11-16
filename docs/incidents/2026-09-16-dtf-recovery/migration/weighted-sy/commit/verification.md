# Independent weighted SY local commit verification

Date: 2026-11-11.

**Verdict: confirmed for bounded local source delivery.** Actual commit
`2baab6e58dafcc3fe5f9a94570d99987d58bf42b` exists on
`work/dtf-migration-phase-14-weighted-sy`. All 33 committed/current files
match the independently accepted final bytes. No needs-fix source-delivery
finding remains. This verdict has the preservation qualification in section 5;
it is not full-category, operational-allocation, target-gas or public acceptance.

## 1. Admission and actual commit

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-14-weighted-sy`.
The complete commit brief, complete phase14 brief, actual complete producer and
independent runtime reports, actual complete commit receipt, independent bindings,
source authority, reconciliation and seals were read. Current main plan r5 and
PRD r22 were loaded and their governing lifecycle/precedence sections read;
their raw bytes and complete authority snapshots match the bound identities.
The actual complete 33-path commit diff was inspected, including all five new
files; `audited-commit.diff` retains it.

| Actual Git fact | Independent observation |
| --- | --- |
| Commit | `2baab6e58dafcc3fe5f9a94570d99987d58bf42b` |
| Only parent | `75d513cb8b36e53f14c8aa3a352f21703ad91ba1` |
| Commit tree / current index tree | `7cce28c369bd5889da9ea10bc8954c07ece0f678` |
| Commits after required parent | 1 |
| Subject | Add verified bounded weighted SY surrender and recovery |
| Change set | 28 modifications, 5 additions; 33 exact accepted paths; 1435 insertions, 54 deletions |
| Required coauthor | Exactly one `Co-authored-by: sisyphus-dev-ai <sisyphus-dev-ai@users.noreply.github.com>` |
| Whitespace | Parent-to-commit, current working-tree and staged checks exit 0 |

The subject-only convention agrees with the two immediately preceding source
commits. No new commit was made by this auditor. No commit is missing or pending.

## 2. Independently derived path, mode and blob set

The accepted set was derived from `../verification/source-authority.json`
`sourceFiles`, joined by exact path to the independent runtime verifier's
`../verification/bindings.json` admitted/final source hashes. All 33 entries
agree. This set was compared to the actual parent-to-commit path set; there are
no extra, omitted, renamed or deleted paths. It was not derived from a broad
directory, the delivery manifest, or a producer pass flag.

For every path, `audit-evidence.json:sources` records accepted, admitted,
final, embedded-snapshot, committed and current SHA-256 identities, current
and committed Git blob identities, parent blob, exact mode and current file
permissions. All identities match. Complete producer source-snapshot contents
were separately hashed, not merely their declared hashes. Current Git blob IDs
were independently recomputed using the Git blob header and current UTF-8 bytes.
The actual delivery manifest's 33 entries then matched these derived results.

Runtime evidence binds bytes, not modes. All 28 existing files preserve the
parent's `100644` mode. All five additions are actual regular non-executable
files with filesystem permissions `644`, committed as `100644`. This is the
mode basis, not a claim that runtime acceptance sealed file modes.

The nine production changes are confined to the existing Migration interface,
repo, allocation/permanent/recovery targets/facet and legacy recovery interface/
library. The remainder is the existing typed operator/stage, runbook and adjacent
spec/fork tests. No ordinary/common/Crane production or dependency/configuration
path appears in the commit. Every noncandidate parent tree entry (12,988) retains
its exact mode and object ID in the new tree. The full current index equals that
tree, so noncandidate index entries are also unchanged relative to the parent.

## 3. Retained runtime acceptance and sealed evidence

Independent runtime report raw SHA-256 recomputes to
`a8239596a190ea6f3b236fe8fa55998e06a0bcd1ac34d5040dad5c6d17773f80`.
All 18 producer/verifier seal entries match. All 501 original independent
admission bindings recompute exactly: 33 sources, 9 authority inputs, 3 historical
archives, 95 raw artifact JSON files and 361 producer evidence files. Separately,
all 361 independent-verifier evidence bindings also match. No sealed report,
snapshot, log, receipt, journal or witness hash discrepancy was found.

The retained independent execution logs show 115 specs and 61 pinned forks with
zero failed/skipped, 59 operator tests in one invocation with zero failures,
successful operator stages and real fixed18564 CLI completion. The sealed checks
record strict TypeScript and all six top-level commands exiting 0; the type log
is empty. This audit did not rerun unchanged tests/builds/CLI. It checks the source
commit against that already completed independent acceptance, not a fresh runtime
execution. Existing compiler warnings and the unavailable JSON LSP/Biome
qualification remain as recorded; no install or configuration change was made.

All 95 admitted raw artifact JSON hashes match admitted/pre-CLI/final identities.
Reading their actual metadata yields 701 distinct compiled source paths. Their
actual current source SHA-256 and keccak256 identities match the accepted ledger
and metadata, with no conflicting metadata source identity. All 95 compilation
targets match their bindings; 47 are independently derived test targets.

All 31 retained captured runtime byte arrays recompute to their recorded code
hashes. Eleven relevant Migration artifact/runtime comparisons independently
match with only actual artifact-declared immutable/library reference spans
masked. The evidence retains the observed bytes in every span. This is not an
unqualified byte-for-byte match for linked/immutable-bearing artifacts, and does
not promote generic captured code to independently matched artifact code.

The three mined-before-checkpoint resumes were also checked from actual retained
interruption records and resumed journal receipts: each interruption has no
completion marker, a successful mined receipt, a decoded signed transaction with
the expected hash/nonce, and all 15 canonical receipt fields identical on resume.

| Resume | Nonce | Actual canonical transaction |
| --- | ---: | --- |
| Donation | 2118 | `0x82cae6fd308ba0d3872d5a6579ae2c20c26524efb2021e7899dd5502a29f111c` |
| Independent issuance | 2132 | `0xcfe405c63762bb5ecacb13144e963c306d3dfadd06b93784da4dbfef53757431` |
| Owner purchase | 2148 | `0x65bd940846e5335481e8d256273ca683d64e973b0af408be1cf5dcece09d33fd` |

## 4. Exclusions and signing-material scan

The actual committed path set contains no weighted-sy evidence, log, snapshot,
probe, journal, generated artifact, cache, broadcast, dependency link/config,
root control file, requirements archive or unrelated path. The accepted operator
runbook is the intended documentation source change, not runtime evidence.
All existing local evidence remains untracked; there is no staged source or
evidence change. Full-file URL/signing-term inspection found only two loopback
templates, `https://example.invalid`, a comment naming the public Anvil mnemonic
without mnemonic words, and deletion of `PRIVATE_KEY` from the Forge environment.
No resolved credential endpoint, private key or mnemonic words were found in the
accepted files. Existing signed local-development transactions remain in excluded
evidence, not in the source commit or copied into this report.

Every Git invocation used `GIT_MASTER=1`; status and diff used
`--ignore-submodules=all`. Read-only Git evidence includes `show`,
`diff-tree --raw --no-abbrev`, `ls-tree -r`, `ls-files --stage -z`,
`show-ref`, `rev-list --count` and the three whitespace checks. No staging,
checkout, reset, ref update, commit, merge, fetch, push or public action occurred.

## 5. Preservation and exact qualification

At this audit's admission, the staged and unstaged tracked sets were empty and
the index tree equaled the actual commit tree. All 53 refs were captured; their
values remained identical through the audit checks. Named protected refs match
the receipt: main and origin/main `90ff0307a7a8e084aa073e02eff125e9c7973933`,
phase13 `75d513cb8b36e53f14c8aa3a352f21703ad91ba1`, held phase09
`421072a7630a0d3d47a6f36e1062d9eae98c93e2`, and stash
`7321b70c984423699475cfb45907b6dd70bb8ef4`. Reading the held ref value is the
entire phase09 interaction: no held candidate/evidence inspection, import,
replay or test occurred.

The 730 existing files under weighted-sy, including the actual delivery receipt
and source manifest, have a per-path mode/size/SHA-256 audit baseline. Their
closing preservation result and exact newly authored paths are recorded in
`audit-cleanup.json`. No unrelated tracked file was dirty. The admitted
`lib/crane` and `node_modules` symlink targets, inodes and permissions match
the receipt and are retained. No dependency or configuration was changed.

**Qualification:** The delivery receipt states pre-commit aggregate inventories
for 742 incident entries, 13,756 artifact entries and 1,100 cache entries. The
actual delivery directory contains its manifest and receipt, not those raw
pre-commit inventories or an all-ref pre-commit baseline. This auditor does not
independently adopt those historical aggregate metadata hashes or infer them
from exact artifact hashes. The independently established facts are exact
accepted source/artifact/sealed-evidence identity, unchanged noncandidate tree/
index entries, current named protected refs, and audit-admission-to-close
preservation. This limits the historical aggregate preservation attestation;
it does not introduce an accepted-source or admitted-artifact mismatch.

## 6. Cleanup and limits

This audit started no node, build, test, provider, subscription or child process
requiring later ownership cleanup. Port18564 has no listener (lsof exit1,
empty output); verifier PID64671 is absent (ps exit1, empty output); the fixed
checkpoint is absent (test exit0). No merge, cherry-pick or rebase state exists.
Only commit verification evidence was written. No owned runtime or pending
operation remains.

Other source categories, operational original-wallet/canonical-origin/Q0/ETH/DTF
records and full-plan/full-category completion remain open. Synthetic fixture
amounts are not approved allocations. Actual local parent deployment used
43,517,419 gas on the permissive 100-million-gas node, above the historical
32-million transaction limit. This audit gives no target-gas, public deployment,
funding, activation, compensation-execution or held09-resumption approval.

**Final bounded local source-delivery disposition: confirmed, with section 5's
historical aggregate-preservation qualification. No source fix or new commit
requested.**
