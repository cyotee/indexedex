# MiniMax M3 — Cross-Review of Three Peer Originals

> Cross-review of `astra-original.md`, `grok-original.md`, `kimi-original.md` for `NETNET_PENDLE_DETF_PRD.md` v0.23. Three originals read together; earlier cross-review artifacts not consulted. My own original (`minimax-original.md`) is the reference baseline; I cross-check each peer's claims, accept shared findings, attribute corrections, identify items I over- or under-weighted, and report new blockers from peers that I missed. Research-only; no shell/tests/code/config edits, no delegation. Routing metadata only: `minimax/MiniMax-M3` (not provider attestation).

---

## 1. Cross-review verdict

The four originals converge on the same **not-yet-ready** verdict with materially overlapping blocker sets. The strongest agreement is around C05 (bond duration vs next-epoch lock), C08 (external-note liveness), C11 (PLP/YT subshare lifecycle), C12 (SY provider/preview), the missing TWAP interface (R53/§2/§9.2), and the broken §10.2 citation to `docs/plans/detf/`. Cross-review did not surface any contradiction that reopens settled owner economics. Two peer items were under-weighted in my original and I accept them as additional blockers: (a) the **hook deploy path** is genuinely ambiguous (Grok §4.1, Kimi acceptance gap #2) given `INDEXEDEX_AGENT_LAW.md` line 49 ("Not monomorph CREATE3 hooks (weighted/orbital/quad) unless migrating to this path"), and (b) the **authority mismatch** between the locked `INDEXEDEX_AGENT_LAW.md` token policy (line 89–101) and the owner-approved FoT NET / rebasing sNET (Kimi B2) is a real PRD defect, not merely an acknowledged shared-law tension. One item I escalated (A20 USDG SE canonical-pool predicate, my B6) is over-scoped — the PRD's §4.1 wording is a planner obligation rather than an OPEN row, so I downgrade it from blocker to acceptance gap. One peer item (Kimi P1 #1, gons/K vs internalShares model mismatch) I treat as a model-divergence observation only; I do **not** assert that `DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md` is the intended missing reference, because the cited path `docs/plans/detf/` is empty and Kimi itself marks the deeper inference as speculative.

Final prioritized blockers after cross-review (numbered for reference; "B" continues from my original's B-series where overlap exists):

- **B12 (new, from Grok §4.1 + Kimi gap #2) — Hook deploy path unspecified.** PRD R02/R14 say "custom Uniswap V4 hook reproducing existing Weighted-hook behavior" without specifying whether this is a new hook diamond package on the current IndexedEx V4-hook package path or a fork of the legacy monomorph under `contracts/hooks/uniswap/v4/standardExchange/weighted/`. `INDEXEDEX_AGENT_LAW.md` line 49 explicitly says monomorph CREATE3 hooks (weighted/orbital/quad) are **not** the package path "unless migrating to this path." Without a selection, plan authoring would either silently migrate or silently copy monomorph. **Confidence: high on the gap; the question is which path, not whether a question exists.**
- **B13 (new, from Kimi B2 + Grok §4.9) — Authority mismatch between locked `INDEXEDEX_AGENT_LAW.md` token policy and owner-approved custom family.** `INDEXEDEX_AGENT_LAW.md:89–101` is "LOCKED — project law, all products" and forbids FoT and rebasing **as configured underlyings**, plus line 91 "Do not treat `WP-SEC-TOKEN-001` / `SEC-SPEC-010` as NEEDS_OWNER." The PRD O01 (line 24) says "Shared instruction files are unchanged." So a coding agent reading CLAUDE.md non-negotiable #6 will refuse FoT NET / rebasing sNET under current law. The PRD acknowledges this tension at line 1051 ("Current FoT policy remains an implementation-authority blocker; the custom-vault instruction is captured as the selected architecture, not a silent shared-policy amendment") without naming a resolution path. Per PRD document-control line 16 ("Do not reopen settled economics merely because unusual"), the **scoped approval is settled**. The PRD defect is that no resolution is proposed for the authority artifact — an explicit scoped-exception note, an entry on the family-local exception register, or an explicit statement that the implementer must add the entry. Kimi's recommended path (B2) is correct as a proposal but the PRD itself does not adopt it. **Confidence: high on the authority gap; this is not a re-asking of approval, it is reporting an open contradiction between two locked files.**
- **B14 (new, from Kimi P1 #1, inference-only) — §10.2 model divergence from `DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md`.** Per Kimi, the cited implementation plan uses a gons/K model (`balanceOf = floor(gonsOf/K)`, rebase adjusts K on distribution), whereas PRD §10.2 selects fixed `internalShares` with growing custody `B`. The PRD does not flag the divergence; it adopts "the established recipient/zero-share accounting" without specifying the mapping. **I do not assert that the implementation plan is the intended missing reference** (the cited path `docs/plans/detf/` is empty per Grok §4.4 / Kimi P1 #1). I treat this as an open model-question: does "internal shares" map onto gons algebra, on a separate K divisor, or on plain ERC-20 share balances? The PRD does not say. **Confidence: medium on the divergence being real; low on which source the PRD author intended.**
- **B15 (corrected from my B6) — USDG SE canonical-pool validation predicate** (downgraded from blocker to acceptance gap AG9). Re-reading PRD §4.1 line 250: "Specify the exact authoritative binding query or registry evidence during interface design." This is a planner obligation, not an OPEN row; the PRD authorizes the implementer to specify it. **Acceptable for plan-level detail; not a PRD defect.** Removing B6 from the blocker list.

Items I keep from my original:
- **B1 / TWAP interface** (all four converge; A44 requires verification matrix but PRD never delivers the interface).
- **B2 / C05 bond duration** (all four converge).
- **B3 / C08 external-note liveness** (all four converge; Kimi B1 with verified `BondDepository.sol:104–153` no-pagination fact, Astra B2 with the same).
- **B4 / C11 PLP/YT subshare lifecycle** (all four converge; PRD §7.1 defines only proportional exit math).
- **B5 / C12 SY provider/preview** (all four converge; Kimi B4 + Astra B8 + Grok blocker #5 + my B5).
- **B8 / §10.2 broken citation** (all four converge; Grok §4.4 confirms `docs/plans/detf/` empty).

Items peers raise that I had not flagged at the same priority:
- **Hook deploy path** → B12 (new blocker, above).
- **Authority mismatch** → B13 (new blocker, above).
- **Model divergence** → B14 (new blocker, above).
- **O09 not marked Resolved** → editorial E11 (below).
- **Versions 0.16–0.21 missing from changelog** → editorial E12 (below); not a blocker.

---

## 2. Items peers raised that I had flagged as acceptance gaps and now escalate

- **AG4 (BasicVaultRepo v0.23 tension)** — Astra B1 + Grok §4.3 escalate this. The PRD §6.3 requires tracking every locally held token including PLP/YT, but `BasicVaultRepo.sol:25–27` warns "NOT the owned shares of deployed liquidity reserves in the DEX." Hook-held PLP/YT are intermediate between "locally held token balance" (covered) and "deployed liquidity reserves" (excluded by comment). Astra's framing — "literal tracking of every unsolicited ERC-20 is also impossible without discovering the token address; ordinary ERC-20 transfers need not notify the recipient" — sharpens this: a full-set sync that walks every registered token is not bounded against adversarial growth. PRD §11.1 line 741 forbids unbounded historical traversal; §6.3 mandates full-set sync; these are in tension and not resolved. **Keep as acceptance gap AG4, do not escalate to blocker (PRD can be amended to specify a known/expected set).**
- **AG5 (A12 pretransfer reconciliation state machine)** — Astra B5 + Kimi gap #3 (and my AG5). Astra provides the sharpest evidence: `PendleYieldToken.sol:166–193` accepts an arbitrary earning user without caller ownership verification; `InterestManagerYT.sol:43–57` zeros accrued interest and pays SY to that user. So an externally forced payment can remove the native receivable and leave an unbooked balance before the hook acts. End-of-route sync cannot distinguish this from caller capital. PRD §6.3 (lines 379–383) names the problem but provides only a conservation rule. **Keep as acceptance gap AG5.**
- **AG8 (wrapper vs BasePoolMath)** — Astra B3 + Grok §4.2. The PRD correctly says "use Balancer behavior not wrapper" (line 272), and the wrapper's `singleExitExactOutSharesIn` (verified at `UniswapV4StandardExchangeWeightedBufferHookMath.sol:472–499`, "approximate: treat full amount as taxable for pool safety" at line 482) is identified as the deviation. PRD §4.3 mandates mapping to Balancer. **Engineering gate, not blocker; keep as AG8.**

---

## 3. Items I had over-scoped or under-scoped

### 3.1 I over-scoped (correcting down)

- **B6 / A20 USDG SE canonical-pool validation** → downgraded to acceptance gap AG9. Re-reading PRD §4.1 line 250 ("Specify the exact authoritative binding query or registry evidence during interface design") more carefully, the PRD explicitly authorizes the planner to specify this during interface design. This is a planner obligation, not an OPEN row. **Removing from blocker list.** A45 wording ("Package/proxy initialization matches the matrix's selected PkgInit/PkgArgs split... validates factory pedigree before NetNet tokens, rejects wrong SE binding and prevents repeat instance deployment") is a verification gate, not a PRD defect.

### 3.2 I under-scoped (correcting up)

- **Hook deploy path** → promoted to B12 blocker. Grok §4.1 and Kimi gap #2 both identify this as an OPEN architectural choice. PRD R02/R14 do not say "via the current IndexedEx V4-hook package path" or "via legacy monomorph"; the implementer would either silently migrate (modifying shared code) or silently copy monomorph (creating a new legacy path). **Both are shared-instruction decisions the PRD claims not to delegate.**
- **Authority mismatch (FoT/rebase)** → promoted to B13 blocker. Kimi B2 is sharp: `INDEXEDEX_AGENT_LAW.md:89–101` is LOCKED project law; line 91 says "Do not re-ask"; line 100 says "Agents must not invent FoT economics." The PRD's owner approval does not amend a file that calls itself LOCKED. The PRD acknowledges this at line 1051 without proposing a resolution. **Per moderator's framing, this is reporting an authority mismatch, not reopening the scoped approval.** I had it implicit in E1 (PRD internal contradictions) but did not name it as a blocker; Kimi is correct.
- **§10.2 model divergence** → promoted to B14 with caveat. I had it as B8 (broken citation only). Kimi P1 #1 observes that even if a path existed, the model on the other side of the citation (gons/K) differs from the model the PRD selects (fixed `internalShares` with growing custody `B`). **Per moderator instruction, I do not assert `DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md` is the intended missing reference.** Kimi marks the deeper inference as speculative; I treat B14 as a model-divergence observation only.

### 3.3 I under-attributed

- **C05 bond duration incompatibility** — verified by all three peers at the same source sites (`UniswapV4DetfCommon.sol:104–109`, `DETFBondNFTMathLib.sol:17–38`, `DETFFundedStakingMath.sol:96–117` linear `_claim`). I correctly verified the same. **No correction needed; my B2 stands.**
- **C08 external-note liveness** — Kimi B1 provides the strongest source evidence (`BondDepository.sol:104–140,143–153`, no per-note or batch redeem). I had the same evidence at §12.3 quote but Kimi adds the line numbers and the "no pagination or pruning" observation. **No correction needed; my B3 stands but is strengthened by Kimi.**
- **TWAP interface** — Grok §4.7 lists the most concrete missing items (observation store, same-block algorithm, consultation-time extension, decimal/denomination, warm-up encoding, who implements the interface). I had the high-level observation; Grok adds the implementable items. **My B1 stands; Grok's enumeration is the right detail.**

---

## 4. Genuine dissent (none that reopens settled economics)

- **None.** All three peers agree on settled economics (FoT/rebase approval, Keep-YT ingress, shared-SY egress, four-leg HLP, atomic rollover, TWAP-gated contraction, principal cliffs, native-wrapper exception, hold-interest-token).
- **One ambiguity:** Kimi P1 #1 infers a model divergence at §10.2; Grok §4.4 infers the cited file is empty and recommends inlining or restating. **Both agree the citation is broken; they differ on what is on the other side of the broken citation.** I treat Kimi's gons/K observation as an inference that requires the cited file to exist with content matching that inference, which it does not (per Grok). **Resolution: PRD must specify the model itself; the citation is irrecoverable in current form.**
- **One framing difference:** Grok treats missing engineering specification (Repo layouts, selector cuts, callback order) as engineering detail the impl-plan writer should produce. I treated some of these as PRD gaps. **Reconciliation: missing engineering specification is not a PRD defect; missing *product* specification is.** By this rule, AG1–AG8 are plan-level obligations; B1–B5, B8, B12, B13 are PRD defects (the PRD mandates an outcome but does not deliver the specification).

---

## 5. Final prioritized findings (after cross-review)

### Blockers (PRD defects — must close before plan freeze)

- **B1. Two one-hour arithmetic TWAPs: no interface delivered** (all four originals converge; PRD §2, §9.2, R53, A44; PRD line 35 itself acknowledges "Exact selectors remain interface design work").
- **B2. C05 bond duration compatibility: acknowledged but unresolved** (all four originals converge; verified `UniswapV4DetfCommon.sol:104–109`, `DETFBondNFTMathLib.sol:17–38`, `DETFFundedStakingMath.sol:96–117`).
- **B3. C08 external-note liveness: no concrete design** (all four originals converge; Kimi B1 verified `BondDepository.sol:104–153` no-pagination).
- **B4. C11 PLP/YT subshare lifecycle: OPEN** (all four originals converge; PRD §7.1 defines only proportional exit math).
- **B5. C12 SY provider / preview caveat: only high-level guidance** (all four originals converge; Pendle primary docs confirm preview is "not audited for on-chain use").
- **B8. §10.2 broken citation to `docs/plans/detf/`** (all four originals converge; Grok §4.4 + Kimi P1 #1 confirm directory empty).
- **B12 (new). Hook deploy path unspecified** (Grok §4.1 + Kimi gap #2; PRD R02/R14 do not name the factory path; `INDEXEDEX_AGENT_LAW.md:49` says monomorph CREATE3 hooks are not the package path "unless migrating to this path").
- **B13 (new). Authority mismatch between locked `INDEXEDEX_AGENT_LAW.md:89–101` and owner-approved FoT/rebase family** (Kimi B2 + Grok §4.9; PRD line 1051 acknowledges tension without proposing a resolution; this is reporting the authority mismatch, not reopening the scoped approval).
- **B14 (new, with caveat). §10.2 model divergence** (Kimi P1 #1, inference-only; PRD §10.2 selects fixed `internalShares` with growing custody `B` while the cited source file does not exist; PRD does not specify how recipient/zero-share accounting maps to internal shares — gons, K divisor, plain balances, or something else).

### Acceptance gaps (PRD correctly authorizes plan-level specification)

- **AG1.** A10 adversarial note-array growth bound — blocked on B3; once B3 is closed this resolves.
- **AG2.** A18 four-leg HLP join/exit storage layout, selectors, events, errors — engineering detail.
- **AG3.** A24/A26/A27 quote-domain construction — engineering detail; PRD §7.2/§7.3 name the rule.
- **AG4.** A49 BasicVaultRepo universal tracking tension with `BasicVaultRepo.sol:25–27` "deployed liquidity reserves" comment; PRD must clarify "locally held" boundary for PLP/YT.
- **AG5.** A12 pretransfer reconciliation state machine — PRD names the conservation rule but not the implementation site.
- **AG6.** §13 forwarding-failure isolation mechanism.
- **AG7.** §11.3 atomic rollover call-ordering items 1–7 — PRD names the flow but not the order.
- **AG8.** §4.3 wrapper-vs-BasePoolMath deviation — PRD mandates Balancer behavior; plan must replace wrapper path or document acceptability.
- **AG9 (downgraded from B6).** A20 USDG SE canonical-pool validation predicate — PRD §4.1 explicitly delegates to interface design.
- **AG10 (new, from Grok acceptance #5).** A21 exhaustive V2 SE parity matrix — PRD E14 acknowledges not done; plan must produce.
- **AG11 (new, from Kimi gap #3).** Gas/execution-bounds evidence — PRD §14 lists "execution/gas bounds" as engineering gate but no acceptance row tests for measured bounds.
- **AG12 (new, from Kimi P1 #5).** First-bond G/U/B/R vs four-leg Keep-YT book mapping — PRD §10.4 specifies first bond; non-first bonds under four-leg virtual book not mapped to `requiredFirstBondTokens()`.
- **AG13 (new, from Kimi gap #4).** Adversarial-matrix deviation for FoT family — PRD never specifies how `test_L2_FoT_forbidden` is scoped; INDEXEDEX_AGENT_LAW line 91 says "Do not re-ask."

### Editorial defects (non-blocking; not "no decisions" blockers)

- **E11 (new).** O09 is the only row in §14 not prefixed "**Resolved:**" (line 842) — Grok blocker #6 + Kimi P1 #2. Either label Resolved or state what remains open.
- **E12 (new).** Version history 0.16–0.21 absent from changelog — Grok §5 + Kimi P1 #3.
- **E13 (new, from Grok §5).** Companion `REQUIREMENTS_QUESTIONS.md` header still "reconciled through version 0.12" (line 7) — stale relative to v0.23; planner must not read Q6 ("NET-out and sNET-out both use interest only") as current.
- **E14 (from my original).** §10.4 illustration uses whole-token DETF (`G = 1,000 DETF`); nine-decimal native unit not stated. Implementer may read 1e18 native units instead of 1e12.
- **E15 (from my original).** §6.3 `(E,R)` tuple storage site not specified.
- **E16 (from my original).** §7.4 / A25 share-token vs internal-balance distinction not made explicit; A21 line 882 mentions `burnFromInternalBalance`.
- **E17 (from my original).** E15–E17 unpinned local snapshots; recommend pinning one upstream Pendle commit hash.

---

## 6. Evidence and confidence

- **High confidence:** B1, B2, B3, B4, B5, B8, B12, B13 (verified by multiple originals at same or overlapping source sites).
- **Medium confidence:** B14 (Kimi's gons/K observation is an inference; the cited file does not exist on disk; PRD does not specify the model so we cannot say what model is intended).
- **High confidence on authority mismatch:** B13 (file-vs-file contradiction is verifiable without inference).
- **Not claiming:** live Robinhood 4663 deployment equivalence, Pendle source line pins in §11/§16 (Grok's RC_UNAVAILABLE on `lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol` and `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol`; Kimi did not re-verify). These remain unverified.
- **Not asserting:** `DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md` is the intended missing balance-derived reference. The cited path is empty per Grok §4.4 / Kimi P1 #1. The model-divergence observation stands; the source identification does not.
- **Not reopening:** scoped custom-family approval (FoT NET, rebasing sNET, direct hook custody, four-leg HLP, Keep-YT ingress, shared-SY egress, atomic rollover, TWAP-gated contraction, principal cliffs, native-wrapper exception, hold-interest-token, non-blocking fee forwarding, public HLP, DETF-as-SY). Per document-control line 16, unusual economics are not grounds to reopen.

---

## 7. Recommended closure sequence (preserved from my original; refined)

1. Close B13 (authority mismatch) first — the family's scoped approval does not amend LOCKED shared files; the PRD must name the resolution path (family-local exception register entry, explicit shared-law supersession note, or PRD statement that an implementer must add the entry). Per moderator's framing, this is reporting the mismatch, not reopening the approval.
2. Close B12 (hook deploy path) — selection between current IndexedEx V4-hook package path and legacy monomorph must be PRD-level, not planner-level.
3. Close B1 (TWAP interface) — produce the standard interface in the PRD (struct `CumulativeObservation`; `consult(seriesId)`, `checkpoint(seriesId, newPriceWad)`; `NotReady`, `StaleObservation` errors; `ObservationRecorded` event; readiness semantics). Per R53 wording, this is PRD-level.
4. Close B2 (C05 duration) — select one of three branches (clamp, reject, no-bonus). Per PRD §10.3, cannot be deferred.
5. Close B3 (C08 liveness) — produce a concrete ownership/liveness design or descope the external-bond feature.
6. Close B4 (C11 PLP/YT subshare) — produce worked math (initial scale, join, last-exit, dust, rollover).
7. Close B5 (C12 SY provider) — produce the on-chain re-derivation design and the receivable/held split during third-party pre-claim.
8. Close B8 / B14 (§10.2 citation + model) — replace the broken citation with inlined formulas or a live co-located law file, and specify how internal shares map to the recipient/zero-share accounting.
9. Engineering detail (AG1–AG13) is plan-level and can be produced during planning, except AG4 / AG12 / AG13 which need PRD amendment before plan freeze (PRD says "specification closure required before executable planning" at line 9).

---

## 8. Notes on peer credibility (routing metadata, not provider attestation)

- **Astra** (`openai/gpt-6-astra`): broad separation of architecture, accounting, integration, lifecycle, custody, bond, and TWAP categories; C-source line citations verified where I cross-checked (BondDepository, BasicVault, PendleYieldToken). High on local-fact accuracy; honest about hook-skill `RC_UNAVAILABLE`.
- **Grok** (`xai/grok-4.6`): most operationally specific on engineering gaps (hook DFPkg vs monomorph, foundry profile contradiction, four-virtual-leg mapping, BasicVaultRepo component table, B/U-vs-gons model). Tool denials (`RC_UNAVAILABLE` on canonical Crane skills) recorded honestly.
- **Kimi K3** (`kimi-code-plan-global/k3`, high): strongest on the authority mismatch (B2 — explicit LOCKED file vs PRD owner-approval contradiction), §10.2 model divergence (P1 #1), and cited file absent. Best at distinguishing facts from inferences.
- **MiniMax M3** (me, `minimax/MiniMax-M3`): same source-trace quality as the others; over-scoped B6; under-scoped hook deploy path and authority mismatch; B8 was right but missed the model-divergence angle Kimi raised.

All three peers independently verified the same source-line ranges I did. Where I diverge from a peer, I attribute and explain; where I agree, no attribution needed beyond this paragraph.

---

## 9. Source-list cross-check (this turn)

I re-read: `docs/research/netnet-prd-quality-2026-09-27/{astra,grok,kimi}-original.md` (full files). I did not re-read: `docs/research/netnet-prd-quality-2026-09-27/minimax-original.md` (my own original, attribute already known); any peer cross-review artifact; any review file under `docs/strategies/ohm-style/netnet-pendle/reviews/`; `REQUIREMENTS_QUESTIONS.md` (read in original pass). Source-line citations in this cross-review refer to PRD v0.23 (1,101 lines) and source files I read in the original pass.
