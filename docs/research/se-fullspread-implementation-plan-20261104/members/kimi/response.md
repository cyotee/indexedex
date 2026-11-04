# Kimi initial independent response

## Identity

- Run: `se-fullspread-implementation-plan-20261104`.
- Member: `kimi`.
- Profile: research.
- Phase: initial independent response.
- Requested role: council-member.
- Requested model and reasoning: `kimi-coding/k3.1-pro:high`, global route.
- Runtime identity: not exposed.
- Task ID: not exposed; none invented.
- Peers read before submission: no.

## Question and targets

Write the complete implementation and testing plan for `UniswapV4FullSpreadStandardExchangeVault` from the current PRD, specific enough that an implementer can build and test it without making a product decision. The target is only `docs/research/se-fullspread-implementation-plan-20261104/members/kimi/response.md`. The plan does not authorize implementation.

## Evidence

- Read the whole current PRD, revision `fullspread-se-prd-rewrite-20261103`, including FS-OWN-01 through FS-OWN-33, FS-FACET-01/02, FS-PKG-01/02, FS-MONEY-01, FS-UNLOCK-01/02/03, FS-HOOK-01/02/03/04, FS-TEST-01/02/03/04, FS-A01 through FS-A39, and inventory rows 010 through 054: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`.
- Read the 2026-11-04 owner overrides: empty `Donation()` and `Compounded()` events, live-owner global and function operator appointment, widened disable with deadline first, and FS-TEST-04 as the closed 45-row inventory: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`.
- Read the binding unbooked-balance, declared-maximum, contract-caller, and parked-share rules: `docs/vaults/PRETRANSFER_DIRECTIVE.md`.
- Read the accepted scalar and bundle ABIs, including the in-place 64-byte `previewExchangeIn` and `exchangeIn` returns and the unchanged selectors: `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`.
- Read the six fail-closed 32-byte gates, three one-word ABI bindings, and the complete textual occurrence index (1,626 occurrences in 618 files): `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` and `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md`. The index is cited, not reproduced.
- Read S1-GAS-01's retained meter: 100,000 gas reserved for intrinsic and fixed money-method calldata, a measured call-body maximum of 11,900,000, a 12,000,000 transaction ceiling, and a 5,000,000 preview ceiling: `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, lines 954-966. Its step caps, fallback modes, and preflight work errors are not carried into this family.
- Read `IOperable`: `setOperator(address,bool)` is `0x558a7297`, `setOperatorFor(bytes4,address,bool)` is `0x755dbe7c`, and grants use the canonical global/function model: `lib/crane/contracts/access/operable/IOperable.sol`.
- Read `ERC20Repo._mint`: it writes `balanceOf[recipient] += amount` and `totalSupply += amount` directly and emits `Transfer(address(0), recipient, amount)` without calling the zero-receiver-reverting `_increaseBalanceOf`: `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol`.
- Read the live V2 disable predicate, `if (address(tokenIn) != address(this)) _requireNotDisabled();`: `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol`. The later full-spread lock widens that predicate and moves deadline validation before it.
- Read the factory lifecycle in `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol`: its constructor installs `POST_DEPLOY_HOOK_FACET`, deployment invokes package and proxy post-deploy hooks, and `postDeployFacetCuts()` removes the temporary facet. The imported filename is `lib/crane/contracts/factories/diamondPkg/PostDeployAccountHookFacet.sol`.
- Confirmed all seven matrix behavior files named in FS-TEST-04 exist under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`.

## Assumptions

There are no open product assumptions. The PRD and dated locks supply the economics and behavior. Section 19 chooses names where the PRD deliberately left identifiers or filenames open; those are implementation names, not new requirements. Existing canonical ERC-20, ERC-2612, ERC-5267, vault, WETH, operable, factory, registry, and PoolManager components remain the shared infrastructure. No peer response, coordinator draft, or another member's file was read.

## Coverage

The Conclusions section contains the 19 required headings in order. It includes the complete file map, package fields and initialization, storage, selector cut, every family mutator's check order, all money routes, maintenance, both unlock paths, one shared quote engine, events/errors, operators, disable, hook and preview migration, gas measurement, every FS-A row, every 010-054 row, and traceability for every requested requirement family. It adopts the brief's locked readings without alternatives or reopened questions.

## Conclusions

### 1. Authority

This is an implementation and testing plan only. It does not authorize implementation, deployment, a registry migration, a PRD edit, a hook-economics redesign, or a claim of audit clearance. An implementer following a later explicit authorization must preserve the locks below rather than treat this plan as a second product authority.

### 2. Sources and precedence

Apply authorities in this order:

1. Dated 2026-11-04 locks in the PRD and the same-dated override section of `IMPLEMENTATION_PLAN_BLOCKERS.md`.
2. Remaining 2026-11-03 overrides and earlier still-operative PRD locks, with FS-OWN-30 governing exits.
3. `docs/vaults/PRETRANSFER_DIRECTIVE.md` for every `pretransferred` call.
4. `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` for scalar and bundle ABIs, except where a later full-spread lock replaces it.
5. `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` and `INDEX.md` for return-width migration scope. F13 is accepted; the old principal-only F14 reading is not.
6. Crane factory/package conventions and current production-first test infrastructure.
7. S1-GAS-01 only for the retained gas ceilings and meter. PairToken economics, quote work caps, withdrawal fallback, zap caps, ratio/quarter-cap compound, SY, and native caller payout are not inherited.
8. Weir only for money operations expressly restated in the PRD, never for its multi-vault manager, treasury fee, sleeve, auto-compound, or administration surface.

A stale status line, an old expected-blocked cell, or a historical deleted-vault row is not a lock and not passing evidence.

### 3. Adopted readings

- A pass-through is an exact-input underlying-to-underlying pool swap at `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. It is not the FS-OWN-33 liquidity-targeting calculation and mints no shares or usage-fee shares.
- A planned manager action is one `swap` or one `modifyLiquidity`. A one-sided deposit uses two sequential unlocks when it swaps and adds, settling and relocking the first before the second. It does not use one unlock per public call.
- A one-sided deposit, one-token `donate`, or one-token `compound` uses FS-OWN-33: choose the greatest liquidity the following add accepts, derive the exact-input swap from the other-token amount and processed-token amount that add consumes, and leave rounding remainder in the input token. No 48%, half-swap, tick-move, or price cap is added.
- A share-minting deposit books `feesAccrued`; it never swaps or credits those existing fees to the new depositor. An exit measures supply, liquidity, unpaid fees, and booked balances before burning and pays only the exiting holder's FS-OWN-30 claim.
- A bundle pretransfer shortfall is checked across both declared maxima before any leg. It reverts without spending or minting, with no new error or pinned new selector.
- `Donation()` and `Compounded()` are empty marker events. There is no `Donation` interface or interface ID. PoolManager events carry amounts; the vault does not duplicate them.
- Maintenance authorization is the live `feeTo()` proxy address, a global operator, or a function operator for `msg.sig`. Only the live owner appoints or revokes operators. Stored-owner modifiers are not used.
- Disable blocks every execution route except a share-in/underlying-out withdrawal, `donate`, and `compound`. Deadline expiry reverts first. Views never revert `VaultDisabled`.
- FS-TEST-04 is the complete audit inventory. Every yes, no, negative, and integration-only disposition stays as written; no audit ID is added.
- Genesis uses `ERC20Repo._mint(address(0), 1_000)`, not `_increaseBalanceOf` or the shared facet path. The floor is in supply but outside `grossShares` and the usage-fee base.
- Raw V4 liquidity is the sole issuance and burn reserve unit. Token decimals never scale shares. There is no local sleeve, booked-balance term in `reserves()`, vault `getRate`, `rateAsset`, ERC-4626 `asset`, or ERC-5115 surface.

