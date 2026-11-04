# Kimi advisory: coordinator archival receipt

Verbatim final response from Native task `st_01a183c4`, advisory epoch 1, on frozen draft r1.

---

## Identity

Independent Kimi advisory member. Exact route: `kimi-coding/k3.1-pro:high`, global route. This feedback does not replace my original assessment.

## Draft under review

Frozen draft: `pairtoken-se-stage-one-council-20261028-01a1810f-draft-r1`

Path: `/Users/cyotee/Projects/indexedex/docs/research/pairtoken-se-stage-one-council-20261028-01a1810f/coordinator/draft.md`

The draft was read completely and was the only document read for this advisory pass.

## Disposition

**support-with-reservations**

The synthesis fairly represents my original assessment and preserves the principal owner decisions without presenting them as already resolved. In particular:

- Q1 accurately carries forward my blocking concern about entrant attribution without silently approving a replacement formula.
- Q2 preserves the projection scope, work-budget, and conditional-exit issues. It also correctly characterizes my collect-only fallback as a proposed departure requiring explicit owner approval, not as unchanged baseline compounding.
- C1 correctly fixes the raw-unit SY rate arithmetic. My original addressed inputs and rounding but did not independently identify that scaling error; the draft states this distinction accurately.
- C3 appropriately narrows my R8 read-guard recommendation where it conflicted with unchanged shared facets.
- C4 adopts native synchronization while correctly qualifying that not every ordinary ERC-20-then-native sequence necessarily fails.
- My genesis/donation concern remains an explicit secondary policy choice for the same requirements revision rather than being discarded.

Two material reservations remain.

## Concerns

### 1. The traceability table overstates adoption of Kimi R6’s common preflight ordering

Section 6 maps Kimi R6 to “reservation ledger and common preflight ordering.” C5 covers the ledger and fee checkpoints, but neither C5 nor C6 actually states the required operation sequence. Q2 discusses the projected domain and work limit without specifying when preflight occurs.

That omission matters: compounding before validating the complete plan can deploy incumbent inventory or change pool state before discovering that the subsequent operation exceeds the admitted quote domain.

The final resolution should carry forward the explicit sequence from my original:

`validate → guard → isolate/reserve input → preflight complete plan → compound → execute → settle reservations → synchronize shared reserves → unlock`

It should apply consistently to paired, SE, SY, native, and wrapped operations, with native value received on entry reserved and excluded from the pre-operation book. Q2’s requested clarification for standalone compound and all money paths does not fully replace this requirement.

### 2. C5 both recommends and reserves the all-fees snapshot policy, while Q1 frames attribution primarily as an entry issue

C5 first recommends including fees earned through completion of mandatory compounding exactly once. It then says Grok’s exclusion proposal disagrees with that intent and that the disagreement belongs to Q1 without quietly choosing a branch. Those statements need a clearer disposition.

Additionally, C5 correctly discusses partial-removal receipts and the danger of giving a partial exiter all whole-position fees, but Q1 is titled and framed around **entry** attribution. The owner-facing questions therefore do not clearly cover the corresponding exit-fee policy.

The final resolution should either:

- label the all-fees snapshot as a proposed default subject to an explicit owner decision covering both entry and exit attribution; or
- leave it expressly unresolved rather than recommending it as though settled.

In either case, retain the requirement for exact fee checkpoints and prevention of duplicate or whole-position fee allocation to a partial exiter. This is a clarity correction, not a request for another advisory round.

## What was not adopted from others

Based only on the draft’s account of other members’ recommendations:

- Not adopting Grok’s private-inventory candidate as a validated final formula is appropriate. The draft preserves it as a useful candidate while identifying the remaining pricing, fee, and rounding questions.
- Not adopting MiniMax’s `deployed_i - idleBefore_i` formula is also appropriate for the stated reasons: possible negative subtraction, failure to trace swap-converted ownership, and unresolved fee attribution.
- The refusal to replace exact parity with an unspecified conservative preview guarantee is sound; no concrete bound or proof was supplied.
- The rejections of the inherited-interface-ID argument, alleged baseline refund-release defect, mandatory full SY redeem override, terminal-residue forfeiture, blanket wrapped-native donation rejection, universal sequential-`mulDiv` guarantee, and claimed 18-decimal baseline deviation are all explained rather than silently omitted. I have no basis within this restricted review to require their adoption.
- Rejecting Grok’s inference that no dead shares implies blanket owner acceptance of donation risk is consistent with my original position.
- Grok’s blanket compound-swap-fee exclusion is the one non-adopted proposal whose handling needs the clarification described in Concern 2; the disagreement itself is preserved fairly.

I do not identify any other material recommendation from another member whose non-adoption is clearly erroneous from the frozen draft alone.

## Limits

- I did not reopen the PRD, baseline sources, peer originals, repository documentation, or external evidence. Assessments of other members’ positions are limited to the coordinator’s characterizations in this draft.
- I checked only arithmetic already present in the draft, principally C1’s raw-unit example.
- This is advisory requirements feedback, not runtime verification, economic proof, or security certification.
- My original remains the independent initial-pass record; this feedback neither replaces nor expands it into a new assessment.
- No additional review round is requested.
