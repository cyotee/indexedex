# Research report

## Question

- Run ID: v4-v2-lp-wrap-20261026-01a177b3
- Question: Does the Uniswap V2 Standard Exchange mint vault shares from LP tokens received, and liquidate a holder's LP portion into one token, in a way that eliminates spot-price share manipulation? If so, can an internal wrapper make a Uniswap V4 position play that LP-token role for the Wings vault?
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: explicit council request in this thread
- Authorizing task or role: invoking session
- Admitted read scope: the V2 vault under contracts/protocols/dexes/uniswap/v2, the Wings inventory and accounting files the members opened, the prior swap-capture report, and the held-reserve rule in docs/agent/INDEXEDEX_AGENT_LAW.md
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Coordinator | invoking-agent, not a vote | invoking session | restored label grok-4.7; reasoning not exposed | none | continued | synthesis written | this thread |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | chatgpt-subscription/gpt-6-astra:high, reasoning high | st_01a179e0 | fresh, then continued for feedback | initial and feedback settled | task host |
| grok | council-member | xai/grok-4.7:xhigh | xai/grok-4.7:xhigh, reasoning xhigh | st_01a179e1 | fresh, then continued for feedback | initial and feedback settled | task host |
| minimax | council-member | minimax/MiniMax-M3 | minimax/MiniMax-M3 | st_01a179e2 | fresh, then continued for feedback | initial and feedback settled | task host |
| kimi | council-member | kimi-coding/k3:high | kimi-coding/k3:high, reasoning high | st_01a179e3 | fresh, then continued for feedback | initial and feedback settled | task host |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none

## Conclusions

Answer: **yes-only-if**. The V2 vault does mint shares from LP tokens received, and it does liquidate a holder's LP portion into one token. That does not eliminate spot-price share manipulation for the product. It removes the spot price from one equation. A V4 wrapper reproduces that narrow property only if the unit it emits is a funded, price-free proportional claim on a homogeneous reserve, and the outer share owns only that claim. Naming the current Wings quote an LP token does not.

This is not implementation authority. It does not redefine getRate as NAV. It does not assume an independent price. No project test was run. The equations below are design statements, not measured results.

### What holds in the V2 vault

The reserve asset is the Uniswap V2 pair. On an exact-in deposit of that pair for vault shares, the executed conversion is:

```text
shares = floor(lpReceived * (S + 10^d) / (R_before + 1))
```

That is BetterMath._convertToShares with floor rounding. The coordinator re-read that function. The received LP is not in the denominator. An OutTarget comment that puts lpReceived in the denominator is not the executed mint.

`S` is share supply after any fee shares minted in the same call. On the exact-in LP route, members who opened InTarget report that `R_before` is the live pair balance before the pull, with a pretransferred inbound subtracted. The zap-in route, on those same member reads, uses the booked LP reserve and refuses the call unless the live balance already equals that book. MiniMax checked both sentences in source during advisory review. The coordinator did not re-open InTarget on the synthesis pass. Neither reserve base is a spot price.

Given that LP reserve and that fee-adjusted share supply, a spot move does not by itself change how many vault shares one received LP token mints. Each V2 LP token is already an equal claim on the same pair. Counting those tokens does not require a price to combine two inventories. Holding the LP reserve fixed while the fee checkpoint changes `S` does not keep the conversion constant.

Exit, on the exact-in path, burns shares and assigns LP with the inverse floor conversion, then, if a pool token is requested, burns that LP and sells the other token from that burn. It does not pay a fraction of a live whole-book quote, and it does not sell the vault's entire opposing balance. Narrowing the sale reduces the quantity sold. It attenuates the fill. It does not close it.

Exact-out exit is the reverse sizing. A quote that reads pool reserves chooses how much LP the requested token amount requires. The converter then maps that LP amount up into shares. Spot does not enter the converter. It does enter how much LP, and therefore how many shares, that route demands. "The share-to-LP assignment is not a whole-book quote" must not be read as "no exit route consults reserves before choosing the LP amount."

### What does not hold

The user's sentence does not hold for the vault as a whole.

The single-token zap reads pair reserves, swaps part of the input, adds both tokens, and returns the LP minted. Spot and the execution price enter how many LP tokens the deposit receives. The share conversion then counts that LP. Avoiding spot in the conversion does not avoid spot in the zap. Shares per deposited token can scale with that execution. That quantity effect is not, by itself, the prior report's mismatched-unit issuance defect. In that defect, credit in one unit is booked against a reserve priced in another, so the old book is mispriced at acceptance. Here the minted claim and the reserve are both LP, so the old book is not repriced at acceptance by that conversion. What remains is execution exposure: the entrant's swap can trade against liquidity the vault owns and change what the remaining LP contains. A deposit swap is not a fix. Calling the quantity effect "the prior mechanism relocated" is not adopted.

