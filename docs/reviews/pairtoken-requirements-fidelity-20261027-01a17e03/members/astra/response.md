# Astra independent response

## Verdict: Yes

The published `pairtoken-requirements-final-r2` is sufficiently accurate and complete to support a separate team's implementation planning and implementation of **PairToken-local behavioral equivalence**, subject to its stated external dependency boundaries. I found no demonstrated false specification or blocking standalone omission in the examined material. No mandatory requirements correction is requested.

This is a static source-to-specification judgment, not proof that a future implementation is equivalent, that the deployed system behaves as assumed, or that a legally cleared clean-room process exists.

## Identity, targets, and provenance

- Member: Astra, independently performing the complete common assignment. This is my initial response, not an advisory review or a council-wide conclusion.
- Requirements: `/Users/cyotee/Projects/indexedex/docs/research/pairtoken-behavioral-requirements-20261027-01a17d57/handoff/REQUIREMENTS.md`, identity `pairtoken-requirements-final-r2`. Read in full, including all three parts and all 58 acceptance scenarios.
- Source root: `/Users/cyotee/Projects/indexedex/docs/reviews/pairtoken-requirements-fidelity-20261027-01a17e03/evidence/sources/`.
- Primary source: `src/pair/PairToken.sol`, read in full.
- Provenance: the coordinator-supplied `evidence/SOURCE.md` records an October 27, 2026 Sourcify retrieval for chain 4663, address `0x56C8c249d4c021e93635b120aC68A9a36eb01753`, match ID `55980642`, and exact creation/runtime matches. These are supplied retrieval records, not my independently reproduced verification. My direct attempt to open the named public endpoint yielded no readable source content; it supplied no additional evidence. I relied on the admitted decoded evidence.
- Separate PRD, implementation plan, and audit: not supplied.

Below, `R:line` means the requirements file above; source paths are relative to the source root. References are to the files actually read.

## Findings

### Fidelity defects

**None identified.** I have no critical, high, medium, or low defect with a defensible conflicting source behavior to report. The following are concrete affirmative checks supporting that disposition, not security endorsements.

| Examined contract | Requirement location | Source location and result |
| --- | --- | --- |
| Public surface and initialization | PT-API-01 through PT-API-18, R:60-77; PT-GET-01 through PT-GET-17, R:88-104; PT-INIT-01/02/03, R:173-182 | `src/pair/PairToken.sol:47-74`, `:133-152`, and its externally callable definitions. The 17 named functions, receiver, 17 getters, one-shot caller-derived factory, lack of initializer factory authorization, and lack of added readiness checks match. `NotFactory` is declared at `:103` but unused. |
| ERC-20 edge behavior | PT-ERC20-01 through PT-ERC20-04, R:322-328; PT-ERROR-02, R:440-450 | `src/pair/PairToken.sol:156-198`. Finite allowance consumption precedes transfer checks, owner-as-caller has no bypass, maximum allowance is preserved, consumption emits no Approval, and the specified checked versus unchecked balance/supply operations match. |
| Exact arithmetic rather than real-number approximations | PT-MATH-01 through PT-MATH-05, R:108-169 | `lib/v4-core/src/libraries/FullMath.sol:14-117`; `SqrtPriceMath.sol:188-256`; `TickMath.sol:39-121`; `src/vendor/uniswap/LiquidityAmounts.sol:13-55`; `src/base/PriceMath.sol:29-66`. Nested rounding, endpoint sorting, invalid zero price, both individually checked liquidity candidates, tick coefficients, floor square root, and the stated width conversions agree with the relevant routines. |
| Manager reads, basket, and previews | PT-VIEW-01 through PT-VIEW-05 and PT-QUOTE-01, R:188-214 | `src/pair/PairToken.sol:214-250`, `:500-529`; `lib/v4-core/src/libraries/StateLibrary.sol:40-63`, `:183-190`, `:279-285`, `:324-348`; `Position.sol:47-66`. The packed position identity, storage slots, unclamped basket endpoints, piecewise quote, gross genesis preview, and absence of ownership checks in redemption preview match. |
| Paired genesis and measured receipts | PT-DEP-01 through PT-DEP-05, R:220-236 | `src/pair/PairToken.sol:256-303`, `:661-675`. The minimum is checked against gross shares before the dead-share deduction. Measured token receipts do not recompute those shares. All eligible idle funds finance addition. Genesis checks the computed positive addition, not independently measured position growth. Native refund goes to the caller after minting. |
| Zap admission, cap, issuance, and tick checkpoint | PT-ZAP-01 through PT-ZAP-04, R:240-252 | `src/pair/PairToken.sol:308-345`, `:576-607`. The cap uses the post-compound vault basket and nominal input; the swap uses half the measured receipt; issuance uses reported add-used amounts and the earlier basket/supply. The reported after tick is sampled before the subsequent add, and the tick subtraction is signed `int24`. |
| Retention and both redemption forms | PT-EXIT-01 through PT-EXIT-05, R:256-278 | `src/pair/PairToken.sol:351-405`, `:538-543`, `:596-598`. The caller's full shares burn, payout shares receive the haircut, liquidity and idle slices round separately, and swap-only deployment suppresses all addition. Partial fill is not independently rejected. Paired zero payouts are skipped; chosen-leg zero payout is still attempted. Zap events retain the pre-sale pair allocation. |
| Collection and fee notification failures | PT-COMP-01/02/03, R:282-299; PT-BAL-04, R:379 | `src/pair/PairToken.sol:416-463`, `:688-690`. Collection reports caller deltas, not the separate fee delta. Both routing getters are read when collection is positive, even for a zero fee-manager result. Notification success does not prove an ERC-20 pull; approval decode failures and cleanup decode failures are not silently swallowed. |
| Dust, compound ratio sizing, and distinct cap | PT-COMP-04/05/06, R:301-318 | `src/pair/PairToken.sol:434-442`, `:469-495`. The outer dust threshold is strict, token0 valuation has two floors, ties select token0, the compound cap uses active pool liquidity and a further division by four, and no compound tick-movement guard is imposed. Swap activity alone does not trigger Compounded. |
| Callback ABI and settlement | PT-CB-01 through PT-CB-07, R:332-369; PT-MATH-05, R:165-169 | `src/pair/PairToken.sol:81-100`, `:120-123`, `:533-643`. Operation values, nested bytes framing, payload/return fields, unarmed configured-manager authority, empty hook data, widened fee-minus-caller used amounts, unsigned reinterpretation of removal/collection deltas, and currency0-first resolution match. The signed swap conversion and minimum-int128 negation quirks are preserved. |
| Donation, reservation, and transfer-helper differences | PT-BAL-01 through PT-BAL-07, R:373-391 | `src/pair/PairToken.sol:646-690`; `lib/v4-core/src/types/Currency.sol:40-96`; `lib/v4-core/src/libraries/CustomRevert.sol:83-127`. There is no donation exclusion or nonstandard-token allowlist. Pull/payment Boolean decoding differs from payout raw-word validation. Wrapped payout errors preserve returned bytes even when the low-level call succeeded but returned unacceptable data. |
| Events, errors, and absence of extra product guarantees | PT-EVENT-01/02/03, R:395-418; PT-ERROR-01 through PT-ERROR-04, R:422-457; PT-ABSENT-01/02, R:461-463 | `src/pair/PairToken.sol:54-55`, `:102-129`, plus the relevant entrypoint bodies cited above. Event types/indexing, mint/burn/refund ordering, custom-error predicates, and stated propagation boundaries agree. The document does not import an oracle, personal fee accounting, target-token rate, armed callback, or unrelated IndexedEx architecture into the baseline. |

