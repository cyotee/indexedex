# Identity

Kimi, independent council member. Assigned route label: `kimi-coding/k3.1-pro:high`; this is not a runtime attestation. Advisory pass only.

# Draft under review

- File: `docs/research/fullspread-se-prd-20261030-01a18660/coordinator/draft.md`
- Revision: `fullspread-se-prd-draft-r1`
- Supplied SHA-256: `6c9d4a741bf96f5e5d1fe238459962e51568d2836e3838077c5afa1e8ff8a946`

I read the complete frozen draft. The hash is recorded as supplied provenance and was not recomputed.

# Disposition

**REQUEST CHANGES.**

The one-diamond/one-pool/one-position architecture, explicit twelve-field package, borrowed-unlock `exchangeIn`, executable one-share `getRate`, and production-first hook-test strategy are sound. Publication should nevertheless wait for the corrections below. In particular, the draft currently turns PairToken’s per-action callback protocol into a one-unlock-per-operation requirement, leaves inherited acceptance rows in direct conflict with the new unlocked behavior, and does not pin a cross-vault fixture that can work without changing the other SE family.

# Material corrections with requirement IDs

## FS-ADV-01 — Restore per-action unlock/callback multiplicity

**Affected:** FS-UNLOCK-01, FS-A17, inherited S1-SEC-01 and S1-A39.

The locked-path text says to “call `unlock` once” and FS-A17 requires one unlock and one accepted callback for a locked `exchangeIn`. That is not the inherited PairToken execution contract. A complete operation can contain maintenance collection, maintenance swap/addition/checkpoint, entry swap/addition, or exit removal/sale. PairToken commits and executes a separate real-manager action for each planned action.

Replace the requirement with:

- Ordinary entry performs **one vault-started unlock per planned manager action**. Before each unlock it stores `keccak256(abi.encode(operation, payload))`; the matching callback is accepted only from the bound manager, only during that active operation, and only once for that payload.
- Multiple sequential unlock/callback rounds within one family operation are valid. Nested unlock and replay of any consumed callback remain forbidden.
- The borrowed-unlock path performs no unlock and consumes no callback hash.

FS-A17 must use a multi-action deposit and a multi-action withdrawal, assert the exact planned unlock/callback count, and reject a replay after each accepted callback. A one-action smoke test is insufficient.

## FS-ADV-02 — Complete the inherited register and remove acceptance conflicts

**Affected:** section 2.1, FS-TEST-02, FS-UNLOCK-01/02, FS-FACET-01.

The inherited register omits S1-X01 through S1-X19, although those are named economic/integration deviations that FullSpread must preserve unless explicitly changed. Add them.

The blanket statement that S1-A01 through S1-A70 apply also conflicts with the draft itself. Make these mappings explicit:

- S1-A40 is **superseded** for canonical exact-input `exchangeIn` by FS-A19 through FS-A23. It remains applicable to the non-borrowed methods listed in FS-A22.
- S1-A06, S1-A56, and S1-A68 use the FullSpread selector manifest: `getRate` is required, not an excluded integration selector. The package-owned total is 61 selectors, with 12 on `queryFacet`.
- S1-A70 retains the inherited vault gas/preview ceilings; hook-composed transactions are additionally measured, not silently exempted.
- Section 2.1’s “two deltas” wording should match the three FS-X01 through FS-X03 deltas actually listed.

Without this mapping, an implementer can satisfy the new unlocked tests and still be told by the inherited suite to reject the same call.

## FS-ADV-03 — Pin the canonical cross-vault fixture to an identity-leg other SE

**Affected:** FS-HOOK-02, FS-A26, FS-A27, FS-TEST-01/02.

The draft requires two vaults with different backing pool keys but does not assign their leg roles. A fixture that buffers both SEs can require the other SE to execute its own unlocked conversion. Current PairToken rejects that context, so such a fixture would manufacture an integration failure unrelated to FullSpread.

Specify the canonical proof as:

1. FullSpread is the **buffered leg**: `standardExchange = fullSpread`, pool token = its `rateAsset`, and its one-share provider is bound where required.
2. The other SE is an **identity leg**: its share is the pool token and, where the package has a separate SE argument, that argument is the other SE itself. Its shares are traded opaquely; it is not asked to mint or redeem inside the outer unlock.
3. The two vaults have different backing pool keys. In one direction the hook mints FullSpread shares while already unlocked; in the reverse it burns them. Assert both directions, exact balances/rated reserves, position ownership, and per-address deltas.
4. Add a separate identity/identity share-trade case, but do not count it as proof of underlying FullSpread entry or exit.
5. A both-buffered composition is optional additional evidence only for another SE that independently supports the same unlocked context.

FS-A27’s cited-rejection branch must not be used to avoid this viable canonical configuration. A rejection remains an open FS-HOOK-04 record, not a passing cross-vault integration row.

## FS-ADV-04 — Use the actual optional quote interface names

**Affected:** section 2.1, FS-HOOK-04.

The draft excludes `IStandardExchangeExternalQuote` and `IStandardExchangeRateQuote`, but the admitted current hook context-quote library imports and probes:

- `IStandardExchangeTransitionQuote`
- `IStandardExchangeUnlockContextQuote`
- `IStandardExchangeExactOutputQuantityQuote`

