# Astra independent design — flattened legacy V4 Standard Exchange

**Date:** 2026-10-15. **Status:** Concrete design proposal for consolidation; no code implementation or deployment authorization.

The current owner instruction resolves D3/D4/D7/D9 as controlling. The redesign proceeds for structural reasons regardless of the previous facet-size claim. Preserve the existing supported SE/SY routes, full-range managed position, funded sleeve, and external ABI, except the explicitly selected custody/disable corrections. Unexpected rebalance protocol failures propagate. V3, hookless, and Pons are not redesigned.

This document fixes the successor components, selector owners, and deletion dispositions now. A subsequent plan may order the work and verification; it must not choose a different partition or add substitute execution hops. Runtime feasibility is unmeasured: no claim is made that this design already fits. A hard-limit failure requires a recorded design revision, not an implementer-selected alternative.

## 1. Evidence and exact baseline surface

I read the redesign draft in full, the package's cuts, each of the ten legacy family facets' `facetFuncs`, the five shared facets' `facetFuncs`, and the SY selector appenders. I also read the factory base cuts and their selector declarations. Relevant current evidence:

- `UniswapV4StandardExchangeDFPkg.sol:170-246` installs fifteen package facets; `:147-163` registers fifteen package interface IDs.
- `UniswapV4StandardExchangeInFacet.sol:25-29` combines exchangeIn, unlockCallback, and four SY execution functions.
- `UniswapV4StandardExchangeInQueryFacet.sol:23-30` owns six transition/external-quote functions, not ordinary previewExchangeIn.
- `UniswapV4StandardExchangeInMultiQueryFacet.sol:23-26` owns previewExchangeIn plus its multi-input preview.
- `UniswapV4StandardExchangeOutMultiQueryFacet.sol:23-26` owns the multi-output preview plus twelve SY queries through `NativeStandardYieldSelectors._appendQuery` (`contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol:58-73`).
- Current remaining delegation: InTarget `:89-98` deposits; OutExecuteTarget `:105-122` share withdrawals. Current OUT self-previews: OutExecuteTarget `:51`, OutExecutionDelegate `:88-96`.
- Current inheritance: InFacet → YieldExecutionTarget → InTarget → InBase → Common; OutBase also inherits InBase. Query and multi targets consequently share the same broad base.

There are **60 package-installed product selectors**: 20 from the five shared facets and 40 from the ten family facets. The factory additionally installs **six permanent introspection selectors**, plus one temporary post-deploy selector removed during construction completion. Those infrastructure selectors are included below; no ownership/admin/upgrade surface is invented.

Selectors below are identified by the **actual Solidity interface member's `.selector`**, not guessed hexadecimal constants. This specifies the exact existing ABI unambiguously; compilation may render their numeric values for verification but cannot choose different signatures.

### Path notation

- `V4/` = `contracts/protocols/dexes/uniswap/v4/`.
- All `UniswapV4StandardExchange…` and `UniswapV4StandardYield…` files named below live directly under `V4/`, unless a path says otherwise.
- A facet row naming a matching target specifies two literal files, `<name>Facet.sol` and `<name>Target.sol`, with the same stem. Facets inherit only that target plus `IFacet`; targets never inherit another family target or a family-wide Common/Base.
- Internal operation libraries are Solidity libraries with **internal-only functions**, not externally linked execution libraries. Moving Solidity code between them does not imply unique deployed bytecode or guaranteed size savings.

## 2. Selected topology

The product package contains the five unchanged shared facets plus **sixteen family facets** specified in section 3: **21 package cuts**. With the existing factory's three permanent base facets the completed proxy has 24 facet owners for 66 selectors. The temporary post-deploy facet is not retained.

The runtime dependency direction is:

`Facet declaration → one ABI Target → explicit operation/read libraries → Repo/canonical math/external protocol`

The one exceptional protocol callback edge is:

`PoolCallLib → external PoolManager.unlock → proxy unlockCallback → CallbackTarget → CallbackLib → PoolManager settlement`

That is the required protocol callback, not a self-call for settlement reuse. There is no target-to-target call, no invocation of public exchange/preview/discovery functions from an internal operation, and no replacement execution delegate. No family target inherits generic `NativeStandardYieldMoneyTarget`, `StandardExchangeInExecutionBase`, old InBase/OutBase, or old Common.

### Internal components: fixed paths, responsibilities, and consumers

