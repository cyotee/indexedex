# Identity

- Member: astra.
- Run: `se-fullspread-prd-quality-20261103`.
- Profile: review.
- Phase: initial independent response.
- Owned path: `members/astra/response.md`.
- Requested role: `council-member`.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Actual runtime model, provider/account route, reasoning setting, and role: not exposed.
- Peers read before submission: no.

# Question and targets

Does the rewritten full-spread PRD say each locked requirement clearly enough that two implementors would copy it the same way?

**No, not throughout.** The rewrite clearly carries the principal economic overrides, but five remaining issues prevent an unqualified clarity approval. Two concern incomplete behavior, one concerns a caller-token mapping collision, one turns an unnamed event ABI into a purported lock, and one leaves an obsolete rejection beside its removal.

The sole review target is:

`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`

The reviewed revision identifies itself as `fullspread-se-prd-rewrite-20261103`. The whole file was read, including the acceptance rows, non-goals, and historical participation section.

The clarity standards are:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`, read in full, with the 2026-11-03 overrides taking precedence over the earlier decisions and historical summaries.
- `docs/vaults/PRETRANSFER_DIRECTIVE.md`, read in full.

# Evidence

All substantive evidence is **source observation from those three documents**, not runtime evidence. Each finding separates the text observed from the implementation divergence inferred.

For concise locators below:

- **PRD** means `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`.
- **Locks** means `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`.
- **Directive** means `docs/vaults/PRETRANSFER_DIRECTIVE.md`.

Line numbers refer to the files read in this assignment. Important finding locations were checked against additional bounded reads. No atomic repository snapshot or content hash is claimed.

The principal comparison anchors were Locks:21 (overstated pretransfer maximum), Locks:23 (one-token swap sizing), Locks:25 (complete one-token exit conversion), Locks:27 (fee and booked-balance exit apportioning), Locks:29 (maintenance events), and Locks:31 (live owner authority). The earlier B-01 through B-13 decisions were also examined; their superseded sentences were not treated as independent requirements.

# Assumptions

- A clarity defect must affect observable behavior, a required interface, or a testable requirement. Different internal helper names or equivalent algorithms are not defects.
- A later owner override governs an older conflicting sentence. In particular, the principal-only withdrawal sentence still present in the lock file's final summary does not displace the explicit F2 override.
- The PRD's references to external reports and implementation files are not proof that those documents supply an unstated decision. Those linked documents and code were not inspected in this assignment.
- The native/WETH example below is conditional on an initialized hookless pool with those two currencies. It is a specification-domain example, not a claim that such a deployed pool was found.
- Accepted liquidity-only issuance, unbounded swaps, privileged maintenance sandwich exposure, and the absence of a vault rate are not reopened as economic objections.

# Coverage

| Supplied document | Status | Coverage |
| --- | --- | --- |
| PRD | Examined in full | Sections 1-10; FS-X and FS-OWN decisions; facets and package; money and both unlock paths; previews; hook fixtures; FS-A01-FS-A38; matrix and audit requirements; non-goals and historical participation. |
| Locks | Examined in full as the clarity standard | November 3 overrides; B-01-B-13; donation/compound booking; N-01-N-07; matrix files; audit tests; final locked-summary list, with precedence applied. |
| Directive | Examined in full as the pretransfer standard | Unbooked versus booked custody; declared maximum; refund token and amount; oversized maximum; contract-caller restriction; parked-share exclusion. |

The following requirements are materially clearer and were not found defective on their own terms:

- FS-OWN-24 specifies fee netting rather than an extra mint, separates the genesis floor, applies the 30% clamp to execution and previews, and excludes pass-through swaps.
- FS-OWN-27 and FS-MONEY-01 use raw liquidity and unscaled shares; `decimals()` is metadata.
- FS-OWN-30 specifies pre-burn denominators, separate rounded-down fee and booked claims, the caller's requested-token payout, and complete conversion of the opposing claim on one-token exit.
- FS-OWN-33 replaces a fixed half-input or 48% prescription with the greatest-addable-liquidity result and input-token remainder constraint.
- FS-OWN-14 distinguishes one-token maintenance from a both-token proportional deposit, actual-balance booking, failure propagation, no-op compound, and the accepted maintenance exposure.
- FS-OWN-07 distinguishes deployed token reserves including unpaid fees from locally booked balances; it does not restore a sleeve or a committed snapshot.
- FS-UNLOCK-02 limits borrowed entry to canonical `exchangeIn`, forbids nested unlock, and requires only this diamond's deltas to close.
- FS-OWN-03, FS-OWN-05, and FS-OWN-29 keep vault rate/SY selectors absent and place the required rate-provider instances outside the vault.
- FS-OWN-08 states the tuple-return migration and names the six length gates and three ABI bindings. Their current implementation contents and the referenced complete occurrence index were not independently verified.
- FS-TEST-04 requires fresh matrix and integration evidence and does not count deletion of the old implementation as proof for this family.

# Review findings

## ASTRA-01 - High: an oversized bundle leg has no complete call-level outcome

**Location:** PRD:238, FS-OWN-32; PRD:208, FS-OWN-25; PRD:244, binding minima. Standard: Locks:21 and Directive's maximum/refund paragraph.

**Requirement that failed:** The pretransfer rule must determine what the accepted bundle operation does when one declared maximum exceeds that token's unbooked balance. Refunding the affected token without spending it or pulling a shortfall is locked; the rest of the same call still needs a testable outcome.

**Source observation:** FS-OWN-32 states the affected-token refund rule and then expressly says: "This sentence does not say what the other declared amounts in the same call do." FS-OWN-25 requires proportional bundle addition without the one-sided balancing swap. FS-OWN-32 also preserves binding minima.

**Inference and impact:** For a two-leg declaration with one overstated leg and one adequately funded leg, an implementor cannot derive the complete refund array, whether the unaffected leg is processed or retained for another call, or whether the operation ends without attempting an add. The no-swap bundle rule constrains the choices but does not supply the missing control flow. Genesis rejection and a positive minimum can additionally prevent a refund-only result, so "a larger maximum is not a revert" cannot serve as an unconditional whole-call assertion. Independently written implementations and tests can disagree despite both applying the affected-token refund sentence.

**Fix direction, advice only:** Complete the bundle-level rule for an overstated component: state the treatment of every other declared component, whether an add is attempted, the returned output/refund values, and how existing genesis and minimum checks apply. Preserve the locked no-spend/no-shortfall rule. If the admitted locks do not determine that behavior, identify it as an unresolved decision rather than asking an implementor to choose. Do not add a balancing swap or silently replace the owner's refund rule.

## ASTRA-02 - High: operator authority is checked but its usable control path is unspecified

**Location:** PRD:166, FS-OWN-14; PRD:299-319, FS-FACET-01; PRD:371; PRD:375-385 and PRD:404, package and initialization rules. Standard: Locks:31.

**Requirement that failed:** The new live-owner/operable requirement must be usable through the deployed proxy and testable without inventing an authorization path.

**Source observation:** FS-OWN-14 clearly replaces a stored owner with the current `feeTo()` address and keeps operator authorizations in `OperableRepo`. It forbids reusing the existing facets for that check. The listed proxy selectors do not identify a way to grant or revoke operator authorization. The package arguments and initialization description do not supply an initial operator set either. The requirement to implement new modifiers does not itself describe a callable operator-management operation.

**Inference and impact:** One implementor can deliver a live-owner-only system because no operator can be registered through the specified surface; another can add a custom management surface, choosing its authorization and observable ABI. A test of a legitimately authorized operator cannot be derived from this PRD alone without importing an unstated interface or injecting authorization state. That is an externally relevant omission, not a request to prescribe modifier filenames.

**Fix direction, advice only:** Identify the intended operator authorization/revocation interface and how it is installed on this proxy, with the live `feeTo()` authority applied where the owner lock requires it. State the initialization source if there is one. Cite the accepted contract rather than inventing new selectors, events, or errors. If no such control path has been accepted, record that missing decision explicitly. This finding does not claim that `OperableRepo` lacks implementation helpers; its code was not inspected.

## ASTRA-03 - Medium: native/WETH face collision leaves accepted-pool routing ambiguous

**Location:** PRD:182, FS-OWN-17; PRD:192, FS-OWN-22; PRD:208, FS-OWN-25; PRD:242, FS-OWN-32; PRD:398, FS-PKG-02. Related requirement: FS-OWN-07's address-keyed reserve query.

**Requirement that failed:** Any initialized hookless pool is accepted, while caller inputs, outputs, and reserve queries must have a determinate ERC-20 face.

**Source observation:** FS-OWN-22 maps each pool currency to `vaultTokens()` in pool order and substitutes network WETH for native. It permits any initialized hookless pool and forbids an inherited-domain check. FS-OWN-25 supports underlying-to-underlying `exchangeIn`; FS-OWN-32 rejects `tokenIn == tokenOut`. The PRD supplies no special treatment for two pool currencies mapping to one caller token.

**Inference and impact:** In the conditional native/WETH pool case, the prescribed list is `[WETH, WETH]`. An address-only input cannot distinguish the native leg from the WETH leg; an underlying-to-underlying call has equal caller-facing addresses and meets the stated invalid-route check. The address-keyed `reserveOfToken(WETH)` also lacks a rule saying whether it denotes one pool leg or their combined ERC-20-facing amount. Two implementors can choose different aggregation and route behavior, or one can silently exclude a pool that the acceptance rule admits.

**Fix direction, advice only:** State the caller-face accounting and supported-route behavior when the substitution produces duplicate faces, including reserve lookup and bundle input/output treatment. Resolve it against the locked pool-acceptance rule; do not quietly add a pool exclusion, raw-ETH caller route, or new selector. This is a missing behavior specification, not evidence of a deployed exploit.

## ASTRA-04 - Medium: an unspecified Donation ABI is presented as an owner-locked zero-field event

**Location:** PRD:176, FS-OWN-14; PRD:190, FS-OWN-21. Standard: Locks:29, F7.

**Requirement that failed:** The rewrite must preserve the event requirement without completing an unmade ABI decision.

**Source observation:** F7 explicitly says "`Compounded()` still has no fields" and "`Donation()` fields were not named." The PRD instead says "`Donation()` has no fields" and repeats that instruction in FS-OWN-21. It presents those paragraphs as owner answers with the November 3 overrides already applied.

**Inference and impact:** "No fields were named" does not establish that an existing or intended event has zero fields. An implementor copying the PRD commits to a zero-field event; an implementor honoring the stated precedence still lacks an accepted field list. The event's observable ABI is therefore decided by the rewrite rather than by the cited lock. This finding does not propose any alternative event arguments.

**Fix direction, advice only:** Identify an admitted source that actually fixes the `Donation` signature, or mark that ABI detail unresolved while preserving the locked emission trigger. Do not claim the F7 sentence itself established zero fields, and do not invent fields to close the gap. The explicit zero-field `Compounded()` lock is unaffected.

## ASTRA-05 - Low: package validation still instructs rejection of a removed argument

**Location:** PRD:395-399, FS-PKG-02, compared with PRD:383 and FS-OWN-03.

**Requirement that failed:** The rejected-input list must not preserve a live validation requirement for the designated `rateAsset` argument after the argument and its error have been removed.

**Source observation:** Under "Reject, without a partial diamond," the PRD lists "A designated `rateAsset`" and immediately says FS-OWN-03 removes that argument and that error. FS-PKG-01 separately says `rateAsset` is not a field.

**Inference and impact:** A test author following the reject list is asked to construct a forbidden argument or restore a validation case that the package schema cannot express. Another correctly treats it as an absence requirement. The sentence is an obsolete negative case left beside its withdrawal, not merely awkward prose.

**Fix direction, advice only:** Remove this item from the live rejection list or clearly classify it as a removed case. Preserve the separate, valid rejection of an installed `rateAsset` selector in the preceding component/cut validation rule. No replacement argument or error is needed.

# Limits

This is a static, independent clarity review of the named PRD against the supplied standards. It is not a security audit, implementation review, or runtime verification.

No peer response, coordinator draft, previous council original, accepted-ABI report, consumer inventory, implementation source, or audit report was read. References to those materials in the PRD were evaluated as references, not independently confirmed evidence. No Forge, tests, installs, deployment, wallet operation, Git command, public search, or sub-agent was used.

Only the assigned `members/astra/response.md` was written. The PRD, lock file, directive, brief, and other members' files were not edited.

The findings advise clarification; they do not choose new economics, authorize implementation, authorize a PRD edit, replace the PRD, or represent a council consensus.
