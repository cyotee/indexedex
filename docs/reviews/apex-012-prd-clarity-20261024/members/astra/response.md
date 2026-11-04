# Member response

## Identity
- Run ID: apex-012-prd-clarity-20261024
- Member label: astra
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/apex-012-prd-clarity-20261024/members/astra/response.md
- Requested role: council-member
- Requested model and reasoning: chatgpt-subscription/gpt-6-astra:high
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

Is `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md` sufficiently clear that two implementers would build the same V3 and V4 Upper Lower Wings accounting?

The PRD is the sole review target. The APEX-2026-012 tracker section and selected existing V4 Wings sources are context, not additional audited targets and not authority to replace the PRD's economic rules. V3 FullSpread was not examined or treated as V3 Wings.

## Evidence

- **E1, target, examined in full:** `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md`, including the opening scope statements, Required outcome, Owner ruling, Accounting, Entry, Exit, Rate checkpoint, What this does not close, Tests 1-9, and Non-goals.
- **C1, context:** `docs/security/audit/second_review/REMEDIATION_TRACKER.md`, heading `APEX-2026-012: apportioned reserve`, lines 353-370. It restates the agreed direction but supplies no additional accounting equations or edge-case rules.
- **C2, context:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol`, especially `_deposit`, `_redeem`, `_harvest`, `_place`, `_bootstrapBacking`, `requiredInput`, and `_postHarvestValue`. The existing implementation has automatic harvest/placement, exact-output helpers, booked local inventory, bootstrap balance adoption, and unlocked-manager branches.
- **C3, context:** the same directory's `UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol`, especially `issue`, `entitlement`, `inputForShares`, `sharesForAssets`, `liquidTarget`, and `requiredLiquid`. Existing initial shares use native target units, and the existing sleeve has a configured reserve percentage and a one-unit floor.
- **C4, context:** the same directory's `UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol`, especially `snapshot`, `totalInventory`, `harvest`, `close`, `place`, `liquidFloor`, and `_add`. Existing accounting distinguishes local balances, per-position principal, and accrued fees. Harvest can close converted wings and placement can populate empty positions.
- **C5, context:** the same directory's `UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol` and `UniswapV4UpperLowerWingsStandardExchangeVaultGeometry.sol`. Storage has three liquidity positions and two booked local balances. Geometry defines a full-range core and specific separated wings.
- **C6, context:** the same directory's `UniswapV4UpperLowerWingsStandardExchangeVaultOutTarget.sol`, `exchangeOut`; and `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol`, `getRate` and `quoteRate`. Exact-output execution currently obtains its input from a quote-dependent helper; `quoteRate` currently supports projected state.
- **C7, context:** the same directory's `UniswapV4UpperLowerWingsStandardExchangeVaultExecutionDelegate.sol`, `unlockCallback` and `_modify`; and `UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol`, `execute`. Execution settles manager deltas into local balances; `_modify` does not separately retain the returned fee delta. `execute` rejects an already-unlocked manager.
- **C8, context:** the same directory's `UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTarget.sol`, `_reshape`; and `UniswapV4UpperLowerWingsStandardExchangeVaultRebalancePlanner.sol`, `bestSwap`. Existing rebalance can choose either token direction, execute a swap, and re-place inventory.

All source observations are static. Arithmetic examples below illustrate specification choices; they are not executed pool traces or exploit proofs.

## Assumptions

- The required economic direction is fixed: fractional ownership of all held positions; target-only user I/O; real same-pool conversions; no whole-book liquidation quote on the money/rate paths; no other-token sale outside an acting holder's entry or exit.
- A pool swap can change the composition of existing liquidity without changing its liquidity units. Its execution result can depend on external liquidity. This is also the mechanism described in E1's Entry and Exit sections.
- Existing V4 behavior is not automatically normative where E1 changes or contradicts it. Conversely, the absence of a replacement rule is not permission to invent one.
- A specification can leave implementation techniques open while fixing observable amounts, ownership, rounding, supported operations, and failure conditions. The findings concern the latter.
- Deferred findings, including 040, remain deferred. Requesting a baseline bootstrap or donation boundary does not request a dead-share redesign or closure of 040.

## Coverage

| Area | Status | Result |
| --- | --- | --- |
| Entire target PRD | Examined | Direction is clear; transition equations and several acceptance rules are not implementation-complete. |
| V3/V4 scope and deployment boundary | Examined | A new V3 Wings family is required; V3 FullSpread stays; deployed immutable vaults are not repaired. No ambiguity on those points. |
| Fractional ownership, entry, exit | Examined | Per-position and idle accounting, entry snapshots, fee allocation, rounding, and swap completion need clarification. |
| Settled counter and rate | Examined | Read formula is specified, but the state-transition oracle is missing. |
| Harvest and rebalance boundaries | Examined | Explicit non-sale rules conflict with an unqualified statement that rebalance is unchanged; automatic harvest also affects entry's range constraint. |
| Tests 1-9 and deferred issues | Examined | Good scenarios, but some assertions are contradictory, self-referential, or insufficient to distinguish implementations. |
| Tracker APEX-2026-012 section | Examined as context | Repetition rather than resolution of the identified questions. |
| V4 source directory | Partially examined as context | Only the named files above and relevant searches were used. Not a family-wide code audit; interfaces, remaining projections/transition code, deployment code, and tests were not comprehensively examined. |
| V3 source implementation | Not examined | E1 explicitly says V3 Wings does not yet exist. No substitute family was used. |
| Runtime behavior | Not examined | No Forge, installation, deployment, or transaction was run. |

## Conclusions

**No. Two implementers can agree with the intended economics and still produce different share counts, rate checkpoints, fee ownership, redemption payouts, and failure behavior.**

The PRD clearly rejects whole-book liquidation valuation and clearly requires both Wings families. It also correctly states that remaining holders can take the other side of a departing holder's sale. Those decisions should be preserved.

The most consequential blockers are the absence of a settled-target transition equation, the conflict between exact temporary-liquidity invariance and issuance from a real entry swap's liquidity result, and the lack of a complete fractional-ownership rule covering all three positions, idle tokens, and fees. These are not implementation details that two engineers can safely choose independently.

The smallest useful revision is a normative operation table, a per-component mint/burn rule with rounding and snapshot timing, an explicit resolution of the contradictory acceptance statements, and a supported-operation/failure table. It should record the owner's answers, not introduce another economic design.

### Requirements questions

Each question below has at least two answers that change a contract, test, or vault behavior. Alternatives demonstrate divergence; they are not recommendations.

1. **Q1 - What is the exact `settledTarget` update for each operation?** Does an entry credit the entire accepted target deposit, or credit it net of target spent buying other token? Are target transfers into/out of liquidity neutral custody movements, or counter events? Are exit-swap receipts credited and then the complete payout debited? These choices produce different rates even for identical liquidity. **Smallest clarification:** write `C_after` equations for deposit, redeem, and target-fee collection, identifying gross versus net amounts and excluding internal custody transfers explicitly.

2. **Q2 - What invariant and terminal rule constrain that counter?** If the chosen cashflow equation produces a residual counter at zero supply, is it cleared or retained for the next bootstrap? If an allowed withdrawal would debit more than the stored counter, must that state be impossible, must the operation revert, or is another representation intended? **Smallest clarification:** state the counter's domain, the invariant proving permissible debits, and its value after the last share burn. The public zero-supply rate fallback alone does not answer these questions.

3. **Q3 - Which temporary-liquidity requirement is normative for an entry that actually swaps?** Must the share count be identical despite a changed real execution result, merely not increase, or reflect actual proportional liquidity while excluding a separate valuation manipulation? E1 contains the first two and also requires the third mechanism. **Smallest clarification:** resolve the priority and state the controlled conditions of Test 3. If literal equality is mandatory, specify how differing execution proceeds and unspent amounts are treated without leaving that decision to the implementer.

4. **Q4 - At what point is the pre-add ownership baseline fixed?** Before automatic harvest, after harvest but before the entry swap, or after the entry swap and any fees it creates? Existing holders can fill that swap, changing their token mix. **Smallest clarification:** name the snapshots for supply, each position's liquidity, idle balances, and accrued fees; state which snapshot Test 6 uses to compare the entrant's other-token contribution and entitlement.

5. **Q5 - What exact vector equation and rounding rule determines shares and each liquidity change?** Must every occupied slot grow/shrink by one common fraction independently, or may total/aggregate liquidity determine shares while individual slots differ? How are nonintegral amounts, zero-share mints, and a redemption rounding to zero liquidity handled? **Smallest clarification:** provide per-slot mint/burn equations, rounding directions, residual ownership, and the accepted error bounds. An aggregate-liquidity formula is not equivalent to proportional ownership of every range.

6. **Q6 - How do booked idle balances and entry leftovers participate?** Does an entrant have to contribute proportionally to existing idle target and other as well as to LP liquidity? Must the existing configured target sleeve remain? Is unused entry target refunded or accepted into shared inventory, and how does that affect shares and the counter? **Smallest clarification:** include both idle components and accepted-versus-refunded input in the ownership equations, and state whether the existing sleeve/floor rules remain normative. These are holdings already included by Accounting, not a proposal for another reserve product.

7. **Q7 - When do uncollected fees become part of a holder's slice?** Do fees accrued before entry belong entirely to existing holders even if collection occurs after minting, or do only previously collected fees count? On redemption, are fees collected by a liquidity modification apportioned across holders or all paid with its returned tokens? What happens to collected other-token fees? **Smallest clarification:** define fee ownership at the entry/exit snapshot, treatment of fees arising during the operation, and allocation of incidental collections separately from removed principal.

8. **Q8 - Is crediting collected target fees mandatory, and which collection paths qualify?** Can harvest collect target fees without updating the counter because it “may” credit them, or must every qualifying collection update it exactly once? Does an add/burn that collects fees receive the same treatment as an explicit harvest? **Smallest clarification:** distinguish optional collection from mandatory accounting of a completed collection and enumerate the qualifying paths.

9. **Q9 - What bootstraps the first positions and first shares in each family?** The first deposit has no existing liquidity against which to mint proportionally. Are current V4 geometry, initial target placement, and native-target share units inherited by V3 and retained by V4, or is another already-approved baseline intended? **Smallest clarification:** name the normative baseline and specify the first-mint equation and initial placement exception. This need not settle the deferred dead-share issue.

10. **Q10 - What may happen when a position slot is empty while supply remains?** Must it remain empty because entry cannot open a new range, or may entry/placement populate a prescribed core or wing? What if all LP liquidity is zero but booked idle assets and shares remain? **Smallest clarification:** distinguish bootstrap from later empty-slot states and state the allowed entry action and denominator in each.

11. **Q11 - Is entry supported when the owned position is entirely other token?** Entry only describes a two-sided position and a target-only position. One implementation could convert and add to the existing ranges; another could reject the omitted state. **Smallest clarification:** state whether this state is supported and apply the same entry equations to it, or specify its unavailability.

12. **Q12 - What determines the swap price limit?** Is it caller-supplied or calculated, and what rule makes it satisfy the prohibition on `MIN`/`MAX` limits that “ignore the slice”? An exact input bounded to the slice and a non-extreme price limit are different constraints. **Smallest clarification:** specify the limit's source and acceptance rule, and whether entry has the same requirement. Do not leave a new price-protection policy to each implementer.

13. **Q13 - Must the entire other-token slice be sold for a successful exit?** If a bounded swap consumes only part of the slice but the target minimum is met, does the operation succeed with residual other token left behind or revert? If removing the final owned liquidity leaves no route to sell its other token, is the exit explicitly unavailable? **Smallest clarification:** state the full-consumption condition and residual policy, including terminal exits. The minimum-out condition alone does not determine this.

14. **Q14 - Is the exit minimum tested against total payout or swap output alone?** With 80 target removed, 20 target from the swap, and a minimum of 90, the former succeeds and the latter fails. E1 uses both “minimum target out” and “what the swap delivers.” **Smallest clarification:** write the exact inequality and use it consistently in Exit and Test 7.

15. **Q15 - Can entry's automatic harvest close/reopen ranges before proportional addition?** Retaining existing V4 harvest/placement can change which positions exist; suppressing it preserves the entry range constraint but changes maintenance behavior. **Smallest clarification:** state whether such restructuring is permitted inside entry/exit, and which operations count as prohibited opening of a new range. Collection of fees and restructuring should not be conflated.

16. **Q16 - What precisely remains in scope for rebalance under the no-sale rule?** Keeping existing rebalance unchanged can retain an other-token sale; disabling that operation or retaining only permitted maintenance gives different callable behavior. **Smallest clarification:** state the required disposition of the existing rebalance swap path, while explicitly leaving 025's loss-cap remediation open. “Rebalance unchanged” and “no rebalance sale” need a precedence rule.

17. **Q17 - Must existing exact-output entry and exit routes remain supported?** If they remain, how is their final required input established without the forbidden quote, and who receives any executed slice surplus caused by integer sizing? Paying exactly requested target and paying all target generated by the burned slice are not always identical. **Smallest clarification:** name supported routes and define their executed-amount, refund/surplus, and maximum-input rules; otherwise explicitly mark the affected routes unavailable. Do not silently retain the old quote-backed calculation.

18. **Q18 - Does the V3 `slot0` prohibition cover execution sizing, or only valuation/rate reads?** A literal global ban and permission to use current pool state for actual liquidity/swap execution lead to different implementations. **Smallest clarification:** explicitly distinguish prohibited valuation reads from permitted execution/composition reads. The unconditional ban for `getRate`/`quoteRate` is already clear.

19. **Q19 - Must V4 deposits and redemptions work while the manager is already unlocked?** Reverting such calls and executing proportional mutations within an existing unlock context are observably different. The PRD addresses unlocked rate reads, but not money-operation availability. **Smallest clarification:** state allowed/reverting behavior for this state and qualify Test 8 accordingly. This does not ask for a different rate rule.

20. **Q20 - Does “donation” mean direct unbooked transfers only, or also pool fee-growth donations later collected as fees?** The broad no-rate-change statement and permission to credit actually collected target fees differ for the latter. **Smallest clarification:** define the donation classes covered by 012 and explicitly leave the stated 040 remainder outside that assertion.

21. **Q21 - Are the numerical inequalities in Test 2 mandatory or only examples of the expected accounting distinction?** Requiring actual payout to differ numerically from an old quote or a pre-exit target balance rejects coincidentally equal but correctly executed outcomes. **Smallest clarification:** require the actual slice/burn/swap equality and independence from the forbidden calculation; identify any fixture-specific inequality as such.

## Review findings

### F1 - Blocking: the rate formula lacks its state-transition specification

- **Location:** `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md`, Accounting, Rate checkpoint, and Test 5.
- **Invariant or requirement:** The counter must represent the agreed last-settled target measure, remain independent of outsiders' live composition changes, and update consistently on authorized operations.
- **Impact:** `settledTarget * 1e18 / supply` is only a read equation. “Tokens actually move” does not distinguish user cashflows, target spent in an entry swap, LP custody movements, swap proceeds, principal withdrawal, and fee collection. Two counters with different economics both satisfy the displayed formula and Test 5.
- **Concrete divergence:** For an accepted 100-target entry that spends 40 target buying other, crediting 100 versus crediting 60 produces different rates without changing the LP transaction. Under a gross-credit/credit-swap-proceeds/debit-payout reading, a later removal of 60 target plus a sale yielding 35 target leaves 40 in the counter after paying 95. This is an illustrative transition calculation, not a claim that these numbers were reproduced in a pool. It shows why the zero-supply counter rule cannot be inferred from the displayed rate fallback.
- **Fix direction:** Answer Q1, Q2, and Q8 with operation equations, fee-credit rules, and terminal invariants. Add expected-counter assertions derived independently from those equations.
- **Evidence class:** Direct specification omission and arithmetic consequence; static context C2-C4 confirms several distinct target movement types.

### F2 - Blocking: temporary-liquidity equality conflicts with execution-based entry

- **Location:** the PRD, Entry and Test 3.
- **Invariant or requirement:** Entry performs a real same-pool conversion and mints from actual proportional liquidity added; external temporary liquidity must not inflate issuance.
- **Impact:** External liquidity can change the entry swap's execution and post-swap composition, hence the affordable proportional LP addition. Exact equality for the same target input is not implied by removing liquidation valuation. Further, Entry says shares “must not increase,” whereas Test 3 requires the “same number,” which also prohibits decreases. The implementer must decide whether to reject/refund differing execution, force issuance equality, or follow actual added liquidity.
- **Fix direction:** Answer Q3 and make the prose and test assert one precise invariant under stated controlled conditions. Do not silently replace the real-swap design with a reference-price design.
- **Evidence class:** Direct textual mismatch plus an execution-dependence inference from the PRD's own swap mechanism; no runtime proof.

### F3 - Blocking: proportional liquidity is not a complete ownership algorithm

- **Location:** the PRD, Owner ruling's all-position requirement, Accounting's idle-balance inclusion, Entry, Exit step 1, and Tests 1 and 6.
- **Invariant or requirement:** Every holder owns the same fraction of every held component; an entrant must not acquire uncompensated inventory.
- **Impact:** The document does not define a common scaling factor across core and both wings, the snapshot used after the entry swap, or how idle balances enter minting and redemption. Summing heterogeneous position liquidity is not equivalent to scaling each range. Minting only against LP additions can dilute existing idle inventory. Integer rounding makes exact fractional statements insufficient for an executable contract.
- **Fix direction:** Answer Q4-Q6 with per-slot and idle-component equations, snapshot ordering, accepted input/refunds, and rounding bounds. Preserve the chosen economic design rather than selecting a new aggregate valuation.
- **Evidence class:** Direct specification gaps; C3-C5 show concrete local reserves, sleeve rules, and three distinct slots that make the gaps material.

### F4 - High: fee ownership and incidental fee collection are unspecified

- **Location:** the PRD, Accounting, Exit steps 1-3, Rate checkpoint, and Test 9.
- **Invariant or requirement:** An exit receives only its slice; entry does not transfer old holders' value to the entrant; target fee credits reflect actual qualifying receipts.
- **Impact:** “Tokens received” on a liquidity modification is not sufficiently precise to distinguish removed principal from collected accrued fees. The PRD does not say whether uncollected fees are in the pre-entry position, how collected other-token fees are owned, or whether fees generated during the actor's swap belong to preexisting/remaining positions. An implementation can dilute old accrued fees or pay more than the departing slice while following the literal burn-and-pay wording.
- **Fix direction:** Answer Q7-Q8 and require separate principal/fee attribution, including collections triggered by add/burn rather than an explicit harvest. The clarification need not require a particular helper or storage layout.
- **Evidence class:** Direct omission; static context C4 and C7. The current delegate settles modification deltas without retaining a separate fee breakdown.

### F5 - High: bootstrap and empty-position states have no normative baseline

- **Location:** the PRD, opening V3 source statement, Owner ruling's no-new-range rule, Accounting's zero-supply rate, and Entry.
- **Invariant or requirement:** The new V3 family and changed V4 family implement the same defined accounting from their first deposit onward.
- **Impact:** “Against the position that existed before the add” is undefined when there is no position. The zero-supply rate does not set initial share units or placement. Nonzero-supply empty slots and entirely idle holdings also lack a rule. Existing V4 geometry and native-target initial issuance offer possible choices, but the PRD does not incorporate them as normative for the new V3 family.
- **Fix direction:** Answer Q9-Q11, naming the inherited baseline if that is intended and documenting narrowly scoped first-deposit/empty-slot exceptions. Do not turn V3 FullSpread into Wings or resolve deferred 040 economics incidentally.
- **Evidence class:** Direct incompleteness; C3 and C5 show existing choices that an implementer might import differently.

### F6 - High: exit completion, price limits, and minimum-out are not unambiguous

- **Location:** the PRD, Exit's final paragraph and Test 7.
- **Invariant or requirement:** Sell only the actor's other-token slice, pay its actual target proceeds, and revert on unmet user protection.
- **Impact:** The PRD forbids certain extreme price limits without specifying a limit rule. It also does not explicitly require full consumption of the slice, leaving a partial fill that meets minimum-out unresolved. A terminal redemption may remove the vault's own available swap liquidity. Separately, “minimum target out” suggests total payout while “what the swap delivers” suggests swap output alone; those conditions differ even on an ordinary successful sale.
- **Fix direction:** Answer Q12-Q14. State the amount bound, price-limit rule, full-fill/residual condition, terminal failure behavior, and exact total-out inequality separately.
- **Evidence class:** Direct ambiguous requirements; C2 and C7 provide context for an existing bounded-input/partial-output execution model. No liquidity-availability guarantee was demonstrated.

### F7 - High: maintenance exclusions do not reconcile existing callable behavior

- **Location:** the PRD, Owner ruling's entry range constraint, Rate checkpoint's no-other-function-sale rule, What this does not close / 025, and Non-goals.
- **Invariant or requirement:** Deposits add proportionally to existing ranges; no harvest/rebalance/keeper sells other token; 025's separate remediation remains out of scope.
- **Impact:** “This PRD does not change rebalance” is too broad beside a new prohibition that existing rebalance can violate. Retaining automatic harvest can close and repopulate positions before entry, whereas another implementation can remove that maintenance to preserve the no-new-range instruction. Both interpretations change the observable portfolio and entry baseline.
- **Fix direction:** Answer Q15-Q16. Separate fee collection, non-swap restructuring, sale prohibition, and deferred loss-cap work, with explicit precedence for the new requirements.
- **Evidence class:** Direct scope tension, made concrete by C2, C4, and C8. The rebalance planner's direction is not fixed to target-to-other.

### F8 - High: the existing exact-output surface is not covered by the new accounting contract

- **Location:** the PRD, Entry, Exit, Rate checkpoint's preview paragraph, and Test 8; context C6, `exchangeOut`.
- **Invariant or requirement:** No deposit or redemption execution obtains its economic entitlement from a whole-book liquidation quote; redemption pays the actual actor slice.
- **Impact:** Existing V4 exact-output entry/exit computes `amountIn` through `Money.requiredInput` before execution. Updating only exact-input deposit/redeem leaves a forbidden money path. Replacing that calculation still needs rules for exact output, maximum input, discrete slice sizing, and surplus/refunds. A generic permission to keep labeled previews does not specify executable exact-output semantics.
- **Fix direction:** Answer Q17 and enumerate supported money routes and their observable outcomes. Include each supported route in the no-quote acceptance coverage.
- **Evidence class:** Direct coverage omission plus static call-path context C2 and C6.

### F9 - Medium: state-read and execution-availability boundaries are too broad

- **Location:** the PRD, Owner ruling's V3 `slot0` sentence, Rate checkpoint's unlocked-manager sentence, and Test 8.
- **Invariant or requirement:** Live state must not become a forbidden valuation input, while actual swaps and liquidity changes use real executable pool state.
- **Impact:** The V3 wording can be read as banning `slot0` throughout the money path or only banning its use in valuation. The unlocked-manager sentence fixes rate behavior but not entry/exit availability. Test 8 also does not distinguish a quote-specific failure from a pool state where the required real swap/add itself cannot execute.
- **Fix direction:** Answer Q18-Q19. Give permitted state-read purposes and explicitly supported execution contexts. Require Test 8 fixtures to establish that the real operation is otherwise executable, rather than implying every quote-failing state must permit a swap.
- **Evidence class:** Direct wording ambiguity and acceptance-scope gap; static C2, C4, and C7 show the affected execution branches.

### F10 - Medium: donation exclusion is broader than its defined accounting boundary

- **Location:** the PRD, Accounting, What this does not close / 040, and Test 5.
- **Invariant or requirement:** Unbooked donations must not become inventory or manipulate issuance/rate; collected target fees may update the settled counter.
- **Impact:** Direct transfers are explicitly excluded, but “a donation” is later unqualified beside a reference to deferred fee-growth donation behavior. Pool-origin fee receipts and direct unbooked vault transfers are different accounting inputs. Without the boundary, one implementer may reject/ignore receipts another credits as collected target fees, and tests can accidentally demand closure of part of 040.
- **Fix direction:** Answer Q20 and name the donation class in each acceptance assertion. Preserve the explicit deferred scope.
- **Evidence class:** Direct terminology/scope ambiguity; no claim that 040 is fixed or reproduced.

### F11 - Medium: several tests do not independently prove the stated economics

- **Location:** the PRD, Tests 1, 2, 5, and 6, with Test 3's separate contradiction covered in F2.
- **Invariant or requirement:** Acceptance tests must reject implementations that violate fractional ownership or compute the wrong settled counter without rejecting legitimate coincidentally equal outcomes.
- **Impact:** Checking `shares / newSupply` against an entitlement defined using the same expression is circular unless the test independently checks actual per-slot liquidity and inventory changes. Checking the displayed rate formula against a counter written by the implementation cannot establish that the counter is correct. Test 2's unconditional numerical non-equalities are stronger than “do not compute payout from these values”: two different methods can produce equal numbers in a particular fixture. Test 6 needs the post-swap baseline and fee/idle policy from Q4-Q7 to be measurable.
- **Fix direction:** Answer Q21, then use independently expected counter transitions and component-level liquidity/token/fee reconciliation. Keep “not computed from a quote” separate from “not numerically equal to a quote.” Define explicit nondegenerate fixtures when an inequality is useful.
- **Evidence class:** Direct acceptance-criteria analysis. No test suite was run or asserted to fail.

## Limits

- This is an independent initial review. No peers, coordinator draft, or other member response were read; no sub-agents were launched.
- The PRD was fully read. Optional V4 source examination was selective and only establishes plausible divergence points, not source correctness or exhaustive API coverage.
- The new V3 Wings requirement was taken from the target. No assertion about V3 Wings runtime behavior or compatibility was fabricated, and V3 FullSpread was not used as a substitute.
- No Forge command, test run, installation, deployment, commit, or mainnet action was performed. Static reading is not runtime proof.
- No alternative economic design is proposed. The questions identify owner decisions or precise specifications needed to implement the recorded design consistently.
- Only this owned response file was authored. The PRD, tracker, and all other council/project artifacts were left unchanged.
