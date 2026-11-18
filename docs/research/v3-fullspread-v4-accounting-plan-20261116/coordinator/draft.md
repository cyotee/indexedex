# Draft implementation plan

- Draft ID: draft-v3-fullspread-v4-accounting-plan-20261116-r1
- Run ID: v3-fullspread-v4-accounting-plan-20261116
- Profile: research
- Question: What ordered implementation and test plan must a later author follow so the Uniswap V3 full-spread Standard Exchange vault under `contracts/vaults/standard/exchange/protocols/uniswap/v3/` satisfies the locked PRD, including the owner locks that the empty position NFT is burned and that import may run after supply exists?
- Sources synthesized: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md
- This draft does not replace the locked PRD. It does not authorize implementation.

## What this draft adopts

All four responses read the same locked PRD and the same V4 gas sentence. None ran tests. The order below is a plan choice except where a later step cannot be true without an earlier one. A filename the PRD does not name is a plan choice. The behavior each step must satisfy is not.

Governed tree: `contracts/vaults/standard/exchange/protocols/uniswap/v3/`. V4 behavior source: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. Locked PRD: `docs/research/v3-fullspread-v4-accounting-prd-20261116/UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_PRD.md`.

## Disagreement carried

- Import execution return. Astra keeps `importPosition`'s one-word share return and widens only the preview. Kimi widens both returns to `(sharesOut, refund0, refund1)`. The PRD requires the preview to report net shares and both refunds, and requires execution to transfer both overages to `recipient`. It does not require the execution return to carry the refund words. This draft requires the preview widening and the transfer. Widening the execution return is a plan choice, not a requirement.
- Unnamed transition-quote selectors. The PRD removes `quoteAssets`. It does not name `quoteState`, `quoteTransition`, `quoteShareBalance`, `quoteTotalSupply`, `quoteExternalDeposit`, or `quoteExternalExchange`. MiniMax and Grok record removal as a plan choice under the V4-surface match, and keeping them as the other reading. This draft removes them. That removal is a plan choice. It is not permission to restore `quoteAssets`.
- `deployedReserve`. Grok recommends dropping it because V4 does not expose it. MiniMax's package test expects it if a minimal liquid-reserve interface is kept to stabilize the usage-fee key. This draft does not require `deployedReserve`. Keeping it, reporting position principal only, is a plan choice. It is not a share basis and not a sleeve target.
- Usage-fee type key. `vaultFeeTypeIds()` keys USAGE on the liquid-reserve interface id. Trimming that interface can change the key. MiniMax did not enumerate consumers outside the V3 tree. This draft's plan choice is to keep that lookup identity stable. Re-keying is the other reading, and it is not adopted until the author inventories every consumer. The required outcome is that `usageFeeOfVault` still resolves for a new vault. Do not silently change the configured fee.
- Storage file. Astra, Grok, and Kimi extend the existing repo. MiniMax allows a new ledger file and a distinct slot. This draft extends `UniswapV3FullSpreadStandardExchangeVaultRepo.sol` and keeps the existing slot string. A second file is the other reading. New vaults only make either safe. A migration of old storage is not authorized.
- Genesis floor call. MiniMax observed that the current Crane `ERC20Repo._mint` writes `balanceOf` without a zero-address check, and that the inspected V4 execution calls `ERC20Repo._mint(address(0), MIN_SHARES)`. The locked V3 sentence still says the write does not use `ERC20Repo._mint`. This draft follows that sentence. MiniMax's observation is carried. It is not permission to copy the V4 call.
- Test filenames and facet counts are plan choices in every response. This draft names concrete files so a later author has one list. Another grouping that preserves the dependencies and the selector homes is not a new requirement.

## Step 0. Fence

No file change. Satisfy V3-ACC-01, V3-OWN-04, and V3-OWN-05 before any edit.

