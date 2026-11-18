# Identity

- Member label: grok
- Profile: research
- Phase: initial independent response
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:high
- Run ID: v3-fullspread-v4-accounting-prd-20261116
- Owned path: docs/research/v3-fullspread-v4-accounting-prd-20261116/members/grok/response.md
- Runtime task id: not exposed
- Runtime model: not exposed
- Runtime provider account: not exposed
- Peers read before submission: no

This response does not authorize implementation. It does not replace the V4 PRD, the V3 remediation PRD, or a later coordinator draft.

# Question and targets

Question: What requirements must a PRD state so the Uniswap V3 full-spread Standard Exchange vault processes deposits, exits, dust, and share issuance in the same manner as the Uniswap V4 full-spread Standard Exchange vault, which current V3 behaviors that PRD must retire or preserve, and which differences are a new product decision rather than a copy of V4?

Targets:

- The V3 full-spread vault under `contracts/vaults/standard/exchange/protocols/uniswap/v3/`, read for deposit, exit, share, dust, and rebalance behavior.
- `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, especially FS-OWN-33, FS-OWN-34, FS-HOOK-06, and the exit and mint locks.
- `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` and `UniswapV4FullSpreadStandardExchangeVaultMath.sol`.

The behavior template is the V4 full-spread vault and its dated locks. pairToken and upper/lower wings are not the template. A V4 lock is a lock for V4 until a V3 requirement says the V3 vault adopts it and names the source lock.

Coordinator context was re-read against those sources before use. It is not an owner lock. Where it is incomplete, Evidence says so.

# Evidence

## What V3 does now

Share issuance is constant-product against token reserves, then a liquid-reserve rebalance.

`UniswapV3FullSpreadStandardExchangeVaultInBase._previewZapInDeposit` and `_executeZapInDeposit` price a one-sided deposit with `_sharesOutForDeposit`. That function calls `StandardExchangeConstantProduct._initialShares` on an empty supply and `_sharesForDeposit` otherwise. `_sharesForDeposit` grows `sqrt(x*y)` for a one-sided add, takes the minimum of the two proportional ratios for a two-sided add, and is linear only when one reserve is already zero. The reserve basis is `_totalVaultReservesForShareMath`: free ERC-20 balances, plus deployed center amounts, plus collectable center fees. A one-sided first mint cannot clear `_initialShares`, because that function returns zero when either amount is zero.

On an empty supply the execution mints `_minimumLiquidity()` and `_initialResidualShares` to `DEAD_SHARES_SINK` (`address(0x...dEaD)`), then mints the depositor's shares. `_minimumLiquidity` is derived from token decimals. `_initialResidualShares` weights pre-existing reserves against the new shares without assigning unlike tokens a price. No usage-fee mint appears on this path. The public `exchangeIn` and `previewExchangeIn` already return `(amountOut, amountRefunded)` and hardcode the refund word to zero.

After the mint, if `canOpenBoundPoolOps()` is true, `_rebalanceLiquidReserveBestEffort` runs. That gate is `pool.slot0().unlocked`. The comment in Common records the opposite polarity of V4 `isUnlocked`. Rebalance targets `liquidReservePercentageOfVault` of free-plus-deployed value, with a 5% relative deadband (`LIQUID_RESERVE_RELATIVE_TOL_WAD = 0.05e18`) and an absolute floor of 1 wei or `10^(decimals-6)`. Excess is `pool.mint`ed into the center. A deficit burns a fraction of center liquidity and collects. If the pool is locked, the deposit still mints shares and emits `LocalDepositWhileBlocked`. It does not rebalance.

`importPosition` is a second genesis path. It is available only when supply is zero and no position exists. It exits an NPM NFT, creates the full-range center, prices the inbound tokens with the same constant-product first-mint formula, mints the decimals floor and residual to the dead sink, mints the recipient, and rebalances. Organic ticks are `TickMath.minUsableTick` / `maxUsableTick`. The vault owns the center position. Pool payment is `uniswapV3MintCallback` and `uniswapV3SwapCallback`. There is no PoolManager unlock.

Exits mix a proportional burn, a free-balance share, and a pool swap. They are not a claim on the exiting holder alone.

Exact-in zap-out (`_idleZapOutCore`) collects fees, burns `liquidity * shares / supply` through `pool.burn` and `pool.collect`, adds the holder's proportional free balance of the other token, swaps that sum to the requested token, and pays the requested-token free share plus swap proceeds. Exact-out withdrawal (`_previewZapOutWithdrawal`) binary-searches that quote, with up to eight interpolations, then pays exactly the requested amount and leaves the surplus in the vault. The old 1% share pad is already gone. While the pool is locked, both shapes use `StandardExchangeConstantProduct._singleExit`: burn a proportional claim, then an `x*y=k` sale of the other entitlement into the remaining book, paid only from free local balances. That path performs no pool swap.

Exact-out mint (`_amountInForZapMint` / `_amountInForShares`) inverts the single-token invariant branch, books the closed-form input, mints exactly the requested shares, and leaves rounding surplus in the book. `exchangeOut` also has an exact-output pool swap, and afterward rebalances. `exchangeOutOneToMany` sizes shares by rounding each requested token up against `_totalVaultReservesForShareMath` and requires the two share amounts to be equal. It does not swap. Idle execution burns proportional liquidity and pays the requested amounts. Locked execution pays them from free balances or reverts.

`exchangeRate()` is installed. It returns `1e18` on zero supply, otherwise `sqrt(reserve0 * reserve1) * 1e18 / supply` on the same owed-inclusive reserve basis as deposits. No `getRate()` was found on this vault. A non-share-input execution calls `_requireNotDisabled` before the route body. Share-input withdrawals are not in that check.

Pass-through `exchangeIn` pulls the declared input, requires exact delivery, swaps the whole amount, and rebalances. It does not refund unspent input.

No `donate` or `compound` selector was found in the V3 full-spread directory. Permissionless `rebalanceLiquidReserve` is the dust-deployment path. A zero liquidity quote on excess free balance is a no-op; that dust stays free inside the deadband.

## What V4 full-spread actually specifies

FS-OWN-33, locked 2026-11-06, is the one-sided mint rule. A one-sided share mint runs one balancing swap. A bundle deposit does not. Inside the position, swap 49% of the processed input, then deposit. Do not iterate. Do not solve a closed-form root. Do not walk ticks. If the price is not strictly inside, including either boundary, do not swap. Add the wanted token with no swap, or refund the unwanted token on a share mint. Zero active liquidity is not the boundary case. If the 49% swap cannot be formed, or the following add cannot consume its output, return the input and keep no swap. A share mint then refunds and mints nothing. Rounding leaves the remainder in the input token. A user-deposit remainder is refunded. A donate or compound remainder is booked. The price limit is the unbounded tick-math limit. No tighter cap is added. This is not an exit rule.

`Planner._size` is that lock in code. It uses `FullMath.mulDiv(amount, 49, 100)`. The whole fixed 49% must be spent. A zero swap amount, an amount that cannot be quoted as `int256`, a quote that spends less than that 49%, or a zero output refunds the whole input. `Math.sizeOneSided` then takes liquidity whose add consumes the quoted output and leaves rounding in the input token. If that liquidity is zero, the plan refunds the whole input. `Math.quadraticInput` is still in the math library. The planner does not call it. The lock forbids that closed-form root. Copying `quadraticInput` would contradict FS-OWN-33.

Share issuance is raw liquidity, not a token rate. FS-OWN-27: mint and burn use raw liquidity. Token decimals do not enter the share formula. `decimals()` is metadata. FS-OWN-24 and FS-MONEY-01: on a later deposit, `grossShares = added liquidity * totalSupply / existing liquidity`, using supply and liquidity before the add. Idle balances, booked remainders, and `feesAccrued` are not in the denominator. On the first deposit, added liquidity must exceed `MIN_SHARES` (`1_000`) or the plan fails with `MinLiquidityNotMet()`. `grossShares = added liquidity - 1_000`. The floor is minted to `address(0)`, is part of `totalSupply()`, is not part of `grossShares`, and is not a fee mint. Fee shares are `mulDiv(grossShares, clampedFee, 1e18)`, taken from `grossShares`, not minted on top. A resolved usage fee above 30% (`3e17`) is clamped to 30% in the vault's read. Previews and `minAmountOut` use net shares. A pass-through takes no fee. There is no exit fee.

FS-OWN-30 is the exit lock. Measure before the burn. Principal removal is `liquidity * sharesBurned / supplyBeforeBurn`, rounded down. Each fee claim and each booked claim is `floor(balance * sharesBurned / supplyBeforeBurn)`. A one-token exit swaps all of the opposing token that holder owns, or reverts `AmountOutNotMet` and does not burn. It does not swap other holders' booked fees or sell the staying holders' inventory. The receipt is swap proceeds, withdrawn requested-token principal, the requested-token fee portion, and the requested booked claim. `minAmountOut` binds that receipt. A both-token exit pays the same claim in both tokens and does not swap. The exit preview uses the same apportioning. That quote is the share valuation. It is not `getRate()`. A mint preview is not that valuation. `Planner._exit` quotes one exact-input swap of the unwanted claim after removing that liquidity, and marks the plan failed if the swap would not spend the entire unwanted amount.

FS-OWN-32: input that does not become liquidity is not minted and is not left for the other shareholders. Pull the declared amount, then refund the unkept amount. A donation or compound remainder is booked, not refunded. A preview of a refund need not be bit-exact with execution. The exit quote's output match is not waived by that sentence.

FS-OWN-04 and FS-OWN-12: there is no local liquidity sleeve and no target from `liquidReservePercentageOfVault`. A deposit, a withdrawal, and `compound()` do not move a local balance toward that target. FS-OWN-20: unbooked balances are not reserves and are not redeemable idle. A booked remainder is not a reserve until `donate()` or `compound()` deploys it. FS-OWN-07: `reserves()` wraps deployed-reserve reads, including unpaid fees, with no local term and no last-committed snapshot.

FS-OWN-14 and FS-OWN-21: `donate` and `compound` are the deployment path for booked fees and booked remainders. They are not permissionless. One-token maintenance uses the FS-OWN-33 shape and books the remainder. Both-token maintenance does not swap. A deposit, a withdrawal, and `exchangeIn` do not call them. A sandwich of that maintenance swap can still sell fees or a booked remainder at a moved price. That exposure is accepted. It is not claimed absent. FS-OWN-15 says the one-token exit swap is for pool volume. It is a quantity rule, not a new cap.

FS-OWN-19 and FS-HOOK-03: this family has no exact-out route. `previewExchangeOut` returns zero. On an enabled vault, `exchangeOut` reverts `ExchangeOutNotAvailable()` and moves no tokens. A disabled `exchangeOut` reverts `VaultDisabled`. No view reverts by a vault error. An unsupported view route returns zero.

FS-OWN-03, FS-OWN-05, and FS-RATE-01: do not implement `getRate()` or `rateAsset()`. Do not install `exchangeRate()` or replace it with NAV. The external rate-provider instance is FS-OWN-29. The vault does not store it and does not call its result this family's rate. FS-OWN-29 also says the provider, and every other consumer of the old one-word preview, must read the FS-OWN-08 tuple. That sentence is a V4 consumer migration. It is not a V3 owner lock.

FS-OWN-34 is hook accounting. Its own text says FullSpread vault issuance remains proportional to raw deployed liquidity under FS-OWN-24/27, booked-claim withdrawal remains FS-OWN-30, and unused user input remains refunded under FS-OWN-32. It says not to restore a vault sleeve, a target percentage, or a vault `getRate()` under that amendment. FS-OWN-35, FS-OWN-36, and FS-OWN-37 are likewise hook membership, Hook LP fees, and hook initial liquidity. FS-OWN-37 says it is not a change to the FullSpread vault's own genesis or 49% entry rule.

FS-HOOK-06, the sentence at the end of that section: "This swap use of a rated reserve is not a claim that price manipulation in swaps or the underlying conversion is solved. The new LP ownership rules specifically remove rate-valued issuance and exits." The first sentence is about swap use of a rated reserve. The second sentence is about Hook LP ownership, not about the vault's share formula. The vault's removal of reserve-valued share issuance is FS-OWN-24/27 and the section 6 table, not that hook sentence.

FS-UNLOCK-01 through FS-UNLOCK-03 are V4 PoolManager unlock paths. They do not translate to a V3 callback pool. FS-UNLOCK-02 says there is no sleeve fallback.

## Rate-provider call that must not be silently replaced

`StandardExchangeRateProviderFacet` was read because the brief makes its `previewExchangeIn` call a constraint. It is not the behavior template.

For a non-empty supply, `_getRate` calls `previewExchangeIn(subject, totalShares, rateTarget)` and requires a 64-byte return. It decodes only the first word. It then normalizes that word by supply and decimals. The subject defaults to the reserve vault, so the ordinary call is share in, rate-target out, for the entire supply. For a zero supply, `_initialRate` calls `previewExchangeIn(rateTarget, 10**rateTargetDecimals, subject)` and inverts the first word, which it treats as shares minted for one whole target token. A 64-byte success with a zero first word becomes a zero rate. `quoteRate` with a non-empty state calls `quoteAssets`, not `previewExchangeIn`.

V3 already returns the 64-byte tuple. The refund word is zero. Adopting V4 accounting changes the first word. It does not require deleting the call, changing the tuple width, replacing the word with NAV, or adding `getRate()` to the vault.

## Coordinator context after re-read

Confirmed: V3 deposits use constant-product share math plus a liquid-reserve rebalance. V3 exact-out withdrawals use a bounded search. V4 one-sided mints use one 49% exact-input swap when the price is strictly inside and active liquidity is non-zero. Bundle deposits do not use that swap. Exits burn a proportional liquidity claim and, on a one-token exit, swap the exiting holder's unwanted claim. The V4 PRD does not claim that same-pool swap price manipulation is solved.

Incomplete if copied without the exceptions: the 49% swap is not the outside-range rule and not the zero-active-liquidity rule. The exit swap must consume the entire unwanted claim or the exit does not burn. Share issuance is the liquidity ratio, not "proportional liquidity" in the bundle-add sense. "Removes rate-valued issuance and exits" in FS-HOOK-06 is a Hook LP sentence. The vault rule is FS-OWN-24/27 plus FS-OWN-30's statement that the exit quote is the share valuation and is not `getRate()`, and that a mint preview is not that valuation.

# Assumptions

- The V4 PRD's dated locks win over `quadraticInput` remaining in the math library. The planner's 49% path is the code of FS-OWN-33. Execution code was not read. If execution diverged, the lock would still be the copy source.
- V3 `pool.mint` does not return a V4 `feesAccrued` credit. The fee split has to be expressed by not collecting fees into the add, and by reading `_collectableCenterFees` before an exit burn. That is an expression of FS-OWN-30, not a new fee formula.
- While `slot0.unlocked` is false, V3 cannot `swap`, `mint`, `burn`, or `collect`. A same-manner route that needs one of those calls cannot succeed on a locked pool. A local `x*y=k` pay would preserve the retired math.
- `MIN_SHARES` of 1,000 is a liquidity-unit floor. V3 center liquidity is the same kind of Uniswap liquidity number. The copy does not rescale it by decimals.
- The external provider's published rate is the provider's act. Stating what the vault preview returns does not decide what the provider should publish.
- No other vault's use of `StandardExchangeConstantProduct` was searched. Requirements below bind this V3 vault's calls, not the library file.

# Coverage

Examined:

- `UniswapV3FullSpreadStandardExchangeVaultInBase.sol`
- `UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol`
- `UniswapV3FullSpreadStandardExchangeVaultOutBase.sol`
- `UniswapV3FullSpreadStandardExchangeVaultCommon.sol`, including share math, swap, mint, burn, collect, and rebalance
- `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol`
- `UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol`
- `UniswapV3FullSpreadStandardExchangeVaultInMultiQueryTarget.sol`
- `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol`
- `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol`
- `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol`
- `UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol`
- `UniswapV3FullSpreadStandardExchangeVaultLiquidReserveTarget.sol`
- `UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol`, because it mints shares
- `StandardExchangeConstantProduct.sol`
- V4 PRD sections 1.4, 5, 6, and 7 through the start of FS-HOOK-07, plus the heading index of the rest
- `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol`
- `UniswapV4FullSpreadStandardExchangeVaultMath.sol` through `singleTokenAdd` and the `quadraticInput` entry point
- `UniswapV4FullSpreadStandardExchangeVaultTypes.sol`
- `StandardExchangeRateProviderFacet.sol`, optional, not used as the template

Not examined:

- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UNISWAP_V3_STANDARD_EXCHANGE_REMEDIATION_PRD.md`
- the pairToken tree
- the upperLowerWings tree
- V4 `UniswapV4FullSpreadStandardExchangeVaultExecution.sol`, the implementation plan, and the blockers file
- section 8 acceptance rows, beyond the heading index

