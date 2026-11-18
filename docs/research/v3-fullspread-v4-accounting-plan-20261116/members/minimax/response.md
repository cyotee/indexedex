# Member response — minimax

## Identity

| Field | Value |
| --- | --- |
| Member | minimax |
| Profile | research |
| Phase | initial independent response |
| Requested role | council-member |
| Requested model | minimax/MiniMax-M3, admitted adaptive thinking, not a selectable depth |
| Owned output | `docs/research/v3-fullspread-v4-accounting-plan-20261116/members/minimax/response.md` |
| Runtime identity | not exposed |
| Task ID | not exposed |
| Peer responses read | none |

This is a research contribution, not a defect review. It does not authorize implementation, tests, installs, deployment, or Git.

## Question and targets

**Question.** What ordered implementation and test plan must a later author follow so the Uniswap V3 full-spread Standard Exchange vault under `contracts/vaults/standard/exchange/protocols/uniswap/v3/` satisfies the locked PRD, including the owner locks that the empty position NFT is burned and that import may run after supply exists?

**Required targets read.**

- `docs/research/v3-fullspread-v4-accounting-prd-20261116/UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_PRD.md` (locked final, including V3-OWN-01 through V3-OWN-05).
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/` (36 files: 35 Solidity, of which one is the test base, plus 1 Markdown file).
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/` (31 files: 27 Solidity, of which two are under `test/`, plus 4 Markdown files).

**Optional context.** The earlier council run at `docs/research/v3-fullspread-v4-accounting-prd-20261116/` was not read as a vote. Where this response states a requirement, the locked PRD is the authority.

## Evidence

Everything in this section is an observation from a file I read. Inference is labelled as such.

### E1. The locked PRD names twenty accounting requirements and five owner locks

`UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_PRD.md` states `V3-ACC-01` through `V3-ACC-20` under "Adopted requirements" and `V3-OWN-01` through `V3-OWN-05` under "Owner locks". The file header says "Implementation authority: none." The "Scope" section says the PRD governs `contracts/vaults/standard/exchange/protocols/uniswap/v3/` only, does not modify `contracts/protocols/dexes/uniswap/v3/`, and that `V3-OWN-04` applies the accounting only to newly deployed vaults.

### E2. The V4 plan's gas ceilings are 12,000,000 and 5,000,000, with an 11,900,000 standalone body

`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`, section 2, last bullet: "Gas ceilings stay 12,000,000 and 5,000,000. A standalone public money or maintenance call passes only if its cold call body is at most 11,900,000, leaving 100,000 overhead. Fixture setup stays outside that body. Do not warm the measurement with a preview. A composed hook route passes only if the whole transaction, including hook work, is at most 12,000,000. Previews fit 5,000,000. An oversized route is unresolved, not passed. There is no `getRate` read in the measurement."

The same plan, section 16 answer 6, names the standalone economic routes: `exchangeIn` one-sided share mint, `exchangeIn` one-token exit, `exchangeIn` pass-through, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, `compound`. `setOperator` and `setOperatorFor` are explicitly not in the set. Section 13 maps `FS-A31` standalone body to `Money.t.sol`, `FS-A31` preview ceiling to `QuotesAndRate.t.sol`, and `FS-A31` composed transaction to `BufferHookIntegration.t.sol`.

**Inference.** The plan states exactly the ceilings the brief names, so the brief's instruction to adopt them applies without substitution. The V3 port has no hook rows, so only the standalone and preview legs have a V3 analogue.

### E3. The current V3 vault issues shares from a token-reserve book, not from liquidity

`UniswapV3FullSpreadStandardExchangeVaultCommon.sol:624` `_sharesOutForDeposit` delegates to `StandardExchangeConstantProduct._sharesForDeposit` (or `_initialShares` when supply is zero) using `reserve0`/`reserve1`. `_totalVaultReserves` (same file) is `free balance + deployed amount`; `_totalVaultReservesForShareMath` adds collectable center fees on top. The genesis floor is `DEAD_SHARES_SINK` at line 80 (`address(0x...dEaD)`), with `_minimumLiquidity()` at line 639 and `_initialResidualShares` at line 645.

`UniswapV3FullSpreadStandardExchangeVaultInBase.sol:99-102` and `:153-156` mint the dead-sink floor and the residual to `DEAD_SHARES_SINK` on a first deposit, then mint `sharesOut` to the recipient.

### E4. The current V3 vault has a local liquidity sleeve with a permissionless rebalance

`UniswapV3FullSpreadStandardExchangeVaultCommon.sol:658` `_rebalanceLiquidReserveBestEffort`, `:665` `_loadRebalanceSnap`, `:673` `_rebalanceLiquidReserveInternal`, `_deployExcessLiquidity`, `_refillDeficitLiquidity`, `_absoluteFloor`, `_shouldRebalanceToken`, `_targetFree`, `_liveLiquidReservePercentage` (reads `liquidReservePercentageOfVault`). The post-operation rebalance call sites are `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:60`, `:110`, `:164`, `:260`; `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:44`, `:52`, `:61`; `UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol:121`; `UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol:126`.

`UniswapV3FullSpreadStandardExchangeVaultLiquidReserveTarget.sol` exposes `localReserve`, `deployedReserve`, `targetLiquidReservePercentage`, `actualLiquidReservePercentage`, and the permissionless `rebalanceLiquidReserve`. `interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol` declares all of them, including `LocalDepositWhileBlocked`.

`LocalDepositWhileBlocked` is emitted at `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:112`, `:166`, `:167` — that is, the locked-pool local deposit path the PRD retires.

### E5. The current V3 vault's one-sided deposit is a reserve-ratio mint with no pool swap

`UniswapV3FullSpreadStandardExchangeVaultInBase.sol:_executeZapInDeposit` calls `_collectIfIdle()`, computes `sharesOut` from the reserve book, mints, and rebalances. It never calls `pool.swap`. `_previewZapInDeposit` mirrors it. The 49% entry swap of `V3-ACC-05` does not exist in the V3 tree.

### E6. The current V3 exit is reserve-ratio plus a proportional free-balance entitlement

`UniswapV3FullSpreadStandardExchangeVaultInBase.sol:_quoteZapOutAmount` adds `(free0 * sharesBurned) / totalShares` to the managed-withdrawal amount and then quotes a swap of the other side. `_executeFreeZapOutExactIn` calls `_collectManagedFees()` then `_idleZapOutCore`, which burns the centre liquidity, swaps the removed other token plus the free portion, and returns the grown balance plus the free share. `_previewZapOutWithdrawal` (`UniswapV3FullSpreadStandardExchangeVaultOutBase.sol`) is a bounded bisection over that quote, and `_amountInForZapMint` (same file) inverts the reserve book for the exact-out mint.

`UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol` implements `executeZapOutWithdrawal` and `executeZapInMintExactOut`; the latter is the closed-form exact-out mint the PRD retires in `V3-ACC-17`.

### E7. The current V3 exact-out surface is live, and the exact-out preview reverts

`UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:previewExchangeOut` routes to `_quoteSwapOut` (which reverts `UniswapV3Exchange_ExactOutputNotFilled` when the quote is not fully filled), to `_previewZapOutWithdrawal`, or to `_amountInForZapMint`. `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:exchangeOut` executes all three.

### E8. The current V3 Standardized Yield surface is installed on the cut

`UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol` declares `assetInfo` (line 22) and `exchangeRate` (line 25) and inherits `NativeStandardYieldPreviewTarget`, which adds `previewDeposit`, `previewRedeem`, `yieldToken`, `getTokensIn`, `getTokensOut` (`contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol`, `NativeStandardYieldTarget.sol`).

`UniswapV3FullSpreadStandardExchangeVaultInFacet.sol:22` inherits `UniswapV3FullSpreadStandardYieldExecutionTarget`, and its `facetFuncs()` appends the SY execution selectors through `NativeStandardYieldSelectors._appendExecution(funcs)`. `UniswapV3FullSpreadStandardYieldExecutionTarget.sol` implements `_redeemVaultHeld`, the named vault-held share redemption.

`UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol:facetInterfaces()` advertises `type(IStandardizedYield).interfaceId` at index 13 and `type(IStandardExchangeTransitionQuote).interfaceId` at index 12.

`UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol:32` installs `IStandardExchangeTransitionQuote.quoteAssets.selector`; the implementation is `UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol:123`.

### E9. `previewExchangeIn` already has the two-word return the PRD keeps

`lib/crane/contracts/interfaces/IStandardExchangeIn.sol` declares `previewExchangeIn(...) returns (uint256 amountOut, uint256 amountRefunded)` with `@custom:selector 0x89d61912`. The V3 implementation is `UniswapV3FullSpreadStandardExchangeVaultInMultiQueryTarget.sol:11`, returning `(_previewExchangeIn(tokenIn, amountIn, tokenOut), 0)` — the refund word is hardcoded to zero. `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:exchangeIn` likewise returns `(_exchangeIn(...), 0)`.

### E10. The import leaves the empty NFT on the vault, mints no pool liquidity, and refuses a non-empty vault

`UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol` header comment: "Leaves the empty NFT on the vault (does not burn)." `importPosition` (line ~96) rejects with `UniswapV3ExchangeImport_Unavailable` when `totalSupply() != 0` or `UniswapV3FullSpreadStandardExchangeVaultRepo._isPositionCreated()`. `_exitNftAndSleeve` transfers the NFT to the vault, calls `decreaseLiquidity` and `collect`, calls `_createPositionIfNeeded` for the full-range ticks, then computes shares from the reserve book (line 169) and mints the dead-sink floor and residual (lines 171-174). It never mints liquidity into the pool; liquidity deployment happens only through the sleeve rebalance at line 126.

`previewImportPosition` returns one word, `uint256 sharesOut`.

The existing test asserts the custody the PRD retires: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_Import.t.sol:162-163` — comment "Empty NFT retained by vault." and `assertEq(IERC721(address(npm)).ownerOf(tokenId), address(vault));`.

### E11. The V4 reference implementation carries the accounting the PRD copies

`UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:_size` performs one exact-input 49% swap (`FullMath.mulDiv(amount_, 49, 100)`), refuses to swap at or outside the bounds, refunds the whole amount when the swap cannot be quoted or is not fully spent, and calls `Math.sizeOneSided`. `_shares` sets `plan_.failed = true` when supply is zero and added liquidity is at or under `Types.MIN_SHARES`, and otherwise computes `grossShares = Math.claim(plan_.liquidityAdded, supply_, liquidityBefore_)`. `planBundleIn` computes the proportional add and refunds. `planBundleOut` computes the pre-burn fee and booked claims. `planMaintenance` implements the donate and compound shapes.

`UniswapV4FullSpreadStandardExchangeVaultExecution.sol:exchangeIn` reverts `IVault.MinLiquidityNotMet()` when `plan_.failed`, handles the oversized-pretransfer branch before planning, and pays the exit receipt as `grown - feeRemainder + bookedClaim`. `_mint` writes the floor with `ERC20Repo._mint(address(0), Types.MIN_SHARES)`. `_bookExit` moves the remaining holders' fee and booked remainder into the booked ledger.

`UniswapV4FullSpreadStandardExchangeVaultRepo.sol` stores `uint256[2] booked`, `bytes32 callbackHash`, `uint256[2] reserved`, `bool guardHeld`, `bool initialized` under `keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.fullSpread")) - 1`.

`UniswapV4FullSpreadStandardExchangeVaultTypes.sol` sets `FEE_CAP = 3e17` and `MIN_SHARES = 1_000`.

### E12. Crane's `ERC20Repo._mint` does not reject `address(0)` in this tree

`lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:329-347`: `_mint(Storage storage layoutStruct, address recipient, uint256 amount)` writes `layoutStruct.balanceOf[recipient] += amount; layoutStruct.totalSupply += amount;` and emits `Transfer(address(0), recipient, amount)`. There is no zero-address check in that path.

**Inference.** The V4 floor write at `UniswapV4FullSpreadStandardExchangeVaultExecution.sol:_mint` therefore satisfies the outcome `V3-ACC-03` requires ("the vault records `balanceOf(address(0))` of 1,000 and includes that balance in `totalSupply()`" and "The write does not revert"). The binding requirement is the outcome, not the choice of call. A later author should still assert the outcome in a test rather than assume it.

### E13. `reserves()` and `reserveOfToken` on the V3 vault are a free-balance snapshot

`contracts/vaults/basic/MultiAssetBasicVaultTarget.sol` implements `vaultTokens()`, `reserveOfToken(address)` and `reserves()` from `MultiAssetBasicVaultRepo._reserveOfToken`. The V3 vault feeds them through `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:400` `_syncVaultReserves()`, which writes `balanceOf(address(this))` for token0, token1 and the share token. The V4 plan, section 4, states the opposite rule for the V4 family: "`reserves()` and `reserveOfToken` do not add booked or unbooked local balances."

### E14. The pretransfer credit base is the basic-vault reserve snapshot, not a booked ledger

`UniswapV3FullSpreadStandardExchangeVaultCommon.sol:_pretransferCredit` and `_secureTokenTransfer` compute available credit as `balanceOf(address(this)) - MultiAssetBasicVaultRepo._reserveOfToken(token)` via `contracts/utils/LocalCreditLib.sol`. The V4 family instead uses `balance - booked[index] - reserved[index]` (`UniswapV4FullSpreadStandardExchangeVaultExecution.sol:_unbooked`).

### E15. The V3 package cut, factory service and test base are the wiring points

`UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol` declares fifteen facet cuts and fifteen `PkgInit` fields (`IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol`), and `vaultFeeTypeIds()` keys the USAGE fee type on `type(IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve).interfaceId`. `UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol` deploys each facet through CREATE3 from `ArtifactCreationCode`, and `contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol` (176 lines) builds the `PkgInit`, deploys the package through the manager registry, and sets `setDefaultLiquidReservePercentageOfTypeId(type(IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve).interfaceId, DEFAULT_V3_LIQUID_RESERVE_PCT)`.