- Edit only the governed tree, plus the tests named below. Do not edit `contracts/protocols/dexes/uniswap/v3/`.
- New vaults of this implementation only. Do not migrate supply, dead-sink shares, sleeve balances, unpaid fees, or imported positions. Do not repoint an existing deployment.
- Pool actions are `pool.swap`, `pool.mint`, `pool.burn`, and `pool.collect`, paid through the existing `uniswapV3MintCallback` and `uniswapV3SwapCallback`. Do not add `unlockCallback`. Do not call PoolManager unlock.
- Do not adopt native-currency substitution, hook LP formulas, or a vault `getRate`. Pool tokens remain `pool.token0()` and `pool.token1()`.
- Do not copy `ERC20Repo._mint(address(0), MIN_SHARES)`.
- Do not reopen import removal, empty-NFT retention, empty-vault-only import, sleeve rebalance as the dust path, local constant-product settlement while the pool is locked, `quadraticInput`, a searched split, a successful refund of a failed genesis plan, a dead-sink floor, or a NAV rate.

A package test fails if a newly deployed vault exposes `unlockCallback`, `getRate`, `exchangeRate`, `assetInfo`, `quoteAssets`, or `IStandardizedYield`.

## Step 1. Booked balances and the floor write

Files, plan choices: extend `UniswapV3FullSpreadStandardExchangeVaultRepo.sol`. Keep the existing position record and slot string. Add `uint256[2] booked` in pool-token order. An in-flight reservation may live beside it. Clear it before return. Do not index booked by address.

- V3-ACC-09. Account separately for deployed position liquidity, unpaid position fees, booked remainders, and unbooked ERC-20 balances. Booked and unbooked balances are not reserves. A user deposit, a withdrawal, and `exchangeIn` do not deploy the staying holders' booked balance.
- V3-ACC-03. On a successful first add, `balanceOf(address(0))` is 1,000 and that balance is in `totalSupply()`. The write does not revert. It does not use `ERC20Repo._mint`, `ERC20Repo._increaseBalanceOf`, or the shared ERC-20 facet path. The helper name is a plan choice. The balance and the non-revert are not. `grossShares` is `addedLiquidity - 1,000`. The floor is not part of `grossShares` and is not a fee mint. Do not mint to `address(0xdead)`, from `decimals()`, or as residual unlike-token weight.

Tests that fail if this is wrong: after the first successful add, `balanceOf(address(0))` is 1,000 and `totalSupply` includes it. A direct transfer does not increase `reserves()` and is not a later caller's credit. A booked remainder is absent from `reserves()` and is not spent by the next user share mint.

## Step 2. One sizing engine

Files, plan choices: add `UniswapV3FullSpreadStandardExchangeVaultMath.sol` and `UniswapV3FullSpreadStandardExchangeVaultPlanner.sol`. Call that planner from preview and execution. Do not keep a second economics path in the CREATE3 delegates. Those delegates may remain only as a bytecode-size split. Do not edit `StandardExchangeConstantProduct`. Do not add `quadraticInput`.

This step is a dependency for steps 4, 7, and 8.

