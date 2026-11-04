# Coordinator resolution

Reviewed draft: pair-spec-fidelity-r1, coordinator/draft.md. SHA-256: 31c5cab73e3a62883c07a53f590255350a146617c67f5da8a348866562c99874.

Final: pair-spec-fidelity-final-r2, REMEDIATION_PRD.md. All four independent originals and all four advisory turns settled before finalization. The final revises the reviewed draft; it is not newly member-approved wording. Original responses, feedback, and draft remain unchanged.

## Advisory ledger

| Member concern | Disposition | Evidence/action |
| --- | --- | --- |
| Astra A1: zero-swap exits | Accepted | Re-read sources.md:472-503; F4 adds selected-leftover <= DUST and zero active-liquidity exits; zero swap does not preclude add. |
| Astra A2: transient terminology | Accepted | Re-read state declaration and _idle; F7 says operation-scoped reservation in ordinary _reservedNative state. No transient-opcode assertion. |
| Astra archive origin | Accepted | Archiving adds terminal newline; final does not attribute it to reader presentation. |
| Grok G1: unsigned callback encodings | Accepted with exact semantics | Re-read sources.md:550-575. F3/F5 preserve uint256(uint128(int128 delta)); negative values reinterpret at the same width. No demonstrated reachability or exploit. |
| Grok G2: fallback process note | Accepted | Final records both Grok and MiniMax reports of unavailable apply_patch and assigned-path fallbacks. |
| MiniMax R-C1: locator convention/F10 anchors | Accepted | Explicit bundle versus original numbering and an exact original-source anchor table, including F10 events/errors/ERC20/state/helper anchors. |
| MiniMax R-C2: interface warning | Accepted as caution only | Warning re-read at sources.md:838-842; original consequence alleging liability shortfall withdrawn. F3 retains actual delta distinction. Independent-design question remains unresolved, not a confirmed vulnerability. |
| MiniMax R-C3: removal delta components | Accepted with qualification | F5 states principal, fee and applicable hook delta composition under interface; no assertion that nonzero fees always remain after prior compound. |
| MiniMax R-C4: uint128 observation | Accepted with corrected type semantics | int128 to uint128 is same-width signed/unsigned conversion, not a demonstrated magnitude above 2^128-1. Negative-value reinterpretation is observed; no reachable failure is proved. |
| MiniMax R-C5: 28/28 rendering identity | Accepted and independently checked | Coordinator parsed all sections, compared each to JSON content; 28 identical, no missing/extra paths. |
| MiniMax R-C6: reconcile and compound cross-reference | Accepted | F6 contrasts report lines 157/238 with no booked-U source ledger and refers to F4 ordinary-action compounding swaps. |
| MiniMax R-C7: archive original F20 | Superseded in this resolution | No re-serialization/loss. Strip one added newline to recover fetched body/digest exactly. Original preserved, not silently edited. |
| MiniMax R-C8: original F11 overreach | Superseded in this resolution | Member expressly withdrew liability/exploit consequence. Retain only documentation caution and source-accounting distinction. |
| MiniMax R-C9: original callback safety assertion | Superseded in this resolution | Only explicit gate is manager equality. Sufficiency and full safety not established without absent manager/context. |
| MiniMax R-C10: original FoT-tolerant language | Superseded in this resolution | Only measured received balance is observed; paired quote is not recomputed. No general safety guarantee. |
| MiniMax R-C11: intent classification | Accepted without overgeneralization | Final distinguishes honest alternative-proposal labels, direct contradictions for source-equivalent use, and omissions. Not every alternative sentence is claimed to contradict source. |
| Kimi: support, no changes | Preserved | All original topics map to F1-F10 and coverage; no additional correction requested. |

No advisory concern was ignored or treated as a veto. No follow-up advisory round was launched.

## Original finding coverage

| Member original | Final disposition |
| --- | --- |
| Astra F01-F12 | Target mismatch in verdict; F02 -> F1/F2; F03 -> F3; F04 -> F5; F05 -> F6; F06 -> F6/F7; F07/F08 -> F8; F09 -> F4; F10 -> F9; F11 -> F10; F12 -> dependency/provenance limitations. |
| Kimi F01-F12 | F01 -> F1; F02 -> F2; F03/F04 -> F3/F4; F05 -> F5; F06/F10 -> F8; F07 -> F6; F08 -> F7/F9; F09 -> F3/F10; F11/F12 -> F10 and coverage. |
| Grok original finding set | Target mismatch, mint, genesis, fees, redemption, zaps, range/owner, previews, idle, runtime factory/callback/native and API gaps -> F1-F10. Citation/dependency and independent-design gaps retained as qualifications. Hash concern withdrawn by member. |
| MiniMax F01-F10 | Verdict plus F1-F6/F8/F9 cover architecture, pricing, fees, exits, rate, zaps, factory, genesis, retention and protocol take. |
| MiniMax F11-F20 | F11 superseded/caution; F12 -> F8; F13 -> F7; F14 -> F6; F15 -> F10; F16 -> F6 booked-U contrast; F17 -> F8 initializer; F18 -> F4-F6; F19 -> dependency evidence; F20 superseded integrity claim. |

MiniMax suggested reusing its B1-B11 numbering if the final has a numbered blocker list. The final instead groups requirements by F1-F10 and the three separate handoff questions; it does not adopt B10 as a proved vulnerability or B11 as an unresolved integrity defect. All substantive correction directions remain traceable above.

## Dissent and limits

No member dissents from non-equivalence or rejection of the requested source-equivalent handoff. Alternative-design usefulness differs in emphasis: some describe a usable outline; others emphasize unresolved implementation choices. Final certifies neither completeness nor safety of that alternative.

Static comparison only; no deployed-state/bytecode/runtime verification, project tests, legal determination or approved clean-room process. Missing external implementations and provenance separation remain explicit limits rather than guessed specifications. This audit answers the confirmation request negatively; it does not rewrite the input specification or authorize implementation.

