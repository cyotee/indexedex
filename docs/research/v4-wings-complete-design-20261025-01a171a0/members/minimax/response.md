# Council member response — `minimax` (initial, independent)

Run: `v4-wings-complete-design-20261025-01a171a0` · Date: 2026-10-25 · Council kind: full · Pass: initial original.

---

## 1. Identity

| Field | Value |
|---|---|
| Role | `council-member` |
| Label | `minimax` |
| Owned path (this pass) | `docs/research/v4-wings-complete-design-20261025-01a171a0/members/minimax/response.md` |
| Requested route (coordinator-supplied, `brief.md` roster) | `minimax/MiniMax-M3; configured adaptive thinking` |
| Effective runtime model / task identity | **not exposed** — I cannot observe a provider payload, billing source or effective model from inside this turn. `brief.md`'s "MiniMax preflight" paragraph observes *configuration*, not a captured effective route. I make no claim about the effective route; runtime metadata is the coordinator's evidence to establish, not mine. |
| Peer outputs read | **none**. I did not read `members/astra/*`, `members/grok/*`, `members/kimi/*`, `coordinator/draft.md`, `coordinator/resolution.md` or `REPORT.md` for this run. |
| Work performed | Reads only, plus writing this one file. No shell, no project tests, no contract/config edits, no Git, no installs, no deployment, no wallets, no delegation. |
| Tooling note | `brief.md` specifies "assigned Markdown creation through `apply_patch`". No `apply_patch` tool is exposed in this session's tool schema (`tool_search` for a patch/create-file capability returned no match), so I used the session's ordinary file-creation tool at exactly the assigned path. I flag this as a **tooling deviation from the brief**, not a scope deviation. |

---

## 2. Question

What is the complete replacement design for the Uniswap V4 Upper Lower Wings Standard Exchange vault — ownership, deposit, share issuance, fees, compounding, maintenance, withdrawal, previews, `getRate`, and use of the share in external liquidity pools — such that (a) every retained overage is fully credited, (b) an exit withdraws the holder's actual proportional claim and sells only that claim's opposing inventory, (c) `getRate` remains a decimal-normalized one-whole-share target exit quote, and (d) the five open audit findings (APEX-2026-012/024/025/026/040) are structurally addressed rather than argued away?

---

## 3. Evidence

### 3.1 Source observations (local files I read; paths relative to `/Users/cyotee/Projects/indexedex`)

**Current V4 Wings source family** (`contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`)

