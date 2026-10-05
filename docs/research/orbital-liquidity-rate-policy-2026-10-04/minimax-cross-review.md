# MiniMax M3 — cross-review (≤1000 words)

- **Inputs:** three peer originals in `docs/research/orbital-liquidity-rate-policy-2026-10-04/` (`astra-original.md`, `grok-original.md`, `kimi-original.md`).
- **Acknowledgment:** Kimi K3 disclosed incidental exposure to two peer snippets during broad grep in its first pass. I treat Kimi's findings as the best evidence available from Kimi under that independence limitation; I do not assume Kimi's conclusions are invalid.
- **Method:** peer findings read as untrusted evidence; primary code and product law re-checked at cited paths. My original preserved at `minimax-original.md`; corrections below.

## 1. Corrections to my original

**Correction 1 (Kimi, Grok).** I claimed rated `fullBookShares` is "bit-identical" to a raw-share computation for buffered legs. **Wrong for non-identity rates.** `ratedNative` is `mulDiv(shares, rate, scale)` with floor (`ClaimLib.sol:317–322`). `fullBookShares` floors per-leg before taking min (`Math.sol:156–161`). The two floors do not cancel: per Grok's example, `mulDiv(3, 5e17, 1e18) = 1`, `mulDiv(6, 5e17, 1e18) = 3` → rated ratio `1/3` vs raw `1/2`. The rated path is **rate-cancelling in exact arithmetic** but **not bit-identical under floor**, and the drift scales with SE-fee/decimal mismatch. Identity-rate + matched-decimal is the only case where it is bit-identical. **Confidence: high (fact).**

**Correction 2 (Kimi, Astra).** I said proportional exit is "rate-free" without conditions. **Right for the payout path, but with a conditional liveness hole.** `_maybeMintProtocolFee` (`Common.sol:899–915`) reads `_effectiveWad()` only when `feeOn && kLast != 0` (lines 900–902); `_snapshotKLastIfFeeOn` (lines 918–929) reads it when `feeOn`. Both run inside `_removeLiquidityAndSettle` (lines 1276, 1364) **after** the LP payout. So: fee-off **or** first-ever exit (kLast == 0) ⇒ rate-free; fee-on after first fee-charging op ⇒ rate is read post-payout. A dead/zero-rate provider bricks the fee-accounting step and reverts the whole exit. **Confidence: high (fact).**

**Correction 3 (Kimi).** I treated PRD line 226 ("No zap-out in v1") as ground truth. **Stale.** `WithdrawTarget.sol:136–177` ships `exitSingleAssetExactBptIn` (raw pro-rata + residual `_swapExitResidual`/`_internalSwapExactIn`, `Common.sol:1951`). The addendum and the B6 remediation PRD did not retract this; the prose is just out of date. **Confidence: high (fact).**

**Correction 4 (Astra).** I cited the implementation plan header as v0.5; Astra cites the PRD header as v0.6 (2026-08-04). **Both are correct**: the impl plan header still says v0.5 (`UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md:6`); the PRD is v0.6 (`UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md:5`). No conflict in law; treat as a doc-drift signal. **Confidence: high (fact).**

**Correction 5 (Kimi).** I missed the family-scoped divergence: **Weighted D23/Q7** (`weighted/UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md:61, 318, 437`) puts **all** LP ops — join, exit, first-mint `V`, one-token aliases — on **inventory only** with **no `getRate()`**. The agent-law sentence "`kLast` … on the rated book" is Orbital-only (per APEX D63); for Weighted, `kLast` is inventory-domain too. **Family difference, not contradiction, but PRD-level.** **Confidence: high (fact).**

## 2. Agreements with all three peers

- **Law:** APEX D59 (plan.md:149) + D60 (open-item-10 PR lines 1–13) + D63 (plan.md:153); agent-law § "Uniswap V4 SE buffer hooks …" lines 233–243; Orbital PRD addendum lines 828–834. Liquidity = raw; swap invariant = rated. We agree.
- **Moderator's "bug solely because rated `fullBookShares`" claim: not established.** Peers strengthen the rejection: rated-vs-raw drift is a real rounding/face-fallback hazard, not a guaranteed exploit. We agree.
- **`WeightedFundedBindingTest` claim unverified.** Grok, Kimi, and my grep all fail to locate a FullSpread-proving file; `V4FundedBindings.t.sol` binds `SimpleYieldERC4626`, not FullSpread. We agree.
- **Aperture PRD out of scope** for this question (line 62 excludes Orbital inversions). We agree.
- **`_proRataOut`/`_burnAndPay` payout is raw** (`Common.sol:1287–1368`). We agree.
- **First-mint and `kLast` stay rated on Orbital** per D63. We agree.
- **`_claimIn` face-amount fallback** at `ExitQuoteLib.sol:380–381` is a known drift when `minted == 0`. We agree.

