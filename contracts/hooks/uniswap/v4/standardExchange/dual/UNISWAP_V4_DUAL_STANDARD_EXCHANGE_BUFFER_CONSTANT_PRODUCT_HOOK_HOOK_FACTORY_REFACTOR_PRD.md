# PRD: Uniswap V4 Dual SE Buffer CP Hook — Hook Factory Package Refactor

**Name:** `UniswapV4DualStandardExchangeBufferConstantProductHook` → **Hook Diamond Package**  
**Date:** 2026-08-04  
**Status:** **Draft v1.0 — plan-ready** (deploy-shape law only; dual CP / SE buffer product law stays on the product PRD)  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/dual/`  
**Package kind:** **Refactor PRD** — migrate the existing **CREATE3 monomorph** dual SE buffer constant-product hook onto the **Uniswap V4 Hook Diamond Package Callback Factory** standard.

**Authority:**

| Layer | Role |
|-------|------|
| **This PRD** | **Deploy / package / factory / registry / vault-surface** law for the dual migration |
| **Product PRD** [`UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`](./UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md) (**v3.12**) | **Still normative** for CP-on-claims, buffer/unwrap, deposit/zap, Permit2, fees, previews — **except** CREATE3/HookMiner/FactoryService-instance-deploy decisions this PRD **supersedes** |
| Factory PRD | `contracts/hooks/uniswap/v4/factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md` |
| Skill | `indexedex-uniswap-v4-hook-packages` |
| Gold consumer | **Sibling** `…/standardExchange/constantProduct/single/` — Single SE BCP is the **closest** gold (same family: SE buffer + CP + LP ERC-20 + vault/SE surfaces) |

**Out of scope (deliberate):**

- `contracts/hooks/uniswap/v4/standardExchange/single/` (legacy **pricing** wrapper) — **not** this workstream.  
- Single SE BCP product math changes.  
- Orbital / quad migrations (separate PRDs).  
- Re-opening dual D78 claim-in composition, D79 zap-eligible residual, or ERC-4626 SE Phase 0 ownership unless deploy forces a thin amendment.

---

## 0. Terminology

| Term | Meaning |
|------|---------|
| **Legacy dual** | Current tree: monomorph hook + `*_FactoryService` CREATE3 mine/deploy via ecosystem `create3Factory` + `HookMinerCreate3` — **no** dedicated on-chain product factory contract |
| **Hook diamond package** | `IUniswapV4HookDiamondPackage` DFPkg + product facet; CREATE2 instance via shared hook factory |
| **Ctor legs** | `(se0, token0)`, `(se1, token1)` free order at deploy |
| **Pool currencies** | Address-sorted pair tokens |
| **Claim supplies** | SE preview-unwrap value of hook-held SE shares — CP reserves |
| **DoD** | §11 |

---

## 1. Goal

Refactor Dual SE Buffer CP so that:

1. Instances are **immutable diamonds** via **shared hook factory** CREATE2 + `mineNonce`.  
2. Package is a **registered vault package**; instances are **registered vaults** (dual is liquidity-holding and SE-coupled — vault registration is **required**, not optional).  
3. Align instance **vault + Standard Exchange surfaces** with Single SE BCP gold where dual product law already implies SE In/Out compatibility (at minimum vault discovery; SE In/Out if product PRD / DETF consumers need them — see D-SE).  
4. Pure package-constant flags matching today’s permission set.  
5. Salt: `PRODUCT_ID` + binding (feeOracle, poolManager, sorted legs) — **no** package address; **no** CREATE3 namespace salt as primary identity.  
6. **Preserve** product PRD v3.12 behavior: dual SE buffer, CP on claims, proportional + single-asset zap deposit, withdraw, Permit2 variants, fee oracle trading + growth, **integrator-initialized** V4 pool (package does **not** create the pool).

### 1.1 Why migrate

| Legacy property | Problem under standard |
|-----------------|------------------------|
| CREATE3 monomorph via FactoryService + HookMinerCreate3 | Wrong instance opcode / factory |
| Library-only deploy (no package/registry) | Not discoverable as vault; not standard product path |
| Deep `isExpectedHook` try-call binding equality | Factory standard wants **thin** `isExpectedInstance` (code + flags) |
| Ctor immutables in Common | Diamond Repo via `initAccount` |
| No DFPkg / no HookFlags facet | Required package shape |
| Sibling Single SE BCP already on package path | Dual must not lag as monomorph sibling in same family |

### 1.2 Why dual is higher vault priority than orbital/quad

Dual holds **SE shares** as inventory and prices on **claims**. It is the natural peer of Single SE BCP for:

- Registry discovery (`vaultsOfToken`, package listing)  
- Future DETF / multi-vault composition consumers  
- Consistent “hook is a vault” operator mental model  

Orbital/quad also register as vaults under their refactor PRDs, but dual **must** implement a vault surface that is at least as complete as Single SE BCP for token/reserve reporting.

---

## 2. Current state (as-built gap analysis)

### 2.1 Layout today

```text
contracts/hooks/uniswap/v4/standardExchange/dual/
  UniswapV4Dual…Hook.sol                    # monomorph entry
  UniswapV4Dual…HookTarget.sol
  UniswapV4Dual…HookCommon.sol               # immutables se/token/currency
  UniswapV4Dual…HookRepo.sol
  UniswapV4Dual…HookMath.sol
  UniswapV4Dual…HookClaimLib.sol
  UniswapV4Dual…HookPullLib.sol
  UniswapV4Dual…Hook_FactoryService.sol      # CREATE3 mine + deploy + isExpectedHook
  interfaces/IUniswapV4Dual…Hook.sol
  product PRD v3.12 + plans (incl. stale dual-buffer plan name)
