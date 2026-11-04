# Member response

## Identity
- Run ID: apex-012-deposit-process-20261024
- Member label: astra
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/apex-012-deposit-process-20261024/members/astra/response.md
- Requested role: council-member
- Requested model and reasoning: chatgpt-subscription/gpt-6-astra:high
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

Determine why the earlier counter question assumed an entry sale, whether current V4 Wings actually performs that sale, and whether removing the liquidation quote while retaining its deposit sequence satisfies the preserved deposit rules. Identify the smallest necessary process change, without assuming an entry swap is required merely because the draft describes one.

The following citation aliases refer to repository-relative paths:

- **PRD:** `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md`.
- **Questions:** `docs/security/audit/second_review/APEX-2026-012-OPEN-QUESTIONS.md`.
- **Prior report:** `docs/reviews/apex-012-prd-clarity-20261024/REMEDIATION_PRD.md`.
- **Money:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol`.
- **Harvest:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol`.
- **Accounting:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol`.
- **Common:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol`.

## Evidence

1. **Current deposit is not an entry swap.** `_deposit` pulls target, optionally initializes bootstrap backing, harvests, obtains `Quote.quote(...).value`, computes shares, checks the minimum/exact-share route, credits local target, mints, and places liquidity. There is no swap instruction in this sequence. The credit precedes the actual mint, despite the abbreviated ordering in Questions. [Money:120-139; Questions:31]
2. **Harvest and placement modify liquidity.** Their header explicitly says ordinary harvest never swaps. `harvest` closes eligible wings and may place the resulting inventory; `placement` calls `place`. Closing and adding generate `Common.Kind.Modify`, not `Common.Kind.Swap`. Pairing inventory already owned by the vault is not purchasing other token with the deposit. [Harvest:17-19,118-155,168-192; Common:13-21]
3. **The explicit sale belongs to redemption funding and runs in the opposite direction.** `_redeem` invokes `_fund`; `_fund` can invoke `_swapDeficit`. That function supplies opposing inventory as exact input with direction `!state.target0`: other token to target, not target to other. [Money:147-172,190-232]
4. **The current mint is value-based, not a proportional-liquidity measurement.** For positive supply, `Accounting.issue` returns `floor(supply * credit / value)`, before `_place` executes. Its comment explicitly assigns subsequent placement costs to vault reserves. [Accounting:17-22; Money:132-138]
5. **Placement is greedy, not proportional across slots.** It tries core, upper wing, then lower wing, using available local balances after a target reserve floor. Each slot independently gets the affordable liquidity. A nonempty slot keeps its range; an empty slot can use freshly calculated geometry. There is no common expansion factor derived from existing slot liquidities. [Harvest:147-192,194-210]
6. **The preserved rule is stronger than fungible ownership alone.** The owner-ruling section states: "A deposit adds liquidity in proportion to those existing positions. It does not open a new range." Accounting includes idle balances. Separately, the draft Entry section explicitly describes a target-to-other swap for two-sided entry. [PRD:24,29-31,43-45]
7. **The correction makes the code the starting point, not proof of compliance.** It rejects the counter question's sale premise and requires a demonstrated conflict with preserved rulings before changing the existing deposit process. [Questions:9,27-35]

## Assumptions

- The owner's correction controls the factual description of the existing process. I do not treat the older Entry sentence as sufficient authority to prescribe a swap.
- The explicit proportional-addition and no-new-range ruling at PRD:24 remains preserved. Questions:9 says the questions do not reopen prior rulings. If proportional addition itself is withdrawn, that is a different contract and changes this conclusion.
- The counterexample concerns positive supply, an available locked-manager execution path, a mixed core, an existing target-only wing with capacity, no eligible wing to harvest, and no available idle other token or other-token fees. It does not require an attacker, a price manipulation, or any particular quote value.
- Equations below describe exact arithmetic. Production rounding, fees, bootstrap, and exact-output behavior still need explicit rules; no integer implementation is claimed here.

## Coverage

| Target | Status |
| --- | --- |
| PRD Entry, owner rulings, accounting and relevant tests | Examined |
| Money `_deposit`, `_harvest`, `_place`, `_swapDeficit` and redemption funding connection | Examined |
| Harvest header, harvest/placement and allocation helpers | Examined |
| Questions and prior aggregate report | Examined as supplied context |
| Accounting issuance and Common operation encoding | Examined as supporting context |
| Peer member files | Not read |
| Runtime, Forge, deployment and full callback implementation | Not examined |

## Conclusions

### 1. Why did the prior review assume that sale?

The assumption has a direct textual source: PRD:43 says that a two-sided entry swaps part of the target deposit into the other token. PRD:13 also describes entry conversion through a real swap. The prior report's counter question then asks about target spent "in the entry swap." It was reviewing the proposed PRD process, not establishing that the current implementation already did this. [PRD:13,43; Prior report:48-54]

The mistake is carrying that proposed-process premise into an unqualified question about deposits after the owner rejected it. The artifact supports that explanation; it does not establish the reviewers' private reasoning. The correction should stand: the counter question cannot assume an existing target sale. Whether a replacement process needs one must be demonstrated separately. [Questions:27-35]

### 2. Does the existing Wings deposit sell target?

**No.** The examined deposit path adds target to custody and places available inventory into liquidity. Harvest can withdraw converted wings and pair their tokens with local balances, but it does not exchange the deposit for other token. The explicit `_swapDeficit` conversion is reached through redeem funding and sells other token for target. A later market swap against deposited liquidity is also not a swap executed by this deposit call. [Money:94-104,120-139,147-172,190-232; Harvest:118-155,168-192]

