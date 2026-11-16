# Independent F1/F2 correction verification

Date: 2026-11-10. **AdversarialVerify: confirmed**, limited to the two corrections in `../verification/report.md`.

Both original findings have evidence-backed dispositions. The corrected exact local CLI independently mined 233 successful transactions. A second invocation, differing only in its selected local endpoint, failed at the CLI guard while the authorized endpoint remained available; neither node's sender nonce, genesis block, or mempool changed. The two historical empty-selection logs remain intact and are correctly described as zero tests, separately from the actual 111-test regression and independent one-test pass.

**This is not full task-2/E3 closure, a new full pricing verification, or Migration lifecycle acceptance.** Original bounded pricing/regression evidence stands because its source inputs remain unchanged. No unchanged test was rerun.

## 1. Handoff, scope, and source/artifact binding

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02`.

The required correction handoff was present and read, together with its three changed files, the original independent report and valid receipts, and the phase-two brief. The repository router, assistant coding/deployment/testing documents, Foundry runtime/script-safety skills, Anvil guidance, and Bun runtime instructions were read before execution.

| Input | SHA-256 |
| --- | --- |
| Original `../verification/report.md` | `aef29e4c5c6e233846c54ccaae33194acbacd4ce5be16744371900ed75861928` |
| Correction `../correction/report.md`, including provenance addendum | `6b9b0ced33a275e37461941ec7a04cc4ff3f22d009b7eae792993428dbe2ea2d` |
| `scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol` | `835f94e84920865b29b4236be04020cf3bf54a4dbc0834bb2e7c30b0bc20f037` |
| `scripts/recovery/dtf-migration/pricing-local-qa.sh` | `29de90e5b906195447f7fab8ca9f64f5430d6341687ce5142c9314e9aff17f76` |
| `migration/quote-evidence.md` | `629feb9a4f1452f0209a9f0dd4647673209eae52c67e6c1f6f358ad48bb24b8d` |
| Current QA script artifact | `abbfd032b1d383274240a954881e78671929904f5e43a91b78799433999ac5ab` |

Before execution, this verifier independently checked:

- All 17 original authored source hashes: 16 are unchanged; only the authorized QA script differs, matching the correction's declared hash. The helper and corrected quote report also match their declared hashes.
- Eleven current artifacts: nine original runtime artifacts, the named test artifact, and the corrected script artifact. Their metadata matches **599 unique current source dependencies**, with no mismatches. All nine original runtime artifact files remain byte-identical to the original verifier's artifact hashes.
- All **5,351 files** in the correction's pre-edit preservation manifest, with no mismatches. The original verifier's separate nine-file implementation-evidence manifest and original broadcast hash also match.
- All **210 pre-existing evidence files** across baseline, implementation, original verification, and correction were hashed before this run and checked again afterward.

`source-artifact-binding.json` contains the actual paths, hashes, dependency checks, and initial evidence inventory. `final-preservation.json` records no final source/artifact, historical-file, or evidence mismatch. Both shared dependency links still resolve to the primary checkout.

The correction's artifact-first and script-build command/exit receipts were inspected. The script build compiled successfully with Solar. Both independent script invocations reported `No files changed, compilation skipped`; no stale-artifact rebuild was necessary. These checks establish current binding, not reconstruction of every generated-cache action during the separately disclosed earlier redispatch.

## 2. F1 disposition: confirmed

### Source observation

`scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol:93-102` now checks chain 31337 and the dev sender, invokes the CLI guard through FFI, probes `anvil_nodeInfo` through the selected execution RPC, and only then calls `startBroadcast` and fixture initialization.

`scripts/recovery/dtf-migration/pricing-local-qa.sh:8-16` accepts no arguments, obtains the actual parent process command with `/bin/ps -ww -p "$PPID" -o command=`, requires executable basename `forge`, and compares the entire remaining command to the exact permitted CLI. A failure exits 1. This is no longer an unrelated fixed-endpoint availability check or caller-provided environment assertion.

### Independent runtime setup

Both ports were free before startup, and each startup wrapper rechecked its port. Fresh owned nodes were started with:

```sh
anvil --host 127.0.0.1 --port 18546 --chain-id 31337 --gas-limit 100000000 --silent
anvil --host 127.0.0.1 --port 18547 --chain-id 31337 --gas-limit 100000000 --silent
```

| Port | Node PID | Recorder PID | Initial latest/pending nonce | Initial block |
| --- | ---: | ---: | --- | ---: |
| 18546 | 5698 | 5696 | 0 / 0 | 0 |
| 18547 | 5705 | 5702 | 0 / 0 | 0 |

`nodes-ready.log` and `negative-before-rpc.json` show both services available, chain 31337, null fork URL, 100,000,000 block gas limit, and identical fresh genesis hash `0xf958d002cdecfff7c1992162690ded52a4832b138c5bb19dfb180726bb97a4fe`. Only the standard unlocked dev account was used. No private key, fork, public-chain action, or code-size-limit bypass was used.

The preflight selected Forge/Anvil 1.9.1-nightly and Solar 0.3.0-dev, compatible Solidity 0.8.38. It checked shell syntax, warm artifact/cache availability, and absence of inherited profile/fork/code-size/test-selection overrides. Every command ran through the owned `run.sh`, which records literal argv, UTC time, cwd, recorder PID, PATH, TMPDIR/cache paths, broadcast destination, and separate command/tee exits.

### Independent negative invocation

With **both nodes available**, this exact direct command was executed:

```sh
FOUNDRY_BLOCK_GAS_LIMIT=1000000000 forge script --use solar scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol:MigrationSnapshotLocalQA --rpc-url http://127.0.0.1:18547 --broadcast --unlocked --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
```

`negative-command.txt`, `negative.log:9-19`, and `negative-exit.txt` establish command exit **1**, tee exit **0**, and rejection at `VM::ffi` with `local QA requires exact Forge CLI`. The trace never reaches `startBroadcast` or fixture initialization. Forge instantiates the script driver inside its simulation before `run()`; that displayed driver creation is not a mined deployment.

`negative-after-rpc.json` independently queries both nodes again. Both remain available at exactly the same genesis hash, with latest/pending dev nonce **0/0**, block **0**, and pending/queued mempools **0/0**. Thus the mismatched node received no deployment or transaction, and the authorized node also remained unchanged. The failure is not explained by an unavailable authorized endpoint, wrong chain, different account, or exhausted funds.

### Independent authorized positive invocation

The positive run used the correction's exact direct Forge argv and a verifier-owned broadcast destination:

```sh
export FOUNDRY_BROADCAST=/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02/docs/incidents/2026-09-16-dtf-recovery/migration/pricing/evidence/correction-verification/broadcast
FOUNDRY_BLOCK_GAS_LIMIT=1000000000 forge script --use solar scripts/foundry/recovery/dtf-migration/MigrationSnapshotLocalQA.s.sol:MigrationSnapshotLocalQA --rpc-url http://127.0.0.1:18546 --broadcast --unlocked --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
```

The recorder passes the simulation-budget assignment through `env`, without changing Forge argv. `positive-exit.txt` records **0/0**; `positive.log:40` reports on-chain execution success. That alone was not accepted as receipt proof.

After reviewing its implementation, this verifier ran the correction's read-only `rpc-receipts.mjs` against these newly owned nodes, with output exclusively in this verification directory. `mined-receipts.log` preserves the full fresh RPC requests/responses:

- **233 distinct mined transaction receipts**, all status `0x1`, all from the standard dev sender, with sequential nonces 0 through 232.
- Authorized node latest and pending sender nonce **233**, final block **233**; mismatched node nonce/block **0/0**.
- Every mined block has a 100,000,000 gas limit; maximum actual transaction gas **33,584,353**.
- Every transaction in the verifier's separate broadcast artifact appears in the fresh RPC receipt set. Auditor command/tee exits are **0/0**; the computed summary is `mined-receipts.log:705`.

Fresh capture transaction: `0x62ce38bce79510802c79b490e03103a80db58f16c79a705a6e43857ba2d68dc8`, block **226**, status **1**, gas **3,842,683**, consumer `0x28db1fae7d59b36ae6bbb939766f3f7f1c3eabec`.

The deterministic transaction hash also appears in the producer's correction, but these are fresh receipts: the independently fetched capture block hash is `0xc38ff14d9cfac952b1a2c7f0c7bf7226aca2d340a7af1bf5e66066ab8663a6ed`, not the correction's `0x49f8bfd7fe27f70bb4b052c1f913d70a9289d74018faba0321bec48ce2bd558e`.

`positive-readbacks.json` records fresh historical `eth_call` requests and decoded results at capture block 226 and final block 233. Both yield ETH original **1,192,506,671**, DTF original **1,773,603,429**, sum **2,966,110,100**, and identical **5,632-byte** snapshots with keccak256 `0x8091af243f6786523c82f07b4149040fb26a49ccc8c1b214813adf12d46ba1ab`. The script's unchanged oracle/mutation assertions also succeeded; its final live outputs were 1,290,890,931 and 1,566,579,720.

This confirms usability of the authorized invocation and rejection of the tested endpoint mismatch before deployment. It does not establish deployment feasibility under a 30M block or an untested target-chain cap.

## 3. F2 disposition: confirmed

`migration/quote-evidence.md:107-117` correctly labels both historical exact-filter invocations as **zero executed tests, not an executed PASS**, while retaining their original command/log/exit receipts. It separately cites the actual producer named-case pass at `../implementation/regression-final.log:3773` and the independent exact-signature run.

The independent checks in `f2-receipt-check.json` found:

| Preserved log | Actual execution evidence |
| --- | --- |
| `../implementation/real-proxy-trace.log:94-98` | Empty selection; 0 PASS lines |
| `../verification/real-proxy.log:5-9` | Empty selection; 0 PASS lines |
| `../implementation/regression-final.log:3773,3814` | Named-case PASS and 111 total passes, 0 failed/skipped |
| `../verification/real-proxy-exact-signature.log:7,3340,3342` | Named-case PASS, gas 13,063,518; 1 passed, 0 failed/skipped |

The current test artifact's metadata binds to unchanged sources. The exact executed test command and exit receipts were inspected, not inferred from the report. These are **accepted prior passes**, not new test executions by this verifier.

The originating future-invocation contract at `migration/quote-evidence.md:119-130` uses:

```sh
--match-contract '^UniswapV4DetfMigrationSnapshotTest$'
--match-test '^test_MigrationSnapshot_RealProxyCaptureAndFreeze\(\)$'
```

Its fresh log is written by `tee`, not appended. `set -euo pipefail` requires Forge and tee success, followed by checks for the exact named PASS and `Suite result: ok. 1 passed; 0 failed; 0 skipped;`. Exit 0 or an old counter alone is insufficient.

This verifier independently ran the documented gate against the preserved logs only. `coverage-gates.log:1-4` records rejection of both zero-selection logs with gate exit **1** and acceptance of the real exact-signature log with exit **0**; aggregate command/tee exits **0/0**. No test, production source, policy, plan, or prior report was edited.

## 4. Cleanup and preservation

Owned temporary root:

```text
/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/pricing-correction-verification.st01a1c62a
```

`stop-nodes.log` verifies the exact listener PIDs, records their commands/parents, and reads empty pending/queued mempools on both nodes before sending SIGINT only to **5698** and **5705**. Both node monitors completed naturally, command/tee **0/0**, at **16:00:50 UTC**.

`cleanup.log`, `cleanup-command.txt`, and `cleanup-exit.txt` establish at **16:01:33-16:01:35 UTC**:

- Both node PIDs and all nine earlier command-recorder PIDs are absent; each `ps` probe exits **1**.
- Ports 18546 and 18547 have no listeners; each listener probe exits **1**.
- Both actual HTTP JSON-RPC endpoint probes fail with curl exit **7**, connection refused.
- Only the owned node/Bun cache directories were removed, followed by the owned root; `test ! -e "$TMPDIR"` passed.
- Warm `out/` and `cache_forge/` remain, and shared dependency symlinks retain their original targets.
- Cleanup command/tee exits **0/0**; its monitor also completed. No owned command, node, pending transaction, or temporary root remains live.

Evidence and the separate verification broadcast are intentionally retained. Forge also wrote its normal generated sensitive-values cache under `cache_forge/MigrationSnapshotLocalQA.s.sol/31337/`; no signing key was supplied. Shared warm caches were not deleted or represented as immutable evidence. All 5,351 manifest-listed historical/source files and all 210 separately inventoried pre-existing evidence files remain byte-identical after execution.

No delegation, Git operation/commit, install, public RPC transaction, product/script/test edit, or broader audit was performed. The only authored files are inside this correction-verification directory; other writes are the authorized runtime outputs. Bash language-server and Biome diagnostics were unavailable; nothing was installed. Shell syntax checks, actual executions, RPC evidence, and JSON construction were used instead. Existing nightly/`fmt.skip` warnings remain visible.

### Root-owned redispatch cleanup follow-up

Root subsequently reported reading the complete correction report, including its recovery-provenance addendum, and inspecting the negative, positive, and cleanup receipts. Root removed only the two reported empty redispatch directories `pricing-baseline.qs0jth` and `pricing-dependencies.rws0ar` under `/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI`, using `rmdir`, then checked `test ! -e` for both. The root-session `bash_10` reportedly exited 0 with `REDISPATCH_EMPTY_ROOTS_REMOVED_AND_ABSENT`. Root states that this cleanup changed no source or evidence file.

This is root-reported cleanup of the separately disclosed redispatch resources, not an operation performed by the correction executor or this independent verifier. Its root-session `bash_10` is distinct from this verifier's own cleanup session. This addendum records the ownership and reported receipt without presenting it as an independently repeated cleanup check. Generated `out/` and `cache_forge/` side effects of the redispatch remain unreconstructed; removing two empty directories does not establish zero redispatch side effects. The F1/F2 disposition and full task-2/E3 limits are unchanged.

## 5. Residual exposure and bounded conclusion

The guard is an operational check of the exact direct CLI on this trusted local host. It is intentionally sensitive to argument order/spelling and depends on Bash, FFI, and `ps`. It is not an authentication boundary against a malicious replacement executable, a modified helper, or a forwarding service placed at the permitted loopback address. This run independently established ownership and no fork on both actual nodes; it tested only the authorized endpoint and the specified otherwise-equivalent local mismatch. No nonlocal endpoint was exercised or certified.

F1 and F2 are **confirmed corrected** under their original corrective acceptance conditions. The original independent needs-fix report remains preserved as historical evidence; `verdict.json` is this new, bounded disposition.

Full task-2 actual-configuration E3 and lifecycle integration remain **not closed**. No new claim is made about production recovery asset/routes, unavailable source getters or unsupported models, actual configured-oracle binding, target-chain gas feasibility, attribution, TokenStaking, surrender, activation, custody, or entitlements. The earlier redispatch's unmanifested generated-cache effects are not reconstructed by this verification.