- V3-ACC-02 and V3-ACC-20. On an existing supply, `grossShares = floor(addedLiquidity * totalSupply / existingLiquidity)`, read before the add. Idle, booked, and accrued fees are not in that denominator. Liquidity removed is `floor(positionLiquidity * sharesBurned / supplyBeforeBurn)`. A later mint may reduce an old holder's booked claim per share. Do not add a per-vintage guarantee.
- V3-ACC-03. The first add must exceed 1,000 or the plan fails with `MinLiquidityNotMet()` and mints nothing. A first deposit whose 49% swap cannot be formed, or whose output the add cannot consume, uses that revert. It is not a successful whole-input refund.
- V3-ACC-04. Take the usage fee from `grossShares`. Do not mint it on top. Clamp a fee above `3e17` to `3e17` without writing the oracle. Skip a zero mint and a zero `feeTo`. Previews and minima use net shares. A pass-through takes no fee. There is no exit fee.
- V3-ACC-05 and V3-ACC-18. Inside the position, with supply already positive, run one exact-input `pool.swap` of `floor(processedInput * 49 / 100)` at `TickMath.MIN_SQRT_RATIO + 1` or `TickMath.MAX_SQRT_RATIO - 1`, then `pool.mint` of the liquidity whose rounded-up amounts consume that entire output and no more than the unswapped input. Do not iterate, solve a root, or walk ticks to choose a better split. Do not add `maxZapTickMove`, a TWAP check, or a tighter price limit. A quote may cross ticks to simulate that fixed swap. If the swap amount is zero, cannot be quoted, is not fully spent, receives zero output, or the mint cannot consume the output, refund the whole processed input, execute no swap, and mint nothing. A positive minimum on that no-mint result reverts `AmountOutNotMet`.
- V3-ACC-06. At or outside either boundary, do not swap. Add only the token the position wants. Refund the other. Zero active pool liquidity, with supply already positive and the price inside, refunds the whole input. That refund does not override a wanted-token boundary add or genesis.
- V3-ACC-07. A both-token deposit adds the greatest proportional liquidity the declared amounts support and refunds each unused token. It does not swap.
- V3-ACC-11. Before every share-minting add, snapshot and collect fees attributable to liquidity that already exists, including by `burn(0)` and `collect` when that is what moves them. Book the collected amounts. Do not infer them from a mint-callback delta. Do not include them in the add or the share credit. On a one-sided mint, collect after the entry swap and before the mint, so fees the swap earned for existing liquidity are booked too. On exit, read collectable fees before the burn. The caller's fee claim is `floor(collectableFees * sharesBurned / supplyBeforeBurn)`. The booked claim is `floor(booked * sharesBurned / supplyBeforeBurn)`. After burn and collect, split by that pre-burn read. Count a fee once.
- V3-ACC-01. One position. Ticks are `TickMath.minUsableTick` and `TickMath.maxUsableTick` at the bound pool's tick spacing, fixed before the first add.

Tests that fail if this is wrong: a first add of exactly 1,000 liquidity reverts and does not refund as success. A later interior mint swaps 49% once. A boundary wanted-token add does not swap. A both-token add does not swap and refunds unused input. Fee shares come out of `grossShares`. A mint after accrued fees does not credit those fees to the new depositor. An exit pays the floored fee and booked claims and does not pay the same fee again from a balance delta.

## Step 3. Callbacks must not spend booked balances

Files: `UniswapV3FullSpreadStandardExchangeVaultCommon.sol` and the facet that already installs the two callbacks. Which facet holds them is a plan choice. They must remain.

- V3-ACC-01. The bound pool is the callback caller. Pay the amount the pool asks for.
- V3-ACC-09. Size the operation, or reserve its spendable amount, so the callback transfer does not need booked tokens. Moving booked tokens to another contract is not authorized.
- V3-ACC-08. Retire `_collectIfIdle` before share math, both rebalance helpers, and `LocalDepositWhileBlocked`.

Tests that fail if this is wrong: a booked remainder is unchanged by a later user mint except for that caller's own exit claim. A foreign callback reverts. The cut contains the two V3 callbacks and does not contain `unlockCallback`.

## Step 4. One-token routes, funding, exits, and pass-through

Files: `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol`, `UniswapV3FullSpreadStandardExchangeVaultInBase.sol`, and the facet that installs `previewExchangeIn`. Today that preview is on the in-multi query facet. If step 6 removes that facet, move `previewExchangeIn` once. Its home is a plan choice. Losing the selector is not. Do not stuff the new bundle selectors into this facet.

