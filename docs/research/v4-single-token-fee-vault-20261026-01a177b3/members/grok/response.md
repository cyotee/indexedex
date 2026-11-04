# Member response

## Identity

- Run ID: v4-single-token-fee-vault-20261026-01a177b3
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/v4-single-token-fee-vault-20261026-01a177b3/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role: council-member
- Actual model and reasoning: PI_MODEL=grok-4.7, PI_REASONING_LEVEL=xhigh. The provider prefix in the requested route was not exposed.
- Task ID: not exposed
- Session ID: PI_SESSION_ID=01a178e8-a0af-7704-a1d6-8aea78e63dfa
- Fresh or continued: fresh
- Peers read before submission: no

This self-description is not proof of the runtime beyond the exposed process values above.

## Question

- Question: What existing public design, or new design, can IndexedEx adapt so a vault earns the underlying pool's trading fees, can be valued as one token, and can be exited in that one token, when that token may have liquidity only in the underlying pool and that pool's TWAP is the only reference?
- Required targets: one design, adapted to IndexedEx, that earns the pool's swap fees, is valued as one token, and exits in that token, under the same-pool pricing premise. The answer must name the fee path, the single token, the mint equation and whether it uses a price, the exit including a short idle balance, what getRate returns and whether one transaction can move it, whether another hook can hold the share under the locked valuation law, which of the prior three mechanisms remain, and what the design does not provide.
- Reading used: "use this liquidity" means the share is holdable by another IndexedEx consumer and valued through a rate provider, and a holder can leave in one token. It does not mean an exit fee. This response does not reject that reading.
- Optional context: the prior swap-capture report, the locked buffer-hook valuation law, and the current wings vault source. The wings source was not opened this pass.
- Admitted read scope: the brief, the prior report, the TWAP note it cites, the locked-law section, and public pages opened below. No other private tree was read.

## Sources

Public queries, generalized. No private source excerpt was sent.

- Query: `THORChain savers single sided deposit earn swap fees withdraw same asset accounting`. Domains limited to docs.thorchain.org, dev.thorchain.org, and thorchain.org. The search result was a synthesized summary and is not a source. The page below was opened after that.
- Query: `Bancor V3 single sided staking bnToken trading fees withdrawal same token documentation`. Domains limited to docs.bancor.network, blog.bancor.network, and bancor.network. Synthesized summary, not a source. The two Bancor pages below were opened after that.
- Query: `Uniswap v4 hook fee versus LP swap fee custom accounting documentation`. No domain limit. Synthesized summary, not a source. The fee and custom-accounting pages below were opened after that.

