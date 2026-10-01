# NetNet–Pendle DETF PRD v0.17 — Independent Readiness Review (MiniMax M3)

**Reviewer identity and observed metadata.** Prompt identifies me as `minimax/MiniMax-M3`. PRD §17 line 762 records tool metadata as `minimax/MiniMax-M3` (alongside `openai/gpt-6-astra` and `xai/grok-4.6`) — routing metadata, not provider attestation, and not an authority grant. The PRD also references `kimi-code-plan-global/k3` (matrix row 135, KEEP_YT_R4). No secret/credential/key material was requested or returned. The task is PRD-only research; no implementation, shell, tests, deployment or config change has been performed, and none is requested.

**Source corpus actually read.**
- `NETNET_PENDLE_DETF_PRD.md` v0.17 (883 lines) — full text.
- `NETNET_PENDLE_OPERATION_MATRIX.md` v0.15-aligned (145 lines).
- `REQUIREMENTS_QUESTIONS.md` A01–A18 + progress register + preserved clarification.
- `KEEP_YT_ROLLOVER_RESEARCH.md` (109 lines).
- `CLAUDE.md` (router, non-negotiables, deploy path reminder).
- `docs/agent/INDEXEDEX_AGENT_LAW.md` (full, 625+ lines incl. token policy, families, TESTING, Foundry, V4 hook SE valuation under APEX D60).
- `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` D1–D66 (excerpt through §14).
- `contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PRD.md` §16 (excerpt).
- `lib/crane/.claude/skills/crane-architecture/SKILL.md` and `crane-testing/SKILL.md`; `.claude/skills/indexedex-uniswap-v4-hook-packages/SKILL.md` (excerpts).

**Tool availability note.** Prompt asks for `apply_patch`; only `write`, `edit`, `read`, `glob`, `grep` are available here, so `write` was used after a `read` of the target directory's listing. I did not read any peer researcher artifacts (Astra/Grok/Kimi). No external Context7 call was made: PRD does not introduce a new library/API/SDK/CLI claim that would change a product decision, and all evidence-register items either point to local repo sources I already read or to the previously verified primary doc URLs (ERC-4626 EIP; Pendle docs) that the moderator already approved.

---

## 1. Overall quality and clarity

The PRD is a **mature, densely-cited research document**, not a deployment plan. Its purpose is unambiguous: capture the human-selected design for a custom NetNet-Pendle DETF family, list remaining engineering gates, and forbid reopening settled selections. Version discipline is excellent — every amendment names what it supersedes and what remains open. Citations are concrete: file paths, line ranges, function selectors (E15/E16). The leading interpretation block (lines 16–23) cleanly separates SELECTED, OPEN, ENGINEERING GATE, and “must” intent from amendment-to-shared-law. Cross-family supersession is explicitly **not** claimed (line 46, §2.1, line 53).

**Weakness #1 — contradiction density.** The PRD contradicts itself about token policy. §2.1 (lines 50–53) records that NET is conditionally FoT and sNET is rebasing, both forbidden by current repo law (INDEXEDEX_AGENT_LAW.md §Token policy, lines 89–101), and that no exemption is assumed. The custom family is nevertheless selected. The PRD's own framing (§2.1) says these are **departures that require explicit approved supersession**. Resolution is implicit (O01) but never landed; the human keeps selecting on top of an unresolved authority/policy reconciliation. This is the single largest product ambiguity.

**Weakness #2 — singleton enforcement claim.** §4.1 (line 173) and matrix line 96 state that salt `"NET-DETF"` is hard-coded and "must prevent a second instance even with changed arguments." The PRD itself acknowledges (line 715: "salt encoding and its interaction with the actual factory/address derivation must demonstrate that requirement; the string alone is not claimed as proof of singleton enforcement"). The plan needs an actual mechanism, not a string literal. This is safely deferred but **must not** be silently closed.

**Weakness #3 — selection of representative numbers vs. proposal.** Line 513 (“launch **1,000 NET per DETF** is confirmed, distinct from the 1 NET ongoing target and not raw-unit scaling”) and matrix line 85 (“now proposes **1,000 NET per DETF at launch plus 0.5% expansion per NET epoch**… Do not change the ongoing 1 NET peg by implication; supply basis, eligibility/stop rule and catch-up compounding remain UNKNOWN”) sit side by side with PRD v0.17's controlling amendment that **does** fix 0.5% of compounded total supply, current-TWAP-gated, with current TWAP qualifying the batch. The matrix is one step behind the PRD — it should be updated to mirror v0.17's resolved formula before any planning begins.

