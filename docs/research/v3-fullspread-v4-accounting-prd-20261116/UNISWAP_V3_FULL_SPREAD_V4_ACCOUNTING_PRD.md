# Uniswap V3 full-spread vault: V4 accounting PRD

- Run ID: v3-fullspread-v4-accounting-prd-20261116
- Draft reviewed: draft-v3-fullspread-v4-accounting-prd-20261116-r1
- Result label: full
- Coordinator mode: invoking-agent
- Implementation authority: none. This PRD does not authorize edits, tests, installs, deployment, or Git.

This file is the council final. Wording added after the reviewed draft is a coordinator revision. It is not member-approved text. Member agreement is not correctness.

## Question

What requirements must a PRD state so the Uniswap V3 full-spread Standard Exchange vault processes deposits, exits, dust, and share issuance in the same manner as the Uniswap V4 full-spread Standard Exchange vault, which current V3 behaviors that PRD must retire or preserve, and which differences are a new product decision rather than a copy of V4?

## Participants

| Participant | Role | Requested model | Task ID | Initial | Feedback |
| --- | --- | --- | --- | --- | --- |
| Invoking session | coordinator, not a vote | grok-4.7; reasoning not exposed | not exposed | n/a | n/a |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | st_01a1e66a | settled | requested-changes |
| grok | council-member | xai/grok-4.7:high | st_01a1e66b | settled | requested-changes |
| minimax | council-member | minimax/MiniMax-M3, adaptive thinking | st_01a1e66c | settled | requested-changes |
| kimi | council-member | kimi-coding/k3.1-pro:high, global route | st_01a1e66d | settled | requested-changes |

Runtime session IDs for the members were not exposed. Model prose is not identity.

## Scope

This PRD governs the full-spread vault under `contracts/vaults/standard/exchange/protocols/uniswap/v3/` only. It does not modify the older implementation under `contracts/protocols/dexes/uniswap/v3/`. It does not repoint an existing deployment. Owner lock V3-OWN-04 applies the accounting only to newly deployed vaults of this implementation. It is not a migration of an existing instance, and it is not permission to edit the older tree.

The behavior source is the Uniswap V4 full-spread vault and its PRD. Pair-token and upper/lower wings are not the template.

## Adopted requirements

A "copy" adopts the named V4 lock. A V3 callback expression is how that lock is performed. It is not a second economic rule.

### V3-ACC-01 — Fence

The vault adopts only the deposit, exit, dust, and share-issuance accounting named here. A V4 lock applies only where a requirement names it. Pool actions are `pool.swap`, `pool.mint`, `pool.burn`, and `pool.collect`, paid through the existing V3 mint and swap callbacks. This vault does not call PoolManager `unlock` and does not take a borrowed unlock. It does not adopt FS-OWN-34's hook component formula, FS-OWN-35, FS-OWN-36, FS-OWN-37, FS-HOOK-05, FS-HOOK-07, FS-HOOK-08, FS-HOOK-09, or FS-HOOK-10 as vault share math. It does not adopt native-currency substitution. Its pool tokens remain `pool.token0()` and `pool.token1()`.

For an organic book, the one vault-owned position uses `TickMath.minUsableTick` and `TickMath.maxUsableTick` at the bound pool's tick spacing. Those bounds are fixed before the first add. No minimum tick spacing is added. This sentence does not decide whether import survives.

Copy of the brief's expression rule and of FS-OWN-34's statement that full-spread issuance stays FS-OWN-24/27.

### V3-ACC-02 — Share basis

Share minting and burning use the raw liquidity of that position. They do not use token reserves, `sqrt(x*y)`, NAV, or `decimals()`. On an existing supply, `grossShares = floor(addedLiquidity * totalSupply / existingLiquidity)`, with supply and liquidity read before the add. Idle balances, booked remainders, and accrued fees are not in that denominator. On a burn, liquidity removed is `floor(positionLiquidity * sharesBurned / supplyBeforeBurn)`.

Copy of FS-OWN-24 and FS-OWN-27. Retires `_sharesOutForDeposit`, `_sharesForDeposit`, and reserve-book issuance.

### V3-ACC-03 — Genesis floor

The first liquidity add must exceed 1,000 or the plan fails. A failed genesis plan reverts `MinLiquidityNotMet()` and mints nothing. It is not a successful whole-input refund. That includes a first deposit whose 49% swap cannot be formed, whose output the add cannot consume, or whose added liquidity is at or under 1,000. The inspected V4 execution reverts `MinLiquidityNotMet()` when `plan.failed` is set, and `Planner._shares` sets that flag when supply is zero and added liquidity is at or under 1,000.

