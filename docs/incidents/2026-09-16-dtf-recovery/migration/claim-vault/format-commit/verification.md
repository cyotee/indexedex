# Independent final claim-vault formatting delivery audit

Date: 2026-11-12. **Disposition: needs-fix.**

The required immutable formatting follow-up does not exist at this audit.
HEAD is still `9c227900b280713305d4a1a1d1cdc3d8d273f23d`, and no
`format-commit/receipt.md` or follow-up source manifest exists. The actual
corrected-source report is also **needs-fix**, not an admission to commit.
Correct working-tree bytes cannot substitute for the required committed delivery.
This is a completed bounded negative audit, not final corrected-source acceptance.

## D2: immutable follow-up and receipt are absent

Location: branch `work/dtf-migration-phase-16-claim-vault`, current HEAD, and
the missing `format-commit/receipt.md`.

Independent Git inspection found no commit after the required parent
`9c227900b280713305d4a1a1d1cdc3d8d273f23d`. The full original-parent-to-HEAD gate:

```text
GIT_MASTER=1 git diff --ignore-submodules=all --check 4a53299b490343ed904d70c92ecbc7360fcb7659 HEAD
```

exits **2** and reproduces all nine original added-EOF-blank-line diagnostics.
The parent-to-HEAD name/status diff is empty because HEAD is the parent itself.
There is therefore no nine-byte-only immutable follow-up, no follow-up parent,
message, trailer, staging receipt or preservation baseline to accept.
Those checks are unavailable, not passed.

The required resolution is an admitted corrected-source handoff and an actual
separate formatting commit with its receipt and baselines, followed by auditing
that actual immutable delivery. This auditor made no fix, staged no file, created
no commit, and performed no amend or history rewrite.

## Carried F1: corrected-source admission is still needs-fix

Location: `../format-verification/report.md`, its `closure.json`, and
`../format-correction/validation-results.json:checks`.

The complete actual independent corrected-source report explicitly says it does
not admit the dependent commit. Independent raw-byte recount reproduces its F1:

| Log | Ledger field `bytes` | Actual raw bytes | Decoded UTF-16 code units |
| --- | ---: | ---: | ---: |
| specs.log | 229420 | 269164 | 229420 |
| forks.log | 180237 | 218681 | 180237 |

This is evidence bookkeeping, not a failed runtime suite or a source defect.
It is not waived or relabeled as acceptance here. The producer ledger and seal
were not edited. No source change or unchanged-suite replay is requested by F1.

## Independently confirmed source facts

The complete correction brief, root correction report, actual corrected-source
report, prior independent E1 report, initial needs-fix commit audit, root command
ledger and receipt-audit record were read. The requested follow-up receipt was
looked up and is absent.

All 40 paths were derived from the actual independent corrected-source
`audit-bindings.json:sourceAudit`, cross-checked against root final bindings, and
hashed from current files and actual committed blobs:

- All 40 current files match both correction bindings.
- Exactly the nine paths in `source-delta.json` equal their parent bytes with
  precisely the last `0x0a` removed. Every preceding byte is identical.
- The remaining 31 current paths are byte-identical to the parent/HEAD.
- The nine corrected current hashes do **not** equal HEAD's nine old hashes.
  These corrections remain unstaged working-tree modifications.
- All 40 current permissions are `0644`; their committed/index modes are
  `100644`.
- The full working-tree diff was inspected and contains only nine deleted blank
  lines. No assertion, fixture value, API or business behavior changed.

The original-parent-to-current-working-tree whitespace gate exits 0. The
HEAD-to-working-tree ignore-blank-lines check and cached exit-code check also
exit 0. None is misrepresented as the failed immutable HEAD whitespace gate.
Every status/diff invocation uses `--ignore-submodules=all`; every Git invocation
uses `GIT_MASTER=1`.

The full original and HEAD trees contain 13,028 and 13,037 entries. Their actual
changed path set is exactly the declared 40 paths: 31 modifications and nine
additions, all mode `100644`, with no evidence, build/cache, dependency,
configuration or root-control path included. This establishes the original
commit's exclusions, not the exclusions of a nonexistent follow-up.

The actual HEAD tree remains `d0729eb87d2ab3c5f22b12e2bef0549226ba4239`, with
single parent `4a53299b490343ed904d70c92ecbc7360fcb7659`. Its message is
`Add verified bounded direct claim-vault surrender and recovery`, with exactly
one required coauthor trailer. No later message or trailer is invented.
Per-path current/parent/HEAD SHA-256 values and actual tree entries are retained
in `audit-checks.json`.

## Root checks, corrected inputs and retained evidence

The root report independently hashes to the supplied
`0f1249a50b5a210df8ef77967ad00b8096c89ebbb2e143ac9406adc4797dd8fb`.
All **411** correction-seal entries, **541** prior producer entries and **430**
prior independent E1 entries were individually rehashed with raw sizes: no
missing or changed sealed entry was found. All 13 initial commit-evidence
entries retain their recorded hashes, sizes and permissions.

All ten current artifacts retain the raw hashes bound by the corrected-source
audit, and all 628 compiled-source raw SHA-256 identities still match its
recorded current inputs. These checks bind the observed working-tree candidate
to the reviewed corrected inputs; they do not bind a missing final commit.
The correction audit explicitly records eight changed raw artifact hashes;
those are not relabeled as unchanged relative to pre-correction E1.

Root executed the fresh suites. This audit read the complete log text for
counting and conclusions, and independently hashed the raw logs:

