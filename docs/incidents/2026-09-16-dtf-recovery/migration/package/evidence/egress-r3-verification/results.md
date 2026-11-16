# Independent r3 execution receipt

Date: 2026-11-10. Classification: finite integer and source-caller
construction evidence, not Solidity/SUT acceptance.

## Execution

From `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`:

```sh
/opt/homebrew/bin/bun --version
/opt/homebrew/bin/bun docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/egress-r3-verification/run.mjs
```

Observed interpreter: **Bun 1.4.2**. The finite monitor
`mon_TP7PPVG5X5NGSHDS` completed with **exit code 0**. The complete output was
read after completion. An earlier resident Bun 1.4.4 run also completed;
the final standalone run additionally includes the RT-owner remainder and
active wallet retirement checks. No arithmetic assertion failed in either run.

`ledger.mjs`, `run.mjs` and `source-callers.mjs` import no producer or prior
verifier modules. Eager per-funding SY earnings deliberately use a different
representation from the producer. The source expressions and limitations are
in `source-evidence.md`. Fixed addresses/callers are symbolic identities;
their predicates are not proof of deployment or real authorization.

| Independent witness | Observed result |
| --- | --- |
| Fresh bond, exact cliff, prolonged Stage 1 | 10 principal succeeds; before-cliff principal 0; combined request rejects; repeat principal 0. |
| Original bond versus growth on delivered principal | Later actual model funding pays 25 to original bond owner and 5 to receipt owner. Total paid 40; final backing 0. |
| Source consumer units and old ownership | Index begins 1, becomes `500000000000000000000000000000000001`; claim is `5000000000000000000` native RT. Principal 10 goes elsewhere; later funding and activation pay old user 18 and treasury 2. Final backing 0, repeat claim 0. |
| Mixed cohorts, all splits, transfers back, self/zero transfers, two output forms | 920 sequences, principal 1..20 and every split; 15,080 aggregate principal and 9,984 rewards paid. 1,788 nonzero owner-residue observations remain explicitly accounted. |
| Failure atomicity | Each cohort sequence includes speculative funding plus a failing final minimum and complete model snapshot restoration; each rejects a locked reward claim. This assumes uncaught EVM failure, not an execution proof of it. |
| Sub-RT fraction | 555,555,555,555,555,554 gons survive tokenization; canonical funding reaches k=1 and the explicit remainder route pays exactly that many native units. Repeat zero. |
| RT burn with a different receiver | 777,777,777,777,777,777,222,222,222,222,222,222 gons remain in the actual RT owner's R0, not the payout receiver's. Failed output minimum restores state. |
| Canonical retirement | Fully paid bond leaves 2 native units as canonical dust. Active full-wallet exit pays 8, retires only that wallet's fraction, and leaves 2 native dust. Neither result licenses pooled/deferred retirement. |
| Captured fee/creator identity | Old beneficiary retains 652,173,913,043,478,260,869,565,217,391,304,348 gons through later role changes; zero closed-stage receipt delivery; active payout 1, immediate repeat 0, remainder 123,688,155,922,038,980,509,745,127,436,281,859 gons. |
| Approved direct pull and standard internal redeem | Pays 5 principal; preserves 2 prior self shares; old holder receives 10 reward; router receives none; maximum SY allowance decrements exactly. Wrong pull operator/external source and final minimum reject. |
| Optional upstream sender handoff | YT and market sender symbols each send 5 directly to SY, router burns 5 self shares, old SY holder later receives 5 reward. Handoff only: no YT/market deployment, LP mint or swap pricing ran. |
| Bearer and self-funded paths | Deliberate self-held shares permit anyone to redeem 5 principal; `2.5*10^36` self-earned gons stay in U, no RT delivery. Atomic caller-funded self deposit/redeem pays 5 with zero final backing. |
| Parent intermediary | Seven-unit receipt packet exits; parent's pre-existing two-unit basis survives. Original owner later receives 7 reward once. |
| Conditional phases | 20 busy-child/phase activation predicates reject; receipt nested funding restores the saved phase rather than blindly Idle. Not callback or lock execution. |

## Counterexamples that remain negative

- R1's consumer records **4,999,999,999,999,999,999 native sDETF** against
  ten funded native units. The bad expression remains rejected.
- R2's one-gon index exceeds uint128. Early token delivery remains prohibited.
- R3 Stage-1 `claimRewards`, including a zero-beneficiary-balance claim,
  rejects. Stock first-expiry and market harvesting are not waived or mocked
  as successful zero payments.
- A fresh factory's local membership does not satisfy any of the unchanged
  controller's four rejecting registries. With activation enabled to isolate
  admission, preceding modeled SY harvest is fully rolled back by rejection.
  No model registry is modified to manufacture an admitted market.
- A valid uint256 principal of `680564733841876926928` native units can
  create a stock accrued RT value above uint128. Index fit alone does not
  establish all-size stock-consumer compatibility.
- Two stock separately floored updates credit 0 where a merged update credits
  1. Exact downstream fraction preservation is not claimed.

## Diagnostics, limitations and resources

The final fresh LSP request reported no diagnostics for `source-callers.mjs`.
Fresh diagnostics for `ledger.mjs` and `run.mjs` timed out after 3,000 ms,
as did earlier automatic requests. These are not clean diagnostics or
Solidity compilation results. All three modules were actually parsed and
executed by the successful Bun run. No full static type-check is claimed.

Initial evidence-reader helper definition failed to parse in the resident
tool cell; replacing it with an async arrow helper corrected the tool usage.
No input file was changed. The initial independent oracle draft's direct-SY
output was corrected before execution to burn SY's exact principal gons
directly, rather than route through a receiver wallet that could retire an
unrelated fraction. An unused draft witness was removed before execution.
These were reviewer evidence edits, not production findings or failed SUT runs.

No production/test/config file, prior artifact or shared Crane file was
changed. No Forge, install, Git, commit, broadcast or delegation ran. There
was no RPC/node/listener, dependency, cache or temporary directory. The one
owned finite monitor is completed, exit 0; no running resource remains.
Tool-owned transcript/LSP resources were not modified.

Configured reserve outputs, fees, decimals, actual custody, permits,
cross-proxy callbacks, artifact identity, gas and full-width limits, selector
installation/removal and all original operational gates remain unexecuted.
