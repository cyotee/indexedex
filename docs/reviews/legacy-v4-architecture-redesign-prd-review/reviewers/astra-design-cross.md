# Astra — legacy V4 flattened-design cross-review

**Disposition:** Reject the retained-delegate design. For consolidation, select the single closed component and ownership set below, corresponding to my original design's sections 2–7. Do not combine competing ownership tables. This is my recommendation, not a claim that the other reviewers have agreed to it.

I read all three supplied original designs and re-read the controlling callback/delegate clauses and disputed current source. No source, redesign markdown, PRD, or implementation plan was edited. My original is preserved.

## 1. Peer agreement and objections

### MiniMax — reject its successor/keep table

MiniMax's owner-ruling summary at line 11, component rows at 69-70, KEEP rows at 161-162, and acceptance at 210 explicitly retain the existing IN and OUT execution delegates and their routing. That contradicts the controlling draft at `legacy-v4-standard-exchange-architecture-redesign.md:101-102`, which requires **both** contracts and their constructor/factory wiring removed. “No new delegate” is not equivalent to “remove both existing delegates.”

The current hops are concrete: `UniswapV4StandardExchangeInTarget.sol:89-98` delegates deposits, and `UniswapV4StandardExchangeOutExecuteTarget.sol:105-122` delegates withdrawals. Moving their self-previews does not remove these hops.

**Replacement sentence:**

> Replace MiniMax's successor-component and KEEP rows for execution delegates with the closed component/selector tables below; delete both legacy execution-delegate contracts and all call, constructor, immutable-address, and factory-deployment wiring used for those contracts, and move their retained operations into the specified internal-only JoinLib, ExitLib, and SwapLib consumers, with no replacement execution hop.

Its selector prose is also internally inconsistent: its table assigns SY selectors once, but lines 47, 50-51 and 131 describe additional SY attachments to OUT/multi facets. Current `UniswapV4StandardExchangeOutMultiQueryFacet.sol:23-26` does install SY queries, contrary to treating them as unsupported because of the current facet's name. Use the exact single-owner table below, not the prose attachments.

### Grok — agree on removal and dedicated callback; select a more explicit partition

Grok's delegate deletion and callback-only facet comply with the owner direction. Its sixteen-cut alternative is not rejected as a delegate violation. I do not select its component/selector table: it leaves the combined IN+SY execution and combined transition/external-query ownership intact, and groups many quote/book responsibilities into one Accounting component. The selected table below separates those responsibilities explicitly without allowing a later implementer to choose a split.

This is a design selection, not a claim that Grok's partition is proven oversized. Neither candidate has a measured passing runtime result. Fewer components are not by themselves a flatter dependency graph.

**Replacement sentence:**

> Use the successor-component list and 21-package-cut selector ownership table in this cross-review, rather than retaining the old IN+SY and mixed query facet groupings; targets call only the specified internal libraries, and the implementation plan may sequence but not repartition these owners.

### Kimi — agree on no delegates; reject its merger and aggregate-deletion table

Kimi correctly removes both delegates and assigns a dedicated callback. I do not select its fourteen-cut merger or its wide Settlement component: it combines single/dual SE operations and SY execution on a new IN owner, whereas the selected design fixes narrower existing-route and SY owners. Again, there is no measured claim that one candidate is smaller.

Two concrete corrections are required independently of that preference:

- Kimi's deletion of the shared `NativeStandardYieldTarget` aggregate at line 81 conflicts with its claim that other consumers need only import changes. `contracts/vaults/standard/erc4626/ERC4626StandardYieldTarget.sol:11,17` still inherits that aggregate. Moving error declarations does not replace its inherited behavior. Retain that aggregate for existing consumers; remove its role as the required error namespace and remove the import shim.
- Kimi labels custody helpers “unchanged, current,” but the current `UniswapV4StandardExchangeCommon.sol:1258-1275` reconstructs local credit from stored total minus deployed inventory. Requirement 7's selected credit corrections must not be lost under equivalence refactoring. The selected Book/Custody/LocalCreditRepo split specifies the distinction explicitly.

**Replacement sentence:**

> Replace the merged facet/Settlement and shared-aggregate deletion dispositions with the closed tables below: retain the shared compatibility aggregate for its existing non-legacy consumers, move only its error declarations to the independent error interface, and implement legacy V4's selected local-credit corrections through the separate local-credit book rather than preserving deployed-reserve subtraction.

## 2. Closed internal component list

Let `V4/` mean `contracts/protocols/dexes/uniswap/v4/`. Each name in the next table is a literal `.sol` file under that directory. Every library operation is internal-only; no public/external linked execution library is introduced.