| Item | Source | Class | What was used |
| --- | --- | --- | --- |
| Council brief | docs/research/v4-single-token-fee-vault-20261026-01a177b3/brief.md | source observation | Question, constraints, required answer contents, and the production summary it attributes to the prior run |
| Prior swap-capture report | docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md | source observation of that artifact | The three mechanisms, the conclusion that deposit and exit swaps do not close them, and the price-free per-component acceptance identity. Its ledgers were not re-executed here. |
| Same-pool TWAP note | docs/research/v4-swap-capture-evidence-20261026-01a177b3/coordinator/twap-source.md | source observation of that note | Public `update`, idle-gap credit with the truncated live tick, not a frozen historical mean |
| Locked valuation law | docs/agent/INDEXEDEX_AGENT_LAW.md, section "Uniswap V4 SE buffer hooks: held-reserve valuation" | source observation | Raw balance or held times rate; no rate derived from the held Standard Exchange; getRate unit and fail-closed reads; D59 raw-balance issuance |
| ICHI vault build | https://docs.ichi.org/ichi-docs-v3/ichi-vaults/technical-concepts/vault-build | source observation of fetched markdown | Single-pool vault, owner rebalance, spot-versus-TWAP gate, share value from token amounts and the pool ratio |
| ICHI product page | https://docs.ichi.org/home/how-ichi-works | source observation of fetched markdown | Single-token deposit claim, and a conflicting rebalance claim |
| Arrakis Pro introduction | https://docs.arrakis.finance/text/arrakisModular/guides/quickstart/introduction.html | source observation of fetched markdown | Issuer-owned vault NFT, offchain strategy, optional v4 hook, external price convergence |
| Arrakis on Uniswap v3 | https://blog.uniswap.org/arrakis-uniswap-protocol-v3 | source observation of fetched markdown | Arrakis v2 described as fungible ERC-20 vaults over concentrated positions. No mint equation on that page. |
| Arrakis G-UNI incident | https://olympix.security/blog/arrakis-finances-7-2k-loss-and-how-olympix-would-have-prevented-it | source observation of fetched markdown | Legacy G-UNI mint and burn priced from live pool state |
| Bunni v2 repository | https://github.com/Bunniapp/bunni-v2 | source observation of fetched markdown | Shapeshifting liquidity; repository says the code was exploited and should not be used as-is |
| Bunni post-mortem | https://blog.bunni.xyz/posts/exploit-post-mortem/ | source observation of fetched markdown | Idle-balance share reduction and a price-dependent liquidity estimate |
| Bunni incident writeup | https://www.coinspect.com/learn-evm-attacks/cases/bunni/ | source observation of fetched markdown | Same withdraw rounding shape and a token0/token1 liquidity-estimate switch. Used as a second account, not as a substitute for the post-mortem. |
| Uniswap v4 hooks | https://docs.uniswap.org/contracts/v4/concepts/hooks | source observation of fetched markdown | Optional per-pool hook, fixed in the pool key, including swap and donate callbacks |
| Uniswap fees | https://docs.uniswap.org/contracts/v4/concepts/fee-structure and https://developers.uniswap.org/docs/get-started/concepts/fees | source observation of fetched markdown | These two URLs returned the same fees page. LP swap fee, protocol fee, dynamic LP fee, and hook fee are distinct. Only in-range liquidity accrues the LP swap fee. v3/v4 LP fees are claimable balances, not an automatic reserve increase. |
| Uniswap custom accounting | https://docs.uniswap.org/contracts/v4/guides/custom-accounting | source observation of fetched markdown | Hook fees are implemented by the hook, separate from pool fees, and can be taken in a currency the hook selects |
| THORChain Savers | https://docs.thorchain.org/thornodes/archived/savers | source observation of fetched markdown | Deprecated single-sided saver units over an asset-quantity vault balance; exit still swaps |
| Bancor single-side FAQ | https://docs.bancor.network/about-bancor-network/faqs/single-side-liquidity | source observation of fetched markdown | Deposit one token and collect LP fees in that token. No equation on the page. |
| Bancor adding liquidity | https://docs.bancor.network/developer-guides/write-functions/adding-liquidity | source observation of fetched markdown | Single-sided deposit; deficit can block a full withdrawal. The linked deficit post was not opened. |

Unverified, not used for contents:

- https://docs.bunni.xyz/docs/v2/guides/pool-creation failed the TLS handshake on two fetches.
- https://github.com/Uniswap/v4-core/blob/main/docs/whitepaper/whitepaper-v4.pdf returned a GitHub file shell. The PDF text was not extracted.
- https://blog.bancor.network/market-conditions-update-june-19-2022-e5b857b39336 is linked from the Bancor adding-liquidity page and was not opened.
- ICHI share-formula images on the vault-build page were not extracted as text. No algebraic ICHI formula is stated below.
- THORChain Medium and video links on the Savers page were not opened.

## Observations

### What the constraints already fix

The prior report's direct answer is that a swap on deposit plus a swap on exit does not eliminate quote-rule extraction or executed-price extraction in the domains it rechecked. One rechecked row has no old opposing inventory and still extracts target. The report's cause for that row is issuance against a book that excludes the new credit, followed by unwinding a smaller slice through a nonlinear pool. Marking inventory the swap did not trade explains some rows and not that one.

The same report accepts a price-free per-component join at acceptance: each component is matched to what the entrant contributed, and unmatched tokens are refunded in kind. That identity is not a post-sale guarantee. It is also not a single-token exit. This pass did not re-execute those ledgers.