The single-token exit still sells through the pool. The share count is no longer the priced step. The trade is. A deposit swap plus an exit swap remains not a fix.

Before the depositor conversion, a fee checkpoint may mint shares to feeTo. ConstProdUtils._calculateFeePortionForPosition, re-read by the coordinator, reads the live reserves and builds a no-fee baseline of `sqrt(initialA * initialB * reserveA / reserveB)`, clamped at zero against the pro-rata claim. `S` therefore includes a reserve-dependent quantity. That is enough to reject "spot is not used to mint shares" for the whole call. It is not an established dilution effect, and it was not shown to mint the depositor extra shares. Ideal constant-product arithmetic can move the ratio without creating a positive fee estimate. Rounding and the later LP-equivalent conversion were not traced. MiniMax's residual position is that economic significance was not shown. Kimi and Grok do not join a claim that the path is not a meaningful spot channel. Astra refuses both immunity and a demonstrated excess mint. This report does not decide that split.

### What this does to the prior mechanisms

The prior swap-capture report is cited, not re-executed. Its closed finding remains: a deposit swap plus an exit swap does not eliminate quote-rule or executed-price extraction while the mint prices inventory the swap did not trade. That sentence is one sufficient case, not the whole prior result. The prior report also contains a zero-old-opposing witness: the issuance denominator can be old target, the execution price need not enter that denominator, and extraction can come from accepting a changed mixture and then liquidating a slice on a nonlinear sale. Removing an average-price mark of old opposing inventory does not, by itself, close every executed-price row.

This pattern is a different mint. It is not a rehabilitation of that swap pair.

- Quote manipulation, as `floor(S * D / V)` against a live whole-book quote, does not run on the V2 LP-to-share leg. It remains on current Wings production, where members who opened Accounting.issue report `floor(supply * credit / value)` with value taken from the quote. It returns if a wrapper prices the position, the idle sleeve, the other wings, or the fees into one denominator.
- Executed-price allocation, in the mismatched-unit form, does not run on the LP-to-share equation. It is not closed as an exposure. The zap and the exit sale still execute against the pool. The wrapper's protection, where it exists, is removal of the acceptance-time ownership mismatch by a funded proportional claim. It is not the mere absence of a price mark.
- Vault self-fill does not run on a pure LP deposit or a pure LP withdrawal, because those do not swap. It remains available on the zap and on the exit swap whenever the vault's liquidity is in the pool that fills them. Astra's zero-fee algebra, in which an exit sale changes remaining pair balances while LP counts need not change, is an algebraic limit, not an executed profit witness. No sign is assigned. Acceptance-time proportionality is not post-sale principal preservation.

### What a wrapper must emit

A V4 position is not a V2 LP token. Inventory.principal, as the members read it, evaluates amount0 and amount1 from a supplied square-root price and a liquidity amount. Those amounts can change without the holder changing its liquidity. That does not establish that an initialized pool's live price moves with no pool operation. composition can be one-sided. A target-only wing needs no sale. An opposing-only wing requires selling its entire withdrawn principal. One-sidedness alone does not say which case applies. earnedFee is separate and is not converted principal. The Wings book is Core, Upper, and Lower liquidity at the PoolManager, plus idle balances. There is no external fungible LP token to deposit the way a caller deposits a V2 pair token.

Two shapes can avoid a scalar price mark. They are not the same design. This report does not pick one. Grok required the first and did not adopt the second as the LP-token role. Astra offered the second as a sufficient ownership specification. Kimi accepts the second only under its funding condition. MiniMax treats one unit across a mixed book as a drift into a mark.

1. One homogeneous receipt per `(pool, range)`. Each unit is an equal claim on that one range's liquidity. The outer share owns only that receipt. It has no unaccounted claim on idle balances, old fees, or other ranges. If one outer share owns several receipt classes, accepting one class does not earn a pro-rata claim on the others through the V2 converter. A single denominator that sums liquidity across ranges fails, because equal numerical liquidity in two ranges is not the same claim. Per-range sub-ledgers need a componentwise join. That join is shape 2, not the V2 LP pattern.
2. A componentwise basket. The backing vector is idle balances and liquidity per identified range, with old fees already attributed or held in a separate entitlement. A new unit is minted only for a contribution that funds every backed component in its own units. Unmatched input is refunded in kind. The acceptance identity `U / (U + w) * (B + C) = B` equals the prior report's share form `S / (S + m) * (B + C) = B` only under proportional issuance, where the new-unit fraction and the new-share fraction match. It is an acceptance-time identity. It is not post-sale immunity, and it is not a sum of unlike amounts.

