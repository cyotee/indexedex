# Identity

- Member: `kimi`
- Profile: research
- Phase: initial independent response
- Requested role: `council-member`
- Requested model: `kimi-coding/k3.1-pro:high`, global route
- Actual Native runtime identity and session ID: not exposed
- Task ID: not exposed; none invented
- Owned artifact: `docs/research/v3-fullspread-v4-accounting-plan-20261116/members/kimi/response.md`

# Question and targets

What ordered implementation and test plan must a later author follow so the Uniswap V3 full-spread Standard Exchange vault under `contracts/vaults/standard/exchange/protocols/uniswap/v3/` satisfies the locked V4-accounting PRD, including the locks that import remains available after supply exists and that the emptied source position NFT is burned?

Required targets:

- `docs/research/v3-fullspread-v4-accounting-prd-20261116/UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_PRD.md`, especially V3-ACC-01 through V3-ACC-20 and V3-OWN-01 through V3-OWN-05.
- The governed V3 vault under `contracts/vaults/standard/exchange/protocols/uniswap/v3/`.
- The V4 behavior source and its implementation/test plan under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.

This is a research contribution. It does not authorize implementation, tests, deployment, or edits to the locked PRD.

# Evidence

## Observations

1. **The PRD fixes the economic basis and the exceptions to a V4 copy.** V3-ACC-02 makes raw position liquidity the share basis; V3-ACC-03 fixes a raw 1,000-liquidity genesis floor and a 1,000-share balance at `address(0)`; V3-ACC-04 takes usage fees out of gross shares; V3-ACC-05 fixes the one-sided entry at one 49% exact-input swap; V3-ACC-11 and V3-ACC-12 define pre-burn fee and booked claims. V3-OWN-01 keeps import, permits it with existing supply, treats all collected NFT principal and source fees as the importer's both-token input, pays both overages to `recipient`, and burns the empty NFT. V3-OWN-03 puts the eight additional V4 selectors on new facets. V3-OWN-04 restricts the change to new vaults. V3-OWN-05 removes Standardized Yield, `exchangeRate`, `assetInfo`, `quoteAssets`, and vault `getRate`, while V3-ACC-19 keeps two-word `previewExchangeIn`.

2. **Current V3 issuance and custody are the retired model.** In `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol`, `_sharesOutForDeposit` delegates to `StandardExchangeConstantProduct`, `_minimumLiquidity` is token-dependent, `_initialResidualShares` creates extra genesis weight, reserves include free balances, and the file contains sleeve rebalancing and exact-out helpers. `UniswapV3FullSpreadStandardExchangeVaultInBase.sol` mints to `DEAD_SHARES_SINK`, performs no 49% entry swap, pays exits from the free book, and rebalances after operations. `UniswapV3FullSpreadStandardExchangeVaultOutBase.sol`, `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol`, and `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol` implement exact-out searches and exact-out mints.

3. **Current V3 share delivery is not the required caller burn.** `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol` pulls shares onto the vault before the execution delegate burns them. `UniswapV3FullSpreadStandardYieldExecutionTarget.sol` also exposes named Standardized Yield redemption. The locked route instead burns shares held by the caller and gives no exit credit for shares merely parked at the vault.

4. **Current import has both owner-lock violations.** `UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol` rejects import when supply is nonzero or a position already exists, uses constant-product genesis issuance, retains the empty NFT at the vault, and calls sleeve rebalancing. Its preview returns one word. The same file already has the necessary owner/approval, matching-pool, deadline, non-reentrancy, full-decrease, and maximal-collect structure to retain.

5. **The package currently installs the retired surfaces.** `UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol` installs 15 cuts, including old multi routes, liquid-reserve routes, transition/frozen quotes, and Standardized Yield. Its basic-vault cut installs the whole supplied facet. `IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol` and `UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol` carry those facets and both execution delegates. `UniswapV3FullSpreadStandardExchangeVaultInMultiQueryTarget.sol` currently hardcodes the `previewExchangeIn` refund word to zero. `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol` exposes `assetInfo` and `exchangeRate`.

