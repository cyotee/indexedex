# PRD: Uniswap V4 SE Balancer Stable Buffer Hook (2–5 tokens)

**Name:** `UniswapV4StandardExchangeBalancerQuadStableBufferHook` (full production type names; plan locks spellings)  
**Date:** 2026-08-08  
**Last updated:** 2026-09-06  
**Status:** **Draft v0.2 — required 2–5 token correction; implementation pending**  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/`  
**Package kind:** IndexedEx **Uniswap V4 Hook Diamond Package** — 2–5 asset **Balancer StableMath** + **standard SE buffering** (≥1 leg)  
**Follow-on plan (later):** `UNISWAP_V4_SE_BALANCER_QUAD_STABLE_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md`  

Independent of the Curve SE buffer product under `…/stable/quad/curve/`.

**Correction authority (2026-09-06):** the user confirmed that this package was intended to support 2 through 5 tokens. The prior fixed-four requirement was a product-specification bug. The [token-count fix PRD](UNISWAP_V4_SE_BALANCER_STABLE_BUFFER_HOOK_TOKEN_COUNT_FIX_PRD.md) governs the correction, supersedes former D4 and fixed-six pair assumptions, and defines implementation acceptance. `Quad` in existing paths/type names is historical; retain this package for the fix.

---

## 0. Authority

| Layer | Role |
|-------|------|
| **This PRD** | Product law for Balancer-identity SE-buffered stable pools with 2–5 tokens |
| **Token-count fix PRD** | Governs the correction of fixed-four assumptions, dynamic binding, math parity, pair enumeration, and compatibility |
| Unbuffered Balancer peer | `stable/quad/balancer/` — math/doors reference |
| SE buffer / virtual / opacity | Compliance SoT §3.4–§3.6; Balancer SE buffer pool for single-SE-style identities |
| Hook factory PRD | Deploy / salt / flags |
| Curve SE sibling | Multi-door + buffer process peer **only** — not math SoT |

---

## 1. Purpose

StableSwap AMM on 2–5 pair tokens with combinatorial V4 pair doors, **Balancer V3 StableMath pricing identity (hard)**, standard SE buffering on **≥1** leg, trader opacity (pair tokens only), and LP in **pair token and/or SE vault share** for buffered legs (deposit **and** withdraw).

---

## 2. Sibling packages

| Package | Path | Role |
|---------|------|------|
| Unbuffered Balancer quad | `stable/quad/balancer/` | No SE buffer |
| Curve SE buffer | `standardExchange/stable/quad/curve/` | Curve math + SE buffer |
| **This** | `standardExchange/stable/quad/balancer/` | Balancer math + SE buffer |
| H8 weighted buffer | `standardExchange/weighted/` | Different curve |

---

## 3. Locked decisions

| ID | Decision |
|----|----------|
| **D1** | Hard math = Crane/Balancer **`StableMath`** identity (`AMP_PRECISION=1e3`, `computeBalance`, favor-protocol rules as applicable). |
| **D2** | Not classic Curve-100 pin for this product. |
| **D3** | Hook Diamond Package + `deployHookVault` / flag-mined CREATE2. |
| **D4** | `2 <= n <= 5`, selected immutably at deployment, with `n * (n - 1) / 2` pair doors and one shared book. Counts 2/3/4/5 require 1/3/6/10 doors. Product doors open via permissionless `deployPair` then `finalizeInitialization`. `postDeploy` is a no-op. This replaces the former fixed-four decision. |
| **D5** | **≥1** SE vault leg required at bind (`seCount == 0` reverts). |
| **D6** | Opacity: pool currencies = pair tokens only (never SE shares). |
| **D7** | Buffer pack: buffer-last; free pair on SE legs not book; rate/claim growth may reprice; buffer reshuffle alone must not false-reprice. |
| **D8** | Virtual/anti-skew: multi-leg dual-scale or proven §3.5-equivalent; document mapping in plan. |
| **D9** | **B6 LP units (hard for this product):** for each buffered leg, LP **deposit and withdraw** may use **pair token and/or SE vault share** so integrators need not unwrap via separate SE interface to enter/exit. |
| **D10** | Firm M2: Balancer-class join/exit (proportional / unbalanced / single-asset) phased if needed — v1 should not ship permanent `InvalidRoute` for core MultiAsset surface without plan-locked Phase 0 list. |
| **D11** | M3: `IStandardExchangeIn`/`Out` + `IStandardExchangeMultiAssetLiquidity` on diamond. |
| **D12** | Optional `IRateProvider` per SE leg; fail-closed. |
| **D13** | Production-first tests for every supported count; pinned StableMath parity, buffer anti-skew, full pair enumeration, and four-token regression coverage. |
| **D14** | Exactly `n` active currencies and consistent binding/amount arrays; no dummy tokens or padded balances in the invariant. Invalid counts and mismatched bindings revert. |

---

## 4. Non-goals

- Curve math product (sibling path)  
- Zero-SE deploy (use unbuffered Balancer package)  
- Orbital / weighted curves  
- Monomorph instance path  

---

## 5. Acceptance criteria

1. Correct this package under `standardExchange/stable/quad/balancer/` and its directly affected ABI/deployment/test consumers. No sibling-product changes.  
2. Swap engine is Balancer StableMath family (not Curve-100).  
3. ≥1 SE required; opacity holds.  
4. B6: deposit and withdraw support pair **and** SE share for buffered legs (tests prove both).  
5. Hook Diamond Package path green.  
6. All 1/3/6/10 product doors for the selected 2/3/4/5 currencies share one book. Doors via `deployPair` then `finalizeInitialization`; not same-tx in `postDeploy`.  
7. Meet the token-count fix PRD's binding, math, LP/SE accounting, compatibility, and validation requirements for all four supported counts.  

---

## 6. Open questions (plan)

- Whether raw-only legs among the active currencies use intentional face reserves vs virtual TTA when mixed with SE legs.  
- Exact claim vs `seBal×rate` rated composition when RP set.  

---

## 7. References

- Balancer `StableMath` / `StablePool` under Crane  
- Virtual SoT: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/`  
- Factory PRD; unbuffered Balancer PRD; Curve SE remediation  

---

## 8. Change log

| Date | Change |
|---|---|
| 2026-09-06 | Corrected the intended range to 2–5 tokens per user clarification. Superseded fixed-four D4 and six-pair acceptance; linked the detailed remediation requirements. Current implementation still requires correction. |

*End of product PRD.*
