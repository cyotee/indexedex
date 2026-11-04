# Grok advisory — fullspread-se-prd-draft-r1

## Identity

Grok, council member, one advisory pass. Assigned route label `xai/grok-4.7:xhigh`. That label is not a runtime attestation. This file is not a second original, not an implementation, and not an approval to code.

## Draft under review

- Path: `docs/research/fullspread-se-prd-20261030-01a18660/coordinator/draft.md`
- Revision: `fullspread-se-prd-draft-r1`
- Supplied SHA-256: `6c9d4a741bf96f5e5d1fe238459962e51568d2836e3838077c5afa1e8ff8a946`
- That hash is supplied provenance. It was not recomputed.

## Disposition

SUPPORT WITH CORRECTIONS.

The product choices in section 2.2 are sound: one-share `getRate` on the existing query facet, no thirteenth facet, unlocked execution only for the `exchangeIn` routes the current hooks call, no hook allowlist, and inherited booked zap credit. The draft is not executable until the corrections below land. They do not reopen those choices.

## Material corrections

### C1 — Section 2 control rule voids FS-X01 and FS-RATE-01

Section 2 says that if this draft and the stage-one PRD disagree on an inherited ID, the stage-one PRD controls, and that this draft controls only `FS-` IDs. Section 2.1 then inherits `S1-SEC-01`, `S1-OP-05`, `S1-API-01` through `S1-API-05`, and, through `FS-TEST-02`, `S1-A01` through `S1-A70`.

Those inherited texts contradict the draft's own deltas:

- `S1-SEC-01` and `S1-OP-05` require a call while the manager is already unlocked to fail before any nested `unlock`. `S1-A40` requires that reject. `FS-X01`, `FS-UNLOCK-01`, and `FS-A19` require `exchangeIn` to succeed on that path.
- `S1-API-04` says stage one does not install `IRateProvider`. `FS-X02` and `FS-RATE-01` install `getRate`.

An implementer who follows the control rule will revert the hook path and omit `getRate`. That deletes the reason this sibling exists.

Required text, in section 2.1 and again in `FS-TEST-02`:

- For `exchangeIn` only, do not inherit the already-unlocked reject in `S1-SEC-01`, the same sentence in `S1-OP-05`, or `S1-A40`. `FS-UNLOCK-01` and `FS-UNLOCK-02` control that path. `FS-A19` replaces `S1-A40` for `exchangeIn`.
- `depositPair`, `redeemPair`, `donate`, `compound`, and the SY mutators still revert `ManagerAlreadyUnlocked` while the manager is unlocked, as `FS-UNLOCK-01` and `FS-A22` say. The "no local-sleeve" sentence stays inherited.
- Do not inherit `S1-API-04`'s refusal to install `IRateProvider`. `FS-RATE-01` controls that one selector. The rest of `S1-API-04` stays: no `IERC4626`, no transition-quote facet, no external-state quote, no silent `IStandardExchangeRateQuote`.

Also change "the two deltas in section 1.2" to "the three deltas in section 1.2." The count is wrong and the exception clause is what a reader will use.

### C2 — `FS-FACET-01` does not name the selector the unlocked path uses

The family table describes `moneyFacet` as paired deposit, paired redeem, donate, and compound. The current PairToken package installs `IStandardExchangeIn.exchangeIn` on that facet, index 5, ahead of those four. `FS-UNLOCK-01` depends on that selector. The table must say `moneyFacet` still installs `exchangeIn`. It is not a new selector and it is not moved.

`queryFacet` is not the PairToken query facet with a comment added. Its expected selector set is that facet's current set plus `getRate`. Package validation must reject a query facet that lacks `getRate`, and must reject a cut that installs `getRate` twice. Do not pass the PairToken query-facet address into this `PkgInit`.

### C3 — `FS-HOOK-02` and `FS-A24` require a bind the current hooks reject

Identity is defined as the pool token being this share and that share also being the `standardExchange` argument. On the current dual package, `_requireTokenInVaultTokens` accepts `token == se` only when `UniswapV4SeBufferHookLegLib.isWrapperShareInventory` is true. That helper returns true only if `staticcall` of selector `0x38d52e0f` (`IERC4626.asset`) returns a different nonzero address. This family must not implement that selector (`S1-API-04`, section 1.1). The single pricing package reverts `SameToken` when `pairToken == standardExchange`.

`FS-A27` allows a cited reject under `FS-HOOK-04`. `FS-A24` does not. Written as a passing assertion, `FS-A24` pushes an implementer to add `asset()` or to edit the hook. Both are forbidden.

Required change: `FS-HOOK-02`'s identity bullet and `FS-A24` use the same gate as `FS-A27`. Either name a current package function that accepts `token == this vault` without `asset()`, or record the cited reject and do not count identity as passed. Do not add `asset()` to make the row green. The buffered configuration in `FS-HOOK-02`, where the pool token is in `vaultTokens()` and is not the share, remains the path `FS-UNLOCK-02` exists for.

### C4 — `FS-RATE-01` is denominated in `rateAsset`, not in every hook leg

`getRate` quotes one whole share into `rateAsset` only. A buffer hook's rate provider must quote the leg's pair token (`IRateProvider.getRate`, WAD whole pair tokens per whole share). The two currency faces are both legal `vaultTokens()`. Only one of them is `rateAsset`.

The sentence that a non-identity leg binds this vault, or a provider whose `getRate` is this vault's `getRate`, is true only when that leg's token is `rateAsset`. For the other face it is the wrong denomination. `FS-HOOK-04` already calls an incompatible denomination a separate requirement. Apply it.