| Component | Sole responsibility |
|---|---|
| `UniswapV4StandardExchangeTypes.sol` | Memory operation/result types and existing quote-state encoding |
| `UniswapV4StandardExchangeErrors.sol` | Existing family error/event declarations with unchanged signatures |
| `UniswapV4StandardExchangeConfigLib.sol` | Configuration reads and internal route/token classification |
| `UniswapV4StandardExchangePolicyLib.sol` | Eligibility, disable/deadline/interaction gates, and TWAP completion policy |
| `UniswapV4StandardExchangeLocalCreditRepo.sol` | Family-only persistent local booked balances used for input authorization |
| `UniswapV4StandardExchangeCustodyLib.sol` | Funding, holder burns, payouts, and bounded refunds |
| `UniswapV4StandardExchangePoolReadLib.sol` | Live pool/position/principal/fee reads and temporary import-state reads |
| `UniswapV4StandardExchangeBookLib.sol` | Complete-book snapshots and final synchronization of complete/local books |
| `UniswapV4StandardExchangeShareMath.sol` | Pure share issuance, residual-sink and proportional/dual-exit arithmetic |
| `UniswapV4StandardExchangeQuoteLib.sol` | Current-route pricing and exact-output inversion |
| `UniswapV4StandardExchangePoolCallLib.sol` | Typed manager-operation requests and fee collection initiation |
| `UniswapV4StandardExchangeCallbackLib.sol` | Authorized callback dispatch and protocol delta settlement; imported only by CallbackTarget |
| `UniswapV4StandardExchangeJoinLib.sol` | One credited-input issuance engine |
| `UniswapV4StandardExchangeExitLib.sol` | Named-holder redemption and common removal/conversion primitives |
| `UniswapV4StandardExchangeSwapLib.sol` | Direct pair-swap settlement |
| `UniswapV4StandardExchangeRebalanceMath.sol` | Shared actual/simulated target, deadband, ratio and fraction calculations |
| `UniswapV4StandardExchangeRebalanceLib.sol` | Managed full-range sleeve adjustment without swaps |
| `UniswapV4StandardExchangeImportLib.sol` | Authorized NFT intake, decrease/collect and conversion |
| `UniswapV4StandardExchangeStateQuoteLib.sol` | Snapshot encoding, decoding, validation and readout |
| `UniswapV4StandardExchangeTransitionLib.sol` | Memory-only simulated operations |

Retain `V4/UniswapV4QuoteService.sol` as the narrow pool/hook-fee quote adapter, with the dead zap-helper deletions specified in my original. Retain the existing configuration/position repos; shared ERC20, permit, basic-vault and standard-vault layouts are unchanged. Add `contracts/interfaces/INativeStandardYieldErrors.sol` for the five existing shared SY errors. Delete the shared execution import shim; other families import the actual defining file and receive mechanical error-reference changes only.

Each family facet below inherits its matching `Target` plus `IFacet`, with exactly one exception in naming: OutFacet retains `UniswapV4StandardExchangeOutExecuteTarget.sol`. All other target filenames replace the terminal `Facet` with `Target`. They live under `V4/`. Targets do not inherit each other, the old Common/InBase/OutBase, or the generic native-SY routing aggregate. Query libraries cannot import execution libraries; CallbackLib cannot be pulled into ordinary execution facets.

The local credit mapping is distinct from complete valuation inventory. Preserve the existing complete-reserve read surface while using canonical saturated availability against the separate locally booked balance for funding authorization. The explicit storage, request roles, synchronization, temporary-import readers, and function-move dispositions in my original sections 5–7 remain the selected definitions, not alternatives to infer later.

## 3. One complete selector-to-facet table

Interface-qualified member names denote their existing `.selector` values; no ABI change or guessed numeric selector is authorized. Every selector listed belongs only to its row's owner. A leading dot repeats the interface named in that row.

### Package cuts 1–5: unchanged shared components, 20 selectors

| Owner path | Exact selector identities |
|---|---|
| `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol` | `IERC20Metadata.name`; `.symbol`; `.decimals`; `IERC20.totalSupply`; `.balanceOf`; `.allowance`; `.approve`; `.transfer`; `.transferFrom` |
| `lib/crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol` | `IERC5267.eip712Domain` |
| `lib/crane/contracts/tokens/ERC2612/ERC2612Facet.sol` | `IERC20Permit.permit`; `.nonces`; `.DOMAIN_SEPARATOR` |
| `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol` | `IBasicVault.vaultTokens`; `.reserveOfToken`; `.reserves` |
| `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol` | `IStandardVault.vaultFeeTypeIds`; `.contentsId`; `.vaultTypes`; `.vaultConfig` |

### Package cuts 6–21: family components, 40 selectors

All owners are literal files under `V4/`, in this exact cut order.