On a successful first add, the vault records `balanceOf(address(0))` of 1,000 and includes that balance in `totalSupply()`. The write does not revert. It does not use `ERC20Repo._mint` or any other path that reverts `ERC20InvalidReceiver` for `address(0)`. The floor is not part of `grossShares` and is not a fee mint. `grossShares` is `addedLiquidity - 1,000`. The vault does not mint a decimals-based floor, residual unlike-token weight, or a floor to `address(0xdead)`.

An oversized one-token pretransfer on an empty vault is also a failed genesis. It reverts `MinLiquidityNotMet()`. It does not succeed as a refund.

Copy of FS-OWN-11 and FS-MONEY-01, including the non-reverting `address(0)` write. Retires `_minimumLiquidity`, `DEAD_SHARES_SINK`, and `_initialResidualShares` for an organic first deposit.

### V3-ACC-04 — Usage fee

On every share-minting deposit, including the first, take the usage fee from `grossShares`. Do not mint it on top. If `feeTo` is not `address(0)` and the clamped fee is non-zero, `feeShares = mulDiv(grossShares, clampedFee, 1e18)`. Mint `feeShares` to `feeTo` and the remainder to the recipient. A fee above `3e17` is used as `3e17`. The clamp does not write the oracle. Previews and minima use the depositor's net shares. A pass-through takes no fee. There is no exit fee.

Copy of FS-OWN-24. MiniMax reserved whether a vault that charges no fee today must take one. That reservation is carried under Disagreement. This requirement does not leave the fee unset.

### V3-ACC-05 — One-sided mint

Processed input is the amount this call will use after the funding rule in V3-ACC-10, and before the 49% split. An oversized one-token pretransfer has no processed input.

When supply is already positive and the current sqrt price is strictly inside the position, a one-sided share mint runs one exact-input `pool.swap` of `floor(processedInput * 49 / 100)`, with `sqrtPriceLimitX96` equal to `TickMath.MIN_SQRT_RATIO + 1` or `TickMath.MAX_SQRT_RATIO - 1`, then `pool.mint` of the liquidity whose rounded-up amounts consume that swap's entire output and no more than the unswapped input. It does not iterate, does not solve a closed-form root, does not walk ticks to find a better split, and does not use `quadraticInput`.

If that swap amount is zero, cannot be quoted, is not fully spent, receives zero output, or the following mint cannot consume that output, and supply is already positive, the call refunds the whole processed input, executes no swap, and mints nothing. It uses no new error. If the caller's minimum is greater than zero, that no-mint result reverts `AmountOutNotMet` instead of succeeding as a zero output. A successful add refunds unused original input under V3-ACC-10. That remainder is not minted and is not booked.

A first deposit does not use this refund branch. A first deposit that cannot form the swap or the add fails under V3-ACC-03.

Preview and execution use this same sizing. A preview does not transfer.

Copy of FS-OWN-33 and of `Planner._size` / `Math.sizeOneSided`, with the genesis precedence taken from the inspected execution revert rather than from the unqualified FS-OWN-33 refund sentence.

### V3-ACC-06 — Boundary and zero active liquidity

If supply is already positive and the sqrt price is not strictly inside the position, including exactly at either boundary, a one-sided share mint does not swap. If the caller provided the token the position wants, add it with no swap and refund what the add does not take. If the caller provided the other token, refund it and mint nothing. Zero active pool liquidity is not that boundary case. In that established-supply case, refund the whole input and mint nothing. These refunds use no new error, unless the caller's minimum is greater than zero, in which case the call reverts `AmountOutNotMet`.

The zero-active refund does not apply to a wanted-token boundary add. It does not override V3-ACC-03 on an empty vault.

Copy of FS-OWN-33 and the zero-active branch of `Planner._size`.

### V3-ACC-07 — Both-token deposit

A both-token deposit adds the greatest proportional liquidity supported by the declared amounts at the current pool price. It refunds each token the add does not take. It does not run the 49% swap. Fees attributable to liquidity that existed before the add are collected and booked under V3-ACC-11. They are not the caller's share credit. Shares follow V3-ACC-02 and V3-ACC-04. The selectors are `previewExchangeBundleInForSingleOut` and `exchangeBundleInForSingleOut` under V3-OWN-03.

