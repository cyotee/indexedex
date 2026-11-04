# PRD — APEX-2026-012 apportioned reserve

- **Status:** DRAFT. Design agreed 2026-10-23. Open questions recorded 2026-10-24 in `docs/security/audit/second_review/APEX-2026-012-OPEN-QUESTIONS.md`. Implementation is not authorized by this document.
- **Date:** 2026-10-23
- **ID:** APEX-2026-012
- **Review target:** Both Upper Lower Wings Standard Exchange families: Uniswap V3 and Uniswap V4. Deposit, redeem, and `getRate` must not use a live whole-book liquidation quote. One family passing does not close the other.
- **Source:** `IndexedEx_DiffReview_aca16198-2ba07631.md` names the defect on V4. Current V4 rate is `Quote.quote(...).value / supply` in `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.getRate`. `UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote` prices the book by removing owned liquidity and simulating a sale through remaining external liquidity. That view counts temporary liquidity and in-transaction price moves. Owner ruling 2026-10-23 extends the same accounting to the V3 Upper Lower Wings family.
- **V3 source:** No Uniswap V3 Upper Lower Wings vault exists in this repository. The V3 tree is FullSpread. Owner ruling 2026-10-23: this PRD requires a new V3 Upper Lower Wings family with the same accounting. Do not convert V3 FullSpread into that family, and do not delete it.
- **Deployed vaults:** Existing Wings deployments are immutable. This PRD changes source for new deployments of each family. It does not upgrade, enable, or repair a deployed vault. Deployed 012 exposure stays a containment problem.

## Required outcome

On both the V3 and V4 Upper Lower Wings vaults, a share is a fraction of the position, not a quoted pile of target. The vault still accepts and pays only the target token. The market may make the position two-sided. Entry and exit convert through a real swap in the same pool. `getRate` does not preview that swap and does not read the current tick.

## Owner ruling

- The accounting, entry, exit, and rate rules below apply independently to the Uniswap V3 Upper Lower Wings vault and the Uniswap V4 Upper Lower Wings vault.
- Do not price deposit, redeem, or `getRate` from `LiquidationQuote.quote` or any other view that sells the book through current depth. On V3 that ban includes `slot0` and a simulated swap through the current book.
- Do not replace that quote with a split: a reference price for the rate and a zap-out for redemption.
- Do not hold only a single-sided target position and call that the quote. A single-sided range earns nothing until price enters it, and then it holds the other token.
- The remaining position taking the other side of an exit sale is intended. It is the same trade any other swapper imposes. It is not a defect.
- Other token is sold for target only inside the acting holder's own entry or exit. Harvest credits target fees the vault actually collected. Harvest does not sell the other token, and it does not set the rate from the current tick.
- Build a new Uniswap V3 Upper Lower Wings family to this accounting. Leave V3 FullSpread in place.
- A share is a fraction of every position the vault holds, core and both wings. A deposit adds liquidity in proportion to those existing positions. It does not open a new range. Rebalance is out of scope.
- Writing this PRD does not authorize implementation, a launch-script change, or a mainnet transaction.

## Accounting

The position has two actual token amounts, target and other. Those amounts are the tokens the vault's liquidity and idle balances hold. They are not `balanceOf` of the vault, so a donation is not inventory. They are not a spot mark.

Supply `S`. Each share owns `1 / S` of the position. Every holder has the same mix. A swap against the position changes the mix for every holder by the same fraction. No price is required to keep that fraction.

`getRate` is a different number. It is the last settled target balance per share:

`settledTarget * 1e18 / supply`, or `1e18` when supply is zero.

Settled target changes only when target tokens actually move in a vault operation: a target deposit, target paid to a redeemer, or target the vault itself received from a swap it executed. It does not change because an outsider swapped the pool, added liquidity, or removed liquidity. It does not include unsold other token. It does not read `slot0`.

The rate may lag the live position. That lag is the protection. A same-transaction swap that is later reversed must not move `getRate`.

## Entry

A deposit is target only. If the position is already two-sided, the vault swaps part of that deposit into the other token against the same pool, then adds the resulting pair as liquidity. Shares are minted from the liquidity actually added against the position that existed before the add. The depositor does not receive a gift of other token that was already in the position. Old holders' share count does not change. After the mint, their fraction of the position is their shares divided by the new supply.

If the position is single-sided in target, no swap is required. The deposit adds target liquidity and mints pro-rata.

The number of shares minted for a given target deposit must not increase because an outsider added liquidity for the duration of the call and then removed it.

## Exit

Redeeming `s` shares removes only `s / S` of the position and pays only that slice.

1. Burn that slice. The tokens received are the actual target and other token in that liquidity at the current tick. This burn is a withdrawal of tokens, not a valuation of the remaining book.
2. Sell only that slice's other token through the same pool. The remaining vault position may fill that sale. That is intended.
3. Pay the exiting holder the target removed from the slice plus the target the swap actually delivered. Pay nothing else. Do not pay a precomputed liquidation of the whole book.
4. Burn the `s` shares.

The remaining holders keep their shares. Their fraction of the remaining position is their shares divided by the new supply. Their token mix may change, because they took the sale. A test that requires their target balance to stay constant contradicts this design. A test that requires their share count and their fraction of remaining liquidity to stay consistent is the proof.

