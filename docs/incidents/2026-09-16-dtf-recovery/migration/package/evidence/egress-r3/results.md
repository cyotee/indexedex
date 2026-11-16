# r3 bounded evidence receipt

Date: 2026-11-10. Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.
Classification: **proposed integer/caller behavior, not SUT or E5 acceptance**.

## Reproduction and actual execution

From the worktree:

```sh
/opt/homebrew/bin/bun --version
/opt/homebrew/bin/bun docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/egress-r3/run.mjs
```

The final standalone execution used **Bun 1.4.2 and exited 0**. Its completion
event included 304 accounting sequences, 72 raw-SY cases, actual modeled
consumer payments of 18 and 2, and the explicitly rejected expiry/large-stock-
accrual cases. Earlier resident execution used Bun 1.4.4. No production test
runner, contract compilation, chain or token deployment was invoked.

`ledger.mjs` imports the immutable, completely read
`../egress-verification/reference.mjs` for the canonical funding, role-weight,
wallet and bond arithmetic. It overrides the rejected SY representation,
reward delivery, internal-balance rules and retirement behavior. It does not
import r1/r2's rejected SY consumer model or alter the independent oracle.
The entry file prints results and throws on an unexpected assertion failure.
Rollback uses explicit speculative-state snapshots; **EVM atomicity is
assumed by this model**, not proved by it.

| Owned module | Responsibility | Nonblank/noncomment lines |
| --- | --- | --- |
| `ledger.mjs` | r3 integer state transitions | 160 |
| `witnesses.mjs` | Funded accounting sequences | 135 |
| `callers.mjs` | Source caller/consumer boundary witnesses | 164 |
| `run.mjs` | Finite evidence entrypoint | 10 |

All inputs are deterministic integers/internal identities; there is no
external parser, network dependency, production seam, timing loop or SUT
stand-in. Fresh LSP diagnostics subsequently returned **no diagnostics for
all four modules**. Earlier apply_patch diagnostic requests timed out at
3,000 ms; those timeouts were not clean checks. No Solidity/typecheck claim
follows from JavaScript diagnostics.

## Positive results

All amounts below are native integer units unless explicitly gons or RT.

| Witness | Observed result |
| --- | --- |
| Actual-clock bond, prolonged Stage 1 | At unlock-1 principal is 0; at unlock principal 10 pays. Combined reward request rejects. Principal subsequently exits after more funded growth. |
| Original versus delivered-principal rewards | Original bond later pays 25 to Alice; post-claim growth pays 5 to Bob. Forty total funded units paid, final backing 0. |
| SY holder fully leaves | Ten principal paid to a different receiver; old Alice keeps `5*10^36` reward gons. Another funding of 10 after exit makes those rights pay 20 after activation; repeat 0; final backing 0. |
| Standard units | Initial index 1; after ten-on-ten funding index is `500000000000000000000000000000000001`; native RT owed is `5000000000000000000`, backed by `5*10^36` gons. Index fits uint128. |
| Concrete consumer expression | Source sentinel/mulDown records the above RT quantity; late holder accrues 0 for the prior interval. Full SY departure preserves the old consumer's claim. After further funding and activation, source 10% fee arithmetic pays old user 18 native and treasury 2; final backing 0, repeated SY claim 0. These are formulas, not a deployed YT lifecycle. |
| Mixed cohorts/transfers/full and partial exits | 304 sequences: principals 1..16, every split 0..n, two funding magnitudes and later mixed deposit/funding. Successful principal aggregate 3,872; native rewards 6,585; 606 nonzero owner residue observations retained. |
| Failure atomicity | Every sequence includes a failed minimum after speculative funding/redemption and exact snapshot restoration. Every sequence rejects a preactivation SY reward claim. |
| Quantum residue | Seven principal plus funding 3 produces a nonzero sub-RT residue. `mintedRT*q+remainingR2` exactly equals pre-claim owned gons. Later canonical funding reaches `k=1`; **555,555,555,555,555,554 gons** pay exactly that many native units through the explicit remainder API; repeat 0. |
| RT assignment/allowance/redemption | Real modeled token balances transfer to B through approved operator; max allowance decreases by the exact spend. B burns its RT and receives corresponding funded receipts, then withdraws held DETF. Final RT supply and issued gons 0; native dust remains accounted. |
| Captured role owner | Old beneficiary retains `652173913043478260869565217391304348` gons after role recipients change; no wallet receipt is delivered while closed. Active release pays 1, repeats 0, retains residual gons. |
| Canonical final bond retirement | Fully paid seven-principal position retires only its final sub-native fraction. No remaining position/gons; two native units remain explicitly as canonical allocation/staking dust. No other position/beneficiary balance is erased. |
| Direct approved caller | Router pulls Alice's five SY, calls unchanged internal redeem, pays Carol principal 5; Alice later gets reward 10; router gets none. Two prior self-held shares survive. |
| Caller-funded self deposit | Actual modeled five-unit funding mints five self shares; same caller's unchanged internal redeem pays 5; final backing 0. No ticket or arbitrary-credit issuer. |
| Parent intermediate | Alice's seven-unit receipt packet goes through parent; parent exits exactly 7 and retains its old two-unit principal. Alice later receives her own 7 rewards. |
| Optional upstream handoff | Actual sender symbols YT and market each push five SY directly to SY; router's unchanged internal redeem pays 5. Original SY holder retains and later receives reward 5. This proves only the last SY handoff, not YT creation, market pricing or controller admission. |
| Delayed bearer self balance | Five deliberately self-held shares earn `2.5*10^36` gons. Anyone may burn the five principal shares under the standard internal API. Self-earned gons remain exact protocol `U`; no RT minted to the redeemer; `claimRewards(SY)` pays 0 after activation. This is not user-owned escrow. |
| Raw SY | 72 cases across 1..12 principal, both burn modes and DETF/receipt/configured output-budget categories. Prior two self shares preserved; raw backing equals shares; temporary approvals cleared; no reward tokens. Configured output pricing is not modeled. |
| Current-owner pooled genesis authority | Fully present two-leg budgets do not let donor, pending or former owner execute genesis. Current owner succeeds once; repeat rejects; later donation adds inventory without owner gating. This checks caller predicates/budgets only, not actual opening-price/self-mint or LP execution. |