- `UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol:18-22` — `issue(supply_, value_, credit_)`: `shares_ = supply_ == 0 ? credit_ : FullMath.mulDiv(supply_, credit_, value_)`. No sink, no virtual offset; a first deposit mints 1 share per target wei.
- `UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol:24-26` — `entitlement(supply_, value_, shares_) = mulDiv(shares_, value_, supply_)`, i.e. **pro-rata of the whole-book value**, not a slice.
- `UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol:41-53` — `liquidTarget` / `requiredLiquid`: the sleeve denominator is *target-side deployed principal*, percentage from `IVaultFeeOracleQuery.liquidReservePercentageOfVault(address(this))`.
- `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:120-145` — `_deposit`: pull → bootstrap bookkeeping → `_harvest()` → `value = Quote.quote(...).value` → `Accounting.issue` → `minimum_` check → **`if (exact_ != 0) shares_ = exact_;`** → `_changeTarget(assets_, true)` → mint → `_place()`. The caller's exact-share number **overrides** the computed one (`Money.sol:135`).
- `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:147-189` — `_redeem`: `_harvest()` → `value = Quote.quote(...).value` → `assets_ = Accounting.entitlement(supply, value, shares_)` → **`if (exact_ != 0) assets_ = exact_;`** (`Money.sol:163`) → `_fund(required, remaining == 0)` → burn → `_changeTarget(assets_, false)` → `_payTarget` → re-quote and `HolderValueLoss` check → `_place()`.
- `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:190-217` — `_fund`: close wings, then core, then `_swapDeficit`.
- `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:219-233` — `_swapDeficit`: sells the **entire** opposing local balance with `priceLimit = MAX_SQRT_PRICE-1` / `MIN_SQRT_PRICE+1`. This is APEX-2026-024 verbatim.
- `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:244-265` / `:266-282` — `requiredInput` / `preview` both use `_postHarvestValue()`, i.e. the whole-book liquidation quote.
- `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:94-104` — `_harvest()` and `_place()` **return silently when `state.manager.isUnlocked()`** (nested/blocked manager state).
- `UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol:108-113`, `:115-134` — `quote()` / `quoteInventory()`; `:138-146` invalid-state guard; `:298-336` `_sell()` walks the live tick bitmap; `:25` `MAX_STEPS = 512`; `:338-347` `swapCost`.
- `UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol:31` — `request_.stepLimit = 512` hard-coded, no setter.
- `UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol:18-42` — `principal(sqrtPriceX96_, lower_, upper_, liquidity_, roundUp_)`: the removable token amounts of a range are a **pure function of the current price and liquidity** (concentrated-liquidity identity), not a path-dependent balance; `:39-49` `earnedFee` (accrued fee since the position's last checkpoint).
- `UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol:61-64` — `harvestEligible`: Upper is eligible once it holds any token1; Lower once it holds any token0; Core never.
- `UniswapV4UpperLowerWingsStandardExchangeVaultGeometry.sol:16-38` — `ranges()`: Core = `[minUsable, maxUsable]`, Upper = nearest strictly separated boundary to `maxUsable` (token0-only while out of range), Lower = to `minUsable` (token1-only while out of range).
- `UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol:118-129` — `harvest()`: closes converted wings, never swaps; `:130-134` `placement()`; `:147-167` `place()` and `liquidFloor()`; `:169-200` `_affordableLiquidity` (no solver, no swap).
- `UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTarget.sol:22-45` — permissionless `rebalance()`; `:47-65` `_validate` computes `maximumLoss = progress / 100` at the live spot both before and after the vault's own swap.
- `UniswapV4UpperLowerWingsStandardExchangeVaultRebalancePlanner.sol:11-47` — `bestSwap()` binary search (12 candidates, shared 512-step budget) with `priceLimit = sale.sqrtPriceX96` (no reference bound).
- `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol:27-30` — `getRate() = mulDiv(Quote.quote(...).value, 1e18, supply)`: **the whole-book liquidation value divided by supply** — an *average* per-share value, not a one-whole-share exit quote.
- `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol:32-36` — `quoteRate(exchange_, asset_, state_)` returns `getRate()` unless `exchange_ == address(this) && asset_ == target`.
- `UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget.sol:30-33` — `exchangeRate()` = `mulDiv(_liquidationValue().value, 1e18, supply)` — a **second** scalar rate with the same whole-book-average semantics (Pendle SY adapter).
- `UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol:115` — `ERC20Repo._initialize(tokenName, "UV4W", IERC20Metadata(args.targetToken).decimals())`: **share decimals = target decimals**; `:121-128` `_validate` (hookless pool, fee ≤ 1e6, spacing 1..32767, target ∈ {token0, token1}).
- `UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol:9-30` — one storage slot: `initialized, busy, mutations, target0, manager, key, oracle, callbackHash, local0, local1, positions[3], registry`. No parameter slot for a reference price, no per-section accounting, no epoch anchor.
- `UniswapV4UpperLowerWingsStandardExchangeVaultProjection.sol:1-207` — the read-only projection that mirrors `_deposit`/`_redeem` for the shared transition-quote ABI, including `_swap()` and a 16-mutation budget.
- `UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol:40-52` — `execute()`: bounded dispatch (≤8 ops, ≤16 mutations per operation) with a `callbackHash` handshake; `UniswapV4UpperLowerWingsStandardExchangeVaultExecutionDelegate.sol:22-45` — `unlockCallback` settles actual deltas once.

**Rate consumers**

- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:61-84` — `_getRate(state)` calls `_safePreviewExchangeIn(totalShares, state)` (`:112-129`) and returns `out / totalShares`: a **full-supply exit preview divided by supply**. It does **not** consume the vault's `getRate()`.
- `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:133-152` — `rateAfterExchange`: if the provider advertises `IStandardExchangeRateQuote`, call `quoteRate(exchange, pair, state)`; otherwise `IRateProvider.getRate()`.
- `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol:100-121` — `redeem()`/`withdraw()` settle at **actual size** via `previewExchangeIn(exchange, shares, pair)` / `previewExchangeOut(...)`; `:24-30` `rate()` falls back to `IRateProvider.getRate()`.
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawalLib.sol:74,88` — `minOut` derived from `previewExchangeIn(...)` at the actual size (the pattern the hooks already use).

**Audit (required sections), `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`**

- **APEX-2026-012** (anchor near line 268) — High, latent, V4 Wings. Deposit and redeem price shares from `LiquidationQuote.quote()`, which reads live `slot0`, live liquidity and the live bitmap and simulates selling the book into that depth. PoC: **+70,634,405,953 raw token0 (7.1 % of a 1e12 vault) per transaction with zero capital**; settled variant **74,704,386,253 (7.5 % of TVL)** at ≈27× TVL transient capital. In-unlock variant is blocked by the 0 % sleeve but the settled variant is not. `HolderValueLoss` compares two quotes taken in the same inflated state.
- **APEX-2026-025** (anchor near line 1109) — Medium. `rebalance` is permissionless and measures its 1 %-of-progress loss cap at the live spot before *and* after the vault's own swap; R2 (front-run) shows 720 bps holder loss with the cap measuring 0.06 %; R1 (back-run) exceeds the designed cap by 1.78×–12.75×.
- **APEX-2026-026** (anchor near line 1173) — Medium. `stepLimit = 512` hard-coded at `Common.sol:31`; 480 liquidity-1 dust positions (≈480 wei) freeze Alice's redeem, Bob's deposit, `getRate` and `liquidationValue`. At spacing 1 with the vault as sole LP, one ordinary trade bricks the vault. "There is no admin escape." The PRD requires work exhaustion to revert rather than be marked market-limited.
- **APEX-2026-024** (anchor near line 1605) — Low. `_swapDeficit` dumps the **whole** opposing balance at a MIN/MAX price limit; PoC back-run profit +1.428e16 with staying-holder loss 5.3 % (614 bps in the sandwich case).
- **APEX-2026-040** (anchor near line 2141) — Low. No dead-share sink; `PoolManager.donate` inflates fee growth; a victim depositing 190e6 receives **1 share** and loses 43–47 % of the deposit; the attacker recovers the donation and the victim's dilution (+81,818,175 token0).

**Historical / optional context read**

- `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` (v0.4, 2026-10-05) — O1–O7 rulings, §4 state model, §5 geometry, §7 V1–V6 whole-vault-liquidation accounting, §7A owner-directed withdrawal priority, §8 sleeve, §10 "one-share rate semantics must reference canonical target-denominated whole-vault V/S … do not value a share by independently liquidating only one share's basket", §13 gas, §15.2 RV-1…RV-8.
- `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md` (2026-10-23) — the *alternative* owner direction: "a share is a fraction of the position, not a quoted pile of target"; `getRate = settledTarget * 1e18 / supply`; exit removes only `s/S` and sells only that slice; "The sale must not be sized as the whole opposing balance."
- `docs/security/audit/second_review/APEX-2026-012-OPEN-QUESTIONS.md` (2026-10-24, "paused") — preserved rulings: **a deposit does not sell target for the other token**; the sell ban stands for harvest/rebalance; "a share is a fraction of every position, including idle"; "a later deposit does not open a new range"; `getRate` reads the settled counter, not `slot0`.
- `docs/plans/records/uniswap-v4-upper-lower-wings/ACCOUNTING_AND_RECOVERY.md` — the O1–O7 arithmetic as implemented; the "credit is not generally value growth" counterexample; the measured O1 recovery-participation witness; the step-fee allowance model for the remaining-value guard.
- `docs/plans/records/uniswap-v4-upper-lower-wings/GAS_AND_SIZES.md` — measured **estimates, not receipts**: deposit 604,041; quote 98,997; partial redeem 397,473; rebalance 2,590,106; ceiling 15,099,494 (90 % of the EIP-7825 16,777,216 cap); runtime sizes at that checkpoint: money library 21,585 bytes, query facet 12,088, package 8,018.
- `docs/plans/records/uniswap-v4-upper-lower-wings/VALUATION_PARITY.md` — 13 liquidation-suite tests incl. 256 fuzz cases; "the current 512-step cap needs full outer-transaction gas acceptance"; one projection library measured **25,176 bytes (over EIP-170)** and had to be split.
- `docs/plans/records/uniswap-v4-upper-lower-wings/SPECIFICATION_DECISIONS.md`, `ZERO_VALUE_WITNESS.md` — O7 one-native-unit floor; sleeve restoration may require reducing the core.

### 3.2 Coordinator-supplied evidence (from `brief.md`, not independently verified by me)

- The user's current preferences: full economic credit for retained overage; exit = proportional claim + sell only that claim's opposing inventory, payout = actual target recovered under user slippage protection; `getRate` retained as a decimal-normalized one-whole-share target exit preview; arbitrary-size previews quote their actual size; a rate read does not execute the quoted swap; issuance NAV ≠ zap-out valuation; approximate entry/exit swaps alone do not prove APEX-012 is closed; **no reference-price source has been chosen and none may be assumed for arbitrary pairs**.
- The newer candidate: swap ≈49–51 % of a target-only deposit, add matched full-range core liquidity, deposit each token's overage into its wing; the percentage is undecided and is a fraction of the target input.
- The owner allows recommending changes to any expectation, explicitly naming changes and costs.
- Required scope: V4 only; no implementation.

### 3.3 Inferences (mine, derived from the sources above)

- **I-1.** The current `getRate()` is a *whole-book-average* rate, not a one-whole-share exit quote. Because the exit curve is concave (selling a smaller slice has less price impact), `V_total/S` **understates** the marginal exit value of one share, and the gap grows with the vault's inventory relative to pool depth. Keeping the user's preferred semantics therefore requires a **code change**, not a clarification.
- **I-2.** `Inventory.principal` (`Inventory.sol:18`) is a *pure function of (price, range, liquidity)*. Therefore a range's token composition is not a path-dependent balance, and a reference-marked valuation can be written either from the **actual composition at the live price** or from the **as-if composition at the reference price**. The difference between the two is exactly the price-drift term, and the two differ by the reference-vs-market gap multiplied by the opposing exposure.
- **I-3.** Under the as-if-at-reference marking, the mark is *invariant* to any attacker action on the pool (positions' liquidity and bounds do not change), whereas under the actual-composition marking the mark moves by the *realized spread* of the attacker's trade. Both are far less manipulable than the present liquidation quote, which additionally depends on **external depth** — the dominant APEX-2026-012 vector.
- **I-4.** Marking the book by *actual tokens* (not by liquidity) makes **placement value-neutral**: adding ΔL to a range moves `B_T`/`B_O` by the exact tokens spent, so `V` changes by exactly the reference value of what was placed. Liquidity-based or invariant-based marking does not have this property, and it is what makes cross-section compounding and full overage credit fall out for free.
- **I-5.** A **single scalar rate cannot equal actual execution proceeds per share for every redemption size** (brief's own statement, confirmed): proceeds are concave in size. Any rate must therefore declare its quote size.
- **I-6.** The hook family already settles redemptions at **actual size** (`ContextQuoteLib.redeem` → `previewExchangeIn(exchange, shares, pair)`; `WithdrawalLib:74,88` derive `minOut` from it). Therefore the *pool's payout* does not depend on the scalar rate; the scalar rate drives the pool's **internal accounting** (`derivedY`, `invDeltas`, `ratedPairUnits`). That is the precise place a rate consumer is exposed.
- **I-7.** `StandardExchangeRateProviderFacet._getRate` derives a rate from a **full-supply exit preview**, which is the *worst* size to quote for an average rate (most impact, most depth-sensitivity) and is APEX-2026-012's own vector. It does not consume the vault's `getRate()`. Any statement that "the Balancer rate provider consumes the vault's canonical getRate" would be false today.

### 3.4 Unverified claims / disclosed gaps

- No gas number in this document is a measurement. The only gas figures I cite are the repo's own recorded **estimates** (`GAS_AND_SIZES.md`), explicitly not outer receipts.
- I did not run any test, simulation or pool harness. Every attacker-economics figure below is **illustrative arithmetic**, not a demonstrated exploit.
- I did not read the audit PoC sources' Solidity (`indexedex-2ba07631-pocs/**`) beyond the finding text; the PoC numbers I cite are the finding's own reported outputs.
- I did not read `docs/reviews/apex-012-design-recommendation-20261024/members/**` (a prior run's council outputs) to keep this original independent of any earlier member reasoning; I used only the audit, the PRDs and the open-questions record.
- I have not verified whether any deployed Wings instance exists in any registry (the audit calls the family "Latent: not deployed"); deployment eligibility is therefore treated as a design constraint, not an observation.
- I did not verify Chainlink/TWAP availability for any specific pair. No pair is assumed.

---

## 4. Assumptions

- **A-1** The supported product remains: one immutable, hookless Uniswap V4 `PoolKey`, one immutable target token, target-only deposit and target-only payout (PRD O6).
- **A-2** Owner rulings O1–O7 (PRD v0.4) and the 2026-10-24 preserved rulings remain in force unless §7.13 explicitly changes them.
- **A-3** Concentrated-liquidity composition identity holds: a range's token amounts are a function of `(liquidity, range, current price)` (`Inventory.sol:18`).
- **A-4** A reference price source can be *configured per instance* but is **not available for arbitrary pairs**. The design must therefore make it an explicit, deploy-time dependency with a documented failure policy, not an assumption.
- **A-5** "Ownership" of a share means a pro-rata claim on the whole book (idle balances, all three ranges, all accrued fees), consistent with the user's item 4 and the 2026-10-24 ruling.
- **A-6** The repository's Foundry profile, no-viaIR rule, EIP-170 gate and EIP-7825 cap assumptions from `CLAUDE.md` and `GAS_AND_SIZES.md` still hold.

---

## 5. Coverage

| Brief item | Where answered |
|---|---|
| 1 units, state, fungibility, ownership, bootstrap, decimals, rounding, dust, donations, fees, liabilities | §7.1 |
| 2 share issuance equations, both tokens, overage credit, when ownership is established | §7.4 |
| 3 full deposit sequence | §7.4 |
| 4 entry-cost attribution | §7.4.5 |
| 5 full withdrawal sequence, in-kind fallback | §7.5 |
| 6 quotes, one-whole-share normalization, size-dependent impact, projected-state rates, exact-in/out | §7.6 |
| 7 compounding, section attribution, maintenance, who bears cost | §7.7 |
| 8 gas | §7.8 |
| 9 independent price / oracle design | §7.3 |
| 10 attacker economics | §7.9 |
| 11 getRate consumers; raw target vs shares | §7.10 |
| 12 APEX-012/024/025/026/040; reentrancy; liveness | §7.11 |
| 13 validation plan | §7.12 |
| 14 requirement changes, limitations, deployment eligibility, owner decisions, simplest surface | §7.13, §7.14, §9 |
| 4 mandated comparisons | §8 |

---

## 6. Conclusions (short form)

1. **The present vault is not repairable by re-weighting the quote.** Its share price is a *liquidation quote* that depends on external depth (`LiquidationQuote.sol:108-134`), and that is precisely APEX-2026-012. A design that keeps "price the book by selling it into live depth" keeps the exploit.
2. **Replace the valuation primitive, not the parameterization.** Value the book from the vault's *actual token holdings* (idle + the three ranges' removable principal + accrued fees), converted at an **independent reference price**. Then the mark cannot be moved by temporary liquidity or by a price push that does not actually trade against the vault, and the APEX-2026-012 family (JIT depth, in-unlock depth, settled JIT) loses its mechanism.
3. **A reference price is a new, explicit trust dependency.** It must be a per-instance, deploy-time adapter over a market-tracking, manipulation-resistant source (TWAP of a designated *external* pool, or a bounded push/attestation oracle). The vault's own pool may never be the reference — self-reference is the exploit. Pairs with no usable source are **not eligible** for deployment. This is the honest answer to "no oracle exists for arbitrary pairs".
4. **Price the book by tokens, not by liquidity, and placement becomes value-neutral.** That single choice makes full overage credit, proportional cross-section compounding and "no separate section accounts" fall out of the arithmetic instead of needing a policy.
5. **The exit must be an actual-proceeds slice**, as the user requires and as `APEX-2026-012-APPORTIONED-RESERVE-PRD.md` requires: remove `s/S` of every range and of idle, sell **only that slice's** opposing inventory with a **bounded** price limit, pay what was actually received. This simultaneously fixes APEX-2026-024 (no whole-balance dump) and removes the "whole-book liquidation" from the money path.
6. **`getRate()` changes meaning.** Today it is `V_total/S` (`EconomicTarget.sol:27-30`). The user's retained preference is a **one-whole-share target exit quote**. These differ, because the exit curve is concave. I recommend keeping the user's semantics **with a clamp to a band around the reference-marked NAV**, so that the rate a pool consumes cannot be inflated beyond the band.
7. **A scalar rate can never equal actual proceeds for every size.** Declare the quote size: `getRate()` is the quote for **one whole share** (`10^d` shares); every other size is quoted by the size-specific preview.
8. **The "49–51 %" entry swap belongs on a separate, explicitly-sized route, not on the standard deposit.** The standard deposit stays target-only and swap-free (2026-10-24 ruling; keeps the shared transition-quote preview/execution parity intact). The swap size is supplied off-chain and verified on-chain, so **the solver leaves the chain** and the original gas objection disappears.
9. **Exact-output routes cannot be honest under actual-proceeds exits.** Keep the *quantity* quote interfaces the hooks require, define them as mark-derived, and let the consumer set the minimum from the size-specific preview. Remove the two "caller overrides the computed number" hooks (`Money.sol:135`, `Money.sol:163`).
10. **Nothing here is a security proof, and I claim no council consensus.** Every economic figure below is illustrative arithmetic; the findings in §7.11 are *structural arguments* that must be confirmed by the validation plan in §7.12 before any deployment.

---

## 7. Preferred complete design

### 7.0 One-line statement

> **A single fungible ERC20 share over a reference-marked, token-denominated book; deposits priced at a reference-marked book value; exits executed as an actual-proceeds proportional slice; and a size-stated, band-clamped one-whole-share exit quote as the canonical rate.**

Everything below is a consequence of one decision: **the book is valued by the tokens the vault actually owns, converted at an independent reference price.**

### 7.1 Units, state, fungibility, ownership, bootstrap, decimals, rounding, dust, donations, fees, liabilities

**Units and decimals.** Target `T`, opposing `O`; `d = T.decimals()`. The share token keeps `ERC20Repo._initialize(..., IERC20Metadata(target).decimals())` (`DFPkg.sol:115`) — share decimals = target decimals — so one whole share = `10^d` shares and native units never lose precision. Rates are expressed as **target units per 1e18 shares** (the existing `mulDiv(x, 1e18, supply)` convention), which is independent of `d`.

**State.** The existing `Repo.Storage` is extended by exactly three fields:

```
IRefPriceAdapter ref;      // immutable per instance
uint256 deviationBand;     // immutable per instance, in 1e18 bps (see §7.3)
uint256 rateBand;          // immutable per instance, in 1e18 bps (see §7.6)
```

Everything else (three positions, local balances, busy/mutation guards, callback handshake) is unchanged. There is **no per-section share account**, no epoch counter, no per-range share ledger — see §7.7.

**Fungibility and ownership.** One ERC20 class. A share is a pro-rata claim on the **entire** book: idle `F_T`/`F_O`, the removable principal of Core/Upper/Lower, and every accrued fee. Ownership is established at **mint**, against the post-harvest, pre-deposit book; the entrant's claim is `m/S` of the whole post-deposit book.

**Initial liquidity / bootstrap.** The first deposit opens only the **target wing** (Core may stay empty — PRD G2 lazy activation; the maintenance route later builds the core). Bootstrap issuance is `m = credit` (1:1 in native target units), unchanged from `Accounting.sol:21`, so there is still **no sink and no virtual offset** (O3) and the zero-supply lifecycle is preserved.

**Rounding, dust.** Every integer division in the issuance and slice equations floors in the vault's favour and the remainder **stays in the book** (never burned, never refunded to an attacker). The slice removal floors per component (`tT`, `tO`, `ΔL_j`), so a dust remainder stays with the remaining holders — which is exactly the "retained overage belongs to the book" rule.

**Direct donations.** A token transfer to the vault is **unbooked** and therefore **not part of the mark** (`B_T`, `B_O` are built from booked custody and position principal). The existing unbooked-surplus push law (`LocalCreditLib.available`) still lets an authenticated contract caller present surplus as credit; because the surplus is excluded from `V_before`, such a depositor receives shares backed by the donated tokens and the total stays conserved (the depositor's post-mint entitlement equals their credit). *Recommendation:* keep this behaviour but add an explicit `SurplusUnbooked` event so the donor's gift is observable; do **not** silently fold surplus into the mark.

**Fees and liabilities.** Uncollected LP fees are read from the pool (`Inventory.earnedFee`) and are part of `B_T`/`B_O` — i.e. fees are backing before they are collected. The target sleeve (PRD S1, `Harvest.liquidFloor`) and the O7 one-native-unit floor remain liabilities that reduce what can be deployed, not what the holder owns.

### 7.2 The two numbers, never conflated

Let `q` be the pool's live price in the vault's own convention, and for each range `j ∈ {Core, Upper, Lower}` let `(a^T_j, a^O_j)` be the removable principal at `q` (`Inventory.principal`, `Inventory.sol:18`) and `(f^T_j, f^O_j)` the accrued uncollected fees (`Inventory.earnedFee`).

```
B_T := F_T + Σ_j (a^T_j + f^T_j)          // all target units the vault owns
B_O := F_O + Σ_j (a^O_j + f^O_j)          // all opposing units the vault owns

p_ref := target units per 1 opposing unit, from the reference adapter (may be invalid)

V := B_T + p_ref · B_O                    // the reference-marked book value  (target units)
```

`V` is a **mark**, not an exit quote and not a spot mark.

**Explicitly not claimed:** `V` is *not* spot-independent. `B_T`/`B_O` are derived from the live price (I-2), so `V` moves when the price moves — but only through the **realized composition change of the vault's own positions**, i.e. through trades that actually happened against the vault and were paid for. The part of the price move that never touched the vault does not touch `V`. The residual difference between `V` and the market value of the same tokens is

```
basis(V) = B_O · ( p_ref − p_market )
```

which is the honest statement of what a reference-marked share is exposed to (§7.3.3, §7.10).

**The exit number is a different object.** Define `exitQuote(q)` (§7.5) as the target actually obtainable by executing the redemption path for `q` shares at the current pool state. `exitQuote` is size-dependent and concave; `V/S` is not an exit quote for any size. The two must never be substituted for one another.

### 7.3 The reference price: a first-class, per-instance dependency

#### 7.3.1 Adapter

```solidity
interface IRefPriceAdapter {
    /// target units per 1 unit of `base` (base = opposing, quote = target)
    function latestPrice(address base, address quote)
        external view returns (uint256 price, uint256 updatedAt, bool valid);
    function maxAge() external view returns (uint256);          // staleness bound, seconds
    function maxDeviationBps() external view returns (uint256); // consistency bound vs its own source
}
```

**Rules, all mandatory:**

1. The source must **track the market** (a TWAP over a window, or an oracle feed). A constant or slowly-updated feed is not eligible.
2. The source must **not be the vault's own pool**. Self-reference reproduces APEX-2026-012 exactly. A designated *external* pool is fine (and is the only self-hosted option).
3. `price` is quoted as **target per opposing** with the target's native decimals, normalized once at the adapter boundary.
4. `valid == false`, `block.timestamp − updatedAt > maxAge`, or the adapter's own deviation check failing ⇒ **the reference is unavailable**.

#### 7.3.2 Failure policy (fail closed on entry, fail open on exit)

| Operation | Reference unavailable |
|---|---|
| Deposit (issuance) | **Revert** with `ReferenceUnavailable()`. Minting shares at an unknown price is not an option. |
| Withdrawal (actual proceeds) | **Proceed.** The exit does not need `p_ref` to price; it needs a *price limit* for the slice sale, which is derived from the live slot0 with a deviation cap (§7.5). Redemptions must not be blocked by a stale oracle — this preserves SEC-10-style exit liveness. |
| `getRate()` / `quoteRate()` | Return the **last valid** mark-derived band, with `valid == false` signalled through a dedicated view (`referenceStatus()`); consumers that require a live rate fail closed (the hook family's existing `_getRateFailClosed` pattern already fails closed on `rate == 0`). |
| Maintenance (rebalance) | **Revert.** The rebalance's loss measurement is reference-based (§7.7.3). |

#### 7.3.3 Deployment eligibility and the deviation guard

- `DFPkg._validate` must require a configured adapter whose `latestPrice(O, T)` is `valid` at deploy time, and must record the adapter and the two bands **immutably**. A Wings instance for a pair with no usable reference is **not deployable**. This is a deliberate, stated product constraint, not an oversight.
- **Deviation guard (issuance):** before minting, the vault compares the adapter's price with the pool's own implied price and requires `|p_ref / p_market − 1| ≤ deviationBand`. If the band is breached, the deposit reverts with `ReferenceDeviation(requested, available)`. Rationale: `basis(V) = B_O·(p_ref − p_market)` is a **direct transfer from incumbents to a new entrant** whenever the reference and the market disagree — the entrant mints at a mark that is off by `basis`, and redeems at market. The guard converts an unbounded basis transfer into a bounded, temporary loss of *entry liveness*. The cost is a griefing surface: an attacker who sustains a price move beyond the band pauses new issuance. That is a deliberate, bounded DoS traded against an unbounded value transfer.
  - Band choice is an owner decision (§7.14). A starting proposal is **50–100 bps** for liquid pairs, scaled by the reference's own tracking error.

### 7.4 Deposit (full sequence)

The standard route is **target-only and swap-free** (2026-10-24 ruling "a deposit does not sell target for the other token"). The entry-swap route is separate (§7.4.6).

#### 7.4.1 Sequence

1. `begin(deadline)`: initialized, not busy, `deadline ≥ block.timestamp`, registry not disabled, **backing check** (`balance ≥ booked` for both tokens). Revert in the manager-unlocked state (see §7.11.6).
2. **Isolate the caller's credit first** (PRD A3/C2): pull mode measures the exact received delta and rejects short delivery; push mode uses the existing `LocalCreditLib` caller restriction. The pending amount is **not** in `B_T` while the harvest runs.
3. **Harvest** (mandatory, observation-triggered): close harvest-eligible wings and collect fees (`Inventory.harvestEligible`, `Harvest.harvest`). Harvest **never swaps** (A3). The collected fees land in `F_T`/`F_O` and therefore in `B_T`/`B_O` — they belong to the incumbents.
4. **Snapshot the mark**:
   ```
   V_before := B_T + p_ref · B_O            // post-harvest, pre-deposit
   ```
   `V_before` **excludes** the pending credit (A1/C1: never count the contribution twice).
5. **Reference guard** (§7.3.3). If `V_before == 0` with `S > 0`, the deposit reverts (`InvalidAccountingState`) — the A2 "no division by zero workaround" rule stands.
6. **Mint**:
   ```
   credit := assets_                          // full target input; no surcharge, no donation
   m      := (S == 0) ? credit : floor(S · credit / V_before)
   if (m == 0) revert ZeroIssue()
   ```
   `m` is minted to `recipient_` **after** the share count is fixed (see §7.4.3 for the ordering against placement).
7. **Minimum shares**: `if (m < minimum_) revert MinAmountNotMet(minimum_, m)`.
8. **Round-trip guard** (APEX-2026-040):
   ```
   require( floor( m · (V_before + credit) / (S + m) ) >= credit − tol )
   tol := 1 wei + 1 bp · credit
   ```
   With `m = floor(S·credit/V_before)` this holds up to rounding; it **fails** exactly in the APEX-2026-040 trap, where `V_before` has been inflated by a donation and the entrant's minted fraction collapses. (Audit's own suggested form; I adopt it unchanged in substance.)
9. **Book the credit**: `F_T += credit` (the target is now part of `B_T`).
10. **Place** (§7.4.4).
11. **Floor**: after placement, keep ≥ 1 native target unit local while `S > 0` (O7); release on the final redemption.
12. `end()`: re-check backing, update the reserve accounting, clear `busy`.

#### 7.4.2 Exact equations, restated for the two tokens

The issuance equation is written **entirely in target units** because the deposit is target-only:

```
m = 0                       if S == 0 and credit == 0            (ZeroIssue)
m = credit                  if S == 0                            (bootstrap, 1:1 native)
m = floor(S · credit / V_before)   otherwise
```

and the holder's claim after the deposit is

```
claim(T) = m · (B_T + credit + p_ref·B_O) / (S + m)
```

which equals `credit` up to the round-trip tolerance — that is the "full economic credit for retained overage" requirement, expressed as a provable inequality rather than a hope. **There is no limiting-token mint rule and no silent donation anywhere in this path**: the entrant's target is credited at par and every unit the vault retains (idle, wing, core, fees) stays inside `B_T`/`B_O` and therefore inside the mark.

#### 7.4.3 When ownership is established

At **mint**, against `V_before`. The entrant's ownership is `m/(S+m)` of the whole post-deposit book — including the *placement outcome* of their own deposit, because placement is value-neutral (§7.4.4). That is the concrete reason ownership is established at mint and not after placement: if ownership were established after placement, the entrant would absorb the rounding of their own placement and the incumbents would absorb nothing, which is an arbitrary transfer.

#### 7.4.4 Placement (value-neutral by construction)

Because `V` is computed from **tokens**, placing liquidity changes `V` by exactly the reference value of the tokens spent:

```
ΔV = ΔB_T + p_ref · ΔB_O = (tokens actually spent, reference-valued)
```

so **placement cannot create or destroy value** — it only decides where the tokens sit. This is the property that makes the rest of the design work.

Placement rules (unchanged from `Harvest.place`, `Harvest.sol:147-167`):

- Target-side remainder → the **target wing** (Upper when `target0`, Lower otherwise; `Geometry.targetWing`).
- Paired remainder → the **Core**, capped by tick capacity (`_capacityRoom`) and by the affordable-liquidity arithmetic (`_affordableLiquidity`), never by a solver.
- The **sleeve** (`liquidFloor`) is respected: the target reserve left local is `floor(targetTotal · p/(1+p))` of the target-side holdings, with the O7 one-unit floor on top.
- Placement never swaps, never opens a range other than the target wing, and never exceeds the 16-mutation budget.

**Recommendation (deviation from the 2026-10-24 "a later deposit does not open a new range" ruling):** that ruling is incompatible with Wings' lazy activation (a target-only first deposit must fund a wing — PRD §1, G2). It is preserved as "a later deposit does not open a **new** range beyond the target wing, and never re-opens a closed wing's bounds outside the controlled close/settle/reopen lifecycle."

#### 7.4.5 Entry-cost attribution (brief item 4)

**Recommendation:** the **entry swap's realized spread is charged to the entrant**; everything else stays with the incumbents.

- The entrant's own swap's LP fee accrues to the vault's own in-range positions and therefore to the incumbents — it is **not** part of the entrant's credit and is **not** double-counted (`B_T`/`B_O` include accrued fee growth; the entrant's credit does not).
- The **spread** the entrant's swap pays (the difference between the reference-valued tokens given up and the reference-valued tokens received) is a real, caller-specific cost and is charged to the entrant.
- **Placement rounding** remains vault-borne (O4: "the vault pays execution costs from reserves … no placement-cost surcharge"). This is a deliberate distinction and I state it because O4 predates any entry swap.
- **This is a change to O4's payer attribution for the entry swap only** (§7.13, change 6).

#### 7.4.6 The separate entry-swap route (`depositWithEntrySwap`)

```
depositWithEntrySwap(uint256 assets_, uint256 swapTargetIn_, uint256 swapMinOut_,
                     uint256 minimumShares_, address recipient_, uint256 deadline_)
```

- `swapTargetIn_` is **supplied by the caller** and is expected to be computed **off-chain** against a simulated pool (this is where the "49–51 %" candidate lives — the fraction is a decision for the owner, §7.14, and the caller may choose any size that satisfies the vault's checks).
- The vault executes **one** exact-input swap of `swapTargetIn_` target with `swapMinOut_` as the floor, using a price limit derived from `p_ref` ± `deviationBand` (never MIN/MAX).
- **On-chain verification (cheap, bounded, no solver):**
  1. `swapTargetIn_ ≤ assets_`; `swapTargetIn_ ≤ assets_ / 2` is *not* required, but `swapTargetIn_` must leave enough target to fund at least the O7 floor;
  2. the realized spread `spread = max(0, swapTargetIn_ − floor(swapOut · p_ref))` is charged to the entrant: `credit = assets_ − spread`;
  3. `V_before` is re-measured **after** the swap and after harvest, so the swap's effect on the composition is priced into the mark rather than left dangling;
  4. the round-trip guard (§7.4.1 step 8) still applies.
- **Why off-chain sizing is safe here:** a malicious size is self-harming — the caller bears the spread it causes — and the two bounds above (price limit vs the reference; spread charged) make the worst case *the caller's own loss*, not a transfer from incumbents. There is no on-chain root-find, so the "exact proportional zap-in is too gas-expensive" objection is answered directly: **the solver runs off-chain; the chain verifies.**
- **Preview parity:** because the swap size is a parameter, this route needs its own preview (`previewDepositWithEntrySwap`) and is **not** part of the shared `IStandardExchangeTransitionQuote` projection. The standard deposit route remains fully modelled by the existing `Projection` library, so the shared hook integration keeps exact preview/execution parity.

### 7.5 Withdrawal (full sequence)

The exit is the **actual-proceeds proportional slice** — the user's model and the `APEX-2026-012-APPORTIONED-RESERVE-PRD.md` model.

#### 7.5.1 The slice

For `s` shares with `S` outstanding, `φ = s/S`:

```
tT := floor(φ · (F_T + Σ_j (a^T_j + f^T_j)))     // idle + principal + fees slice, target
tO := floor(φ · (F_O + Σ_j (a^O_j + f^O_j)))     // idle + principal + fees slice, opposing
ΔL_j := floor(φ · L_j)                            // liquidity slice per range
```

The floors leave dust with the remaining holders. `tO` is the **only** opposing inventory that may be sold.

#### 7.5.2 Sequence

1. `begin(deadline)`; blocked-manager behaviour per §7.11.6.
2. **Harvest** (mandatory, so the fee slice is real): close eligible wings, collect fees into `F_T`/`F_O`.
3. **Compute the slice** on the post-harvest state; recompute the slice after each removal so the arithmetic tracks rounding.
4. **Remove the slice's liquidity** from the ranges (priority order preserved from PRD §7A, but applied **within the slice only** — see §7.5.3): target-side first (local idle, then the target wing, then the core), then the opposing-side wing, then the core. Never remove more than the slice.
5. **Sell only `tO`**, exact-input, with a price limit derived from `p_ref` ± `deviationBand` (or, when the reference is unavailable, from the pre-call slot0 ± a configured cap) — **never `MIN_SQRT_PRICE+1` / `MAX_SQRT_PRICE-1`**. If the swap cannot fill within the limit, the exit **reverts**; the holder is not forced into a bad price, and no whole balance is dumped (APEX-2026-024 closed by construction: the input is `tO`, not the vault's balance).
6. **Pay**: `payout = tT + targetActuallyReceived`. The LP/protocol fee of the sale is paid by the vault's reserves (O4), the *impact* is borne by the redeemer and is protected by the user's minimum. `if (payout < minimum_) revert MinAmountNotMet(minimum_, payout)`.
7. **Burn** `s` shares and debit `F_T` by `payout`.
8. **Residual**: unsold opposing, rounding dust and over-realization stay in the vault and are re-placed per §7.4.4 or kept idle (never refunded to the redeemer, never swept).
9. **Last holder**: when `S − s == 0`, remove everything, drop the O7 floor, and leave the residual **unowned** (O1/O3: residual inventory is unowned and available to subsequent interaction). The final redemption releases the floor and returns the residual in the target token where realizable.
10. **Non-dilution check (defense in depth):** after payment, compare the remaining book at the **reference-marked** level against `V_before − payout`; a violation beyond the measured execution-cost allowance is an atomic revert (`HolderValueLoss`). Because the mark is reference-priced, this check is **not** evaluated at a manipulated spot (APEX-2026-012's item 3). The allowance is the existing step-fee model (`ACCOUNTING_AND_RECOVERY.md`): per executed step, `ceil((f+1)·r + 1)`.

#### 7.5.3 Change from PRD §7A's priority order (and why)

PRD §7A (2026-10-05) is owner-directed: "use local target, then the target wing, then the opposing wing with conversion, then the core, then convert." The proportional-slice model conflicts with it in one respect: §7A can realize **more** than the holder's slice.

**Recommendation:** keep §7A as the *ordering of operations within the slice*, and add the hard cap **"never realize more than the slice"**. That preserves the owner's ordering preference, satisfies "a share is a fraction of every position", and is exactly what closes APEX-2026-024. The realized overage that §7A wanted ("realization overshoot remains owned by the vault") becomes zero by construction; the residual is then only rounding dust and the slice's own unsellable remainder.

#### 7.5.4 In-kind fallback

**Recommendation: add it, as an explicit opt-in route, not as an automatic fallback.** `redeemInKind(s)` removes the slice and returns `tT` target and `tO` opposing to the redeemer, with no swap. Rationale:

- A proportional slice removal is *always* executable (it is a liquidity removal), so a holder is never permanently stuck: if the market cannot deliver the minimum in target, the holder can still take the slice in kind. That closes the liveness hole that APEX-2026-026 exposes.
- It must **not** be automatic (an automatic basket exit would change the product's economics and the hook integration contract) and it must **not** be the pool-facing route.
- Cost: it widens the public surface, and PRD §3 currently excludes "a proportional basket-exit fallback". This is an explicit requirement change (§7.13, change 8).
- With `redeemInKind` available, the "reference unavailable → issuance reverts, exits proceed" split (§7.3.2) is coherent: exits never depend on the reference being fresh.

### 7.6 Quotes, `getRate`, and preview/execution parity

#### 7.6.1 `getRate()` — the user's semantics, with a clamp

```
ONE_UNIT := 10^d                                   // one whole share
q        := (S < ONE_UNIT) ? S : ONE_UNIT          // quote size, clamped when the book is tiny

rawRate  := floor( exitQuote(q) · 1e18 / q )        // target per 1e18 shares
navRate  := floor( V · 1e18 / S )                   // reference-marked per-share value

getRate() := clamp( rawRate,
                    floor(navRate · (1e18 − rateBand) / 1e18),
                    floor(navRate · (1e18 + rateBand) / 1e18) )
```

- This **is** a one-whole-share target exit quote, as the user requires; it is *not* `V/S` and *not* a NAV.
- The clamp is the only addition, and it is the difference between "a rate" and "a rate a pool can safely pay without redeeming" (§7.10).
- The clamp **can bind** and when it does, `getRate()` reports the reference-marked value rather than the exit quote. Cost: for a book whose inventory is large relative to pool depth, the true one-share exit quote can sit outside the band and the rate will understate it. That is the intended trade, and the *unclamped* number remains available through the size-specific preview.
- `getRate()` does **not** execute anything, does not touch `slot0` as a price source, and is not a function of external depth beyond the depth actually used by the one-share slice sale.
- `SYTarget.exchangeRate()` (`SYTarget.sol:30-33`) must be re-pointed to the same clamped rate; leaving it as `V/S` would publish a second, unbounded, whole-book-average rate to Pendle-style consumers.

#### 7.6.2 Size-dependent previews

- `previewExit(shares)` / `previewExchangeIn(se, shares, target)` → the **unclamped, size-specific** execution quote. "Arbitrary-size previews quote their actual size" — satisfied literally.
- `previewDeposit(assets)` → shares at `V_before` (the standard, swap-free route), matching `Money.preview` (`Money.sol:266`) but on the new mark.
- `previewDepositWithEntrySwap(assets, swapTargetIn)` → shares net of the spread, matching §7.4.6.
- `quoteState` / `quoteTransition` (`IStandardExchangeTransitionQuote`) keep the existing semantics; the `Projection` library must be re-based on the new mark and on the slice exit.
- **Parity rule:** every preview must be produced by the *same* code path as execution (the existing `Projection` design), and the standard deposit route must remain the only route in the shared projection, so hook parity is not weakened.

#### 7.6.3 Exact-input / exact-output

- **Exact-in deposit** (`exchangeIn(target → shares)`): primary; shares computed by the equation; `minimumShares` protects the caller.
- **Exact-in redeem** (`exchangeIn(se → target)`): primary; actual proceeds; `minimumTargetOut` protects the caller.
- **Exact-out routes:** the existing `depositExactShares` (`Money.sol:135`) and `redeemExactAssets` (`Money.sol:163`) **let the caller override the computed number**, which under a mark-based issuance is a caller-chosen price. They must be replaced:
  - `depositExactShares` → the vault computes `m` and the *caller* asserts `m ≥ minimumShares` (i.e. it collapses into the exact-in route).
  - `redeemExactAssets` → under actual-proceeds exits an exact-output is **not honestly implementable**: the payout is whatever the market delivers. The **quantity** interfaces the hook family requires (`IStandardExchangeExactOutputQuantityQuote.quoteSharesForExactAssets` / `quoteInputForExactShares`, used by `ContextQuoteLib.withdrawFromState`) are retained and defined as **mark-derived quantities, explicitly labelled as such**; the consumer's protection is the minimum, which it already derives from the size-specific preview (`WithdrawalLib:74,88`).
  - `requiredInput` (`Money.sol:244`) returns the **quantity** of input implied by the mark, and the same label applies.

#### 7.6.4 Projected-state rate queries

`quoteRate(exchange, asset, state)` (`EconomicTarget.sol:32-36`) currently returns `getRate()` for any (exchange, asset) pair. Under the new design it must return the **projected** clamped rate for the supplied state, and must **not** fall back to the live rate for a foreign pair without saying so. The hook family's `rateAfterExchange` probes for `IStandardExchangeRateQuote` and calls it with the projected state — so this is the hook-facing path and it must be exact.

### 7.7 Fees, compounding, maintenance

#### 7.7.1 Section attribution: there is none, by construction

The vault does **not** maintain per-section share accounts. Because `V` is token-denominated and placement is value-neutral, a fee collected in the target wing and re-placed in the core moves value between **sections of the same holder**, not between holders. Every holder's claim is `m/S` of the whole book at all times.

**Explicit ownership of cross-section reinvestment:** fees accrued in any range are credited to the book (and therefore to all holders pro rata); when they are reinvested, the reinvestment is *also* pro rata because the resulting `ΔB_T`/`ΔB_O` are added to the same `V`. No holder gains from another holder's section. This is the answer to the brief's requirement 7 "section attribution" and to the alternative "separate section/range claims" (§8.3).

#### 7.7.2 Compounding

- Trigger: the mandatory harvest at the start of every idle money operation (A3) plus the permissionless maintenance route.
- Mechanism: collect fees → `F_T`/`F_O` → place into the ranges per §7.4.4, subject to the sleeve and the O7 floor.
- Value effect: `ΔV = ΔB_T + p_ref·ΔB_O` equals the reference value of the collected fees, so **compounding is value-neutral to the share price** and strictly increases the vault's *fee-earning capacity*. That is the correct definition of compounding here: not a rate increase, but more liquidity earning the same fee.
- Fees earned during an entrant's own entry swap accrue to the incumbents (§7.4.5).

#### 7.7.3 Maintenance (`rebalance`) — permissionless, reference-measured

**Recommendation (this is the fix for APEX-2026-025):**

- The loss cap must be measured **at the reference price**, not at the live spot:
  ```
  impact = | ΔB_T + p_ref·ΔB_O |_after-reshape  vs  | ΔB_T + p_ref·ΔB_O |_before-reshape
  require( impact ≤ maximumLoss )
  ```
  This closes R1 (the vault's own trade cancels out of a spot-denominated measurement) and, with the reference-derived price limit, R2.
- The swap's **price limit is clamped to `p_ref` ± `deviationBand`** instead of the projected post-sale price (`RebalancePlanner.sol:40`).
- The swap's **input is capped** (`RebalancePlanner` currently searches up to the full local balance).
- Progress requirement retained: the rebalance must increase core liquidity or reduce the target-sleeve deficit; otherwise `NoRebalanceProgress`.
- Caller-supplied `minimumValueAfter` may only **tighten** the protocol bound.
- No keeper reward; the vault's inventory pays the trading cost (A4); the caller pays gas.
- **The 2026-10-24 "sell ban"** applies to *harvest* ("Harvest does not sell the other token"). The maintenance route's balancing swap was explicitly permitted by PRD §8/S2 and by the open-questions record ("Is this swap removed? The 025 loss-cap finding stays open either way"). **Recommendation:** keep the maintenance swap, with the reference-measured cap. Rationale: without it there is no path to a two-sided core from a target-only book, and the fee-earning requirement fails. Cost: the balancing swap remains a permissionless, market-touching operation; the reference-measured cap and the price clamp bound it, and the validation plan (§7.12) must attack it.
- `rebalance` must revert in the manager-unlocked state (no nested session) and must leave state untouched on revert.

### 7.8 Gas — where the work actually is

**No gas measurement is claimed here.** The only figures I cite are the repo's own recorded **estimates** (`GAS_AND_SIZES.md`: deposit 604,041; quote 98,997; partial redeem 397,473; rebalance 2,590,106; eight-leg Weighted join subcalls 1.59 M–5.57 M; ceiling 15,099,494 = 90 % of EIP-7825 16,777,216) — explicitly *not* outer receipts, and the projection library once measured 25,176 bytes, over the EIP-170 gate.

**Bounded arithmetic vs tick traversal — the distinction that matters:**

| Work | Bounded? | Cost driver |
|---|---|---|
| Book snapshot (3 positions, principal + fee growth) | **Yes** — O(1) ranges, O(1) fee reads | 3 `getPositionInfo` + 3 `getFeeGrowthInside` + 3 `getSlot0`-class reads |
| Mark `V = B_T + p_ref·B_O` | **Yes** — one multiply | negligible |
| Placement arithmetic (`_affordableLiquidity`) | **Yes** — closed-form `LiquidityAmounts` | negligible; no solver |
| Slice arithmetic (per-component floors) | **Yes** | negligible |
| **Exit quote / sale simulation** | **No** — walks the live tick bitmap | `LiquidationQuote._sell`, one step per initialized tick or empty word |
| Entry-swap sizing | **No, but off-chain** | the solver leaves the chain |
| Maintenance balancing search | **No** — 12 candidates × ≤512 steps | `RebalancePlanner.bestSwap` |

**Where the solving happens.** The three historically expensive items separate cleanly:

1. **The proportional zap-in solver** → **off-chain**. The caller supplies `swapTargetIn_`; the chain verifies the bounds and charges the spread (§7.4.6). *This removes the original gas objection outright.* It also removes the on-chain binary search that the earlier strategy needed, at the cost of a caller-side simulation and a slightly weaker on-chain guarantee (the caller may pick a bad size, which is self-harming).
2. **The valuation tick walk** → stays on-chain, but it must be made **bounded by price distance rather than by crossings** (§7.11.4). The current walk costs one step per initialized tick *or per empty bitmap word*, so ~3,466 steps at spacing 1 with no external liquidity (APEX-2026-026) and one step per dust tick. Bounding by price distance and skipping dust ticks converts an attacker-controlled work budget into a protocol constant.
3. **The maintenance balancing search** → stays on-chain but is **not on the user money path** (PRD S2), and its 12 × 512-step budget must be measured as an outer transaction, not a subcall.

**Consequences for the product:** a consumer hook that re-quotes the vault repeatedly must reuse the projected state, not re-walk the bitmap (`Projection` already caches `cachedProceeds` against `cachedOpposing`; that caching must survive the redesign, and the design must expose the same reuse so the eight-leg Weighted join does not multiply the walk). The `quote`-only path must be separately budgeted (the repo measured 543,786–651,248 gas for isolated subcall quotes).

### 7.9 Attacker economics (illustrative arithmetic, not demonstrated exploits)

The design's defences are structural, so the interesting question is what an attacker *can* still do and what it costs.

**(a) Temporary depth (JIT) before a deposit.** The attacker's temporary liquidity changes the pool's depth, not the vault's holdings. `V` is token-denominated, so `V_before` is unchanged ⇒ the minted `m` is unchanged ⇒ **profit 0**. This is the APEX-2026-012 in-unlock variant and its settled twin, and the mechanism is gone: the quote no longer reads external depth for pricing. *Cost to the attacker: the temporary liquidity's own gas and the unwind.*

**(b) Temporary depth before a redemption.** The slice sale does read depth, so a deepened pool would give the redeemer a *better* price — that is a gift to the redeemer, not a profit to the redeemer. The attacker cannot profit by deepening; they can only *deepen to make the exit look attractive*. The relevant risk is the reverse (removing depth to make the exit look bad), which pushes the price and is bounded by the deviation band and by the holder's minimum.

**(c) Price push before a deposit.** To move `B_T`/`B_O` the attacker must trade against the vault's own in-range liquidity, i.e. **pay the spread**. The mark moves by the realized spread only, and in the direction that *raises* the mark (the LP earns the spread). A raised mark means the entrant mints **fewer** shares ⇒ **no profit for the attacker**, and the transfer goes to the incumbents. The attacker's cost is the spread plus the unwind.

**(d) Sustained price displacement (the real residual).** If the reference is a TWAP and the market is displaced from it, then
```
basis(V) = B_O · (p_ref − p_market)
```
and a deposit priced at `V` mints shares whose *market* value differs from the credit by that fraction. An attacker who sustains a displacement and deposits at the favourable end captures the difference from the incumbents. **Bound:** the deviation guard (§7.3.3) refuses issuance once `|p_ref/p_market − 1| > deviationBand`, which caps the capture at roughly `deviationBand × (opposing share of the book)`. With a 50–100 bps band and a ~50 % opposing share, the worst case is roughly **25–50 bps of the book per deposit**, and it requires the attacker to *sustain* the displacement against the vault's liquidity. This is the single most important number in the design and it is an owner parameter (§7.14).

**(e) Donation (APEX-2026-040).** `PoolManager.donate` raises the vault's fee growth ⇒ raises `B_T`/`B_O` ⇒ raises `V` ⇒ the next depositor mints fewer shares (diluted). The round-trip guard (§7.4.1 step 8) rejects the degenerate case (the audit's PoC: victim receives 1 share for 190e6). The attacker still donates real value to the vault and can recover part of it; the guard removes the rounding collapse, not the donation itself. **Residual:** with a large donation the victim's dilution is bounded by the donation's size relative to `V`, and the guard's tolerance is the bound.

**(f) Rebalance sandwich (APEX-2026-025).** With the loss cap measured at the reference price and the swap's price limit clamped to the reference band, a front-run must push the price beyond the band to matter, and the clamp makes the vault's own swap execute inside the band. The cap can no longer be neutralised by the vault moving the spot itself.

**(g) Exit manipulation.** The exit sells `tO` only, with a bounded price limit; a searcher front-running it captures the spread the searcher creates, but the redeemer's minimum transfers the loss to the redeemer, not to the remaining holders. The remaining holders' exposure is the composition change from the sale (they are the counterparty), which is the intended design ("the remaining position taking the other side of an exit sale is intended").

**(h) What is deliberately *not* defended.** The share's mark is not a market NAV; §7.10 states the guarantee honestly. And the design does not defend the holder from the vault's own inventory risk (an LP position is not risk-free).

### 7.10 `getRate` consumers — what can honestly be guaranteed

**The consumer map (source-observed):**

1. `StandardExchangeRateProviderFacet._getRate` (`StandardExchangeRateProviderFacet.sol:61-84`) derives a rate from `previewExchangeIn(totalShares, rateTarget)` — a **full-supply exit preview divided by supply**. It does **not** consume the vault's `getRate()`. A full-supply exit is the *worst* size to average (maximum impact, maximum depth sensitivity) and is exactly the APEX-2026-012 shape. **Recommendation: the provider must consume the vault's bounded `getRate()`/`quoteRate()` instead of deriving its own rate from a full-supply preview.** This is a required change in `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/`, and it is the difference between the Balancer side being safe and being the weakest link in the system.
2. The hook family (`UniswapV4SeBufferHookLegLib.rateAfterExchange`, `:133-152`) calls `quoteRate(exchange, pair, state)` when the provider advertises `IStandardExchangeRateQuote`, else `IRateProvider.getRate()`. The Wings `EconomicTarget` implements both, so the Wings vault can be its own provider — and then `quoteRate` must return the **bounded** rate, including for foreign pairs (today it silently returns the unbounded `getRate()`).
3. The hook's **settlement** is at actual size: `ContextQuoteLib.redeem` (`:100-112`) uses `previewExchangeIn(exchange, shares, pair)`; `WithdrawalLib:74,88` derive `minOut` from the size-specific preview. **The pool's payout therefore does not depend on the scalar rate** — the rate drives the pool's internal accounting (`derivedY`, `invDeltas`, `ratedPairUnits`). That is the exact exposure point.
4. `SYTarget.exchangeRate()` (`SYTarget.sol:30-33`) publishes a second scalar (whole-book average) to Pendle-style consumers; it must be re-pointed to the bounded rate.

**The honest guarantee the preferred integration can make:**

- `getRate()` is bounded within `rateBand` of the reference-marked NAV rate, and the reference-marked NAV is bounded by the reference's own tracking error plus the deviation guard's refusal to issue outside the band.
- The rate is **not** a promise of realizable proceeds at any size. It is a one-whole-share quote, clamped.
- A pool that **settles at actual size** (which the existing hooks do) is exposed only in its **internal accounting**, and the accounting error is bounded by `rateBand` × the pool's share exposure plus the reference's tracking error.
- A pool that **pays out without redeeming** is exposed to the *full* gap between the reference mark and the market, i.e. `B_O × (p_ref − p_market)`. **No design eliminates this**; it is the price of a reference-marked share. The mitigation is to size the pool's share exposure against it, or to settle at actual size.
- **Raw target and shares are NOT economically interchangeable.** A share is a pro-rata claim on a pooled LP position whose realizable value depends on the market price, the pool's depth, and the vault's own inventory; the raw target token is a fixed quantity. A hook must treat the share leg as a rate-bearing claim and must not assume a 1:1 mapping.

### 7.11 APEX-2026-012 / 024 / 025 / 026 / 040 — structural implications

#### 7.11.1 APEX-2026-012 (High)
- **Root cause removed:** the share price no longer comes from `LiquidationQuote.quote` (`LiquidationQuote.sol:108-134`). The money paths use `V = B_T + p_ref·B_O`, which depends on the vault's own tokens, not on external depth. The JIT-depth and settled-JIT variants lose their mechanism.
- **Residual:** the reference-vs-market basis (§7.9d), bounded by the deviation guard. The audit's suggested "mint at max(V_live, V_ref)" is *not* adopted — it keeps a manipulable term in the mint path.
- **Not claimed:** this is an argument from the source structure, not a demonstrated defence. §7.12's round-trip and depth tests must confirm it.

#### 7.11.2 APEX-2026-024 (Low)
Closed **by construction**: the exit's swap input is `tO` (the slice), never the vault's opposing balance (`Money.sol:219-233` is replaced), and the price limit is reference-derived rather than MIN/MAX. The "whole opposing balance is dumped" path disappears.

#### 7.11.3 APEX-2026-025 (Medium)
- Loss cap measured at the **reference** price, not the spot ⇒ R1 cannot cancel out.
- Swap price limit clamped to the reference band ⇒ R2's front-run must exceed the band to help, and the vault's own execution is bounded inside it.
- Swap input capped; progress requirement retained.
- **Residual:** the rebalance remains a permissionless, market-touching operation. It must be attacked in testing (sandwich, repeated calls, keeper-then-arb) and the guard must be parameterized.

#### 7.11.4 APEX-2026-026 (Medium)
- The step budget must be changed from **"crossings"** to **"price distance + dust skipping"**: skip initialized ticks whose net liquidity is dust (a liquidity-1 tick absorbs no flow but costs a step), and bound the walk by price distance rather than by the number of empty bitmap words. The PRD's requirement that work exhaustion *revert* rather than be marked market-limited is preserved.
- A **deploy-time check** must enforce that a full empty-word walk fits the budget for the configured spacing (`DFPkg._validate`).
- The mark (`V`) **does not depend on the tick walk at all** — it is three principal computations. So `getRate()`'s *mark* component is immune to the dust-tick DoS even before the walk is fixed. The *clamped* rate still needs the one-share exit quote, so the walk fix remains required for `getRate()`; the alternative is to derive the clamp band from the mark and skip the walk when the band cannot bind — a legitimate simplification I recommend: **`getRate()` computes the walk only when `rawRate` could exceed the band**, otherwise return the band directly. That makes the DoS-free path the common one.
- The dust-tick DoS must still be able to freeze the *exit*, because the exit needs a real sale. Hence the in-kind fallback (§7.5.4) and the price-distance bound.

#### 7.11.5 APEX-2026-040 (Low)
- The round-trip guard (§7.4.1 step 8) is the substantive fix and is adopted essentially as the audit wrote it.
- The bootstrap remains 1:1 with no sink (O3), so the guard — not a sink — is the protection. The guard's tolerance (1 wei + 1 bp) is the accepted rounding cost; it must be a documented, bounded constant, not a "generic one-wei allowance" (PRD §11's prohibition).

#### 7.11.6 Reentrancy and nested manager-unlock
- `begin()` must **revert when `state.manager.isUnlocked()`** (the audit's smallest fix for APEX-2026-012): today `Money.begin` (`Money.sol:41-48`) has no such check, and `_harvest`/`_place` silently no-op in that state, so a nested session can deposit or redeem against a *transient* pool state. Under the new design this is a hard revert, and the views (`getRate`, `liquidationValue`, `preview`, `requiredInput`) must revert identically rather than quote a state that execution would refuse.
- **Read-only reentrancy:** `quoteRate`/`quoteState` must not observe a transient state. `Projection` already refuses while `busy`; the new views must keep that and must additionally refuse while the manager is unlocked (or must quote the *projected* post-unlock state, which is what `Projection` does via `blocked`).
- **Nested manager-unlock contexts:** the current `blocked` path pays from local cover only, with a typed `InsufficientLocalTarget(requested, available)`. That behaviour is preserved. But the *mark* used while blocked must still be the reference mark — computed from the book, not from a transient depth.
- The `callbackHash` handshake (`Common.sol:40-52`, `ExecutionDelegate.sol:22-45`) and the 16-mutation budget are unchanged and remain the structural defence against forged/replayed callbacks.

#### 7.11.7 Liveness and dust ticks
The vault must never be permanently frozen. Two mechanisms: (i) the price-distance-bounded walk (§7.11.4) and (ii) the in-kind exit (§7.5.4). Note the tension with the PRD's requirement that work exhaustion revert rather than be market-limited: the *rate* may revert on exhaustion, but the *exit* must remain available — which the in-kind route guarantees.

### 7.12 Validation plan (production-first; **not executed** in this assignment)

Per `CLAUDE.md` (production-first, no SUT mocks, gold TestBases, `forge build` before `forge test`) and `docs/plans/records/uniswap-v4-upper-lower-wings/`:

**Invariants (stateful fuzz)**
1. `V = B_T + p_ref·B_O` equals an independent Python/TypeScript reference recomputation of the three ranges' principal and fee growth at the same price — for both target orientations, every range configuration and the price extremes.
2. `Σ holder claims = V` after every operation, within the declared rounding tolerance; no holder's claim decreases across a non-exiting operation (beyond declared costs).
3. Placement is value-neutral: `ΔV` equals the reference value of the tokens placed, for every placement path (core, wings, sleeve, dust).
4. `claim(entrant) ≥ credit − tol` after every deposit (the round-trip guard is never violated by a legitimate deposit).
5. The remaining holders' non-dilution condition `V_after/(S−s) ≥ V_before/S − allowedCosts` in full-width cross-multiplication, evaluated at the reference mark.
6. Conservation: `B_T`/`B_O`/booked custody reconcile with actual balances after every operation; `BackingDeficit` never fires on a well-formed path.

**Attacker round trips**
7. JIT depth around a deposit → identical `m` with and without the temporary liquidity (APEX-2026-012's test 3).
8. Settled JIT depth → identical `m` (APEX-2026-012's settled variant).
9. In-unlock deposit/redeem → reverts with a typed error; no state change.
10. Donation inflation (APEX-2026-040): victim deposit must revert or mint a fair fraction; `attackerProfit ≤ 0` (PRD SEC-03).
11. Rebalance sandwich, front-run and back-run, with the reference-measured cap; assert fair loss ≤ the designed cap (APEX-2026-025).
12. Forced-dump exit: assert the swap input equals the slice's opposing inventory and never the vault balance; assert the price limit is inside the band (APEX-2026-024).
13. Dust-tick DoS: 480 liquidity-1 positions; assert deposit, redeem and `getRate` still work; assert the walk's step count is bounded by price distance (APEX-2026-026).
14. Reference deviation: displace the market beyond the band; assert the deposit reverts with `ReferenceDeviation` and the exit still proceeds; assert a stale reference blocks issuance but not redemption.
15. Basis capture: sustain a displacement within the band and assert the entrant's capture ≤ `deviationBand × opposing share` (the §7.9d bound).

**Integration**
16. Every hook family × assignment matrix in `docs/plans/records/uniswap-v4-upper-lower-wings/CONSUMER_MATRIX.json`, with the new rate semantics; the eight-leg Weighted join, the quad-stable and Orbital legs, single/dual constant-product, both target orientations, same-manager and different-manager nesting.
17. The Balancer rate provider: assert it now consumes the vault's bounded rate and that a manipulated pool cannot move the provider's rate by more than `rateBand` (this is the `probe-se-rate-provider` scenario re-run against the new design).
18. SY round trip: `exchangeRate()` equals the bounded `getRate()`; the Pendle-style consumer settles at actual size.

**Gas (outer receipts)**
19. Record full outer transaction receipts (intrinsic + calldata + nested calls) for: swap-free deposit, deposit-with-entry-swap, one-share quote, full exit, in-kind exit, maintenance rebalance, the eight-leg Weighted join. Compare against the chain cap and the EIP-170 gate; report the failing configuration rather than raising the harness limit (PRD §13).

### 7.13 Explicit changes from current preferences and expectations

| # | Change | From | To | Cost / who pays |
|---|---|---|---|---|
| 1 | `getRate()` semantics | `V_total/S` (`EconomicTarget.sol:27-30`) | one-whole-share target exit quote, clamped to a band around the reference-marked NAV | Understates the true one-share exit quote when the band binds; consumers wanting the exact number must use the size-specific preview. `SYTarget.exchangeRate()` changes with it. |
| 2 | Share price basis | whole-book liquidation quote (`LiquidationQuote.quote`) | token-denominated mark at an independent reference price | Requires a per-instance reference adapter; pairs without one are **not deployable**; the mark is not a market NAV (basis exposure §7.10). |
| 3 | Exit | `floor(s·V/S)` of a whole-book liquidation value (`Accounting.entitlement`) | actual-proceeds proportional slice: remove `s/S` of every range and idle, sell only that slice's opposing inventory, pay what was received | The holder's payout becomes market-dependent (they bear impact); the remaining holders' composition changes; exact-output routes become mark-derived quantities, not guarantees. |
| 4 | Withdrawal priority | PRD §7A may realize beyond the holder's slice | §7A ordering applied **within** the slice; never realize more than the slice | Realization overshoot is eliminated; dust remains with the book. |
| 5 | `depositExactShares` / `redeemExactAssets` | the caller overrides the computed number (`Money.sol:135`, `:163`) | the vault computes; the caller asserts a minimum | The caller loses the ability to name its own price; exact-output quantity quotes remain, relabelled as mark-derived. |
| 6 | Entry-cost payer | O4: the vault pays execution costs from reserves | the **entry swap's realized spread** is charged to the entrant; placement rounding and harvest costs stay vault-borne | The entrant pays the spread it creates; incumbents are not diluted by a caller's routing choice. |
| 7 | Deposit route | (new) | the standard deposit stays target-only and swap-free; a **separate** `depositWithEntrySwap` carries the caller's off-chain-sized swap | Two deposit routes and two previews; the shared transition-quote projection covers only the standard route. |
| 8 | In-kind exit | PRD §3 excludes a proportional basket-exit fallback | `redeemInKind(s)` added as an **opt-in** route | Wider surface; must not become the pool-facing route; the hook integration does not use it. |
| 9 | Maintenance swap | 2026-10-24 "sell ban" applies to harvest | harvest never sells; the **permissionless maintenance** route may swap, with a reference-measured cap and a banded price limit | Keeps a permissionless market-touching operation alive; the guard is parameterized and must be attacked. |
| 10 | Range opening | "a later deposit does not open a new range" | preserved except the target wing, which lazy activation requires | A later deposit may open the target wing if it is closed. |
| 11 | Rate provider | `StandardExchangeRateProviderFacet` derives its rate from a full-supply exit preview | it consumes the vault's bounded rate | A change in `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/`; the Balancer side stops being the weakest link. |
| 12 | Reference dependency | none | per-instance `IRefPriceAdapter`, immutable bands, deploy-time validity check | Deployment eligibility narrows to pairs with a usable reference source. |

### 7.14 Limitations, owner decisions, and the simplest implementation surface

**Limitations**
- The share's mark is a reference mark, not a market NAV; the basis exposure is real and stated, not eliminated.
- A pool that pays out **without redeeming** carries the basis exposure; the hook family that already settles at actual size does not.
- The reference source is a new trust assumption (a TWAP or an attestation oracle). It is strictly weaker than "the vault's own pool", but it is not trust-free.
- The deviation guard introduces a bounded issuance liveness cost.
- Nothing here is a security proof. No exploit was demonstrated; no gas was measured.
- The design assumes the target token is not rebasing and has no transfer fee (repository token law), and that the pool is hookless (`DFPkg._validate`).

**Decisions genuinely left to the owner**
1. The reference source per pair (TWAP of which external pool? or an attestation oracle?) and its staleness bound.
2. `deviationBand` and `rateBand` (starting proposal 50–100 bps and 50–200 bps; the second must exceed the first, since the rate band is applied on top of the mark's own tracking error).
3. The entry-swap fraction: the "49–51 %" candidate is undecided; my recommendation is that the **caller** chooses the size per deposit (off-chain), with the vault enforcing the bounds, and that a fixed default fraction be offered as a convenience for routers.
4. Whether the entry-swap route may be used by the shared hook projection (I recommend no).
5. Whether `redeemInKind` is exposed publicly (I recommend yes, opt-in).
6. Whether the maintenance route may swap (I recommend yes, with the reference-measured cap).
7. The minimum first-deposit size, if any, beyond the round-trip guard (I recommend none; the guard suffices and a minimum conflicts with O3's zero-supply lifecycle).
8. Whether the share token keeps target decimals (I recommend yes, unchanged).

**Simplest implementation surface**
- `Repo.Storage`: +3 fields (`ref`, `deviationBand`, `rateBand`).
- New library `UniswapV4UpperLowerWingsStandardExchangeVaultMark.sol`: `book()`, `V()`, `slice()`, `roundTripGuard()` — pure arithmetic over three positions, no state.
- `Accounting`: replace `issue`/`entitlement` with the mark-based equations; keep `liquidTarget`/`requiredLiquid` unchanged (the sleeve denominator is settled).
- `LiquidationQuote`: keep for the **exit sale simulation** (it is the right tool for a bounded slice sale); stop using it for the share price. Add the price-distance bound and dust skipping (§7.11.4).
- `Money`: rewrite `_deposit` (mark-based issuance, round-trip guard, optional entry swap) and `_redeem` (proportional slice, bounded sale, actual payout); drop `_swapDeficit`'s whole-balance behaviour.
- `EconomicTarget`: `getRate()` = clamped one-whole-share exit quote; `quoteRate()` = projected clamped rate; `SYTarget.exchangeRate()` = the same.
- `RebalanceTarget`: reference-measured loss cap, banded price limit, capped input.
- `DFPkg`: adapter in `PkgArgs`, deploy-time validity check, immutable bands.
- `StandardExchangeRateProviderFacet`: consume the bounded rate.
- New: `IRefPriceAdapter` + at least one adapter (external-pool TWAP) + one attestation adapter.

---

## 8. Alternatives considered, and the strongest objection

### 8.1 Alternative A — *Fungible portfolio shares, independent-reference valuation, actual-proceeds exits, execution-quoted getRate* → **PREFERRED**
This is §7. It is the only candidate that satisfies **all four** of the user's stated requirements simultaneously: full overage credit (token-denominated mark), an actual-proceeds proportional exit, a one-whole-share execution-quoted rate, and fungibility that composes in external pools. Its costs are the reference-price trust assumption, the basis exposure, the deviation guard's liveness cost, and a narrowed deployment set.

### 8.2 Alternative B — *Oracle-free, strictly proportional position ownership with off-chain zap sizing and cheap on-chain verification/refund*
**Shape:** no price anywhere. The deposit is swapped (off-chain sized) so that the added liquidity is a uniform proportional add `ΔL_j = λ·L_j` across the three ranges; shares are minted as `λ·S`; the on-chain check is one cross-multiplication (the added (ΔA,ΔB) must match `λ·(A_tot,B_tot)` within tolerance); any deviation is refunded.

**Strengths:** no oracle, no basis exposure, no manipulation surface at all in issuance, and an exact fractional-claim property for every holder. It is the closest thing to the 2026-10-23 apportioned-reserve PRD and the 2026-10-24 ruling "a share is a fraction of every position".

**Why it is not preferred:**
1. **It cannot credit a mixed overage.** The deposit is target-only; after the swap, the residual overage is in the opposing token, and λ is set by the *tight* of the two component constraints (`min(ΔA/A_tot, ΔB/B_tot)`). The residual is retained by the book and dilutes the entrant by construction — precisely the "silent donation under a limiting-token rule" the user rejected.
2. **It cannot produce a target-denominated rate at all.** With no price, there is no way to express "target per share" except by liquidating, which reintroduces the depth dependency (APEX-2026-012) or by a stored counter (a settled-counter index, not an exit quote).
3. **The proportional-add rule fights the Wings geometry.** A target-only first deposit must open a target wing (no existing range to be proportional to); a wing whose boundary the market has crossed is no longer one-sided; and `ΔL_j = λ·L_j` cannot respect tick capacity or the sleeve. The "uniform λ" invariant is not compatible with a three-slot book with capacity limits.
4. **The exact root requires the live swap function**, so the caller must simulate the pool anyway — the same off-chain dependency as Alternative A, without the price.

**Adopted from B (this is the important part):** the *discipline* — the solver leaves the chain, the caller supplies the size, the chain verifies cheaply and bounds the result, and a bad size is self-harming. Alternative A adopts that discipline for the entry swap (§7.4.6).

### 8.3 Alternative C — *Separate section/range claims (multi-ERC20, ERC1155, or a fixed-basket wrapper)*
**Shape:** Core, Upper and Lower each issue their own claim token; a holder redeems each section separately; compounding re-issues per section.

**Strengths:** no cross-range valuation is ever needed — each section is homogeneous, so a section's value is its own tokens; compounding is explicit per section; the "which section did my fee come from" question is answered by construction.

**Why it is not preferred:**
1. **It destroys the composability the user asked for.** "a single-target-token exit quote/rate allowing shares to be used in liquidity" requires *one* transferable claim a pool can hold and price. Three section tokens (or an ERC1155) cannot be held by the existing buffer hooks, which take a single SE share token and settle it with `previewExchangeIn` (`ContextQuoteLib.redeem`). The whole consumer matrix in `CONSUMER_MATRIX.json` assumes one share token.
2. **The composite still needs a price.** A consumer holding all three sections must value the bundle; that is the same valuation problem, relocated.
3. **Cross-section compounding becomes a transfer decision** that must be specified ("ownership of cross-section reinvestment must be explicit") — the very question the token-denominated mark answers for free (§7.7.1).
4. **It is a much larger surface**: three ERC20s (or ERC1155), three deposit/redeem routes, three fee ledgers, three bootstraps.

### 8.4 Alternative D — *Invariant-based alternatives*
- **Geometric-mean / product invariant** (`√(A·B)`): **rejected**. The brief itself warns that `√(aggregate actual token reserves product)` is not manipulation-resistant for heterogeneous ranges; concretely, the three ranges have different compositions and the product of the *totals* is not conserved by adding or removing a slice of one range, and a pool-price push changes the totals in a way that a single product does not pin. It also fails for one-sided books (product = 0).
- **Liquidity-share (L-based) minting**: **rejected**. Liquidity units in a narrow in-range wing and in the full-range core are not value-comparable (`LiquidityAmounts` amounts per unit of L differ by orders of magnitude), so `ΔL/ΣL` is not a value share. This is the classic error the brief flags.
- **Settled-counter / fee-index (the 2026-10-23 apportioned-reserve PRD's `getRate = settledTarget·1e18/supply`)**: **the strongest alternative, and the one I would pick if the rate-consumer requirement were dropped.** Strengths: no price, no basis exposure, no manipulation surface in the rate at all (it moves only on vault operations), trivially safe as a pool pricing oracle, and it preserves "a share is a fraction of every position". Weaknesses: it does not reflect the market at all, so it drifts away from the realisable value of the book; it cannot answer "what would one share fetch now"; it is **not** the user's retained `getRate` semantics; and it silently changes the share from a claim on a *position* to a claim on an *accounting balance*. If the owner values rate-consumer safety above rate fidelity, this alternative should be preferred over mine. I do not choose it because the user explicitly retained the one-whole-share exit quote and because a rate that never moves is of little use to a pool that must mark the share.

### 8.5 Strongest counterargument against my preferred design

> **"You have replaced a valuation bug with a trust assumption and a basis risk, and you have told the owner that the share's rate is not the market value. The audit's own preferred fix — price against a manipulation-resistant `V_ref`, mint at `max(V_live, V_ref)`, redeem at `min(V_live, V_ref)` — does the same job without a new per-instance oracle dependency, and your `getRate()` clamp plus the deviation band is a band-aid on a rate that is still a mark. Worse: the whole design now *requires* a reference price for an arbitrary token pair that does not exist, so the flagship product becomes un-deployable on most pairs; and the counter-intuitive result — that a legitimate depositor is systematically diluted by `basis(V)` whenever the market is away from the reference — means the product's own users are the attack surface. Under the settled-counter alternative the share is exactly a fraction of the position, the rate is provably unmanipulable, and none of this exists. Why are you proposing a design whose primary defence is a number the owner has to guess?"**

**My answer, honestly.** The counterargument is right about three things and wrong about one.

- *Right:* the design's safety rests on the reference's quality and on two owner-chosen bands. That is a real, permanent operational dependency, and I have priced it: it narrows the deployable set, it introduces a bounded issuance DoS, and it creates a basis transfer whose size is `deviationBand × opposing share`. I do not think these are reasons to reject the design; they are reasons to make the bands conservative, to measure the reference's tracking error per pair, and to prefer a TWAP over a push oracle wherever a liquid external pool exists. I would rather the owner chose a 25 bps band knowingly than discovered a 5 % basis after launch.
- *Right:* the "one-whole-share exit quote" rate is not a redemption guarantee, and any pool that pays without redeeming eats the basis. I state this plainly in §7.10 rather than pretending otherwise, and the clamp plus the actual-size settlement already used by the hooks are the mitigation.
- *Right:* the audit's `max(V_live, V_ref)` / `min(V_live, V_ref)` asymmetry is a reasonable alternative to my deviation guard and is cheaper to adopt (no new bands). I reject it because it keeps a **manipulable** term (`V_live`) in the mint path, which is the mechanism APEX-2026-012 demonstrates, and because it makes the issuance price depend on a quantity that the attacker controls. If the owner prefers the audit's form, the change is small and the cost is that APEX-2026-012's root mechanism survives in diluted form — I would not recommend it.
- *Wrong:* the settled-counter alternative does not remove the basis risk; it **relocates** it. With a counter, the share's value is the vault's accounting balance, and the *realisable* value of a slice is still the market's. A pool holding the share under a settled counter is exposed to the **entire** gap between the accounting balance and the realisable value — which is unbounded and unmanaged, whereas my basis is a bounded, measurable, band-limited quantity. The counter is not a free lunch; it is an *unpriced* version of the same exposure. What the counter genuinely buys is that the *rate* cannot be inflated within a transaction — a property I also have, because my rate is clamped to a reference-marked band that no depth manipulation can move.
- The remaining, irreducible disagreement: the user explicitly retained the one-whole-share exit quote as `getRate`. I have honoured that and added a clamp. If the owner decides that rate fidelity matters less than rate fidelity's *absence of any basis*, the settled-counter design is the better product and I would support switching. I do not think the current evidence forces that switch, and I would want the §7.12 depth and basis tests run before recommending it.

---

## 9. Limitations of this response

- Independent original; no peer outputs, no coordinator draft, no consensus claim.
- No security proof, no exploit demonstration, no gas measurement, no test execution, no implementation.
- All attacker-economics numbers are illustrative arithmetic on stylized books, not production figures.
- No reference-price source is assumed to exist for any pair; the design makes it an explicit, per-instance, fail-closed dependency and states the eligibility consequence.
- Line numbers are navigation aids taken from the files as read on 2026-10-25; symbols are the durable anchor.
- The reference-price adapter interface, the deviation band, the rate band, the entry-swap fraction and the in-kind route's exposure are **proposals**, not owner-ratified.
- I did not read the audit's PoC Solidity; the PoC outputs I cite are the findings' own reported numbers.
- I did not read the 2026-10-24 prior council's member outputs, to keep this original independent of earlier member reasoning.
- The `IRefPriceAdapter` shape, its adapters, and the TWAP/attestation oracle choices are **my design**, not existing repository code; `IVaultFeeOracleQuery` (the existing fee oracle) is a different surface and is not reused for pricing.
