# Kimi member response

## Identity

- Label: kimi
- Role: council-member, initial independent pass. Not the coordinator and not a vote by itself.
- Requested model and reasoning: kimi-coding/k3:high, global route (per the brief roster).
- Owned path written: members/kimi/response.md only. No peer files, no project code, no Git.

## Question

What existing public design, or new design, can IndexedEx adapt so a vault earns the underlying pool's trading fees, can be valued as one token, and can be exited in that one token, when that token may have liquidity only in the underlying pool and that pool's TWAP is the only reference? "Exposed to trading fees" means holders earn the pool's swap fees, not an exit fee.

## Sources

Opened local files:

- docs/research/v4-single-token-fee-vault-20261026-01a177b3/brief.md (this brief).
- docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md (prior full-council evidence; cited as evidence, not as implementation authority).
- docs/research/v4-swap-capture-evidence-20261026-01a177b3/coordinator/twap-source.md (same-pool TWAP is a public-poke record; the truncated live tick is credited across the idle gap; not a frozen reference; nothing forces outside arbitrage to restore the pool).
- docs/agent/INDEXEDEX_AGENT_LAW.md, section "Uniswap V4 SE buffer hooks: held-reserve valuation (APEX D60, LOCKED 2026-09-22)" (a hook values a held reserve as raw balance or held x rate from a configured rate provider; never derives a rate from the Standard Exchange it holds; getRate is WAD whole pair tokens per whole share and fails closed on revert, short return, or zero; a buffered leg must carry a provider).

Opened public pages (fetched this session):

- https://docs.ichi.org/ichi-docs-v3/ichi-vaults/technical-concepts/vault-build - ICHI V3 vaults: single-sided single-token deposit vaults over one Uniswap V3 pool; share issuance prices deposited value against vault TVL using the pool's token ratio at deposit time, defended by a spot-versus-TWAP threshold check that rejects when the pool's latest observation timestamp equals the current block's; rebalancing is owner-only.
- https://docs.ichi.org/home/how-ichi-works - ICHI product page: single-token deposits, no swaps during deposit or rebalance, directional range allocation; yield is pool trading fees.
- https://docs.uniswap.org/contracts/v4/concepts/hooks - Uniswap V4 hook lifecycle: one hook per pool fixed at initialize; before/after swap, liquidity, and donate hooks; return-delta permissions let a hook adjust balances; hook address flags must match implemented functions.
- https://github.com/Bunniapp/bunni-v2 - Bunni v2 repository README: a Uniswap V4 hook tokenizing LP positions with a custom liquidity distribution function; the README states Bunni v2 was exploited and the repo does not have the issues addressed.
- https://www.coinspect.com/learn-evm-attacks/cases/bunni/ - Coinspect case study of the Bunni v2 exploit: $8.4M loss; flashloan-funded swap sequences pushed the same pool's price to extremes to distort the vault's active/idle balance ratio, 44 small withdrawals compounded a rounding error in the idle-balance decrease, and a final two-swap sandwich extracted value at self-created prices.
- https://docs.arrakis.finance/text/arrakisModular/guides/quickstart/introduction.html - Arrakis Pro / Modular: self-custodial vault plus per-DEX module and an optional Uniswap V4 hook, with an offchain manager submitting rebalance and fee instructions; valuation and inventory decisions sit with that manager.

Unverified URLs from the brief's list (not opened; contents not described): https://docs.bunni.xyz/docs/v2/guides/pool-creation (TLS handshake failure on fetch), https://blog.uniswap.org/arrakis-uniswap-protocol-v3, https://olympix.security/blog/arrakis-finances-7-2k-loss-and-how-olympix-would-have-prevented-it, https://github.com/Uniswap/v4-core/blob/main/docs/whitepaper/whitepaper-v4.pdf. No additional web search was performed; no private source was sent to any fetch or search service.

## Observations

