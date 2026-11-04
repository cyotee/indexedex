# Coordinator receipt of MiniMax initial evidence

Native task st_01a1773e, epoch 0. The complete member-authored inline response and model follow unchanged. This is coordinator-preserved delivery, not a member-written file or a production reproduction.

---

Ask: Determine whether executed same-pool deposit/withdrawal swaps capture manipulation when only venue/reference is the underlying pool and TWAP - wanted: a precise model, exact witness, and current-vs-historical TWAP analysis.  
For you: The complete Minimax member response and reproducible model are inline below. Project-scoped `apply_patch` was registered but inactive, so, as the brief requires, I did not substitute `write` or `edit`; both owned files remain absent. The standalone arithmetic was executed and verified in the resident kernel, with no project tests or builds.  
Now: No task remains.  
Next: None.

# MiniMax member response — same-pool executed swaps

## Evidence labels

- **SO — Source observation:** read directly in this run.
- **DER — Exact derivation:** algebra from stated assumptions.
- **RW — Reproducible witness:** standalone exact-rational computation with conservation assertions.
- **PS — Parameter search:** finite, fully disclosed domain.
- **UV — Unverified:** not established by project execution in this assignment.

## 1. Verdict

### Current Wings implementation: unsafe, independently of the proposed swaps

**SO.** The current implementation does not require an entry conversion or an exit sale for ordinary pricing:

- `Money._deposit` pulls target assets, harvests, obtains `Quote.quote(Common.quoteRequest()).value`, and mints with `Accounting.issue(supply, value, assets_)`.
- `Money._redeem` obtains the same live whole-book liquidation quote and pays `Accounting.entitlement(supply, value, shares_)`.
- There is no corresponding conversion in the ordinary deposit or redeem path.