Copy of FS-OWN-25 and the bundle sentence of FS-OWN-33. Retires the minimum-of-proportions constant-product dual mint.

### V3-ACC-08 — No sleeve

This vault has no local liquidity sleeve. It does not read `liquidReservePercentageOfVault` as a target. It does not mint or burn liquidity to move a free balance toward that target after a deposit, a withdrawal, a pass-through, `donate`, or `compound`. It does not keep the 5% deadband or the decimals floor as a rebalance tolerance.

`rebalanceLiquidReserve` is removed. `targetLiquidReservePercentage` is removed. `localReserve` is removed as a sleeve-balance view. A liquid-reserve percentage view is removed. `canOpenBoundPoolOps` remains, and it remains only the pool-lock gate. `deployedReserve`, if retained, reports position token amounts and is not a share basis and not a sleeve target. `LocalDepositWhileBlocked` is not emitted, because the locked-pool local deposit is retired by V3-ACC-15.

Copy of FS-OWN-04 and FS-OWN-12. Retires `_rebalanceLiquidReserveBestEffort`, `_rebalanceLiquidReserveInternal`, and the post-operation rebalance calls.

### V3-ACC-09 — Balance classes

The vault accounts separately for deployed position liquidity, accrued but uncollected position fees, booked per-token remainders, and unbooked ERC-20 balances. Unbooked balances are not reserves and are not redeemable. A booked remainder is a vault record. It is not a reserve, including after `donate` and `compound` are added. A user deposit, a withdrawal, and `exchangeIn` do not deploy the staying holders' booked balance. An authorized `donate` or `compound` may budget eligible booked balances under V3-OWN-02. `reserves()` and `reserveOfToken` report deployed token amounts plus unpaid position fees. They do not add a free-balance term, a booked term, or a last-committed snapshot. Booked tokens may sit in the vault's ERC-20 balance. They are excluded from those reads and from the next user share-minting add.

Copy of FS-OWN-07, FS-OWN-20, and FS-OWN-30. The storage expression is required because V3 has no PoolManager credit.

### V3-ACC-10 — Refunds and funding

Input that does not become liquidity is not minted into shares and is not left for the other shareholders on a user deposit.

On a pull, pull the declared amount from `msg.sender`, then refund the unkept amount of that token to `msg.sender`. Shares or exit output go to `recipient`.

On a one-token pretransfer, process only this call's unbooked credit. If the declared maximum is within that credit, use at most the maximum and refund maximum minus used. If the declared maximum exceeds the unbooked balance, spend none of that balance, mint no shares, and do not pull a shortfall. On an empty vault, that call reverts `MinLiquidityNotMet()`. On an existing supply, refund the entire unbooked balance. If the caller's minimum is greater than zero, revert `AmountOutNotMet` instead of returning a zero output. A bundle whose any maximum exceeds that token's unbooked balance reverts before a leg is processed.

A share-minting deposit's pre-existing fees are booked under V3-ACC-11, not refunded. A donate or compound remainder is booked, not refunded. A one-token exit's unspent opposing residual is neither booked nor kept. That exit reverts `AmountOutNotMet` and does not burn shares. A preview of a refund does not transfer and need not equal the execution refund. The exit receipt's match to execution is not waived by that sentence.

Copy of FS-OWN-32 and FS-OWN-20, and of the oversized-pretransfer branch in `UniswapV4FullSpreadStandardExchangeVaultExecution.sol`. Retires the hardcoded zero refund and the rule that spends a staged balance down to what the add needs.

### V3-ACC-11 — Fees on mint and exit

Before every share-minting add, snapshot the position's collectable fees attributable to liquidity that already exists. Collect those fees, including by `burn(0)` and `collect` when that is what moves them out of the pool, and book the collected amounts. Collected fees become booked custody only after that collection. Unpaid fees and booked amounts are mutually exclusive. Do not infer the fee from a combined mint-callback or balance delta. Do not include those fees in the add, the caller's share credit, or a deposit swap.

On a withdrawal, read collectable center fees before the burn. The caller's fee claim is `floor(collectableFees * sharesBurned / supplyBeforeBurn)` for each token. The caller's booked claim is `floor(booked * sharesBurned / supplyBeforeBurn)`. Leave the rest with the remaining supply. Do not also pay that same fee as a free-balance share. After `burn` and `collect`, split the collected tokens by that pre-burn read. Do not use the combined balance delta as the claim. A fee moved from the pool into booked custody is counted once.

