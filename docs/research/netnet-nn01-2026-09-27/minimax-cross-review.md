# MiniMax M3 — NN-01 Cross-Review (Bounded Round)

> Cross-review of three peer originals for NN-01 (PRD_OPEN_QUESTIONS.md lines 67–72). Read `astra-original.md`, `grok-original.md`, `kimi-original.md` together. Earlier cross-review artifacts not consulted. My `minimax-original.md` is the baseline; I cross-check each peer's claims, attribute corrections, and report convergence/dissent. Research-only; routing metadata `minimax/MiniMax-M3` only (not provider attestation).

---

## 1. Convergence (four-of-four agreement)

All four originals converge on the same core position. **NN-01 is a manifest artifact with evidence classes; it is not a request to redesign or deploy.** Specific points of agreement:

1. **PRD §16 line 931 caveat ("inspected snapshots, not immutable pins") is the central gap.** Every peer names this as the failure mode NN-01 exists to prevent.
2. **A package name, token symbol, Solidity pragma, or historical research address is NOT a release pin.** This is the operative closure test (Astra §3 "Design closure"; Grok §1 "Three different jobs get mixed up"; Kimi §3 class A; me §4 "Practical avoidance rule").
3. **PRD §8 BEFORE-IMPLEMENTATION verification requirement must be preserved as a recorded obligation, not silently postponed.** Astra: "PRD §8's existing before-implementation verification requirement for the canonical pool is not silently postponed; NN-01 must record it as pending if no authorized evidence exists." Grok: "LIVE pair/factory/oracle still verified before production." Kimi: "Tier 2 execution is scheduled pre-deployment work, explicitly pending — recording it is not claiming it passed." Me §3.2: closure = observation block + queried value.
4. **Canonical pair `0x59F95461E68e0c77605299791E1449f175165B54` is SELECTED but unverified live.** All four handle this identically: the address is selected, recording it is not verifying it. **It is not an invitation to substitute a different pair.**
5. **New custom components need no deployed addresses for design closure.** Grok: "No pre-existing 4663 address required to close this table." Kimi: "Absence of an address today is expected, not a gap." Me §3.3.
6. **Owner trigger is narrow: only if a required dependency class cannot be bound or bound bytecode materially lacks a capability the PRD already selected.** (Astra §Narrow checkpoint; Grok §6; Kimi §6; me §5.5.) Do not re-ask family approval.
7. **Don't reopen PkgInit/PkgArgs/discovery split, Keep-YT routing, four-leg HLP, fixed salt `"NET-DETF"` or any settled economics.** All four agree.

---

## 2. Class taxonomy: 4 (me/Grok) vs 5 (Kimi) vs 2 (Astra)

| Peer | Classes | Distinction |
| --- | --- | --- |
| Astra | 2 layers | design/source baseline + deployment evidence |
| Grok | 4 statuses | DESIGN / CAPABILITY / LIVE / GAP |
| Kimi | 5 classes | A fixed source, B live, C new component, D rollover-changing, E dynamic external state |
| Me | 4 classes | fixed source, live, new component, state-bound |

The differences are presentational, not substantive. **Kimi's five-class split is sharpest**: separating **D (rollover-changing)** from **E (dynamic external state)** is correct because D requires a re-validation procedure (factory-recognition + `readTokens()` + expiry check) invoked at every rollover, while E requires a runtime lookup rule (`taxEnabled()` at call-time; `feeTo()` dynamic; three-tier oracle resolution) — they are different closure shapes. I recommend Kimi's A/B/C/D/E taxonomy for the PRD amendment. Astra's "two-layer evidence" framing is compatible and could be combined (Tier 1 = A+C+D with `DESIGN`/`CAPABILITY` markers; Tier 2 = B+E live observations).

---

## 3. Where my original needs correction (attributed)

- **"Manifest complete" vs "dependency gate passed" must be explicitly named.** Astra names this distinction (line 41: "Recommend distinguishing manifest complete from dependency gate passed so an honestly documented blocker never reads as deployment readiness"). Kimi names it (line 53: "Explicit blocking gaps are valid closure content"). I implied it without naming; correct this.
- **Vendored trees need provenance beyond a single commit hash.** Kimi §3 class A: "vendor snapshot date + upstream URL + upstream commit where known for vendored trees." Better than my "pinned local commit + compatibility claim" alone. Apply to Pendle/Balancer vendored sources (PRD §16 E15–E16).
- **Placement: prefer §4.1.1 (anchor) over §16.1 (appendix).** Kimi's proposed amendment anchors at §4.1.1 (next to the PkgInit/PkgArgs split). Grok and I placed at §16.1 (next to evidence register). Kimi's placement keeps the manifest next to the configuration it documents and makes the "before executable planning" requirement structurally visible. Recommend §4.1.1 over §16.1.
- **Don't invent deployment architecture or extra NFT contracts.** Prompt's explicit caution. PRD only specifies two NFTs (wrapping NFT for external bonds; bond NFT for internal bonds). None of the four originals invent extra NFT contracts; all stay within scope. I correctly did not add NFT contracts beyond what the PRD names.