| Path under V4/ | Single responsibility | Direct consumers |
|---|---|---|
| `UniswapV4StandardExchangeTypes.sol` | Shared memory request/result types, existing quote-state encoding, typed PoolManager operation data | All family operation/read libraries and ABI targets |
| `UniswapV4StandardExchangeErrors.sol` | Existing legacy-family error/event declarations, unchanged signatures | Targets and internal libraries; no selectors |
| `UniswapV4StandardExchangeConfigLib.sol` | Read configured pool/face/oracle addresses and classify valid token routes | Policy, custody, pool reads/calls, quotes, import, SY metadata |
| `UniswapV4StandardExchangePolicyLib.sol` | Operation eligibility and completion policy: disabled checks, deadlines, interaction-state gating, TWAP update/event | Execution targets, ImportLib, PoolCallLib, RebalanceLib |
| `UniswapV4StandardExchangeLocalCreditRepo.sol` | Persist local booked balances solely for input-credit authorization | CustodyLib, BookLib, package initializer |
| `UniswapV4StandardExchangeCustodyLib.sol` | Funding, named-holder burns, payouts, and operation-bounded refunds | In/Out/Multi targets, SY deposit/redeem targets, JoinLib, ExitLib, SwapLib |
| `UniswapV4StandardExchangePoolReadLib.sol` | Live pool/position/principal/earned-fee reads, including transient import-state reads | BookLib, QuoteLib, RebalanceLib, ImportLib |
| `UniswapV4StandardExchangeBookLib.sol` | Complete-book snapshots and final book synchronization | JoinLib, ExitLib, SwapLib, ImportLib, RebalanceLib, query libraries |
| `UniswapV4StandardExchangeShareMath.sol` | Pure deposit/proportional-share/sink-share/dual-exit arithmetic | JoinLib, ExitLib, QuoteLib, TransitionLib |
| `UniswapV4StandardExchangeQuoteLib.sol` | Single implementation of route pricing and exact-output inversion | QuoteTarget, SYQueryTarget, execution libraries, state/transition libraries |
| `UniswapV4StandardExchangePoolCallLib.sol` | Typed requests opening allowed PoolManager operations and fee collection | JoinLib, ExitLib, SwapLib, RebalanceLib |
| `UniswapV4StandardExchangeCallbackLib.sol` | Execute and settle the authorized PoolManager callback operation | CallbackTarget only |
| `UniswapV4StandardExchangeJoinLib.sol` | One funded pair-input share-issuance engine for single/dual/import funding | InTarget, InMultiTarget, SYDepositTarget, ImportLib |
| `UniswapV4StandardExchangeExitLib.sol` | Named-holder share redemption and shared position-removal/conversion primitives | InTarget, OutTarget, OutMultiTarget, SYRedeemTarget |
| `UniswapV4StandardExchangeSwapLib.sol` | Direct pair-token swap settlement, exact-in and exact-out | InTarget and OutTarget |
| `UniswapV4StandardExchangeRebalanceMath.sol` | Pure target/deadband/ratio/fraction decisions shared by actual and simulated rebalance | RebalanceLib and TransitionLib |
| `UniswapV4StandardExchangeRebalanceLib.sol` | Execute managed full-range sleeve adjustment without swapping | Execution finalization and RebalanceTarget |
| `UniswapV4StandardExchangeImportLib.sol` | Authorized NFT intake, decrease/collect, and conversion into managed funding | PositionImportTarget only |
| `UniswapV4StandardExchangeStateQuoteLib.sol` | Encode/decode/validate/read the existing quote snapshot | StateQuoteTarget, TransitionQuoteTarget, ExternalQuoteTarget |
| `UniswapV4StandardExchangeTransitionLib.sol` | Apply supported simulated operations to memory snapshots | TransitionQuoteTarget and ExternalQuoteTarget |

Keep existing `V4/UniswapV4QuoteService.sol` as the narrow external-pool quote/hook-fee adapter used by QuoteLib and TransitionLib; its dead zap helpers are deleted as specified below. Do not make it an execution library.

### Dependency boundaries that prevent a renamed Common

- Config/Types/Errors/Repos contain no settlement orchestration.
- PoolRead contains no token movements. Book may persist final books but cannot trade, mint, or burn. ShareMath and RebalanceMath are pure and receive snapshots explicitly.
- QuoteLib and StateQuoteLib cannot import execution targets, JoinLib, ExitLib, SwapLib, ImportLib, or CallbackLib. QuoteLib uses shared mathematical and pool-read functions, not an execution engine in view mode.
- TransitionLib imports state types, shared math and quote functions; it mutates memory only. It cannot perform PoolManager operations or persist reserve state.
- Join/Exit/Swap perform their one money operation; they do not call public wrappers or call one another to manufacture a route. Exit's conversion primitive may use PoolCallLib directly. Import shares the JoinLib issuance primitive rather than re-entering an entrypoint.
- CallbackLib is imported by CallbackTarget only. No ordinary money facet embeds its full dispatch/settlement implementation. PoolCallLib encodes operation data and invokes the actual manager.
- Targets apply one existing shared reentrancy modifier for money entries and call internal functions. Internal libraries do not take another lock. CallbackTarget has protocol-caller validation, not the money-entry lock that would reject legitimate callbacks.

## 3. Complete selector ownership

### Unchanged shared package owners — 20 selectors

Each row is the single owner of every selector listed in that row; none is appended elsewhere.

