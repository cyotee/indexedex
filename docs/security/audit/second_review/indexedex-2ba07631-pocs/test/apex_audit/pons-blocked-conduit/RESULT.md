# pons-blocked-conduit: weighted hook swaps force the Pons SE into blocked mode, and the deposit is spot-priced

P2 ids: hunt-comp-hook-blocked-pons-conduit, hunt-weighted-hook-forces-pons-blocked-mint

**Status:** CONFIRMED, but only when the SE holds a large share of the Pons pool's liquidity. When the pool is deeper, it is not profitable.

## Fixture
Everything is the project's own code. No mocks and no cheatcodes run during the attack.
- **Pons pool:** a real PonsV2MemeHook pool (from TestBase_UniswapV4FullSpreadPonsFamilyHook) on a real PoolManager. LP fee is 0, the Pons hook fee is 100 bps and the creator tax is 100 bps.
- **SE:** registry-deployed UniswapV4FullSpreadPonsFamilyHook with a 20% liquid sleeve. An honest LP bootstraps it with 100/100.
- **Hook:** a real weighted buffer hook (FullSpreadSameManagerWeightedFixture, 50/50, face = SE token0, raw = a DETF stand-in) on the same PoolManager.
- **Hook owner:** an honest party. It does an idle dual deposit of 2000/2000 into the SE, then joins the hook with those SE shares plus 4000 raw. The hook ends up holding 95% of SE supply.

## Attack
The attacker is an unprivileged contract. Everything happens in one `PM.unlock`, and all deltas are settled from the attacker's own balance in the same transaction, so this is flash accounting with net cost measured.
1. Swap token1 into the Pons pool to push sqrtP up by 1.5x, 2x or 3x.
2. Swap face for raw exact-in on the weighted pair pool. Inside beforeSwap the hook previews and executes the Pons SE deposit in blocked mode against the live slot0, so the SE mints too many shares. The size is set to the largest the MAX_IN_RATIO cap accepts.
3. Swap the Pons pool back to exactly the original sqrtP.
4. In a later transaction, with the PoolManager locked, sell all the raw back through the hook using `hook.exchangeIn` (idle path).

Profit is the attacker's net face+token1 at P=1, after all Pons and hook fees. Victim loss is the change in the SE claim of the hook plus the honest SE LP, valued at the restored price. The hook's raw reserve returns exactly to where it started.

## Results (face units, 18 decimals; SE NAV is about 4200)

The push size is in the column headers; the first figure in each cell is attacker profit, the second is victim delta.

| Pool depth (SE share of liquidity) | control (no push) | k=2.25 | k=4 | k=9 |
|---|---|---|---|---|
| ext 2,000 (SE about 47%) | -291 / +253 | -43 / -57 | **+61.8 / -211.9** | **+129.4 / -367.0** |
| ext 8,000 (about 18%) | -260 / +236 | -113 / -75 | -88 / -230 | -160 / -385 |
| ext 40,000 (about 4%) | -245 / +232 | -631 / -78 | -1,033 / -233 | -1,852 / -388 |
| ext 1,000,000 (project default, about 0.2%) | -241 / +221 | -16,627 / -86 | -29,828 / -240 | -53,047 / -393 |

Share inflation (shares minted against the fair a·S/NAV):
- k=4: 616.8 against 412.6, about 1.49x.
- k=9: 616.8 against 314.4, about 1.96x.

The free sleeve caps the inflation, as the skeptics predicted: (f+D)/(f+D/√k), not √k.

The shallow-pool case passes `test_k4` and `test_k9` with the assertions profit > 0 and victim < 0.

## Assessment
- **Mechanism:** real. In every pushed run the SE holders (the hook, standing in for the DETF reserve, plus the honest LP) lose 57 to 393 face.
- **Who keeps the loss:** the attacker keeps it only when the Pons round-trip fee (2% hook fee plus creator tax, charged on the push volume) is smaller than the gain. That needs the SE (and so the hook's holding) to be roughly 30% or more of the Pons pool's liquidity. At 18% it already loses money.
- **Severity: medium.** It is conditional on two things:
  - The HEAD Pons family being deployed as the weighted hook's WETH-leg SE. The live vault 0x999D is the pre-diff family.
  - The DETF's liquidity SE being the dominant LP in the ETH/DTF Pons pool, which is plausible for protocol-owned liquidity.
- **Live depth unknown:** the Robinhood fork at 127.0.0.1:8545 returned "historical state not available", so the live depth ratio could not be read.

**Fix:** do not let consumers price or execute FullSpread deposits and redeems on the blocked spot path inside a foreign unlock. Options:
- Require a TWAP or deviation check in `_snapshot` when idle is false.
- Have the hooks reject buffering when `!se.canOpenPoolManagerUnlock()`, and route through a context-aware quote.

**Run:** `forge test test/apex_audit/pons-blocked-conduit/PonsBlockedConduit.t.sol -vv`