Not read, and not used: any file under `members/` other than this path, `coordinator/draft.md`, `coordinator/resolution.md`, `RUN.md`, and the final PRD.

# Conclusions

The PRD must adopt named V4 locks for this V3 vault, express them with V3 `swap`, `mint`, `burn`, and `collect`, and leave the open rows unresolved. It must not import the hook books, a PoolManager unlock, `quadraticInput`, or a claim that same-pool price manipulation is solved.

Each requirement below is a sentence the coordinator can copy. "Copy" means the V3 vault adopts that named V4 lock. It is not a new economic rule. An open row is a product decision this response does not make.

## Adopted requirements

### V3-ACC-01

Sentence: The Uniswap V3 full-spread Standard Exchange vault adopts only the deposit, exit, dust, and share-issuance accounting named in this PRD from the Uniswap V4 full-spread vault. A V4 lock applies to this vault only where a requirement names it. Pool actions are `pool.swap`, `pool.mint`, `pool.burn`, and `pool.collect`, paid through the existing `uniswapV3SwapCallback` and `uniswapV3MintCallback`. This vault does not call PoolManager `unlock` and does not take a borrowed unlock. It does not adopt FS-OWN-34, FS-OWN-35, FS-OWN-36, FS-OWN-37, FS-HOOK-05, FS-HOOK-07, FS-HOOK-08, FS-HOOK-09, or FS-HOOK-10. It does not adopt FS-OWN-17's native-currency substitution. Its pool tokens remain `pool.token0()` and `pool.token1()`. It keeps one vault-owned full-range center at the minimum and maximum usable ticks and adds no minimum tick spacing.

