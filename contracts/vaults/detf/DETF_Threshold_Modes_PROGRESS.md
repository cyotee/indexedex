# DETF Threshold Modes — Progress Tracker

**Single source of truth for execution agents.** Update this file as work completes. Do not invent a second tracker.

| Field | Value |
|-------|--------|
| **Product law** | [`DETF_Threshold_Modes_PRD.md`](./DETF_Threshold_Modes_PRD.md) (**formal LOCKED 2026-07-28** + §16) |
| **Plan-agent prompt** | [`DETF_Threshold_Modes_PLAN_AGENT_PROMPT.md`](./DETF_Threshold_Modes_PLAN_AGENT_PROMPT.md) |
| **Tracker created** | 2026-07-27 |
| **Last updated** | 2026-07-28 (**P7 `done`** — Threshold Modes program P0–P7 complete) |

---

## Status legend

| Status | Meaning |
|--------|---------|
| `todo` | Not started |
| `in_progress` | Actively being implemented |
| `blocked` | Waiting on dependency or decision (note why) |
| `done` | Definition of done met; tests claimed green were run |
| `deferred` | Explicitly postponed with reason |

---

## How execution agents update this file

1. Set phase/row status to `in_progress` when starting; note agent/date in **Notes**.
2. After each meaningful milestone (lib unit tests green, family package green, suite green), update status + date + PR/commit ref.
3. Mark phase `done` only when that phase’s **definition of done** checklist is complete.
4. Do **not** re-open product decisions in this tracker — link PRD §12 / §16.
5. Keep Policy/gated suites green; Open suites are additive.

---

## Dependency graph

```text
P0 Core lib (API + pure unit tests)
  └─► P1 F1 SingleStandardExchangeDETF (gold patterns)
        ├─► P2 F2 MultiVaultWeightedDetf   } parallelizable after F1 API/patterns stable
        └─► P3 F3 MixedBufferMultiVault…  } (or after lib-only if copying F1 plan strictly)
              └─► P4 Formal PRD → LOCKED (plans accepted + P0–P3 implement waves per PRD)
                    └─► P5 F4 / F5 (+ synthetic migration F5)
                          └─► P6 F6 NatSpec / F7 audit parity-or-Out
                                └─► P7 AGENTS.md + family PRD “conforms to …” notes
```

**Notes:**

- Core lib must land (or at least its public API be fixed) before family wiring.
- F2 and F3 may implement in parallel once F1 patterns are accepted; both consume the same lib API and trailing `PkgArgs.thresholdMode`.
- Formal PRD **LOCKED** requires accepted plans for F1+F2+F3 (this planning session) **and** implementation waves per PRD §6.

---

## Plan artifacts

| Artifact | Path | Status |
|----------|------|--------|
| Core lib plan | [`core/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](./core/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) | `done` (plan only) |
| F1 plan | [`standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](./standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) | `done` (plan only) |
| F2 plan | [`composed/multi-vault-weighted/MultiVaultWeightedDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](./composed/multi-vault-weighted/MultiVaultWeightedDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) | `done` (plan only) |
| F3 plan | [`composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](./composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) | `done` (plan only) |
| F4 plan | [`composed/stable/common/ComposedStableCommonDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](./composed/stable/common/ComposedStableCommonDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) | `done` (plan only) |
| F5 plan | [`composed/single/SingleVaultDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](./composed/single/SingleVaultDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) | `done` (plan only) |
| F7 Out note | [`../seigniorage/THRESHOLD_MODES_OUT.md`](../seigniorage/THRESHOLD_MODES_OUT.md) | `done` (formal Out 2026-07-28) |

---

## Program phases

