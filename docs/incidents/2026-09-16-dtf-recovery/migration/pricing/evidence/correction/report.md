# F1/F2 local QA and evidence correction

Date: 2026-11-10.
Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02`.

**DoneClaim: F1 and F2 are corrected and locally demonstrated. The authorized direct CLI mined 233 successful transactions; the mismatched selected endpoint was rejected before broadcast/deployment with both nodes available and unchanged. Both original exact-filter receipts are now accurately labeled zero executed tests. No pricing or product behavior changed. Full task 2/E3 and lifecycle integration remain open.**

The independent `../verification/report.md` remains unchanged as the historical needs-fix report. This correction disposes of its F1/F2 findings; it does not rewrite that independent verdict or expand its bounded pricing confirmation.

## Scope and mechanism

Read the complete independent report and phase-two brief at `/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase02-brief.md`, repository router and assistant coding/deployment/testing rules, applicable Foundry/Anvil/script conventions, script, consumer ABI, preserved test receipts and artifact-helper workflow.

Only these non-evidence paths were edited/created:

- `scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol`: replace the unrelated fixed-URL probe with a real-process CLI guard, then probe Anvil through the selected RPC. Retain chain 31337 and dev-sender checks.
- `scripts/recovery/dtf-migration/pricing-local-qa.sh`: necessary CLI guard helper, not a launcher. It reads the actual parent Forge process command using `/bin/ps -ww -p "$PPID" -o command=`, accepts no arguments, and requires the complete fixed direct CLI. No caller-provided endpoint environment variable is accepted as proof.
- `docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md`: correct both empty-selection claims, cite executed evidence, document the exact ABI-signature/nonzero-coverage contract and guard.

The installed `Vm.sol` exposes RPC aliases and current-fork requests but no selected-endpoint URL getter. The helper therefore checks the actual executing Forge CLI rather than trusting an environment assertion. Its whole-command equality rejects changed/duplicate RPC flags, extra flags, alternate target, signer overrides and resume. This intentionally supports only the exact documented argument order, spelling and sender case. It requires local `ps`, Bash and the repo's already-enabled FFI; it is not an on-chain access-control mechanism.

All guard checks run before `startBroadcast` and fixture deployment. The script neither creates nor selects a replacement fork. `vm.rpc("anvil_nodeInfo", "[]")` now queries the current selected execution RPC. The actual `--rpc-url` is the one Forge uses for broadcast. The native chain/dev-sender requirement remains. A helper failure reverts via FFI before any broadcast. The script driver itself is still instantiated in Forge's local simulation; that is not a mined deployment.

No production contract/test, ordinary product, dependency, configuration, plan or attribution-policy edit was made. No private key was loaded, fork was used, public RPC action occurred, commit was created, or task was delegated.

## Exact execution contract and build

Every recorded command uses `run.sh`, which records literal expanded argv, UTC time, recorder PID, cwd, PATH, TMPDIR/cache paths, broadcast destination and separate command/tee exits. For label `X`, receipts are `X-command.txt`, `X.log`, `X-exit.txt`. It selects `/Users/cyotee/.foundry/bin` first.

Forge/Anvil: `1.9.1-nightly`, commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`. Solar: `0.3.0-dev+commit.e7a91fc7`; its compatible Solidity version is 0.8.38. The read-only mined-receipt auditor used the installed shell Bun 1.4.2.

Warm `out/` and `cache_forge/` were already present. Artifact-first order, both command/tee exits **0/0**:

```sh
python3 scripts/forge-artifacts.py build \
  scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol \
  --consumer scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol
forge build --use solar \
  scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol
```

`artifact-build-command.txt` and `artifact-build.log` preserve the helper invocation and expanded `forge build --use solar` runtime-artifact command. `script-build.log` reports one compiled file and compiler success. No unchanged pricing tests or 111-test suite were rerun.

The **actual positive direct Forge CLI**, without a launcher, was:

```sh
export FOUNDRY_BROADCAST=/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02/docs/incidents/2026-09-16-dtf-recovery/migration/pricing/evidence/correction/broadcast
FOUNDRY_BLOCK_GAS_LIMIT=1000000000 forge script --use solar scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol:MigrationSnapshotLocalQA --rpc-url http://127.0.0.1:18546 --broadcast --unlocked --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
```