6. **The V4 implementation supplies the accounting sequence, not V3 pool mechanics.** In `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol`, one planner handles mint, bundle, exit, pass-through, and maintenance. Its `_shares` applies the floor and fee, `_size` applies the fixed 49% rule and strict interior test, and `_exit` quotes after liquidity removal. `UniswapV4FullSpreadStandardExchangeVaultExecution.sol` funds before execution, books pre-add fees, mints floor/fee/net shares, pays refunds to the payer, burns the caller's shares, and books only staying-holder fee remainders. `UniswapV4FullSpreadStandardExchangeVaultMath.sol` distinguishes rounded-up amounts payable from rounded-down claims and contains the one-sided output-fitting calculation. The V3 plan must not copy its `quadraticInput`, PoolManager settlement, native currency handling, or unlock paths.

7. **Existing V3 dependencies expose the needed completion and rounding evidence.** `lib/crane/contracts/utils/math/UniswapV3Quoter.sol` returns `amountIn`, `amountOut`, post-swap price/liquidity, and `fullyFilled`, and supports an exact-input quote after a position liquidity change. Thus a V3 planner can reject a partially spent 49% entry or opposing exit claim and can quote the exit against post-burn state. `lib/crane/contracts/utils/math/UniswapV3Utils.sol` exposes `SqrtPriceMath` amount deltas with an explicit round-up flag as well as liquidity-for-amounts helpers. Execution can therefore use rounded-up mint requirements rather than treating rounded-down reserve amounts as pool payment amounts.

8. **The V4 gas bar is current and explicit.** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`, section 2, states a 12,000,000 transaction ceiling and a 5,000,000 preview ceiling. It further requires a cold standalone public money or maintenance call body of at most 11,900,000, reserving 100,000 for overhead, with fixture setup excluded and no warming preview. Section 13 and the owner answers require every supported economic money and maintenance route, not a sample. `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Money.t.sol` implements the standalone measurements with isolated calls and `vm.lastFrameGas().gasTotalUsed`; `QuotesAndRate.t.sol` measures cold previews against 5,000,000.

9. **Current tests prove which assertions must be replaced rather than retained.** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_Import.t.sol` currently expects a second import to revert, expects the empty NFT to remain vault-owned, and uses the constant-product floor. `UniswapV3FullSpreadStandardExchangeVault_FullRangeBook.t.sol` calls permissionless rebalancing after import. `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadExactOutputFill.t.sol` expects successful exact-out fills; `UniswapV3FullSpreadVaultHeldRedeem.t.sol` expects vault-held share burns and Standardized Yield redemption; `UniswapV3FullSpreadLocalBook.t.sol` treats local balances as reserves and rejects over-max pretransfer instead of applying V3-ACC-10.

## Inferences

- A single V3 planner shared by previews and execution is the lowest-drift way to satisfy V3-ACC-05, V3-ACC-12, V3-ACC-13, and V3-ACC-19. This is an implementation inference, not a new economic rule.
- V3 needs explicit booked and operation-reservation storage because collection produces ordinary ERC-20 balances rather than PoolManager credit. That storage expression is required by V3-ACC-09; the field layout below is a plan choice.
- V3 should use its existing bound-pool mint/swap callbacks and direct `pool.swap`, `pool.mint`, `pool.burn`, and `pool.collect`. No V4 `unlock`, borrowed-unlock branch, callback commitment, or native wrapper is needed.
- Import must use the same planner and mint/fee functions as an ordinary bundle deposit. A separate constant-product or genesis implementation would violate V3-OWN-01 even if its happy-path share amount happened to match.

# Assumptions

- The PRD is the sole behavioral authority. V4 source and tests explain the copied rules but do not add V3 requirements.
- All deployment and ABI changes apply only to newly deployed vaults of the governed V3 implementation. There is no storage migration or repointing of an existing proxy.
- Tests deploy real facets, the production package through the manager/registry, a real hermetic V3 factory/pool, and a real Nonfungible Position Manager. The vault, package, facets, pool, and position manager are not mocked, etched, or storage-injected.
- Token indices always mean `pool.token0()` and `pool.token1()`. No native-currency substitution is introduced.
- Booked balances are tested through reserves, balances, maintenance, and exit claims; no new public booked-balance getter is required.
- The external rate provider behavior is taken from V3-ACC-19. Its implementation was not independently read in this pass.
- The source tree can change during the council; this is not an atomic repository snapshot.

# Coverage