What fails is a wrapper whose unit is principal, Quote.quote, a sum of liquidity across ranges, or the current Wings issue calculation with a new name. If a single target token cannot fund every required component, the wrapper cannot manufacture the missing leg. The same pool may be the only market.

The following are proposals, not observations of the current V2 vault. If the outer vault owns the entire internal wrapper and neither layer has fees or offsets, the outer conversion adds no economic protection beyond correct inner accounting. The receipt does not have to be a transferable token if mint, burn, and backing are enforceable. A non-transferable receipt can avoid a later channel that V2 leaves open, in which a holder withdraws LP and sells it into the pool at a chosen time. A transferable receipt reopens a channel the current Wings position does not have, because that position is not an extractable pair token. Making the receipt transferable is not required by the V2 pattern and is not a safety finding.

### Equations, if a sufficient shape is met

These were not executed.

Receipt deposit of one homogeneous class, new units excluded from the denominator:

```text
shares = floor(uReceived * (S + 10^d) / (U_before + 1))
```

`U_before` counts only that class. No square-root price. No Accounting.issue against a liquidation quote. No same-pool TWAP as a value denominator. The prior TWAP note remains a poke record, not an independent price.

Single-token entry is not the safe leg. A swap through the pool, then an add, can produce a receipt for one range. For the basket, receipt issuance requires funding every backed component, not one range addition. The conversion then counts the receipt. The swap is where spot and execution enter.

Exit, as a proposal:

```text
uOut = floor(shares * (U + 1) / (S + 10^d))
remove that slice of the receipt's backing
realize that slice's fee entitlement in the same settlement, unless fees were already inside the receipt
sell only the non-target token from that removal
pay the target from the removal, the fee realization, and the sale proceeds
```

Removal uses the current square-root price and the tick's place in the range to split that slice into tokens. That is live composition. It is not the same fact as a V2 burn returning the pool's reserve ratio, and it is not the share count. A same-block price move can change how one-sided the redeemed slice is even when the liquidity count is fixed. The sale must not pay entitlement(shares, quote, supply), and it must not sell the vault's remaining opposing inventory to fund this redeemer. If the sale cannot complete, the proposed contract reverts or returns residual in kind. It does not treat unfilled opposing as target, and it does not borrow target from the incumbent sleeve. That failed-sale rule is a proposal, not a property observed in the V2 vault.

If a later design has getRate, it is the normalized preview of that one-whole-share removal and sale. It is not liquidateAll(book) / supply, and it is not an issuance NAV. Current Wings getRate, as members read it, is the whole-book quote over supply. This report does not change it and does not copy it into the wrapper.

A hook values a held reserve as raw balance, or as balance times its configured rate provider. It does not substitute the held Standard Exchange's conversion preview for that valuation rule. This proposal supplies no independent price and makes no new claim about the safety of a configured provider. The separate wrapper constraint, that issuance must not use the same-pool TWAP as its value denominator, is not a broader ban on every same-pool reference inside a configured provider.

### What the adaptation does not provide

- Elimination of spot-price exposure on single-token entry or exit.
- An independent price.
- A fungible token that the Wings position already is.
- One receipt that holds Core, Upper, Lower, idle balances, and uncollected fees without either a price or an in-kind per-component join.
- Fee accrual inside a raw liquidity unit. A fee path that marks uncollected fees at the current price reintroduces a spot-dependent quantity. A fee path that reads reserves, as V2's fee-share mint does, is the untraced qualification above.
- Removal of composition risk.
- A no-profitable-round-trip theorem, or preservation of incumbent token principal after the exit sale.
- The settled-target fee-vault design from the other report. That design does not put the depositor's capital in the pool. This question asks whether the position can play the LP role. Those are different objects.
- Implementation authority.

## Evidence

