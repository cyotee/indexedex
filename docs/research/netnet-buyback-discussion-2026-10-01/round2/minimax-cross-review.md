# MiniMax M3 — Round 2 cross-review

Read `docs/research/netnet-buyback-discussion-2026-10-01/round2/{astra,grok,kimi}-original.md` only. No peer cross-review artifacts read. Originals frozen. Source-checked against repo; not majority-vote.

## 1. Capacity max formula

**Agreed (Astra + Kimi).** Largest `n` with `floor(n·P/1e9) ≤ C` is `n_max = ((C+1)·1e9 − 1) / P` (integer division). Astra's `bCap = ceil((C+1)·U/P) − 1` (`U=1e9`) is algebraically identical. `floor(C·1e9/P)` is unsafe).

**Correction to Grok.** Grok originals.md:19 says "Largest `n` with `floor(n*P/1e9) <= C` is not always `floor(C*1e9/P)`. Compute that candidate, then decrement while `mulDiv` exceeds `C`." Two errors: (a) `floor(C·1e9/P)` is generally far below the true max (when `P < 1e9`, the true max can exceed it by orders of magnitude); (b) the algorithm direction is wrong — start must be at or above the true max, then *increment/decrement* to find the boundary. The correct iterative search is `for (n = floor(C*1e9/P); mulDiv(n,P;1e9) <= C; n++)` (forward), then `n-1`. Or use the closed form.

## 2. Marginal vs average-price

**Agreed (all four).** Pool marginal USDG/NET decreases with trade size; IB marginal is flat. Interior optimum equalizes marginals; average-price comparison over-uses IB at the start (because pool avg > pool marginal). The toy closed form in my Round-2 originals.md:§1 only equalizes for sale-only Objective A; the zap objective in §1 also stated `(n−n_ib−n_pool)/(u_ib+u_pool) = (x+n_pool)/(y−u_pool)`, which is the **deposit-ratio** — Grok originals.md:56 and Kimi originals.md:43 both sharpen this as the correct constraint, Kimi noting the recursive dependence (sold amount affects post-pool reserves which affect the ratio).

**Correction to my own Round-2.** I framed the constraint correctly but did not derive a closed form for the mixed (IB+pool) zap objective. Kimi originals.md:49 explicitly states "**no existing solver; uniqueness/concavity of the integer objective is an unproven gap**" and recommends evaluating Mode B (IB-only) vs Mode C (pool-only) plus the mixed stationary point's integer neighborhood. This is the honest engineering posture.

## 3. Tax formula `g − floor(g·t/D)`

**Agreed (all four).** Net transfer receipt is `g − floor(g·t/10000)` with `t=500`, `D=10000`. `floor(g·(1−t/D))` would be the rounding-**wrong** formulation because tax is the *integer-floored* portion, not a fractional net. The peers correctly cite `NET.sol:131–145` and Kimi originals.md:7 writes `a = g − floor(g·t/D)` explicitly. Minimum gross for net `n`: `floor((n−1)·D/(D−t)) + 1` per Plan §6.5.4 and Astra originals.md:25.

## 4. Protocol fee — exact helper vs QuoteTarget helper

**Counterexample to Grok.** Grok originals.md:62 says "Do not copy QuoteTarget's `_calculateProtocolFee` plus `UNISWAP_PROTOCOL_FEE_SHARE = 16667`; that is a different formula from canonical Uni V2." This is wrong. Source: `ConstProdUtils.sol:951–960`:

```text
if (ownerFeeShare >= 16666 && ownerFeeShare <= 16667) {
    return (lpTotalSupply * (uniRootK - rootKLast)) / (uniDen);
}
```

With `ownerFeeShare=16667`, `_calculateProtocolFee` *is* the canonical Uni V2 formula `lpTotalSupply·(√k − √kLast)/(5·√k + √kLast)` — see `ConstProdUtils.sol:953–959` and the comment at `:951–952`. The `_calculateProtocolFeeMint` at `:984–996` is the standalone helper with the same math, used when `kLast`-only is available. Both helpers converge on the canonical formula when called with the right `ownerFeeShare`/`kLast`.

**Caveat Grok is right about.** The constant `16667` is a per-pair parameter from `setFeeTo(target)/setFeeToSetter(toggle)` and is queried via `_quoteFeeTo()` in the QuoteTarget. The QuoteTarget's `UNISWAP_PROTOCOL_FEE_SHARE = 16667` is a hardcoded constant, not a live per-pair reading. The bounded design must mirror the QuoteTarget's `if (recipient_ != address(0))` gate (`QuoteTarget.sol:212–223`) or read the live pair-level parameter.

## 5. Router leftover vs refund — **token-level correction to Grok**

