# Grok round-2 original — capacity split and NET-funded zap-in

Independent. No peer reports read. No code, config, shell, RPC, or PRD/plan edits. `apply_patch` is not in this session’s tool catalog; this assigned file was created with `write` only.

**Scope the owner accepted:** add InverseBond routing, with finite-capacity splitting, including the NET-funded zap-in sale leg. Whole-fill-only and pass-through-only are not the final scope. v0.34/v0.10 still do not specify this; it remains an owner addition on top of R34 parity.

## 1. Executable constraints

InverseBond `swap(netAmount, minUsdgOutRaw)` is exact-in, all-or-nothing, and pays `msg.sender` (`InverseBond.sol:68–89`). A contract caller is allowed. There is no partial-fill or recipient argument, so a split is two venues in one transaction, not one overloaded call.

```text
payoutWad = floor(netAmount * price() / 1e9)     // FixedPointMath.mulDiv
usdgRaw   = floor(payoutWad / F)                 // F = 10^(18-usdg.decimals())
revert if payoutWad > capacityRemaining
```

`price()` is `floor(backingPerToken * 9850 / 10000)` (`:108–111`, `Constants.sol:64–67`). TWAP is only the liveness gate (`:71–73`). Cap is 1% of `liquidUsdg`, snapshotted at the epoch’s first fill, then frozen (`:76–79,128–139`). `spendUsdg` may Morpho-withdraw if liquid later falls under that snapshot (`Treasury.sol:135–146`).

Largest `n` with `floor(n*P/1e9) <= C` is not always `floor(C*1e9/P)`. Compute that candidate, then decrement while `mulDiv` exceeds `C`. Skip the leg if `usdgRaw == 0`.

NET tax is 500 bps only if enabled, neither side is exempt, and one side is a taxed pair (`NET.sol:131–145`). Post-wire `addTaxedPair` can map only a factory NET pool (`:201–219`). Vault→InverseBond is untaxed. Vault→canonical pair is taxed unless the vault is exempt. User→vault is untaxed, and `_secureTokenTransfer` requires the balance delta to equal the requested amount (`UniswapV2StandardExchangeCommon.sol:441–451`). The taxed leg is the later send to the pair, not the deposit credit.

Reference execution still calls `swapExactTokensForTokens` and quotes as if the full input arrives (`UniswapV2Service.sol:301,325–332`). Router02’s supporting-fee method is exact-input only (`IUniswapV2Router02.sol:29–35`). Context7 `/uniswap/docs`, accessed 2026-10-01, confirms there is no supporting-fee exact-output. Pool NET legs must use the supporting-fee router and quote the post-tax amount that hits the pair. Fee units are `300/100_000 = 0.30%` (`Constants.sol:34–37`, `ConstProdUtils.sol:149–165`), not 300 bps.

## 2. Toy model vs integer algorithm

**Toy, no tax, continuous, one linear bid.** Pool marginal USDG per NET falls. Buyback marginal is flat at `p` until cap, then unavailable. For a pure NET→USDG sale, sell to the bid while `p` exceeds the pool’s marginal on the residual, then send the rest to the pool. That is a threshold, not a blend of average prices. Average-price comparison mis-sizes the split once the pool leg has impact.

**Integer algorithm, not a closed proof.** Let `G` be NET credited to the vault. Let `nMax` be the capacity-safe maximum above.

1. Read `active`-equivalent gates, `P`, `C`, pair reserves, `kLast`, `feeTo`, and live exemption of the actual vault→pair sender. Fail the bid candidate closed if any bid read fails.
2. `nB = min(G, nMax)` is only the domain. The objective search picks `nB` inside `0..nBmax`.
3. For a pure swap, `USDG(nB) = buybackRaw(nB) + supportingFeeQuote(taxed(G-nB))`. Choose the feasible `nB` with the greatest raw USDG. Tie, or no strict gain versus `nB=0`, stays pool-only.
4. Execute **one** `swap(nB, 0-or-slice-min)` then one supporting-fee pool swap of `G-nB`. Sum must meet the user’s `minAmountOut`, or revert.
5. Do not loop `swap`. Each fill raises `backingPerToken` because payout is 98.5% of backing while supply falls by the full burned amount (`Treasury.sol:105–118` plus burn). The next `price()` is higher, so a second call buys less NET per remaining wad and burns the accretion into a worse average. Cap does not grow mid-epoch: the first fill freezes it before `spendUsdg`.

