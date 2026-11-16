# Independent claim-vault EOF correction verification

Date: 2026-11-12. **Disposition: needs-fix (F1, evidence bookkeeping only).**

The corrected source passes the independent static checks: exactly nine final
LF bytes were removed, the other 31 accepted paths are unchanged, and the full
original-parent-to-current whitespace gate exits 0. The fresh root execution
records, compiled inputs, runtime witnesses and signed interruption resumes
reconcile. However, two sealed validation ledger fields labeled `bytes` contain
UTF-16 code-unit counts rather than byte lengths. The brief requires needs-fix
for inconsistent evidence. This report therefore does **not** admit the dependent
formatting commit. No source fix or unchanged-suite replay is requested.

## F1: two validation log sizes are mislabeled

Location: `../format-correction/validation-results.json`, the `checks` entries
named `specs` and `forks`, field `bytes`.

| Log | Ledger `bytes` | Actual raw bytes | JavaScript string length |
| --- | ---: | ---: | ---: |
| `specs.log` | 229420 | 269164 | 229420 |
| `forks.log` | 180237 | 218681 | 180237 |

The discrepancy is reproduced by reading the full UTF-8 logs and comparing
their raw lengths with their decoded string lengths. Both ledger values equal
the latter exactly. The seal correctly binds the actual raw sizes and hashes:

- `specs.log`: SHA-256 `f6897050e0874ac4b4605a5462740f60fab7083b066923a24dc2804f8075a11b`.
- `forks.log`: SHA-256 `2b97a1c267c97c0591f1e3b4ccf03b4a007956dd48c454a3ff40e0843be78051`.

There is no evidence of truncated logs or failed tests: the full logs contain
130 and 81 PASS lines and their successful terminal suite summaries. This is
an evidence-field inconsistency, not a product failure. Root should correct
these two byte counts, or explicitly rename them as code-unit counts, and
publish final bindings/seal for that correction. This verifier did not modify
the producer ledger, report, seal or source.