```

**No** `*Factory.sol` product contract (unlike orbital/quad). Deploy is library-driven for tests/scripts.

### 2.2 Deploy path today

```text
FactoryService.deployHook(create3Factory, poolManager, feeOracle, se0, t0, se1, t1[, namespace])
  → mineNonce loop: salt = hash(namespace, pm, feeOracle, sorted legs, mineNonce)
  → HookMinerCreate3.computeAddress(create3Factory, salt)
  → CREATE3 deploy monomorph with ctor args
  → isExpectedHook deep binding checks for idempotency
```

V4 pool: **not** created by package (integrator `poolManager.initialize`).

### 2.3 Flags today (must remain package-constant)

```text
BEFORE_INITIALIZE | BEFORE_ADD_LIQUIDITY | BEFORE_SWAP | BEFORE_SWAP_RETURNS_DELTA
```

**Note:** Unlike orbital/quad, dual does **not** set `BEFORE_REMOVE_LIQUIDITY` / `BEFORE_DONATE` in FactoryService `requiredFlags()`. Package pure flags **must match this** (product Target permissions).

### 2.4 Binding / identity today

| Field | Law |
|-------|-----|
| `poolManager`, `feeOracle` | Ctor immutables |
| `se0, token0, se1, token1` | Ctor legs; salt uses **token-address-sorted** legs |
| `currency0/1` | Sort of pair tokens |
| Claims / kLast / LP | Repo + monomorph ERC-20 |
| Permit2 | Constant address (not in salt — product C28) |

### 2.5 Gap vs gold Single SE BCP

| Requirement | Dual legacy | Gap |
|-------------|-------------|-----|
| `IUniswapV4HookDiamondPackage` | No | **P0** |
| `PkgInit`/`PkgArgs` on interface | No | **P0** |
| `deployVault` → `deployHookVault` | No | **P0** |
| Shared CREATE2 hook factory | CREATE3 FactoryService | **P0** |
| `PRODUCT_ID` salt | namespace + binding + mineNonce in CREATE3 salt | **P0** |
| Thin `isExpectedInstance` | Deep `isExpectedHook` try-calls | **P0** |
| Product Facet + DFPkg | Monomorph | **P0** |
| Repo bindings only | Common immutables | **P0** |
| `IBasicVault` / `IStandardVault` | No | **P0** |
| `IStandardExchangeIn/Out` on instance | Product is SE-coupled; surface partial today | **P1** — see D-SE |
| Pool init in package | Correctly absent | Keep absent |
| ClaimLib / PullLib / Math | Present | Reuse as libraries |

---

## 3. Locked product decisions (refactor)

### 3.1 Identity & placement

| # | Decision | Value |
|---|----------|--------|
| D1 | Product name | Keep long form **`UniswapV4DualStandardExchangeBufferConstantProductHook`** (or documented short type id for vault type bytes4) |
| D2 | Package type | **`UniswapV4DualSEBCPHookDFPkg`** (recommended short file names like Single SE) **or** full-name DFPkg — plan locks one naming scheme; interface holds structs |
| D3 | Path | Stay under `…/standardExchange/dual/` |
| D4 | Gold shape | **Closest mirror of Single SE BCP** in same family (package + facet + Target + Repo + libs + FactoryService for facets/deployPkg) |
| D5 | Fresh codepath | Do **not** subclass monomorph or Single SE BCP contracts; pattern-copy |
| D6 | Legacy monomorph | Retire after DoD; FactoryService rewritten to package helpers |

### 3.2 Deploy path

| # | Decision | Value |
|---|----------|--------|
| D7 | Product path | `pkg.deployVault(args, mineNonce)` → registry `deployHookVault` → hook factory |
| D8 | Auto-mine | Optional only |
| D9 | Direct hookFactory | Tests / escape only |
| D10 | No product CREATE3 factory | Dual never had one; **do not invent** one — package is the UX |
| D11 | Pool create | **Still not** a package step (integrator initialize) — product D / C law |
| D12 | Premine-first | Same as factory skill |

### 3.3 Salt & flags

| # | Decision | Value |
|---|----------|--------|
| D13 | `PRODUCT_ID` | `keccak256("uv4-dual-se-buffer-constant-product-hook")` (align with legacy DEFAULT_SALT_NAMESPACE intent) |
| D14 | `calcSalt` includes | `PRODUCT_ID`, `poolManager`, `feeOracle`, **token-sorted** legs `(seLo, tLo, seHi, tHi)` |
| D15 | `calcSalt` excludes | package/facet addresses, Permit2, namespace string, caller, raw ctor order if swapped |
| D16 | Leg order | `processArgs` may accept free ctor order; **salt always sorted by pair token address** (legacy FactoryService) so same economic binding → same address |
| D17 | `requiredHookFlags` | Pure; flags §2.3 only (no beforeRemoveLiquidity / beforeDonate unless product Target is deliberately expanded — **default: no expansion**) |
| D18 | `isExpectedInstance` | **Thin** code + flags — supersedes deep D80 factory `isExpectedHook` as **factory collision gate**. Optional deep binding checks may remain as **test helpers only**, not package gate |
| D19 | Supersedes product PRD | Instance CREATE3 mine, FactoryService deployHook as production path, D80 as deploy gate |

### 3.4 Storage & diamond

| # | Decision | Value |
|---|----------|--------|
| D20 | Bindings | se/token/currency/pm/feeOracle → Repo `initAccount` |
| D21 | Claim / pull / math | Keep libraries; Target orchestration |
| D22 | LP ERC-20 | Facet; Repo storage; proxy address = LP token |
| D23 | No diamondCut on package | Immutable after postDeploy |
| D24 | `beforeInitialize` | Still one-pool bind / fee=0 checks; store `poolInitialized` in Repo |

### 3.5 Vault & SE surfaces (family alignment)

| # | Decision | Value |
|---|----------|--------|
| D25 | Package | `IStandardVaultPkg` + `vaultDeclaration` |
| D26 | Instance vault | **Required:** `IBasicVault` + `IStandardVault` with `vaultConfig` for `_registerVault` |
| D27 | `vaultTokens` | Bound **pair tokens** (pool currencies), not SE share tokens — document; reserves report **claim** or SE share balances per product clarity (plan locks one consistent with Single SE BCP style: report inventory users care about) |
| D28 | SE In/Out | **Recommended P1:** expose `IStandardExchangeIn` / `IStandardExchangeOut` for **pair0 ↔ pair1** book routes if closed-form and dual product already has swap previews — **do not invent** multi-hop SE matrix. If product PRD did not require SE surface on dual monomorph, plan may ship vault-only first then SE surface as same-release stretch — **default: vault required (D26); SE surface in DoD if Single SE BCP peer has it for the same “hook as vault” story** |
| D29 | Vault type id | Distinct `HOOK_VAULT_TYPE` for dual |

**D-SE (locked default):** Dual DoD includes **vault surface (D26)**. SE In/Out is **in DoD** if implementors can map dual swap previews to SE methods without product-law change; otherwise document residual and file follow-on — **do not block** deploy-path DoD on SE surface if vault registration already works.

### 3.6 Product law that stays (v3.12)

- CP on **claim supplies**; buffer-in / unwrap-out.  
- Proportional deposit + `depositSingle` zap (D78/D79).  
- Withdraw both pair tokens; Permit2 signature/allowance variants.  
- Fee oracle dexSwapFee residual + growth / `kLast`.  
- Pool fee = 0 plumbing; product mid from claims.  
- No native modifyLiquidity.  
- Preview fidelity per product PRD.  
- Bound SE must support closed-form pair ↔ SE routes (existing D60/D66 gate — still plan Phase 0 verify).

---

## 4. Target architecture

### 4.1 Suggested layout

```text
contracts/hooks/uniswap/v4/standardExchange/dual/
  interfaces/
    IUniswapV4DualStandardExchangeBufferConstantProductHook.sol  # keep/extend
    IUniswapV4DualSEBCPHookPackage.sol                           # NEW (short name OK)
  facets/
    UniswapV4DualSEBCPHookFacet.sol                              # NEW
  UniswapV4DualSEBCPHookDFPkg.sol                                # NEW
  UniswapV4Dual…HookTarget.sol                                   # REWRITE Repo bindings
  UniswapV4Dual…HookRepo.sol                                     # EXTEND
  UniswapV4Dual…HookMath.sol / ClaimLib / PullLib                # keep
  UniswapV4DualSEBCPHook_FactoryService.sol                      # REWRITE: facets + deployPkg
  TestBase_UniswapV4Dual…Hook.sol                                # NEW/rewrite on factory ladder
  product PRD (amend deploy) + THIS FILE + follow-on plan