1. The prior run closed the swap-as-fix question. Executing a swap during deposit and a swap during exit does not eliminate quote-rule or executed-price extraction while the mint prices inventory the swap did not trade (docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md). Production today has no entrant swap at all: `_deposit` reads the whole-book quote before booking and mints `floor(supply * credit / quote)`; `_redeem` pays `floor(shares * quote / supply)`; `getRate` is the whole-book quote times 1e18 over supply.
2. The only mechanism in the prior run with a demonstrated safety identity is the price-free per-component join: accepted fraction lambda per component (idle target, idle opposing, each range's liquidity), matched to what the entrant contributed, unmatched tokens refunded in kind, minted shares `m = lambda * S`. The acceptance identity `S / (S + m) * (B + C) = B` holds inside its stated domain, and the 288-case proportional control had zero positive target-profit rows where 155 executed-price rows were positive. The identity covers acceptance, not later trading.
3. The same-pool TWAP is not an independent price and not a frozen reference: `update` is public, the truncated live tick is credited across the whole idle gap, and reads can fill an unwritten tail with the current truncated tick (coordinator/twap-source.md). Under the question's premise the pool is the only liquidity venue, so nothing forces an outside arbitrageur to restore price after a push. A TWAP band around issuance adds delay and a cap; it does not close the demonstrated rows.
4. Every public single-token-deposit design I could open prices the mint against the pool. ICHI's share formula is deposited value over vault TVL with both sides computed from the pool's token ratio at deposit time, defended by a spot-versus-TWAP check. That is exactly the pattern the prior evidence shows is extractable under the same-pool premise: the defense compares spot to the same pool's own poke record, which can be held at a manipulated tick when no external venue exists to arbitrage against.
5. The one open public design that makes the LP share itself a token on a V4 hook (Bunni v2) was exploited for $8.4M through same-pool price pushes that distorted its active/idle balance accounting, followed by rounding-compounding withdrawals and a self-created-price sandwich (Coinspect). This is direct evidence that dual-component accounting on same-pool prices is attacked in practice, and that the hazard is not hypothetical.
6. Arrakis Modular is self-custodial with an offchain manager; it does not solve onchain single-token issuance pricing and does not fit IndexedEx's trust model. It is a custody pattern, not an answer to this question.
7. A strictly single-token deposit into a live two-sided LP book cannot be minted price-free without dilution. If the book holds any opposing-token component (in-range principal or accrued fees) and shares are minted as `S * D / A_target`, the entrant receives a pro-rata claim on the unpaid opposing component; incumbents are diluted by exactly that slice. Sweeping opposing balances to target cannot remove this, because an in-range concentrated position continuously holds both tokens. Per-component matching (observation 2) is the only demonstrated non-dilutive rule, and for an entrant who contributes only target it admits lambda = 0 and refunds everything.
8. The locked law accommodates the share: a buffer hook holding the share on a buffered leg values it as held x rate from a configured rate provider implementing `IRateProvider.getRate()`, fails closed, and never derives the rate from the SE itself. So the design needs a compliant getRate, not a new valuation path.

## Conclusions

Recommendation: adapt the prior run's price-free per-component join into the Wings vault as a proportional-join, single-token-exit Standard Exchange, with single-token deposit presented through an unpriced zap at the accounting boundary. This is a new design borrowing two public ideas: ICHI's single-token deposit surface (the holder only ever handles one token) and Bunni v2's hook-native LP share token (the share as a first-class ERC-20 over a V4 pool position). It borrows neither design's pricing: ICHI's pool-priced mint and Bunni's dual-balance price-derived accounting are the components the evidence condemns.

No design I could find or construct meets every constraint, and I name the break up front: at the vault's accounting boundary the deposit must arrive matched in both pool components, so the strictly-single-token deposit as an on-chain accounting act is the constraint this design breaks. Single-token handling is preserved at the user surface (deposit one token, quoted in one token, exit in one token) by a swap step that sits outside issuance accounting. Per the constraint, that swap is not a fix and is not claimed as one: the safety comes from per-component matching with in-kind refund, which is safe with or without the zap. The depositor bears their own zap execution quality and can supply both tokens directly to skip it.

Design elements, against the brief's checklist:

- Fee-exposure path: the vault holds concentrated LP positions in the underlying V4 pool (the existing upper/lower wings shape is compatible) plus idle sleeves. Pool swap fees accrue to the positions in both tokens and are harvested into the book, so holders earn the pool's trading fees pro rata through share redemption value. No exit fee is introduced.
- The single token: target token T. The holder deposits T (zap converts the needed portion to opposing token O outside accounting), is quoted in T via getRate, and receives T on exit.
- Mint equation: price-free per-component join. With book components `A_T` (idle target), `A_O` (idle opposing), and `L_i` (each range's liquidity), the accepted fraction is `lambda = min over components of contributed / book`, matched range by range; minted shares `m = floor(lambda * S)`; unmatched contributed tokens are refunded in kind. This equation uses no price: it is a ratio of amounts within each component, never a conversion between tokens. The prior run's acceptance identity applies: immediately after acceptance, incumbents' claim on the augmented book equals their prior claim.
- Exit execution: the redeemer burns shares and receives the floor of fraction `h = shares / supply` of every component: idle T, idle O, and a proportional slice withdrawn from each position (T + O). To pay in the single token, the vault sells only the redeemer's O slice through the pool (the slice-sale exit the prior report tested), never the whole local opposing balance. If the vault does not already hold enough T, the shortfall is funded by that bounded slice withdrawal-and-sale; the redeemer may alternatively elect in-kind exit (take the O slice) to opt out of the sale entirely. Exit never pays a whole-book quote.
- getRate: a normalized preview of actually redeeming one whole share - withdraw the share's slice of every position and idle balance, sell the O portion through the pool at the live executable price, and return WAD whole T per whole share, failing closed on revert, short return, or zero. It is not a NAV mark and issuance never reads it. Whether one transaction can move it: yes. It reads live pool state, and a same-transaction price push moves the executable sale price it previews. The locked law requires fail-closed semantics and hook-side provider discipline, not immobility; an optional TWAP band could reject previews taken while spot diverges from the poke record, but under observation 3 that band is a cost-raiser, not a guarantee, and I do not rely on it.
- Hook holdability under the locked law: yes. The share is an ordinary SE share token. A buffer hook holding it on a buffered leg carries a rate provider wrapping getRate and values the reserve as held x rate; the hook never derives a rate from the SE. This satisfies the locked held-reserve valuation law unchanged, including `RateProviderRequired` at package init.
- Remaining manipulation, named against the prior report's three mechanisms:
  - Quote manipulation: closed at issuance and at exit payout. Neither the mint nor the redemption computes a whole-book quote; the demonstrated quote rows (including the +60.44 net target quote-paid-exit row and the idle-book row) required a quote-priced mint or payout and do not survive per-component matching with slice exit.
  - Executed-price allocation: closed at acceptance - the 288-case control showed zero positive proportional rows where the executed-price rule produced 155. Residual: the exit slice sale and the depositor's zap trade execute at live pool prices and can be sandwiched. The slice bound caps the vault-side exposure to the redeemer's own fraction, the redeemer can exit in kind instead, and the zap is the depositor's own transaction. I carried the stronger claim in the prior run that this rule eliminates the extraction channel inside a slice-bounded-exit domain; the report carried that as dissent, and I restate it here as my position, not as consensus: the residual is execution quality on bounded, optional sales, not an issuance-pricing channel.
  - Vault self-fill: remains, bounded. When the vault's own LP fills the exit slice sale, the prior run's two machines disagreed on sign (coordinator interval ledger positive, MiniMax's single-range reduction negative at the shares they reported); neither rebuts the other. This design bounds self-fill to the slice but does not eliminate it, and the Bunni case shows same-pool self-created-price extraction is a real attack shape against hook-native LP accounting.
- What the design does not provide: a manipulation-resistant execution price for any same-pool sale (exit slice or zap); any independent valuation source; a pure single-transaction, single-token deposit at the accounting boundary (the named broken constraint); a post-sale guarantee that every holder's token principal is unchanged (the acceptance identity does not cover later trading); or protection from fee-harvest timing games beyond pro-rata accrual.

If the council instead requires a strictly single-token on-chain deposit with no matched-component entry, then the closest remaining candidate is an ICHI-style pool-priced mint defended by the pool's own TWAP band. That candidate breaks the core safety constraint instead: under the same-pool premise its only reference is the manipulable poke record, and the prior evidence plus the Bunni case both show that pattern is extracted in practice. Between breaking the deposit-surface constraint and breaking the solvency constraint, I recommend breaking the deposit-surface constraint.

## Coverage

- Fee-exposure path: covered (LP positions plus harvest, pro-rata to shares).
- Single token for deposit/quote/exit: covered, with the accounting-boundary caveat named.
- Mint equation and whether it uses a price: covered (per-component ratio, no price).
- Exit execution including insufficient-T case: covered (slice withdrawal and bounded slice sale, in-kind alternative).
- getRate definition, one-transaction movability, and non-redefinition: covered.
- Hook holdability under the locked law: covered (rate provider, held x rate, fail closed).
- Remaining manipulation against the prior three mechanisms: covered, one mechanism closed at issuance, one closed at acceptance with bounded residuals, one bounded but open.
- Public designs: ICHI and Bunni pages opened and used; Arrakis opened and set aside as a custody pattern; four brief URLs unverified and undescribed.
- Not covered: no Forge execution, no production trace of the Wings lifecycle, no patch, no implementation. This response is not implementation authority.

## Uncertainty

- The slice-sale versus quote-paid-exit numbers I cite are the prior report's rechecked rows; Kimi's own prior +15068798773.084002 whole-book-mint-versus-slice-exit figure was member-reported and not re-executed there, and I do not rely on the number, only on the mechanism.
- The self-fill sign disagreement between the coordinator interval ledger and MiniMax's single-range reduction is unresolved; I treat self-fill as an open residual rather than claiming closure.
- I did not model fee-harvest timing under the proportional join; a donation-style fee injection between a depositor's zap and their join could still transfer value, and that row was not in the prior run's grid.
- The zap's execution venue and protection are the depositor's problem by design; I have not quantified depositor-level slippage under an adversarial pool state.
- Whether a TWAP-banded getRate preview adds real cost for an attacker under this oracle implementation is unmodeled; the twap-source read suggests it adds delay and a cap but not safety.

## Limits

- Independent initial pass: no peer responses read; no sub-agents launched; no project code, tests, configuration, or Git touched; only the owned response path written.
- Public citations are limited to pages actually fetched this session; unopened URLs are labeled unverified with no content claims.
- No private source was included in any web query or fetch.
- The prior report is cited as evidence and as the definition of the three mechanisms; it is not treated as implementation authority, and neither is this response.
- Line-level and behavioral claims about production come from the prior run's source observations, not a fresh read this session; live source can move.