| Item | Source | Class | Used for |
| --- | --- | --- | --- |
| Share converter | lib/crane/contracts/utils/math/BetterMath.sol, _convertToShares | source observation | Mint and redeem equations. Coordinator re-read. |
| Fee baseline | lib/crane/contracts/utils/math/ConstProdUtils.sol, _calculateFeePortionForPosition | source observation | Reserve ratio enters the fee checkpoint. Coordinator re-read. Not a profit trace. |
| V2 LP deposit, zap, and exit routes | members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md, citing UniswapV2StandardExchangeInTarget.sol, OutTarget.sol, Common.sol, and UniswapV2Service.sol | source observation by members | Two reserve bases, zap, slice sale, exact-out sizing. Coordinator did not re-open InTarget on the synthesis pass. MiniMax checked the zap guard and the exact-in reserve base during review. |
| OutTarget comment versus converter | members/grok/response.md; coordinator re-read of the converter | source observation | Comment is not the mint. |
| V4 principal and current issue | member responses citing Inventory.principal, Accounting.issue, and EconomicTarget.getRate | source observation by members | Position is not an LP token. Current issue is quote-denominated. Coordinator did not re-open those files on the synthesis pass. |
| Prior mechanisms | docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md | source observation of that report | Cited, not re-executed. Includes the zero-old-opposing case as Astra stated it from that report. |
| Held-reserve rule | docs/agent/INDEXEDEX_AGENT_LAW.md, as read by members | source observation by members | Raw balance or configured provider. Not an independent-price mandate. |
| Optional Uniswap v4 page | members/astra/response.md, withdrawn in members/astra/feedback.md | unverified | Dropped. Not used. |
| Advisory reviews | members/*/feedback.md | source observation of those files | Wording carried into this report. Not a second vote. |

No private source was sent to a search or fetch service. No project test was run.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| V2 LP-to-share mint, and whether spot enters it | required | examined | Converter re-read. Spot does not enter the equation. Fee-adjusted supply is a qualification. |
| V2 single-token deposit | required | examined | Member reads of the zap. Spot enters the LP quantity. |
| V2 single-token exit | required | examined | Exact-in assigns LP then sells. Exact-out sizes LP from reserves first. |
| Whether the pattern eliminates the prior manipulation | required | examined | Quote-denominator mint does not run on the LP leg. Exposure on the zap and the exit sale remains. Prior rows not re-run. |
| What a V4 wrapper must emit | required | examined as a proposal | Two shapes. Neither selected. Scalar mark rejected. |
| Adapted mint and exit | required | examined as a proposal | Equations above. Not executed. |
| Prior three mechanisms | required | examined against the prior report | Self-fill sign not resolved. |
| getRate | required if present | examined | Absent on V2. Present on Wings as a whole-book quote. Not redefined. |
| Independent price | required constraint | examined | Not assumed. Not used as a mint input. |
| Production Forge trace | not authorized | not examined | This assignment forbids project tests. |

## Disagreement and missing responses

- Disagreement: fee-share economic significance is unsettled among the four. The basket is a sufficient price-free join for Astra, and is not Grok's adoption of the LP-token role. The label "prior mechanism relocated into the zap" is MiniMax's and is not adopted. Self-fill sign and post-sale principal preservation are unproved.
- Dissent carried into this report: those four points, in the conclusions above.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-v4-v2-lp-wrap-20261026-01a177b3-r1
- Draft path: docs/research/v4-v2-lp-wrap-20261026-01a177b3/coordinator/draft.md
- Resolution path: docs/research/v4-v2-lp-wrap-20261026-01a177b3/coordinator/resolution.md
- Feedback dispositions: astra requested-changes; grok, minimax, and kimi support-with-reservations
- Post-review wording changes: the conclusions above scope the per-range receipt, keep the fee path untraced, carry the exact-out sizing split, correct the hook-law and composition sentences, add fee realization as a proposal, and drop the optional public page
- Those changes are member-approved: no

## Recommendations

- Do not implement this report. A later design, if one is authorized, has to choose one shape and state what the outer share owns. This report does not make that choice.
- Do not treat a deposit swap plus an exit swap as the fix. The prior report already refused that, and this pattern does not reverse it.
- Do not copy Wings getRate into a wrapper, and do not use a wrapper preview as a hook's valuation of the vault it holds.
- A trace of the fee-share checkpoint under a moved reserve, and a trace of exact-out LP sizing, would be new research. They are not authorized by this report.

## Limitations

- No project test, Forge trace, or profit measurement was run.
- The coordinator's own re-read on the synthesis pass was BetterMath._convertToShares and ConstProdUtils._calculateFeePortionForPosition. Other locators are member observations.
- Live files can move. This is not an atomic repository snapshot.
- The prior report's numeric rows were not re-run on the V2 vault or on a wrapper.
- Agreement on yes-only-if is not proof that every sentence in the member responses is correct.
- Inherited permissions are not confinement evidence.

## Publication

- Publication state: published
- Final path or chat-only statement: docs/research/v4-v2-lp-wrap-20261026-01a177b3/REPORT.md
- Cooperative update: none
- Unrelated edits preserved: yes
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes
