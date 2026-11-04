# Identity and assigned route

Kimi, independent council member. Assigned route label: `kimi-coding/k3.1-pro:high`. This is the assigned label, not a runtime attestation.

# Direct answer: split

**Split the core vault surface from buffered-hook rate integration.** The full-spread vault can drop the eleven PairToken query selectors without removing any economic capability: the admitted hook does not call them, and the state they expose remains available internally to execution and accounting.

It can also drop `getRate()` as a required vault selector while the owner has not chosen a rate policy. That is a return to inherited S1-API-04, which does not install `IRateProvider`, rather than a defect in the core Standard Exchange vault. But it is **not** compatible with continuing to claim the current canonical buffered-hook integration. For a buffered leg whose pool token is not the Standard Exchange share, the current hook package requires a rate provider; the published full-spread PRD binds that provider to this vault's `getRate()`. Removing it leaves that integration unresolved until the owner chooses a provider and rate policy.

Accordingly, do not preserve the present one-share formula merely to keep hook tests green, and do not substitute SY `exchangeRate()`, NAV, a whole-book rate, zero, or a 1:1 creation rate. If buffered-hook support remains release-blocking, that support must wait for an explicit rate decision; it is not a reason to invent one here.

# Problems caused by removing the eleven queries

S1-API-01 and S1-API-05 require this family query interface, so removing it is an explicit full-spread API delta and requires corresponding PRD and selector-manifest changes. Within the admitted sources, however, the requirement is declarative rather than caller-driven. `UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol` calls the vault's ERC-20 and Standard Exchange surfaces; it does not call any of these eleven getters.

| Selector | Caller or interface that needs it, and consequence of removal |
| --- | --- |
| `poolManager` | Required by the inherited family query interface in S1-API-01/S1-API-05. **No external caller found in the admitted sources.** The hook uses its own bound `Repo._layout().poolManager`. The vault must retain its internal PoolManager binding for unlocks, swaps, liquidity, settlement, and `isUnlocked`; only public discovery disappears. |
| `poolKey` | Required by S1-API-01/S1-API-05. **No external caller found in the admitted sources.** Removing the getter removes direct on-chain discovery of the pool identity, not the immutable pool key used by execution, position ownership, or validation. |
| `wrappedNative` | Required by S1-API-01/S1-API-05 and exposes the binding described by S1-NATIVE-01. **No external caller found in the admitted sources.** Native/wrapped adaptation still needs the internal binding; shared `vaultTokens()`, SY token discovery, and `assetInfo()` remain separate surfaces. |
| `rateAsset` | Required by S1-API-01/S1-API-05. **No external caller found in the admitted sources.** The configured rate asset must still exist for SY `assetInfo()` and `exchangeRate()` under S1-QUOTE-02 even if both this getter and `getRate()` are removed. |
| `tickLower` | Required by S1-API-01/S1-API-05. **No external caller found in the admitted sources.** The full-range position identity and execution still need the lower tick internally. Direct public position-range discovery is lost. |
| `tickUpper` | Required by S1-API-01/S1-API-05. **No external caller found in the admitted sources.** The full-range position identity and execution still need the upper tick internally. Direct public position-range discovery is lost. |
| `positionLiquidity` | Required by S1-API-01/S1-API-05. **No external caller found in the admitted sources.** Owned liquidity remains an accounting and execution input. Removing the view removes a convenient deployed-position observation, not the position or its liquidity. |
| `localReserves` | Required by S1-API-01/S1-API-05. **No external caller found in the admitted sources.** Booked local balances and operation reservations must remain internally consistent. The shared `IBasicVault.reserveOfToken/reserves` snapshot is a different surface and stays. |
| `basket` | Required by S1-API-01/S1-API-05. **No external caller found in the admitted sources.** Principal plus booked idle remains the economic book used by accounting and previews. Removing the raw observation does not remove SY accounting or executable quotes. |
| `maxZapBps` | Required by S1-API-01/S1-API-05. **No external caller found in the admitted sources.** Entry sizing and the compound cap still need the immutable configured value and its deployment-identity validation. |
| `maxZapTickMove` | Required by S1-API-01/S1-API-05. **No external caller found in the admitted sources.** Entry-swap tick-movement enforcement still needs the immutable configured value. |

The practical loss is therefore introspection: integrators can no longer read the pool key, range, owned liquidity, raw basket, local book, wrapper, or zap configuration through this dedicated family ABI. That can break unexamined off-chain or on-chain consumers, but none is present in the admitted caller set. It does not justify removing the underlying configuration, reserve accounting, shared vault discovery, or execution previews.

# Problems caused by removing `getRate`

## Current hook integration

The published PRD makes `getRate()` part of the integration, not merely an informational getter:

- FS-X02 installs `IRateProvider.getRate()` and overrides S1-API-04's decision not to install a provider.
- FS-HOOK-02 makes FullSpread a buffered leg, sets the pool token to its `rateAsset`, and binds the package-required provider to this vault's `getRate()` when the token is not the share.
- FS-A25, FS-A26, and FS-A29 rely on that buffered configuration and provider binding.

The current dual buffer-hook common code shows why this matters beyond minting and burning. `_buffer()` and `_unwrap()` use `previewExchangeIn` and `exchangeIn`, but `_claimSupply()` delegates to `ClaimLib.ratedReserve(se)`, and `_claimOfSe()` delegates to `ClaimLib.ratedOf(se, seAmount)`. Those rated claims feed liveness, deposit clamps, swap quotes, zap sizing, protocol-fee calculations, and reserve publication. Thus the continued existence of `exchangeIn` does not by itself preserve the hook's book logic when its expected provider disappears.

