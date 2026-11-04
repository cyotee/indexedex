# Research response

## Identity

- Member: grok
- Role: council-member. Not the coordinator. Not a vote by itself.
- Run: `v4-v2-lp-wrap-20261026-01a177b3`
- Owned path: `docs/research/v4-v2-lp-wrap-20261026-01a177b3/members/grok/response.md`
- Requested model and reasoning: `xai/grok-4.7:xhigh`
- Exposed identity in this session: Grok 4.7. The reasoning label was not independently verified here.
- Peer responses of this run were not read.

## Question

Does the Uniswap V2 Standard Exchange mint vault shares from LP tokens received, and liquidate a holder's LP portion into one token, in a way that eliminates spot-price share manipulation? If so, can an internal wrapper make a Uniswap V4 position play that LP-token role for the Wings vault?

The user's sentence is the hypothesis. It is not a finding.

## Sources

| Item | Path | Class | Used for |
| --- | --- | --- | --- |
| Council brief | `docs/research/v4-v2-lp-wrap-20261026-01a177b3/brief.md` | source observation | Question, constraints, required contents. The coordinator source note in that file was not used as evidence. |
| V2 share conversion | `lib/crane/contracts/utils/math/BetterMath.sol`, `_convertToShares` and `_convertToAssets` | source observation | Mint and redeem equations |
| V2 common redeem, fee, checkpoint | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol` | source observation | Share-to-LP exit, fee-share mint, reserve checkpoint |
| V2 exact-in routes | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol` | source observation | LP deposit, zap-in, zap-out |
| V2 exact-out routes | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol` | source observation | Exact-out LP deposit, zap-out, and a comment that does not match the executed mint |
| V2 transition quote | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeQuoteTarget.sol` | source observation | Preview of the same split. Not a hook valuation. |
| V2 zap and withdraw-swap | `lib/crane/contracts/protocols/dexes/uniswap/v2/services/UniswapV2Service.sol`, `_swapDeposit` and `_withdrawSwapDirect` | source observation | What the zap trades, and what the exit sells |
| Fee-portion estimate | `lib/crane/contracts/utils/math/ConstProdUtils.sol`, `_calculateFeePortionForPosition` | source observation | Where a reserve ratio enters fee shares |
| V4 principal | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol`, `principal` | source observation | What a Wings position amount is |
| V4 slots and position | `UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol` and `UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol` | source observation | Three slots, PoolManager liquidity, fees separate from principal |
| V4 issue and getRate | `UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol`, `issue`; `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol`, `getRate` | source observation | Current priced mint and current rate. Not redefined. |
| Prior swap-capture report | `docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md` | source observation of that report | The three mechanisms and the closed finding that a deposit swap plus an exit swap is not a fix. Not re-executed. |
| TWAP source note | `docs/research/v4-swap-capture-evidence-20261026-01a177b3/coordinator/twap-source.md` | source observation of that note | Same-pool TWAP is a poke record, not an independent price |
| Held-reserve law | `docs/agent/INDEXEDEX_AGENT_LAW.md`, held-reserve valuation | source observation | A hook does not derive a rate from the Standard Exchange it holds |
| Single-token fee-vault report | `docs/research/v4-single-token-fee-vault-20261026-01a177b3/REPORT.md` | source observation of that report | A different design. Not adopted here. |

No private source was sent to a search or fetch service. No project test was run. No peer file of this run was opened.

## Observations

### LP-to-share conversion

The V2 reserve asset is the Uniswap V2 pair. On an exact-in deposit of that pair token for vault shares, `UniswapV2StandardExchangeInTarget._exchangeIn` loads the live pair balance, pulls the LP, and mints:

```text
shares = floor(lpReceived * (S + 10^d) / (R_before + 1))
```

That is `BetterMath._convertToShares` with floor rounding. `S` is vault share supply after any fee shares minted in the same call. `d` is the stored ERC-4626 decimal offset, not a constant read here. `R_before` on this route is the live pair balance before this pull, or that balance minus `amountIn` when the LP was pretransferred. The new LP is not in the denominator. The `+ 1` is the virtual asset in the converter. It is not a price and it is not the deposit.

`getReserves` is not an input to that equation. A spot move does not change the vault's pair-token balance, and it does not change how many vault shares one received LP token mints against that balance.

The exact-out LP deposit uses the same converter, but its reserve argument is `vault.vaultLpReserve` (`ERC4626Repo._lastTotalAssets()`), not the live balance. It then mints the requested share amount if the conversion covers it, rather than minting the full floored result. Those are two reserve bases. The exact-in route is the one that books a pre-existing LP donation into `R_before`. The zap-in route refuses the call unless the live pair balance already equals the booked reserve, so an unbooked LP donation cannot be absorbed into a zap mint.

`UniswapV2StandardExchangeOutTarget` comments that the exact-in zap computes `floor(lpReceived * (S + 10^d) / (R_before + lpReceived + 1))`. The executed converter does not add `lpReceived` to the denominator. The comment is not the mint equation.

The V2 package has no `getRate`. `quoteAssets` can price a share into one pool token by converting shares to LP and then quoting a withdraw-and-swap. That is a preview. It is not the issuance denominator. Under the held-reserve law, a hook must not use that preview, or `previewExchangeIn`, as the valuation of a Standard Exchange it holds.

### Single-token zap

The zap is a different leg. Exact-in zap-in calls `UniswapV2Service._swapDeposit` on the same pair that is the reserve asset. That function reads the pair reserves, swaps a calculated portion of the input through the pair, adds both tokens, and returns the LP minted. Spot and the execution price enter that LP amount. The following share mint is the LP-to-share equation above, against the pre-zap booked LP reserve, which the call has already required to equal the live balance.

So a spot price does not enter the share conversion. It does enter how many LP tokens the single-token deposit receives. Those LP tokens are what the conversion counts. The prior finding that a deposit swap is not a fix applies to this leg. It does not apply to the conversion that follows.

### Single-token exit

`_redeemLpSharesFrom` burns the holder's vault shares and converts them with:

```text
lpOut = floor(shares * (R + 1) / (S + 10^d))
```

If the requested token is the pair, it pays that LP. If not, it calls `UniswapV2Service._withdrawSwapDirect` on that LP amount only. That function transfers the LP to the pair, burns it, and swaps the other token into the requested token. The exact-in zap-out route does the same split: shares to LP, then `_withdrawSwapDirect` on that LP. The exact-out zap-out first quotes how much LP the desired token amount requires, using pool reserves, converts that LP up into shares, burns those shares, and then withdraw-swaps that quoted LP amount.

What is sold is the other token received from burning the redeemed LP. It is not a live whole-book quote of the vault, and it is not the vault's entire opposing balance. The swap still executes against the pair. If the vault holds a material fraction of that pair, the vault's remaining LP is part of the liquidity that fills the sale.

### Fee shares and the checkpoint

Before the depositor conversion, `_calcAndMintVaultFee` may mint shares to `feeTo`. `_calculateFeePortionForPosition` reads the live reserves. It compares the position's pro-rata claim with a no-fee revaluation `sqrt(initialA * initialB * reserveA / reserveB)` and clamps each side at zero. The resulting token amounts are quoted into an LP equivalent against the last checkpoint, then converted into vault shares against the vault's LP reserve. Those shares increase `S` before the depositor's mint. They are not new LP.

Spot therefore can change share supply on an LP deposit, but only through that fee estimate, and only as dilution toward `feeTo`. It does not set `lpReceived` or `R_before`. This was not executed as a profit trace. It is not the prior quote-manipulation mechanism.

After the operation, `_checkpointVaultReserves` stores `ownedLP * reserve / pairSupply` for each token. That uses reserves. It does not mint shares.

### What a V4 position is

`Inventory.principal` takes a square-root price, a tick range, and a liquidity amount. It clamps the price into the range and returns `amount0` and `amount1` from the Uniswap square-root deltas. `composition` can be token0-only, token1-only, mixed, or empty. `earnedFee` is separate. The library says it never treats fees as converted principal.

The Wings book is not one of those amounts. `Types.Slot` is Core, Upper, and Lower. Harvest reads each slot's liquidity from `PoolManager.getPositionInfo`. A search of the Wings sources found no ERC-6909 or other fungible LP token. The position is liquidity held at the PoolManager, not a balance the vault can transfer the way it transfers a V2 pair token.

`Accounting.issue`, for existing supply, is `floor(supply * credit / value)`. `getRate` is that quote times `1e18` divided by supply, or `1e18` at zero supply. The prior report already recorded that this `getRate` is not a one-whole-share withdrawal-and-sale preview. This response does not redefine it.

### Prior mechanisms

The prior report's closed finding, not re-executed here, is that a deposit swap plus an exit swap does not eliminate quote-rule or executed-price extraction while the mint prices inventory the swap did not trade. The same-pool TWAP note describes a public poke record that can credit an idle gap with the truncated live tick. It is not an independent price and not a frozen pre-trade mean. Nothing in this response uses it as one.

The single-token fee-vault report is a different design: depositor target stays idle, the share does not own the pool position, and an unpaid redemption reverts instead of swapping. It does not make a V4 position into an LP token. It is not the adaptation below.

## Conclusions

Answer: **yes-only-if**.

The hypothesis holds for one leg. It does not hold for the vault as a whole, and it does not hold for the Wings position as that position is computed today.

### What holds

On a direct LP deposit, vault shares are minted from LP tokens received against LP already held. Spot does not enter that equation. On exit, the vault burns shares into that holder's LP portion and, if a pool token is requested, burns that LP and sells only the other token from that burn. It does not pay `floor(shares * liveQuote / supply)`.

That is why a spot move cannot, by itself, change how many vault shares a given LP deposit mints. Each V2 LP token is already an equal claim on the same pair. Counting those tokens does not require a price to combine two inventories.

### What does not hold

The single-token zap uses the pair reserves to decide how much LP the deposit receives. The share conversion then counts that LP. Avoiding spot in the conversion does not avoid spot in the zap. The prior report's reason for rejecting a deposit swap as a fix still applies to this leg.

The single-token exit also uses the pool. The share-to-LP step does not. The sale of the other token does. Calling that sale a liquidation of the holder's LP portion is accurate. Calling it the elimination of spot-price share manipulation is not. The manipulation is no longer in the share count. It is in the trade.

Fee-share minting is a third, narrower opening. It can change supply before the LP conversion by reading the reserve ratio. It was not shown here to mint the depositor extra shares. It is enough to reject the sentence "spot is not used to mint shares" if that sentence is applied to the whole call rather than to the LP-to-share equation.

### Wrapper condition

An internal wrapper can make a V4 position play the V2 LP role only if the object it emits is the same kind of object as that LP token: a fungible claim unit, where each unit is an equal claim on one homogeneous reserve, and the outer mint counts units received against units held.

The Wings position is not that object.

- Liquidity in Core, Upper, and Lower is not interchangeable. The same liquidity amount in two ranges is not the same claim.
- `principal` turns one range's liquidity into token amounts with the current square-root price. Using that mark, or `Quote.quote`, as the wrapper's unit recreates the priced mint. The wrapper would then be a rename of the vulnerability, not a reproduction of the LP leg.
- Idle balances and uncollected fees are not liquidity units. Putting them into the receipt with a price is the priced mint. Putting them in without a price is a per-component join, which the prior report accepted only as an acceptance-time identity, not as post-sale immunity, and which is not the V2 LP pattern.
- A one-sided wing has no other token to sell. The V2 exit's withdraw-and-swap assumes the burn returns both tokens. A one-sided removal does not.

What can play the role is narrower than the Wings book. The wrapper would mint its own receipt when liquidity is added to one chosen range, one receipt per equal liquidity claim, and burn that receipt when that liquidity is removed. The PoolManager position cannot be deposited as an external token the way a V2 pair token can. The receipt has to be created by the add. Ranges must not be mixed inside one unit. Idle, fees, and the other slots stay outside the unit unless they are joined in kind, component by component, and refunded in kind when unmatched.

That condition is a proposal. It is not permission to edit code.

### Adapted equations, if that condition is met

LP-like deposit of the receipt, new units excluded from the denominator:

```text
shares = floor(uReceived * (S + 10^d) / (U_before + 1))
```

`U_before` is receipt units held before this deposit. `d` stays the stored offset. No square-root price. No `Accounting.issue` against a liquidation quote. No same-pool TWAP.

Single-token zap, not the safe leg:

```text
uReceived = receipt minted by adding liquidity after a swap through the pool
shares = floor(uReceived * (S + 10^d) / (U_before + 1))
```

The swap is where spot and execution enter. The second line does not remove them.

Exit of one holder's portion:

```text
uOut = floor(shares * (U + 1) / (S + 10^d))
(amount0, amount1) = remove uOut from that one range
proceeds = swap only the other token from that removal
pay the target amount from the removal plus proceeds
```

Removal uses the current square-root price to decide the token split of that slice. That is composition at removal, the same kind of fact as a V2 burn returning pro-rata reserves. It is not the share count. The swap sells only that slice's other token. It must not pay `entitlement(shares, quote, supply)`, and it must not sell the vault's remaining opposing inventory to fund this redeemer.

If a `getRate` is later added, it is the normalized preview of that one-whole-share removal and sale. It is not NAV. It is not the issuance denominator. Wings `getRate` is the whole-book quote over supply and must not be copied. This response does not define a new rate and does not change the existing one.

A hook that holds the receipt values it as raw balance when the leg token is the receipt, or as balance times an external rate provider when a provider is required. It does not derive that rate from this Standard Exchange. The V2 withdraw-swap preview is not that provider. The same-pool TWAP is not that provider.

### Which of the three mechanisms remain

Quote manipulation, as closed in the prior report: mint `floor(S * D / V)` and pay a live whole-book quote. It does not run on the V2 LP-to-share leg, and it does not run on a wrapper that counts homogeneous receipt units. It remains on current Wings production. It returns if the wrapper prices the position, the idle sleeve, the other wings, or the fees into `V`. The fee-share path is not this mechanism. It is a separate supply change that reads reserves.

Executed-price allocation: it does not enter the LP-to-share equation. It remains on the single-token zap, because the unit count is the output of a swap against live reserves. It remains on the single-token exit, because the other token is sold at the execution price. A deposit swap plus an exit swap is still not a fix. The prior numeric rows were not re-run on this vault.

Vault self-fill: it does not run on a pure receipt deposit or a pure receipt withdrawal, because those do not swap. It remains on the zap and on the exit swap whenever the vault's liquidity is in the pool that fills them. V2 narrows the exit sale to the burned LP's other token. It does not remove the fill. A V4 range the vault owns can be the whole fill, not a pro-rata slice of an external pair. No sign or profit is assigned to that case here.

### What the adaptation does not provide

- An independent price. The only pool reference remains a poke record, and this design does not use it as a mint input.
- Safety of the deposit zap or the exit swap. Those are the operations the prior report refused to treat as a fix.
- A fungible token that the Wings position already is.
- A way to keep Core, Upper, Lower, idle balances, and uncollected fees inside one receipt without either a price or an in-kind per-component join.
- Removal of composition risk. A square-root move changes what one liquidity unit contains, including pushing a range from mixed to one-sided, without changing the share count.
- The fee-vault design. That design does not put the depositor's capital in the pool. This question asks whether the position can play the LP role. Those are different objects.
- A `getRate` that another hook can trust as a target price. Raw balance is the identity-leg valuation. A buffered leg still needs an external provider.
- Implementation authority. The equations above are the accounting this member would require before the safe leg could be claimed. They are not an instruction to implement them.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| V2 LP-to-share mint equation, and whether spot enters it | required | examined | Executed converter and both reserve bases. Spot does not enter the equation. Fee-share mint can change supply before it. |
| V2 single-token deposit, and whether spot enters the zap | required | examined | `_swapDeposit` reads reserves and swaps the pair. The following conversion does not. |
| V2 single-token exit, and what is sold | required | examined | Share-to-LP, then burn of that LP and swap of the other token only. |
| Whether that pattern eliminates the prior manipulation or moves it | required | examined | Quote-denominator manipulation does not run on the LP leg. Executed-price allocation and self-fill remain on the swaps. |
| What a V4 wrapper must emit | required | examined | A homogeneous fungible receipt. The Wings position, as `principal` computes it, is not that receipt. |
| Adapted mint and exit | required | examined as a proposal | Equations above. Not an implementation. |
| Which of the three mechanisms remain | required | examined | Quote manipulation does not run on the unit conversion. The other two remain on the zap and the exit swap. Quote manipulation returns if the wrapper prices the book. |
| What the adaptation does not provide | required | examined | Listed above. |
| Same-pool TWAP as an independent price | required constraint | examined as a prior source note | Not used as a price. Not re-executed. |
| `getRate` as a one-share withdrawal-and-sale preview | required if present | examined | Absent on V2. Present on Wings as a whole-book quote. Not redefined. |
| Single-token fee-vault report | optional | examined as a different design | Not adopted. |
| Production Forge trace of either vault | not authorized | not examined | This assignment forbids project tests. |
| Peer responses of this run | forbidden on this pass | not examined | Independent pass. |

## Uncertainty

- The fee-share estimate reads the live reserve ratio and can mint unbacked vault shares to `feeTo` before the depositor conversion. No trace here shows whether a spot move inflates that mint, or by how much. The LP-to-share conclusion does not depend on that trace. A claim that the whole deposit call is spot-free would.
- Exact-in LP deposit uses the live pre-pull balance. Exact-out LP deposit uses the booked reserve. The difference matters for an unbooked donation. It was not executed. It is not a spot-price path.
- The OutTarget comment includes `lpReceived` in the denominator. The executed converter does not. A reader who implements the comment would be implementing a different rule. This response uses the converter.
- V4 self-fill when the vault owns the whole range was a disagreement in the prior report. This response does not resolve that sign. It only says the fill remains available.
- `decimalOffset` is storage. The equation keeps it symbolic.
- Line numbers are from the tree opened for this response. They can move.

## Limits

- This file is one member response. It is not a coordinator finding and not a vote.
- No project test, install, deploy, or Git action was run. None is authorized by this assignment.
- The prior profit rows are cited as that report's closed finding. They were not re-executed, and they are not evidence that the same integers occur on the V2 vault.
- The adapted equations are a condition for the yes, not an implementation, and not a change to Wings `getRate`.
- A hook still must not derive a rate from the Standard Exchange it holds. Nothing in the V2 pattern supplies a substitute independent price.
