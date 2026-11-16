# Migration implementation and evidence status

Date: November 13, 2026.

**The full implementation-and-test plan is not complete.** The latest delivered cumulative commit is `1694e68a4bd66dd67d3b5e3f145f1da23074ff48`. No compensation allocation, deployment, funding, activation or source-governance action is authorized by this status document.

## Implementation coverage carried forward

The existing independent coverage report is `requirements-coverage-0856a5c5.md` in this directory. A read-only comparison of its subject with the delivered revision found no changes under `contracts/` or `test/foundry/`:

```text
git --no-pager diff --name-only --ignore-submodules=all \
  0856a5c56e5d09b81c669f59b613efef79133e19 \
  1694e68a4bd66dd67d3b5e3f145f1da23074ff48 \
  -- contracts test/foundry
```

Exit was 0 with empty stdout and stderr. This comparison describes the delivered commit, not later uncommitted work. The E-S custody gap has since been implemented and verified as recorded below. The owner's latest November 13 correction reinstates TokenStaking because its backing migrated into the old DTF DETF. The bounded claimed-SY path is restored; broader claim forms remain open. Other evidence and deployment limits remain distinct.

## Evidence completed since that coverage report

| Work | Accepted result | Boundary |
| --- | --- | --- |
| Phase 27 | Delivered deterministic historical candidate preparation at `789fced8` | Candidates remain non-issuable; unknowns are not zero |
| Phase 28 | Delivered named purchase/claim receipt collection at `07d54b9a`; 77 canonical transaction records | Preserves routing and indirect-call qualifications |
| Phase 30 | Delivered conversion/recovery collection at `1694e68a`; 319 exact output records and 172 passing operator tests | Gross outputs are not approved deductions or current custody |
| Joined receipt worksheet | 376 distinct transactions, 378 references, all 20 retained flags independently verified | Recipient event flows are not original financial inputs |
| Phase 31 | All 59 named NFTs independently observed at block 113279837 | Not a census or a promise of state after the captured block |
| Phase 32 | Source-supported caller-paid token observations for 16 earlier purchases | No approved ETH/DTF original-cost or credit values |
| Phase 33 | All 23 named weighted NFT claims reconciled; seven prior receipts reused and 16 acquired | Seven reward-only claims remain separate from principal; no lifetime-history claim |
| Phase 34 | Actual weighted purchase facet recovered and runtime-bound; 39 direct weighted purchase observations independently verified | Payment roles are not automatically approved original-cost roles |

The phase 31 pin is `0x78f23110692ee71a64dfea3463f7df0f9687ffa5d5f951fabb22c239921c4113`, timestamp November 13, 2026 at 10:18:57 UTC. It contains 57 present named NFT identities; weighted 25 and 42 are absent, and 26 has a different owner from its original recipient. Phase 33 separately proves the retirement events for 25 and 42. Unavailable current position fields remain unknown, not zero.

Accepted reports and sealed raw evidence remain in their existing phase directories. No passing checks were replayed for this status update.

## Requirement status