The document also correctly avoids adopting misleading source comments as guarantees. Examples include the claim of universal excess refunds above `deposit`, a pool-reserve description above user zaps, and the claim above `_carve` that a fee manager can never block a user action. The normative requirements follow the executable statements instead.

## Acceptance scenarios and numerical checks

All PT-AC-01 through PT-AC-58 were read and compared with their normative requirements and relevant source branches. I found no incorrect published numerical example. Direct integer arithmetic, without executing the contract, confirms:

| Scenario | Checked result |
| --- | --- |
| PT-AC-02, R:474 | Spacing 60 gives usable bounds -887220 and 887220. |
| PT-AC-08, R:485 | Inputs 2000/2000 give gross genesis shares 2000; successful entry mints 1000 to the recipient and 1000 to DEAD even with `minShares=2000`. |
| PT-AC-12, R:489 | The candidate shares are 333 and 714; the minimum is 333, and upward-rounded selected amounts are 100 and 234. |
| PT-AC-18/19, R:495-496 | The stated nominal cap is 1000; half of measured receipt 999 floors to 499. |
| PT-AC-23, R:505 | Payout shares are 999, liquidity removal is 4995, and idle allocations are 10 and 9. |
| PT-AC-35, R:522 | Protocol amounts at 250 bps are 250 and 125. |

### Acceptance-evidence gaps, not false specification

The scenarios are a good acceptance outline, not a complete executable conformance corpus. PT-AC-BASE explicitly says so at R:467. The following are nonblocking additions for a later authorized verification plan; they do not require inventing behavior or consulting target implementation code:

1. **More exact mathematical vectors.** PT-AC-55 at R:542 provides categories rather than a broad set of numeric oracles. Expand PT-MATH-02/03/04 with nonzero remainder cases, nonzero positive and negative tick values, exact usable-range endpoints, one-side candidate overflow, and a checked-product-overflow versus full-precision-success distinction. Relevant source: `SqrtPriceMath.sol:188-256`, `TickMath.sol:57-121`, `LiquidityAmounts.sol:18-55`, and `_quoteShares` at `PairToken.sol:500`.
2. **Explicit dependency-call traces.** PT-AC-46/49/50 at R:533-537 state the right rules but do not supply concrete calldata/returndata and read traces. Derive vectors for operation 0 through 4, malformed inner encodings, ignored Collect payload, packed signed delta words, and the different paired-add versus Deploy price/idle checkpoints. Relevant source: `_addAll` at `PairToken.sol:295`, `_unlock` at `:546`, `unlockCallback` at `:550`, and `_deployInLock` at `:576`. No change to the normative ABI contract is needed.
3. **A complete transfer-return matrix.** PT-AC-38/39/52 at R:525-526 and R:539 cover important failure classes, but later evidence should distinguish empty, false, short, noncanonical Boolean, true-plus-trailing-data, revert, and unsuccessful cleanup results across pull, manager payment, approval, payout, and refund. Relevant source: `PairToken.sol:447-463`, `:670-690`; `Currency.sol:40-87`; `CustomRevert.sol:83-127`. The existing prose already defines these distinctions.

These are coverage recommendations, not additional findings of incorrect requirements and not evidence that such tests ran.

## Coverage

| Target or examination area | Status | Extent and limits |
| --- | --- | --- |
| Entire published requirements, Parts I-III | Examined | Full read; all normative groups and all 58 scenarios considered. |
| Entire `src/pair/PairToken.sol` | Examined | All entrypoints, generated-getter declarations, helpers, constants, errors, and events. |
| Required arithmetic dependencies | Examined | PairToken-used FullMath, TickMath, SqrtPriceMath unsigned delta routines, UnsafeMath rounding, FixedPoint96, LiquidityAmounts, and PriceMath square root. Unused helper algorithms were not treated as implementation obligations. |
| Required identity/storage dependencies | Examined | PoolKey, PoolId hashing, Position key construction, and StateLibrary reads used by PairToken. |
| Required currency/delta/error dependencies | Examined | Currency balance/payout paths, BalanceDelta component extraction, and CustomRevert wrapper encoding. |
| Required manager/token interfaces | Examined | IPoolManager, IExtsload, IUnlockCallback, IERC20Minimal, and the factory/fee-manager interfaces embedded in PairToken. |
| Public ABI/getters/events/errors and initialization/ERC-20 edges | Examined | Static declarations and control-flow comparison, not generated ABI or bytecode execution. |
| Basket/previews/genesis/minShares/deposits/exits/retention | Examined | Formula, width, checkpoint, event, and failure-path comparison. |
| Compound/fees/notifications/native reservations/refunds/donation/dust | Examined | Local conditional behavior, not actual deployed dependency behavior. |
| Callback framing/opcodes/deltas/settlement/caps/ticks | Examined | Required nested schemas, direction, read order, and type semantics. |
| Remaining unused routines and transitive interfaces in the source bundle | Partial | Some surrounding definitions were read; no claim to audit every unused function or inherited interface. They do not fill in the missing deployed implementations. |
| Concrete factory, fee manager, hook, PoolManager engine, and token implementations/settings | Not examined | Not supplied as deployed implementations. Interfaces/comments do not establish their internals or live behavior. |
| Runtime equivalence and exhaustive input-domain verification | Not examined | No tests, builds, runtime calls, wallets, or deployments. Arithmetic checks above are not contract execution. |
| Legal clearance and implementation-team source-exposure history | Not examined | Outside this technical assignment; no legal research performed. |

## Standalone handoff and process boundaries

**Technical readiness:** Yes, for the contract-local scope described in PT-CONFORM-01/02 and Part III. The published document gives an implementation team the public surface, arithmetic, branch precedence, external-call checkpoints, callback encoding, and helper failure behavior without directing it to target code. No missing manager default, hook rule, or factory setting should be supplied by guessing; PT-DEPENDS-01 through PT-DEPENDS-05 at R:551-572 already identify those unknowns. Whole-system equivalence requires a compatible manager and identified dependencies, as the document itself states.

**Source exposure and segregation:** This review is source-exposed. Its source locators and analyst conclusions should remain analysis-side evidence. The designated standalone handoff is the requirements document, not this response or the source bundle. A separate planner is a process choice, not evidence that every participant was source-unexposed. I did not inspect peer responses, earlier council artifacts, or analyst notes.

**Legal clearance:** Not certified. `src/pair/PairToken.sol:1` identifies BUSL-1.1. The license marker, verification metadata, original prose, and existence of a separate implementer do not establish legal permission. This response neither supplies a license opinion nor treats legal clearance as having been obtained.

## Disposition and saved artifact

Proceed with requirements-based planning under the existing dependency limits. Preserve the specified quirks; proposed repairs require explicitly labeled deviations. No requirements edits were made or requested by this review.

Only this response was written, using `apply_patch`:

`/Users/cyotee/Projects/indexedex/docs/reviews/pairtoken-requirements-fidelity-20261027-01a17e03/members/astra/response.md`