| Source | Coverage |
| --- | --- |
| Locked V3 PRD and council brief | Examined in full; all V3-ACC and V3-OWN rows are covered in the plan. |
| Governed V3 production tree | Examined the common, repo, in/out bases and targets, execution delegates, multi routes and queries, import, liquid-reserve surface, package/interface, FactoryService, and TestBase. Remaining thin wrappers were inventoried but are not claimed line-by-line reviewed. |
| V4 implementation and test plan | Examined in full, including sections 13-16 and the gas owner answer. |
| V4 production behavior source | Examined Types, Repo, Math, Projection, SwapProjection, Planner, Execution, ExecutionPreparation, money/quote/out/query targets and facets, owner/maintenance modifiers, package/interfaces, and TestBase. V4 callback/unlock mechanics are not carried into the V3 plan. |
| V4 behavior tests | Examined Package, QuotesAndRate, OneSidedFuzz, Callbacks, and the relevant Money cases and gas measurements; AlreadyUnlocked and Native test names were inventoried to exclude those V4-only paths. |
| V3 behavior tests | Examined the three direct V3 regression files, the full import suite, the import facet test, and relevant FullRangeBook and lock-harness sections; other release-v3 files were inventoried for migration. |
| Earlier council responses | Not examined; they were optional and are not a new vote. |
| Runtime evidence | None. No build, test, gas run, deployment, wallet operation, or Git operation was performed. |

# Conclusions

## Plan-choice convention

The PRD fixes behavior, selectors, and owner locks, but not implementation sequencing, new library names, new facet/test filenames, or the exact import refund tuple. Every such choice below is a **plan choice**, not a new requirement. Existing paths named as edit targets are observed files. An author may reorder adjacent work only while preserving the dependency that previews and execution use the same planner and that all routes are wired before their tests are run.

## Ordered implementation and test plan

### 1. Add the V3 accounting state and math primitives

**Files — plan choices:** extend `UniswapV3FullSpreadStandardExchangeVaultRepo.sol`; add `UniswapV3FullSpreadStandardExchangeVaultTypes.sol` and `UniswapV3FullSpreadStandardExchangeVaultMath.sol`; edit `UniswapV3FullSpreadStandardExchangeVaultCommon.sol`.

- Append per-token `booked[2]` and operation-local `reserved[2]` state beside the existing position record, in pool-token order. At an idle boundary, unbooked balance is ERC-20 balance minus booked; during funding, also subtract that operation's reservation. Reservations return to zero before return. Retain the existing position key and full-range tick storage. This implements V3-ACC-09 and the funding isolation in V3-ACC-10 without a second fee-origin ledger.
- Keep `canOpenBoundPoolOps`, the bound-pool callback authorization, direct pool primitives, position/fee reads, and min/max usable ticks. Remove constant-product issuance, dead-sink/residual genesis math, decimals-based floors, free-balance reserve math, exact-out math, and all sleeve-rebalance helpers from the new execution path (V3-ACC-01, V3-ACC-02, V3-ACC-03, V3-ACC-08, V3-ACC-17).
- Add math for raw-liquidity claims, proportional adds, rounded-up amounts payable, rounded-down withdrawal amounts, net usage fees, and the fixed 49% one-sided fit. The one-sided fit chooses liquidity whose rounded-up opposing amount equals the entire swap output and whose rounded-up original-token amount does not exceed the unswapped input. Do not port `quadraticInput`, a root solve, or a split search (V3-ACC-05).

**Tests that can fail — plan choices:** add `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/OneSidedFuzz.t.sol` and math cases in `Money.t.sol`. Cover both token directions, exact boundary prices, tiny amounts, amounts above `int256` swap range, zero output, partial quotes, and proportional rounding. A wrong result fails preview/execution equality, whole-output consumption, input-only refund, or the raw-liquidity share equation. Include adjacent initialized dust ticks with `maxSteps == 0`; an undocumented step cap fails the normal mint/exit case (V3-ACC-05, V3-ACC-06, V3-ACC-18).

### 2. Implement one shared V3 planner before route execution

**Files — plan choices:** add `UniswapV3FullSpreadStandardExchangeVaultPlanner.sol`; use the existing V3 quoter directly rather than adding a V4 SwapProjection or unlock preparation file.

