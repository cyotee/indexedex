# v3fs-blocked-cp — CONFIRMED (execution)

Hypothesis: v3fs-blocked-mode-callback-cp. Commit 2ba07631.

## Mechanism (as executed)
An attacker can put a UniswapV3 FullSpread vault into blocked mode by calling it from inside `pool.swap`'s callback. In that callback `slot0.unlocked == false`, so `canOpenBoundPoolOps()` returns false, while `slot0.sqrtPriceX96` already holds the attacker's post-swap price.

In blocked mode:
- Zap-in (`_sharesForDeposit`, single-sided sqrt growth) followed by a blocked zap-out (`_singleExit`) behaves as a **fee-free x*y swap**.
- That swap runs over `free + deployed(slot0) + fees`.
- Payment comes from the free sleeve, which is not repriced.

The attack: push token0's price up, sell token0 to the vault at the inflated book price for the sleeve's token1, then swap the pool back.

## PoC
- File: `V3FSBlockedCP.t.sol`. Fixture: `TestBase_UniswapV3FullSpreadStandardExchangeVault`, which deploys through the real DFPkg on a real UniswapV3 factory.
- Pool: 0.3% fee. Liquid reserve: 20%, which is the fixture value and also `UniswapV4DetfProductionSeDeployLib.V3_LIQUID_RESERVE_PCT`.
- Honest LP: deposits 1000/1000 before the attack, ending with 200/200 free and about 800/800 deployed full-range. External full-range LP depth is varied.
- Attacker: an unprivileged contract that starts with 0 tokens plus 100e18 of its own token1, which is subtracted from profit. Its capital comes from an independent `FlashLender` that charges 9 bps and reverts unless repaid in the same tx.
- No pranks, store, etch, mocks or deal on protocol contracts.

Attack steps, all in one tx:
1. Flash-borrow both tokens.
2. `pool.swap(oneForZero)` up to a sqrtP target.
3. Inside the callback, with the pool locked: `exchangeIn(token0 -> vaultShares)`, then `exchangeIn(vaultShares -> token1)` for about 97% of free1. Pay the pool.
4. Swap back to P0.
5. Buy any token0 shortfall from the pool and repay the flash loan.

To value the vault at the original fair price, a neutral third party then returns the pool to P0. Vault NAV includes the fees the vault earned from the attack swaps.

## Runner output (forge test, all PASS)

The vault's share of pool liquidity is about 1/λ.

| λ (pool L / vault L) | Price push | Attacker net profit | Vault NAV loss at P0 | LP loss |
|---|---|---|---|---|
| 2 | 4.0x | +107.55 token1 | 117.93 | 5.89% |
| 5 | 3.06x | +81.06 | 100.59 | 5.02% |
| 10 | 2.25x | +46.26 | 74.12 | 3.70% |
| 20 | 1.69x | +6.26 | 41.56 | 2.07% |
| ~1250 (fixture default 1M external L) | — | attack reverts: cannot repay | — | — |

The honest LP holds 99.9999% of shares, so LP loss is the vault NAV loss.

## Preconditions and limits
- The free sleeve must be non-zero (liquidReservePercentage > 0). The robinhood_main fee-oracle script sets no V3 default, so a vault there would have a pct of 0 and no sleeve. The production DETF deploy lib sets 20%.
- Profit is capped at about the tokenOut free sleeve per cycle (about 10% of TVL at 20%). It is only profitable when the vault is roughly 5% or more of the bound pool's in-range liquidity.
- Not executed here: repeating after the permissionless `rebalanceLiquidReserve()` refills the sleeve, and the mirror direction to drain free0. Both are plausible; the drain looks repeatable per sleeve refill.
- No V3 FS vault is deployed on chain 4663 per the repo manifests.

## Fix suggestion
Do not price blocked-mode zap-in or zap-out from live `slot0`. Options:
- Use a TWAP / `observe` price with a deviation check against slot0.
- Price blocked exits only against the free sleeve, i.e. proportional free-only exit with no CP conversion of deployed value.
- Disallow blocked-mode single-sided deposits followed by single-token exits in the same block.
