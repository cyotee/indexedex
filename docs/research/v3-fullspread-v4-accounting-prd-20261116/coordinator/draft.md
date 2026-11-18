# Coordinator draft

- Draft ID: draft-v3-fullspread-v4-accounting-prd-20261116-r1
- Path: docs/research/v3-fullspread-v4-accounting-prd-20261116/coordinator/draft.md
- Fingerprint: not computed
- Profile: research
- Council kind: full
- This draft is not the final PRD. It does not authorize implementation. It does not replace the V4 PRD or the V3 remediation PRD.
- Coordinator is not a vote. Member agreement is not correctness.

## Question

What requirements must a PRD state so the Uniswap V3 full-spread Standard Exchange vault processes deposits, exits, dust, and share issuance in the same manner as the Uniswap V4 full-spread Standard Exchange vault, which current V3 behaviors that PRD must retire or preserve, and which differences are a new product decision rather than a copy of V4?

## Sources compared

All four members read the required V3 deposit, exit, share, and rebalance code, `StandardExchangeConstantProduct.sol`, the V4 full-spread PRD, and the V4 planner and math. Optional files were not uniformly read. Kimi marked the optional sources not examined. That gap is carried below. No member ran a test. Claims below are static source observations reported by the members, checked by the coordinator against the named locks and the code read in this session before the council.

## Adopted requirements

These sentences are the proposed PRD text. "Copy" means the V3 vault adopts that named V4 lock. A V3 callback expression is an adaptation, not a new economic rule.

### V3-ACC-01 — Fence

The Uniswap V3 full-spread Standard Exchange vault adopts only the deposit, exit, dust, and share-issuance accounting named in this PRD from the Uniswap V4 full-spread vault. A V4 lock applies here only where a requirement names it. Pool actions are `pool.swap`, `pool.mint`, `pool.burn`, and `pool.collect`, paid through the existing V3 mint and swap callbacks. This vault does not call PoolManager `unlock` and does not take a borrowed unlock. It does not adopt FS-OWN-34's hook component formula, FS-OWN-35, FS-OWN-36, FS-OWN-37, FS-HOOK-05, FS-HOOK-07, FS-HOOK-08, FS-HOOK-09, or FS-HOOK-10 as vault share math. It does not adopt native-currency substitution. Its pool tokens remain `pool.token0()` and `pool.token1()`. It keeps one vault-owned full-range position.

Copy of the brief's expression rule and of FS-OWN-34's statement that full-spread issuance stays FS-OWN-24/27. Not a copy of the hook refactor.

### V3-ACC-02 — Share basis

Share minting and burning use the raw liquidity of that one position. They do not use token reserves, `sqrt(x*y)`, NAV, or `decimals()`. On an existing supply, `grossShares = floor(addedLiquidity * totalSupply / existingLiquidity)`, with supply and liquidity read before the add. Idle balances, booked remainders, and accrued fees are not in that denominator. On a burn, liquidity removed is `floor(positionLiquidity * sharesBurned / supplyBeforeBurn)`.

Copy of FS-OWN-24 and FS-OWN-27. Retires `_sharesOutForDeposit`, `_sharesForDeposit`, and reserve-book issuance.

### V3-ACC-03 — Genesis floor

The first liquidity add must exceed 1,000 or the call reverts `MinLiquidityNotMet()` and mints nothing. The vault mints 1,000 shares to `address(0)`. That balance is part of `totalSupply()`. It is not part of `grossShares` and it is not a fee mint. `grossShares` is `addedLiquidity - 1,000`. The vault does not mint a decimals-based floor, does not mint residual unlike-token weight, and does not mint the floor to `address(0xdead)`.

Copy of FS-OWN-11 and FS-MONEY-01. Retires `_minimumLiquidity`, `DEAD_SHARES_SINK`, and `_initialResidualShares` for an organic first deposit. An unusable first deposit reverts. It does not succeed as a whole-input refund. That reading follows the inspected V4 planner's failed-genesis branch, which Astra advised copying if implementation parity is intended. Import and already-issued supply are V3-OPEN-01 and V3-OPEN-04.

### V3-ACC-04 — Usage fee

