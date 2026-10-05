# Kimi K3 — Round 2 original: capacity-safe split + NET-funded zap-in via InverseBond

**Scope.** Human accepts buyback routing in the custom tax-aware V2 SE and explicitly wants (a) finite-capacity splitting between InverseBond (IB) and the canonical pool, and (b) research on NET-funded zap-in using the buyback for the USDG leg instead of/in addition to the pool swap. Whole-fill/direct-swap is not the final scope. Research only; no writes beyond this file, no RPC/tests/implementation. No peer artifacts (any round) read. Sources: vendored NetNet dump (`lib/crane/contracts/protocols/pol/net/`, provenance `VENDOR.md:5–18,39` — 2026-08-28 verified-source dump, **not** fresh runtime proof; G1 open), repo V2 SE + `ConstProdUtils`, Context7 `/uniswap/v2-core` (accessed 2026-10-01), docs.netnet.capital/treasury (accessed 2026-10-01). PRD v0.34 / plan v0.10 unchanged; this is new scope requiring owner selection.

## 1. Venue model (verified from source)

**IB leg (sell NET → USDG):** price `P = floor(backingPerToken() × 9850/10000)` WAD USDG per NET (`InverseBond.sol:108–112`); `payoutWad = floor(n·P/1e9)`; `usdgRaw = floor(payoutWad / 1e12)` with USDG 6 decimals (`:64,75,82`; ROBINHOOD_MAIN.sol:29). Capacity `C` WAD = 1% of `treasury.liquidUsdg()` per 8h epoch, snapshotted at first fill, no rollover (`:76–80,124–140`); **capacity is consumed in WAD including sub-USDG-unit dust** (`filledInEpoch += payoutWad`, `:80`). Oracle gate fail-closed (`:73`; PairOracle window 30min–4h, `PairOracle.sol:85–113`). `swap` is contract-callable, pays `msg.sender`, burns `n` (`:85–89`). Vault→IB hop is **structurally untaxed**: `addTaxedPair` requires a factory-verified NET pool (`NET.sol:201–221`), so neither vault nor IB can be a taxed-pair endpoint.

**Pool leg (sell g NET → USDG):** vault→pair transfer taxed when enabled: pair receives `a = g − floor(g·t/D)`, t=500, D=10000 (`NET.sol:131–145`); out = `f·a·rU/(rN + f·a)`, f = 997/1000. Reference fee units are **PPHK**: `FEE_DENOMINATOR = 100000`, "0.5% == 500" (`ConstProdUtils.sol:203`); the reference passes `300` = 0.3% (`UniswapV2StandardExchangeInTarget.sol:89–98`).

