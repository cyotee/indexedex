# Identity

- Member: astra
- Phase: advisory review
- Requested role: council-member
- Requested model: chatgpt-subscription/gpt-6-astra:high
- Conversation: continued conversation
- Initial response: preserved
- Peers read before this feedback: no
- Actual runtime model, provider, account, reasoning setting, role, and ancestry: not exposed

# Draft under review

- Run: se-fullspread-prd-rewrite-20261103
- File: `docs/research/se-fullspread-prd-rewrite-20261103/coordinator/draft.md`
- Revision stated in the file: `fullspread-se-prd-rewrite-20261103`
- Coverage: the complete draft, sections 1 through 10, read in four consecutive ranges covering its 639 lines.
- Review question: does the merged replacement copy the locked decisions without adding economics or retaining contradicted sentences?
- Review basis: this draft and the locks already read in this continued conversation. No authority document, original response, or peer feedback was reopened. No hash was computed.

# Disposition

requested-changes

# Concerns

The main decisions are substantially represented: fee netting and its 30% clamp, raw-liquidity shares, removed sleeve, live `feeTo()` authority, the fee/booked exit entitlement, one-sided sizing, external rate providers, and the tuple migration. The six fail-closed sites and three ABI bindings are named with their reported locators, and other one-word preview readers are covered. Nevertheless, the draft is not yet a consistent replacement: several operational sentences still contradict those decisions, and the WETH source is incorrectly reopened.

The observations below are observations of the draft. Comparisons with owner intent use the previously read context, not a fresh source verification. Each correction is advice for the named draft section, not an edit or additional authorization.

## 1. Section 5, FS-MONEY-01; section 8, FS-A11; section 1, Goal: preserve the complete exit claim throughout

**Observation.** FS-OWN-30 and FS-A08 correctly require a one-token exit to swap the caller's opposing-token booked claim. But FS-MONEY-01 also says that a deposit, withdrawal, and `exchangeIn` "do not deploy or swap a booked remainder." Its withdrawal bullet says, "It does not pay pro-rata idle," and FS-A11 repeats that exclusion. The Goal says a booked remainder "is held until `donate()` or `compound()` deploys it."

**Why correction is needed.** A booked remainder is one of the booked balances apportioned by the later F2 override. The blanket no-swap sentence forbids the caller's required exit conversion. The other sentences can be read as keeping all locally booked assets until maintenance, rather than paying the exiting holder's portion. The correct lock elsewhere does not remove these conflicting instructions.

**Correction by section.** In FS-MONEY-01, preserve the prohibition on automatic maintenance and deployment of booked remainder, but expressly allow the exit's apportioned booked claim to be paid or converted under FS-OWN-30. Replace the categorical no-pro-rata-idle wording in FS-MONEY-01 and FS-A11 with the actual boundary: no sleeve or unrelated unbooked-balance entitlement; the caller does receive their fee and booked-balance claim. In the Goal, distinguish the staying holders' retained booked balance from the exiting holder's claim. Do not change liquidity-only issuance or introduce a new local reserve view.

## 2. Section 1.4, FS-OWN-17 and FS-OWN-22; section 9: do not reopen the already specified WETH source

**Observation.** FS-OWN-17 says the later lock names no replacement field or WETH constant and that the PRD does not add one. FS-OWN-22 explicitly calls the address source a "gap." Section 9 repeats that the replacement does not name it.

**Why correction is needed.** The earlier FS-OWN-17, read in the initial phase, already specified the network `WETH` constant, `WETH9` on Robinhood. The later removal of `PkgInit.wrappedNative` and the getter did not replace that constant rule. The draft itself says an earlier lock remains unless replaced. Treating the absent package argument as an unresolved source discards a retained requirement; restoring the constant is not inventing a replacement binding.

**Correction by section.** Restore the network-WETH source in FS-OWN-17 and use it for FS-OWN-22's native-currency substitution. Remove the corresponding gap statements from those sections and section 9. Keep the package argument and getter absent. Also scope "the vault does not accept or produce native ETH" to caller-facing routes; internal pool-boundary native settlement is expressly retained by FS-A35.

## 3. Section 1.4, FS-OWN-14; section 8, FS-TEST-04: reconcile the no-event sentence with `Donation()`

**Observation.** FS-OWN-14 says a call with no fees, donation, or booked remainder has no state change and no event. The surrounding rule covers both `compound()` and `donate()`. The next paragraph requires `Donation()` whenever `donate()` is called, with reverting calls excluded. The APEX-2026-048 row repeats the generic unchanged-call statement.

**Why correction is needed.** The later F7 rule requires a successful `donate()` to emit fieldless `Donation()`. The draft leaves a generic no-event instruction beside that lock. It does not establish that every donation invocation with nothing to deposit necessarily reverts, and such a new rejection must not be invented merely to reconcile the prose.

**Correction by section.** Scope the no-state-change/no-event compound rule to `compound()` with no fees or booked remainder. For both maintenance functions, retain the separate rule that no deposit means no `Compounded()`. State successful `donate()` emits `Donation()` independently of whether it deposits. Align the APEX-2026-048 wording with that distinction without adding a new zero-donation error or eligibility rule.

