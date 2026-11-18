# Identity

- Run ID: `v3-fullspread-v4-accounting-prd-20261116`
- Member: `kimi`
- Profile: `research`
- Phase: `initial independent response`
- Requested role: `council-member`
- Requested model and reasoning: `kimi-coding/k3.1-pro:high`, global route
- Runtime provider/model attestation: not exposed
- Runtime task identifier: not exposed
- Peers read before submission: no
- Owned artifact: `docs/research/v3-fullspread-v4-accounting-prd-20261116/members/kimi/response.md`

# Question and targets

The question is which requirements would make the Uniswap V3 full-spread Standard Exchange vault reproduce the Uniswap V4 full-spread vault's deposit, exit, dust, and share-issuance accounting; which existing V3 behavior must be retired or preserved; and which V3 differences cannot be presented as copies of V4 decisions.

The behavior target is the V4 full-spread vault, especially FS-OWN-24, FS-OWN-27, FS-OWN-30, FS-OWN-32, FS-OWN-33, FS-MONEY-01, and the exit and mint implementations in `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` and `UniswapV4FullSpreadStandardExchangeVaultMath.sol`. FS-OWN-34 and FS-HOOK-06 are examined to prevent hook accounting from being mistaken for vault accounting. They are not a replacement issuance formula for either vault.

The V3 target remains a single-position, callback-based Uniswap V3 vault. The required accounting must therefore be expressed through V3 `swap`, `mint`, `burn`, and `collect`, with actual callback settlement and integer token amounts. A V4 PoolManager `unlock` is not part of the V3 design.

This response distinguishes three things:

1. Economic behavior copied from an explicitly named V4 lock.
2. Mandatory V3 protocol adaptation needed to express that behavior through V3 pool calls.
3. Open V3 product decisions for which V4 supplies no answer, especially callback-locked calls, legacy surfaces, NFT import, and migration of existing vault state.

# Evidence

## Current V3 deposits and issuance

- `UniswapV3FullSpreadStandardExchangeVaultInBase.sol::_executeZapInDeposit` does not perform a balancing swap. It collects when the pool is idle, calculates shares before deploying the contribution, mints those shares to the recipient, synchronizes token reserves, and then calls `_rebalanceLiquidReserveBestEffort`.
- The deposit basis is `_totalVaultReservesForShareMath` in `UniswapV3FullSpreadStandardExchangeVaultCommon.sol`: free token balances plus token amounts implied by deployed V3 liquidity plus stored and unpoked position fees. Execution subtracts the just-delivered input to reconstruct the pre-deposit basis. Consequently, existing fees and free sleeve balances enter the current deposit calculation.
- `_sharesOutForDeposit` delegates to `StandardExchangeConstantProduct`. With supply and both reserves already present, a one-sided deposit mints from growth in `sqrt(reserve0 * reserve1)`; a dual deposit uses the smaller of the two token-ratio share amounts. These are token-reserve valuations, not raw-V3-liquidity issuance.
- On genesis, `StandardExchangeConstantProduct._initialShares` requires both token amounts, calculates `sqrt(amount0 * amount1)`, subtracts a token-decimal-derived minimum, and rejects an insufficient result. V3 mints that minimum and any `_initialResidualShares` to the nonzero `DEAD_SHARES_SINK` at `0x...dEaD`. The residual calculation gives pre-existing inventory separate share weight.
- The inspected V3 `exchangeIn` deposit path mints the entire computed `sharesOut` to the recipient. No usage-fee split appears in the admitted V3 tree. This observation is limited to that path; it is not a claim about every possible shared SY wrapper.
- `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol::executeZapInMintExactOut` provides a second issuance route. `_amountInForZapMint` inverts the same constant-product formula, books the full computed input, and mints exactly the requested shares. This is not V4 behavior.
- `UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol` is another genesis path. It values collected NFT principal and fees through the same geometric-mean issuance, mints the decimal-derived floor and residual shares to `DEAD_SHARES_SINK`, and rebalances the sleeve. V4 has no equivalent import lock.
- `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol::exchangeRate` returns `sqrt(reserve0 * reserve1) * 1e18 / totalSupply` using the owed-inclusive reserve basis. The exact-out mint comments explicitly identify this as the same basis used by deposit preview and `exchangeRate`.

## Current V3 exits and searches

- When V3 pool operations are available, `_executeFreeZapOutExactIn` collects fees, burns `positionLiquidity * sharesBurned / totalShares`, allocates a pro-rata amount of each free token balance, swaps the removed opposing token plus the free opposing-token share into the requested token, pays the result, burns the shares, and rebalances. This is the closest current V3 analogue to the V4 one-token exit, but its free-balance term is a sleeve share rather than separately accounted fee and booked-remainder claims.
- `_swapRemovedOtherPlusFreeShare` caps the opposing amount to the available balance and `_swap` does not require the entire exact-input amount to be spent. A price-limit partial fill can therefore leave input in the vault. V4 instead treats failure to spend the whole unwanted claim as a failed exit plan.
- When `slot0.unlocked == false`, V3 does not burn or swap. `_quoteSleeveZapOutAmount` uses `StandardExchangeConstantProduct._singleExit` against the complete owed-inclusive two-token book, then requires the requested token to be available locally. The library comment describes remaining holders buying the exiting holder's other-token entitlement at `x * y = k`; no actual pool swap occurs.
- Exact-output withdrawal is different again. `_previewZapOutWithdrawal` searches for the minimum sufficient shares using up to eight interpolated probes followed by bisection. `executeZapOutWithdrawal` then pays exactly the requested amount and leaves any exact-input zap surplus in the vault. Its blocked-pool branch instead uses the constant-product/local-reserve calculation.
- `exchangeOutOneToMany` is an exact-output dual exit. `_dualExitShareBurns` independently rounds up each token's share requirement against total token reserves and requires the two results to be equal. It is not a shares-exact-in proportional bundle exit.
- V3 also supports exact-output underlying swaps through `_quoteSwapOut` and `_swapExactOut`. Thus exact-out is a family of current V3 routes, not merely the bounded withdrawal search.

