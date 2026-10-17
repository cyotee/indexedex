# Kimi K3 — cross-review: legacy V4 architecture-redesign draft PRD

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. My original is `kimi-original.md` in this directory. The three peer originals were read in full as untrusted model output. The redesign draft was not edited. Nothing else was edited.
- **Date:** 2026-10-14. I did not run Forge.

## Assigned ruling 1 — useful direction, not a ready flattening PRD, because successor components and selector owners are unnamed

**Agree, unanimously, and I keep my F1.** Astra-01, Grok-01, MiniMax F1, and my F1 are the same finding: the draft's decisive content is deferred to a later plan — the component inventory replacing `UniswapV4StandardExchangeCommon` (`:43` names responsibility categories, not files), the selector-to-facet table (`:99` freezes it only "in the implementation plan"), and the consolidation judgment calls (`:98` "measuring opportunities to consolidate smaller groups"). Grok's severity is High; Astra, MiniMax, and I used Medium. I hold Medium — this is a specification-completeness gap with no production defect attached, and the draft self-labels as pre-plan (`:167` "_no plan yet_") — but Grok's High is a defensible read of the same text; the split is recorded, not resolved.

Evidence I verified independently in my first pass and that peers corroborate: the duplicated `_quoteZapOutAmount` in `UniswapV4StandardExchangeInBase.sol:129` and `UniswapV4StandardExchangeOutBase.sol:89`; the five-line import-only shim at `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol`; the remaining self-preview at `UniswapV4StandardExchangeOutExecuteTarget.sol:51` and the OUT delegate's self-reads at `UniswapV4StandardExchangeOutExecutionDelegate.sol:88,94`; the current IN facet's combined selector ownership at `UniswapV4StandardExchangeInFacet.sol:25-29`. Astra's additional claim that `UniswapV4StandardExchangeOutBase.sol:22-24` inherits `InBase` was not re-verified by me; it is consistent with the duplicated quote implementation and I do not rely on it.

## Assigned ruling 2 — the four Assumed decisions still need an owner

**Agree, unanimously.** D3, D4, D7, and D9 are marked "Assumed" (`:157-163`) while requirements 4, 6, 9, and constraint `:147` write their content as mandatory outcomes. Astra-04, Grok's four owner questions, MiniMax's F3/Q1-Q4, and my F3 converge on the same single owner action: ratify or amend those four rows before the inventory is frozen. The decided rows (D1, D2, D5, D6, D8) are corroborated by recorded rulings and are not reopened by any pass; MiniMax's F4 mapping them to owner records matches what I have seen of those rulings.

## Evidence adopted from peers that strengthens my findings

- **Astra-02** (deletion and storage/shared-SY dispositions are conditional work items): verified against the draft — `:77` defers per-field Repo disposition to implementation, and `:62` defers the shared-SY consumer inventory. I adopt it as part of my F1's scope: the missing artifact is not only the component/selector table but the current-to-result disposition table.
- **Astra-03** (the "one accounting model" requirement never defines the persistent book that pretransfer credit reads): verified against the draft's deferral of the behavior-delta table (`:40`) and consistent with the recorded residual that legacy V4's stored-total-minus-deployed credit (`UniswapV4StandardExchangeCommon.sol:1256-1274` region) was kept without an authorized repair. Since the draft mandates accounting consolidation and corrections (requirement 5, D6), the missing stored-book definition is a genuine gap, not an optional one. I adopt it as a third sub-finding under F1/F3's umbrella; it does not change the verdict.
- **Grok's evidence check** for the 31,908-byte figure extends my F2: the number is also absent from `out/UniswapV4StandardExchangeInFacet.sol/UniswapV4StandardExchangeInFacet.json`. All four passes found no saved measurement. MiniMax's fix direction (attach a saved measurement or label the figure a claim) matches mine and Astra's.

## Corrections to peer text

None material. MiniMax's F2 mislabels nothing factual; Astra's unverified inheritance claim is flagged above; Grok's "Validation stopped at that gate" treatment matches mine (unrecorded runtime claim).

## Unresolved dissent

Only severity on the central deferral finding: Grok High; Astra, MiniMax, Kimi Medium. Same text, same fix direction. The readiness verdict itself is unanimous: **No** — the council should not treat the draft as ready to implement. Consensus is not proof, but here the agreement rests on independently re-read deferral sentences, not on shared conclusions.

I did not run Forge.