| Owner path | Exact selector identities |
|---|---|
| `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol` | `IERC20Metadata.name.selector`; `IERC20Metadata.symbol.selector`; `IERC20Metadata.decimals.selector`; `IERC20.totalSupply.selector`; `IERC20.balanceOf.selector`; `IERC20.allowance.selector`; `IERC20.approve.selector`; `IERC20.transfer.selector`; `IERC20.transferFrom.selector` |
| `lib/crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol` | `IERC5267.eip712Domain.selector` |
| `lib/crane/contracts/tokens/ERC2612/ERC2612Facet.sol` | `IERC20Permit.permit.selector`; `IERC20Permit.nonces.selector`; `IERC20Permit.DOMAIN_SEPARATOR.selector` |
| `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol` | `IBasicVault.vaultTokens.selector`; `IBasicVault.reserveOfToken.selector`; `IBasicVault.reserves.selector` |
| `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol` | `IStandardVault.vaultFeeTypeIds.selector`; `IStandardVault.contentsId.selector`; `IStandardVault.vaultTypes.selector`; `IStandardVault.vaultConfig.selector` |

Evidence: respective `facetFuncs` bodies at ERC20 `:67-87`, ERC5267 `:45-57`, ERC2612 `:44-58`, BasicVault `:35-40`, StandardVault `:32-39`. Preserve these shared sources/layouts rather than modifying other products.

### Family owners — 40 selectors

All owner/target paths are under `V4/`. Each listed facet has exactly its listed selectors in `facetFuncs`; factory metadata functions are not installed on the vault merely because facets implement `IFacet`.

| Facet file → target file | Responsibility / direct operations | Exact selectors; current owner where moved |
|---|---|---|
| `UniswapV4StandardExchangeInFacet.sol` → `UniswapV4StandardExchangeInTarget.sol` | Exact-input SE dispatcher only; JoinLib/ExitLib/SwapLib | `IStandardExchangeIn.exchangeIn.selector` |
| `UniswapV4StandardExchangeOutFacet.sol` → `UniswapV4StandardExchangeOutExecuteTarget.sol` | Exact-output SE dispatcher only; ExitLib/SwapLib | `IStandardExchangeOut.exchangeOut.selector` |
| `UniswapV4StandardExchangeInMultiFacet.sol` → `UniswapV4StandardExchangeInMultiTarget.sol` | Dual input issuance; JoinLib | `IStandardExchangeInMulti.exchangeInManyToOne.selector` |
| `UniswapV4StandardExchangeOutMultiFacet.sol` → `UniswapV4StandardExchangeOutMultiTarget.sol` | Dual requested-output redemption; ExitLib | `IStandardExchangeOutMulti.exchangeOutOneToMany.selector` |
| `UniswapV4StandardExchangePositionImportFacet.sol` → `UniswapV4StandardExchangePositionImportTarget.sol` | NFT intake entry; ImportLib | `IUniswapV4StandardExchangePositionImport.importPosition.selector` |
| `UniswapV4StandardExchangeLiquidReserveFacet.sol` → `UniswapV4StandardExchangeLiquidReserveTarget.sol` | Sleeve and policy discovery, read-only | `IUniswapV4StandardExchangeLiquidReserve.canOpenPoolManagerUnlock.selector`; `.localReserve.selector`; `.deployedReserve.selector`; `.targetLiquidReservePercentage.selector`; `.actualLiquidReservePercentage.selector`; `.twapOracle.selector` |
| `UniswapV4StandardExchangeRebalanceFacet.sol` → `UniswapV4StandardExchangeRebalanceTarget.sol` | Permissionless managed rebalance entry; RebalanceLib | `IUniswapV4StandardExchangeLiquidReserve.rebalanceLiquidReserve.selector` — from LiquidReserveFacet |
| `UniswapV4StandardExchangeCallbackFacet.sol` → `UniswapV4StandardExchangeCallbackTarget.sol` | Sole PoolManager callback entry; CallbackLib | `IUnlockCallback.unlockCallback.selector` — from InFacet |
| `UniswapV4StandardExchangeQuoteFacet.sol` → `UniswapV4StandardExchangeQuoteTarget.sol` | Stateless current-state SE route previews; QuoteLib | `IStandardExchangeIn.previewExchangeIn.selector` and `IStandardExchangeInMulti.previewExchangeInManyToOne.selector` — from InMultiQueryFacet; `IStandardExchangeOut.previewExchangeOut.selector` — from OutQueryFacet; `IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector` — from OutMultiQueryFacet |
| `UniswapV4StandardExchangeStateQuoteFacet.sol` → `UniswapV4StandardExchangeStateQuoteTarget.sol` | Snapshot creation and readout; StateQuoteLib | `IStandardExchangeTransitionQuote.quoteState.selector` — from OutQueryFacet; `.quoteAssets.selector`; `.quoteShareBalance.selector`; `.quoteTotalSupply.selector` — from InQueryFacet |
| `UniswapV4StandardExchangeTransitionQuoteFacet.sol` → `UniswapV4StandardExchangeTransitionQuoteTarget.sol` | Holder's simulated SE operation; TransitionLib | `IStandardExchangeTransitionQuote.quoteTransition.selector` — from InQueryFacet |
| `UniswapV4StandardExchangeExternalQuoteFacet.sol` → `UniswapV4StandardExchangeExternalQuoteTarget.sol` | External-actor simulated operations; TransitionLib | `IStandardExchangeExternalQuote.quoteExternalExchange.selector`; `.quoteExternalDeposit.selector` — from InQueryFacet |
| `UniswapV4StandardYieldDepositFacet.sol` → `UniswapV4StandardYieldDepositTarget.sol` | SY deposit validation/event wrapper; JoinLib | `IStandardizedYield.deposit.selector` — from InFacet |
| `UniswapV4StandardYieldRedeemFacet.sol` → `UniswapV4StandardYieldRedeemTarget.sol` | SY named-holder redemption validation/event wrapper; ExitLib | `IStandardizedYield.redeem.selector` — from InFacet |
| `UniswapV4StandardYieldQueryFacet.sol` → `UniswapV4StandardYieldQueryTarget.sol` | SY metadata, token discovery, previews and reward views | `IStandardizedYield.exchangeRate.selector`; `.yieldToken.selector`; `.assetInfo.selector`; `.getTokensIn.selector`; `.getTokensOut.selector`; `.isValidTokenIn.selector`; `.isValidTokenOut.selector`; `.previewDeposit.selector`; `.previewRedeem.selector`; `.getRewardTokens.selector`; `.accruedRewards.selector`; `.rewardIndexesStored.selector` — all from OutMultiQueryFacet |
| `UniswapV4StandardYieldRewardsFacet.sol` → `UniswapV4StandardYieldRewardsTarget.sol` | Existing empty reward execution responses/events only | `IStandardizedYield.rewardIndexesCurrent.selector`; `.claimRewards.selector` — from InFacet |