The liquidation quote used for issuance is a valuation input. Its presence does not mean that the deposit executes the sale it models. Removing it therefore removes a pricing dependency, not an existing entry swap. [Money:132-138; PRD:6-7,18]

### 3. Is removing the quote while keeping the rest sufficient?

**No, not for all supported inventory states under the preserved proportional-addition ruling.** This conclusion does not depend on the disputed Entry swap sentence.

Consider the assumed mixed core and target-only wing. With no local other token, the mixed core's affordable addition is zero. The deposit can still increase the target-only wing. Thus:

```text
L_core > 0, L_wing > 0
deltaL_core = 0
deltaL_wing > 0
```

For a proportional entry issuing `m` shares against old supply `S`, the required common factor is:

```text
m / S = deltaL_core / L_core = deltaL_wing / L_wing
```

No positive `m` satisfies both ratios. Changing the scalar used by `Accounting.issue` cannot fix the actual additions. Using old holders' idle other token instead does not create a depositor-funded contribution of other token; idle is already owned. [Harvest:177-210; Accounting:17-22; PRD:24,29-31]

It is true that any fungible share can still own `1 / (S + m)` of every resulting position. That identity alone would permit dissimilar contributions. **The decisive additional rule is that the deposit itself adds liquidity proportionally to the existing positions.** I do not infer a constant target-balance guarantee, or reject changes caused by legitimate swaps. [PRD:21,24,31,58-60]

There is a second manifestation of the same rule violation: placement may populate an empty slot from current geometry, and deposit-triggered harvest can close and subsequently replace a wing. Merely deleting the quote leaves those paths intact. [Harvest:118-155,168-175; PRD:24]

## Review findings

### One finding: quote removal leaves non-proportional placement and range creation on deposit

**Location:** Money:131-138, calling Harvest:118-155 and Harvest:168-210.

**Ruling:** PRD:24 requires proportional additions to the existing core and wings and forbids opening a new range on deposit. PRD:29 includes already-owned idle inventory. This is the preserved ruling that justifies changing the process; the superseded assumption that deposits already sell target does not.

**Impact:** A positive mint can accompany zero contribution to one existing position and a positive contribution to another. Placement can also introduce a range. Neither substituting `settledTarget` for the quote nor dividing summed liquidity fixes these effects. A sum can conceal an unchanged core and a growing wing.

**Smallest deposit process that restores these structural rules:**

1. Retain the target pull, pending-credit isolation, access checks and slippage/minimum-share protection. Keep incumbent inventory and fees separate from the depositor's contribution.
2. Fix the existing ranges. On this entry path, replace harvest/placement behavior that closes and recreates ranges with fee settlement that does not change those ranges. Do not populate empty slots. This is a deposit-path restriction, not a proposed redesign of standalone harvest.
3. Determine a common proportional addition across all existing positions and the owned idle balances. If those additions are fundable entirely in target, add them without a swap. This includes a suitably proportioned target-only book; it does not justify keeping greedy placement.
4. If the proportional contribution requires other token that the depositor has not supplied, successful target-only entry needs to acquire that token. The smallest functional extension is a deposit-funded target-to-other swap in the same pool, followed by proportional additions to the unchanged ranges. Do not spend incumbent other-token inventory as if it were a new contribution. This swap is justified by the demonstrated failure of PRD:24, not by a claim about current code.
5. Use the incumbent book after that real swap and before the additions as the contribution baseline, including any fees credited to incumbent liquidity. Add the pair and required idle contribution, then mint from the achieved common factor. Return unused depositor inventory rather than silently counting unrelated residuals as proportional additions. Enforce the caller's minimum atomically.

In exact arithmetic, with pre-add incumbent liquidities `L_i`, idle balances `B_target` and `B_other`, and a positive common factor `r`, the contribution rule is:

```text
deltaL_i = r * L_i                  for every existing position
deltaB_target = r * B_target
deltaB_other = r * B_other
m = S * r
```

The post-mint entrant fraction is `m / (S + m) = r / (1 + r)`. Its proportional claim equals the contribution rather than an unfunded slice of the baseline. Integer minting must round against over-issuance and verify actual additions; merely choosing one slot's ratio is insufficient. Zero-liquidity slots remain unopened. [PRD:24,29-31,43-45]

Rejecting deposits that cannot fund this factor without conversion is a smaller **restricted** no-swap operation, but it disables mixed-book entry and is not a complete replacement for the described product. There is no positive share-mint equation that makes the unchanged greedy sequence proportional in the counterexample.

This is the smallest structural correction, not a claim that a complete executable specification has been settled. In particular, the actual-output swap/add process can benefit from temporary external liquidity through better execution. PRD:47 prohibits increased issuance, while PRD:88 demands equality. A swap by itself does not establish either property. The owner must reconcile that requirement with actual-liquidity issuance, or specify an execution/admission constraint that proves it. The prior report already identifies this unresolved conflict. I therefore cannot certify an unrestricted replacement as satisfying every sentence of the draft. [PRD:43,47,88; Prior report:36,54]

## Limits

Static review only. No Forge, tests, subagents, peer-file reads, or source edits. The counterexample is an arithmetic/code-path argument, not an executed fixture. The prior aggregate report was read only because it was explicitly supplied as optional context.

Bootstrap, exact routes, counter debits/credits, fee attribution details, integer rounding, and locked-manager admission remain outside this narrow process determination. The current helpers skip harvest and placement when the manager is unlocked, so that branch cannot be presented as evidence of actual proportional liquidity addition either. [Money:94-104; Questions:37-85]

The conclusions are deliberately separate: the owner is correct about current behavior; the earlier sale premise came from the proposed PRD; and quote removal alone still fails the independently preserved proportional-addition/no-new-range ruling.
