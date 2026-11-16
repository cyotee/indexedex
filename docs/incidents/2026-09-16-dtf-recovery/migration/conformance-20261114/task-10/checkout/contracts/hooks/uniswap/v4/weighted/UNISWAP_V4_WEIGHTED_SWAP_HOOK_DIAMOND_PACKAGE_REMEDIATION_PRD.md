# Remediation PRD: Weighted Swap Hook → Hook Diamond Package

**Name:** `UniswapV4WeightedSwapHook` Hook Diamond Package migration  
**Date:** 2026-08-08  
**Status:** **Draft v0.1 — LOCKED for planning**  
**Package path (subject):** `contracts/hooks/uniswap/v4/weighted/`  
**Document kind:** Remediation product law (not greenfield)  
**Follow-on plan (later):** `UNISWAP_V4_WEIGHTED_SWAP_HOOK_DIAMOND_PACKAGE_REMEDIATION_IMPLEMENTATION_AND_TEST_PLAN.md`  
**Compliance driver:** `COMPLIANCE_REPORT_weighted.md` — overall **DIVERGENT**; P0 PKG1–PKG4 / H3.5 monomorph-only production path  

---

## 0. Authority

| Layer | Role |
|-------|------|
| **This remediation PRD** | Normative for the migration effort: target deploy shape, non-goals, acceptance |
| Co-located weighted product PRD | **Superseded on deploy law** where it locks monomorph / “No Facet/DFPkg” (historical D14-class law). Math / multi-door / join-exit product identity remain unless this PRD explicitly changes them |
| Hook factory PRD | Deploy / salt / flags / immutability — `contracts/hooks/uniswap/v4/factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md` |
| Skill | `indexedex-uniswap-v4-hook-packages` |
| Compliance SoT | Operator intention for H3: Balancer weighted math (hard) + Hook Diamond Package (hard) |

**No live deployments.** Breaking address / salt / factory API is **allowed**.

---

## 1. Problem

Production H3 is a **CREATE3 monomorph** hook (`UniswapV4WeightedSwapHook.sol`) plus an **application factory** with `mineNonce`. That fails SoT **PKG1–PKG4**:

- Not a diamond proxy at a flag-mined CREATE2 address via the shared hook callback factory  
- No `IUniswapV4HookDiamondPackage` + registry `deployHookVault` path  
- Facets not the production instance shape  

Math (Crane `WeightedMath`) and multi-door behavior are largely aligned with Balancer M1; this remediation is **packaging / deploy path**, not a curve change.

---

## 2. Intention (locked)

Migrate **unbuffered** weighted multi-asset V4 hook to the **Uniswap V4 Hook Diamond Package** pattern used by H1 / H2 / H5–H9:

1. **Instance** = diamond proxy at flag-mined address (CREATE2 via hook callback factory).  
2. **Package** implements `IUniswapV4HookDiamondPackage` (+ vault surfaces as peers require).  
3. **Deploy path:** `pkg.deployVault(args, mineNonce)` → registry `deployHookVault` → hook factory.  
4. **Facets** via CREATE3 / `*_FactoryService`; product Target / Repo / Facet separation.  
5. **Immutable** postDeploy (no live `diamondCut`). Premine `mineNonce` preferred.  
6. **Product identity unchanged:** Balancer-class **weighted** math; combinatorial pair doors; **no SE buffering** (buffering remains **H8** forever).  

### Sibling locks

| Package | Role after this remediation |
|---------|------------------------------|
| **This (H3)** | Unbuffered weighted multi-door AMM; Hook Diamond Package |
| **H8** `standardExchange/weighted/` | **Only** SE-buffered weighted product |
| Do **not** merge H3 and H8 into one package |

---

## 3. Locked decisions

| ID | Decision |
|----|----------|
| **D1** | Target deploy shape = Hook Diamond Package + shared hook factory (not monomorph long-term). |
| **D2** | Reference package structure: **H1/H2-style** multi-door unbuffered diamond (doors + LP + hooks facets), adapted for weighted math — not H8 buffer facets. |
| **D3** | Retire monomorph production path: remove or quarantine `UniswapV4WeightedSwapHook.sol` instance path and app factory as **non-production** once package path lands. |
| **D4** | Salt law: product `calcSalt` from processArgs; **never** package address in salt; `finalSalt = keccak256(abi.encode(packageSalt, mineNonce))` per factory law. |
| **D5** | `requiredHookFlags()` pure package-constant; factory masks to `Hooks.ALL_HOOK_MASK`. |
| **D6** | No address continuity requirement (nothing deployed). |
| **D7** | Firm join/exit and SE multi-asset surface gaps from compliance may be **out of scope** for this PRD unless cheap while migrating — default **PKG migration only**; firm M2/M3 tracked as separate remediation if still open after migrate. |
| **D8** | Tests: production-first TestBase via registry + hook factory; no mock SUT diamond/factory. |

---

## 4. In scope

- DFPkg + package interface + FactoryService facet deploys  
- Target / Repo split of current monomorph logic  
- Facets for IHooks + liquidity/views as needed  
- Pair doors via staged `deployPair` + `finalizeInitialization` (not `postDeploy` / `ensureAllPairPools`). See [`UNISWAP_V4_WEIGHTED_SWAP_HOOK_STAGED_INIT_PRD.md`](./UNISWAP_V4_WEIGHTED_SWAP_HOOK_STAGED_INIT_PRD.md).  
- TestBase rewrite to package path  
- Deprecation of monomorph factory as production entry  

## 5. Out of scope / non-goals

- SE buffering, virtual TTA, rate-as-buffer (→ H8)  
- Changing weighted math family away from Balancer `WeightedMath`  
- Full Balancer join/exit feature parity stretch (optional follow-on)  
- Live migration / address preservation  
- Role of compliance program re-score (downstream)  

---

## 6. Acceptance criteria (DoD for this remediation)

1. Production deploy path is **only** package → `deployHookVault` → flag-mined diamond.  
2. Package is `IUniswapV4HookDiamondPackage`; `isExpectedInstance` validates flags.  
3. PKG1–PKG4 checklist MEETS against compliance vocabulary.  
4. Hermetic tests deploy real package through registry/hook factory and exercise swap + multi-door init.  
5. Monomorph `new` / app-factory-only path is not documented as production.  
6. Product remains **unbuffered** (no SE vault legs).  

---

## 7. Open questions (non-blocking for plan)

- Exact facet cut set (whether to compose shared ERC20Permit + MultiAsset vault facets like SE buffer packages). **Default:** yes if hook is its own LP token (peer H1/H2).  
- Whether legacy monomorph files are deleted in the same PR or retained under `legacy/` for one cycle. **Default:** delete once package tests green.  

---

## 8. References

- Compliance: `contracts/hooks/uniswap/v4/COMPLIANCE_REPORT_weighted.md`  
- Factory: `contracts/hooks/uniswap/v4/factory/`  
- Peer packages: `orbital/`, `stable/quad/` (diamond shape); **not** H8 buffer economics  
- Crane: `crane-deployment`, `crane-architecture`  

---

*End of remediation PRD. No production code in this document’s DoD.*
