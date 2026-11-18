# Uniswap V3 full-spread V4-accounting implementation and test plan

- Run ID: v3-fullspread-v4-accounting-plan-20261116
- Question: What ordered implementation and test plan must a later author follow so the Uniswap V3 full-spread Standard Exchange vault under `contracts/vaults/standard/exchange/protocols/uniswap/v3/` satisfies the locked PRD, including the owner locks that the empty position NFT is burned and that import may run after supply exists?
- Authority: `docs/research/v3-fullspread-v4-accounting-prd-20261116/UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_PRD.md`
- Reviewed draft: `coordinator/draft.md`, ID `draft-v3-fullspread-v4-accounting-plan-20261116-r1`, SHA-256 `f8265634984958df9eb1e22716527ae6be06c7b5505ab571ddbe1fa0d2026314`. That file was not edited after review.
- Advisory outcome: all four members returned `requested-changes`. The accepted corrections are in `coordinator/resolution.md`.
- This plan does not replace the locked PRD. It does not authorize implementation.

## How to read a plan choice

The order is a plan choice except where a later step cannot be true without an earlier one. A filename the PRD does not name is a plan choice. The behavior each step must satisfy is not. Another file grouping that preserves the dependencies, the selector homes, and the gates in this plan is not a new requirement.

Governed tree: `contracts/vaults/standard/exchange/protocols/uniswap/v3/`.

## Disagreement carried

- Import execution return. The preview must report net shares and both refunds. Execution must transfer both overages to `recipient`. Widening `importPosition`'s return is a plan choice, not a requirement.
- Unnamed transition-quote selectors. This plan removes `quoteState`, `quoteTransition`, `quoteShareBalance`, `quoteTotalSupply`, `quoteExternalDeposit`, and `quoteExternalExchange`. That removal is a plan choice. It is not permission to restore `quoteAssets`.
- `deployedReserve`. This plan does not require it. Keeping it, reporting position principal only, is a plan choice. It is not a share basis and not a sleeve target.
- Usage-fee type key. Keep the existing USAGE lookup identity stable. Re-keying is not adopted until every consumer of the liquid-reserve interface id is inventoried. `usageFeeOfVault` must still resolve. Do not change the configured fee while removing selectors.
- Storage file. Extend `UniswapV3FullSpreadStandardExchangeVaultRepo.sol` and keep the existing slot string. A second ledger file is the other reading. Do not migrate old storage.
- Genesis floor call. Do not call `ERC20Repo._mint`, including the inspected V4 call `ERC20Repo._mint(address(0), MIN_SHARES)`. The current Crane implementation's lack of a zero-address check does not lift that sentence.
- Appointment disable. `setOperator` and `setOperatorFor` are not named by V3-ACC-16. Treating them as execution routes that revert `VaultDisabled` is a plan choice. The other reading, that they are administrative and ignore disable, is not adopted. Do not describe that revert as a locked requirement.

## Step 0. Fence

No production edit yet. Satisfy V3-ACC-01, V3-OWN-04, and V3-OWN-05 before any edit.

- Edit only the governed tree and the test paths named in Step 9. Do not edit `contracts/protocols/dexes/uniswap/v3/`.
- New vaults of this implementation only. Do not migrate supply, dead-sink shares, sleeve balances, unpaid fees, or imported positions. Do not repoint an existing deployment.
- Pool actions are `pool.swap`, `pool.mint`, `pool.burn`, and `pool.collect`, paid through the existing `uniswapV3MintCallback` and `uniswapV3SwapCallback`. Do not add `unlockCallback`.
- Do not adopt native-currency substitution, hook LP formulas, or a vault `getRate`. Pool tokens remain `pool.token0()` and `pool.token1()`.
- Do not reopen import removal, empty-NFT retention, empty-vault-only import, sleeve rebalance as the dust path, local constant-product settlement, `quadraticInput`, a searched split, a successful refund of a failed genesis plan, a dead-sink floor, or a NAV rate.

A package test fails if a newly deployed vault exposes `unlockCallback`, `getRate`, `exchangeRate`, `assetInfo`, `quoteAssets`, or `IStandardizedYield`.

