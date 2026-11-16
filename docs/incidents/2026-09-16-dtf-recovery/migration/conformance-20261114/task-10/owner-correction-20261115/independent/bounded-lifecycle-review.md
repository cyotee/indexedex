# Independent task-10 bounded lifecycle review

Disposition: **needs-fix**, failure class **harness**. Task 10 is incomplete. This is a bounded evidence closeout, not permission to resume implementation, acceptance work, or QA. No new product defect is established by the incomplete run.

## Identity and evidence roots

Independent verifier session: `st_01a1e077`. Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.

Paths below are relative to that worktree unless stated otherwise.

- C: `.omo/ulw-execute/dtf-conformance/owner-correction-20261115/`.
- E: `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/`.
- R49: `E/runtime-attempt-09/rehearsal-1794767163207/`.
- R52: `E/runtime-attempt-10/rehearsal-1794768218770/`.
- P52: `E/bounded-stop-runtime-01/checkpoints/`.

R49 was discovered from attempt 49's retained command `--evidence` argument and its actual child directory. R52 comes from the genuine `C/task-10-done.json` handoff and agrees with attempt 52's command metadata. Neither directory was guessed. A successful final `rehearsal-location.json` was not emitted; neither was a normal attempt-52 result.

The entire current task-10 plan block, admitted repairs and acceptance criteria were read. Preparation mapped 20 evidence groups before the final claim. Prior failed runs and synthetic transport repairs were kept separate from real lifecycle evidence.

## Clock and command outcomes

The original interval was November 15, 2026, **14:55:25.715Z to 18:55:25.715Z**. It was not reset. `checkpoint-bound-observation.json` records the run still active at 18:56:48.717Z with the last observed CLI at initial verification. The termination record was written at 19:06:05.503Z and the incomplete claim at 19:08:01.515Z. These later observations do not make the lifecycle complete within the bound.

- Attempt 49: `bun scripts/recovery/dtf-migration/cli.ts rehearse` with the complete authority bundle, alias `robinhood_mainnet_alchemy`, block `108944663`, port `18575`, and the fixed portable checkpoint. Started 18:26:03.092Z; finished 18:41:02.764Z; **exit 1**. Retained stdout/stderr bytes and hashes match the result metadata.
- R49 `044-configure.log.command.json`: real configure with `--fault-after-mined`; intentional **SIGKILL**, no normal exit code. Its output names the mined transaction and nonce.
- R49 `045-set-pricing.log.command.json`: **exit 1**, `LOCK: second active execution under operator root`. The independent owner action incorrectly shared A's active root.
- Attempt 52: the same real rehearsal surface, after moving only B's checkpoint into a separate owner root. Started 18:43:38.616Z; **forcibly terminated**, no normal process exit code, result, or successful finalization. Termination monitor exit 1 is not a successful rehearsal exit.
- Seven retained preparation negatives: actual command **exit 1**, controlled INPUT, PROVENANCE or DOMAIN errors, and identical captured before/after nonces. These include absent/false/combined NFT-three mode, missing ETH/DTF originals, wrong issuance history and unsupported book C. They do not replace the missing final negative corpus.
- Settled `C/issuance-census-repairs-verdict.json`: 336 passing, 0 failing tests at the unchanged 15000 ms timeout; strict operator types passed. Retained helper types passed with the explicit historical **28/29** reachable-file inventory limit. Reused without rerunning. This gate excludes real Anvil lifecycle acceptance.

## Authenticated partial observations

R49 configure A transaction `0x8614d4e76a949cd7414587de30b88f9605b108f8b35fad31643ec3e00c8494d7` is genuinely signed for chain 4663, sender `0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`, proxy `0x14501775250f84ea2547cb913ff111448ae64641`, nonce 2230. The raw signature, transaction input, original journal domain hash, successful receipt, canonical header/block/index and successful call trace agree. The source-bound ABI decodes `IndependentAllocationConfigured` for the intended recipient and 736 native credit. Completion was absent. This proves the real mined configure interruption, not recovery after B.

Attempt 49's 160 source bindings were compared against both current delivered files and runtime checkout: 159 matched; only `rehearse.ts` differed after the owner-root repair. Attempt 52's 160 source bindings all match both current locations. No production operator or contract mismatch was found in this comparison.