On every share-minting deposit, including the first, take the usage fee from `grossShares`. Do not mint it on top. If `feeTo` is not `address(0)` and the clamped fee is non-zero, `feeShares = mulDiv(grossShares, clampedFee, 1e18)`. Mint `feeShares` to `feeTo` and the remainder to the recipient. A fee above `3e17` is used as `3e17`. The clamp does not write the oracle. Previews and minima use the depositor's net shares. A pass-through takes no fee. There is no exit fee.

Copy of FS-OWN-24. MiniMax listed "whether this fee applies at all" as an open item because this vault charges no usage fee today. The other three treat the fee as part of behaving like V4. This draft adopts the copy and carries MiniMax's reservation in Disagreement. It does not leave the fee unset.

### V3-ACC-05 — One-sided mint

When the current sqrt price is strictly inside the position, a one-sided share mint runs one exact-input `pool.swap` of `floor(processedInput * 49 / 100)`, with `sqrtPriceLimitX96` equal to `TickMath.MIN_SQRT_RATIO + 1` or `TickMath.MAX_SQRT_RATIO - 1`, then `pool.mint` of the liquidity whose rounded-up amounts consume that swap's entire output and no more than the unswapped input. It does not iterate, does not solve a closed-form root, does not walk ticks to find a better split, and does not use `quadraticInput`. If that swap amount is zero, cannot be quoted, is not fully spent, receives zero output, or the following mint cannot consume that output, the call refunds the whole processed input, executes no swap, and mints nothing. A successful add refunds unused original input under V3-ACC-10. That remainder is not minted and is not booked. Preview and execution use this same sizing. A preview does not transfer.

Copy of FS-OWN-33 and of `Planner._size` / `Math.sizeOneSided`. The V3 price-limit names and the mint callback are the expression, not a second rule.

### V3-ACC-06 — Boundary and zero active liquidity

If the sqrt price is not strictly inside the position, including exactly at either boundary, a one-sided share mint does not swap. If the caller provided the token the position wants, add it with no swap and refund what the add does not take. If the caller provided the other token, refund it and mint nothing. Zero active pool liquidity is not that boundary case. In that case, refund the whole input and mint nothing. These refunds use no new error.

Copy of FS-OWN-33 and the zero-active branch of `Planner._size`.

### V3-ACC-07 — Both-token deposit

A both-token deposit adds the greatest proportional liquidity supported by the declared amounts at the current pool price. It refunds each token the add does not take. It does not run the 49% swap. Fees observed on that add are booked and are not the caller's share credit. Shares follow V3-ACC-02 and V3-ACC-04. The selector that carries this rule is V3-OPEN-03.

Copy of FS-OWN-25 and the bundle sentence of FS-OWN-33. Retires the minimum-of-proportions constant-product dual mint.

### V3-ACC-08 — No sleeve

This vault has no local liquidity sleeve. It does not read `liquidReservePercentageOfVault` as a target. It does not mint or burn liquidity to move a free balance toward that target after a deposit, a withdrawal, a pass-through, `donate`, or `compound`. It does not keep the 5% deadband or the decimals floor as a rebalance tolerance. `rebalanceLiquidReserve` no longer moves inventory. `canOpenBoundPoolOps` remains the pool-lock gate only.

Copy of FS-OWN-04 and FS-OWN-12. Retires `_rebalanceLiquidReserveBestEffort`, `_rebalanceLiquidReserveInternal`, and the post-operation rebalance calls.

### V3-ACC-09 — Balance classes

The vault accounts separately for deployed position liquidity, accrued but uncollected position fees, booked per-token remainders, and unbooked ERC-20 balances. Unbooked balances are not reserves and are not redeemable. A booked remainder is a vault record. It is not a reserve until `donate` or `compound` deploys it, if those operations are adopted under V3-OPEN-02. A user deposit, a withdrawal, and `exchangeIn` do not deploy the staying holders' booked balance. `reserves()` and `reserveOfToken` report deployed token amounts plus unpaid position fees. They do not add a free-balance term, a booked term, or a last-committed snapshot. On this callback vault, booked tokens may sit in the vault's ERC-20 balance, but they are excluded from those reads and from the next add's budget.