| Phase | Content | Status | Owner / notes |
|-------|---------|--------|---------------|
| **P0** | Core lib: extend `DETFThresholdPolicy` + pure unit tests | `done` | 2026-07-27 — lib + 21 pure unit tests green; `forge build` ok; 2-arg Policy wrappers kept |
| **P1** | F1 SingleStandardExchangeDETF: package + Common/Info/gates + TestBase + T1–T19 | `done` | 2026-07-27 — trailing mode, live-coupled gates, Open suite; 81/81 single/** green |
| **P2** | F2 MultiVaultWeightedDetf: same product law | `done` | 2026-07-27 — trailing mode, live-coupled gates, Open suite; 97/97 multi-vault-weighted/** green; oversight accepted |
| **P3** | F3 MixedBufferMultiVaultStableDetf: same product law | `done` | 2026-07-27 implement; **oversight PASS 2026-07-28** — re-ran 72/72 green |
| **P4** | Formal PRD status → **LOCKED** | `done` | 2026-07-28 — PRD formal LOCKED + changelog; Wave 2 P0–P3 green |
| **P5** | F4 ComposedStableCommon + F5 SingleVaultDetf (synthetic migration) | `done` | 2026-07-28 — P5a/P5b/P5c green; F5 synthetic migration + Open suite; 106/106 composed/single/** |
| **P6** | F6 IProtocolDETF NatSpec; F7 Seigniorage audit parity-or-Out | `done` | 2026-07-28 — F6 shipped; F7 **Out** (`THRESHOLD_MODES_OUT.md`); F5 smoke 106/106 |
| **P7** | AGENTS.md one-liner + family PRD “conforms to …” notes | `done` | 2026-07-28 — AGENTS Policy/Open; F1–F4 PRD + F5 plan conform notes; program complete |

#### P5 split (plans vs implement)

| Sub-phase | Content | Status |
|-----------|---------|--------|
| **P5a** | Full F4 + F5 implementation/test plans | `done` (2026-07-28) |
| **P5b** | Implement F4 ComposedStableCommonDetf (already synthetic; mode wiring) | `done` (2026-07-28) |
| **P5c** | Implement F5 SingleVaultDetf (**mandatory synthetic migration** + mode wiring) | `done` (2026-07-28) |

**P5 whole-phase `done` only when P5b + P5c green** — do not mark complete on plans alone.

### P0 — Core lib

**Plan:** `core/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`

**Definition of done:**

- [x] `ThresholdMode { Policy, Open }` in `DETFThresholdPolicy.sol`
- [x] Defaults `1.05e18` / `0.95e18` + `resolveThresholds`
- [x] Mode-aware `_isMintingAllowed` / `_isBurningAllowed` (no `live` param); Open short-circuit
- [x] Optional `_isOpenMode`; Policy-only 2-arg wrappers retained for unported families
- [x] Pure Foundry unit tests green (no diamond)
- [x] Families must not reimplement defaults / Open short-circuit

**Suggested verify:**

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/core/*Threshold*' -vv
```

### P1 — F1 SingleStandardExchangeDETF

**Plan:** `standardExchange/single/SingleStandardExchangeDETF_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`

**Definition of done:**

- [x] Trailing `PkgArgs.thresholdMode`; storage + init resolve/validate; `ThresholdModeSet` once
- [x] Common gates mode-aware; live still in family; Info: `thresholdMode()`, live-coupled `is*Allowed()`
- [x] Facet selector arrays include `thresholdMode`
- [x] Existing Policy/gated suites remain green
- [x] Open suites + named `_deployOpenModeDetf` (or rename path) cover T1–T19 as mapped
- [x] Production-first: no mocks of SUT DETF/manager/registry/fee oracle/SE vaults

**Suggested verify:**

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/standardExchange/single/**' -vv
```

**Verify result (2026-07-27):** 81 passed, 0 failed under `test/foundry/spec/vaults/detf/standardExchange/single/**`.  
Open suite: `test/foundry/spec/vaults/detf/standardExchange/single/SingleStandardExchangeDETF_ThresholdMode.t.sol`.

### P2 — F2 MultiVaultWeightedDetf

**Plan:** `composed/multi-vault-weighted/MultiVaultWeightedDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`

**Definition of done:** same product surface as F1 (mode, event, info, Open suites); multi-leg nested modes remain independent; T1–T19 mapped green.

- [x] Trailing `PkgArgs.thresholdMode`; storage + init resolve/validate; `ThresholdModeSet` once
- [x] Common gates mode-aware; live still in family; Info: `thresholdMode()`, live-coupled `is*Allowed()`
- [x] Facet selector arrays include `thresholdMode`
- [x] Existing Policy/gated + dual-path extreme suites remain green
- [x] Open suites + `_deployOpenModeDetfN` cover T1–T19 as mapped; nested mode independence smoke
- [x] Production-first: no mocks of SUT DETF/manager/registry/fee oracle/SE vaults

**Suggested verify:**

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/multi-vault-weighted/**' -vv
```

**Verify result (2026-07-27):** 97 passed, 0 failed under `test/foundry/spec/vaults/detf/composed/multi-vault-weighted/**`.  
Open suite: `test/foundry/spec/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetf_ThresholdMode.t.sol`.

### P3 — F3 MixedBufferMultiVaultStableDetf

**Plan:** `composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`

**Definition of done:** same product surface as F1/F2; Open does **not** add burn assets (buffer-only burn stays); bootstrap first bond synthetically ungated; T1–T19 mapped green.

- [x] Trailing `PkgArgs.thresholdMode`; storage + init resolve/validate; `ThresholdModeSet` once
- [x] Common gates mode-aware; live still in family; Info: `thresholdMode()`, live-coupled `is*Allowed()`
- [x] Facet selector arrays include `thresholdMode`
- [x] Open does **not** unlock vaultShare (or other non-buffer) burn routes
- [x] `bootstrapFirstBond` / first bond remains synthetically ungated
- [x] Invalid mint≤burn fixtures fixed (esp. Pricing `1,1` → `2,1`); T4 green
- [x] Existing Policy/gated suites green (esp. PriceShift T9)
- [x] Open suites + `_deployOpenModeDetfN` cover T1–T19 as mapped
- [x] Production-first: no mocks of SUT DETF/manager/registry/fee oracle/SE vaults/MixedBuffer pool

**Suggested verify:**

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/**' -vv
```

**Verify result (2026-07-27):** 72 passed, 0 failed under `test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/**`.  
Open suite: `test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetf_ThresholdMode.t.sol`.  
Fixture repairs: Pricing closed-burn `mint=2,burn=1`; Reentrancy/Nested/RateProviders always-allow → product Open (`0,0` + `thresholdMode: Open`).

**Oversight re-verify (2026-07-28):** `forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/**' -vv` → **72 passed, 0 failed**.  
Code surface checked: trailing `PkgArgs.thresholdMode`; `resolveAndRequireValidThresholds` + `requireValidThresholdMode`; `ThresholdModeSet` at postDeploy; Common live-coupled mode-aware gates; Info `thresholdMode()` + live-coupled is*; facet selectors; `_deployOpenModeDetfN` / product Open dual-path; Pricing closed-burn `2,1`; Open suite T1–T19 map incl. buffer-only burn lock + bootstrap ungated under closed mint.  
**Verdict: PASS — ready for P4.**

### P4 — Formal PRD LOCKED

**Definition of done:**

- [x] F1 + F2 + F3 threshold-mode plans accepted (planning gate — **met 2026-07-27** when plans reviewed)
- [x] Core + F1 implemented green (MVP) — P0 + P1 `done`
- [x] F2 implemented green — P2 `done` (Wave 2 partial)
- [x] F3 implemented green — P3 `done` (Wave 2 complete); oversight re-verify 2026-07-28
- [x] PRD header status → formal **LOCKED**; changelog entry — **done 2026-07-28**

### P5 — Wave 3 plans + implement

**Plans (P5a):**

- F4: [`composed/stable/common/ComposedStableCommonDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](./composed/stable/common/ComposedStableCommonDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md)
- F5: [`composed/single/SingleVaultDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](./composed/single/SingleVaultDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md)

**Implement order (recommended):** P5b F4 first (already synthetic), then P5c F5 (spot→synthetic migration risk).

### P6–P7 — Later waves

See stubs below.

---

## Program-level T1–T19 map

| ID | Case (PRD §5) | Core | F1 | F2 | F3 | F4 | F5 |
|----|---------------|------|----|----|-----|----|-----|
| T1 | Policy `0,0` → defaults + mode Policy + event | resolve unit | Deploy/Info | Deploy | Deploy | ThresholdMode | ThresholdMode + Deploy |
| T2 | Policy custom band | — | Deploy/gates | Deploy/gates | Deploy/gates | ThresholdMode | ThresholdMode |
| T3 | Open deploy | Open short-circuit unit | Open suite | Open suite | Open suite | ThresholdMode | ThresholdMode |
| T4 | Invalid `mint <= burn` after resolve | validate unit (if pure) / family init | Deploy revert | Deploy revert | Deploy revert | ThresholdMode | ThresholdMode |
| T4b | Extreme Policy `1`/`max` | — | dual-path | dual-path | dual-path | ThresholdMode extreme 2/1 | ThresholdMode 2/1 |
| T5 | Live Policy deadband (incl. equality) | Policy unit | Gates | Gates | Gates | ExchangeIn unit | ThresholdMode + MintWithWeth synthetic |
| T6 | Live Policy mint above | — | Mint happy | Mint | Mint | ExchangeIn unit | MintWithWeth + ThresholdMode |
| T7 | Live Policy burn below | — | Burn happy | Burn | Burn | Burn/Out unit | MintWithWeth burn-not-allowed |
| T8 | Inert blocked any mode | — | Deploy/Liveness | Liveness | Liveness | ThresholdMode Open inert | live=`isReservePoolInitialized` postDeploy |
| T9 | Real pool trades under default ±5% | — | PriceShift/Req | PriceShift | PriceShift | N/A (no price-shift suite) | drive synthetic (legacy ±0.5% Policy suite) |
| T9b | Info views match execution | — | Info | Info | Info | Open info + mint | ThresholdMode coupling asserts |
| T10 | Open live inside former deadband mint+burn | Open unit | Open suite | Open suite | Open suite | ThresholdMode | ThresholdMode gate views |
| T11 | Inert + Open blocked | — | Open suite | Open suite | Open suite | ThresholdMode | Open postDeploy live allows (F5 live flag) |
| T12 | Preview == execution when allowed | — | Mint/Burn | MintBurn | Mint/Burn | mint approx + harness burn | preview burn gates + MintWithWeth |
| T13 | Open mint fee/seigniorage split | — | Open suite | Open suite | Open suite | ThresholdMode | Policy mint suite (Open gate + fee path) |
| T13b | Live Open info both true | — | Open suite | Open suite | Open suite | ThresholdMode | ThresholdMode |
| T14 | No post-deploy setter | — | Guards/Adv | Guards | Guards | ThresholdMode | ThresholdMode |
| T15 | No alternate route bypass Policy | — | Guards | Guards | Guards | Open invalid route | burn gates on In/Out/preview |
| T16 | Reentrancy `IsLocked` | — | Reentrancy | Reentrancy | Reentrancy | Adv P0 remains | Adv P0 remains |
| T17 | Open round-trip mint→burn | — | Open suite | Open suite | Open suite | ThresholdMode (gate+mint) | Open gate both sides (bond-seed needed for exec) |
| T18 | Extreme Policy reports mode Policy | — | Info/Open dual | dual | dual | ThresholdMode | ThresholdMode |
| T19 | Open + non-default stored thresholds never deadband-revert | — | Open suite | Open suite | Open suite | ThresholdMode | ThresholdMode |

Concrete test names live in each family plan’s **Test map** section.

---

## Wave 3 / Wave 4 (F4–F5 plans ready; implement next)

### F4 — ComposedStableCommonDetf (Wave 3 / P5b)

| | |
|--|--|
| **Path** | `contracts/vaults/detf/composed/stable/common/` |
| **Plan** | [`ComposedStableCommonDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](./composed/stable/common/ComposedStableCommonDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **Plan status** | `done` (plan only, 2026-07-28) |
| **Implement status** | `done` (2026-07-28) |
| **Work (implement)** | Trailing `thresholdMode`; already-synthetic `_syntheticDetfEthPrice` gates; mode-aware 3-arg lib; live-coupled info; `ThresholdModeSet`; ExchangeIn **and** ExchangeOut/query sites; nested modes independent |
| **Verify** | `forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/common/**' -vv` → **116/116 pass** |

### F5 — SingleVaultDetf (Wave 3 / P5c)

| | |
|--|--|
| **Path** | `contracts/vaults/detf/composed/single/` |
| **Plan** | [`SingleVaultDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](./composed/single/SingleVaultDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **Plan status** | `done` (plan only, 2026-07-28) |
| **Implement status** | `done` (2026-07-28) |
| **Work (implement)** | **Mandatory synthetic migration** of all mint/burn gates + `is*Allowed` off spot; trailing `thresholdMode` + PkgArgs mint/burn; resolve/validate; `ThresholdModeSet`; mode-aware 3-arg lib; live-coupled info; Open suite T1–T19 |
| **Verify** | `forge test --match-path 'test/foundry/spec/vaults/detf/composed/single/**' -vv` → **106/106 pass** |

### F6 — IProtocolDETF surface (P6 / Wave 4)

| | |
|--|--|
| **Path** | `contracts/interfaces/IProtocolDETF.sol` (+ errors/proxy) |
| **Work** | NatSpec Policy vs Open + synthetic gates; `thresholdMode()` on typed surface (`ThresholdMode` from core); live-coupled `is*Allowed` NatSpec; thresholds display under Open; `RedemptionNotAllowed` independent of Open; F5 facet selector uses `IProtocolDETF.thresholdMode`. |
| **Status** | `done` (2026-07-28) |
| **Verify** | `forge build`; `forge test --match-path 'test/foundry/spec/vaults/detf/composed/single/**' -vv` |

### F7 — SeigniorageDETF (P6 / Wave 4) — **Formal Out**

| | |
|--|--|
| **Path** | `contracts/vaults/seigniorage/` |
| **Decision** | **Out** of threshold-mode implement scope (2026-07-28) |
| **Audit note** | [`THRESHOLD_MODES_OUT.md`](../seigniorage/THRESHOLD_MODES_OUT.md) |
| **Evidence (summary)** | True DETF-like chassis (diluted peg gates, RBT/sRBT); **no** mint/burn threshold or mode storage; peg mint-above / burn-at-or-below 1e18 (`PriceAbovePeg`/`PriceBelowPeg`); deploy scripts + sepolia artifacts + tests exist, but **not** on `anvil_single` modern path; frontend legacy tokenlist path; consolidation plan **reference only / out of active migration**. Parity would redesign peg economics, not thin-wire mode. |
| **Code change** | None (no half-wired mode storage) |
| **Status** | `done` — **Out** |

---

## Risks / blockers

| Risk | Mitigation | Status |
|------|------------|--------|
| Families diverge on Open short-circuit | Shared lib only; plans forbid local Open logic | Open |
| `0` thresholds misread as Open | Explicit `thresholdMode`; T1/T18 | Open |
| Extreme Policy confused with product Open | Keep dual-path tests; add `_deployOpenMode*` with `mode=Open`; T18 | Open |
| Info `is*Allowed` today ignores live | Family plans require live check in Common/Info path (PRD §4.5) | **Fixed F1–F5** |
| No `mint > burn` validation today | Add at resolve/init both modes (PRD §16.3) | **Fixed F1–F5**; F3 Pricing closed-burn → `mint=2,burn=1` |
| Extreme `mint=1`/`burn=max` dual-path illegal after pair validation | F1/F2/F3 map old always-allow helpers → product **Open** (`0,0` + `thresholdMode: Open`) | **As implemented F1–F5** |
| F5 gated on reserve spot | Mandatory synthetic migration for gates + is*Allowed | **Fixed P5c** (`_calcReserveSpotPrice` non-gate only) |
| PkgArgs ABI break (trailing field) | Update all TestBase / fork / nested struct literals | Open |
| Preview paths don’t gate today | Keep parity: execution gates; preview math may stay ungated unless family already gates — document in family plans; T12 is preview==execution when **allowed** | Open |
| Nested DETF tests encode extreme thresholds without mode field | Update nested PkgArgs when F1 lands; modes independent | Open |
| Fee-oracle threshold language in family PRDs | P7: AGENTS split oracle vs PkgArgs; family PRD conform notes | **Done P7** |

---

## Suggested execution agent order

1. **Agent A — P0:** ~~implement core lib~~ → **`done`**
2. **Agent B — P1:** ~~implement F1~~ → **`done`**
3. **Agent C — P2:** ~~implement F2~~ → **`done`** (oversight accepted 2026-07-27)
4. **Agent D — P3:** ~~implement F3 MixedBuffer~~ → **`done`** (72/72 green)
5. **Agent E — P4:** ~~formal PRD LOCKED~~ → **`done`**
6. **P5a plans:** ~~draft F4 + F5~~ → **`done`** (2026-07-28)
7. **P5b implement F4** ComposedStableCommon ← **`done` 2026-07-28**
8. **P5c F5** SingleVaultDetf ← **`done` 2026-07-28**; whole **P5 `done`**
9. **P6** F6 IProtocolDETF NatSpec / F7 Seigniorage Out ← **`done` 2026-07-28**
10. **P7** AGENTS.md + family PRD “conforms to …” notes ← **`done` 2026-07-28**

**Program complete (P0–P7).** No automatic next implementor phase; open a new initiative for frontend mode UX, F7 revival, or further fee-oracle language cleanup elsewhere.

Each agent: read PRD → this tracker → assigned plan → implement only that phase → update this file.

---

## Changelog (tracker)

| Date | Note |
|------|------|
| 2026-07-27 | Tracker created. Plans for core + F1 + F2 + F3 written. Implementation phases all `todo`. |
| 2026-07-27 | **P0 done:** `DETFThresholdPolicy` enum/defaults/resolve/validate/mode-aware allow + 2-arg Policy wrappers; `test/foundry/spec/vaults/detf/core/DETFThresholdPolicy.t.sol` 21/21 pass; `forge build` ok. P1+ still `todo`. |
| 2026-07-27 | **P1 done:** F1 trailing `thresholdMode`, resolve/validate, `ThresholdModeSet`, live-coupled mode-aware gates, Info + facet selectors, TestBase Open helpers; dual-path always-allow → product Open (mint=1/burn=max illegal under mint>burn); Open suite T1–T19 mapped; `forge test --match-path 'test/foundry/spec/vaults/detf/standardExchange/single/**'` 81/81 pass. P2+ still `todo`. |
| 2026-07-27 | **P2 done:** F2 trailing `thresholdMode`, resolve/validate, `ThresholdModeSet`, live-coupled mode-aware gates, Info + facet selectors, TestBase Open/extreme Policy helpers; dual-path always-allow → product Open (mint=1/burn=max illegal under mint>burn); Open suite T1–T19 + nested independence smoke; `forge test --match-path 'test/foundry/spec/vaults/detf/composed/multi-vault-weighted/**'` 97/97 pass. P3+ still `todo`. |
| 2026-07-27 | **Oversight:** P2 accepted for phase advance (tracker + code surface: mode storage, live-coupled Common, Open helpers, 97/97 claim). Next implementor = **P3 F3** (`DETF_Threshold_Modes_P3_F3_EXEC_AGENT_PROMPT.md`). |
| 2026-07-27 | **P3 done:** F3 trailing `thresholdMode`, resolve/validate, `ThresholdModeSet`, live-coupled mode-aware gates, Info + facet selectors, TestBase Open/extreme Policy helpers; dual-path always-allow → product Open; Pricing closed-burn `1,1` → `2,1`; Open suite T1–T19 + buffer-only burn lock + bootstrap ungated; `forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/**'` 72/72 pass. P4 formal PRD LOCKED next. |
| 2026-07-28 | **Oversight:** P3 accepted (**PASS**). Re-ran mixedBuffer/** **72/72** green; code DoD surface confirmed. Next = **P4** formal PRD LOCKED (`DETF_Threshold_Modes_P4_PRD_LOCKED_EXEC_AGENT_PROMPT.md`). |
| 2026-07-28 | **P4 done:** PRD formal **LOCKED** (header + status table + inventory F1–F3 Yes/shipped + changelog). Product law locked 2026-07-27; gated by accepted F1+F2+F3 plans **and** P0–P3 implement waves green. **P4 formal LOCKED. Next: P5 draft F4 + F5 threshold-mode plans (then implement).** |
| 2026-07-28 | **P5 plans done (F4 + F5).** Full plans at `composed/stable/common/ComposedStableCommonDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md` and `composed/single/SingleVaultDetf_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`. P5 split: P5a plans `done`; P5b F4 impl / P5c F5 impl still `todo` (whole P5 not implement-complete). **Next: implement F4 ComposedStableCommon, then F5 SingleVaultDetf (synthetic migration).** |
| 2026-07-28 | **P5b F4 done:** trailing `thresholdMode` after `routes`; resolve/validate both modes; `ThresholdModeSet` once resolved; live-coupled mode-aware gates (synthetic price); ExchangeIn + ExchangeOut/query sites; info surface on ExchangeIn; FactoryService/TestBase Open helpers; Open suite T1–T19 mapped; matrix always-allow → product Open. `forge test --match-path 'test/foundry/spec/vaults/detf/composed/stable/common/**'` **116/116** pass. **P5c F5 still `todo`.** Whole P5 remains `in_progress`. |
| 2026-07-28 | **P5c F5 done:** synthetic migration (all mint/burn gates + `is*Allowed` use `_calcSyntheticPrice`; spot helper non-gate only); trailing `PkgArgs.thresholdMode` + mint/burn (hardcode ±0.5% removed → product ±5% defaults); resolve/validate; `ThresholdModeSet` once resolved; mode-aware 3-arg lib; live-coupled Info; facet `thresholdMode` selector; Open suite T1–T19 mapped. `forge test --match-path 'test/foundry/spec/vaults/detf/composed/single/**'` **106/106** pass. **Whole P5 done.** Next: P6 F6/F7. |
| 2026-07-28 | **P6 done:** F6 `IProtocolDETF` + errors/proxy NatSpec; `thresholdMode()` on typed surface (`ThresholdMode` from core); F5 facet selector + IFacet test use `IProtocolDETF.thresholdMode`; claim `RedemptionNotAllowed` independent of Open. `forge build` ok; F5 path **106/106** pass. F7 **Out** (evidence: peg-regime diluted gates, no threshold/mode storage, consolidation reference-only, not on anvil_single modern path) — note `contracts/vaults/seigniorage/THRESHOLD_MODES_OUT.md`; no code half-migration. PRD inventory F6/F7 updated. **Next: P7** AGENTS.md + family PRD conform notes. |
| 2026-07-28 | **P7 done:** AGENTS Policy/Open + synthetic gates; fee oracle no longer owns mint/burn thresholds (PkgArgs source of truth); family PRD conform notes F1–F4 (+ F5 plan-header synthetic note); F7 remains Out. **Threshold Modes program P0–P7 complete.** |