Copy of FS-OWN-30, expressed with V3 collect. Retires `_collectIfIdle` before share math and the proportional free-balance entitlement.

### V3-ACC-12 — One-token exit

A canonical one-token exit burns shares held by the caller. It does not treat shares merely delivered to the vault as generic exit credit. It burns the caller's liquidity fraction and pays `recipient` the swap proceeds of that holder's opposing claim, the withdrawn requested-token principal, that holder's requested-token fee portion, and that holder's requested booked claim. The opposing claim is that holder's unwanted principal, unwanted fee claim, and unwanted booked claim. It is not the staying holders' inventory.

The swap is one exact-input `pool.swap` of that entire opposing amount, quoted after the liquidity removal, at the same price limit as V3-ACC-05. If that swap cannot spend the entire opposing amount, execution reverts `AmountOutNotMet` and does not burn shares. The preview of that failed plan does not revert. It returns a zero first word and is not a successful receipt. A completable preview returns the receipt execution will pay, so that `amountOut` matches execution. `minAmountOut` binds the full receipt. The preview is the share valuation of that operation. It is not `getRate()`.

This vault has no Standardized Yield redemption. A vault-held share burn is not an exit path. V3-OWN-05 removes that surface.

Copy of FS-OWN-15, FS-OWN-20, and FS-OWN-30. Retires sleeve pay, partial-input acceptance, and the exact-out share search as the exit quote.

### V3-ACC-13 — Both-token exit

A both-token exit pays the V3-ACC-12 claim in both tokens and does not swap. Shares burned are the caller's exact-in share amount, from shares the caller holds. The exit is not sized by inverting token reserves, and it does not require the two token claims to imply an equal share burn of a requested token amount. The selectors are `previewExchangeBundleOut` and `exchangeBundleOut` under V3-OWN-03.

Copy of FS-OWN-09's mapped redeem and FS-OWN-30. Retires reserve-ratio share burn on the current one-to-many exit.

### V3-ACC-14 — Pass-through

An underlying-to-underlying `exchangeIn` is a pass-through. It mints no shares and takes no usage fee. It refunds input the swap does not spend. It does not rebalance. `minAmountOut` binds the swap output.

Copy of FS-OWN-25 and FS-OWN-32. Retires the trailing rebalance on the direct swap.

### V3-ACC-15 — Pool locked

While `pool.slot0().unlocked` is false, every execution route that must `swap`, `mint`, `burn`, or `collect` reverts `UniswapV3Exchange_BoundPoolInteractionBlocked`. It does not fall back to constant-product issuance, `_singleExit`, a local pay, or a V4 unlock. A preview of an adopted route returns the computed result, or zero if the route is unsupported. It does not revert merely because the pool is locked. `slot0.unlocked == true` means the V3 pool is idle. That polarity is not V4 `isUnlocked`.

Copy of the no-sleeve rule, expressed as a revert because a locked V3 pool cannot perform the copied actions. Retaining a local-only route would be a different product. This PRD does not adopt it.

### V3-ACC-16 — Disable

A disabled vault reverts `VaultDisabled` on every execution route except a withdrawal, `donate`, and `compound`. A withdrawal is share in and underlying out. A pass-through is not a withdrawal. Views do not revert `VaultDisabled`. Vault-disabled and pool-locked are different gates. A disabled `exchangeOut` reverts `VaultDisabled` and is not a withdrawal.

Copy of FS-OWN-26.

### V3-ACC-17 — Exact-out

The bounded exact-out share search, the constant-product deposit inverse, and the exact-out mint are not accounting paths. `previewExchangeOut` returns zero and does not revert with a vault error. On an enabled vault, `exchangeOut` reverts `ExchangeOutNotAvailable()` and moves no tokens. A disabled `exchangeOut` reverts `VaultDisabled`. Neither selector gains a refund word. A zero preview is not a promise that execution succeeds.

This is the parity rule. It is also an express compatibility disposition: Astra required that the retirement be stated, and advised this fail-closed policy. A retained exact-out route with the old economics is rejected. A retained exact-out route with new accounting would be a new product. This PRD does not specify one.

Copy of FS-OWN-19 and FS-HOOK-03 for these selectors.

### V3-ACC-18 — Manipulation limit