A leading dot in a cell repeats the explicitly named interface in that same group, not the facet class. The ten current family `facetFuncs` bodies and SY appenders supply this exhaustive forty-selector set. This design adds no product selector and drops none.

Do not install `isValidTokenIn`/`isValidTokenOut` again on the SY money facets. Their validation is `ConfigLib.isPoolFace`, not a public self-call or inherited discovery surface. Do not attach SY selectors using `_appendExecution`/`_appendQuery` on the old SE facets after the move; the new SY facets enumerate their own exact lists.

### Factory-installed infrastructure — preserve six permanent selectors

| Selector | Single permanent owner |
|---|---|
| `IERC165.supportsInterface.selector` | `lib/crane/contracts/introspection/ERC165/ERC165Facet.sol` |
| `IDiamondLoupe.facets.selector` | `lib/crane/contracts/introspection/ERC2535/DiamondLoupeFacet.sol` |
| `IDiamondLoupe.facetFunctionSelectors.selector` | same DiamondLoupeFacet |
| `IDiamondLoupe.facetAddresses.selector` | same DiamondLoupeFacet |
| `IDiamondLoupe.facetAddress.selector` | same DiamondLoupeFacet |
| `IERC8109Introspection.functionFacetPairs.selector` | `lib/crane/contracts/introspection/ERC8109/ERC8109IntrospectionFacet.sol` |

The ERC8109 implementation declares `facetAddress` too, but the factory installs only `functionFacetPairs` from it (`DiamondPackageCallBackFactory.sol:279-309`); do not introduce a duplicate owner. `IPostDeployAccountHook.postDeploy.selector` is temporarily installed on `lib/crane/contracts/factories/diamondPkg/PostDeployAccountHookFacet.sol:38-40` and removed by the existing factory post-deploy cut (`DiamondPackageCallBackFactory.sol:425-452`). Preserve this construction-only lifecycle; do not retain it as a product entry. No `diamondCut`, ownership, arbitrary executor, or public holder-selecting settlement selector is added. The factory's own initialization functions are not extra installed product selectors.

## 4. Package and declaration wiring — fixed

Retain `V4/IUniswapV4StandardExchangeDFPkg.sol`, `V4/UniswapV4StandardExchangeDFPkg.sol`, and `V4/UniswapV4_Component_FactoryService.sol` as the family deployment entrypoints; rewrite their wiring rather than wrapping the old package.

`PkgArgs` stays exactly the existing `PoolKey poolKey` shape (`IUniswapV4StandardExchangeDFPkg.sol:47-49`). Preserve instance-salt derivation and package name. Existing component identities that remain keep their established name-derived salts; new facet identities use their exact new contract names. No bytecode-hash salt or silent fallback to an occupied deployment identity. This is fresh-instance work, not an upgrade to occupied instances.

The new `PkgInit` has the existing five shared-facet fields first. Its family-facet fields follow the sixteen rows of the family ownership table in that order, each named by lowercasing the first letter of its facet contract name (for example, `uniswapV4StandardExchangeCallbackFacet`). Retain the existing protocol/deployment fields afterward, in their current order: `vaultFeeOracleQuery`, `vaultRegistryDeployment`, `permit2`, `poolManager`, `positionManager`, `twapOracle`, `weth`. Remove the four old QueryFacet initialization fields. `facetAddresses` and `facetCuts` use exactly the same 21-entry order: five shared rows followed by sixteen family rows.

