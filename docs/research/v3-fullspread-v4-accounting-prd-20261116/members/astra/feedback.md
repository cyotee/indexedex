# Identity

- Member: astra.
- Phase: advisory review.
- Requested role: council-member.
- Requested model: chatgpt-subscription/gpt-6-astra:high.
- Runtime model, provider, reasoning setting, and task identity: not exposed.
- Fresh or continued: continued.
- Initial response preserved: yes.
- This file replaces a missing initial response: no.
- Peer responses read: not read.
- Peer feedback read: not read.
- Unread members treated as support: no.

# Draft under review

- Draft ID: draft-v3-fullspread-v4-accounting-prd-20261116-r1.
- Exact path: `/Users/cyotee/Projects/indexedex/docs/research/v3-fullspread-v4-accounting-prd-20261116/coordinator/draft.md`.
- Fingerprint: not computed. No fingerprint was computed.
- The exact draft was opened and read completely: 194 lines.
- Review basis: that draft and the source observations and reasoning already established in this conversation. No sources or initial response were reopened for this advisory.

# Disposition

requested-changes

The draft accurately carries the main accounting proposal: raw-liquidity issuance, the fixed 49% entry swap, user refunds, separate booked balances, proportional exits, removal of the sleeve, V3 callback settlement, and the distinction between vault and Hook LP accounting. It also preserves the external preview dependency and acknowledges booked-claim dilution.

The corrections below address executable differences or wording that cannot safely become PRD requirements. They do not ask the coordinator to resolve the genuinely open product decisions without owner authority.

# Concerns

| ID | Draft section | Concrete concern | Advised correction |
| --- | --- | --- | --- |
| A1 | V3-ACC-10, Refunds | The oversized one-token pretransfer rule says to "consume nothing beyond that balance" and refund the unused amount. This permits partial spending of the available balance. The cited FS-OWN-32 rule requires spending none of it and refunding the entire available unbooked balance. These are different successful outcomes, not equivalent descriptions. | Replace that clause with: "If a one-token declared maximum exceeds the available unbooked balance, spend none of that balance, mint no shares, and refund the available unbooked balance to the payer; do not pull a shortfall. The genesis rule and caller minimum remain binding." Preserve atomic bundle rejection separately. |
| A2 | V3-ACC-03, V3-ACC-05, and V3-ACC-06 | ACC-03 explicitly makes unusable genesis revert, but ACC-05 unconditionally says failed sizing refunds input and ACC-06 unconditionally refunds wrong-boundary-token and zero-active-liquidity inputs. The proposed precedence is therefore contradicted in the operative branches. Neither refund branch expressly preserves a positive minimum-output rejection. | Qualify the successful no-mint/full-refund branches as applying to established supply and only when the caller's minimum permits zero output; expressly cross-reference ACC-03 for genesis. In ACC-06, scope the zero-active-liquidity failure to the strictly-inside-range branch so it does not override a permissible boundary add. |
| A3 | V3-OPEN-01, Position import | "Imported pre-existing fees are booked, not credited as new principal" resolves an economic question despite declaring import undecided. It also conflates the incoming NFT's fees with fees already belonging to the destination vault. My initial response explicitly distinguished them: collected NFT fees are part of the importer's actual incoming assets. FS-OWN-30's treatment of the destination position's existing fees does not by itself require confiscating those incoming fees into a shared book. | Remove the unconditional imported-fee booking instruction. If import is retained, require an explicit disposition of the importer's collected principal and fees as incoming contribution, refund, or an expressly selected alternative; distinguish them from pre-existing destination fees. A proposal to process both as the importer's contribution may be stated as advice, but must not be called a copied V4 NFT-import rule. |
| A4 | V3-ACC-07 and V3-ACC-11, Fees on mint and exit | The draft requires fees observed on an add to be booked but does not state the V3 custody transition on a deposit. V3 `pool.mint` does not itself perform `pool.collect`. One implementer could record fee amounts as local booked property while they remain owed by the pool; another could leave them unpaid. The former can double-count them in booked claims and unpaid-fee reads or leave the local book unfunded. The explicit burn/collect rule addresses withdrawals only. | State that collected fees become booked custody only after actual V3 collection, with unpaid and booked amounts mutually exclusive. For the copied deposit behavior, specify collection of fees attributable to pre-add liquidity, including any fees generated for that position by the entry swap, separately from the caller-funded add. No collected destination fee may fund the user's swap, add, or refund. This is a V3 expression of the copied ownership rule, not a proposal to auto-compound. |
| A5 | V3-ACC-19, Consequence of the copied mint | "Later mints use only new liquidity in the denominator" is mathematically wrong and conflicts with ACC-02. New liquidity is a numerator factor; the denominator is existing deployed liquidity. The booked-claim dilution conclusion is otherwise an accurate statement of my initial response. | Replace the first sentence with: "Later mints use added liquidity multiplied by pre-mint supply in the numerator and existing deployed liquidity in the denominator; unpaid fees and booked balances are excluded from that denominator." Keep the subsequent dilution explanation. |
| A6 | V3-OPEN-03, Selector names | This is more than a naming decision. The current V3 both-token exit takes requested output amounts and a maximum share input; the adopted V4-style redemption takes an exact share input and per-token minima. The current many-to-one deposit also lacks the refund return. Saying the old selectors can be kept "with the new accounting" permits incompatible argument interpretations without identifying the behavioral ABI change. | Rename this decision to cover route signatures, argument meanings, return values, and compatibility. Require an explicit mapping for each retained alias. Do not imply that requested exact outputs can silently become minimum outputs, or that maximum input can silently become exact share input. Leave the actual adoption/retirement choice open. |
| A7 | V3-ACC-10, V3-ACC-12, and V3-OPEN-05 | The draft does not settle or explicitly reserve the distinction between underlying pretransfer credit and authority to burn shares. Current V3 canonical exits can consume shares delivered to the vault, while V4 burns caller-held shares and excludes parked vault shares from generic credit. SY's named vault-held redemption adds another existing path. "The caller's liquidity fraction" does not identify which account is debited, and the generic pretransfer paragraph can be read as applying to shares too. | Add an explicit share-authority decision or requirement: identify the share owner burned on canonical exits, whether share pretransfer remains supported, and how any retained named vault-held SY path is authorized. State that unrelated parked shares are not generic caller credit. Scope underlying pretransfer rules separately and preserve the existing EOA-pretransfer prohibition. |
| A8 | V3-OPEN-06 and Disagreement | The draft describes Astra's exact-output position as dissent from the fail-closed policy. My initial response advised that strict-parity policy, while requiring an express V3 compatibility decision. That is not substantive opposition once the draft explicitly proposes the retirement. Separately, OPEN-06 leaves the reader unsure whether fail-closed behavior is adopted or still proposed: it is under Open decisions, yet calls it "the parity rule." | Record Astra as recommending fail-closed exact-output parity with explicit compatibility disposition, not as opposing it. Mark the proposed route retirement clearly as either awaiting adoption or an adopted draft requirement, and make the Adopted requirements/Open decisions placement agree. Do not infer other members' positions from this correction. |

