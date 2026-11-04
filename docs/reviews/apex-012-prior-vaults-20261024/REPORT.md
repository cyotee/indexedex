# Council report — suggestions from the completed vault survey

- Run: apex-012-prior-vaults-20261024
- Profile: research
- Council kind: full
- Coordinator: invoking agent. Not an extra vote.
- Draft reviewed: draft-apex-012-prior-vaults-20261024-r1
- This final is a coordinator revision. It is not member-approved text.
- This report does not authorize a design.

## Participation

| Label | Task | Feedback |
| --- | --- | --- |
| astra | st_01a16fcb | requested-changes |
| grok | st_01a16fcc | requested-changes |
| minimax | st_01a16fcd | support-with-reservations |
| kimi | st_01a16fce | support-with-reservations |

## What the survey does not contain

No inspected production Uniswap vault was shown to earn swap fees and pay one token in a way that ignores a permitted liquidity change. The survey did not test any design against APEX-2026-012. Its recommendation is not a decision. Its question was a one-token rate that does not read same-pool spot. That is not this claim.

Wings is the only inspected design recorded as pricing a withdrawal from other liquidity providers' live depth. `Quote.quote` reads slot0 and simulates a sale into remaining depth (synthesis, Quote functions; ledger S2, S3; claim report). Added depth is an input to the amount paid. That is the claim. It is not a pattern to take.

Reading slot0 is not that failure. Arrakis V2 and Charm return two token amounts from the vault's own position (S4, S14). Gamma V4 is recorded as a slot0 mark (S13). Those fail the old spot question. The survey does not show that adding someone else's liquidity changes those payments. Two members first grouped the slot0 readers with Wings. On review, that grouping was withdrawn for the depth claim. Kimi's grouping was the claim report's separate spot-move sequence, not the depth channel.

## What can be taken

Three pieces. None is a finished vault. None was tested against the claim.

**Pay two tokens from the vault's own position.** Arrakis V2's underlying library and Charm's recorded withdraw. If spot, the vault's own liquidity, inventory, accrued fees, and supply are unchanged, adding someone else's liquidity is not an input to that payment, because there is no simulated sale. This is an inference from the formulas, not a test. Both formulas also add idle token balances. The survey's own rate rule says a rate must not read `balanceOf`. Charm's TWAP gates rebalance, not the payment. The Arrakis evidence is the underlying library, not a withdraw entrypoint that was opened. The cost is the one-token exit. The holder receives two assets and bears the later conversion. Amounts remain spot-sensitive. The survey did not show whether the auditor's swap-and-swap-back sequence succeeds against Charm. Arrakis V2 is recorded as deprecated on 15 Jun 2026.

**Pay from a stored counter.** Panoptic `convertToAssets` reads stored assets and supply (S16). An outsider adding Uniswap liquidity does not write those stores, so that formula would not pay more because depth changed. The contract is options collateral, not an LP vault. The shape can be called. The vault cannot. If that shape is adapted, the counter is accounted storage, not a token balance and not pool state. Fee earning is not given up on the survey's record. Fees and the other token stay out of the published amount until a real credit writes the counter. What is given up is a hypothetical sale inside the rate. A rate that reads the counter does not fix a deposit or redeem that still prices off the pool. The survey does not show how the counter funds an immediate exit of a live position. That is not the same as giving up fee earning, or giving up a one-token number.

**Publish a cached external mark between updates.** Maker `GUniLPOracle`, in the synthesis section "Alternative precedent, not the recommendation." There is no ledger row. `peek` and `read` return the last `poke`. The synthesis reports a default one-hour hop. The price comes from two outside feeds, not from pool depth. A depth-only change does not, on that record, rewrite the cached number, including at a later refresh. The survey does not show that a refresh cannot be called in the same transaction. It does not show that a withdrawal pays the cached number. `seek` still calls the vault, and the Arrakis path still reads slot0 for the fee tick. The survey says this does not make a live at-price call safe.

## What must not be taken

- "Do not read slot0 in `getRate`" as a fix for this claim. A payment path that still simulates a sale into live depth is unchanged.
- The Visor and Gamma postmortems as this attack (S22, S23). Those are spot-mint cases.
- ICHI's deposit comparison of spot and TWAP (S9). The surveyed page has no withdrawal rate.
- A live at-price call.
- Any item on the auditor's fix list. The survey supports none of them: the unlock revert, a reference mark, a depth cap, a different loss check, an exit fee, or the added round-trip test.
- The synthesis recommendation as already chosen.

## Limits

Static reading of the named survey, its ledger, the claim report, and the four responses. No new protocol search. No Forge run. No design authority.