- V3-ACC-10. On a route that takes `deadline`, a missed deadline reverts before disable. On a pull, pull the declared amount from `msg.sender` and refund unkept input to `msg.sender`. Pay shares or exit output to `recipient`. On a one-token pretransfer within unbooked credit, use at most the declared maximum and refund maximum minus used. If the maximum exceeds unbooked credit, spend none and pull no shortfall. On an empty vault, that call reverts `MinLiquidityNotMet()`. On an existing supply, refund the entire unbooked balance. A positive minimum on a zero output reverts `AmountOutNotMet`. A bundle over-maximum on either leg reverts before either leg. Do not compute credit from the old free-balance snapshot.
- V3-ACC-16. After the deadline check, a disabled vault reverts `VaultDisabled` on every execution route except a withdrawal, `donate`, and `compound`. A withdrawal is share in and underlying out. A pass-through is not a withdrawal. Views do not revert `VaultDisabled`. Reading V3-ACC-16, `setOperator` and `setOperatorFor` are not in that exception list, so a disabled vault reverts `VaultDisabled` on them. That is an application of the locked sentence, not a new exception.
- V3-ACC-15. While `pool.slot0().unlocked` is false, every execution route that must swap, mint, burn, or collect reverts `UniswapV3Exchange_BoundPoolInteractionBlocked`. `true` means the pool is idle. Do not fall back to constant-product issuance, a local pay, or an unlock. A preview returns the computed result, or zero if the route is unsupported. It does not revert merely because the pool is locked.
- V3-ACC-12. A one-token exit burns shares the caller holds. Shares parked on the vault are not burn credit. Quote the opposing swap after the planned liquidity removal. If that swap cannot spend the entire opposing claim, execution reverts `AmountOutNotMet` and does not burn. The preview of that failed plan returns a zero first word and does not revert. A completable preview's first word equals the receipt execution pays. `minAmountOut` binds the full receipt.
- V3-ACC-14. An underlying-to-underlying `exchangeIn` is a pass-through. It mints no shares, takes no fee, refunds unspent input, and does not rebalance. `minAmountOut` binds the swap output.
- V3-ACC-19. `previewExchangeIn` keeps its two-word return. Word one is net shares, the exit receipt, or zero. Word two is the refund. A preview of a refund need not equal the execution refund. That does not waive the exit receipt match.

Tests that fail if this is wrong: the refund word is not hardcoded to zero. An oversized empty-vault pretransfer reverts `MinLiquidityNotMet`. An incomplete opposing exit does not burn, and its preview returns zero. A locked-pool execution reverts and its preview does not. A pass-through mints nothing. The external provider still calls `previewExchangeIn`. A non-empty unspendable exit and an empty-supply mint that would not clear the floor read a zero rate. No test adds a fallback rate.

## Step 5. Fail-closed exact-out and the removed yield surface

Files: the out execute and out query targets, the yield execution target, and the package interface list. Deleting an unreachable file versus leaving it uninstalled is a plan choice. The surface must be gone from the new package.

- V3-ACC-17. `previewExchangeOut` returns zero and does not revert with a vault error, including when the pool is locked. Enabled `exchangeOut` reverts `ExchangeOutNotAvailable()` and moves no tokens. Disabled `exchangeOut` reverts `VaultDisabled`. Neither selector gains a refund word.
- V3-OWN-05. Do not implement `IStandardizedYield`, `exchangeRate()`, `assetInfo()`, `quoteAssets`, or a named vault-held share redemption. Do not add `getRate()`. Keep `previewExchangeIn`.
- Plan choice, stated above: also remove the unnamed transition-quote selectors. Do not restore `quoteAssets` to keep a consumer compiling.

Tests that fail if this is wrong: enabled and disabled `exchangeOut` use the errors above and move no tokens. `supportsInterface` for `IStandardizedYield` is false. `exchangeRate`, `assetInfo`, `quoteAssets`, and `getRate` are absent. A share balance sitting on the vault is not the caller's exit credit.

## Step 6. Reserves, package cut, and the fee-type key

Files: the package interface, `UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol`, `UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol`, and `test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol`. New query facet and target names are a plan choice.

- V3-ACC-09. Install family `reserves()` and `reserveOfToken`. They report deployed token amounts plus unpaid position fees. They do not add a free-balance term, a booked term, or the last `_syncVaultReserves` snapshot. An unknown token returns zero. Stop using that snapshot as the economic reserve or the pretransfer-credit source.
- Plan choice: install only `vaultTokens` from the basic-vault facet, matching the V4 package pattern, so the old basic reserve selectors cannot shadow the family query.
- V3-ACC-08. Remove `localReserve`, the liquid-percentage views, `rebalanceLiquidReserve`, and their events from the new cut. Keep `canOpenBoundPoolOps` as the pool-lock gate only.
- Plan choice: keep the existing USAGE fee-type lookup identity stable. Inventory consumers of the liquid-reserve interface id before any re-key. `usageFeeOfVault` must still resolve. Do not change the oracle default while removing selectors.
- V3-OWN-04. Version component salts only if a new package would otherwise resolve to already deployed old bytecode. Do not upgrade or recut an existing vault.

