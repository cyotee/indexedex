# Remediation PRD: SE Curve Quad Stable Buffer — B6 SE-Share LP + Firm Join/Exit

**Name:** SE Curve Quad Stable Buffer — B6 / firm remediation  
**Date:** 2026-08-08  
**Status:** **Draft v0.1 — LOCKED for planning**  
**Package path (after rename move):** `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/`  
**Document kind:** Remediation (firm features; **not** Balancer math)  
**Follow-on plan:** `UNISWAP_V4_SE_CURVE_QUAD_STABLE_BUFFER_B6_AND_FIRM_REMEDIATION_IMPLEMENTATION_AND_TEST_PLAN.md`  
**Compliance driver:** `COMPLIANCE_REPORT_standardExchange_stable_quad.md` P1 join/exit Phase 0; P1 B6 pair-only LP  
**Depends on:** rename/move remediation PRD in this directory (or may ship after move)  

---

## 1. Problem

After Curve identity is explicit, remaining firm gaps from compliance:

- Phase-0 MultiAsset routes `InvalidRoute` (unbalanced / exact-out singles)  
- LP edge pair-token only — no SE-share deposit/withdraw (B6)  

Math stays **classic Curve** (Balancer product is the sibling under `balancer/`).

---

## 2. Locked decisions

| ID | Decision |
|----|----------|
| **D1** | **B6:** deposit **and** withdraw support pair token **and/or** SE vault share for buffered legs. |
| **D2** | Integrator goal: no forced SE unwrap solely to LP. |
| **D3** | Close Phase-0 MultiAsset gaps **or** permanently document reduced surface and remove false interface claims — **default:** implement unbalanced + exact-out singles to firm M2. |
| **D4** | ≥1 SE, opacity, six doors, Curve math, Hook Diamond Package unchanged. |
| **D5** | Prefer sequencing: rename/move first, then this PRD’s code changes on `curve/` tree. |

---

## 3. Acceptance criteria

1. SE-share and pair LP paths tested.  
2. Core MultiAsset join/exit paths no longer permanent `InvalidRoute` for plan-listed selectors.  
3. Curve math pin unchanged.  
4. Compliance P1 firm rows closed for this product.  

---

*End of remediation PRD.*
