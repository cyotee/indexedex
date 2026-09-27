# MiniMax M3 — combined cross-review (preserves original)

Three peer originals read: Astra (60 lines), Grok (109), Kimi (80). My original (`…-minimax-original.md`) preserved. All peer reports are attributed evidence, not authority.

**Verification points requested:**
1. D61 + alignment line 9 supersession of D9
2. Universal PRD version (v0.2 stale vs v0.5 current)
3. Owner-policy vs engineering distinctions
4. Batch cadence dependence of `floor(S0*n/200)`
5. Unavailable-history marker/entitlement effects
6. Synthetic TWAP consumers
7. Retained-token incentive treatment
8. Extra approval scope

## A. Verified against current source

**D61 + alignment line 9 vs D9.** Verified. `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md:42` (D9) makes Uni V4 reserve hooks owner-only add/remove LP with the DETF as owner; `:101` (D61) introduces `ownerOnlyLiquidity` deploy-time config — `true` keeps D9, `false` permits public deposits/redemption; in both modes the DETF stays hook owner and public swaps stay available. Alignment line 9: "D32–D66 and §24 supersede conflicting D1–D31 text." **Resolution:** D61 modulates D9 in the planned refactor scope; for NetNet (PRD R32 public shared HLP), `ownerOnlyLiquidity = false` is the right deploy config. Encapsulation still reconciles D61 + R32 — the underlying V4 pool's `addLiquidity`/`removeLiquidity` stay owner-only at the hook level; public access is via the hook-mediated LP ERC-20 surface. **Kimi §3 line 43 is correct** that §2.1 of NetNet PRD does not enumerate this D9/D61 departure; the editorial fix is to record the D61 config selection in §2.1, not a new owner decision. **Astra line 52** ("public LP rights remain selected; do not import owner-only restrictions") and **Grok line 84** ("D9 owner-only HLP (public HLP remains selected R32)") both agree; **no new approval needed.**

**Universal PRD version.** Current is **v0.5** (313 lines, `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md:7`); **Kimi line 5 reads v0.2** (stale). Even v0.5 still contains stale "compounded" references to NetNet at lines 11, 19, 164, 281, and D08 at line 298 — these contradict NetNet v0.18 V18-4 single catch-up. **Astra §2 line 31** correctly identifies these as stale and correctly warns against importing Universal's cold-window skip (line 178), fee/creator internal-share issuance, and zero-share donation allocation into NetNet (Universal-specific choices per its own D09/D12/D13 and §3.3 line 178).

**Catch-up batch cadence dependence.** **Astra §3 Q1 line 37 claims a residual compounding under settlement cadence:** "two epochs batched from 1,000 mint 10; separately settling each epoch mints 5 then 5.025, totaling 10.025 before rounding." **Arithmetic verification** with `pendingMint = floor(S0 * n / 200)`:
- Batched: floor(1000·2/200) = 10. ✓
- Sequential step 1: floor(1000·1/200) = 5; mint 5; S0→1005. Step 2: floor(1005·1/200) = floor(5.025) = **5** (floor is integer division); mint 5; S0→1010. Total = **10**, not 10.025.

**Astra's "10.025 before rounding" is an arithmetic error** (treating 5.025 as unrounded when the formula floors at each step). Under the working interpretation, batched and sequential settlement are invariant at 10 minted. **No residual compounding across settlement cadence.** This does not foreclose the underlying question — it shows that the working interpretation `floor(S0*n/200)` is itself cadence-invariant. The owner is still entitled to confirm or replace that interpretation per PRD V18-4 line 71.

## B. Agreements across all four originals

1. **v0.18 controlling banner (PRD:18–83) supersedes body contradictions** at R13/R30/R52/R53, §9.1/§9.2/§10.4/§13, A11/A40/A43/A44, O05/O08, and §2.1 O01 framing (Astra §1, Grok §"Quality", Kimi §3, mine §2).
2. **Three assistant-inferred items must not be treated as owner-chosen** (mine §1, Kimi §2, Grok §"Human choices vs assistant inference", Astra §3):
   - `floor(S0*n/200)` linear-catch-up equation (V18-4:71 explicit).
   - TWAP oracle failure policy (V18-2:41 explicit).
   - Same-token incentive classification (V18-3:47–49 explicit).
3. **Stale companions** must be updated before planning: matrix `M:3,49,54,85,88,104`, `REQUIREMENTS_QUESTIONS.md:7,28`, Universal PRD v0.5 `U:11,19,164,281,298` (Astra §1, Grok §"Quality", Kimi §4, mine §3).
4. **Custom-family approval (V18-1) closes O01** but does not authorize execution; engineering feasibility, conservation, note liveness, etc. remain (all four).
5. **Do-not-reopen list** is consistent: family approval, 3,600 s arithmetic, two-series separation, existing-hook retrofit separate, generalized feeTo with retained yield token, single catch-up rate/gate/marker (Grok §"Do not reopen", Kimi §6, mine §"Confirmatory").
6. **Engineering gates (not owner questions)**: Weighted multi-reserve conservation; V2 SE full parity; §12.3 note-array liveness; zero-interest bootstrap; singleton-salt enforcement; bond min-duration vs next-epoch; callback authority (Astra §4, Grok §"Engineering / spec gates", Kimi §5, mine §4).
7. **D9/R32 encapsulation** via D61 deploy-time `ownerOnlyLiquidity = false` (Kimi §3 line 43; agrees with my prior cross-review).

