# Implementation-plan advisory resolution

Run: `dtf-migration-gap-closure-plan-20261116`.
Reviewed draft: `dtf-migration-gap-closure-plan-20261116-r1`,
`coordinator/draft.md`.
Coordinator-supplied draft SHA-256:
`0fbc28eb001b2964b63b0bea527da03786c0347841bf8b3ef37a0cc020c405fc`.
The reviewed draft is preserved unchanged.

Final: `../IMPLEMENTATION_PLAN.md`.
All four independent proposals and all four sole advisory turns settled.
No implementation or project execution occurred. The final plan has seven
implementation tasks and three final verification gates, all unchecked.

## Participation and dispositions

| Member | Advisory disposition | Concerns | Publication |
| --- | --- | ---: | --- |
| Astra | support | 0 | Member-published feedback |
| Grok | requested-changes | 3 | Inline, coordinator archived verbatim |
| MiniMax | support-with-reservations | 4 | Inline, coordinator archived verbatim |
| Kimi | support | 0 | Inline, coordinator archived verbatim |

The final is a coordinator synthesis after this pass, not a unanimous approval
or text reviewed a second time. No requested concern was silently omitted.

## Grok G1 - alleged missing residual settlement

The alleged defect is not adopted. The chosen MaintenanceFacet override
delegates `_sweepDustBody` to `UniswapV4DetfMigrationPolicy`. That wrapper
checks whether the budget is closed, then calls `_beginBudget`, the common
sweep, and `_endBudget` (`Policy.sol:29-64`). `_endBudget` recomputes residual
inventory from actual remaining balances minus the protected floors and
closes the budget. The chosen explicit sweep preserves that dispatch.

The coordinator checked this source. Astra, Kimi and MiniMax independently
confirmed it in their advisories. Manually setting residuals again after the
existing wrapper would not repair a missing settlement and risks duplicate
accounting.

Accepted clarification: the final states the exact dispatch and settlement
chain, prohibits bypass/double settlement, and adds a later genuine donation
regression proving that a subsequent budget opens and closes while recovery
and unsolicited balances remain protected.

## Grok G2 - receipt exit and join arrays

The draft already required mature principal claim followed by the actual
receipt-to-DETF exit. It did not assume the NFT claim itself paid DETF.
The final now names the precise receipt `exchangeIn` call and exact positive
DETF balance assertion.

Accepted API clarification: the final specifies caller-owned auxiliary SE
shares, sorted raw/share amounts and actual allowances/refunds. It uses the
gold first-liquidity path `joinProportionalFlexible(amounts, flags, ...)`
from `H/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol:454-472`.
That avoids leaving first liquidity implicit in a generic native-component
join instruction.

For later live joins, the final records the exact two-array
`joinNativeComponents(localAmounts, shareAmounts, to, minLp, deadline)` ABI,
declared in `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol`.
No claim that every native-component zero-supply call necessarily reverts is
made: the production liquidity library contains zero-supply accounting branches.
The plan deliberately uses the existing tested first-join pattern.

## Grok G3 - indexed getters, capture and book headers

The draft contained no `standardExchangeOf(i)` call, already selected direct
capture of the separate comparison hook, and already reused the validated
consumer and actual parent setter. The asserted wrong call is not present.

Accepted precision: the final names `Capture(comparisonHook)`, distinguishes
`standardExchange(uint256)` from `standardExchangeOf(address)`, and states
that the existing consumer/setter construct and validate version 2, chain,
consumer/output, contribution identities, complete inputs, fee, seigniorage
and domain-bound book ID. The observed helper returns inputs rather than
bypassing validation with a fabricated header.

## MiniMax C1 - sum-of-books invariant

Accepted as an explicit accounting precondition and proof obligation.
The final states:

`donationInventory[token] + residualInventory[token] <= held[token]`.

The release preserves this sum. Under the admitted non-FoT/non-rebasing model,
measured receipts and existing floor-preserving spending maintain disjoint
books. Recovery and unsolicited balances are additional protected custody,
not a source for the release.

A new redundant balance guard or saturating fallback is not prescribed.
Existing checked subtraction rejects an inconsistent budget atomically. Tests
must prove conservation across real receipt/refund/sweep/recovery paths; they
must not manufacture invalid SUT storage merely to exercise an unreachable
bookkeeping branch.

## MiniMax C2 - alleged inherited-purchase collision

The requested retirement of unrelated pranked helper calls is not adopted.
The coordinator rechecked the current script: its only `_buyOwnerFirstBond()`
call is inside the separate simulation-only `runMixedRecordRehearsal()` at
line 171. `deployAndIssue` does not call it, script `setUp()` is empty, and
there is no `_purchaseForActivation` function in the inspected file.
The C7 `--sig` entries therefore do not execute that separate simulation.

Accepted clarification: exactly one real owner purchase occurs in the broadcast
Stage A, using the controller-funded owner helper. Neither broadcast stage may
call the pranked helper or claim simulation state as a mined prerequisite.
Receipts and readbacks must prove payment, marker and NFT owner.
The separate working simulation fixture is preserved.

## MiniMax C3 - specify the output rate source

Accepted as a deterministic fixture clarification. R2 now installs the exact
production provider returned by
`providerFor(create3Factory, diamondPackageFactory, se0, pairA)` on the raw
DETF output leg. Assertions check its `reserveVault`, `rateTarget`, live
`getRate()` and matching captured rate. This is explicitly an SE-share-derived
arithmetic/policy binding, not a statement of the parent DETF's economic price.

The final does not adopt the broader categorical claim that the generic
provider factory can never be constructed for a DETF. Source reads show the
provider delegates to its configured subject's full-book preview and normalizes
units. Whether that alternative produces a positive usable value is a different
runtime/domain question. The plan avoids that unresolved alternative by naming
the already grounded SE-derived provider, while retaining the RawRate output
comparison.

## MiniMax C4 - prove reentry was attempted and rejected

Accepted in part. A low-level callback that records and asserts the exact
inner rejection is not vacuous merely because the outer token operation
continues. The existing hostile fixture already retains callback success and
reason bytes.

The final requires reset/fresh callback observations, proof the callback was
attempted, `callbackSucceeded == false`, and exact
`IReentrancyLock.IsLocked()` reason bytes, plus positive successful outer sweep
and protected-state assertions. Ignoring a low-level failure is forbidden.

The separate armed `ForcedTransferRevert` case proves full outer rollback.
Requiring the reentry fixture itself to bubble every failure is unnecessary,
and would erase its persisted callback observations with the outer revert.
The two cases deliberately test different outcomes.

## Astra and Kimi

Both support without concerns. Their source checks confirm the explicit-only
handoff, standalone budget settlement, real paid owner call, persistent
Migration presentation and separate valid raw-hook comparison boundary.
No approval was inferred from silence or substituted for a missing response.

## Final scope and delivery

The final retains the selected existing-selector repair and all five gap
acceptance rows. It preserves original migration requirements, immutable
deployment boundaries, historical evidence, normal artifact/cache locations,
and the withdrawn-operator scope.

Only council-owned Markdown artifacts were authored. No original plan, review,
historical evidence, implementation, test or configuration file was edited.
No project build/test, Git operation, RPC call, deployment or transaction was
performed. The future command blocks are not reported as executed.

All final wording changes are coordinator revisions after the single advisory
pass. Originals, draft and complete feedback remain available. No further
council round is required or implied.
