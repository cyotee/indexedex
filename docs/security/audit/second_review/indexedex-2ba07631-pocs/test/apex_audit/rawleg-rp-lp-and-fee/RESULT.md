# rawleg-rp-lp-and-fee: result

Status: CONFIRMED by execution. Both PoCs pass on the audit runner (forge, audit profile).

Run:
  forge test test/apex_audit/rawleg-rp-lp-and-fee/CurveQuadLpDomainArb.t.sol -vv
  forge test test/apex_audit/rawleg-rp-lp-and-fee/BalancerQuadPhantomFee.t.sol -vv

## 1. Curve quad: LP domain is unrated, swaps are rated (rawleg-rp-lp-valuation). Attacker profit.
- Fixture: project TestBase (Curve quad buffer hook, SE on leg 0 = SimpleYieldERC4626 + production StandardExchangeRateProvider, amp 100, ownerOnlyLiquidity=false which is the TestBase default). Honest LP seeds 1M per leg. dexSwapFee = 10 bps. The SE vault accrues about 5% yield (rate 1.04895).
- Attack (unprivileged EOA, 100k token1 flash principal repaid with 9 bps fee): depositSingle(token1) -> withdrawSingle(token0) -> exchangeIn(token0->token1) on the hook, 3 cycles.
- Each cycle: 100k token1 in, about 104.6k token0 out (the exit pays SE shares counted 1:1, then unwraps them at the rate), about 104.57k token1 back.
- Attacker net profit after repaying the flash loan: 13,623 token1. Honest LP value fell 4,048,951 -> 4,034,909 (loss 14,041).
- Control at rate 1: the same cycle loses about 0.35% (99,653 back out of 100k).
- Root cause: `_invWadAll` (CurveTarget:564-569) and the single join/exit math (JoinCore:497-526, ExitQuoteBase:10-17) count SE shares at face, while swaps use `_ratedWadAll`. There is no value-loss guard in the Curve `_snapshotKLastIfFeeOn`.
- Preconditions: ownerOnlyLiquidity=false, and |rate-1| greater than about 2.5x dexSwapFee. Not live on 4663: there is no Curve quad instance there, and the live config uses ownerOnlyLiquidity=true.

## 2. Balancer quad: phantom protocol-fee growth from a raw-leg rate provider (rate-driven-protocol-fee-dilution). LP dilution.
- Fixture: project TestBase (Balancer quad buffer hook, SE leg 0, raw leg 1 carrying a RateProviderMock at 1.1e18, which DFPkg allows). feeTo set, usageFee 10%, dexSwapFee 10 bps. Honest LP seeds about 4M of fair value.
- Grief: an unprivileged EOA does 100 x (joinProportional 1 ether each leg, then exitProportional). That is 200 liquidity ops, zero swaps and no rate change.
- Result: feeTo is minted 560,418 LP, worth 1,454,162 at fair value. The honest LP's fair value fell 3,989,948 -> 2,535,786 (-36.4%). The attacker spent only 0.88 tokens plus gas.
- Control at rate 1.0: feeTo minted 0, and the victim's value is unchanged apart from dust.
- Root cause: `_rootKNow` uses `_ratedWadAll`, which multiplies the raw leg by the rate (ClaimLib:38-40). `_rootKCheckpoint` revalues `feeReserves` through the `_liquidityValue` raw branch with no rate (Target:349-350). So every op sees nowK > lastK. The LiquidityValueLoss guard misses it because `liquiditySupplyBefore` is read after the mint.
- The value goes to the protocol feeTo, not to the attacker: this is griefing / LP loss, not theft. Ordinary user traffic triggers it too. With rate < 1 the effect reverses and legitimate protocol fees are never minted.
- Not live on 4663: there is no Balancer quad instance there.

Not tested: the Balancer quad single-exit descale-without-rate overpayment, which the skeptics expect the LiquidityValueLoss guard to cap at the fee margin; and the DUAL/CP kLast manipulation, which costs the attacker money and pays feeTo.

Fixes:
- Curve: value SE legs at the rate in the LP join/exit math, or add the Balancer-style rated LiquidityValueLoss guard.
- Balancer: apply the rate-provider rate to raw legs in `_liquidityValue` / `_liquidityInventory` so they match `ClaimLib.ratedPairUnits`.