Required change:

- `FS-A25` and `FS-A29` stay valid for a leg whose token equals `rateAsset`.
- A leg whose token is the other face is not a passed `FS-A29`. Record it under `FS-HOOK-04`. Do not add a second `getRate`, and do not retarget `rateAsset` per caller.
- Say that a hook fixture which reads `getRate` must have share supply of at least `1e18`. `InsufficientRateSupply` below that is specified behavior, not a hook defect and not a reason to extrapolate.

Make the safe exponent form the normative formula. `floor(E * 1e18 / 10^d)` is the definition. The implementation form is multiply by `10^(18-d)` when `d <= 18`, and divide by `10^(d-18)` when `d > 18`. An intermediate `10^d` that cannot be represented reverts `RateNormalizationOverflow` rather than wrapping.

### C5 — `FS-A26` can be read as requiring exact-out success

"Both directions that the hook supports" includes hook exact-out paths. Those paths call `exchangeOut`. `FS-HOOK-03` and `FS-A28` require that call to fail closed. An implementer can treat `FS-A26` as the row that must go green and weaken `FS-A28`.

Required change: `FS-A26` is both exact-input swap directions, `zeroForOne` and `oneForZero`, on two vaults with different backing pool keys. Exact-out remains `FS-A28` and is not a direction `FS-A26` must complete.

### C6 — Hook acceptance does not check position ownership

`FS-UNLOCK-02` step 5 says the position owner remains this diamond and the only position written is the full-range salt-zero position. `FS-A19`, `FS-A25`, and `FS-A26` do not assert that. A swap can return, close deltas, and still have moved or replaced the position.

Add to `FS-A25` and `FS-A26`: after the swap, the manager reports the position owner as this diamond, at `tickLower` / `tickUpper` from `TickMath.minUsableTick` / `maxUsableTick` and salt `bytes32(0)`. Liquidity may change. The owner and the key may not. The same rows should assert incumbent fee ownership still follows `S1-ACC-06` on the borrowed path, because that path is the one the hooks exercise and `S1-A24` can otherwise be satisfied only on the locked path.

## Dispositions of proposals the draft did not adopt

These use the draft's section 2.2 and section 9 summaries. Peer originals were not read for this pass.

| Proposal the draft did not adopt | Disposition |
| --- | --- |
| Grok: omit `getRate`. | Do not restore it. Owner decision 8 allows an exposed rate when it is the executable normalized one-share exit. `FS-RATE-01` is that quote, not NAV, not `exchangeRate`, and not `StandardExchangeRateProviderFacet._getRate`. Keeping it off the diamond would leave non-identity hook legs without a one-share provider this family can honestly bind. C2 and C4 are the conditions. The omission is not a blocking objection. |
| Grok: run compound, donate, and paired methods on the borrowed unlock. | Do not restore it. Current hooks call `exchangeIn` during `beforeSwap`, with `recipient == msg.sender` and `pretransferred == false`. Widening the borrowed path is not required for that integration. Public `compound`, `donate`, paired methods, and SY mutators reverting `ManagerAlreadyUnlocked` is the safer rule, provided C1 keeps `exchangeIn` itself on `FS-UNLOCK-02`. Mandatory compound inside `exchangeIn` still has to run, because `FS-UNLOCK-02` step 4 uses the same planner and settlement code. That is internal to the call. It is not a public `compound()` while unlocked. |
| MiniMax: a thirteenth `RateFacet`. | Agree with the rejection. One new selector belongs on `queryFacet`. A thirteenth facet would change `bindingHash` order and add a second rate surface. C2 is the selector-set consequence, not a reason to split the facet. |
| Kimi: return zero when supply is below one whole share. | Agree with the rejection. A zero return is readable as a price. `InsufficientRateSupply` is the executable reading: there is no one-share exit to normalize. Do not extrapolate a smaller redemption either. Hook fail-closed on revert is the existing D60 behavior. A zero from this vault would be worse, not safer. |
| A `PkgArgs` hook allowlist. | Agree with the rejection. The hook address is not known when the vault is deployed, and the unlocked flag must not become an authorization list. `InvalidUnlockedContext` (code, self recipient, `pretransferred == false`, `msg.value == 0`) matches the observed hook call and does not need an address list. |
| A new rule that every input wei becomes liquidity. | Agree with the rejection. That rule would replace `S1-ACC-07`. Full consumption of the selected swap input, no second-token payout, and no burn-and-donate on exit are the right reading of owner decision 6. Booked zap `J_i` stays the inherited no-extra-shares donation. |

No unadopted proposal should be edited back in as a silent alternative. C1 through C6 are constraints on the draft's own choices, not a return to those alternatives.

## Limits

- One advisory pass. This file does not replace the draft and does not authorize implementation, a hook edit, or a PairToken PRD amendment.
- The supplied SHA-256 was not recomputed. If the file on disk is not that revision, this review does not apply.
- Peer response files were not opened. Dispositions of MiniMax and Kimi use only the sentences in this draft. If those summaries are incomplete, the disposition is incomplete in the same way.
- PairToken `TestBase` and the port's `currencyDelta` accessor were not re-read in this pass. `FS-TEST-01`'s `new PoolManager(address(this))` was not checked against the current harness. If that constructor is not the harness path, follow the harness; that is not a product objection.
- The factory filename caution in `FS-FACET-02` is acceptable. This pass does not require the draft to name `PostDeployAccountHookFacet` or the ERC-8109 facet. Implementation still has to cite the factory file before hard-coding those names.
- No project code, draft, original, peer file, or resolution was edited.