Retires: nothing by itself. It is the fence against copying the rest of the V4 PRD.

Preserves: the callback pool, callback authorization, full-range center, and ERC-20 pool tokens.

Source: copy of the brief's expression rule, and of FS-OWN-34's statement that FullSpread issuance stays FS-OWN-24/27 and that the amendment does not restore a vault sleeve or a vault `getRate()`. Not a copy of the hook refactor. Not a new product decision.

### V3-ACC-02

Sentence: Share minting and burning use raw center-position liquidity. They do not use token reserves, `sqrt(x*y)`, NAV, or `decimals()`. On an existing supply, `grossShares = addedLiquidity * totalSupply / existingLiquidity`, with both supply and liquidity read before the add. Idle balances, booked remainders, and fees are not in that denominator. On a burn, liquidity removed is `floor(positionLiquidity * sharesBurned / supplyBeforeBurn)`.

Retires: `_sharesOutForDeposit`, `_sharesForDeposit`, and `_totalVaultReservesForShareMath` as the mint basis. Retires fee-inclusive reserve dilution of a new depositor.

Preserves: one ERC-20 share supply, and the position liquidity read from the bound pool.

Source: copy of FS-OWN-27, FS-OWN-24, and FS-MONEY-01. Not a new product decision.

### V3-ACC-03