A large exit sells a larger slice into a thinner remaining book. The exiting holder pays that impact. The remaining holders earn the fee and take the inventory. The sale must not be sized as the whole opposing balance. That is the 024 behavior, and this exit must not reproduce it. Closing 024 still requires a separate review after the code exists.

The swap uses the pool's real price and fee. It does not use `MIN` or `MAX` as a price limit that ignores the slice. Slippage protection is the exiting holder's minimum target out. If the swap cannot deliver that minimum, the exit reverts and no shares are burned.

## Rate checkpoint

Write the settled target counter at the end of deposit and redeem. Harvest may credit target tokens the vault actually collected, and that credit updates the counter. Harvest must not sell the other token. Harvest must not set the counter from a live reading of position composition at the current tick. No other function may sell the position's other token.

`getRate` and `quoteRate` read that counter and the supply. They do not call `LiquidationQuote.quote`. They do not call `slot0`. An unlocked pool manager does not make the rate a quote of the live pool.

`liquidationValue`, if it remains, is not an input to deposit, redeem, or `getRate`. If a caller still wants a preview, that preview must be labeled as a quote and must not mint or burn shares.

## What this does not close

- APEX-2026-025. Rebalance still measures its loss cap at spot. This PRD does not change rebalance.
- APEX-2026-026. The 512-step quote cap becomes irrelevant on the deposit, redeem, and `getRate` path once those paths stop calling the quote. Do not call 026 closed until those paths no longer revert on the quote, and a dust-tick pool still deposits and redeems.
- APEX-2026-040. Bootstrap dead-share and fee-growth donation rounding stay open. This PRD only requires that a donation not move the settled rate or mint shares.
- APEX-2026-024. The new exit must not dump the whole opposing balance. Closure is a later review, not a claim of this document.
- Deployed vaults, 010, 037, and 054. No enable, no upgrade, no recovery contract.

## Tests

Run this set on a real V4 Wings vault and on the new V3 Wings vault. Deploy each through its own manager registry path and TestBase. Do not mock the vault, the quote, the pool, or the rate provider. A V4 pass does not cover V3. Do not assert a constant target payout. "Apportioned value" in these tests means the holder's fraction of the position. Do not satisfy the V3 half by running these tests against V3 FullSpread.

After any production edit, `forge build` before `forge test`.

1. **Fraction after another holder's exit.** Two holders. Move the pool with a real swap so the position is two-sided. Holder A exits. Holder B's share balance is unchanged. B's shares divided by the new supply equal B's fraction of the remaining liquidity. B's target and other amounts may differ from the pre-exit amounts. The difference is the fill of A's slice sale, not a transfer of B's shares.
2. **Second exit pays the remaining slice.** Holder B then exits. Target paid to B equals target removed by burning B's liquidity plus target delivered by the swap of B's other token. It does not equal `LiquidationQuote.quote` of the pre-exit book, and it does not equal B's pre-exit target balance.
3. **Temporary liquidity does not mint shares.** The same target deposit, with and without an outsider adding and removing liquidity around the call, mints the same number of shares. The outsider ends with zero vault shares.
4. **Temporary liquidity does not move the rate.** Adding and removing external liquidity does not change `getRate`. A swap that changes live composition, followed by the reverse swap, does not change `getRate` if no deposit, redeem, or harvest ran between the two reads.
5. **Rate formula.** After a deposit, `getRate` equals `settledTarget * 1e18 / supply`. A direct token transfer to the vault does not change `getRate` and does not increase shares minted by the next deposit.
6. **Entry does not gift the other token.** Starting from a two-sided position, a new target deposit leaves old holders' share balances unchanged. Their fraction after the mint is old shares divided by new supply. The new holder's claim on other token is only the other token bought by the entry swap, not a slice of the other token that was already held.
7. **Exit sale is the slice, not the book.** A large exit sells only the exiting holder's other token. The remaining position's other-token balance increases and its target balance decreases by that fill, or external liquidity takes the fill. The whole opposing balance is not sold. If the exiting holder's minimum target is above what the swap delivers, the call reverts and supply, both holders' shares, and both token amounts are unchanged.
8. **No quote on the money path.** A pool state that would make `LiquidationQuote.quote` revert or return a manipulated value still deposits, redeems, and returns `getRate` from the settled counter. This is the 012 and 026 gate. It is not closed by deleting the quote library if deposit or `getRate` still calls it.
9. **No harvest conversion.** After the position holds the other token, a harvest call leaves that other-token principal in place. It may increase settled target only by target fees actually collected. `getRate` does not change because of the other token still held.

## Non-goals

- No implementation until a later instruction says to build it. The required build includes the new V3 Upper Lower Wings family and the V4 accounting change.
- No restoration of either V4 FullSpread family, and no conversion or deletion of V3 FullSpread.
- No Wings substitution into the retired launch stages.
- No harvest, rebalance, or keeper call that sells the position's other token.
- No new share class, receipt id, or second rate provider.
- No oracle. The stored counter is not a price of the other token.
- No requirement that the remaining holder's target balance be constant.
