# Task 13 independent re-verification after repair attempt 1

Date: 2026-11-15. Verdict: **needs-fix**. Primary failure class: **product**. Verification is complete; plan task 13 remains incomplete.

The failure signature is still: **operator claimed-SY witness pin does not match compiled router hash; exit 1**. The retained full operator execution has 240 passed and 1 failed. No reproducible approved build matching the unchanged pin was established, and the missing task 10 lifecycle proof is still absent. Documentary corrections do not satisfy task 13's required exit 0 and real lifecycle acceptance.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
Plan: `/Users/cyotee/Projects/indexedex/.omo/plans/dtf-migration-conformance-remediation-20261114.md:543-564`.
Unless otherwise qualified, evidence paths below are relative to `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-13/`.

## Claim and preservation

The complete untrusted `.omo/ulw-execute/dtf-conformance/task-13-done.json` is 13660 bytes, SHA-256 `eef2ab8973d415c07fad4aa0f8fea9f317b69b5a5b08918749f5489bd9378cc7`. A subsequent complete read was identical. It says `completed:false`, `status:"incomplete"` and `repair.productFixed:false`. It explicitly records the operator exit 1 and missing lifecycle proofs rather than presenting them as green.

The archived prior claim, `task-13-done-attempt-1.json`, is 8737 bytes, SHA-256 `d73967ecccfc8a498c9322464bd37e2ddc9ee4c56630aaa5efb07885ac644cbd`, matching the first verdict's claim binding. The first verdict remains SHA-256 `3cbd144b91439f9f0e2b4c7e7360ffd87e4a97b35195bcea37b4ffef195b1b71`; its report remains `7557626a3066d680ce8348c9c21ba26597f692a9f5e792cef7133d5d8c69c78e`.

All 63 entries of the original evidence index and all 7 entries of the supplemental index independently match current raw lengths and SHA-256 hashes, with no missing files or mismatches. Their index hashes match the new claim: `9a4a0a81fb8050bcb2b707c8280b18daece3620f040cef08c248bd961babe265` and `f5a433ca0ca9189951afffcad12dbccc33d295dca21192c7e3db5f58a1cd7416`. All 8 bound source/artifact/verifier entries in the investigation also match. These checks establish preservation against the retained bindings, not universal provenance for every workspace artifact.

## Findings and requested checks

1. **Product gate remains failed.** `scripts/recovery/dtf-migration/claimed-sy-witness.test.ts:89-93` still loads the concrete artifact and executes `assert.equal(keccak256(artifact.deployedBytecode.object), claimWitnessCodeHash)`. The import at lines 6-7 resolves to `claimed-sy-witness.ts:11`. The complete expected pin is:

   `0x4ae06bcb278766df6529bcd60e05453fee6c853f6536b9f18d2a4d0dac8fd899`

   Independently hashing the current deployed bytecode gives:

   `0x33a0fe038a5d441aa3d9fe48b841bcfc0d0f00f0b085e44b9c41b9b0a7aab2bc`

   The pin definition and complete test file match the prior claim's `source-final.json` bindings. Their SHA-256 values remain `d45bd8b41a5feef7dc7d86c68e8d085ed6babffadf5e13a6703c7d2a84feac5c` and `3ef41ca2e5004fd43a721bea7e146604bc18501d6ff1acf4ebd299bd66ed0231`. Thus no assertion in that test file was weakened between claims. Read-only Git diff shows only the existing certificate fixture change from `snapshotCapture` to `pricingSet`; the pin assertion is unchanged. The replacement claim's expected-pin transcription now matches the source and raw log, including the previously omitted `f653`. This repairs the transcription only.