**Buyback-first vs pool-first.** One bid call and one pool call barely interact. The bid does not move pair reserves. A pool swap does not spend treasury USDG; it only nudges NAV through treasury-owned LP’s share of the 0.3% fee (`k` up). Pool-first therefore makes the following bid slightly worse. Buyback-first does not move the pool, so the pool quote stays valid. **Order: one buyback, then the pool leg.** Repeated bid calls are dominated.

Pool-first does not refresh the epoch cap. Only a first fill of the epoch snapshots `liquidUsdg`. Our own `spendUsdg` cannot enlarge that snapshot.

## 3. NET-funded zap-in

Current zap sells `ConstProdUtils._swapDepositSaleAmt` (`:457–473`) through the pool, then `addLiquidity` (`UniswapV2Service.sol:339–413`). That quadratic assumes the sold NET arrives in the pair and moves reserves. It is the wrong splitter if some USDG comes from InverseBond and does not move `k`.

**Objective:** maximize vault shares credited to the user after the existing deposit fee. If that fee is a fixed fraction of new shares, maximizing LP minted by `pair.mint` is the same choice. If a later reading shows a non-linear fee, optimize shares, not raw LP. Do not optimize intermediate USDG.

**Gross/net.** Ingress `G` is already net of transfer tax. Split `G = nB + nS + nD`: bid, pair sale, direct LP NET. Bid burns `nB` and returns `U_b`. Pair receives `floor(nS * 9500/10000)` unless exempt; the 0.3% fee then applies to that received amount. `nD` is transferred into `mint` and is not a taxed pair-to-pair hop if the sender is the vault and the recipient is the pair — **it is taxed**, because the recipient is the taxed pair. Both `nS` and `nD` lose 5% unless the vault is exempt. The bid leg does not. The deposit ratio must be built from amounts that arrive, not from nominal `nS`/`nD`.

**Toy, no tax, fee factor γ, exogenous bid USDG `U_b`, no pool sale.** Perfect current-reserve ratio:

```text
(G - b) / (b * p) = R_net / R_usdg
b* = G * R_usdg / (R_usdg + p * R_net)
```

Clamp to `nMax`. If `b* <= nMax` and this LP beats the pool-only zap, use the bid **instead of** a pool swap: buy `b*`, deposit the arrived NET and `U_b`.

If `b* > nMax`, take full `nMax`, then solve a **modified** pool sale on the remainder so post-swap reserves match `nD_arrived : (U_b + U_pool)`. That is **in addition to** the pool, not the stock `_swapDepositSaleAmt(G)`. The stock formula ignores `U_b` and will oversell into the pool.

**Marginal rule.** An extra NET goes to the bid while its USDG still corrects a USDG-short ratio by more than a taxed pool sale, and while `nB < nMax`. After the ratio is funded, further bid sales create a USDG leftover and should stop even if `p` still beats the pool marginal. Average price is the wrong score. A small taxed pool sale can still be required when the bid cannot move reserves and the residual is NET-heavy.

**Protocol fee.** A pool sale grows `k`. The following `mint` can mint fee LP first. Match execution with `_calculateProtocolFeeMint` (`ConstProdUtils.sol:984–995`, denominator `5*rootK+rootKLast`). Do not copy QuoteTarget’s `_calculateProtocolFee` plus `UNISWAP_PROTOCOL_FEE_SHARE = 16667` (`QuoteTarget.sol:212–217`); that is a different formula from canonical Uni V2. The bid leg does not mint protocol fee.

