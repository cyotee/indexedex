# Grok — Orbital liquidity rate policy (original, 2026-10-04)

**Author:** Grok (xai/grok-4.7), independent first pass. No peer findings read. No tests executed.

**Question.** For Orbital liquidity ops, quote rates for every operation, only zap-in/zap-out, or never (raw balances only)?

**Answer.** Quote rates only for the internal swaps inside zap-in and single-asset exit. Proportional joins and proportional exits stay on raw balances / live share ratios. Not every liquidity operation. Not never: a sphere zap cannot be sized without the rated book.

## Law (fact)

Current law beats the 2026-08-04 Orbital implementation plan where they conflict.

- APEX D59 (2026-09-21) and D60 (2026-09-21, signed off): liquidity, LP issuance, and proportional exits use raw balances of the concrete reserve; the virtual swap invariant uses rated reserves. Source: `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md:149-150` and `docs/audits/apex-2026-09-17-open-item-10-cp-hook-rate-providers-PRD.md:7-15`.
- D63 (2026-09-23): later joins and exits follow raw balances; first-mint scale and `kLast` stay on the rated book (`plan.md:153`).
- Agent law and the hook skill repeat that split (`docs/agent/INDEXEDEX_AGENT_LAW.md:233-241`; `.claude/skills/indexedex-uniswap-v4-hook-packages/SKILL.md:112`).
- Orbital addendum (2026-09-22): swap valuation is `shares x rate`; liquidity uses raw balances; buffered-leg LP follows the share ratio; exits are pro rata in raw shares and raw tokens (`UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md:828-835`). The sentence that rated `ExitQuoteLib` paths are “the only valuation” means the only allowed *reserve valuation* (no SE self-quote). It does not order LP algebra onto rated coordinates. The next bullet forbids that.
- Weighted addendum is the same rule (`UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md:920-926`). Weighted D23/Q7 already put all liquidity in inventory units and rates on swaps only (PRD lines 318, 437).
- Compiler observed: `foundry.toml:29` `solc = "0.8.35"`. Access date for local files and Context7: 2026-10-04.

**Assumption.** “Intended law: liquidity uses raw balances to avoid price manipulation” is the D59/D63 reading, not a new ruling.

## What the code does (fact)

**Proportional exit matches raw law.** `_proRataOut` / `_burnAndPay` (`UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:1287-1357`) pay `shares * rawReserve / supply` or `shares * IERC20(se).balanceOf(hook) / supply`, then unwrap that share slice. No `getRate`. `exitProportional` is that path (`WithdrawTarget.sol:107-122`).

**Later proportional join does not.** `_computeFullBook` → `_fullBookSharesUsed` (`Common.sol:988-1083`) ratios `previewBufferClaimIn` (shares minted × rate, `ClaimLib.sol:392-407`) against `_effectiveWad()` (`Common.sol:336-355` → `ClaimLib.effectiveNative:376-389`, shares × rate). `joinProportional` calls `_addLiquidity` (`DepositCore.sol:158-169`).

**Partial / single-sided join is a worse unit mix.** `_partialMinShares` (`Common.sol:1162-1183`) divides face `a0Max` by rated `_effectiveNativeAt`. `_partialUsed` (`1147-1148`) then treats that rated-native used amount as the face pull. Full-book converts back through `_invertBufferForEffective` (`1106-1112`). Partial does not. `_singleSidedPlan` (`2021-2033`) uses this path when the ratio zap is skipped.

**Zap-in is two coordinates in one function.** `ExitQuoteLib._planDeposit` (`ExitQuoteLib.sol:272-295`) is reached from `planDeposit` (`241-246`) and `_planZap` (`Common.sol:2000-2012`). `_depositSales` (`297-314`) feeds rated WAD reserves into `zapSplitWad`. That split is the rated sphere (D59 swap invariant). `fullBookShares` then mints from rated claims (`_claimIn`, `376-381`) over rated `legs[i].effective`. Execution settles the planned swap output and does not re-quote (`Common.sol:1929-1944`).

**Single-asset exit already splits the two jobs.** `exitSingleAssetExactBptIn` (`WithdrawTarget.sol:136-172`) removes pro rata in raw units, then `_internalSwapExactIn`. `ExitQuoteLib.preview` (`29-47`) withdraws `shares * balance / supply` (`49-67`) and rates `effective` only for the later sphere sale (`73-82`, `135-144`).

**Fees.** Trading fee is only `applyTradingFeeNet` on the sphere inflow (`ExitQuoteLib.sol:140-142`; `Math.sol:115-116`). Protocol LP uses the rated geometric mean (`Common.sol:899-909`; quote twin `_depositSupply` at `ExitQuoteLib.sol:384-398`). That matches D63, not a liquidity-ownership quote.

**Rate failure.** `getRateFailClosed` reverts on revert, short return, or zero (`ClaimLib.sol:332-337`). `rateAfterExchange` does the same (`UniswapV4SeBufferHookLegLib.sol:133-149`). A dead provider blocks rated joins and zaps. It does not block `_proRataOut`.

**Weighted gold, not a zap twin.** Proportional join uses `_nativeAt` = raw reserve or `balanceOf(se)` (`WeightedBufferHookTarget.sol:310-314`) and `_pairToInvPreview` = buffering `previewExchangeIn` to shares (`626-642`). `proportionalJoinShares` is the min raw ratio (`WeightedBufferHookMath.sol:261-274`). No rate. Weighted single-asset join is inventory-domain `singleJoinExactInShares` (`LiquidityTarget.sol:477-495`), not an Orbital sphere zap. Do not copy that function as the zap template.

## Moderator assertion (not established)

“Bug solely because `ExitQuoteLib._planDeposit` uses rated effective and `fullBookShares`” is an overclaim.

