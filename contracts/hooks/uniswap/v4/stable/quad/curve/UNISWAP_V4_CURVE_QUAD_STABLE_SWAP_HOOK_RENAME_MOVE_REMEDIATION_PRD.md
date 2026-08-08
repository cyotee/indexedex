# Remediation PRD: Quad Stable (Curve) — Rename, Move, Intentional Product Split

**Name:** `UniswapV4CurveStableSwapHook` (working product name; full type names may include `Quad`)  
**Date:** 2026-08-08  
**Status:** **Draft v0.1 — LOCKED for planning**  
**Target package path:** `contracts/hooks/uniswap/v4/stable/quad/curve/`  
**Source path (current):** `contracts/hooks/uniswap/v4/stable/quad/curve/` (production `.sol` at tree root today)  
**Document kind:** Remediation — rehome + rename + **intentional Curve product identity**  
**Follow-on plan:** `UNISWAP_V4_CURVE_QUAD_STABLE_SWAP_HOOK_RENAME_MOVE_REMEDIATION_IMPLEMENTATION_AND_TEST_PLAN.md`  
**Compliance driver:** `COMPLIANCE_REPORT_stable_quad.md` — **DIVERGENT** on hard M1 vs Balancer StableMath; math is classic Curve  

---

## 0. Authority

| Layer | Role |
|-------|------|
| **This remediation PRD** | Law for rename/move and for treating the **current** implementation as the **Curve** stable product |
| Co-located `UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md` | Historical; will be superseded by Curve product naming after move (update or archive in same effort) |
| New Balancer product | **Independent** greenfield under `stable/quad/balancer/` — **not** this remediation |
| Hook factory / diamond package law | Unchanged — current tree is already Hook Diamond Package |

---

## 1. Problem / product decision

Compliance scored H2 against SoT “mirror **Balancer** StableMath” while production (and co-located PRD) pin **classic Curve** StableSwap (`getD`/`getY`, `AMP_PRECISION=100`).

**Operator decision (2026-08-08):** do **not** force-convert this tree to Balancer. Instead:

1. **Keep** classic Curve math as an intentional product.  
2. **Rename** types/files to **Curve**-explicit names.  
3. **Move** production tree to `stable/quad/curve/`.  
4. Implement **Balancer StableMath** as a **separate** product under `stable/quad/balancer/` (separate product PRD).  

This remediation resolves the **identity mismatch** by making Curve explicit; it does **not** implement Balancer math.

---

## 2. Intention (locked)

| ID | Decision |
|----|----------|
| **D1** | Final home: `contracts/hooks/uniswap/v4/stable/quad/curve/`. |
| **D2** | Product class name includes **Curve** (e.g. `UniswapV4CurveStableSwapHook` / `…CurveQuad…` full names per IndexedEx naming law). |
| **D3** | Math remains classic Curve StableSwap Newton; header/docs must **not** claim Balancer StableMath identity. |
| **D4** | Deploy shape remains Hook Diamond Package (already MEETS PKG). No monomorph regression. |
| **D5** | Unbuffered only — no SE buffering (buffered Curve product is H9 curve sibling). |
| **D6** | Imports, TestBases, specs, and co-located docs updated to new path/names. |
| **D7** | Root `stable/quad/` after move holds **only** shared docs index (optional) or is a thin parent; **no** dual production trees at root + curve. |
| **D8** | Nothing deployed — rename/move may break import paths freely. |

---

## 3. In scope

- Move production `.sol`, facets, interfaces, TestBase into `curve/`  
- Rename contracts/files/interfaces to Curve-explicit full names  
- Update Foundry tests / imports / remappings as needed  
- Rewrite or relocate product PRD under `curve/` stating Curve intention  
- Leave `balancer/` empty of this code (Balancer is greenfield)  

## 4. Out of scope

- Porting to Balancer `StableMath` (→ balancer product PRD)  
- Join/exit feature expansion beyond current Curve product  
- SE buffer (→ H9 curve path)  
- Changing amp encoding to Balancer `1e3` as a “half port”  

---

## 5. Acceptance criteria

1. All production Curve quad-stable code lives under `stable/quad/curve/`.  
2. No production type name implies “Balancer” for this product.  
3. Math module documents classic Curve pin (`AMP_PRECISION=100`, getD/getY).  
4. Package still deploys via hook diamond factory / registry.  
5. Hermetic tests pass against new paths/names.  
6. Parent `stable/quad/` does not still host a second copy of production sources.  

---

## 6. Naming guidance (plan locks exact symbols)

| Layer | Guidance |
|-------|----------|
| Directory | `stable/quad/curve/` |
| Product short label | Curve Quad Stable Swap Hook |
| Type prefix | `UniswapV4Curve…Stable…` (full words; no SEBCP-style compression) |
| LP symbol prefix | May keep short prefix if already locked; plan chooses if rename needed |

---

## 7. References

- Compliance: `COMPLIANCE_REPORT_stable_quad.md`  
- Current sources: `stable/quad/*.sol`  
- Sibling greenfield: `stable/quad/balancer/` product PRD  
- Factory: `contracts/hooks/uniswap/v4/factory/`  

---

*End of remediation PRD.*