Sources:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:112-181`
- `.../UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol:17-27`
- `.../UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol`, especially `quote`, `_prepare`, and `_sell`

**SO, reported executed PoC.** Audit APEX-2026-012 reports that its in-unlock JIT variant produced a `70,634,405,953` raw-token0 profit on a `1e12` vault, while the matched no-JIT control returned `-1`. The audit also reports a settled variant. The finding is **latent, not deployed**, so this is not a claim of current production loss.

Source:

- `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md:268-331`

### Actual entry and slice-exit swaps do not, by themselves, “capture” manipulation

**DER/RW.** Executing against the only venue does not reveal that the venue was manipulated. It makes the manipulated venue the numeraire. Under the literal executed-price rule, I found a fully settled positive round trip:

- **5,162,744.89786187 target-token profit**
- 0.3% pool fee
- 100,000,000 opposing-token flash debt fully repaid
- final opposing inventory: **0**
- final vault shares: **0**
- exact rational target and opposing conservation assertions passed

This is an exact-rational witness for an external-only constant-product pool and a two-sided vault inventory. It **disproves the universal claim that actual entry plus actual proportional exit swaps make the literal denominator safe**. It is not yet an exact production Wings PoC; the missing production features are listed in §3.6.

### Corrected historical TWAP is better than APEX-050, but it is still not an independent price

**SO.** Current `UniswapV4TruncatedTwapOracleLib.write` credits the entire elapsed interval with the live tick read at write time, and the read side extrapolates with the live tick. `update` is permissionless. APEX-050’s executed PoC moved `consult(W=1800)` to tick `9116`, produced a Morpho-adapter price of `2.488187...e36`, and cost approximately 2,866.8 tokens in fees. The lender was hypothetical, and no current consumer or deployment using this oracle was verified.

Sources:

- `contracts/oracles/uniswap/v4/twap/libraries/UniswapV4TruncatedTwapOracleLib.sol:86-112,150,239-251`
- `contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleTarget.sol:32-45,126-133`
- `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md:2763-2815`
- `docs/security/audit/second_review/indexedex-2ba07631-pocs/test/apex_audit/probe-twap-retroactive/TwapRetroactive.t.sol`
- `.../probe-twap-retroactive/RESULT.md`

A correctly anchored implementation should credit `[t_prev,t_write]` with `prevTick` and extrapolate subsequent reads from the last anchored tick rather than the live tick. That prevents one atomic poke from retroactively contaminating an already elapsed window. It does **not** reconstruct prices that occurred between writes, and an attacker can still poison the interval beginning at its write until the next honest write.

### Recommendation

1. Do not use the literal executed-price denominator as a safety proof.
2. Use strictly proportional, externally sized, on-chain-verified vector deposits with unmatched-excess refund as the only construction here that is price-independent by algebra.
3. If same-pool TWAP gating is retained, first implement correctly anchored and gap-covered history, then add pre-operation snapshots, deviation bands, write-age/coverage requirements, operation caps, and multi-block holding. Treat this as a bounded same-venue reference, not an independent oracle.
4. Preserve the one-share `getRate` semantics exactly, but quarantine scalar `getRate` from consumers that do not redeem at the consumed quantity.

---

## 2. Exact model definitions

### 2.1 Current audit baseline: whole-book live liquidation

After harvest, define the live book’s target and opposing inventories as `A0` and `A1`. The current quote:

1. reads live `slot0`, liquidity, and tick bitmap;
2. removes the vault’s owned positions from the simulated book;
3. sells the remaining opposing inventory through external liquidity;
4. returns the resulting target value `V_live`.

Then:

\[
m=\left\lfloor\frac{S D}{V_{\text{live}}}\right\rfloor,
\qquad
a=\left\lfloor\frac{s V_{\text{live}}}{S}\right\rfloor.
\]

This is the APEX-012 baseline. It is not the proposed actual-swap design.

### 2.2 Literal actual-entry, actual-slice-exit design

Let target be token 0 and opposing token 1.

Before the entry swap, after harvest:

- `S` = existing share supply;
- `A0` = target inventory, including local balances, position principal, and old fees;
- `A1` = opposing inventory on the same basis;
- `D` = entrant target deposit.

The vault executes an exact-input entry swap of `x` target for `o` opposing. Define the fee-inclusive execution price:

\[
p_e=\frac{x}{o}\quad\text{target per opposing}.
\]

The literal rule is:

\[
V_{\text{pre}}=A_0+p_e A_1,
\]

\[
m=\left\lfloor\frac{S D}{V_{\text{pre}}}\right\rfloor.
\]

The credit identity is:

\[
C=(D-x)+p_e o=D.
\]

The literal share cutoff is therefore:

\[
\alpha=\frac{m}{S+m},
\]

where `alpha` is the entrant’s proportional ownership of the enlarged vault.

On exit, the entrant withdraws `alpha` of every position, idle balance, and fee claim, and sells only `alpha` of the opposing slice. Its target payout is the target slice plus the **actual** proceeds of that slice sale.

This design has three distinct properties that must not be conflated:

- `C=D` is an accounting identity.
- Actual entry execution prices the entrant’s own swap.
- Actual slice execution realizes the exit.
- None of those facts proves that `V_pre` is manipulation-resistant.

### 2.3 Post-swap-composition variants tested

Let the post-entry book be:

\[
A'_0=A_0+D-x,\qquad A'_1=A_1+o.
\]

I tested:

1. **Post-swap at execution price**

\[
V_{pe}=A'_0+p_e A'_1.
\]

2. **Post-swap at post-swap marginal price**

\[
V_{pm}=A'_0+p_m A'_1,
\qquad
p_m=\frac{X_{\text{post}}}{Y_{\text{post}}}.
\]

3. **Minimum of the two corrections**

\[
V_{\min}=\min(V_{pe},V_{pm}).
\]

In the witness, merely changing the denominator to post-swap composition did not eliminate the closed-loop profit: §3.4 reports the exact results.

---

## 3. Exact witness, controls, and search

### 3.1 Pool equations

For a constant-product pool with virtual reserves `X,Y` and fee `gamma`, let:

\[
z_n=z(1-\gamma).
\]

Target-token input:

\[
\Delta_1=\frac{Yz_n}{X+z_n},
\qquad
X'=X+z_n,
\qquad
Y'=Y-\Delta_1.
\]

Opposing-token input:

\[
\Delta_0=\frac{Xz_n}{Y+z_n},
\qquad
X'=X-\Delta_0,
\qquad
Y'=Y+z_n.
\]

Fees are excluded from virtual reserves but tracked as LP fee claims. The standalone model asserts conservation including those claims.

### 3.2 Witness state

Initial state:

- external pool: `X=Y=100,000,000`;
- external LP is the only pool LP;
- pool fee: `0.3%`;
- vault inventory: `A0=1,000,000` target and `A1=200,000,000` opposing;
- initial supply: `S=1,000,000` shares;
- attacker capital: `5,000,000` target;
- flash borrow: `100,000,000` opposing, with zero flash fee in the base witness;
- fixed entry: `x=49% D=2,450,000` target.

The attacker-owned target capital is `D`; the flash principal is opposing and must be repaid.

### 3.3 Action ledger

| Step | Action | Actual result |
|---|---|---|
| 1 | Flash-borrow opposing | `100,000,000` opposing debt |
| 2 | Swap `100,000,000` opposing for target | Receive `49,924,887.330996498466` target; pay `300,000` opposing fee; pool becomes `50,000,000 / 200,000,000` |
| 3 | Deposit `5,000,000` target; vault swaps `2,450,000` target | Receive `9,288,232.784674635157` opposing; pay `7,350` target fee; pool becomes `52,442,650 / 190,711,767.215325365` |
| 4 | Compute literal denominator | `p_e=0.263774612113775`; `V_pre=53,754,922.422755002975` |
| 5 | Mint | `m=93,014` shares; total supply `1,093,014`; attacker fraction `alpha=0.08509863551610501` |
| 6 | Redeem attacker’s proportional slice | Target slice `302,100.15608217276`; opposing slice `17,810,143.039552767`; actual target sale proceeds `4,479,750.341824248433`; opposing fee `53,430.429118658300`; total payout `4,781,850.497906421193` |
| 7 | Repay flash debt | Sell `44,543,992.931041046977` target for exactly `100,000,000` opposing; target fee `133,631.978793123126` |
| 8 | Final attacker wallet | `10,162,744.897861870006` target; `0` opposing; `0` shares; debt `0` |
| 9 | Final profit | `10,162,744.897861870006 - 5,000,000 = 5,162,744.897861870006` target |

No favorable external mark is used. Profit is a target-denominated wallet difference after the flash loan, all swaps, all fees, and the full redemption.

### 3.4 Matched controls and denominator variants

| Case | Final target profit |
|---|---:|
| No manipulation, no flash loan | `-143,477.293833896721` |
| Flash manipulation, no vault deposit or redemption | `-452,033.470528949460` |
| Literal denominator | `+5,162,744.897861870006` |
| Post-swap at `p_e` | `+3,930,748.715170613956` |
| Post-swap at post-marginal price | `+3,370,122.044926437549` |
| Minimum of post-swap corrections | `+3,930,748.715170613956` |

The two controls establish that the profit is not merely the manipulation trade:

- manipulating and unwinding the pool by itself loses money;
- depositing and redeeming under the literal rule creates the positive result.

### 3.5 Entry-size and flash-fee sensitivity

Fixed entry fractions:

| Entry swap | Profit |
|---|---:|
| 49% | `5,162,744.897861870006` |
| 50% | `5,053,409.393024628982` |
| 51% | `4,943,655.362700939178` |

Attacker-selected entry sizing:

| Entry swap | Profit |
|---|---:|
| 1% | `10,143,708.375864716247` |
| 5% | `9,748,215.715689878911` |
| 10% | `9,248,938.387080568820` |

A smaller entry swap preserves more of the manipulated price while still creating a large denominator mismatch.

Flash-loan fee sensitivity:

| Flash fee on 100,000,000 opposing | Profit |
|---|---:|
| 0% | `5,162,744.897861870006` |
| 0.01% | `5,154,171.686303458177` |
| 0.1% | `5,076,941.384119707160` |
| 1% | `4,297,503.988510520197` |
| 2% | `3,415,963.685765361413` |
| 5% | `668,806.773793010041` |
| 10% | `-4,282,909.461136403494` |

The model’s flash-fee break-even is approximately **5.704875606%**. Flash-loan availability and gas are not verified.

### 3.6 LP inventories and reachability limits

The witness contains:

- **External LP inventory:** initial `100,000,000 / 100,000,000`; final virtual reserves `92,448,373.279427185655 / 108,168,479.825759470463`.
- **External LP fee claims:** `140,981.978793123126` target and `353,430.429118658300` opposing.
- **Vault residual inventory:** `3,247,899.843917827122` target and `191,478,089.745121866465` opposing.
- **Attacker JIT LP inventory:** zero.
- **Attacker vault shares at end:** zero.

The model assigns all pool fee claims to the external LP. A real Wings core/wing LP would receive part of those fees. Harvest timing can therefore improve or worsen the realized result.

Crucially, the witness represents the vault inventory as idle or out-of-range inventory and omits active Wings core liquidity. Its approximate tick path is `-14,664.284465...` to `0`:

- with ordinary spacing 60, the lower wing would become active, so this is **not** an exact default-spacing Wings reproduction;
- with spacing 32,767, the path can remain outside the nearest wing boundaries, and a negligible active core makes the limiting model closer to the intended concentrated-liquidity state;
- actual `Harvest.placement`, integer rounding, per-range fee growth, and exact wing activation remain unmodeled.

Therefore:

- **RW:** the literal rule has a profitable, fully settled closed loop in the stated model.
- **UV:** exact reachability and profit in a production Wings implementation are not established.
- **DER:** because the safety claim was universal, the model is sufficient to reject “actual entry and exit swaps make same-pool pricing safe” as a general theorem.

### 3.7 Finite parameter search

**PS.** The exact-rational search covered 13,500 cases:

- `X=Y` in `{1e6, 1e7, 1e8}`;
- fee in `{0, 0.003}`;
- `A0/X` in `{0.01, 0.1, 0.5, 1, 2}`;
- `A1/X` in `{0.01, 0.1, 0.5, 1, 2}`;
- `D/X` in `{0.001, 0.01, 0.05, 0.1, 0.5}`;
- flash `B/X` in `{0.001, 0.01, 0.05, 0.1, 0.5, 1}`;
- entry in `{49%, 50%, 51%}`.

Results:

- **3,474 / 13,500** profitable;
- **2,190** at zero fee;
- **1,284** at 30 bps.

Every point passed exact target and opposing conservation, closed the flash debt, and ended with zero opposing inventory.

This is a finite parameter search, not a proof of all parameter regimes. It also did not model active core/wing liquidity, integer rounding, gas, or flash availability.

---

## 4. Current APEX-050 versus a correctly anchored historical TWAP

### 4.1 Current oracle

**SO.**

- `update(PoolKey)` is permissionless.
- `write` takes the live `slot0` tick.
- The entire `now - lastTimestamp` interval is credited with that live, truncated tick.
- `observe` extrapolates an uncovered tail using the live tick.
- The attacker’s write resets `lastTimestamp`, so `writeAge=0`.
- Adapter `maxWriteAge` checks therefore do not stop the APEX-050 sequence.

APEX-050’s executed PoC reports:

- exact spot restoration;
- `consult(W=1800)=9116`;
- adapter price `2.488187...e36`;
- attacker fees about `1,109.43` token0 and `1,757.38` token1;
- hypothetical lender profit `447,133.18` and bad debt `450,000`.

The hypothetical lender is not protocol code, and no current protocol consumer was verified.

### 4.2 Correctly anchored historical behavior

A corrected write should conceptually be:

\[
C_{\text{new}}
=
C_{\text{old}}+\operatorname{tick}_{\text{prev}}(t_{\text{write}}-t_{\text{prev}}).
\]

The next observation should extrapolate from the last anchored tick, not from live `slot0`.

This changes APEX-050’s failure mode:

- the already elapsed interval is no longer retroactively credited with the poked tick;
- the manipulated tick can still become the anchor for the interval beginning at the poke;
- contamination lasts until the next honest write, rather than necessarily the entire prior window;
- if writes are infrequent, that interval can still be large.

A corrected accumulator with sparse writes does **not** reconstruct the actual historical path. It approximates an uncovered interval by the previous tick. It is not a true historical TWAP unless coverage is sufficiently dense or an independently anchored path-reconstruction rule is specified.

### 4.3 Limits of TWAP gating in a sole-venue market

Even with correct anchoring:

- an attacker can move the price before a sampling write;
- time-weighting limits the weight of a short manipulation but does not make the venue independent;
- there is no assumed outside arbitrageur to restore the sole pool’s price. Restoration is the attacker’s own opposite swap, with fees and impact;
- if the vault is a dominant LP, the attacker’s trades may transfer composition value from the vault’s own liquidity;
- `writeAge` and observation count do not prove that the historical interval was covered;
- a permissionless update can still reset the anchor.

A plausible TWAP-gated variant would require all of:

1. correctly anchored interval accounting;
2. a proven coverage-span rule, not merely `cardinality>0`;
3. no live-tick extrapolation across uncovered gaps;
4. a pre-operation snapshot;
5. deviation-band enforcement;
6. maximum notional per operation;
7. multi-block holding or delayed settlement;
8. restricted or sequenced updates;
9. separate treatment of stale, uncovered, or update-controlled states.

The directional issuance bound suggested by the audit—mint against `max(V_live,V_reference)` and redeem against `min(V_live,V_reference)`—can prevent the specific direction in which a depressed live value would over-mint. It is safe only if the reference itself is not currently poisoned and the band is enforced.

**Conclusion:** a correctly anchored, covered, bounded same-pool TWAP can reduce manipulation exposure. It does not turn the underlying pool into an independent price source.

---

## 5. Best viable no-independent-feed design

### 5.1 Strict proportional vector entry with refund

For externally sized two-sided entry amounts `a0,a1`, define:

\[
f=\min\left(\frac{a_0}{A_0},\frac{a_1}{A_1}\right),
\qquad
m=fS.
\]

Mint only the proportional claim. Refund the unmatched excess in kind.

If the pre-entry book is `B`, and exactly `fB` of target and opposing is added, then:

\[
B_{\text{after}}=(1+f)B,
\qquad
S_{\text{after}}=(1+f)S.
\]

Every pre-existing holder retains the same ownership fraction. No token needs a price. An on-chain implementation must verify the actual funded vector and the actual position-vector constraints; it must not trust an off-chain quote.

This is the only design in the examined set with a direct manipulation-independent conservation invariant.

### 5.2 What full imbalance credit costs

Full economic credit for unmatched excess requires valuing that excess in shares. With only the same pool:

- the executed price is endogenous;
- the pool’s own TWAP is not independent;
- a spot or TWAP valuation can be manipulated or poisoned;
- the entrant and incumbent cannot both receive full credit without defining which party absorbs the valuation and exit-impact loss.

A credible alternative is to keep unmatched excess in a separately attributed surplus reserve, but it must be explicit whether that reserve:

- belongs to incumbents;
- is non-redeemable and retained as vault inventory;
- has its own vector redemption rules; or
- is ultimately credited through a priced mechanism.

Crediting it fully to the entrant at an endogenous same-pool price recreates the vulnerability.

A scalar internal-AMM invariant is also not automatically safe:

- heterogeneous Wings ranges do not share one conserved `sqrt(x*y)` quantity;
- an internal curve can price imbalance only by introducing a manipulable marginal price;
- a virtual-reserve design can preserve the vault’s own accounting while still allowing withdrawal at an unfavorable internalized price.

The unresolved tradeoff is therefore real: **full imbalance credit plus same-pool-only denomination versus price-independent proportional issuance**.

---

## 6. One-share `getRate` and downstream consumers

### 6.1 Preserve the requested semantics

`getRate` should remain:

> A normalized preview of the actual withdrawal and target sale for exactly one whole share.

If `q` is one whole share in the vault’s native share unit, and `P(q)` is the actual target proceeds from withdrawing that fraction and selling only its opposing slice:

\[
\operatorname{getRate}
=
\operatorname{mulDiv}(P(q),10^{18},q).
\]

Requirements:

- quantity-specific previews quote their own quantity;
- `getRate` uses one whole share, not the whole book;
- the preview does not execute a trade;
- no scalar mark, NAV, or unrelated consumer is substituted.

**SO.** The current source does not yet have this semantics. `EconomicTarget.getRate` divides the **whole-book** live liquidation quote by total supply.

Source:

- `.../UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol:27-41`

The requested one-share semantics are therefore a proposed change, not a description of current behavior.

### 6.2 Consumers are a separate risk surface

**SO.**

- The single constant-product buffer hook’s `ratedReserve` values its entire SE-share balance using scalar `IRateProvider.getRate()` without redeeming the shares.
- The dual and orbital hook implementations use the same scalar-provider pattern.
- DETF scaling multiplies raw amounts by `rateProvider.getRate()`.
- The Balancer standard-exchange rate provider separately obtains a **full-book** exit preview; it is not the vault’s one-share rate.

Sources:

- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:409-459`
- `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol`
- `contracts/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHookTarget.sol:410-450`
- `contracts/vaults/detf/common/core/DETFBalancerScaleLib.sol`
- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol`

Consequences:

- a one-share rate is low-impact relative to the whole book, but it is still a live execution quote;
- it is not a safe valuation for an arbitrary consumer inventory;
- a consumer that redeems must use the actual consumed quantity;
- a consumer that does not redeem needs a bounded reference or must accept that its scalar rate is manipulable;
- the vault’s own issuance safety must not depend on the scalar `getRate`.

---

## 7. Required next production validation — not run here

No project test, build, deployment, wallet operation, or Git action was performed.

A production implementation should validate:

1. **Exact Wings reproduction**
   - real PoolManager swaps and `modifyLiquidity`;
   - default spacing 60 and large spacing 32,767;
   - core, upper-wing, lower-wing, idle, and fee inventories;
   - actual Harvest placement and conversion.

2. **Witness ledger**
   - flash borrow, manipulation, entry, mint, proportional withdrawal, opposing-slice sale, and debt repayment;
   - final zero opposing, zero shares, zero debt;
   - exact token conservation;
   - final target-denominated profit after fees and gas.

3. **Controls**
   - no manipulation;
   - manipulation without deposit;
   - deposit without redemption, labeled as residual share exposure rather than profit;
   - no attacker JIT LP and a separate JIT-LP variant.

4. **Matrix**
   - vault active-liquidity fractions near 0%, 10%, 50%, 90%, 99%;
   - low and high external same-pool depth;
   - core-dominant, wing-heavy, and idle-heavy books;
   - fixed/default and large deposits;
   - zero and realistic positive fees;
   - 49%, 50%, 51%, and attacker-selected entry sizes.

5. **Accounting alternatives**
   - literal `V_pre`;
   - post-swap-at-`p_e`;
   - post-swap-at-marginal;
   - conservative minimum;
   - strict proportional vector issuance/refund.

6. **TWAP**
   - APEX-050 regression;
   - correctly anchored writes;
   - sparse-gap behavior;
   - write coverage and age;
   - deviation bands;
   - operation caps and multi-block holding.

7. **Rate and consumers**
   - one-share preview versus actual withdrawal-and-sale;
   - quantity-specific preview parity;
   - scalar consumers versus actual-size redeemers.

---

## 8. Sources actually examined

### Project rules and implementation

- `CLAUDE.md`
- `AGENTS.md`
- Wings:
  - `Money.sol`
  - `Accounting.sol`
  - `LiquidationQuote.sol`
  - `Inventory.sol`
  - `Geometry.sol`
  - `Harvest.sol`
  - `ExecutionDelegate.sol`
  - `Projection.sol`
  - `EconomicTarget.sol`
  - `Common.sol`
  - `Repo.sol`
  - `Types.sol`
  - `QueryTarget.sol`
  - `InTarget.sol`, `InExecutionBase.sol`
  - `OutTarget.sol`
  - `QuoteBase.sol`
  - `interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol`

### Audit and existing evidence

- `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`
  - APEX-2026-012
  - APEX-2026-024
  - APEX-2026-025
  - APEX-2026-026
  - APEX-2026-040
  - APEX-2026-050
- `docs/security/audit/second_review/indexedex-2ba07631-pocs/test/apex_audit/probe-twap-retroactive/TwapRetroactive.t.sol`
- `.../probe-twap-retroactive/RESULT.md`

### Oracle

- `contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleTarget.sol`
- `.../UniswapV4MultiPoolTwapOracleRepo.sol`
- `.../aware/UniswapV4TwapOraclePoolManagerAwareRepo.sol`
- `.../libraries/UniswapV4TruncatedTwapOracleLib.sol`
- `.../UniswapV4TwapAggregatorV3Adapter.sol`
- `.../UniswapV4TwapMorphoOracle.sol`

### Uniswap V4 execution and math

- `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol`
- `.../interfaces/IPoolManager.sol`
- `.../types/PoolOperation.sol`
- `.../libraries/Pool.sol`
- `.../libraries/SwapMath.sol`
- `.../libraries/SqrtPriceMath.sol`
- `.../libraries/LiquidityAmounts.sol`

### Downstream rate consumers

- `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol`
- `UniswapV4SeBufferHookContextQuoteLib.sol`
- `UniswapV4CurveQuadStableSwapHookTarget.sol`
- `DETFBalancerScaleLib.sol`
- `StandardExchangeRateProviderFacet.sol`

### Prior-work use

The prior run’s Kimi member original was read only to recover the literal formula’s definitions. It was treated as a record of what was proposed, not as proof. No current-run peer original or draft was read.

### Public queries

No public query or member fetch was performed. The brief’s supplied public Uniswap links were not independently re-fetched. No external price feed was used in the model.

## Strongest counterargument

The strongest objection is that the witness is algebraically exact but not an exact Wings execution:

- it omits active core and wing liquidity;
- default spacing would activate a wing during the manipulation;
- it assumes flash-loan availability;
- it excludes gas;
- it allocates all LP fees to the external LP;
- it does not execute integer rounding or `Harvest.placement`.

That objection correctly limits the production claim. It does not rescue the universal safety claim: actual execution prices the manipulated venue, the literal rule has a settled positive counterexample, and current Wings is independently exposed under APEX-012. Production validation must determine whether the exact Wings geometry strengthens, weakens, or eliminates the modeled extraction. The construction that avoids that dependence entirely is proportional vector issuance with refund, at the cost of full imbalance credit.

---

# Inline `model.py` receipt

```python
from fractions import Fraction as F
from math import floor