## Current V3 sleeve and callback behavior

- `_rebalanceLiquidReserveInternal` targets `liquidReservePercentageOfVault` independently for each token. It deploys excess free balances, burns a fraction of the position to refill deficits, may deploy again, and emits a rebalance event.
- `_shouldRebalanceToken` applies a 5% relative deadband and a token-decimal-derived absolute floor. `UniswapV3FullSpreadStandardExchangeVaultLiquidReserveTarget.sol` exposes local/deployed reserves, target and actual percentages, and permissionless `rebalanceLiquidReserve`.
- Deposits, direct swaps, and idle exits call this rebalance. It is not just an unrelated view: it determines how much of a deposit becomes V3 liquidity and how much remains locally available for blocked-pool exits.
- `canOpenBoundPoolOps` is `pool.slot0().unlocked`. V3 mint, burn, swap, and collect helpers require that state. Mint and swap callbacks accept only the bound pool and transfer the positive amounts owed to it. This is the V3 mechanism that must carry any redesigned accounting.

## V4 mint, dust, and issuance template

- `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol::_mintOne` calls `_size`, plans at most one swap followed by one liquidity add, sets the depositor's net shares, and records an input refund.
- `_size` implements FS-OWN-33. At a strictly interior price with active liquidity it uses `floor(amount * 49 / 100)` as exact input to one swap. It does not call the quadratic/root helpers that remain elsewhere in the math library. The operative planner, not the presence of those unused helpers, defines the behavior.
- The whole 49% must be spent and produce nonzero output. `Math.sizeOneSided` then selects liquidity at the post-swap price whose rounded-up add consumes all swap output and no more than the unswapped input. Any rounding remainder is in the original input token. If the swap/add cannot be formed, the plan refunds the entire input and mints nothing rather than searching for another split.
- At or outside a position boundary, the wanted token is added without a swap. The unwanted token is not swapped; a user share mint refunds it. Zero active liquidity or an unformable swap is also a full-refund/no-mint plan, not a new split or cap.
- `planBundleIn` uses `Math.proportional`, performs no balancing swap, and refunds both unused token amounts. Bundle dust is therefore user refund dust, not an automatic liquid reserve.
- FS-OWN-24, FS-OWN-27, and FS-MONEY-01 make raw deployed liquidity the sole issuance denominator. For existing supply, `grossShares = addedLiquidity * supplyBefore / liquidityBefore`. Idle balances, booked remainders, and accrued fees are excluded. Token decimals do not scale shares.
- On genesis, added liquidity must exceed `MIN_SHARES = 1_000`; gross shares are `addedLiquidity - 1_000`, and a separate 1,000-share floor is minted to `address(0)` and included in supply. FS-OWN-24 takes the usage fee out of gross new shares, capped at 30%, and mints only the net to the depositor. It never adds fee shares on top. Mint previews and minima use net shares; an underlying-to-underlying pass-through mints no shares and takes no mint fee.
- On a share-minting deposit, FS-OWN-30 and FS-MONEY-01 book `feesAccrued` but exclude it from the deposit, the new depositor's share credit, and the balancing swap. A user operation does not compound those fees or deploy existing booked balances.
- FS-OWN-32 requires unused declared user input to be refunded to the payer, not booked or minted. It separately specifies pull and pretransfer behavior. FS-OWN-14/21 instead book donate/compound remainders for later maintenance. These are deliberately different dust dispositions.

## V4 exit template

- FS-OWN-30 measures claims against supply before the burn, including the genesis floor. For each token, principal is `floor(liquidity * sharesBurned / supplyBefore)`, the fee claim is `floor(feesAccrued * sharesBurned / supplyBefore)`, and the booked claim is `floor(bookedBalance * sharesBurned / supplyBefore)`. The remaining fees and booked balances remain for continuing holders.
- `Planner._exit` converts the exiting holder's entire unwanted side: unwanted principal plus unwanted fee claim plus unwanted booked claim. The requested-side payment is requested principal plus requested fee claim plus requested booked claim plus actual swap proceeds. It does not sell the staying holders' claims.
- The exit swap is exact-input after the planned liquidity removal, and the planner marks the plan failed if the entire unwanted amount would not be spent. The recipient's complete receipt, not swap proceeds alone, is bound by `minAmountOut`. Failure must leave shares unburned.
- `planBundleOut` pays the same principal/fee/booked claims in both tokens and performs no swap. This is a shares-exact-in exit, not V3's exact-output `s0 == s1` calculation.
- Exit previews use the same apportionment and recipient receipt as execution. The exit quote is share valuation for that operation, but it is not `getRate` and is not whole-book NAV divided by supply.

## Sleeve, exact-out, rate, and hook boundaries in V4

