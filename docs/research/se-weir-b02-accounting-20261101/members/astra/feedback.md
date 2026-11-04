# Identity

- Member label: astra.
- Run: `se-weir-b02-accounting-20261101`.
- Phase: advisory review.
- Fresh or continued: continued.
- Initial response preserved: yes.
- Peers read: no.
- Native identity not supplied in this advisory assignment: not exposed.
- Owned artifact: `members/astra/feedback.md`.

# Draft under review

- Draft ID: `draft-se-weir-b02-accounting-20261101-r1`.
- Exact file read: `docs/research/se-weir-b02-accounting-20261101/coordinator/draft.md`.
- Coordinator-supplied SHA-256: `7249b8b39ba5aa4a9a06d2e1afdc3be2d25370a4f4be91f90841b956ce9b2d8a`.
- That digest is supplied metadata, not my computation or an independently verified fingerprint. The draft itself says `Fingerprint: not computed`.
- The complete supplied draft was readable. No other draft was substituted.
- Review basis: this draft and the retained context of my initial independent response. No source, PRD, script, peer artifact, or memory file was reopened.

# Disposition

**requested-changes**

The central distinction is supported: Weir does not protect shared placement from a displaced live price, has no automatic post-withdraw compound, and avoids the specific whole-opposing-balance withdrawal dump by swapping the withdrawn net. The draft also correctly separates placement shortfall from demonstrated attacker profitability.

Before publication, qualify the deposit-isolation claims, carry the effect of FS-OWN-12 into the trailing-placement conclusion, and distinguish an unstated swap-sizing detail from an authorized new product rule. These corrections do not require another research round or an implementation decision.

# Concerns

## 1. External push; Half-excess balance; Preserved disagreements

**Correction: limit the old-holder isolation claim to deployed liquidity, or explicitly state the zero-residual-idle fixture.**

The External push section says the other holders' value change is zero "in that fixture," but it never states the zero-old-idle condition of the caller-funded deposit comparison. Half-excess balance then says, without qualification, "Existing holders are unchanged because the new liquidity is assigned to the depositor." The disagreement table calls deposit isolation real without preserving that boundary.

My initial response distinguished preservation of old liquidity from preservation of all old-holder value. The liquidity-only issuance denominator excludes leftover idle, while withdrawal includes it. A new depositor can therefore acquire a fraction of existing idle even though its new shares leave old holders' deployed-liquidity entitlement unchanged. My executed examples reported idle transfers of 3.097483577 and 3.409090909 after the preceding compound left 50 or 75 token0 idle.

Replace the unqualified claim with:

> With no pre-existing residual idle, the caller-funded deposit fixture leaves existing holders' value at P0 unchanged. More generally, the share formula preserves their deployed-liquidity claim, not necessarily their total claim including idle. Idle is excluded from the entry denominator but included in proportional withdrawal, so residual idle can be diluted by a new deposit.

Use that qualification in Half-excess balance and the deposit-isolation row of Preserved disagreements as well. This is an existing accounting limitation from the initial response, not a proposed additional blocker or an instruction to change issuance.

## 2. Self-moved trailing placement; What selecting Weir does not change

**Correction: explicitly distinguish raw Weir's missing trailing call from the PRD's required post-withdraw sleeve adjustment.**

The draft accurately describes raw Weir's pre-withdraw compound and lack of an automatic post-zap compound. It does not carry forward the relevant FS-OWN-12 sentence, although the coverage table marks that lock examined.

The initial response quoted FS-OWN-12 as requiring an attempt to move each token's local balance toward its sleeve target after every deposit, withdrawal, and compound. That is additional behavior absent from raw Weir. Without this distinction, the reader can incorrectly infer that choosing Weir removes the adaptation's post-withdraw placement exposure.

Add to Self-moved trailing placement:

> This absence describes raw Weir only. FS-OWN-12 separately requires a best-effort sleeve adjustment after withdrawal. Selecting Weir does not remove that lock. If the adjustment deploys a usable pair after the redemption swap, the live-price placement identity still applies; this run has not implemented or executed that adaptation.

Carry FS-OWN-12 into What selecting Weir does not change. Do not assert that every sleeve adjustment necessarily mints: whether it can place depends on the inventory and target at that point.

## 3. Proposed text; Whole-balance redemption dump; Coverage adopted from responses

**Correction: distinguish the absence of an explicit withdrawn-net swap sentence from a finding that the PRD authorizes a whole-balance dump or requires a new economic cap.**

The opening states categorically: "It does not copy the one Weir rule that stops the whole-balance dump." The Whole-balance section treats that as a missing "cap."