## C. Corrections / dissent with attribution

| # | Claim | Source | Verification |
|---|---|---|---|
| C1 | "10.025 before rounding" residual compounding under cadence | Astra §3 Q1 line 37 | **Arithmetic error.** `floor(1005/200) = 5`, not 5.025. Both batched and sequential yield 10. Cadence-invariant under the working interpretation. Underlying owner-confirmation question still stands. |
| C2 | "U v0.2 states NetNet selects 0.5% compounded" | Kimi §1 line 5, §4 line 49 | **Version mismatch.** Current U is **v0.5** (`UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md:7`). v0.5 still contains stale NetNet "compounded" assertions (lines 11, 19, 164, 281, 298). Companions are stale at v0.5 also. |
| C3 | §2.1 "never listed D9 against public HLP" → §2.1 should enumerate | Kimi §3 line 43 | **Correct and editorially warranted.** D61 (alignment line 101) and the controlled-refactor supersession (alignment line 9) supersede D9 once `ownerOnlyLiquidity = false` is selected at deploy. Editorial fix, not new owner question. |
| C4 | "Earlier assistant suggestions to skip expansion while allowing claims were not explicit owner decisions" → oracle failure policy is owner question | All four | **Agreed.** Engineering must present alternatives (skip-and-advance marker, revert, other); owner picks. Universal §3.3:178 is Universal-specific. |
| C5 | Synthetic TWAP consumer mapping | All four | **Engineering deliverable.** PRD V18-2:41 explicitly: "does not by itself specify which consumers replace instantaneous synthetic-price reads." Engineering supplies a consumer table; owner decides only if the chosen mapping changes entitlements. |
| C6 | Same-token incentive classification | All four | **Owner question, but conservative default is "do not silently forward as feeTo and do not silently relabel as accrued YT interest"** (V18-3:49). Engineering proposal first; owner only if entitlements change. |

## D. Owner-policy vs engineering classification (per task instruction)

**Owner-policy questions (require human decisions, cannot be defaulted by engineering without changing entitlements or scope):**

1. **Catch-up equation confirmation** — `floor(S0*n/200)` or alternative. Cadence-invariant under working interpretation (C1). V18-4:71 explicit ask. **Necessary for frozen spec.**
2. **Oracle failure policy** — must owner select to bind entitlements (skip-and-advance, revert, etc.). V18-2:41 explicit.
3. **Same-token incentive classification when market emits the retained yield token** — must owner select because forwarding vs retaining changes fee/inventory entitlements. V18-3:49 explicit.

**Engineering deliverables (engineering proposes, owner approves only if entitlements change):**

- TWAP standard interface selectors, units, cumulative observation storage, same-block / boundary / quiet-period rules (no entitlement change).
- Synthetic TWAP consumer map (initial empty; engineering proposes additions only if economic equivalence to instantaneous quote is preserved per V18-2:41).
- Linear-catch-up safety analysis (overflow, horizon, marker atomicity) per V18-4:73.
- Reward provenance ledger (force-claims, historical-series claims, donation vs interest classification) per V18-3:49–51.
- §2.1 enumeration of the D61/D9 departure (Kimi C3; no entitlement change).

**Does scope need extra approval?** No. V18-1 (custom-family approval) explicitly covers "the described family-specific behavior" including R32 public shared HLP via D61 deploy config. **No new approval required for D9/D61 reconciliation** (C3). Existing-hook TWAP retrofit is already separately scoped per V18-2:35. Universal PRD's stale NetNet assertions are documentation drift, not a new approval trigger.

## E. Minimal human checkpoint (3 owner questions)

1. **Catch-up equation:** confirm `pendingMint = floor(S0 * n / 200)` or specify replacement (V18-4:71).
2. **TWAP oracle failure policy:** select from engineer-presented alternatives (V18-2:41). Default candidate: skip-and-advance-marker mirroring Universal §3.3:178, but explicitly not auto-selected.
3. **Same-token incentive classification:** when retained yield token is also emitted as incentive, classify as feeTo-routed / interest-retained / split / other (V18-3:49).

**Confirmatory (close, do not ask):** O01 closed by V18-1; D9/D61 departure enumerated in §2.1 (Kimi C3, engineering fix); empty-target revert-only (PRD §11.4:644); no additional contraction eligibility (PRD §7.5:407); DETF synthetic TWAP consumer set initially empty (engineering supplies additions only if entitlements unchanged).

**Non-owner / engineering gates unchanged:** Weighted conservation; V2 SE parity; §12.3 note liveness; zero-interest bootstrap; singleton-salt proof; bond min-duration compatibility; callback authority; external evidence pins (Pendle V7, NetNet `BOND_VEST` on 4663).

No council consensus asserted. No code, tests, deployment, signing, instruction edit, file deletion/move, browser, MCP, subagent delegation, or peer cross-review artifact read occurred. Originals preserved unchanged. Stopping here for the human moderator.