Keep the existing fifteen package interface IDs from DFPkg `:147-163` unchanged; factory introspection IDs remain separately registered. Fragmented interfaces are advertised at package/proxy level. For family `facetInterfaces`, keep existing In/Out/InMulti/OutMulti/Import declarations; new Quote/StateQuote/TransitionQuote/SYDeposit/SYRedeem/SYQuery/SYRewards fragments advertise no complete interface they do not independently implement; ExternalQuote advertises its complete existing external-quote interface, Callback advertises IUnlockCallback. LiquidReserve views and Rebalance fragments no longer individually advertise the complete reserve interface; the package continues to advertise it. This changes facet metadata ownership, not proxy interface support.

Remove both delegate deploy functions and every constructor argument/immutable address used only for them. All sixteen family facets are constructor-independent of execution delegates. Keep CREATE3/FactoryService deployment and manager-registry package deployment. Update `V4/test/bases/TestBase_UniswapV4StandardExchange.sol` to construct this exact package; do not substitute direct facet instantiation or a test-only cut.

## 5. Accounting and operation contract — no new economics

### Two explicit quantities, not a conflated reserve

1. **Complete economic inventory** per currency is held ERC-20 face plus exact deployed principal plus uncollected fees, counted once. This is used for existing share math, SY rate, and quoted claims. Preserve the current canonical rounding and hook-fee adjustments; no spot-NAV replacement, new fees, new share token, or change from 18-decimal shares.
2. **Local booked credit baseline** is the locally held balance last finalized for credit purposes. It excludes deployed principal and uncollected fees. Persist it in the new family-only `LocalCreditRepo`, as `mapping(address => uint256) bookedLocal`, for the two ERC-20 faces and self-share. Use an ERC1967-derived slot with the literal namespace `indexedex.protocols.dexes.uniswap.v4.standardExchange.localCredit`; do not touch shared repo layouts.

Preserve the installed `IBasicVault` read surface and its historical stored complete-reserve meaning: BookLib continues to write complete currency inventory to `MultiAssetBasicVaultRepo._reserveOfToken`, and self-share custody for the self entry. **CreditLib must never authorize credit using that total mapping or subtract live deployed inventory from it.** This separate local credit baseline implements the required authorization correction without silently changing the shared query surface or other families' storage semantics.

CustodyLib computes availability using canonical `LocalCreditLib.available(balance, bookedLocal)` and exact-output budgets using `LocalCreditLib.budget`. Authenticate a prepaid starter before credit-sensitive token reads. Exact-in pull accepts only its measured exact delta; prepaid exact-in consumes only the declared amount. Exact-out pull takes the required quote, not the maximum; prepaid exact-out captures its bounded credit once and refunds only unused authorized credit to the original payer. Surplus arriving later cannot enlarge that operation's refund. Final synchronization books the entire remaining local balance, including retained surplus; it is not a depositor-ownership ledger.

All money routes capture their operation's funding credit before any collection, movement, or synchronization can reclassify it. Complete-book issuance subtracts only this operation's credited inputs from the post-funding snapshot, equivalent to the current mint basis. Resting/donated inventory retains its existing holder/sink treatment. Sync both local-credit and reported complete books after settlement/refunds and the final allowed rebalance. Outside pool trading must not alter the stored local-credit baseline.

### Explicit operation inputs

`Types` fixes these memory request roles; configured token order is always pool order:

- `Funding`: `address payer`, `address token`, `uint256 requested`, `uint256 maximum`, `bool pretransferred`.
- `FundingResult`: `uint256 credited`, `uint256 openingBalance`, `uint256 bookedLocal`.
- `JoinRequest`: `address payer`, `address receiver`, `uint256 amount0`, `uint256 amount1`, `uint256 minimumShares` (amounts are already credited; no funding flag reaches the mint primitive).
- `ExitRequest`: `address holder`, `address receiver`, `uint256 shares`, `address tokenOut`, `uint256 minimumOut`.
- `ExactOutputExitRequest`: `address payer`, `address holder`, `address receiver`, `address tokenOut`, `uint256 requestedOut`, `uint256 maximumShares`, `uint256 creditedShares`.
- `DualExitRequest`: `address payer`, `address holder`, `address receiver`, `uint256 amount0Out`, `uint256 amount1Out`, `uint256 maximumShares`, `uint256 creditedShares`.
- `SwapRequest`: `address payer`, `address receiver`, `address tokenIn`, `address tokenOut`, `uint256 amount`, `uint256 limit`, `uint256 creditedInput`, `bool exactOutput`.

Deadlines and request validity are checked at the entrypoint before invoking funded operations. A named holder is not selected from `msg.sender` inside an execution library; entrypoints explicitly supply it. Keep the existing `InventoryQuote` field order/types and encoded state contract when moving it into Types; preserve existing invalid-state checks and supported transition operations. Simulated state is memory, never a write to the live credit book.

### Route dispatch and finalization

