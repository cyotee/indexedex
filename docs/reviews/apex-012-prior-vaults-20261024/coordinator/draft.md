# Coordinator draft

- Draft ID: draft-apex-012-prior-vaults-20261024-r1
- Path: `docs/reviews/apex-012-prior-vaults-20261024/coordinator/draft.md`
- Run: apex-012-prior-vaults-20261024
- Coordinator: invoking agent. Not an extra vote.

## Participation

| Label | Task | Status |
| --- | --- | --- |
| astra | st_01a16fcb | completed |
| grok | st_01a16fcc | completed |
| minimax | st_01a16fcd | completed |
| kimi | st_01a16fce | completed |

## What the survey can support

No inspected production Uniswap vault was shown to earn swap fees and pay a one-token amount that ignores a permitted liquidity change. The survey did not test any design against APEX-2026-012. Its recommendation is not a decision.

Wings is the only inspected design recorded as pricing a withdrawal from other liquidity providers' live depth. `Quote.quote` reads slot0 and simulates a sale of the other token into remaining depth. Added depth is an input to the amount paid. That is the claim. It is not a pattern to take.

Reading slot0 is not the same failure. Arrakis V2 and Charm return a share of the vault's own position as two token amounts. Gamma V4 is recorded as a slot0 mark. Those fail the old question, which wanted a one-token rate that ignores same-pool spot. The survey does not show that merely reading slot0 lets added depth change the payout. Astra and Grok separate those designs from Wings. MiniMax and Kimi group the slot0 readers with designs that do not stop the claim. This draft follows the narrower reading: only a simulated sale into remaining depth is the liquidity claim.

## What can be taken, and the cost

Three pieces, none of them a finished vault.

**Pay a share of the vault's own position, in two tokens.** Arrakis V2 and Charm. At a fixed spot, added outside liquidity is not an input to that payment, because there is no simulated sale. This is an inference from the recorded formulas, not a test, and not a synthesis finding. The cost is the one-token exit. The holder receives two assets and bears the later conversion. Amounts still move if the spot moves. Arrakis V2 is recorded as deprecated on 15 Jun 2026. Charm does not stop the spot-move sequence.

**Pay from a stored counter.** Panoptic `convertToAssets` reads stored assets and supply. An outsider adding Uniswap liquidity does not write those stores, so that formula would not pay more because depth changed. The survey says this is options collateral, not an LP vault. The shape can be called. The vault cannot. The cost is that fees and the other token stay out of the amount until a real credit writes the counter. A rate that reads the counter does not, by itself, fix a deposit or redeem that still prices off the pool. The survey does not show how that counter funds an immediate one-token exit of a live position.

**Publish a cached external mark between updates.** Maker `GUniLPOracle`. `peek` and `read` return the last `poke`, limited by a hop the synthesis reports as one hour by default. A liquidity change in the attacker's own transaction does not rewrite that cached number. A later poke can. `seek` still calls the vault, and Arrakis still reads slot0 for the fee tick. The survey says this does not make a live at-price call safe. The cost is a stale mark, two outside price feeds, and no proof that the withdrawal pays the cached number.

## What must not be taken

- "Do not read slot0 in `getRate`" as a fix for this claim. That answers the old question. A deposit or redeem that still simulates a sale into live depth is unchanged.
- The Visor and Gamma postmortems as this attack. Those are spot-mint cases.
- ICHI's deposit comparison of spot and TWAP. The surveyed page has no withdrawal rate, and a depth-only change need not move spot.
- A live at-price call. The survey records that the cached mark does not make that call safe.
- The auditor's reference-price list. The survey does not test it.
- The synthesis recommendation as already chosen.

## Limits

Read from the four responses against the named survey and the claim report. No new protocol search. No Forge run. Advisory review has not happened. This draft does not authorize a design.
