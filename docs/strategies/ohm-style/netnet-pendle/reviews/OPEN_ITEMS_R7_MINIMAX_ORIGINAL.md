# MiniMax M3 — OPEN_ITEMS_R7 first pass

- Identity: `minimax/MiniMax-M3` (council-minimax, independent). Provider attestation: not claimed.
- Source: PRD v0.16 (`NETNET_PENDLE_DETF_PRD.md`), `NETNET_PENDLE_OPERATION_MATRIX.md`, `REQUIREMENTS_QUESTIONS.md`, `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md` (v0.1, 2026-09-25), CLAUDE.md, current canonical skills. No peer artifacts read. No shell/tests/delegation.

## Three prioritized owner questions

### Q1. Compounded supply vs reward allocation semantics (U02)

Whether the realization path is (a) **compounded token-supply projection followed by one final aggregate reward allocation**, or (b) **projected sequential allocation/index updates equivalent to settling each virtual epoch**. Both preserve R43 funded staking custody and role-recipient identities; the difference is gons/index rounding, dust treatment, fee/creator receipt participation, and gas profile of the final on-chain realization. **Why owner-visible:** recipients of fee/creator role-NFTs observe different intermediate display states; a single aggregate may keep existing display compatible, while sequential allocates may surface more dust.

### Q2. Price feedback policy inside the virtual-epoch sequence (U01)

Whether to (a) **recompute the synthetic price at each virtual supply `S_i`** (substitute `S_i` into the adapter, re-evaluate gate), or (b) **freeze the settlement snapshot price** while compounding only supply. Recomputing can shrink premium; later virtual epochs may become ineligible under the >1 NET/DETF gate (premium loss is structural, not a bug). Freezing P permits a geometric expression before integer rounding but is not equivalent to as-if-sequential realization. **Why owner-visible:** an eligible epoch now can become ineligible later under (a); display reads as “accrued” for several epochs then drops to zero under (b) is not possible (P fixed). Do not silently pick a method under the label “compounding.” No historical oracle snapshot/replay system is selected.

### Q3. 0.5% coefficient — basis and unit encoding still undefined

User clarified: 0.5% is **not** automatically flat or premium closure; it does not by itself fix basis or unit. Required owner choices:

- **Basis**: per `totalDetfSupply` (current Universal default), per circulating staked sDETF, per hook-LP supply, or per eligible-stake share. The PRD §3.2 math (`floor(Si * (Pi - W) / Pi)`) uses current supply. Switching basis changes recipient count and the gons/index delta at realization.
- **Unit**: annual-percentage-point (`expansionClosureRatePerYearWad` slot) applied via `floor(rate * EPOCH / YEAR)`, **or** per-processed-NET-epoch rate directly (no annual divisor). Custom family uses processed NET epochs (PRD §9), so the annual field is a convenience multiplier — owner must confirm whether 0.5% is **annual** or **per processed NET epoch**.
- **Catch-up compounding convention**: PRD v0.16 §1 confirms compounded pending supply; the basis × 0.5% × premium compounding is selected. Linear alternative is rejected. Owner must confirm that “0.5%” applies to the **final aggregate supply delta**, not the **per-epoch delta** (these are different values once compounded).

Provisional defensible defaults (PROPOSALS only, not owner-confirmed): **basis = current `totalDetfSupply` (Universal precedent)**, **unit = annual rate** (matches existing `expansionClosureRatePerYearWad` slot — no new field required), **coefficient literal = `0.005e18`** (0.5% WAD). This produces ~0.00137% per processed NET epoch at constant 10% premium — far smaller than 0.5% of supply naively. Owner must confirm the literal.

## Engineering proposals (not owner decisions; inside conditional plan)

- **U03 dust handling** (compounded-expansion PRD §6): per-virtual-epoch filtering vs final aggregate only. Recommendation: per-virtual-epoch dust suppression to keep compounded supply monotonic; remainder accrues to next epoch. Aggregate-only dust is simpler but skips permanently when consecutive dust epochs occur.
- **U04 display ABI** (compounded-expansion PRD §5): existing `balanceOf`/`totalSupply` keep stored semantics; add new getters (e.g., `previewBalanceOf`, `previewTotalSupply`) for projected values. Recommendation: keep stored-state selectors byte-compatible; surface projections only through explicitly-prefixed previews. No silent change to existing getters.
- **Empty successor / first-zero-interest paths**: totalSupply=0 mints zero under dust+supply guards (compounded-expansion PRD §3.2 and §3.1). Rollover to empty successor: empty target reverts by div-zero on Keep-YT split; full-book seed required before Keep-YT path. **No silent inventory classification;** documentation required that zero epochs do not mint and that bootstrap after rollover uses R51-style first-bond path on the successor.

## Authority gates before execution

The compounded-expansion PRD §7 acceptance table (T01–T14) and v0.16 PRD §1 amendment are conditional implementation-plan inputs, not implementation authorization. Authority gate remains: implementation/test plan separately authorized after **U01, U02, U04** resolved and **0.5% coefficient** explicitly defined.

## Doc reconciliation flagged (not re-asked)

- `REQUIREMENTS_QUESTIONS.md` rows Q4/Q5/Q7/Q10/Q12/Q13 may still cite older 0.5% wording; reconciled separately by moderator.
- `DETF_ALIGNMENT_PRD.md:977–1005` linear `perEpoch * epochs` semantics is now superseded for both Universal (separate PRD) and NetNet (this v0.16); reconciliation is editorial, not owner-level.
- Matrix rows 35–37 (expansion/sync) may still say “equation UNKNOWN”; recorded here, not re-asked.

## Saved
- `docs/strategies/ohm-style/netnet-pendle/reviews/OPEN_ITEMS_R7_MINIMAX_ORIGINAL.md`
- Original preserved. No peer artifacts read beyond PRD/matrix/tracker/compounded-expansion PRD/CLAUDE. No shell/tests/delegation.