class Pool:
    def __init__(self, x, y, fee):
        self.x, self.y, self.fee = F(x), F(y), F(fee)
        self.f0 = self.f1 = F(0)

    def t_in(self, a):
        net = a * (1 - self.fee)
        out = self.y * net / (self.x + net)
        fee = a - net
        self.x += net
        self.y -= out
        self.f0 += fee
        return out, fee

    def o_in(self, a):
        net = a * (1 - self.fee)
        out = self.x * net / (self.y + net)
        fee = a - net
        self.y += net
        self.x -= out
        self.f1 += fee
        return out, fee

    def t_for_o(self, amount):
        # Gross target input needed to receive exactly `amount` opposing.
        return (amount * self.x / (self.y - amount)) / (1 - self.fee)


def run(
    X=10**8,
    Y=10**8,
    fee=F(3, 1000),
    A0=10**6,
    A1=2 * 10**8,
    D=5 * 10**6,
    B=10**8,
    xf=F(49, 100),
    loan_fee=F(0),
    denom="literal",
    manipulate=True,
    deposit=True,
    redeem=True,
):
    X, Y, A0, A1, D, B, xf, loan_fee = map(
        F, (X, Y, A0, A1, D, B, xf, loan_fee)
    )
    pool = Pool(X, Y, fee)
    S = 1_000_000

    attacker_target = D
    attacker_opp = F(0)
    debt = B * (1 + loan_fee)

    manip_target = manip_fee = F(0)
    if manipulate and B:
        manip_target, manip_fee = pool.o_in(B)
        attacker_target += manip_target
        # The borrowed opposing is spent in the manipulation swap.
        attacker_opp += B
        attacker_opp -= B

    minted = V = pe = entry_opp = entry_fee = F(0)
    if deposit:
        attacker_target -= D
        entry_target = D * xf
        entry_opp, entry_fee = pool.t_in(entry_target)
        pe = entry_target / entry_opp
        post_marginal = pool.x / pool.y

        if denom == "literal":
            V = A0 + pe * A1
        elif denom == "post_pe":
            V = (A0 + D - entry_target) + pe * (A1 + entry_opp)
        elif denom == "post_marginal":
            V = (A0 + D - entry_target) + post_marginal * (A1 + entry_opp)
        elif denom == "min":
            V = min(
                (A0 + D - entry_target) + pe * (A1 + entry_opp),
                (A0 + D - entry_target) + post_marginal * (A1 + entry_opp),
            )
        else:
            raise ValueError(denom)

        minted = floor(S * D / V)

    alpha = F(minted, S + minted) if minted else F(0)
    vault_target = A0 + (D - D * xf if deposit else F(0))
    vault_opp = A1 + (entry_opp if deposit else F(0))

    exit_opp = exit_target = F(0)
    if deposit and redeem:
        target_slice = alpha * vault_target
        opp_slice = alpha * vault_opp
        vault_target -= target_slice
        vault_opp -= opp_slice
        exit_target, _ = pool.o_in(opp_slice)
        exit_opp = opp_slice
        attacker_target += target_slice + exit_target

    repay_target = repay_opp = F(0)
    if debt:
        repay_target = pool.t_for_o(debt)
        repay_opp, _ = pool.t_in(repay_target)
        attacker_target -= repay_target
        attacker_opp += repay_opp
        attacker_opp -= debt
        assert attacker_opp == 0

    # Exact token ledgers, including LP fee claims and the lender's flash fee.
    assert pool.x + pool.f0 + vault_target + attacker_target == X + A0 + D
    assert pool.y + pool.f1 + vault_opp + attacker_opp == (
        Y + A1 - loan_fee * B
    )

    return {
        "pool": pool,
        "V": V,
        "pe": pe,
        "minted": minted,
        "alpha": alpha,
        "manip_target": manip_target,
        "manip_fee": manip_fee,
        "entry_target": D * xf if deposit else F(0),
        "entry_opp": entry_opp,
        "entry_fee": entry_fee,
        "exit_opp": exit_opp,
        "exit_target": exit_target,
        "repay_target": repay_target,
        "repay_opp": repay_opp,
        "attacker_target": attacker_target,
        "attacker_opp": attacker_opp,
        "profit": attacker_target - D,
        "vault_target": vault_target,
        "vault_opp": vault_opp,
    }


w = run()
assert abs(float(w["profit"]) - 5_162_744.897861870) < 1e-6
assert w["attacker_opp"] == 0

print("profit", float(w["profit"]))
print("final_target", float(w["attacker_target"]))
print("V_pre", float(w["V"]))
print("p_e", float(w["pe"]))
print("minted", w["minted"])

print("control_no_manipulation", float(run(B=0, manipulate=False)["profit"]))
print(
    "control_manipulation_without_deposit",
    float(run(deposit=False, redeem=False)["profit"]),
)

for denominator in ("literal", "post_pe", "post_marginal", "min"):
    case = run(denom=denominator)
    print(denominator, float(case["profit"]))
```

**Artifact status:** `members/minimax/response.md` and `members/minimax/model.py` were not created because project-scoped `apply_patch` was inactive. No alternative writer was used.
