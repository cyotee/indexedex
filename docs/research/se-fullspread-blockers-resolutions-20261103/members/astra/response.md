# Astra: proposed resolutions for F1 through F15

## Identity

- Run: se-fullspread-blockers-resolutions-20261103.
- Member: astra.
- Profile: research.
- Phase: initial independent response.
- Requested role: council-member.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Actual runtime role, model, provider/account route, and reasoning setting: not exposed.
- Peers read before submission: no.
- Date: 2026-11-03.

## Question and targets

For each open finding F1 through F15 in the second blocker-report review, what one sentence should be locked so two implementors would not diverge?

The recommendations below are proposed sentences, not owner locks. They do not authorize implementation, a PRD edit, or an owner lock. They do not replace the blockers file or the published review.

## Evidence

The following source abbreviations identify files read in this run:

| Reference | Path and coverage |
| --- | --- |
| Brief | `docs/research/se-fullspread-blockers-resolutions-20261103/brief.md`, complete. |
| Review | `docs/reviews/se-fullspread-blockers-review-r2-20261102/REMEDIATION_PRD.md`, complete, including all F1-F15 findings. |
| Locks | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`, complete, including the booking section and final already-locked list. |
| PRD | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, complete; revision `fullspread-se-prd-weir-align-r1`. |
| Directive | `docs/vaults/PRETRANSFER_DIRECTIVE.md`, complete. |
| Functions | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, complete. |

Section and requirement references below refer to those files. Repository routing and council procedure instructions were also read; they are not economic evidence. No peer response or feedback was read, including either prohibited review-member location. These are live-file reads, not an asserted atomic repository snapshot.

## Assumptions

The Locks file governs over conflicting older PRD and function-review text. Where it leaves a procedure open, the recommended sentence deliberately supplies that procedure and labels the reasoning as inference. An old PRD sentence is retained only when it does not contradict the Locks file.

Amounts are raw integer token units unless a sentence explicitly names raw liquidity or shares. Existing authorization, route, deadline, and caller-minimum checks remain applicable. A preview's mathematical answer is not a promise that an unauthorized or otherwise invalid execution succeeds.

The proposals are a coherent set: F1 determines the refund-only branch, F2 separates newly collected fees from user inputs, F3 determines the final booked total, F4 fixes the ratio, and F5 fixes the one-token conversion procedure. F7 adds fee-origin accounting solely to make the no-argument event predicate deterministic; it does not create a second economic claim.

## Coverage

All fifteen findings receive exactly one recommended lock sentence below. F1-F7, F10-F12 select procedures or clarify their scope. F8, F9, F13, and F14 make storage, terminology, or replacement instructions explicit. F15 defines completion evidence for work assigned to the comprehensive PRD pass; it does not perform that pass or enumerate consumers here.

## Conclusions

### F1. Overstated pretransfer maximum

**Source observation.** Review F1 identifies the missing order; Locks B-13 and the Directive require refunding the unbooked balance when the maximum exceeds it, forbid pulling the shortfall, preserve unrelated staged balances in the ordinary branch, and require input-token refunds.

**Recommended lock sentence:**

> After ordinary validity and authority checks but before any collection, pull, swap, burn, or liquidity change, snapshot each pretransferred input's unbooked held balance U, and if any declared maximum M exceeds its U, make the entire call refund-only with zero output and zero consumption, refund min(M,U) of each declared pretransferred input to msg.sender in that input token, pull no other leg, leave all undeclared balances untouched, skip donation-triggered compounding, and use that same zero-output branch in applicable previews and minimum checks, with a failed minimum reverting the refunds atomically.

**Inference.** Returning all 60 when M is 100 and U is 60 is fundable only if this operation consumes none of that 60. A whole-call branch avoids a half-executed bundle; a valid second pretransferred leg refunds only its declared maximum, not all staged tokens. With a positive required output, the call reverts rather than returning a successful zero-output trade. A donation on this branch has accepted no donation and therefore does not enter maintenance; the ordinary accepted-donation remainder remains booked under B-05. For ordinary M <= U execution, the Directive's existing M-minus-used refund, staging protection, and input-token swap shape remain unchanged.

**Rejected alternative:** Process up to U and refund U-minus-used, because that changes the locked instruction to refund U in the overstated branch.

### F2. Fees collected while adding user liquidity

**Source observation.** Locks B-02 forbids user-route compounding, while the booking section explicitly books fees collected by a withdrawal; Review F2 identifies the missing deposit-side disposition.

**Recommended lock sentence:**

> Every liquidity-adding deposit, bundle deposit, and share-minting exchangeIn collects and books the position fees returned by its liquidity modification as holder-owned local fees, separately from the gross token debits that fund the user's added liquidity, so those fees neither reduce the user's attributed consumption nor increase the user's refund or minted shares and are not reinvested by that user route.

**Inference.** This adopts collection plus booking, not the unverified claim that a liquidity modification can leave earlier fees unpaid. Settlement may net manager deltas, but user attribution must still distinguish the liquidity debit from the fee credit. Shares remain calculated from added liquidity against the pre-add liquidity and supply, with the B-01 fee taken from those new shares. This sentence is a proposed procedure, not a claim that the implementation has been inspected.

**Rejected alternative:** Treat a net manager credit as a depositor refund, because it would transfer holder-owned fees to the current depositor.

### F3. Final booked total and zero added liquidity

**Source observation.** The Locks booking section says both to book the excess and to book the actual held balance, prohibits extra attempts and swallowed failures, and permits a remainder; Review F3 asks which sentence governs and what happens when integer sizing produces zero liquidity.

**Recommended lock sentence:**

> At the end of a successful donate or compound, replace each underlying token's booked total with its actual held balance after settlement rather than adding a calculated excess, treat full use of the scarcer token as the proportional-sizing target subject to integer rounding, and if that sizing yields zero added liquidity skip the liquidity-add call and book the held inputs without another swap or deposit attempt, while every attempted failing step still reverts.

**Inference.** Assignment to the actual balance prevents double-counting an existing remainder and captures the stray transfers the owner explicitly chose to book. A zero-liquidity result is a successful booking outcome, not an attempted failing zero-size add whose error is hidden. F7 makes its event result explicit.

**Rejected alternative:** Increment the old booked total by the entire post-operation balance, because that counts previously booked custody twice.

### F4. Meaning of position ratio

**Source observation.** Locks B-10 preserves `getLiquidityForAmounts` with native token units; the booking section uses an unspecified position ratio; PRD FS-OWN-07 distinguishes principal amounts from unpaid fees.

**Recommended lock sentence:**

> For both-token maintenance, position ratio means the principal token0-to-token1 requirements per unit of liquidity at the bound pool's current sqrt price and the stored full-range ticks immediately before the add, excluding unpaid fees and local balances, with the limiting side determined by the existing integer getLiquidityForAmounts calculation and a zero-required side imposing no limit.

**Inference.** This uses the ratio of the position being funded, not a ratio distorted by fee accumulation, donations, or token decimals. Equal limiting capacities produce the same liquidity amount and need no economically significant tie-break. The one-token path uses this same principal requirement at the price after its selected swap.

**Rejected alternative:** Use principal plus unpaid fees as the target ratio, because fees are inventory to process rather than the token requirements of newly added liquidity.

### F5. One-token swap amount and rounding

**Source observation.** Locks requires a one-token swap toward the ratio and a remainder in the processed token, with no swap for a both-token maintenance balance; PRD FS-OWN-33 still says "about half of the excess"; Review F5 asks for one deterministic size and its scope.

**Recommended lock sentence:**

> For a one-sided user mint or one-token maintenance, replace FS-OWN-33's about-half rule with one mathematically planned swap followed by one proportional add, choosing the greatest integer added liquidity whose rounded-up opposite-token add debit at the resulting pool price is exactly the swap's opposite-token output and whose swap input plus rounded-up provided-token add debit does not exceed the processed input, breaking ties by least total provided-token consumption and then least swap output, executing the swap for that exact output at the existing unbounded limit and leaving every unused processed-input unit in the provided token.

**Inference.** A fixed half-input swap is simple but does not specify a post-swap ratio or guarantee that integer rounding leaves no opposite-token conversion dust. The recommendation instead defines the mathematical result in integer units, including the swap fee and price movement: the opposite-token output is exactly the quantity consumed by the one add. The swap input is the amount required to obtain that output in the same projected state; it is not estimated from the pre-swap spot price. Zero liquidity with zero swap is the feasible base case, subject to ordinary user-mint validity rules and the F3 maintenance rule.

This is an internal swap-direction choice, not a public exact-output route: `exchangeOut` remains unavailable. It does not select a quoter implementation, add a quote-work cap, authorize a second live attempt, or change the both-token no-swap rule. The guarantee concerns the remainder of the processed input; separately collected position fees and stray transfers are booked under F2/F3, not relabeled as user conversion dust. Establishing an efficient integer planner within the existing gas requirements remains implementation work, not evidence supplied by this research.

**Rejected alternative:** Lock `floor(input / 2)` as the swap input, because it does not guarantee the locked input-token-only remainder after fees, price movement, and integer add debits.

### F6. One-token exit residual

**Source observation.** Locks B-02/B-09 removes the sleeve and restricts the swapped quantity to withdrawn principal; PRD FS-MONEY-01 and FS-A08 require a one-token exit to pay only the selected token or revert.

**Recommended lock sentence:**

> The no-leftover-shortfall-revert sentence removes only the former sleeve top-up requirement, while every one-token exit on either unlock path must convert all unwanted withdrawn principal into the selected output token or revert atomically without burning shares, and must never pay, book, or abandon an unconverted principal residual.

**Inference.** This preserves the existing one-token payout contract rather than silently changing redemption into a mixed-token transfer or a donation. A caller minimum remains independently enforceable. A preview of an execution that cannot complete this conversion returns zero rather than introducing a coded view revert under B-06.

**Rejected alternative:** Book the exiting holder's unconverted principal for remaining holders, because the exit entitlement is principal and the accepted output is one selected token.

### F7. `Compounded()` predicate and explanation

**Source observation.** Locks B-11 permits no fields and requires fees to be compounded, not merely collected; `donate` also compounds; Review F7 reports that `ModifyLiquidity` carries a liquidity delta but not token amounts, a dependency-source observation made by that review's coordinator rather than independently rechecked here.

**Recommended lock sentence:**

> Emit Compounded() exactly once from donate or compound iff the call adds positive liquidity using at least one unit of newly collected or previously booked fee-origin tokens, preserving fee-origin counters across booking, charging fee-origin units first within each token's maintenance consumption and assigning swap output pro rata to the fee-origin share of actual swap input with rounding down, while donation-only deployment and zero-liquidity processing emit none and the no-argument signature promises no token-amount reconstruction from PoolManager logs.

**Inference.** The predicate requires knowing whether deployed units came from fees; a single undifferentiated local-balance counter cannot establish that for old booked fees mixed with donations. The proposed fee-origin counters are subsets of the existing booked totals, not additional assets. For a swap consuming S units with F fee-origin units, label `floor(output * F / S)` output units fee-origin, retaining the unconsumed input's existing label; a zero-input swap needs no allocation. For the add, consume fee-origin units first in each token. This determines mixed calls, old withdrawal-collected fees, and fee dust without issuing an event merely because fees were present somewhere in custody. Fees newly collected by the add but not used by it remain booked for a later call.

The reason for the empty event is the locked ABI, not a promise that another event supplies token amounts. B-12's paired-event explanation should likewise avoid claiming that `ModifyLiquidity` itself provides those amounts; its signature remains unchanged.

**Rejected alternative:** Emit whenever a positive add occurs in a call that merely holds any fees, because all fee-origin units could remain undeployed.

### F8. Canonical seven-address write

**Source observation.** Locks B-07 places all seven architecture bindings in package immutables, requires instance initialization to write them into the Protocol Aware Repo, and ambiguously forbids a second per-vault copy.

**Recommended lock sentence:**

> During each vault's initialization, copy the package's seven immutable Uniswap V4 architecture addresses exactly once into that diamond's Uniswap V4 Protocol Aware Repo as its canonical instance storage, with no duplicate copy in the family repo or another instance repo, while the package immutables remain the deployment bindings.

**Inference.** Package deployment storage and a diamond's canonical instance storage are different scopes; the prohibition concerns a redundant instance home, not the required initialization write.

**Rejected alternative:** Keep the addresses only in the package and omit the instance write, because B-07 explicitly requires the Protocol Aware Repo to be initialized.

### F9. Selector absence row

**Source observation.** PRD FS-A01 explicitly includes `poolManager()` in its absence list and says "family-only `poolKey()`"; FS-FACET-01 also contains an ambiguous `poolManager()` exclusion, while Locks B-07 requires externally callable Crane getters.

**Recommended lock sentence:**

> Replace the poolManager and family-only poolKey absence wording in FS-A01 and FS-FACET-01 with the requirement that the factory-built proxy exposes poolManager through the Crane Uniswap V4 Protocol Aware Facet and poolKey, tickLower, tickUpper, and positionLiquidity through the Crane UniswapV4SinglePositionAware Facet, never through a duplicate family query implementation, while preserving the other locked selector exclusions.

**Inference.** This resolves the review's previously member-supplied citation using the actual PRD row. The absence of a family implementation is not the absence of the proxy selector. The other seven-component getters remain governed by B-07; this correction does not trim that facet.

**Rejected alternative:** Delete `poolManager()` from the proxy, because B-07 assigns it to an externally callable shared facet rather than forbidding the information.

### F10. Donation signature

**Source observation.** Functions, "Paired money," retains `donate(token, amount)`; the later Locks booking section explicitly uses `pretransferred`; B-05 retains caller-owned share burning and restricted callers.

**Recommended lock sentence:**

> Install only the nonpayable donate(address token,uint256 amount,bool pretransferred) signature with no return values, replacing the old two-argument signature, where underlying-token donations use the Directive and F1 when the flag is true and pull the directed amount when false, while share donations require false and burn only the caller's shares.

**Inference.** This gives the later pretransfer rule an explicit ABI input instead of inferring it from ambient custody. It also prevents the new flag from turning parked vault shares into caller credit. The owner/operator guard, supported-token check, and zero-supply rejection remain unchanged. The signature is a recommendation, not a claim that the shared interface already has it.

**Rejected alternative:** Retain only `donate(address,uint256)` and infer pretransfer from a sufficient balance, because that makes the specified flag implicit and confuses staged custody with caller direction.

### F11. Batch-swap scope

**Source observation.** Locks B-02 permits inclusion in a batch swap and preserves borrowed execution; PRD FS-X01, FS-UNLOCK-01, FS-UNLOCK-02, and FS-A22 explicitly distinguish canonical `exchangeIn` from bundle and maintenance routes.

**Recommended lock sentence:**

> The batch-swap permission covers every supported canonical exchangeIn route, including share mint, one-token share redemption, and underlying-to-underlying pass-through, under the existing borrowed-unlock funding and settlement conditions, whereas exchangeBundleInForSingleOut, exchangeBundleOut, donate, and compound still revert ManagerAlreadyUnlocked and exchangeOut remains unavailable.

**Inference.** This permits the composition the owner accepted without enlarging the mutator surface by implication. It preserves the existing self-funded, non-pretransferred borrowed context and per-vault delta closure. It adds no exclusion based solely on other pools being in the batch.

**Rejected alternative:** Permit all mutators whenever the manager is unlocked, because the batch sentence does not itself specify the extra bundle and maintenance contexts and the PRD already supplies a narrower usable route.

### F12. Initialization owner and later `feeTo`

**Source observation.** Locks B-02 says to set the owner to `feeTo()` at initialization, permits operators, and does not specify a nonzero precondition or continuing oracle synchronization.

**Recommended lock sentence:**

> Initialize the stored owner to exactly the Vault Fee Oracle's feeTo() value read during initialization, including address(0) without substituting a deployer or rejecting initialization solely for that value, and do not change that stored owner when feeTo() later changes, with maintenance access continuing to use the stored owner and the existing operator authorization independently.

**Inference.** A snapshot is the direct reading of "set its owner." A zero owner has no ordinary owner-originated transaction; it is not proof that the independent operator path is either reachable or unreachable. This does not invent an owner-recovery function or silently synchronize ownership with the fee recipient. Existing ownership-transfer authority, if present, is not determined by an oracle change.

**Rejected alternative:** Re-read `feeTo()` as the owner on every maintenance call, because that replaces initialization with live oracle-controlled ownership.

### F13. Separate liquidity from token reserves

**Source observation.** Locks B-10 uses a raw liquidity scalar for issuance; B-06 and the booking section make the reserve views return position token amounts plus unpaid fees, without local balances.

**Recommended lock sentence:**

> Call the raw position-liquidity scalar used in share mint and burn formulas deployed liquidity, and call the per-token principal amounts plus unpaid fees returned by reserves() and reserveOfToken() deployed token reserves, with neither local booked balances nor a share-decimal scale added to either definition.

**Inference.** This changes names, not formulas or units. `reserves()` remains a token array in `vaultTokens()` order rather than becoming a raw-liquidity return.

**Rejected alternative:** Use "deployed reserve" interchangeably for both, because a rewriter could substitute a liquidity scalar for the locked token amounts.

### F14. Exact no-compound replacement instructions

**Source observation.** PRD FS-MONEY-01 explicitly compounds before deposit and withdrawal, uses the post-compound denominator, and pays pro-rata idle; FS-A11 and FS-A33 repeat those behaviors; the section 6 preview table also includes maintenance.

**Recommended lock sentence:**

> In the comprehensive PRD pass, replace the automatic-compound, post-compound-denominator, and pro-rata-idle instructions in FS-MONEY-01, FS-A11, FS-A33, and section 6's preview description with no compounding or booked-remainder deployment by user deposit, withdrawal, or exchangeIn on either unlock path, pre-add deployed liquidity for issuance, principal-only redemption with collected fees booked under F2 and the withdrawal booking rule, and previews of that same operation.

**Inference.** This identifies the stale instructions rather than relying on a rewriter to infer that every call site is superseded. Borrowed and ordinary paths still share settlement semantics; they now share the absence of user-triggered maintenance. F2 remains necessary because collection is not compounding.

**Rejected alternative:** Replace only FS-OWN-14's public `compound()` definition, because that leaves explicit automatic-compound instructions and acceptance rows in force.

### F15. Consumer-inventory completion rule

**Source observation.** Locks, "How to use this file," and B-08 explicitly assign enumeration of old 32-byte preview-return consumers to the comprehensive PRD pass, not this lock exercise; Review F15 says this is a completion requirement rather than a start gate.

**Recommended lock sentence:**

> The comprehensive PRD pass may begin without a precomputed consumer list but is complete only when it records a source-located inventory of every in-scope direct, interface-mediated, and low-level consumer of the old 32-byte preview return, including the configured rate-provider path, with each consumer's current decoding assumption, required treatment of the 64-byte (amountOut,amountRefunded) tuple, and explicit migrate-or-proven-unaffected disposition.

**Inference.** A path-and-decode inventory is reviewable evidence; a guessed list of component categories is not. The pass must state its search scope and trace indirect decoding rather than declaring completeness from literal selector-name matches alone. This requires documenting migration requirements in that pass, not implementing them or treating an unexecuted migration as complete.

**Rejected alternative:** Require this council to invent the full consumer list before the PRD pass starts, because B-08 explicitly assigns that enumeration to the pass.

## Limits

- These are proposed resolutions to textual and procedural gaps, not verified implementation behavior or accepted owner decisions.
- No source-code investigation, external research, Forge, project tests, installs, Git, deployments, wallets, or sub-agents were used.
- The event-field fact in F7 is attributed to the admitted review; the underlying PoolManager interface was not independently opened.
- F5 specifies a deterministic economic result but does not prove that a particular planner computes it within the existing gas ceilings; no unfinished-quote failure, cap, or fallback is proposed.
- F7's fee-origin bookkeeping is an explicit proposed addition for event attribution, not an assertion that existing storage already distinguishes fee-origin custody.
- No consumer inventory was made for F15, and no proxy selector manifest, operator implementation, or runtime zero-owner behavior was inspected.
- Only the assigned Astra response file is written; the PRD, blockers, published review, and all peer files remain outside this contribution's edit scope.
