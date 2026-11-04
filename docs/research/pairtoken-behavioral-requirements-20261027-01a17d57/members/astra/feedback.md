# Astra advisory feedback - PairToken behavioral requirements

## Position

**SUPPORT WITH CORRECTIONS.**

Reviewed identity: **`pairtoken-requirements-draft-r1`**.

Reviewed file: `coordinator/draft.md`.

SHA-256 computed from the complete reviewed text: **`763dd6ad786ac84e61f968af77a627a2c0103a6fc6c67c8152127115083f229b`**, matching the assigned identity.

The draft is substantially complete and supports a different agent preparing an implementation plan without reading raw target code. It specifies the actual basket-based product rather than the previously proposed alternative. I found no missing public method/getter or foundational accounting substitution. Four bounded corrections below should be incorporated before treating the handoff as an exact behavioral baseline. They concern error payload bytes, an acceptance-case precondition, a dependency-read checkpoint, and an overbroad native-funding explanation. None requires new product behavior or investigation of an absent concrete dependency.

The wording at issue largely originated in my own candidate. Its reuse does not establish correctness; the frozen source controls this review.

## Review basis and limits

I read the entire immutable draft, including its initial Scope and Conformance sections, and the complete supplied `analyst/traceability.md`. I used the admitted frozen PairToken and dependency sources from the continued source-exposed context, rechecked all named public declarations, getters, events and custom-error declarations, and specifically rechecked the relevant quote, addition, redemption, zap, compound, token and wrapped-error passages.

No peer original or feedback was read. I did not perform an independent chain verification, run tests, compile, install, delegate, deploy, use Git, modify configuration, or send external messages. This feedback is the only authored artifact in this advisory pass. The draft and all originals remain unchanged.

Source locators below refer to original-source lines, not Markdown bundle lines. `src/pair/PairToken.sol` is abbreviated as `PairToken` only where its path is already explicit. The previous complete source reads remain admitted context; this is a static advisory comparison, not a fresh runtime or mathematical-library audit.

## Corrections

### C1 - Correct the wrapped payout error's `reason` bytes

**Classification:** Required behavioral correction; medium significance for exact error compatibility.

**Requirement IDs:** `PT-BAL-05`; associated acceptance `PT-AC-52`. Clarify the meaning of propagation in `PT-ERROR-03` consistently.

**Draft issue:** The payout wrapper description says its `reason` contains the target's “raw revert data.” That is incomplete. A payout can be rejected because the low-level call returned successfully with false or malformed data, not because it reverted.

**Source anchors:**

- `lib/v4-core/src/types/Currency.sol:64-85`, `CurrencyLibrary.transfer`: success combines the call-success bit with the return-data acceptance predicate; either kind of failure invokes the wrapper.
- `lib/v4-core/src/libraries/CustomRevert.sol:83-117`, `bubbleUpAndRevertWith`, particularly lines 107-109: the reason length and contents come from the full `returndatasize` and `returndatacopy`, without a distinction between returned and reverted data.

**Observed behavior:** If an ERC-20 payout call succeeds at the EVM level but returns a 32-byte false Boolean, the wrapped `reason` contains those 32 zero bytes. If it returns a single byte `0x01`, the wrapper retains that single byte. If it reverts with data, the wrapper retains that revert data. The wrapper does not replace successful-but-rejected return data with an empty reason.

**Precise correction:** Replace the reason-field description with:

> The `reason` field contains the complete raw returndata of the failed-or-rejected low-level payout call, whether that data came from a revert or from a successful call whose return value failed the payout acceptance rule.

Keep the existing target, selector and four-byte context requirements. Add to `PT-AC-52` that the wrapped reason preserves the actual short returned bytes, and add the false-Boolean case either to that scenario or a neighboring error scenario.

In `PT-ERROR-03`, distinguish “causes the outer operation to fail” from “bubbles the original revert bytes unchanged.” Pull/refund errors can be replaced with `TransferFailed`; payout errors are wrapped; manager and token-balance-read failures follow their respective external-call behavior. The existing detailed helper requirements already mostly establish this, so a short clarification is sufficient.

**Implementation-plan consequence if uncorrected:** A planner could preserve the fact of a revert but specify the wrong externally observable encoded error payload.

### C2 - Add positive supply to the one-zero-reserve acceptance scenario

**Classification:** Required acceptance correction; low significance because the normative branch table is already correct.

