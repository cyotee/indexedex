# wings-quote-cap-dos (wings-quote-step-cap-dos): CONFIRMED (DoS / frozen funds)

Run: `forge test test/apex_audit/wings-quote-cap-dos/WingsQuoteCapDos.t.sol -vv`. Result: 3/3 PASS.

## Mechanism
- `Common.quoteRequest()` hard-codes `stepLimit = 512`.
- `LiquidationQuote._sell` removes the vault's own liquidity, then walks one initialized tick or one bitmap word per step until `unsold == 0` or the price limit is reached. Past 512 steps it reverts `QuoteWorkExceeded(512)`.
- deposit, redeem, getRate and liquidationValue all call this quote with no fallback.

## What the tests show
Fixture: the project's TestBase (real PoolManager and DFPkg). Wings vault with token0 as target. Alice deposits 1e12 honestly.

| Test | Setup | Attacker | Result |
|---|---|---|---|
| A | fee 3000, spacing 60 (the fixture defaults), vault is the only LP. A trader swaps to tick 120. Before the attack the quote takes 58 steps. | Adds 480 adjacent 60-tick positions with liquidity 1 above the price, in 4 txs of 120 positions each. Token cost: 480 wei of token0. | Each of these reverts with QuoteWorkExceeded(512): Alice's full and 1% redeem, Bob's deposit, getRate, liquidationValue. After the attacker removes the dust, Alice's redeem works again (997004645041 out), so the dust was the only cause. |
| B | fee 100, spacing 1, vault is the only LP. One ordinary trade to tick 50. | None | Same reverts. Normal use bricks the vault with no attacker at all. |
| C | spacing 1, plus an honest full-range external LP (L = 1e12, about the vault's size). A trader moves the price to tick 1000 (about +10%). Before the attack the quote takes 5 steps. | 550 one-tick dust positions. Cost: 550 wei. | Same reverts. |

## Impact and limits
- Holders' funds are frozen: redeem is impossible and there is no admin or emergency exit. New deposits and the rate feed are DoS'd.
- The attacker makes no profit. This is pure griefing, and very cheap: a few hundred wei plus about 80M gas spread over several txs.
- The attack persists. To undo it, someone has to add enough external liquidity near the price to absorb the vault's opposing inventory within 512 crossings, and the attacker can re-seed.
- Precondition: the vault must hold some opposing token, which happens after any trade through its wing.
- Precondition: external liquidity must not absorb that inventory within 512 crossings. That holds when the vault is the dominant LP, or for spacing 1 pools with comparable external depth (test C).
- Wings was not found in any deployment manifest for chain 4663. Suggested severity: medium.

## Fix ideas
- Do not revert. Treat unsold inventory remaining at the step limit as market-limited, valued at 0 or at a floor.
- Or allow a pro-rata in-kind redeem (target plus opposing token) that needs no quote.
- Or skip zero-or-dust-liquidity ticks and words cheaply, and count only steps that move value.
