# Remediation PRD: Single SE Buffer CP — SE-Share LP Units (B6) + Firm Surfaces

**Name:** `UniswapV4SingleStandardExchangeBufferConstantProductHook` — B6 / firm remediation  
**Date:** 2026-08-08  
**Status:** **Draft v0.1 — LOCKED for planning**  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/`  
**Document kind:** Remediation  
**Follow-on plan:** `UNISWAP_V4_SINGLE_SE_CP_B6_SE_SHARE_LP_REMEDIATION_IMPLEMENTATION_AND_TEST_PLAN.md`  
**Compliance driver:** `COMPLIANCE_REPORT_standardExchange_constantProduct_single.md` — **MOSTLY COMPLIANT**; P1 B6 (SE-share LP missing), M3 multi-asset surface gap  

---

## 0. Authority

| Layer | Role |
|-------|------|
| **This PRD** | Remediation law for B6 LP units and related firm surface close-outs |
| Co-located Single SE CP product PRD | Remains math/buffer SoT unless conflict; this PRD **wins** on B6 LP units |
| Compliance SoT §3 / Buffer B6 | Pair token **and/or** SE vault share for LP on buffered products |

---

## 1. Problem

Production LP edge is **pair (+ raw) only**. Operators cannot deposit or withdraw **SE vault shares** as LP contribution/redemption units. Integrators who already hold SE shares must unwrap via SE interfaces first — the opposite of the integration goal.

Hard targets (CP math, single SE leg, virtual/anti-skew equivalent, PKG, opacity) **MEETS** — do not regress them.

---

## 2. Locked decisions

| ID | Decision |
|----|----------|
| **D1** | **B6 required:** LP **deposit and withdraw** support **pair token and/or SE vault share** for the buffered SE leg. |
| **D2** | Motivation: integrators need not call Standard Exchange unwrap solely to enter/exit LP. |
| **D3** | Raw (unpaired) leg remains face ERC-20 for LP; no “SE share” on raw leg. |
| **D4** | Accounting stays **native + rated** / claim-based as product already defines; SE-share in must convert to book units consistently with buffer math. |
| **D5** | Anti-skew identities preserved: depositing SE shares must not false-reprice vs depositing equivalent pair then buffering (within documented dust). |
| **D6** | Previews required for SE-share deposit/withdraw paths. |
| **D7** | M3: align public surface with `IStandardExchangeMultiAssetLiquidity` **or** document permanent product ABI with adapters — **default:** add MultiAsset selectors that map to existing + new paths where applicable. |
| **D8** | No change to “exactly one SE vault leg” or CP family. |
| **D9** | Hook Diamond Package path unchanged. |

---

## 3. Acceptance criteria

1. Tests: deposit with **SE shares only** (buffered leg) mints LP; withdraw burns LP and pays **SE shares** option.  
2. Tests: pair-token deposit/withdraw still work.  
3. Mixed paths (plan defines) do not break virtual/anti-skew.  
4. Compliance B6 / H5.7 scoreable as MEETS.  
5. No opacity break (SE not a V4 pool currency).  

---

## 4. Out of scope

- Dual-SE product (H6)  
- Changing virtual model to literal `virtualTTA` storage if claim model already equivalent  
- Fee oracle redesign  

---

## 5. References

- Compliance H5 report  
- Product PRD co-located  
- Balancer SE buffer pool (economic peer for anti-skew)  

---

*End of remediation PRD.*
