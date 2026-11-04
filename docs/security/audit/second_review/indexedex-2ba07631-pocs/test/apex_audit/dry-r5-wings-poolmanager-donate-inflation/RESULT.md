# dry-r5-wings-poolmanager-donate-inflation: CONFIRMED (latent, medium)

PoC: WingsDonateInflation.t.sol, a copy of ../r5-wings-donate-inflation/WingsDonateInflation.t.sol.
Run: forge test -vvv gave `Suite result: ok. 5 passed; 0 failed; 0 skipped`.

## Mechanism
- Accounting.sol:21: when supply is 0, shares = credit. There is no dead-share or minimum-liquidity sink. Later deposits get floor(S*credit/value), and the only guard is ZeroIssue.
- Money._deposit (129-136) prices shares from Quote.quote().value. LiquidationQuote.sol:272-273 adds earnedFee(liquidity, feeGrowthInside - last) for each position.
- Anyone can raise feeGrowthInside on the vault's positions with the public PoolManager.donate. This gets around p2's balanceOf/booked-local refutation.
- The attack, in one unlock:
  1. Push the price into the vault's out-of-range target wing (Geometry: [nextBoundary, maxTick]).
  2. Remove the attacker's own LP.
  3. donate(D).
  4. Re-add the LP.
  5. Swap back. The PoC asserts the price ends at exactly p0.

## Results (token0, 6 decimals)
| case | victim deposit | shares (= preview) | victim out | victim loss | attacker net token0 | token1 |
|---|---|---|---|---|---|---|
| seed 10, D=1e9 | 190e6 | 1 | 108,181,818 | 81,818,182 (43%) | +81,818,175 | -5 wei |
| seed 100, D=1e9 | 19e6 | 1 | 10,089,109 | 8,910,891 (47%) | +8,910,883 | -5 wei |
| seed 1000 (full-range core, no price push needed) | 1.9e6 | 1 | 1,000,898 | 899,102 | +899,093 | -5 wei |
| control (no donate) | 19e6 | 19,191,919 | 18,999,999 | 1 | -3 | -1 |
| DoS: 5e6 deposit while the trap is set | reverts (ZeroIssue) | | | | | |

The attacker recovers its whole donation on redeem, and the attacker's external LP is removed at the end. Net profit is close to the victim's loss.

## Caveats
- Wings is not deployed on chain 4663, so this is latent.
- Owner rulings O1/O3 (docs/research/apex-stage2-review/accepted-20261007) allow residual value to go to the first depositor and allow no sink. This attack goes further: it takes value from the *second* depositor. The owner's stated mitigation, minimum = preview, does not help, because the preview already shows the trap (1 share).
- To be harmed, the victim must accept 1 share for 190 tokens.

## Fix
- Add a minimum-liquidity / dead-share sink at bootstrap (for example FullSpread's 10^(dec-3)) or use virtual shares/offset.
- Alternatively, leave uncollected fee growth out of the issue-side value, or cap per-share fee accrual.