- Read supply, position liquidity, current sqrt price, fixed ticks, current pool active liquidity, collectable destination fees, and booked balances. Use supply and position liquidity from before an add. Existing-supply gross shares are floor(added liquidity times pre-add supply divided by pre-add position liquidity); burn liquidity is floor(pre-burn position liquidity times shares burned divided by pre-burn supply) (V3-ACC-02).
- On the first liquidity add, mark the plan failed when added liquidity is at most 1,000. Otherwise set gross shares to added liquidity minus 1,000 and schedule exactly 1,000 shares at `address(0)`. On every mint, calculate fee shares from gross shares using the live usage fee clamped to `3e17`, only when `feeTo` is nonzero; recipient shares are gross minus fee. Do not add the floor or fee on top of gross (V3-ACC-03, V3-ACC-04).
- For an established-supply one-token mint strictly inside the position, quote exactly floor(processed input times 49 / 100) at the PRD price limit. Require a nonzero, quotable, fully spent swap with nonzero output and a subsequent add that consumes all output. Any failure produces a zero-share whole-input refund plan; a positive execution minimum later produces `AmountOutNotMet`. Genesis failure instead remains `MinLiquidityNotMet` (V3-ACC-03, V3-ACC-05).
- At or outside either tick boundary, do not swap. Add only when the supplied token is the token the position wants; otherwise refund all. With established supply and zero active pool liquidity inside the position, refund all. Do not let zero-active liquidity override a valid wanted-token boundary add or the genesis floor (V3-ACC-06).
- Plan bundle-in as the greatest proportional add with two positional refunds and no swap. Plan bundle-out as the exact caller share burn and both token claims with no swap (V3-ACC-07, V3-ACC-13).
- Plan one-token exit from the caller's pre-burn principal, fee, and booked claims. Quote one exact-input swap of the entire opposing principal plus opposing fee and booked claims after the planned liquidity removal. If it cannot spend the entire amount, return a zero first preview word; execution will revert without burning. A valid first word is the requested principal, requested fee claim, requested booked claim, and swap proceeds (V3-ACC-11, V3-ACC-12).
- Plan pass-through as exact-input underlying swap with output and unspent-input refund, no shares, no usage fee, and no liquidity add/remove (V3-ACC-14).
- Plan donate/compound using the V4 sequence: collect nonzero unpaid fees first; combine booked, collected, and donated balances; use one 49% swap only for a one-token balance; use a proportional add without swap for both tokens; book remainders rather than refunding them. A share donation burns caller shares without withdrawing liquidity. No donation is allowed before the first mint (V3-OWN-02, V3-ACC-18).

**Tests that can fail — plan choices:** `Money.t.sol`, `QuotesAndRate.t.sol`, and `OneSidedFuzz.t.sol` must independently calculate gross/net shares, floor supply, fee shares, liquidity burned, four-part exit receipts, and bundle claims. Test fees of zero, `1e13`, `3e17`, and above cap, plus zero `feeTo`; test genesis at and below 1,000, failed first swaps, oversized first pretransfer, both boundaries, zero active liquidity, and incomplete full-book exits. A denominator that includes booked, unpaid, or stray balances fails V3-ACC-02/V3-ACC-09/V3-ACC-20 cases.

### 3. Implement V3 execution, funding, collection, and settlement against the planner

**Files — plan choices:** add `UniswapV3FullSpreadStandardExchangeVaultExecution.sol`; rewrite `UniswapV3FullSpreadStandardExchangeVaultInBase.sol` and `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol`; retain or resize `UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol` only as the existing CREATE3 bytecode-size mechanism, with no economic logic duplicated there.