- FS-OWN-04/12 remove the local liquidity target and post-operation target-seeking. A booked V4 remainder is not a reserve until `donate` or `compound` deploys it. This is incompatible with retaining V3's percentage-target sleeve as the normal destination of deposit or exit dust.
- FS-OWN-08/19 and FS-HOOK-03 make `previewExchangeOut` return zero and enabled `exchangeOut` revert `ExchangeOutNotAvailable` without moving tokens. V4 has no exact-out mint or exact-out withdrawal to copy.
- FS-OWN-03/05 forbid a vault `getRate`, `rateAsset`, and an SY/NAV replacement denomination. FS-OWN-29 instead configures external rate-provider instances. Section 6 defines mint and exit previews as operation results, not a vault rate.
- FS-OWN-34 concerns hook-owned SE shares `S_i` and local pair tokens `L_i`. It removes rate-valued Hook LP issuance and exits in favor of proportional actual component quantities. It expressly leaves FullSpread vault issuance under FS-OWN-24/27 and withdrawal under FS-OWN-30.
- FS-HOOK-06 permits `L_i + ratedPairTokenUnits(S_i)` only as a hook swap-pricing reserve. Local-first output and deficit-only SE redemption are hook swap settlement rules, not a V3 vault exit rule and not authority to retain the V3 vault sleeve. The same lock expressly says this does not solve price manipulation in swaps or the underlying conversion.

# Assumptions

- “The same manner” means economic and accounting parity for the named money operations. It does not silently require identical Solidity selectors, identical callback architecture, or a V4 PoolManager on V3.
- Raw liquidity of the single V3 full-range position is the appropriate V3 representation of the raw-liquidity unit used by V4. Token amounts retain their own decimals when converted to or from V3 liquidity; decimals do not enter the share formula.
- V4 PRD locks are locks for V4 until the proposed V3 PRD expressly adopts them. This response names the source lock for every proposed copy.
- The current V3 source is evidence of behavior to retire or preserve, not an owner lock that requires its preservation.
- Exact-input underlying-to-underlying swap remains a pass-through: no shares are minted and no share-mint fee applies. Its current automatic sleeve rebalance does not survive no-sleeve parity.
- A strict V4 surface adopts exact-input bundle routes and removes exact-out success routes. Keeping V3-specific aliases is treated below as an interface decision, never as permission to retain different economics.
- No optional source was used as the behavior template.

# Coverage

| Topic | Required coverage | Requirement IDs |
| --- | --- | --- |
| Accounting unit and ownership | Raw V3 liquidity for principal; separate accrued-fee, booked, and unbooked balances | V3-ACC-01, V3-ACC-07 |
| V3 protocol expression | Bound-pool swap/mint/burn/collect and callback payment; no V4 unlock | V3-ACC-02, V3-DEC-01 |
| Sleeve and rebalance | Retire target percentage, deadband-driven movements, and local-first vault exits | V3-ACC-03, V3-ACC-10, V3-ACC-14 |
| One-sided deposit | One 49% exact-input swap, post-swap liquidity add, boundary and failure behavior | V3-ACC-04 |
| Dual/bundle deposit | Proportional liquidity, no balancing swap, refund both remainders | V3-ACC-05 |
| Share issuance and genesis | Raw-liquidity formula, 1,000 floor at zero address, fee out of gross | V3-ACC-06 |
| User dust and pretransfer | Refund payer, never book or mint unused user input | V3-ACC-08 |
| Maintenance dust | Book only donate/compound residue; no automatic user-operation compounding | V3-ACC-09 |
| One-token and both-token exits | Pro-rata principal/fees/booked claims; unwanted-side-only swap; no-sale of stayers | V3-ACC-10 |
| Exact-out | Retire exact-out mint, withdrawal, dual exit, and underlying swap | V3-ACC-11 |
| Quotes and manipulation | Shared plan for preview/execution; no search split or hidden cap; no solved-manipulation claim | V3-ACC-12 |
| Rate provider and legacy valuation | Preserve `previewExchangeIn` consumer path; retire geometric-mean valuation; no `getRate` | V3-ACC-13, V3-DEC-02 |
| Hook boundary | FS-OWN-34 and FS-HOOK-06 remain hook rules, not V3 vault formulas | V3-ACC-14 |
| V3-only surfaces and migration | NFT import, route aliases, existing supply/dead shares/sleeve require explicit choices | V3-DEC-03, V3-DEC-04, V3-DEC-05 |

# Conclusions

## V3-ACC-01 — Raw-liquidity principal and separate balance classes

**Copyable requirement:** “The V3 vault SHALL denominate share principal in the raw liquidity of its one vault-owned full-range Uniswap V3 position. It SHALL account separately for (a) deployed principal, (b) accrued but uncollected position fees, (c) booked per-token remainders, and (d) unbooked ERC-20 balances. Unbooked balances, pending caller input, and refunds owed to a caller SHALL NOT be reserves or share backing. Booked remainders SHALL NOT enter deployed principal or the issuance denominator until an authorized maintenance operation actually deploys them. Live token-reserve views MAY report deployed token amounts plus unpaid position fees, but SHALL NOT add unbooked or booked local balances to deployed principal.”

- **Retires:** `_totalVaultReservesForShareMath` as a universal share-pricing basis; geometric-mean token-reserve issuance; treatment of arbitrary free balances as deployed backing; direct-transfer socialization into later share calculations.
- **Preserves:** The single full-range V3 position, live position-amount and fee-owed reads, and actual token-unit accounting at the V3 boundary.
- **Disposition:** Copies V4 FS-OWN-07, FS-OWN-20, FS-OWN-27, and the balance-class portions of FS-OWN-30. Expressing those classes with V3 position reads is protocol adaptation.
- **Refuses to decide:** Does not choose a migration for existing balances; V3-DEC-05 owns that choice.

