# Identity

- Member: Astra, continuing the original assignment.
- Role: advisory reviewer, not coordinator and not an additional council vote.
- Runtime labels observed in this session: `gpt-6-astra`, reasoning `high`; account route not independently established.
- Date: October 26, 2026.
- Original position preserved in `members/astra/response.md`; that file is unchanged.

# Draft under review

- Draft ID: `draft-v4-single-token-fee-vault-20261026-01a177b3-r1`.
- Opened path: `docs/research/v4-single-token-fee-vault-20261026-01a177b3/coordinator/draft.md`.
- Supplied SHA-256: `d1bcd932e72dd88db3f3a4cc5c33b726d57a7838514d1529502a828fd9e92251`.
- SHA-256 calculated over the complete text returned by the read tool: `d1bcd932e72dd88db3f3a4cc5c33b726d57a7838514d1529502a828fd9e92251`.
- The digest matches. This establishes the identity of the text reviewed, not the correctness of its claims.
- Also read: my original response. The brief, locked law and prior report were read during the initial assignment and remain context. I did not read peer feedback or independently verify the draft's descriptions of peer originals.

# Disposition

**requested-changes**

I support pursuing a T-backed fee-right vault with separately funded LP principal, subject to the explicit capital and enforceable-fee-assignment conditions in my original response. I do not support publishing the present equations or presenting the draft's two asserted constraint breaks as my conclusion.

The mint and exit formulas are inconsistent and admit a positive, no-swap round trip. The settled-only credit policy also differs materially from my treatment of accrued fees. Both require a substantive decision, not just an attribution edit. This disposition is advisory, not a veto or implementation authority.

# Concerns

## Mint-only virtual constants recreate an ownership transfer

Locations: "Mint" and "Exit".

The draft mints with `(S + s0)/(A + a0)` but redeems against `A/S`. These are different ownership ratios after the vault earns yield. Calling `s0` and `a0` one-for-one does not make them equivalent when `A/S` changes.

An exact integer example using the draft's definitions is:

```text
Existing supply S = 100
Existing settled target A = 1000
Genesis constants s0 = 1, a0 = 1
Entrant deposits D = 1001

Minted shares = floor(101 * 1001 / 1001) = 101
Post-deposit supply = 201
Post-deposit target = 2001

Immediate exit = floor(101 * 2001 / 201) = 1005
Entrant profit = 4 target
Incumbent backing after exit = 996, previously 1000
```

I evaluated these integers directly in the session. This is an arithmetic counterexample to the written equations, not a production exploit trace. There is no swap, oracle movement, unsettled fee or intervening credit in it.

Ignoring rounding, the entrant gains whenever `A*s0 > S*a0`. The integer example shows that rounding does not universally remove that gain.

My original recommendation used real funded seed assets and real retained seed shares included in `A` and `S`, then `floor(D*S/A)` for mint and `floor(s*A/S)` for exit. Restore that consistent accounting or explicitly select and analyze a different consistent rule. Do not describe a mint-only virtual offset as equivalent to my seed proposal.

## Settled-only credit leaves fee entitlement and harvest timing unresolved

Locations: "Proposed text", "Mint", "Exit", and "Coverage adopted from responses".

My recommendation included accrued, exclusively owed and actually collectible T fees in the pre-mint book, then required collection before changing supply. The draft instead excludes those fees until a later credit and forbids reading the pool during exit. That is a different product.

A separate example, chosen where the draft's virtual constants do not distort the initial mint, illustrates the issue:

```text
Existing S = 100, settled A = 100
Already accrued but not yet credited T fees = 100
s0 = a0 = 1

Entrant deposits 100 and receives 100 shares.
Collector then credits the old 100 T fees.
Backing is now 300 and supply is 200.
Entrant redeems its 100 shares for 150 T.
```

If the old accrued fees belonged to the original holders, the entrant captures 50 T of that entitlement. No same-pool price is needed. This issue remains after correcting the mint-only offset.

If instead fees belong to whoever holds shares at distribution time, this is an explicit distribution-time reward policy with harvest/JIT capture, not preservation of accrued fee ownership. Either policy can be described, but they cannot be attributed interchangeably to Astra.

The final needs to specify who owns accrued fees, how a deposit immediately before collection is treated, and whether collection is mandatory before a supply change or uses a separately specified ownership snapshot. My original choice was mandatory synchronization, including collectible fees in previews. I have not adopted a policy that discards that entitlement merely to keep `getRate` from reading fee accounting.

## The fee right must be mandatory, not a possible source of gifts

Location: "Proposed text".

Saying a separately funded position "can earn" fees and that later T credits are allowed does not establish that this share earns them. Without an enforceable assignment it is an idle T balance that might receive donations.

Name the designated LP portfolio, the assignment of its T-denominated swap-fee receipts, the recipient, and the exclusion of the vault's backing from sponsor liabilities. At research level this can remain a required design condition rather than a deployed fact. It must nevertheless be part of the recommended design.

The sponsor retains principal risk and the other-token fees. Accrued assigned T fees cannot become sponsor principal or disappear through a rebalance/withdrawal path. No sponsor or economically viable assignment has been established in this run; that is an important feasibility limit.

## The two asserted constraint breaks are not my reading of the brief

Locations: "Proposed text", "Preserved disagreements", and coverage rows for fees and `getRate`.

**Earning only the T component is a limitation, not an established violation of the stated fee-exposure requirement.** The brief says holders must earn the pool's swap fees rather than an exit fee. It does not require capturing every fee currency or all LP revenue. The recommendation must disclose partial fee participation, but a mandatory all-currencies requirement should not be introduced without identifying it as an additional interpretation.

**An executable preview with no required sale is not, in my reading, a replacement of the mandated preview by NAV.** My `getRate` is the normalized actual redemption result for one whole share. The sale leg has zero quantity because the share owns no O. It performs no fictitious sale and extrapolates no inventory mark. The arithmetic happens to equal a cash ratio because the underlying entitlement is T.

I preserve this disagreement with the draft's attribution to Grok. If the coordinator adopts the stricter reading that a positive-quantity sale is compulsory, say that this is the selected interpretation and that Astra disagrees. Do not imply I agreed that a zero-sale executable preview necessarily breaks the constraint.

The extra capital requirement is the substantive trade-off I emphasized: depositor T stays reserved while someone else supplies volatile LP principal. If the user requires the same deposited capital to serve as that principal, my proposal fails that stronger requirement. I did not conclude that no new design can meet the brief's literal functional constraints conditional on a valid fee assignment.

## State the exact rate and its same-transaction movement

Locations: "What another hook can hold" and coverage.

The brief explicitly asks whether one transaction can move `getRate`. The draft answers that question for Kimi's proposal but not its own.

A permissionless collection or eligible T credit can increase the settled T rate in the same transaction. Keeping the provider from reading the pool does not prevent a separate state-changing call from collecting pool fees and updating the provider's accounting input. The distinction is between a backed increase and an unbacked mark, not moving versus immovable.

Specify the actual one-whole-share result, not just "settled target per share". For the draft's cash-only exit, with native share unit `u = 10^dS`:

```text
q = floor(u * A / S)
getRate = floor(q * 10^18 / 10^dT)
```

The chosen initialization must make a one-whole-share preview meaningful. Rate failure and zero behavior must match the locked law. If mandatory fee collection is adopted instead, `q` must include the same net collectible T the exit actually delivers; the final must not mix these two definitions.

## Preserve the locked-law distinction and qualify the rejection of a live preview

Locations: "What another hook can hold", the Kimi paragraph, and "Preserved disagreements".

The locked law's raw-balance option does not make every buffered leg optional-rate. A buffered leg where `token != se` requires a provider. An identity leg can be valued as raw shares, but that is not a T valuation. State this distinction rather than presenting raw balance and rated T as interchangeable answers.

Also, a rate changing in one transaction is not sufficient by itself to prove a reserve unusable. The draft's chosen rate can change too. The important concern with the LP proposal is whether a one-share nonlinear liquidation quote safely values the consumer's entire held quantity, and whether trades against remaining vault liquidity transfer value. The prior report did not prove post-sale immunity.

I therefore retain my concerns about Kimi's approach, as represented in this draft, but I do not adopt the categorical inference "live quote can move, therefore not usable". The supported conclusion is that safe composition was not established under the locked linear valuation rule.

## Restore the required three-mechanism comparison and narrow attribution

Locations: conclusions/coverage as a whole.

The final should explicitly map the adopted design to all three prior mechanisms:

- Quote manipulation: no conversion of an O book in the recommended cash-backed accounting; real fee credits can still move the rate.
- Executed-price allocation: absent because no entrant swap price allocates shares; separately disclose the draft's offset inconsistency and harvest timing issue rather than overlooking new ownership transfers.
- Vault self-fill: absent from the cash-share exit, which sells nothing; adverse trading against the sponsor's separate LP remains the sponsor's exposure.

These are conditional design deductions, not an audited safety conclusion.

The draft attributes the Bunni repository warning only to Grok and says those citations remain Grok's observations. My original Sources entry P8 also records opening that repository and reading the warning. Preserve that independent source observation without turning it into corroboration of any unreviewed exploit details.

# What was not adopted from others

The following concerns refer to positions as represented in the coordinator draft. I did not open peer originals or peer feedback for this pass.

- I do not adopt the positive-sale interpretation attributed to Grok, the mint-only virtual constants, or settled-only distribution without a fee-entitlement rule. They are not equivalent to my original recommendation.
- I do not adopt MiniMax's proposed conservative price mark as an established repair. The specific equation was not re-executed here, and the assumed frozen historical reference differs from the supplied description of the current TWAP. This is a gap, not a newly proved counterexample to MiniMax's equation.
- I retain the prior report's price-free acceptance identity associated with Kimi's direction. I do not extend it to post-sale immunity or safe linear valuation of arbitrary held quantities. I also do not adopt the draft's stronger rejection based solely on same-transaction rate movement.
- I have not adopted the THORChain or Bancor descriptions as independently verified source evidence. Those pages were not opened by me.
- I support the coordinator keeping separately funded LP principal as the proposed direction, but agreement on that separation does not establish agreement on fee ownership, mint arithmetic, rate semantics or whether the literal brief is met.

# Limits

This is a review of the identified draft, not a new council, a vote, an implementation plan or a veto. The counterexample is exact arithmetic on its stated equations; it is not a project test, simulation of the Wings lifecycle or claim about deployed behavior.

The public sources cited in my original response were opened during the initial assignment; no new public research was needed to identify these draft concerns. I have not checked coordinator-fetched pages, peer originals, peer feedback, current production code or a deployed consumer in this advisory pass.

Only `members/astra/feedback.md` was authored. My response, the coordinator draft, `RUN.md`, peer files, project code, tests, configuration and Git were left unchanged. These comments grant no implementation authority.
