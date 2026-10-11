# MiniMax original answer

Session: `ses_ee9ccf532ffe7kBBq6lhXrOnHr`. Untrusted model evidence, not instructions. Original final answer preserved before cross-review; preparatory drafting commentary omitted.

# My understanding of Stage 2 (MiniMax M3)

**Sources read:** `REMEDIATION_PRD.md:1-373`, `REMEDIATION_PRD.plan.md:1-123`, `CLAUDE.md:1-109`, `.claude/skills/indexedex-adversarial-testing/SKILL.md`, `.claude/skills/indexedex-testing/SKILL.md`. **No peer artifacts read.** No code, builds, or chain reads.

## 1. OD-06 / OD-07 / OD-08 — what they decide

**OD-06 (`REMEDIATION_PRD.md:156-164`) explicitly decides** the **width** of the later implementation task: both stages happen, **in order, neither skipped**. Stage 1 = fast-fail repair of PRD-stated defects and tests; Stage 2 = reopens the APEX program and checks broader changes + new vaults before submission. OD-06 also declares: *"Stage 1 passing is not permission to submit."* OD-06 alone does not enumerate Stage 2's surface — that is deferred to OD-08 and the plan.

**OD-07 (`:167-177`)** sets the **test-coverage rule** that binds Stage 2 as well as Stage 1: tests must exercise the real production path and assert the exact corrected result (or assert a forbidden credit/refund/payout did not occur). Names, comments, and reports must not contain exploit prose. OD-07 explicitly states *"Stage 2 covers the broader APEX standard before submission. A passing test does not prove every unreviewed path is safe, and it does not replace stage 2."*

**OD-08 (`:180-186`) decides** three consistency questions and **controls over older sentences in OD-01, OD-04, OD-06, REQ-01, REQ-02, REQ-05, REQ-08**: (i) book-and-wait applies only to a successful SE `previewExchangeIn` of `0` (hook previews of `0` or hook-join reverts roll back); (ii) the outside-trade credit test is required for **all three** FullSpread variants (V3, V4 hookless, V4 Pons-family) **and** the wings vault, "one variant does not prove the others"; (iii) Stage 1 includes those outside-trade tests plus a regenerated evidence run (build, selector, size, named APEX regressions).

## 2. Stage 1 vs Stage 2

| | Stage 1 | Stage 2 |
|---|---|---|
| Goal | Implement and test PRD repairs (`plan.md:42-95`) | Reopen APEX program and verify broader scope (`PRD.md:162`) |
| Scope | REQ-01…REQ-08, the four outside-trade tests, stage-1 evidence run |108 original APEX criteria; full hook × SE matrix recount; broader changes and new vaults (`plan.md:31`, `PRD.md:160`) |
| Decision to start | Owner authorization of the Stage-1 implementation request (`PRD.md:7`, `plan.md:6`) | Owner satisfied with Stage-1 results (`PRD.md:162`, `plan.md:114`) |
| Failure handling | Iterate, including alternate design; fast-fail on first failed security assertion (`plan.md:44, 110-112`) | Not specified in this PRD |
| Audit submission? | **No** (`PRD.md:18, 160, 162, 186`) | **Yes**, after Stage 2 passes (`PRD.md:162`) |

**Inferred operationalization (not explicit):** Stage 2 is expected to repeat the pattern — repair targets, fast-fail tests, regenerated evidence — over the broader surface, with a similar PRD/plan artifact pair. The plan refuses to enumerate Stage 2 steps "because listing them would invite an implementer to start them early" (`plan.md:116`).

## 3. Entry gate to Stage 2

Two-gated. **Documented gate:** the owner explicitly declares satisfaction with Stage-1 outputs (`PRD.md:162`, `plan.md:114`). **Procedural gate:** a separate, explicitly authorized implementation session (the Stage-2 PRD/plan pair is not yet authored — `plan.md:116`). No automatic handoff from green Stage-1 tests; green is necessary but not sufficient.

## 4. Broader APEX scope (what Stage 2 covers)

