# Task 11 independent verification, round 2

Date: 2026-11-15. Verdict: **confirmed**. Failure class: **none**.

The authorized harness repair closes H1 and H2. Confirmation covers task 11's measured batches and signed gas evidence, with the qualifications below. It does not certify task 10, authorize implementation, or replace the first verdict.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
Plan: `/Users/cyotee/Projects/indexedex/.omo/plans/dtf-migration-conformance-remediation-20261114.md`, task 11, lines 505-525.
All paths below are relative to this worktree. `E11` means `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-11`.

The claim was treated as untrusted and read completely. Its size remained 16970 bytes, and a subsequent complete byte read matched. Its SHA-256 is `5b6981a70a64ab2c2ff104727d575a3ff32b85b392077f93c8642df687ed6300`. The claim's complete status was not used as evidence of confirmation.

## Immutable evidence

Independent local SHA-256 calculations matched all three required pins:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `E11/attempt-signed-final/raw.log` | 2009879 | `8564769f3fe4ee7641327b0274c706a3d7e06528818a391d84323b5eeb9df641` |
| `E11/gas-negatives.json` | 113771 | `37568eb59592305665dbe4bee56f65d11d28ee850b743a70192dcb6d9baa82a8` |
| `.omo/ulw-execute/dtf-conformance/task-11-done-attempt-1.json` | 11316 | `1145910001463fce554ed877b6fd42f1e1b4986b74336eed14c8850b613c3d49` |

The archived prior claim therefore matches the exact original claim fingerprint in the first verdict. The first report still matches its recorded SHA-256, `d7612428575e4c5ba506ca5758b549634540f4f4b29b7482ef49289938680c10`. The first verdict was read and left untouched; its current SHA-256 is `2c5a2a9a0a275f04deb41954ec7aa4d62ec89b766ea9f87d4cec0358b27bb34c`. No earlier verdict hash was supplied for comparison.

## H1: complete negative witness binding

Disposition: closed by a provenance-backed supplement.

`E11/harness-repair/negative-supplement.json` has SHA-256 `6e28766f586ba48037e815a70bb817491fefc83e0b6b0c20d6f18bc82af59460`. Its `completeNegativeWitness` is structurally identical to the entire preserved `gas-negatives.json`, including full signed bytes and receipt. Its exact argv matches raw log line 1 and the accepting `commands.json`:

```text
bun docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-11/signed-envelopes
```

Raw line 2 contains the command before output, line 57 contains the negative summary, line 65 contains `EXIT_CODE 0`, and line 66 records a null signal. The supplement's commands-file SHA-256, `630cb08e5c31b5e1f36c339b50dfedd46308963d58c088cc55395dc28954857a`, matches the actual file. Its producer-source SHA-256, `3bab69eab0e0f97d91fb7cca12de36340360563144e8154e135afc823e84b895`, also matches current source and the accepting source map.

The raw summary's boundary object equals the preserved witness. Its failed transaction hash and saved nonce join exactly to the complete witness:

- Boundary: 64 independent issuance recipients, simulation gas 32000000, rejection before signing or sending, zero calls for both, and nonce unchanged at `0x87e`.
- Underfunded transaction: locally decoded legacy signed bytes contain chain 4663, gas 1000000, and nonce 2184 (`0x888`). The receipt hash is `0x05c7ecca9273a352ce920a57eea5805ca620ccac6a30c89f2cb8161c4ec387de`, status is `0x0`, gas used is 987108, and logs are empty. Before and after configuration hashes both equal `251b5acb73ab38ce907a18c3051d096d8f546d3742b4d0993d6788a376ff952f`.
- Oversized saved intent: locally decoded signed bytes contain chain 4663, gas 32000001, and nonce 2185. The complete witness records rejection, nonce before and after `0x889`, zero signing during validation, and zero sends.

The supplement expressly says original stdout omitted the underfunded signed limit, full receipt/status, rollback hashes, oversized saved-intent gas, and validation counters. This review preserves that distinction. Those fields are authenticated supplemental witness data, not reconstructed stdout.

The underfunded pre-nonce is a qualification rather than a remaining defect. The separate pre-read RPC response was not retained. The decoded signed nonce establishes the submitted envelope's nonce; the source at `docs/incidents/2026-09-16-dtf-recovery/migration/resumed-integration/verify-bounded-deployments.ts:210-242` reads the latest nonce immediately before signing, waits for a mined failed receipt, checks rollback and empty logs, then saves and checks the subsequent nonce. Raw line 57 independently joins the failed hash and post-failure nonce `0x889`. This supports the required failure/rollback witness without claiming an independently saved pre-read. A failed mined transaction consumes its nonce; rejected validation does not.

## H2: exact historical policy capture

Disposition: closed by the authorized read-only capture.

