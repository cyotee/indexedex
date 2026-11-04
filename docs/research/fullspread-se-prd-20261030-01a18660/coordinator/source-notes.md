# Coordinator source notes — full-spread PRD

These are coordinator observations for the later draft. They are not member findings and not a draft. Originals were still running when this note was written. MiniMax had a response file on disk; that file is not settled until the task completes.

## Hook asset bindings

Read from current package interfaces, not from a test run.

- Single buffer hook `PkgArgs` is `poolManager`, `standardExchange`, `pairToken`. The `pairToken` field name is not proof that only the PairToken family can be supplied. A later draft must cite the validation that consumes it before requiring a hook-package change.
- Constant-product single uses `standardExchange`, `pairToken`, and `rawToken`.
- Dual uses `standardExchange0/1` and `token0/1`, plus rate providers when the token is not the share.
- Weighted, Balancer quad, and Curve quad take `standardExchanges` and `rateProviders` arrays. Those fields are address arrays, not a PairToken type.
- Orbital `PkgArgs` names `token0/1/2` and decimals, not `standardExchange`. Do not assume it accepts an SE share without reading its init validation.

Integration testing can target the families whose arguments already take a Standard Exchange address. A hook redesign is a separate requirement only where cited validation rejects a full-spread share.

## Settled originals, not yet a draft

Grok and MiniMax have settled. Astra and Kimi have not. Do not freeze the draft from these two alone.

Material disagreement already visible:

- Grok FS-RATE-02: do not install `getRate` on the diamond. The executable one-share exit quote is `previewExchangeIn` of `1e18` shares. A hook that needs `IRateProvider` uses the external provider, and that provider's full-book formula is not this family's rate.
- MiniMax FS-FACET-03: add a family `RateFacet` exposing `IRateProvider.getRate()` as the executable normalized one-share sale rate, so a buffer hook can bind it. MiniMax treats that selector as absent from the shared and inherited family facets.
- Astra FS-21: install `IRateProvider.getRate()` on the existing `QueryFacet`, not a new facet. The value is `floor(E(1e18) * 1e18 / 10^rateAssetDecimals)`, where `E` is the same planner as `previewExchangeIn`. It fails closed below one whole share. It is not Wings NAV and not SY `exchangeRate`.
- Kimi's file has all nine headings but the task has not settled. Treat this as unsettled text: it also puts `getRate` on `queryFacet`, with the same one-share formula, and returns zero when supply is below `1e18` instead of Astra's revert.
- Current PairToken family files have no `getRate` match. `StandardExchangeRateProviderFacet._getRate` prices the entire book and, at zero supply, inverts a unit target deposit. That is not the one-share exit quote. Do not point fullSpread's exposed rate at that formula.

Both reject copying Wings' full-book liquidation `getRate`. The draft must not average these into a silent NAV. Owner decision 8 says a rate, where exposed, is the executable normalized one-share quote.

## Grok advisory, not yet a resolution

Grok settled SUPPORT WITH CORRECTIONS. The other three have not. Do not publish from this note.

Corrections to carry into resolution unless another advisory contradicts them with a better source:

- C1: the stage-one control rule must not void `FS-X01` or `FS-RATE-01`. `exchangeIn` does not inherit the already-unlocked reject. `getRate` does not inherit `S1-API-04`'s refusal to install `IRateProvider`.
- C2: `moneyFacet` still installs `exchangeIn`. Do not pass the PairToken query facet into this package.
- C3: identity `token == share` is rejected by current hooks unless `asset()` exists. Do not add `asset()`. Record the reject.
- C4: `getRate` is denominated in `rateAsset` only. The other face is `FS-HOOK-04`, not a second rate.
- C5: `FS-A26` is exact-input both directions, not exact-out.
- C6: hook rows must assert position owner, ticks, and salt.

## Astra advisory, not yet a resolution

Astra settled REQUEST CHANGES. MiniMax's feedback file exists but that task has not settled. Kimi has not settled. Do not publish.

High corrections to reconcile with Grok before the final:

- C1: locked `exchangeIn` keeps per-action unlock, not one unlock per public call. Borrowed path dispatches each action without `unlock`.
- C2: complete selected-entry consumption is a named delta, `FS-X04`, and must override the inherited partial-fill clause. The stage-one control rule must not void `FS-X01` or `FS-RATE-01`. Same point as Grok C1.
- C3: harness must follow the actual production-first manager pattern. Re-read before adopting the exact sentence.
- C4: facet inventory must name selectors, including `exchangeIn` on `moneyFacet`. Same point as Grok C2.
- C7: hook rows are family-specific. `single/` is not a two-vault package. A cited reject is not a pass. Agrees with Grok C3 that identity `token == share` is not a green row.
- C8: composed 12M gas and borrowed-path fee/delta invariants need their own acceptance rows.

## MiniMax advisory, not yet a resolution

MiniMax settled SUPPORT WITH CORRECTIONS and withdrew the thirteenth `RateFacet`. Kimi has not settled.

Claims to verify before adopting:

- Hook outflow calls `exchangeIn` with an end-user recipient, so `recipient == msg.sender` would reject the path the hooks use. Check the cited call sites before dropping that rule.
- PairToken callback's global nonzero-delta check cannot be copied into a borrowed unlock. Per-address closure stays.
- Shared `CurrencyReserves` sync slots can clobber an outer sync. Require atomic sync, transfer, settle, and no foreign `settleFor`.
- Orbital `PkgArgs` does contain `se0`, `se1`, and `se2` at the package interface. The hook view is `standardExchange(uint8)`. MiniMax's claim that `se0` does not exist is not adopted as written. The final must name the package fields and the view getter separately.

## Package shape

PairToken `PkgInit` remains the exemplar: five named shared facets, seven named family facets, infrastructure bindings, and six linked libraries. Its interface comment excludes factory-owned introspection and temporary-hook facets from package inputs. The temporary-hook facet file was not located in this pass. Do not invent its name in the PRD until a member or a later read cites the file.