Tests that fail if this is wrong: a booked donation does not raise `reserves()`. Unpaid fees do, until they are booked. `rebalanceLiquidReserve` is absent. `usageFeeOfVault` resolves without a liquid-reserve setting. A new package's loupe matches the intended cut, and `previewExchangeIn` is present once.

## Step 7. New facets for the additional selectors

Files, plan choices, new under the governed tree. The split into these groups is a plan choice. Putting the selectors on new facets, and not on the existing one-token facets, is not.

- Bundle execution: `exchangeBundleInForSingleOut`, `exchangeBundleOut`.
- Bundle query: `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`.
- Maintenance: `donate`, `compound`, `setOperator`, `setOperatorFor`.

Argument meanings and return words are the V4 meanings: bundle deposit returns one share amount and a refund word for each input; bundle exit takes an exact share amount and a minimum for each output token. A requested exact output is not silently a minimum. A maximum share input is not silently an exact share burn. Use the V4 bundle errors already named beside those selectors. Do not declare a new bundle over-max error.

- V3-ACC-07 and V3-ACC-13. Bundle in is step 2's proportional add. Bundle out pays the V3-ACC-12 claim in both tokens and does not swap. Shares burned are the caller's exact-in amount.
- V3-OWN-02. `donate` and `compound` follow FS-OWN-14, FS-OWN-21, and the donate and compound sentences of FS-OWN-33. The caller is the live `feeTo()` owner, a global operator, or a function operator for that selector. Only the live owner appoints operators. User routes do not call them. There is no donation before the first mint. One-token maintenance uses the 49% shape and books the remainder. Both-token maintenance adds in proportion and does not swap. An unformable sizing books the input and does not swap. A real processing failure reverts. Empty `compound` is a no-op even if an unrelated unbooked transfer exists. After a qualifying maintenance operation, book actual held balances, including stray custody. That booking is not a user refund. Emit `Donation()` on successful donation, including a no-add result. Emit `Compounded()` only when a deposit uses collected fees or booked tokens. A share donation burns caller-owned shares and does not withdraw that liquidity.
- V3-ACC-16. Maintenance remains available while the vault is disabled, and still cannot operate a locked pool.

Tests that fail if this is wrong: none of the eight selectors is served by the existing one-token facets. A both-token deposit does not swap. A bundle exit does not swap and does not invert token amounts into a share burn. A stranger cannot donate. A donation before the first mint reverts. A user route does not deploy booked dust. Empty compound emits nothing. Booked dust stays out of reserves until a later authorized deploy.

## Step 8. Import

Dependency: steps 2 and 4 are settled. Import calls that proportional-add path. It does not keep a second issuance implementation.

Files: `UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol` and its facet. Plan choice: widen `previewImportPosition` to `(sharesOut, refund0, refund1)` in pool-token order. The selector can stay the same. Selector or ERC-165 checks alone do not prove the ABI change. Widening `importPosition`'s return is a plan choice. Transferring both refunds to `recipient` is not.

- V3-OWN-01. Remove the nonzero-supply and already-created prohibition. Import may run after supply exists. It does not replace the existing position and does not reset supply. Preserve owner or approval, matching pool, nonzero source liquidity, deadline, and non-reentrancy.
- Collect every token the NFT yields: both tokens' principal and the fees collected from that position. Those amounts are the importer's both-token deposit under V3-ACC-07. Destination-position fees, if any, are collected and booked under V3-ACC-11 before the importer's amounts are measured. They are not incoming import credit.
- Refund each unused token to `recipient`, including when owner, caller, and recipient differ. Mint net shares under V3-ACC-02, V3-ACC-03, and V3-ACC-04. The genesis floor applies only when this import is the first liquidity.
- After the tokens are collected, burn the empty position NFT. Do not leave it on the vault and do not return it to the owner. Burn only after liquidity and owed amounts are zero, as the position manager requires. A later failure reverts the burn with the transaction. A failed genesis plan reverts `MinLiquidityNotMet` and leaves the NFT with its owner.
- The preview reports net shares and both refunds from the same planner. It does not transfer.
- Do not use `StandardExchangeConstantProduct`, the dead-sink floor, or a sleeve rebalance.