**Inference.** Removing selectors from the liquid-reserve interface changes its interface id, which is the fee-type key the DFPkg registers and the test base configures. That is a wiring consequence of `V3-ACC-08` that the plan has to schedule, not an afterthought.

### E16. Existing V3 test surface that this work touches

Verified to exist: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/` holds `UniswapV3FullSpreadStandardExchangeVault_Import.t.sol`, `_Routes.t.sol`, `_Previews.t.sol`, `_MultiJoinExit.t.sol`, `_FeeCompound.t.sol`, `_FullRangeBook.t.sol`, `_PretransferParity.t.sol`, `_ReserveReconcile.t.sol`, `_Decimals.t.sol`, `_DFPkg_Deploy.t.sol`, one `*_IFacet_Test.t.sol` per facet, and `harness/UniswapV3FullSpreadStandardExchangeVaultBoundPoolLockSeCaller.sol`. Also `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol`, `.../release/sy/UniswapV3FullSpreadStandardExchangeVault_NativeSY.t.sol`, `.../adversarial/*`, `.../invariants/UniswapV3FullSpreadStandardExchangeVault_Invariant.t.sol`, and the hook rows `test/foundry/spec/hooks/uniswap/v4/standardExchange/*UniswapV3FullSpreadStandardExchangeVault*.t.sol` with `SeMatrix_FullSpreadV3Fixture.sol`.

### E17. The V4 plan's file map, for shape only

`UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` section 3 lists the V4 family files, including a separate `Math`, `Projection`, `SwapProjection`, `Planner`, `Execution` and `ExecutionPreparation`, a `Repo`, an owner-modifier file and a maintenance-modifier file, plus one facet and one target each for money, quote, out, query and callback. Section 14 records these as implementation names, not requirements.

## Assumptions

1. The locked PRD governs. Where this plan says "must satisfy V3-ACC-xx", the PRD text is the requirement and this plan only routes it to a file and a test.
2. The V4 family under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/` is the behavior source for accounting, as the PRD's Scope section states. V4 pool mechanics (PoolManager unlock, `modifyLiquidity`, `StateLibrary`, `Currency`) are not ported; the V3 pool API is.
3. `V3-OWN-04` means the accounting ships only in newly deployed instances of this implementation. No migration, no reclassification of existing supply, no edit under `contracts/protocols/dexes/uniswap/v3/`.
4. The V4 plan's ceilings are adopted as measured in E2, because the plan states the same numbers the brief names.
5. "New vaults only" is read as "the package and its facets change; live instances are not touched." New deployments pick up the new cut; nothing is migrated in place.
6. The V3 vault keeps its ERC-20 share token, its symbol and its 18 decimals. The PRD changes the share math, not the token.
7. The later author is expected to follow the repo's testing law (`contracts/vaults/standard/exchange/protocols/uniswap/v3/UNISWAP_V3_STANDARD_EXCHANGE_REMEDIATION_PRD.md` section 3 and `.agents/skills/indexedex-testing`): real instances, no etching of the system under test, no injected storage, `forge build` before `forge test` because the factory reads creation bytecode from `out/`, and `forge test --use solar`.

## Coverage

What this response covers.

- The full set of twenty `V3-ACC` requirements and five `V3-OWN` locks, each routed to at least one file change and one failing test.
- The two owner locks the question names: burn the empty position NFT (`V3-OWN-01`), and import may run after supply exists (`V3-OWN-01`).
- The eight new V4 selectors that must land on new facets (`V3-OWN-03`).
- The Standardized Yield surface removal (`V3-OWN-05`).
- The new-vaults-only scope (`V3-OWN-04`).
- The gas measurement bar, verified against the V4 plan and adopted.

What this response does not cover.

- No Solidity. No test code. No diff.
- No run of any test, build, forge command, Git command, install, deploy or wallet operation. Every statement about behavior is a reading, not a measurement.
- No proof that the 49% V3 sizing is numerically equivalent to the V4 sizing. That is an implementation-time check with a property test (step 10, T2).
- No decision on the open product questions the PRD already closed; none are reopened here.
- The V3 hook rows under `test/foundry/spec/hooks/uniswap/v4/standardExchange/` are named as affected files, but their internal expectations were not read; the plan says only that they must be re-baselined.

## Conclusions

An ordered plan for a later author. Steps are ordered by dependency: a step may assume every earlier step has landed.

**Convention used throughout.** *Plan choice* marks a step, a file name, a facet grouping or a shape that the PRD does not name and that two careful authors could order differently. Everything else is bound to a PRD ID.

**Naming.** All new-file names below are plan choices. The PRD names no file.

---

### Stage 1 — Package and storage foundation

Land this first. Every later step writes against the ledger, the planner and the cut that this stage creates.

**Step 1 — New V3 family ledger repo.** *(plan choice: file name and file split)*

- Add `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultLedgerRepo.sol`.
- Holds `uint256[2] booked` in `token0`/`token1` order and `uint256[2] reserved` in the same order, under a family storage slot distinct from the V3 position slot and from the V4 slot. *(plan choice: slot derivation and whether the ledger lives in the existing `UniswapV3FullSpreadStandardExchangeVaultRepo.sol` instead of a new file.)*
- Must satisfy `V3-ACC-09`: booked remainders are a vault record, distinct from deployed position liquidity, from accrued but uncollected position fees, and from unbooked ERC-20 balances.
- Must satisfy `V3-ACC-10`: unbooked balance of face *i* is `token.balanceOf(address(this)) - booked[i]`, and it is the pretransfer credit base.

Failing test: after a `donate` that books a remainder, `booked[i]` equals the held balance of face *i* and the balance minus `booked[i]` is the unbooked credit; a later one-token pretransfer of exactly the unbooked credit is accepted and one wei more is not.

**Step 2 — Persist the fixed full-range bounds in the position repo.**

- Change `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultRepo.sol` so the derived centre bounds are written once and read back, instead of being re-derived per call.
- Must satisfy `V3-ACC-01`: for an organic book the one vault-owned position uses `TickMath.minUsableTick` and `TickMath.maxUsableTick` at the bound pool's tick spacing, and those bounds are fixed before the first add.

Failing test: after the first add, the stored lower and upper equal the pool's min/max usable ticks at its spacing, and a later change of the pool's tick spacing cannot move them.

**Step 3 — Reserve the pool-lock gate and the check order.**

- Change `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol` so `_requireCanOpenBoundPoolOps()` is the single gate every execution route that must `swap`, `mint`, `burn` or `collect` passes through, and so the sleeve helpers are removed from it.
- Must satisfy `V3-ACC-15`: while `pool.slot0().unlocked` is false, every such route reverts `UniswapV3Exchange_BoundPoolInteractionBlocked`, and it does not fall back to constant-product issuance, a local pay, or any unlock.
- Must satisfy `V3-ACC-16`: a disabled vault reverts `VaultDisabled` on every execution route except a withdrawal, `donate` and `compound`; views do not revert it.

Failing test: with the bound pool locked, `exchangeIn` (share mint), `exchangeIn` (exit), `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate` and `compound` all revert `UniswapV3Exchange_BoundPoolInteractionBlocked`; `previewExchangeIn` on the same state returns the computed result or zero and does not revert.

**Step 4 — Cut the Standardized Yield surface out of the diamond.**

- Change `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol` (drop `NativeStandardYieldQuoteBase`), `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol` (drop `NativeStandardYieldPreviewTarget`, delete `assetInfo` and `exchangeRate`), `UniswapV3FullSpreadStandardExchangeVaultInFacet.sol` and `UniswapV3FullSpreadStandardExchangeVaultOutMultiFacet.sol` (reparent from `UniswapV3FullSpreadStandardYieldExecutionTarget` to the In/OutMulti targets and drop `NativeStandardYieldSelectors._appendExecution`).
- Delete or empty `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardYieldExecutionTarget.sol`, which exists only to serve the named vault-held redemption.
- Remove `IStandardizedYield.interfaceId` from `UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol:facetInterfaces()`.
- Remove `IStandardExchangeTransitionQuote.quoteAssets.selector` from `UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol:facetFuncs()` and delete `quoteAssets` from `UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol:123`.
- Must satisfy `V3-OWN-05`: the vault does not implement `IStandardizedYield`, `exchangeRate()`, `assetInfo()`, `quoteAssets`, or a vault `getRate()`.
- *(plan choice: the PRD names `quoteAssets` only. The sibling transition-quote selectors `quoteState`, `quoteTransition`, `quoteShareBalance`, `quoteTotalSupply`, `quoteExternalDeposit` and `quoteExternalExchange` are not named by the PRD. Matching the V4 surface exactly would drop them too, because the V4 plan section 5 says its query facet installs only `reserveOfToken` and `reserves`. Either choice is admissible; the PRD-bound part is `quoteAssets` alone.)*

Failing test: the deployed diamond's ERC-165 supports do not include `IStandardizedYield`; a low-level call to `exchangeRate()`, `assetInfo()`, `quoteAssets`, `previewDeposit`, `previewRedeem`, `deposit`, `redeem` and `getRate()` on the vault reverts.

**Step 5 — Recompute `reserves()` and `reserveOfToken` from position plus unpaid fees.**

- Add a V3 query facet and target that install `reserveOfToken` and `reserves` and compute them as the deployed position token amounts plus unpaid position fees. *(plan choice: the file name, and whether to keep the basic-vault facet's `vaultTokens` as the only selector taken from it, as the V4 plan section 5 does.)*
- Stop `_syncVaultReserves()` from writing the free-balance snapshot into `MultiAssetBasicVaultRepo` for the share token, and retire its uses as a share basis.
- Must satisfy `V3-ACC-09`: `reserves()` and `reserveOfToken` report deployed token amounts plus unpaid position fees, and add no free-balance term, no booked term, and no last-committed snapshot.

Failing test: after a `donate` that books a remainder, `reserveOfToken(token0)` is unchanged; after a swap that accrues pool fees, `reserveOfToken(token0)` rises by the unpaid fee and no more.

**Step 6 — New facets for the eight additional V4 selectors.**

- Add facet and target files that carry `previewExchangeBundleInForSingleOut`, `exchangeBundleInForSingleOut`, `previewExchangeBundleOut`, `exchangeBundleOut`, `donate`, `compound`, `setOperator`, `setOperatorFor`. *(plan choice: how many facets and which selectors share one. The PRD requires only that these sit on new facets and are not stuffed into the existing one-token facets.)*
- Add a V3 family interface file carrying the errors and marker events the routes need: `MinLiquidityNotMet()`, `InvalidRoute()`, `InvalidRecipient()`, `EmptyExchange()`, `TokenNotExchangeable()`, `Donation()`, `Compounded()`, `PairDeposited(address indexed caller)`, `PairRedeemed(address indexed caller)`, and the bundle-in and bundle-out error sets. *(plan choice: the file name and the interface layout. The V4 family keeps its bundle interfaces in the same file as the family surface — `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol`.)
- Add an owner-modifier file with `onlyLiveFeeToOwner` (the live `feeTo()` address from the bound oracle) and `onlyLiveFeeToOwnerOrOperator` (that address, a global operator, or a function operator for `msg.sig`). *(plan choice: file name, mirroring the V4 modifier files.)
- Must satisfy `V3-OWN-03`.
- Must satisfy `V3-OWN-01` and `V3-OWN-02` in that the import entry stays and the maintenance entry is added.

Failing test: the deployed diamond exposes all eight selectors and none of them is served by `UniswapV3FullSpreadStandardExchangeVaultInFacet` or `UniswapV3FullSpreadStandardExchangeVaultOutFacet`; a call to `donate` from a stranger reverts `IOperable.NotOperator(address)`.

**Step 7 — Package, factory service and test base.**

- Change `contracts/vaults/standard/exchange/protocols/uniswap/v3/IUniswapV3FullSpreadStandardExchangeVaultDFPkg.sol` (`PkgInit` gains a field per new facet) and `UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol` (`facetCuts()`, `facetInterfaces()`, `facetAddresses()`).
- Change `UniswapV3FullSpreadStandardExchangeVault_Component_FactoryService.sol` to deploy the new facets through the same CREATE3 path.
- Change `contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol` to deploy and bind the new facets.
- Resolve the liquid-reserve interface id consequence noted in E15: `vaultFeeTypeIds()` keys on `type(IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve).interfaceId`, and trimming that interface's selectors changes the key. *(plan choice: keep a minimal dedicated interface holding only `canOpenBoundPoolOps` and `deployedReserve` so the fee-type key is stable, or re-key the fee type and update every consumer of it, including the test base's `setDefaultLiquidReservePercentageOfTypeId` call.)*
- Must satisfy `V3-ACC-08` (the sleeve views and the permissionless rebalance leave the cut; `canOpenBoundPoolOps` stays and stays only the pool-lock gate; `deployedReserve`, if retained, reports position token amounts and is not a share basis and not a sleeve target) and `V3-OWN-03`, `V3-OWN-04`.

Failing test: the package deploys a vault whose ERC-165 support list matches the intended cut exactly; `rebalanceLiquidReserve`, `targetLiquidReservePercentage`, `localReserve` and `actualLiquidReservePercentage` are absent; `canOpenBoundPoolOps` and `deployedReserve` are present.

---

### Stage 2 — Share math and the quote engine

**Step 8 — New V3 math library.**

- Add `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultMath.sol` carrying the pieces of the V4 `UniswapV4FullSpreadStandardExchangeVaultMath.sol` that the accounting needs: `claim`, `netShares`, `proportional`, `singleTokenAdd`, `sizeOneSided`, `amountsForLiquidity`, `liquidityForAmounts`, with the V3 tick and price primitives (`TickMath`, `SqrtPriceMath`, `LiquidityMath`, `UniswapV3Utils`) in place of the V4 ones.
- Must satisfy `V3-ACC-02` (share basis is raw liquidity), `V3-ACC-05` (one exact-input 49% swap, no iteration, no closed-form root, no tick walk), `V3-ACC-07` (greatest proportional liquidity).
- Do not port `quadraticInput`: the PRD lists it among the rejected alternatives.

Failing test: `claim(booked, sharesBurned, supply)` equals `floor(booked * sharesBurned / supply)` at a fuzzed boundary where the division truncates.

**Step 9 — One planner, one execution engine.**

- Add a planner and an execution engine for the V3 family. *(plan choice: file names and whether the planner is a linked library. The V4 family splits the quote engine from the execution engine and calls the same planner from preview and execution; the PRD requires the same coupling — "Preview and execution use this same sizing" in `V3-ACC-05`.)*
- The planner produces a plan for: one-sided mint, bundle mint, one-token exit, bundle exit, pass-through, donate, compound.
- The execution engine applies a plan against the V3 pool using `pool.swap`, `pool.mint`, `pool.burn`, `pool.collect`, paid through the existing `uniswapV3MintCallback` and `uniswapV3SwapCallback` in `UniswapV3FullSpreadStandardExchangeVaultCommon.sol`.
- Must satisfy `V3-ACC-01` (no PoolManager `unlock`, no borrowed unlock, no `unlockCallback`), `V3-ACC-05`, `V3-ACC-06`, `V3-ACC-07`, `V3-ACC-12`, `V3-ACC-13`, `V3-ACC-14`.
- Must satisfy `V3-OWN-03`: this vault does not add `unlockCallback`.

Failing test: the deployed vault has no `unlockCallback` selector, and the V3 callback selectors still satisfy the pool's callback checks.

**Step 10 — Share basis, genesis floor and usage fee.**

- In the planner/execution engine, replace the reserve-book issuance with: on an existing supply, `grossShares = floor(addedLiquidity * totalSupply / existingLiquidity)`, with supply and liquidity read before the add and with idle balances, booked remainders and accrued fees excluded from the denominator; on a burn, `liquidityRemoved = floor(positionLiquidity * sharesBurned / supplyBeforeBurn)`.
- On the first add, require added liquidity greater than 1,000, otherwise the plan fails and the call reverts `MinLiquidityNotMet()` and mints nothing. On success, record `balanceOf(address(0))` of 1,000, include it in `totalSupply()`, and set `grossShares = addedLiquidity - 1,000`.
- Take the usage fee out of `grossShares`: `feeShares = mulDiv(grossShares, clampedFee, 1e18)` with the fee clamped at `3e17` and a zero `feeTo()` giving zero fee shares; mint `feeShares` to `feeTo()` and the remainder to the recipient. A pass-through takes no fee. There is no exit fee.
- Retire `DEAD_SHARES_SINK`, `_minimumLiquidity`, `_initialResidualShares`, `_sharesOutForDeposit` and the `StandardExchangeConstantProduct` import from `UniswapV3FullSpreadStandardExchangeVaultCommon.sol` and `UniswapV3FullSpreadStandardExchangeVaultInBase.sol`.
- Must satisfy `V3-ACC-02`, `V3-ACC-03`, `V3-ACC-04`, `V3-ACC-20`.

Failing tests.

1. First deposit whose added liquidity is exactly 1,000 reverts `MinLiquidityNotMet()` and leaves `totalSupply()` at zero and the depositor with no shares.
2. First deposit that succeeds leaves `balanceOf(address(0)) == 1_000`, `totalSupply() == 1_000 + grossShares`, and the recipient's balance equal to `grossShares` minus `feeShares`.
3. A later deposit computes `grossShares` from pre-add liquidity and pre-mint supply; the same deposit computed from the old reserve book gives a different number, so the test fails against the old code.
4. A fee of `3e17` is clamped to `3e17` and the oracle is not written; `feeTo() == address(0)` yields zero fee shares; the recipient receives `grossShares - feeShares` and no extra mint occurs.

**Step 11 — One-sided mint, boundary and zero-active-liquidity branches.**

- One-sided share mint on established supply: one exact-input `pool.swap` of `floor(processedInput * 49 / 100)` at `TickMath.MIN_SQRT_RATIO + 1` or `TickMath.MAX_SQRT_RATIO - 1`, then `pool.mint` of the liquidity whose rounded-up amounts consume that swap's entire output and no more than the unswapped input.
- If the swap amount is zero, unquotable, not fully spent, produces zero output, or the following mint cannot consume that output, refund the whole processed input, execute no swap, mint nothing, and use no new error. If the caller's minimum is greater than zero, revert `AmountOutNotMet` instead.
- At or outside the bounds, including exactly at either boundary: no swap. If the caller provided the token the position wants, add it with no swap and refund what the add does not take. If the caller provided the other token, refund it and mint nothing.
- Zero active pool liquidity on established supply: refund the whole input, mint nothing.
- Must satisfy `V3-ACC-05`, `V3-ACC-06`.

Failing tests.

1. Established supply, price strictly inside the position: the recorded swap input equals `floor(processedInput * 49 / 100)` exactly, one swap happens, and the add consumes the whole swap output.
2. Established supply, swap unquotable or not fully spent: zero swaps, zero shares minted, the whole processed input refunded to `msg.sender`, and a `minAmountOut > 0` reverts `AmountOutNotMet`.
3. Price exactly at the lower or upper bound: zero swaps; the wanted-token case adds and refunds the remainder, the other-token case refunds everything and mints nothing.
4. Zero active pool liquidity: refund the whole input and mint nothing.

**Step 12 — Bundle deposit.**

- `previewExchangeBundleInForSingleOut` and `exchangeBundleInForSingleOut` add the greatest proportional liquidity the declared amounts support at the current pool price, refund each token the add does not take, and do not run the 49% swap.
- Fees attributable to liquidity that existed before the add are collected and booked, not credited to the caller.
- Shares follow `V3-ACC-02` and `V3-ACC-04`.
- The bundle preview returns the depositor's net shares and a refund word for each input.
- Must satisfy `V3-ACC-07`, `V3-ACC-04`, `V3-ACC-11`.

Failing test: a bundle deposit of deliberately unequal amounts adds the proportional subset, refunds each token's remainder to `msg.sender`, mints the net shares the single-token path would mint for the same proportional liquidity, and performs zero swaps.

---

### Stage 3 — Fees, funding, exits

**Step 13 — Fee collection and booking.**

- Before every share-minting add, snapshot the position's collectable fees attributable to liquidity that already exists, collect them with `pool.burn(lower, upper, 0)` and `pool.collect`, and book the collected amounts into the ledger.
- On a withdrawal, read the collectable centre fees before the burn. The caller's fee claim is `floor(collectableFees * sharesBurned / supplyBeforeBurn)` per token; the caller's booked claim is `floor(booked * sharesBurned / supplyBeforeBurn)`. Leave the remainder with the remaining supply. Split the collected tokens by the pre-burn read, not by a combined balance delta.
- Retire `_collectIfIdle()` as a pre-share-math step in `UniswapV3FullSpreadStandardExchangeVaultInBase.sol` and the proportional free-balance entitlement in `_quoteZapOutAmount` and `_idleZapOutCore`.
- Must satisfy `V3-ACC-11`.

Failing tests.

1. A deposit on a position that has accrued pool fees books those fees; the depositor's share credit is computed from liquidity only, and the booked amount is visible in the ledger.
2. An exit after fees accrue pays the exiting holder `floor(collectableFees * sharesBurned / supplyBeforeBurn)` and leaves the remainder booked for the holders that remain.
3. The same exit pays a fee once, not twice: the exit receipt is not inflated by the free balance that the collect moved in.

**Step 14 — Funding and refunds.**

- On a pull, pull the declared amount from `msg.sender`, then refund the unkept amount of that token to `msg.sender`; output goes to `recipient`.
- On a one-token pretransfer, process only this call's unbooked credit. If the declared maximum is within that credit, use at most the maximum and refund maximum minus used. If the declared maximum exceeds the unbooked balance, spend none of it, mint no shares, do not pull a shortfall; on an empty vault revert `MinLiquidityNotMet()`; on established supply refund the entire unbooked balance; if the caller's minimum is greater than zero revert `AmountOutNotMet` instead of returning a zero output.
- A bundle whose any maximum exceeds that token's unbooked balance reverts before a leg is processed.
- Retire the hardcoded zero refund in `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol` and `UniswapV3FullSpreadStandardExchangeVaultInMultiQueryTarget.sol`, and the rule that spends a staged balance down to what the add needs.
- Must satisfy `V3-ACC-10`.

Failing tests.

1. An oversized one-token pretransfer on an empty vault reverts `MinLiquidityNotMet()` and does not succeed as a refund.
2. The same oversized pretransfer on established supply refunds the entire unbooked balance to `msg.sender`, mints no shares, pulls nothing, and with `minAmountOut > 0` reverts `AmountOutNotMet`.
3. A bundle whose one leg's maximum exceeds that token's unbooked balance reverts with no leg processed, no shares minted and no balance moved.

**Step 15 — One-token exit.**

- Burn the caller's shares only. Pay `recipient` the swap proceeds of that holder's opposing claim, the withdrawn requested-token principal, that holder's requested-token fee portion and that holder's requested booked claim.
- The opposing claim is that holder's unwanted principal, unwanted fee claim and unwanted booked claim. It is not the staying holders' inventory.
- The swap is one exact-input `pool.swap` of that entire opposing amount, quoted after the liquidity removal, at the same price limit as `V3-ACC-05`. If the swap cannot spend the entire opposing amount, execution reverts `AmountOutNotMet` and does not burn shares.
- The preview of a failed plan does not revert; it returns a zero first word. A completable preview returns the receipt execution will pay, so `amountOut` matches execution. `minAmountOut` binds the full receipt.
- Retire `_previewZapOutWithdrawal`'s bisection, `_amountInForZapMint`, `_quoteSwapOut`, `_executeQuotedSwapOut`, `executeZapInMintExactOut` and the sleeve-pay branch in `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol`.
- Must satisfy `V3-ACC-12`, `V3-ACC-11`.

Failing tests.

1. A one-token exit burns exactly `sharesBurned` of the caller's shares and pays a receipt equal to the withdrawn principal plus the requested fee portion plus the requested booked claim plus the swap proceeds.
2. A plan whose opposing amount cannot be fully swapped reverts `AmountOutNotMet`, burns no shares, and moves no tokens; the matching preview returns a zero first word and does not revert.
3. A completable plan's preview `amountOut` equals the execution `amountOut` for the same state.
4. Shares merely delivered to the vault are not exit credit: a holder with zero balance cannot exit.

**Step 16 — Both-token exit.**

- `previewExchangeBundleOut` and `exchangeBundleOut` pay the `V3-ACC-12` claim in both tokens, do not swap, and burn the caller's exact-in share amount.
- The exit is not sized by inverting token reserves, and does not require the two token claims to imply an equal share burn of a requested token amount.
- Must satisfy `V3-ACC-13`.

Failing test: a bundle exit with unequal token claims burns the exact share amount supplied and pays both claims, with zero swaps, and the preview matches execution for both outputs.

**Step 17 — Pass-through.**

- `exchangeIn` from one face to the other is a pass-through: it mints no shares, takes no usage fee, refunds input the swap does not spend, does not rebalance, and `minAmountOut` binds the swap output.
- Must satisfy `V3-ACC-14`, `V3-ACC-08`.

Failing test: a face-to-face `exchangeIn` performs one swap, mints zero shares, burns zero shares, takes no fee, and refunds the unspent input; `totalSupply()` is unchanged across the call.

---

### Stage 4 — Maintenance

**Step 18 — `donate` and `compound`.**

- `donate(token, amount, pretransferred)` and `compound()` follow the locked V4 rules: one-token maintenance uses the 49% shape and books the remainder; both-token maintenance adds in proportion and does not swap.
- The caller is the live `feeTo()` owner, a global operator, or a function operator for that selector. User routes do not call them.
- There is no donation before the first mint: `donate` reverts when `totalSupply()` is zero.
- Permissionless `rebalanceLiquidReserve` is not a substitute; it does not exist after Step 7.
- Booked tokens stay out of reserves.
- A `donate` emits `Donation()`; `compound` emits `Compounded()` only when a deposit is made from collected fees or booked tokens; a compound with nothing to do changes nothing and emits nothing.
- Must satisfy `V3-OWN-02`, `V3-ACC-08`, `V3-ACC-09`.

Failing tests.

1. A one-token `donate` swaps 49% of the processed amount, adds the proportional liquidity, and books the remainder instead of refunding it.
2. A both-token `donate` adds proportionally and performs zero swaps.
3. `donate` before any mint reverts; `donate` and `compound` from a stranger revert `IOperable.NotOperator(address)`; a call from a global operator and from a function operator both succeed.
4. `compound()` with no fees and no booked remainder emits nothing and leaves state unchanged; a qualifying `compound` emits `Compounded()`; every successful `donate` emits `Donation()`.

---

### Stage 5 — Import (the two locks the question names)

**Step 19 — Import as a both-token deposit.**

- Change `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol`.
- The import collects every token amount the NFT yields: both tokens' principal and the fees collected from that position. Those amounts are a both-token deposit under `V3-ACC-07`: the vault adds the greatest proportional liquidity those amounts support and refunds each token the add does not take. The refund goes to `recipient`. The import transfers the overage out; it does not leave it in the vault.
- The import adds liquidity to the vault's existing centre position directly. It does not deploy through the sleeve.
- The import does not use `StandardExchangeConstantProduct`, does not mint the dead-sink floor, and does not rebalance a sleeve. The NFT amounts are the importer's incoming assets, not booked into the destination vault's shared fee balance.
- Fees already owed by the destination position stay under `V3-ACC-11` and are not part of the importer's deposit.
- Must satisfy `V3-OWN-01`, `V3-ACC-07`, `V3-ACC-02`, `V3-ACC-03`, `V3-ACC-04`.

Failing test: an import on a vault with no position adds liquidity to the pool by the amount the imported principal supports, not zero; the import's share credit equals what the same proportional liquidity would mint through `exchangeBundleInForSingleOut`; the overage is refunded to `recipient` and is not left in the vault's balance.

**Step 20 — Burn the empty position NFT.**

- After the tokens are collected, burn the empty position NFT. It is not left on the vault and it is not returned to the owner.
- This reverses the current behavior recorded in E10 and the existing assertion at `UniswapV3FullSpreadStandardExchangeVault_Import.t.sol:162-163`.
- Must satisfy `V3-OWN-01`.

Failing test: after a successful import, the NFT no longer exists (`ownerOf` reverts, or the vault's NFT balance is zero) and the owner does not hold it; the import test's existing "Empty NFT retained by vault" assertion is replaced by this one.

**Step 21 — Import may run after supply exists.**

- Remove the `totalSupply() != 0 || _isPositionCreated()` rejection in `importPosition`.
- A later import is the same proportional add and refund. It does not replace the existing position and it does not reset supply: the centre position's liquidity is increased by the imported amount, the pre-existing liquidity and supply are the denominators, and the genesis floor applies only when the import is the first liquidity.
- Must satisfy `V3-OWN-01`, `V3-ACC-02`, `V3-ACC-03`.

Failing tests.

1. With established supply and an existing centre position, a second import succeeds, increases the position's liquidity, leaves `totalSupply()` equal to the previous supply plus the import's net shares plus the pre-existing floor, and leaves the original position ticks unchanged.
2. The same import on an empty vault is the first liquidity: the 1,000 floor is recorded at `address(0)` and `grossShares` is the added liquidity minus 1,000.
3. A later import does not reset supply: the first holder's share of the position is reduced by the proportional dilution, not rewritten.

**Step 22 — Import preview returns the net shares and both refunds.**

- `previewImportPosition` must report the depositor's net shares and both refunds; the one-word return is not enough.
- The return shape is a plan choice: a three-word tuple `(uint256 sharesOut, uint256 refund0, uint256 refund1)` or a tuple with an array. *(plan choice. The PRD binds the content, not the shape.)*
- This changes the return width of an existing selector. Every consumer of the one-word preview must be migrated. Verified consumers today: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_Import.t.sol` (lines 133, 188, 221, 372) and the IFacet test at `.../UniswapV3FullSpreadStandardExchangeVaultPositionImportFacet_IFacet_Test.t.sol:29`.
- Must satisfy `V3-OWN-01`, `V3-ACC-19` (the same two-word discipline applies to `previewExchangeIn`).

Failing test: the preview's shares equal the executed `importPosition`'s shares for the same state, and the preview's two refund words equal the refunds actually transferred to `recipient`.

---

### Stage 6 — External preview and exact-out closure

**Step 23 — `previewExchangeIn` semantics.**

- Keep the selector and its two-word return.
- For a share-minting route the first word is the depositor's net shares.
- For a one-token exit the first word is the `V3-ACC-12` receipt, or zero when the plan cannot spend the opposing amount.
- The second word is the refund.
- The external rate provider keeps calling `previewExchangeIn`; the provider's non-empty call prices `totalSupply` shares through the exit preview and ignores the refund word; the provider's empty-supply call inverts a one-unit mint preview. Both outcomes — a zero rate when the exit plan cannot spend the opposing amount, and a zero rate when a first deposit would not exceed the floor — stand as the PRD states. No fallback rate is added, and no return word becomes NAV.
- Must satisfy `V3-ACC-19`, `V3-ACC-12`.

Failing tests.

1. A share-minting preview's first word equals the net shares the execution mints to the recipient, and its second word equals the refund actually paid.
2. An exit preview on a completable plan equals the execution receipt; on an uncompletable plan it returns zero and does not revert.
3. A first deposit that would not exceed the floor previews zero shares, and the provider reads a zero rate rather than a substituted number.

**Step 24 — Fail-closed exact-out.**

- `previewExchangeOut` returns zero and does not revert with a vault error.
- On an enabled vault, `exchangeOut` reverts `ExchangeOutNotAvailable()` and moves no tokens.
- On a disabled vault, `exchangeOut` reverts `VaultDisabled`.
- Neither selector gains a refund word.
- Must satisfy `V3-ACC-17`, `V3-ACC-16`.

Failing test: on an enabled vault `previewExchangeOut` returns zero and `exchangeOut` reverts `ExchangeOutNotAvailable()` with unchanged balances; on a disabled vault `exchangeOut` reverts `VaultDisabled`, not `ExchangeOutNotAvailable`.

**Step 25 — No manipulation control is added.**

- The 49% entry swap, the one-token exit swap and a one-token maintenance swap stay same-pool swaps. No `maxZapTickMove`, no TWAP check, no tighter price limit, no new fee cap is introduced, and the price limits stay `TickMath.MIN_SQRT_RATIO + 1` and `TickMath.MAX_SQRT_RATIO - 1`.
- Must satisfy `V3-ACC-18`.

Failing test: the price-limit arguments observed at the pool for all three swap kinds equal those constants, and no TWAP or tick-move guard is present in the vault.

---

### Stage 7 — Tests and gas measurement

**Step 26 — Retire or rewrite the tests that assert retired behavior.**

The following existing files assert behavior the PRD retires and must be rewritten or deleted, not left failing:

- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_Import.t.sol` — the NFT custody assertion at lines 162-163, the one-word preview reads at lines 133, 188, 221, 372, and the "import is unavailable on a non-empty vault" expectations.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_Routes.t.sol`, `_Previews.t.sol`, `_MultiJoinExit.t.sol`, `_FeeCompound.t.sol`, `_FullRangeBook.t.sol`, `_PretransferParity.t.sol`, `_ReserveReconcile.t.sol` — reserve-book share expectations, sleeve rebalance expectations, and locked-pool local-deposit expectations.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg_Deploy.t.sol` and every `*_IFacet_Test.t.sol` — the cut changes in Steps 4, 5 and 6.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/sy/UniswapV3FullSpreadStandardExchangeVault_NativeSY.t.sol` and `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol` — the Standardized Yield surface is removed under `V3-OWN-05`; these suites are deleted and replaced by a negative surface suite.
- `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/invariants/UniswapV3FullSpreadStandardExchangeVault_Invariant.t.sol` and `.../adversarial/*` — the share basis and the pool-lock gate change, so the handlers and assertions must be rebased on liquidity-based accounting.

*(plan choice: the file split of the new suites below. The PRD names no test file.)*

**Step 27 — New suites.**

| Suite | Covers | PRD IDs |
| --- | --- | --- |
| `UniswapV3FullSpreadStandardExchangeVault_Accounting.t.sol` | share basis, genesis floor, usage fee, one-sided mint, boundary, zero-active-liquidity, bundle deposit | V3-ACC-02..07, V3-ACC-20 |
| `UniswapV3FullSpreadStandardExchangeVault_Fees.t.sol` | pre-add fee collection and booking, pre-burn fee read, booked claim | V3-ACC-11 |
| `UniswapV3FullSpreadStandardExchangeVault_Funding.t.sol` | pull and refund, pretransfer budget, oversized pretransfer, bundle over-max | V3-ACC-10 |
| `UniswapV3FullSpreadStandardExchangeVault_Exit.t.sol` | one-token exit receipt, failed-plan revert, bundle exit, pass-through | V3-ACC-12..14 |
| `UniswapV3FullSpreadStandardExchangeVault_Maintenance.t.sol` | donate and compound shapes, permissions, events | V3-OWN-02, V3-ACC-08, V3-ACC-09 |
| `UniswapV3FullSpreadStandardExchangeVault_ImportAccounting.t.sol` | import as bundle deposit, NFT burn, import after supply, preview width | V3-OWN-01, V3-ACC-07 |
| `UniswapV3FullSpreadStandardExchangeVault_Surface.t.sol` | absence of `getRate`, `exchangeRate`, `assetInfo`, `quoteAssets`, SY selectors; exact-out fail-closed; preview tuple; no `unlockCallback` | V3-OWN-03, V3-OWN-05, V3-ACC-17, V3-ACC-19 |
| `UniswapV3FullSpreadStandardExchangeVault_Gas.t.sol` | the standalone routes and the previews | see Step 28 |

Each suite builds a real instance through the manager registry and the shared `TestBase_UniswapV3FullSpreadStandardExchangeVault`, with no etching of the vault and no injected storage. A property test asserts `supply == floor(addedLiquidity * supplyBefore / liquidityBefore) + feeShares` across a fuzzed liquidity and supply range, and a second asserts that the booked ledger never exceeds the vault's face balance and that the unbooked balance is never negative.

**Step 28 — Gas measurement.**

Adopt the V4 plan's ceilings as measured in E2, without substitution:

- Transaction ceiling **12,000,000**.
- Preview ceiling **5,000,000**.
- A standalone public money or maintenance call passes only if its cold call body is at most **11,900,000**, leaving 100,000 overhead. Fixture setup stays outside the body. The measurement is not warmed by a preview. An oversized route is unresolved, not passed.

Measure each of the seven standalone routes named in the V4 plan section 16 answer 6, each in its own cold call: `exchangeIn` one-sided share mint, `exchangeIn` one-token exit, `exchangeIn` pass-through, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, `compound`. `setOperator` and `setOperatorFor` are not measured, as the V4 plan states.

Measure the previews against the 5,000,000 ceiling: `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`, `previewExchangeOut`, and `previewImportPosition`.

The V4 plan's composed-route measurements have no V3 analogue, because V3 has no hook rows. *(plan choice: whether to name V3 composed rows. If the coordinator wants parity, the rows to name are the existing `test/foundry/spec/hooks/uniswap/v4/standardExchange/*UniswapV3FullSpreadStandardExchangeVault*.t.sol` files; the V4 plan section 12 gives the per-row shape.)* *(plan choice: whether `importPosition` and `previewImportPosition` also get a standalone measurement. The V4 list does not include an import because V4 has none. Recommended, because the import is the only V3-only execution route and it does a collect, a mint and a burn.)*

**Step 29 — Build and run order.**

Run `forge build` before `forge test`, because the factory service reads creation bytecode from `out/` (see `contracts/vaults/standard/exchange/protocols/uniswap/v3/UNISWAP_V3_STANDARD_EXCHANGE_REMEDIATION_PRD.md` section 2 and the repo's Foundry rules). Run the V3 full-spread suites with `forge test --use solar`; `via_ir` is forbidden.

---

### Step 30 — Scope discipline, checked last

- No file under `contracts/protocols/dexes/uniswap/v3/` is edited. *(V3-OWN-04)*
- No existing instance is migrated or repointed. *(V3-OWN-04)*
- No `unlockCallback` is added. *(V3-OWN-03, V3-ACC-01)*
- No `IStandardizedYield`, `exchangeRate`, `assetInfo`, `quoteAssets` or vault `getRate` survives; `previewExchangeIn` survives with its two-word return. *(V3-OWN-05, V3-ACC-19)*
- The import stays, burns the empty NFT, and may run after supply exists. *(V3-OWN-01)*
- `donate` and `compound` follow the locked V4 rules. *(V3-OWN-02)*
- The additional V4 selectors are on new facets. *(V3-OWN-03)*
- The gas bar is 12,000,000 / 5,000,000 with an 11,900,000 standalone body. *(E2)*

Failing test: a repository check that the diff touches nothing under `contracts/protocols/dexes/uniswap/v3/`, and the surface suite of Step 27 that asserts the absence of every retired selector.

---

## Limits

1. Static reading only. No test was run, no build was run, no forge command was executed, no gas number was measured. Every behavioral claim is a reading of the cited file, not an observation of execution.
2. The gas ceilings are adopted from the V4 plan (E2) and are not verified by measurement. Whether any V3 route fits under 11,900,000 is unknown until Step 28 runs. An oversized route is unresolved, not passed.
3. The PRD's wording on the genesis floor — "It does not use `ERC20Repo._mint` or any other path that reverts `ERC20InvalidReceiver` for `address(0)`" — reads as forbidding a reverting path, since Crane's `ERC20Repo._mint` in this tree does not reject `address(0)` (E12) and the V4 execution uses exactly that call (E11). I have treated the binding requirement as the outcome — `balanceOf(address(0)) == 1_000`, included in `totalSupply()`, no revert — and flagged the mechanism as a plan choice. If the coordinator reads the sentence as a literal prohibition of `ERC20Repo._mint`, the V4 reference itself would not satisfy it, and that reading needs adjudication before Step 10 is implemented.
4. The V3 hook rows under `test/foundry/spec/hooks/uniswap/v4/standardExchange/` were located but not read. Step 26 names them as affected; their internal expected amounts will have to be re-baselined against the new accounting, and I cannot say which specific assertions break.
5. The `IStandardExchangeTransitionQuote` sibling selectors (`quoteState`, `quoteTransition`, `quoteShareBalance`, `quoteTotalSupply`, `quoteExternalDeposit`, `quoteExternalExchange`) were not read as a consumer surface. Step 4 names only `quoteAssets`, which the PRD names; whether the siblings survive is a plan choice the coordinator should confirm, because dropping them changes the diamond's ERC-165 support list and the DFPkg's advertised interface ids.
6. The fee-type key consequence in Step 7 (E15) is an inference from reading `vaultFeeTypeIds()` and the test base. I did not enumerate every consumer of `type(IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve).interfaceId` outside the V3 tree, so the blast radius of re-keying it is not bounded here.
7. Numeric equivalence between the V4 `Math.sizeOneSided` sizing and a V3 port of it is assumed, not proven. The V4 math operates on V4 sqrt-price and tick primitives; the V3 port substitutes `TickMath`, `SqrtPriceMath`, `LiquidityMath` and `UniswapV3Utils`. Step 10's property test is the check that must carry this.
8. This contribution does not authorize implementation. It states what a later author must satisfy and how to test it. It does not replace the locked PRD, and it does not decide any product question the PRD has already closed.