- For a pull, transfer the full declared face amount from `msg.sender`; pay shares or exit output to `recipient` and unused input to `msg.sender`. For a one-token pretransfer within available unbooked credit, process at most the declared maximum and refund maximum minus used. If the maximum exceeds credit, spend none and pull no shortfall: on empty supply revert `MinLiquidityNotMet`; on established supply refund the entire unbooked balance and enforce a positive minimum with `AmountOutNotMet`. A bundle over-maximum on either leg reverts before either leg. Never subtract the old `MultiAssetBasicVaultRepo` free-balance reserve to compute credit (V3-ACC-10).
- For share-in exits, check and burn `msg.sender`'s own shares. Do not pull shares to the vault, burn vault-held shares, or treat parked shares as credit (V3-ACC-12, V3-ACC-13, V3-OWN-05).
- For each share-minting add, collect and book all destination-position fees attributable to pre-add liquidity immediately before the add, using `burn(0)` and `collect` when required. In a one-sided mint this is after its swap and before its mint, so swap fees owed to existing liquidity are booked too. Do not infer the old fee from a combined mint-callback delta and do not include it in the deposit or share denominator (V3-ACC-11).
- Execute the planned V3 actions in order. Verify actual mint payment against rounded-up planned amounts and actual swap input against the required full amount for one-sided mint and exit. Refund successful deposit remainders; do not book them. A partial opposing exit swap reverts `AmountOutNotMet`, so no shares burn and no residual is booked or kept (V3-ACC-05, V3-ACC-10, V3-ACC-12).
- On exit, read collectable fees before burn; burn and collect; split principal and fees using that read. Pay the exiting claims, subtract booked claims, and add only the staying holders' fee remainder to booked custody. Do not pay a combined balance delta as the caller's fee claim or count collected fees twice (V3-ACC-11 through V3-ACC-13).
- Pass-through pays actual output to `recipient`, applies its minimum to that output, and performs no fee collection, share mint, or rebalance (V3-ACC-14). Remove every post-operation sleeve rebalance and `_syncVaultReserves` free-balance booking call (V3-ACC-08).

**Tests that can fail — plan choices:** `Money.t.sol` records real V3 swap/mint/burn/collect calls and ERC-20 transfers. Assert exactly one 49% swap and one add for a normal one-sided mint, full pull then payer refund, no booked user refund, no swap for bundles, exact four-part exits in both directions, no burn on incomplete exit, no double-counted fees, and unchanged balances/supply after every revert. Migrate `UniswapV3FullSpreadLocalBook.t.sol` so booked and unbooked balances are distinct, within-max pretransfer works, over-max behavior matches V3-ACC-10, and direct transfers neither become reserves nor later caller credit. Replace vault-held-burn assertions in `UniswapV3FullSpreadVaultHeldRedeem.t.sol` with caller-only burns and parked-share negatives.

### 4. Add maintenance authorization and routes

**Files — plan choices:** add `UniswapV3FullSpreadStandardExchangeVaultOwnerModifiers.sol`, `UniswapV3FullSpreadStandardExchangeVaultMaintenanceModifiers.sol`, and new `UniswapV3FullSpreadStandardExchangeVaultMaintenanceTarget.sol` / `UniswapV3FullSpreadStandardExchangeVaultMaintenanceFacet.sol`.

- Install `donate`, `compound`, `setOperator`, and `setOperatorFor` on this new facet, not on the existing one-token facet. Use the live oracle `feeTo()` as owner; permit that owner, a global operator, or a function operator for `msg.sig`. Only the live owner appoints or revokes operators (V3-OWN-02, V3-OWN-03).
- Keep maintenance enabled while the vault is disabled. There is no user-route call to maintenance and no permissionless sleeve rebalance substitute. Empty `compound` is inert; successful `donate` emits the V4 no-argument donation marker; `Compounded` is emitted only for a qualifying deposit of collected fees or booked tokens. Remainders stay booked and processable (V3-OWN-02, V3-ACC-08, V3-ACC-16).

**Tests that can fail — plan choices:** `Money.t.sol` covers live-`feeTo` replacement, global and per-selector grants/revocations, strangers, zero-supply donation, share donation burn-only, one- and two-token maintenance, no maintenance refund, collapsed plans booked for later, empty/qualifying/reverting event cases, and disabled-vault maintenance. A user route that invokes maintenance or a booked balance that appears in reserves fails V3-OWN-02/V3-ACC-09 assertions.

### 5. Rebuild import as a late-capable bundle mint and burn the NFT

**Files:** edit `UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol` and `UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet.sol`. **Plan choice:** change both import returns to `(sharesOut, refund0, refund1)` so execution exposes the same report as preview; the PRD mandates net shares and both refunds on preview and actual overage payment, but does not mandate this exact tuple shape.