Copy of FS-OWN-07, FS-OWN-20, and FS-OWN-30. The storage expression is required because V3 has no PoolManager credit. It is not a new economic rule.

### V3-ACC-10 — Refunds

Input that does not become liquidity is not minted into shares and is not left for the other shareholders on a user deposit. On a pull, pull the declared amount from `msg.sender`, then refund the unkept amount of that token to `msg.sender`. Shares or exit output go to `recipient`. On a pretransfer, process only this call's unbooked credit up to the declared maximum. Refund maximum minus used when the maximum is within that credit. If a one-token maximum exceeds the unbooked balance, consume nothing beyond that balance, refund the unused amount, and do not pull a shortfall. A bundle whose any maximum exceeds that token's unbooked balance reverts before a leg is processed. A share-minting deposit's fees are booked, not refunded. A donate or compound remainder is booked, not refunded, if those operations exist. A one-token exit's unspent opposing residual is neither booked nor kept. That exit reverts instead. A preview of a refund does not transfer and need not equal the execution refund. The exit receipt's match to execution is not waived by that sentence.

Copy of FS-OWN-32 and FS-OWN-20. Retires the hardcoded zero refund and exact-out surplus left for holders.

### V3-ACC-11 — Fees on mint and exit

A share-minting mint does not collect pre-existing fees into the add, the caller's share credit, or a swap. On a withdrawal, read collectable center fees before the burn. The caller's fee claim is `floor(collectableFees * sharesBurned / supplyBeforeBurn)` for each token. The caller's booked claim is `floor(booked * sharesBurned / supplyBeforeBurn)`. Leave the rest with the remaining supply. Do not also pay that same fee as a free-balance share. After `burn` and `collect`, split the collected tokens by that pre-burn read. Do not use the combined balance delta as the claim. A fee moved from the pool into booked custody is counted once.

Copy of FS-OWN-30, expressed with V3 `collect`. Retires `_collectIfIdle` before share math and the proportional free-balance entitlement.

### V3-ACC-12 — One-token exit

A one-token exit burns the caller's liquidity fraction and pays `recipient` the swap proceeds of that holder's opposing claim, the withdrawn requested-token principal, that holder's requested-token fee portion, and that holder's requested booked claim. The opposing claim is that holder's unwanted principal, unwanted fee claim, and unwanted booked claim. It is not the staying holders' inventory. The swap is one exact-input `pool.swap` of that entire opposing amount, quoted after the liquidity removal, at the same price limit as V3-ACC-05. If that swap cannot spend the entire opposing amount, the call reverts and does not burn shares. `minAmountOut` binds the full receipt. The preview quotes that same receipt. The preview is the share valuation of that operation. It is not `getRate()`.

Copy of FS-OWN-15 and FS-OWN-30. Retires sleeve pay, partial-input acceptance, and the exact-out share search as the exit quote.

### V3-ACC-13 — Both-token exit

A both-token exit pays the V3-ACC-12 claim in both tokens and does not swap. Shares burned are the caller's exact-in share amount. The exit is not sized by inverting token reserves, and it does not require the two token claims to imply an equal share burn of a requested token amount. The selector is V3-OPEN-03.

Copy of FS-OWN-09's mapped redeem and FS-OWN-30. Retires reserve-ratio share burn on the current one-to-many exit.

### V3-ACC-14 — Pass-through

An underlying-to-underlying `exchangeIn` is a pass-through. It mints no shares and takes no usage fee. It refunds input the swap does not spend. It does not rebalance. `minAmountOut` binds the swap output.

Copy of FS-OWN-25 and FS-OWN-32. Retires the trailing rebalance on the direct swap.

### V3-ACC-15 — Pool locked

While `pool.slot0().unlocked` is false, every execution route that must `swap`, `mint`, `burn`, or `collect` reverts `UniswapV3Exchange_BoundPoolInteractionBlocked`. It does not fall back to constant-product issuance, `_singleExit`, a local pay, or a V4 unlock. A preview of an adopted route returns the computed result, or zero if the route is unsupported. It does not revert merely because the pool is locked. `slot0.unlocked == true` means the V3 pool is idle. That polarity is not V4 `isUnlocked`.