The TWAP note says `update` is public, and that after the first observation the truncated live tick is applied across the idle gap. A later read can fill an unwritten tail with the current truncated tick. The note says this is not a frozen pre-trade reference and does not make the deposit-swap or exit-swap ledger safe.

The locked law says a reserve-holding buffer hook values a held reserve as its raw balance, or as held times rate when a rate provider is configured. It never derives a rate from the Standard Exchange it holds. `getRate` is WAD whole pair tokens per whole share. A revert, a short return, or zero fails closed. A buffered leg must carry a provider. An identity leg values the raw balance. Liquidity issuance and proportional exits of that hook use raw balances of the concrete reserve. The rated reserve is what the virtual swap invariant uses.

The brief's production summary, which this pass did not re-read from source, says the current wings deposit quotes before booking and mints `floor(supply * credit / quote)`, the redeem pays `floor(shares * quote / supply)`, and `getRate` is that whole-book quote times `1e18` over supply. There is no entrant swap. That summary is not this pass's evidence of current line text.

### Public designs that were opened

ICHI's vault-build page describes one vault for one Uniswap v3 pool and an immutable strategy that defaults to single-sided deployment. Rebalancing is owner-only. Fees above a base fee reach liquidity providers through their interest in total assets. The share rule on that page uses deposited value and vault TVL, both calculated from the two token amounts and the pool's token ratio. The page also says the implementation takes the lesser value for the deposit and the larger value for the pool. Its manipulation gate compares spot with a TWAP, usually one hour, and rejects a transaction when the gap exceeds an owner-set threshold and the pool's latest observation timestamp is the current block. The formula figures are images. Their algebra was not read.

ICHI's product page says a user deposits one token, receives an LP token, and that the protocol deploys that deposit directionally so deposit and rebalance do not swap. It also says automation has no privileged rebalance function, and that withdrawal returns the corresponding assets. That page and the vault-build page disagree on whether rebalance is privileged. This pass does not resolve the disagreement. Neither page states a one-token exit that avoids the pool ratio.

Arrakis Pro, on the page opened, is an issuer-owned vault NFT. Arrakis runs an offchain strategy. An optional v4 hook is described for dynamic fees and for price convergence against an external reference. That is not a fungible depositor share, and the external reference is an independent price. The Uniswap blog page says Arrakis v2 vaults are fungible ERC-20 wrappers over concentrated positions. It does not give a mint equation or a one-token exit.

The Olympix page describes a legacy Arrakis G-UNI vault whose mint and burn both read live pool state through `getUnderlyingBalances()`. The page says that function reads slot0. A same-transaction swap, mint, partial swap, and burn returned more than the deposit. The page says a time-weighted check existed on manager rebalance and not on mint or burn. It suggests a time-weighted check, a mint snapshot, or a same-transaction mint-and-burn lock. Those are the article's suggestions. They are not evidence that those guards survive the admitted TWAP note or the prior report's ledgers.

Bunni's repository page says Bunni v2 is a v4 hook with shapeshifting liquidity, that it was exploited, and that the repository should not be used in production as-is. The Bunni post-mortem shows `withdraw` reducing idle balance by `balance.mulDiv(shares, currentTotalSupply)`, and a total-liquidity estimate that picks the smaller of a token0 estimate and a token1 estimate. The Coinspect page describes the same withdraw line and the same estimate switch. Neither page describes a one-token exit. The pool-creation guide was not opened.

The Uniswap fees page says a swap fee accrues to in-range liquidity and, in v3 and v4, accumulates as a claimable balance rather than inside the reserves. Out-of-range liquidity does not accrue that fee. The same page says hook fees are custom fees inside the hook, separate from the swap fee and the protocol fee. The custom-accounting page says a hook fee can be taken in a currency the hook selects, and lists withdrawal penalties as a possible use. A hook fee taken in one token is still not the pool's LP swap fee. Donate callbacks exist on the hooks page. A donation is not the swap fee.

