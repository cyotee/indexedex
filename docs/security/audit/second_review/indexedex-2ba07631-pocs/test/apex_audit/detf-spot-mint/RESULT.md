# detf-spot-mint: CONFIRMED (detf-spot-mint-gate), with fee dependence

Test: `DetfSpotMint.t.sol::test_detfSpotMint_thirdLegDump`. It passed on the audit runner.

## Setup
- Fixture: `TestBase_UniswapV4Detf_Weighted`. This is a real V4 PoolManager with a 3-leg weighted buffer hook (DETF/pair0/pair1 at 40/30/30) and `ownerOnlyLiquidity`.
- Before the attack, the owner sets fees to the deployed values from `scripts/foundry/anvil_robinhood_main/FixtureEconomics.sol`: dexSwapFee 3e14 (0.03%) and seigniorage 5%. The fixture default dexSwapFee is 5%.
- Honest bonder: first bond of 1000 pair0.
- Honest minter: 14 normal mints of 100 pair0 each. The resulting ~598.7e9 DETF sits with a simulated flash lender that charges 0.10% and requires repayment in the same tx.

## Attack
One tx from an unprivileged attacker contract, using public hook and DETF entrypoints only:
1. Flash-borrow δ DETF (about 0.64x the hook's DETF balance).
2. Dump δ into the third leg (DETF -> pair1). The pair0 mint gate (weighted `previewSynthetic`) only reads the pair0 leg, so it stays open.
3. `DETF.exchangeIn(pair0, 60e18, DETF)`. The mint is priced from the depressed spot quote.
4. Buy back δ + fee DETF with pair1 (exchangeOut).
5. Sell the remaining minted DETF for pair0.
6. Restore pair1 inventory.
7. Repay the loan.

## Result (runner output)
| | control (δ=0) | attack |
|---|---|---|
| user DETF minted | 17.03e9 | 27.99e9 (+64%) |
| attacker pair0 PnL | -1.32e18 | **+32.61e18** |
| protocol-LP pair backing | 3396.60e18 -> 3397.86e18 | 3396.60e18 -> **3363.44e18 (-33.16e18)** |

Assertions that passed:
- Control PnL <= 0 and attack PnL > 0.
- pair1 restored and attacker holds no DETF.
- Lender repaid plus fee.
- Protocol LP backing decreased.

## Caveats
- **Fee-dependent.** At the fixture default dexSwapFee of 5%, the same attack lost money (-53e18 vs control -7.2e18, first run). Round-trip fees on δ outweighed the gain. At the deployed 0.03% it is strongly profitable.
- **Needs DETF inventory of the order of the pool's DETF balance** (a whale or a lending market). Buying DETF in the same tx through the pair0 leg cancels the effect. Profit scales with δ/B_DETF × the mint amount.
- `hunt-detf-entry-no-unlock-gate` (Pons blocked-mode variant) is not exercised here, because this fixture uses ERC4626 SEs. It has the same root cause as fs-pons H1/U1; see `../fs-blocked-entry-spot-mint`.

## Fix
Do not price issuance off a spot hook quote. Options:
- Price mint gross from the same manipulation-resistant valuation as the gate (e.g. a synthetic/TWAP price for pair -> DETF).
- Bound the deviation of spot from the gate price.
- Make the gate depend on the DETF leg balance as well.