R52 retains signed owner-B setter `0x6a0fe35c9f274e05d7043e4c7e734d742ea46cb94f93462ac9563cd1c66f1fcb`, nonce 2231, successful receipt and `MigrationWeightedPricingSet` completion for book `0xc00ae1d4a2af803c2ce2fdc7b7cb7d2b7b9d1d0cd3941f1c8ee186ecb7b25340`. Its signature/receipt, original domain and canonical-object intent hash agree. It is a retained post-bound partial observation, not in-bound scenario completion. R52 A still has no completion in the preserved checkpoint.

R52 setup funding selects `0x0da0877ab57a89e5db9125069fa8cd3702536e37` from the contained transfer evidence. CSV hash `c840d060c5c7119a1f4777730d726fc0e0390e87ed3190ea0b4b841e99417939` and 4,535,122 bytes match; the donor occurs in those bytes. Pinned header is block 108944663, hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`. Captured pinned and immediately-before balances agree at 1160555124327723708919833 raw DTF; after balance is 1150555124327723708919833. Developer balance rises from zero to exactly 10000000000000000000000 raw DTF. Transfer receipt `0x32c40dbe164f2578efc8693bd4ac11f6c80562d527aedae62a9904d255108327` has status 1. The record excludes the donor from compensation and retains NFT-three principal/claimed-principal before setup. This is a genuine local setup prerequisite, never approval of a public funder or proof of the missing surrender.

R52 donation evidence contains two distinct explicit IDs, identical donation calldata, four separate approval operations and two donation operations. All six raw signatures match their recorded transactions and successful receipts, original funding domain, preserved intents and canonical-object completion hashes. First donation `0x9855a1646ff910da4cdb96e9b3fc7c98364a6eb49428e7117b220db413ff69a0` and second `0x7c367d4e52ffcbe806215af93f654d487c9702ce5557e9a03e2b661b8e986895` are distinct. Retained observations record recovery of the original interrupted receipt, zero completed resends, and unchanged completed-resume nonce `0x894`. This supports the narrow donation group; it does not establish the remaining lifecycle.

An initial raw-file intent-hash comparison included the file's newline. Completion hashes bind canonical JSON objects. Recomputing the contractually relevant canonical-object hashes matches all six donations and B; no evidence defect is inferred from that discarded comparison.

## Exact coverage mapping

| Required behavior or artifact | Disposition and actual evidence | Remaining requirement |
| --- | --- | --- |
| Completed claim and exact emitted location | Genuine `C/task-10-done.json` explicitly says INCOMPLETE/BOUNDED-STOP; command paths authenticate R49/R52 | No successful final location, result or full lifecycle |
| Original pinned fork and authority transport | R49/R52 historical headers, command arguments, contained CSV and settled task-16 verdict | No completion inference from authenticated prerequisites |
| Real 10000-DTF setup donor | R52 selection, transfer receipt, exclusions and exact before/after balance records | Full cohesive lifecycle and no-manufactured-history assertion not certified beyond reviewed setup facts |
| Actual manager/registry/CREATE3/proxy surface | Real deployment receipt, environment and runtime bindings retained in partial runs | Full final activation/loupe/retained-surface lifecycle not reached |
| Bootstrap and deployment/funding interruption | Actual preparation/deployment/funding records retained | Complete final continuation absent |
| Distinct donation identities and idempotent resume | Narrow retained local donation observations supported as above | Does not certify other stages |
| Mixed A/B and mined-A recovery after B | A mined before checkpoint; B successful only in later partial run | No A-after-B recovery, no completed mixed records |
| Same recipient configuration B / issuance A | Initial issuance and configuration history retained | `same-recipient-config-b-issuance-a.json` absent; replacement/history proof unmet |
| Actual same-block A then B | Not reached | `same-block-config-a-then-b.json`, transaction-prefix recovery and tamper corpus absent |
| Stale and malformed negatives | Seven retained CLI negatives and earlier claimed-SY negatives are partial | Signed stale A after B and complete wrong-domain/artifact/history/chain/proxy corpus absent |
| Paid owner-first bond and activation | No completed real scenario | Paid receipt recovery, post-purchase setter, mixed activation, complete selector removal and retained claims/surrender proof absent |
| Genuine unset pricing and empty census | Earlier run exposed the repaired census issue; settled unit/CLI proof remains separate | Successful paid owner purchase, activation and retained unset getter absent |
| All baseline source branches | Actual source acquisitions and initial preparation retained | Post-activation weighted liquid/SY, claimed SY, DTF-custody SE, claim vault, weighted receipt, earlier receipt/liquid and held-SE-LP followthrough incomplete |
| Admission, clocks and ordinary deposit | Not completed | Admission phases, delayed clocks, ordinary deposit and exact cliff claims absent |
| Repeated recovery preserving principal/custody | Not reached | Recovery observations, repeated reward-only cycles and asset-conservation followthrough absent |
| Genuine original-wallet NFT three | Original quantities/source position retained only as setup/preparation inputs | `nft-three-two-bonds.json`; one source consumption, two exact principals/gons, aggregate funding and fresh 90-day clocks absent |
| Separate synthetic receiver second-callback rollback | Not reached | `nft-three-rollback.json`; second-callback trace, full rollback and later funded success absent |
| Portability and deterministic original bytes | Initial relocation/preparation comparisons retained | Complete mixed-book and immutable-issuance lifecycle through portable domains absent |
| Current source applicability and original preservation | All 160 attempt-52 source fingerprints match; 107 preserved checkpoint files match inventory | No global independent claim that every historical archive byte was unchanged |
| Runtime cleanup and command completion | Forced-stop receipt reports no listener/processes; 107 files/677799 bytes preserved exactly | No normal successful completion; no fresh process probe performed by verifier |

Of the producer's eight scenario groups, donation identities has retained narrow evidence; the other seven remain unmet. No complete task-10 lifecycle is independently accepted. Initial source acquisition, deployment or typechecking never closes a later unexecuted branch.

Six specifically required scenario files are absent from the final runtime: `mixed-pricing.json`, `same-recipient-config-b-issuance-a.json`, `same-block-config-a-then-b.json`, `unset-pricing-owner-bond-activation.json`, `nft-three-two-bonds.json`, and `nft-three-rollback.json`. The naming differences noticed during preparation are not the decisive issue: neither corresponding completed unset/receiver scenario exists.

## Adversarial coverage and limits

- Replay/duplication: retained donation identities, signed originals and no-resend observations support that narrow case; A-after-B and same-block replay remain unproved.
- Concurrency/order: the actual shared-root LOCK failure is a harness observation; separate-root B has a partial success, but no same-block or historical recovery acceptance.
- Domain/source forgery: canonical original A domain and seven actual preparation negatives checked; final wrong chain/proxy/artifact corpus incomplete.
- Custody/issuance atomicity: no final positive NFT-three surrender and no second-callback rollback; cannot certify.
- Funding/solvency/rounding: actual setup/donation receipts retained; two component bond principals, gons and aggregate funding remain unproved.
- Lifecycle/access control: paid-first, unset-pricing activation, selector removal and restoration negatives remain unproved on the completed real surface.
- Source/wrapper double credit and admission: retained acquisition/intake negatives are partial; all baseline source branches cannot be certified.
- Recovery/accounting: repeated reward-only harvest and protected backing/conservation followthrough not reached.
- Failure/cancellation/resource ownership: intentional interruption and forced stop are documented; checkpoint copies match. Cleanup relies on retained termination/lsof evidence, not a new process or RPC run.

The removed `claimWitnessCodeHash` stays removed. Settled pin-removal review is reused; no replacement bytecode pin or price-policy condition was added. Genuine source, transaction, trace and conservation obligations are not waived.

No tests, builds, installs, RPC calls, transactions, delegation, commits, public sends or source/test edits were performed by this verifier. Only this new independent evidence and the final verdict are written. No runtime was started. The one claim subscription fired and completed. The helper inventory limit remains explicit; no new lifecycle verdict is inferred from the 336/0 gate. Producer termination and archive preservation claims are attributed at their actual scope.

The unverified task-10 rehearsal changes remain in the requested worktree. This report does not authorize merging, landing, reverting mixed-ownership files, resuming QA, or changing plan status.
