# F3 real manual QA: bounded partial evidence

Date: November 15, 2026. Independent reviewer: this session. Verdict: **confirmed**, failure class **none**, exclusively for the accuracy of the bounded partial-evidence package. **Full goal met: false. Known unmet tasks: [10,12,13,14,15]. Full real lifecycle is not accepted.**

No genuinely new inconsistency requiring rejection of the bounded claims was established. Historical statements about unchanged source and open donor/pin blockers must retain their dates; they are not current claims. The source comparison below further limits reuse of task-11 evidence.

All paths are relative to `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.

- C: `.omo/ulw-execute/dtf-conformance/owner-correction-20261115/`.
- E: `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/`.
- T: `E/task-10/owner-correction-20261115/`.
- R49: `T/runtime-attempt-09/rehearsal-1794767163207/`.
- R52: `T/runtime-attempt-10/rehearsal-1794768218770/`.
- B: `E/final/owner-correction-20261115/boundary/`.

## Authority and actual review channel

I read the bounded brief, current plan F3 and bounded-final-wave override, incomplete task-10 claim/verdict, confirmed issuance/census gate, actual command/receipt/trace/state files, retained gas evidence and historical task-13 outputs. I sent the preparation note before any final write, then awaited the boundary claim through a single native file subscription. The create event delivered and the watcher completed. `C/partial-boundary-done.json`, recorded at 19:43:30.099Z, was read before this report.

The real surface is the saved `T/attempts/52-portable-cli/command.json`:

```text
bun scripts/recovery/dtf-migration/cli.ts rehearse
  --bundle T/authorities-bundle/bundle.json
  --rpc-alias robinhood_mainnet_alchemy
  --fork-block 108944663 --port 18575
  --checkpoint .omo-runtime/dtf-migration-portable/checkpoints
  --evidence T/runtime-attempt-10