Sentence: The first liquidity add must exceed 1,000 or the call reverts `MinLiquidityNotMet()` and mints nothing. The vault mints 1,000 shares to `address(0)`. That balance is part of `totalSupply()`. It is not part of `grossShares` and it is not a fee mint. `grossShares` is `addedLiquidity - 1,000`. The depositor receives the net of V3-ACC-04. The vault does not mint a decimals-based floor, does not mint residual unlike-token weight, and does not mint the floor to `address(0xdead)`.

Retires: `_minimumLiquidity`, `DEAD_SHARES_SINK`, `_initialResidualShares`, and `_initialShares`. Retires the current inability to open the book with a one-sided add that becomes liquidity.

Preserves: a permanently locked floor inside `totalSupply()` that the first depositor does not receive.

Source: copy of FS-OWN-11, FS-OWN-24, and FS-MONEY-01. Not a new product decision for an organic first deposit. Import survival is V3-OPEN-01.

### V3-ACC-04

Sentence: On every share-minting deposit, including the first, take the usage fee from `grossShares`. Do not mint it on top. If `feeTo` is not `address(0)` and the clamped fee is non-zero, `feeShares = mulDiv(grossShares, clampedFee, 1e18)`. Mint `feeShares` to `feeTo` and `grossShares - feeShares` to the recipient. Skip a zero mint. Do not mint a fee on the fee shares or on the 1,000-share floor. When this vault reads `usageFeeOfVault(address(this))`, a fee above `3e17` is used as `3e17`. A fee of `3e17` or less is used as read. The clamp does not write the oracle. `previewExchangeIn` and `minAmountOut` use the depositor's net shares. A pass-through takes no fee. There is no exit fee.

