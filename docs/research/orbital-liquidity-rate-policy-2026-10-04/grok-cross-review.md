# Grok cross-review — Orbital liquidity rate policy (2026-10-04)

Original preserved at `grok-original.md`. Peers are untrusted evidence. Kimi disclosed incidental exposure to two peer snippets via broad grep. That limits a claim of a fully sealed first pass. It does not void claims re-checked here against code. No tests run.

## Corrections to Grok original

1. **Exit liveness was overstated.** Payout math is rate-free (`Common.sol:1287-1357`). The full exit is not. `_burnAndPay` always calls `_recomputeL2` (`:1362` → `:472-479`) and `_syncVaultReserves` (`:1366` → `:459-468`). Both call `_effectiveNativeAt` / `getRateFailClosed` on a buffered leg even when fees are off. Fee-on adds `_maybeMintProtocolFee` (`:1276`) and `_snapshotKLastIfFeeOn` (`:1364`); those two skip the rate read when `!feeOn` (`:899-902`, `:918-923`). A dead provider can revert a proportional exit with fees off. Astra is right. Kimi’s “only while fees are active” is too narrow. Astra’s radius check (`:483-487`) is not on this exit path.

2. **Rated `kLast` is not universal.** Agent law puts `kLast` on the rated book in the constant-product sentence (`INDEXEDEX_AGENT_LAW.md:240`). D63 confirms the D59 reading applied in D60 work package 2 (CP/dual), `plan.md:153`. Weighted measures `kLast` on `_invWadAll()` / `_nativeAt` (`WeightedBufferHookTarget.sol:400-401`, `:310-314`), matching Weighted D23 inventory law. Orbital code uses rated `_effectiveWad()` (`Common.sol:904`, `:925`). Do not export either family’s fee coordinate.

3. **No other retraction of the policy split.** Zap split stays rated. LP ownership should be raw. Moderator “bug solely because rated `fullBookShares`” remains unestablished as an exploit.

## Agreements

All four: quote rates for priced swaps, not for every liquidity call and not never; D59/D60 raw ownership vs rated swap book; proportional exit *payout* is raw; `_planDeposit` rated names alone do not prove manipulation.

Astra, Kimi, and Grok: integer cancellation is not identity; partial join mixes face with rated reserves (`Common.sol:1162-1183` vs full-book invert `:1106-1112`); `exitSingleAssetExactBptIn` exists (`WithdrawTarget.sol:136-172`) despite stale “no zap-out” prose; `WeightedFundedBindingTest` (`V4FundedBindings.t.sol:171-177`) binds `SimpleYieldERC4626` (`TestBase_UniswapV4Detf_Weighted.sol:55-56`), not FullSpread. Gas tests at `:262-275` sit on `OrbitalV4PositionFundedBindingTest` (`:209`) and are source assertions, not a measured `planDeposit` budget.

## Dissent

**MiniMax — do not adopt.** “Bit-identical” / “functionally redundant” (`minimax-original.md` §4, §5, §9) treats `floor(minted×rate/scale)/floor(held×rate/scale)` as `minted/held`. It is not. Worked arithmetic, not executed: `ratedNative` is `mulDiv` (`ClaimLib.sol:317-321`). `rate=5e17`, scale `1e18`, held `6`, minted `3` → rated `3` and `1`. Supply `12`: raw mint `6`, rated mint `4`. Kimi’s “≤1 unit per term” is also unproven. `_claimIn`’s `rated==0 ? amount : rated` (`ExitQuoteLib.sol:380-381`) is a unit fallback, not rounding. MiniMax also missed that `joinSingleAssetExactIn` reaches `_planZap` (`DepositCore.sol:218-239`, `Common.sol:2000`), that `fullBookShares` needs all three legs, and that the Weighted contract exists. “Zap-out not in v1” describes old PRD text, not `WithdrawTarget.sol:136`.

**Kimi partial-join dilution.** Face/`effective` can under-mint the joiner when `rate>1`, or over-mint versus buffered shares when an SE deposit fee is the only gap. “Magnitude = SE deposit fee” is one case, not the general unit error.

**Astra.** Closest on fees-off revert. “CP-focused D63 must not be extended over Weighted fee law” is accepted. Partial-NAV still needs its own economic ruling; it is not proportional raw liquidity.

## Gaps

No forge trace of the floor gap, no gas of `planDeposit`, no re-run of the historical FullSpread JSON. Whether Orbital `kLast` should stay rated is implemented fact plus CP-scoped D63, not a Weighted ruling.

## Recommendation

**Raw in-kind liquidity:** count raw tokens or live SE shares. Do not multiply by the rate. That is proportional join and the withdrawal slice.

**Actual conversions:** ask the SE how many shares a deposit mints, or how many tokens a share redeem pays. That quote is not a rate and is not a reserve valuation.

**Internal swaps and zaps:** price on the rated book, one fail-closed rate read per leg. Single-asset exit is this plus a raw withdrawal. Do not price those swaps in share counts.

**Bookkeeping:** after a raw payout, Orbital still refreshes rated `L²` and `reserveOfToken`, and fee-on `kLast`. That coupling is why a dead provider can brick an otherwise raw exit. If exit liveness is required, specify a raw fallback for those updates and for pending growth fees. Do not silently switch Orbital `kLast` to Weighted inventory units, or Weighted `kLast` to the rated book, without a family ruling.