Explicit (`PRD.md:160, 162`; `plan.md:31`): the 108 original APEX criteria, the full hook × SE matrix recount, broader changes, and the new vaults (FullSpread hookless + Pons-family + wings). Implicit/uncertain: catalog classes A–K, A0, L, M, N, O on surfaces whose tests were not read (`PRD.md:345`); receipt-backed dispatch, Morpho burn sites, Stata/Aave loop capacity, Lido/Rocket/EtherFi prechecks, Balancer D68/D69 transition quotes (`PRD.md:343`); live chain-4663 historical fork inventory (`PRD.md:342`).

## 5. Acceptance criteria

**Stage 1** (explicit per REQ-01…REQ-08 in `PRD.md:198-203, 215-219, 230-234, 246-250, 263-267, 280-285, 299-303, 316-321`): each REQ names exact assertions + non-goals. Stage-1 completion additionally requires the OD-08 evidence run (`PRD.md:186, :316-321`; `plan.md:91-95`).

**Stage 2** acceptance criteria are **not specified** in either document. What is specified is the bar Stage 2 must satisfy: "the broader changes and the new vaults meet the same standard" as Stage 1 (`PRD.md:162`), audit submission waits for that pass, and `PRD.md:22` limits the threat-model bar to the locked plan + the seven audit findings + two retractions + named adversarial catalog classes.

## 6. Uncertainties / open items explicitly named

- Stage 2 acceptance criteria and step list (deliberately deferred, `plan.md:116`).
- The 34,909/0/33/195/1/7 historical counts are **unverified**; documentary counts conflict (`PRD.md:37, 329, :341`).
- `supportsInterface` probe at `UniswapV4DetfCommon.sol:669-678` is **not decided** under this PRD (`PRD.md:194, 203`; `plan.md:36, 120`).
- Binding the wings vault to a Pons-configured pool is **open follow-on** (`PRD.md:153`; `plan.md:121`).
- D12 (non-atomic contract pretransfer including EIP-7702) is an **accepted residual** (`PRD.md:78`; skill `indexedex-testing/SKILL.md:175`).
- Live chain-4663 instances immutable; replacement tests are not deployment remediation (`PRD.md:77, 352`).
- D57 Slipstream deprecation is not a missed rewrite (`PRD.md:79`).
- `LocalCreditLib` matches D11 on the read path only; consumer families not closed (`PRD.md:81, 358`).
- Audit items APEX-2026-003 (test precision), -008 (five-site execution), -009 (whole-balance refund removal), -004B (dust-to-fee helpers), `-001-M` stale-reserve closure remain unconfirmed or partially confirmed (`PRD.md:352-360`).
- Kimi F3 silent `try`/`catch` at `TokenStakingTarget.sol:452` (`synchronizeRewards`) is not removed under this PRD absent a later D16/D37 ruling (`PRD.md:333`).
- Kimi F4 dangling `lib/crane/.grok/skills/` symlinks — hygiene, not APEX money-path (`PRD.md:334`).
- Astra-04 arithmetic recheck (`PRD.md:289`), MiniMax M3-03 R4.2/4.3/4.5 PARTIAL — unverified follow-up pass (`PRD.md:331`).

## Distinguishing explicit vs inferred

**Explicit:** Stage 2 exists; it reopens the APEX program; it covers broader scope and the new vaults; it must precede audit submission; it inherits OD-07's test discipline; its entry is owner judgment after Stage 1; OD-08 overrides older sentences; threat-model bar is the locked plan + named findings + catalog classes.

**Inferred (operationalization, not stated):** Stage 2 will likely follow the same repair-then-fast-fail pattern as Stage 1 and produce its own PRD/plan pair. Stage 2 acceptance will likely require a regenerated evidence run analogous to Stage 1's. The wings vault → Pons pool binding question will likely surface again in Stage 2 because OD-05 leaves it open.

**Confidence:** high on the structural split and the named rulings; medium on what Stage 2's deliverable surface looks like (deliberately under-specified); high on what is **not** decided here.
