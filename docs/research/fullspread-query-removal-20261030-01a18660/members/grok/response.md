# Full-spread query and getRate removal — Grok original

## 1. Identity and assigned route, not a runtime attestation

Grok, independent council member, first pass. Assigned route label: `xai/grok-4.7:xhigh`. That label is not a runtime attestation.

This original answers the owner question recorded in the brief. It does not edit the published PRD, does not implement, and does not authorize implementation. The published full-spread PRD is evidence of what the current text requires. It is not a veto of the question, and it is not already an answer to it.

## 2. Direct answer: remove, keep, or split

Split.

Keep the eleven PairToken query selectors. Do not install `getRate()`.

The owner's reason is that the rate policy is not known at creation. That reason reaches `getRate`. It does not reach pool identity, the native-face binding, position identity, the raw basket, or the zap limits. Bundling those eleven with `getRate` deletes a discovery surface in order to avoid choosing a formula. Those are different decisions.

I agree with the brief's boundary. Do not expand the removal to `exchangeIn`, `previewExchangeIn`, the paired methods, SY `exchangeRate`, or the five shared facets. None of those is inseparable from the eleven query selectors. The admitted hook calls `previewExchangeIn` and `exchangeIn`, and the package calls `vaultTokens()`, `decimals()`, and `symbol()`. That is why those stay. It is not why they should be removed.

The published PRD rejected an earlier omission of `getRate` while a one-share exit rate was still the instruction. That rejection does not survive the owner's new statement that the rate policy is unknown. Restoring PairToken's refusal to install `IRateProvider` is the record that matches the new statement. It is not a vote to invent a different formula.

The full-spread vault is specified, not deployed, in the admitted sources. Removal does not regress a live vault. It contradicts the published full-spread text, and it removes the vault as a candidate hook rate provider.

## 3. Problems caused by removing the eleven queries, each with a caller or interface that needs it, or an explicit "no external caller found"

No external caller of these eleven selectors was found in the admitted dual buffer-hook package. `UniswapV4DualStandardExchangeBufferConstantProductHookCommon` calls `IStandardExchangeIn.previewExchangeIn` and `exchangeIn`. It does not call `poolManager`, `poolKey`, `wrappedNative`, `rateAsset`, `tickLower`, `tickUpper`, `positionLiquidity`, `localReserves`, `basket`, `maxZapBps`, or `maxZapTickMove` on the vault. The same absence holds in the dual package interface, `DFPkg`, `Repo`, and `ClaimLib`. "No external caller found" means that package, not a repo-wide proof. UI, indexers, tests, and the other hook families were outside this pass.

The interface that needs them is the inherited family query surface: PairToken `S1-API-01` and the eleven signatures in `S1-API-05`. Full-spread `FS-FACET-01` puts those eleven, plus `getRate`, on `queryFacet`. No full-spread delta removes the eleven. Dropping them is a new delta. It is not required by the rate question.

Dropping a selector does not drop the stored value. Execution can keep the pool key, ticks, zap limits, and `rateAsset` in storage and still lose the public witness. That is the damage, selector by selector.

