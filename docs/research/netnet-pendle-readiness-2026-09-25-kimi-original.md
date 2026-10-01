# Kimi K3 — Independent first-pass readiness review of NETNET_PENDLE_DETF_PRD.md v0.17

- **Date:** 2026-09-25 (environment date). **Author:** Kimi K3 (reported metadata: `kimi-code-plan-global/k3`, variant high; routing metadata, not provider attestation).
- **Scope:** quality, clarity, remaining open items and questions needed before an implementation plan. Research only; no code/tests/config changes; no peer artifact reading. Settled selections are not reopened.
- **Sources read directly:** `CLAUDE.md`; `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` (full, 883 lines); `NETNET_PENDLE_OPERATION_MATRIX.md` (full); `REQUIREMENTS_QUESTIONS.md` (full); `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md` v0.2 (partial); `docs/agent/INDEXEDEX_AGENT_LAW.md` (token-policy and expansion sections); `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` (D50/D52, §24.3.2). Spot-checked code citations below.

## 1. Verified source citations (facts)

| PRD claim | Verification (2026-09-25 local checkout) |
|---|---|
| E15/§10.3: `DETFFundedBondTarget.sol:93–125` receives calculated principal; `:143–188` reward/principal claim separation | Confirmed: `createFundedPosition` at lines 94–106 pulls/stakes given principal; `_claim` at 164–189 splits principal/reward debit |
| §10.3: `DETFFundedStakingMath.sol:96–116` releases principal linearly (incompatible with custom cliff) | Confirmed: `_claim` lines 104–106 compute `mulDiv(principal, elapsed, vestingDuration)` — linear vesting |
| §10.4 first-bond split `B=floor(U(1-p))`, `R=floor(Up)+floor(Gp)` | Confirmed in `DETFMintSplitLib.sol:37–52` (`_splitBond`) |
| E12: `_quoteMintGross` input adjustment `UniswapV4DetfCommon.sol:252–255` | Confirmed: lines 252–256, `Math.mulDiv(pairEq_, ONE_WAD + p_, ONE_WAD)` into `previewSwapExactIn` |
| §10.4 opening quote `Q(x)=floor(nativeToWad*1e9/P0)`, `creationOfPair` fallback | Confirmed: `UniswapV4DetfCommon.sol:259–264` |
| §4.3/E16: Weighted math imports Crane-vendored Balancer V3 `FixedPoint`/`WeightedMath` at lines 4–8 | Confirmed in `UniswapV4StandardExchangeWeightedBufferHookMath.sol:4–8`; domain guards (`MaxInRatio` etc.) at lines 19–42 |
| §8/E04: NET tax predicate `taxEnabled()`, `taxTotalBps()`, `isTaxedPair`, `isTaxExempt` | Confirmed: `lib/crane/.../net/src/NET.sol:53–56,133–134,180–191`; `INET.sol:32–47` |
| §2.1: D52 removes expansion catch-up caps | Confirmed: `DETF_ALIGNMENT_PRD.md` D52 and §24.3.2 (lines 985–997) — uncapped aggregate catch-up, no compounding of hypothetical historical receipts |

No citation checked was wrong. Not verified (missing evidence): Pendle-side citations (ActionAddRemoveLiqV3, InterestManagerYT, PendleYieldToken), NetNet `BondDepository.sol` vesting (2-day code vs 5-day prose discrepancy at PRD line 598), and any live Robinhood-chain state.

## 2. Consistency findings

