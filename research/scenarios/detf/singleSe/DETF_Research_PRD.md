# Product Requirements Document (PRD)

## Title

Single Standard Exchange DETF — Lifecycle, Policy/Open Gates, Primary-Market Honesty, Protocol Compound, and Natural Expansion Research

## Status

**PHASE 3 COMPLETE** (2026-07-30) — hermetic D0–D9 evidence locked. Does not change production DETF packages.

| Field | Value |
|-------|--------|
| **Campaign id** | `detf/singleSe` |
| **Created** | 2026-07-29 |
| **Updated** | 2026-07-30 — protocol compound + natural supply expansion product law |
| **Horizon** | Hours to ~1 day agent execution (not multi-week process) |
| **Portfolio program** | [`research/papers/detf-litepaper/RESEARCH_AND_WRITING_PROGRAM.md`](../../../papers/detf-litepaper/RESEARCH_AND_WRITING_PROGRAM.md) |
| **Product PRD (SUT)** | [`SingleStandardExchangeDETF_PRD.md`](../../../../contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_PRD.md) |
| **Threshold law** | [`DETF_Threshold_Modes_PRD.md`](../../../../contracts/vaults/detf/DETF_Threshold_Modes_PRD.md) (**LOCKED**) |
| **Compound + expansion law** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](../../../../docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) (**LOCKED**); docs handoff: [`DETF_Protocol_Compound_And_Supply_Expansion_HANDOFF_FOR_DOCS_AND_UI.md`](../../../../docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_HANDOFF_FOR_DOCS_AND_UI.md) |
| **Narrative / non-claims** | [`docs/marketing/DETF_NARRATIVE_SPINE.md`](../../../../docs/marketing/DETF_NARRATIVE_SPINE.md) |
| **Methodology** | [`research/RESEARCH_PLAYBOOK.md`](../../../RESEARCH_PLAYBOOK.md) Tier 5 |
| **SE rails (reuse, do not re-run)** | [`rateProviderCompare/AGENT_RESEARCH_REPORT.md`](../../uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md) |
| **Phase 3 PRD** | [`DETF_Research_Phase3_PRD.md`](./DETF_Research_Phase3_PRD.md) — Phase 3 harness + **D0–D9** done bar |
| **Implementation plan** | [`DETF_Research_Phase3_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_Research_Phase3_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **Findings (after runs)** | [`FINDINGS.md`](./FINDINGS.md) — create when Phase 3 locks |
| **Agent handoff** | [`AGENT_RESEARCH_REPORT.md`](./AGENT_RESEARCH_REPORT.md) — create when campaign locks |

**Conflict rule:** Product PRDs (including threshold modes **and** protocol compound / natural expansion) win on behavior. Chart conventions in `research/README.md` win on framing. Narrative spine + compound/expansion handoff win on public claim language.

---

## Progress

*Update this section as work completes. Spec sections below stay stable unless PRD is revised.*

| Checkpoint | Status | Notes |
|------------|--------|-------|
| PRD authored | **done** | 2026-07-29 |
| Phase 0 brief / claims freeze (paper portfolio) | pending | Optional short `papers/detf-litepaper/BRIEF.md` |
| SE figure harvest for litepaper appendix | pending | Cite existing rateProviderCompare; no new SE matrix |
| Formal definitions snippet | pending | Synthetic + Policy/Open predicates (writing) |
| Research harness fixture | **done** | `ResearchFixture_DetfSingleSeUniV2` (Uni V2 SE) |
| Telemetry + runner | **done** | `./research/run_detf_single_se.sh` |
| **D0** inert deploy | **done** | PASS |
| **D1** first bond → live | **done** | PASS |
| **D2** Policy mint blocked (deadband) | **done** | burn-side post-bond (not deadband); mint blocked |
| **D3** Policy mint allowed + preview==exec | **done** | exact preview==exec |
| **D4** Policy burn blocked / allowed | **done** | PASS |
| **D5** Open control twin | **done** | no natural expansion |
| **D6** capital seigniorage dilution | **done** | PASS |
| **D7** bond vs mint books | **done** | PASS |
| **D8** natural expansion (Policy + rich + time) | **done** | PASS |
| **D9** protocol compound → protocol BPT | **done** | PASS |
| Plots F1–F4 | **done** | `out/detf/singleSe/figures/` |
| Plots F7–F9 (bond / expansion / compound) | **done** | F7–F9 |
| FINDINGS.md + SCENARIO_LOG rows | **done** | RQ1–RQ10 |
| Litepaper draft sections from this campaign | pending | Portfolio Phase 4 |

**Next action:** Portfolio Phase 4 litepaper prose from FINDINGS — do not casually re-run D0–D9.

---

## Results summary (living)

| ID | Result | Artifact |
|----|--------|----------|
| D0–D9 | **PASS** — see [`FINDINGS.md`](./FINDINGS.md) RQ1–RQ10 | `research/out/detf/singleSe/` |
| D0 | inert, default thresholds, mint reverts | `D0_inert/` |
| D1 | first bond → live | `D1_firstBond/` |
| D2 | burn-side post-bond; mint blocked | `D2_policyDeadband/` |
| D3 | mint-allowed; preview==exec exact | `D3_policyMintAllowed/` |
| D4 | burn when synth < burnTh | `D4_policyBurnGate/` |
| D5 | Open mint/burn; no expansion | `D5_openControl/` |
| D6 | capital seigniorage supply ↑ | `D6_capitalSeigniorage/` |
| D7 | free holder no expansion airdrop | `D7_bondVsMint/` |
| D8 | Policy expansion; Open twin no | `D8_naturalExpansion/` |
| D9 | protocol BPT principal ↑ | `D9_protocolCompound/` |

**Headline for agents (locked):** Hermetic Single SE DETF + Uni V2 SE: inert→live, Policy gates, exact mint preview, Open never expands, Policy expands when mint-rich, protocol compound raises protocol BPT. No APY/peg claims.

---

## Purpose

Produce **reviewable, reconstructable hermetic evidence** that the **Single Standard Exchange DETF** product pattern behaves as publicly claimed:

1. Deploy **inert**; **first bond** with vault shares takes the instance **live** and deepens protocol-owned reserve.
2. **Policy** gates primary mint/burn on **synthetic** price (default ±5% deadband); **Open** does not price-gate mint/burn (fees may still apply).
3. Closed-form vault-share ↔ DETF primary routes aim for **preview = execution**.
4. Synthetic valuation is **reserve-derived** (not an off-pool admin NAV).
5. **Natural supply expansion** (time-based free DETF to **bond** reward ledger) may accrue only when **Policy + live + synthetic > mintThreshold**; **never** on Open, inert, or non-rich Policy; **not** paid to unlocked free DETF holders.
6. **Protocol compound** sinks protocol NFT free DETF rewards into **more protocol-owned reserve BPT** (single-sided DETF join); users still **claim** free DETF on their bonds; fee-recipient NFT is not auto-compounded in v1.

Results feed the DETF **litepaper** (§ measured DETF scenarios) and agent handoff. They do **not** claim mainnet APY, peg guarantees, claim APY, or Protocol DETF fee size.

### Why this campaign exists

| Prior work | What it proved | What it did **not** prove |
|------------|----------------|---------------------------|
| Uni V2 SE Mode A / rateProviderCompare | Nested SE re-mark; R+ residual ≈ 0; fee as arb threshold | DETF synthetic gates, bond→live, seigniorage mint |
| DualLiquidity research | Nested multi-SE composition + share book | Full DETF Policy/Open / bond NFT seigniorage |
| Frontend `/research/detf` | Public product education | Measured DETF scenario figures; expansion/compound copy lag |
| Gold unit/integration tests | Correctness under test harnesses (incl. ProtocolCompound / NaturalExpansion suites) | Research-grade JSONL + paper figures + claim-safe FINDINGS |
| Compound + expansion PRD (LOCKED) | Product law shipped Stages 00–09 | Hermetic research figures for expansion/compound path |

Playbook **Tier 5 (DETF)** was explicitly **not started**. This PRD starts it for **one gold family only**.

### Research questions (normative)

| ID | Question |
|----|----------|
| **RQ1** | Does a fresh deploy stay **inert** (mint of user DETF against vault shares blocked) until first successful bond? |
| **RQ2** | Does first bond with **standardExchangeVaultShare** set `isReserveLive`, establish protocol-owned depth / bond principal accounting, and enable the live surface? |
| **RQ3** | Under **Policy** + **default resolved thresholds**, is mint blocked when synthetic is in the deadband and allowed only when synthetic is **strictly above** mintThreshold? |
| **RQ4** | Under Policy, is burn blocked in the deadband / above burn band and allowed only when synthetic is **strictly below** burnThreshold? |
| **RQ5** | Can synthetic be moved across thresholds by **production market paths only** (no Open cheat, no deal-seed, no storage hacks)? *Empirics:* Uni V2 trades alone are insufficient from post-bond free-DETF dilution; free-DETF primary burns (when burn-allowed) + Uni trades is the measured path. |
| **RQ6** | On a successful closed-form mint, does **preview amount equal execution** (exact preferred; document ≤ few-wei only if forced)? |
| **RQ7** | Under **Open**, with the same shock path, do primary mint and burn remain available **without** synthetic price gates (fees may still apply)? |
| **RQ8** | Does **natural expansion** accrue only under **Policy + live + synthetic > mintThreshold**, and **not** under Open, inert, or non-rich Policy (including after time warp)? |
| **RQ9** | Does expansion credit the **bond reward ledger** (not unlocked free DETF holders), and can users still **claim** free DETF while locked? |
| **RQ10** | Does **protocol compound** (automatic and/or `compoundProtocolRewards`) convert protocol NFT rewards into **more protocol-owned reserve BPT** rather than long-lived free DETF on the protocol NFT? |

**Campaign science coverage:** RQ1–RQ10 via scenarios **D0–D9**.  
**Phase 3 done bar:** full **D0–D9** + figures F1–F4 and F7–F9 — see [`DETF_Research_Phase3_PRD.md`](./DETF_Research_Phase3_PRD.md).

---

## SUT and naming

### Subject under test

| Item | Identity |
|------|----------|
| Family | Single Standard Exchange DETF |
| Package | `SingleStandardExchangeDETDFPkg` / registry deploy path |
| Code root | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/` (**not** `composed/single`) |
| Gold TestBase | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol` |
| Default SE attachment (research) | **Uni V2 Standard Exchange** (WETH/USDC-style hermetic path) for narrative continuity with SE rateProviderCompare / Mode A — **real SE, not mock**. TestBase default Aero DAI/USDC is **not** the research gold attachment unless re-locked. |
| Info / bond / exchange surfaces | `ISingleStandardExchangeDETFInfo`, bonding target, `IStandardExchangeIn` |

### Role names (mandatory)

| Role | Meaning |
|------|---------|
| `detfToken` / `address(this)` | DETF diamond ERC-20 |
| `standardExchangeVault` | Attached SE vault |
| `standardExchangeVaultShare` / `vaultShare` | SE share (often vault address) |
| `rateTarget` / `rateAsset` | Rate denomination of the vault share leg |
| `reservePool` / `reserveBpt` | Weighted reserve + BPT |
| `bondNftVault` | Bond NFT vault package surface |
| **protocol / detf-owned NFT** | System bond position; rewards **auto-compound** into protocol BPT |
| **fee-recipient NFT** | Fee position; rewards stay claimable free DETF (no auto-compound v1) |
| **user bond NFT** | Retail locked position; **claim free DETF** (seigniorage ± expansion) |
| **natural expansion** | Time-based free DETF to bond effective shares when Policy + rich |
| **protocol compound** | Protocol NFT free DETF rewards → single-sided DETF join → more protocol BPT |
| **capital seigniorage** | Free DETF rewards from others’ mint/bond capital (distinct from expansion) |

**Anti-patterns:** brand token names in research contracts; `MockStandardExchange`; bypassing vault registry for the DETF package; treating DualLiquidity as this SUT; calling expansion “Open yield” or “all holder rebase.”

### What this is / is not

| Is | Is not |
|----|--------|
| True DETF: self-leg + one SE share in weighted reserve; seigniorage mint/burn | Simple pro-rata BPT claim vault |
| Policy/Open threshold modes on synthetic | Off-pool multi-asset FX ledger |
| Inert → first bond → live | Admin “bootstrap mode” product |
| Natural expansion when Policy + rich (bond ledger only) | Expansion for unlocked free DETF or Open mode |
| Protocol compound → protocol BPT depth | User-forced auto-compound; guaranteed claim APY |
| Research forge **scripts** + offline plots | Replacement for unit/integration test suite |
| Evidence for litepaper | Mainnet performance study |

---

## Locked decisions

Do not re-open without an explicit PRD revision.

| Topic | Decision |
|-------|----------|
| Gold family | **Single Standard Exchange DETF only** for this campaign |
| Deploy path | Production-first: CREATE3 facets + `indexedexManager` / registry DFPkg + instance deploy — **no** `new` package/facets; **no** mock SUT |
| Fixture base | Inherit / compose from `TestBase_SingleStandardExchangeDETF` (or thin research fixture that reuses the same deploy helpers) |
| Environment | **Hermetic** production ports (TestBase chain). Fork only if hermetic blocks a required drive; then PRD revision |
| Foundry | `FOUNDRY_PROFILE=default` unless a documented exception |
| Thresholds (Policy) | **Default resolve:** mint 1.05e18 / burn 0.95e18 via `DETFThresholdPolicy` — do **not** use Open-only deploys as sole proof of gates |
| ThresholdMode | Explicit Policy vs Open instances; never infer Open from zero thresholds |
| **Synthetic drive for D3/D4/D8** | **Production paths only:** free-DETF primary burns when burn-allowed (unwind bond free-DETF dilution from product mint-split) + real Uni V2 trades on attached underlyings. **No** Open thresholds, deal-seed DETF, storage hacks, or fake oracles. *Empirics:* Uni trades alone cannot clear mintThreshold from post-bond synth ~0.625 (RQ5 PARTIAL). |
| **SE attachment** | **Uni V2 SE** for narrative continuity with Mode A / rateProviderCompare (not TestBase Aero default) |
| **D2 (deadband)** | **Flexible:** record gate state at `t_live` after first bond. If synthetic already mint-allowed, D2 is **N/A** or opportunistic deadband only if easy; full Policy gate story still rests on D3/D4 |
| **Figure deliverables** | **Must ship PNG plots F1–F4** before campaign is done (not tables-only) |
| First bond | Vault shares (family path); first bond **ungated** by synthetic supply rules per product law |
| Open twin | Separate deploy world; same Uni V2 SE attachment topology; compare under analogous demand where possible; **must assert no natural expansion** |
| Primary book metrics | `isReserveLive`, `syntheticPrice`, `thresholdMode`, `isMintingAllowed` / burn allowed, supply, preview vs execution, bond position flags |
| **Natural expansion** | Accrues only **Policy + live + synthetic > mintThreshold**; time-based; bond effective shares; deploy-time params; **Open never**; inert never; non-rich Policy never; not paid to free DETF-only holders |
| **Protocol compound** | Protocol NFT rewards → single-sided DETF join → protocol BPT; keeper-free on touches + public `compoundProtocolRewards`; best-effort retry; user bonds still claim free DETF; fee-recipient not auto-compounded v1 |
| **Expansion vs capital seigniorage** | Research must **label separately**: capital-backed rewards (others mint/bond) vs natural expansion (time when rich) |
| Nested mark integrity | **Cite** Uni V2 SE rateProviderCompare — **do not** rebuild SE matrices in this campaign; DETF fixture **shares Uni V2 SE story** for continuity |
| Artifacts | `research/out/detf/singleSe/<runId>/` only |
| Tracked narrative | `research/scenarios/detf/singleSe/` |
| Scripts | `scripts/foundry/research/detf/singleSe/` |
| Runner | `research/run_detf_single_se.sh` (when added) |
| Charts | One story per figure; raw market direction; no APY; caption states mechanism; **PNG required for F1–F4** |
| Multi-family types | Out of scope (taxonomy only in paper writing — **four live families only**) |
| **Removed package** | `contracts/vaults/detf/composed/single` (**SingleVaultDetf**) is **not** in this campaign: not SUT, not fixture base, not behavioral research reference, not a type in paper taxonomy |
| Gold path disambiguation | Empirics use **`standardExchange/single`** (`SingleStandardExchangeDETF` + `TestBase_SingleStandardExchangeDETF`) — **never** `composed/single` |
| Monte Carlo / APY | Out of scope — including expansion “yield” and claim “coupon” narratives |
| Production package edits | Out of scope unless a true product bug blocks research (separate product PR) |

---

## Scope

### In scope (v1 / litepaper minimum)

- Research fixture + scripts for D0–D5  
- Policy instance with default thresholds  
- Open instance for D5  
- **Expansion negative checks** on D0 / D2 (if deadband) / D5 (Open + time warp when rich if applicable)  
- Telemetry JSONL + `meta.json` (git commit, mode, script id; expansion/compound fields when sampled)  
- PNG plots F1–F4  
- FINDINGS + SCENARIO_LOG  
- Implementation notes in this PRD  
- Product-law citations for compound + expansion in FINDINGS even before D8/D9  

### Out of scope (v1)

- Multi-vault weighted / mixed-buffer / multi-vault stable (composed) DETF empirics  
- **Anything under `contracts/vaults/detf/composed/single`** (package removed / removing — do not restore for research)  
- Re-running rateProviderCompare or DualLiquidity matrices  
- Mode B/C SE expansion for marketing  
- Full claim redeem stress / mainnet claim APY (optional light D9 BPT delta only)  
- Protocol DETF fee accrual measurement  
- Frontend R4 shipping (paper portfolio Phase 5)  
- Novel AMM math / LVR re-derivation  
- Marketing expansion as guaranteed rebase / OHM affiliation  

### Extended scenarios (required for Phase 3 done)

| ID | Spec |
|----|------|
| D6 | Capital seigniorage dilution series (supply, synthetic, composition from **primary mints**) |
| D7 | Parallel mint vs bond books (free DETF vs bond rewards / expansion eligibility) |
| **D8** | **Natural expansion positive path:** Policy + rich (real trades) + time warp → bond `pendingRewards` rise |
| **D9** | **Protocol compound:** accrue rewards on protocol path → compound → protocol-owned BPT ↑ |

---

## Scenarios (normative)

### D0 — Inert deploy

| Field | Spec |
|-------|------|
| **Setup** | Deploy DETF Policy instance via production path; **no** first bond |
| **Assert** | `isReserveLive() == false`; primary mint of user DETF against vault shares **reverts or is disallowed**; **no natural expansion** after optional short time warp (RQ8 negative) |
| **Telemetry** | live flag, synthetic if defined pre-live, mode, thresholds |
| **RQ** | RQ1, RQ8 (negative) |

### D1 — First bond → live

| Field | Spec |
|-------|------|
| **Setup** | From D0 world (or fresh inert); fund actor with vault shares; execute family first-bond path |
| **Assert** | `isReserveLive() == true`; bond principal / protocol-owned depth accounting consistent with product PRD; residual free inventory on diamond documented (BPT on diamond may remain per family rules); protocol NFT wiring present when package requires it |
| **Telemetry** | live flag, supply, bond NFT state, synthetic post-live, protocol NFT id if available |
| **RQ** | RQ2 |

### D2 — Policy mint blocked (deadband)

| Field | Spec |
|-------|------|
| **Setup** | Live Policy instance; record synthetic + gates at `t_live` (after first bond) |
| **Assert** | If synthetic in deadband: `isMintingAllowed() == false` (or equivalent); mint attempt reverts / blocked; **no expansion accrual** after short warp (RQ8 negative). **If already mint-allowed:** mark D2 **N/A**, document synth level, do not force deadband |
| **RQ** | RQ3 (when deadband observed); RQ8 (negative when deadband) |

### D3 — Policy mint allowed + preview honesty

| Field | Spec |
|-------|------|
| **Setup** | From live Policy; drive synthetic **> mintThreshold** via production free-DETF burns (when burn-allowed) + real Uni V2 trades |
| **Assert** | `isMintingAllowed() == true`; mint succeeds; **preview == execution** (exact preferred). Note: expansion **may** become eligible once rich—do not conflate capital seigniorage from this mint with expansion (label in NOTES) |
| **Telemetry** | synthetic series vs thresholds; mint amounts; preview/exec pair; optional pendingRewards snapshot |
| **RQ** | RQ3, RQ5, RQ6 |

### D4 — Policy burn gate

| Field | Spec |
|-------|------|
| **Setup** | Live Policy; move synthetic **below burnThreshold** via production paths (capital dilution mints when mint-allowed + real Uni V2 trades) |
| **Assert** | Burn allowed only when synthetic strictly cheap; blocked in deadband / rich region as per Policy; **no expansion** while not mint-rich (RQ8 negative under cheap/deadband) |
| **RQ** | RQ4, RQ5, RQ8 (negative when not rich) |

### D5 — Open control (+ no expansion)

| Field | Spec |
|-------|------|
| **Setup** | Separate **Open** instance; bring live via first bond; apply comparable synthetic stress where possible (real trades); **time warp** while synthetic would be “rich” on a Policy twin if measurable |
| **Assert** | Primary mint and burn **not** blocked by synthetic price gates when live; fees may still apply (do not claim fee-free); **natural expansion does not accrue** (RQ8 Open negative)—bond pendingRewards must not grow from expansion path |
| **Telemetry** | mode=Open; gates; supply; pendingRewards before/after warp; synthetic |
| **RQ** | RQ7, RQ8 (Open negative) |

### D6 — Capital seigniorage dilution (Phase 3 required)

Sequence of allowed **Policy primary mints** (capital-backed seigniorage); record supply, synthetic, reserve composition. **Label separately** from natural expansion.

### D7 — Bond vs mint books (Phase 3 required)

Two actors: **minter** receives free DETF (no bond); **bonder** holds NFT. After capital seigniorage and/or expansion window: only bonder earns bond-ledger rewards; free DETF-only holder does **not** receive expansion airdrop (RQ9).

### D8 — Natural expansion positive path (Phase 3 required)

| Field | Spec |
|-------|------|
| **Setup** | Live **Policy**; drive synthetic **> mintThreshold** via production free-DETF burns (when burn-allowed) + real Uni V2 trades; hold user bond; `vm.warp` (or multi-touch accrual) under deploy-time expansion params |
| **Assert** | Bond `pendingRewards` (or claimable free DETF after sync) **increase** from expansion path; Open twin under same warp does not; document rate/cap params used |
| **RQ** | RQ8 (positive), RQ9 |

### D9 — Protocol compound (Phase 3 required)

| Field | Spec |
|-------|------|
| **Setup** | Live instance with protocol NFT accruing rewards (seigniorage and/or expansion as applicable); call touch path and/or `compoundProtocolRewards` |
| **Assert** | Protocol-owned **reserve BPT** (or documented protocol depth metric) **increases**; protocol NFT does not retain long-lived free DETF inventory as the product sink; user bond still claimable free DETF |
| **RQ** | RQ10 |

---

## Metrics dictionary

| Name | Definition | Notes |
|------|------------|-------|
| `isReserveLive` | Product liveness flag | D0/D1 |
| `syntheticPrice` | Fully diluted reserve-derived price (1e18 peg narrative) | Gates + expansion eligibility |
| `mintThreshold` / `burnThreshold` | Stored resolved thresholds | Defaults 1.05e18 / 0.95e18 |
| `thresholdMode` | Policy vs Open | Deploy-time; Open ⇒ no expansion |
| `isMintingAllowed` / burn allowed | Live-coupled gate views | Policy; expansion only when mint-rich |
| `totalSupply` | DETF supply | Capital mint dilution vs expansion |
| `previewOut` / `execOut` | Quote vs realized primary mint/burn | Honesty |
| `uniOrSeSpotIndex` (optional) | Underlying demand path index | Drive documentation |
| `pendingRewards(tokenId)` | Bond claimable free DETF after sync | Seigniorage ± expansion |
| `protocolBpt` / protocol depth | Protocol-owned reserve BPT (or documented equivalent) | Compound success metric |
| `expansionEligible` | Derived: Policy ∧ live ∧ synth > mintThreshold | Research flag |
| `lastExpansionTimestamp` (if exposed) | Advanced / debug | Optional |

---

## Figure pack (litepaper)

| Fig | Content | Scenarios | Format |
|-----|---------|-----------|--------|
| **F1** | Lifecycle strip: inert → bond → live | D0–D1 | **PNG required** |
| **F2** | Synthetic vs peg + threshold bands + allowed regions | D2–D4 | **PNG required** |
| **F3** | Underlying Uni V2 / SE demand → synthetic (Policy) | D3 | **PNG required** |
| **F4** | Preview vs execution | D3 | **PNG required** (table may accompany) |
| **F7** | Bond vs mint books / reward eligibility | D7 | PNG when D7 ships |
| **F8** | Expansion: Policy rich + time vs Open no-accrual | D5 + D8 | PNG when D8 ships (D5 table OK for negative) |
| **F9** | Protocol compound: protocol BPT before/after | D9 | PNG when D9 ships |

SE appendix figures (F5–F6 residual / fee threshold) come from **existing** rateProviderCompare — tracked in paper figure manifest, not produced by this campaign.

---

## Telemetry and artifacts

```text
research/
  scenarios/detf/singleSe/          # this PRD + FINDINGS (tracked)
  out/detf/singleSe/<runId>/        # generated (gitignored)
    meta.json
    series.jsonl
    NOTES.md                        # required when run is "done"
    *.png                           # optional
  run_detf_single_se.sh             # one-command reproduce when ready

scripts/foundry/research/detf/singleSe/
  harness/ …                        # fixture + sample helpers
  Script_D0_*.s.sol …
```

### `meta.json` (minimum)

- `campaign`: `detf/singleSe`  
- `scenarioId`: `D0` … `D9`  
- `thresholdMode`: `Policy` | `Open`  
- `gitCommit`, forge version, script id  
- threshold values after resolve  
- optional: expansion params, compound invoked true/false

### `NOTES.md` (required per run)

One-line story, setup, what charts/tables show, mechanism, caveats, reproduce commands (playbook template).

---

## Implementation notes (how — keep lean)

*If this section grows past ~1 screen of checklists, peel to `DETF_Research_IMPLEMENTATION_AND_TEST_PLAN.md`.*

### Suggested build order

1. **Fixture** — research fixture from Single SE DETF gold deploy helpers, with **Uni V2 SE** as the attached vault (not Aero TestBase default); expose detf, seVault, rateTarget, bonding, info.  
2. **Sample function** — write JSONL row: live, synthetic, thresholds, mode, supply, optional preview/exec, optional uni/se spot index, optional `pendingRewards`, optional protocol BPT.  
3. **D0 script** — deploy only; assert inert; short warp; **no expansion**; export.  
4. **D1 script** — fund Uni V2 SE shares; first bond; assert live; export.  
5. **D2** — sample gates at `t_live`; if deadband, attempt mint expect fail + no expansion; if already mint-allowed, mark N/A.  
6. **D3** — production free-DETF burns + Uni trades to push synthetic rich; mint; record preview/exec; label capital seigniorage vs expansion.  
7. **D4** — production paths to push synthetic cheap (or post-bond burn-allowed); burn path; no expansion while not rich.  
8. **D5** — Open deploy twin; mint/burn without price gate; **warp + assert no expansion**.  
9. **Plots** — produce **PNG F1–F4**; reuse `stamp_meta.py` / plot conventions where possible.  
10. **FINDINGS** — lock numbers; include expansion/compound product-law summary + negative results; SCENARIO_LOG; optional agent report.  
11. **Stretch** — D6–D9 + F7–F9 if time.  

### Production-first reminders

- Facets via CREATE3; DETF DFPkg via manager registry.  
- Real **Uni V2** SE vault (production package path); no mock SE.  
- No `vm.mockCall` on DETF/manager/registry/SE under test.  
- Role names in new code.  
- Synthetic moves: **production free-DETF burns (when burn-allowed) + Uni trades** (no Open/deal).  
- Expansion eligibility is **orthogonal** to primary mint route set but **shares** Policy mint-rich condition.  

### Acceptance (campaign / Phase 3)

**Authoritative Phase 3 done bar:** [`DETF_Research_Phase3_PRD.md`](./DETF_Research_Phase3_PRD.md) §13 — **D0–D9**, PNG **F1–F4 + F7–F9**, FINDINGS RQ1–RQ10.

Summary:

1. All **D0–D9** have `series.jsonl` + `meta.json` + `NOTES.md`.  
2. FINDINGS answers **RQ1–RQ10** (D2 N/A allowed with documentation).  
3. **PNG F1–F4 and F7–F9** exist and are reproducible.  
4. D5: Open ungated + **no expansion**; D8 expansion positive; D9 protocol compound.  
5. D3 preview ≈ execution; synthetic drive = production free-DETF burns + Uni trades (RQ5 PARTIAL on Uni-only).  
6. Runner reproduces; SCENARIO_LOG + campaign Progress/Results synced.  
7. No APY / Open expansion / all-holder rebase marketing language.  

---

## Success criteria (PRD-level)

1. Hermetic Single SE DETF research path exists without mocking SUT.  
2. Inert → live via first bond is demonstrated (RQ1–RQ2).  
3. Policy default thresholds gate mint/burn as specified (RQ3–RQ5).  
4. At least one successful Policy mint shows preview honesty (RQ6).  
5. Open twin shows no synthetic price gates on primary mint/burn when live (RQ7) **and no natural expansion** (RQ8 Open negative).  
6. Expansion negatives (inert/Open/non-rich) **and** D8 positive path measured (Phase 3).  
7. Protocol compound D9 measured (Phase 3).  
8. Findings are claim-safe and cite reproduce paths.  
9. Nested SE mark integrity is **referenced**, not re-executed.  
10. Phase 3 PRD acceptance §13 satisfied.  

---

## Non-claims (mandatory in FINDINGS and paper use)

- Not a registered securities ETF.  
- No promised APY, peg, rebase performance, or claim “coupon.”  
- Open ≠ fee-free; Open **does not** natural-expand; invents no returns.  
- Expansion is **not** paid to unlocked free DETF holders.  
- Protocol compound is **not** a guaranteed claim APY and is not user-bond auto-compound.  
- Hermetic results ≠ mainnet portfolio performance.  
- SE residual/fee findings transfer carefully across fee settings.  
- DualLiquidity is not this SUT.  
- Not a legal or product affiliation with OlympusDAO (historical analogy only if carefully framed).  

---

## Relation to paper portfolio

| Paper need | This campaign | Elsewhere |
|------------|---------------|-----------|
| Nested mark integrity (C7–C8) | Cite only | rateProviderCompare |
| Lifecycle / Policy / Open / preview (C3–C4, C6) | **D0–D5** | — |
| Natural expansion / protocol compound (C12–C13) | D5 negatives + D8/D9 stretch; product PRD | handoff + unit tests |
| Bond vs mint (C9) | D7 stretch or design-only until then | frontend bond-vs-mint note |
| Four **live** types (C10) | Out of scope | detf-types education (no `composed/single`) |
| Litepaper prose | Consumes FINDINGS | `papers/detf-litepaper/` |

---

## Status log

| Date | Event |
|------|--------|
| 2026-07-29 | PRD created; Progress empty of runs; litepaper minimum = D0–D5 |
| 2026-07-29 | Locked out removed `composed/single` / SingleVaultDetf; SUT remains `standardExchange/single` only |
| 2026-07-29 | Clarifications locked: **strict real-trade synthetic drive**; **Uni V2 SE** attachment; **D2 flexible/N/A OK**; **PNG F1–F4 required** |
| 2026-07-30 | Integrated **protocol compound** + **natural supply expansion** (LOCKED product law): RQ8–RQ10; D5 no-expansion; stretch D8/D9; vocab + non-claims |
| 2026-07-30 | Phase 3 execution PRD: [`DETF_Research_Phase3_PRD.md`](./DETF_Research_Phase3_PRD.md) — **D0–D9 all required** for Phase 3 done; one script per Di |

---

*End of PRD.*