- Preserve deadline, owner/approval, matching factory/pool/token/fee, nonzero source liquidity, and non-reentrancy checks. Delete the total-supply/already-created prohibition. Import is valid on an empty vault or after organic supply, a prior import, and accrued destination fees exist (V3-OWN-01, V3-OWN-04).
- Before adding importer assets, snapshot, collect, and book destination-position fees under V3-ACC-11. Keep those assets out of the importer's incoming amounts. Then transfer the NFT, decrease all source liquidity, and collect both principal and all source fees. Measure the actual incoming amounts without mixing them with destination booked balances.
- Feed both incoming amounts into the same proportional planner and share/fee logic as bundle-in. Add to the one existing full-range destination position; never replace it or reset supply. Apply the genesis floor only when this import is the first liquidity. Refund both unused token amounts to `recipient`, not to shared booked custody (V3-OWN-01, V3-ACC-02 through V3-ACC-04, V3-ACC-07, V3-ACC-10).
- After decrease and collect have yielded every token amount, call the position manager's burn for the now-empty NFT. Do not return it to the owner and do not leave it at the vault. Any later failure reverts the whole call, including the NFT transfer/decrease/collect/burn and share writes. No constant-product issuance, dead-sink mint, residual share weight, or sleeve rebalance remains (V3-OWN-01).
- Preview computes source principal at current price plus all source stored/unpoked fees, runs the same destination proportional/share planner without transferring, and reports net shares and both refunds. A failed first-liquidity plan has zero shares; execution reverts `MinLiquidityNotMet` and leaves the NFT with its owner (V3-OWN-01, V3-ACC-03).

**Tests that can fail:** rewrite `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_Import.t.sol` rather than preserving its old expectations. Replace `test_import_secondImport_reverts` with a successful later import whose gross shares use pre-add liquidity/supply and whose supply is not reset. Replace `test_import_happyPath_principalOnly_leavesEmptyNft` with proof that the real position manager emitted the burn and that `ownerOf` reverts afterward; execution must not attempt burn until source liquidity and owed amounts are zero. Add distinct owner/caller/recipient cases proving both refunds go to `recipient`; source principal and fees are credited once; pre-existing destination fees are booked and excluded; genesis and later imports match previews; late one-sided input can refund without replacing the book; failed genesis rolls back the NFT and all balances. Preserve wrong-pool, wrong-factory, zero-liquidity, unauthorized-caller, missing-approval, and deadline negatives. Update `UniswapV3FullSpreadStandardExchangeVault_FullRangeBook.t.sol` to assert one maximum-usable-range position and NFT burn without calling `rebalanceLiquidReserve`. Update the import IFacet test for the chosen ABI.

### 6. Replace the public facet and package surface

**Files — plan choices:** add a family interface plus new Bundle, Quote, and Query target/facet pairs; edit In, Out, LiquidReserve, and Import facets; edit `IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol`, `UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol`, and `UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol`; update the V3 TestBase.

