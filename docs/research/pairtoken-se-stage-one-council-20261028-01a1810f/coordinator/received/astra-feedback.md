# Astra advisory: coordinator archival receipt

Verbatim final response from Native task `st_01a183c1`, advisory epoch 1, on frozen draft r1.

---

## Identity

Astra, independent advisory reviewer. Assigned route: `chatgpt-subscription/gpt-6-astra:high`, unchanged. This statement is not independent runtime attestation.

## Draft under review

Revision: `pairtoken-se-stage-one-council-20261028-01a1810f-draft-r1`

Path: `/Users/cyotee/Projects/indexedex/docs/research/pairtoken-se-stage-one-council-20261028-01a1810f/coordinator/draft.md`

I read the complete frozen draft. No hash was supplied or required.

## Disposition

**Support-with-reservations.**

The synthesis fairly represents my principal conclusions: correct SY units, resolve entrant attribution before coding, preserve mandatory compounding while qualifying exit availability, reconcile read guards with unchanged facets, and specify fee checkpoints and native synchronization.

It also handles substantive disagreements appropriately: candidate formulas remain unapproved, alternative compounding behavior is identified as a departure from confirmed scope, and unsupported technical claims are not converted into consensus.

My reservations concern missing behavioral requirements behind several traceability entries and one newly proposed policy whose trade-off should be explicit.

## Concerns

### 1. Preview parity and preflight validity need substantive wording

Section 6 says Astra R9 is addressed by C6/Q2 and that parity excludes unavailable caller/recipient facts. C6 and Q2 do not actually state that contract. My original also required revalidation after external interactions invalidate preflight assumptions; that requirement is absent.

This matters because “exact economic parity” can otherwise be interpreted as either an impossible prediction of receiver behavior or permission to execute a stale plan.

**Requested addition to C6 or Q2:**

> Preview parity covers economic outputs and economic-domain failures from the same initial pool/book/configuration state. It does not establish unavailable caller authorization, allowances, staged-credit availability, recipient acceptance, attached value, or deadline validity. Execution validates those conditions separately, settles actual manager deltas, and revalidates economic preflight assumptions invalidated by external token or wrapper interactions.

This preserves exact economic previews without claiming they simulate arbitrary external behavior.

### 2. Several traceability entries claim fuller adoption than the recommendation text provides

The following are present only as abbreviated traceability labels, or are missing from their cited destination:

- **Astra R7:** C6 does not state the one-sided accepted-input rule. My recommendation was to preserve consumption of the complete maximum of the supported leg and zero of the other, rather than silently substituting ceiling-trimmed acceptance.
- **Astra R10:** The secondary-policy table discusses zero-output burns, but not the clean-empty-instance compound no-op. The intended requirement is to avoid poking an empty position or adopting unsolicited balances when `S = L = B0 = B1 = 0`.
- **Astra R12:** C6/section 5 do not substantively specify the complete selector/initialization manifest, final-proxy absence checks for administrative and excluded surfaces, or package-binding deployment identity.

These need not become additional lead owner questions. Either insert their concrete requirements or label them as retained follow-up details rather than implying that C6 already contains them.

For R12, a compact addition would suffice:

> Require a final selector/interface ownership and initialization manifest; verify the absence of operational ownership, upgrade, rescue, and excluded integration surfaces on the deployed proxy; cover package bindings as well as instance arguments in deployment-identity controls.

### 3. Blocking donations while disabled is a new coordinator recommendation

The secondary-policy table recommends allowing standalone compound but blocking donations while disabled. That was not my recommendation, and it does not follow directly from disabling inbound issuance: donation creates no shares.

The draft correctly labels the policy unchosen, so this is not a misrepresentation of owner authority. However, its operational trade-off is missing. Blocking donations restricts further funding, but also removes a possible way to supply inventory useful to maintenance. This does **not** establish that donations guarantee recovery or exit availability.

**Requested qualification:**

> Blocking donation is an additional policy proposal, distinct from disabling issuance. Explain whether disabling is intended to stop new capital contributions or only new share issuance, and acknowledge the maintenance-funding trade-off. Do not assume donation or standalone compound guarantees exit recovery.

### 4. Preserve the limits of “verified technical corrections”

C1’s arithmetic correction and the identified native settlement mechanism are distinct from economic decisions about fee attribution and execution-domain restrictions.

C5 already records the additional checkpoint as a deliberate deviation for owner review, and Q1 preserves the fee-snapshot disagreement. Keep those qualifications prominent in the final report. The section heading should not imply that a complete fee-allocation algorithm, bounded projector, or liveness guarantee has been verified.

No new round is needed to resolve this presentation issue.

## What was not adopted from others

I read no peer originals during this pass. The following positions concern only alternatives described in the frozen synthesis:

- I do not adopt gross deployment or `deployed_i - idleBefore_i` as a complete entrant-attribution solution.
- I do not adopt excluding all compound-swap fees from the snapshot as a blanket baseline-fidelity rule.
- I do not adopt collect-only exit fallback as unchanged mandatory baseline compounding.
- I do not adopt conservative previews without defined bounds and correctness evidence.
- I do not adopt guarded shared reserve selectors while simultaneously requiring their unchanged canonical facets.
- I do not adopt a genesis minimum as an approved or proven cure for donation/rounding risk.

C2’s sorted registry-identity recommendation was not established in my original. The draft presents it as coordinator-checked source evidence and preserves PoolKey ordering for accounting. I have no draft-internal objection, but I have not independently verified its cited registry implementation in this advisory pass.

## Limits

I read only the specified frozen draft. I did not reopen the PRD, baseline sources, my original file, peers, memory, or other documents. Comparison with my original relies on the original response already present in this conversation.

No research, commands, tests, builds, delegation, edits, or writes were performed. Participation metadata, new source checks, and other members’ original positions remain coordinator-reported evidence.

This feedback does not replace my original response.