## V3-ACC-02 — V3 callback expression, not a V4 unlock

**Copyable requirement:** “Every redesigned V3 money operation SHALL perform its planned pool actions through the bound Uniswap V3 pool's `swap`, `mint`, `burn`, and `collect` entrypoints. The vault SHALL accept mint and swap callbacks only from that pool, pay exactly the positive callback amounts owed from the operation's authorized balances, and use actual token-balance deltas to reconcile amounts consumed, collected, refunded, paid, and booked. `slot0.unlocked == true` denotes that the V3 pool is idle and these operations may be opened. The V3 vault SHALL NOT require, emulate, or expose a Uniswap V4 PoolManager `unlock` as a prerequisite for this accounting.”

- **Retires:** Any assumption that V4 unlock dispatch or delta settlement can be copied literally; any accounting based on nominal rather than actual V3 callback payments.
- **Preserves:** V3's bound-pool callback authorization, exact payment of callback debts, and idle-pool guard.
- **Disposition:** This is a mandatory V3-specific protocol adaptation, not a copy of a V4 lock. The economic plans it carries are copied from the V4 locks named below.
- **Refuses to decide:** Does not define what an external call should do while the V3 pool is callback-locked; V3-DEC-01 is explicitly open.

## V3-ACC-03 — Retire the liquid-reserve sleeve

**Copyable requirement:** “The V3 vault SHALL NOT maintain a target from `liquidReservePercentageOfVault`, a 5% target deadband, or a token-decimal absolute rebalance floor. It SHALL NOT deploy excess, burn the position to refill a target, or invoke target-seeking rebalance after a deposit, withdrawal, underlying swap, donation, or compound. Permissionless `rebalanceLiquidReserve` SHALL no longer move vault inventory. Locally held tokens SHALL have only an explicit role as pending operation funds, caller refunds, accrued fees awaiting allocation, or booked remainders under V3-ACC-01; none constitutes a percentage-target sleeve.”

- **Retires:** `_rebalanceLiquidReserveBestEffort`, `_rebalanceLiquidReserveInternal`, `_deployExcessLiquidity`, `_refillDeficitLiquidity`, their 5%/absolute-floor trigger, permissionless sleeve maintenance, and the automatic post-operation calls.
- **Preserves:** Actual balances needed to settle the current operation and explicitly booked maintenance balances; it does not require every local wei to be deployed immediately.
- **Disposition:** Copies V4 FS-OWN-04, FS-OWN-12, FS-OWN-14, and FS-MONEY-01's no-automatic-compound rule.
- **Refuses to decide:** Whether legacy sleeve-view selectors remain as compatibility views is an interface question under V3-DEC-04; they cannot drive accounting.

## V3-ACC-04 — One-sided deposit uses one 49% swap

**Copyable requirement:** “For a one-sided share-minting deposit at a price strictly inside the full-range position and with nonzero active pool liquidity, the V3 vault SHALL calculate `swapIn = floor(processedInput * 49 / 100)` with overflow-safe multiply/divide and perform exactly one exact-input swap of that amount on the bound V3 pool, using `MIN_SQRT_RATIO + 1` or `MAX_SQRT_RATIO - 1` in the swap direction. The plan SHALL require nonzero `swapIn`, complete consumption of `swapIn`, and nonzero output. At the post-swap price it SHALL compute the greatest V3 liquidity whose rounded-up `mint` amounts consume the complete swap output and no more than the unswapped input, then mint that liquidity. Any remainder SHALL be only unspent original input and SHALL be refunded under V3-ACC-08. The vault SHALL NOT iterate, solve a root, walk ticks for a better split, or substitute a 48%, 50%, quarter, or closed-form split. At or outside a range boundary it SHALL add a provided wanted token without swapping; a provided unwanted token SHALL be fully refunded with zero shares and no swap. If the 49% swap or following add cannot be formed, or the add cannot consume the quoted output, the plan SHALL be a full input refund with zero shares and no pool action; an execution mismatch SHALL revert atomically without minting shares.”

- **Retires:** Constant-product one-sided share credit without a balancing swap, deposit-sized liquid-reserve leftovers, and any iterative or exact-out input sizing.
- **Preserves:** Exact-input V3 swaps, the full-range position, caller minima, and V3 tick/liquidity mathematics.
- **Disposition:** Copies V4 FS-OWN-33 and the operative `Planner._size`/`Math.sizeOneSided` behavior. The V3 `sqrtPriceLimitX96`, callback, and `pool.mint` mechanics are protocol adaptation.
- **Refuses to decide:** Does not add a TWAP, impact cap, tick bound, or manipulation defense and does not claim the fixed split is optimal.

## V3-ACC-05 — Bundle deposit is proportional and has no balancing swap

**Copyable requirement:** “A declared token0/token1 share-minting bundle SHALL calculate the greatest proportional V3 liquidity supported by the declared amounts at the current pool price, call `pool.mint` for that liquidity, and perform no balancing swap. Actual rounded-up amounts consumed by the V3 mint SHALL determine `used0` and `used1`; every unused declared amount SHALL be refunded under V3-ACC-08. Existing accrued fees SHALL be handled under V3-ACC-07 and SHALL NOT be included in the caller's contribution or share credit. Shares SHALL be issued only under V3-ACC-06.”