### 4. File map, including Crane files and family files

Create the family under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`:

- `interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol` and `interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol`.
- `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol`.
- `UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol`.
- `UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol`.
- `UniswapV4FullSpreadStandardExchangeVaultTypes.sol`.
- `UniswapV4FullSpreadStandardExchangeVaultRepo.sol`.
- `UniswapV4FullSpreadStandardExchangeVaultMath.sol`.
- `UniswapV4FullSpreadStandardExchangeVaultProjection.sol`.
- `UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol`.
- `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol`.
- `UniswapV4FullSpreadStandardExchangeVaultExecution.sol`.
- `UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation.sol`.
- `UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers.sol` and `UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.sol`.
- For each of Money, Quote, Out, Query, and Callback, `UniswapV4FullSpreadStandardExchangeVault<Role>Facet.sol` and `UniswapV4FullSpreadStandardExchangeVault<Role>Target.sol`. Do not create SY files or shortened target names.
- `test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol` and the seven specs named in section 17 under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.

Create the reusable Crane pairs under `lib/crane/contracts/protocols/dexes/uniswap/v4/aware/`:

- `IUniswapV4ProtocolAware.sol`, `UniswapV4ProtocolAwareRepo.sol`, and `UniswapV4ProtocolAwareFacet.sol` for the seven architecture addresses.
- `IUniswapV4SinglePositionAware.sol`, `UniswapV4SinglePositionAwareRepo.sol`, and `UniswapV4SinglePositionAwareFacet.sol` for the instance `PoolKey`, ticks, salt, and position read.
- Crane specs `lib/crane/test/foundry/spec/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAware.t.sol` and `UniswapV4SinglePositionAware.t.sol`.

Reuse, rather than reimplement, the canonical ERC-20, ERC-2612, ERC-5267, `MultiAssetStandardVaultFacet`, `MultiAssetBasicVaultFacet.vaultTokens`, `WETHAwareRepo`, `OperableRepo`, EIP-712, registry, and factory components. Only `vaultTokens` comes from `MultiAssetBasicVaultFacet`; the family Query facet implements `reserves` and `reserveOfToken`.

The factory file `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` establishes that ERC-165, loupe, ERC-8109, and `PostDeployAccountHookFacet.sol` are factory-owned. Exclude all four from package inputs, cuts, linked components, and package interface aggregation while testing their intended final-proxy availability or post-deploy removal.

Add one FullSpread matrix row beside each of the seven behavior contracts listed in FS-TEST-04, using the row filenames defined in section 17. Do not weaken existing family assertions. Update stale V4 FullSpread evidence in the five FS-TEST-04 evidence files while preserving V3 rows.

### 5. Package, initialization, and validation

Declare `PkgInit` and `PkgArgs` on `IUniswapV4FullSpreadStandardExchangeVaultDFPkg`. Use this binding order:

1. `erc20Facet`, `erc2612Facet`, `erc5267Facet`, `basicVaultFacet`, `standardVaultFacet`.
2. `moneyFacet`, `quoteFacet`, `outFacet`, `queryFacet`, `callbackFacet`.
3. `uniswapV4ProtocolAwareFacet`, `uniswapV4SinglePositionAwareFacet`.
4. `poolManager`, then the six chosen architecture fields `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, `universalRouter`.
5. `registry`, `oracle`, `diamondFactory`.
6. `linkedLibraries` as `address[6]` for Math, Projection, SwapProjection, Planner, Execution, ExecutionPreparation.
7. `weth`.

All seven architecture addresses are package immutables. `bindingHash` covers every field, including every facet, library, architecture address, registry, oracle, factory, and WETH. No `wrappedNative`, `rateAsset`, `maxZapBps`, `maxZapTickMove`, SY facet, or hook-allowlist field exists.

`PkgArgs` contains exactly `PoolKey poolKey`, `string name`, and `string symbol`. `deployVault(PkgArgs)` uses the bound IndexedEx registry. `calcSalt` and `processArgs` use delegatecall, immutable bindings, and self calls. `processArgs` requires both `msg.sender == registry` and `address(this) == diamondFactory`, otherwise `NotCalledByRegistry`.

Deploy facets and packages through the component FactoryService and CREATE3; deploy instances through the registry/factory path. Do not CREATE3 the PoolManager in the package or hardcode Robinhood addresses.

Validation is atomic and leaves no usable partial diamond:

- `InvalidComponent` for a missing/code-empty component or mismatched family linked-component hash, and for any cut containing `getRate` or `rateAsset`.
- `InvalidPoolKey` unless the bound manager reports the pool initialized and `hooks == address(0)`. Accept any initialized hookless pool; add no tick-spacing, inherited-domain, or token-behavior restriction.
- `InvalidInitializationContext` for a proxy/package/argument mismatch and `AlreadyInitialized` for a second initialization.
- Reject no absent `rateAsset`, wrapped-native, or zap argument; those arguments do not exist.

During the single `initAccount` delegatecall:

- Initialize ERC-20 name, symbol, 18 decimals, and zero supply; initialize EIP-712 with the share name and version `"1"`, leaving nonces at zero.
- Derive ERC-20 faces in PoolKey order, substituting `weth` for native currency0, and initialize basic/standard vault state. Preserve that order for `vaultTokens` and bundle arrays; compute `contentsId` from the registry-compatible sorted copy.
- Call `WETHAwareRepo._setWeth(weth)`.
- Write all seven package-immutable architecture addresses into `UniswapV4ProtocolAwareRepo` once; do not create per-vault duplicates.
- Write the full PoolKey, `TickMath.minUsableTick`, `TickMath.maxUsableTick`, and `bytes32(0)` into `UniswapV4SinglePositionAwareRepo`.
- Do not store a rate provider, designated rate asset, local sleeve target, or `feeTo()` owner. Do not mint or create the position at initialization; the first accepted deposit does both.

### 6. Storage

Use the implementation namespace `indexedex.vaults.standard.exchange.uniswap.v4.fullSpread`; the slot is `bytes32(uint256(keccak256(abi.encode(namespace))) - 1)`. Test inequality with PairToken and Wings slots.

The family Repo contains only family state:

- `initialized` and the active public-operation/reentrancy state.
- The committed callback hash and one-shot callback state.
- Operation reservations and settlement context needed across callbacks, cleared before external return.
- `bookedBalance0` and `bookedBalance1`, in actual PoolKey currency units and PoolKey order. These combine collected fees and all booked remainders with no fee-origin store.

