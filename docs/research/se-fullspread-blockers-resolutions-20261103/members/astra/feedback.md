# Astra advisory feedback

## Identity

- Member: astra.
- Profile: research.
- Phase: advisory feedback, continuing the initial Astra conversation.
- Requested role: council-member.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Actual runtime role, model, provider/account route, and reasoning setting: not exposed.
- Peer feedback read: no.

## Draft under review

- Draft ID: `draft-se-fullspread-blockers-resolutions-20261103-r1`.
- Exact path read: `docs/research/se-fullspread-blockers-resolutions-20261103/coordinator/draft.md`.
- Fingerprint: not computed; no hash was computed.
- The complete named draft was readable.
- Review basis: that draft and the initial Astra contribution already present in this conversation; no other file was opened for this advisory.

## Disposition

requested-changes

The draft preserves the principal owner constraints and covers all fifteen findings, but several recommended procedures still admit different implementations. F5 changes my optimization objective while recording agreement at the broader level of a ratio-sized swap. F7 rejects my attribution mechanism without replacing the distinction between fees present and fees actually deployed. F1 and F10 omit rules needed to handle bundles and share donations. These need correction before describing the proposed sentences as resolving their respective gaps.

This feedback does not authorize implementation, does not authorize a PRD edit, does not replace the draft, and does not treat any draft recommendation as an owner lock.

## Proposal accuracy

| Draft section | Does it state my proposal accurately? |
| --- | --- |
| F1 | The refund-only choice is accurate; per-leg refunds, donation handling, validation order, and zero-output minimum behavior are incomplete. |
| F2 | The disposition is accurate; the gross user debit versus net settlement distinction should be explicit. |
| F3 | The actual-balance assignment and zero-liquidity result are accurate; narrow the skipped modification to the liquidity-add call. |
| F4 | The broad ratio is accurate; the stored bounds, integer sizing, and observation point are omitted. |
| F5 | Only the rejection of a half-input rule is accurately shared; greatest swap input is not my greatest-added-liquidity objective. |
| F6 | Accurate in substance; expressly retain both unlock paths and atomic rollback. |
| F7 | It accurately says my fee-origin counters were not adopted, but its replacement predicate is not my proposal and does not preserve the actual-deployment distinction. |
| F8 | Accurate in substance; clarify that package immutable bindings remain alongside canonical instance storage. |
| F9 | Accurate for FS-A01, but omits the accompanying FS-FACET-01 correction from my proposal. |
| F10 | Accurate about adding the flag, but omits share-donation treatment, no return values, and exclusion of the old overload. |
| F11 | Accurate about the route set, but omits preservation of the existing borrowed-unlock funding and settlement conditions. |
| F12 | Accurate about the stored owner, including zero; operator eligibility remains conditional on existing authorization, not runtime evidence supplied by me. |
| F13 | Accurate in substance. |
| F14 | Accurate about the listed replacements, but omits the issuance-denominator and preview-description replacements I named. |
| F15 | Accurate about timing, but omits the source-located decoding inventory and per-consumer disposition that make completeness checkable. |

## Concerns and corrections

### Draft F1: specify every leg of the refund-only branch

**Observation.** The sentence triggers when any maximum exceeds its snapshot, then says to refund "that snapshot" while processing no leg.

**Inference.** A two-input call remains ambiguous. For maxima `(100,20)` and snapshots `(60,50)`, the intended refund-only result is `(60,20)`, with the second token's undeclared 30 left staged. Refunding both snapshots takes undeclared custody; refunding only the offending leg strands the other declared leg without specifying its disposition.

**Correction.** State that an overstatement on any leg makes the entire call refund-only, with each pretransferred leg refunding `min(maximum,snapshot)` to the caller/payer, no pulls on other legs, zero consumption, and zero output. Explicitly skip donation-triggered compounding on this branch. Preserve ordinary validity and authority checks, including deadline precedence, before the snapshot rather than making the no-bytecode check the sole named prerequisite. State that a failing output minimum reverts the entire branch, including refunds. These were load-bearing parts of my F1 proposal.

### Draft F2: distinguish user debits from net settlement

**Observation.** Fees are excluded from the caller's consumed input, refund, and share credit.