The THORChain Savers page, preserved for a feature it says was deprecated on 4 January 2025, describes the closest opened product shape. The user minted a synthetic with 1:1 purchase rights on the L1 asset, locked it, and received saver units that tracked ownership of the vault balance. Yield was paid into that vault. The page gives `saversYield = LPYield * (MaxSynthsForSaversYield - SynthsPerPool) * SynthYieldBasisPoints / 10000`, with the two parameters stated as 60% and 80%. It says that on each L1 swap, fees and rewards were divided using those basis points and the saver depth versus pool depth, in asset quantity, and paid into the vault. Withdrawal claimed a synth quantity and then swapped that synth to the L1 asset. Enter and exit charged a demand-responsive liquidity fee, which the page says prevented economic attacks. The page does not show that proof. Savers were not the dual-sided LP. They earned a portion of yield; the LP kept the rest. The exit swap and the enter/exit fee are part of that design.

The Bancor FAQ page says a depositor provides only the token they hold and collects LP fees in that token. The adding-liquidity page repeats that one asset is enough to provide liquidity and earn yield, and warns that a pool in deficit might affect withdrawal of the full deposit. Neither page states a mint equation, a fee-credit equation, or how the other token is kept out of the claim. The deficit explanation was not opened. Bancor is a product analogue, not a source for an equation.

### What no opened design does

No opened page shows a vault that pays holders both tokens of the pool's LP swap fee, values the claim as one token, exits in that token, and does so without a price and without a sale. ICHI prices both tokens with the pool ratio. G-UNI prices mint and burn from live pool state. Arrakis Pro, on the page opened, is not a depositor share and names an external reference. Bunni accounts a two-token book and was exploited. Savers keep an asset-quantity balance, then swap on the way out. Bancor's opened pages claim one-token fees and do not show the accounting. Uniswap's own fee page separates a selectable hook fee from the LP swap fee, and limits that LP fee to in-range liquidity, which holds both tokens while it earns.

## Conclusions

No design meets every constraint. The closest admissible design is a new one: a settled-target claim. It is not an average of the opened products. It borrows two ideas and refuses the rest. From the THORChain Savers page, it borrows an asset-quantity vault balance and units that track that balance, with swap-fee tokens paid into the balance in kind. It does not borrow the synthetic, the utilization scalar, the enter or exit liquidity fee, or the synth-to-L1 withdrawal swap. From the prior report, it borrows the price-free match, restricted to the target component, so the mint does not price inventory. It does not borrow ICHI's pool-ratio share value or its spot-versus-TWAP gate. It does not borrow a hook fee.

This is a proposal. It is not implementation authority. The prior report is not implementation authority either.

The constraint it breaks is complete holder exposure to the pool's swap fees. In-range liquidity accrues the LP swap fee, and that fee is claimable in the tokens the swaps paid. Only fees collected in the exit token enter the share. Fees collected in the other token stay outside the share. Putting them into the exit token requires a sale or a price. This design uses neither. A second miss, not renamed away: `getRate` previews the exit this design actually performs, and that exit does not sell, so `getRate` is not a withdrawal-and-sale preview.

### Fee-exposure path

The share does not become in-range liquidity. Shareholder target stays idle. A separate position in the underlying pool, funded by capital that is not this share, can accrue the pool's LP swap fee while it is in range. When that position collects fees, the exit-token amount actually received is credited to the settled-target balance. The other token's collected fees are not credited, not marked, and not sold. No hook fee is charged, and no exit fee is charged. If the separate position does not exist, the credit is zero. This design does not create that position by swapping shareholder target.

A single-sided range funded by shareholder target is not the fee path. The fees page says that range earns the LP fee only once it is in range, and an in-range position holds both tokens. Crediting the resulting other token would require the sale or the price this design refuses. Leaving that conversion in a non-share bucket would charge shareholders the target loss and give them none of the other token. That is not adopted.

### Single token

The single token is the target token: the token deposited, the token the share is quoted in, and the token paid on exit. It is the token that may have no other pool. The other pool token is not a depositor asset, not a quote input, and not an exit asset.

### Mint equation

The mint does not use a price, a quote, a TWAP, or `getRate`.