Booked balances exclude pending caller input, reserved refunds, reserved exit allocations, and unbooked transfers. A pretransfer reads only unbooked held balance, never these booked balances. A share-minting deposit adds actual `feesAccrued` to booked balances. An exit deducts only the exiting holder's allocated booked claim and fee claim, leaving the rest booked. Maintenance writes the actual post-deposit held remainder, including a stray transfer admitted by that maintenance operation. No booked amount appears in `reserves()` until deployed.

Use the shared Repos for ERC-20 supply/balances, EIP-712, vault configuration/token faces, WETH, operator grants, architecture addresses, and position identity. Do not duplicate `feeTo()`, architecture addresses, PoolKey, ticks, salt, or share supply in the family Repo. Do not add a local reserve snapshot, NAV/rate field, fee-origin ledger, second share ledger, second position, or sleeve.

### 7. Selector cut

Build the manifest from facet metadata and test the reviewed cut through the proxy; do not reuse the old count of 61.

- ERC-20 facet: the nine canonical token/metadata selectors.
- ERC-2612 facet: `permit`, `nonces`, `DOMAIN_SEPARATOR`; ERC-5267 facet: `eip712Domain`.
- Standard Vault facet: `vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig`.
- `MultiAssetBasicVaultFacet`: only `vaultTokens`.
- Family Query facet: `reserves`, `reserveOfToken`, plus the two operator queries `isOperator` and `isOperatorFor`.
- Money facet: `exchangeIn`, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, `compound`, plus `setOperator` and `setOperatorFor`.
- Quote facet: `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`.
- Out facet: `previewExchangeOut`, `exchangeOut`.
- Callback facet: `unlockCallback`.
- Crane Protocol Aware and Single Position Aware facets: all their stored-component and position getters, externally callable on the vault.

Advertise `IStandardExchangeIn` as `0x59fb2971`, derived from `0x89d61912 ^ 0xd02d3063`; never advertise `0x8c8035da` or `0x676ec907`. Recheck bundle IDs `0x2576ed1a` and `0xb40c1ba3` with `type(I).interfaceId` before registration. Advertise `IOperable` as `0xa7f11160`. `previewExchangeIn` and `exchangeIn` return two words; bundle functions use the accepted tuple/array returns. `exchangeOut` and `previewExchangeOut` keep their old return widths.

Do not install family `poolManager` or `poolKey`, `rateAsset`, `getRate`, `basket`, `wrappedNative`, `localReserves`, `previewWithdrawalMode`, `previewZapCredit`, `maxZapBps`, `maxZapTickMove`, `depositPair`, `previewDepositPair`, `redeemPair`, `previewRedeemPair`, `WithRefund` siblings, ERC-4626 `asset`, or any SY selector. Do not install transition/context/exact-output quote interfaces without a separate FS-HOOK-04 requirement. Factory-owned facets and `PostDeployAccountHookFacet.sol` are absent from package cuts.

### 8. Check order for each public mutator

The order below makes deadline and disable behavior deterministic. Canonical ERC-20 `approve`, `transfer`, `transferFrom`, and `permit` retain their canonical checks and do not enter vault economics.

**`exchangeIn`:**

1. If `block.timestamp > deadline`, revert `DeadlineExceeded(deadline, block.timestamp)` before any other route work.
2. Classify withdrawal structurally as share `tokenIn` and a supported underlying ERC-20 face `tokenOut`. If disabled and not that withdrawal, revert `VaultDisabled(address(this))`; this blocks deposits and pass-throughs.
3. Reject zero/vault recipient with `InvalidRecipient`, identical input/output with `InvalidRoute`, zero amount with `EmptyExchange`, zero or unsupported tokens with `TokenNotExchangeable`, and any other unsupported route with the inherited exact-input route error.
4. Validate ordinary amount and share authority. Output goes to `recipient`; refunds go to `msg.sender`. On the borrowed path require caller code, `pretransferred == false`, self-funded input, and caller-owned shares on exit. A value-bearing call fails at the nonpayable ABI boundary.
5. Read `TransientStateLibrary.isUnlocked`. Locked dispatch uses section 11's per-action unlocks. Unlocked dispatch first verifies initialized, idle, empty callback hash, zero reservations, and zero own backing-currency deltas; a reentrant borrowed entry is `ReentrantOperation`, while the other context failures use their specified inherited error or an unnamed revert.
6. Run the shared Planner projection and the selected pass-through, one-sided deposit, or one-token exit actions. Enforce net scalar output against `minAmountOut`; a one-token exit failure is `AmountOutNotMet` and leaves shares unburned after rollback.
7. Settle each action, pay recipient and refunds, book fees/remaining-holder balances, mint or burn only at successful finalization, clear reservations/guard, and verify the required locked relock or borrowed per-address zero deltas.

**`exchangeBundleInForSingleOut`:**

1. Deadline first; disabled vault second (`VaultDisabled`).
2. Validate recipient, `amountsIn.length == vaultTokens().length`, nonzero aggregate input, and `tokenOut == address(this)`. Unsupported argument combinations revert `ExchangeBundleInForSingleOutNotAvailable`; length and empty-input failures use the accepted interface errors.
3. For pretransfer, require a contract caller and verify each declared maximum is covered by that token's unbooked held balance before any pull, swap, liquidity leg, or mint. Any shortfall reverts unnamed, spends nothing, and mints nothing. For pull, transfer every declared amount from `msg.sender` before processing.
4. Require locked manager dispatch; if already unlocked, revert `ManagerAlreadyUnlocked`.
5. Execute exactly one proportional `modifyLiquidity` with no balancing swap, book returned fees, compute gross/net shares and per-token refunds, enforce `minAmountOut`, mint, refund payer, emit `PairDeposited(msg.sender)`, and clear the operation.

**`exchangeBundleOut`:**

1. Deadline first.
2. Exempt from disable only when `tokenIn == address(this)` and `tokensOut` is exactly the two underlying ERC-20 faces, in either caller order. Every other disabled call reverts `VaultDisabled`.
3. Validate recipient, nonzero share amount, aligned `tokensOut`/`minAmountsOut` lengths, no duplicate outputs, and the exact supported share-to-both-faces route. Unsupported combinations revert `ExchangeBundleOutNotAvailable`; structural failures use accepted interface errors.
4. Burn authority is always `msg.sender`'s shares; parked vault shares are not credit, and `pretransferred` does not make vault-held shares spendable. Bundle exit requires locked dispatch; an already-unlocked manager reverts `ManagerAlreadyUnlocked` rather than using the canonical-only borrowed exception.
5. Snapshot and apportion before burn, execute one liquidity removal without a swap, enforce each `MinAmountNotMetAt(index, min, actual)`, pay both tokens, book the remaining holders' fee/booked claims, burn at successful finalization, emit `PairRedeemed(msg.sender)`, and return zero share refund.

**`exchangeOut`:** deadline first; if disabled revert `VaultDisabled`; if enabled revert `ExchangeOutNotAvailable()` without securing funds or changing state. Do not substitute preview or route validation for those two outcomes.