**Residuals.** Router `addLiquidity` refunds the overweight token to `msg.sender` (the vault). Those NET/USDG residuals belong to the initiating user, not booked LP and not other shareholders. Sweep them in the same call. Pass-through zap already reverts if the vault’s pair-token balance moves (`InTarget.sol:471–476`); a vault deposit must likewise not leave bid USDG inside the share claim. Exact-out credit refund stays `_refundExactOutCredit` (`Common.sol:476–481`).

**Rounding gaps (engineering, not solved here).** Joint search over `nB` and `nS` is finite but not proven unimodal once tax floors, `mulDiv`, protocol-fee mint, and `addLiquidity`’s min-ratio trim interact. A conservative implementation evaluates a bounded candidate set (0, `b*`, `nMax`, and a binary search on quoted user shares) and executes the winner. That is an approximation policy, not an optimality proof. Product choice: accept the searched maximum, or require a later proof before enabling the zap leg.

## 4. Quotes, exact-out, depletion

**Accounting** (`quoteAssets`, `StandardExchangeRateProviderFacet.sol:85–173`) stays on owned LP and pool exit. Unowned bid capacity is not share NAV.

**Execution-transition state** for a participating zap must: leave reserves unchanged for the bid slice; subtract `payoutWad` from projected remaining cap; apply the pool slice, tax, and `_calculateProtocolFeeMint` before LP; mint shares from LP that actually arrives. A later simulated fill in the same transition must not reuse `P` or `C`. If the committed preview is canonical-only plus an unbound upper bound, say so. Do not promise `max(pool, split)` and then fall back.

**Exact-out.** No InverseBond exact-out ABI. For exact USDG, choose `y_b <= floor(C/F)`, set `nB` to the smallest `n` whose replayed `usdgRaw >= y_b`, then exact-out the remainder on the pool using the taxed gross-up. Router supporting-fee cannot do that exact-out (Context7, 2026-10-01). Exact LP/shares invert the zap search: minimize `G` such that simulated user shares `>=` target, then pull only `G` and refund. Leftover from the smallest NET quantum is the user’s.

**Fallback.** Re-read `C` immediately before the one `swap`. On `ExceedsCapacity`, oracle revert, or zero raw out, set that slice to the pool in the same transaction. `swap` is atomic, so a revert does not burn NET. The user’s original `minAmountOut` / min shares still bind the sum. If the pool-only path cannot meet them, revert everything. Do not catch a failure and deliver less than the committed minimum. R11’s DETF no-fallback rule does not govern this internal venue choice.

## 5. DETF boundary

DETF NET and sNET inputs stay Keep-YT (PRD R03; plan v0.10 §1.1). This zap is for a caller depositing NET into the custom V2 SE. It is not a DETF NET entry and must not replace Keep-YT. DETF USDG input deposits USDG into the SE; that zap sells USDG for NET on the pool. InverseBond cannot buy NET, so it does not improve the USDG-funded entry. Ordinary DETF USDG output still redeems SE inventory (PRD line 111); that is an exit, not this zap-in.

## 6. Decisions still open

**Product:** searched zap maximum versus a proof gate; whether previews may show the split as a guaranteed amount or only as a non-binding upper bound over a canonical floor; whether the vault should ever be tax-exempt (PRD does not require it; exemption would change both `nS` and `nD`).

**Engineering:** live `decimals()` for `F` (do not hardcode 6); fork check that the 2026-08-28 dump still matches `0x92166e94Eea5B7799b761653881692f881dFC4C9` (Channels, fetched 2026-10-01); unimodality of the taxed zap search; Morpho-withdraw revert inside a frozen cap.

**Confidence:** high on one-call cap math, tax locus, buyback-first, and Keep-YT separation. Medium on the zap candidate search as a practical optimizer. Low on live reserves, exemptions, and bytecode identity. No live-state claims.

**Reuse:** `IInverseBond` views and `swap`; `ConstProdUtils._saleQuote` / `_swapDepositSaleAmt` only for the pool slice after tax; `_calculateProtocolFeeMint`; `IUniswapV2Router02.swapExactTokensForTokensSupportingFeeOnTransferTokens`; existing secure-pull, booked-reserve, and exact-out refund helpers. Do not reuse stock `_swapDeposit(G)` unchanged.