The new helper does not launch or alter this command. Its permitted parent command is exactly this Forge argv (the environment assignments are not argv). `positive-command.txt` records the actual recorder invocation through `env FOUNDRY_BLOCK_GAS_LIMIT=1000000000`; this is equivalent to the assignment above, not a different script contract.

## F1 negative: two available, otherwise identical local nodes

Fresh owned nodes, port freedom checked before startup and again inside each startup wrapper:

```sh
anvil --host 127.0.0.1 --port 18546 --chain-id 31337 --gas-limit 100000000 --silent
anvil --host 127.0.0.1 --port 18547 --chain-id 31337 --gas-limit 100000000 --silent
```

| Port | Anvil PID | Recorder PID | Initial nonce / block |
| --- | ---: | ---: | --- |
| 18546 | 95431 | 95429 | 0 / 0 |
| 18547 | 95439 | 95437 | 0 / 0 |

Both returned chain 31337, 100M gas limit, null fork URL and the same fresh genesis hash. Thus the rejection cannot be attributed to different chain IDs, dev accounts or a missing authorized service. No code-size-limit bypass was used; the 1B Forge setting is a finite whole-script simulation budget, not the actual node block limit.

The exact negative argv differed only in the selected endpoint:

```sh
FOUNDRY_BLOCK_GAS_LIMIT=1000000000 forge script --use solar scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol:MigrationSnapshotLocalQA --rpc-url http://127.0.0.1:18547 --broadcast --unlocked --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
```

`negative-command.txt` / `negative.log` / `negative-exit.txt`: command **1**, tee **0**. The trace reaches `VM::ffi`, rejects the actual parent CLI with `local QA requires exact Forge CLI`, and reverts without reaching `startBroadcast` or fixture deployment.

`negative-before-*` and `negative-after-*` show both listeners still available and both dev nonces/block numbers **0/0 before and 0/0 after**. The after-command asserts these values and exits **0/0**. Consequently neither endpoint received a deployment or any transaction during the mismatched attempt. Both endpoints were local-only; no nonlocal mismatch was attempted.

## F1 positive: actual mined receipts and historical reads

`positive.log` reports `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL`; command/tee exits **0/0**. The independent correction broadcast directory contains:

```text
broadcast/MigrationSnapshotLocalQA.s.sol/31337/run-latest.json
```

This path is relative to this correction evidence directory. It did not overwrite the original normal broadcast or verifier broadcast.

`rpc-receipts.mjs` fetched every mined block, transaction and receipt again from 18546. `mined-receipts.log` preserves each exact JSON-RPC request and full response, not just Forge's broadcast JSON. Its assertions require:

- **233** mined transactions/receipts, every receipt status `0x1`.
- Every sender is the standard dev account; transaction nonces are exactly 0 through 232.
- Latest and pending dev nonces both **233**; final block **233**.
- Every mined block has a **100,000,000** gas limit; maximum actual transaction gas **33,584,353**.
- The unused 18547 node remains at nonce/block **0/0**.

Auditor command/tee exits: **0/0**. This is not a 30M-block or target-chain gas feasibility claim.

Capture transaction: `0x62ce38bce79510802c79b490e03103a80db58f16c79a705a6e43857ba2d68dc8`, block **226**, status **1**, gas **3,842,683**, input `0xd4a3e9d7`, consumer `0x28dB1faE7d59B36aE6BBB939766F3F7F1c3eabec`. These values were read from the owned node; the matching raw receipt/transaction are in `mined-receipts.log`.

`mined-readbacks.log` records actual `eth_call` results at capture block 226 and final block 233:

| Native integer | Block 226 | Block 233 |
| --- | ---: | ---: |
| Frozen ETH original user | 1,192,506,671 | 1,192,506,671 |
| Frozen DTF original user | 1,773,603,429 | 1,773,603,429 |
| Frozen originals sum | 2,966,110,100 | 2,966,110,100 |

The script's unchanged assertions also compared the primary oracle before mutation and required effective trade plus unchanged frozen values/bytes after the existing real mutations. Its positive log reports changed live ETH/DTF outputs **1,290,890,931 / 1,566,579,720**. These are script outputs, distinct from the historical frozen readbacks above.

`snapshot-final-*`, command/tee **0/0**, compares both historical `snapshotBytes()` values, asserts **5,632 bytes**, and records identical keccak256 `0x47e50284db172e79d69227f05be428b960293e80ee4276a8acae17c3adb30208`.