**Feedback/order facts:** pool sells do **not** change backing `B` (POL valued k-invariant `2√(x·y)`, `Treasury.sol:92–103; 114–118`); IB fills burn NET and pay below backing ⇒ `B` rises slightly per fill, `C` is consumed, and `liquidUsdg` falls (next epoch's cap falls). IB and pool legs are therefore near-independent within one tx: **IB-first vs pool-first changes nothing for the pool leg** (IB never touches pool reserves) and nothing for `B` from the pool leg; only capacity/oracle failure risk argues for executing the IB leg first (fail fast) — first-order order-invariance is a fact of the venue model, second-order effects are limited to sequential projected fills.

## 2. Exact-in split sell (NET→USDG)

**Toy continuous model.** Total `X` NET (gross, already in vault). Allocate `x` to IB (fixed average = marginal price `p` USDG/NET, capacity `Ĉ` in NET terms) and `g` to pool. Maximize `U(x,g) = p·x + Q(g)`, `Q` strictly concave increasing. KKT: interior optimum equalizes **marginal** prices; pool marginal w.r.t. gross input is

```
m(g) = (1−t)·f·rU·rN / (rN + f(1−t)g)²        (continuous, pre-floor)
```

- `m(0) ≤ p` → IB-then-pool: `x = min(Ĉ, X)`, remainder pool.
- `m(X) ≥ p` → pool-only.
- else interior `g*` solving `m(g*) = p`; `x = X − g*`, clamped to `Ĉ`.

This generalizes my round-1 whole-fill rule: because pool **average > marginal**, average-price comparison under-uses IB; marginal equalization is the optimum. (Inference; concavity of `Q` is standard constant-product math.)

**Executable integer algorithm.** (i) Capacity clamp in NET units: need `floor(n·P/1e9) ≤ C` ⟺ `n < (C+1)·1e9/P`, so `n_max = ((C+1)·1e9 − 1) / P` (integer division; **proof obligation**, not yet machine-checked). (ii) Evaluate `U` at the two corners and at floor/ceil neighbors of the continuous `g*` (bounded candidate set, no loop over n); forward-replay the real floors (`payoutWad`/USDG truncation, `_saleQuote` floor, `ConstProdUtils.sol:149`). (iii) Single IB `swap` call sized to the whole IB tranche — repeated calls re-read rising `B` and step-consume capacity with no benefit; one call keeps the capacity check atomic. (iv) Depletion/fallback: precheck = genesis finalized + oracle gate (try staticcall) + `C>0` + live untaxed-predicate; failure → pool-only, **user limits unchanged** (`minAmountOut`, `deadline`, `exchangeIn` envelope `InTarget.sol:354–369`). Precheck passes but `swap` reverts (same-block capacity race; Morpho unwind failure in `spendUsdg`, `Treasury.sol:138–144`) → **revert the whole transaction** (my round-1 cross-review reconciliation retained): retry is safe because the next precheck routes pool-only. Partial capacity is consumed by construction (`x ≤ n_max`), so `ExceedsCapacity` is not reachable from our own sizing. (v) Ties → pool (do not burn public capacity for zero gain).

## 3. NET-funded zap-in (new research)

Goal: user supplies `T` NET; end with LP (pass-through zap-in) or SE shares (zap-in vault deposit) — reference routes 2/4 (`InTarget.sol:371–386`; execution swaps+deposits via `UniswapV2Service._swapDeposit` at `:447–458`). Three modes:

**Mode C (classic, existing):** pool-swap `s` of `T`, deposit remainder at post-swap ratio. Solver `_swapDepositSaleAmt` (`ConstProdUtils.sol:428–470`, sqrt closed form) + `_quoteSwapDepositWithFee` (`:279–345`). Fully reusable.

**Mode B (IB-only):** sell `x` via IB (pool reserves **unchanged**), deposit remaining NET + obtained USDG at the **current** ratio. Deposit-leg vault→pair NET transfer is taxed, so arriving NET `D(x) = (T−x)(1−t)`; USDG `U(x) = x·p` (after truncations). Ratio condition `U/D = rU/rN` gives the **toy closed form**

```
x* = T·(1−t)·rU / (p·rN + (1−t)·rU)
```

`_swapDepositSaleAmt` is **not** reusable here (it encodes pool-swap impact); the deposit/mint tail **is** reusable — protocol-fee-aware mint quote with `kLast`/`rootK/rootKLast` (`ConstProdUtils.sol:753–754`; feeOn ⇒ 1/6 of swap fees to feeTo, Context7 `/uniswap/v2-core`, 2026-10-01; reference passes `UNISWAPV2_PROTOCOL_FEE_SHARE`, `InTarget.sol:119–136` — verify constant value during implementation). LP minted `≈ D·L′/rN` with the fee-adjusted supply.

**Mode M (mixed, requested):** sell `x` via IB and `g` via pool; final ratio `(rN+a)/(rU−out(a))`, `a = g(1−t)`; constraint

```
(x·p + out(a)) / ((T−x−g)(1−t)) = (rU − out(a)) / (rN + a)
```

Maximize projected LP over the one free variable. **No existing solver; uniqueness/concavity of the integer objective is an unproven gap.** Executable fallback: evaluate Modes B and C exactly, plus the continuous stationary point's integer neighborhood for M, forward-replay all, pick max. Recommend **v-scope = split sell + two-mode zap-in (B vs C)**; Mode M only with a proven solver — engineering choice, not economics.

**Operation order (Mode B):** secure NET incl. pretransfer credit (`InTarget.sol:438–445` pattern) → precheck IB → exact-approve `x` → `swap(x, minU)` (USDG to vault) → transfer remaining NET to pair (**taxed**; pair `mint` credits actual `balance − reserve`, so FoT deposits are mechanically safe — Context7 mint semantics, 2026-10-01 — but the tax must be in the quote, not slippage, PRD §8:633) → transfer USDG → `mint` → LP to recipient (`:461–467`) or vault deposit → reserve sync (`:422, 469–473`). **Gross/net ratio and tax inventory:** taxed hops = pool-swap in-leg (C/M only) and deposit NET leg (all modes); untaxed = user→vault (neither endpoint a pair), vault→IB, pair→vault USDG. Tax accrues to TaxCollector, never to the vault. **Residual ownership:** integer dust (USDG wei, undeposited NET from floor mismatches) is the **user's** — refund or unbooked pretransfer credit; never booked revenue, never charged to other holders (PRD §8:631–633).

**Why B wins when it wins:** avoids swap-leg 5% tax + 0.3% fee + impact; pays 1.5%-below-`B` fixed price. Dominant near/below the round-1 crossover (~1.04×`B` marginal, lower with size) or for large `T`. Mode selection: project all feasible modes with `x ≤ n_max`, pick max LP (or shares), tie → Mode C. Preview returns the best-mode projection as the guaranteed minimum; execution re-derives and enforces `minAmountOut`.

## 4. Zap-out LP→USDG with split (now in scope)

Burn LP → receive NET (pair→vault hop **taxed** — from-side is the taxed pair) + USDG; the received NET feeds the §2 splitter instead of a pool-only sale. Reference preview branch `InTarget.sol:142–149`. Transition projection must not move projected pool reserves for the IB tranche (round-1 consensus retained).

## 5. Exact-output implications

- **Exact USDG out:** inverse allocation minimizing gross NET: IB inverse `n(y) = ceil(y·1e12·1e9/P)` (capacity-clamped), pool inverse `_purchaseQuote` (`ConstProdUtils.sol:206`) with the tax gross-up `floor((y−1)·D/(D−t))+1` discipline (plan:495). Same marginal logic inverted; integer corners + interior candidates, forward replay, predecessor checks. User `maxAmountIn` enforced; bounded pretransfer refund semantics preserved.
- **Exact LP-out zap:** no cross-venue closed form; out of split v-scope or solved by bounded outer search. Open engineering choice.

## 6. State projection / accounting

Projected IB consumption must: debit `C` in the projection, raise `B` for subsequent projected fills (NET burned, RFV − payout), and leave projected pool reserves untouched for IB tranches; pool/deposit legs mutate reserves with k/protocol-fee handling (`UniswapV2StandardExchangeQuoteTarget.sol:225–270` pattern; `quoteTransition` `:51–100`). **Accounting valuation, `quoteAssets`, and the SE rate provider exclude IB entirely** (round-1 consensus; capacity is public, 1%/epoch, unowned).

## 7. DETF relationship (unchanged law)

DETF NET/sNET input → Keep-YT, USDG input → SE (PRD R03/R37/R49): **unaffected**. This zap is a public SE route feature, not a DETF funding path; USDG-funded zap-in (selling USDG for NET) is the wrong direction for IB and stays classic. DETF USDG exits redeem SE inventory; §4 is where below-NAV exits could opportunistically benefit — with no reliance (public 1% cap). HLP exits deliver raw SE shares (R05), untouched.

## 8. Toy vs executable — gap table

| Clean continuous claim | Executable gap |
|---|---|
| `x*` closed form (Mode B) | Integer floor/ceil neighborhood + forward replay; proof that candidate set contains the integer optimum |
| `n_max` capacity formula | Arithmetic proof + fork vector |
| KKT/marginal split optimality | Concavity verification under integer floors; candidate evaluation bounds |
| Mode M stationary point | No solver; uniqueness unproven — defer or prove |
| Exact-out cross-venue inverse | Rounding/predecessor proofs; user-limit mapping |

## 9. Product vs engineering choices

**Owner/product:** split-sell acceptance (given); zap-in scope two-mode vs mixed; tie-break-to-pool policy; exact-out zap scope; residual refund vs pretransfer credit; confirmation that IB remains excluded from all valuation. **Engineering:** solver proofs above; projection fields for `C`/`B` consumption; fork vectors for live `P`, `t`, `feeOn`, exemptions, decimals (G1).

## 10. Assumptions, confidence, sources

Assumptions: dump ≡ deployed bytecode (unverified); USDG 6 decimals (constants comment); live tax/exemption state unread. No speculative live-state claims. **Confidence:** high on venue mechanics, tax structure, split-sell design, Mode B zap; medium on Mode M optimality sketch and integer-solver completeness. Sources: `InverseBond.sol:64–140`, `IInverseBond.sol:16–37`, `Treasury.sol:84–147`, `NET.sol:131–145,185–221`, `PairOracle.sol:85–113`, `Constants.sol:12–79`, `ROBINHOOD_MAIN.sol:29,459–476`; `ConstProdUtils.sol:149–470,753–754`; `UniswapV2StandardExchangeInTarget.sol:54–149,354–473`; `UniswapV2StandardExchangeQuoteTarget.sol:31–107,150–270`; Context7 `/uniswap/v2-core` mint/feeTo/getAmountOut (accessed 2026-10-01); https://docs.netnet.capital/treasury (accessed 2026-10-01). PRD v0.34 §§4.1–4.2, 8; plan v0.10 §§3, 5.3, 6.5.
