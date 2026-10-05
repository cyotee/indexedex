# Orbital liquidity rate policy — Kimi K3 cross-review

**Author:** Kimi K3. **Date:** 2026-10-04. Inputs: my original (`kimi-original.md`, preserved unchanged) plus Astra, Grok, MiniMax M3 originals read in full, together, as untrusted evidence. Contested points re-checked against primary code before adoption.

## Disclosure

In my first pass, one repo-wide grep incidentally surfaced two peer file snippets (file names and two fragments) before I had written my findings. I did not open the files and based all findings on primary sources; I cannot prove zero subconscious influence, but every load-bearing claim in my original carries an independently read path:line citation, and the corrections below come only from full reads performed now plus fresh primary-code verification.

## Agreements (all four researchers, or three-plus)

1. **Policy split:** liquidity issuance/proportional exits = raw balances (raw face / live SE share balances); the swap invariant, including swaps inside zaps and single-asset exits = rated book. Law: `INDEXEDEX_AGENT_LAW.md:233-242`; APEX plan `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md:149-153` (D59/D60/D63); Orbital addendum `…ORBITAL_BUFFER_HOOK_PRD.md:828-835`. Matches the user's stated law.
2. **Proportional exit payout is raw (conforms):** `Common.sol:1287-1316, 1319-1368, 1789-1817`.
3. **Moderator's assertion overclaimed:** "`_planDeposit` is a bug *solely* because it uses rated effective + fullBookShares" — not established as stated. All four reject the "solely" framing; the substantive issues lie elsewhere.
4. **`WeightedFundedBindingTest` is not FullSpread evidence:** `test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol:171`; TestBase binds `SimpleYieldERC4626` stubs (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol:38-55`); zero `FullSpread` occurrences in the file.
5. **"Old planner fits gas" unverified.** Grok adds the only local evidence is a comment (`Common.sol:1929-1931`: re-quoting inside the 31M cap OOGs on the second leg) and `foundry.toml:38` ceiling — a comment, not a measurement. Astra: aperture plan D11 demands matched-state gas evidence; none exists.
6. **Aperture refactor out of scope for this policy** (`docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md:62` excludes Orbital inversions).

## Corrections to my original (evidence that changed my view)

1. **Rate-failure liveness — I was wrong; Astra is right; Grok's "does not block `_proRataOut`" is only true of the view math.** My original said "with fees off, liquidity is rate-free." Re-verified: `_burnAndPay` unconditionally calls `_recomputeL2()` (`Common.sol:1362` → `:472-480`, rated `_effectiveWad()` when `R != 0` and supply remains) and `_syncVaultReserves()` (`:1366` → `:459-469`, rated `_effectiveNativeAt` on all legs). The fee reads are gated (`:899-903, 918-929`), but these two post-payout bookkeeping reads are **not**. So a dead/zero rate provider reverts proportional exits **even with growth fees off**; only `supply == 0` skips `_recomputeL2`, and `_syncVaultReserves` still runs. Corrected: rate failure currently bricks essentially all Orbital liquidity operations on books with a buffered leg.
2. **Rounding severity — I under-weighted it.** My "≤1 unit per term" was absolute per-term error; Astra (`held=3, minted=1, rate=1.5` → raw mint 4 vs rated mint 3) and Grok (`mulDiv(3,5e17,1e18)=1` vs `mulDiv(6,5e17,1e18)=3` → 1/3 vs 1/2) show the floored `ratedNative` (`ClaimLib.sol:317-322`) can change which leg binds and shift the mint by large *relative* amounts on small books. **MiniMax's "bit-identical under raw-share rewrite" claim is false in general** (holds only when no truncation: identity rate, equal decimals, divisible values). Adoption: rated-vs-raw is algebraically cancelling but **not** bit-identical; the divergence is rounding-bounded per term yet unbounded in relative effect near dust.
3. **Cancellation has an explicit hole I under-flagged:** `_claimIn`'s face fallback (`ExitQuoteLib.sol:379-381`: `minted == 0 → return amount`; `rated == 0 → amount`) and `ClaimLib.previewBufferClaimIn:309` insert raw face units into a rated ratio when SE previews return 0 — breaking cancellation structurally, not just numerically (Grok's "concrete hazard"; Astra's equivalent note). I upgrade this from footnote to a genuine coordination hazard.
4. **Partial joins are worse than I found.** Grok's addition, verified: `_partialUsed` (`Common.sol:1147-1158`) floors the rated-native `used` and pulls it **as face** with no `_invertBufferForEffective`, whereas the full-book path converts back (`:1106-1113`). Combined with my `_partialMinShares` raw-face/rated-denominator mix (`:1162-1184`), partial/single-sided joins (`_singleSidedPlan`, `:2021-2033`) are the weakest-conforming liquidity path, not the zap planner.
5. **MiniMax refuted on single-asset joins:** "conforms verbatim (no rate read)" is wrong — `_depositSingleFromBalance` calls `_planZap` (`Common.sol:1864`), i.e. the rated zap path. MiniMax's "no zap-out in v1" is also stale against `WithdrawTarget.sol:136-173` (Astra, Grok, and my original agree the code ships single-asset exit).
6. **Grok's FullSpread matrix evidence partially rehabilitates the compatibility question (not the fixture claim):** an Orbital × `UniswapV4FullSpreadStandardExchangeVault` suite exists with COMPATIBLE header and historical `passed: 10, failed: 0` JSON (`docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json:3746-3767`), with some rows overridden to blocked-accounting/exact-out-rejected. Past-suite evidence, not a current green run; the "WeightedFundedBindingTest proves it" formulation remains unsupported.

## Remaining dissent / unresolved

- **Framing of rated join/zap mint:** Grok calls rated `fullBookShares` "legal only as a cancellation accident"; MiniMax calls it "not a correctness defect"; Astra and I sit between — conformity by linearity, violation of D59's *expression*, real rounding/fallback hazards. Consensus recommendation (raw-share rewrite) is shared; the severity label is not.
- **MiniMax's quote/execution rate-drift point on the mint:** real only through rounding terms; the swap legs already accept drift by design. I rank it below the liveness and partial-join issues.
- **D63 scope:** Astra warns D63 (first-mint scale and `kLast` rated) is CP-context and must not be silently extended over Weighted's stricter inventory-only law (`…WEIGHTED_BUFFER_HOOK_PRD.md:61,318`; inventory-domain code confirmed `WeightedBufferHookTarget.sol:310-314`, `WeightedBufferHookMath.sol:261-274` per Grok). Orbital's own PRD D27 ("LP NAV + kLast use effective only", pre-addendum line 282) vs the addendum remains a documentary tension no one resolved.

## Evidence gaps (shared)

No forge runs, no wei-level differential test of rated-vs-raw mint across rate/decimals matrices, no current gas measurement of `planDeposit`/`_faceForClaim`/`_invertBufferForEffective`, no verification that the historical matrix JSON matches today's bytecode, `LegLib.rateAfterExchange` internals unread by me, no owner ruling on the Weighted-vs-AGENT_LAW `kLast` tension or the PRD D27-vs-addendum tension.

## Plain-English recommendation

Classify by sub-operation, not API name:

- **Raw in-kind liquidity (no rates):** proportional joins and exits should be computed as `shares × liveRawBalance / supply` (face for raw legs, `balanceOf(se)` share ratios for buffered legs, with SE buffering previews only to convert edge amounts to shares). Exit payout already does this; join paths (`_fullBookSharesUsed`, `_partialMinShares`/`_partialUsed`) should be rewritten to it — fixing both the D59 expression and the partial-join unit mix.
- **Actual conversions (buffer/unwrap):** always use the SE's own buffering quotes (`previewExchangeIn`/`exchangeIn`/`exchangeOut`) — never rates, never 1:1 assumptions.
- **Internal swaps / zap sizing:** rated sphere book with fail-closed rate reads — required, correct today.
- **Bookkeeping (`kLast`, protocol-fee LP, radius/L2, vault reserve views):** rated per D63/first-mint exception — but decide explicitly whether a dead provider may freeze redemptions; if liveness is required, gate or raw-ify the post-payout `_recomputeL2`/`_syncVaultReserves` reads on exits, or specify a raw in-kind recovery route (Astra's framing), because today they make exits rate-dependent regardless of fees.

No code, tests, or config changes made or authorized by this document.
