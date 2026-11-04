Ask: Perform one advisory on frozen revision v4-adaptation-r1 - wanted: a disposition, material corrections, original-proposal dispositions, and limits. For you: **SUPPORT**, with no material corrections. `apply_patch` remains inactive, so `/members/kimi/feedback.md` was not written; the complete advisory follows inline without using another write mechanism. Now: none - all tasks closed. Next: none.

# Kimi advisory on frozen revision v4-adaptation-r1

## Disposition: SUPPORT

I found no material correction. The draft concretely answers the chosen goal, fairly preserves the external ranking split, and accurately distinguishes **Weir as strategy reference**, **lpTOKEN as accounting/conversion reference**, and **the existing local full-range SE vault as the lowest-burden implementation vehicle**. It does not pretend that one upstream contract should be copied or that adding ERC20 is sufficient.

## Material checks

- **Same-manager settlement:** The draft correctly rejects nested unlock and requires a narrow, authorized already-unlocked entry rather than an unguarded bypass. It preserves direct vault ownership, caller-and-currency delta accounting, separate outer-router obligations, and final global settlement. It also correctly treats a different PoolManager as a topology condition, not a general fix.
- **PositionManager:** `modifyLiquiditiesWithoutUnlock` is correctly acknowledged as protocol-legal in principle. NFT execution is not categorically excluded; it is rejected only as the higher-burden choice for this simple direct-custody model.
- **Transient observability:** The draft properly distinguishes manager-unlocked from vault-busy and explicitly allows another contract to observe manager transient state through an accessor in the same transaction. It does not repeat MiniMax's claim that an external rate provider is automatically blind to that state.
- **Idle and fee attribution:** Liquidity-only issuance is not treated as adequate for an idle-bearing basket. The draft preserves attributable caller contribution, incumbent fee checkpoints, post-entry-swap snapshots, categorized input/idle/exit inventories, and the local disclosed zap-remainder policy.
- **Exact one-token output:** Full unwanted-allocation consumption and one-token payout or atomic revert are structural requirements. Weir's residual payout is not mislabeled as a strict exit, and no queue or silent paired fallback was introduced.
- **Rate semantics:** The requested normalized executable one-share quote remains identifiable and is not renamed into NAV. The formula distinguishes one whole share from raw share units and normalizes target decimals. Nonlinear redemption is correctly treated as a constraint on how settlement must use the quote, not as a categorical prohibition on rate-aware pools.
- **Alternative accounting adapter:** A separate accounting/reference adapter remains an explicit new product choice to evaluate, not accepted authority or a silent replacement for executable `getRate`, current SY accounting, or the user's Rate Provider goal.
- **No-independent-market premise:** Same-pool conversion is not confused with fair pricing. A same-pool historical/TWAP reference is described as endogenous, lagged, availability-limited, and not automatically present.
- **Local constraints:** Existing ERC20/Diamond packaging, native support, no-dead-share/no-fee policy, strict atomicity, bounded previews, and unsupported exact-output behavior remain intact.

## Disposition of my original's key proposals

- **Adopted:** lpTOKEN as the strongest external accounting and exact-conversion reference; Weir as the full-range strategy runner-up; the existing local stage-one implementation as the actual adaptation base.
- **Adopted:** a narrowly authorized already-unlocked engine using direct manager calls and caller-specific settlement, with normal locked callback authentication retained.
- **Adopted:** full-spend-or-revert conversion with no residual second-token payout or residual custody.
- **Adopted:** local attributable issuance and idle/fee accounting rather than Weir's liquidity-only issuance or lpTOKEN's launch/share-fee policies.
- **Adopted with appropriate qualification:** my warning against treating a one-share executable quote as a generic invariant multiplier. The draft preserves the warning without turning nonlinearity into a blanket ban on rate-aware pools.
- **Adopted as an explicit alternative only:** my preference for a separate accounting NAV/reference adapter. It is not presented as already approved or as a substitute for the requested executable quote.
- **Adopted:** PositionManager without-unlock nuance, transient-read consistency, bounded amount-specific previews, and the no-independent-market limitations.

## What I did not adopt from peers

- **MiniMax's queues/rate limits and cadence-bound redemption proposal:** the draft correctly leaves these out because they would change the user's synchronous hook-swap requirement.
- **MiniMax's transient-visibility and NFT-impossibility overstatements:** the draft corrects both rather than inheriting them.
- **Grok's withholding of the Rate Provider goal:** the draft preserves the requested goal and evaluates pricing policy instead of discarding it.
- **Any global-sync restoration prescription or assumption that another actor's settlement checkpoint remains valid:** the draft properly avoids making transient checkpoint manipulation an integration requirement.
- **Any production-safety inference:** verification records, read-only rates, and proposed settlement sketches are not treated as deployed economic validation.

## Limits

I read the complete frozen draft and all three other adaptation originals, not peer feedback. No new primary-source check was necessary beyond the admitted originals and the sources already inspected in this run. I executed no transactions, queried no live chain state, and performed no audit or implementation review.

This advisory neither replaces my original nor authorizes implementation, and no further round is requested.