**Inference.** The disposition agrees with mine, but "excluded from consumed input" can still be implemented using the liquidity modification's net currency debit after the fee credit, thereby understating what the user consumed.

**Correction.** Name the gross token debits attributable to the user's added liquidity as the consumption basis, independent of collected fee credits and net manager settlement. Keep collection and booking separate from reinvestment. This is clarification of the shared disposition, not a request to change it.

### Draft F3: skip only the zero-size add

**Observation.** The zero-liquidity branch says "do not call `modifyLiquidity`."

**Inference.** Read literally, that can forbid a fee-collection modification needed earlier in maintenance, not merely the add that would have zero liquidity.

**Correction.** Say "skip the liquidity-add call" when the computed add is zero. Preserve prior collection, the final actual-held-balance assignment, and the rule that an attempted failure reverts. Also make integer rounding the reason that complete exhaustion is a sizing target rather than a guaranteed raw-token result.

### Draft F4: fix the sizing inputs and observation point

**Observation.** The ratio uses a full-range liquidity unit at the current pool price.

**Inference.** That is the right principal-only basis, but computing rounded token amounts for a single raw liquidity unit can yield zeros, and "current" does not distinguish pre-swap from post-swap sizing.

**Correction.** Name the stored full-range ticks, use the existing integer liquidity-sizing calculation rather than rounded amounts for one raw unit, and specify the current price immediately before the proportional add, which is the resulting price after the selected one-token swap. A side with zero principal requirement imposes no liquidity limit. These details were present in my F4/F5 proposal and prevent a ratio definition from becoming a separate rounding policy.

### Draft F5: restore a deterministic objective and exact rounding condition

**Observation.** The recommendation maximizes swap input subject to output-side consumption, while my proposal maximized integer added liquidity and broke ties by least total provided-token consumption and then least swap output.

**Inference.** Those objectives are not interchangeable merely because both are called ratio-sized. Integer plateaus can admit different swaps for the same liquidity; "rounded so" does not identify the selected swap or establish exact output-side consumption.

**Correction.** Use the greatest feasible integer added liquidity as the objective, with the stated consumption/output tie-breaks; require the swap's opposite-token output to equal that add's rounded-up opposite-token debit at the resulting price, and require actual swap input plus the rounded-up provided-token add debit to fit the processed input. Retain one planned swap and one add, with the swap executed for that exact internal output and the zero-liquidity/zero-swap base case. This does not enable a public exact-output route or select a quoter implementation.

If the coordinator retains a different objective, identify it as the coordinator's recommendation rather than an accurate synthesis of Astra's sizing procedure. The draft may reject my procedure, but should not claim the current abbreviated rule resolves its integer choices without specifying them. The practical planner and gas feasibility were explicitly unverified in my response and should remain an evidence limit.

### Draft F7 and Preserved disagreements: presence is not deployment

**Observation.** F7 requires positive added liquidity and a processed balance that "included" a fee; the disagreements table and coverage instead say fees are deployed.

**Inference.** Those predicates differ. A proportional add can use donated inventory while a small fee-origin amount remains in the excess token. Positive liquidity plus fee presence does not establish that any fee unit funded the add. Previously booked fees also cannot be identified solely from an undifferentiated current balance.

**Correction.** Resolve the predicate using actual fee-origin units consumed by the add, including previously booked fees, with deterministic attribution for mixed balances and swaps. My proposed mechanism was fee-origin subset counters, fee-first consumption, and pro-rata swap-output attribution rounded down. The coordinator need not adopt that particular mechanism, but rejecting it as a new store does not resolve the underlying information requirement. Without another specified attribution rule, label F7 unresolved rather than treating fee presence as equivalent to fees compounded.

Preserve the rationale correction: the empty event is the locked ABI, not proof that `ModifyLiquidity` logs token amounts. My original mechanism remains a recommendation, not an existing lock or verified storage design.

### Draft F8: distinguish instance copies from package bindings

**Observation.** The draft forbids another store of the addresses "for the same vault."

**Correction.** Limit that prohibition to another instance-storage copy in the family repo or another instance repo, and expressly retain the package immutables as deployment bindings. This keeps the required package-to-instance initialization write from again becoming ambiguous.