## Step 1. Booked balances and the floor write

Files, plan choices: extend `UniswapV3FullSpreadStandardExchangeVaultRepo.sol`. Keep the existing position record and slot string. Add `uint256[2] booked` in pool-token order. An in-flight reservation may live beside it. Clear it before return.

- V3-ACC-09. Account separately for deployed position liquidity, unpaid position fees, booked remainders, and unbooked ERC-20 balances. Booked and unbooked balances are not reserves.
- V3-ACC-03. On a successful first add, `balanceOf(address(0))` is 1,000 and that balance is in `totalSupply()`. The write does not revert. It does not use `ERC20Repo._mint`, `ERC20Repo._increaseBalanceOf`, or the shared ERC-20 facet path. The helper name is a plan choice. `grossShares` is `addedLiquidity - 1,000`. The floor is not part of `grossShares` and is not a fee mint.

Callback budgets, which Step 3 must enforce:

- A user add and a pass-through cannot consume booked custody.
- An exit may reserve and spend only that caller's floored booked claim.
- Authorized `donate` or `compound` may reserve the eligible booked input defined in Step 7.
- An in-flight reservation is excluded from other available credit and is reconciled before return.

Tests that fail if this is wrong:

- After the first successful add, `balanceOf(address(0))` is 1,000 and `totalSupply` includes it.
- A direct share-token transfer creates no reserve and no liquidity credit.
- A direct pool-token transfer does not increase `reserves()` and does not become booked. It is unbooked credit. A later one-token pretransfer may use only that available credit under V3-ACC-10. An unrelated route cannot treat it as reserve-backed credit.
- A user add cannot spend another holder's booked tokens. An exit that funds its own floored booked claim succeeds. Authorized maintenance that deploys eligible booked input succeeds.

## Step 2. One sizing engine

Files, plan choices: add `UniswapV3FullSpreadStandardExchangeVaultMath.sol` and `UniswapV3FullSpreadStandardExchangeVaultPlanner.sol`. Preview and execution call that same planner. CREATE3 delegates may remain only as a bytecode-size split. They must not keep a second economics path. Do not edit `StandardExchangeConstantProduct`. Do not add `quadraticInput`.

This step is a dependency for steps 4, 7, and 8.

- V3-ACC-02 and V3-ACC-20. On an existing supply, `grossShares = floor(addedLiquidity * totalSupply / existingLiquidity)`, read before the add. Idle, booked, and accrued fees are not in that denominator. Liquidity removed is `floor(positionLiquidity * sharesBurned / supplyBeforeBurn)`. A later mint may reduce an old holder's booked claim per share. Do not add a per-vintage guarantee. Later fee and booked claims use the enlarged post-mint supply, and that supply includes the 1,000 floor.
- V3-ACC-03. The first add must exceed 1,000 or the plan fails with `MinLiquidityNotMet()` and mints nothing. A first deposit whose 49% swap cannot be formed, or whose output the add cannot consume, uses that revert. It is not a successful whole-input refund.
- V3-ACC-04. Take the usage fee from `grossShares`. Do not mint it on top. Clamp a fee above `3e17` to `3e17` without writing the oracle. Skip a zero mint and a zero `feeTo`. Previews and minima use net shares. A pass-through takes no fee. There is no exit fee.
- V3-ACC-05 and V3-ACC-18. Inside the position, with supply already positive, run one exact-input `pool.swap` of `floor(processedInput * 49 / 100)` at `TickMath.MIN_SQRT_RATIO + 1` or `TickMath.MAX_SQRT_RATIO - 1`, then `pool.mint` of the liquidity whose rounded-up amounts consume that entire output and no more than the unswapped input. Do not iterate, solve a root, or walk ticks to choose a better split. Do not add `maxZapTickMove`, a TWAP check, or a tighter price limit. A quote may cross ticks to simulate that fixed swap. If the swap amount is zero, cannot be quoted, is not fully spent, receives zero output, or the mint cannot consume the output, refund the whole processed input, execute no swap, and mint nothing. A positive minimum on that no-mint result reverts `AmountOutNotMet`.
- V3-ACC-06. At or outside either boundary, do not swap. Add only the token the position wants. Refund the other. Zero active pool liquidity, with supply already positive and the price inside, refunds the whole input. That refund does not override a wanted-token boundary add or genesis.
- V3-ACC-07. A both-token deposit adds the greatest proportional liquidity the declared amounts support and refunds each unused token. It does not swap.
- V3-ACC-11. Before every share-minting add, snapshot and collect fees attributable to liquidity that already exists, including by `burn(0)` and `collect` when that is what moves them. Book the collected amounts. Do not infer them from a mint-callback delta. On a one-sided mint, collect after the entry swap and before the mint. On exit, read collectable fees before the burn. The caller's fee claim is `floor(collectableFees * sharesBurned / supplyBeforeBurn)`. The booked claim is `floor(booked * sharesBurned / supplyBeforeBurn)`. After burn and collect, split by that pre-burn read. Count a fee once.
- V3-ACC-01. One position. Ticks are `TickMath.minUsableTick` and `TickMath.maxUsableTick` at the bound pool's tick spacing, fixed before the first add.