| Owner | Exact selector identities |
|---|---|
| `UniswapV4StandardExchangeInFacet.sol` | `IStandardExchangeIn.exchangeIn` |
| `UniswapV4StandardExchangeOutFacet.sol` | `IStandardExchangeOut.exchangeOut` |
| `UniswapV4StandardExchangeInMultiFacet.sol` | `IStandardExchangeInMulti.exchangeInManyToOne` |
| `UniswapV4StandardExchangeOutMultiFacet.sol` | `IStandardExchangeOutMulti.exchangeOutOneToMany` |
| `UniswapV4StandardExchangePositionImportFacet.sol` | `IUniswapV4StandardExchangePositionImport.importPosition` |
| `UniswapV4StandardExchangeLiquidReserveFacet.sol` | `IUniswapV4StandardExchangeLiquidReserve.canOpenPoolManagerUnlock`; `.localReserve`; `.deployedReserve`; `.targetLiquidReservePercentage`; `.actualLiquidReservePercentage`; `.twapOracle` |
| `UniswapV4StandardExchangeRebalanceFacet.sol` | `IUniswapV4StandardExchangeLiquidReserve.rebalanceLiquidReserve` |
| `UniswapV4StandardExchangeCallbackFacet.sol` | `IUnlockCallback.unlockCallback` |
| `UniswapV4StandardExchangeQuoteFacet.sol` | `IStandardExchangeIn.previewExchangeIn`; `IStandardExchangeOut.previewExchangeOut`; `IStandardExchangeInMulti.previewExchangeInManyToOne`; `IStandardExchangeOutMulti.previewExchangeOutOneToMany` |
| `UniswapV4StandardExchangeStateQuoteFacet.sol` | `IStandardExchangeTransitionQuote.quoteState`; `.quoteAssets`; `.quoteShareBalance`; `.quoteTotalSupply` |
| `UniswapV4StandardExchangeTransitionQuoteFacet.sol` | `IStandardExchangeTransitionQuote.quoteTransition` |
| `UniswapV4StandardExchangeExternalQuoteFacet.sol` | `IStandardExchangeExternalQuote.quoteExternalExchange`; `.quoteExternalDeposit` |
| `UniswapV4StandardYieldDepositFacet.sol` | `IStandardizedYield.deposit` |
| `UniswapV4StandardYieldRedeemFacet.sol` | `IStandardizedYield.redeem` |
| `UniswapV4StandardYieldQueryFacet.sol` | `IStandardizedYield.exchangeRate`; `.yieldToken`; `.assetInfo`; `.getTokensIn`; `.getTokensOut`; `.isValidTokenIn`; `.isValidTokenOut`; `.previewDeposit`; `.previewRedeem`; `.getRewardTokens`; `.accruedRewards`; `.rewardIndexesStored` |
| `UniswapV4StandardYieldRewardsFacet.sol` | `IStandardizedYield.rewardIndexesCurrent`; `.claimRewards` |

This is one 21-cut product package, not a choice between 14, 16, and 21 cuts. The current package's fifteen interface IDs remain advertised at proxy/package level. Do not append SY selectors to old IN or multi-query facets after installing the new SY owners.

### Factory-provided infrastructure: six permanent selectors

| Owner | Selector identities |
|---|---|
| `lib/crane/contracts/introspection/ERC165/ERC165Facet.sol` | `IERC165.supportsInterface` |
| `lib/crane/contracts/introspection/ERC2535/DiamondLoupeFacet.sol` | `IDiamondLoupe.facets`; `.facetFunctionSelectors`; `.facetAddresses`; `.facetAddress` |
| `lib/crane/contracts/introspection/ERC8109/ERC8109IntrospectionFacet.sol` | `IERC8109Introspection.functionFacetPairs` only |

Keep the factory's temporary `IPostDeployAccountHook.postDeploy` owner at `lib/crane/contracts/factories/diamondPkg/PostDeployAccountHookFacet.sol` and its existing removal lifecycle. Do not duplicate `facetAddress` onto ERC8109 or retain a construction-only selector on the final vault. These infrastructure owners were read during my original design pass and are not new product features.

## 4. Deletion and acceptance closure

Adopt the original Astra keep/move/delete table with this ownership set. In particular, remove the family-wide Common/InBase/OutBase, both execution delegates and their wiring, the empty OutTarget combiner, the old four query-target/facet pairs, and the generic legacy yield-routing target. Preserve and narrow the designated existing execution/import/reserve targets; add only the successor paths listed here. Keep the actual shared SY aggregate for existing other-family behavior while removing its necessity as an error namespace.

No family money facet calls or delegatecalls the diamond to reuse execution or a quote. The one installed callback remains a genuine manager callback. Include the legacy disable correction; preserve explicit holders, supported SE/SY routes, full-range managed backing, funded sleeves, and native/WETH accounting. Propagate unexpected rebalance protocol failures. Do not infer new economics from another family's implementation or from an old defective credit calculation.

The 24,576-byte hard cap and 23,000-byte advisory target remain measurement gates, not permission to retain a hop or select a different ownership table. No draft has demonstrated a compiled size result for its proposed successor architecture. If the selected partition fails the hard cap, preserve evidence and request an explicit design revision; do not silently merge/split selectors or weaken behavior.

**Remaining dissent:** MiniMax's retained execution hops are nonconforming. Grok and Kimi provide alternative partitions, but I recommend the single explicit Astra partition above for consolidation; their alternatives are not optional branches for the implementer. No peer agreement or runtime pass is claimed.

I did not run Forge.