| Root execution record | Observation in this audit |
| --- | --- |
| Migration specs | 130 PASS lines, 22 suites, 0 failed/skipped |
| Pinned Migration forks | 81 PASS lines, 16 suites, 0 failed/skipped |
| Six operator test files | 64 pass, 0 fail |
| Strict types | Empty log; root ledger records exit 0 |
| Both operator stages | Successful Solar compilation; root ledger exit 0 |
| Fixed18566 CLI | bounded-rehearsal-complete; root ledger exit 0 |

Root's outer execution authority is monitor `mon_421RFJBGZ9MVA9XE` / `bash_85`.
These are reviewed root execution results, not new verifier process exits.
Root records no LSP errors on all nine corrected files. Existing compiler
warnings remain in the preserved logs.

The sealed fresh run is
`../format-correction/runtime/rehearsal-1794451995939/`. Its raw witnesses and
the independent corrected-source audit retain all three decoded signed/raw
receipt resumes: donation nonce 2123, issuance nonce 2139, and owner-bond nonce
2157. The correction audit verifies signer, chain 4663, hash, transaction
payload, missing pre-resume completion and all 15 canonical receipt fields,
including complete logs; this final-delivery lane preserved those witnesses.
It did not perform another signature decoder, runtime cryptographic rematch,
deployment or unchanged-suite replay. That prior proof's overall needs-fix
disposition is retained.

## Preservation boundaries

Every entry in the four retained original precommit JSONL baselines was
independently parsed and compared with current lstat and raw SHA-256 using the
retained recipe. Current membership was also walked without following links.
`audit-preservation.json` contains every expected/observed entry and difference,
not only aggregate hashes.

| Historical baseline | Entries | Current observation |
| --- | ---: | --- |
| docs-incidents.jsonl | 996 | All original entries unchanged; evidence additions only |
| docs-incidents-perms.jsonl | 1149 | Original permissions unchanged; claim-vault parent directory size 192 to 288 before this audit's directory was created |
| out.jsonl | 7330 | 2747 changed entries, three old build-info entries missing, two new build-info entries |
| cache_forge.jsonl | 595 | Three changed entries, one new operator-run cache entry |

These original inventories precede the corrected-source builds. Their observed
build/cache differences are not alleged evidence corruption, are not silently
restored, and are not claimed unchanged. Causality or preservation across a
nonexistent follow-up cannot be established from those older inventories.
There is no follow-up-specific retained baseline or receipt to check.
The sealed evidence and the ten explicitly corrected artifact bindings do
reconcile independently as stated above.

All 55 retained refs were compared: only this branch differs from the original
precommit baseline, from `4a53299b` to `9c227900`; no ref was added. This is the
original delivery movement, not a formatting follow-up. The raw current index
SHA-256 remains
`90fcbe92225a40a47f145bb8f9ef2efffc3d395d9df343dd424f0830b69a3221`,
matching corrected verification, with no staged delta.

The historical failed `../commit/verification.md` remains byte-identical:
SHA-256 `55a9eb3f128addf8f10d668015ff7c97985418bb2726534cc86e4bcab73751a3`.
Its D1/needs-fix conclusion and original commit are preserved, not overwritten
or retroactively relabeled.

## Limits, cleanup and audit artifacts

Exact historical legacy deployed-source equivalence remains unproved.
Workstation-specific authority and Foundry paths, synthetic operational inputs,
unapproved operational award datasets, other source categories, full-category,
full-plan, full hermetic and portable/full-F3 limits remain.

The prior phase15 W-SD archive dependency remains at the exact path recorded in
the correction and E1 reports, bound there to 1,047,506 bytes and SHA-256
`600c072adccc5e624333fd3dfd511787a3d89868193b320efdb8cbfc912483e7`.
It was not changed or removed here; its external file was not newly rehashed in
this worktree-only final audit. It must remain available or be deliberately
relocated with updated bindings before phase15 cleanup.

The recorded actual parent deployment receipt remains
`0x164e3d434eb60cadf95d1e33baeb9b681fe482964e4fb05d29f8a2e8f448d533`,
44,099,850 gas, above the retained historical 32-million limit. Target-gas,
public-execution and full-plan acceptance are not given.

Independent lsof on port 18566 and ps for PIDs
67199/57230/57324/48079/49746 return exit 1 with empty output. The checkpoint
and its owned runtime parent are absent. No merge, cherry-pick, revert, rebase
or index-lock state exists. This auditor started no runtime, monitor, subscription
or background operation and has none pending.

Only this new `format-commit/` audit evidence was authored. No source fix,
permission change, historical evidence overwrite, Git write, held09 execution,
metadata/source retrieval, dependency/configuration change, public action,
push, PR or merge occurred. JSON LSP is unavailable because `biome` is not
installed; no installation was attempted. JSON was serialized and parsed
directly. No test was added to pin prose or whitespace.

| Supporting evidence | SHA-256 |
| --- | --- |
| audit-checks.json | 6b2bd5db3426c0532a7586b44c37c71c4e9bf58cfb777031a6bab09cdaefe687 |
| audit-preservation.json | e4e588b466e6b25de6a507891ad3082ebfce5bd7c93b4ac286ff303621806eaf |

`audit-closure.json` records final source/evidence/index/ref isolation and cleanup.

**Final bounded delivery: needs-fix (missing immutable follow-up and receipt;
corrected-source admission still F1/needs-fix). Current EOF-only static
correction and sealed-evidence preservation: confirmed. No owned operation
is pending.**
