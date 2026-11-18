# Identity

- Member: astra.
- Profile: research.
- Phase: initial independent response.
- Run ID: v3-fullspread-v4-accounting-plan-20261116.
- Requested role: council-member.
- Requested model: chatgpt-subscription/gpt-6-astra:high.
- Actual runtime model, reasoning setting, account route, role, session identity, and task ID: not exposed.
- Contribution: an independent implementation-and-test planning proposal. This contribution does not authorize implementation.

# Question and targets

What ordered implementation and test plan must a later author follow so the governed Uniswap V3 full-spread Standard Exchange vault satisfies the locked accounting PRD, including burning the emptied imported NFT and allowing import after supply exists?

Authority is `docs/research/v3-fullspread-v4-accounting-prd-20261116/UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_PRD.md`, particularly V3-ACC-01 through V3-ACC-20 and V3-OWN-01 through V3-OWN-05. The assignment is `docs/research/v3-fullspread-v4-accounting-plan-20261116/brief.md`.

The following path abbreviations are used throughout this contribution:

- `V3/` = `contracts/vaults/standard/exchange/protocols/uniswap/v3/`.
- `V4/` = `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.
- `PRD` = the locked V3 accounting PRD named above.
- `V4 plan` = `V4/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`.
- `V4 PRD` = `V4/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`.

These abbreviations expand to repository paths, not external sources. The older `contracts/protocols/dexes/uniswap/v3/` implementation is outside the work. Existing deployed vaults are outside the conversion.

# Evidence

All observations below are static source observations. The implementation sequence and file organization in Conclusions are inferences and plan choices, not observed runtime results.

| Evidence | Observation and source actually read | Planning consequence |
| --- | --- | --- |
| E1 | The complete PRD retains import, requires the empty NFT to be burned, permits subsequent imports, closes maintenance and new-facet decisions, restricts the change to new vaults, and removes Standardized Yield. | These are inputs to the plan, not questions for another owner decision. |
| E2 | `V3/UniswapV3FullSpreadStandardExchangeVaultRepo.sol` stores the center ticks and a created flag. `V3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol` already derives usable full-range ticks, reads position liquidity, computes stored plus unpoked fees, and uses bound-pool mint/swap callbacks. It also contains reserve-book issuance, dead-sink issuance, free-balance reserve accounting, sleeve targeting, and rebalance helpers. | Preserve the V3 pool adapter and position identity; replace the accounting and funding classifications. |
| E3 | `V3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol` credits reserve-based deposits, collects before its old share calculation, permits blocked local issuance/exits, apportions free balances on exit, and rebalances afterward. `V3/UniswapV3FullSpreadStandardExchangeVaultInTarget.sol` returns a hardcoded zero refund; its delegate burns vault-held shares. `V3/UniswapV3FullSpreadStandardExchangeVaultInMultiQueryTarget.sol` likewise returns a hardcoded zero refund. | Deposit, exit, funding, and preview changes must land together; changing only the share formula would retain incompatible settlement. |
| E4 | `V3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol` rejects nonzero supply or an existing position, returns one preview word, transfers/decreases/collects the NFT, leaves it unburned, credits constant-product shares, mints a dead-sink floor, and invokes sleeve rebalance. Its fee projection includes stored NFT amounts owed and fee-growth differences. | Import must become an adapter into the same proportional-add engine, with source-NFT and destination-position fee amounts kept separate. |
| E5 | `V3/UniswapV3FullSpreadStandardExchangeVaultOutBase.sol`, `...OutExecuteTarget.sol`, `...OutExecutionDelegate.sol`, and `...OutQueryTarget.sol` implement exact-out inverse/search paths. `...OutMultiTarget.sol` and `...OutMultiQueryTarget.sol` derive a burn from requested token outputs. | These implementations cannot be used as the new exact-in bundle exit. The one-token exact-out selectors become fail-closed. |
| E6 | `V3/UniswapV3FullSpreadStandardExchangeVaultInFacet.sol` appends SY execution selectors; `...OutQueryFacet.sol` appends SY query selectors. `...InQueryFacet.sol` installs transition/frozen quote functions, including `quoteAssets`. `...InQueryTarget.sol` models the old reserve and sleeve economics. The DFPkg advertises SY and transition interfaces and installs all basic-vault facet selectors. | Audit the finished proxy cut and interface declarations, not just function bodies. Preserve `previewExchangeIn` when removing the old query surface. |
| E7 | `V3/IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol`, `V3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol`, and `V3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol` describe current components, CREATE3 deployment helpers, and manager/registry package deployment. `V3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol` supplies a production fixture with a real V3 factory/pool and currently configures a sleeve percentage. | Update the actual package and fixture together. Remove sleeve-dependent setup and use fresh component/package deployment identities for new vaults. |
| E8 | `V4/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` shares planning between execution and previews; `_size` uses the fixed 49% input and inclusive boundary checks. `_shares` uses raw liquidity and net fee shares. `V4/UniswapV4FullSpreadStandardExchangeVaultMath.sol`, read through its sizing and single-token-add functions, distinguishes rounded-up mint costs from rounded-down principal and consumes all quoted swap output. It also contains `quadraticInput`, which the locked V3 PRD expressly rejects. | Port the accepted behavior, not every available helper. Preserve full swap quote results and mint-cost rounding. |
| E9 | `V4/UniswapV4FullSpreadStandardExchangeVaultExecution.sol`, `...Planner.sol`, `...Repo.sol`, `...Projection.sol`, `...MoneyTarget.sol`, and `...QuoteTarget.sol` separate booked custody, refunds, fee claims, mint shares, and exit receipts. `_mint` in the inspected execution still calls `ERC20Repo._mint(address(0), ...)`. The PRD expressly forbids using that path for the floor. | V4 source is evidence, not a correctness oracle. The locked non-reverting zero-address balance write controls the V3 implementation. |
| E10 | V4 PRD FS-OWN-14/21/33 and the V4 plan sections 9 and 11 require live-owner/operator maintenance, one-token 49% sizing, proportional two-token processing, booked remainders, share donation by burn, and specific marker-event behavior. V4 maintenance books actual held balances after processing, including stray transfers, while empty `compound` does nothing. The two V4 modifier files implement the live-owner and selector-specific comparisons. | Port the whole maintenance lifecycle, including its distinction between eligible processing inputs and terminal balance booking. |
| E11 | `V4/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` explicitly selects installed functions, including only `vaultTokens` from its basic-vault facet. `...QueryTarget.sol` returns position amounts plus unpaid fees. `...OutTarget.sol` returns zero for the preview and fails execution after disable handling. | Use explicit V3 selector ownership and live reserve reads. Do not copy V4 infrastructure getters or `unlockCallback`. |
| E12 | The complete V4 plan, section 2, says transaction ceiling **12,000,000**, preview ceiling **5,000,000**, and standalone cold public money/maintenance body **11,900,000**, leaving 100,000 overhead. Section 13 names seven economic routes and rejects sampled coverage. Sections 13 and 16 retain those ceilings. V4 PRD FS-MONEY-01 and FS-A31 repeat the transaction/preview ceilings. | Adopt these verified numbers, add V3 import to route coverage, and report an over-ceiling result as unresolved. No gas result was obtained in this assignment. |

# Assumptions

1. The locked V3 PRD wins over old V3 comments, the older V3 remediation document, conflicting V4 implementation details, and historical router descriptions. V4 provisions apply only through the V3 requirements that adopt them.
2. Proposed filenames, internal decomposition, test grouping, component salt versioning, and the order of otherwise independent work below are **plan choices**. They do not add economic requirements. The V3 PRD names behavior and the governed tree rather than a required implementation file layout.
3. A preview/execution equality test starts from the same pool, oracle, supply, liquidity, and booked state. Refund previews do not promise custody or transfer; this does not relax exit receipt equality.
4. Valid fixture tokens follow the repository token policy: no fee-on-transfer or rebasing underlyings. Different token decimals remain useful tests because the share formula must not normalize them. `CLAUDE.md` supplies that policy and the production-first deployment/testing rules.
5. Dependency implementations outside the admitted trees were not inspected. A later implementer must inspect the current Crane ERC-20 floor-write helper, V3 quoting result fields, position manager, and affected consumers before coding against those APIs. This is an engineering prerequisite, not a reopened product question.

# Coverage

| Target | Coverage |
| --- | --- |
| Brief and locked V3 PRD | Read in full, including the import amendments and all five owner locks. |
| Governed V3 Solidity | Read the repository, common accounting, in/out bases, execution delegates, query and multi targets, all family facet selector lists, import implementation, pool/factory bindings, package interface, DFPkg, FactoryService, SY adapter, sleeve interface/target, and the co-located TestBase. |
| V4 implementation | Examined the economic planner, execution, projection, swap projection, types, repo, money/quote/query/out targets, owner/maintenance modifiers, interface, and complete DFPkg. Math was examined through sizing, payment rounding, claims, fees, and boundary additions; the unused quadratic helper's remaining arithmetic was not needed. |
| V4 implementation and test plan | Read in full, including sections 2, 9-13, 15, and 16. Its hook inventory is context, not a wholesale V3 requirement. |
| V4 PRD | Examined the adopted owner accounting and maintenance locks and gas passages. Did not treat the hook-economics amendments as V3 vault share requirements. |
| Existing tests outside the admitted trees, dependency implementations, external provider source, generated ABIs and deployment consumers | Not inspected. The plan identifies required behavior and a later targeted consumer inventory; it does not claim those callers already work. |
| Earlier member responses | Not read. No earlier council response is counted as a new vote. |
| Runtime, build, tests and gas | Not run. All acceptance tests and measurements below are future work. |

# Conclusions

The dependency order is: fix the package contract and accounting classifications, establish shared V3 sizing and claims, implement deposits and exits, connect import to the settled deposit engine, then add maintenance and complete integration/gas acceptance. Implementing import before the proportional-add engine would duplicate the most important accounting.

**Plan-choice convention:** every new filename and every implementation file grouping below is a proposed concrete destination. Likewise, the numbered order is the proposed execution order, except where an explicit dependency is stated. The behavior and test oracle in each step come from its cited PRD IDs.

For test destinations, use the existing `V3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol` and add these co-located suites as a **plan choice**:

- `V3/test/UniswapV3FullSpreadStandardExchangeVault.Package.t.sol`
- `V3/test/UniswapV3FullSpreadStandardExchangeVault.Accounting.t.sol`
- `V3/test/UniswapV3FullSpreadStandardExchangeVault.Deposits.t.sol`
- `V3/test/UniswapV3FullSpreadStandardExchangeVault.Exits.t.sol`
- `V3/test/UniswapV3FullSpreadStandardExchangeVault.Import.t.sol`
- `V3/test/UniswapV3FullSpreadStandardExchangeVault.Maintenance.t.sol`
- `V3/test/UniswapV3FullSpreadStandardExchangeVault.QuotesAndGates.t.sol`
- `V3/test/UniswapV3FullSpreadStandardExchangeVault.Invariants.t.sol`
- `V3/test/UniswapV3FullSpreadStandardExchangeVault.Gas.t.sol`

These are proposed files, not claims that those suites already exist or pass. Each economic assertion must exercise a real manager/registry-deployed vault and real V3 pool through the public proxy. Expected amounts must come from independently read pre-state, integer claim formulas, pool liquidity/fee information, and observed token movements; preview-versus-execution equality alone is insufficient.

## 1. Establish the new-vault package and selector contract

**Files:** change `V3/IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol`, `V3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol`, `V3/UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol`, the current in/query/out facet selector lists, and the V3 TestBase. Add `V3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol` for family declarations as a plan choice; reuse the accepted bundle signature definitions rather than inventing a different bundle ABI.

**Requirements:** V3-ACC-01/08/09/13/17/19; V3-OWN-03/04/05. Prepare the final cut now and complete it as the later steps implement its targets:

| Home, a plan choice | Installed economic functions |
| --- | --- |
| Existing `...InFacet.sol` / `...InTarget.sol` | `exchangeIn` and the authenticated V3 mint/swap callbacks. |
| Repurposed `...InQueryFacet.sol` / `...InQueryTarget.sol` | The existing two-word `previewExchangeIn`. Its present home is `...InMultiQueryFacet.sol`; move it exactly once. |
| Existing out and out-query facets | Fail-closed `exchangeOut` and zero-returning `previewExchangeOut`, preserving their return widths. |
| New `UniswapV3FullSpreadStandardExchangeVaultBundleFacet.sol` and `...BundleTarget.sol` | `exchangeBundleInForSingleOut`, `exchangeBundleOut`. |
| New `UniswapV3FullSpreadStandardExchangeVaultBundleQueryFacet.sol` and `...BundleQueryTarget.sol` | Both new bundle previews. |
| New `UniswapV3FullSpreadStandardExchangeVaultMaintenanceFacet.sol` and `...MaintenanceTarget.sol` | `donate`, `compound`, `setOperator`, `setOperatorFor`. |
| Existing import facet and target | `previewImportPosition`, `importPosition`; widened import preview ABI. |
| New `UniswapV3FullSpreadStandardExchangeVaultQueryFacet.sol` and `...QueryTarget.sol` | `reserves`, `reserveOfToken`, `canOpenBoundPoolOps`; retain `deployedReserve` as a plan choice reporting principal amounts only. |

Select only the necessary shared basic-vault functions, with `vaultTokens` preserved and family reserve queries taking their correct selectors. Preserve ordinary ERC-20, permit, domain, and standard-vault metadata functionality. Remove SY execution/query appenders, SY inheritance in governed targets, and SY interface advertisements. Remove `quoteAssets` and the old transition/frozen quote implementation from the new package. **Plan choice:** retire that entire old quote facet surface rather than preserve additional selectors that model reserve-book issuance.

Do not install old many-to-one/one-to-many entrypoints as aliases with reinterpreted arguments. **Plan choice:** remove those legacy selector cuts from new packages; the adopted bundle selectors are the supported replacements. The new facets are mandatory under V3-OWN-03; the particular three facet groups above are a plan choice. No cut installs `unlockCallback`, `IStandardizedYield`, `exchangeRate`, `assetInfo`, named vault-held-share redemption, `quoteAssets`, vault `getRate`, or `rateAsset`.

**Plan choice:** version the governed FactoryService's component/package deployment salts for the accounting generation, keeping public helper names where practical. Verify that a new package resolves to the intended new component bytecode rather than an already deployed old component. Do not upgrade, recut, or repoint an existing vault. Keep changes out of the older V3 tree. Read affected helper callers before updating any `PkgInit` construction outside this tree; those caller filenames have not been inventoried here.

The current usage-fee type key is tied to the old sleeve interface in `vaultFeeTypeIds()`. **Plan choice:** preserve that existing usage-fee lookup identity as metadata while removing the obsolete interface from supported-interface declarations and eliminating all sleeve-percentage reads. Do not silently change oracle defaults while removing selectors; prove that `usageFeeOfVault(vault)` resolves as configured.

**Failing tests:** Package tests enumerate the actual loupe cut and interface support, call retained selectors, decode both `previewExchangeIn` words, and verify retired selectors are absent. Test a new package through the manager/registry, its bound pool factory, unchanged ERC-20/permit/domain behavior, no initialization floor, no duplicate preview selector, and intended component bytecode. Removal must not accidentally remove the external provider's preview entrypoint. Assert usage-fee resolution independently of liquid-reserve settings.

## 2. Introduce custody accounting and remove sleeve settlement

**Files:** change `V3/UniswapV3FullSpreadStandardExchangeVaultRepo.sol`, `...Common.sol`, and the new query target. Retire the sleeve target/facet from the package; remove their obsolete execution helpers and remove unused governed-only files once all references have been migrated. Do not delete shared constant-product or SY implementations used by other families.

**Requirements:** V3-ACC-01/08/09/10/11/15. Keep one direct-pool position with full usable ticks fixed before its first add. Store booked token amounts explicitly in token0/token1 order. **Plan choice:** use `uint256[2] booked` in the existing governed repo and carry each operation's funding/refund budgets separately in operation state. If storage reservations are used, clear them at completion and exclude them from concurrent available credit.

Retain and adapt the existing fee-growth reader, including owed tokens and unpoked growth. Reserve queries read position principal plus unpaid fees; they exclude both booked and unbooked ERC-20 custody. Stop using `_syncVaultReserves` or `MultiAssetBasicVaultRepo` snapshots as the economic reserve or pretransfer-credit source. Available pretransfer custody is held underlying minus booked custody and any live operation reservation, with checked accounting.

Keep `canOpenBoundPoolOps` as the pool-lock gate only. All execution paths requiring a pool operation must reject a locked bound pool. No local success path, reserve issuance, sleeve payment, percentage target, deadband, or post-operation rebalance remains. Keep the public-operation guard across funding, callbacks, accounting, payouts, and import; authenticate callbacks against the bound pool while allowing the legitimate callback inside that guard.

**Failing tests:** Accounting tests create separate deployed principal, unpaid fees, booked custody, and an unsolicited transfer. Assert the reserve read includes only the first two; collection moves fees from unpaid to booked exactly once. User deposits do not consume booked balances; user withdrawals do not claim unbooked balances. Changing the oracle sleeve percentage cannot change an operation's liquidity or payout. Callback tests reject a foreign caller and reentrant money entry without disturbing legitimate V3 callbacks. A locked-pool test uses an actual pool callback, not a patched lock bit.

## 3. Build shared liquidity sizing, share math, and claim planning

**Files:** add `V3/UniswapV3FullSpreadStandardExchangeVaultMath.sol` and `V3/UniswapV3FullSpreadStandardExchangeVaultPlanner.sol` as plan choices. Make the planner a common internal planning layer over the V3 readers; refactor `...InBase.sol` and the preview targets to use it. Reuse the existing V3 quoter entrypoints already called by Common instead of copying V4 PoolManager state handling.

**Requirements:** V3-ACC-02/03/04/05/06/07/11/12/13/18/20. Keep full quote results: spent input, output, resulting sqrt price, and relevant post-swap pool state. An amount-output-only wrapper cannot prove full consumption. For exit projection, apply the vault's liquidity removal at its actual bounds, including its effect on active liquidity and crossed ticks.

Implement proportional add sizing against rounded-up V3 mint payments and withdrawal principal against rounded-down burn amounts. Test that the selected both-token liquidity fits and that one additional liquidity unit does not fit when representable. Share calculations use actual added liquidity and pre-add supply/liquidity; fees, custody, and decimals do not enter that denominator.

Implement the 1,000 floor through a current Crane storage helper that can write the zero-address balance and supply without invoking its prohibited receiver check. Do not copy the inspected V4 `_mint` call. Select the exact helper only after reading it. The first successful add produces `floor + feeShares + recipientShares == addedLiquidity`; later supply growth is exactly `grossShares`. Apply live fee netting and the `3e17` clamp consistently in planning and settlement.

For one-token sizing, decide boundary handling before the zero-active-liquidity interior branch. Inside, quote exactly `floor(processedInput * 49 / 100)` once at the locked extreme limit, and accept only a fully spent swap whose entire output the rounded-up add can use. Do not search for a different split. A quote may traverse ticks to simulate that fixed swap; that is not permission to traverse ticks to choose a better fraction.

**Failing tests:** Cover floor additions below, equal to, and above 1,000; zero-address balance/supply inclusion; zero and 0.001% fees; the cap, an above-cap oracle value, zero `feeTo`, and no oracle mutation. Test both token directions, mixed decimals, exactly both position boundaries, out-of-range wanted/unwanted tokens, interior zero active liquidity, zero 49% rounding, unquotable inputs, partial fill, zero swap output, and an add that cannot consume the swap output. Compare expected shares with independent integer formulas, not another call to the planner. Verify old holders' per-share booked claim can fall after a later mint under V3-ACC-20; do not assert a stronger per-vintage guarantee.

## 4. Connect user deposits, bundles, refunds, and pass-through

**Files:** change `V3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol`, `...InTarget.sol`, `...InExecutionDelegate.sol`, repurposed `...InQueryTarget.sol`, and the new bundle execution/query targets. Update delegate return data so the refund is real rather than discarded.

**Requirements:** V3-ACC-03 through V3-ACC-11, V3-ACC-14/15/16/19/20, V3-OWN-03. Pull the full declaration on the pull path. On pretransfer, validate against unbooked custody before any leg or pool action. A within-credit declaration budgets only that declaration; an oversized one-token declaration spends nothing, pulls nothing, and follows the exact genesis/established-supply/minimum outcomes. An oversized bundle leg rejects the complete bundle before processing a leg.

For a successful share mint, snapshot supply and existing position liquidity before the add. The entry swap uses only the caller budget. Immediately before minting liquidity, snapshot and collect the existing position's payable fees and book the actual collected amounts. **Execution-order inference:** when the entry swap itself earned fees for the existing destination position, include those fees in this pre-add collection; they are not the new depositor's contribution. Do not rely on a snapshot from before that swap or infer fees from the mint payment delta. A bundle has no balancing swap and uses the same proportional-add and fee-netting path.

Refund unused user inputs to `msg.sender`; mint net shares to `recipient`. A failed established-supply one-sided plan performs no swap and no mint and refunds its whole processed input unless the minimum forces `AmountOutNotMet`. Failed genesis instead reverts `MinLiquidityNotMet`, including oversized pretransfer. Do not turn that revert into a successful refund.

Pass-through returns actual swap output and unspent input, charges no usage fee, mints no shares, and does not collect/rebalance/compound the vault position. Distinguish that partial-fill refund from the stricter full-spend requirements for a balancing swap or one-token exit.

**Failing tests:** Deposit tests reconcile declared input to consumed plus refunded amounts and measure payer and recipient separately. Test a large pre-existing unbooked balance with a smaller declaration, exactly available credit, over-max with zero/positive minimum, first-deposit over-max, one bad bundle leg, and both argument orders relevant to the adopted ABI. Prove the unchanged booked inventory is not funding a mint. Accrue fees before and during a later one-token mint and prove collection does not increase its share credit. For bundles assert no pool swap and each refund. For pass-through assert unchanged share supply/position liquidity, no usage-fee shares, and a partial-input refund. Positive net-share minima must fail atomically.

## 5. Implement caller-share exits and fail-closed exact-out

**Files:** implement shared exits in the planner and `...InBase.sol`/`...InExecutionDelegate.sol`; wire the new bundle targets. Reduce `...OutExecuteTarget.sol` and `...OutQueryTarget.sol` to the adopted fail-closed contract. Remove unused exact-out arithmetic/delegation from the governed `...OutBase.sol`, `...OutExecutionDelegate.sol`, and old multi targets after their callers are removed.

**Requirements:** V3-ACC-02/09/10/11/12/13/15/16/17/19, V3-OWN-05. Canonical exits verify and burn `msg.sender`'s exact-in shares. Neither the pretransfer flag nor shares parked on the vault substitute for caller ownership.

Before burning liquidity, record supply, position liquidity, collectable fees, and booked balances. Compute each token's fee and booked claim by multiply-then-divide flooring. Burn the liquidity fraction and collect; separate returned principal from fees using the pre-burn record and pool operation results. Pay only the caller's claim and retain/book the other holders' collected fee remainder once.

A one-token exit projects the swap after liquidity removal and swaps the entire opposing principal-plus-fee-plus-booked claim. It pays the requested principal, requested fee and booked claims, and swap output. Require actual full input spend and the minimum against the full receipt. A failed full-spend plan previews a zero first word; execution reverts `AmountOutNotMet` with all token, liquidity, share, and custody changes rolled back.

A bundle exit uses the same claim in both tokens without swapping, accepts the exact share input, and maps outputs/minimum failures to the caller's token order. No token-output inverse or equality-of-two-implied-burns test survives. Handle a tiny share burn whose liquidity fraction rounds to zero without silently losing a nonzero fee/booked claim; collection still has to follow the claim accounting.

**Failing tests:** Exits tests use two holders, unpaid fees in both tokens, booked remainders, and unrelated unbooked custody. Independently assert all four receipt components and remaining-holder custody. Test both single-output directions, both bundle output orders, small shares, the zero-liquidity-rounding case, minima one wei above the receipt, and partial opposing-swap spend. Assert the complete rollback, not only the error. Test parked shares with a caller that lacks shares, and caller shares with both flag values. Enabled exact-out always fails with `ExchangeOutNotAvailable`, disabled exact-out with `VaultDisabled`, and its preview is zero without moving tokens.

## 6. Rebuild import as a funded proportional deposit and burn its NFT

**Dependency:** complete steps 2-4 first. Import must call their settled proportional-add/share-fee behavior, not maintain a second issuance implementation.

**Files:** change `V3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol`, its inline import interface or the new family interface, `...PositionImportFacet.sol`, FactoryService/package bindings as needed, and import ABI consumers identified later. **Plan choice:** widen `previewImportPosition` to `(sharesOut, refund0, refund1)` in pool-token order while retaining the execution function's existing share return. The requirement is the preview's net shares and both refunds, not these particular return names.

**Requirements:** V3-OWN-01, V3-ACC-01/02/03/04/07/09/10/11/15/16/20. Remove the existing nonzero-supply/created-position prohibition. Preserve appropriate source ownership/approval, factory/pool matching, and deadline validation. Transfer the source NFT, remove its liquidity, collect all principal and fees into separately measured incoming amounts, and burn the now-empty NFT. **Plan choice:** burn immediately after collection and before the destination add; a later failure reverts that burn with the transaction.

Keep two different fee accounts throughout:

- Source-NFT principal and collected fees are the importer's incoming deposit budget.
- Destination-position fees are collected/booked for the destination under V3-ACC-11 and never become incoming import credit.

Add the greatest proportional liquidity supported by the source proceeds. Pay both unused input amounts to `recipient`, including when `owner`, caller/operator, and recipient differ. Mint only net shares after the usage fee. On an empty destination use its canonical full-range position and exactly one floor. On an established destination preserve its position key/ticks and use existing liquidity and supply in the share formula; do not reset or replace either.

The preview includes source principal, stored owed amounts and pending collectible source fees, computes the same destination add, and reports net shares/refunds. It does not require custody transfer. Widening only return data leaves the function selector unchanged, so selector or ERC-165 checks alone cannot prove the preview ABI migration.

**Failing tests:** Use a real position manager and real NFTs. Cover import as genesis, after an organic deposit, after a previous import, and after swaps plus maintenance have created destination unpaid/booked balances. Use differently ranged source NFTs to force proportional refunds. Assert source fees increase importer input while destination fees do not; destination liquidity increases by the actual add; gross/net/fee shares follow the correct pre-add denominator; the 1,000 floor occurs only once. Assert the source NFT no longer exists after success, rather than merely checking its liquidity or vault ownership. Verify both refunds arrive at `recipient`, not the NFT owner or transaction caller by accident. Test insufficient minimum and downstream failure rollback of source NFT ownership/liquidity, burn, destination state, transfers and supply. Decode all three preview words and compare the executed import receipt/refunds from the same state.

## 7. Add authorized donate and compound on their new facet

**Files:** new maintenance facet/target, shared execution/planning code, repo, and package/FactoryService bindings. **Plan choice:** place the two live-owner comparison helpers in the maintenance target rather than introduce another stored-owner mechanism.

**Requirements:** V3-OWN-02/03; V3-ACC-05/06/08/09/10/15/16/18; adopted V4 FS-OWN-14/21/33. Read the bound oracle's live `feeTo` proxy address for ownership. Use the existing operable storage model for global and per-selector grants. Only the live owner appoints operators; a function grant for another selector is insufficient. Do not initialize a cached ownable owner.

Collect unpaid destination fees before maintenance sizing. Process collected fees plus booked balances plus the directed donation. If this eligible balance holds both tokens, add proportionally without swapping. If it holds one, use the same boundary/interior 49% logic; an unformable sizing outcome books the input and keeps no swap. A real failed processing step propagates its revert. Do not swallow failures or add an extra cleaning attempt.

An underlying donation mints no shares. A share donation burns caller-owned shares without withdrawing liquidity or swapping those shares, then processes eligible held tokens by the same maintenance rule. Reject donation before the first mint. After processing, book actual held balances as the adopted V4 rule requires, including stray custody; do not mistake this maintenance booking for a user's refundable deposit remainder. Conversely, `compound` with no fees and no booked remainder is a true no-op even if an unrelated unbooked transfer exists.

Emit `Donation()` on successful donation, including a no-add result. Emit `Compounded()` only when a deposit actually uses collected fees or booked tokens; fresh donation alone does not earn that event. Empty compound emits nothing; a reverting call emits neither. User deposit/exit/pass-through routes never invoke this maintenance.

**Failing tests:** Maintenance tests cover live owner change, owner/global/correct-function authorization, wrong-function/stranger rejection, grant and revocation, underlying/share donations, no-supply rejection, one-token and both-token eligible balances, boundaries, failed sizing without a swap, actual processing failure rollback, repeated processing of booked dust, and actual-balance booking of a stray transfer during qualifying maintenance. Assert no minted donation shares, no share-donation principal withdrawal, no deployment of staying-holder custody through ordinary user routes, and the complete event matrix. Booked dust remains excluded from reserves until deployed. Do not assert that authorized maintenance swaps are manipulation-proof.

## 8. Finish gates, public previews, and consumer compatibility

**Files:** all public governed targets touched above; the package tests and QuotesAndGates suite. Later identify the actual typed callers and ABI artifacts affected by import preview widening, retired selectors, and `PkgInit` changes before editing those files. No external consumer inventory was performed here.

**Requirements:** V3-ACC-15/16/17/19; V3-OWN-03/04/05. Separate disabled-vault gating from locked-pool gating. Allowed disabled withdrawals and maintenance still cannot perform a pool operation while that pool is locked. Previews compute or return zero for an unsupported adopted route without failing solely because of either gate. Keep the `previewExchangeIn` tuple and its first-word meaning.

Apply V3-ACC-16's explicit exception list to execution routes. In particular, the V4 plan section 6 says its appointment functions have no disable check, but the locked V3 text exempts only withdrawals, `donate`, and `compound`. **Inference from the controlling V3 wording:** appointments also reject `VaultDisabled`; do not silently import a fourth exception from the V4 plan. This applies the existing lock rather than reopening it.

**Plan choice:** use deadline-before-disable ordering for routes with deadlines, consistent with the adopted V4 behavior and current import ordering; do not add a deadline to maintenance. Preserve specifically mandated error behavior for failed genesis, positive-minimum refunds, incomplete exits, exact-out and pool locking.

Exercise the real external Standard Exchange provider with this vault and each underlying as rate target. Its non-empty route quotes `totalSupply` shares through `previewExchangeIn`; its empty route inverts a unit mint preview. Test a completable full-book quote, a full-book opposing swap that cannot complete and produces zero, and an empty mint below the floor/unformable add that also produces zero. Do not add fallback NAV or a vault rate to keep an old provider number. A consumer that still calls removed `quoteAssets` must be recorded as incompatible with this new surface, not repaired by restoring that selector.

**Failing tests:** Use real pool callbacks to run the locked execution/view matrix; run enabled and disabled deposit, import, pass-through, both exits, maintenance, appointments, and exact-out cases. Validate that positive-minimum refund outcomes fail atomically. Assert the exact two-word preview ABI, three-word import preview ABI, bundle array order, disabled views, and caller-held-share semantics. Provider tests must compare with the specified preview operation and must include zero-rate cases, not only a positive example. Consumer changes must preserve their argument meanings; a requested exact token output cannot become a minimum and a maximum share amount cannot become an exact burn under an old selector.

## 9. Run lifecycle, adversarial, and regression acceptance

**Files:** the proposed Invariants suite and all earlier suites; extend the production V3 TestBase rather than substitute a fake vault. Remove its default sleeve-percentage setup as the new fixture no longer needs that dependency. Use real manager/oracle configuration to generate fees and disable states.

**Requirements:** all V3-ACC and V3-OWN rows, with particular emphasis on V3-ACC-09/11/20 and V3-OWN-01/04. A stateful sequence should include organic genesis, direct transfer, fees, later mint, later import, maintenance, partial exit, more fees, and a final ordinary holder exit. Include multiple holders, operator changes and disable/re-enable. Keep the floor in supply; a last ordinary holder exit is not necessarily a zero-supply vault.

Check token conservation without equating unlike tokens: caller input, callback spend, principal receipt, fees, refund/payout, booked change, and unbooked change are separate terms. A fee collected from the pool is no longer unpaid. A user's refund never becomes booked. An import's refunded token goes to its recipient. The remaining holders' booked inventory cannot finance another user's add or opposing exit swap.

Fuzz liquidity/share rounding, token decimals, supply, fee values, token direction, output ordering and representable tick spacings. Include dust initialized ticks and substantial tick crossings in a fixed-input quote. No minimum spacing, new quote step cap, TWAP, tighter price limit, or alternative split solver may be introduced to make tests pass.

Test expectations tied to old reserve issuance, exact-out success, sleeve behavior or SY must be replaced with the corresponding new public behavior and a cited PRD ID; do not merely skip failing tests. Tests of the older prohibited V3 tree retain their own behavior. An integration that depends on a retired function is a recorded compatibility result, not permission to restore the old economics.

The future implementation run must follow `CLAUDE.md`: production artifacts built before tests because the FactoryServices read `out/`, compiling Forge commands use `--use solar`, and `via_ir` is forbidden. Use the current artifact dependency workflow when it applies, preserve the shared cache, and run the affected production/package tests before broader consumer compilation. Verify actual facet runtime sizes as well as successful compilation; the present V3 split explicitly exists to remain deployable. None of these commands has been run for this contribution.

## 10. Measure every economic route against the verified ceilings

**Files:** the proposed Gas suite, with fixture setup shared from the production TestBase. **Authority:** brief gas instruction; V4 plan sections 2, 13 and 16; V4 PRD FS-MONEY-01/FS-A31. Applying the same bar to import is a **plan choice** necessary to cover V3's additional economic route, not a higher allowance.

| Measurement | Acceptance bar |
| --- | --- |
| Standalone public economic call, cold body | At most **11,900,000 gas**; keep **100,000** for transaction overhead. |
| Whole transaction, including any claimed composition | At most **12,000,000 gas**. |
| Public preview | At most **5,000,000 gas**. |

Measure eight economic route families, not a sample: one-sided `exchangeIn` mint, one-token `exchangeIn` exit, pass-through, bundle deposit, bundle exit, `donate`, `compound`, and `importPosition`. The owner-appointment functions are outside the seven-route V4 economic list; they still receive functional tests.

Include first and later mints, both token directions, pull and pretransfer where supported, fee/booked-heavy exits, proportional bundle refunds, one-token and both-token maintenance, empty compound, and first/later NFT imports with both source and destination fees. Measure the imported NFT's transfer, decrease, collect and burn inside the import body. A measurement omitting the burn is not the requested import measurement.

Measure all three `previewExchangeIn` route forms, both bundle previews and `previewImportPosition`, including their meaningful success and zero-result cases. Keep preview data capture out of the timed transaction; a prior preview in the same transaction can warm pool reads. Construct liquidity, fees, NFT ownership and approvals outside the measured body and use demonstrably cold calls. Test dense/dust-tick and large-crossing states as well as ordinary states; a single favorable pool state cannot establish a universal gas bound.

For every measurement retain the route, fixture state, direction, funding mode, cold/warm methodology, body gas, overhead or full-transaction gas, preview gas where applicable, and pass/unresolved status. If claiming compatibility with a composed consumer, measure that complete consumer transaction including its vault calls; standalone gas cannot establish composition gas. Do not import the V4 plan's entire hook redesign or borrowed-unlock machinery as a V3 obligation.

A ceiling failure remains unresolved with its reproducible state. Improve the implementation without changing locked semantics, or report the limitation. Do not raise the ceiling, cap the quote, remove a difficult route, claim a revert is a successful economic operation, or add vault `getRate` to obtain a passing measurement.

## Requirement-to-step check

| Locked requirement | Primary steps |
| --- | --- |
| V3-ACC-01 | 1, 2, 3 |
| V3-ACC-02/03/04 | 3, 4, 5, 6 |
| V3-ACC-05/06 | 3, 4, 7 |
| V3-ACC-07 | 3, 4, 6 |
| V3-ACC-08/09 | 1, 2, 4, 5, 7 |
| V3-ACC-10 | 2, 4, 5, 6, 7 |
| V3-ACC-11 | 2, 4, 5, 6 |
| V3-ACC-12/13 | 3, 5 |
| V3-ACC-14 | 4 |
| V3-ACC-15/16/17 | 1, 5, 8 |
| V3-ACC-18 | 3, 7, 9 |
| V3-ACC-19 | 1, 3, 8 |
| V3-ACC-20 | 3, 4, 6, 9 |
| V3-OWN-01 | 6, 9, 10 |
| V3-OWN-02 | 7, 8, 9, 10 |
| V3-OWN-03 | 1, 4, 5, 7, 8 |
| V3-OWN-04 | 1, 9 |
| V3-OWN-05 | 1, 5, 8 |
| Verified gas instruction | 10 |

# Limits

This is a research contribution based on admitted local files, not a code review, a second PRD, implementation, or proof of correctness. Only the owned response file was authored. No test, build, installation, Git operation, deployment, wallet action, public-source query, peer reading, or sub-agent launch was performed.

The sources were read live and are not an atomic repository snapshot. V4 settlement/callback machinery and the rest of its deployment helper/test implementation were not exhaustively examined because this port must not adopt PoolManager unlock behavior. Dependency helper selection, complete consumer inventory, actual deployability, existing-suite migration, and measured gas remain work for the later authorized implementer.

The verified gas ceilings are documentary requirements, not performance results. The plan carries the accepted same-pool manipulation exposure and the accepted later-mint booked-claim dilution; it does not claim either is removed. All five owner locks remain closed.

This contribution does not authorize implementation.