| Selector | Interface that needs it | External caller in the admitted dual package | What breaks if the selector is dropped |
| --- | --- | --- | --- |
| `poolManager()` | `S1-API-01`, `S1-API-05` | No external caller found | The family no longer states which manager it is bound to. The hook has its own manager binding and does not read this selector. Internal settlement can keep the stored manager. |
| `poolKey()` | `S1-API-01`, `S1-API-05` | No external caller found | The family no longer states the hookless key it owns. Swaps can still use the stored key. A reader cannot check currency order, fee, tick spacing, or the zero hook from the vault. |
| `wrappedNative()` | `S1-ARCH-03`, `S1-NATIVE-01`, `S1-API-05` | No external caller found | `S1-NATIVE-01` requires the canonical wrapper to be exposed through the family query interface. Native entry and payout use the stored binding, not this selector. The binding becomes undiscoverable. Package binding identity still includes the wrapper if `PkgInit` keeps it. |
| `rateAsset()` | `S1-ARCH-03`, `S1-API-05` | No external caller found | The selector is the family witness of the stored SY denomination. No admitted hook reads it. SY `assetInfo()` still reports the same stored face under `S1-QUOTE-02`, so the value is not only on this selector. Removing the selector does not remove the init argument, and it does not decide `getRate`. |
| `tickLower()` | `S1-ARCH-02`, `S1-API-05`; full-spread `FS-UNLOCK-02` names these ticks as the only position written | No external caller found | The family no longer states the full usable lower tick. The position can still be the salt-zero full-range position. Acceptance rows that read the manager can still see the tick. The vault's own witness is gone. |
| `tickUpper()` | Same as `tickLower()` | No external caller found | Same as `tickLower()`, for the upper tick. |
| `positionLiquidity()` | `S1-ARCH-02`, `S1-API-01`, `S1-API-05` | No external caller found | `S1-ARCH-02` forbids conflating pool active liquidity with owned liquidity. This selector is that distinction. The manager can still be read. The family no longer publishes owned liquidity, including the zero before the first deposit. |
| `localReserves()` | `S1-API-01`, `S1-API-05`, `S1-NATIVE-01` | No external caller found | This is booked local custody in raw pool currencies. Shared `reserves` / `reserveOfToken` stay, and they report ERC-20 faces, with a native leg under the wrapped face. `S1-NATIVE-01` says family pool, basket, and local queries retain raw-currency identity, and that ETH and its temporary wrapped form are not two reserves. Dropping `localReserves()` collapses that raw witness into the wrapped-face shared view. |
| `basket()` | `S1-API-01`, `S1-API-05`, `S1-ACC-01` | No external caller found | `S1-ACC-01` defines a raw `basket()` observation as principal plus booked idle, distinct from a fee-inclusive accounting rate and from a prepared execution preview. Dropping it leaves `exchangeRate` and previews as the easy substitutes. That is the confusion the query exists to prevent. |
| `maxZapBps()` | `S1-ARCH-03`, `S1-API-05` | No external caller found | The cap still governs zap sizing and the compound quarter-cap if `PkgArgs` keeps it. There is no silent default. A depositor cannot read the cap that will reject the zap. |
| `maxZapTickMove()` | `S1-ARCH-03`, `S1-API-05` | No external caller found | Same as `maxZapBps()`, for the tick bound. |

Shared problems if the eleven are removed as a bundle:

- `S1-API-05` and `FS-FACET-01` no longer match the proxy. `S1-A06` requires every package selector to be callable. A manifest that still lists the eleven fails. A manifest that drops them is a new family ABI, not an inherited one.
- `S1-SEC-01` gives family basket, position, and local-book queries a busy-vault rule: revert `ReentrantOperation`. Shared reserve reads return the last committed snapshot. Deleting the family queries deletes that read class. It does not make the shared snapshot a substitute.
- `queryFacet` would have nothing to install if `getRate` is also absent. The facet field in the twelve-field `PkgInit` would be an empty cut, or the field would have to be removed. Removing the field changes the PairToken `PkgInit` shape that `FS-FACET-01` and `FS-PKG-01` keep. That is a larger package break than the rate question.

`previewWithdrawalMode` and `previewZapCredit` sit in the same `S1-API-05` code block, but they are not in the eleven. Full-spread places them on `quoteFacet`. Do not treat them as part of this removal.

## 4. Problems caused by removing `getRate`, including hook integration and the fact that the rate policy is undecided

Removing `getRate` is the change that matches the owner's statement. The problems are real, and none of them is a reason to invent a formula.

What the published text currently requires:

- `FS-X02` installs `IRateProvider.getRate()` as the executable normalized one-share exit into `rateAsset`.
- That sentence is the named override of PairToken `S1-API-04`, which refuses to install a Balancer rate provider and says a later adapter must define its own normalized single-share withdrawal-and-sale quote. It must not equate that quote with issuance or silently reuse the SY accounting rate.
- `FS-FACET-01` expects 12 query selectors, not 11, and rejects a query facet that lacks `getRate`.
- `FS-PKG-02` rejects a missing or duplicate `getRate` as `InvalidComponent`.
- `FS-RATE-01` defines `getRate` as the floor-normalized `previewExchangeIn` of `1e18` shares into `rateAsset`, reverting below one whole share. The published text already forbids NAV, SY `exchangeRate`, a cached rate, a 1:1 bootstrap, and the full-book `StandardExchangeRateProviderFacet` as substitutes.
- `FS-HOOK-02` says that where the package requires a provider because the token is not the share, the provider's `getRate` is this vault's `getRate`, and only when the leg token equals `rateAsset`.

Those sentences are why a literal reading of the published PRD cannot drop `getRate` without a revision. They are not an external production caller. They are the text the owner is now questioning.

What the admitted hook actually does:

- Package interface `IUniswapV4DualStandardExchangeBufferConstantProductHookPackage` declares `RateProviderRequired` and takes `rateProvider0` / `rateProvider1` as separate `PkgArgs`. The comment on those fields says a provider is required when `tokenN != standardExchangeN`, and optional on an identity leg. The provider is not required to be the vault.
- `DFPkg._validateArgs` enforces that at lines 387-388: if `token0 != standardExchange0` and `rateProvider0` is zero, revert `RateProviderRequired`, and the same for leg 1.
- `Repo` stores those providers for a buffered leg (`token != se`). The comment says the provider is optional on an identity leg.
- `ClaimLib._rate` staticcalls `IRateProvider.getRate.selector` on the bound provider (line 203). A failed call, a short return, or a zero rate reverts `RateProviderFailed`. If the provider address is zero and the leg is identity (`pair == se`), it returns `RATE_PRECISION` and does not call `getRate` (lines 200-201). A zero provider on a buffered leg reverts `RateProviderRequired`.
- `HookCommon` does not staticcall `getRate`. Its buffer and unwrap path calls `previewExchangeIn` and then `exchangeIn` (`_buffer` at line 357, `_unwrap` at line 370). The comment at line 194 says the provider rate never enters LP issuance. Issuance uses raw share balances. The rated book is a separate read, through `ClaimLib.ratedReserve`.

So:

- A full-spread vault without `getRate` can still be built, and the admitted hook can still buffer and unwrap it through `previewExchangeIn` / `exchangeIn`, if some other contract is bound as `rateProvider`.
- The published plan that binds this vault as that provider cannot be executed. A staticcall to a missing `getRate` fails, and `ClaimLib` reverts `RateProviderFailed`.
- The hook package will not deploy a buffered leg with a zero provider. The failure is at hook bind, not inside vault money logic.
- An identity leg would skip the provider only when `token == standardExchange`. The published full-spread text says current hooks reject `token == share` unless `asset()` exists, and it forbids adding `asset()` to make that bind pass (`FS-A24`, section 2.1). This pass did not re-read that rejecting function. If that published claim holds, the no-provider identity path is not available for this share. Do not add `asset()` to create it.
- Because the rate policy is undecided, a separate rate-provider contract is not an available substitute. Binding an unnamed formula is the same gap as installing `getRate` on the vault. The honest result is that a buffered bind of this share waits.

What does not break:

- Vault issuance. `FS-A16` already says issuance does not read `getRate` or `exchangeRate`. The hook comment agrees for LP issuance.
- `previewExchangeIn` and `exchangeIn`. They are amount-specific executable routes. `FS-RATE-01` forbids treating `amount * getRate` as the preview. Removing `getRate` does not remove the preview.
- SY `exchangeRate()`. That is `S1-QUOTE-02`: raw rate-asset units per `1e18` raw shares, spot accounting, zero at zero supply, not an exit quote, not a WAD oracle, not an issuance input. It remains specified. It is not the undecided rate, and it must not be wired up as `IRateProvider.getRate`.
- The eleven queries.
- PairToken stage one, which already omits `getRate` under `S1-API-04`. Full-spread was the override. Suspending the override returns this family to that refusal. It does not amend PairToken.