**Requirement IDs:** `PT-AC-11`, with authoritative branch precedence in `PT-QUOTE-01`.

**Draft issue:** The scenario premise says only that one reserve is zero, and expects quotation exclusively against the other leg. That is true only after excluding the zero-supply branch.

**Source anchor:** `src/pair/PairToken.sol:500-511`, `_quoteShares`. The `supply == 0` alternative is evaluated before either individual zero-reserve branch.

**Observed behavior:** With `S=0`, exactly one reserve zero, and requested amounts `(2000,2000)`, a successful quote uses the geometric-mean branch and returns gross shares 2000 with both selected amounts 2000. It does not quote only the nonempty-reserve leg. This is a static example of the existing branch definition, not an observed live-pool transaction.

**Precise correction:** Change the scenario premise to:

> Positive supply and exactly one basket reserve zero.

Optionally add to `PT-AC-08` or `PT-AC-09` that zero-supply precedence holds regardless of nonzero donated basket property. Do not change `PT-QUOTE-01`, which already captures the source correctly.

**Implementation-plan consequence if uncorrected:** A scenario-derived acceptance plan could contradict the ordered normative quote table. `PT-CONFORM-01` helps resolve that conflict, but the example itself should be accurate.

### C3 - Specify the paired-add balance-read versus price-read order

**Classification:** Required checkpoint completion for the draft's exact call/failure-order baseline; low-to-medium significance.

**Requirement IDs:** `PT-DEP-03`; relevant ordering summary `PT-ERROR-02`.

**Draft issue:** Paired addition is described as using all current idle balances “at a fresh current price,” but the relative order of those dependency reads is not explicit. The draft specifies comparable ordering for basket and Deploy, so this is a narrow remaining gap.

**Source anchor:** `src/pair/PairToken.sol:295-302`, `_addAll`, especially lines 296-298.

**Observed behavior:** At this post-pull addition checkpoint, the instance reads currency0 idle, then currency1 idle, then manager slot0. It computes fundable liquidity from those sampled balances and that subsequent price. This differs from Deploy, which obtains its price checkpoint before its later idle reads.

**Precise correction:** Add to `PT-DEP-03`:

> For the paired-entry addition, sample currency0 idle, then currency1 idle, then read the fresh manager price; compute fundable liquidity from those sampled values.

Do not impose this order on the separately specified Deploy path.

**Implementation-plan consequence if uncorrected:** A plan could move the manager price read ahead of the token balance reads and alter external observation or first-failure behavior. For example, conditional on reaching this checkpoint, a failing currency0 balance read occurs before an otherwise failing next slot0 read; the latter is not reached. No adversarial reachability or security claim is needed to specify that ordering.

### C4 - Do not turn the native helper's nominal return into a universal funding assertion

**Classification:** Required wording qualification for the expressly admitted unvalidated-key domain; low significance.

**Requirement IDs:** `PT-BAL-02`, read with `PT-SCOPE-04`, `PT-INIT-02`, `PT-DEP-01` and `PT-ZAP-01`.

**Draft issue:** The native pull description says “native value has already arrived.” That explains intended correctly ordered payable routes, but is not an unconditional guarantee of the helper or initializer.

**Source anchors:**

- `src/pair/PairToken.sol:661-667`, `_pull`: the native branch returns the requested amount without a transfer or funding check.
- `src/pair/PairToken.sol:651-656`, `_checkNative`: paired value admission depends on currency0.
- `src/pair/PairToken.sol:319-323`, `zapDeposit`: native value is required only for the native currency0/input branch.
- `src/pair/PairToken.sol:138-152`, `initialize`: no currency-order check.

**Observed behavior:** The helper's native return is nominal. Correct funding for an ordinary native currency0 route follows from that entrypoint's separate value checks. An initialized key with native currency1 is not locally rejected merely for its ordering, and the native helper itself does not prove that its returned amount arrived in this call. Downstream behavior remains dependency-dependent.

**Precise correction:** Replace the explanatory sentence with:

> Pulling a native amount returns that nominal amount without making a transfer or independently checking funding. For the ordinary native currency0 routes, the separate entrypoint value checks account for the incoming native value.

Do not add a new key-order, balance or native-input validation. This is a qualification of the stated observation, not a request to support or repair an invalid pool configuration.

**Implementation-plan consequence if uncorrected:** A planner could mistakenly treat native receipt as measured or guaranteed across every key the local initializer accepts.

## Optional handoff precision