Retires: minting the entire share credit to the recipient with no fee split.

Preserves: the absence of an exit fee. The oracle may still store a higher fee for other vaults.

Source: copy of FS-OWN-24. Not a new fee design. Keeping a zero fee would make issuance not the same as V4, and this requirement does not do that.

### V3-ACC-05

Sentence: A one-sided share mint, when the current sqrt price is strictly inside the vault's position, runs one exact-input `pool.swap` of `floor(processedInput * 49 / 100)`, with `sqrtPriceLimitX96` equal to `TickMath.MIN_SQRT_RATIO + 1` or `TickMath.MAX_SQRT_RATIO - 1`, then `pool.mint` of the liquidity whose add consumes that swap's entire output. It does not iterate, does not solve a closed-form root, and does not use `quadraticInput`. If that swap amount is zero, cannot be quoted, is not fully spent, receives zero output, or the following mint cannot consume that output, the call refunds the whole processed input, executes no swap, and mints nothing. A successful add leaves rounding in the input token and refunds it under V3-ACC-13. That remainder is not minted and is not booked. Preview and execution use this same sizing. A preview does not transfer.

Retires: constant-product one-sided deposit, and any search or closed-form split of the input.

Preserves: exact-input `pool.swap`, callback payment, and the unbounded V3 price limit already used by this vault. The V3 constant is `MIN_SQRT_RATIO`, not the V4 `MIN_SQRT_PRICE` name.

Source: copy of FS-OWN-33 and of `Planner._size` / `Math.sizeOneSided`. Not a new product decision. Consumption is measured by the V3 mint callback's owed output. That measurement is the expression of "the add consumes the swap output," not a second rule.

### V3-ACC-06

Sentence: If the sqrt price is not strictly inside the position, including exactly at either boundary, a one-sided share mint does not swap. If the caller provided the token the position wants, add it with no swap and refund what the add does not take. If the caller provided the other token, refund it and mint nothing. Zero active pool liquidity is not that boundary case. In that case, refund the whole input and mint nothing. These refunds use no new error.

Retires: minting shares against free-balance reserves when position liquidity is zero, and swapping when the position wants only one token.

Preserves: full-range ticks, so the interior case remains the ordinary case.

Source: copy of FS-OWN-33 and the zero-active branch of `Planner._size`. Not a new product decision.

### V3-ACC-07

Sentence: A both-token deposit adds liquidity for the declared amounts in proportion to the current pool price. It refunds each token the add does not take. It does not run the 49% swap. It books fees observed on that add and does not include them in the caller's share credit or in a swap. Shares follow V3-ACC-02 and V3-ACC-04.

Retires: `_previewZapInDualDeposit` and the minimum-of-proportions constant-product dual mint.

Preserves: a both-token entry that does not sell one leg to buy the other.

Source: copy of FS-OWN-25 and the bundle sentence of FS-OWN-33. Not a new product decision. The selector that carries this rule is V3-OPEN-03.

### V3-ACC-08

Sentence: This vault has no local liquidity sleeve. It does not read `liquidReservePercentageOfVault` as a target. It does not mint or burn liquidity to move a free balance toward that target after a deposit, a withdrawal, a pass-through, `donate`, or `compound`. It does not keep the 5% deadband or the decimals floor as a rebalance tolerance. `rebalanceLiquidReserve` is removed.

Retires: `_rebalanceLiquidReserveBestEffort`, `_rebalanceLiquidReserveInternal`, `_deployExcessLiquidity`, `_refillDeficitLiquidity`, `rebalanceLiquidReserve`, and `LIQUID_RESERVE_RELATIVE_TOL_WAD`.

Preserves: `canOpenBoundPoolOps` as the pool-lock gate only. It is not a sleeve mode.

Source: copy of FS-OWN-04 and FS-OWN-12. Not a new product decision.

### V3-ACC-09

Sentence: Unbooked ERC-20 balances are not reserves and are not redeemable. A booked remainder is a vault record, not `balanceOf`. It is not a reserve until `donate` or `compound` deploys it. A deposit, a withdrawal, and `exchangeIn` do not deploy the staying holders' booked balance. `reserves()` and `reserveOfToken` report deployed token amounts plus unpaid position fees. They do not add a free-balance term, a booked term, or a last-committed snapshot. On this callback vault, booked tokens may sit in the vault's ERC-20 balance, but they are excluded from those reads and from the next add's budget.