2. **Approved-bytecode repair is unestablished.** `repair-attempt-1/approved-bytecode-investigation.json` explicitly establishes no reproducible approved matching recipe and records no build or test execution during repair. The source comment specifies Solar and optimizer runs 1 but does not bind complete approved compiler inputs/settings to the expected hash. Retained sibling `task-7/witness-build.log` records `python3 scripts/forge-artifacts.py build scripts/foundry/recovery/dtf-migration/MigrationClaimWitness.sol`, rejected with no artifact roots and exit 2. `task-7/witness-build-2.log` records `forge build --use solar scripts/foundry/recovery/dtf-migration/MigrationClaimWitness.sol`, compiled successfully and exit 0. This historical command was executed; it is not a demonstrated matching-pin recipe. No new recipe was executed in this re-verification.

   Current artifact SHA-256 remains `09187d4b4adcfe56a63bc0fc53501fb5d4d43598c3a43b671ad43aa8cd1400ff`. Its metadata identifies compiler `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, optimizer enabled/runs 1, Osaka EVM and IPFS bytecode metadata. Independently hashing current Solidity source gives `0x48206e00c432f4fe647b220d35eee53201f01f13a136ba22b0018c5e79195156`, matching the artifact's metadata source hash. This corroborates the observed mismatch; it does not prove all possible cache freshness or explain the historical pin's origin. The investigation's negative historical-audit search is reported as its bounded search, not independently repeated here. No claim that a matching build is impossible is made.

3. **Original failure is preserved accurately.** `operator-r2/04.log:88-110` contains the strict equality failure and the exact expected/actual hashes above. Lines 329-331 retain 240 pass, 1 fail and 241 tests across 21 files. Its 29520 raw bytes hash to `ea428eaeadc993624ed88ca301bd4beb1a5871ef207ddbdcd0f330c2aba33861`. The command sidecar records `["/bin/zsh","-c","bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts"]`, code 1, signal null. `operator-r2-recorder.log` retains `CHECK_END operator 4 1`; `operator-r2/results.json` remains `completed:false`. No new successful full operator execution is evidenced.

4. **Additive provenance is accurate but historical raw-log gaps persist.** Every record in `repair-attempt-1/command-provenance.json` was joined independently to its current raw log, original command receipt and recorder log. All five rows match declared log lengths/hashes, verbatim sidecar bytes/hashes, argv, exit, signal, recorder hashes and quoted `CHECK_END` lines. They bind build exit 0, hermetic exit 0, fork-helper exit 0, operator typecheck exit 0 and operator tests exit 1. Shell argv remains shell argv; expanded child filenames are not invented.

   The helper command string exactly matches `invocation-inventory.json` at `/commands/operator/2`, whose hash also matches. The separate exit receipt exactly contains `HELPER_TYPECHECK_EXIT=0` and matches its hash. The original helper stdout is still zero bytes with the empty SHA-256 hash. The new provenance explicitly leaves native argv null and qualifies this separate-record binding. It supplies no invented stdout to the original logs. Strict historical raw-log argv/exit acceptance remains unmet, as the claim now acknowledges. This is an additional harness evidence limitation, not an explanation that makes the product equality failure green.

5. **Task 10 proof remains missing.** Sibling `task-10/funding-blocker.json` still records status blocked, an authority-bundle provenance-contract blocker for the 10000 DTF setup budget, zero transactions sent, no NFT-three principal consumed for setup and no public transactions. Its two covering bound candidates are excluded admitted source contracts; it also explicitly records funded candidates outside the bundle. This is not evidence of global DTF scarcity. Sibling `task-10/verification/report-r2.md` certifies an offline export repair only and explicitly says the lifecycle remains incomplete.

   The current task-10 directory lacks `mixed-pricing.json`, `same-block-config-a-then-b.json`, `same-recipient-config-b-issuance-a.json`, `donation-identity-resume.json`, `nft-three-two-bonds.json`, `rehearsal-location.json` and `runtime`. Directory inspection, the blocker and the retained independent report agree: no complete task-10 current-chain lifecycle is available to reuse. No synthetic fixture or task-11 historical gas receipt is accepted as that proof. Dependent task-12 real portable purchase/donation lifecycle proof therefore remains unsupported. No invented task-10 lifecycle appears in the new task-13 claim or repair records.

## Adversarial assessment and limits

| Case | Assessment |
| --- | --- |
| misleading_success_output | Checked. Passing subsets are not full acceptance. The original log, sidecar and recorder agree on exit 1; the new claim preserves incomplete status. |
| stale_state | Checked. The complete 13660-byte claim was reread unchanged. Original and supplemental index bindings match current bytes. |
| dirty_worktree | Checked with limits. Read-only `GIT_MASTER=1 git -C <worktree> status --short --untracked-files=no` exited 0 and reported 110 existing tracked dirty entries. No blanket clean-tree assumption is made. Source content comparisons use the prior claim's manifest rather than HEAD. Existing changes were preserved. This is not a full audit of unrelated dirty work. |
| generated_or_cached_artifacts | Checked with limits. Artifact raw hash is unchanged; independently recomputed runtime hash still fails; current source hash matches metadata. No generated artifact was substituted or written. No fresh build or universal cache-validity proof is claimed. |
| hung/flaky/cancel/interruptions | Not applicable because this verifier reran no commands under test. No fault-handling pass for those cases is claimed. |

This verifier used local file reads, JSON parsing, raw SHA-256 comparisons, installed ethers Keccak hashing in the resident kernel and read-only Git inspection. No Forge or bun CLI command, test, recorder, rehearsal, RPC, installation, commit, delegation or public transaction was performed. Public-transaction absence in the repair is supported by retained local records and the documentary repair scope; no fresh public-chain state was queried or certified.

Only this second report and the requested second verdict are authored. Product files, the new claim, archived claim, original logs and first verdict remain untouched. JSON evidence parsed successfully. No compiler, test or LSP pass is claimed for this documentary re-verification. The final verdict is emitted last, after report and evidence checks.