Tests that fail if this is wrong: a first add of exactly 1,000 liquidity reverts and does not refund as success. A later interior mint swaps 49% once. A boundary wanted-token add does not swap. A both-token add does not swap. Fee shares come out of `grossShares`. A mint after accrued fees does not credit those fees to the new depositor. An exit pays the floored claims and does not pay the same fee again from a balance delta. A later mint, then an old holder's exit, uses the enlarged supply including the floor: the per-share claim is smaller, and the absolute booked remainder of the staying holders is unchanged except for that exit's own claim. Entry and opposing-exit quotes across adjacent initialized dust ticks are fully spent, and preview and execution use that same sizing. Do not add a quote step cap to make those cases pass. Preview-versus-execution equality alone is not the economic proof. Expected amounts come from pre-state, the integer formulas, and observed token movements.

## Step 3. Callbacks must not spend another holder's booked balance

Files: `UniswapV3FullSpreadStandardExchangeVaultCommon.sol` and the facet that already installs the two callbacks. Which facet holds them is a plan choice. They must remain.

- V3-ACC-01. The bound pool is the callback caller. Pay the amount the pool asks for.
- Apply the three budgets in Step 1. Do not move booked tokens to another contract.
- V3-ACC-08. Retire `_collectIfIdle` before share math, both rebalance helpers, and `LocalDepositWhileBlocked`.

Tests that fail if this is wrong: a foreign callback reverts. The cut contains the two V3 callbacks and does not contain `unlockCallback`. The three budget cases in Step 1 pass.

## Step 4. One-token routes, funding, exits, and pass-through

Files: `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol`, `UniswapV3FullSpreadStandardExchangeVaultInBase.sol`, and the facet that installs `previewExchangeIn`. Today that preview is on the in-multi query facet. Move it exactly once, in Step 6, before that old facet is retired. Its new home is a plan choice. Losing the selector is not. Do not stuff the new bundle selectors into this facet.

