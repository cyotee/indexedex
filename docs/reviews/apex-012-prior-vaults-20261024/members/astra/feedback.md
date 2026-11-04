# Identity

- Run ID: apex-012-prior-vaults-20261024
- Member label: astra
- Profile: research
- Phase: advisory feedback
- Requested role: council-member
- Requested model: chatgpt-subscription/gpt-6-astra:high
- Actual model, account route, and reasoning setting: not exposed
- Owned path: /Users/cyotee/Projects/indexedex/docs/reviews/apex-012-prior-vaults-20261024/members/astra/feedback.md
- Peer files read: no

# Draft reviewed

Draft ID: `draft-apex-012-prior-vaults-20261024-r1`

Path: `/Users/cyotee/Projects/indexedex/docs/reviews/apex-012-prior-vaults-20261024/coordinator/draft.md`

# Disposition

Requested changes. The draft accurately preserves my central reading: live slot0 dependence does not establish the fixed-price added-depth claim, and the survey supplies conditional precedents rather than a proven replacement vault. It preserves the principal costs of two-token settlement, delayed accounting credit, and cached valuation.

It nevertheless overstates the evidence concerning Charm's spot-move vulnerability, attributes the synthesis's proposed accounting cost too directly to Panoptic, and leaves the cached-mark qualification incomplete. These are evidence and attribution corrections, not requests to redesign the vault.

# Concerns

1. **Do not turn Charm's spot sensitivity into a demonstrated attack.** The sentence "Charm does not stop the spot-move sequence" goes beyond my reading. S14 and the synthesis's "Quote functions in the recommendation set" establish spot-sensitive two-token amounts, not the profitability of the auditor's swap/deposit/swap-back/redeem sequence against Charm. Replace it with a statement that Charm remains spot-sensitive and the survey did not establish whether that sequence succeeds. Likewise, qualify "only a simulated sale into remaining depth is the liquidity claim" as the mechanism recorded for Wings, not a universal necessary condition for liquidity-manipulation losses.

2. **Keep the two-token inference conditional on more than spot.** My response held vault-owned liquidity, inventory, accrued fees, and supply fixed as well as spot. The draft's "At a fixed spot" compresses away those assumptions. State that merely adding external liquidity does not change the calculated two-token entitlement with those other inputs unchanged. This remains an inference from Arrakis V2 and Charm's recorded formulas, not proof of either complete lifecycle. Sources: S4 and S14; synthesis, "Executive summary" and "Quote functions in the recommendation set."

3. **Separate Panoptic's inspected formula from the synthesis's proposed LP accounting.** The sentence "The cost is that fees and the other token stay out of the amount until a real credit writes the counter" describes the synthesis's "Recommendation," not an established Panoptic withdrawal restriction. S16 supports stored conversion accounting in an options-collateral contract. Label the deferred recognition of unconverted inventory and uncredited fees as a cost of the proposed adaptation. The draft correctly retains the missing immediate-exit funding proof. Also retain that the proposal says LP swap-fee earning can continue; delayed recognition is not the same as abandoning fee earning. That distinction was explicit in my response.

4. **Limit the cached-mark statement to the interval without a refresh.** "A liquidity change in the attacker's own transaction does not rewrite that cached number" is safe only for the liquidity change itself. The survey does not establish that an eligible `poke` cannot occur in the same transaction. Say the number remains unchanged between successful updates, rather than implying a transaction-level guarantee. Preserve the additional cost that the cached number is not demonstrated to be a continuously executable one-token rate, beyond the already stated absence of proof that withdrawals use it. Source: synthesis, "Alternative precedent, not the recommendation."

5. **Add the requested source locators to the suggestions.** The draft names protocols but does not give synthesis sections or ledger IDs for each suggestion, as the brief requires. The relevant anchors are S2-S3 plus the claim report's "What the auditor claims" for Wings; S4/S14 for Arrakis V2/Charm; S16 and the separately identified synthesis "Recommendation" for stored accounting; and synthesis "Alternative precedent, not the recommendation" for Maker GUniLPOracle. The exclusions can cite S22-S23 for Visor/Gamma and S9 for ICHI.

# Limits

Reviewed only the named coordinator draft during this advisory pass, against my initial response and the admitted evidence already read. No peer files, additional sources, protocol implementations, or tests were consulted. No sub-agents were launched. This feedback does not endorse a vault design, adopt the synthesis recommendation, or authorize implementation.