Copy of the no-sleeve rule, expressed as a revert because a locked V3 pool cannot perform the copied actions. All four members recommend this for parity. Astra required the policy to be stated rather than inherited from FS-OWN-13. This sentence is that statement. Retaining a local-only route would be a different product, and this draft does not adopt it.

### V3-ACC-16 — Disable

A disabled vault reverts `VaultDisabled` on every execution route except a withdrawal, and except `donate` and `compound` if V3-OPEN-02 adopts them. A withdrawal is share in and underlying out. A pass-through is not a withdrawal. Views do not revert `VaultDisabled`. Vault-disabled and pool-locked are different gates.

Copy of FS-OWN-26.

### V3-ACC-17 — Manipulation limit

The 49% entry swap, the one-token exit swap, and a one-token maintenance swap are same-pool swaps. They do not solve swap-price manipulation. This PRD must not claim that they do. It adds no `maxZapTickMove`, no TWAP check, no tighter price limit, and no new fee cap on those swaps. A sandwich of an authorized maintenance swap can still sell booked fees or a booked remainder at a moved price. That exposure is accepted. It is not claimed absent. Hook LP ownership rules are not adopted. The FS-HOOK-06 sentence that swap use of a rated reserve is not a solved manipulation claim is adopted for these vault swaps.

Copy of FS-OWN-33, FS-OWN-14, and that one sentence of FS-HOOK-06. Not a new protection design.

### V3-ACC-18 — External preview

The external Standard Exchange rate provider keeps calling `previewExchangeIn`. This vault does not delete that call, does not replace either return word with NAV, and does not add `getRate()` or `rateAsset()`. `previewExchangeIn` keeps its current two-word return. For a share-minting route, the first word is the depositor's net shares. For a one-token exit, the first word is the V3-ACC-12 receipt. The second word is the refund. A mint preview is not the share valuation. The exit preview is the valuation of that operation and is not this vault's rate. The provider's current non-empty call prices `totalSupply` shares through the exit preview and ignores the refund word. Its empty-supply call inverts a one-unit mint preview. This vault does not change either call to keep the provider's old number. A full-book exit that cannot spend the opposing amount previews as a failed plan. The provider then reads a zero rate. The PRD states that outcome. It does not add a fallback rate.

Copy of FS-OWN-03, FS-OWN-08's existing tuple, and FS-OWN-29's refusal to add a vault rate, plus the brief's provider constraint. The stateful `quoteAssets` path is V3-OPEN-05.

### V3-ACC-19 — Consequence of the copied mint

Later mints use only new liquidity in the denominator. Outstanding shares, including the floor, still participate in later proportional fee and booked claims. A later mint can therefore reduce an old holder's booked claim per share even though the mint did not credit shares for those booked tokens. That is the copied FS-OWN-24/30 formula. This PRD does not add a stronger per-vintage claim. Astra named that stronger promise as a new design. This draft does not adopt it.

## Open decisions

The PRD must state each of these and must not answer it by omission. Silence is not a choice.

### V3-OPEN-01 — Position import

Position import is not decided. V4 has no import. If import remains, it must not price shares with `StandardExchangeConstantProduct`, must not mint the dead-sink floor, and must not rebalance a sleeve. The shares it mints must follow V3-ACC-02, V3-ACC-03, and V3-ACC-04. Imported pre-existing fees are booked, not credited as new principal. If import is removed, the only genesis path is the organic first add. This PRD does not choose which.

### V3-OPEN-02 — Donate and compound

Whether this vault adds `donate` and `compound` is not decided. Grok and Kimi treat the selectors as required by the copied dust rule. Astra and MiniMax treat adding the surface as a scope choice. If they are added, they follow FS-OWN-14, FS-OWN-21, and the donate/compound sentences of FS-OWN-33: one-token maintenance uses the 49% shape and books the remainder; both-token maintenance adds in proportion and does not swap; the caller is the live `feeTo()` owner, a global operator, or a function operator for that selector; user routes do not call them; there is no donation before the first mint. If they are not added, no user-deposit remainder is booked, and this PRD must say what, if anything, deploys accrued fees and booked remainders. Permissionless `rebalanceLiquidReserve` is not that answer.