`E11/harness-repair/policy-binding.json` has SHA-256 `19f715df645b96ff57c4421654b32794b27ac5d7aa4bfa3cc52572c51ab7a3cc`. `policy-capture.log` is 3646 bytes with SHA-256 `e808c5e6eec229b92f73671c87f8feb06f65186e45919cbb70c8fe33e867c7c0`.

Each exact argv appears before its output:

| Raw lines | Captured command after `/Users/cyotee/.foundry/bin/cast` | Result and exit |
| --- | --- | --- |
| 5-12 | `chain-id --rpc-url robinhood_mainnet_alchemy` | 4663; exit 0 |
| 15-20 | `block 108944663 --json --rpc-url robinhood_mainnet_alchemy` | Exact pinned header; exit 0 |
| 24-31 | `call 0x000000000000000000000000000000000000006c "getMaxTxGasLimit()(uint256)" --rpc-url robinhood_mainnet_alchemy --block 108944663` | 32000000; exit 0 |

Line 18's complete JSON header parses successfully and equals the binding's header object. It records number `0x67e5d17` (108944663), hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`, and gas limit `0x4000000000000`. The raw log also records the getter signature, called address, selector `0xaae1cd4c`, block tag, and RPC parameters. Capture exit is 0 at line 33.

The bound `foundry.toml` SHA-256 matches current bytes. Line 91 maps the same archive alias to the Robinhood Alchemy endpoint template. The original signed-run manifest still binds the unchanged diagnosis JSON hash `4b31c4a85d992dabdba1c97389bde803064520566c5222bf39840490590afacf`, with the same chain, block, hash and limits.

The applicable minimum is 32000000. The helper's local Anvil limit 100000000 is a permissive experimental setting, explicitly separate from target policy in both source and repaired capture. Captured `chain-id`, `block`, and `call` operations are reads, not public transactions. This verifier made no RPC requests. The capture is new historical-pin evidence, not recovered original stdout; the repair's bounded search is not treated as exhaustive.

## Preserved results and adversarial assessment

Every `happyQA` entry still names the same command and raw log as the archived prior claim. Only the signed-record count wording and its branch qualification changed. The four construction entries are unchanged.

Local inspection of retained evidence supports the already accepted counts: 14 individual Forge passes and an exit-0 summary in `attempt-forge-2/raw.log`; 46 operation rows plus five recovery rows in the unchanged accepting signed log; 51 entries in `signed-envelopes/operation-gas.json`; 299 entries with 298 distinct hashes in `signed-envelopes/transactions.json`; and four construction receipts for two parents. Their gas used is 19746754, 29860062, 19595874, and 29298754. No execution was rerun.

The recovery samples retain their snapshot-branch qualification. Receipts were canonical at capture and some branches were subsequently reverted. These counts do not represent 299 distinct surviving transactions on one final chain. Measured axes are not a promise for arbitrary calldata or their Cartesian product.

| Adversarial concern | Assessment |
| --- | --- |
| `misleading_success_output` | Confirmation uses exact command/exit joins, not PASS text or complete status. Retained `adversarial/results.json` records misleading success text with exit 7 rejected. |
| `stale_state` | All 221 accepting-run source-map entries match current bytes. The claim remained unchanged across complete reads. All required immutable hashes matched. The retained stale-reference rejection was inspected, not rerun. |
| `dirty_worktree` | The 217-file initial source map has 214 unchanged files and exactly the three previously allowed changed files: `execution.test.ts`, `MigrationDeploymentGasResumedQA.s.sol`, and `verify-bounded-deployments.ts`. None is a product contract change. Protected rehearsal and claimed-SY witness sources match. No Git command was run; this is source-map evidence, not an exhaustive working-tree inventory. |
| `generated_or_cached_artifacts` | Retained probe evidence records rejection of altered cached ABI bytes. Accepting source fingerprints still match; prior supported build/count evidence is retained. No fresh rebuild or complete independent runtime-byte certification is claimed. |
| Hung/flaky/cancel/interruptions | Not applicable to this review because no commands or economic operations were rerun. The producer's historical synthetic timeout probe is not a new verifier execution. |

No product behavior change, witness-pin retune, public send, or invented task 10 lifecycle was found in the inspected evidence. All accepting-run source fingerprints remain unchanged after the harness repair. This is bounded local provenance evidence, not an independent network audit or an exhaustive claim about unlisted files.

Task 10 remains outside this verdict: the missing authority-bundle donor, mixed-book lifecycle, and NFT 3 two-bond rehearsal are not supplied or certified by gas experiments. Task 12 and final-wave checks are separate.

This verifier performed local reads, hashing, JSON comparisons, and legacy-envelope decoding only. No Forge, bun CLI, Cast, RPC, installs, commits, delegation, product edits, claim edits, or first-verdict edits occurred. The only authored files are this report and the second verdict, which is written last.