| External route | Funding/holder selection and internal operation |
|---|---|
| SE exchangeIn pair→pair | Custody funding → SwapLib exact-in; remains unavailable during an already-unlocked manager context |
| SE exchangeIn pair→self-share | Custody funding → JoinLib single-token issuance; first activation still requires both tokens through a supported two-token entry |
| SE exchangeIn self-share→pair | Deliver shares once to vault → ExitLib with holder vault |
| SE exchangeOut pair→pair | Internal quote → quote-sized pull or bounded prepaid funding → SwapLib exact-out; check actual input maximum and requested output |
| SE exchangeOut self-share→pair | Internal share quote → ordinary caller holder or authenticated vault prepaid holder exactly as the existing single-output exact-out route; ExitLib pays exactly requested output and retains rounding surplus |
| exchangeInManyToOne | Validate two ordered pool faces and positive amounts → two funding results → same JoinLib issuance core, no ratio-forcing swap |
| exchangeOutOneToMany | Preserve equal per-leg share-burn eligibility; quote-sized ordinary share delivery or bounded prepaid share delivery → vault holder → dual ExitLib payout |
| SY deposit | Preserve SY validations/events → ordinary token funding → the same JoinLib single-token issuance; do not call exchangeIn |
| SY ordinary redeem | Original caller is holder; no share allowance or synthetic pretransfer; ExitLib exact-input redemption |
| SY internal-balance redeem | Authenticate starter and verify held amount; vault is holder; burn only requested held shares; no unrelated self-share refund |
| importPosition | Existing authorization/pool/deadline/minimum rules → ImportLib collection/conversion → JoinLib funded two-token mint core |
| rebalanceLiquidReserve | Disabled/idle gate → RebalanceLib; no caller reward, no swaps |

Do not invent token→exact-share-mint routes for exchangeOut: the current legacy V4 Out dispatcher supports direct pair swaps and share exits, not that additional route. Preserve unsupported-route rejection.

Every economic execution entry above takes one shared reentrancy lock and rejects disabled operation before funding/burn/movement, including SY redemption (REQ-V4-02). ERC20 transfers/permits and read-only discovery are not repurposed into disabled economic operations. Empty SY reward functions retain their existing behavior/events; they do not become new funded money routes.

After a successful money operation, perform the existing applicable managed rebalance, final book sync, then the defined TWAP poke. Preserve the TWAP failure event handling rather than conflating it with D8's unexpected rebalance protocol failure. Internal operation libraries do not independently take another lock or route through an ABI entry.

### Sleeve and rebalance law

Retain the full-range ticks, canonical liquidity math, fee-oracle percentage, absolute floors/deadband, bounded deploy/refill/second-deploy sequence, and ratio limitation. RebalanceMath is shared with projected rebalance so actual and modeled rounding cannot drift. Deposits while manager interaction is blocked remain funded sleeve deposits and emit the existing telemetry. Supported blocked redemptions pay only if local inventory can satisfy them; no nested unlock. Idle exits retain their required pool interaction even if sleeve liquidity would cover payout. Explicit rebalance and import retain their current idle-only gates.

Unexpected failures of actual PoolManager/token/PositionManager rebalance operations propagate and roll back the parent; insufficient ratio, representational rounding, or deadband can still produce no-op/partial adjustment. No catch boundary, arbitrary executor, or retry through self-call is added. Do not change the existing fee-oracle/TWAP economic policy.

## 6. Keep / move / delete inventory

### Existing family files

| Current V4/ file(s) | Fixed disposition |
|---|---|
| `UniswapV4StandardExchangeCommon.sol` | Delete after its functions are moved according to the responsibility map below; no successor Common/Base aggregate |
| `UniswapV4StandardExchangeInBase.sol`, `UniswapV4StandardExchangeOutBase.sol` | Delete; share one pure quote/issuance/removal primitive in the designated libraries, not inheritance |
| `UniswapV4StandardExchangeInExecutionDelegate.sol`, `UniswapV4StandardExchangeOutExecutionDelegate.sol` | Delete entire contracts, including obsolete SELF/error declarations and constructor/factory wiring; internal Join/Exit/Swap operations replace them |
| `UniswapV4StandardYieldExecutionTarget.sol` | Delete; explicit SYDeposit/SYRedeem targets replace generic route override and settlement wrapper |
| `UniswapV4StandardExchangeOutTarget.sol` | Delete empty execution/query compatibility aggregate |
| `UniswapV4StandardExchangeInQueryTarget.sol`, `UniswapV4StandardExchangeOutQueryTarget.sol` and corresponding two `…QueryFacet.sol` files | Delete after moving selectors to Quote/StateQuote/TransitionQuote/ExternalQuote owners specified above |
| `UniswapV4StandardExchangeInMultiQueryTarget.sol`, `UniswapV4StandardExchangeOutMultiQueryTarget.sol` and corresponding two `…QueryFacet.sol` files | Delete; ordinary/multi previews go to Quote, twelve SY queries go to SYQuery |
| Existing InFacet/InTarget, OutFacet/OutExecuteTarget, InMultiFacet/InMultiTarget, OutMultiFacet/OutMultiTarget | Keep paths and contract identities; replace broad inheritance with thin targets and internal libraries as mapped |
| Existing LiquidReserveFacet/LiquidReserveTarget | Keep paths; retain six views only; move rebalance selector and its guarded body to new Rebalance owner |
| Existing PositionImportFacet/PositionImportTarget | Keep paths; thin ImportLib wrapper; import interface moves out of InTarget to `V4/interfaces/IUniswapV4StandardExchangePositionImport.sol` with identical ABI |
| `UniswapV4PoolKeyAwareRepo.sol`, `UniswapV4PoolManagerAwareRepo.sol` | Keep current storage and initialization; ConfigLib accesses them directly |
| `UniswapV4PositionRepo.sol` | Keep fields and slots; preserve temporary import semantics and emptied-NFT metadata as below; no ongoing imported-NFT growth |
| `UniswapV4QuoteService.sol` | Keep direct quote/hook adjustment functions; delete `_quoteZapInShares`, `_quoteZapInSwapAmount`, `_quoteZapInDetail`, `_quoteZapOutShares`, their exclusive ZapIn/ZapOut parameter structs, search constants and now-unused zap-quoter/constant-product imports |
| `IUniswapV4StandardExchangeDFPkg.sol`, `UniswapV4StandardExchangeDFPkg.sol`, `UniswapV4_Component_FactoryService.sol` | Keep names; replace facet/delegate wiring with the fixed table in section 4 |
| `interfaces/IUniswapV4StandardExchangeLiquidReserve.sol` | Keep ABI/events and interface ID; update obsolete ongoing imported-position descriptions, not route economics |
| `test/bases/TestBase_UniswapV4StandardExchange.sol` | Keep public test-base identity/helpers; deploy the specified package and new facets, remove obsolete delegate/query facet setup |