```

Here T expands to the absolute evidence directory in the actual argv; cwd is `T/qa-checkout-01`. Start was 18:43:38.616Z. This is a reading of the actual command receipt, not a new command invocation or replacement binary.

I reused the settled signature/authentication conclusions in `C/task-10-verdict.json` and independently inspected the retained underlying observations below. I did not repeat the complete signature corpus, historical archive authentication or checkpoint hashing already settled there. No new chain query, simulation, test, build, install, Anvil run, transaction, delegation, Git operation or source edit occurred.

## Actual observations and their limits

| Observation | Exact retained evidence | What it establishes and does not establish |
| --- | --- | --- |
| Local donor transfer | R52 `setup-funding-transfer.json`; transaction `0x32c40dbe164f2578efc8693bd4ac11f6c80562d527aedae62a9904d255108327`, status `0x1` | Donor `0x0da0877ab57a89e5db9125069fa8cd3702536e37` decreases from 1160555124327723708919833 to 1150555124327723708919833 raw DTF; developer rises from zero to 10000000000000000000000. Transfer log agrees. Compensation exclusion, pre-setup NFT position and no public-funder approval are recorded. This is a genuine local fork transfer despite the setup's `synthetic-local` purpose label. It does not certify a complete no-manufactured-history lifecycle or public allocation. |
| Deployment | R52 `deployment-receipt.json`, transaction `0x12dcbd47492f6de1517e489ce701b7185ea9357ceeb27c04f7dc012ccae30ad7`, status `0x1` | Actual deployment and proxy/registry logs are retained. This does not prove later activation, complete selector removal or every child/custody behavior. |
| Configure A interruption | R52 `configure-a-before-resume.json`, `044-configure.log.command.json`; R49 `journal-interrupted-a/e516ee0b340ae8bbcbd98fd4ac19d3efb9fc29b66e8000fc522bc859631e239b.canonical-chain.json` | Signed transaction `0x8614d4e76a949cd7414587de30b88f9605b108f8b35fad31643ec3e00c8494d7`, nonce 2230, mined successfully before completion. Command records `SIGKILL`, code null, with `--fault-after-mined`. Saved R49 header, ordered transaction list, receipt/index/log and successful call/delegatecall trace agree within that run. Configuration event records 736 native credit. This proves interruption, not A recovery after B. |
| Independent B setter | R52 `independent-owner-b/set-pricing/9cb83a43f7d864409ba38e26d39e871196672d002eca8764491977d42b2ef7f0.receipt.json` and original journal | Transaction `0x6a0fe35c9f274e05d7043e4c7e734d742ea46cb94f93462ac9563cd1c66f1fcb`, status `0x1`, sets book `0xc00ae1d4a2af803c2ce2fdc7b7cb7d2b7b9d1d0cd3941f1c8ee186ecb7b25340`; event and captured state agree. A is in block `0x67e5e87`, B in `0x67e5e88`: this is not same-block proof. B is a later partial observation and does not repair deadline compliance. |
| Donation receipt recovery | R52 `donation-before-resume.json`, `donation-resumed.json`, `donation-identity-resume.json`; settled task-10 verdict | First donation `0x9855a1646ff910da4cdb96e9b3fc7c98364a6eb49428e7117b220db413ff69a0` has actual transfer/capital events and retained inventory state. Two distinct donation IDs use identical donation calldata with six distinct approval/donation operations. Settled authentication supports the second hash `0x7c367d4e52ffcbe806215af93f654d487c9702ce5557e9a03e2b661b8e986895`, recovered original receipt and zero completed resends. The completed/resumed nonce is `0x894`. This narrow success is not lifecycle acceptance. |
| Controlled failures | R52 rejection files, including `018`, `020`, `021`, `026`, `028`, `032`, `033`; task-10 verdict's exact scenario mapping | Read records show controlled INPUT/PROVENANCE/STATE failures and unchanged captured before/after nonces. Rejected owner-bond/activation commands are not successful owner purchase/activation. The completed stale signed-A-after-B and full final tamper corpus remain absent. |

R49's canonical A header hash is `0xf141985a68fbbe440b4d888fe6d2251905603b5b0d1720515049602bf24dda4b`; R52's A receipt uses `0x28a6577c0293dc5ca7be6c0c3350ab4bb6bf076a4ca2e47ff43f7ad2a477b992`. Identical deterministic transaction hashes across independent local forks do not make their block/domain evidence interchangeable. No R49 trace is presented as R52 canonical evidence.

`T/owner-root-fix-and-retained-evidence.json` identifies the shared-root LOCK failure in attempt 49 and the separate-owner-root repair used in attempt 52. The latter permits the observed independent B action; it does not prove the unresolved A continuation. The preserved interrupted-A checkpoint still contains an intent and lock, with no completion. A preserved lock is historical interruption evidence, not proof of a surviving runtime or a ready-to-replay relocated domain.

## Unproved real behavior

The bounded outcomes and independent task-10 verdict accurately leave these requirements unmet:

- Complete A-after-B recovery without resend, retained/new mixed records, and the same recipient's B configuration with immutable A issuance.
- Actual same-block A/B ordering, transaction-prefix recovery and transaction-local tamper rejection.
- Successful paid owner-first purchase/recovery, setter after that purchase, unset-pricing activation, and the final removed/retained selector census.
- Original-wallet NFT 3 surrender, two distinct exactly funded bonds/principals/gons, aggregate backing/supply conservation, fresh 90-day clocks and cliff-minus/exact/plus-one claims.
- Separate receiver second-callback rollback of both bonds and custody, followed by funded success.
- Complete postactivation source admission/surrender, repeated reward-only recovery retaining principal/custody, ordinary-deposit/delayed-clock behavior and portable mixed-book/issuance-history followthrough.

The six final scenario files named absent in the task-10 verdict are not supplied by setup, preparation, initial issuance, gas experiments or unit tests. Their absence remains known unmet work, not a new authorization to execute it.

## Current unit/CLI gate and historical gas

`C/issuance-census-repairs-verdict.json` confirms 336 tests, zero failures, unchanged 15000 ms timeout, strict operator types, and retained helper types. Its CLI main was invoked in-process on synthetic loopback transport, with zero sends/nonce requests; an expected thrown omission error was not a separate negative-process exit. It explicitly excludes real rehearsal. Current raw hashes of `execution-domain.ts`, `execution-state.ts` and `execution.ts` match the boundary's admitted repair bindings. The helper-type historical 28/29 coverage limit remains; no missing historical identity is invented.

I read task-11 `verification/report-r2.md`, `batch-limits.md`, accepting command/exit record, raw log ending, `signed-envelopes/{operation-gas,transactions,constrained-receipts,source-manifest,cleanup}.json`, and task-13's historical reuse audit. Direct enumeration confirms **51 samples, 299 records, 298 distinct transaction hashes**. Four successful construction receipts cover two parents, with gas used 19,746,754; 29,860,062; 19,595,874; 29,298,754. This retains the accepted two-owner construction scope; it does not prove the task-10 owner/activation lifecycle.

The historical applicable gas limit is 32,000,000 on chain 4663 at block 108944663, hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`. The permissive local 100m limit is not target policy or ArbOS fee emulation. Measured batch axes do not admit their Cartesian product or arbitrary calldata. Recovery snapshot branches were canonical at capture and subsequently reverted; 299 records are not 299 distinct surviving final-chain transactions.