- **Retires:** The current dual deposit's minimum-of-two-token-reserve-ratios formula, automatic booking of unused input into a sleeve, and any 49% swap on a bundle.
- **Preserves:** An exact-input two-token contribution route and proportional full-range liquidity addition.
- **Disposition:** Copies V4 FS-OWN-25, FS-OWN-32, `Planner.planBundleIn`, and `Math.proportional`.
- **Refuses to decide:** Does not choose whether the route is exposed only through the V4 bundle ABI or also through a V3 alias; V3-DEC-04 owns that surface choice.

## V3-ACC-06 — Genesis, subsequent issuance, and usage-fee split

**Copyable requirement:** “Every permitted share-minting route SHALL use actual newly added raw V3 liquidity as its gross issuance basis. On genesis, added liquidity less than or equal to `MIN_SHARES = 1_000` SHALL revert; the vault SHALL separately mint 1,000 shares to `address(0)`, include them in `totalSupply`, and set `grossShares = addedLiquidity - 1_000`. For existing supply it SHALL set `grossShares = floor(addedLiquidity * totalSupplyBefore / deployedLiquidityBefore)`. Idle, unbooked, booked, and accrued-fee balances SHALL NOT enter either denominator, and token decimals SHALL NOT scale the formula. When `feeTo` is nonzero, `feeShares = floor(grossShares * min(usageFee, 0.3e18) / 1e18)`; the vault SHALL mint `feeShares` to `feeTo` and `grossShares - feeShares` to the depositor's recipient, never minting a fee on top or on the fee shares. Mint previews and `minAmountOut` SHALL use net shares. An underlying-to-underlying pass-through SHALL mint no shares and take no mint fee. Any retained import, SY, alias, or other issuance route SHALL use this same rule or be disabled.”

- **Retires:** `sqrt(amount0 * amount1)` genesis, decimal-derived minimum liquidity, `DEAD_SHARES_SINK`, `_initialResidualShares`, invariant-growth subsequent issuance, exact-output share minting, and the inspected exact-input path's all-shares-to-recipient behavior.
- **Preserves:** One ERC-20 share supply, a permanently locked genesis floor as an anti-inflation mechanism, and recipient/payer separation.
- **Disposition:** Copies V4 FS-OWN-11, FS-OWN-24, FS-OWN-27, and FS-MONEY-01. Changing the floor's value and destination from current V3 is part of that explicit copy, not a preservation of current V3.
- **Refuses to decide:** Does not specify how an already existing V3 supply is converted to this denomination; V3-DEC-05 owns migration.

## V3-ACC-07 — Existing fees are booked, never new-depositor credit

**Copyable requirement:** “Before a share-minting V3 liquidity add, the vault SHALL measure and, where necessary through V3 `burn(0)` and `collect`, realize the position's pre-existing accrued fees. Actual fees attributable to the existing position SHALL be booked per token and excluded from contributed principal, newly added liquidity, the depositor's share credit, and every deposit balancing swap. Previously booked balances SHALL remain separate and SHALL NOT be counted again as newly accrued fees. A deposit SHALL NOT compound accrued fees or deploy booked balances. Preview and execution SHALL use the same pre-add fee and liquidity state so no existing fee is credited to the new depositor.”

- **Retires:** Deposit issuance against owed-inclusive total token reserves and collection followed by target-driven redeployment of existing fees.
- **Preserves:** V3 fee-growth accounting, collection when idle, and continuing holders' ownership of fees.
- **Disposition:** Copies the mint paragraph of V4 FS-OWN-30, FS-OWN-24's excluded denominator, and FS-MONEY-01. V3 `burn(0)`/`collect` measurement is protocol adaptation.
- **Refuses to decide:** Does not define a new fee token, performance fee, or growth-based mint; none is authorized by this parity work.

## V3-ACC-08 — User input dust is refunded, with explicit pretransfer rules

**Copyable requirement:** “Input that does not become V3 liquidity SHALL NOT be minted into shares or booked for other shareholders on a user deposit. With `pretransferred == false`, the vault SHALL pull the declared amount from `msg.sender` and refund the unkept amount of that same token to `msg.sender`; declared input equals amount consumed plus amount refunded, while minted shares go to `recipient`. With `pretransferred == true`, a one-token call SHALL use only the unbooked held balance up to the caller's declared maximum, never booked balances or parked shares. If the maximum is within that unbooked balance, refund maximum minus used; if it exceeds the unbooked balance, process no more than that balance, refund its unused amount without pulling a shortfall, and do not revert merely because the maximum is larger. A bundle whose declared maximum exceeds either token's unbooked balance SHALL revert before processing a leg, spending input, or minting shares. A zero refund SHALL transfer nothing. Execution SHALL reconcile actual balances so a refund cannot spend booked inventory or another caller's staged funds.”

- **Retires:** Full booking of one-sided deposit input, treating direct transfers as reserve backing, and using recipient and payer interchangeably for refunds.
- **Preserves:** Secure pull/pretransfer authorization, exact-delivery checks, and output to a distinct recipient.
- **Disposition:** Copies V4 FS-OWN-20 and FS-OWN-32; the dust source follows FS-OWN-33 and FS-OWN-25.
- **Refuses to decide:** Does not make a non-atomic pretransfer safe and does not turn ambient balances into caller credit.

## V3-ACC-09 — Maintenance remainder is booked, not a sleeve or user refund