Retires: treating free balance plus deployed amount plus unpoked fees as the redeemable share book, and treating `_syncVaultReserves` as economic booking of every token that sits on the vault.

Preserves: pretransfer credit limited to this call's unbooked maximum. A staged balance for another call is not this call's refund.

Source: copy of FS-OWN-20, FS-OWN-07, and FS-OWN-30. The storage expression is required because V3 has no PoolManager credit to book. It is not a new economic rule.

### V3-ACC-10

Sentence: A share-minting `pool.mint` does not collect fees into the add, the caller's share credit, or a swap. Unpoked fees remain the position's unpaid fees until an exit read or a maintenance collect. They are not copied into a booked balance while they remain in the position. On a withdrawal, read collectable center fees before the burn. The caller's fee claim is `floor(collectableFees * sharesBurned / supplyBeforeBurn)` for each token. Book or leave the rest for the other holders. Do not also pay that same fee as a free-balance share. After `pool.burn` and `pool.collect`, split the collected tokens by that pre-burn read. Do not use the combined balance delta as the claim.

Retires: `_collectIfIdle` before share math, and the proportional free-balance entitlement that mixes fees, sleeve inventory, and stray transfers.

Preserves: `_collectableCenterFees` as the unpaid-fee read, and burn-then-collect as the V3 withdrawal primitive.

Source: copy of FS-OWN-30, expressed with V3 collect. Not a new formula.

### V3-ACC-11

Sentence: A one-token exit burns the caller's liquidity fraction and pays `recipient` the swap proceeds of that holder's opposing claim, the withdrawn requested-token principal, that holder's requested-token fee portion, and that holder's requested booked claim. The opposing claim is that holder's unwanted principal, unwanted fee claim, and unwanted booked claim. It is not a proportional free-balance share and it is not the staying holders' inventory. The swap is one exact-input `pool.swap` of that entire opposing amount, quoted after the liquidity removal, at the same unbounded price limit as V3-ACC-05. If that swap cannot spend the entire opposing amount, the call reverts `AmountOutNotMet` and does not burn shares. It does not pay, book, or keep that opposing residual. `minAmountOut` binds the full receipt. The preview quotes that same receipt, so the quoted `amountOut` matches execution. The preview is the share valuation of that operation. It is not `getRate()`.

Retires: `_idleZapOutCore`, `_quoteSleeveZapOutAmount`, `_singleExit` as an exit, the exact-out share search, paying only the requested amount and leaving surplus, and the post-exit rebalance.

Preserves: share in and one underlying out as the withdrawal, a caller minimum, and no burn when the receipt cannot be paid.

Source: copy of FS-OWN-15, FS-OWN-30, and FS-MONEY-01. Not a new product decision.

### V3-ACC-12

Sentence: A both-token exit pays the V3-ACC-11 claim in both tokens and does not swap. It books the other holders' fee and booked remainders. Shares burned are the caller's exact-in share amount. The exit is not sized by inverting token reserves, and it does not require the two token claims to imply an equal share burn of a requested token amount.

Retires: `exchangeOutOneToMany`'s reserve-ratio share burn, its locked local pay, and its idle pay of requested amounts with surplus left in the vault.

Preserves: a both-token payout that does not sell one leg to pay the other.

Source: copy of FS-OWN-09's mapped redeem, FS-OWN-15, and FS-OWN-30. Not a new product decision. The selector is V3-OPEN-03.

### V3-ACC-13

Sentence: Input that does not become liquidity is not minted into shares and is not left for the other shareholders. On a pull, pull the declared amount from `msg.sender`, then refund the unkept amount of that token to `msg.sender`. A zero refund transfers nothing. On a pretransfer, refund only this call's unused credit, not another call's staged balance. A share-minting deposit's fees are booked, not refunded. A donate or compound remainder is booked, not refunded. A one-token exit's unspent opposing residual is neither booked nor kept. That exit reverts instead. A preview of a refund does not transfer and need not equal the execution refund. The exit receipt's match to execution is not waived by that sentence.

Retires: the hardcoded zero refund, exact-out surplus left for holders, and sleeve dust left inside the deadband.

Preserves: the existing two-word return, and the pretransfer maximum rule.

Source: copy of FS-OWN-32 and the remainder sentences of FS-OWN-33. Not a new product decision.

### V3-ACC-14

Sentence: Booked fees and booked remainders are deployed only by `donate` or `compound`. A deposit, a withdrawal, and `exchangeIn` do not call them and do not deploy the staying holders' booked balance. One-token maintenance uses the V3-ACC-05 shape and books, rather than refunds, what the add does not take. Both-token maintenance deposits in proportion to the pool and does not swap. The caller is the live `feeTo()` owner, a global operator, or a function operator for that selector. Any other caller reverts. A failed step reverts. A remainder does not by itself revert. These calls do not restore a sleeve target. There is no donation before the first mint.

Retires: permissionless `rebalanceLiquidReserve` as the dust-deployment path.

Preserves: nothing equivalent. These selectors are an addition required by the copied dust rule.

Source: copy of FS-OWN-14, FS-OWN-21, FS-OWN-12, and the donate/compound sentences of FS-OWN-33. Not a new caller set. A permissionless rebalance is the rejected alternative, not an open choice.

### V3-ACC-15

