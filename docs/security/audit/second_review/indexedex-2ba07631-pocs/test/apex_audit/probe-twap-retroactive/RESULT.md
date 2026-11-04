# probe-twap-retroactive (hunt-twap-retroactive-current-tick)

Status: the mechanism is CONFIRMED by execution. Impact is CONDITIONAL: no protocol contract and no deployment uses the TWAP as a price source.

## What I ran
- File: TwapRetroactive.t.sol. Fixture: TestBase_UniswapV4MultiPoolTwapOracle, which deploys a real v4 PoolManager and the oracle DFPkg instance.
- Pool: full range, 1M/1M tokens, fee 3000. Oracle cardinality raised to 8 (this is permissionless). W = 1800 and the pool had an idle gap of at least W.
- The attacker is an unprivileged contract. Inside its own PoolManager.unlock it swaps the tick up by more than 9116, calls `update(key)`, swaps back to the exact original sqrtPrice, and settles the net deltas.

## Results (both tests PASS)
- `test_mechanism_restoredSpot_skewedTwap`:
  - Spot sqrtPrice is restored exactly.
  - `consult(id,1800) = 9116`, so the whole 1800 s window gets the manipulated tick.
  - The Morpho adapter `price() = 2.488e36`, against a fair value of 1e36. `writeAge = 0`, so the `maxWriteAge` check passes.
  - Attacker cost is fees only: about 1,109 token0 plus 1,757 token1, roughly 0.29% of one side's depth.
- `test_hypotheticalConsumer_profit`:
  - Setup: a minimal Morpho-like lender (LLTV 86%) priced by a factory-created `UniswapV4TwapMorphoOracle`. This lender is HYPOTHETICAL and is not part of the protocol.
  - The attacker posts 400k collateral and borrows 850k. Net profit at the fair price is +447,133 tokens. The lender's bad debt is 450k.

## Why the severity is low
- Nothing in contracts/ (outside the oracle and adapter files) calls consult, observe, writeAge or price. The fullSpread vaults only write to the oracle. scripts/ and deployments/ never wire UniswapV4TwapMorphoOracle or AggregatorV3Adapter into any market.
- The oracle library is unchanged in aca16198..2ba07631. The blocked-mode poke call sites added in the diff are not needed, because `update` is permissionless.
- The PRD (sections 10.2 and 10.3) documents the risk of dumping, poking and then consuming the price. The project's own adversarial test (`test_pokeThenRead_truncatesVsPrevTick`) asserts the 9116 clamp. The PRD's stated control, `maxWriteAge`, does not help here because the attacker's own write refreshes it.

## Suggested fix
Credit the elapsed interval with the tick that prevailed *before* the write: store the last tick and use `prevTick` for `(now - last)`, the way V3 accumulates the pre-swap tick. Then a manipulated tick only affects time that passes after the write. Optionally, refuse to write while the PoolManager is unlocked.
