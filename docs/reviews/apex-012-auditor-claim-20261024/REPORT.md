# Council report — APEX-2026-012 auditor claim

- Run: apex-012-auditor-claim-20261024
- Profile: review
- Council kind: full
- Coordinator: invoking agent. Not an extra vote.
- Draft reviewed: draft-apex-012-auditor-claim-20261024-r1
- This final is a coordinator revision. It is not member-approved text.
- This report does not authorize a fix.

## Participation

| Label | Task | Feedback |
| --- | --- | --- |
| astra | st_01a16f31 | requested-changes |
| grok | st_01a16f32 | requested-changes |
| minimax | st_01a16f33 | support-with-reservations |
| kimi | st_01a16f34 | support-with-reservations |

## What the auditor claims

APEX-2026-012 is High and latent. It is not deployed. The heading is not "spot price is an invalid price." It says UpperLowerWings prices deposits and redeems from a live liquidation quote that counts temporary liquidity and in-session price moves.

`Money._deposit` and `Money._redeem` set the share price from `LiquidationQuote.quote()`. That quote reads live `slot0`, `getLiquidity`, and the tick bitmap. It subtracts only the vault's own liquidity. It simulates selling the vault's other token into the remaining depth, and adds those proceeds to the target-token amount. Shares are issued as `supply * credit / V`. A redeem pays `shares * V / supply`. If that simulated sale looks better, the vault looks more valuable, and the redeem pays more.

The principal sequence uses allowed calls.

1. Deposit at the honest quote `V0`.
2. Add a large full-range position in the same pool.
3. Redeem the new shares at the higher quote `V1`.
4. Remove the added position and keep the difference.

In the unlocked version the added position is left unsettled inside one `unlock`, and the redeem is paid from the local target sleeve. The auditor's formula is `profit = D*(V1 - V0 - D)/(V0 + D)`. The stated result is 70,634,405,953 raw token0, called 7.1% of a 1e12 vault, with no capital left behind. That per-transaction profit is capped by the target already sitting in the sleeve. The auditor says it can be repeated once the sleeve refills. A scripted 0% sleeve blocks this version with `InsufficientLocalTarget`.

The settled version deposits normally, adds settled liquidity, redeems while the manager is locked, and then removes the liquidity. The auditor says that redeem pays through `_fund` with no sleeve cap. The stated profit is 74,704,386,253, called 7.5% of TVL, valued in token0 at the starting price. It uses flash-loanable depth, on the order of 27 times TVL, and the 0% sleeve does not block it.

The auditor says the remaining holders lose what the attacker gains. Their entitlement falls. `HolderValueLoss` does not see the inflation, because both quotes it compares are taken while the extra depth is still there. The report does not describe a separate ledger entry that records the difference as a loss. That sentence is the owner's.

The auditor also states a second sequence: swap, deposit, swap back to the exact original price, redeem, paying 0.3% swap fees. Stated profits on that path are 53,661,742,003 and 33,284,087,429 raw token0 at two liquidity levels. That is a spot-move channel. It is not the liquidity channel.

The auditor does not claim an invalid call. The design note says the attack satisfies the tested SEC-08 bound. It also says the cited SEC-08 text names temporary liquidity and JIT, and that an owner ruling which accepts round trips moving value between holders does not waive that text.

## The auditor's fix, not adopted here

Revert in `Money.begin()` when the manager is unlocked, and guard `getRate()`, `liquidationValue()`, preview, and `requiredInput` the same way. The auditor says this only partly fixes the issue, because settled depth and flash-loaned spot moves still work. The rest of the list is a TWAP-bounded reference with a fixed haircut, minting at the higher of the live quote and that reference and redeeming at the lower, a cap on the depth used in the simulated sale, a loss check against the reference, an optional exit fee of at least the current haircut, and a round-trip test for added depth. This report does not adopt any of those.

## Against the clarification

The clarification matches the liquidity channel. Changing the pool's depth changes the withdrawal. The calls are allowed. The holders who stay are the ones who lose the difference.

The report is broader in two places. It also claims the spot-move sequence. And it claims unsettled depth inside one unlock, which the scripted 0% sleeve blocks, as well as settled depth, which that sleeve does not block. Depositing at the honest quote and redeeming at the inflated quote is the withdrawal story. It is not a third broadening.

## Limits

Static reading of the named report section and the four responses. No Forge run. No fix authority.
