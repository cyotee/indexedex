# Stage 09 — Docs: alignment / donation / agent-law pointers

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **09** |
| **This file is the sole implementation scope** | Markdown only. No Solidity |
| **Depends on** | None (can run after PRD v0.14). Do not claim code is shipped |
| **Blocks** | None |
| **Product law** | PRD “If accepted” table |

---

## Files to touch

| File | Action |
|------|--------|
| `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` | D20: burn `tokenOut` = resolved `burnRoutes` (pointer to I/O PRD). D25 remainder: Default basket; Custom = one hook pair + leftover swaps (Uni V4 unified package). §16.2 mint token list: instance-owned; family supplies defaults. **Do not** rewrite D29 for common NFT (N4 stays). |
| `contracts/vaults/detf/DETF_RESERVE_DONATION_PRD.md` | N6 seating → R12 + donateRoutes subset for packages that implement I/O tables. N7 seating vault = route row. **Leave N4/N11** as the common NFT law. Add a sentence: Uni V4 unified Bond NFT uses R12a (I/O PRD). |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` | User routes: rateAsset mint legal iff `{rateAsset, vault}` is a resolved mint/bond row and R14. Donate: common NFT still id 0; Uni V4 unified NFT is R12a. Pointer to I/O PRD + PROGRAM. |
| `docs/agent/AGENT_NAVIGATION_INDEX.md` | One row: I/O routing PRD + PROGRAM. |
| `Claude.md` / skill catalog | Only if those files already index DETF PRDs; add PROGRAM path. Do not paste full law. |

**Do not** edit family Uni V4 DETF PRDs except a one-line “superseded for new instances by unified DFPkg + I/O PRD §16” if those files still claim to own mint token lists.

---

## Tests

None. `forge` must not run.

---

## Acceptance

- [x] Alignment D20 / D25 remainder / §16.2 point here without deleting D9/D11/D12/D13/D16.
- [x] Common donation N4 not silently replaced. Uni V4 unified Bond NFT is R12a (N7).
- [x] Agent law token policy block untouched. User-routes donate + rateAsset mint point at I/O PRD.