There is no RT before activation in any proposed sequence. An existing
funded NFT/right can transfer without issuing a new reward token; changing
beneficiary records does not move physical reward gons outside custody.

## Preserved failures and unsupported integrations

| Case | Actual outcome and interpretation |
| --- | --- |
| r1 `Q-k` reported as native sDETF reward index | Reproduced **4,999,999,999,999,999,999** native consumer claim against ten funded native units. This remains rejected, not relabeled. |
| r2 one-gon token/index | Reproduced index `500000000000000000000000000000000000000000000000000001`, beyond uint128, and premature reward receipt delivery of `5*10^36` units. Those are rejected r2 behaviors, not current deployed exploits. |
| r3 first-expiry harvest before activation | Actual model claim rejects and restores state. This matches the read call to `SY.claimRewards(YT)` in `PendleYieldToken._setPostExpiryData`; no claim of stock preactivation expiry support. |
| r2 fresh market versus unchanged controller | Local factory contains M; all four distinct controller factory registries reject M; admission is false even with zero emissions. No model registry is changed to manufacture a passing market. |
| Unchanged downstream floors | Two separate floor updates can credit 0 while one combined update credits 1. Exact downstream fraction preservation is not claimed for the stock consumer; its source was not forked. |
| Large accrued token amount | A representable uint256 gon amount can produce an RT accrued value above uint128. Index fit alone is not stock end-to-end compatibility; no Migration supply cap is added. |
| Wrong caller/source | Unapproved share pull, external redeem from empty caller, wrong parent-pull operator and wrong typed-custodian identities reject. Public internal SY burn is deliberately **not** a wrong-caller rejection condition. |

The caller and guard witnesses are symbolic source-derived executions, not
deployments. The real retained dependency graph uses the registered package
path and fixed parent/child authorities specified in the construction. There
is no actual gauge admission, governance action, optional protocol deployment
or new trusted registration predicate hidden behind these results.

## Actual unsuccessful execution history

1. First resident accounting run failed `false == true` at
   `witnesses.mjs:98`, the assertion requiring a nonzero sub-RT residue.
   Re-running only to retrieve the stack reproduced that same failure.
   The chosen seven-principal/two-funding vector reached a divisor aligned
   with `q`, so its residue was zero. The vector was changed to funding
   **3**, producing the required nondivisible divisor under the actual
   allocation floor. No invariant was weakened; both the fractional-payment
   and retirement vectors now exercise real nonzero fractions.
2. An attempted standalone launch used resident `process.execPath`.
   In this host it was
   `/Users/cyotee/.omo/binary-runtime/5.1.58/omo`, **not** the Bun interpreter.
   The process printed `senpi rpc host: internal_key_unavailable: no key within 2000ms`
   and exited **137**, without running the evidence. It was not a passing
   model run or a delegated task.
3. The actual interpreter was located as `/opt/homebrew/bin/bun`.
   The subsequent standalone run reported Bun 1.4.2 and exited **0**.
   After adding the concrete consumer-payment and raw-SY budget witnesses,
   the complete final entrypoint was run once more and exited **0**.
4. Initial helper invocation `show is not defined` was an evaluation-helper
   error during reading; it was corrected without changing any input file.
   Long read output was revisited in bounded chunks rather than assumed read.

No failed assertion, unsupported integration or failed launcher is suppressed
from this receipt.

## Coverage limits and cleanup

No Solidity/Forge build, production/test/config edit, install, Git operation,
commit, broadcast, external message, shared Crane write or delegation ran.
The owned outputs are exactly `egress-contract-r3.md` plus this results
receipt and four modules. Prior reports/evidence were read only.

The failed packaged launcher and both finite Bun monitors have terminated;
the successful monitor completion events report exit 0. No task-owned node,
RPC endpoint, listener, daemon, cache, dependency, worktree or temporary
directory remains. There is no waiting background task. Tool-owned logs and
language-server resources were not deleted as if they were task-owned files.

Unexecuted production requirements remain real-proxy installation/admission,
all configured output pricing/fees/decimal conversions, actual custody deltas,
ERC2612 signatures, callback/phase behavior, gas and uint256 stress, selector
removal/restoration and the real legacy gates. E1/E2, actual recovery E3 and
runtime E4/E5 remain open. These finite models cannot close them.
