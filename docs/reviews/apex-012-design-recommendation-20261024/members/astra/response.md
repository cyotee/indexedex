# Member response

## Identity
- Run ID: apex-012-design-recommendation-20261024
- Member label: astra
- Profile: research
- Phase: initial independent response
- Owned path: docs/reviews/apex-012-design-recommendation-20261024/members/astra/response.md
- Requested role: council-member
- Requested model and reasoning: chatgpt-subscription/gpt-6-astra:high
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

Recommend one reserve that earns swap fees, accepts and ultimately pays one target token, and uses the same economic price for subscriptions, redemptions, and an 18-decimal `uint256` rate.

**Recommendation: an epoch-settled LP vault. It trades between dealing dates, completely settles its portfolio into target before dealing, and issues and redeems shares only at that realized cash price.** It refuses instant entry or exit against a stale rate while the reserve is invested.

There are no required code-review targets. The old apportioned-reserve PRD is evidence of the design being reconsidered, not a constraint to preserve.

## Evidence

- `docs/reviews/apex-012-design-recommendation-20261024/brief.md`, "Scope copied to every member": requires fee exposure, one target-token rate and payout rule, no live liquidation price, and an explicit account of value omitted until conversion.
- `docs/reviews/apex-012-deposit-process-20261024/REMEDIATION_PRD.md`, "Agreed" and "Owner choice": the current deposit does not sell target for the other token; a future conversion must be identified as a new process.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol`, `_deposit`: pulls target, harvests, reads `Quote.quote`, issues shares, credits target, mints, and places liquidity. It contains no entry swap.
- The same file, `_redeem`, `_fund`, and `_swapDeficit`: redemption first computes a quoted entitlement and then funds it through removals and potentially a swap. This is evidence of the existing process, not the proposed settlement process.
- `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md`, "Accounting", "Entry", and "Exit": proposes a historical target counter for the rate, liquidity-based issuance, and actual slice-sale proceeds for exit. Those are different economic measurements unless a further mechanism makes them coincide.
- `.omo/ulw-research/20261023-171500/SYNTHESIS.md`, "Recommendation": supports the shape of a stored target-accounting rate. It does not demonstrate that an invested LP can honor that number on demand. Its external protocol descriptions were not independently verified here.

The recommendation below is a design inference from these requirements, not a claim that an admitted implementation already provides it.

## Assumptions

- Target-only dealing may be asynchronous. A redemption request is not a promise to pay the rate displayed when the request arrives.
- The rate may be the last completed settlement price. A consumer requiring continuously redeemable current NAV is outside this design.
- The redesigned vault may close and reopen positions and convert inventory during settlement. The old PRD's prohibition on keeper conversion and its fixed Wings topology are not retained.
- Holders bear trading losses, conversion costs, and delayed or failed settlement. Swap fees are revenue, not a guarantee of positive return.
- Underlyings follow the repository token policy. Pending deposits and redemption claims can be segregated from active shareholder assets.

## Coverage

The design covers the investment position, target-only subscription and payment, one settlement formula, rate publication, transient pool-state isolation, cohort fairness, and the common V3/V4 economic mechanism.

The core invariant is: **no fungible shares are issued or redeemed while the existing cohort still owns unconverted trading inventory.** Recording a cheap or zero value for that inventory is not a substitute for this gate.

This is deliberately a different product lifecycle, not a quote-library replacement in the current deposit function.

## Conclusions

### Position

Hold a two-token LP position spanning a broad active range, plus explicitly accounted idle balances. The reserve earns swap fees when trades cross its liquidity; it accepts both inventory movement and periods outside the range. Do not describe a resting target-only wing as continuously productive.

Use one fungible share class and a fixed sequence:

`invested -> close and convert -> cash settled -> batch dealing -> reinvested`

At settlement, remove all owned liquidity, collect fees, and sell all other-token inventory into target. This is a real conversion of the complete portfolio, not a hypothetical whole-book quote or an individual holder's zap. There is no remaining vault LP position to take the other side of that sale.

For conversion, use a funded, time-separated batch auction rather than an immediate same-pool swap whose output automatically becomes the share price. Inventory must already be in custody before bidding closes; accepted target proceeds must already be received before the settlement price can be published in a later transaction/block. No provisional bid, unpaid receivable, or unsold inventory enters settled assets.

### Deposit

Accept target into a segregated pending-deposit balance. Do not mint at the previous epoch's rate and do not let pending target cover the existing cohort's conversion losses.

After the old portfolio is fully converted, compute its net target assets and settle deposits at that price. Only then mint shares and admit the new target into active assets.

Reinvestment buys the other token with part of the post-dealing target balance and creates the next LP position. This is a new, explicit portfolio conversion: an active two-token reserve needs the other token, and the user supplied only target. It is not a claim that today's `_deposit` performs that sale. The post-dealing cohort bears the next investment period's deployment costs and risks together.

### Exit

Escrow requested shares without burning them early. They remain part of the old cohort and its supply throughout liquidation, so they bear their fraction of its gains, losses, and settlement costs.

At completed cash settlement, burn accepted redemption shares and reserve their target payment at the same price used for new deposits. Claiming that payment later involves only a target transfer, not another conversion or valuation.

If conversion cannot finish, redemption remains pending: do not pay early redeemers from target cash and leave the unsold inventory to everyone else. User minimum-output or deadline conditions may reject a request, but must not create a different settlement price.

### Rate: the same realized cash ratio

For a completed epoch, let:

- `C` be actual accounted target available to the existing shareholders after conversion and settlement costs, excluding pending deposits, prior payment liabilities, and unsolicited donations.
- `S` be their share supply before the batch, including escrowed redemption shares.
- `D` be an accepted target deposit and `s` an accepted redemption.

Using raw token and share amounts:

```text
shares minted = floor(D * S / C)
target paid   = floor(s * C / S)
```

For target decimals `dT` and share decimals `dS`, the published rate is:

```text
getRate = floor(C * 10^dS * 10^18 / (S * 10^dT))
```

These are one rational price, `C / S`, with unit normalization and conservative integer rounding, not independent valuations. Preserve the settlement numerator and denominator for batch calculations rather than dividing by an already rounded display rate. Rounding dust needs an explicit allocation and must not become a new cohort's windfall on a terminal exit.

For example, if 100 shares settle to 90 target, the rate is 0.9 target per share. An 18-target subscription receives 20 shares; a 10-share redemption receives 9 target. The remaining 110 shares have 99 target before reinvestment. Nobody deals at an obsolete rate of 1.

Bootstrap starts with cash at a declared initial ratio. A total loss with positive supply must not be disguised by resetting that ratio for new deposits.

Between settlements, `getRate` returns the stored last-settled rate. It does not compute current inventory composition, inspect external depth, or execute a sale. Other-token principal has no newly recognized target value until it has actually sold; unrealized inventory gains and losses and unconverted fees are absent from the next rate update. The previous rate is a historical settlement observation, not a claim that its target backing remains in cash after reinvestment.

Consumers need a separate settlement timestamp/status and must accept this stale-rate contract. The rate method itself still returns one 18-decimal `uint256`. No subscription or redemption executes at that historical number during exposure.

### Refused behavior

- No immediate mint or target payout while mixed inventory remains.
- No live same-pool liquidation quote, spot composition mark, or reference-price rate paired with a separately priced zap.
- No gross-deposit counter presented as redeemable target after that capital has been invested.
- No sale, withdrawal, or auction result that reads transient pool state and mints shares or publishes a rate in that same transaction.
- No guaranteed principal, monotonic rate, bounded settlement delay, or uninterrupted fee earning.

A temporary pool move or temporary liquidity addition therefore cannot change the stored settlement inputs used by a dealing transaction. Actual portfolio execution remains exposed to economic losses and execution quality. The design does not pretend that any fee-earning trading reserve can be economically invariant to every trade.

### Cost and V3/V4 treatment

The price of one honest realized-value rule is delayed liquidity, complete liquidation and redeployment costs each epoch, auction infrastructure, and periods with no active LP exposure. Existing holders share the old portfolio's realization costs even if they did not request redemption. Poor bidding or an unsellable token can stop settlement.

Use the same lifecycle and accounting for V3 and V4. Their position-removal, fee-collection, and settlement adapters differ; those differences do not require different prices or subscription rules. This recommendation does not restore either deleted V4 FullSpread family and does not turn V3 FullSpread into Wings.

### Rejected alternatives

- **Historical target counter with unrestricted dealing:** new entrants can receive unpriced inventory and redeemers can consume cash that does not match the recorded claim.
- **Proportional LP entry and per-holder slice liquidation:** preserves position ownership but produces size-dependent target exit proceeds, not one common executable rate.
- **External-oracle NAV with zap redemption:** provides a mark and an execution outcome, which are the two-price split the brief rejects.
- **Target-only out-of-range liquidity:** avoids holding the other token only while it is not providing active liquidity; participation restores the mixed-inventory problem.

## Limits

Static reading and design reasoning only. No Forge, project tests, Git operations, external research, peer-response reading, or sub-agents were used.

Auction bidding rules, execution protections, permissionless progress, precise rounding, and accounting for settlement costs require a later specification and verification. Time separation removes the proposed same-transaction accounting dependency; it does not by itself prove resistance to multi-block manipulation, bidder collusion, or poor execution.

This recommendation meets the goals only by making dealing asynchronous and the rate historical between settlements. If "suitable for a rate provider" instead requires a continuously executable target price while the reserve remains invested, this design refuses that requirement rather than concealing a second price or an unfunded guarantee.