- Those rated reserves are required for the zap *split*. Removing them would price the internal swaps off the raw share count, which D60 rejects for a buffered leg.
- The mint half is the D59 issue, and only if cancellation fails. Same per-leg rate on numerator and denominator cancels when `ratedNative` (`ClaimLib.sol:317-321`) is linear and truncation-free. Identity `rate == 1e18` with equal decimals is `mulDiv(shares, 1e18, 1e18) = shares`.
- **Inference, not executed:** a non-identity rate does not always cancel. `mulDiv(3, 5e17, 1e18) = 1` and `mulDiv(6, 5e17, 1e18) = 3`, so the rated ratio is `1/3` against a raw share ratio of `1/2`. WAD/decimal floors can do the same. `_claimIn`’s `rated == 0 ? amount : rated` (`ExitQuoteLib.sol:380-381`) inserts face units into a rated ratio. That is a concrete hazard, not proof of a live exploit.
- The stronger observed divergence is later `_computeFullBook` / `_partialMinShares`, which the assertion did not cite. Proportional exit is already raw.

**Counterargument.** If every production provider is identity and every SE mint is 1:1, rated `fullBookShares` equals the share ratio and the economic bug is dormant. That does not make the coordinate legal under D59, and it does not cover partial joins.

## Prior claims not verified here

- `WeightedFundedBindingTest` (`test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol:171-177`) binds ERC-4626 `SimpleYieldERC4626` SEs (`TestBase_UniswapV4Detf_Weighted.sol:55-56, 141-142`). It checks bond/SY debits, package size, and selectors. It does not construct a FullSpread vault.
- Orbital × `UniswapV4FullSpreadStandardExchangeVault` has its own suite. Header says COMPATIBLE (`..._SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:8-11`). Several rows are overridden to `assertBlockedAccounting` or `assertExactOutRejected` (lines 21-42). Fixture exact-out helper expects revert (`SeMatrix_FullSpreadV4Fixture.sol:388-405`). Historical matrix JSON records `state: COMPATIBLE`, `passed: 10`, `failed: 0`, log `phase2-release-001-hermetic.log` (`docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json:3746-3767`). That is a past suite result, including rejection rows. It is not a green run of today’s bytecode, and it is not evidence that every FullSpread route is an exact gold path.
- “Old planner fits gas” is not verified. The only local statement is a comment that a second quote inside a 31M chain cap OOGs and surfaces as `RateProviderFailed` (`Common.sol:1929-1931`). `foundry.toml:38` `gas_limit = 30000000000` is a Foundry ceiling, not a chain measurement. No gas snapshot was read or produced.

## Policy by operation

| Operation | Rate quote? | Why |
| --- | --- | --- |
| Proportional join / exit | Never | Ownership must not move when a provider moves. Exit already does this. Join should ratio live shares (buffering preview of shares minted, not × rate) against `balanceOf(se)` or raw face. |
| First mint and `kLast` | Rated book stays | D63. Not a later-join precedent. |
| Zap-in split and zap internal swaps | Yes, rate read | Sphere is rated. One fail-closed `getRate` / `quoteRate` per leg. Do not value the reserve by `quoteAssets` or full-balance `previewExchangeIn`. |
| Zap LP mint after swaps | No | Mint the post-swap inventory at the raw share ratio. Rated `fullBookShares` is legal only as a cancellation accident. |
| Single-asset exit | Split | Raw pro-rata withdrawal, then rated sphere for residual swaps. Current execute shape is the right split. |
| SE transition simulation | Only where execution buffers, unwraps, or sequences swaps | `quoteState` / `quoteTransition` is the expensive part (`ExitQuoteLib._withdraw` 61-67, `_swap` 90-98, `_faceForClaim` search 347-373). Not a substitute for a rate, and not required to compute a raw share ratio. |

**Manipulation.** A movable rate rewrites swap prices by design (rated book). It must not rewrite LP supply. Quoting rates on proportional joins reopens that. Quoting them only on zap swap legs does not, if the mint after those swaps is raw.

**Liveness.** Keep proportional exit (and a corrected proportional join) free of rate reads so a dead provider cannot freeze redemption. Fail closed on zap and single-asset-exit swaps. Do not re-simulate the zap quote on the execute path; the 31M comment is a reason to settle the plan, not a measured gas budget.

**Aperture.** `docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md:62` leaves `_faceForClaim`, `_invertBufferForEffective`, and `zapSplitWad` out of that refactor. It is not this rate ruling.

## External note

Context7 `/balancer/docs`, query on rate-provider application, 2026-10-04: Composable/Meta Stable pools scale raw balances by `getRate()` before stable math; weighted pools use rates mainly for yield fees, not spot. Source: https://github.com/balancer/docs/blob/main/docs/reference/contracts/rate-providers.md. Local D59’s “Balancer rate-scaled method” is the rated *swap* book. D59’s raw LP rule is a local departure from scaling BPT itself. Not independently re-derived from Balancer join code.

## Confidence and gaps

- Policy split: **high** (locked D59/D60/D63 plus weighted inventory code plus Orbital exit code).
- “`_planDeposit` is a bug solely because it is rated”: **reject**, high confidence the “solely” is false; medium that non-identity rates change the mint (formula only).
- Partial-join unit mix: **high** that the conversions differ; medium that it mis-pulls in production (not executed).
- FullSpread / gas claims: **not adopted**.

**Missing.** No forge run, no wei trace of `ratedNative` cancellation, no current gas of `planDeposit` vs a 30M/31M tx, no check that today’s FullSpread suite still matches the JSON. Historical Orbital plan (zap-out non-goal, optional RP) is superseded by the addendum and by `exitSingleAssetExactBptIn`.
