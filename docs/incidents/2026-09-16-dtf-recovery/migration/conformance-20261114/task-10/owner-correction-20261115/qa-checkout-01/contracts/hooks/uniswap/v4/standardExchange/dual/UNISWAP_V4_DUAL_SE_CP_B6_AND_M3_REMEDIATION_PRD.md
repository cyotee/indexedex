# Remediation PRD: Dual SE Buffer CP — B6 SE-Share LP + M3 Surface

**Name:** `UniswapV4DualStandardExchangeBufferConstantProductHook` — B6 / M3 remediation  
**Date:** 2026-08-08  
**Status:** **Draft v0.1 — LOCKED for planning**  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/dual/`  
**Document kind:** Remediation  
**Follow-on plan:** `UNISWAP_V4_DUAL_SE_CP_B6_AND_M3_REMEDIATION_IMPLEMENTATION_AND_TEST_PLAN.md`  
**Compliance driver:** `COMPLIANCE_REPORT_standardExchange_dual.md` — **MOSTLY COMPLIANT**; M3 residual (P2); B6 pair-only public LP edge  

---

## 1. Problem

- Public LP API is **pair-token** deposit/withdraw; SE shares are internal buffer inventory only.  
- Hook does not expose canonical `IStandardExchange` / `IStandardExchangeMultiAssetLiquidity` for the pair0↔pair1 product surface (M3 residual).  

Hard targets (always-2 SE, CP, opacity, PKG, virtual N/A) **MEETS** — preserve them.

---

## 2. Locked decisions

| ID | Decision |
|----|----------|
| **D1** | **B6:** For **each** SE leg, LP **deposit and withdraw** may use that leg’s **pair token and/or SE vault share**. |
| **D2** | Integrators need not unwrap SE shares solely to LP. |
| **D3** | Always **two** SE vault legs remains mandatory. |
| **D4** | Virtual TTA remains **not required** for dual-SE design. |
| **D5** | **M3:** Expose `IStandardExchangeIn`/`Out` and/or `IStandardExchangeMultiAssetLiquidity` on the diamond for the product’s join/exit/swap surface (plan picks selector map; no silent `InvalidRoute` for advertised core paths). |
| **D6** | Previews for SE-share LP paths. |
| **D7** | Anti-skew: SE-share in/out must not false-reprice vs pair buffer path. |

---

## 3. Acceptance criteria

1. Deposit with SE shares on leg0 and/or leg1 mints LP (plan matrix).  
2. Withdraw can pay SE shares and/or pair tokens per leg.  
3. Pair-token paths remain.  
4. Documented M3 interface IDs match implemented selectors.  
5. PKG/opacity/always-2 SE unchanged.  

---

## 4. Out of scope

- Single-SE CP (H5)  
- Orbital/weighted/stable curves  
- Requiring virtual TTA  

---

*End of remediation PRD.*
