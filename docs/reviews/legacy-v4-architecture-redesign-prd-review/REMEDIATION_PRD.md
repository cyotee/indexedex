> **Superseded — legacy family deleted (2026-10-15).** Retained as historical evidence only. Do not execute this plan or restore its implementation. See the [removal report](../legacy-v4-removal/EXECUTION_REPORT.md).

# Remediation PRD — legacy V4 redesign draft is not ready to implement

- **Status:** WITHDRAWN, 2026-10-15. The owner is deleting `contracts/protocols/dexes/uniswap/v4`. Do not implement the redesign.
- **Date:** 2026-10-15
- **Review target:** `contracts/protocols/dexes/uniswap/v4/legacy-v4-standard-exchange-architecture-redesign.md`
- **Question:** Is that draft a good PRD for simplifying and flattening the legacy Uniswap V4 Standard Exchange vault?
- **Astra participation:** Substantive first pass and substantive cross-review. Session `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored. No resubmission.
- **Other reviewers:** Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax M3 `ses_ec41255ceffeVhrySLQe8hwwMC`. Kimi K3 is the labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Execution evidence:** No Forge run. The draft's 31,908-byte figure was not found in a saved measurement. It remains a claim.

Writing this review does not authorize editing the redesign draft, production code, or tests.

## Required outcome

The 2026-10-15 owner ruling asked the council to name the flattened design, not to wait on facet size. The rewritten PRD is `docs/reviews/legacy-v4-architecture-redesign-prd-review/REDESIGN_PRD.md`. A write to the original file under `contracts/` was rejected by the review-council guard. Do not implement this design in this session. A later implementation plan sequences that named design. It does not choose another one.

## Answer

The intent is sound. The draft correctly says the family is too layered: a broad common base, duplicate quote cores, delegate hops, and self-calls to public previews. It also correctly says fewer files do not by themselves make the facet smaller, and that a hop must not be put back to hide a size miss.

It is not a good implementation PRD for flattening. It describes the kind of design it wants and then tells a later plan to invent the actual design. An implementer handed only this document would still have to choose the files, the facet split, and what is deleted.

## R1 — The flattened design is not named

- **Severity:** Medium. Grok rated this High because it blocks implementation. Astra, MiniMax, and Kimi rated Medium because it is a missing specification, not a shown production loss. This draft uses Medium.
- **Section:** Requirements 2 and 9, lines 42-47 and 96-104. Execute says no plan yet, line 167.
- **Intended behavior:** A flattening PRD names the successor components, who owns each selector, and what is deleted.
- **Broken requirement or invariant:** Line 43 names responsibility categories, not files. Line 47 assigns component paths and selector ownership to a future plan. Line 99 freezes the selector table only in that plan. Line 98 still says to measure opportunities to consolidate groups.
- **Acceptance criteria:**
  - The revised PRD, or a reviewed appendix it incorporates, lists each successor component, its path, its responsibility, and its consumers.
  - It lists every installed selector and exactly one facet owner.
  - It lists what is kept, moved, and deleted, including the current common base, the two execution delegates, and the shared SY shim.
  - The implementation plan sequences that selected design. It does not choose the design.
- **Non-goals:** Do not invent the component list in this review. Do not treat moving `unlockCallback` alone as proof the facet will fit.

## R2 — Four decisions are still assumed

- **Severity:** Medium for D3, D4, and D7. Low for the advisory size target in D9.
- **Section:** Decisions table, lines 157-163.
- **Intended behavior:** A required outcome is either decided by the owner or not required.
- **Broken requirement or invariant:** D3, D4, D7, and D9 are marked Assumed, while later requirements treat shim removal, a dedicated callback facet, fresh-instance storage cleanup, and the 23,000-byte target as required.
- **Acceptance criteria:** The owner ratifies or amends each row. A ratified row is marked Decided. An amended row replaces the requirement that depended on the assumption.
- **Non-goals:** Do not reopen D1, D2, D5, D6, or D8. Those are already marked Decided.

### Owner questions

1. **D3.** Do you approve removing the shared SY import shim and moving shared errors out of the compatibility aggregate, with other families limited to mechanical import changes?
2. **D4.** Do you approve one dedicated legacy V4 callback facet, and no replacement execution delegate, as a fixed constraint? This does not by itself name the other facet owners.
3. **D7.** Do you approve a fresh-package storage cleanup with no promise that existing deployed instances can use the new layout?
4. **D9.** Do you approve 23,000 bytes as an advisory target per facet? A miss below 24,576 bytes is recorded, not a failure. The hard limit stays 24,576 bytes.

## R3 — Accounting and deletion details are also deferred

- **Severity:** Medium
- **Section:** Requirements 4, 5, 6, and 7, especially lines 40, 62, 70, and 77.
- **Intended behavior:** Structural flattening does not leave the implementer to invent the persisted book, the pretransfer credit rule, or which Repo fields die.
- **Broken requirement or invariant:** The draft says complete-book accounting and "booked reserves never become caller credit," then defers the behavior-delta table and the per-field disposition. It also defers the shared-SY consumer inventory and the unused-helper inventory.
- **Acceptance criteria:**
  - The revision defines the stored book used for valuation and the stored amount used for pretransfer credit, and how they differ.
  - It names each family Repo field that is removed, and each field that stays, with its remaining reader.
  - It names the shared SY files that move or disappear, and the consumers that only change imports.
- **Non-goals:** Do not treat this as a new accounting exploit. Do not redesign other families.

## R4 — The size number is unverified

- **Severity:** Low
- **Section:** Summary, lines 14-16.
- **Intended behavior:** A size claim used to justify a redesign is either attached to a saved measurement or labeled as unverified.
- **Broken requirement or invariant:** The draft says the IN facet compiled to 31,908 bytes. This council did not find that figure in a saved build log. The draft itself says the source-map byte counts are not removable-byte budgets.
- **Acceptance criteria:** Attach the measurement, with compiler settings and the artifact identity, or label the number as an unverified report. The hard 24,576-byte limit does not depend on proving this one figure.
- **Non-goals:** Do not rerun Forge in this review. Do not treat the missing log as proof the facet fits.

## What is already good

The prohibitions are worth keeping: no self-call trampoline, no replacement delegate hop, no `via_ir` to evade the size gate, no mock facet as the test subject, and no claim that fewer source files prove a smaller runtime. The holder rules and the separate REQ-V4-02 disable correction are also stated clearly enough to keep.

## Dissent

- Grok rated the missing architecture High. The other three rated it Medium. This draft uses Medium.
- Approving D4 does not name the other selector owners. Grok's cross-review rejected reading that approval as permission to start the facet split.

## Questions round, 2026-10-15

All four reviewers, including cross-review, found no owner question on `REDESIGN_PRD.md`. D1 through D9 are decided. The component paths, selector owners, and deletion list are named. A later plan may sequence that design. It does not choose another one.

Grok dissented from MiniMax listing extra disable-check sites. The rewritten PRD adds that check only on SY `deposit` and `redeem`. Existing checks on other routes stay. That is not a new owner question.

## Non-goals

No code change. No implementation plan in this questions round. No replacement architecture. No live upgrade.