Removing `getRate()` without another admitted provider therefore has these concrete effects:

1. The FS-HOOK-02 canonical cross-vault fixture can no longer be assembled as specified.
2. FS-A29's provider assertion is impossible, and the buffered-route claims in FS-A25/FS-A26 cannot remain passing requirements under the current binding.
3. Other current buffer-hook family rows must be treated as unresolved wherever their topology requires the same non-identity provider; they are not rescued by the exact-input execution surface alone.
4. A future provider must also resolve denomination and creation/bootstrap behavior. The current PRD's one-share exit rule, its below-`1e18` supply revert, and its `rateAsset` denomination are choices, not inevitable consequences of `IRateProvider`.

This does **not** break direct paired or single-token vault operations, SY operations, or the Standard Exchange route table. Those use their own accounting and amount-specific previews, not `getRate()`. Nor does it justify adding ERC-4626 `asset()` or treating an identity leg as the canonical buffered route.

## Undecided rate policy

The owner's new statement removes the basis for treating FS-RATE-01 as settled. The published formula is a normalized executable one-share exit; S1-API-04 originally left the vault without `IRateProvider` and required any later adapter to define its rate explicitly. With the policy undecided, the correct default is no provider requirement, not an unspecified implementation of `getRate()` and not reuse of SY `exchangeRate()`.

The unresolved integration consequence should be recorded alongside that removal. Otherwise the PRD would simultaneously say there is no rate policy and promise provider-dependent hook routes that cannot be configured.

# What must stay if those are removed

- **The immutable economic configuration and state.** Keep the PoolManager and pool-key bindings, wrapped-native binding, full-range ticks, owned position and liquidity, booked local reserves and reservations, `rateAsset` initialization argument and validation, and both zap limits. Dropping getters must not drop `PkgArgs`, deployment identity, validation, or internal accounting.
- **The exact-input Standard Exchange surface.** Keep `exchangeIn` and `previewExchangeIn`, including FS-X01/FS-UNLOCK's already-unlocked execution path. The admitted hook directly calls both in `_buffer()` and `_unwrap()` and uses previews throughout its quote logic. Keep all four S1-API-02 currency/share routes and their execution-equivalent behavior.
- **The rest of the money, quote, callback, and paired surfaces.** Keep paired deposit/redemption and previews, donation, compound, withdrawal-mode and zap-credit previews, native SY execution, and the authenticated PoolManager callback. Keep `previewExchangeOut`/`exchangeOut` installed and explicitly reverting `ExchangeOutNotAvailable`; removal of queries is not authorization to alter exact-output behavior.
- **The native SY accounting surface.** Keep all 16 SY methods, especially `assetInfo()` and `exchangeRate()`. SY `exchangeRate()` remains S1-QUOTE-02's raw rate-asset spot accounting value, zero at zero supply, and is not an issuance input, exit quote, or replacement `IRateProvider`.
- **The five shared facets and factory-owned surfaces.** ERC-20/metadata, ERC-2612, ERC-5267, `IBasicVault`, and `IStandardVault` are independent of the family query facet. In particular, shared booked-reserve queries and token/configuration discovery remain. Factory-provided ERC-165, ERC-8109, loupe, and temporary-hook behavior also remain governed by the factory.
- **The operational safety and native behavior.** Keep the shared operation guard, economic-view reentrancy rules, bounded planners, atomic settlement, native wrapping/unwrapping, and registry-disable behavior. None depends on the eleven public getters.

If all twelve selectors are removed, the family `queryFacet` has no remaining selectors. It should disappear from the package rather than remain as an empty component. On the published PRD's arithmetic, the package then has **49 package-owned selectors**: 20 shared plus 29 family selectors. It has **eleven explicit facet inputs**, rather than twelve.

# Smallest PRD change

Do not edit the PairToken stage-one PRD. Make a bounded full-spread revision that:

1. Adds an explicit query-surface delta overriding the family-query row of inherited S1-API-01 and the eleven declarations in S1-API-05. Remove `queryFacet` from FS-FACET-01 and the package inputs, change the manifest to 49 selectors and eleven facet inputs, and delete validation that requires or deduplicates `getRate()`.
2. Withdraws FS-X02 and FS-RATE-01 rather than replacing their formula. With FS-X02 gone, inherited S1-API-04 again controls: no `IRateProvider` is installed by default. Remove `getRate()` from FS-MONEY-01's public surface and remove or revise the getRate-only errors, dispositions, tests, and selector-count references.
3. Records the owner's decision status without specifying economics, for example: **“The vault's `IRateProvider` policy is undecided. This revision installs no `getRate()` and defines no creation-time or ongoing provider rate. SY `exchangeRate()` and amount-specific execution previews are unchanged and are not provider substitutes.”**
4. Marks provider-dependent buffered-hook integration unresolved instead of passed. In particular, revise FS-HOOK-02's provider step and the affected acceptance rows, including FS-A25, FS-A26, and FS-A29. A later owner-approved rate decision can restore a provider and define those routes; no hook edit or alternate provider is authorized by this revision.

That is sufficient to record the new uncertainty. It does not require changing issuance, redemption, SY accounting, native handling, or the exact-input execution engine.

# Limits

This advisory reads only the brief's admitted PRD sections and the admitted dual buffer-hook common source. “No external caller found” means no caller in that admitted set, not a repository-wide or off-chain consumer audit. I did not read peer responses, edit the published PRD, implement code, run Forge, or verify a runtime route. The appropriate future rate formula, provider denomination, bootstrap behavior, and any hook-package change remain owner decisions outside this response.
