# Astra original: full-spread query and getRate removal

## 1. Identity and assigned route, not a runtime attestation

Member: Astra. Assigned route label: `chatgpt-subscription/gpt-6-astra:high`. This identifies the assignment, not independently attested runtime model, provider, account, or effort.

Run: `fullspread-query-removal-20261030-01a18660`, 2026-10-30. Independent original; no other members' responses were read.

Source keys used below:

- **[FS]** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, revision `fullspread-se-prd-final-r2`, read completely.
- **[S1]** `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, especially S1-NATIVE-01, S1-API-01 through S1-API-05, S1-QUOTE-02, and S1-SEC-01.
- **[Common]** `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol`, the current execution and preview call pattern.
- **[Package]** `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol`, especially `_validateArgs`, `_requireTokenInVaultTokens`, and provider initialization.
- **[Claim]** `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol`, especially `_rate`, `_ratedOf`, `_ratedWith`, `previewOutputExactIn`, and `ratedReserve`.
- **[Leg]** `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol`, the directly referenced `isWrapperShareInventory`, `addPairSe`, and `rateAfterExchange` branches.

## 2. Direct answer: remove, keep, or split

**Split. Defer the built-in `getRate()` policy; do not remove eleven unrelated discovery and accounting queries merely because that policy is undecided.**

The vault can, in principle, omit all twelve selectors and still implement proportional ownership, paired operations, amount-specific Standard Exchange conversions, and their previews. Getter removal does not require removal of the underlying state or internal calculations. I found no call to those eleven family getters in the inspected dual buffer-hook execution and binding paths. That is a scoped finding, not a repository-wide compatibility clearance.

However, removing `getRate()` prevents this vault from serving as its own provider in the currently specified buffered-hook fixture. Retaining `previewExchangeIn` does not fix that: the current hook uses an executable conversion quote and a provider rate for different jobs. Conversely, the hook's provider can be a separate address; the package does not require it to equal the Standard Exchange. A future explicitly chosen provider could restore that aspect of integration without putting `getRate()` back on the vault. That is an option, not an approved adapter or rate formula. [Common: `_buffer`, `_unwrap`, `_claimSupply`; Package: `_validateArgs`; Claim: `_rate`]

My recommendation is:

- Keep the eleven existing getters for now. They describe the pool, native binding, ownership, custody, or execution constraints; they do not choose a new valuation policy.
- Remove or suspend the mandatory built-in one-share `getRate` requirement pending the owner's policy decision. Do not replace it with NAV, a constant, a cached rate, or SY `exchangeRate`.
- Record current provider-dependent hook integration as unresolved, rather than claiming the existing cross-vault acceptance proof still passes.

If the owner separately wants the smallest public ABI, removing some or all of the eleven is a coherent choice with the discovery costs below. It is not necessary to resolve the rate-policy question.

## 3. Problems caused by removing the eleven queries

For each row, **"no external caller found" means no such vault-getter caller found in the inspected current dual-hook paths**. The inherited family interface itself requires every listed method under S1-API-01/S1-API-05. Removing them therefore changes the specified family ABI even where no runtime consumer was found.

| Selector | Caller or interface evidence | Consequence and recommendation |
| --- | --- | --- |
| `poolManager()` | No external caller found. S1-API-05 exposes it. The hook has its own configured manager; that is not a call to the vault getter. | Removes direct discovery of the manager holding this vault's position. Internally the binding remains essential for position reads, callbacks, and settlement. Keep for inspecting manager compatibility; removal does not itself make `exchangeIn` impossible. |
| `poolKey()` | No external caller found. S1-API-05 exposes it; S1-NATIVE-01 distinguishes raw currencies from ERC-20 faces. | Loses direct discovery of the full pool identity, including fee, spacing, hooks, and native currency. `vaultTokens()` is not an equivalent replacement: it reports faces, not the complete key. Keep. |
| `wrappedNative()` | No external caller found. S1-ARCH-03/S1-NATIVE-01 specify the binding and its discovery. | Loses an explicit native-to-wrapped mapping. Standard discovery still reports supported faces, and SY discovery still reports native support, but consumers must interpret those conventions or obtain configuration elsewhere. Keep; never remove the internal wrapper binding as a side effect. |
| `rateAsset()` | No external caller found. S1-QUOTE-02 also exposes the selected denomination through `assetInfo()`. | This getter is redundant for consumers willing to use retained SY `assetInfo()`. It is the easiest getter to omit without losing that fact. Its deletion does not remove `PkgArgs.rateAsset`, its validation, or the denomination needed by existing SY accounting. Keeping the getter does not settle a hook-provider policy. |
| `tickLower()` | No external caller found. S1-API-05 exposes it; FS-UNLOCK-02 defines the full usable range. | Removes direct range inspection. The lower bound is derivable from a known key and the specified full-range rule, but discovery must then obtain that key elsewhere if `poolKey()` also disappears. Keep for explicit position identity. |
| `tickUpper()` | No external caller found. Same interface and range requirements as `tickLower()`. | Same consequence for the upper bound. Removing either getter does not authorize a different range or position owner. Keep. |
| `positionLiquidity()` | No external caller found. S1-API-01 requires deployed-ownership discovery. | Removes the direct owned-liquidity query. A reader with manager, pool, owner, ticks, and salt can reconstruct the position externally; pool active liquidity is not the vault's owned liquidity. Basic local-reserve queries do not replace it. Keep. |
| `localReserves()` | No external caller found. S1-API-01/S1-NATIVE-01 define raw-currency local-book reporting. | The retained basic-vault reserve surface reports booked local custody under ERC-20 faces, so much of the idle information survives. It is not identical: raw-native identity differs, and shared reserve views return the last committed snapshot during an operation whereas family economic queries revert. Removal is possible if those distinctions are documented. |
| `basket()` | No external caller found. S1-API-01 and S1-ACC-01 distinguish deployed principal plus booked idle from fee-inclusive accounting and executable previews. | Loses direct raw-asset ownership inspection. `reserves()` is only local custody; `exchangeRate()` is a scalar accounting value; a redemption preview includes preparation and execution effects. None is a faithful drop-in replacement. Keep. |
| `maxZapBps()` | No external caller found. S1-ARCH-03/S1-API-05 expose the immutable configured execution bound. | Removes direct limit discovery useful for explaining rejected amounts and sizing transactions. Actual previews and execution must still enforce the bound. Do not remove the parameter or invent a default. Keep. |
| `maxZapTickMove()` | No external caller found. Same configuration/interface source as `maxZapBps()`. | Removes direct price-movement-limit discovery, not the limit itself. Amount-specific previews remain necessary even with the getter. Keep. |

The practical loss is therefore primarily **observability and ABI compatibility**, not a demonstrated dependency of canonical exact-input hook execution on these eleven methods. Existing callers using the removed selectors would fail, but this examination did not identify an existing deployed caller or frontend using them. Do not invent one.

If all eleven are removed, configuration artifacts can supply static facts and PoolManager reads can help reconstruct deployed holdings. That is a different integration contract, not a claim that the retained shared facets already expose the same information. In particular, neither token balances nor basic local reserves alone report the full owned position. [S1: S1-API-01, S1-NATIVE-01]

## 4. Problems caused by removing getRate

### A concrete current consumer breaks

The dual hook's `_validateArgs` requires a nonzero `rateProvider0` whenever `token0 != standardExchange0`, and the same for leg 1. Missing providers revert `RateProviderRequired()`. The providers are separate package arguments, included in the package's instance salt and stored during initialization. [Package: `_validateArgs`, `calcSalt`, `processArgs`]

At runtime, `_rate` calls the configured provider with `IRateProvider.getRate.selector`. A reverted call, a return payload other than 32 bytes, or a zero result becomes `RateProviderFailed()`. An address without the selector is therefore not a usable substitute merely because it passed the package's nonzero-address check. [Claim: `_rate`]

The current full-spread fixture binds the vault itself as that provider and requires the hook leg token to equal `rateAsset`. Removing its `getRate` invalidates that fixture. In the inspected hook, rated reserves feed the swap book, liveness, contribution clamping, and other calculations; provider failure is not merely a missing display price. Later LP issuance uses raw share-growth ratios, but surrounding operations still read the rated book. [FS: FS-HOOK-02, FS-A25/26/29; Common: `_claimSupply`, `_requireLive`, `_clampToClaimRatio`, `_quoteExactInContext`, `_mintFromClaimDeltas`]

### Preview and execution are not substitutes for the provider

`_buffer` and `_unwrap` call `previewExchangeIn` for the actual amount and then `exchangeIn`. Separately, `previewOutputExactIn` converts a rated output budget into shares using `_rate`, then previews the payout of those shares. The current code therefore requires both capabilities for that buffered route. [Common: `_buffer`, `_unwrap`; Claim: `previewOutputExactIn`]

There is no need to expand the requested removal to `previewExchangeIn` or `exchangeIn`. They are precisely the amount-specific conversion interface that must remain. Removing `getRate` also does not authorize removing borrowed-unlock execution: that requirement remains relevant to any future provider-backed integration.

### A separate provider is possible, but its policy is still missing

The current hook can bind another provider address. This avoids requiring every vault to choose a universal hook valuation when it is created. It does **not** make the decision disappear: before a buffered hook can be accepted, its provider must have an explicitly selected denomination, scale, economic meaning, failure behavior, and compatibility with the execution context and budgets.

A one-share executable exit, whole-book liquidation value, spot accounting value, and an independently chosen pricing policy are different choices. The published one-share definition is not owner authority against the new question; neither is it permission to substitute another formula. Do not automatically reuse `StandardExchangeRateProviderFacet` or forward SY `exchangeRate` and call it equivalent. [FS: section 6 and FS-RATE-01]

An already non-upgradeable vault need not gain a new selector merely to support a separately bound provider later, but the chosen provider must be implementable from available information. Removing all discovery getters can make that future integration harder. No provider implementation or migration has been established here.

### Identity inventory is not a demonstrated escape

The no-provider identity branch is not a general proof that this share can be used directly in the current hook. `_requireTokenInVaultTokens` accepts recognized wrapper-share inventory or requires membership in `vaultTokens()`. `isWrapperShareInventory` requires `token == se` and a successful `asset()` probe returning a different nonzero underlying. FullSpread intentionally does not install `asset()`, and its `vaultTokens()` contains currency faces, not its share. The ordinary identity bind therefore fails this package's membership check. `addPairSe` also rejects unrecognized pair/share overlap. [Package: `_requireTokenInVaultTokens`; Leg: `isWrapperShareInventory`, `addPairSe`; FS: section 1.1, FS-HOOK-04]

Do not add `asset()`, misreport `vaultTokens()`, or edit the hook to conceal that separate limitation.

### Rate policy remains partly present through SY

Deleting `getRate()` does not make the current PRD wholly valuation-neutral. Retained `assetInfo()` and `exchangeRate()` still have the inherited S1-QUOTE-02 denomination and spot-accounting definition, including raw-unit scaling and zero at zero supply.

If the owner's uncertainty concerns only the hook's rate-provider policy, these SY requirements can remain unchanged. If it includes **all** scalar valuation and the creation-time denomination, that is a separate unresolved change to `rateAsset`, `assetInfo`, and `exchangeRate`. This assignment does not authorize removing those SY methods. The honest response is to flag that boundary, not silently delete them or assert that removing the twelve selectors eliminates every rating decision.

## 5. What must stay if those are removed

Within the present product scope, retain:

1. **All five shared facets and their 20 selectors.** In particular, `IBasicVault.vaultTokens()` is a real package-binding dependency, and ERC-20 balances, metadata, approvals, and transfers are used throughout hook execution. `IStandardVault` discovery remains part of the specified vault contract. Keep factory-provided introspection separate from package cuts. [Package: `_requireTokenInVaultTokens`, `_readDecimals`; Common: `_buffer`, `_unwrap`; FS: FS-FACET-01/02]
2. **`exchangeIn` and `previewExchangeIn`, with all four supported currency/share routes and exact amount semantics.** Preserve native/wrapped adaptation, minima, deadline and authority checks, complete single-token conversion or atomic rejection, and borrowed-unlock settlement. [S1: S1-API-02, S1-NATIVE-01; FS: FS-MONEY-01, FS-UNLOCK-01 through FS-UNLOCK-03]
3. **Paired entry, paired exit, and their previews.** Paired entry bootstraps supply; paired exit retains its specified proportional withdrawal and maintenance-fallback role. Keep `previewWithdrawalMode`, `previewZapCredit`, `donate`, and `compound`; these are outside the eleven-query removal. [S1: S1-API-02/05; FS: FS-FACET-01]
4. **The installed exact-output rejection contract.** `exchangeOut` and `previewExchangeOut` continue to revert `ExchangeOutNotAvailable()` without taking funds. A provider does not create exact-output support. [FS: FS-HOOK-03, FS-A09/28]
5. **The complete SY surface under the currently retained scope**, including `exchangeRate`, `assetInfo`, native discovery and payment forms, and empty reward semantics. Keep the accounting-rate/exit-quote distinction explicit; retain the creation-time denomination unless separately revised. [S1: S1-API-03, S1-QUOTE-02]
6. **Internal configuration, ownership accounting, limits, and guards.** Manager, key, wrapper, full-range ticks, owned liquidity, booked/reserved inventories, fee attribution, zap bounds, and authenticated callbacks remain necessary even without their getters. No change to issuance follows from removing a scalar provider. [FS: FS-PKG-01/02, FS-UNLOCK-02, FS-A16]
7. **A truthful integration boundary.** If provider-dependent buffered-hook support remains a deliverable, a usable provider must eventually exist and be validated for that binding. Until then the required provider-dependent proof is unresolved, not passed and not silently replaced with an identity-only trade.

## 6. The smallest PRD change, if any, that records the owner's undecided rate without inventing a formula

No published PRD edit was made. I recommend a narrow prospective amendment that keeps the eleven getters and records only the newly undecided provider policy:

> **Rate-provider decision pending.** The owner has not selected the rate-provider policy for this family. FS-X02 and FS-RATE-01's mandatory built-in `getRate()` definition are suspended pending that decision. No replacement formula, adapter, denomination, bootstrap value, or fallback rate is selected by this amendment. The eleven family discovery/accounting selectors remain required. Amount-specific execution and preview semantics, share issuance, and the existing SY accounting contract remain unchanged. Provider-dependent buffered-hook integration remains an unresolved requirement and must not be reported as passing until an explicitly selected provider and its binding have been validated. A separate provider is an option for later decision, not an approved implementation.

That paragraph needs the following limited consistency edits if adopted:

- Update section 2 precedence and the historical-disposition table so the earlier requirement to install `getRate` does not override this new pending decision. Do not accidentally reinstate S1-API-04's later-adapter formula as a decision already made for this family.
- In FS-FACET-01 and FS-PKG-02, remove the mandatory `getRate` selector check and `IRateProvider` advertisement. Keep `queryFacet` with eleven selectors. The proposed package count becomes **60 selectors**, still **12 facet inputs**. Reconcile FS-MONEY-01's surface description and selector-manifest acceptance references.
- Mark provider-only errors and FS-A13 through FS-A15 as tied to the suspended policy rather than current implementation requirements. Preserve FS-A12's SY accounting assertion without requiring comparison to an absent getter; preserve FS-A16's issuance independence and FS-A32's remaining economic-view guards.
- Reconcile FS-HOOK-02 and FS-A25/26/27/29/31/38 with the provider decision dependency. Keep the underlying integration goals and unrelated exact-output, topology, and settlement requirements; do not turn an unresolved provider-dependent row into a pass.

If the owner instead elects to remove **all twelve** selectors, that is a larger ABI amendment: **49 package-owned selectors** remain, and an empty query facet should not be required just to preserve a twelve-field shape. Removing that facet would mean **11 facet inputs**, with corresponding changes to package interfaces, bindings, manifests, files, and inherited S1-API-01/05 overrides. These are arithmetic and specification consequences, not implementation instructions or approval.

Finally, the amendment should explicitly state whether the retained SY policy is outside the owner's uncertainty. No formula needs to be invented to record that unresolved boundary.

## 7. Limits

This is a source-based original opinion, not an implementation, deployment compatibility certification, or audit. The published PRD is a specification, not evidence that this family or a particular consumer is deployed.

The caller finding is limited to the admitted current dual-hook family and directly referenced provider/leg code. It does not establish that all frontends, scripts, other hook families, or external consumers are free of family-getter dependencies. I did not inspect other members' originals.

No Forge command, build, test, installation, Git operation, deployment, wallet operation, external-source search, or delegation was performed. The source was not sent to public search. No rate formula or adapter was selected; no runtime or gas result is claimed. Only this assigned response file was written, and this original does not authorize implementation or amend the published PRD.
