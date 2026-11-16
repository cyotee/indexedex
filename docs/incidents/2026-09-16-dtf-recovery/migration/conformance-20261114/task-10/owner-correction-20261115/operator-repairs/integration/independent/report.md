# Independent combined operator-repair gate

Verdict: **confirmed**. Failure class: **none**. Confidence: **high within the unit/CLI gate**.

The two admitted repairs and the new combined QA satisfy this gate. This is not fresh Anvil, real proxy or task-10 lifecycle acceptance. It does not emit parent readiness or close the implementation plan.

## Admitted repair decisions

The existing independent setter-repair-verdict.json and configure-fault-verdict.json are admitted without repeating their settled reviews. Both remain confirmed; all seven product/test source fingerprints still match their admitted verdicts and the current shared-QA source manifest. Their exact verdict-file hashes are recorded in verification.json.

The new claim is .omo/ulw-execute/dtf-conformance/owner-correction-20261115/operator-repairs-integration-done.json. Its QA-only scope is consistent with task 10's blocking-repair paragraph. The earlier scoped verdict limitations concerning then-pending shared tests/types are resolved for this combined gate by the actual commands below. The historical unavailable custom audit and LSP timeouts are not retroactively changed into successful checks.

## Exact shared commands and observed results

All commands ran in /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1, using Bun 1.4.2+50a8a8387 and TypeScript 5.9.2. They were run once by the QA executor; this verifier did not rerun them.


```bash
bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/record-verification.ts docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts
```

| Required command | Independently checked result |
| --- | --- |
| Complete operator suite | Exit 0; exactly 280 pass lines, 0 failures, all 21 selected files observed; reported 92.23 seconds. |
| Strict operator TypeScript | Exit 0; exactly all 87 current operator .ts files selected; empty stdout/stderr. |
| Strict delivered-helper TypeScript | Exit 0; both named helper files selected; empty stdout/stderr. |

The NUL-delimited expanded argv matches each receipt's argv array. Cwd and numerical exit sidecars agree. The current directory file sets match the shell-expanded test/type inputs exactly, including the untracked domain/state tests. Both compiler invocations retain --strict, --noUncheckedIndexedAccess, --exactOptionalPropertyTypes and --verbatimModuleSyntax, together with the exact required --skipLibCheck and other flags. There is no alternate command, filtered subset or custom-audit substitution.

I read the complete raw test stderr and nonempty stdout. Successful source-binding, unknown-event, corrupted receipt, configure crash/resume, corrupted recovery, reverted-first-run and local-only tests occur in the full output. Other selected suites cover portable/history integrity, exact authority roles, preparations and source boundaries. Expected negative-case JSON in stdout is test evidence; it is not mistaken for command failure. Both compiler raw streams are genuinely empty.

run-checks.sh records argv before execution, invokes the original command as "$@", saves its direct exit before further commands, and accumulates every nonzero result in overall. No pipe masks a failed test or compiler. Overall exit is 0. The original QA transcript /Users/cyotee/.omo/agent/projects/indexedex-5248cf3d3615/senpi-task/children/st_01a1df7f/sessions/st_01a1df7f/2026-11-15T13-56-27.259Z_d2b1deb1-116a-4980-bb65-794d9db80bb6.jsonl, launch record 72f529de, binds /bin/bash to this recorder. Monitor mon_1S046DDKK7RF0R8F reports each required command exit 0 and REPAIR_QA_COMPLETE exit=0; notification records 20c54658 and 28013373 include natural watcher completion. Earlier task-7 monitor evidence is not substituted for this run.

## Source, artifact and evidence integrity

I independently hashed every entry in the new delivery inventory (152), all current source/input captures (107), the protected prior-evidence census (252), and all original-manifest source references (35). Every recorded hash and byte length matches current bytes; no read or hash failed. The 107 before/after source entries match each other with no additions or removals, and still match current files. All four original failed-run records retain their admitted SHA-256 values:

| Historical record | SHA-256 |
| --- | --- |
| Canonical receipt/transaction/header/trace | c6b1e9c210ccce97c27d1fb051f2b70198af57302b367cc6952416aee8645666 |
| Pricing execution manifest | 399d926f7d61aff65d74e79f11d7ead47e06369eb483c3065aef6ae866c5aa44 |
| Immutable journal domain | d6afa20561144bdd2057e8846b5e76009fdba03bd86083eeb047386aae60db36 |
| Signed intent | 9117eb335e45c0d323c5dd5cf35ff38706f39717e328d776ef5d74e2b9e0cdca |

The old manifest remains unbound to pricing-abi. The admitted rejecting manual control remains intact: missing bound pricing event ABI. Its successful actual local-chain receipt and standalone generated decode are diagnostic history, not production acceptance. No source was appended, no original journal/intent re-domained and no old history retroactively accepted. New bound positive contexts have their own signatures, transaction hashes, books and domains. The generated pricing artifact digest remains the admitted bc27f132877882a81b5d89f7ecb2637eb4b04fa685ad42430930e595cd181bbd.

Removed witness-pin policy and source/receipt integrity stay as reviewed. Captured schema/claimed-SY source hashes match their reviewed baselines; this gate restores no pin and makes no new policy decision. Exact authority roles remain intact, including the full suite's 22-role transport cases. All old producer records, failed attempts and task-7 evidence remain preserved.

The shared worktree remains dirty. Narrow tracked status/diff receipts are identical before and after QA, staged diffs are empty and both scoped whitespace checks exit 0. Those tracked diagnostics do not cover untracked tests; the independently verified source hashes, selected tests and actual strict compiler do. No unrelated dirty change is attributed to either repair.

## Retained manual-proof bindings

The manual-bindings.json summary agrees with the admitted proofs. Both programs' 28 core local-source entries match their recorded raw hashes and the current source/evidence census. The later state-module mtime is explained by the admitted mutation restored byte-for-byte; a timestamp is not treated as an affecting source change.

Setter evidence keeps the original unbound rejection separate from a new source-bound synthetic positive and twelve independent corrupted-receipt rejections. The summary's raw outcomes equal the previously admitted manual stdout outcomes. Configure evidence preserves SIGKILL/code 137, then two exit-0 resumes with no signal, for independent and separate-NFT contribution operations. Their original signed intent/domain hashes and canonical receipts remain the admitted ones. Each has one send and one completion across repeated resume. Both nonce queries are the original pending/latest checks before the initial send, not new allocation on recovery. The accepted-signed-object counter is not misrepresented as separate wallet-sign instrumentation.

The CLI import census has 62 entries: 57 match available proof-era baselines, four rehearsal modules differ from the older task-7 baseline and one rehearsal module lacks a historical digest. Their mtimes precede the lane proofs, but mtimes do not establish complete historical byte identity. These are separate rehearsal-path modules, not evidence of a changed configure/resume repair. They are covered by the current full compiler/test run, without claiming fresh rehearsal execution. Historical recursive third-party module bytes are likewise not exhaustively fingerprinted; captured dependency manifests, lockfile and compiler identify this run. These explicit provenance limits do not contradict the admitted unit/CLI behavior. No affecting change or evidence failure requires another replay.

## Cleanup, applicability and limits

The original monitor completed naturally. cleanup.json records no pending QA processes, no added temp roots and preservation of two pre-existing fixture directories. The finite runner and compiler/test children exited; no verifier-owned process was started. There was no source/test edit, installation, Forge, RPC, transaction, Anvil restart, delegation or commit in this gate.

Stale/unbound source identity, malformed data, misleading success output, dirty-tree integrity, interruption and repeat-resume correctness are applicable and supported by the admitted lanes plus the full run. UI/browser/accessibility/responsive and throughput/stress probes are inapplicable to these scoped operator repairs. Single-run evidence does not establish a flake rate. Public-network behavior, real-chain reorg/power-loss campaigns, actual proxy/custody effects and fresh Anvil/task-10 lifecycle remain outside this verdict.

No concrete gate defect found. Required fixes: none. The parent owns task-10-operator-repairs-ready.json and any rehearsal wake; this verifier does not write it. The combined verdict confirms the unit/CLI gate only.