RETIRE after DoD:
  UniswapV4Dual…Hook.sol monomorph entry
  UniswapV4Dual…HookCommon.sol (fold into Target/Repo)
  CREATE3 HookMiner paths in FactoryService
```

### 4.2 PkgArgs (normative shape)

```solidity
struct PkgInit {
    IVaultRegistryDeployment vaultRegistryDeployment;
    IFacet productFacet;
}

struct PkgArgs {
    address poolManager;
    address feeOracle;
    address standardExchange0;
    address token0;
    address standardExchange1;
    address token1;
}
```

Validation: non-zero; `se0 != se1`; `token0 != token1`; each token ∈ corresponding SE `vaultTokens()` (same as monomorph ctor checks).

### 4.3 Canonical deploy story

```text
1. setHookDiamondPackageFactory
2. deployPkg(dual package)
3. premine mineNonce for PRODUCT_ID + sorted binding
4. pkg.deployVault(args, mineNonce) → registered diamond
5. Integrator initializes V4 pool: currencies sort(token0,token1), fee=0, hooks=proxy
6. deposit / depositSingle / swap / withdraw per product PRD
```

---

## 5. Migration phases

| Phase | Work | Exit |
|-------|------|------|
| **0** | Hook factory green; verify ERC-4626 SE (or production SE) routes for tests (existing dual Phase 0) | SE legs deployable |
| **1** | Package skeleton, salt/flags, vault decl | Inert diamond + `isVault` |
| **2** | Repo bindings; drop Common immutables | View parity |
| **3** | Port deposit/zap/withdraw/swap + Permit2 | Product suite green |
| **4** | Vault surface (D26); optional SE In/Out (D-SE) | Registry + vaultConfig |
| **5** | TestBase on factory ladder; delete monomorph deploy from tests | Single path |
| **6** | Amend product PRD deploy sections; mark stale dual-buffer plan non-authoritative | Docs clean |

---

## 6. Testing expectations

Ladder: factory TestBase → dual product TestBase.

| Area | Assert |
|------|--------|
| Deploy / registry / flags / salt / idempotent / immutable | Skill checklist |
| Sorted salt | Swapped ctor leg order → **same** address |
| SE validation | Token not in SE.vaultTokens reverts at processArgs/init |
| Pool | Deposit works pre-init; swaps need initialize (product law) |
| Product | Dual deposit, depositSingle zap-eligible gate, claim-in composition, withdraw, fee growth |
| Profile | `FOUNDRY_PROFILE=hook_factory` |

Production-first: real dual package, real SEs (ERC-4626 wrapper or production SE TestBases), real hook factory — **no** mock dual SUT.

---

## 7. Explicit supersessions

| Product PRD / code topic | Superseded by |
|--------------------------|---------------|
| CREATE3 + HookMinerCreate3 instance deploy | D7–D12 |
| FactoryService `deployHook` as production UX | D7, D10 |
| Deep `isExpectedHook` as deploy gate (D80) | D18 thin `isExpectedInstance` |
| Package kind “not Facet/DFPkg / not vault diamond” | D2–D4, D25–D29 |
| Namespace string identity | D13–D15 PRODUCT_ID |

CP/SE/zap/fee product law remains v3.12 product PRD.

---

## 8. Non-goals

1. Changing claim-in composition (D78) or zap residual gate (D79).  
2. Building a dedicated dual CREATE3 product factory.  
3. Package-owned V4 pool initialize (stays integrator).  
4. Migrating legacy `standardExchange/single` pricing hook.  
5. Subclassing Single SE BCP diamond.  
6. Post-deploy upgrades.

---

## 9. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| SE reentrancy / IsLocked | Keep existing dual adversarial expectations; diamond reentrancy same as monomorph nonReentrant patterns |
| Stack on facet | Split facet only if needed; libs already factor claim/pull |
| Salt sort bugs | Fuzz free-order args → same CREATE2 address |
| Stale plan filenames | Plan rewrite name locks to dual SE BCP + hook factory; ignore `DUAL_BUFFER_PRICING` plan |

---

## 10. Related files

| Asset | Path |
|-------|------|
| Factory PRD | `…/factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md` |
| Gold package | `…/constantProduct/single/UniswapV4SingleSEBCPHookDFPkg.sol` |
| Product PRD | `./UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md` |
| Skill | `indexedex-uniswap-v4-hook-packages` |

---

## 11. Definition of Done

1. Only product deploy path is package → registry → hook factory.  
2. Package implements `IUniswapV4HookDiamondPackage` + `IStandardVaultPkg` with interface structs.  
3. Instance registered as vault; `vaultConfig` works.  
4. Flags D17; salt D13–D16; thin `isExpectedInstance` D18.  
5. Hermetic dual lifecycle suite green under `FOUNDRY_PROFILE=hook_factory` on package path.  
6. Monomorph CREATE3 FactoryService deploy path removed from production/tests.  
7. Product PRD deploy sections amended / superseded pointer added.  
8. Implementation plan file exists (rewrite from this PRD + product v3.12).  
9. SE In/Out: either in suite or explicitly residual-documented per D-SE without blocking vault DoD.

---

## 12. Open items for plan only

| ID | Question | Default |
|----|----------|---------|
| O1 | Short vs long Solidity type names for DFPkg/Facet | Short `DualSEBCP` like Single SEBCP |
| O2 | SE In/Out in same release | Prefer yes if swap preview maps cleanly |
| O3 | `vaultTokens` / reserve reporting shape | Pair tokens + claim or SE share — match Single SE BCP clarity in plan |
| O4 | Temporary monomorph support | None after suite green |

---

**End of refactor PRD v1.0**
