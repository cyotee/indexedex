# probe-maintenance-jit (fs-maintenance-at-spot-jit): CONFIRMED in a corrected form (V3 FullSpread); the original claim is REFUTED

Test file: `MaintenanceJit.t.sol`. All 8 tests pass on forge test.
Fixture: `TestBase_UniswapV3FullSpreadStandardExchangeVault`, which deploys a real DFPkg vault on a real UniswapV3 factory.
- Pool fee: 0.3%.
- Liquid reserve: 20% (fixture default; matches the production DETF lib).
- Honest LP: deposits 1000/1000 before the attack. A keeper rebalance then leaves the vault at 200/200 free and 800/800 deployed.
- Attacker capital: an independent FlashLender that charges 9 bps and must be repaid in the same tx. The attacker also holds 100/100 of its own tokens, counted as cost.
- No pranks, store, etch or mocks on protocol contracts.

## A. The hypothesis as stated: REFUTED by execution
Attack: push the price, call the permissionless `rebalanceLiquidReserve()` at P', then swap back. Starting from sleeve equilibrium, the rebalance only **burns** at P' (`_refillDeficitLiquidity`). The excess is one-sided, so the mint plans 0 liquidity. The burn locks in the vault's favourable side of the move.

| case (vault ~50% of pool L) | attacker PnL | victim PnL |
|---|---|---|
| no rebalance (control A0), price x2 | -5.25 | 0 |
| rebalance at P', price x2 | **-10.82** | **+6.61** |
| rebalance at P', price x4 | **-51.07** | **+41.93** |

This matches the econ and design skeptics: removal at P' moves value from the attacker to the vault.

## B. Corrected mechanism: CONFIRMED
A two-sided deposit made while the pool is locked skips the best-effort rebalance. `_executeZapInDualDeposit` emits `LocalDepositWhileBlocked` and returns. That leaves **two-sided idle excess**, and the next `rebalanceLiquidReserve()` mints it at whatever spot price is current.

The attacker does all of this in one tx, funded by the flash loan:
1. Make a fair, book-proportional dual deposit at P0, inside the callback of a 1-wei `pool.swap`.
2. Push the price up (sqrtP x1.414 or x2).
3. Call `rebalanceLiquidReserve()`. It mints dL at P'; vault L goes 800 -> 1318.8.
4. Swap back to exactly P0, capturing the IL on dL.
5. Make a dust deposit, which collects fees, then exit pro-rata with `exchangeOutOneToMany` at P0.
6. Repay the loan.

Results are in token1-equivalent at P0. The victim is the honest LP, valued at P0 including collected fees:

| case | attacker net profit | honest LP loss |
|---|---|---|
| control B0 (no push) | -1.80 (flash fee only) | 0 |
| vault 50% of pool L, price x2 | **+25.05** | **30.39 (1.52%)** |
| vault 50% of pool L, price x4 | **+68.09** | **77.95 (3.90%)** |
| vault 10% of pool L, price x2 | **+4.06** | 30.39 |
| 3 separate txs, keeper rebalance at P0 between them, price x2, vault 50% | **+66.60 total** | **82.44 (4.12%)** |

The victim loss does not depend on external depth. Pool fees the vault earns scale with the vault's own liquidity, so only the attacker's cost (fees paid to external LPs) grows with depth.

Side effect seen during the repeat run: each round leaves one-sided free token0 that the rebalance can never redeploy. A one-sided mint plans 0 liquidity and there is no deficit to trigger a burn. So the sleeve drifts upward (free0 reached 640 against 568 deployed) and that capital earns no fees.

## Preconditions / severity
- The vault needs a sleeve (`liquidReservePercentage > 0`).
- The vault must be roughly 10% or more of in-range pool liquidity, or the attacker pays too much in fees to external LPs.
- A flash source deep enough to push the price.
- Any blocked-mode two-sided deposit, including one from an honest integrator, creates excess that anyone can JIT.
- No V3 FullSpread vault appears in the 4663 manifests (per the P2 notes), so this is latent.
- Severity: medium. If a vault were deployed, losses would be repeatable at about 1.5-4% of TVL per round.
- Not executed: the V4 hookless and Pons variants.

## Fix
- Do not let `rebalanceLiquidReserve` or the best-effort path mint at an unvalidated spot: add a TWAP/`observe` deviation guard, or bound the price against the last checkpoint.
- Alternatively, make blocked-mode deposits only exitable (or deployable) after a fair-price checkpoint.
- Minting only when slot0 is within X bps of a TWAP also closes the residual add-at-P' path.