### Draft F9: include the second stale selector instruction

**Observation.** Only FS-A01 is named for replacement.

**Correction.** Also name FS-FACET-01's ambiguous `poolManager()` exclusion, as my response did, and preserve the externally callable position getters through the shared facet. Correcting an acceptance row alone must not leave a contradictory facet instruction for the PRD pass to copy.

### Draft F10: separate underlying donation from share donation

**Observation.** The flag's true branch applies to the signature generally and the false branch universally says to pull the amount.

**Inference.** That wording can apply held-unbooked-balance attribution to shares parked on the vault or replace caller-share burning with a transfer-based claim. My proposal deliberately did neither.

**Correction.** Restrict the pretransfer true branch to underlying-token donations; require false for a share donation and burn only the caller's shares. Specify no return values and installation of only the three-argument signature, rather than leaving an old overload implicitly available. Keep the existing owner/operator restriction and zero-supply rule. These are omitted load-bearing parts of my F10 recommendation, not objections to adding the flag.

### Draft F11 and F12: preserve conditions without claiming verification

**Observation.** F11 names the permitted borrowed routes but not their existing conditions; F12 says an operator may still call with a zero owner.

**Correction.** In F11, preserve the existing self-funded, non-pretransferred borrowed context and settlement of the vault's own deltas; manager-unlocked status alone is not authority. In F12, say an independently authorized operator remains eligible under the existing guard even when the stored owner is zero. Do not imply that this advisory inspected how such an operator is established or proved the zero-owner path at runtime.

F6 should likewise expressly apply on both unlock paths and preserve atomic rollback, although its principal-only conversion choice otherwise states my proposal accurately.

### Draft F14: name the remaining stale denominator and preview wording

**Observation.** The replacement list includes automatic compound and idle payout, but not the post-compound issuance denominator or section 6's maintenance-bearing preview description.

**Correction.** Add those two replacements: use pre-add deployed liquidity for issuance, and preview the same operation without automatic maintenance. These were explicit, load-bearing parts of my F14 proposal. Otherwise a pass limited to the named sentences can retain inconsistent issuance timing and preview behavior.

### Draft F15: make inventory completeness auditable

**Observation.** The proposed completion condition says to name every consumer and point each at the tuple.

**Correction.** Require source locations, the current decoding assumption, the required treatment of both tuple fields, and a migrate-or-proven-unaffected disposition for each in-scope direct, interface-mediated, and low-level consumer, including the configured rate-provider path. State the inventory's search scope. This is completion evidence for the comprehensive pass, not a requirement to build the list in this council or implement migration during authoring.

### Draft Proposed text and Coverage: distinguish sentences from summaries

**Observation.** Most entries labeled "Recommended sentence" are multiple sentences, and the agreement table often records only a high-level shared direction.

**Correction.** Provide one clearly delimited copyable lock sentence per finding, with rationale outside it, as the assignment requested. In Coverage, distinguish agreement on direction from agreement on a fully specified procedure, especially for F1, F5, F7, and F10. My support for a ratio target or a three-argument signature does not establish support for the omitted details.

## What was not adopted from others

I have not read other members' files for this advisory and cannot attest to their full proposals. I assess only the alternatives attributed to them in this draft.

- F5's fixed-half alternative remains rejected because it does not specify the ratio-and-rounding result.
- F6's residual payment and residual booking alternatives remain rejected because they change the selected-token principal payout contract.
- F7's donation-only emission remains rejected, but the draft's fee-presence substitute is also insufficient.
- F10's implicit shared-context flag remains rejected in favor of an explicit signature argument with separate share-donation rules.

These are continuing Astra positions, not claims that the owner has accepted a replacement.

## Limits

Only the exact coordinator draft was read during this advisory. The initial response was used from conversation context, not reopened. No peer feedback, PRD, blockers, dependency source, memory file, or other draft was opened. No hash, Forge, tests, installs, Git, or sub-agents were used.

This is textual and procedural advice, not runtime proof. It neither authorizes implementation nor authorizes a PRD edit, and it does not replace the draft or create an owner lock.