**`donate`:** enter the public-operation guard; require the three-arm maintenance authorization; reject an already-unlocked manager with `ManagerAlreadyUnlocked`; require `totalSupply > 0` before any swap; validate token as share or one vault face and process the directed amount under pretransfer/pull rules. Do not apply registry disable and do not add a deadline. Share donation burns only caller-owned shares and performs no withdrawal or share swap. Underlying donation enters section 10's combined maintenance flow. Emit `Donation()` on every success and `Compounded()` only if liquidity is added.

**`compound`:** enter the guard; require the same maintenance authorization and locked manager; do not apply disable or accept input/deadline. Collect and process existing fees/booked balances under section 10. With no fees and no booked remainder, return with no state change or event.

**`setOperator` and `setOperatorFor`:** require `msg.sender == address(VaultFeeOracleQueryFacet(oracle).feeTo())` at call time; neither a stored owner nor an operator can appoint. Write only `OperableRepo` and emit the canonical event. These administration calls do not mint, burn, or enter PoolManager execution.

**`unlockCallback`:** accept only the bound PoolManager, only while the matching public operation holds the guard, only with the exact committed operation/payload hash, and only once. Consume the hash before execution. Any other caller, stale payload, replay, or external unlock reverts without moving tokens.

### 9. One-sided deposit, bundle deposit, one-token exit, both-token exit, and pass-through

**One-sided deposit (`underlying -> share`).** Secure the declared input under FS-OWN-32. Use SwapProjection to find the greatest acceptable following liquidity add and its required other-token output and processed-token input; the resulting exact-input swap amount is derived from that add, not fixed at half and not confused with the processed-token amount consumed by the add. Execute the swap at the direction's unbounded price limit, settle/relock, then execute the add in a second locked action when necessary. Book the add's `feesAccrued` and do not include them in deposit principal, share credit, or the swap.

For first supply, require `addedLiquidity > 1_000`, set `grossShares = addedLiquidity - 1_000`, and mint the separate floor through `ERC20Repo._mint(address(0), 1_000)`. For later supply, compute `grossShares = addedLiquidity * supplyBefore / existingLiquidityBefore`, with no fee, idle, or booked term in the denominator. Read `usageFeeOfVault(address(this))`, clamp to `3e17`, and compute `feeShares = mulDiv(grossShares, clampedFee, 1e18)` when live `feeTo()` is nonzero. Mint only `feeShares` to that collector and `grossShares - feeShares` to `recipient`, skipping zero mints. Supply grows by `grossShares` plus the first-deposit floor only. Enforce the caller minimum against net recipient shares.

Refund unkept declared input to the payer. Pull calls refund `declared - used`; pretransfer within the unbooked maximum refunds `maximum - used`; an overstated one-token maximum refunds the entire unbooked balance, spends none of that unbooked excess, and pulls no shortfall. No `IncompleteConversion` check exists.

**Bundle deposit (`underlying[] -> share`).** Require positional amounts in `vaultTokens()` order and share output. Secure both declarations atomically. Add the proportional matched pair in one `modifyLiquidity`, with no balancing swap. Book `feesAccrued`; calculate actual added liquidity and gross/net shares exactly as above; refund each unused declared token to the payer; emit `PairDeposited`. The bundle remainder is refunded, never booked. First-deposit floor and fee behavior are identical to one-sided entry.

**One-token exit (`share -> one underlying`).** Before burn, snapshot `S`, `L`, unpaid fee-owed `F_i` excluding already booked tokens, and booked `B_i`. For `s` shares compute, with full-precision multiply then floor division:

- `removedLiquidity = L * s / S`.
- `feeClaim_i = F_i * s / S`.
- `bookedClaim_i = B_i * s / S`.

Remove only `removedLiquidity`. Let the withdrawn principal in each token be `principal_i`. Pay the selected token's `principal + feeClaim + bookedClaim` plus actual conversion output. Sell the entire opposing `principal + feeClaim + bookedClaim` in one exact-input swap at the unbounded limit. Do not sell any other holder's principal, fees, or booked balance. If complete conversion or the caller minimum fails, revert `AmountOutNotMet`; rollback leaves shares unburned and no residual paid, booked, or kept by the exiter. Reconcile actual collected fees without counting booked tokens twice, and book all remaining holders' fee and booked claims.

**Both-token exit (`share -> both underlying`).** Use the same pre-burn snapshot and formulas, remove the same liquidity, and pay each token's principal plus fee and booked claims in caller-specified output order. Check each minimum with `MinAmountNotMetAt`. Perform no swap, book the rest, burn only on success, and emit `PairRedeemed`.

**Pass-through (`underlying -> other underlying`).** Secure the exact input and perform one exact-input swap on the bound hookless pool at the unbounded directional limit. Pay `recipient`, return `(amountOut, amountRefunded)`, and do not add/remove liquidity, mint shares, charge usage fee, or invoke FS-OWN-33. It is disabled as a non-withdrawal and may use canonical borrowed unlock dispatch.

### 10. `donate` and `compound`

Both functions are owner/operator maintenance and never called implicitly by deposit, withdrawal, or `exchangeIn`.

- `compound` accepts no donation. `donate` accepts share or one vault token, a directed amount, and `pretransferred`; it also compounds. A share donation burns caller shares without pool withdrawal or share conversion and mints nothing.
- Collect current trading fees through the appropriate `modifyLiquidity` action and combine them with previously booked balances and, for `donate`, the directed underlying donation. Never swap the deployed position.
- If the combined maintenance balance holds only one token, use the same FS-OWN-33 SwapProjection as one-sided entry and the same unbounded price limit. Swap that combined one-token balance toward the position ratio; do not take an opposing token outside that balance. Book any input-token remainder.
- If it holds both tokens, do not swap. Determine scarcity relative to the position ratio, fully use the proportionally scarcer token, and make one proportional add. Book the actual held post-add balance, not a calculated residual; this captures excess and stray held tokens admitted to the operation.
- Best effort is one straightforward secure sequence. A failed step reverts; there is no retry, fallback, swallowed error, or remainder-size threshold. A remainder alone does not revert and is processed by a later maintenance call.
- Empty `compound` returns unchanged with no event. Successful `donate` always emits `Donation()`, even without an add. Any add from collected fees or booked tokens emits one empty `Compounded()`, including an add during `donate`. There is no fee-origin store or amount-bearing vault maintenance event.

### 11. Locked and borrowed unlock paths

**Locked path.** After ordinary checks, each planned `swap` or `modifyLiquidity` commits `keccak256(abi.encode(operation, payload))`, calls `unlock` once, accepts one matching callback only from the bound manager while the operation guard is active, settles that action, and verifies relock before the next action. Consume the callback hash before execution. Keep the public-operation guard active across all actions, token calls, refunds, and payouts. `unlockCallback` cannot become a deposit, and an external unlock cannot satisfy a committed hash. Bundle routes, `donate`, and `compound` use only this path and preflight-reject an already-unlocked manager with `ManagerAlreadyUnlocked`.

**Borrowed canonical `exchangeIn`.** When the bound manager is already unlocked:

1. Require initialized and idle vault state, empty callback hash, zero reservations, and zero own backing-currency deltas. These four precondition failures revert unnamed; do not relabel them `ReentrantOperation` or `SettlementMismatch`. A reentrant borrowed operation specifically reverts `ReentrantOperation`.
2. Require caller code, self-funded input, caller-owned burn shares, `pretransferred == false`, and the ordinary recipient/route/minimum/deadline/disable authority checks. No allowlist, foreign payer, callback payload, or foreign creditor is accepted.
3. Dispatch to the same Planner, action, account, and settlement internals as locked execution. Do not call `unlock` or `unlockCallback`, do not run `compound`, and do not apply the locked callback's global `getNonzeroDeltaCount` requirement.
4. Touch only this diamond's hookless PoolKey and its full-range salt-zero position. A one-token exit removes the caller fraction and swaps exactly the FS-OWN-30 opposing claim.
5. For each currency debt, sync immediately before transfer/value settlement, settle, then take credits. Never `settleFor` a foreign address or rely on an outer actor's sync checkpoint. Native sync occurs immediately before exact-value settle.
6. Before return, assert zero for every currency delta touched by this diamond, per address. Outer hook/router deltas may remain nonzero. Inability to close this diamond's own deltas without a foreign credit reverts `SettlementMismatch`.
7. Any failure restores this call's shares, liquidity, bookings, and token effects. An outer caller that catches the revert still owns its separate settlement; no sleeve fallback exists.

### 12. Quotes and previews

Use `UniswapV4FullSpreadStandardExchangeVaultPlanner` as the single mathematical quote engine for previews and execution. It consumes Math, Projection, and SwapProjection and produces the same route actions and integer apportioning that Execution consumes. The stored Quoter address is architecture metadata, not permission to substitute a step-capped external quote. Add no 64-step cap, tick-spacing rule, partial fill, `QuoteWorkLimit`, or preview-only impact check.

- `previewExchangeIn` returns `(amountOut, amountRefunded)` with selectors and parameters unchanged. Mint routes quote net shares after the same clamped fee and never credit existing fees to the depositor. A one-token exit runs the same pre-burn apportionment and swap calculation, so output matches execution from the same state. A pass-through quotes the same exact-input swap. Refund previews assume declarations are available, do not transfer, and do not read balances; execution refunds may differ without waiving exit-output equality.
- `previewExchangeBundleInForSingleOut` returns net shares and per-input refund quotes in `vaultTokens()` order. It performs no balance read and uses the same proportional add and fee/netting math.
- `previewExchangeBundleOut` uses the same pre-burn principal/fee/booked apportionment as both-token execution, returns outputs in caller order without a swap, and returns zero share refund.
- For a structurally malformed or unsupported preview, return zero-valued results without a coded vault revert: bundle-in uses a zero `amountsRefunded` array of `amountsIn.length`; bundle-out uses a zero `amountsOut` array of `tokensOut.length` and zero refund. `previewExchangeOut` always returns zero and gains no refund word. A zero preview is not an execution promise.
- Views do not revert because the manager is busy or unlocked. `reserveOfToken` returns zero for an unknown token. `reserves` and `reserveOfToken` return live removable position token amounts at current price/ticks plus unpaid fees owed, using existing position-amount and fee-owed reads. They exclude booked and unbooked local balances. `positionLiquidity` wraps `StateLibrary.getPositionInfo` for the diamond, stored ticks, and salt against PoolManager, not StateView or PositionManager.
- `vaultTokens` remains PoolKey currency0/currency1 order with WETH substituted for native. No `getRate`, `rateAsset`, NAV substitute, SY exchange rate, or vault-held rate-provider address is installed. External rate-provider previews read the 64-byte tuple.

### 13. Events and errors

Emit only the locked family events and existing shared/protocol events:

- `PairDeposited(address indexed caller)` on bundle deposit and `PairRedeemed(address indexed caller)` on bundle exit; no additional arguments.
- Empty `Donation()` on every successful `donate`; empty `Compounded()` on every maintenance liquidity add. No `Donation` interface or new amount-bearing maintenance event.
- Canonical ERC-20 `Transfer` for mint/burn, canonical operator status events, and PoolManager `Swap`/`ModifyLiquidity` with this vault as `sender` for amounts, price, and liquidity. No duplicate vault swap/liquidity event.

Family errors are `InvalidUnlockedContext`, `SettlementMismatch`, `ManagerAlreadyUnlocked`, `ReentrantOperation`, `InvalidRoute`, `MinLiquidityNotMet`, and `InvalidRecipient`. Use accepted interface errors including `DeadlineExceeded`, `VaultDisabled`, `AmountOutNotMet`, `EmptyExchange`, `TokenNotExchangeable`, `ExchangeInNotAvailable`, `ExchangeOutNotAvailable`, `AmountsLengthMismatch`, `ExchangeBundleInForSingleOutNotAvailable`, `TokenAmountsLengthMismatch`, `DuplicateOutput`, `MinAmountNotMetAt`, and `ExchangeBundleOutNotAvailable`; use `NotOperator` for failed operator authority.

Do not declare a bundle-shortfall error. Borrowed initialized/idle/hash/reservation failures may be unnamed reverts and are not `ReentrantOperation` or `SettlementMismatch`. Do not declare `IncompleteConversion`, `QuoteWorkLimit`, `ExchangeInWithRefundNotAvailable`, `UnderlyingUnavailable` for the closed borrowed case, `InsufficientRateSupply`, `RateNormalizationOverflow`, `RateUnavailable`, or `MinAmountNotMet` for these routes.

### 14. Operators

Read the bound `PkgInit.oracle` through `VaultFeeOracleQueryFacet.feeTo()` at each protected call. The returned `IFeeCollectorProxy` address is the live owner; this vault exposes no `feeTo()` getter and stores no initialization-time owner.

- `onlyLiveFeeToOwner`, in `UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers.sol`, alone gates `setOperator(address,bool)` and `setOperatorFor(bytes4,address,bool)`. Appointment and revocation write `OperableRepo`; do not use `MultiStepOwnableRepo._onlyOwner`.
- `onlyMaintenanceAuthorized`, in `UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.sol`, accepts exactly three arms: caller is the current live `feeTo()` address, `OperableRepo.isOperator(caller)`, or `OperableRepo.isOperatorFor(msg.sig, caller)`. Do not inherit `OperableModifiers.onlyOwnerOrOperator`.
- A global operator may call both `donate` and `compound`. A function operator may call only its granted selector; a grant for the other selector or a stranger reverts. Only the live owner can change grants, including after an owner change.

### 15. Disable

Reuse the V2 predicate's share-input exception, widened to every execution route and reordered by the newer deadline lock:

- Canonical `exchangeIn` is exempt only for share input and one underlying output. Underlying-to-underlying pass-through and underlying-to-share deposits revert `VaultDisabled` when disabled.
- Bundle deposit reverts. Bundle exit is exempt only for share input and exactly both underlying outputs. `exchangeOut` is not a withdrawal and reverts `VaultDisabled` when disabled, versus `ExchangeOutNotAvailable` when enabled.
- `donate` and `compound` remain executable under their maintenance authorization.
- Every deadline-bearing route checks expiry before disable. Views, including previews and reserve reads, never revert `VaultDisabled`.
- Apply the same predicate on borrowed unlock: buffered withdrawals may proceed; buffered non-withdrawals revert before manager actions.