| Requirement area | What remains open |
| --- | --- |
| Earlier SE source, F1-01 | Custody gap closed in an uncommitted eight-file increment after1694e68a: genuine EOA holder, finite-source admission, four-source behavior/configuration coverage and ten-source stateful coverage. All76 focused tests passed, including32invariant runs/512calls/0reverts. Financial eligibility and disabled conversion remain separate. See `earlier-se-custody-verification-20261113.json`. |
| TokenStaking scope, F1-02 | Reinstated because its backing migrated into the old DTF DETF. The owner selected one conserved original across eligible remaining claims and already-claimed SY. A new bounded remaining-original loader retains full original contributions and scales their frozen credit by eligibleWeight/originalWeight after complete measured-SY preparation. Ordinary complete-original intake remains compatible. The cumulative gate passed 186 hermetic tests, 12 real-source fork tests, four lifecycle tests covering all 16 removed loaders, strict types and 180 operator tests. The actual local operator rehearsal passed with real source claims, configuration, activation, partial/final surrender, exact funding and late-funding rollback; its node exited and runtime was removed. Evidence is in the phase-30 worktree at `docs/incidents/2026-09-16-dtf-recovery/migration/remaining-sy-rehearsal/runtime/rehearsal-1794593414055`. The synthetic one-third remainder preserved full quoted credit 466690583 and delivered eligible credit 155563527 as 51854503 plus 103709024, leaving zero Q/C. Delegated-wallet source support and other uncovered claim forms remain open. Earlier exclusion/removal records are superseded history. |
| Actual financial inputs, F1-03 | Gross token payments are now observed for all59named NFT purchases:55source-supported direct purchases and4receipt/calldata-corroborated smart-account purchases. See `nft-payment-owner-review-r2-20261113.json`. Eligibility, net/native-refund treatment, original cost, prior compensation, economic-origin disjointness and broader fungible inputs are not approved by these observations. |
| Weighted NFT 3 | Implemented in the uncommitted phase-30 worktree: the separate-contribution loader independently quotes 0.000999999 WETH and 362.8938576 DTF and issues two funded bonds on one atomic eligible surrender. Single-contribution loading remains compatible. Operator proofs bind `separateContributions: true`, retain both quotes, select the matching loader and verify its distinct configuration hash. The contract increment passed 50 focused tests; integration passed the typed stage build, strict types and 179 operator tests. Four additional lifecycle tests passed, including two invariant campaigns of 32 runs / 512 calls / zero reverts each, checking all 15 removed administration selectors. No deployment or operational issuance occurred. |
| Disabled or authority-restricted recovery, F1-04 | Custody-and-hold evidence does not establish successful liquidation/donation of every held legacy representation. No legacy governance or ownership was changed. |
| Selected composition and quote evidence, F1-05 | Actual recovery composition, funding inputs, supported quote domains and target-specific operational sizing remain distinct from the tested fixtures. |
| Deployment feasibility | Recorded registration remains 45,116,678 gas versus the 32,000,000 target. The held gas lane was not reopened or worked around. |
| Operational authority | No real allocation, funding, deployment, configuration, issuance, activation or harvest approval follows from a source observation, commit or test. |
| Cleanup and archival | Historical worktrees, evidence and required artifact dependencies remain retained. Pending archival/landing cleanup is not represented as completed, and nothing was deleted to improve the task count. |

The current review worksheet is `nft-payment-owner-review-r2-20261113.md`, with all59records, exact integer quantities and proof links in its companion JSON. Revision1 is preserved. All financial approval fields remain unset. Historical principal payments are not migration-compensation deductions; rewards are not new original contributions. Transfers do not move the configured original wallet's compensation.

## Access gates and unanswered decisions

The configured producer route for phase 29 refused after partial work. The affected task was released; its incomplete evidence was preserved and never promoted into an admission proof. The separate historical `debug_traceTransaction` attempt returned HTTP 400 / code -32600 because it is unavailable on the RPC Free tier.

The earlier provider-access confirmation was unanswered. Reinstating TokenStaking scope does not itself authorize a refused-provider retry or resolve the separate held deployment-gas lane. Weighted NFT 3's contribution classification and two-bond implementation are complete within the tested domain; final funded-snapshot credits and operational issuance remain unapproved. No alternative model/provider, repeated refused operation, paid upgrade or live financial action was applied.

Remaining data, composition, recovery and deployment requirements retain their own evidence gaps. TokenStaking's temporary exclusion was explicitly corrected by the owner; its remaining claim-domain requirements are open again, not proven absent by a sampled lookup or failed provider call.

## Preservation qualifications

- The first remainder rehearsal failed because its evidence output was outside Foundry's existing worktree write sandbox. The failure and cleanup remain at `.omo/ulw-execute/dtf-migration/remaining-sy-rehearsal-20261113/runtime/rehearsal-1794593274621` in the primary checkout. The successful run changed only the evidence location; no filesystem permission was broadened.
- P1's two unavailable historical artifact versions remain unavailable. Current source/runtime checks do not reconstruct them.
- Phase 32's failed first observation lost 243 response entities/outcomes. Its successful later captures supply the accepted bounded evidence but do not repair that loss.
- The phase 30 immutable audit distinguishes concurrent ref packing from logical ref changes, and retains the original commit-record stderr/pager limitations.
- Missing or timed-out language-server diagnostics are not passing checks. The accepted reports identify the actual executed checks and their limits.
- ETH/WETH remain contribution, funding and recovery evidence; no standalone compensated native-token surrender requirement was invented.

**Status: partial implementation and evidence delivered; full-plan completion remains open. No unanswered decision is treated as approval.**