- V3-ACC-10. On a route that takes `deadline`, a missed deadline reverts before disable. On a pull, pull the declared amount from `msg.sender` and refund unkept input to `msg.sender`. Pay shares or exit output to `recipient`. On a one-token pretransfer within unbooked credit, use at most the declared maximum and refund maximum minus used. If the maximum exceeds unbooked credit, spend none and pull no shortfall. On an empty vault, that call reverts `MinLiquidityNotMet()`. On an existing supply, refund the entire unbooked balance. A positive minimum on a zero output reverts `AmountOutNotMet`. A bundle over-maximum on either leg reverts before either leg. Do not compute credit from the old free-balance snapshot.
- V3-ACC-16. After the deadline check, a disabled vault reverts `VaultDisabled` on every execution route except a withdrawal, `donate`, and `compound`. A withdrawal is share in and underlying out. A pass-through is not a withdrawal. Views do not revert `VaultDisabled`.
- Plan choice, not a lock: `setOperator` and `setOperatorFor` revert `VaultDisabled` while the vault is disabled. They are not in the exception list, and this plan does not treat that absence as proof they are execution routes. The chosen behavior is the revert. Do not also implement the administrative reading.
- V3-ACC-15. While `pool.slot0().unlocked` is false, every execution route that must swap, mint, burn, or collect reverts `UniswapV3Exchange_BoundPoolInteractionBlocked`. The gate is the required pool action, not facet membership. `true` means the pool is idle. Do not fall back to constant-product issuance, a local pay, or an unlock. A preview returns the computed result, or zero if the route is unsupported. It does not revert merely because the pool is locked. Appointment selectors do not swap, mint, burn, or collect, so this gate does not apply to them.
- V3-ACC-12. A one-token exit burns shares the caller holds. Shares parked on the vault are not burn credit. Quote the opposing swap after the planned liquidity removal. If that swap cannot spend the entire opposing claim, execution reverts `AmountOutNotMet` and does not burn. The preview of that failed plan returns a zero first word and does not revert. A completable preview's first word equals the receipt execution pays. `minAmountOut` binds the full receipt.
- V3-ACC-14. An underlying-to-underlying `exchangeIn` is a pass-through. It mints no shares, takes no fee, refunds unspent input, and does not rebalance. `minAmountOut` binds the swap output.
- V3-ACC-19. `previewExchangeIn` keeps its two-word return. On a share-minting route, word one is net shares. On an exit, word one is the receipt, or zero when the opposing claim cannot be spent. On a pass-through, word one is the planned swap output and word two is the unspent-input refund. A zero first word is a failed or unsupported plan, not a successful pass-through. A preview of a refund need not equal the execution refund. That does not waive the exit receipt match or the pass-through output match.

Tests that fail if this is wrong: the refund word is not hardcoded to zero. An oversized empty-vault pretransfer reverts `MinLiquidityNotMet`. An incomplete opposing exit does not burn, and its preview returns zero. A locked-pool execution reverts and its preview does not. A pass-through mints nothing, and its preview word one equals the swap output execution pays. A disabled pass-through reverts `VaultDisabled`. A disabled share-in exit still pays. The external provider still calls `previewExchangeIn`. A non-empty unspendable exit and an empty-supply mint that would not clear the floor read a zero rate. No test adds a fallback rate.

## Step 5. Fail-closed exact-out and the removed yield surface

Files: the out execute and out query targets, the yield execution target, and the package interface list. Deleting an unreachable file versus leaving it uninstalled is a plan choice. The surface must be gone from the new package.

- V3-ACC-17. `previewExchangeOut` returns zero and does not revert with a vault error, including when the pool is locked. Enabled `exchangeOut` reverts `ExchangeOutNotAvailable()` and moves no tokens. Disabled `exchangeOut` reverts `VaultDisabled`. Neither selector gains a refund word. `exchangeOut` takes `deadline`. A missed deadline reverts before `VaultDisabled`. Do not replace `ExchangeOutNotAvailable` with the pool-lock error. This route does not touch the pool.
- V3-OWN-05. Do not implement `IStandardizedYield`, `exchangeRate()`, `assetInfo()`, `quoteAssets`, or a named vault-held share redemption. Do not add `getRate()`. Keep `previewExchangeIn`.
- Plan choice: also remove the unnamed transition-quote selectors. Do not restore `quoteAssets` to keep a consumer compiling.

Tests that fail if this is wrong: a missed deadline on `exchangeOut` reverts before `VaultDisabled`. Enabled and disabled `exchangeOut` use the errors above and move no tokens. `supportsInterface` for `IStandardizedYield` is false. `exchangeRate`, `assetInfo`, `quoteAssets`, and `getRate` are absent. A share balance sitting on the vault is not the caller's exit credit.

## Step 6. Reserves, package cut, and the fee-type key

Files: the package interface, `UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol`, `UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol`, and `contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol`. New query facet and target names are a plan choice.

