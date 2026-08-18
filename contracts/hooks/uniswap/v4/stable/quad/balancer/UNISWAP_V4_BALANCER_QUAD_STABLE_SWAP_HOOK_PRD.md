# PRD: Uniswap V4 Balancer Quad Stable Swap Hook (Unbuffered)

**Name:** `UniswapV4BalancerQuadStableSwapHook` (full production type names; plan locks exact spellings)  
**Date:** 2026-08-08  
**Status:** **Draft v0.1 — LOCKED for planning (greenfield product)**  
**Package path:** `contracts/hooks/uniswap/v4/stable/quad/balancer/`  
**Package kind:** IndexedEx **Uniswap V4 Hook Diamond Package** — unbuffered 4-asset StableSwap with **Balancer V3 StableMath pricing identity**  
**Follow-on plan (later):** `UNISWAP_V4_BALANCER_QUAD_STABLE_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md`  

**Not** a remediation of the Curve tree. **Independent** product beside `stable/quad/curve/`.

---

## 0. Authority

| Layer | Role |
|-------|------|
| **This PRD** | Product law for the Balancer-identity unbuffered quad stable hook |
| Hook factory PRD | Deploy / salt / flags / immutability |
| Balancer baseline | Crane `lib/crane/contracts/external/balancer/v3/` — `StableMath`, `StablePool` |
| Curve sibling | Behavioral peer for multi-door V4 layout **only** — **not** math SoT |
| Compliance SoT H2 | Operator hard target “Balancer stable math” is **this** product’s job |

---

## 1. Purpose

Provide a Uniswap V4 multi-door hook whose **swap pricing identity** matches **Balancer V3 Stable** math (hard), with combinatorial pair doors over four pair tokens and a shared multi-asset book. Join/exit feature parity with Balancer stable class is **firm** (desired).

Traders see **pair tokens only**. No SE buffering (buffered Balancer product is a separate package under `standardExchange/stable/quad/balancer/`).

---

## 2. Sibling packages (do not conflate)

| Package | Path | Role |
|---------|------|------|
| **Curve Quad Stable** | `stable/quad/curve/` | Classic Curve StableSwap; intentional alternate product |
| **This package** | `stable/quad/balancer/` | **Balancer StableMath** identity; unbuffered |
| SE Curve buffer | `standardExchange/stable/quad/curve/` | Buffered Curve (after H9 rename) |
| SE Balancer buffer | `standardExchange/stable/quad/balancer/` | Buffered Balancer |
| Weighted unbuffered | `weighted/` | Different curve family |

---

## 3. Locked decisions

| ID | Decision |
|----|----------|
| **D1** | Math hard target = Crane/Balancer **`StableMath`** (`computeInvariant`, `computeOutGivenExactIn`, `computeInGivenExactOut`, `computeBalance`, amp precision **`1e3`**, favor-protocol ±1 where Balancer applies). |
| **D2** | Do **not** reimplement classic Curve `getD`/`getY` with `AMP_PRECISION=100` as this product’s swap engine. |
| **D3** | Deploy = **Hook Diamond Package** + registry `deployHookVault` + shared CREATE2 hook factory. Facets CREATE3. |
| **D4** | \(n=4\) pair tokens; \(\binom{4}{2}=6\) V4 pair doors; shared 4-leg reserve book. |
| **D5** | Unbuffered: no SE vault legs; optional `IRateProvider` only for **scale** of pair tokens (Balancer-style rates), not SE buffer inventory. |
| **D6** | Opacity: pool currencies = pair tokens only. |
| **D7** | Firm: join/exit surface aims at Balancer-class proportional / unbalanced / single-asset where tractable on V4 multi-door book; plan may phase M2. |
| **D8** | Firm: expose `IStandardExchangeMultiAssetLiquidity` (and swap surfaces as applicable) for share-bearing multi-asset product. |
| **D9** | Fee model: document adaptation vs Balancer vault fees (V4 hook residual) **without** breaking StableMath swap identity. |
| **D10** | Production-first tests; golden fixtures vs Balancer `StableMath` where feasible (hermetic). |
| **D11** | Full type/file names; no compressed aliases as production types. |

---

## 4. Product surfaces (summary)

| Area | Requirement |
|------|-------------|
| Swap | V4 `beforeSwap` (+ returns delta as required by flags); quotes use StableMath on rate-scaled balances |
| LP | Fungible LP on diamond (shared ERC20 permit facets preferred); multipath join/exit |
| Doors | Six product pair doors via permissionless `deployPair`; production ABI via `finalizeInitialization`. `postDeploy` is a no-op. |
| Package | `IUniswapV4HookDiamondPackage`, `requiredHookFlags`, `calcSalt` without package address |

---

## 5. Non-goals

- SE buffering / virtual TTA (other packages)  
- Orbital / weighted / CP curves  
- Preserving Curve amp numbers as “the same A”  
- Monomorph CREATE3 instance path  
- Cloning Curve product bugs for parity with curve sibling  

---

## 6. Acceptance criteria (product DoD)

1. Production code under `stable/quad/balancer/` only.  
2. Swap quotes use Balancer StableMath family with **`AMP_PRECISION=1e3`** (or equivalent wrap of Crane `StableMath` — not Curve-100 pin).  
3. Numerical / property tests show identity with StableMath for fixed fixtures (plan defines matrix).  
4. Hook Diamond Package deploy path green in hermetic TestBase.  
5. Six pair doors + shared book.  
6. No SE vault as pool currency.  
7. Co-located product PRD does **not** claim Curve classic as this product’s math.  

---

## 7. Open questions (for implementation plan)

- Amp ramp support: out of scope v1 unless plan pulls it in.  
- Exact join/exit phase split (M2 full in v1 vs phased).  
- Fee residual on input vs output — plan chooses consistent with V4 + oracle peers.  

---

## 8. References

- `lib/crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol`  
- `lib/crane/contracts/external/balancer/v3/pool-stable/`  
- Factory PRD under `contracts/hooks/uniswap/v4/factory/`  
- Curve sibling remediation under `stable/quad/curve/`  
- Compliance: historical H2 score against Balancer intention  

---

*End of product PRD. Implementation plan is a separate document.*