### 16. Hook integration, matrix rows, and 32-byte preview migration

Use each current package interface without adding hook fields:

| Family | Required FullSpread row and proof |
| --- | --- |
| `single/` | FullSpread as the one buffered SE; borrowed canonical `exchangeIn` through `beforeSwap`, both exact-input directions. This is not a two-vault proof. |
| `constantProduct/single/` | FullSpread as buffered SE, one pair token, one raw token; name the converting leg and do not imply the raw leg converts without fixture evidence. |
| `dual/` | Canonical FS-HOOK-02 two-SE fixture with disjoint backing pools. |
| `orbital/` | Valid `se0/se1/se2` and `rp0/rp1/rp2` bind, FullSpread on one leg and another SE share on another, with roles named. |
| `weighted/` | At least a 2-leg and one larger supported setup up to 8 legs; rate each FullSpread leg. |
| `stable/quad/curve/` | Four valid legs; never treat the volatile FullSpread share as a peg. |
| `stable/quad/balancer/` | A 2-leg and a 5-leg setup using dynamic arrays, not the fixed-four constructor. |

The canonical dual fixture configures FullSpread as the buffered leg with an external `IStandardExchangeRateProviderDFPkg` instance for this vault and one target. The other SE is not asked to mint/redeem inside the outer unlock; use a raw token or accepted share transfer where necessary. Use different backing PoolKeys, execute exact-input `zeroForOne` and `oneForZero`, and assert balances, position owner/ticks/salt, and per-address deltas. Add one rate-target row per underlying and two pools holding the same vault at different targets. This vault supplies no `getRate` and knows no provider.

An identity bind of `token == this vault` is attempted and, if rejected for lack of `asset()`, recorded under FS-HOOK-04 rather than passed. Exact-output calls fail closed; an identity route that never calls `exchangeOut` is separate. Same-backing-pool sequential composition remains unverified. A required route defect in this family is fixed here; a missing quote interface, `asset()` requirement, `SameToken`, pair-overlap, or denomination reject outside FS-OWN-29 gets a cited FS-HOOK-04 record with consumer, selector, arguments, and revert, not a stub or hook redesign.

For the ABI migration, use `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` as the complete textual occurrence inventory; do not paste it. Update `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`, both frontend ABI bindings, every typed or raw one-word `previewExchangeIn` reader (including calls ignoring the word), and every one-word `exchangeIn` decoder to the accepted tuples. Change the six production gates to require/decode the 64-byte preview success and use `amountOut`: the two Standard Exchange rate-provider paths, wrapped rate-provider target, common/mixed stable buffer hook targets, and common weighted buffer hook target. Migrate `contracts/test/bases/FundedThresholdAssertions.sol` as well. Preserve selectors and ERC-165 IDs. Validate ordinary hook ERC-165-gated fallback to standard previews; do not add transition/context quote stubs.

Replace stale V4 FullSpread matrix evidence in `hook-se-matrix.json`, `hook-se-matrix-findings.json`, `hook-se-matrix-finding-descriptions.json`, `docs/audits/apex-2026-09-17-evidence.md`, and `acceptance.json` R10.3 only from current passing row evidence. Preserve V3 rows and judge each composed route on its whole transaction below 12,000,000 gas.

### 17. Test plan

**Harness and execution.** Build `TestBase_UniswapV4FullSpreadStandardExchangeVault` on `IndexedexTest` and the canonical native-wrapper base, using current parent setup order. Deploy the real PoolManager through the artifact-backed CREATE3 helper, real facets/package/registry through production factory paths, and the hook and vault on the same manager. Bootstrap only through accepted public entries. Use current mintable funding tokens outside the SUT; never mock, etch, inject storage, or `vm.mockCall` the vault, PoolManager, facets, registry, or factories. Use default Foundry profile, `viaIR=false`, and current code limits. Test Crane facets in Crane with real storage and a real manager. Snapshot tests assert pre/post state before restore; receipt logs alone are not proof.

