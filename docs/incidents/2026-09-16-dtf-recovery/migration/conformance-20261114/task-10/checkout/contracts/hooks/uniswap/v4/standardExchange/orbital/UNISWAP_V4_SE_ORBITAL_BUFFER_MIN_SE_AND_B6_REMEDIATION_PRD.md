# Remediation PRD: SE Orbital Buffer — Min ≥1 SE + B6 SE-Share LP

**Name:** `UniswapV4StandardExchangeOrbitalBufferHook` — min-SE / B6 remediation  
**Date:** 2026-08-08  
**Status:** **Draft v0.1 — LOCKED for implementation**  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/orbital/`  
**Document kind:** Remediation  
**Compliance driver:** `UNISWAP_V4_HOOKS_INTENTION_COMPLIANCE_REVIEW_PRD.md` H7 (`standardExchange_orbital`) + Buffer pack B1–B7  

---

## 0. Authority

| Layer | Role |
|-------|------|
| **This PRD** | Remediation law for **minimum one SE leg** and **B6 LP units** |
| Co-located product PRD | Remains sphere/math/buffer SoT unless conflict; **this PRD wins** on min-SE binding and B6 LP surfaces |
| Compliance SoT H7 / Buffer B6 | ≥1 buffered leg; LPs manage liquidity via **pair token and/or SE vault share** |

---

## 1. Problem

1. **Min SE gap (H7.2 / product D11):** Product PRD allowed **0-SE** raw-only binding (degenerate pure orbital). Intention for H7 is **Orbital + standard buffering for ≥1 leg**. Zero-SE configs are out of product family and must be rejected at package validation.
2. **B6 gap:** Public multipath LP edge is **pair-token only** (`addLiquidity` / `removeLiquidity`). Operators holding SE vault shares must unwrap solely to enter/exit LP — opposite of buffer-product integration goals.

Hard targets (sphere math, three doors, buffer-last, opacity, PKG path, dual-channel fees, SE In/Out) **MEETS** — do not regress them.

---

## 2. Locked decisions

| ID | Decision |
|----|----------|
| **D1** | **Min SE:** Instance binding requires **≥1** non-zero `standardExchange[i]`. All-zero SE reverts in `processArgs` / init validation. |
| **D2** | Still **0–2 raw legs** allowed; optional SE remains **per leg** (1–3 SE total). Non-zero SEs pairwise distinct (unchanged). |
| **D3** | **B6:** Multipath LP **deposit and withdraw** support **pair token and/or SE vault share** for each **buffered** leg. |
| **D4** | Raw legs accept **face ERC-20 only** for LP; `*IsSeShare` / `receiveSeShare*` **false** on raw legs (or revert). |
| **D5** | Integrators need not unwrap SE shares solely to LP or re-buffer pair solely to exit as SE. |
| **D6** | Accounting stays **effective-reserve / claim / rate** as product defines; SE-share in converts via claim or RP (anti-skew vs pair-then-buffer within dust). |
| **D7** | Previews required for flexible SE-share deposit/withdraw paths. |
| **D8** | Existing pair-token `addLiquidity` / `removeLiquidity` remain; flexible API is additive. |
| **D9** | Hook Diamond Package path, salt law, flags, immutability unchanged. |
| **D10** | Product PRD D11 (allow zero-SE) is **superseded** by D1 for production binding. |

---

## 3. Surface (normative)

```solidity
// B6 multipath flexible LP (pool-order legs 0/1/2)
function depositFlexible(
    uint256 amount0, bool amount0IsSeShare,
    uint256 amount1, bool amount1IsSeShare,
    uint256 amount2, bool amount2IsSeShare,
    address to, uint256 sharesMin, uint256 deadline
) external returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2);

function withdrawFlexible(
    uint256 shares, address to,
    bool receiveSeShare0, bool receiveSeShare1, bool receiveSeShare2,
    uint256 a0Min, uint256 a1Min, uint256 a2Min, uint256 deadline
) external returns (uint256 a0, uint256 a1, uint256 a2);

function previewDepositFlexible(...) external view returns (...);
function previewWithdrawFlexible(...) external view returns (...);
```

- All `*IsSeShare == false` → semantic peer of pair `addLiquidity` (amounts are pool tokens).  
- All `receiveSeShare* == false` → semantic peer of pair `removeLiquidity` (pays pool tokens after unwrap on SE legs).  
- When a flag is true on a buffered leg: amount / payout unit is that leg’s **SE vault share**.  

Events: `DepositFlexible` / `WithdrawFlexible` (or extend existing) must record flags + used/paid units.

---

## 4. Acceptance criteria

1. `processArgs` / deploy **reverts** when `se0 == se1 == se2 == address(0)`.  
2. Deploy with exactly one SE (any leg) and with 2–3 SEs **succeeds** (existing distinct-SE rules).  
3. Tests: deposit with **SE shares** on buffered leg(s) mints LP; inventory is SE shares (not free pair book).  
4. Tests: withdraw can pay **SE shares** and/or pair tokens per buffered leg.  
5. Tests: pair-token paths still work.  
6. Previews bit-exact (within dust) vs execution for flexible paths.  
7. Compliance H7.2 + B6 scoreable as MEETS; no opacity break (SE never a V4 pool currency).  

---

## 5. Out of scope

- Changing sphere math / multipath NAV formulas beyond SE-unit conversion  
- Requiring all three legs buffered  
- M3 multi-asset SE surface redesign (already has SE In/Out)  
- Dual / Single SE CP products (H5/H6 remediations)  

---

## 6. References

- Product PRD: `UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md`  
- Intention SoT: H7 + Buffer B1–B7  
- Peer B6 impl: Dual SE CP `depositFlexible` / `withdrawFlexible`  
- Skill: `indexedex-uniswap-v4-hook-packages`  

---

*End of remediation PRD.*