---

## 4. Genuine dissent

**None that reopens settled owner economics.** One presentation difference: Astra emphasizes a `NOT YET DEPLOYED` label for new components; Kimi argues "absence of an address today is expected, not a gap." Same conclusion (don't block design on addresses); different rhetorical framing. Kimi's framing is preferable because the closure criterion is *what evidence exists*, not *whether a label is alarming*.

---

## 5. Plain-English recommendation (narrowly scoped, UNAPPROVED PRD paragraph)

Recommend placing the new manifest amendment at **PRD §4.1.1** (not §16.1), using **Kimi's five-class taxonomy (A–E)** plus **Astra's "manifest complete ≠ dependency gate passed" distinction**, with **Kimi's vendor-tree provenance rule** (snapshot date + upstream URL + commit where known). The single §4.1.1 paragraph below consolidates the four originals' convergence.

```markdown
### 4.1.1 Dependency and evidence manifest (NN-01) — UNAPPROVED

Maintain a two-tier dependency manifest preserving §4.1's selected PkgInit/PkgArgs/discovery split. **Tier 1 (design-time)** records, for every dependency: role, evidence class (A fixed source/interface design; B live deployment verification; C new component; D rollover-changing; E dynamic external state), source of truth (PkgInit, PkgArgs, validated market discovery, computed deployment, or dynamic oracle resolution), a source-revision pin (repository commit hash for IndexedEx paths; vendor snapshot date + upstream URL + upstream commit where known for vendored Pendle/Balancer trees), and required capabilities. **Tier 2 (pre-deployment checklist)** records, for every class-B and class-E fact: verification method, acceptance predicate, observation-block field, and status (verified / open / blocked). Class values MUST NOT be conflated: a package name, token symbol, pragma, historical address or unpinned `main`/`master` link is not a release pin; a local source inspection is not deployed-chain equivalence; a resolved oracle value at one block is not a configuration constant. Class-D dependencies are pinned by re-validation procedure, not address. Class-C components are recorded by deployment path, salt/flag derivation and post-deploy verification step; absence of an address today is expected, not a gap.

NN-01 closes when Tier 1 is complete and every Tier 2 item carries evidence or an explicit blocking gap. **Manifest completion is not deployment readiness.** Class-B facts (including the §8 canonical NET/USDG V2 pool and §12.1 BondDepository vesting) require the PRD's recorded verification before reliance; NN-01 records them as pending if no authorized evidence exists. Tier 2 execution remains separately scheduled pre-deployment work. This manifest adds no token allowlist, administration power or redundant configuration.
```

---

## 6. Narrow human checkpoint

> Is the five-class dependency taxonomy (A fixed source / B live / C new component / D rollover-changing / E dynamic external state) with a two-tier closure rule (Tier 1 design-time completeness + Tier 2 enumerated pre-deployment checklist with explicit blocking gaps) and the **manifest complete ≠ dependency gate passed** distinction acceptable as the NN-01 closure standard? Placement: new §4.1.1. No addresses, decimals, fees or live values requested.

Owner trigger (unchanged): only if a class-C/D dependency cannot be bound on 4663 or bound bytecode materially lacks a capability the PRD already selected.

---

## 7. Confidence and evidence limits

- **High** on the four-of-four convergence and the proposed amendment's compatibility with PRD §4.1, §8, §12.1, §16.
- **Medium** on Kimi's §4.1.1 placement preference vs. my §16.1 — both work; §4.1.1 is structurally clearer.
- **Not verified**: any live 4663 address, code hash, fee, exemption state or deployed equivalence. PRD §16 line 966 confirms none was certified.
- **Not asserting**: `docs/plans/detf/` exists (verified absent by prior council work).
- **Not reopening**: any settled owner decision (FoT NET, rebasing sNET, Keep-YT ingress, shared-SY egress, four-leg HLP, atomic rollover, principal cliffs, native-wrapper exception, hold-interest-token, non-blocking fee forwarding, public HLP, DETF-as-SY, fixed `NET-DETF` salt, canonical pair `0x59F95461…` as PRD's selected-but-unverified address).

**Saved file:** `docs/research/netnet-nn01-2026-09-27/minimax-cross-review.md`. Original `minimax-original.md` untouched.
