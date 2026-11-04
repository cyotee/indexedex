# Kimi advisory feedback

## Identity

- Run: `se-fullspread-implementation-plan-20261104`.
- Member: `kimi`.
- Phase: advisory review, feedback attempt 1 on the same conversation.
- Requested role: council-member.
- Requested model and reasoning: `kimi-coding/k3.1-pro:high`, global route.
- Runtime identity: not exposed.
- Peers or peer feedback read: no.

## Draft under review

- Draft ID: `draft-se-fullspread-implementation-plan-20261104-r1`.
- Exact path reviewed: `docs/research/se-fullspread-implementation-plan-20261104/coordinator/draft.md`.
- Coordinator-supplied SHA-256: `32745f5d7579e53ae2121206add5114f1a451c2f467bb024ba7eba3371d96407`.
- Independent fingerprint: not computed.
- The exact draft opened successfully and was reviewed in full.

## Disposition

requested-changes

The draft preserves the central locked economics, but it is not yet decision-complete or internally consistent enough to serve as the implementation and testing plan. The corrections below are limited to named draft sections and do not replace the draft.

## Concerns

| Correction | Draft section | Concern and required correction |
| --- | --- | --- |
| C1 | 6. Storage | `token.balanceOf(address(this)) - booked[token]` treats pending caller input, reserved refunds, and reserved exit allocations as available unbooked balance. That can let a pretransfer consume tokens reserved for another operation leg or payout, despite the section separately naming reservations. Define available unbooked balance as raw held balance minus booked balances **and all active operation reservations**, with checked accounting and native/WETH boundary handling. State that reservations return to zero before external return and are never pretransfer credit. |
| C2 | 7. Selector cut | `Query facet: no family selector` contradicts the following assignment of `reserveOfToken` and `reserves` to the family facet. Assign those two selectors explicitly to the Query facet and retain only `vaultTokens` on `MultiAssetBasicVaultFacet`. Also place the canonical `isOperator` and `isOperatorFor` queries in the cut so the operable surface is not left ambiguous. Replace the uncited hardcoded exact-out selector constants with compile-time `.selector` derivation from the current `IStandardExchangeOut` signatures, as already required for the other interface IDs. |
| C3 | 8. Check order | The brief requires check order for every public mutator, but this section gives a detailed sequence only for `exchangeIn`. Add complete sequences for `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `exchangeOut`, `donate`, `compound`, both appointment functions, and `unlockCallback`. In particular, fix the relative order of deadline, disable, recipient/route/length/duplicate/empty checks, pretransfer atomic shortfall validation, locked-versus-borrowed dispatch, `ManagerAlreadyUnlocked`, share authority, minima, manager actions, mint/burn finalization, refunds/payouts, events, reservation cleanup, and callback-hash consumption. Bundle exit must not acquire a borrowed path; parked shares must not become burn credit. |
| C4 | 12. Quotes and previews | The quote section covers scalar mint/exit previews but omits the accepted bundle previews and most deployed-reserve semantics. Specify `previewExchangeBundleInForSingleOut` net shares and positional refund array, `previewExchangeBundleOut` caller-ordered two-token outputs using the same pre-burn apportionment, zero refund, and output equality with execution from the same state. Add deterministic zero-valued results for unsupported views without coded vault reverts, `reserveOfToken` zero for an unknown token, live position amounts plus unpaid fees in `reserves`/`reserveOfToken`, exclusion of booked and unbooked local balances, and `positionLiquidity` through `StateLibrary.getPositionInfo` on PoolManager. |
| C5 | 16. Hook integration and preview migration | The migration names only `previewExchangeIn`; FS-OWN-08 also requires one-word `exchangeIn` decoders to migrate to the tuple. Add that decoder migration. Make the seven matrix rows implementable by naming each topology's binding and proof, and state the canonical dual fixture fully: disjoint backing PoolKeys, exact-input `zeroForOne` and `oneForZero`, no mint/redeem demand on the other SE inside the outer unlock, and balance/position/per-address-delta assertions. Keep same-backing-pool sequential composition unverified and retain the cited FS-HOOK-04 rejection record requirements. |
| C6 | 17. Test plan | Several mappings do not exercise the locked expected result. Move or expand row 036 beyond `AlreadyUnlocked` to ordinary Money and hook integration; add Money execution to 041 and 051; expand 044 to prove no existing-holder value moves to `feeTo` on a round trip, net-share previews/minimum, 30% clamp, and 0.001% precision; expand 048 to assert `Compounded()` on a qualifying deposit, `Donation()` on every successful donation, and that a booked remainder does not freeze a later route. Include borrowed one-token claim conversion in the FS-A08/024 coverage and direct plus borrowed disable cases in FS-A38/045 rather than relying only on buffer integration. Reconcile the composed-route gas text with section 3: standalone bodies are at most 11,900,000 with 100,000 overhead, while a composed route is judged on its whole transaction under 12,000,000. |
| C7 | 18. Traceability | `FS-OWN-13` is omitted even though it governs locked versus borrowed manager execution. Add it explicitly to sections 9 and 11. Keep the individual FS-A test-file mapping in section 17 linked from this section rather than relying only on the range citation. |

## What was not adopted from others

No rejected naming alternative needs restoration. In particular, I do not request restoration of Kimi's FS-OWN-33-inside-`SwapProjection` assignment or Kimi's maintenance-modifier identifier. The draft's placement of amount selection in `Math`, exact-input swap execution in `SwapProjection`, and `onlyLiveFeeToOwnerOrOperator` in the maintenance modifier are acceptable implementation names, not product changes. The requested corrections above concern requirement coverage and internal consistency, not a preference for another member's names. The coordinator's explicit one-token overstated-pretransfer reading is retained; this feedback does not reopen it.

## Limits

I reviewed only the exact draft path named above. I did not recompute its hash, read peer responses or peer feedback, reopen the PRD or other sources, launch sub-agents, run tests, or edit any file other than this feedback. This feedback does not authorize implementation and does not replace the draft.