Sentence: An underlying-to-underlying `exchangeIn` is a pass-through. It mints no shares and takes no usage fee. It refunds input the swap does not spend. It does not rebalance. It is not a withdrawal. `minAmountOut` binds the swap output.

Retires: the full-amount exact-delivery swap followed by `_rebalanceLiquidReserveBestEffort`.

Preserves: the route, and a caller minimum on output.

Source: copy of FS-OWN-24, FS-OWN-25, and FS-OWN-32. Not a new product decision.

### V3-ACC-16

Sentence: This vault has no exact-out share route and no exact-out pool route. It does not invert a constant-product deposit and does not search shares for a token amount. `previewExchangeOut` returns zero and does not revert with a vault error. On an enabled vault, `exchangeOut` reverts `ExchangeOutNotAvailable()` and moves no tokens. A disabled `exchangeOut` is not a withdrawal and reverts `VaultDisabled`. Neither selector gains a refund word. A zero preview is not a promise that execution succeeds.

Retires: `_previewZapOutWithdrawal`, `_amountInForZapMint`, `_amountInForShares`, the exact-output pool swap, and the D64 exact-out mint.

Preserves: the selectors, so existing callers fail closed instead of executing the retired math.

Source: copy of FS-OWN-19 and FS-HOOK-03 for these selectors. Not a new product decision. This requirement does not decide a blanket no-revert rule for unrelated views.

### V3-ACC-17

Sentence: While `pool.slot0().unlocked` is false, every execution route that must `swap`, `mint`, `burn`, or `collect` reverts `UniswapV3Exchange_BoundPoolInteractionBlocked`. It does not fall back to `_singleExit`, a local constant-product pay, a sleeve payment, or a V4 unlock. `canOpenBoundPoolOps` remains true only when that flag is true. A preview of an adopted route returns the computed result, or zero if the route is unsupported. It does not revert merely because the pool is locked.

Retires: `LocalDepositWhileBlocked` as a successful deposit, the locked zap-out, and the locked dual exit.

Preserves: the gate, the error, and callback authorization.

Source: copy of the brief's prohibition on a V4 unlock, and of FS-UNLOCK-02's "no sleeve fallback," expressed as a revert because a locked V3 pool cannot perform the copied actions. Not a new economic rule. Keeping the local exit would preserve retired math, and this requirement does not do that.

### V3-ACC-18

Sentence: A disabled vault reverts `VaultDisabled` on every execution route except a withdrawal, `donate`, and `compound`. A withdrawal is share in and underlying out. A pass-through is not a withdrawal. A both-token deposit reverts `VaultDisabled`. Views do not revert `VaultDisabled`. Vault-disabled and pool-locked are different gates. A pool-locked maintenance call still reverts under V3-ACC-17.

Retires: nothing in the current share-in exception. It widens the existing non-share-input disable check to the new maintenance exceptions.

Preserves: share-in withdrawal while disabled.

Source: copy of FS-OWN-26. Not a new product decision.

### V3-ACC-19

Sentence: The 49% entry swap, the one-token exit swap, and a one-token maintenance swap are same-pool swaps. They do not solve swap-price manipulation. This PRD must not claim that they do. It adds no `maxZapTickMove`, no TWAP check, no tighter price limit, and no new fee cap on those swaps. A caller who sets no minimum can sell that caller's own input at the live price. That sale does not spend the staying holders' inventory. A sandwich of an authorized maintenance swap can still sell booked fees or a booked remainder at a moved price. That exposure is accepted. It is not claimed absent. FS-HOOK-06's Hook LP ownership rules are not adopted. Its statement that swap use of a rated reserve is not a solved manipulation claim is adopted for these vault swaps.

Retires: any reading of the sleeve, or of the constant-product book, as a price protection this redesign continues.

Preserves: the unbounded V3 swap limit.

Source: copy of FS-OWN-33, FS-OWN-15, FS-OWN-14, and the manipulation sentence of FS-HOOK-06. Not a new protection design. Adding protection would be a new product decision, and this requirement does not make it.

### V3-ACC-20

Sentence: The external Standard Exchange rate provider keeps calling `previewExchangeIn`. This vault does not delete that call, does not replace either return word with NAV, and does not add `getRate()` or `rateAsset()`. `previewExchangeIn` keeps its current two-word return. For a share-minting route, the first word is the depositor's net shares under V3-ACC-04. For a one-token exit, the first word is the V3-ACC-11 receipt. The second word is the refund under V3-ACC-13. A mint preview is not the share valuation. The exit preview is the valuation of that operation and is not this vault's rate. The provider's current non-empty call prices `totalSupply` shares through the exit preview and ignores the refund word. Its empty-supply call inverts a one-unit mint preview. Those provider results are not this vault's rate, and a full-supply exit is not a per-share marginal rate. This vault does not change either call to keep the provider's old number.

Retires: the hardcoded zero refund, and the constant-product amount as the first word.

Preserves: the selector and the 64-byte return the provider already decodes.

Source: copy of FS-OWN-03, FS-OWN-08's tuple shape already present on this vault, FS-OWN-29's refusal to add a vault rate, and FS-OWN-30's split between exit valuation and mint preview. The provider's continued publication of those words is the conflict in V3-OPEN-02. This requirement does not resolve it.

## Open product decisions

