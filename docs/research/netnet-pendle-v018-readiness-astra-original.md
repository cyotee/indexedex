# Astra — v0.18 independent readiness review

Review date: 2026-09-26 (provided environment date). Research only. No peer originals/cross-reviews opened in this pass; preserved session knowledge is not authority. No shell, tests, delegation, code/config/instruction changes or deployment. Only this report is written.

**Metadata:** Astra is the assigned researcher label. No tool exposed an independently verifiable runtime model ID/provider attestation; prompt identity and historical PRD metadata are not runtime evidence.

References: **P** = `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.18, all 950 lines read; **M** = sibling `NETNET_PENDLE_OPERATION_MATRIX.md`; **Q** = sibling `REQUIREMENTS_QUESTIONS.md`; **U** = `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md`, now **v0.5**, read completely. Current CLAUDE, skill catalog, relevant agent law/alignment/I/O sections and canonical Crane/local architecture, deployment, testing, adversarial and hook-package guidance were read directly. Citations are unpinned local snapshots.

## Verdict

**Ready to write a gated implementation plan; not ready to freeze its executable specification.** Custom-family approval is recorded (P:22–24). The one-hour arithmetic windows, separate hook-spot/DETF-synthetic series, interface-standardization scope, generalized reward destination and abandonment of missed-epoch compounding are settled (P:26–81). Do not seek approval again or expand this task into existing-hook retrofits.

The amendment commendably distinguishes human selections from inferred formulas and failure policies. However, it remains an override pasted above contradictory operative requirements. Consolidation and four narrow semantic closures are more urgent than another broad product questionnaire.

## 1. Document consistency — high confidence

P:20 supplies clear precedence, so the following are **retired text, not competing owner choices**:

- P:93,189,440–460,580,715,769 still mandate compounding; P:456 expressly forbids the linear expression now proposed at P:59–71.
- P:190,464,715 still leave the window/method open; they omit the second series.
- P:426,711 still declare authorization missing; P:24 closes O01. `CLAUDE.md:45–46` and `docs/agent/INDEXEDEX_AGENT_LAW.md:89–101` remain unreconciled shared text. Record the approved family-specific exception in implementation traceability rather than request fresh approval or generalize it to other families.
- P:693–701,718,740 retain PENDLE-only harvesting and OPEN other destinations. All fee-owned exclusions throughout custody/quote accounting must cover the generalized reward set, not only PENDLE.
- P:295,303 describe HLP exits as restricted to allotted components without a proportional-mode qualifier; P:331–342 expressly permits invariant-priced nonproportional modes.

**Recommendation:** reconcile R/O/A tables and operative sections in place, preserving historical narratives separately. A precedence banner resolves interpretation but is a weak implementation checklist.

Companions remain stale: M:3,49,54,85,88,104 still has v0.15-era expansion/reward gaps and an UNKNOWN USDG maturity despite its own row 24. Q:7,28 remains reconciled only through v0.12. Replace outdated gaps with the specific v0.18 remaining questions; do not mark the proposed equation as owner-confirmed.

## 2. Current Universal companion introduces a real integration boundary

U is no longer v0.2: v0.5 still describes NetNet compounding (U:11,17–19,164,206,265,281,298), contrary to P:55. More importantly, it now selects Universal cold-window epoch consumption, fee/creator internal-share issuance and zero-share donation allocation (U:113–132,178,291–303).

**Do not import those policies into NetNet.** P:20,39 explicitly prevents companion override and inferred skip-on-unavailable behavior; P:518,522 retains unchanged-share expansion and no new fee/creator expansion allocation. Engineering must document which shared utilities are reusable without inheriting incompatible economics, and where custom staking remains separate. This is a compatibility/design gate, not a request to reconsider balance-derived staking. Existing-hook TWAP implementation remains a separate workstream even if both efforts converge on the same interface.

## 3. Necessary narrow owner questions

1. **Confirm the catch-up equation and its cadence consequence.** P:59–71 correctly labels `floor(S0*n/200)` a working interpretation, not a supplied owner equation. Under unchanged eligibility and no other supply changes, two epochs batched from 1,000 mint 10; separately settling each epoch mints 5 then 5.025, totaling 10.025 before rounding. Thus “non-compounded catch-up” does not eliminate compounding across actual settlements. Ask whether this batch-local interpretation is intended; do not add a fixed global base or flat one-time 0.5% silently. This arithmetic is inference, not an exploit/profit claim.
2. **Approve an operation/readiness policy after engineering presents alternatives.** For unavailable history, must settlement-dependent stakes/transfers/claims revert, defer epochs, or follow another explicitly specified behavior? P:39,71 leaves this open; P:472–478 otherwise couples operations to settlement. Skipping expansion while allowing claims is not selected. Distinguish zero-result valid price, insufficient history, invalid valuation and arithmetic failure.
3. **Identify intended consumers of the synthetic TWAP.** P:41 explicitly does not replace instantaneous synthetic reads. Preserve hook TWAP for expansion and finite-size owned-reserve execution. Ask only whether specified gates/views should switch to the synthetic average; engineering supplies a consumer table with the retained instantaneous baseline and economic differences.
4. **Resolve the retained-token incentive collision, if supported markets can produce it.** P:45–49 selects a token exception but leaves same-token incentive allocation/classification explicit. Do not forward it merely because its provenance is “incentive,” or admit it as accrued YT interest merely because its address matches. Confirm permissible use of retained incentive receipts, including whether they may fund the interest-only trading leg. Actual designated token/address discovery is engineering verification, not a new destination election.

No fresh questions are needed on approval, window, averaging method, public HLP, atomic rollover, empty-target rejection (P:644), extra contraction controls, or generic other-reward destinations.

## 4. Engineering specification and feasibility gates

**Oracle correctness:** P:33 promises a price-time integral. Define the exact marginal spot and synthetic valuation, denomination, fee inclusion and units; pre-change accumulation; boundary interpolation; same-block handling; bounded history; cumulative overflow; initialization and rollover continuity. Price can change through public HLP activity, donations, external rebases, rate changes and claim realization—not only local swaps. Extending the last sample is faithful only to an explicitly defined sampled-price process or an unchanged underlying price. Specify that distinction and demonstrate how changes outside DETF calls are observed; do not claim reconstructed history. Avoid circular initialization where settlement prevents the operation needed to establish observations.

**Whole-call liveness:** removing the expansion loop does not bound dependency work. Freshly read `lib/crane/contracts/protocols/pol/net/src/Staking.sol:134–150` advances one epoch per due invocation. Keep processed-NET epochs distinct from elapsed wall time; do not add a hidden upstream catch-up loop. `.../net/src/BondDepository.sol:104–138,143–165` still accepts arbitrary note recipients and scans the whole note list. A bounded ownership/collection design remains unproved; per-NFT escrows alone do not establish a bound.

**Reward accounting:** build a per-token, per-source ledger covering principal, YT interest, incentives, donations and fee liabilities, including force-claims and historical series (P:47–51,598–622). Reward USDG cannot inflate backing or synthetic prices. Specify supported reward discovery, bounded collection and forwarding failure isolation without inventing sweep rights. New SY after rollover must not erase the old retained-token classification.

**Unchanged hard gates:** owned-book Weighted mapping, exact-output inversion, full V2 feature parity, zero-interest first bond, B/U zero-share/final-exit rounding, child authority/reentrancy and short/expired bond-duration compatibility (P:252–268,376–380,518–541,570–580). Funding realization steps are possible, not a fixed waterfall. Public LP rights remain selected; do not import owner-only restrictions.

## 5. Planning acceptance and evidence limits

Expand V18-5 into actual A11/A40/A43/A44 replacements and an operation-to-evidence map. Include cadence comparison, cold/warm oracle operation availability, same-token provenance, reward-USDG exclusion, quiet periods with external valuation changes, failed forwarding and long-inactivity total-call cost. Numerical representability needs a documented horizon/recovery analysis; repeatable overflow revert is not recovery (P:73).

Repo layouts, selectors, observation structures, rounding algorithms, dependency pins and test decomposition are planning work. Exact deployed addresses/code hashes, active markets, reward lists, tax state and oracle terms remain unverified. Local source inspection is not live equivalence. No external library/API documentation claims are relied on here; no external query transmitted source or secrets. Referenced upstream URLs in P:796–811 were not refreshed in this pass.

Confidence: **high** on textual precedence, stale companions and arithmetic; **moderate** on identified integration/liveness risks; **no certification** of feasibility, solvency, peg effectiveness or security. No council consensus is asserted. Stop after this independent report.
