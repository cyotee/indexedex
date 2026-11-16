# Task 10 independent harness repair re-verification

Date: 2026-11-15. Verdict: **confirmed-with-follow-up**. Failure class: **none**.

H1 is resolved by a genuine export rerun into a new log. The original log is unchanged. The donor provenance blocker remains; task 10's lifecycle is incomplete. No rehearsal was run, no product file was edited by the repair, and NFT 3 was not consumed in the inspected execution history. These custody and authorship conclusions are supported by local execution provenance, not fresh chain queries.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`. Paths below are relative to this worktree unless absolute. Evidence names are relative to `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/`.

## Findings

No remaining harness finding within this re-verification scope. Prior finding H1 is closed. No product failure is established. Export success is only offline integrity evidence and does not close the mixed-pricing, activation, donation-resume, two-bond, rollback, or recovery obligations.

## Actual execution and preserved original

`bundle-export-r2.log` contains the exact argv on line 1, offline-integrity-only output on line 2, and `BUNDLE_EXPORT_EXIT=0` on line 3. Its 730 bytes hash to `332ec6ac8864ed1f17a00adaa4da285701e4f3971876f3e091e5dadaec2699e5`.

The exact argv is:

```text
bun "/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1/scripts/recovery/dtf-migration/cli.ts" bundle-export --input "/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1/docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/authorities-input.json" --output "/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1/docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/authorities-bundle-r2"
```

Producer provenance was independently read from:

```text
/Users/cyotee/.omo/agent/projects/indexedex-5248cf3d3615/senpi-task/children/st_01a1dde5/sessions/st_01a1dde5/2026-11-15T06-29-13.694Z_17f3b054-fb85-421b-9cc6-eff6ab4860c8.jsonl
```

The inspected transcript has 263 records, 1814336 bytes, SHA-256 `1bfd48898f558d17996f023ba6ddddb30c63013d02ba7bd7147dceebcc1cdc7f`. Its first 233 raw records are byte-identical to the prior verifier's transcript binding: 1749872 bytes, SHA-256 `d0b4a0f02e7cb8c0beaca939b5b06e4f557bc14cde45c92930b445f89ace3dc9`. Thus the historical action record was preserved and the repair was appended.

Transcript line 241 starts a monitor whose command uses noclobber and redirects the entire group into the new log. The group prints the argv, executes it, captures `$?` immediately in `code`, prints that captured code, and exits with it. Lines 250 and 253 independently record watcher completion with exit code 0. This is process provenance corroboration; the conclusion does not rely on accepting a success string alone.

The original `bundle-export.log` is still exactly 703 bytes, SHA-256 `10c171d534be637b2522e26f9a9fe9195f59b40159d2071b4abbf0d420ec24db`, matching the prior report's independent binding. It still has two lines and no exit-status line. No forged exit line was appended to it.

## Stale state and bundle checks

The claim grew from the prior verdict's 10558 bytes to 11168 bytes. It was completely reread as raw JSON and rebound to SHA-256 `35d5bc731fefe52d3d9573a046555d1ad690ff8f09113fb89fa4f087a515b4e1`. A subsequent complete read was identical. The claim remains untrusted input; its success fields were checked against actual bytes and process provenance.

All 18 current claim evidence entries match their declared byte counts and hashes. Both original and r2 bundle manifests are identical: 10246 bytes, SHA-256 `4ab93713b6aafd43d674a7b605252f938c4e70cf638a1ed89bf33b4fc5f1dac0`. All 22 r2 source items match their declared hashes and lengths, the original bundle items, and current original source bytes. The template also matches the original bundle and `authorities-input.json`: 12705 bytes, SHA-256 `2601b5c3fa6b349984e42730ee5d380221e5541f7234212fb8bf3c4fe0a7ab8c`. The r2 data directory contains exactly the 23 declared content files.

The new bundle therefore carries the same authorities and donor-evidence limitations. No extra transfer census or substituted authority was smuggled into it. The fixed 22-role contract remains visible at `scripts/recovery/dtf-migration/bundle.ts:11-25`.

## Donor block and custody

Task 10 of `/Users/cyotee/Projects/indexedex/.omo/plans/dtf-migration-conformance-remediation-20261114.md:480-503` requires a separate eligible holder covering 10000 DTF from the bound transfer/holdings evidence. The prior independently verified donor block is preserved by identical bundle and probe bytes.

The saved probe still binds block 108944663, hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`, and the exact budget `10000000000000000000000`. Independently recomputed all 337 returned hex balances and covering flags without mismatch. All 60 authority-candidate balances agree between the blocker and probe. Only these two authority candidates cover the budget:

| Address | Saved raw balance | Exclusion |
| --- | ---: | --- |
| `0x2e9c1f705ab967c5af59249203d7495bdabb223b` | 16226464590164018429679811 | Admitted custody source |
| `0x999dae02d22e5fee1c4508430d5196d31d631009` | 48199379819584937212078 | Admitted W-SW source |

Both are excluded in the preserved blocker. Eligible covering authority candidates remain zero. Funded candidates in the separately retained transfer census remain outside the fixed authority bundle. The follow-up concerns binding and transporting that genuine evidence, not global DTF scarcity.

The repair's five top-level tool calls at transcript lines 239, 241, 251, 255 and 257 were inspected, including the full embedded command and patch. They read files, export into the new bundle and log, compute fingerprints, and update only the claim citation plus two evidence references. No product edit or rehearsal invocation occurs. The export route at `scripts/recovery/dtf-migration/cli.ts:127-135` invokes `exportBundle`; the authority branch at `bundle.ts:46-69` collects source files; `bundle-files.ts:134-175` reads originals and writes exclusively into the specified new output directory. The export is not a chain operation.

The preserved Anvil logs expose only `eth_getBlockByNumber`, `eth_call` and `eth_getCode`; the saved probe records zero transactions. There is no task-10 runtime directory or rehearsal-location record. The existing setup still calls `claimBond("3", ...)` at `scripts/recovery/dtf-migration/rehearse.ts:114-125`; the repair did not execute it. Together with the unchanged original execution history and the prior custody audit, this corroborates no NFT 3 consumption by task 10 or its repair. No present-day public chain state is certified.

## Adversarial cases and dirty worktree

| Case | Result |
| --- | --- |
| misleading_success_output | Pass. Exact argv and captured actual exit are corroborated by the monitor's exit 0. Offline export is not lifecycle success. Original log remains unchanged. |
| stale_state | Pass. Updated claim was completely reread and remained stable. All 18 evidence bindings match. Original and new bundles have identical manifests and content. |
| dirty_worktree | Pass with local provenance limit. Read-only `GIT_MASTER=1 git -C <worktree> status --short --untracked-files=no` exited 0 and shows extensive existing shared product/test dirt. Attribution rests on the complete repair action audit, not that dirty status. No product write by the repair was found; this verifier preserved shared changes. |
| hung/flaky/cancel/interruptions | Not applicable: the rehearsal was not run. No timeout, cancellation, interruption, or lifecycle fault-handling pass is claimed. |

Verification performed only local reads, hashes, JSON comparisons, source inspection and read-only Git status. No implementation, delegation, rehearsal, Forge, RPC, install, commit or transaction was performed by this verifier. No producer file, original verdict, original report, original export log or DoneClaim was edited by this verifier.

Follow-up: resolve donor-evidence binding and transport while preserving exact authority bytes and bundle completeness, then execute task 10 under separate instructions. This report neither authorizes that change nor certifies a full lifecycle pass.