The draft itself acknowledges that FS-MONEY-01 already copies proportional liquidity and idle removal. The retained initial response also distinguishes that accounting requirement from the absence of a literal statement of the `net0`/`net1` swap argument. These are not equivalent to a finding that the adaptation may sell stayers' inventory. Nor is the withdrawn-net amount a newly invented price-impact cap.

Replace the opening's final sentence with:

> The quoted locks already require proportional withdrawal accounting, but the draft has not identified an explicit sentence specifying the withdrawn-net amount as the redemption swap input. Weir's source makes that quantity explicit. This is a specification-clarity observation, not authorization to sell staying holders' inventory or to add a new economic cap.

In Whole-balance redemption dump, call it the "withdrawn-net swap amount" or "quantity rule." Preserve the source conclusion that Weir swaps only the exiting slice. Do not turn this advisory's wording correction into a requirement for an additional owner lock.

FS-OWN-30 and FS-OWN-33 are presented as coordinator-supplied context. I did not independently verify them in this draft-only pass. Their inclusion does not authorize me to infer further PRD behavior beyond the text supplied here.

## 4. What the source does; Half-excess balance

**Correction: describe half-excess as targeting the current ratio, not guaranteeing the post-swap ratio.**

The source summary says `_balance` swaps half the excess "so the caller's own input matches the live pool ratio." Half-excess balance similarly says it "ratio-matches" the input. That can read as an exact post-swap property.

The calculation uses the pre-swap live price. Its own swap changes that price, and `_deposit` subsequently rereads slot0. The executed initial examples had leftover token1 of 8.362092890 and 23.201730665 after placement, showing that half-excess does not solve the exact post-swap ratio.

Use:

> `_balance` swaps half the caller's excess calculated at the pre-swap live price. This targets the pool ratio but does not guarantee an exact ratio after price impact. `_deposit` then sizes liquidity at the post-swap live price and refunds unplaced input.

The draft's conclusion that this is not a price guard remains supported.

## 5. Self-moved trailing placement; Evidence gaps

**Correction: state the loss baseline and preserve the source-order feasibility limit of the fee-bearing example.**

The statement that a later placement shortfall belongs to remaining holders is correct. It should not imply that my fee-bearing example proves a net decline from their pre-withdraw wealth or a profitable attack.

Add:

> The fee-bearing example measures placement shortfall against retaining the same net fees and idle until the pool returns to P0. It does not show that the staying holders finish below their pre-fee wealth. In Astra's source-ordered fixture, the pre-withdraw compound leaves one-sided idle; fees generated by the withdrawal swap supply the missing currency for the later compound.

Keep the existing zero-fee, one-sided-idle control. Do not imply that an arbitrary large two-sided idle budget survives Weir's preceding compound unchanged. Other members' differing fixture amounts are recorded in the draft, but agreement on an allocation identity does not independently establish the reachability of each fixture under raw Weir's call order.

# What was not adopted from others

- I do not adopt the profitability claim attributed to Grok that a same-pool round trip extracts the shortfall with or without outside liquidity. The draft correctly limits its conclusion to the accounting identity. I have not read Grok's original in this pass.
- I do not adopt "partly resolved" as an unqualified answer to the shared-maintenance question. As attributed to MiniMax in the draft, it concerns a different caller-funded deposit case; that case needs the residual-idle qualification above. This is a scope distinction, not a rejection of the liquidity-ownership identity.
- I do not adopt peer trailing-loss numbers or treat their agreement as independent validation of source-order feasibility. The draft can retain their participation and differing fixtures while preserving the concrete limits of the example I actually executed.
- I do not adopt an inference that a new owner-approved economic cap follows from the PRD's failure to quote the exact withdrawn-net swap argument. The source quantity and the existing proportional-withdrawal requirement must remain distinguished from new product choices.
- These statements address positions attributed within the supplied draft. They do not represent fresh inspection of peer responses or feedback.

# Limits

- Only the exact supplied draft was read during this advisory pass. The initial response remains preserved.
- The supplied SHA-256 was recorded as coordinator metadata and was not recomputed. The draft's fingerprint line was not edited.
- No peer response or feedback was read. No sub-agent, new council, source investigation, simulation rerun, project test, build, install, network request, or Git operation was performed.
- The coordinator's reported script reruns and newer-lock checks are attributed evidence, not my independently repeated verification.
- This feedback writes only `members/astra/feedback.md`. It does not replace the draft, lock B-02, authorize a PRD edit, or authorize implementation.
- No additional advisory round is requested.
