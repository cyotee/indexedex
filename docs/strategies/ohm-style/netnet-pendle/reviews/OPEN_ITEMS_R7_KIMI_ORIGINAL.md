# OPEN_ITEMS_R7 — Kimi K3 ORIGINAL independent first pass

Read 2026-09-25: CLAUDE.md, custom PRD v0.16 (`NETNET_PENDLE_DETF_PRD.md:7,26,122,368–372,460,595,812–814`), operation matrix, REQUIREMENTS_QUESTIONS.md, and `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md` (U01–U04, C01–C16). No peer/older artifacts; no code runs. Settled and not re-asked: opening 1,000 NET/DETF; strict >1 NET gate on processed NET epochs; premium-dependent compounded pending expansion with pre-transaction display; atomic rollover; full HLP modes; USDG bond lock alignment; deployment split/singleton/Args; no strict-certification gate.

## Three remaining true owner-economic questions

**Q1 — Premium coefficient: what does "0.5%" mean inside the premium-dependent model?**
Still unclear (PRD:26, :370, O05 :595; compounded PRD:19, :90). The selected recurrence is `E_i = floor(premiumBase_i * c / W)` with `premiumBase_i = floor(S_i*(P_i−W)/P_i)`. The 0.5% proposal has no defined basis under this model.
*Proposal (not a selection):* interpret 0.5% as the per-processed-NET-epoch premium-closure coefficient, `c = 0.005e18`, i.e., each eligible epoch mints 0.5% of the current premium base — the most faithful premium-dependent reading. Flag: at NetNet epoch frequency this compounds aggressively; owner should confirm magnitude intent before freezing.

**Q2 — Which NET price, and how does the price evolve across virtual epochs?**
Two coupled choices: (i) the NET-per-DETF price measure for the >1 gate (marginal reserve-hook spot, owned-book synthetic, or an executable finite-size quote — each manipulable differently); (ii) U01 price feedback: recompute P_i substituting projected supply S_i (premium shrinks; later virtual epochs can lose eligibility) versus freezing the settlement-snapshot price (geometric, mints more, stays eligible longer) (compounded PRD:92–103).
*Proposal:* use the owned-reserve Weighted synthetic NET mark at a fixed external snapshot, recomputed with projected S_i each virtual epoch — it matches as-if-sequential realization and cannot mint on a premium that issuance itself would erase. This is a policy question because the alternatives are provably non-equivalent; do not let "compounding" silently pick one.

**Q3 — Allocation and display semantics (U02/U04 for this family).**
(a) One aggregate reward allocation at realization versus emulated per-virtual-epoch allocation/index updates — these differ in gons rounding, dust and fee/creator participation; equivalence is unproven (compounded PRD:105–111). (b) Display: separate projected getters versus changing stored `balanceOf`/`totalSupply` semantics (C05 forbids the latter silently; U04:145).
*Proposal:* compounded supply projection with a single aggregate funded allocation at realization, exposed through distinct projected views; stored supply/balances remain actual-only. Recipient identities and R43 custody are settled and not reopened.

## Explicitly NOT owner questions

- **Engineering:** empty-successor seeding (R4 evidence: `mintPY` + dual `market.mint`; Keep-YT split divides by zero on empty reserves); first-bond zero-interest reconciliation (PRD:451, :460); gas-bounded realization without hidden caps (C12); dependency inventory and selector/display mapping (§5 inventory).
- **Authority gates before execution:** O01 FoT/rebasing token-policy reconciliation; approved supersession of D50-era noncompounding law and 8h clock for this family; Universal instances are immutable/unowned — remediation does not authorize upgrading or migrating existing deployments (compounded PRD:183); no implementation is authorized by any of these documents.
- **Doc reconciliation (not questions):** tracker header still says "reconciled through version 0.12" (`REQUIREMENTS_QUESTIONS.md:7`) though PRD is v0.16; PRD R09's "same tokens" wording predates the new-SY permission (§11:459 controls); matrix rows 08–10 Input/Output UNKNOWNs are partially superseded by the selected HLP modes; alignment PRD:977–1005 noncompounding text conflicts with the owner's reversal and awaits the reconciliation the compounded PRD §1.1 already mandates.

## Uncertainties

No live Robinhood verification; NET epoch processing cadence vs wall time unmeasured; proposal magnitudes unchecked against economic-safety gates. R6-era linear arithmetic is superseded and not relied on.

Researcher: **Kimi K3** — assigned metadata `kimi-code-plan-global/k3` (variant high); routing metadata only, no provider attestation.