## 3. Specific objections I want recorded

- **Grok:** the stronger divergence vs. raw law is `_computeFullBook` / `_partialMinShares` (`Common.sol:988–1090`, `1162–1184`), not the zap planner. The zap planner is rate-cancelling mod rounding; partial join mixes raw face numerators with rated denominators (a different unit mismatch). **Accepted.** My original underweighted this; partial-join unit accounting is the priority enforcement site, not `_planDeposit`.
- **Kimi:** PRD text "no zap-out in v1" is stale; `exitSingleAssetExactBptIn` exists. **Accepted; see Correction 3.**
- **Astra:** "old planner fits gas" unverified; **31M OOG comment** in `Common.sol:1929–1931` is a comment, not a measurement; `foundry.toml` `gas_limit = 30_000_000_000` is a Foundry ceiling, not a chain measurement. **Accepted.** No peer or I has measured gas on the current bytecode.

## 4. Remaining dissent

None on law or roadmap. One operational disagreement on emphasis:
- **Astra and Kimi** treat the post-payout fee-accounting liveness hole as the primary risk; **I** underweighted it (Correction 2). Net: their prioritization is correct.

## 5. Evidence gaps

- No forge runs (forbidden).
- No verification of today's `phase2-release-001-hermetic.log` against current bytecode (Grok notes historical COMPATIBLE rows with rejection-overrides).
- No wei-trace of `_planDeposit` cancellation under non-identity rate.
- No gas measurement of `_planDeposit` / `_faceForClaim` / `_invertBufferForEffective` on current bytecode.
- `WeightedFundedBindingTest` file does not exist; prior claim retracted.
- Kimi's incidental peer-snippet exposure is a partial independence limitation; findings stand.

## 6. Plain-English recommendation (the actual answer)

| Operation | Quote rates? | Why |
|---|---|---|
| Proportional `addLiquidity` / `removeLiquidity` (raw math), and `proportionalJoin` / `proportionalExit` | **Never** | Ownership must not move when a provider moves. The face-amount / SE-share-count division has no use of a rate. **Compliance fix needed: `_computeFullBook` (`Common.sol:988–1090`) and `_partialMinShares` (`:1162–1184`) currently use `_effectiveWad()` (rated).** Rewrite on `balanceOf(se)` for buffered legs and on raw face for raw legs. |
| First mint (`shares = sumWad − MIN`) and `kLast` / `usageFeeOfVault` protocol mint | **Yes, rated book stays** (APEX D63; Orbital-specific; Weighted differs) | D63 explicitly preserves rated first-mint scale and rated `kLast` on Orbital. |
| Zap-in `depositSingle`: internal sequential swaps (`_swap`, `_saleBudget`) | **Yes** | Sphere is rated (D60 swap invariant). |
| Zap-in `depositSingle`: post-swap LP mint | **Never** | Mint the post-swap inventory at the raw share ratio; rate presence in `_planDeposit` (`ExitQuoteLib.sol:272–295`) is a floor/face-fallback hazard, not a true bug. **Compliance fix: rewrite `_planDeposit` to use `IERC20(se).balanceOf(hook)`-based share ratio; drop `_claimIn` rated path for the mint.** |
| Single-asset joins (`_entryJoinSingleAssetExactIn`, SE-share branch unwraps to pair, then raw) | **Never** | Already conforms. |
| Single-asset exit `exitSingleAssetExactBptIn` (`WithdrawTarget.sol:136–177`) | **Split** | Raw pro-rata withdrawal, then rated sphere for the residual swap leg. Current shape is right. |
| Fee accounting post-payout (`_maybeMintProtocolFee`, `_snapshotKLastIfFeeOn` at `Common.sol:899–929`, called at `:1276, :1364`) | **Conditional rate read** | Dead/zero provider bricks the whole exit when fee-on and `kLast != 0`. **Compliance fix: either specify a fee-off raw-payout path or document that protocol-fee-active instances require a working rate provider.** |

**Distinguish in plain English:** raw in-kind liquidity = ownership math; actual conversions = SE buffer/unwrap quotes (must execute the SE); internal swaps/zaps = priced on the rated book; bookkeeping (fee mint, kLast snapshot) = rated per D63.

**No implementation executed. No peer cross-review read. No tests run.**

---

*End of cross-review. Original preserved. Saved to `docs/research/orbital-liquidity-rate-policy-2026-10-04/minimax-cross-review.md`.*