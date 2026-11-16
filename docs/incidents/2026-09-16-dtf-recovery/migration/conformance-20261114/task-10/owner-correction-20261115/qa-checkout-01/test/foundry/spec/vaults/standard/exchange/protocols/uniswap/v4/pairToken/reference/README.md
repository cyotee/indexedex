# P1 exact arithmetic controls

The SUT is `UniswapV4PairTokenStandardExchangeVaultMath`, not the standalone
PairToken baseline. `math_oracle.py` uses Python unbounded integers and
`fractions.Fraction` directly from the stage-one equations. It neither imports
production arithmetic nor runs Forge/FFI. Seed: `20261028`.

Run `python3 math_oracle.py` from this directory to verify all checked-in
vectors. Run `python3 math_oracle.py fixtures` to print replacement JSON;
the script never writes files. Install replacements with the normal patch tool.

## Fixture rows

`vectors.json` is compact, flat numeric JSON consumed by Foundry:

| Key | Width | Columns |
| --- | --- | --- |
| amounts | 8 | price, lower, upper, liquidity, principal0, principal1, cost0, cost1 |
| liquidity | 7 | price, lower, upper, amount0, amount1, success, result |
| paired | 8 | supply, reserve0, reserve1, max0, max1, shares, accepted0, accepted1 |
| credit | 7 | supply, reserve0, reserve1, credit0, credit1, cap, shares |
| zap | 7 | supply, reserve0, reserve1, credit0, credit1, status, shares |
| allocation | 8 | supply, shares, liquidity, idle0, idle1, removed, allocated0, allocated1 |
| compound | 9 | price, lower, upper, idle0, idle1, activeLiquidity, maxZapBps, zeroForOne, amount |
| rates | 7 | price, amount0, amount1, supply, token0, success, rate |

Success is `1` or `0`. Zap status is `1` for success, `2` for zero shares,
and `0` for final-result overflow. Failed results use zero only as a fixture
placeholder; the Solidity consumer checks exact revert bytes.

## Arithmetic boundary and API

All eleven functions are public/view linked-library functions with primitive
scalar arguments. Their arithmetic cores remain pure. The view boundary rejects
direct library execution with `DirectCallNotAllowed`; product calls delegatecall
the package-bound implementation.

```solidity
principal(uint160 price, uint160 lower, uint160 upper, uint128 liquidity)
    returns (uint256 amount0, uint256 amount1);
costs(uint160 price, uint160 lower, uint160 upper, uint128 liquidity)
    returns (uint256 amount0, uint256 amount1);
liquidityForAmounts(uint160 price, uint160 lower, uint160 upper,
    uint256 amount0, uint256 amount1) returns (uint128 liquidity);
tryLiquidityForAmounts(uint160 price, uint160 lower, uint160 upper,
    uint256 amount0, uint256 amount1) returns (bool fits, uint128 liquidity);
pairedQuote(uint256 supply, uint256 reserve0, uint256 reserve1,
    uint256 max0, uint256 max1) returns (uint256 shares, uint256 used0, uint256 used1);
credit(uint256 supply, uint256 r0, uint256 r1, uint256 c0, uint256 c1,
    uint256 cap) returns (uint256 shares);
zapCredit(uint256 supply, uint256 r0, uint256 r1, uint256 c0, uint256 c1)
    returns (uint256 shares);
allocation(uint256 supply, uint256 shares, uint128 liquidity,
    uint256 idle0, uint256 idle1) returns (uint128 removed, uint256 amount0, uint256 amount1);
compoundSwap(uint160 price, uint160 lower, uint160 upper,
    uint256 idle0, uint256 idle1, uint128 activeLiquidity, uint16 maxZapBps)
    returns (bool zeroForOne, uint256 amount);
tryCompoundSwap(uint160 price, uint160 lower, uint160 upper,
    uint256 idle0, uint256 idle1, uint128 activeLiquidity, uint16 maxZapBps)
    returns (bool fits, bool zeroForOne, uint256 amount);
accountingRate(uint160 price, uint256 a0, uint256 a1, uint256 supply, bool token0)
    returns (uint256 rate);
```

