# Grok round-2 cross-review

Originals frozen. Peers are untrusted evidence. No live RPC. Human selected capacity splits; mixed zap-in stays in scope as research with an unproven solver, not a silent deletion.

## Agreement

Contract callers may `swap`; there is no partial-fill ABI (`InverseBond.sol:68–89`). Cap is WAD, snapshotted on the epoch’s first fill, debited by `payoutWad` not raw USDG (`:76–80,135–139`). TWAP gates liveness only. User→vault and vault→InverseBond are untaxed if neither endpoint is a taxed pair; post-wire `addTaxedPair` cannot map the vault (`NET.sol:131–145,201–219`). Vault→pair is taxed unless exempt. DETF NET/sNET input stays Keep-YT; this zap is an SE NET deposit, not that path. USDG-funded entry cannot use the bid. Accounting rates must not mark unowned capacity. One execution policy is not a global-optimality proof.

## Capacity max and nested floors

Astra’s `ceil((C+1)*U/P)-1` and Kimi’s `floor(((C+1)*U-1)/P)` are the same integer for `P>0`. Both dominate `floor(C*U/P)`, which my round-2 used only as a candidate plus a decrement. `FixedPointMath.mulDiv` is floor, so the closed bound matches `w(b)=floor(b*P/1e9)<=C` if it does not overflow. **Nested floor:** `q=floor(w/F)` can be 0 while `w>0`. That fill consumes cap and pays nothing. Do not send it. The unpaid `w-q*F` is not a token. `spendUsdg` transfers only `usdgOutRaw` (`Treasury.sol:135–146`). MiniMax’s vault/caller/stuck **token** dust options invent a balance. It is capacity dust, not SE property.

## Tax identity — correction to me and to linear `(1-t)`

Executable receipt is `g-floor(g*t/D)`, `t=500`, `D=10000` (`NET.sol:136–143`). It is not `floor(g*9500/10000)`.

Counterexample: `g=10001`. Tax `floor(10001*500/10000)=500`, received `9501`. `floor(10001*9500/10000)=9500`. Off by 1.

My round-2 `floor(nS*9500/10000)` is wrong. Kimi’s section 1 uses the correct difference, but Mode B’s `(T-x)(1-t)` is toy-only. Astra’s `T(g)` and inverse `floor((n-1)*D/(D-t))+1` match the code. Checked: net `9500` needs gross `9999`, not `10000`.

## Marginal, average, zap objective

For a pure sale, equalize **marginal** pool output to `p`, then clamp to cap. At size 0, average equals marginal, so a zero-size screen is valid. Interior tests are not.

MiniMax’s `r_pool_µ(s)=997*y/(1000*x+997*s)` is **average** `out/s`, not `d(out)/ds=997*y*1000*x/(1000*x+997*s)^2`. Using average under-uses the bid. Kimi’s `m(g)` and Astra’s `f'(m)` are the right sale derivatives. “Always exhaust cap if `p` beats spot” is false once impact makes marginal fall through `p` before cap.

Zap objective is final user shares, not USDG. Astra’s `dL/dm=0` is not `f'=p`. Exhausting cap can destroy LP.

Toy counterexample, no tax, no fee, `X=Y=100`, `p=1`, `A=100`, huge cap. Ratio-balanced bid-only sale is `b=A*Y/(p*X+Y)=50`, LP large. Selling all `100` through the bid leaves no NET to deposit and mints ~0 LP. MiniMax’s zap rule “exhaust IB if `r_ib>r_pool_µ(0)`” fails that case. Mixed Mode M stays requested; uniqueness is unproven. Do not drop it, and do not ship stock `_swapDepositSaleAmt(G)` as the mixed solver.

## Stock helpers

`_swapDepositSaleAmt` (`ConstProdUtils.sol:457–473`) and `_quoteSwapDepositWithFee` (`:381–383`) add the full sold amount to reserves and ignore exogenous USDG. `_quoteDeposit` does the same (`QuoteTarget.sol:225–233`). Kimi’s “Mode C fully reusable” fails once the sale hop is taxed. Reuse the pool quote only on post-tax arrived input, after subtracting bid NET and adding bid USDG outside `k`.

## Protocol fee