These rows are requirements that the PRD state the question and not answer it. Silence is not a choice.

### V3-OPEN-01

Sentence: Position import is not decided. V4 has no import. If import remains, it must not price shares with `StandardExchangeConstantProduct`, must not mint the dead-sink floor, and must not rebalance a sleeve. The shares it mints must follow V3-ACC-02, V3-ACC-03, and V3-ACC-04. If import is removed, the only genesis path is the organic first add. This PRD does not choose which.

Retires: nothing until the choice is made. The constant-product import formula cannot survive either choice.

Preserves: the current import selector only if the open choice keeps it.

Source: not a copy. V4 does not decide a V3-only import.

### V3-OPEN-02

Sentence: The stateful rate-provider path is not decided. `quoteRate` with state calls `quoteAssets`, not `previewExchangeIn`. V4 does not install `IStandardExchangeTransitionQuote` unless a consumer rejects without it. This provider is such a consumer. Deleting the transition quote would drop that call. Leaving the current inventory simulation would keep the sleeve rebalance and the constant-product deposit in a quote the provider can read. This PRD does not choose between retaining the interface on the new engine and recording the stateful path as an unresolved consumer. It does not replace `quoteAssets` with NAV, and it does not add `getRate()` so the provider can stop calling the vault.

Retires: nothing until the choice is made.

Preserves: the provider's `previewExchangeIn` call under V3-ACC-20, whichever way this row is later closed.

Source: not a copy of V4's absence. The absence conflicts with a named consumer.

The same row covers the empty-supply consequence this response does not fix. A one-unit mint preview that refunds and mints nothing makes the provider's initial rate zero. That is not a reason to mint anyway, to substitute NAV, or to add vault `getRate()`. Whether a zero initial provider rate is acceptable is not decided.

### V3-OPEN-03

Sentence: Selector names for the both-token routes are not decided. The accounting is V3-ACC-07 and V3-ACC-12. V3 now exposes `previewExchangeInManyToOne`, which returns one word, and `exchangeOutOneToMany`, which takes requested token amounts. V4 uses `exchangeBundleInForSingleOut`, `previewExchangeBundleInForSingleOut`, and `exchangeBundleOut`, and the bundle preview must expose net shares and the refund. This PRD does not choose between keeping the V3 selectors and changing their accounting, and adding the V4 selectors and retiring the old ones. It does not hide a refund inside the current one-word many-to-one return.

Retires: nothing about names until the choice is made. The constant-product math on those routes is already retired by V3-ACC-07 and V3-ACC-12, whichever selector carries the new math.

Preserves: a both-token deposit and a both-token exit.

Source: not a copy of FS-OWN-09's names. The economic mapping is copied. The rename is not.

### V3-OPEN-04

Sentence: `exchangeRate()` and the rest of the Standardized Yield surface are not decided. `exchangeRate()` now returns `sqrt(reserve0 * reserve1) * 1e18 / supply` on the owed-inclusive reserve basis. That is a reserve-valued rate. V4 withdraws `exchangeRate()` and forbids replacing it with NAV. Leaving it publishes a valuation the adopted issuance no longer uses. Deleting the whole Standardized Yield package is wider than deposits, exits, dust, and share issuance. This PRD does not choose between withdrawing `exchangeRate()` with no NAV substitute, and keeping it while stating that it is not the issuance rule and not the exit valuation. It does not add `getRate()` as the substitute.

Retires: nothing until the choice is made.

Preserves: no vault `getRate()`, under V3-ACC-20, either way.

Source: not a silent copy of FS-OWN-05. The conflict is named here.

## Rejected alternatives

These are not open. They are named so a later draft cannot treat them as adopted by silence.

- Permissionless sleeve rebalance as the dust path. Rejected by V3-ACC-08 and V3-ACC-14.
- Local `x*y=k` settlement while the V3 pool is locked. Rejected by V3-ACC-17.
- A closed-form or searched input split, including `quadraticInput`. Rejected by V3-ACC-05.
- Keeping constant-product issuance so the rate provider's old number is unchanged. Rejected by V3-ACC-02 and V3-ACC-20.
- Adding vault `getRate()`, or replacing a preview word with NAV, to reconcile the provider. Rejected by V3-ACC-20.
- A tighter swap cap, TWAP, or other manipulation control. Rejected by V3-ACC-19.
- Copying hook pair-token books or Hook LP entitlement into this vault. Rejected by V3-ACC-01.
- Requiring a V4 unlock on this vault. Rejected by V3-ACC-01.

# Limits

- This response does not authorize implementation, a PRD edit, or a coordinator draft. It does not claim council consensus.
- V4 execution was not read. The copy source for behavior is the dated PRD lock, checked against the planner and math where those files were read.
- The V3 remediation PRD, pairToken, and upperLowerWings were not examined.
- Other callers of `StandardExchangeConstantProduct` were not searched. These requirements do not delete that library.
- Deadline-before-disable ordering in FS-OWN-28 is not adopted and is not rejected. It is outside deposit, exit, dust, and share issuance. Silence is not adoption of that reorder or of a deadline-error rename.
- FS-OWN-08's consumer-migration index was not re-verified. V3-ACC-20 relies on the provider facet that was read, not on that index.
- No test, build, install, deploy, or Git operation was run.