The old zap helper removal is based on production searches showing only their mutual definitions in QuoteService, with no test references found. No removal of Crane's canonical quoter implementations is authorized. If a newly discovered external consumer contradicts this observed inventory, report it rather than deleting across another product or keeping a second family engine by stealth.

### Function ownership when Common/Base are removed

| Existing function group | Sole successor |
|---|---|
| `_poolManager`, `_poolKey`, `_poolId`, `_currency0/1`, `_token0/1`, `_erc20Face`, `_weth`, pool-face predicates | ConfigLib |
| `_requireNotDisabled`, `_requireCanOpenPoolManagerUnlock`, `canOpenPoolManagerUnlock`, `_pokeBoundPoolTwap` policy | PolicyLib (ConfigLib reads addresses; PoolRead reads actual unlock state) |
| `_positionInfo`, `_currentLiquidity`, `_positionAmounts`, `_deployedAmounts`, `_collectablePositionFees`, `_slot0` | PoolReadLib |
| `_freeBalances`, `_freeBalancesForShareMath`, `_totalVaultReserves`, `_syncVaultReserves` | BookLib with explicit complete/local distinction |
| `_sharesOutForDeposit`, `_initialResidualShares`, `_quoteInitialShares`, proportional and dual share rounding | ShareMath; one implementation |
| Both `_quoteZapOutAmount` bodies, `_previewZapOutExactIn`, `_previewZapOutWithdrawal`, direct/dual deposit/exit previews, `_quotedWithdrawalShares`, `_withdrawalAssets` | QuoteLib; all execution callers use it internally |
| `_executeZapInDeposit`, `_executeZapInDualDeposit`, mint/residual handling | JoinLib's single credited-amount pair core |
| `_executeZapOutExactIn`, `_executeFreeZapOutExactIn`, idle single-output conversion, exact-output withdrawal core and dual payout wrappers | ExitLib; one pro-rata liquidity-removal primitive and one removed-other-token conversion primitive |
| Direct swap execution and measured payout | SwapLib |
| `_secureTokenTransfer`, `_secureShareDelivery`, `_transferCurrency`, unused-input/share refunds | CustodyLib; remove `_deployedFaceOf` as a credit reconstruction dependency |
| `_executeUnlock`, simple add/remove/swap request encoders, managed fee collection | PoolCallLib |
| `_unlockCallback`, `_executeSwap`, `_executeAddLiquidity`, `_executeRemoveLiquidity`, delta/currency settlement | CallbackLib; unlock entry only in CallbackTarget |
| `_liveLiquidReservePercentage`, `_targetFree`, `_absoluteFloor`, `_shouldRebalanceToken`, liquidity-budget/fraction calculations | RebalanceMath for pure calculations; PolicyLib/PoolRead supply live inputs |
| `_rebalanceLiquidReserveInternal`, managed deploy/refill/fraction burn, managed-position creation | RebalanceLib; delete imported-growth branches |
| `_inventory*` snapshot read/encoding/validation | StateQuoteLib |
| `_inventory*` deposit/redeem/swap/collect/liquidity-transition and simulated rebalance | TransitionLib, using ShareMath/RebalanceMath/QuoteLib rather than independent economics |
| `_requireAuthorizedImport`, `_executeAuthorizedImport`, `_collectImportedAssets`, `_burnImportedLiquidityCommon` | ImportLib; the last is import-only decrease/collect, not ongoing reserve management |
| `_deployExcessImported`, `_increaseImportedPositionCommon`, `_increaseImportedPosition` | Delete, with their NFT-growth approvals; do not recreate equivalent branches |
| Family errors/events and memory structs | Errors/Types, preserving names/signatures/quote-state encoding |