## Authority and exact source correction

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-16-claim-vault`.
Branch: `work/dtf-migration-phase-16-claim-vault`.
Current HEAD: `9c227900b280713305d4a1a1d1cdc3d8d273f23d`.
Original parent: `4a53299b490343ed904d70c92ecbc7360fcb7659`.

The complete EOF correction brief, router, root correction report, prior
independent E1 report and initial needs-fix commit audit were read. The complete
current nine-file diff and all correction JSON binding objects were inspected.
Root's final report independently hashes to the supplied
`0f1249a50b5a210df8ef77967ad00b8096c89ebbb2e143ac9406adc4797dd8fb`.
Its final seal declares source modifications stopped and no pending runtime.

All 40 source paths were matched against the prior independent acceptance and
actual committed bytes. For each of the nine paths named in `source-delta.json`,
the current file equals the committed file with its last byte, exactly `0x0a`,
removed. Every preceding byte is identical; the ordinary terminating LF remains.
All nine corrected snapshots, stored with `.txt` suffixes, match current source.
The other 31 files are byte-identical to the accepted committed versions. There
is no assertion, signature, fixture, configuration or behavioral change.

All 40 current files are regular mode 0644; their index modes are 100644.
The only tracked working-tree changes are the nine named EOF corrections.
The index has no staged delta. The complete current diff contains nine deleted
blank lines and no other changes. Independent commands, all prefixed
`GIT_MASTER=1`, include:

```text
git diff --ignore-submodules=all --check 4a53299b490343ed904d70c92ecbc7360fcb7659
git diff --ignore-submodules=all --ignore-blank-lines --exit-code HEAD
git diff --ignore-submodules=all --cached --exit-code
```

All three exit 0 with empty output. The first tests the actual combined
original-parent-to-working-tree bytes, not an empty present-day index.

The initial needs-fix audit remains unchanged, SHA-256
`55a9eb3f128addf8f10d668015ff7c97985418bb2726534cc86e4bcab73751a3`.
Its D1 conclusion still applies to the immutable original commit. No amend,
history rewrite, staging or commit occurred here.

## Seals and fresh root checks

All 411 files in the final correction seal were independently read and hashed;
every raw size and SHA-256 matches, with no missing or unsealed file other than
the seal's intentional self-exclusion. All 541 prior producer entries and all
430 prior independent E1 seal entries also retain their byte identities.
The 13 existing commit-evidence files were individually bound for preservation.

The root executed the fresh suites; this verifier did not repeat them.
Complete logs were read, rather than accepting pass flags alone:

| Root execution | Independently checked record |
| --- | --- |
| Migration specs | 130 PASS lines; 22 suites; 0 failed/skipped |
| Pinned Migration forks | 81 PASS lines; 16 suites; 0 failed/skipped |
| Six operator test files | 64 pass, 0 fail, one invocation |
| Both operator stages | successful Solar compilation |
| Strict operator types | empty diagnostic log; exit 0 in root result ledger |
| Actual fixed18566 CLI | `bounded-rehearsal-complete`; 47 child-command records |

Solar artifact preparation precedes the tests in both full logs. The six
outer exit-0 results are recorded by root in `validation-results.json` under
monitor `mon_421RFJBGZ9MVA9XE` / `bash_85`; these are reviewed execution records,
not new verifier process exits. The CLI records distinguish successful commands,
six expected rejection exits and three deliberate SIGKILL interruptions.
Existing compiler/nightly/unknown-format-key warnings remain visible. Root
records no LSP errors for all nine edited files. No failed required product
check was waived.

## Current artifacts, inputs and actual runtime

All ten current raw artifact SHA-256 hashes match the correction bindings and
their previous accepted raw hashes match the prior independent artifact list.
**Eight raw JSON hashes changed and two stage-artifact hashes did not.** Changed
raw hashes are not relabeled unchanged or inferred to imply changed behavior.
The exact per-artifact before/after hashes are retained in `audit-bindings.json`.

The metadata targets, 628 distinct compiled-source keccak256 values and their
raw SHA-256 identities were independently reconciled to actual current files.
The compiler is `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`.
All 20 captured runtime byte arrays reproduce their keccak256 hashes and the
root runtime table.

Five current artifact-to-captured-runtime comparisons match: permanent
Migration, existing allocation, new claim-vault allocation, retained recovery
and package. Only the exact link/immutable spans declared by each current
artifact were masked; every declared span and observed byte value was checked.
Recovery requires no masked span. Template lengths equal actual runtime lengths.
These are current recorded runtime matches, not a new independent deployment.
Full span locations, actual bytes, addresses and hashes are in the bindings.

## Signed interrupted/resumed receipts and gas

Fresh root run: `../format-correction/runtime/rehearsal-1794451995939/`.

| Resume | Nonce | Actual transaction hash | Logs compared |
| --- | ---: | --- | ---: |
| donation | 2123 | `0x5b17d1e14671ab202b71ae48b6ec5402f36588bcf1f107b37cea602beca44b02` | 6 |
| issuance | 2139 | `0x0a2f1e4bdd6d7a62ebec64feae5621e40e669f6d338fd86bd665ea92179ee7f6` | 15 |
| owner-bond | 2157 | `0xf5259aa029db69dc5ad451d7650994eef9fcdc3fa7694516d6572e5278871497` | 268 |

Each signed intent was independently decoded: recovered signer
`0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`, chain 4663, nonce, transaction hash,
recipient, calldata and value match the intent and recorded RPC transaction.
Completion is absent in each before-resume witness and the receipt is already
mined successfully. The resumed intent is identical and all 15 receipt fields,
including complete nested logs, equal the corresponding resumed journal receipt.
The summary's `sameCanonicalReceipt` flag was not used as proof.
All 47 signed successful journal completions also bind their signatures,
payloads and mined receipt hashes.

The actual current parent deployment journal receipt is
`0x164e3d434eb60cadf95d1e33baeb9b681fe482964e4fb05d29f8a2e8f448d533`,
using 44,099,850 gas. It exceeds the retained historical 32-million limit;
target deployment feasibility is not accepted.

## Cleanup, limits and supporting evidence

Independent `lsof -nP -iTCP:18566 -sTCP:LISTEN` and
`ps -p 67199 -o pid=,command=` both exit 1 with empty output. The checkpoint and
its owned runtime parent are absent by lstat. No merge, cherry-pick, revert,
rebase or index-lock state exists. This verifier started no runtime, subscription
or background operation and has none pending.

The retained phase15 W-SD archive was hashed in place: 1,047,506 bytes,
SHA-256 `600c072adccc5e624333fd3dfd511787a3d89868193b320efdb8cbfc912483e7`.
Exact legacy deployed-source equivalence remains unproved. Workstation-specific
authority/Foundry paths, that archive dependency, synthetic operational inputs,
other source categories and full-category/full-plan/hermetic/portable-full-F3
limits remain. No public-execution or target-gas acceptance is given.

Only `format-verification/` evidence was authored. No source, dependency,
configuration, earlier evidence, permissions or history was changed; no held09,
metadata retrieval, public action, push, PR or merge was performed. JSON LSP
could not run because `biome` is not installed; no installation or configuration
change was made. Evidence JSON is serialized and parsed directly.

`audit-bindings.json` contains the exact per-entry hashes, source comparisons,
Git command results, compiled inputs, runtime spans, receipt comparisons,
command exits, preservation bindings and cleanup probes. Its SHA-256 is
`ea1ced6834ef49df83cf1e72d3c9d82e75fb27eb3a04545d34fb9826c8a9275b`.
`closure.json` records final isolation and preservation checks.

**Corrected-source static checks: confirmed. Overall corrected-source handoff:
needs-fix solely for F1. Cleanup: confirmed. No owned operation is pending.**