- V3-ACC-09. Install family `reserves()` and `reserveOfToken`. They report deployed token amounts plus unpaid position fees. They do not add a free-balance term, a booked term, or the last `_syncVaultReserves` snapshot. An unknown token returns zero. Stop using that snapshot as the economic reserve or the pretransfer-credit source.
- Plan choice: install only `vaultTokens` from the basic-vault facet, so the old basic reserve selectors cannot shadow the family query.
- V3-ACC-08. Remove `localReserve`, the liquid-percentage views, `rebalanceLiquidReserve`, and their events from the new cut. Keep `canOpenBoundPoolOps` as the pool-lock gate only.
- Plan choice: remove the legacy many-to-one and one-to-many selector cuts. Do not keep them by reinterpreting a requested exact output as a minimum or a maximum share input as an exact burn. Move `previewExchangeIn` exactly once before retiring the facet that currently installs it. The package inventory must list every removed selector, not only the new ones.
- Plan choice: keep the existing USAGE fee-type lookup identity stable. Inventory consumers of the liquid-reserve interface id before any re-key. `usageFeeOfVault` must still resolve.
- V3-OWN-04. Version component salts only if a new package would otherwise resolve to already deployed old bytecode. Do not upgrade or recut an existing vault.

Tests that fail if this is wrong: a booked donation does not raise `reserves()`. Unpaid fees do, until they are booked. `rebalanceLiquidReserve` and the old multi-route selectors are absent. The eight new selectors are present and are not served by the existing one-token facets. `previewExchangeIn` is present once and still returns two words. `usageFeeOfVault` resolves without a liquid-reserve setting. A new package's loupe matches that inventory.

## Step 7. New facets for the additional selectors

Files, plan choices, new under the governed tree. The split into these groups is a plan choice. Putting the selectors on new facets, and not on the existing one-token facets, is not.

- Bundle execution: `exchangeBundleInForSingleOut`, `exchangeBundleOut`.
- Bundle query: `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`.
- Maintenance and appointment: `donate`, `compound`, `setOperator`, `setOperatorFor`. Sharing a facet does not give the appointment selectors the economic gates.

Argument meanings and return words are the V4 meanings. Bundle deposit returns one share amount and a refund word for each input. Bundle exit takes an exact share amount and a minimum for each output token. Use the V4 bundle errors already named beside those selectors. Do not declare a new bundle over-max error.

Bundle gates, separate from maintenance:

- Both bundle routes take `deadline`. A missed deadline reverts before disable.
- A disabled bundle deposit reverts `VaultDisabled`. A bundle exit is a withdrawal and remains available while disabled.
- Bundle execution that must mint, burn, or collect reverts `UniswapV3Exchange_BoundPoolInteractionBlocked` while the pool is locked. Bundle previews do not revert merely because the pool is locked.
- V3-ACC-07 and V3-ACC-13. Bundle in is the proportional add and does not swap. Bundle out pays the V3-ACC-12 claim in both tokens and does not swap. Shares burned are the caller's exact-in amount.

Maintenance:

- V3-OWN-02. The caller is the live `feeTo()` owner, a global operator, or a function operator for that selector. Only the live owner appoints operators. User routes do not call them. There is no donation before the first mint.
- Collect unpaid destination fees first. Form the eligible input from those collected fees, plus booked balances, plus the directed donation. Choose one-token or proportional processing from that combined budget, not from the donation alone. A token0 donation with token1 already booked is a both-token add and does not swap. One-token eligible input uses the 49% shape and books the remainder. Both-token eligible input adds in proportion and does not swap. Keep unrelated unbooked custody out of the initial eligible input.
- An unformable sizing books the eligible input and does not swap. A real processing failure reverts. After qualifying processing, book actual held balances, including stray custody that arrived during that operation. That booking is not a user refund. Empty `compound`, including when an unrelated unbooked transfer exists and no fee or booked remainder is eligible, is a no-op and emits nothing.
- An underlying donation mints no shares. A share donation burns caller-owned shares and does not withdraw that liquidity, then processes the eligible held tokens by the same rule.
- Emit `Donation()` on successful donation, including a no-add result. Emit `Compounded()` only when a deposit uses collected fees or booked tokens.
- `donate` and `compound` remain available while the vault is disabled. They still cannot swap, mint, burn, or collect while the pool is locked. Do not extend that disable exception to `setOperator` or `setOperatorFor`.