Let `S` be share supply, `A` be settled target, and `D` be target tokens actually received by the deposit call. Let `s0` and `a0` be nonzero constants in share units and target units, with `s0` corresponding to `a0` one-for-one at genesis. Settled target increases by `D` only inside the deposit call. A bare transfer does not increase it.

`sharesMinted = floor((S + s0) * D / (A + a0))`

At genesis, `S = 0` and `A = 0`, so the first deposit mints shares one-for-one with target, up to rounding. After that, the deposit buys shares of settled target only. The virtual constants are there so a tiny deposit cannot round to zero shares. They are not a price.

Issuance accounting is this equation. It is not `getRate`, and it is not a NAV mark of unsold inventory.

### Exit execution

Burn the shares and pay `floor(shares * A / S)` in target from idle settled target. Decrease settled target by the amount paid. Do not read the pool. Do not remove liquidity. Do not swap. Do not pay the other token.

If idle target is below that payout, the exit reverts. The shortfall is not closed inside the exit. A later transaction may return target to the idle balance only if that return is itself target tokens already held, such as collected target fees. A liquidity removal that would receive the other token is refused. It is not converted.

Because shareholder target is not deployed, the idle balance and settled target are the same balance unless credited fees have not yet arrived or paid target has not yet left. Either divergence reverts the exit. It does not start a swap.

### getRate

`getRate` returns the WAD target-token amount paid for one whole share on the actual exit, `A * 1e18 / S`, and it reverts when supply is zero or idle target cannot pay that amount.

A caller can move it inside one transaction by crediting collected target fees before the read, or by a deposit or withdrawal whose rounding changes `A / S`. A caller cannot move it by changing the pool tick, the spot price, or the TWAP, because `getRate` does not read them. The fee credit moves it by the target tokens collected, not by a mark of the other token.

This is not a withdrawal-and-sale preview. There is no sale in the exit. A preview that simulated a sale of the other token would read the only pool, would be movable by a same-transaction trade, and would be the quote path the prior report did not accept as a fix. This design does not substitute that preview and call it `getRate`.

### Another hook holding the share

Yes, while `getRate` returns a non-zero WAD amount. A buffer hook can hold the share as a reserve. If the leg is buffered, the locked law requires a rate provider, and that provider is this `getRate`. The hook values the reserve as held times that rate. It must not derive a rate from this vault. If `getRate` reverts, returns short, or returns zero, the locked law fails closed, and the share cannot be valued on that read.

An identity leg can hold the share without a provider and value the raw balance. That values the share as itself, not as target. It meets the locked law and does not meet the rate-provider reading of the question.

The hook's own liquidity issuance and proportional exits still use the raw share balance, as the locked law states for the concrete reserve. The rate applies to the hook's swap invariant, not to a second quote of this vault's book.

### The prior three mechanisms

Quote manipulation does not remain on mint, exit, or `getRate`. None of them reads a whole-book liquidation quote. The current wings formula in the brief's summary is the formula this proposal replaces. That replacement was not executed.

Executed-price allocation does not remain on deposit or exit. The deposit does not swap, the exit does not unwind a slice, and the issuance denominator is settled target in the same unit as the deposit. The prior zero-opposing row required a deposit swap and a later unwind. This is an inference from the report's stated cause. The row was not re-executed. The mechanism returns if a later change sells the other token and credits the proceeds, or issues shares against a book that excludes the new credit. This design does not include that change.

Vault self-fill does not remain on exit, because the exit does not sell. It remains as the ordinary fact that external swaps fill the separate fee-earning position. That fill is how the LP fee is earned. It is not an input to the mint, the exit, or `getRate`. The prior self-fill extraction was an exit sale filled by the vault's own liquidity. There is no exit sale here.

### What the design does not provide

- It does not pay holders the other token's swap fees, or a price-marked equivalent.
- It does not earn fees from shareholder target alone. Without a non-share position that already contains both tokens, the fee credit is zero.
- It does not solve where that other-token principal comes from. The prior report left opposing-capital availability as a separate question. This pass does too.
- It does not protect the fee-earning position from inventory loss. That loss stays with the capital that is in range.
- It does not make `getRate` a sale preview.
- It does not use the same-pool TWAP, and it does not assume another price.
- It does not keep a holding hook's rate available when `getRate` reverts.
- It does not prove the prior ledgers stay closed. That mapping was not re-executed.
- It does not authorize an edit, a test, or a deployment.