**Copyable requirement:** “Only the authorized owner/operator `donate` and `compound` maintenance operations SHALL process collected fees and booked remainders for redeployment. A one-token maintenance balance SHALL use the same 49% one-swap rule as V3-ACC-04; a balance already holding both tokens SHALL make a proportional add without a swap. The simplest actual V3 add SHALL determine the remainder: maintenance remainder SHALL be booked per token and not refunded to the donor, and its size alone SHALL NOT force a revert or another attempt. User deposits and withdrawals SHALL NOT call these operations. A maintenance call with no fees, donation, or booked balance SHALL make no accounting change. Booked balances remain outside deployed principal until an actual subsequent add.”

- **Retires:** Permissionless target-driven sleeve maintenance, automatic compounding during user operations, and refunding maintenance dust as though it were user deposit dust.
- **Preserves:** Actual fee/booked ownership and the ability to deploy residual balances later without inventing a target percentage.
- **Disposition:** Copies V4 FS-OWN-14, FS-OWN-21, and FS-OWN-33. No V3 `donate`/`compound` implementation was found in the admitted V3 tree, so adopting this surface must be stated expressly rather than assumed to exist.
- **Refuses to decide:** Does not choose new operator permissions, event ABI, or a performance-fee policy beyond the V4 rule being copied.

## V3-ACC-10 — Exact-input exits pay proportional claims only

**Copyable requirement:** “For a shares-exact-in exit, let `supplyBefore` include the genesis floor and measure liquidity, accrued fees, and booked balances before burning shares or V3 liquidity. The exiting holder SHALL receive claims calculated with multiply-before-divide and floor rounding: `liquidityOut = floor(positionLiquidity * sharesBurned / supplyBefore)`, `feeClaim_i = floor(accruedFee_i * sharesBurned / supplyBefore)`, and `bookedClaim_i = floor(booked_i * sharesBurned / supplyBefore)`. The vault SHALL use V3 `burn` and `collect` to realize `liquidityOut` and actual principal amounts, allocate only the exiting holder's fee and booked claims, and leave all unallocated claims booked for continuing holders. A both-token exit SHALL pay its principal, fee, and booked claims in both tokens without a swap. A one-token exit SHALL swap exactly the exiting holder's unwanted principal plus unwanted fee claim plus unwanted booked claim through one exact-input V3 swap after the liquidity removal, require complete consumption of that unwanted amount, and pay `recipient` the requested principal plus requested fee claim plus requested booked claim plus actual swap proceeds. It SHALL NOT pay, retain, or rebook an opposing residual for the exiting holder and SHALL NOT swap continuing holders' inventory. `minAmountOut` SHALL bind the complete recipient receipt; an unmet minimum, incomplete unwanted-side swap, or settlement failure SHALL revert atomically without burning shares. Exit previews SHALL quote the same claims, post-burn pool state, and receipt. Share-in withdrawals remain permitted while the vault is registry-disabled; deposits and pass-through swaps remain blocked.”

- **Retires:** Blocked-pool `_singleExit` against total token reserves, local-reserve-funded vault exits, undifferentiated pro-rata sleeve shares, partial unwanted-side fills, exact-output surplus retention, and exact-output dual-exit share equality.
- **Preserves:** The current idle-path proportional center burn and unwanted-side swap concept, exact-input share burning, caller minima, recipient payout, and withdrawal while registry-disabled.
- **Disposition:** Copies V4 FS-OWN-15, FS-OWN-26, FS-OWN-30, `Planner._exit`, and `Planner.planBundleOut`. V3 burn/collect and post-burn swap quoting are protocol adaptation.
- **Refuses to decide:** Does not create a local-first vault withdrawal from FS-HOOK-06; that rule belongs to hooks. Callback-locked availability remains V3-DEC-01.

## V3-ACC-11 — Retire every exact-out success route

**Copyable requirement:** “The V3 vault SHALL be exact-input only for the parity surface. `previewExchangeOut` SHALL return zero and enabled `exchangeOut` SHALL revert `ExchangeOutNotAvailable` without moving tokens. Exact-output underlying swaps, exact-output share mints, exact-output one-token withdrawals, and exact-output dual withdrawals SHALL be unsupported, including through aliases such as `exchangeOutOneToMany`. The constant-product `_amountInForShares` mint inversion, the bounded exact-output withdrawal search, and `s0 == s1` dual-output sizing SHALL NOT remain as alternative accounting paths. Both-token redemption SHALL instead be shares-exact-in under V3-ACC-10. Exact-input previews and execution SHALL share one plan and integer rounding.”

- **Retires:** `_previewZapOutWithdrawal`, its eight interpolated probes and bisection, `executeZapOutWithdrawal`, `executeZapInMintExactOut`, exact-output pool swaps, and exact-output one-to-many redemption.
- **Preserves:** Exact-input deposit, exact-input one-token exit, proportional both-token exit, and the exact-input pass-through swap.
- **Disposition:** Copies V4 FS-OWN-08, FS-OWN-19, FS-OWN-24's statement that no exact-out gross-up is adopted, and FS-HOOK-03.
- **Refuses to decide:** Does not preserve a legacy exact-out compatibility wrapper with different economics; any such proposal would require a new owner decision outside parity.

## V3-ACC-12 — Quotes reproduce the operation; manipulation remains unsolved