The 49% entry swap, the one-token exit swap, and a one-token maintenance swap are same-pool swaps. They do not solve swap-price manipulation. This PRD must not claim that they do. It adds no `maxZapTickMove`, no TWAP check, no tighter price limit, and no new fee cap on those swaps. A sandwich of an authorized maintenance swap can still sell booked fees or a booked remainder at a moved price. That exposure is accepted. It is not claimed absent. Hook LP ownership rules are not adopted. The FS-HOOK-06 sentence that swap use of a rated reserve is not a solved manipulation claim is adopted for these vault swaps.

Copy of FS-OWN-33, FS-OWN-14, and that one sentence of FS-HOOK-06.

### V3-ACC-19 — External preview

The external Standard Exchange rate provider keeps calling `previewExchangeIn`. This vault does not delete that call, does not replace either return word with NAV, and does not add `getRate()` or `rateAsset()`. `previewExchangeIn` keeps its current two-word return. For a share-minting route, the first word is the depositor's net shares. For a one-token exit, the first word is the V3-ACC-12 receipt, or zero when the plan cannot spend the opposing amount. The second word is the refund. A mint preview is not the share valuation. The exit preview is the valuation of that operation and is not this vault's rate.

The provider's non-empty call prices `totalSupply` shares through the exit preview and ignores the refund word. If that full-book exit cannot spend the opposing amount, the preview's first word is zero and the provider reads a zero rate. The provider's empty-supply call inverts a one-unit mint preview. A first deposit that would not exceed the floor, or that cannot form the add, does not mint. That inversion therefore sees zero shares, and the provider reads a zero rate. This PRD states both outcomes. It adds no fallback rate and does not change either call to keep the provider's old number.

Copy of FS-OWN-03, FS-OWN-08's existing tuple, and FS-OWN-29's refusal to add a vault rate, plus the brief's provider constraint. This vault does not implement `quoteAssets`. V3-OWN-05 removes that surface. The provider's `previewExchangeIn` call in this requirement remains.

### V3-ACC-20 — Consequence of the copied mint

Later mints calculate gross shares from actual newly added liquidity against pre-add deployed liquidity and pre-mint supply. Unpaid fees and booked balances are excluded from that denominator. Future fee and booked claims use the enlarged post-mint supply, including the new shares and the genesis floor. A later mint can therefore reduce an old holder's booked claim per share even though the mint did not credit shares for those booked tokens. That is the copied FS-OWN-24/30 formula. This PRD does not add a stronger per-vintage claim.

## Owner locks

Locked 2026-11-16 by the owner in this session. These locks close the former open rows. They are not a council vote. They do not authorize implementation.

### V3-OWN-01 — Position import

Position import stays. `previewImportPosition` and `importPosition` remain. V4 has no import. This is a V3 entry, not a V4 copy.

The import collects every token amount the NFT yields: both tokens' principal and the fees collected from that position. Those amounts are a both-token deposit under V3-ACC-07. The vault adds the greatest proportional liquidity those amounts support and refunds each token the add does not take. The refund goes to `recipient`. The preview reports the depositor's net shares and both refunds. The one-word preview return is not enough for that report. The import execution transfers the overage. It does not leave it in the vault. After the tokens are collected, the empty position NFT is burned. It is not left on the vault and it is not returned to the owner.

Import may run when the vault already has supply. It is not limited to an empty vault. A later import is the same proportional add and refund. It does not replace the existing position and it does not reset supply. Fees already owed by the destination position stay under V3-ACC-11 and are not part of the importer's deposit.

Those NFT amounts are the importer's incoming assets. They are not booked into the destination vault's shared fee balance. The import does not use `StandardExchangeConstantProduct`, does not mint the dead-sink floor, and does not rebalance a sleeve. Shares follow V3-ACC-02, V3-ACC-03, and V3-ACC-04. The genesis floor applies only when the import is the first liquidity.

### V3-OWN-02 — Donate and compound

`donate` and `compound` are added. They follow FS-OWN-14, FS-OWN-21, and the donate and compound sentences of FS-OWN-33. One-token maintenance uses the 49% shape and books the remainder. Both-token maintenance adds in proportion and does not swap. The caller is the live `feeTo()` owner, a global operator, or a function operator for that selector. User routes do not call them. There is no donation before the first mint. Permissionless `rebalanceLiquidReserve` is not a substitute. Booked tokens stay out of reserves.