### N1 - Preserve the front matter as part of the planner input

**Requirement ID:** `PT-HANDOFF-01`.

The current assignment explicitly makes the **entire** immutable draft, without analyst material, the planner-facing baseline. The requirement's “contain Parts I-III” wording should not cause a publisher to omit the preceding Scope and Origin or Conformance and Planning Use sections.

Suggested clarification:

> Publish this complete standalone requirements document, including Scope and Origin, Conformance and Planning Use, and Parts I-III; retain analyst traceability and deliberation separately.

This is a handoff instruction clarification, not a source-behavior correction. Its authority is the current user assignment and the draft's own opening, not a code locator.

## Public-surface verification

All 17 named public/external functions, the receiver, and all 17 generated getters are represented with their parameter types/order, return types, mutability and relevant caller/recipient rules. There is no missing method requiring raw-source consultation by the planner.

| Public surface | Requirement coverage | Source anchor / disposition |
| --- | --- | --- |
| `initialize` | PT-API-01; PT-INIT-01/02/03 | `PairToken:138-152`; one-shot first-caller factory assignment and lack of extra validation retained. |
| `approve` | PT-API-02; PT-ERC20-01 | `PairToken:156-160`; overwrite, zero spender, event and true return retained. |
| `transfer` | PT-API-03; PT-ERC20-02 | `PairToken:162-165,174-181`; destination/balance checks and unguarded plain transfer retained. |
| `transferFrom` | PT-API-04; PT-ERC20-03 | `PairToken:167-181`; finite/max allowance, no owner bypass and precedence retained. |
| `poolKey`, `token0`, `token1` | PT-API-05/06/07 | `PairToken:201-211`; stored key/address getters represented. |
| `positionLiquidity` | PT-API-08; PT-VIEW-01 | `PairToken:214-218`; owner/range/zero-salt manager read represented. |
| `basket` | PT-API-09; PT-VIEW-02 | `PairToken:221-230`; live endpoints, no clamp, idle inclusion and zero-liquidity branch retained. |
| `previewDeposit` | PT-API-10; PT-VIEW-03; PT-QUOTE-01 | `PairToken:233-241,500-519`; complete quote branches and gross genesis preview retained; correct C2 in the example. |
| `previewRedeem` | PT-API-11; PT-VIEW-04/05 | `PairToken:243-250`; zero short circuit, retention, no balance/supply cap and execution differences retained. |
| `deposit` | PT-API-12; PT-DEP-01 through PT-DEP-05 | `PairToken:256-302`; gross check, measured receipts without share recomputation, computed-add genesis check, dead mint and sender refund retained; C3/C4 complete precision. |
| `zapDeposit` | PT-API-13; PT-ZAP-01 through PT-ZAP-04 | `PairToken:308-345,521-529`; vault-basket cap, actual-receipt half-swap, tick guard and pre-basket used-amount mint retained. |
| `redeem` | PT-API-14; PT-EXIT-01/02/03/05 | `PairToken:351-363,391-405`; caller-only burn, independent floors, pair minima and skipped zero transfers retained. |
| `redeemZap` | PT-API-15; PT-EXIT-01/02/04/05 | `PairToken:366-388,538-544`; per-call selection, skip-add, partial fills, zero output transfer and pre-swap event amounts retained. |
| `compound` | PT-API-16; PT-COMP-01 through PT-COMP-06 | `PairToken:412-495`; returned collection, protocol routing, both cap contexts, strict dust and event predicate retained. |
| `unlockCallback` | PT-API-17; PT-CB-01 through PT-CB-07 | `PairToken:550-642`; operation schemas, sender-only guard, signed widths, settlement and separate unlocks retained. |
| Payable `receive` | PT-API-18; PT-BAL-01/06 | `PairToken:133`; unrestricted empty receiver retained. |
| `name`, `symbol`, `decimals` | PT-GET-01/02/03 | `PairToken:47-49`; string/string/uint8 and constant 18 represented. |
| `totalSupply`, `balanceOf`, `allowance` | PT-GET-04/05/06 | `PairToken:50-52`; exact address arguments and uint256 results represented. |
| `BPS`, `DEAD_SHARES`, `RETENTION_BPS`, `DUST`, `DEAD` | PT-GET-07 through PT-GET-11 | `PairToken:59-66`; four uint256 constants and address constant represented. |
| `factory`, `poolManager`, `poolId`, `tickLower`, `tickUpper`, `initialized` | PT-GET-12 through PT-GET-17 | `PairToken:68-74`; address/address/bytes32/int24/int24/bool represented. |