Grok originals.md:64: "Router `addLiquidity` refunds the overweight token to `msg.sender` (the vault)." **Wrong for tokens.** Source: `UniV2Router02.sol:41–68` (`_addLiquidity`) computes `(amountA, amountB)` and at `:82–83` does `TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA)` (not `amountADesired`). The unused `amountADesired − amountA` stays at `msg.sender` (vault). Only `addLiquidityETH` (`:109–110`) explicitly refunds excess ETH. Kimi originals.md:105 is closer to truth ("integer dust… is the **user's**"). The bounded design must explicitly forward the `amountDesired − amountOptimal` residual from vault back to the user (or to the user's pretransfer credit).

## 6. Order dependence k-fee/NAV

**Counterexample to Kimi (small).** Kimi originals.md:11: "pool sells do **not** change backing `B`" — because POL RFV = `2√(x·y)` is k-invariant under the no-fee idealization. **But pool fees stay in the pool** (V2 swap fee accrues to LPs), so post-swap `k_new > k_old` and `2√(x_new·y_new) > 2√(x_old·y_old)`. Treasury's POL NAV rises (slightly) after a pool swap. Source: `Treasury.sol:92–103`; canonical V2 `swap()` retains `fee*input` in pool. The "pool-first makes next IB quote slightly worse" framing (Kimi originals.md:34) is the dominant effect, but pool-first *also* raises POL NAV. Net effect of pool-first then IB: capacity is conserved but `backingPerToken` rises slightly, slightly raising IB price. **Practical impact small**, but Kimi's reasoning needs the pool-fee-into-k nuance.

Grok originals.md:37: "Pool-first therefore makes the following bid slightly worse" is the **correct** first-order framing. Grok is right.

## 7. Direction of economic benefit — to SELLER

**Correction to Grok.** Grok originals.md:35: "Repeated bid calls are dominated." This is too strong. Each fill raises `backingPerToken` (smaller supply, same RFV); next call sees higher `P`. But next call also consumes remaining cap. Whether repeating is dominated depends on (a) price rise per NET burned vs (b) per-NET slippage across fills.

**Toy counterexample.** Suppose `R = 1000`, `S = 1000` NET, `δ = 0.985`, no Morpho. `B = 1.0`. Single fill of `b` NET: payout = `floor(b·0.985)`, new `B' = (1000 − floor(b·0.985)) / (1000 − b) > 1.0` (since `floor(b·0.985) < b` for any `b ≥ 1`). Two fills `b1, b2`: average price `(floor(b1·0.985) + floor(b2·B_after_1·0.985)) / (b1 + b2)` may exceed single-fill `floor((b1+b2)·0.985) / (b1+b2)` due to per-fill backing accretion. **Two smaller fills can pay slightly more** than one larger fill, when cap permits. The bounded design should not assume strict dominance; the bounded release should size one fill per operation but allow per-operation retry logic if and only if the same tx routes pool-only (no double IB).

## 8. No guaranteed preview across blocks

**Agreed (all four).** Snapshot at operation entry; preview returns canonical floor; IB is opportunistic upper bound. No cross-block queuing. PRD R11 atomicity. Grok originals.md:72 and Kimi originals.md:66 align.

## 9. Stock zap helper vs tax/exogenous USDG

**Agreed (Grok + Kimi).** `_swapDepositSaleAmt` (`ConstProdUtils.sol:457–474`) solves the quadratic for the pool-only zap. With exogenous USDG from IB, the constraint `(T−x−g)·(1−t) / (x·p + Q(g)) = (rN + g·(1−t)) / (rU − Q(g))` changes (Kimi originals.md:43–46). Stock helper **cannot** be reused unchanged for Mode M (mixed). Mode B (IB-only) and Mode C (pool-only) inherit the existing structure. Astra originals.md:89: "Do not feed gross NET/USDG into stock addLiquidity and assume proportional receipt." ✓

## 10. Refund policy vs reference no exact-in maximum refunds

**Agreed (Astra + Kimi).** Reference: exact-input pretransfer refunds no unused maximum; exact-output refunds bounded credited-minus-used (`BasicVaultCommon.sol:108–137`; Plan §6.3:331–335). The bounded split design must preserve this asymmetry. Astra originals.md:97 is precise.

## 11. Exact-output parity

**Agreed.** IB exact-output is `n = ceil(y · 10^(18−usdgDec) · 1e9 / P)` minimum-sufficient (Astra originals.md:101; Kimi originals.md:61). Pool-side exact-output uses `_purchaseQuote` (`ConstProdUtils.sol:206`) plus tax gross-up `floor((y−1)·D/(D−t)) + 1`. Router supporting-fee has **no exact-output** (Context7 `/uniswap/docs`, Grok originals.md:23). The bounded design must use direct-pair + supporting-fee router for in-leg and accept the asymmetry.

## 13. Residual treasury rounding dust

**Agreed.** USDG `wei` (one sub-WAD unit) from `usdgOutRaw = floor(payoutWad / 10^(18−usdgDec))` is stuck at the IB contract, not forwarded to the treasury or the SE. InverseBond burns the *nominal* `netAmount`, pays that truncated UT to msg.sender, and does not credit the dust anywhere — `InverseBond.sol:75–89`. The dust is **not** the SE's property and is not the user's property. It is permanently stuck in InverseBond until the next fill's `payoutWad += floor(n·P/1e9)` accrues a sub-USDG remainder that no future fill can recover. **Engineering decision (Round-1 unresolved, still open):** the SE must not advertise USDG out including this dust; previews return floor; promotions are explicit. (Astra originals.md:97 and Kimi originals.md:51 align.)

## 14. Agreement summary (round 2)

- Finite-capacity split with `n_max = ((C+1)·1e9 − 1) / P` is the correct integer bound. **3-of-4.**
- Marginal-not-average optimization. **4-of-4.**
- Tax formula `g − floor(g·t/D)`. **4-of-4.**
- Reference fee is 300/100_000 = 0.30% (PPHK), not 300 bps. **3-of-4 (Grok + Kimi + me; Astra uses 997/1000 form which is equivalent).**
- Stock zap helper (`_swapDepositSaleAmt`) does not handle tax/exogenous USDG. **3-of-4 (Grok + Kimi + me).**
- No cross-block preview guarantees. **4-of-4.**
- Exact-input pretransfer no-unused-maximum refund; exact-output bounded credited-minus-used refund. **3-of-4 (Astra + Kimi + me).**
- Residual dust is not SE property. **3-of-4.**

## 15. Dissent summary

- **Grok originals.md:62** (QuoteTarget fee is "different formula"): **wrong**; `_calculateProtocolFee` with `ownerFeeShare=16667` is the canonical Uni V2 formula.
- **Grok originals.md:64** (Router addLiquidity refunds overweight token): **wrong** for token pairs (only ETH refunds).
- **Grok originals.md:35** ("Repeated bid calls are dominated"): **too strong**; per-fill `backingPerToken` accretion means smaller fills may pay better than one large fill up to cap, all else equal.
- **Kimi originals.md:11** (Pool sells do not change backing B): **mostly right but small counterexample**; pool fees stay in pool, raising `2√(x·y)` slightly.
- **Astra originals.md:60** (gross deposit ratio is `d/Q = X'/(h·Y')`): matches my §1 deposit-ratio constraint only if `h = 1`. With SE→pair taxed (h ≠ 1 unless SE exempt), the ratio uses received-amount numerators, not nominal. Astra's continuous toy assumes untaxed; the bounded design must read live `isTaxExempt(SE)`.

## 16. Open product vs engineering (carried from originals)

**Product:** tie-break policy (pool vs IB when equal); preview guarantee semantics (canonical floor only vs canonical-plus-unbound-upper); vault tax-exempt status; zap-out SDK acceptance; residual dust ownership statement.

**Engineering:** integer solver proof for Mode M (mixed zap); unimodality/concavity under floors; per-operation retry safety (no cross-block preview reuse); live `decimals()` and tax-predicate reads; `_calculateProtocolFee` vs `_calculateProtocolFeeMint` selection; residual `addLiquidity` forward-back to user; live source-equivalence (G1).

## Sources cited (path:lines)

- `ConstProdUtils.sol:140–217,419–474,950–996,1013–1022` (PPHK fee, _swapDepositSaleAmt quadratic, _calculateProtocolFee canonical, _calculateProtocolFeeMint, _equivLiquidity)
- `Constants.sol:34–37,40` (`UNISWAPV2_FEE_DENOMINATOR = 100_000`, `UNISWAP_PROTOCOL_FEE_SHARE = 16667`)
- `UniV2Router02.sol:41–85,109–110` (`_addLiquidity` no token refund, ETH refund)
- `UniswapV2Service.sol:339–414` (`_swapDeposit`, `_calculateSwapAmount` → `_swapDepositSaleAmt`)
- `UniswapV2StandardExchangeQuoteTarget.sol:200–271` (`_quoteMintPoolFee`, `_quoteAssets`, `_quoteDeposit`, `_quoteWithdraw`)
- `InverseBond.sol:68–89,108–139` (`swap`, `price`, capacity)
- `IInverseBond.sol:16–37`
- `Treasury.sol:84–147` (RFV, POL, Morpho unwind)
- `NET.sol:131–145,188–221,231` (tax predicate, factory validation, pair exemption disabled)
- `Constants.sol:17,42,64,67` (`EPOCH_LENGTH`, `INVERSE_SPREAD_BPS`, `INVERSE_EPOCH_CAP_BPS`)
- `ROBINHOOD_MAIN.sol:29,459–476` (deployment-pinning)
- Peers (untrusted): `docs/research/netnet-buyback-discussion-2026-10-01/round2/{astra,grok,kimi}-original.md`

No peer cross-review artifacts read; originals frozen; bounded round complete.