**Copyable requirement:** “Mint and exit previews SHALL evaluate the same operation plan as execution at the same economic state: post-swap price and rounded-up mint amounts for a one-sided add, and post-burn liquidity for an exit swap. No undocumented quote-step cap, minimum tick spacing, partial-fill success, price-impact cap, `maxZapBps`, `maxZapTickMove`, or alternate split search SHALL be introduced. The 49% entry swap and unwanted-claim exit swap SHALL use the unbounded V3 directional price limits; the caller's minimum remains the output protection. The PRD SHALL state explicitly that same-pool swaps expose the operation to pool-price movement and that this redesign does not solve swap-price manipulation or make an external rate manipulation-resistant.”

- **Retires:** Exact-output search as a quote engine and any implication that raw-liquidity issuance or hook component accounting protects a same-pool swap price.
- **Preserves:** V3 quoting of exact-input swaps, `_quoteSwapAfterWithdrawal`'s useful modeling of the liquidity removal, and user-set minima.
- **Disposition:** Copies V4 section 6, FS-OWN-30/33 price-limit rules, and FS-HOOK-06's express manipulation limitation.
- **Refuses to decide:** A TWAP, independent oracle, price guard, narrower limit, or alternative split would be a new product decision, not a V4 copy.

## V3-ACC-13 — Retire geometric-mean valuation without breaking the preview consumer

**Copyable requirement:** “The current geometric-mean `exchangeRate` and every rate-valued issuance or exit based on it SHALL be retired. The V3 vault SHALL NOT add `getRate`, `rateAsset`, a NAV substitute, or a queued-withdrawal denomination. The external Standard Exchange rate-provider integration SHALL continue to call `previewExchangeIn`; that call and its return ABI SHALL NOT be silently deleted, and its result SHALL NOT be replaced with NAV. A mint preview SHALL return net shares from the actual one-sided mint operation without crediting existing fees; an exit preview SHALL return the V3-ACC-10 operation receipt including the exiting holder's fees and booked claim. The PRD SHALL identify these as operation quotes rather than a normalized whole-book rate and SHALL disclose the unresolved same-pool manipulation exposure to any consumer that uses them as a rate.”

- **Retires:** `sqrt(reserve0 * reserve1) / supply` as a share valuation and as the basis for exact-out minting or blocked-pool exits.
- **Preserves:** The brief-required external consumer's `previewExchangeIn` path, the existing preview return tuple, and operation-specific quote semantics.
- **Disposition:** The no-`getRate`/no-NAV and preview meanings copy V4 FS-OWN-03, FS-OWN-05, FS-OWN-29, and section 6. Preserving the V3 consumer call is an explicit integration constraint from the brief, not permission to preserve the old geometric-mean formula.
- **Refuses to decide:** Does not silently redefine an external provider's denomination or certify its manipulation resistance. Any different provider design is a separate product decision.

## V3-ACC-14 — Keep hook accounting out of the V3 vault formula

**Copyable requirement:** “The V3 PRD SHALL NOT import FS-OWN-34's hook component formula or FS-HOOK-06's `L_i + ratedPairTokenUnits(S_i)` into V3 vault share issuance, vault withdrawal, or vault reserve valuation. V3 vault shares SHALL use raw deployed V3 liquidity under V3-ACC-06 and proportional claims under V3-ACC-10. An SE Vault Hook MAY separately book its actual SE shares and local pair tokens and use the rated sum only for its own swap pricing, local-first output, and deficit redemption as those V4 hook locks specify. Hook LP mint and burn SHALL use actual proportional component quantities, not spot price, NAV, `getRate`, or a rated-reserve change. No hook or vault requirement SHALL describe this separation as a solution to swap-price manipulation.”

- **Retires:** Any reading that FS-OWN-34 replaces raw-liquidity vault issuance, or that FS-HOOK-06 authorizes a V3 local-first sleeve exit or rate-valued vault shares.
- **Preserves:** The V4 hook's separate actual-component ownership model and external provider's limited swap-pricing role.
- **Disposition:** Copies the scope boundary stated in V4 FS-OWN-34 and FS-HOOK-06, not their hook mechanics into the V3 vault.
- **Refuses to decide:** Does not redesign any hook, choose a rate provider, or assert council-wide agreement.

## V3-DEC-01 — Open product decision: callback-locked external calls

**Copyable decision requirement:** “The owner SHALL explicitly specify the result of a deposit, exit, or pass-through call that arrives while the bound V3 pool has `slot0.unlocked == false`. For full V4 no-sleeve accounting parity, the call SHALL revert without changing shares, liquidity, booked balances, or token balances; it SHALL NOT substitute constant-product issuance, `_singleExit`, or local-reserve payment. Retaining any local-only route instead is a separate V3 product choice that must specify its ownership and solvency rules and must not be represented as full V4 accounting parity. No requirement shall call this state a V4 borrowed unlock.”

- **Retires:** Under the parity choice, the current blocked-pool constant-product and local-reserve fallbacks. Until the owner chooses, this requirement does not silently retire or preserve them.
- **Preserves:** V3's actual callback-lock constraint and the prohibition on opening same-pool mint/burn/swap/collect while locked.
- **Disposition:** **New product decision.** V4's already-unlocked path has no mechanical V3 equivalent; FS-OWN-13/31 cannot be copied literally.
- **Refuses to decide:** This response recommends the no-state-change revert for strict parity but does not present that recommendation as an owner lock.

## V3-DEC-02 — Open compatibility decision: SY and legacy valuation surfaces