Two additional coverage corrections would make the proposal more complete without closing an open product question:

- **V3-ACC-08 and the surface disposition:** "`rebalanceLiquidReserve` no longer moves inventory" allows a retained successful no-op as well as removal or rejection. The draft should require an explicit selector/interface disposition for rebalance and its obsolete sleeve queries. Retaining an inert public function is not specified by the cited V4 absence. This can be included in the expanded V3-OPEN-03 manifest.
- **V3-ACC-18 and the external provider outcome:** The draft correctly distinguishes the provider's full-supply sample from a one-share implementation. Specify the preview result for an unfillable opposing claim as a concrete return tuple rather than "a failed plan," which is an internal concept. Also record that the empty-supply inversion currently uses the declared unit input while ignoring a possible refund; retaining that calculation does not make it a consumed-input exchange rate. My initial response identified this refund-denomination issue, and it should not disappear behind the instruction to leave the provider calls unchanged.

These concerns concern requirements fidelity and copyability. I have not reopened the price-protection question, proposed a new oracle, or requested a different liquidity formula. The selected genesis precedence and pool-locked rejection can be stated as draft proposals without presenting them as pre-existing V3 owner locks.

# What was not adopted from others

Peer responses and peer feedback were not read. The draft's descriptions of other members' positions were read only as statements made by the coordinator; I cannot independently attest that those descriptions accurately represent those members.

I did not adopt a peer vote or an inferred consensus as evidence. In particular, I do not treat the reported agreement on locked-pool behavior as authority over the protocol mechanics, and I do not adopt the draft's attribution of exact-output dissent to Astra.

The draft preserves my distinction between the vault's liquidity-only issuance and Hook LP component contributions. It also preserves the consequence that later issuance can dilute existing booked-token claims. It does not fully preserve my distinctions concerning incoming NFT fees, oversized pretransfer no-spend behavior, share-burn authority, or the provider's ignored initial-refund word; those omissions are identified above.

# Limits

This advisory reviewed only the exact named draft using the prior conversation as context. No peer files were read, no fingerprint was computed, no additional source research was performed, and no sub-agent, test, build, install, deployment, wallet action, or Git operation was used.

Only this owned feedback file was written. The initial response, draft, run record, peer artifacts, and final PRD remain untouched.

This feedback is advisory. It does not authorize implementation and does not replace the draft. It does not claim council consensus or require another council round.