What must not be installed in the hole:

- A zero return. The published text already rejected that.
- A 1:1 bootstrap. Both `S1-QUOTE-02` and `FS-RATE-01` reject it.
- NAV, a whole-book liquidation divided by supply, or `StandardExchangeRateProviderFacet._getRate`.
- SY `exchangeRate` presented as `getRate`. The units differ, and one is an accounting spot while the other was defined as an executable exit.
- A second `getRate`, or a `rateAsset` that changes per caller.
- A package-owned provider facet whose formula is unnamed.

The undecided policy also means the published one-share formula is not a reserved default. A later delta may choose that quote, another quote, or no vault-level rate. This original does not choose.

Selector and error consequences inside the published text, if `getRate` is removed and the text is not revised:

- `FS-PKG-02` cannot deploy, because a query facet without `getRate` is `InvalidComponent`.
- `FS-A01` expects 61 selectors. The count with `getRate` removed is 60: 20 shared and 40 family. `queryFacet` returns to 11.
- `FS-A12`, `FS-A13`, `FS-A14`, `FS-A15`, `FS-A29`, and the `getRate` clause of `FS-A32` have nothing to assert.
- `InsufficientRateSupply`, `RateNormalizationOverflow`, and `RateUnavailable` imply a formula. They should not be declared while no rate is installed. `InvalidUnlockedContext`, `IncompleteConversion`, and `SettlementMismatch` are not rate errors and stay.

## 5. What must stay if those are removed

Under the recommended split, the eleven stay and `getRate` does not. This list is what removal must not take with it. If the eleven were removed against that recommendation, the stored values in the last group would still have to stay.

Money and quotes the admitted hook calls:

- `exchangeIn` and `previewExchangeIn`, on the existing facets. `HookCommon._buffer` and `_unwrap` call them while the PoolManager can already be unlocked. `FS-X01` exists for that caller. Do not replace them with a new unlocked selector.
- The other exact-input routes those calls use: share to `rateAsset` or pool token, and pool token to share.

Paired and maintenance surface, not part of the eleven:

- `depositPair`, `redeemPair`, `donate`, `compound`, and their previews.
- `previewWithdrawalMode` and `previewZapCredit`.
- `previewExchangeOut` and `exchangeOut`, installed and reverting `ExchangeOutNotAvailable`.

SY, including the accounting rate that is not `getRate`:

- The 16 native SY methods. `exchangeRate()` and `assetInfo()` stay under `S1-QUOTE-02`.
- `rateAsset` as a `PkgArgs` field and as the stored SY denomination. Keeping that field is not a `getRate` decision. If the owner also does not know which face SY should account in, that is a separate question. It would rewrite `S1-QUOTE-02`. This removal list does not include it, so this original does not drop it.

Shared facets, because a cited caller needs three of their selectors:

- All five shared facets and their 20 selectors.
- `IBasicVault.vaultTokens()`, because `DFPkg._requireTokenInVaultTokens` reads it at line 393 before it will bind a leg.
- `decimals()` and `symbol()`, because `DFPkg._readDecimals` and `_safeSymbol` read them on the standard exchange and on the leg tokens.
- `reserves` / `reserveOfToken`, because `S1-SEC-01` makes them the last committed snapshot, distinct from the family basket.

Callback and native I/O:

- `unlockCallback`.
- Native ETH entry, payout, and the stored wrapped-native binding. `S1-NATIVE-01` is not a query-selector feature. Dropping `wrappedNative()` would hide it. It would not turn native pools into ERC-20-only pools.

Stored family state, whether or not the eleven selectors remain public:

- Pool manager, pool key, full-range ticks, salt-zero position, owned liquidity, booked local reserves in raw currencies, basket components, `maxZapBps`, `maxZapTickMove`, and `rateAsset`.
- Zap limits still have no silent default.
- The twelve-field `PkgInit` shape stays. Do not delete `queryFacet` merely because `getRate` is absent. With the eleven kept, that facet still has 11 selectors.

Explicitly not required to stay:

- `getRate` on this vault.
- A requirement that the hook's `rateProvider` equal this vault.
- The three rate errors named above.
- `asset()`, `IERC4626`, and the transition-quote interfaces. The admitted `ClaimLib` can call `IStandardExchangeTransitionQuote` when a vault advertises it. The published full-spread text already says not to install that interface unless a cited consumer rejects without it. Absence of `getRate` is not that citation.

## 6. The smallest PRD change, if any, that records the owner's undecided rate without inventing a formula

Yes. One suspension, no new formula, no new facet, no new provider argument.

Replace `FS-X02` and withdraw its override of `S1-API-04`. Proposed record text:

> FS-X02 is suspended. The owner has not decided how any given vault is rated at creation. This family does not install `getRate` and does not implement `IRateProvider`. No formula is chosen by this suspension.
>
> Do not fill that gap with SY `exchangeRate`, a full-book NAV, a zero return, a 1:1 bootstrap, or a provider facet owned by this package. A later rate, if any, requires a named delta that defines its own quote. It is not implied by `IStandardExchangeIn`. It is not an issuance input. It is not the SY accounting rate.
>
> The eleven PairToken query selectors stay on `queryFacet`. The query count is 11. Package-owned selectors are 60: 20 shared and 40 family. Package validation does not require `getRate`.
>
> `rateAsset` stays the inherited SY denomination under `S1-QUOTE-02`. That stored face is not a `getRate` policy and is not a hook rate-provider quote.
>
> The current dual buffer package reverts `RateProviderRequired` when `token != standardExchange` and that leg's rate provider is zero. This vault is not that provider. A buffered bind of this share is unresolved until a later delta names the quote. Do not add `asset()` to force an identity bind, and do not treat an identity bind as the rate decision.

Sentences the revision has to strike or rewrite so the file does not contradict that record:

- Section 1.2 `FS-X02`, and the inherit sentence that excepts "the provider sentence" of `S1-API-04`. With `FS-X02` suspended, `S1-API-04`'s refusal applies.
- Section 2.1 `getRate` row. The omitted-rate choice is the one that now matches the owner. The thirteenth facet and the zero return stay rejected.
- `FS-FACET-01` query count 12, the 61-selector total, and the check that rejects a query facet without `getRate`.
- `FS-PKG-02` missing-or-duplicate `getRate` check.
- `FS-MONEY-01` "plus `getRate`".
- Section 6 `getRate` row and all of `FS-RATE-01`.
- `FS-HOOK-02` step 1, where the provider's `getRate` is this vault's `getRate`.
- `FS-TEST-02` sentence that `getRate` is required on the 61-selector manifest.
- `FS-A01` selector count; `FS-A12` where it requires a difference from `getRate`; `FS-A13`; `FS-A14`; `FS-A15`; `FS-A29`; the `getRate` clause of `FS-A32`.
- The three rate errors in `FS-FACET-01`.
- Section 9's sentence that omission of `getRate` stays rejected. Left in place, it contradicts the owner. The coordinator replaces it. This original does not edit that file.

Do not add a rate formula, a per-vault rate enum, or a hook allowlist in that edit. Do not change PairToken stage one.

## 7. Limits

- Admitted sources were the published full-spread PRD, the PairToken stage-one sections on architecture, native faces, the route table, quotes, and the family ABI, and the dual buffer-hook example. Checking the package requirement also used that family's package interface, `DFPkg`, `Repo`, and `ClaimLib`. `HookCommon` alone does not show the `getRate` staticcall.
- No peer originals were read.
- No external caller search was done outside that dual package. Absence of a caller there is not absence everywhere.
- The `asset()` identity reject was taken from the published full-spread text. The rejecting function was not re-read.
- Selector hex was not computed. The 60-selector count is arithmetic from `FS-FACET-01` minus `getRate`, not a loupe dump.
- No Forge, install, deploy, Git, or sub-agent was run. The published PRD was not edited.
- This original does not choose the rate, does not reserve the one-share formula, and does not authorize implementation.