Tests that fail if this is wrong: a both-token deposit does not swap. A bundle exit does not swap and does not invert token amounts into a share burn. A disabled bundle deposit reverts `VaultDisabled`. A disabled bundle exit still pays. A missed bundle deadline reverts before disable. A locked-pool bundle execution reverts and its preview does not. A stranger cannot donate. A donation before the first mint reverts. A token0 donation with token1 already booked does not swap. Empty compound with only stray custody emits nothing and does not book that stray transfer. A qualifying maintenance operation books a stray transfer that arrives during processing. Underlying donation mints no shares. Disabled `setOperator` reverts `VaultDisabled`. Enabled appointment does not revert merely because the pool is locked.

## Step 8. Import

Dependency: steps 2 and 4 are settled. Import calls that proportional-add path. It does not keep a second issuance implementation.

Files: `UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol` and its facet. Plan choice: widen `previewImportPosition` to `(sharesOut, refund0, refund1)` in pool-token order. The selector can stay the same. A selector or ERC-165 check does not prove the ABI change. Widening `importPosition`'s return is a plan choice. Transferring both refunds to `recipient` is not.

- V3-OWN-01. Remove the nonzero-supply and already-created prohibition. Import may run after supply exists. It does not replace the existing position and does not reset supply. Preserve owner or approval, matching pool, deadline, and non-reentrancy. Do not preserve a nonzero-liquidity reject. V3-OWN-01 does not name one.
- If the NFT yields tokens, collect them. That includes a position with zero liquidity and nonzero tokens owed. Measure both tokens' principal and the fees collected from that position. Those amounts are the importer's both-token deposit under V3-ACC-07. Do not reject the NFT before collection. Do not add a new error for zero liquidity. After collection, a failed genesis plan reverts `MinLiquidityNotMet`. On an existing supply, a no-mint plan follows the positive-supply refund rule in Step 4. Keep the wrong-pool, unauthorized, and deadline negatives. Do not keep a zero-liquidity negative that skips collection.
- Destination-position fees, if any, are collected and booked under V3-ACC-11 before the importer's amounts are measured. They are not incoming import credit.
- Refund each unused token to `recipient`, including when owner, caller, and recipient differ. Mint net shares under V3-ACC-02, V3-ACC-03, and V3-ACC-04. The genesis floor applies only when this import is the first liquidity.
- After the tokens are collected, and only after liquidity and owed amounts are zero, burn the empty position NFT. Do not leave it on the vault and do not return it to the owner. A later failure reverts the burn with the transaction. A failed genesis plan leaves the NFT with its owner.
- The preview reports net shares and both refunds from the same planner. It does not transfer.
- Gates. A missed deadline reverts before `VaultDisabled`. A disabled import reverts `VaultDisabled`. Import is not a withdrawal, `donate`, or `compound`. Import execution that must mint reverts `UniswapV3Exchange_BoundPoolInteractionBlocked` while the pool is locked. The preview does not revert merely because the pool is locked.
- Do not use `StandardExchangeConstantProduct`, the dead-sink floor, or a sleeve rebalance.

Tests that fail if this is wrong: rewrite `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_Import.t.sol`. A second import succeeds and does not reset supply. The position manager burn is observable, and `ownerOf` reverts afterward. A zero-liquidity NFT with tokens owed is collected, not rejected before collection. Source fees increase the importer's input. Destination fees do not. Both refunds arrive at `recipient`. The floor is minted only on the first liquidity. A failed genesis rolls the NFT back to its owner, with no leftover burn, transfer, or supply change. A disabled import reverts `VaultDisabled`. A locked-pool import execution reverts and its preview does not. A missed deadline reverts before disable. Update the full-range book suite so it no longer calls `rebalanceLiquidReserve` or expects the empty NFT to remain.

## Step 9. Gates, provider, migrated suites, and named tests

Test destinations are plan choices. Step 0's fence includes these paths and no others outside the governed tree:

- `contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_Import.t.sol`
- the release-v3 suites that currently encode exact-out success, vault-held redemption, local-book reserves, and sleeve rebalance after import
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/Package.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/Accounting.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/Money.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/QuotesAndRate.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/Maintenance.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/PoolLocked.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/Invariants.t.sol`
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/Gas.t.sol`