Define suite aliases under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`:

- **P:** `UniswapV4FullSpreadStandardExchangeVaultPackage.t.sol`.
- **M:** `UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol`.
- **N:** `UniswapV4FullSpreadStandardExchangeVaultNative.t.sol`.
- **Q:** `UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol`.
- **C:** `UniswapV4FullSpreadStandardExchangeVaultCallbacks.t.sol`.
- **U:** `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol`.
- **B:** `UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol`.

Add these concrete row specs beside their respective behavior contracts:

- **H1:** `single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchange.t.sol`.
- **H2:** `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchange.t.sol`.
- **H3:** `dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchange.t.sol`.
- **H4:** `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchange.t.sol`.
- **H5:** `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchange.t.sol`.
- **H6:** `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchange.t.sol`.
- **H7:** `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchange.t.sol`.

Also run the two Crane aware specs from section 4. Every money assertion compares supply, holder balances, position liquidity/owner/ticks/salt, booked and reserved custody, wrapper balances, and per-address deltas as applicable, not merely token movement.

**FS-A mapping.**

| Row | Test file(s) | Required assertion |
| --- | --- | --- |
| FS-A01 | P, Crane aware specs | Exact reviewed cut, forbidden-selector absence, callable Crane/factory surfaces, factory disjointness. |
| FS-A02 | P | Every facet/library/infrastructure/WETH binding changes `bindingHash`. |
| FS-A03 | P | All named invalid deploy/init contexts revert atomically; absent argument classes create no rejection path. |
| FS-A04 | P | Namespace slot differs from PairToken and Wings. |
| FS-A05 | M | First public deposit creates the one position, rejects `<=1_000`, direct `_mint` floor, net fee issuance, no performance fee. |
| FS-A06 | M | Bundle deposit/redeem mappings, paired payout, no exit swap or PairToken issuance formulas. |
| FS-A07 | M | Pull/pretransfer refunds, no booked/minted remainder, booked deposit fees, no `IncompleteConversion`. |
| FS-A08 | M, U | Exact FS-OWN-30 one-token claim conversion or no-burn `AmountOutNotMet`; both-token claim without swap. |
| FS-A09 | Q | Zero exact-out preview and enabled `exchangeOut` locked revert, unchanged balances and old return widths. |
| FS-A10 | N | WETH-only caller boundary, native wrap/unwrap only at pool, no native caller receipt/payout. |
| FS-A11 | M | No implicit compound; exit pays only caller claim and books rest; no collection-only fallback. |
| FS-A12 | Q | `exchangeRate` and SY selectors absent. |
| FS-A13 | Q | `getRate` absent. |
| FS-A14 | Q | `InsufficientRateSupply` absent. |
| FS-A15 | Q | No planner observation through `getRate`; unsupported previews follow FS-OWN-19. |
| FS-A16 | Q, M | Issuance reads neither `exchangeRate` nor `getRate`. |
| FS-A17 | C | One unlock/callback per action across multi-action routes, replay rejection, continuous guard; borrowed zero unlocks. |
| FS-A18 | C | Non-manager callback reverts without token movement. |
| FS-A19 | U | Borrowed canonical call performs zero unlocks, own deltas close, global count may remain, position identity holds. |
| FS-A20 | U | Non-self-funded/pretransferred borrowed calls fail as locked; value fails nonpayable boundary. |
| FS-A21 | U | Unlocked flag supplies neither input nor burn authority. |
| FS-A22 | U | Bundle/donate/compound `ManagerAlreadyUnlocked`; paired and SY selectors absent. |
| FS-A23 | U | Reverting borrowed call restores shares, liquidity, bookings, and token balances. |
| FS-A24 | B, H1, H3 | Attempt identity bind and record any `asset()` reject; never add `asset()` to pass. |
| FS-A25 | B, H1-H7 | Buffered mint/burn while unlocked, hook/unwrap recipients, fee handling, external provider rows. |
| FS-A26 | B, H3 | Disjoint-pool exact-input both directions with full balance/position/delta assertions. |
| FS-A27 | B, H1-H7 | Each topology has its expressible proof or cited FS-HOOK-04 record; FS-A26 still required. |
| FS-A28 | B | Hook exact-out call reverts and pays neither token. |
| FS-A29 | Q, B, H4-H7 | No vault rate; configured provider per target and two pools with different targets read tuple. |
| FS-A30 | B | Evidence explicitly does not mark same-backing-pool sequential composition passed. |
| FS-A31 | M, U, B, H1-H7 | Gas meter below; every claimed composed route and preview fits; oversized route is unresolved. |
| FS-A32 | Q | No coded economic-view revert while busy/unlocked; deployed reserves include unpaid fees and no local snapshot. |
| FS-A33 | U | Borrowed/locked economic parity from same state, no compound, sleeve, fallback, or performance fee. |
| FS-A34 | U | Nonzero own entry delta reverts; only own deltas close and outer debts remain. |
| FS-A35 | N, U | Native sync immediately before settle, no double counting or foreign sync credit, WETH caller face. |
| FS-A36 | U | Outer caught failure restores vault and preserves outer caller's separate settlement obligation. |
| FS-A37 | U | Funded non-hook contract succeeds without an allowlist. |
| FS-A38 | M, U, B | Every disable exception/non-exception, deadline first, views, buffered routes; enabled exact-out separately. |
| FS-A39 | M | Live owner appointment, global/function arms, stranger/other-selector rejection, no stored-owner gate. |

**010-054 inventory mapping.** Rows marked no remain no; integration-only rows remain integration-only. Mapping a no row to P records that no unrelated regression test is added, while the listed nearest suite guards any named adjacent behavior. No new audit identifier is introduced.

| Row | Test file(s) | Disposition implemented in tests |
| --- | --- | --- |
| 010 | M | Direct transfer never becomes redeemable idle or caller credit. |
| 011 | M, U | Own/borrowed entry and exit cannot over-mint. |
| 012 | U | No Wings quote test; borrowed parity is covered with 011. |
| 013 | P, M | Generic ERC-4626 `deposit` absent; pre-existing balance mints nothing. |
| 014 | H4-H7 | Integration only: every rated hook treats FullSpread through its configured provider, never as unrated raw liquidity. |
| 015 | H6 | Integration only: Curve join/exit accounting remains hook scope, not claimed as a vault fix. |
| 016 | M | No separate weighted-hook test; first-deposit inflation is covered by 034. |
| 017 | P | No Balancer caller-router callback case added. |
| 018 | P | No Balancer `computeBalance` case added. |
| 019 | Q | Negative: enabled `exchangeOut` reverts `ExchangeOutNotAvailable`; never use disabled fixture. |
| 020 | P | No DETF mint/bond pricing case added. |
| 021 | P | No Balancer DETF bond pricing case added. |
| 022 | M, U | Same borrowed-path loop as 011, referenced to both rows without a second mechanism. |
| 023 | M | No permissionless sleeve placement; live owner/global/function operator only, stranger rejected; accepted authorized sandwich is not claimed absent. |
| 024 | M, U | Swap exactly the exiting FS-OWN-30 claim, never staying inventory; quantity, not price-cap, test. |
| 025 | P | No Wings rebalance/loss-cap case added. |
| 026 | Q | No separate Wings 512-step test; this vault's dust-tick liveness is 041 with no spacing rule. |
| 027 | P | No staking withdrawal queue case added. |
| 028 | B, H3 | Dual identity-leg attempt cannot burn caller position and pay zero. |
| 029 | Q, B | Negative: no `getRate` or bound full-book provider; pumped external provider is not vault rate. |
| 030 | H6, H7 | Integration only: Balancer phantom-fee LP remains pool scope, not a vault-fix claim. |
| 031 | P | No Balancer virtual-TTA join case added. |
| 032 | P | Shared-factory deployment leaves no unprivileged post-deploy selector. |
| 033 | P | No DETF primary redemption case added. |
| 034 | M | Direct transfers plus zero-address floor prevent first-deposit inflation. |
| 035 | P | No Aave cross-version loop case added. |
| 036 | M, B | A staged pretransfer cannot become a later caller's credit. |
| 037 | P | No frozen legacy-vault re-enable case added. |
| 038 | P | No sDETF staking-weight case added. |
| 039 | M | Pretransfer maximum and parked-share rules; overstated bundle maximum reverts before legs, spends nothing, mints nothing, with no new pinned selector. |
| 040 | M | Pool donation then compound cannot round a later deposit to dust shares. |
| 041 | M, Q | Seeded dust ticks do not freeze normal deposit/redeem through an undocumented cap; no cap added. |
| 042 | P | Deployment succeeds with a token whose `approve` returns no bool; no typed Permit2 requirement. |
| 043 | H4 | Integration only: orbital radius pinning remains hook scope. |
| 044 | M, Q | Netted fee shares, 30% clamp, no extra mint/dilution round trip, net previews/minimum, including 0.001% precision. |
| 045 | M, U, B | Full disable matrix, deadline first, allowed withdrawals/maintenance/views, disabled exact-out behavior. |
| 046 | P | No Balancer composite-router settlement case added. |
| 047 | M | No Stata case; nearest vault donation/dust case is 040. |
| 048 | M | Empty compound no-op; empty `Compounded()` on qualifying add; empty `Donation()` on success; booked remainder never freezes later route. |
| 049 | Q | Negative: exact-out absent with enabled locked revert, not a Camelot equality check. |
| 050 | Q | No truncated TWAP dependency introduced; previews use the shared mathematical engine. |
| 051 | M, Q | Nonzero preview and execution use the same engine; no unexecuted impact check or step cap rejects execution. |
| 052 | P | Standard signer `permit` works after init with share-name EIP-712 domain and version `"1"`. |
| 053 | P | No Crane ownership-transfer buffering change or test added. |
| 054 | B, H1-H7 | Every unwrapping hook approves the vault and completes exit; missing approval cannot freeze the user. |

**Gas measurement.** For each supported public money/maintenance route, use a cold external call and reserve 100,000 gas for intrinsic plus fixed money-method calldata. Measure the call body with `gasleft()` immediately around the external call; it must be at most 11,900,000, so the conservative whole transaction is at most 12,000,000. Measure previews with a 5,000,000 local ceiling. For every hook-composed route, measure the entire composed transaction, including both vault operations and hook work, below 12,000,000; do not report only the vault's inner body. Cover first/later deposits, one/both-token exits, pass-through, maintenance with one/two-token balances, native/wrapped settlement, borrowed multi-action routes, dust ticks, fee-growth currencies, initialized crossings, and boundary remainder cases. An oversized composed route is recorded as an unresolved narrowed route, not passed and not waived. Do not import S1-P07's work-budget errors or preflight rejection behavior.

### 18. Traceability

**Core requirement identifiers.**

| Identifier | Plan section(s) |
| --- | --- |
| FS-OWN-01 | 4, 5, 7, 12 |
| FS-OWN-02 | 4, 5, 7, 12 |
| FS-OWN-03 | 5, 7, 12, 16 |
| FS-OWN-04 | 3, 6, 9, 10 |
| FS-OWN-05 | 5, 7, 12 |
| FS-OWN-06 | 5, 6, 12 |
| FS-OWN-07 | 6, 7, 12 |
| FS-OWN-08 | 7, 12, 16 |
| FS-OWN-09 | 7, 8, 9, 10, 13 |
| FS-OWN-10 | 5, 7, 12 |
| FS-OWN-11 | 3, 5, 6, 9 |
| FS-OWN-12 | 3, 6, 9, 10 |
| FS-OWN-13 | 8, 11 |
| FS-OWN-14 | 8, 10, 13, 14 |
| FS-OWN-15 | 9, 11 |
| FS-OWN-16 | 5 |
| FS-OWN-17 | 5, 6, 9, 11 |
| FS-OWN-18 | 5, 12 |
| FS-OWN-19 | 8, 12, 15 |
| FS-OWN-20 | 6, 8, 9 |
| FS-OWN-21 | 8, 10 |
| FS-OWN-22 | 5, 12 |
| FS-OWN-23 | 7 |
| FS-OWN-24 | 9, 12 |
| FS-OWN-25 | 9 |
| FS-OWN-26 | 8, 11, 15 |
| FS-OWN-27 | 6, 9 |
| FS-OWN-28 | 8, 15 |
| FS-OWN-29 | 12, 16 |
| FS-OWN-30 | 9, 12 |
| FS-OWN-31 | 11 |
| FS-OWN-32 | 8, 9, 10, 12 |
| FS-OWN-33 | 3, 9, 10, 12 |
| FS-FACET-01 | 4, 5, 7 |
| FS-FACET-02 | 4, 7 |
| FS-PKG-01 | 4, 5 |
| FS-PKG-02 | 5 |
| FS-MONEY-01 | 8, 9, 10, 11, 12, 17 |
| FS-UNLOCK-01 | 8, 11 |
| FS-UNLOCK-02 | 8, 11 |
| FS-UNLOCK-03 | 8, 11 |
| FS-HOOK-01 | 16 |
| FS-HOOK-02 | 16, 17 |
| FS-HOOK-03 | 13, 16 |
| FS-HOOK-04 | 16 |
| FS-TEST-01 | 17 |
| FS-TEST-02 | 4, 17 |
| FS-TEST-03 | 17 |
| FS-TEST-04 | 16, 17 |

**FS-A identifiers.** Section 17 contains the individual test-file and assertion mapping for every row; this table adds the governing plan sections without replacing that mapping.

| Identifier | Plan section(s) | Identifier | Plan section(s) |
| --- | --- | --- | --- |
| FS-A01 | 4, 5, 7, 17 | FS-A02 | 5, 17 |
| FS-A03 | 5, 17 | FS-A04 | 6, 17 |
| FS-A05 | 5, 9, 17 | FS-A06 | 8, 9, 17 |
| FS-A07 | 9, 17 | FS-A08 | 9, 11, 17 |
| FS-A09 | 12, 13, 17 | FS-A10 | 9, 11, 17 |
| FS-A11 | 9, 10, 17 | FS-A12 | 7, 17 |
| FS-A13 | 7, 12, 17 | FS-A14 | 13, 17 |
| FS-A15 | 12, 17 | FS-A16 | 9, 12, 17 |
| FS-A17 | 11, 17 | FS-A18 | 8, 11, 17 |
| FS-A19 | 11, 17 | FS-A20 | 8, 11, 17 |
| FS-A21 | 8, 11, 17 | FS-A22 | 7, 11, 17 |
| FS-A23 | 11, 17 | FS-A24 | 16, 17 |
| FS-A25 | 11, 16, 17 | FS-A26 | 16, 17 |
| FS-A27 | 16, 17 | FS-A28 | 13, 16, 17 |
| FS-A29 | 12, 16, 17 | FS-A30 | 16, 17 |
| FS-A31 | 17 | FS-A32 | 12, 17 |
| FS-A33 | 10, 11, 17 | FS-A34 | 11, 17 |
| FS-A35 | 11, 17 | FS-A36 | 11, 17 |
| FS-A37 | 11, 17 | FS-A38 | 8, 15, 17 |
| FS-A39 | 8, 14, 17 |  |  |

### 19. Implementation names the PRD left open

Every entry in this table is an implementation name or source filename, not a new requirement.

| Open item | Chosen name and assignment |
| --- | --- |
| Six non-PoolManager architecture `PkgInit` fields | `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, `universalRouter`. |
| Two Crane facet input fields | `uniswapV4ProtocolAwareFacet`, `uniswapV4SinglePositionAwareFacet`. |
| Owner modifier filename | `UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers.sol`, containing `onlyLiveFeeToOwner`. |
| Maintenance modifier filename | `UniswapV4FullSpreadStandardExchangeVaultMaintenanceModifiers.sol`, containing `onlyMaintenanceAuthorized`. |
| Family storage namespace | `indexedex.vaults.standard.exchange.uniswap.v4.fullSpread`. |
| `SwapProjection` operation | FS-OWN-33 greatest-acceptable-liquidity one-sided swap/add projection, shared by qualifying user deposits and one-token maintenance. |
| `ExecutionPreparation` operation | Route/context validation and construction of per-action payloads, reservations, and locked/borrowed settlement plans for the already specified routes; it adds no economics. |
| Temporary factory hook filename | Existing `PostDeployAccountHookFacet.sol`, cited from `DiamondPackageCallBackFactory.sol`; excluded from package inputs and cuts. |
| Shared preview/execution quote engine | `UniswapV4FullSpreadStandardExchangeVaultPlanner`. |
| Crane pair paths and specs | The `aware/` filenames listed in section 4. |
| Matrix concrete row filenames | H1-H7 in section 17. |
| EIP-712 initialization values | Configured share `name` as domain name and version string `"1"`; no new token or denomination. |

## Limits

No implementation, Forge run, test, install, deployment, Git operation, or public source disclosure was performed. Gas, compiler, fork, and integration results remain future evidence. This plan is not an audit and does not prove same-backing-pool sequential composition. A cited FS-HOOK-04 rejection does not replace the canonical disjoint-pool proof. The accepted sandwich exposure of an authorized `donate` or `compound` remains; no price guard or disclosure function is added. Third-party RPC preview gas limits, if unverified, belong in the eventual release report. The plan leaves no product question open and does not authorize implementation.