Stub `mint` uses `supply*(rootK-rootKLast)/(5*rootK+rootKLast)` (`UniV2Pair.sol:233–245,284–285`), matching `_calculateProtocolFeeMint` (`ConstProdUtils.sol:984–995`). QuoteTarget `_quoteMintPoolFee` calls `_calculateProtocolFee` with `UNISWAP_PROTOCOL_FEE_SHARE=16667` (`QuoteTarget.sol:212–217`, `ConstProdUtils.sol:962–969`). Those integers differ.

Counterexample: `supply=1000`, `rootK=1000`, `rootKLast=1`. Exact mint floors to **199**. The quote helper floors to **200**. MiniMax’s “reuse `_quoteMintPoolFee`, do not re-derive” is not execution parity. Project the 1/6 helper. Fee-off stub clears local `kLast_`, not storage `_kLast` (`UniV2Pair.sol:249–250`). Do not treat that port as an upstream oracle. Astra’s audit note holds for the stub I read.

## Router leftover vs reference refund

Local `addLiquidity` pulls only the optimal amounts (`UniV2Router02.sol:70–84`). It does not push a refund. Excess never leaves the vault. Reference `_refundExcess` pays only exact-out pretransfer `max-used`, capped by unbooked surplus, and says leftover push surplus is absorbed at sync (`BasicVaultCommon.sol:108–137`). Exact-in has no unused-maximum refund.

My round-2 “router refunds leftovers to the user” overstated this. Kimi’s “dust is the user’s” is a **new** policy, not current exact-in law. Astra is right: returning conversion leftovers to the funding caller is an amendment. If unspecified, sync books them into share backing. That choice changes who owns the residual. Do not silently donate, and do not pretend the reference already refunds exact-in dust.

## Order and repeated fills — corrections

Kimi: pool sales do not change backing because POL is k-invariant. False for fee-retaining swaps. `polRfv` is `2*sqrt(x*y)` (`Treasury.sol:94–102`). The 0.3% fee increases `k` and, if the treasury holds LP, increases RFV before a later `price()`. Tax to TaxCollector does not raise `liquidUsdg` or the snapshotted cap.

**Seller direction:** pool-first leaves pair reserves for the pool leg unchanged by the bid, and slightly **raises** the later bid. That is weakly better for the seller than buyback-first, opposite my round-2 claim. If treasury LP is zero, the k effect on NAV is zero. Buyback-first is a fail-fast policy, not a seller-payout optimum. Astra’s `p(m)` term is the right warning. MiniMax’s “IB-first then `c_rem` drops to zero” is false unless that fill exhausts cap.

**Repeated fills are not dominated.** Toy, ignore `F`, `R=1000`, `S=100`, `δ=0.985`, sell 10 NET, cap slack. One call pays `98.5`. Two calls of 5 pay `49.25` then about `49.289`, total **98.539**. Later fills can pay the seller more because NAV rose. Kimi’s “no benefit” and my “one call dominates” are false. If cap binds, the second call consumes more wad per NET, so the USDG total can go either way. One call is a gas and rounding policy Astra correctly refuses to call global. Micro-fills also burn cap on `w` not paid as raw USDG. Product choice, not a theorem.

## Previews, exact-out, fallback

No quote is guaranteed across blocks: reserves, cap, exemption, and oracle move. Same-transaction re-read before effects is required. MiniMax both reverts the whole tx on bid failure (step 7, citing R11) and describes pool fallback (steps 98–99). R11 does not govern this venue choice. If the committed minimum is the split quote, pool-only fallback can miss it and must revert. If the committed minimum is canonical, same-tx pool fallback can preserve it. Those are different products. Do not cite a prior-round “consensus” as authority.

Exact-out has no InverseBond selector. Inverse is `ceil` replay of both floors, with scale `F`, not Kimi’s hardcoded `1e12`. Supporting-fee router is exact-in only. Exact LP/shares need a bounded search plus forward replay. `ConstProdUtils` binary search is a different forward function (`:579+` per Astra; not re-certified here as the mixed inverse).

## Dissent left open

- Call count and pool-first vs buyback-first: seller payout vs gas vs fail-fast. Not settled by optimality.
- Residual recipient: book at sync (reference exact-in) vs refund caller (amendment).
- Solver guarantee for mixed zap: candidate search versus a proof. Keep the route in the research scope.
- Whether previews may promise the split. I now agree with Astra that a promised venue cannot also silently fall back.

**Confidence:** high on the tax counterexample, protocol-fee counterexample, cap-bound identity, and repeated-fill payout increase. Medium on seller benefit from pool-first when treasury LP is nonzero. Low on live bytecode and decimals. No shell, tests, or RPC.
