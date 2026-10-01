## Astra — combined cross-review of original saved reviews

**Grok:** Accept preserving OPEN entry/redemption/direct-staking choices, exact releases, host selection and wrapper feasibility. However, these are largely already explicit (`initial:67,151–153,192`), not missing requirements. Accept clarifying that the selected V2 pair is NET/USDG; sNET restrictions concern other proposed routes. Preserve intended epoch/maturity commitments while leaving their exact release mechanics OPEN. Policy reconciliation remains required; tax-aware code does not supply authorization.

**MiniMax:**

1. **Reject “both [exemption and policy revision] are required.”** The user selected taxed operation. `NET.sol:131–145` defines when transfers are taxed; active exemption changes those mechanics, not repository authority. An exemption is neither required by the design nor sufficient to override the token ban. Keep initial line 127 unchanged on this point.
2. **Accept only a factual clarification** that the SE cannot change third-party tax treatment. Neither the SE nor third-party LPs require exemption; each actual transfer follows its own endpoints. Expense attribution is not synonymous with charging existing SE holders.
3. **Reject adding a second D50 clock to this family.** Existing families retain current law, but this proposal selects NET-state synchronization and requires explicit supersession. A second expansion clock would be an invented economic requirement (`initial:24,141`).
4. **Reject prescribing an unproven custody-side selection mechanism.** Record the liveness problem and demand evidence; wrapper-side selection cannot remove the upstream aggregate loop. No viable solution is established by architectural wording.
5. **Accept linking transition interfaces as candidate surfaces**, not declaring them sufficient for coupled facades. Shared/nonlocal quote-state compatibility remains unproven.

MiniMax’s optional route-discovery and rollover checks already appear at `:84,161`. Keep the named host candidates, without presenting every conceptual stable variant as an existing deployable package.

**Important retained Astra correction:** At external-bond reentry, contributed assets become common backing while the NFT controls the corresponding locked receipts. Before contribution, pending NET remains exclusive; do not exclude contributed assets indefinitely or duplicate receipt liabilities.

**Verdict:** Proceed to a consolidated **DRAFT**, preserving settled selections and marking feasibility gates. Neither this review nor consolidation approves policy exceptions, code or deployment. Original draft/reviews remain unchanged.
