# wings-spot-nav: CONFIRMED (wings-liquidity-depth-jit and wings-unlock-spot-nav)

Test: `WingsSpotNav.t.sol`. All 7 tests pass on the t4 runner (profile audit, solc 0.8.35).

## Setup
- Fixture: the project's own `TestBase_UniswapV4UpperLowerWingsStandardExchangeVault`, which uses a real V4 PoolManager and a hookless pool with fee 3000 and spacing 60.
- An honest LP deposits 1e12 token0 into `wings0`, with the liquid reserve set to 20%.
- A permissionless keeper then calls `rebalance` until it stops, which builds the core position plus the lower wing.
- External full-range LP depth is swept: 1e11 (thin), 1e12 (about 3x the vault's L) and 1e13 (about 25x the vault's L).

The attacker is an unprivileged contract. All of its principal is PoolManager flash credit (`take` / `settle`) inside a single `unlock`. Only dust, or the swap fees in the spot variant, comes from the attacker's own balance, and that is subtracted from profit.

## JIT depth attack (no fees paid)
All steps run inside one unlock:
1. `take` D token0 from the PoolManager.
2. Call `exchangeIn` to deposit D. The vault is valued at the thin-depth liquidation value V0.
3. Call `modifyLiquidity` to add 1e22 L full-range. This is left unsettled.
4. Call `exchangeIn` to redeem all shares. The quote now sells the opposing inventory into the JIT depth, giving V1 > V0, and the payout comes from the local sleeve.
5. Remove the JIT liquidity, then settle.

| external L | D | attacker net profit (token0) | honest entitlement drop |
|---|---|---|---|
| 1e11 | 2e11 | 74,047,396,281 (7.4% of TVL) | 999.16e9 -> 925.11e9 |
| 1e12 | 1e12 | 70,634,405,953 (7.1% of TVL) | 998.05e9 -> 927.41e9 |
| 1e13 | 1e12 | 9,777,515,150 (1.0% of TVL) | 997.39e9 -> 987.62e9 |
| 1e12, no JIT (control) | 1e12 | -1 | none |

`test_jit_honestRealizedLoss` shows the honest LP's actual redeem payout falls from 998,045,067,650 to 927,410,661,695 token0 after the attack.

## Spot price attack (V4 unlock, swap fees paid)
Inside one unlock:
1. `take` D.
2. Swap token1 to token0 to push the price up.
3. Deposit at the depressed V.
4. Swap back to the exact original sqrtPrice.
5. Redeem from the local sleeve, then settle.

Results, net of all round-trip fees with token1 valued at the restored spot price:
- external L 1e12, D = 3e11: profit 53,661,742,003.
- external L 1e11, D = 1e11: profit 33,284,087,429.

In both cases the price is restored exactly, and the honest entitlement and the vault's mark value fall.

## Root cause
`Money._deposit` and `Money._redeem` (Money.sol:132 and 160) price shares from `LiquidationQuote.quote`. That quote reads live `slot0` and `getLiquidity` and the live tick bitmap. It includes unsettled liquidity and unsettled price moves made by another caller's open unlock.

Nothing stops a deposit or redeem while the manager is unlocked: `_harvest` and `_place` just return early. When unlocked, redeem is paid from the local sleeve. The `HolderValueLoss` check re-quotes in the same manipulated state, so it passes.

## Caveats and limits
- Per-transaction profit is capped by the local target sleeve. The redeem inside the unlock needs `local >= payout`, and the sleeve is about 20% of the target. The attack can be repeated after each sleeve refill.
- The deep-pool row (external L 25x the vault's L) still gives about 1% of TVL per transaction.
- The Wings family is not deployed on chain 4663 at 2ba07631.
- Spec SEC-08 (`Manipulation.t.sol`) accepts entry at a depressed V. Its tests only bound the payout by the post-state pro-rata share, so they do not catch this.

## Fix
Do either of the following:
- Reject deposit and redeem when `manager.isUnlocked()`, which closes the free-capital path.
- Value shares independently of live depth and spot, for example with a mark or TWAP oracle with a liquidation haircut, or charge entry/exit fees of at least the depth discount.

Rejecting while unlocked is only a partial fix. Flash-loan capital outside an unlock can still move spot, and an attacker can still add and remove external depth across separate unlocks within one transaction.