### Position state disposition

All existing PositionRepo fields have explicit retained roles; do not delete them merely because successful conversion clears a flag:

- `centerPosition.tickLower/tickUpper/salt/created`: managed full-range identity and creation state; read by PoolRead, PoolCall and Rebalance, written by initialization/import-finalization/managed creation.
- `importedPositionManager`, `importedPositionTokenId`: import-time authorization/custody reference and retained emptied-NFT metadata; written by ImportLib, read by import decrease/collect and temporary pool readers.
- `importedPositionActive`: temporary import lifecycle discriminant only; set during collection and cleared before managed-position operation. PoolRead preserves temporary-state reader behavior; normal Join/Exit/Rebalance never increase an imported NFT.
- `authorizedPositionManager`: configured authorization; written by package initialization, read by ImportLib.

The emptied NFT stays in the vault with no new rescue rights. Common's ongoing imported growth/approval branches are deleted, but required temporary import decrease/collection and readers are not. Add only the new local-credit storage namespace; no new admin or upgrade ledger. Shared ERC20/basic/standard/permit/oracle storage remains unchanged.

## 7. Shared SY migration — mechanical only outside legacy V4

Delete `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol` (the five-line import shim). The actual `NativeStandardYieldExecutionTarget` declaration stays in `NativeStandardYieldTarget.sol` for existing non-legacy consumers; imports refer directly to that defining file. Do not add another re-export file.

Add `contracts/interfaces/INativeStandardYieldErrors.sol` containing exactly the existing five errors from `NativeStandardYieldTarget.sol:90-94`, with identical signatures. Move their declarations there and update shared targets and qualified error references to this independent interface. Keep the existing compatibility aggregate as a behavior composition for families that still inherit it; it is no longer the required error namespace. Do not delete their behavior or change inheritance semantics beyond mechanical declaration/import adjustment. Legacy V4's new SY targets use the independent errors and their explicit operation libraries and do not inherit that aggregate.

Current production shim import consumers found in this pass, excluding the legacy target that is deleted, are:

- `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookSeTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/facets/UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/facets/UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet.sol`
- `contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardYieldExecutionTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardYieldExecutionTarget.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyStandardYieldExecutionTarget.sol`

No test shim imports were found in the scoped search. Additional qualified error references receive only symbol/import migration to the same error signatures, not functional rewrites. Updating a V3/hookless/Pons import is not permission to change their redemption architecture.

SY behavior remains: original validation/minimum/error/event contract, same two currency faces in token discovery, zero yieldToken, liquidity asset info, existing geometric complete-book rate and zero-supply rate, empty rewards and ClaimRewards event. Unsupported-token SY preview still returns zero as in `NativeStandardYieldPreviewTarget.sol:10-17`; execution retains its invalid-token rejection. Do not copy a new quote validity rule from another family.

## 8. Acceptance is fixed; measurement is not a design chooser

Before declaring implementation complete:

1. Compare the resulting 60 product selector identities and six permanent infrastructure identities against section 3. Assert one owner each through facet declarations, 21 package cuts, package interface support, and deployed proxy loupe. Verify the temporary post-deploy selector is removed. Do not count facet/package metadata ABI as installed vault selectors.
2. Search legacy production code for external self-calls and delegatecall execution reuse. The allowed manager callback edge and unchanged factory construction machinery are not permission for a self-preview or execution library hop.
3. Execute production proxy tests for all retained directions, each trust flag, explicit holder modes, disabled entries, both manager-lock contexts, exact-output limits/refunds/surplus, NFT intake/rollback, native face settlement, fee/deployment accounting, and sequential transition parity. Preserve the original assertions unless they encode a documented requirement-7 correction; explain every such delta.
4. Refresh artifacts before tests; measure every deployed runtime. Hard cap 24,576 bytes, advisory target 23,000 per facet. The claimed earlier 31,908-byte measurement is not assumed or reproduced by this design. Even if a simpler build already fits, the required structural replacement still proceeds. Conversely, if this fixed design exceeds the hard cap, report its exact dependency/size evidence and stop for an explicit design revision; do not move selectors, combine groups, add a delegate, enable viaIR, or remove behavior unilaterally.
5. Validate the mechanical shared-SY migration by compiling all importers and retaining source-level error selector/event behavior. Do not invoke legacyV4-only policies on another family's money path.

This independent design does not claim compile success, runtime sizes, or test passes. The package and every current family/shared facet selector declaration were read; broader legacy functions were inspected by body and function inventory for responsibility placement rather than re-audited exhaustively. A broad Crane glob encountered missing LayerZero dependency paths; the needed factory/introspection facets were subsequently read directly at their canonical paths. No supplied legacy source read failed and no reviewer notes were read.

The owner-selected architecture direction is now represented by concrete successor files, a complete selector ownership table, and explicit deletion/storage/package dispositions in this document. Consolidation may accept or reject this design, but its implementation must not reinterpret these tables as a menu.

I did not run Forge.