Fresh offline comparison of the accepting task-11 `commands.json` source map finds **189/221 current matches and 32 changed entries**, including **11 entries in the historical reachable-helper list**. All **65 recorded contract/gas-generator/helper paths** selected as contracts, `MigrationDeploymentGasResumedQA`, or `verify-bounded-deployments.ts` match. Historical report statements that all sources, or all reachable modules, matched were observations at their earlier review times. They cannot certify the current CLI/import graph. The saved gas measurements remain evidence at their captured source applicability; no fresh current-helper execution or complete runtime-byte certification is inferred.

## Task-13 historical qualification

Actual recorder `results.json` files and raw log endings support the historical build exit 0, hermetic exit 0 with 28,641 passes, and pinned-fork helper exit 0 with 183 passes. Historical operator output has 240 passes, one failure and exit 1; its fixed witness-pin failure predates the owner-directed removal and current 336-test gate. Neither that obsolete pin requirement nor task-13's older donor-blocker wording is reinstated. Initial failed toolchain attempts remain historical failures.

These are captured-source results, not renewed complete final-tree acceptance. The later operator gate does not retroactively turn the old task-13 result green or supply missing real lifecycle evidence. Task 13 remains closed unmet.

## Cleanup, dirty state and boundary

`T/bounded-stop-termination.json` records the real forced stop: command session `bash_37` killed, deadline session `bash_38` killed, normal result absent and normal process exit null. The monitor's exit 1 is not a normal rehearsal exit. The saved lsof probe for port 18575 exited 1 with empty output; owned process rows and pending owned resources are empty. Cleanup is supported by those retained receipts, not a fresh process/network probe. The independently settled preservation covers 107 checkpoint files and 677,799 bytes; no checkpoint domain was rewritten for this review. Task-11's saved cleanup says its node exited on port 18561.

The ten rehearsal WIP paths in `T/bounded-stop-source-inventory.json` remain isolated, uncommitted and unlanded. `rehearsal-data.ts` mixes the confirmed generated pricing-ABI binding with unverified broader fixture changes. No blind revert, merge or cleanliness claim follows. The confirmed operator repair is distinct from that WIP.

I read the actual boundary claim and `B/boundary.md`. The published inventory's 33,680,555 bytes hash to `e6a417a096e2746cfb48a85edbd5f3ad86b793cf4eca0a4a48354db301a7c8d0`, matching the claim. Published destination entries are 123,368; the corrected recorder receipt's earlier snapshot is 123,361. These are different additive capture points.

`B/commands/delivery-corrected/result.json` has actual exit 1, signal null; `B/delivery-corrected/delivery.json` says completed false. Its 340 messages classify as two checks for each of 166 preserved symlinks plus two checks for each of four retained divergences: `recovery-route-disposition.md`, `resumed-integration/verify-bounded-deployments.ts`, `source-manifest.json`, and `source-route-matrix.md`. The boundary prose also retains pointers to the earlier failed delivery; the final claim explicitly identifies the corrected failed receipt. Neither is a green task-15 result. Link text/catalog preservation is not external-target availability or behavioral verification. Exterior companion identities are not revalidated by the migration-tree recorder itself.

The current inventory, historical evidence, failed attempts and source tombstones are disclosed. This review does not certify every archive byte or an exhaustively clean worktree. Its new files are additive and require the coordinator's subsequent additive closeout; they were not represented as present in the preceding baseline.

The requested programmatic reads of `B/task-owned-files.json` and `B/ownership-dispositions.json` confirm 311 exterior entries, ten WIP paths, the single mixed-ownership `rehearsal-data.ts` path and the same known unmet tasks. The ownership category counts describe the earlier 123,312-entry discovery capture; the published inventory includes later additive bookkeeping entries. Both delivered helpers have regular-file entries in that inventory. The changed signed-gas helper's identity is `3bab69eab0e0f97d91fb7cca12de36340360563144e8154e135afc823e84b895`, matching the retained task-13 identity rather than the earlier origin. The recorder's original archive/supersession is distinguished from the four unresolved differences. No new contradictory completion claim was found. A final teardown request for the resolved subscription's returned handle `watch_1` returned `No terminal session found with id: watch_1`; no live watcher was rearmed.

The subscription completed without rearming. I started no runtime and have no pending runtime resources. Only this report and `C/F3-verdict.json` are authored; the verdict is the last file write. Evidence reading and offline JSON/hash/count checks are the manual QA for this bounded review. No product acceptance check was rerun, and no release, landing, public action or reopening of closed work is authorized.
