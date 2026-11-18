# Identity

| Field | Value |
| --- | --- |
| Member label | minimax |
| Profile | research |
| Phase | initial independent response |
| Requested role | council-member |
| Requested model and reasoning | minimax/MiniMax-M3, adaptive thinking, not a selectable depth |
| Run ID | v3-fullspread-v4-accounting-prd-20261116 |
| Owned path | `docs/research/v3-fullspread-v4-accounting-prd-20261116/members/minimax/response.md` |
| Peers read before submission | no |

Runtime identity not exposed by this assignment: task identifier, session identifier, provider account, tool surface, wall-clock timing, and model build hash are all **not exposed**. The assignment supplied only the fields in the table above.

# Question and targets

**Question.** What requirements must a PRD state so the Uniswap V3 full-spread Standard Exchange vault processes deposits, exits, dust, and share issuance in the same manner as the Uniswap V4 full-spread Standard Exchange vault; which current V3 behaviors must that PRD retire or preserve; and which differences are a new product decision rather than a copy of V4?

**Targets read (behavior template is the V4 full-spread vault).**

- `contracts/vaults/standard/exchange/protocols/uniswap/v3/` — `UniswapV3FullSpreadStandardExchangeVaultInBase.sol`, `UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol`, `UniswapV3FullSpreadStandardExchangeVaultOutBase.sol`, `UniswapV3FullSpreadStandardExchangeVaultCommon.sol`, plus `InTarget`, `InMultiTarget`, `InMultiQueryTarget`, `InQueryFacet`, `OutExecutionDelegate`, `OutMultiTarget`, `OutQueryTarget`, `LiquidReserveTarget`, `Repo`.
- `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` (FS-OWN-33, FS-OWN-34, FS-HOOK-06, and the exit and mint locks), `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol`, `UniswapV4FullSpreadStandardExchangeVaultMath.sol`, plus `Execution.sol`, `QuoteTarget.sol`, `Projection.sol`, `SwapProjection.sol`, `Types.sol` for confirmation.

**Coordinator context, treated as context and re-checked against the sources.** The brief states V3 deposits use constant-product share math plus a liquid-reserve rebalance; V3 exact-out withdrawals use a bounded search; V4 full-spread uses one 49 percent exact-input swap for a one-sided mint, proportional liquidity, and a proportional exit plus one unwanted-side swap; and the V4 PRD says the redesign removes rate-valued issuance and exits and does not solve swap-price manipulation. Each of these was re-read in the sources and is confirmed below where it is load-bearing.

**Sub-questions this response answers.** (1) Which requirement sentences does the V3 PRD need? (2) For each, what V3 behavior does it retire and what does it preserve? (3) Which are copies of a named V4 lock, and which are new product decisions that the V4 PRD does not decide?

# Evidence

Source observations, with file and line. Inference is marked as such and is confined to the Conclusions section.

## V3 current behavior (observed)

**Deposit and share issuance.**

1. The V3 deposit mints shares by constant-product math over the whole book. `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:88-92` reads `_totalVaultReservesForShareMath()` and calls `_sharesOutForDeposit`; `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:624-637` delegates to `StandardExchangeConstantProduct._sharesForDeposit` (`StandardExchangeConstantProduct.sol:37-66`), whose single-token branch grows `sqrt(reserve0*reserve1)`; the first-mint branch is `_initialShares` (`StandardExchangeConstantProduct.sol:30-35`), `mulSqrt(amount0, amount1) - minimum`.
2. The V3 first mint mints a floor plus a residual to a dead sink. `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:99-103` and `153-157` mint `_minimumLiquidity()` and then `_initialResidualShares(...)` to `DEAD_SHARES_SINK`; the sink address is `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:80` (`0x...dEaD`); the residual weight rule is `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:645-651`. The floor size is decimal-derived (`StandardExchangeConstantProduct.sol:23-28`), not a fixed 1,000.
3. The V3 deposit consumes the whole declared input and never refunds it. `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:29-31` returns `(amountOut, 0)`; the refund word is hard-zero in the live path.
4. The V3 deposit then runs the sleeve rebalance. `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:110` and `164` call `_rebalanceLiquidReserveBestEffort()` (`UniswapV3FullSpreadStandardExchangeVaultCommon.sol:658-732`), which deploys only the liquidity that both legs support (`_managedLiquidityPlan`, `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:422-455`) and leaves the remainder as free balance. There is no swap on the deposit path.
5. The V3 reserve basis for share math includes unpaid accrued fees. `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:330-336` adds `_collectableCenterFees()` (`:345-364`) to the free-plus-deployed totals, so accrued fees dilute the depositor's share credit.
6. No usage fee is taken on the V3 mint path in the code read: `InBase.sol:74-117` and `Common.sol:624-637` mint the full computed amount to the recipient with no fee read and no fee mint, although `UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol:111-115` declares the `VaultFeeType.USAGE` fee type id.

**Exit.**

7. The V3 exit burns center liquidity proportionally, swaps the removed other side plus the free sleeve share, and pays the free out-share. `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:263-280` (`_idleZapOutCore`), `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:793-808` (`_burnCenterLiquidityForShares`) and `:810-830` (`_swapRemovedOtherPlusFreeShare`, `_actualOutPlusFreeShare`).
8. The V3 exit quote adds the free sleeve share and quotes the swap after the burn (`UniswapV3FullSpreadStandardExchangeVaultInBase.sol:182-196`; `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:239-266` `_quoteSwapAfterWithdrawal` uses `UniswapV3Quoter.quoteExactInputAfterLiquidityChange`).
9. The V3 exact-out withdrawal uses a bounded search. `UniswapV3FullSpreadStandardExchangeVaultOutBase.sol:54-113` bisects `_quoteZapOutAmount` with at most 8 interpolation probes; the transition-quote twin is `UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol:239-266`.
10. The V3 pool-locked path falls back to constant-product sleeve settlement. `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:203-209` and `212-250` use `_quoteSleeveZapOutAmount` -> `StandardExchangeConstantProduct._singleExit` (`:171-180`); `UniswapV3FullSpreadStandardExchangeVaultOutBase.sol:65-73` uses `_sharesForSingleExit` (`StandardExchangeConstantProduct.sol:113-128`).
11. The V3 vault exposes an SY `exchangeRate()`. `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:25-30` returns `mulSqrt(reserve0, reserve1) * 1e18 / supply`.

**Pool mechanics and surface.**

12. The V3 lock predicate is `pool.slot0().unlocked` and `true` means idle; the polarity is the opposite of V4 `isUnlocked`. `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:126-134`. The V3 pool is operated by callback: `uniswapV3MintCallback` and `uniswapV3SwapCallback` (`:136-170`), `pool.mint`/`pool.burn`/`pool.collect` (`:568-612`), `pool.swap` (`:506-566`).
13. The V3 position is created lazily inside the sleeve rebalance. `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:614-620` defines `_createOrganicPositionsIfNeeded`, which `_deployExcessLiquidity` (`:730-760`) calls; the stored ticks live in `UniswapV3FullSpreadStandardExchangeVaultRepo.sol:14-68`; imported books keep the imported ticks.
14. `previewExchangeIn` on V3 already returns the 64-byte tuple `(amountOut, amountRefunded)`. `UniswapV3FullSpreadStandardExchangeVaultInMultiQueryTarget.sol:11-16`.
15. V3 installs a transition-quote surface and a frozen-quote surface that V4 does not: `UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol:21-23` advertises `IStandardExchangeTransitionQuote`, `IStandardExchangeExternalQuote`, and `IStandardExchangeFrozenQuoteInputs`; the frozen model is `UniswapV3PairDeposit` (`UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol:29-44`).
16. V3 has no `donate` and no `compound` selector; a search of the whole V3 directory for `function donate`, `function compound`, `Donation`, `Compounded` returned nothing.

## V4 full-spread behavior (observed, the template)

17. Issuance is over one value, liquidity. `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:224-241` (`_shares`): first deposit `grossShares = liquidityAdded - MIN_SHARES`; later `grossShares = liquidityAdded * totalSupply / liquidityBefore`. `UniswapV4FullSpreadStandardExchangeVaultMath.sol:136-142` (`netShares`) and `:144-148` (`claim`).
18. The floor is `MIN_SHARES = 1_000` and the fee cap is `3e17`. `UniswapV4FullSpreadStandardExchangeVaultTypes.sol:6-7`. A first deposit whose added liquidity is not above the floor fails the plan (`Planner.sol:227-229`); `FS-MONEY-01` names the reject `MinLiquidityNotMet()`.
19. The one-sided mint is exactly one 49 percent exact-input swap. `Planner.sol:178-222` (`_size`): `swapIn = mulDiv(amount, 49, 100)`, the whole fixed fraction must be spent, the output sizes the add via `Math.sizeOneSided` (`Math.sol:47-82`), and the remainder is returned to the payer. `FS-OWN-33` (locked 2026-11-06) is the product rule: no iteration, no root solve, no tick walk, no swap when the price is not strictly inside the position.
20. The bundle deposit is proportional and swaps nothing. `Planner.sol:39-50` (`planBundleIn`), refunds `amount0 - used0` and `amount1 - used1`. `FS-OWN-25`.
21. The one-token exit removes `liquidity * shares / supplyBeforeBurn`, claims the holder's accrued-fee portion and booked portion, and swaps all of the holder's opposing token. `Planner.sol:132-176` (`_exit`): if the swap cannot spend the whole opposing amount the plan fails; `UniswapV4FullSpreadStandardExchangeVaultExecution.sol:76-78` then reverts `AmountOutNotMet` before any burn. `FS-OWN-30` and `FS-OWN-15` are the product rules.
22. The bundle exit pays the claim in both tokens and does not swap. `Planner.sol:52-72` (`planBundleOut`).
23. There is no sleeve and no rebalance. `FS-OWN-04` and `FS-OWN-12`; a remainder is booked instead (`Planner.sol:74-105` `planMaintenance`; `Execution.sol:190-196` writes the booked balances).
24. The fee read is an unpaid-fee read, not a collect. `UniswapV4FullSpreadStandardExchangeVaultProjection.sol:29-58` (`read()`): liquidity, amounts for liquidity, and `fee0`/`fee1` from `getFeeGrowthInside`.
25. A failed plan previews as zero. `UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol:18-27`: `if (plan_.kind == Unsupported || plan_.failed) return (0, 0);`.
26. The V4 PRD removes the vault's own rate surfaces: `FS-OWN-03` (no `rateAsset()`, no `getRate()`, do not install `StandardExchangeRateProviderFacet` on this vault), `FS-OWN-05` (no `IStandardizedYield`, therefore no `exchangeRate()`), `FS-RATE-01` (withdrawn).
27. `FS-OWN-06` says the swap use of a rated reserve is not a claim that same-pool price manipulation is solved; `FS-HOOK-04` and `FS-OWN-30` fix the exit preview as the share valuation and forbid `getRate()` as its substitute.

## External consumer of the V3 vault (observed)

28. `StandardExchangeRateProviderFacet.getRate()` values the whole book by calling the SE vault's `previewExchangeIn`. `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:112-132` (`_safePreviewExchangeIn`): for the live path it calls `previewExchangeIn(subject, totalShares, rateTarget)` and requires a 64-byte return; for a projected state it calls `quoteTotalSupply` and `quoteAssets` on `IStandardExchangeTransitionQuote`. Its empty-supply path (`:98-113`, `_initialRate`) calls `previewExchangeIn(rateTarget, 10**rateTargetDecimals, subject)` and requires 64 bytes.
29. The provider is generic over the SE vault: `IStandardExchangeRateProviderDFPkg.deployRateProvider(IStandardExchange reserveVault, IERC20 rateSubject, IERC20 rateTarget)`.

# Assumptions

1. "The same manner as the V4 full-spread vault" means the same accounting basis, share formula, entry and exit shape, fee treatment, and dust disposition as the V4 vault as locked in the V4 PRD. It does not mean copying V4 PoolManager mechanics. V3 remains a callback pool: `pool.swap` with `uniswapV3SwapCallback`, `pool.mint` with `uniswapV3MintCallback`, `pool.burn` and `pool.collect`.
2. The V3 deployed-reserve unit is the vault's own position liquidity (`uint128` liquidity of the single managed position), which is the V3 analogue of V4's raw V4 liquidity. `reserves()` / `reserveOfToken` on V3 remain token-amount reads built from that liquidity and the pool price, not a new unit.
3. A dated V4 lock binds V4 only. A V3 requirement copies one only by naming the source lock and saying the V3 vault adopts that behavior.
4. The V4 PRD's `FS-OWN-34` and `FS-HOOK-05` through `FS-HOOK-10` are hook rules. This response does not propose hook changes for V3; it cites `FS-HOOK-06` only for its explicit non-claim about price manipulation.
5. The V3 remediation PRD at `contracts/vaults/standard/exchange/protocols/uniswap/v3/UNISWAP_V3_STANDARD_EXCHANGE_REMEDIATION_PRD.md` is context. It states that the new full-spread V3 vault "manages liquidity under the same constant-product/proportional-ownership rules as the corrected V4 vault" and that the preserved older V3 implementation under `contracts/protocols/dexes/uniswap/v3/` must not be modified. This response treats the constant-product rule as the thing the new PRD is changing, not as a constraint.
6. Where the V4 PRD is silent, this response states a requirement as a decision to be made rather than choosing silently. Every such item appears in the open-decision list.

# Coverage

**Read (required targets).** All four named V3 files, plus the V3 `InTarget`, `InMultiTarget`, `InMultiQueryTarget`, `InQueryFacet`, `OutExecutionDelegate`, `OutMultiTarget`, `OutQueryTarget`, `LiquidReserveTarget`, `Repo`, and `DFPkg` (grep only, for fee and fee-type-id facts). `StandardExchangeConstantProduct.sol` in full. The V4 PRD sections for FS-OWN-01 through FS-OWN-37, FS-MONEY-01, FS-UNLOCK-01 through FS-UNLOCK-03, section 6 rate and issuance, FS-HOOK-01 through FS-HOOK-10, FS-TEST-01 through FS-TEST-04 (grep for the acceptance rows that mention dust), and sections 2 and 9. The V4 `Planner.sol`, `Math.sol`, `Execution.sol`, `QuoteTarget.sol`, `Projection.sol`, `SwapProjection.sol`, `Types.sol` in full.

**Read (optional context).** `UNISWAP_V3_STANDARD_EXCHANGE_REMEDIATION_PRD.md` — examined. `StandardExchangeRateProviderFacet.sol` — examined. `v4/pairToken` — **not examined**. `v4/upperLowerWings` — **not examined**.

**Read outside the admitted list, disclosed.** `contracts/vaults/standard/exchange/protocols/uniswap/VALIDATION.md` and `VALIDATED_ARTIFACTS.json`, read once to establish deployment status. Both sit one directory above the admitted V3 target. `VALIDATION.md:12` states the working-tree implementation "has not been committed or deployed". That statement is used only as a caveat on the scope of the change (see `V3-DEC-06`), not as a requirement, and I did not verify it further.

**Not read.** `docs/research/v3-fullspread-v4-accounting-prd-20261116/coordinator/*`, `RUN.md`, the final PRD, and any other member file. The V4 PRD's implementation-and-test plan and `IMPLEMENTATION_PLAN_BLOCKERS.md` were consulted only through the PRD's own precedence statements, not read as sources.

# Conclusions

Each row gives a copyable PRD sentence, the V3 behavior it retires, the V3 behavior it preserves, and whether it is a copy of a named V4 lock or a new product decision. "Copy" means: the requirement reproduces a named V4 lock and says the V3 vault adopts that behavior. "New" means: the V4 PRD does not decide it, and the V3 PRD must decide it.

## A. Share issuance

| ID | Copyable requirement | Retires | Preserves | Class |
| --- | --- | --- | --- | --- |
| V3-ISS-01 | "The vault accounts its deployed reserve as one value: the liquidity of its single managed position. Share minting and burning use that number. Token amounts stay in their own decimals; no amount scaled to a token's decimals, and no use of `decimals()`, enters the share formula." | Constant-product share math over token reserves (`StandardExchangeConstantProduct._sharesForDeposit`, `Common.sol:624-637`). | Complete-book ownership: every holder's claim still tracks the whole deployed position. | Copy of FS-OWN-27. |
| V3-ISS-02 | "On the first deposit, reject added liquidity less than or equal to `MIN_SHARES` (1,000) with `MinLiquidityNotMet()`. Mint the 1,000-share floor to `address(0)`, include it in `totalSupply()`, and mint the depositor `added liquidity - 1,000`. On a later deposit, `grossShares = added liquidity * totalSupply / existing liquidity`, where the denominator is the existing liquidity before this deposit is added." | The decimals-derived `_minimumLiquidity()` floor and the `mulSqrt(amount0, amount1) - minimum` genesis (`StandardExchangeConstantProduct.sol:30-35`). | A floor that is in `totalSupply()` and is not credited to a depositor. | Copy of FS-OWN-11, FS-MONEY-01, FS-OWN-24. |
| V3-ISS-03 | "The residual first-mint dead-share weight is removed. `DEAD_SHARES_SINK` and `_initialResidualShares` are deleted; no share is minted to a dead address." | `_initialResidualShares` and the sink mint (`Common.sol:645-651`, `:80`; `InBase.sol:99-103`, `153-157`). | The property that genesis dust is not held by any holder. | Copy of FS-OWN-11 and FS-OWN-32 (input that does not become liquidity is not minted into shares and is not left for other shareholders). |
| V3-ISS-04 | "A share-minting deposit takes the usage fee from the shares that deposit mints. `feeShares = mulDiv(grossShares, clampedFee, 1e18)`, minted to `feeTo()`; the depositor receives `grossShares - feeShares`. A resolved fee above 30% is used as 30%. No share is minted beyond `grossShares`. A pass-through mints no shares and takes no fee. There is no exit fee." | The current fee-free mint (`InBase.sol:74-117`, `Common.sol:624-637`). | The vault's existing `VaultFeeType.USAGE` fee-type registration, so the fee oracle can resolve a fee for this vault. | Copy of FS-OWN-24. New revenue behavior for V3: this vault currently charges no usage fee. |
| V3-ISS-05 | "The share token is a liquidity number. `decimals()` returns 18 as metadata. It is not a scale and is not an input to the mint or the burn." | Nothing on its own; it constrains V3-ISS-01 and V3-ISS-02. | The share token's 18-decimal display convention. | Copy of FS-OWN-27. |

## B. Deposits

| ID | Copyable requirement | Retires | Preserves | Class |
| --- | --- | --- | --- | --- |
| V3-DEP-01 | "A one-sided share mint runs exactly one balancing swap: swap 49% of the processed input through the bound V3 pool, then deposit. Do not iterate. Do not solve a closed-form root. Do not walk ticks to find a better split." | The V3 deposit's no-swap path: the input is added to the book and the sleeve rebalance deploys only the liquidity both legs support (`InBase.sol:110`; `Common.sol:422-455`, `:658-760`). | The single-swap, single-add entry shape and the position's full-range character. | Copy of FS-OWN-33; the V3 execution mechanics are the adaptation, the 49% rule is the copy. |
| V3-DEP-02 | "When the pool price is not strictly inside the position bounds, including exactly at either bound, the vault does not swap. The position wants only one token: if the caller provided that token, add it with no swap; if the caller provided the other token, return that input and mint nothing. Zero active pool liquidity is not that boundary case. If the 49% swap cannot be formed, or the following add cannot consume its output, return the input and mint nothing." | Nothing directly; it bounds V3-DEP-01. | The V3 vault's own managed tick bounds, which are the V3 analogue of V4's `sqrtA`/`sqrtB`. | Copy of FS-OWN-33, with the V3 mapping stated in the sentence: "position bounds" are the square-root prices of the vault's managed ticks, and "active pool liquidity" is `pool.liquidity()`. |
| V3-DEP-03 | "A bundle deposit adds the declared amounts in proportion to the underlying pool, books the fees the pool returns, and does not run the one-sided balancing swap. The unused remainder of each declared leg is refunded to the payer." | The V3 dual deposit's whole-input booking and its post-deposit sleeve rebalance (`InBase.sol:129-168`). | The two-token `exchangeInManyToOne` route and its dual-currency validation. | Copy of FS-OWN-25 and FS-OWN-32. |
| V3-DEP-04 | "Unused declared input is refunded to the payer in the token the caller provided. It is not minted into shares and it is not left for the other shareholders. The `amountRefunded` word in `exchangeIn` and `previewExchangeIn` carries it." | The always-zero refund (`InTarget.sol:29-31`) and the "surplus stays in the book and accrues to existing holders" rule on the exact-out mint (`OutExecutionDelegate.sol:92-142`). | The 64-byte `(amountOut, amountRefunded)` preview return that the external rate provider requires (`InMultiQueryTarget.sol:11-16`; `StandardExchangeRateProviderFacet.sol:112-132`). | Copy of FS-OWN-32 and FS-OWN-08. |
| V3-DEP-05 | "A share-minting deposit books the fees the pool accrues to the position. Those fees are not in the deposit, not in the caller's share credit, and not swapped into the deposit. A mint preview does not credit the new depositor with existing fees." | The V3 reserve basis that adds `_collectableCenterFees()` into the depositor's share math (`Common.sol:330-336`; `InBase.sol:88-92`). | The V3 accrued-fee read `_collectableCenterFees()` (`Common.sol:345-364`), which is the V3 analogue of V4's `feesAccrued`. | Copy of FS-OWN-30 first paragraph and FS-OWN-24. |
| V3-DEP-06 | "An underlying-to-underlying swap is a pass-through. It mints no shares, takes no usage fee, and triggers no sleeve maintenance." | The V3 direct swap's trailing `_rebalanceLiquidReserveBestEffort()` (`InBase.sol:52-61`). | The direct token-to-token `exchangeIn` route itself. | Copy of FS-OWN-25. |

## C. Exits

| ID | Copyable requirement | Retires | Preserves | Class |
| --- | --- | --- | --- | --- |
| V3-EXIT-01 | "A one-token exit withdraws the exiting holder's portion of the deployed reserve, claims that holder's portion of the accrued fees and of the booked balances, and swaps all of the opposing token that holder owns. The receipt to `recipient` is the swap proceeds, the withdrawn requested-token principal, that holder's requested-token fee portion, and that holder's requested-token booked claim. `minAmountOut` binds that receipt. If the swap cannot convert the whole opposing amount, revert `AmountOutNotMet` and do not burn shares." | The V3 exit's token-amount-proportional burn, its free-sleeve share in the payout (`InBase.sol:263-280`; `Common.sol:810-830`), and its partial-swap tolerance (`_swapRemovedOtherPlusFreeShare` swaps what it can). | The V3 exit's "burn first, then swap the removed other side" order, which V4 also uses (`Planner.sol:132-176`). | Copy of FS-OWN-30 and FS-OWN-15. |
| V3-EXIT-02 | "A both-token exit pays the same claim in both tokens and does not swap." | The V3 dual exit's `_dualExitShareBurns` constant-product rounding and its local-reserve funding checks (`OutMultiTarget.sol:61-124`). | The V3 two-token exit route and its `MinAmountsOut`-style minima. | Copy of FS-OWN-30 and FS-OWN-09. |
| V3-EXIT-03 | "The exit preview uses the same apportioning as the execution it quotes. A one-token exit preview quotes the same recipient receipt, so its `amountOut` matches execution. That exit quote is the share valuation, and it includes accrued fees. It is not `getRate()`." | The bounded exact-out search (`OutBase.sol:54-113`) and the transition-quote search (`InQueryTarget.sol:239-266`). | The V3 preview/execution agreement that D55 already established for the forward quote. | Copy of FS-OWN-30 and the section 6 rate table. |
| V3-EXIT-04 | "The vault keeps a booked balance per token for fees and remainders that it holds but has not deployed. A booked balance is not a reserve, is not redeemable idle, and is not part of the deployed-reserve read. A share-minting deposit and a withdrawal book the exiting holder's claim and release the rest to the other holders." | The V3 model in which the free ERC-20 balance is both the sleeve and the fee store (`_syncVaultReserves`, `Common.sol:400-407`). | The V3 accrued-fee read that feeds the booked balance. | Copy of FS-OWN-07, FS-OWN-20, FS-OWN-30; the booked store itself is new to V3. |

## D. Dust and remainders

| ID | Copyable requirement | Retires | Preserves | Class |
| --- | --- | --- | --- | --- |
| V3-DUST-01 | "A first deposit that would not take the position above `MIN_SHARES` reverts `MinLiquidityNotMet()`. The vault does not open the position with a partial genesis." | The V3 first deposit's ability to mint shares from a one-sided book that does not establish a ratio (`StandardExchangeConstantProduct.sol:37-44` returns zero for a single-token first mint; `InBase.sol:92-96` reverts `UniswapV3Exchange_ZeroAmount`). | The V3 rule that a zero-share deposit is an error rather than a silent no-op. | Copy of FS-MONEY-01. |
| V3-DUST-02 | "Rounding remainder left in the input token after a one-sided deposit is refunded to the payer. It is not booked and it is not minted into shares." | The V3 handling of a one-sided deposit's unusable leg, which today stays in the sleeve as a liquid reserve. | The V3 vault's ability to report the remainder; V3 already returns a refund word in the preview. | Copy of FS-OWN-33 and FS-OWN-32. |
| V3-DUST-03 | "The quote is the mathematical result of the operation. The preview and execution use one quote engine. Do not add a step cap, a minimum tick spacing, a partial fill, or a failure mode for a quote that cannot finish. Dust-tick liveness is a test, not a spacing rule." | Nothing; it constrains the new quote path. | The V3 quoter is already unbounded (`UniswapV3Quoter` calls use `maxSteps: 0`, `Common.sol:239-266`); the new requirement must keep it that way. | Copy of section 6 of the V4 PRD (the "no step cap" rule) and FS-TEST-04 row 041. |
| V3-DUST-04 | "A failed plan previews as zero. A failed deposit or exit is an execution reject; the preview does not revert it." | Nothing; it constrains the new preview path. | The V3 rule that an unsupported preview route reverts `ExchangeInNotAvailable` for a truly unsupported token pair, which stays. | Copy of FS-OWN-19 and FS-OWN-32. |
| V3-DUST-05 | "A donation or compound remainder is booked, not refunded. If the V3 vault does not adopt `donate` and `compound`, then no user-deposit remainder is ever booked, because V3-DEP-04 refunds it." | Nothing by itself. | The absence of `donate`/`compound` on V3 today. | Copy of FS-OWN-21 and FS-OWN-33 if the maintenance surface is adopted; the second half is a new decision, see `V3-DEC-03`. |

## E. Rate surfaces and the external rate provider

| ID | Copyable requirement | Retires | Preserves | Class |
| --- | --- | --- | --- | --- |
| V3-RATE-01 | "The vault installs no `getRate()` and no Standardized Yield `exchangeRate()`. It designates no `rateAsset`." | The V3 SY `exchangeRate()` returning `mulSqrt(reserve0, reserve1) * 1e18 / supply` (`OutQueryTarget.sol:25-30`), which has no meaning once the share is a liquidity number. | The external provider's own `getRate()`, which lives in `StandardExchangeRateProviderFacet` and is not this vault's rate. | Copy of FS-OWN-03, FS-OWN-05, FS-RATE-01. New consequence for V3: it currently implements `IStandardizedYield`; see `V3-DEC-02`. |
| V3-RATE-02 | "The external Standard Exchange rate provider continues to call `previewExchangeIn` on this vault. The vault keeps the 64-byte `(amountOut, amountRefunded)` preview return and keeps the live path's meaning: `previewExchangeIn(share, totalShares, rateTarget)` is the full-book exit quote, and `previewExchangeIn(rateTarget, one whole target token, share)` is the empty-supply deposit quote." | Nothing; it protects the existing consumer. | The provider's two live call sites (`StandardExchangeRateProviderFacet.sol:98-113`, `:112-132`) and its 64-byte length gate. | Copy of FS-OWN-08's return shape; the requirement to keep the provider's call is the brief's constraint, and the provider must not be pointed at NAV or at a vault `getRate()`. |
| V3-RATE-03 | "The PRD states the outcome when the provider's full-book exit quote cannot be formed. Under V3-EXIT-01 a full-book exit is one all-in swap of the entire unwanted side of the book; if the pool cannot absorb it, the plan fails and `previewExchangeIn` returns `(0, 0)`, which the provider reads as a zero rate. The PRD states that outcome in words. It does not add a fallback rate." | Nothing; it forces the outcome to be stated. | The provider's honest failure mode, which returns zero rather than a smaller book value (`StandardExchangeRateProviderFacet.sol:80-82`). | New: the V4 PRD does not decide how the V3 provider behaves. See `V3-DEC-05`. |
| V3-RATE-04 | "The PRD states that neither the 49% entry swap nor the exit swap solves same-pool price manipulation, and that a rate derived from the exit quote reflects the price after the vault's own swap. No requirement in this PRD may claim that manipulation is solved." | Nothing; it prevents an unsupported claim. | Nothing to retire. | Copy of the FS-HOOK-06 non-claim sentence, applied to the V3 vault's own swaps. |

## F. Decisions the V4 PRD does not make for V3

| ID | Copyable requirement | Retires | Preserves | Class |
| --- | --- | --- | --- | --- |
| V3-DEC-01 | "The bound-pool lock state is `pool.slot0().unlocked`, and `true` means the pool is idle. The polarity is the opposite of the V4 manager's `isUnlocked`. Every route that needs a pool operation, including the exit, reverts `UniswapV3Exchange_BoundPoolInteractionBlocked` while the pool is locked. There is no local-funding fallback, because the vault has no sleeve." | The V3 pool-locked constant-product sleeve settlement (`InBase.sol:203-209`, `212-250`; `OutBase.sol:65-73`), and the local-reserve errors `UniswapV3Exchange_InsufficientLocalReserve`. | The V3 `canOpenBoundPoolOps()` predicate and its existing revert name. | New: the V4 PRD answers a different state (borrowed unlock) and V3 cannot borrow a V3 pool lock. The "no sleeve" premise is a copy of FS-OWN-04. |
| V3-DEC-02 | "The vault stops advertising `IStandardizedYield`. The PRD names the consumers of this vault's `exchangeRate()` that are affected, if any." | The V3 SY surface (`OutQueryTarget.sol:17-30`: `getTokensIn`, `getTokensOut`, `yieldToken`, `assetInfo`, `exchangeRate`). | The vault's `assetInfo()` and token getters if the owner chooses to keep them outside the SY interface. | New: the V4 PRD reaches this by withdrawing `IStandardizedYield` for a family with no underlying LP token; the V3 consequence is a named-consumer question. |
| V3-DEC-03 | "The PRD states whether the V3 vault adopts the `donate` and `compound` maintenance surface with the V4 semantics, or states that it does not. If it does not, then no user-deposit remainder is booked and only accrued-fee remainders are booked." | Nothing. | The V3 vault's current absence of both selectors. | New. Copy of FS-OWN-14 and FS-OWN-21 if adopted. |
| V3-DEC-04 | "The PRD states whether the exact-out mint and `previewExchangeOut` are retired to match V4, or retained as a V3-only route re-expressed over the new accounting. If retained, the rule that the input surplus stays in the book and accrues to existing holders is deleted, and the input is either refunded or fully consumed." | The V3 D64 exact-out mint (`OutBase.sol:39-51`; `OutExecutionDelegate.sol:92-142`; `OutQueryTarget.sol:32-57`) if retired. | The V3 `previewExchangeOut` quote surface for the token-to-token case if retained. | New: V4 has no exact-out route, so this is V3-only in either direction. Copy of FS-OWN-19 and FS-HOOK-03 if retired. |
| V3-DEC-05 | "The PRD states the behavior of a first deposit that does not take the position above `MIN_SHARES`: it reverts `MinLiquidityNotMet()` on execution and previews as zero. The PRD states that this is also the condition under which the external provider's empty-supply rate is zero." | Nothing. | The V3 rule that a zero-share deposit is rejected. | New: the interaction between V3-ISS-02, V3-DUST-01, and the provider's `_initialRate` path is not decided by the V4 PRD. Copy of FS-MONEY-01 for the revert itself. |
| V3-DEC-06 | "The PRD states which V3 implementation it governs. It governs the full-spread vault under `contracts/vaults/standard/exchange/protocols/uniswap/v3/` only. The preserved older V3 implementation under `contracts/protocols/dexes/uniswap/v3/` is not modified, and no existing deployment is repointed." | Nothing. | The preservation rule already in the V3 remediation PRD section 1 and section 4. | New: a scope sentence this PRD must carry. The deployment caveat in `VALIDATION.md:12` is context, not authority. |

## G. V3 mechanics adaptations that are not new product rules

These sentences describe how V4 accounting is expressed with V3 swap, mint, burn, and collect. They are adaptations of copied rules, not new product decisions.

| ID | Copyable requirement | Retires | Preserves | Class |
| --- | --- | --- | --- | --- |
| V3-V3-01 | "The entry swap and the exit swap are executed through the bound V3 pool with the pool's own fee tier and the unbounded price limit `TickMath.MIN_SQRT_RATIO + 1` or `TickMath.MAX_SQRT_RATIO - 1`. The preview and the execution use one quote engine, and the exit swap is quoted against the pool state after the burn." | Nothing. | The V3 `UniswapV3Quoter.quoteExactInputAfterLiquidityChange` helper already models the post-burn liquidity (`Common.sol:239-266`), and the V3 quoter is already unbounded. | Adaptation of FS-OWN-33 and FS-MONEY-01; the price-limit constants are the V3 values. |
| V3-V3-02 | "The vault's managed position bounds are fixed before the entry swap and the add. For an organic book they are `TickMath.minUsableTick` and `TickMath.maxUsableTick` at the pool's tick spacing. For an imported book they are the imported position's ticks. The vault does not switch bounds after the first deposit." | The V3 lazy position creation inside the sleeve rebalance (`Common.sol:614-620`, called from `:730-760`), which under the new accounting cannot be the moment the position is priced. | The V3 import rule that an imported book keeps the imported ticks as the single center (`Repo.sol:14-68`; `PositionImportTarget`). | New sequencing decision forced by V3-DEP-01; the bounds rule itself is a copy of FS-OWN-06 in substance. |
| V3-V3-03 | "The V3 transition-quote surface, if retained, is re-expressed over the new accounting and the frozen-quote model for a pair deposit is re-expressed over the new share formula. The PRD names the consumers of the transition quote." | The V3 transition quote's constant-product `_singleExit` and `_sharesForSingleExit` redemption (`InQueryTarget.sol:217-218`, `:247-248`). | The V3 transition-quote and frozen-quote selectors themselves. | New: V4 does not install `IStandardExchangeTransitionQuote`, and the external provider's projected-state path calls it (`StandardExchangeRateProviderFacet.sol:67-69`, `:120-124`). |

## Open product decisions the V3 PRD must not settle by omission

1. The exact-out mint and `previewExchangeOut`: retire to match V4, or keep as a V3-only route over the new accounting (`V3-DEC-04`).
2. The Standardized Yield surface: remove `IStandardizedYield` and name the affected consumers, or re-expose the token getters outside it (`V3-DEC-02`).
3. The `donate`/`compound` maintenance surface: adopt with V4 semantics, or state that the vault has none and that only fee remainders stay booked (`V3-DEC-03`).
4. The pool-locked route: revert on every route including the exit, with no local-funding fallback (`V3-DEC-01`).
5. The provider's visible outcomes: the zero rate when the full-book exit quote cannot be formed, and the zero rate when the first deposit is below the floor (`V3-RATE-03`, `V3-DEC-05`).
6. The usage fee on V3: whether the 30%-clamped fee from FS-OWN-24 applies to this vault at all, given that it charges no fee today and declares the `USAGE` fee type id (`V3-ISS-04`).
7. The scope of the change: which implementation is governed and whether any existing instance is affected (`V3-DEC-06`).

## What is a copy of a named V4 lock, and what is not

Copies: V3-ISS-01 through V3-ISS-05 (FS-OWN-27, FS-OWN-11, FS-OWN-24, FS-OWN-32), V3-DEP-01 through V3-DEP-06 (FS-OWN-33, FS-OWN-25, FS-OWN-32, FS-OWN-30, FS-OWN-08), V3-EXIT-01 through V3-EXIT-04 (FS-OWN-30, FS-OWN-15, FS-OWN-09, FS-OWN-07, FS-OWN-20), V3-DUST-01 through V3-DUST-04 (FS-MONEY-01, FS-OWN-33, FS-OWN-19, section 6 no-step-cap rule), V3-RATE-01 (FS-OWN-03, FS-OWN-05, FS-RATE-01), V3-RATE-02 (FS-OWN-08 return shape), V3-RATE-04 (the FS-HOOK-06 non-claim).

New product decisions: V3-DEC-01 through V3-DEC-06, V3-DUST-05's second half, V3-RATE-03, V3-V3-02's sequencing, V3-V3-03, and the seven-item open list above. V3-V3-01 is an adaptation of a copied rule, not a new decision.

# Limits

1. This response is research. It does not authorize implementation, and it does not replace the V4 PRD, the V3 remediation PRD, or any owner decision. It states no council consensus and no owner lock.
2. I did not read the V4 `pairToken` and `upperLowerWings` trees; those are not the behavior template and I make no claim about them.
3. I did not read the V4 implementation-and-test plan or `IMPLEMENTATION_PLAN_BLOCKERS.md`. Where I cite a V4 rule I cite the PRD file itself.
4. The deployment-status statement in `VALIDATION.md:12` comes from a file outside the admitted read list. I read it once, disclosed it above, and used it only as a caveat on scope.
5. I did not compile, test, deploy, or run any project command, and I did not launch a sub-agent or another council.
6. Several requirements above are stated at the level of a product rule. Whether each is implementable in the V3 callback pool within the gas and code-size limits this repository enforces is not verified here and is a plan concern.
7. The requirement sentences are drafts for the coordinator to copy, rewrite, or reject. Where I named a V4 lock, the coordinator should confirm the exact lock text in the V4 PRD before adoption.
8. I did not verify the ERC-165 surface, the facet cut, the storage-slot impact, or the consumer-migration list for any of these changes.
