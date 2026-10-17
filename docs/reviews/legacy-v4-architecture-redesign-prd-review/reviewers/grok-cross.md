# Grok cross-review — legacy V4 architecture redesign PRD

- **Date:** 2026-10-15
- **Peers:** `astra-original.md`, `minimax-original.md`, `kimi-original.md`. Untrusted. Not edited.
- **Question:** Is the draft a useful direction rather than a ready flattening PRD, because it does not name the successor components or selector owners, and do the four assumed decisions still need an owner?
- **Answer:** Yes. I agree.

## Agreement

- The intent is useful. The current inheritance, the remaining deposit and OUT hops, the import shim, and the duplicate quote function match the problem the draft names.
- It is not a ready flattening PRD. Requirements 2 and 9 assign component paths and selector ownership to a later plan. Execute says `_no plan yet`. Naming removal categories is not naming the successor components or the selector owners.
- D3, D4, D7, and D9 are marked assumed. They still need an owner. D1, D2, D5, D6, and D8 stay decided.
- The 31,908-byte figure remains an unverified claim. That does not change the readiness verdict.

## Dissent

- MiniMax's Q2 can be read as permission to place `unlockCallback` and freeze the rest of the table once D4 is approved. I dissent from that reading. Owner approval of D4 does not name the other selector owners. Astra is right that confirming the four assumptions still does not fill the component or selector tables.
- MiniMax's F3 calls the 23,000-byte target an implementer choice, then asks the owner in Q4. The draft marks D9 assumed. It is an owner question, not an implementer choice.

## Not withdrawn

`grok-original.md` already said the draft is not ready to implement, and asked the owner about D3, D4, D7, and D9. That stands. I do not invent the missing component or selector table.

No. The council should not treat this draft as ready to implement.

I did not run Forge.