Tests that fail if this is wrong: rewrite `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_Import.t.sol`. A second import succeeds and does not reset supply. The position manager burn is observable, and `ownerOf` reverts afterward. Source fees increase the importer's input. Destination fees do not. Both refunds arrive at `recipient`. The floor is minted only on the first liquidity. A failed genesis rolls the NFT back to its owner. Keep the wrong-pool, zero-liquidity, unauthorized, and deadline negatives. Update the full-range book suite so it no longer calls `rebalanceLiquidReserve` or expects the empty NFT to remain.

## Step 9. Gates, provider, and migrated suites

- Exercise the real external Standard Exchange provider with this vault. A non-empty route quotes `totalSupply` shares through `previewExchangeIn` and ignores the refund word. An empty route inverts a one-unit mint preview. Do not add a vault rate to preserve an old number. A consumer that still calls `quoteAssets` is incompatible. Do not restore that selector.
- Update the existing release-v3 suites whose assertions encode retired economics: exact-out success, vault-held redemption, local-book reserves, sleeve rebalance after import, and the one-word import preview. Replace those assertions with the cited PRD behavior. Do not delete or skip a failing test to go green. Tests of `contracts/protocols/dexes/uniswap/v3/` keep their own behavior.
- Run `forge build --use solar` before `forge test --use solar`, because FactoryServices read `out/`. Do not use `via_ir`. Do not mock, etch, or storage-inject the vault, the package, the pool, or the position manager.

## Step 10. Gas

Authority: the V4 implementation plan, section 2, which states ceilings of 12,000,000 and 5,000,000, and a cold standalone public money or maintenance body of at most 11,900,000. All four responses verified that sentence. It is not a different ceiling. Applying the same bar to import is a plan choice required to cover V3's extra route. It is not a higher allowance.

Measure, cold, with fixture setup outside the body and no warming preview: one-sided mint, one-token exit, pass-through, bundle in, bundle out, `donate`, `compound`, genesis import, and later import. Measure `previewExchangeIn` for mint, exit, and pass-through, both bundle previews, and `previewImportPosition`. Each preview is at most 5,000,000. Each standalone body is at most 11,900,000. A composed consumer, if one is later claimed, must fit 12,000,000 for the whole transaction. An oversized route is unresolved. Do not raise a ceiling, omit later import, or add `getRate` to obtain a pass.

## Requirement check

| Locked row | Steps |
| --- | --- |
| V3-ACC-01 | 0, 2, 3 |
| V3-ACC-02, V3-ACC-03, V3-ACC-04 | 1, 2, 4, 8 |
| V3-ACC-05, V3-ACC-06 | 2, 4, 7 |
| V3-ACC-07 | 2, 7, 8 |
| V3-ACC-08, V3-ACC-09 | 1, 3, 6 |
| V3-ACC-10 | 4, 7, 8 |
| V3-ACC-11, V3-ACC-12, V3-ACC-13 | 2, 4, 7, 8 |
| V3-ACC-14 | 4 |
| V3-ACC-15, V3-ACC-16, V3-ACC-17 | 4, 5, 7 |
| V3-ACC-18 | 2 |
| V3-ACC-19 | 4, 5, 9 |
| V3-ACC-20 | 2, 9 |
| V3-OWN-01 | 8, 10 |
| V3-OWN-02 | 7, 10 |
| V3-OWN-03 | 6, 7 |
| V3-OWN-04 | 0, 6 |
| V3-OWN-05 | 0, 5, 9 |

## Limits

This draft is a synthesis of four independent research responses. It is not a vote, a code review, or implementation authority. No test, build, or gas measurement was run for this draft. Live files can change before a later author edits. The author must re-read the locked PRD and the named sources before editing.