- New Bundle facet: `exchangeBundleInForSingleOut` and `exchangeBundleOut`. New Quote facet: `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, and `previewExchangeBundleOut`. New Maintenance facet from step 4 carries donate/compound/appointments. Thus all eight V3-OWN-03 selectors are on new facets, with V4 argument meanings and return words: exact share input on bundle exit, per-input refund words on bundle entry, and caller-ordered minima/outputs on bundle exit. Do not reinterpret exact output as a minimum or maximum share input as exact burn.
- Keep `exchangeIn` and the two V3 callbacks on the existing In facet. Move the canonical two-word `previewExchangeIn` to the new Quote facet. Keep fail-closed `previewExchangeOut` and `exchangeOut` on the Out surface. There is no `unlockCallback` (V3-ACC-01, V3-OWN-03).
- New Query facet installs `reserves` and `reserveOfToken`, returning deployed position principal plus unpaid position fees only; booked and unbooked balances are excluded and unknown tokens return zero (V3-ACC-09). Trim LiquidReserve to the retained `canOpenBoundPoolOps` and, as a plan choice, `deployedReserve` reporting position principal only. Remove `localReserve`, target/actual liquid percentages, `rebalanceLiquidReserve`, and their events (V3-ACC-08).
- Restrict the basic-vault cut to `vaultTokens`, as the V4 package does, so old basic reserve writes/views cannot conflict with the new Query facet. Preserve ERC-20/permit/domain and standard-vault facets and manager/registry deployment. As a plan choice, preserve the existing usage-fee registration while removing the liquid-reserve default; the tests set and read the live usage fee directly.
- Remove Standardized Yield execution/query selectors, `exchangeRate`, `assetInfo`, `quoteAssets`, `getRate`, old exact-out economics, and old multi/transition/frozen surfaces from the new package. The last removal is a plan-choice implementation of the V4-surface match, not permission to retain their retired reserve math. Remove obsolete delegate/facet deployments from FactoryService once unreferenced; never edit `contracts/protocols/dexes/uniswap/v3/` (V3-OWN-03 through V3-OWN-05).
- Update `TestBase_UniswapV3FullSpreadStandardExchangeVault.sol` to CREATE3-deploy the real new facets and deploy the changed package through the manager/registry. Bootstrap through public bundle or import routes, not storage injection or old multi routes. Remove liquid-reserve-default setup and expose usage-fee setters needed by the tests.

**Tests that can fail — plan choices:** add `Package.t.sol` and update the release-v3 IFacet/deploy suites. Enumerate every installed selector exactly once and its declared facet; assert the new-facet homes, pool-token order, full-range ticks, registry provenance, ERC-2612 domain, new-instance isolation, and zero floor/supply at initialization. Assert absence of `unlockCallback`, `IStandardizedYield`, `exchangeRate`, `assetInfo`, `quoteAssets`, `getRate`, sleeve routes/events, and old multi/exact-out routes. A pre-existing direct transfer at a predicted new address must not mint or become reserves (V3-ACC-03, V3-ACC-09, V3-OWN-03 through V3-OWN-05).

### 7. Enforce locked, disabled, exact-out, and preview/rate-provider boundaries

**Files:** edit the route targets from steps 3-6, `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol` / `UniswapV3FullSpreadStandardExchangeVaultOutFacet.sol`, and the new Quote/Query targets. Retire the old Out query/delegate exact-out implementation after migration.

- Before any execution route that must swap, mint, burn, or collect, require `pool.slot0().unlocked == true`; otherwise revert `UniswapV3Exchange_BoundPoolInteractionBlocked`. Do not use local settlement, constant-product issuance, or V4 unlock. `true` means idle. Previews still compute normally, or return zero for unsupported/failed plans, without reverting merely because the pool is locked (V3-ACC-15).
- Apply `VaultDisabled` to every execution route except one-token and bundle withdrawals, donate, and compound. Pass-through and enabled/disabled `exchangeOut` are not withdrawals; disabled `exchangeOut` reverts `VaultDisabled`. Views remain available (V3-ACC-16).
- `previewExchangeOut` always returns its existing one-word zero without a vault error. Enabled `exchangeOut` reverts `ExchangeOutNotAvailable()` and moves no tokens; neither selector gains a refund word (V3-ACC-17).
- Keep `previewExchangeIn` two words. Mint word one is net recipient shares; exit word one is the full receipt or zero for an unspendable opposing claim; word two is refund. Execution output and exit receipt must match preview from the same state even if refund words need not match (V3-ACC-19).
- Exercise the external Standard Exchange rate provider without adding any vault rate function: its nonempty call prices total supply through exit preview and ignores refund; its empty-supply call inverts a one-unit mint preview. An unspendable full-book exit and a failed/floor-bound first mint therefore read zero rate, with no NAV or fallback substitution (V3-ACC-19, V3-OWN-05).
- Do not add a TWAP, tick-move cap, tighter price limit, or claim that same-pool entry/exit/maintenance swaps solve manipulation (V3-ACC-18).

**Tests that can fail — plan choices:** add `PoolLocked.t.sol` and `QuotesAndRate.t.sol`; update `UniswapV3FullSpreadStandardExchangeVaultBoundPoolLockSeCaller.sol` to invoke the new canonical routes from inside a real pool callback. Cover every adopted execution route, no local fallback, and live previews while locked. Cover the full disable matrix and missed deadlines with atomic balance checks. Rewrite `UniswapV3FullSpreadExactOutputFill.t.sol` from successful exact-out fills to zero preview, enabled/disabled execution errors, and no token/supply movement. Quote tests cover all three `previewExchangeIn` kinds, both bundle previews in both caller orders, reserves with booked plus unpaid plus stray balances, both external rate-provider targets, empty/full-supply zero-rate cases, and absence of vault rate/quote functions.

### 8. Migrate the remaining V3 suites and run production-first verification

**Files — plan choices:** update the inventoried release-v3 Routes, Previews, MultiJoinExit, ReserveReconcile, PretransferParity, FeeCompound, FullRangeBook, Decimals, DFPkg deployment, harness, and IFacet files to the new selectors and economics. The three direct regression files are migrated as specified above. Replace obsolete positive assertions with the new positive and negative behavior; do not delete or skip a failing test merely to make the suite green.

- Keep all valid authorization, wrong-route, wrong-pool, recipient/payer, refund, rounding, and atomicity negatives. Change expected values only because a cited PRD rule changes them.
- Run production artifact generation before tests so FactoryServices cannot read stale creation bytecode: `forge build --use solar`, then the targeted V3 direct and release suites with `forge test --use solar`. Do not use `via_ir`, mock the SUT, or test the older `contracts/protocols/dexes/uniswap/v3/` tree.
- Review the final diff for V3-OWN-04: new deployments of the governed implementation only, no migration path, and no edit to the older tree.

A failure in any migrated assertion blocks completion; an old economic expectation is not a reason to preserve old code.

### 9. Measure every supported route against the verified V4 ceilings

**Files — plan choices:** standalone money/maintenance measurements in `Money.t.sol`, import measurements in the rewritten release-v3 Import suite, and preview measurements in `QuotesAndRate.t.sol`.

- Adopt the V4 plan's current 12,000,000 transaction ceiling and 5,000,000 preview ceiling. For each standalone public economic call, run a cold isolated call with fixture setup outside the measured body and no preceding warming preview. Assert `vm.lastFrameGas().gasTotalUsed <= 11_900_000`, preserving the V4 plan's 100,000 overhead allowance under the 12,000,000 transaction ceiling.
- Measure separately: one-sided share mint, one-token exit, pass-through, bundle-in, bundle-out, donate, compound, genesis import, and later import. Import measurements are a plan-choice extension because V4 has no import; they do not relax any ceiling. Include a dust-tick route so an unbounded quote cannot pass only on a trivial pool.
- Measure cold `previewExchangeIn` for mint, exit, and pass-through; both bundle previews; import preview; and zero `previewExchangeOut`, each at most 5,000,000. Do not warm one preview with another and do not measure a nonexistent `getRate`.
- An oversized route is unresolved, not passed. Do not raise the ceilings, omit later import, or convert a failed measurement into a warning. No V4 hook-composed or borrowed-unlock measurement is required for this V3 vault; if a separate composed consumer is later added, its entire transaction must independently fit 12,000,000 rather than relying on the standalone body result.

## Requirement-to-plan check

| PRD IDs | Ordered steps and principal failing suites |
| --- | --- |
| V3-ACC-01, 02, 03, 04 | 1-3, 5-6; Package, Money, QuotesAndRate, Import |
| V3-ACC-05, 06, 07 | 1-3, 6; Money, OneSidedFuzz, QuotesAndRate |
| V3-ACC-08, 09, 10 | 1, 3, 4, 6; Money, Package, QuotesAndRate, migrated LocalBook |
| V3-ACC-11, 12, 13 | 2-3, 6-7; Money, QuotesAndRate, migrated VaultHeldRedeem |
| V3-ACC-14, 15, 16, 17 | 2-3, 7; Money, PoolLocked, QuotesAndRate, migrated ExactOutputFill |
| V3-ACC-18 | 1-2, 7; Money and QuotesAndRate contain no added manipulation gate |
| V3-ACC-19, 20 | 2, 6-7; QuotesAndRate and Money later-mint/booked-claim cases |
| V3-OWN-01 | 5, 9; rewritten Import and FullRangeBook suites |
| V3-OWN-02 | 2, 4, 9; Money maintenance and authorization cases |
| V3-OWN-03 | 4, 6; Package and new/updated IFacet suites |
| V3-OWN-04 | 5-6, 8; new-instance tests plus scoped-diff check |
| V3-OWN-05 | 3, 6-7; Package, QuotesAndRate, migrated VaultHeldRedeem |

# Limits

- This is static research and an ordered plan, not implementation authority and not a claim that the current or proposed code passes.
- No tests, builds, gas measurements, installs, deployment, wallet operations, or Git operations were run. The gas numbers are verified plan ceilings, not measured V3 results.
- The external rate-provider implementation was not read; its required calls and zero-rate outcomes come from the locked PRD. The V4 hook matrix, PairToken, upper/lower wings, native-currency routes, and borrowed-unlock behavior were not used as V3 requirements.
- The exact import refund tuple, internal library/facet decomposition, test filenames, retention of `deployedReserve`, and work ordering are labeled plan choices. The owner locks are not reopened.
- Live files may change before implementation; the later author must re-read the locked PRD and the actual V3/V4 sources before editing. This contribution neither replaces the PRD nor authorizes implementation.