### V3-OPEN-03 — Selector names

Selector names for the both-token routes are not decided. The accounting is V3-ACC-07 and V3-ACC-13. This PRD does not choose between keeping the V3 selectors with the new accounting and adding the V4 bundle selectors while retiring the old ones. It does not hide a refund inside a one-word many-to-one return.

### V3-OPEN-04 — Existing supply

Whether the accounting change applies only to newly deployed vaults, or also migrates existing supply, dead-sink shares, sleeve balances, unpaid fees, and imported positions, is not decided. No formula change silently reclassifies old local property or rescales existing balances. V4's genesis rule is not that migration.

### V3-OPEN-05 — Stateful quote and Standardized Yield

`quoteRate` with state calls `quoteAssets`, not `previewExchangeIn`. Deleting the transition quote would drop that consumer. Leaving the current inventory simulation would keep sleeve and constant-product math in a quote the provider can read. `exchangeRate()` currently publishes `sqrt(reserve0 * reserve1) * 1e18 / supply`. Leaving it publishes a valuation the adopted issuance no longer uses. Deleting the Standardized Yield package is wider than deposits, exits, dust, and share issuance. This PRD does not choose between withdrawing those surfaces and retaining a wrapper that calls only the new exact-input engine. Either way it does not add `getRate()`, does not substitute NAV, and does not remove the provider's `previewExchangeIn` call in V3-ACC-18.

### V3-OPEN-06 — Exact-out selector disposition

The economics of exact-out success are not V4 behavior. Grok and Kimi retire every exact-out success route as a copy of FS-OWN-19 and FS-HOOK-03: `previewExchangeOut` returns zero, enabled `exchangeOut` reverts `ExchangeOutNotAvailable()`, and the search, the constant-product inverse, and the exact-out mint do not remain as accounting paths. Astra and MiniMax require that retirement, or any retained exact-out route, be an express compatibility decision rather than a silent copy. This draft proposes Grok's fail-closed text as the parity rule and records that dissent. A retained exact-out route with the old economics is rejected. A retained exact-out route with new accounting would be a new product, and this draft does not specify one.

## Disagreement

- Usage fee: adopted as a V4 copy. MiniMax's open-list reservation is carried, not adopted.
- Donate and compound: not adopted as a lock. Split is recorded in V3-OPEN-02.
- Exact-out: economics of the old routes are rejected. Selector disposition is V3-OPEN-06, with a proposed fail-closed text and named dissent.
- Pool-locked local fallback: rejected by all four for parity. Adopted as V3-ACC-15.
- Import, migration, selector names, SY, and `quoteAssets`: left open. No member supplied a source that decides them.
- Booked-claim dilution: stated as a consequence. The stronger protection is not adopted.
- Kimi did not examine the optional V3 remediation PRD, pair-token tree, wings tree, or the rate-provider facet. The provider sentences above rely on the other three members and on the coordinator's earlier read of `StandardExchangeRateProviderFacet.sol`. That is a coverage limit, not a fourth vote.

None of the above is consensus. A missing concern in later feedback is not approval.

## Rejected alternatives

- Permissionless sleeve rebalance as the dust path.
- Local `x*y=k` settlement while the V3 pool is locked.
- A searched or closed-form input split, including `quadraticInput`.
- Keeping constant-product issuance so the rate provider's old number is unchanged.
- Adding vault `getRate()`, or replacing a preview word with NAV.
- A tighter swap cap, TWAP, or other manipulation control.
- Copying hook pair-token books or Hook LP entitlement into this vault.
- Requiring a V4 unlock on this vault.
- Minting the genesis floor to `address(0xdead)` or from token decimals.
- Treating a raw `collect` balance delta as the exiting holder's entire claim.

## Limits

- Static reading only. No test was run. No gas measurement is claimed.
- Live files can change. This draft is not an atomic snapshot.
- This draft does not authorize implementation, a vault edit, or a test.
- Advisory feedback has not happened. Post-review wording will be a coordinator revision, not member-approved text.