Two recorder-only failures are preserved, not promoted to passes: `mined-readbacks-*` and `snapshot-readback-*` both exited **1/0** because the command string's final shell length expression was malformed. The former had already printed both component tuples and sums correctly. The failing length/equality receipt was completed separately with corrected `wc -c` arithmetic in `snapshot-final-*`; no transaction or deployment was repeated.

## F2: accurate coverage and invocation acceptance

`quote-evidence.md` now labels both originals as **zero executed tests, not an executed PASS**, despite Forge/tee exits 0/0:

1. Producer `../implementation/real-proxy-trace.log:94-98`.
2. Verifier `../verification/real-proxy.log`, with its preserved command/exit receipts.

Valid producer named-case coverage remains `../implementation/regression-final.log:3773`, inside its 111-test run. Valid independent coverage remains `../verification/real-proxy-exact-signature.log`: **1 passed, 0 failed, 0 skipped**, test gas **13,063,518**. Both logs and all original evidence remain unchanged.

The documented future command now uses:

```sh
--match-contract '^UniswapV4DetfMigrationSnapshotTest$'
--match-test '^test_MigrationSnapshot_RealProxyCaptureAndFreeze\(\)$'
```

Its `set -euo pipefail` invocation requires both Forge/tee success and a real exact-signature PASS plus `Suite result: ok. 1 passed; 0 failed; 0 skipped;`. Empty selection therefore cannot satisfy the invocation contract.

`coverage-gate.sh` applies those same machine-output checks to the preserved logs only. `coverage-gates-*` records each original log rejected with gate exit **1**, and the independent exact-signature log accepted with gate exit **0**; aggregate command/tee **0/0**. No test was run for this prose correction.

## Source hashes and preservation

SHA-256 values, with literal hash commands/exit receipts in `source-hashes-*`:

| Source | Final SHA-256 |
| --- | --- |
| `scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol` | `835f94e84920865b29b4236be04020cf3bf54a4dbc0834bb2e7c30b0bc20f037` |
| `scripts/recovery/dtf-migration/pricing-local-qa.sh` | `29de90e5b906195447f7fab8ca9f64f5430d6341687ce5142c9314e9aff17f76` |
| `migration/quote-evidence.md` | `629feb9a4f1452f0209a9f0dd4647673209eae52c67e6c1f6f358ad48bb24b8d` |
| Correction `run.sh` | `3de4c19ad0680b4d652e7d046bd18c6f9964caee6554f4cd43ce12642c6392e3` |
| Correction `rpc-receipts.mjs` | `c0934a011d56e20137b16639188b7e1bd81f3599cc6ea8ad742f1323fea8b953` |
| Correction `coverage-gate.sh` | `16f2db9c7951139b2e7fc5d079d8652d5899c7036244a027ef14b0431d8cb871` |

`edited-before.sha256` preserves pre-correction QA-script hash `003b66c4cdbcc30b8cf81ecdce58c66b824cf3c6f74d691d41560b47ab93d3ac` and quote-evidence hash `0536c8db963ef50414d1773f5e83020895f0ed4d64bbafc27e59556a613dec7d`.

`preserved-before.sha256` captured **5,351 existing files** before edits: production/test/script trees excluding the authorized QA script, existing migration documents/evidence excluding quote-evidence and this correction directory, and original normal broadcast outputs. Manifest SHA-256: `d8986ac5003850b4401b2d653ffe4d715bce027476aa76968f663b83a1b10350`.

`preservation-*` runs `shasum -a 256 -c` on that complete manifest, exits **0/0**, and reports all files OK, including the independent report, both empty-selection logs, valid regression/exact-signature logs, and original broadcast JSON/lock. Existing producer source manifests remain historical; only the QA-script entry has been superseded by the correction hash above. No other pricing source changed.

Native Solidity diagnostics on the corrected script returned **No diagnostics found** before compilation. Bash language server is unavailable; no dependency was installed. `preflight-*` records `bash -n` success for the guard/recorder; `coverage-gates-*` records gate syntax success. Known nightly-build and existing `fmt.skip` warnings remain visible. Successful Solar compilation and real execution are the verification gates, not an assertion that repository-wide warnings disappeared.

## Cleanup receipts and final limits

Owned temporary root (including its two cache directories):

```text
/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/pricing-correction.20261110-1549
```