Deposit and exit swaps are not proposed as a repair. A design that sells on exit could pay both fee tokens in one token, and its `getRate` could preview that sale. The prior report already tested that shape and did not accept it as closing quote manipulation or executed-price allocation. Under the only-pool premise, the seller may also be the only liquidity, so the sale has no counterparty that is not the vault. That alternative is the one this recommendation refuses.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| One recommended design | required | examined | Settled-target claim, in Conclusions. It does not meet every constraint. The broken constraint is named there. |
| Fee-exposure path | required | examined | Target-denominated collected LP fees only. Other-token fees excluded. |
| Single exit token | required | examined | Target in, target quoted, target out. |
| Mint equation and price use | required | examined | Price-free settled-target mint with a constant virtual offset. |
| Exit, including a short balance | required | examined | Pay settled target or revert. No swap. |
| getRate and same-transaction movement | required | examined | Actual no-sale exit preview. Sale-preview requirement missed and stated. |
| Hook holdability under the locked law | required | examined | Holdable at the rate while getRate succeeds; fail-closed when it does not. Identity leg is raw balance only. |
| Prior three mechanisms | required | examined | Mapped from the admitted report. Not re-executed. |
| What the design does not provide | required | examined | Listed in Conclusions. |
| Prior swap-capture report | required by the brief | examined | Read. Ledgers not rerun. |
| Locked valuation law | required by the brief | examined | Section read. |
| Same-pool TWAP note | required by the brief's constraint | examined | Note read. |
| ICHI, Arrakis, Bunni, Uniswap fee docs, Savers, Bancor FAQ and adding-liquidity | required before citing a public design | examined | Pages opened. Equations taken only where the page stated them. |
| Bunni pool-creation guide | optional starting point | not examined | TLS handshake failed twice. Unverified. |
| Uniswap v4 whitepaper PDF | optional starting point | not examined | GitHub page did not yield PDF text. Unverified. |
| Current wings vault source | optional | not examined | Production behavior is taken only from the brief and the prior report. Those files were not re-checked against source this pass. |
| Bancor deficit post | optional link from an opened page | not examined | Not opened. Deficit math is not used. |

## Uncertainty

- The mapping from the prior report's causes onto this design is inference. The ledgers were not re-run against a settled-target mint. A row whose cause was not the one named in that report could still exist. No such row was identified in the report's stated causes.
- ICHI's two opened pages conflict on privileged rebalance. Either page could be stale. The conflict does not change the recommendation, because the vault-build page still prices shares from the pool ratio.
- Bancor's opened pages do not show how one-token fee accounting is maintained. A later page could show a price or a sale. That would not make Bancor admissible here, and this response does not treat the unopened page as evidence.
- The Savers page says enter and exit liquidity fees prevented economic attacks. It does not show the argument. Combined with the prior report, that sentence is not accepted as evidence under this premise.
- Whether any non-share inventory already exists to fund the fee-earning position is not in the admitted sources. If it does not, this design earns no fees.
- Live law and vault source can move. The law text is from the file read this pass. The wings summary is not.
- `getRate` as a required sale preview is the brief's wording. This response treats a no-sale exit as unable to satisfy that wording. A coordinator could judge the preview clause satisfied because the actual exit pays target. That would be their reading. It is not slipped in here as a redefinition.

No calibrated probability is claimed.

## Limits

- Runtime or extraction proof: none. No ledger was re-executed. No page was treated as a rendered-browser capture. The whitepaper PDF was not extracted. ICHI formula images were not read as text.
- Not examined: wings source, the Bunni pool-creation guide, the v4 whitepaper text, the Bancor deficit post, and peer responses.
- Assignment boundary: this response does not authorize implementation, tests, installs, deployment, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement. Isolation was not claimed.
- Peers were not read. Nothing here is council consensus.
