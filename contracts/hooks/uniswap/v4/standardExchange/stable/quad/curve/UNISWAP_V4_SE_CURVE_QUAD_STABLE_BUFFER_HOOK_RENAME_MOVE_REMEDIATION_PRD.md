# Remediation PRD: SE Quad Stable Buffer (Curve) — Rename, Move, Intentional Product Split

**Name:** `UniswapV4StandardExchangeCurveQuadStableBufferHook` (working; plan locks full spellings)  
**Date:** 2026-08-08  
**Status:** **Draft v0.1 — LOCKED for planning**  
**Target package path:** `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/`  
**Source path (current):** `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/`  
**Document kind:** Remediation — rehome + rename + **intentional Curve + SE buffer** product identity  
**Follow-on plan:** `UNISWAP_V4_SE_CURVE_QUAD_STABLE_BUFFER_HOOK_RENAME_MOVE_REMEDIATION_IMPLEMENTATION_AND_TEST_PLAN.md`  
**Compliance driver:** `COMPLIANCE_REPORT_standardExchange_stable_quad.md` — **DIVERGENT** on hard M1 (same Curve pin as unbuffered H2)  

---

## 0. Authority

| Layer | Role |
|-------|------|
| **This remediation PRD** | Rename/move + Curve identity for **current** buffered stable tree |
| Co-located SE quad stable buffer PRD | Historical; rehome/update under `curve/` |
| Balancer SE buffer product | Greenfield under `standardExchange/stable/quad/balancer/` — independent |
| Unbuffered Curve sibling | `stable/quad/curve/` |
| Buffer / B6 firm gaps | May be separate remediations; **not** blocked by this move |

---

## 1. Problem / product decision

H9 production uses the same classic Curve StableSwap pin as H2 (`getD`/`getY`, `AMP_PRECISION=100`) while compliance hard-targets Balancer StableMath.

**Operator decision:** parallel product split (same as unbuffered):

1. Keep current implementation as **Curve + SE buffer** product.  
2. Rename + move to `standardExchange/stable/quad/curve/`.  
3. New **Balancer StableMath + SE buffer** product under `…/balancer/` (separate product PRD).  

---

## 2. Locked decisions

| ID | Decision |
|----|----------|
| **D1** | Final home: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/`. |
| **D2** | Names include **Curve** and **Standard Exchange** buffer semantics. |
| **D3** | Math remains classic Curve; docs must not claim Balancer StableMath identity. |
| **D4** | Retain Hook Diamond Package + SE buffer (≥1 SE), dual inv/rated domains, six pair doors, opacity. |
| **D5** | Root `standardExchange/stable/quad/` must not retain a second production copy after move. |
| **D6** | Breaking renames OK (nothing deployed). |
| **D7** | B6 SE-share LP deposit/withdraw and Phase-0 join/exit close-outs are **not** required for rename DoD (tracked in firm remediations / Balancer product). |

---

## 3. Acceptance criteria

1. Production Curve SE buffer sources live only under `…/stable/quad/curve/`.  
2. Type/path names are Curve-explicit.  
3. Package still deploys via hook diamond factory / registry.  
4. Hermetic TestBase updated; tests green.  
5. `balancer/` sibling not populated by this rename (greenfield separate).  

---

## 4. Out of scope

- Balancer StableMath port  
- Full M2 Phase-0 close-out (optional follow-on PRD)  
- B6 SE-share LP (shared SE buffer remediation wave)  

---

## 5. References

- Compliance: `COMPLIANCE_REPORT_standardExchange_stable_quad.md`  
- Unbuffered Curve remediation: `stable/quad/curve/…_RENAME_MOVE_REMEDIATION_PRD.md`  
- Current sources: `standardExchange/stable/quad/*.sol`  

---

*End of remediation PRD.*