All five event schemas/indexing and all 13 declared local custom errors are accounted for. The draft correctly treats `NotFactory` as unused rather than an authentication rule. C1 corrects a dependency wrapper's dynamic payload description; it does not alter that local-error inventory.

## Disposition of material topics from my original

| Original topic | Advisory disposition |
| --- | --- |
| Collective basket property and absence of detached fee claims | Fully retained in PT-SCOPE, PT-COMP and PT-ERC20. |
| Raw units, constants and token decimal non-normalization | Retained; no hidden 9-decimal or virtual-offset conversion introduced. |
| Exact amount/liquidity and tick-price integer contracts | Retained in PT-MATH-01 through PT-MATH-05, including candidate-cast failures and necessary fixed numerical coefficients. These are mathematical definitions, not copied target function listings. |
| Initialization and first-caller factory trust | Retained, including absent code/key/pool readiness checks; C4 prevents a funding explanation from contradicting that domain. |
| Genesis branches and gross `minShares` | Retained accurately. C2 corrects only the one-zero-reserve scenario's missing positive-supply precondition. |
| Paired receipt measurement without share recomputation | Retained, including old idle deployment and refund semantics; C3 makes the final balance/price read order explicit. |
| User zap versus compound reserve-cap sources | Retained and kept distinct; actual receipt and before/after tick checkpoints are specified. |
| Retention, dead supply, both exit routes and no last-user sweep | Retained with the correct sequential floors and burn quantity. |
| Zero payouts and no independent full-fill/positive-output requirement | Retained without adding a safety repair. Paired skipped zero transfers versus zap's attempted zero transfer is explicit. |
| Unsigned reinterpretation and signed-width swap conversion | Retained; no inappropriate checked positivity cast or invented tag error replaces the source behavior. |
| Protocol routing, success-not-proof, failure catches and malformed returns | Substantially retained. C1 supplies the exact payout-wrapper return/revert payload distinction; it does not change protocol routing. |
| Plain ERC-20 allowances/transfers and guard scope | Retained, including max allowance, no owner bypass, no fee sync and allowed unguarded calls during a guarded operation. |
| Callback operation schemas and separate unlocks | Retained, including manager equality without an armed flag, ignored Collect inner data, empty hook data and no ERC-6909 settlement route. |
| Views and preview/execution differences | Retained without inventing a target rate or an exact-preview guarantee. |
| Events, failures and checkpoint precedence | Complete at the inventory level; C1 and C3 improve exact observable error/call behavior. |
| Dependencies and planning boundaries | Retained correctly. Missing concrete contracts are not mislabeled missing PairToken local requirements. |
| Standalone, source-informed handoff with separate analyst traceability | Retained; N1 clarifies preservation of the complete front matter. No legal or source-unexposed-process conclusion is claimed. |

## Standalone-planning and provenance assessment

The opening and PT-CONFORM-01/02 correctly establish a requirements baseline rather than an implementation sequence. The planner receives the public contract, math, check ordering, error/event rules and conditional external-call behavior. The analyst traceability is not needed to understand those definitions.

The absent factory, fee manager, concrete manager/Pool engine, hooks, token implementations and live state remain external dependency limits. They do not justify replacing known local behavior with guesses, and their absence does not prevent planning the specified PairToken behavior against identified interfaces. An environment-specific claim of deployment or whole-system parity requires the narrower decisions already listed in Part III.

The handoff is prose, tables and mathematical definitions. It does not contain target implementation listings or require the planner to inspect member transcripts or raw target code. Exact ABI identifiers, encoding contracts, state-read layout and numerical math coefficients serve the stated behavioral compatibility objective. No new product feature is requested in this feedback.

The provenance statements are appropriately factual: analysts were source-exposed; the document is source-informed; a separate agent and separated files do not themselves prove an unexposed workflow or legal clearance. No further legal conclusion is needed or supplied.

## Final recommendation

**SUPPORT WITH CORRECTIONS:** incorporate C1-C4, and preferably N1, then use the resulting complete document as the standalone input for the authorized implementation-planning task. The corrections are bounded and source-anchored; they do not require another advisory round or a broad new investigation.

This position applies to the reviewed draft and the changes described here. The coordinator owns final wording and dispositions. It is not approval of an implementation, runtime behavior, security result, deployment, or legal status.
