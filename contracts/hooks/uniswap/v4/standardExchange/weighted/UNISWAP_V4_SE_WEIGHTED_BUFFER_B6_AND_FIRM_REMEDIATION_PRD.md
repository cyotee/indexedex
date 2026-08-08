# Remediation PRD: SE Weighted Buffer — B6 SE-Share LP + Firm Join/Exit

**Name:** `UniswapV4StandardExchangeWeightedBufferHook` — B6 / firm remediation  
**Date:** 2026-08-08  
**Status:** **Draft v0.1 — LOCKED for implementation**  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/weighted/`  
**Document kind:** Remediation (B6 + firm surface; **not** unbuffered H3 diamond work)  
**Compliance driver:** `UNISWAP_V4_HOOKS_INTENTION_COMPLIANCE_REVIEW_PRD.md` H8 + standard buffering **B6**; co-located product PRD join/exit matrix  
**Depends on:** Existing SE Weighted Buffer package under `standardExchange/weighted/` (H8 greenfield). **Not** `contracts/hooks/uniswap/v4/weighted/` (H3 unbuffered).  

---

## 0. Authority

| Layer | Role |
|-------|------|
| **This PRD** | Remediation law for B6 LP units + firm join/exit close-outs |
| Co-located product PRD | Remains curve / doors / inventory-domain / buffer-last SoT; **this PRD wins** on SE-share LP edge units (overrides “pair-token only at LP edge” for optional flexible paths) |
| Compliance SoT § Standard buffering B6 | Pair token **and/or** SE vault share for LP on buffered products |
| Peer remediations | Single SE CP B6, Dual SE CP B6/M3 — process peers for flexible SE-share LP (adapt to **n-leg inventory domain**) |

---

## 1. Problem

1. **B6 gap:** Public LP edge is **pair-token only**. Buffered-leg inventory is live SE vault shares, but integrators who already hold SE shares must unwrap via SE interfaces before join and receive only pair tokens on exit — opposite of the integration goal.  
2. **Firm:** Product law claims full weighted join/exit + MultiAssetLiquidity 1:1. Remediation must keep those paths **live** (no permanent `InvalidRoute` / stub for advertised selectors) and prove SE-share LP alongside pair paths.

Hard targets (weighted curve, ≥1 SE, opacity, dual inventory/rated scales, buffer-last, Hook Diamond Package, all \(\binom{n}{2}\) doors) **MEETS** — do not regress them.

---

## 2. Locked decisions

| ID | Decision |
|----|----------|
| **D1** | **B6 required:** LP **deposit and withdraw** support **pair token and/or SE vault share** for **each buffered leg**. |
| **D2** | Integrator goal: no forced SE unwrap solely to enter/exit LP. |
| **D3** | Raw (unbuffered) legs remain face ERC-20 only; `amountIsSeShare` / `receiveSeShare` **must revert** on raw legs. |
| **D4** | LP algebra stays **inventory domain** (face \| live SE shares; Q7/Q26). SE-share in maps 1:1 to inventory; pair-in on buffered leg still maps via buffer preview then **buffer-last**. |
| **D5** | Anti-skew: depositing SE shares must not false-reprice the inventory book vs depositing the equivalent post-buffer SE shares (within dust). Pair-path buffer fees may reduce inventory contribution vs pre-held SE shares — expected, not a reprice bug. |
| **D6** | Previews required for all SE-share LP mutators. |
| **D7** | Surface shape (n-asset): **flexible** proportional + single-asset paths with per-leg flags (arrays), not dual’s fixed two-bool ABI only. |
| **D8** | **Firm:** Keep full join/exit matrix + one-token aliases + MultiAssetLiquidity 1:1 for **pair-token** paths; do not drop advertised selectors. |
| **D9** | B6 flexible selectors live on product interface + LiquidityFacet cut; pair-only selectors unchanged. |
| **D10** | Opacity unchanged: V4 pool currencies = pair tokens only (never SE share addresses). |
| **D11** | Hook Diamond Package / CREATE2 deploy path unchanged. |
| **D12** | Optional: single-asset + proportional cover B6 DoD; unbalanced flexible SE-share is **not** required for this remediation (pair unbalanced remains firm). |

---

## 3. API (normative)

### 3.1 Proportional flexible

```text
previewJoinProportionalFlexible(amounts[], amountIsSeShare[])
  → (shares, usedAmounts[])   // usedAmounts in the same unit as input per leg

joinProportionalFlexible(amounts[], amountIsSeShare[], to, sharesMin, deadline)
  → (shares, usedAmounts[])

previewExitProportionalFlexible(shares, receiveSeShare[])
  → amounts[]                 // unit per leg follows receiveSeShare

exitProportionalFlexible(shares, to, receiveSeShare[], amountsMin[], deadline)
  → amounts[]
```

### 3.2 Single-asset flexible (+ aliases)

```text
previewJoinSingleAssetExactInFlexible(tokenIn, amountIn, amountIsSeShare) → shares
joinSingleAssetExactInFlexible(tokenIn, amountIn, amountIsSeShare, to, sharesMin, deadline) → shares
depositSingleFlexible / previewDepositSingleFlexible  // aliases

previewExitSingleAssetExactBptInFlexible(tokenOut, sharesIn, receiveSeShare) → amountOut
exitSingleAssetExactBptInFlexible(tokenOut, sharesIn, receiveSeShare, to, amountOutMin, deadline) → amountOut
withdrawSingleFlexible / previewWithdrawSingleFlexible  // aliases
```

### 3.3 Semantics

| Flag | Buffered leg | Raw leg |
|------|--------------|---------|
| `amountIsSeShare=true` | Pull SE vault share; inventory += shares; **no** buffer | **Revert** |
| `amountIsSeShare=false` | Pull pair; buffer-last; inventory += SE shares minted | Pull face; credit raw reserve |
| `receiveSeShare=true` | Pay SE vault shares (no unwrap) | **Revert** |
| `receiveSeShare=false` | Unwrap SE → pair to `to` | Pay face |

Pair-only existing methods remain: flags all-false on flexible must match pair path within dust.

---

## 4. Acceptance criteria

1. Tests: first mint and subsequent prop join with **SE shares on buffered leg(s)** mint LP; preview == exec.  
2. Tests: exit prop can pay **SE shares** on buffered leg(s); preview == exec.  
3. Tests: single-asset join/exit flexible SE-share + pair aliases.  
4. Tests: pair-token paths still work; flexible all-false matches pair prop join within dust.  
5. Tests: `amountIsSeShare` / `receiveSeShare` on raw leg reverts.  
6. Firm: existing Liquidity / MultiAssetLiq suite remains green (unbalanced, exact-out, aliases).  
7. Opacity / vault discovery: `vaultTokens` = pair tokens; `reserveOfToken` buffered = live SE shares.  
8. Compliance B6 / H8.3 scoreable as MEETS for LP units.  

---

## 5. Out of scope

- Unbuffered weighted H3 diamond package (`contracts/hooks/uniswap/v4/weighted/`)  
- Unbalanced multi-asset join with per-leg SE-share flags (optional follow-on)  
- Changing inventory vs rated domain split, weights, or door law  
- Fee oracle redesign  

---

## 6. References

- Product: `UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md`  
- Plan: `UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md`  
- Peers: Single SE CP B6, Dual SE CP B6/M3 remediation PRDs  

---

*End of remediation PRD.*
