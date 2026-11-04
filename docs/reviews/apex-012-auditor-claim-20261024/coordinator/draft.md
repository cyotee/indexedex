# Coordinator draft

- Draft ID: draft-apex-012-auditor-claim-20261024-r1
- Path: `docs/reviews/apex-012-auditor-claim-20261024/coordinator/draft.md`
- Run: apex-012-auditor-claim-20261024
- Coordinator: invoking agent. Not an extra vote.

## Participation

| Label | Task | Status |
| --- | --- | --- |
| astra | st_01a16f31 | completed |
| grok | st_01a16f32 | completed |
| minimax | st_01a16f33 | completed |
| kimi | st_01a16f34 | completed |

## The claim, as the report states it

APEX-2026-012 does not say the spot price is, by itself, an invalid price. The heading names two inputs to one quote: temporary liquidity, and an in-session price move.

The auditor says `Money._deposit` and `Money._redeem` set the share price from `LiquidationQuote.quote()`. That function reads live `slot0`, `getLiquidity`, and the tick bitmap, subtracts only the vault's own liquidity, and simulates selling the vault's opposing inventory into the remaining depth. Share issuance is `S*credit/V`. Redemption entitlement is `shares*V/S`. Depth that exists for one transaction, or that is left unsettled inside another caller's `unlock`, raises that simulated value. The vault still accepts the deposit and the redeem.

The principal sequence is permitted calls, not a rejected call:

1. Open `PoolManager.unlock`.
2. Take token0 `D` as flash principal.
3. Deposit at the honest value `V0`. Harvest and place are skipped while unlocked.
4. Add a large full-range position and leave it unsettled.
5. Redeem the new shares at the inflated value `V1`, paid from the local target sleeve.
6. Remove the position, repay `D`, and keep `paid - D`.

The auditor's formula is `profit = D*(V1 - V0 - D)/(V0 + D)`. The stated in-unlock result is 70,634,405,953 raw token0, called 7.1% of a 1e12 vault, with zero capital. A settled variant adds the liquidity in the attacker's own unlock, then redeems while the manager is locked. The auditor says that pays through `_fund` with no sleeve cap, and states 74,704,386,253 raw token0, called 7.5% of TVL, using flash-loanable depth. The auditor says incumbent holders lose what the attacker gains. `HolderValueLoss` does not catch it, because it compares two quotes of the same inflated state.

A second sequence in the same finding moves the spot: swap, deposit, swap back to the original price, redeem. The auditor states a profit on that path as well. That is a separate channel from adding and removing liquidity.

The auditor does not claim an invalid selector or a reverted call. The design note says the attack satisfies the tested SEC-08 bound, and that an owner ruling accepts round trips moving value between holders, while also saying that ruling does not waive SEC-08. The claim is that a permitted sequence changes the quote, and the vault accounts the changed quote as share value.

## The proposed fix, as the auditor states it

Revert in `Money.begin()` when the manager is unlocked, and guard `getRate()`, `liquidationValue()`, and the preview functions the same way. The auditor says this only partly fixes the issue, because settled depth and flash-loaned spot moves still work. The rest of the list is a reference mark, a cap on the depth used in the simulated sale, a loss check against that reference, an optional exit fee, and a round-trip test for added depth. This draft does not adopt those fixes.

## Against the owner's clarification

The clarification matches the liquidity channel. The attacker changes pool depth, the withdrawal amount changes, the calls are allowed, and the difference is accounted as a loss to the holders who remain.

The report is broader in three places. It also claims an in-session spot-move channel. It claims unsettled depth inside one unlock, not only a settled liquidity change. It prices both sides of the round trip: the deposit mints against `V0`, and the redeem pays against `V1`. The clarification speaks of the withdrawal amount.

## Limits

Read from the four responses against the named report section. No Forge run. Advisory review has not happened. This draft does not authorize a fix.