**Copyable decision requirement:** “For strict V4 surface parity, the V3 PRD SHALL remove SY deposit/redeem/query dependencies, `exchangeRate`, `rateAsset`, transition-state quote routes, and any alternate rate-valued money path under FS-OWN-03/05 and V4 section 2. If a V3 consumer requires retaining any such selector, the owner SHALL approve that as a V3-specific compatibility decision; the retained route SHALL call only the V3-ACC exact-input accounting and SHALL NOT restore constant-product issuance, exact-out, NAV, or `getRate`. This choice SHALL NOT remove or replace the external provider's `previewExchangeIn` call required by V3-ACC-13.”

- **Retires:** Under strict parity, the current SY/geometric-mean surface and every alternate issuance/exit implementation behind it.
- **Preserves:** Only explicitly approved compatibility wrappers with identical new economics, plus the mandatory external preview consumer.
- **Disposition:** Removal copies V4 FS-OWN-03/05; retention is a **new V3 product decision** because V4 does not authorize that compatibility surface.
- **Refuses to decide:** Does not enumerate unreviewed external consumers or claim that retaining a view is harmless without checking its use.

## V3-DEC-03 — Open product decision: NFT position import

**Copyable decision requirement:** “The V3 PRD SHALL explicitly remove `importPosition`/`previewImportPosition` or approve a V3-only import design; it SHALL NOT leave the current geometric-mean import as an issuance exception. If import is retained, actual raw full-range V3 liquidity established from the imported position SHALL determine gross shares under V3-ACC-06, imported pre-existing fees SHALL be booked rather than credited as new-depositor principal, and no sleeve rebalance or residual dead-share mint SHALL occur. Any different valuation or grandfathering rule SHALL be identified as a new import product, not V4 parity.”

- **Retires:** NFT principal-plus-fees geometric-mean genesis, `DEAD_SHARES_SINK` residual issuance, and import-triggered sleeve rebalancing.
- **Preserves:** Only the possibility of importing actual V3 liquidity if the owner expressly retains it.
- **Disposition:** **New product decision.** The V4 full-spread PRD has no NFT-import behavior to copy; only the raw-liquidity/fee constraints are copied if import is retained.
- **Refuses to decide:** Does not choose whether import remains available or how imported non-full-range ticks are valued beyond actual resulting full-range liquidity.

## V3-DEC-04 — Open interface decision: V3 aliases versus the V4 bundle ABI

**Copyable decision requirement:** “Strict V4 interface parity SHALL expose the accepted exact-input bundle deposit and bundle redemption routes and the refund-bearing `previewExchangeIn`/`exchangeIn` tuple, while removing exact-out routes. Retaining `exchangeInManyToOne` or introducing a shares-exact-in replacement for `exchangeOutOneToMany` as an alias SHALL be an explicit V3 interface decision. Every retained alias SHALL implement V3-ACC-05 or V3-ACC-10, use the same refunds, net-share fee split, minima, previews, and actual settlement, and SHALL NOT accept exact-output economics.”

- **Retires:** Different economics behind an alias, especially exact-output one-to-many redemption and zero-refund one-sided deposit returns.
- **Preserves:** The option of source-compatible exact-input aliases if the owner needs them.
- **Disposition:** Strict ABI adoption copies V4 FS-OWN-08/09; keeping V3 names is a **new interface product decision**, not a V4 lock.
- **Refuses to decide:** Does not invent selector hex or claim ERC-165 compatibility without a separate interface review.

## V3-DEC-05 — Open product decision: existing-vault migration

**Copyable decision requirement:** “The V3 PRD SHALL state whether the new accounting applies only to newly deployed vaults or also to existing V3 instances. A migration of an existing instance SHALL specify the treatment of current total supply and holder balances, shares at `DEAD_SHARES_SINK`, the absent or different zero-address floor, raw deployed liquidity, liquid-sleeve balances, accrued fees, imported positions, booked and unbooked balances, and outstanding previews/consumer assumptions. It SHALL demonstrate conservation for existing holders before enabling the new routes. No migration SHALL silently reprice supply through the new raw-liquidity denominator or move the liquid sleeve into booked fees.”

- **Retires:** Any implicit assumption that replacing formulas preserves existing holder claims without a defined conversion.
- **Preserves:** Existing holders' claims until an explicit migration rule says how they are represented.
- **Disposition:** **New product decision.** The V4 genesis locks define a new vault, not migration of a live V3 vault.
- **Refuses to decide:** Does not select a snapshot, exchange ratio, migration transaction, disable/upgrade sequence, or grandfathering policy.

# Limits

- This is one independent research response, not council consensus, an owner lock, an implementation plan, a security clearance, or authorization to implement.
- No peer response, coordinator draft, coordinator resolution, run record, or final PRD was read. No sub-agent or council was launched.
- No implementation, test, installation, deployment, wallet operation, or Git operation was performed.
- Optional source `contracts/vaults/standard/exchange/protocols/uniswap/v3/UNISWAP_V3_STANDARD_EXCHANGE_REMEDIATION_PRD.md`: not examined.
- Optional V4 `pairToken` tree: not examined.
- Optional V4 `upperLowerWings` tree: not examined.
- Optional `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol`: not examined. The requirement to preserve its `previewExchangeIn` consumer path comes from the admitted brief; this response does not independently attest to that file's implementation or all of its consumers.
- V4 execution/settlement libraries outside the required planner and math files were not used to add behavior. Actual V3 execution feasibility, gas, callback reentrancy, and rounding equivalence require later implementation evidence; none is claimed here.
- Same-pool swap-price manipulation remains unsolved. No independent price source, TWAP guarantee, migration safety, or existing-holder conservation result is asserted without the explicit decisions and evidence identified above.