Replace the two unsupported names with these three source-backed interfaces. Keep all three absent unless a cited consumer requires a separate change. The ordinary exact-input hook path must demonstrate the existing ERC-165-gated fallback to standard previews; no transition stub or live-value projection is authorized.

## FS-ADV-05 — Restore ERC-8109 to the factory-owned surface

**Affected:** FS-FACET-02, FS-A01.

The exclusion list names ERC-165, diamond loupe, and the temporary hook but omits ERC-8109 introspection, which the inherited PairToken package law explicitly assigns to the factory. Add ERC-8109 to the exclusions from `PkgInit`, `facetCuts`, and package interface aggregation. The acceptance matrix must assert both sides: it is absent from package-owned inputs/cuts and remains callable on the final factory-built proxy.

## FS-ADV-06 — Complete the selector and new-error ABI contract

**Affected:** FS-FACET-01, FS-RATE-01, FS-UNLOCK-02, FS-A01, FS-A14, FS-A20.

The facet table gives roles but not the complete interface/selector manifest needed to implement and verify `facetFuncs`. Add the current shared facet names and interfaces, the inherited family selector groups, and the explicit totals: 20 shared selectors, 41 family selectors, 61 distinct package-owned selectors, and 12 query selectors including `getRate`. The package acceptance row must smoke every one of those selectors on the deployed proxy while keeping factory selectors disjoint.

Declare the new failure ABI on the family interface rather than leaving error names only in prose:

- `InvalidUnlockedContext()` for FS-UNLOCK-02/FS-A20.
- `InsufficientRateSupply(uint256 available, uint256 required)` for FS-RATE-01/FS-A14, with exact arguments asserted.
- `RateNormalizationOverflow()` for an unrepresentable normalized result.
- `RateUnavailable()` for a mathematically zero normalized rate.

Selectors and interface IDs still follow the repository’s canonical later computation; no hexadecimal values are needed in the PRD.

## FS-ADV-07 — Preserve the complete `processArgs` context check

**Affected:** FS-PKG-01, FS-PKG-02, FS-A03.

The validation bullets say only that `processArgs` rejects entry not through the bound registry. Preserve the current PairToken conjunction explicitly: `msg.sender` must be the bound registry **and** `address(this)` must be the bound `diamondFactory`; otherwise revert `NotCalledByRegistry`. Tests must cover the correct registry in the wrong execution account and the wrong caller in the factory context, not only an arbitrary external caller.

# Dispositions of proposals the draft did not adopt

| Proposal recorded in the draft | Advisory disposition |
| --- | --- |
| Omit `getRate` entirely (attributed to Grok) | **Keep the draft’s rejection.** A buffered leg needs a provider under current hook law, and the brief preserves an executable normalized one-share rate where a rate is exposed. The correct provider is the amount-specific one-share exit, not SY accounting or full-book NAV. |
| Add a thirteenth `RateFacet` (attributed to MiniMax) | **Keep the draft’s rejection.** `queryFacet` already owns family read-only queries and can carry one selector without another rate authority. The twelve-field package shape and binding order should remain stable. |
| Return zero below one whole share (my original proposal) | **Accept the draft’s alternative.** Reverting `InsufficientRateSupply(available, required)` is clearer and avoids any downstream interpretation of zero as a price. Existing hooks also fail closed on revert. I withdraw the zero-return proposal. |
| Extend borrowed-unlock execution to compound, donate, paired methods, and SY mutators (attributed to Grok; my original also included SY) | **Keep the draft’s narrow scope.** The admitted current hooks call canonical `IStandardExchangeIn.exchangeIn`; that is the required integration surface. Ordinary paired/SY/compound/donation paths retain their authenticated unlock behavior and `ManagerAlreadyUnlocked()` guard. Widening can be a later consumer-backed requirement. |
| Add a `PkgArgs` hook allowlist | **Keep the draft’s rejection.** It is deployment-circular and unnecessary for the current hook calls. Code caller, self-funded input, caller recipient, `pretransferred == false`, zero value, ordinary route authority, and zero own-delta closure provide a narrower executable contract without pretending `isUnlocked` identifies a locker. |
| Require every input wei to become liquidity | **Keep the draft’s rejection.** Preserve S1-ACC-07’s `J_i` accounting and disclosed zap remainder. The atomic guarantee is complete consumption of the selected swap input and no second-token payout/stranded unpaid exit, not a new all-liquidity issuance rule. |
| Carry a nonzero per-address delta baseline (my original proposal) | **Accept the draft’s stricter zero-baseline rule.** Requiring this diamond’s backing-currency deltas to be zero on entry and return is sufficient for repeated borrowed-unlock calls and easier to audit. The essential correction already present in the draft is that the outer hook/router’s deltas and global nonzero-delta count are not required to be zero inside FullSpread. |
| Permit cited hook rejection as alternative cross-vault evidence | **Support only with FS-ADV-03.** A cited rejection is an honest unresolved integration record, not a successful cross-vault swap. The canonical buffered-FullSpread/identity-other-SE fixture must be attempted first and cannot be skipped merely because a both-buffered fixture fails. |

# Limits

This is one advisory pass on the supplied frozen draft. It does not replace the draft, amend my original, authorize implementation, or approve deployment. I did not recompute the supplied hash, read peer feedback or the resolution, edit project code, run Forge, or delegate. The advisory neither replaces the original nor authorizes implementation; no further advisory round is requested here.