`stop-nodes-*` verified listeners exactly matched PIDs **95431 / 95439**, recorded their full commands/parents, then sent SIGINT only to those two PIDs. Both native node monitors completed naturally with command/tee **0/0** (`anvil-18546-exit.txt`, `anvil-18547-exit.txt`).

At **2026-11-10 15:48:31 UTC**, `cleanup-*`, command/tee **0/0**, established:

- `ps` exits **1** for node PIDs **95431 / 95439** and recorder PIDs **95429 / 95437**: all absent.
- Both listener probes exit **1**; both actual HTTP probes exit **7**, connection refused.
- Removed only the owned root's `node-cache` and `bun-cache`, then the owned root; `test ! -e "$TMPDIR"` passed.
- Warm `out/` and `cache_forge/` retained, including allowed generated Foundry artifacts. No global or phase cache deletion.
- `lib/crane` and `node_modules` still resolve to the primary checkout; prior evidence/broadcast files remain hash-identical.

All finite build, script, readiness, receipt and node monitors completed. No owned node, temporary/cache root, pending transaction or background task remains. New correction evidence and its broadcast are intentionally retained. `*-command.txt` / `*-exit.txt` contain exact receipts for preflight, both builds, both node lifecycles, readiness, negative before/attempt/after, positive execution, receipt audit, coverage gates, historical reads (including the two explained recorder failures), preservation, hashes, stop and cleanup.

**Still open:** full task 2/E3 actual recovery composition, target-chain deployment feasibility, and lifecycle integration. No attribution, TokenStaking, surrender, activation, custody or entitlement decision is made by this correction.

## Recovery-context provenance follow-up

After the correction was delivered, root disclosed an accidental approximately 80-second redispatch of the original dependencies/domains/baseline nodes. No further code edit was made. Before this evidence-only addendum, current files were compared directly against `../verification/source-artifact-binding.json` and `../verification/preservation.json`; both manifests agree on all 17 original source hashes.

`recovery-provenance.json` records the comparisons and actual filesystem/process observations:

- **16/17 current authored sources match** the original verifier hashes exactly. The sole difference is the authorized QA guard correction: original `003b66c4...ab93d3ac`, current `835f94e8...c20f037`, both recorded in full above. The pre-correction hash captured by this executor matches the original verifier hash.
- **9/9 preserved implementation evidence files and the original normal broadcast JSON match** the independent preservation manifest exactly.
- A new quiet `shasum -a 256 -c preserved-before.sha256` check returned **0** for all **5,351** pre-correction files, including baseline evidence. No baseline evidence was overwritten by this correction or follow-up. This comparison does not independently reconstruct baseline bytes from before this executor's initial capture.
- At **15:52:06-15:52:29 UTC**, two unexpected **empty** directories remained under the shared phase temporary parent: `pricing-baseline.qs0jth` (mtime **15:38:18 UTC**) and `pricing-dependencies.rws0ar` (mtime **15:38:04 UTC**). These differ from the original baseline root `pricing-baseline.iud2vw`, documented as removed. The new empty directories predate this correction session and are consistent with the disclosed redispatch; their creator is not proven by filesystem metadata.
- `lsof +D` on the shared parent returned **1**, with no open handles. No active Forge build/test/script, Anvil, or phase-one/phase-two runtime command was found in the process snapshot. The only other Forge process was PID **96408**, `forge lsp --stdio`; its cwd was the separate **phase-03** worktree. It was not touched.
- Both QA ports remained without listeners. The named phase-one roots `verification.30kbMI` and `verification-final.xoextQ` were absent. The correction-owned root remained absent.

The two empty redispatch directories were **reported and left untouched**: they are not resources created or owned by this correction, and no other worker's temporary data was removed. The first raw baseline `stat` listing used local time despite a literal `Z` in its formatting; do not interpret those baseline timestamp strings as UTC. The subsequent resource-detail listing explicitly set `TZ=UTC`, and the directory times above come from that listing.

These are bounded source/evidence/resource checks, **not a claim that the redispatch had no side effects**. In particular, generated `out/`/`cache_forge/` contents and actions absent from the available manifests are not reconstructed by these observations. The original F1/F2 execution proof, unchanged pricing-source hashes and explicit open task-2/E3/lifecycle limits still stand. No build, pricing test, transaction, baseline write or code change was repeated for this follow-up.