## 4. Section 1.4, FS-OWN-21: remove the donated-only swap restriction for combined maintenance input

**Observation.** FS-OWN-14 combines donation, collected fees, and booked remainder. FS-OWN-33 applies the one-token add rule to that maintenance operation. FS-OWN-21 nevertheless says, "The one-token swap spends the donated tokens only."

**Why correction is needed.** Consider a donation and an existing booked balance in the same token. The combined balance is still one-token input. FS-OWN-14/33 require processing that balance, while the donated-only sentence forbids using its booked portion in the swap. This also leaves an origin distinction beside the later rule that booked tokens count as fees and no fee-origin store is wanted.

**Correction by section.** In FS-OWN-21, describe the swap budget as the combined one-token maintenance balance authorized by FS-OWN-14. Preserve the restrictions against swapping the deployed position or using an opposing holder token to force a one-sided donation trade. When the combined balance contains both tokens, the no-swap proportional rule still applies. Do not introduce origin tracking.

## 5. Section 5, FS-MONEY-01; section 8, FS-A05: retain the strict genesis boundary

**Observation.** FS-MONEY-01 now rejects added liquidity "that cannot cover `MIN_SHARES`." It does not state the equality case. FS-A05 does not recover that condition.

**Why correction is needed.** The retained genesis rule in the initial context rejected `addedLiquidity <= MIN_SHARES`. "Cannot cover" can instead mean only `addedLiquidity < MIN_SHARES`, admitting exactly `1_000` liquidity, minting the whole supply to the floor, and giving the depositor no gross shares. No later lock changed this boundary.

**Correction by section.** State the original strict requirement directly: the first add must exceed `1_000`, and an add less than or equal to `1_000` is rejected. Carry the equality case into FS-A05. Do not invent a new error signature or alter the floor, fee base, or share unit.

## 6. Section 5, FS-MONEY-01: separate token settlement credit from minted share credit

**Observation.** The second bullet begins with a positive PoolManager settlement credit paid back to the depositor, correctly excludes `feesAccrued`, then says, "The credit is the depositor's net shares under FS-OWN-24."

**Why correction is needed.** A settlement token credit/refund and the recipient's minted share credit have different units and may have different recipients. The final sentence can identify the former as the latter, leaving an implementor to choose whether the paragraph describes a token refund or net share issuance.

**Correction by section.** Name the two amounts explicitly: caller-input token credit is returned to the payer under FS-OWN-32; share credit to `recipient` is the net shares under FS-OWN-24. Keep accrued holder fees separately booked. This is a clarification of the retained payer/recipient and refund rules, not a new economic operation.

## 7. Section 1.4, FS-OWN-30: make the rounding location explicit

**Observation.** The draft says the caller's share is `shares burned / totalSupply()` "rounded down" and that the caller owns that share of each fee/booked amount. It gives a multiply-before-divide expression for principal, but not for fees or booked balances.

**Why correction is needed.** The intended pre-burn proportional entitlement should not be implemented by integer-dividing the naked share fraction first; for a partial exit that would be zero before it is applied to fees or booked tokens. The current phrasing permits that reading despite the rest of FS-OWN-30 describing a real proportional claim.

**Correction by section.** Express the existing apportioning as `floor(feesAccrued_i * sharesBurned / supplyBeforeBurn)` and `floor(bookedBalance_i * sharesBurned / supplyBeforeBurn)`, with the remainder booked for staying holders. This states where the already required rounding occurs; it adds no fixed-point scale, new valuation, or altered denominator.

# What was not adopted from others

I did not read other members' originals or feedback. The draft's preamble attributes its base to Grok and says the other responses were compared; that does not expose which contributor proposed or rejected a particular sentence. I cannot independently attribute omissions to a member or describe an unseen disagreement.

Relative to my preserved initial contribution, the merge does not retain the explicit network-WETH source, the strict first-add boundary, the separation of refund token credit from share credit, or the explicit per-amount fee/booked rounding formulas. Those differences matter for the reasons above, not because my wording must be adopted.

The draft does accurately preserve the main fee, preview-return, external-provider, maintenance-authority, and no-sleeve conclusions. I do not require my facet field names, library filename enumeration, acceptance-row placement, or phrasing to be copied. This feedback does not reopen the owner's accepted unbounded swap limits, maintenance sandwich exposure, or liquidity-only issuance.

# Limits

- Only the named coordinator draft was opened during this advisory pass. Source comparisons rely on the earlier authorized reading in this conversation; source files were not re-read or newly verified.
- Only `docs/research/se-fullspread-prd-rewrite-20261103/members/astra/feedback.md` was written. The initial response and every other artifact remain unedited by this pass.
- No peer feedback, sub-agent, Forge, test, installation, deployment, wallet operation, Git command, or external search was used.
- This is a document-consistency and lock-fidelity advisory, not runtime verification or a security clearance.
- This feedback does not authorize implementation and does not replace the draft. The coordinator owns any revisions. No further review round is requested.