- `credit` always treats its cap as a real cap, including `uint256.max`.
  `zapCredit` is uncapped and rejects a mathematically overflowing minimum.
- Positive-supply paired and credited zero-share results reject. A zero-reserve
  leg imposes no credit constraint; both zero reserves reject.
- `pairedQuote` preserves checked genesis multiplication and full accepted
  live-leg maxima in one-sided states. The planner checks positive genesis
  fundable liquidity and `supply + actual minted q` after the final credit cap.
- Bounds are ordered and strictly positive. Principal/costs clamp the current
  price to them. Liquidity sizing preserves canonical conservative floor-product
  arithmetic, but narrows only the limiting quotient. It never clamps capacity.
  Signed addition, owned/active liquidity, tick gross/net capacities and signed
  principal/fee/net settlement domains require the planner's actual pool state.
- The two `try` helpers share their core with the normal reverting wrappers.
  `fits == false` means only that the limiting affordable liquidity exceeds
  uint128; outputs are zero on failure, never a saturated capacity. Invalid
  configuration bounds still revert. This permits typed maintenance failure
  classification without caught calls. A returned compound swap amount is at
  most `idle / 2`, so it fits positive int256; the planner still checks price
  interval and projected signed settlement domains itself.
- `compoundSwap` takes validated instance configuration. It preserves strict
  raw-unit dust, sequential floors, token0 ties, half leftover, zero-active
  branch, and quarter cap. If both balances are at most dust, its irrelevant
  zero-amount direction is `false`.
  The narrow-range sequential-versus-single-floor direction witness is a
  scalar math control, not a full-range product reachability claim.
- Math-local errors are `InvalidPrice`, `InvalidAccountingState`, `ZeroShares`,
  `InvalidAllocation`, `LiquidityOverflow`, and `ArithmeticOverflow`.
  Genesis checked multiplication retains `Panic(0x11)`. These helpers do not
  classify a planner failure as withdrawal-maintenance fallback.

## Wide-value proof and limits

For `0 < P < 2^160` and uint256 assets, `P*P*A0 < 2^576`.
The token1 path retains three limbs until the one shift by 192, giving a
conversion below `2^384`. Token0's numerator `A1<<192` is below `2^448`;
division by positive `P*P` cannot increase it. Adding the other asset and
scaling by `1e18 < 2^60` remains below `2^509`, inside two limbs.
The restoring divider processes at most 512 bits and retains both quotient
limbs. Its divisors are below `2^320`; the remainder invariant bounds the
shifted remainder below `2^321`. Low-word subtraction carries an explicit
borrow. Only the final public rate narrows to uint256.

The compound comparison intentionally uses two Q96 floors instead. Its first
quotient is below `2^320`; multiplying again by a uint160 price stays below
`2^480`, so both stages also fit two limbs.

## Coverage classification

- Preserved: canonical/baseline interior amounts and affordable sizing on their
  common cast-admitted domain; candidate paired rules; baseline compound sizing.
- Intentional deviations: clamped endpoints; no eager non-limiting overflow
  rejection; all genesis shares; zero-book positive supply rejects.
- New capability: actual contribution credit, uncapped versus capped overflow
  handling, full proportional allocation, exact raw SY valuation with late
  narrowing.
- Unsupported scope: baseline fee/dead-share/retention behavior, proxy execution,
  fee checkpoints, actual manager receipts/capacity/fallback classification.

The Solidity suite replays every fixture and adds deterministic exact controls,
bounded fuzz checks, baseline/canonical comparisons, both wide-intermediate
representable rates, genuinely overflowing final rates, and canonical SY helper
rounding/overflow domains for 6/8/18-decimal metadata. Pure math evidence does
not complete product A32 or A45; those still need the parent's registered-proxy
and real-manager integration runs. No Forge command was run by this worker.
