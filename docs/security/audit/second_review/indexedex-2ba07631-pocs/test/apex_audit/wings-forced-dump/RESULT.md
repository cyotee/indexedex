# wings-forced-dump (P2: wings-forced-dump-rebalance)

Status: CONFIRMED for the redeem `_fund -> _swapDeficit` path. REFUTED by execution for the permissionless `rebalance` sandwich path.

## Setup
Fixture: the real TestBase_UniswapV4UpperLowerWingsStandardExchangeVault (real PoolManager, hookless 0.3% pool, tickSpacing 60), oracle sleeve 20% (same as the repo's rebalance spec), target token0 vault (wings0). An external full-range LP provides L=1e18 (re-run at 3e18). Honest holders deposit, and a keeper rebalances until the book settles. External arbitrage returns the pool to the fair price (sqrtP = 2^96) before any attack. All attacker and searcher actors are fresh unprivileged contracts. Their capital is minted to them and counted. Profit is the net change in token0+token1 valued at the fair price, and the price is required to be restored exactly.

## Redeem path, confirmed (WingsRedeemDump.t.sol)
Bug: if a redemption exceeds local target + target wing + core target principal, `_fund` closes the core and then `_swapDeficit` sells the vault's ENTIRE opposing balance exact-in with a MIN/MAX price limit. In the test the shortfall was about 2.7e16, but it sold about 1.1e17 token1. The remaining holders' share of the opposing inventory is therefore sold at a heavily slipped price. `HolderValueLoss` cannot catch this, because it compares against a liquidation quote that already assumes a full dump at that same price.

- test_PoC_redeemForcedDumpBackrun (L=1e18; holders deposit 2e17 and 1e17; the 2e17 holder exits with min = 99% of the fair quote):
  - back-run only: searcher +1.428e16 (fair value); staying holder fair mark 9.448e16 -> 8.948e16 (-5.00e15, about 5.3%)
  - front-run of 200 ticks (inside the exiter's 1% slippage) + back-run: searcher +1.663e16; staying holder -5.81e15 (614 bps)
  - control: a 50%-of-supply exit (no core close, no dump) leaves the staying holder better off (+5.0e15)
  - sweep at L=3e18: back-run +5.27e15, staying holder -2.02e15 (about 2.1%)
- test_PoC_forcedDumpSelfTriggered: one tx, no prior shares. Attacker contract deposits 2e17, calls the permissionless rebalance, redeems all, then back-runs to the fair price. Attacker net +1.428e15; honest holder (1e17 deposit) fair mark 9.791e16 -> 9.574e16 (-2.17e15, about 2.2%). It is also profitable at 4e17 (+1.03e15) and 8e17 (+3.4e14). It does not trigger at 1e17.

## Rebalance path, refuted (WingsForcedDump.t.sol::test_sweep)
Sweep: push ±400/1000/2000/4000 ticks, call rebalance(0) as an unprivileged contract, restore the price. Vault deposits 1e16, 1e17 and 3e17 against L=1e18. The attacker loses money in every case. Compared with the same round trip without the rebalance, adding the rebalance made the attacker worse off in every case (for example -9.1e14 extra at 3e17 / -4000 ticks), and the vault ended with a higher liquidation value. The full-range core re-placement and the bounded `bestSwap` (priced at the projected sale price) do not hand the attacker value. The attacker's own round-trip fees dominate, and the vault earns those fees as an LP.

## Preconditions / caveats
- The family is new in this diff and not deployed on any manifest network, so this is pre-deployment / design-level.
- Requires an exit large enough to force a core close (more than about 52% of supply here), or an attacker with enough capital to create one. Loss scales with how large the vault's opposing inventory is relative to external depth (5.3% of staying-holder value at 15% of pool TVL, 2.1% at about 5%).

## Fix
In `_swapDeficit`, swap only the shortfall (an exact-output swap for `required_ - localTarget`, with a bounded input), not the whole opposing balance. Add a price limit tied to a pre-tx or reference price. Bound the remaining-holder check against a fair or reference mark rather than a liquidation quote taken at the same pool state.

Run: forge test .../wings-forced-dump/WingsRedeemDump.t.sol -vv --match-test PoC ; forge test .../wings-forced-dump/WingsForcedDump.t.sol -vv