1. **(Fact) Operation matrix is stale relative to v0.16/v0.17.** Matrix header (line 3) reconciles only to v0.15. Matrix line 85 ("expansion base, gate and catch-up calculation are not silently selected" / "supply basis, eligibility/stop rule and catch-up compounding remain UNKNOWN"), line 104 ("Proposed 0.5% expansion base/gate/catch-up mechanics … remain unresolved"), and row 36's UNKNOWN cells are superseded by PRD R52–R54/§9.1, which settle rate (0.5% of compounded total supply per eligible epoch), base (total supply), gate (current hook TWAP strictly > 1 NET/DETF), catch-up (one current TWAP qualifies all missed epochs) and distribution (direct mint to sNET-DETF, balance-derived). Planning should reconcile the matrix before deriving operation-level specs from it. Low risk: the PRD is controlling.
2. **(Fact) v0.17 is internally coherent on expansion.** PRD lines 26, 375–393, R52–R54, §9.3, A40–A44 all agree; the arithmetic illustration (1,000 → 1,015.075125 over 3 epochs) is correct (1000×1.005³).
3. **(Fact) Compounding across unbounded missed epochs needs an O(1)/O(log n) evaluation** (fixed-point power), since D52-style uncapped catch-up is retained (PRD line 389: "do not … introduce a missed-epoch cap"). PRD correctly assigns "deterministic native-unit precision … and an efficient bounded-complexity method" to engineering (line 389). A gas-driven per-transaction epoch limit would risk conflicting with the no-cap rule; worth one explicit clarification (see §5).
4. **(Fact) Existing staking already uses internal shares ("gons")** (`DETFFundedBondTarget.sol:108–125` reads `staking_.gonsOf`), and the Universal remediation PRD v0.2 selects the same balance-derived model; §10.2 is consistent with owner direction for both families. Rounding/first-depositor/zero-share rules are flagged as undefined (line 451) — appropriately deferred.
5. **(Fact) The 1,000 NET/DETF opening vs 1 NET/DETF ongoing peg is an explicit, distinct selection** (line 513). Consequence (inference, not stated): at launch the price is ~1000× above the contraction threshold, so below-peg contraction is unreachable and the TWAP>1 expansion gate is trivially satisfied for a long time; expansion (0.5%/epoch, compounding, minted only to sNET-DETF) dilutes liquid DETF holders relative to stakers. This is coherent Olympus-style design and arguably settled, but the PRD never states the intended price-decay path; one owner confirmation would remove ambiguity (§5, Q2).
6. **(Fact) Contraction incentive `p` and bond split `p` are the same oracle parameter used in two roles**; the PRD distinguishes them (lines 499, 297). Consistent with the verified reference code (`_seigniorageIncentiveWad`, `UniswapV4DetfCommon.sol:112–116`, uses `address(this)` — matching R36's lookup identity).
7. **(Observation) Acceptance criteria A01–A45 map almost 1:1 to R01–R55 and O-items.** Redundancy between A24/A26/A28 is harmless for a test matrix. No acceptance criterion contradicts a settled requirement.

## 3. Area assessments

- **Custody/accounting:** Strong. Hook-LP vs DETF separation, component-wise proportional exit formulas, accrued-value-follows-LP, once-counted interest, fee-owned-PENDLE exclusion, and the staked-reinvestment participant debit (100→60+replacement example, lines 457–459) are unambiguous. The balance-derived rebasing model (B, u/U) is specified to the level needed for planning; remaining rounding rules are planning detail.
- **Expansion/TWAP:** Economics settled (owner decision). Open engineering: TWAP window, observation/update cadence, stale/insufficient-history and invalid-TWAP failure semantics (R53, line 391 — correctly not equating invalid with below-peg), units/decimals for "1 NET per DETF" (§7.5), and bounded compounding evaluation. §9.2 line 397 says "do not choose an unapproved duration" — so the TWAP window is an **owner parameter decision still outstanding** (§5, Q3).
- **Bootstrap:** First-bond lifecycle (G/U/B/R, full-book join, atomic activation) is specified and source-verified. Remaining: custom asset/rate mapping, zero-interest first-book initialization, TWAP-history precondition vs first-bond activation ordering (line 513). Engineering/planning.
- **Maturity/rollover:** Atomicity, factory-first validation, new-SY permission, historical-claim preservation are settled; §11.3 enumerates the remaining execution specification honestly. Empty-target Keep-YT division-by-zero reverts atomically (line 577) — correct handling.
- **Interfaces:** ERC-4626/SY/SE branch table (§7.4) is clear; owner waived strict-conformance certification (line 334) while keeping truthful-behavior obligations. Remaining: rounding-safe exact-output inverse (engineering), V2 SE full surface inventory (A21, engineering gate), and the SE variant exposure list.
- **External dependencies:** Vault Fee Oracle reuse with correct per-proxy lookup keys; canonical V2 pair address given with a verify-before-implement gate (line 344); Pendle V7 claim mechanics grounded in local code with a deployment-equivalence caveat (line 535); NetNet vesting discrepancy flagged. All appropriately gated.
- **Hardest residual risk (engineering gate, correctly labeled):** §12.3 unsolicited-note/aggregate-redemption liveness. `redeem(to)` loops over all of `msg.sender`'s notes and anyone can deposit notes to an arbitrary `to`; the PRD correctly refuses to declare a solution. This, plus the direct-custody Weighted multi-reserve conservation proof, are the two gates most likely to force design changes during planning.

## 4. Owner decisions vs engineering gates vs planning-deferrable

- **Owner decisions needed (blocking or near-blocking):** O01 authority reconciliation for FoT NET and rebasing sNET as configured underlyings (current law forbids both; `INDEXEDEX_AGENT_LAW.md:95–96`) — this is the single hard blocker. TWAP window/duration approval (PRD line 397 reserves it). Confirmation of opening-vs-peg economics (below).
- **Engineering gates (not owner-resolvable by approval):** §12.3 note-array liveness; Weighted multi-reserve conservation; owned-book construction for contraction quotes; exact-output inverse; V2 SE parity inventory (A21); rollover execution ordering/reentrancy; deployment/codehash verification; compounding precision/gas.
- **Safely deferred to planning:** selector/route inventories, Repo layouts, per-operation fee cells (matrix UNKNOWNs), preview/view mapping, matrix re-reconciliation to v0.17, test-case enumeration.

## 5. Prioritized narrow clarification list

1. **O01 (owner/policy):** Explicit approved supersession scope for FoT NET and rebasing sNET as this family's configured underlyings, before any implementation planning assumes token-policy legality.
2. **Owner confirmation (small):** Is the intended path from 1,000 NET/DETF opening to the 1 NET/DETF peg a long price decay with always-on expansion, and is expansion minted exclusively to sNET-DETF (diluting liquid holders) intended at all prices far above peg? (PRD line 513 implies yes; a one-line confirmation closes it.)
3. **Owner parameter:** TWAP window duration and minimum history/staleness policy for the expansion gate (line 397 forbids choosing an unapproved duration).
4. **Owner/legal-of-cap question:** Confirm that an O(log n) fixed-point compounding evaluation (no per-epoch loop, no epoch cap) satisfies the "no missed-epoch cap" rule; i.e., no gas-driven epoch limit may be introduced.
5. **Verification task (not owner):** NetNet BondDepository vesting duration — local code says two-day linear, historical prose says five days (line 598); verify deployed code before locking wrapper maturity math.
6. **Owner confirmation (small):** No additional contraction eligibility conditions beyond price < 1 NET/DETF and funded delivery (R11/§7.5 require explicit specification; currently none is recorded — confirm "none").

## 6. Confidence, counterarguments, missing evidence

- **Confidence:** High on document-internal consistency and citation accuracy (7 of 7 spot checks passed). Medium on completeness of the open-items register, since Pendle/NetNet depository citations were not re-verified this pass.
- **Counterarguments:** (a) One could argue Q2/Q6 reopen settled selections — I treat them as confirmations of implications, not redesigns; if the moderator judges them settled, they drop out with no PRD change. (b) The matrix staleness could be called cosmetic; it is nonetheless a real hazard because the matrix is the artifact a planner would expand row-by-row. (c) The PRD's honesty about unproven gates (lines 655–657) means "readiness" cannot be certified by review alone — consensus here proves neither security nor economic soundness.
- **Missing evidence:** live-chain verification of NetNet/Pendle deployments; gas feasibility of atomic rollover and uncapped compounding; the exhaustive V2 SE surface inventory (A21); a demonstrated custody design for §12.3.

**No implementation, tests, deployment or configuration change is authorized or performed by this review.**