### V3-OWN-03 — V4 selectors and new facets

The additional V4 selectors are added on new facets. They are not stuffed into the existing one-token facets.

The new selectors are `previewExchangeBundleInForSingleOut`, `exchangeBundleInForSingleOut`, `previewExchangeBundleOut`, `exchangeBundleOut`, `donate`, `compound`, `setOperator`, and `setOperatorFor`. Their argument meanings and return words are the V4 meanings: bundle deposit amounts in, one share amount out, and a refund word for each input; bundle exit is an exact share amount in and a minimum for each output token. A requested exact output is not silently a minimum. A maximum share input is not silently an exact share burn. `previewExchangeIn` and `exchangeIn` remain the one-token routes. `previewExchangeOut` and `exchangeOut` remain the fail-closed routes in V3-ACC-17. This vault does not add `unlockCallback`.

### V3-OWN-04 — New vaults only

The accounting applies only to newly deployed vaults of the governed implementation. There is no migration of existing supply, dead-sink shares, sleeve balances, unpaid fees, or imported positions. No formula change reclassifies old local property. This lock does not authorize an edit to `contracts/protocols/dexes/uniswap/v3/`.

### V3-OWN-05 — No Standardized Yield

This vault does not implement `IStandardizedYield`. It does not implement `exchangeRate()`, `assetInfo()`, or a named vault-held share redemption. It does not implement `quoteAssets`. The V4 full-spread surface does not expose those functions, and this vault matches that surface except for the import entry in V3-OWN-01.

`previewExchangeIn` stays. The external rate provider keeps that call. A stateful `quoteRate` that calls `quoteAssets` will not find that function on this vault. That is the surface match. It is not a deletion of `previewExchangeIn`, and it is not a NAV substitution. The vault still does not add `getRate()`.

## Disagreement carried

- Usage fee: adopted as a V4 copy. MiniMax's reservation that this vault charges none today is carried, not adopted.
- Donate and compound: closed by V3-OWN-02. The earlier split is historical. It is not still open.
- Exact-out: fail-closed text is adopted. Astra is recorded as requiring that disposition to be express, not as opposing the fail-closed policy.
- First-deposit refund: not adopted for a failed genesis plan. Grok asked for an FS-OWN-33 refund of an unformable first-deposit swap. The inspected execution reverts `MinLiquidityNotMet()` on `plan.failed`.
- Import, new-vault scope, V4 selectors, and the Standardized Yield surface: closed by V3-OWN-01, V3-OWN-03, V3-OWN-04, and V3-OWN-05. Those locks are owner decisions. They are not council consensus.

This is not consensus.

## Rejected alternatives

- Permissionless sleeve rebalance as the dust path.
- Local `x*y=k` settlement while the V3 pool is locked.
- A searched or closed-form input split, including `quadraticInput`.
- Keeping constant-product issuance so the rate provider's old number is unchanged.
- Adding vault `getRate()`, or replacing a preview word with NAV.
- A tighter swap cap, TWAP, or other manipulation control.
- Copying hook pair-token books or Hook LP entitlement into this vault.
- Requiring a V4 unlock on this vault.
- Minting the genesis floor to `address(0xdead)`, from token decimals, or through a path that reverts `ERC20InvalidReceiver` for `address(0)`.
- Treating a raw `collect` balance delta as the exiting holder's entire claim.
- Spending an oversized one-token pretransfer down to the available balance.
- A successful refund of a failed genesis plan.

## Advisory outcome

All four members reviewed draft `draft-v3-fullspread-v4-accounting-prd-20261116-r1` and returned `requested-changes`. Every substantive concern is mapped in `coordinator/resolution.md`. Accepted corrections are in this file. They were not sent back for another review. Post-review wording is a coordinator revision.

## Limitations

- Static reading only. No test was run. No gas measurement is claimed.
- Kimi did not examine the optional remediation PRD, the pair-token tree, the wings tree, or the rate-provider facet. Provider sentences use the other three responses and the coordinator's read of `StandardExchangeRateProviderFacet.sol` and of the V4 execution file cited above.
- Live files can change. This PRD is not an atomic snapshot.
- This PRD does not authorize implementation.

## Publication

- Publication state: published
- Final path: docs/research/v3-fullspread-v4-accounting-prd-20261116/UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_PRD.md
- Cooperative update of an existing product PRD: none
- Draft bytes changed after review: no
- Model work repeated for publication: no
- Git actions: none