Deploy the vault through the real manager and registry. Use a real pool and a real position manager. Do not mock, etch, or storage-inject the vault, the package, the pool, or the position manager.

- Exercise the real external Standard Exchange provider. A non-empty route quotes `totalSupply` shares through `previewExchangeIn` and ignores the refund word. An empty route inverts a one-unit mint preview. Do not add a vault rate to preserve an old number. A consumer that still calls `quoteAssets` is incompatible. Do not restore that selector.
- Replace retired assertions with the cited PRD behavior. Do not delete or skip a failing test to go green. Tests of `contracts/protocols/dexes/uniswap/v3/` keep their own behavior.
- The invariant sequence uses more than one holder and covers organic genesis, a stray pool-token transfer, accrued fees, a later mint, a later import, maintenance, a partial exit, and a final ordinary-holder exit. Include a tiny burn whose liquidity rounds to zero while the fee or booked claim does not. Include the later-mint dilution case from Step 2. Include complete failed-import rollback.
- Run `forge build --use solar` before `forge test --use solar`, because FactoryServices read `out/`. Do not use `via_ir`.

## Step 10. Gas

Authority: the V4 implementation plan, section 2. Ceilings are 12,000,000 for a transaction and 5,000,000 for a preview. A cold standalone public money or maintenance body is at most 11,900,000. Applying the same bar to import is a plan choice required to cover V3's extra route. It is not a higher allowance.

Measure cold, with fixture setup outside the body and no warming preview. One favorable state is not enough. For each economic route record the state, direction, funding mode, cold-call method, body gas, transaction gas where claimed, preview gas where applicable, and pass or unresolved.

Required matrix:

- First and later one-sided mints, both token directions, pull and pretransfer.
- One-token exits, including a fee-and-booked-heavy exit, and a pass-through.
- Bundle in with a proportional refund, and bundle out.
- One-token and both-token `donate` and `compound`, plus empty compound.
- Genesis import and later import, including the NFT transfer, decrease, collect, and burn inside the measured body.
- A dust-tick path with initialized adjacent ticks and a substantial tick crossing, for both a money route and its preview.
- Cold `previewExchangeIn` for mint, exit, and pass-through; both bundle previews; `previewImportPosition`; and `previewExchangeOut`. Each preview is at most 5,000,000. `previewExchangeOut` returning zero without a vault error is a behavior assertion. Its gas measurement is additional.

Each standalone body is at most 11,900,000. A composed consumer, if one is later claimed, must fit 12,000,000 for the whole transaction. An oversized route is unresolved. Do not raise a ceiling, omit later import, treat a revert as a successful measurement, add a quote cap, or add `getRate` to obtain a pass.

## Requirement check

| Locked row | Steps |
| --- | --- |
| V3-ACC-01 | 0, 2, 3 |
| V3-ACC-02, V3-ACC-03, V3-ACC-04 | 1, 2, 4, 8 |
| V3-ACC-05, V3-ACC-06 | 2, 4, 7 |
| V3-ACC-07 | 2, 7, 8 |
| V3-ACC-08, V3-ACC-09 | 1, 3, 6 |
| V3-ACC-10 | 1, 4, 7, 8 |
| V3-ACC-11, V3-ACC-12, V3-ACC-13 | 2, 4, 7, 8 |
| V3-ACC-14 | 4 |
| V3-ACC-15, V3-ACC-16 | 4, 5, 7, 8 |
| V3-ACC-17 | 5 |
| V3-ACC-18 | 2, 10 |
| V3-ACC-19 | 4, 5, 9 |
| V3-ACC-20 | 2, 9 |
| V3-OWN-01 | 8, 10 |
| V3-OWN-02 | 7, 10 |
| V3-OWN-03 | 6, 7 |
| V3-OWN-04 | 0, 6 |
| V3-OWN-05 | 0, 5, 9 |

## Limits

This plan is the council's admitted final. It is not implementation authority. No test, build, or gas measurement was run for it. Live files can change before a later author edits. That author must re-read the locked PRD and the named sources before editing.