**Weakness #4 — operation-matrix and PRD n-symbol divergence.** PRD §9.1 uses `S0, n, T` for `pendingMint = S0 * ((1.005)^n − 1)`; matrix uses similar but different pseudocode. PRD §10.4 uses `A, P0, M, p, Q, G, U, B, R`; matrix uses the same. The PRD's `n` and the matrix's `n` for the matrix are different things. Code, not prose, will resolve this — flagged for the planning author.

**Clarity strengths.** Strict separation of hook-LP claims vs. liquid DETF (R35/R42, §7.1); selection of "no caller-selected token destination" (line 222); explicit atomicity across rollover and external-bond collection (R09, R45); rejection of the rejected tender-plus-buyback mechanism; separation of reinvestment burn leg from bond leg with explicit no-bonus rule (R46); accrual-value-with-LP transfer rule (R42); rejection of MiniMax's earlier D50-clock suggestion (line 776). All of these are well-anchored.

---

## 2. Owner decisions vs. engineering gates vs. deferred-to-planning

The PRD's three categories are useful and consistent with INDEXEDEX_AGENT_LAW.md.

**Owner decisions (resolved, not to be reopened, per PRD's own record and historical council disposition):** R01–R55 §3 except where flagged OPEN; v0.5 liquid swap-only; v0.6 standard-interface contraction with input-side `p`; v0.7 hook-as-vault; v0.8 public hook + configurable USDG SE; v0.9 NetNet-tax-in-SE-only; v0.10 shared-LP scope + oracle identities + ERC-4626/SY on DETF itself; v0.11 ownership-limited burn, unclaimed-interest sNET leg, transferable NFT, atomic reinvestment; v0.12 reuse of `DETFFundedBondTarget.sol` and `UniswapV4StandardExchangeWeightedBufferHookMath.sol`; v0.13 first-bond G/U/B/R; v0.14 rollover/claim mechanics; v0.15 atomic rollover; v0.16 premium-gated compounding; v0.17 0.5% compounded, current-TWAP-gated, balance-derived rebasing. R55 (matrix deployment consolidation) is owner-decided.

**Open items requiring human input (PRD §14, O01–O10):**
- O01 — FoT NET, rebasing sNET, exact configured token faces; approved scope of new-family departures.
- O02 — Authoritative price/quote construction for withdrawal-branch selection, any additional justified eligibility, atomic realization.
- O03 — Claim/checkpoint execution, reference-duration compatibility, terminal-epoch processing, NFT retirement details.
- O04 — Custom reserve-to-math mapping, parity/deviations, weights, bootstrap, authority flow (math source resolved).
- O05 — TWAP window/observation/invalid-history policy, native precision/dust, bounded evaluation, initial epoch marker, view integration.
- O06 — Zero-share/deposit/withdraw rounding, bond-accounting integration, duration compatibility, views, conversions, costs, bootstrap.
- O07 — Registry layout, safe call order, verified SY conversions, successor allocation/empty-target policy, residual access, execution bounds/compensation (atomicity settled).
- O08 — Payment conversion/limits, custody and note-array liveness, final release/retirement, reward destinations, PENDLE-forwarding failure handling.
- O09 — Contraction funding/fee order, post-operation reserve and peg-price response, owned-book construction, exact-output inverse (quote domain settled; insufficient delivery reverts).
- O10 — Admission/transfer valuation and checkpoint implementation, exact validation interface, this strategy's self-leg representation (shared LP, USDG inclusion settled).

**Engineering gates (PRD §14, explicit):** direct-custody Weighted hook multi-reserve joins/exits and quote/settlement conservation; safe DETF/child callback authority; full-feature NetNet V2 SE parity with taxed/untaxed execution; external-note ownership/aggregate redemption liveness; deployment/code verification; epoch/reward attribution; execution/gas bounds; pricing and rollover recovery. Encapsulation assigns responsibility but does not prove these.

**Safely deferred to planning (not owner questions, not authority questions):** TWAP implementation specifics (window length, observation cadence, history retention, failure-mode behavior); native-unit rounding constants; gas budget; exact zero-share initialization algorithm; exact-output inverse math; `requiredFirstBondTokens()` weight values (the matrix marks them UNKNOWN and that is correct); pending-expansion view/event surface; test fixture selection (production-first TestBases per INDEXEDEX_AGENT_LAW.md §Testing and CLAUDE.md non-negotiable #3); event names and indexing tags; ERC-4626 `convertTo*`/`preview*`/`max*` exact selector implementation; SVG/metadata per D55 for the custom NFT; signed-quote permit2 wiring details; the singleton-salt enforcement mechanism (deferred, **not** silently closed).

---

## 3. Consistency and custody/accounting

Custody model is internally consistent. The hook **is** the custody and accounting vault for Pendle LP, retained YT, accrued interest, V2 SE shares (line 132–150; R02, R05). The DETF proxy directly holds its hook LP (R29). The custom `rebasingClaimToken` holds DETF and internal ownership shares; expansion mints to it directly (R43/R54, §9.1). The NFT controls native-note custody and controls wrapped bond position (R12/R44/R45). Children call the DETF coordinator (R29).

Conservation boundary issues (A01, A05, A12):
- `projectedBacking = B + pendingMint` is shown for UX but not spent (§10.2). Good.
- Hook-internal custody components are not literal V4 trading currencies (line 159). Exact custom rate mapping to Weighted math inputs remains O04. The PRD correctly does not silently assign it.
- Proportional-mode allocation uses `floor(h*X/H)` per component; unbalanced/subset and single-token modes use the copied Weighted invariant-based quote (R28, §7.1). The PRD rejects capping these by the proportional vector. Correct.
- All accrued value follows LP on transfer (R42); admission must still price existing accrued value (line 277). Correct.
- Fee-owned PENDLE excluded or offset once (lines 248, 273). Correct.
- Hook's sNET leg is unclaimed interest only; "public swaps must never fully drain it or substitute Pendle principal" (R40, §6 line 236). Acceptance criteria A27 must prove this empirically; the PRD does not prove it, only requires the property.

**Funding waterfall for contraction (§7.3, lines 309–313):** Own reserve portion → claim income → unbuffer SE shares → redeem owned hook LP → convert components → pay. Insufficient delivery reverts atomically. The PRD explicitly rejects: ordinary-swap fallback, partial settlement, pending-output balance, spending other participants' staking backing or exclusive external notes or fee-owned PENDLE. This is sound in principle but has no demonstrated conservation proof — A17 is the test obligation. ENGINEERING GATE.

**Expansion realization ordering (§9.3, R54):** stake, bond, burn/redeem, unstake, transfer, claim or reinvest all settle **before** changing relevant ownership or consuming backing. Acceptance criteria A42 enforce it; A43 require previews to match. Correct sequencing; preview/execution divergence must be bounded by user protections, not by per-caller nonces as reentrancy defense (line 313).

**Funded staking and bond fund claim separation (§10.2, §10.3):** sDETF holds DETF directly (D34); rewards are sDETF claims paid before principal matures (D38, R50); principal cliff per selected position-specific release rule (R19/R50). The custom family overrides the Universal linear-vesting release (PRD line 474). Reusing `DETFFundedBondTarget.sol` is conditioned on incompatibility identification (R47); release-predicate adaptation is the explicit resolution. The PRD's identification of the compatibility boundary (linear `_claim` vs. custom cliff) is honest and clear; the PRD does **not** silently change lifecycle.

**Reinvestment debit (R43, §10.2):** participant reinvesting staked backing must atomically debit only the participant's old claim and burn only that backing, then credit only funded replacement. Example 100/40/60+replacement is correct (line 459). No double-claim, no separate unstake transaction. A29 acceptance is the proof. ENGINEERING GATE.

**External-bond custody (§12):** three custody stages (table line 610) — pre-collection (NFT-exclusive), post-contribution (common backing), post-staking (NFT controls attributed sNET-DETF position). The PRD rejects raw-NET payout bypass (R45), deferred harvested-NET mode (R45, R12), advance credit (R45), and double-counting of raw DETF and receipt (line 614). The atomic-failure behavior is consistent with the engineering gate and A30.

**PENDLE harvesting (§13, R30):** hook is earning/custody address; any caller may trigger; recipient is dynamic `feeTo()` from Vault Fee Oracle; caller acquires no entitlement; third-party force-claims must not strand the balance. Accounting must track new harvest and previously attributable harvested PENDLE. A11 acceptance. ENGINEERING GATE.

---

## 4. Expansion / TWAP / bootstrap / maturity/rollover

**Expansion v0.17 (§9.1):** `pendingMint = S0 * ((1.005)^n − 1)` when current TWAP strictly > 1 NET/DETF, else 0. Rate is 0.5% per eligible epoch on **total supply** (compounded), not per-staker, not per-HLP, not premium-scaled, not annualized. The PRD explicitly rejects `S0 * 0.005 * n`, premium-size multipliers, `(price-peg)/price`, and seigniorage parameter reuse. Equality and below-peg yield no expansion. Current TWAP qualifies the entire batch — no historical per-epoch replay, no synthetic price re-evaluation. A40/A41/A43 enforce. The math is unambiguous.

**TWAP (§9.2):** hook owns calculation/storage; window, observation updates, bootstrap history, retention, stale/insufficient-history behavior, callback-safe consultation are all O05/engineering. The PRD correctly rejects substituting spot for missing history (line 397) and rejects using TWAP as the burn synthetic-price oracle (line 399, separating expansion gating from post-expansion burn pricing). A44 enforcement. ENGINEERING GATE.

**Bootstrap / first bond (§10.4):** merged 02–03 in matrix. Inert branch seats capital, calculates matching/purchased DETF (`G`, `U`, `B`, `R`), joins hook, checks nonzero initial LP, marks live, funds NFT/rewards. Full-book additional non-DETF legs pulled within the same call. Linear opening price (`openingOfPair` or `creationOfPair` if zero). Reference `UniswapV4DetfTarget.sol:532–560,581–600,629–669` cited (matrix line 98). The PRD correctly identifies that zero-interest initialization must reconcile without relabeling principal as yield (line 513, A35). ENGINEERING GATE for asset mapping; settled for lifecycle.

**Maturity/rollover:** ordinary bonds and direct-Pendle bonds hold their assigned Pendle-maturity cliff (R18/R19). USDG-funded fresh bonds share the same lock schedule (matrix line 24). Wrapped external NetNet bonds mature at **full native NetNet bond maturity** (R19, line 426) — explicit exception. Atomic rollover is selected (R09, v0.15): active source rejected; trusted-factory-first NetNet validation; new SY permitted; old PT/YT/SY addresses need not equal successor. Per `KEEP_YT_ROLLOVER_RESEARCH.md` §"Answer", seeded-target Keep-YT entry uses ratio-matched tokenization + dual mint (no PT/SY swap call). Expired-source exit burns LP into SY/PT and redeems mature PT without AMM sale. Empty successor is rejected (line 577). Atomicity is settled; remaining execution specifications are listed in §11.3 and A37. ENGINEERING GATE.

---

## 5. Interfaces, external dependencies, acceptance criteria

**Interfaces (R37, §7.4, A16/A25):** NET-DETF itself is the share token for both ERC-4626 and Pendle SY surfaces. ERC-4626 declares `asset() = sNET`; SY routes NET/sNET/USDG. Deposit-side buys existing DETF; no wrapper receipt, no fresh liquid issuance, no separate proportional reserve claim. Withdrawal/redemption branch (P ≥ 1 SWAP, P < 1 BURN with input-side `p` only) is settled (R38, A24). The owner expressly **declined** strict-conformance certification as a prerequisite (A12, R37 §7.4 last paragraph). The PRD does not silently add wrappers, fresh issuance, or proportional claims.

**External dependencies:**
- *NetNet* — FoT NET, rebasing sNET, epoch + staking + bond depository + distributor. O01 authority reconciliation is unresolved. PRD acknowledges this directly (lines 50–53). Source paths cited correctly in E04/E05/E06.
- *Pendle* — V7 market, YT/SY/PT/rewards; router helpers inspected locally (E17; `ActionAddRemoveLiqV3.sol` ranges; `ActionBase.sol:26–64`; `ActionMarketCoreStatic.sol:146–163`). No verified Robinhood deployment equivalence; no live fee/exemption verification; expansion semantics caveat (line 748). ENGINEERING GATE.
- *Vault Fee Oracle* — reuse existing Robinhood instance; hook proxy key for hook-LP mint usage fee; NET-DETF instance key for usage fees and `seigniorageIncentivePercentageOfVault`. Lookup identity is selected (R36/A23); no numerical default is invented.
- *Weighted hook math* — `UniswapV4StandardExchangeWeightedBufferHookMath.sol` and vendored Balancer V3 `WeightedMath.sol` selected as baseline (R48, E16). Owned-reserve input mapping remains engineering.
- *V2 SE reference* — `UniswapV2StandardExchangeDFPkg.sol` cited as baseline for full-feature parity (R34, E14, A21). An exhaustive pinned parity matrix remains engineering work.

**Acceptance criteria:** A01–A45 are comprehensive and tied to evidence (P1–P8 in matrix). They correctly separate *integration behavior* (A16, A25) from *engineering proof* (A17, A26, A27). They forbid silent reductions (A04, A21) and silent additions (A06, A14). The PRD's own A36–A39 acknowledge that ownership-bound rollover and Keep-YT entry are not yet demonstrated. ENGINEERING GATE.

**Cross-family consistency:**
- *Custom-family vs. Universal DETF* — PRD does not silently amend D32–D66 or §24 (lines 46, 53). The bond math reuse (R47) is conditional on compatibility identification. The balance-derived rebasing correction is shared with the Universal remediation PRD (`docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md` v0.2, line 413, line 881) and the two are explicitly kept distinct (line 413).
- *DETF I/O routing (§16 of `DETF_INSTANCE_IO_ROUTING_PRD.md`)* — PRD does not mention route tables. Custom family probably requires its own Custom mint/burn/bond/close/donate tables since liquid routes use reserve swaps and contraction uses a single selected branch. Plan must reconcile.
- *APEX D60 (held-reserve valuation under weighted/curve-quad/orbital/CP/dual SE buffer hooks)* — applies to any Uni V4 reserve hook. PRD's selected baseline is the same Weighted hook family. Plan must implement rate providers per D59/D60. Likely not yet enumerated in PRD.
- *D9 owner-only liquidity* — for a custom direct-custody hook, owner = the DETF; flag on. Plan must implement MultiStepOwnable and the deploy-time flag per D9.
- *D39 fallback to reserve swap* — PRD explicitly **rejects** automatic fallback restoration (line 168, line 209). Owner has selected standard-interface contraction via input-side `p`. PRD consistent with itself.
- *D63 LP-payment bond economics* — custom family selects G+U+B+R with explicit G/U/B/R formula; it is not the LP-payment bond (G=0) variant. Plan must keep these two modes distinct.
- *FoT/rebasing token policy* — unresolved (O01). No silent waiver. Correct posture.
- *D55 NFT metadata/SVG* — not addressed in PRD. Plan must produce it.

---

## 6. Prioritized narrow clarification list

This is the smallest set of questions whose answer changes a product decision or unblocks an engineering gate, in priority order. I do **not** reopen settled selections.

1. **O01 — token-policy reconciliation.** Confirm that the custom family is the approved departure from FoT-NET-as-rateAsset and rebasing-sNET-as-underlying prohibitions, and that no exemption is required. Or specify the exemption scope. Without this, the plan cannot list PkgInit/PkgArgs validation rules for the three tokens. *Critical blocker.*
2. **Singleton-enforcement mechanism.** What concrete mechanism (factory salt composition, registry occupancy check, package `initAccount` revert-on-second-call) implements the "single NET-DETF instance" requirement? The salt string alone is not proof (line 715).
3. **Bond depository interface canonical face.** `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol` is the cited reference (E06). Confirm the deployed Robinhood instance and which market IDs (0 USDG, 1 VLP) the custom NFT exercises, and the minimum-price/payment-deadline composition for §12.1.
4. **TWAP failure-mode policy.** Define: (a) initialization source (first observation seeded how?); (b) missing/stale/invalid history behavior (does it block expansion, treat as below peg, or treat as no observation?); (c) window length proposal; (d) observation cadence; (e) retention bound. PRD line 391 requires explicit definition; A44 enforces.
5. **Owned-reserve self-leg representation (O10).** Confirm the custom DETF's own HLP position is represented as a separate component `S` (or analogous), with weight consistent with the selected V4 Weighted mapping, and counted once in backing. PRD line 159, 281 say it must be enumerated; it is not.
6. **V2 SE binding evidence.** Specify the authoritative binding query (e.g., `lp.token0()/token1()` equality with NET/USDG, factory address match, getReserves presence, IRFV presence) and what an empty correctly configured SE looks like. PRD line 175–177 explicitly defers.
7. **External-note aggregate-redemption liveness proof.** §12.3 names this as unresolved; A09 requires it. Either (a) provide a wrapper-implementation sketch with note array bound, or (b) defer external-bond purchase to a separate PRD and remove it from this implementation plan.
8. **Custom rebasing-token initial epoch marker and bootstrap history.** §9.2 line 397 requires explicit specification; A41 enforces. What is the first observation? What is the source (oracle, manual, hook internal)? Is there a minimum-history gate before expansion can qualify?
9. **Owner-disposition on standard-interface numeric defaults.** PRD explicitly does not select any default percentage, hard cap, hysteresis band, off-pool funding, second buyback, or keeper bounty (§7.5 line 340, line 905). Confirm these remain unselected so the plan does not silently introduce any.
10. **DETF I/O routing alignment.** Does this custom family use `IUniswapV4Detf` from `DETF_INSTANCE_IO_ROUTING_PRD.md` §16, or a new package? PRD says "wholly custom" (R14). If custom, plan must reconcile R1–R20 of that PRD explicitly.

---

## 7. Confidence and what is missing

**High confidence (settled selections):** selection of Keep-YT for NET/sNET (R03); V2 for USDG (R03/R05); hook-as-vault (R02/R28); public shared hook LP (R32/R35); configurable USDG SE validated by Package (R33); ownership-limited burn quote (R27/R39); atomic rollover (R09); unclaimed-interest sNET leg (R40); transferable NFT (R44); atomic external-bond reinvestment (R45); 0.5% compounded total-supply expansion gated by current TWAP > 1 (R52/R53/R54); balance-derived rebasing (R43/R55); first-bond G/U/B/R formula (R51/§10.4); PkgInit/PkgArgs split (R55); mandatory fixed-salt enforcement (R55, mechanism still owed); reuse of `DETFFundedBondTarget.sol` and Weighted hook math (R47/R48).

**Medium confidence (consistency with related law):** that this family does not silently amend shared law (PRD says it doesn't; matrix and PRD disagree only on the 0.5% expansion base being unresolved — matrix needs update); that APEX D60 rate-provider requirement is achievable for the custom hook (likely yes via copying Weighted hook math plus rate-provider plumbing); that the hook can own V2 SE shares (PRD yes; the existing V2 SE surface permits share custody as a holder).

**Low confidence (engineering gates):** conservation under multi-reserve joins/exits; quote/settlement atomicity under finite precision; zero-interest first-bond initialization; same/different SY conversion cost; empty-successor policy with no silent seed path; bond duration minimum compatibility with next-epoch release; funded staking reward accounting without a per-user distribution index; rollback of pending expansion markers across all failure paths; callback-safe snapshot consistency.

**Missing or weak evidence:**
- No verified Robinhood deployment equivalence of Pendle V7 router, YT v6, market V7; line 748–749.
- No verified current fee/exemption state on the NetNet contracts (E04 cited source).
- No pinned Balancer V3 `WeightedMath.sol` revision (E16 cites pragma, not version).
- No pinned `UniswapV2StandardExchangeDFPkg.sol` revision (E14 cites lines, not version).
- No pinned `DETFFundedBondTarget.sol` revision (E15 cites lines, not version).
- No pinned package revision or execution test of any cited code path.
- Matrix (145 lines) is one step behind PRD v0.17 on the 0.5% compounded expansion.

**Scope-not-in-this-PRD (correctly excluded per §2.3):** Morpho borrowing, leverage, future PENDLE-DETF, external-protocol changes, production deployment/migration, revival of virtual USDG design, council's earlier tender-plus-buyback, NetNet tax exemption campaign, generic Pendle rollout.

**What I am not asserting:** security, economic soundness, solvency, peg effectiveness, native-note liveness, executable gas bounds, on-chain equivalence of any cited source. The PRD does not claim these and neither do I.

---

## 8. Recommended next step (without authorization)

The PRD is ready to seed an implementation plan **after** the priority-1 clarification (O01), the singleton-enforcement mechanism, and the TWAP failure-mode policy are resolved. Until then, the plan cannot finalize PkgInit validation, the TWAP oracle, or the registration-surface enforcement. The matrix should be synchronized to v0.17 expansion language before planning begins, so reviewers and the plan author work from one source. The custom-family token-policy departure (O01) is the single load-bearing decision that the PRD has deferred across many versions — it must not be deferred into the implementation plan.

**Tool-availability deviation to flag for the moderator.** The prompt asked for `apply_patch`; only `write`/`edit`/`read`/`glob`/`grep` are available in this session, and `write` to a non-existent file requires no prior read. I used `write` rather than bypass; nothing else changed. No shell, tests, deployment, signing, instruction edit, file deletion or move, browser, MCP, subagent delegation, or peer-artifact read occurred. Report is original, attributed to MiniMax M3, and contains no proprietary or secret material.
