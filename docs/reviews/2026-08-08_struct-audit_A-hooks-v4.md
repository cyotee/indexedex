# Struct + Audit Readiness Review — A-hooks-v4

- **Date:** 2026-08-08  
- **Agent/role:** area subagent (pilot)  
- **Scope paths:** `contracts/hooks/**` only  
- **Out of scope notes:** DETF consumers, vaults, routers, tests/scripts, `lib/**` (cited only as reference). HANDOFF stack-too-deep incident doc and PRD are process references, not production code.  
- **Status:** **COMPLETE** (inventory complete; struct/gas + audit workstreams addressed; gas directions are static — no `forge` measurement run in this pass)  
- **Commands / tools used:**  
  - `rg` / content search: `struct\s+\w+` under `contracts/hooks/**/*.sol`  
  - Targeted reads of orbital SE buffer Target/Math/Repo/package interface, dual buffer Target, factory DeployCtx, stable QuoteCtx/ZapWork, Layouts, PRD §2–3/6–7, `docs/HANDOFF_CI_BUILD_BLOCKER_STACK_TOO_DEEP.md`  
  - Grep for reentrancy, `new`, `PkgInit`/`PkgArgs`, `via_ir` in `foundry.toml`

---

## 1. Executive summary

### Top 5 opportunities

1. **Deduplicate `SphereLegsWad`** — identical 5-field packing in SE Orbital Math and Target; Target should use `Math.SphereLegsWad` (C3).  
2. **Dead members on `WithdrawFlexibleVars` (orbital)** — `a0`/`a1`/`a2` never written/read; trim to stack-relief fields only.  
3. **Embed `SharesUsed` inside `ZapPlan`** (or return `SharesUsed` only) to cut parallel share/used fields on zap path.  
4. **Share `QuoteCtx` / `ZapWork`** across Balancer vs Curve pure stable hooks (identical layouts).  
5. **Storage packing (C6)** on SE Orbital / Dual / pure stable Layouts (uint8/bool/int24 packing) — pre-launch OK with layout tests; label migration risk.

### Top 5 audit concerns

1. **Historical stack-too-deep CI blocker** on `UniswapV4StandardExchangeOrbitalBufferHookTarget.sol` (~line 740 in HANDOFF); current file already has stack-relief structs around that region — **verify default `forge build`** before audit sign-off.  
2. **`feeWad` discarded** in swap execute helpers (`feeWad;`) while preview re-loads fee from oracle — gas waste + dual source of truth for fee.  
3. **Reentrancy coverage inconsistency** — SE Orbital/Dual/Weighted use `reentrancyStatus`; single SE buffer Layout has **no** lock field.  
4. **String `require` on bind/lock paths** in Repos vs custom errors on money paths — auditor friction / gas.  
5. **Hermetic gas/adversarial measurement gaps** for orbital swap + flexible + zap hot paths (needs package TestBase snapshots).

### Struct count

| Metric | Count |
|--------|------:|
| **Struct definitions verified** | **62** |
| Recommended remove (dead members / redundant wrappers) | ~3–5 members or 1–2 thin wrappers |
| Recommended merge / share (type-level) | ~6–8 candidates (many C3 library share) |
| Explicit do-not-collapse | 12 (see §5) |

**PkgInit/PkgArgs:** all on package **interfaces** (compliant). No interface-struct-only-on-contract violations found in allowlist.

---

## 2. Struct inventory

| Name | File | Kind | Visibility | ~Members | Write sites | Read sites | Lifetime | Notes |
|------|------|------|------------|----------|-------------|------------|----------|-------|
| `InitArgs` | `.../factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol:16` | api | interface / public ABI | 5× `IFacet` | factory ctor | immutables | deploy | Shared factory facets |
| `DeployCtx` | `.../factory/UniswapV4HookDiamondPackageCallBackFactory.sol:72` | execution-context | internal-only | 6 (pkg, processed, salt, nonce, flags, predicted) | `_prepare` / deploy | `_deployAt` | single deploy call | Stack-relief for mine/deploy |
| `Storage` | `.../factory/UniswapV4HookDiamondPackageFactoryAwareRepo.sol:17` | storage | library | 1× factory addr | `_initialize` | getters | permanent | ERC-7201-style slot |
| `Storage` | `.../factory/UniswapV4HookFlagsRepo.sol:12` | storage | library | 1× `uint160` flags | `_set` | `_requiredHookFlags` | permanent | |
| `PkgInit` ×11 | each `I*HookPackage.sol` (see list below) | api | interface | 4–11 facets/registry/oracle | DFPkg ctor | immutables | deploy | **Pattern family** — not identical |
| `PkgArgs` ×11 | each `I*HookPackage.sol` | api | interface | product binding fields | `deployVault` / processArgs | salt + init | deploy | Salt identity rules per PRD |
| `Layout` (orbital swap) | `.../orbital/UniswapV4OrbitalSwapHookRepo.sol:24` | storage | library | ~15 + mapping reserves | `_initializeBindings` | Target/hooks | permanent | 3-token sphere |
| `Layout` (weighted swap) | `.../weighted/UniswapV4WeightedSwapHookRepo.sol:21` | storage | library | dynamic arrays + kLast | init | Target | permanent | n-token |
| `Layout` (balancer quad stable) | `.../stable/quad/balancer/...Repo.sol:19` | storage | library | 4 tokens + RPs + reserves[4] | init | Target | permanent | Near-clone of curve pure |
| `Layout` (curve quad stable) | `.../stable/quad/curve/...Repo.sol:19` | storage | library | same shape as balancer pure | init | Target | permanent | |
| `QuoteCtx` (balancer) | `.../balancer/...Math.sol:162` | stack-relief / execution-context | library | reserves[4], rates[4], i, j, amp, fee | quote helpers | math | call chain | **Duplicate of curve** |
| `QuoteCtx` (curve) | `.../curve/...Math.sol:206` | stack-relief | library | identical | quote helpers | math | call chain | |
| `ZapWork` (balancer) | `.../balancer/...Target.sol:701` | stack-relief | internal | W, workingR, rates, amp, fee | `_zapRebalance` | `_zapRebalanceWork` | single fn | **Duplicate of curve** |
| `ZapWork` (curve) | `.../curve/...Target.sol:699` | stack-relief | internal | identical | same | same | single fn | |
| `Layout` (dual SE CP) | `.../dual/...Repo.sol:22` | storage | library | bindings + kLast + lock | init | Target | permanent | |
| `DepositFlexibleVars` (dual) | `.../dual/...Target.sol:1024` | stack-relief / execution-context | internal | ~14 | `_depositFlexibleSe` | helpers | call chain | 2-leg; caches se/currency |
| `WithdrawFlexibleVars` (dual) | `.../dual/...Target.sol:1168` | stack-relief | internal | ~13 | `_withdrawFlexible` | pay helpers | call chain | |
| `DepositSinglePreview` (dual) | `.../dual/...Target.sol:1393` | execution-context / result | internal | 7 | `_previewDepositSingle` | clamp/mint preview | call chain | Zap preview scratch |
| `Layout` (SE orbital) | `.../se/orbital/...Repo.sol:25` | storage | library | ~20 + mapping | `BindingsInit` init | Target | permanent | SE+RP per leg + sphere |
| `BindingsInit` | `.../se/orbital/...Repo.sol:60` | stack-relief | library | mirrors binding fields | DFPkg init | `_initializeBindings` | init only | Avoids stack-too-deep on init |
| `ZapSplitArgs` | `.../se/orbital/...Math.sol:220` | stack-relief / api-internal | library | 8 | zapSplitWad | residual search | call chain | Preferred entry |
| `ZapSplitResult` | Math:232 | result | library | 5 | zapSplitWad | callers | return | |
| `FullBookArgs` | Math:241 | stack-relief | library | 7 | fullBookShares packed | math | call chain | Dual overload vs flat args |
| `SphereNavArgs` | Math:252 | stack-relief | library | 8 | sphere-NAV shares | math | call chain | |
| `ResidualSearchCtx` | Math:297 | execution-context | library | nested `ZapSplitArgs` + j/k/e* | zapSplitWad | residual loop | call chain | Nested graph |
| `EvalResidualResult` | Math:306 | result | library | 6 | residual eval | search | iteration | |
| `SphereLegsWad` (Math) | Math:455 | stack-relief | library | 5 | `_tryExactInPacked` | sphere try | call chain | **Dup Target** |
| `SphereLegsWad` (Target) | Target:667 | stack-relief | internal | 5 identical | `_loadSphereLegs` | `_sphereExactIn/Out` | call chain | **Stack-too-deep relief (HANDOFF region)** |
| `SwapLiveCtx` | Target:676 | execution-context | internal | 3 | `_loadSwapLiveCtx` | preview exact in/out | call chain | Hot quote path |
| `SharesUsed` | Target:683 | result | internal | 4 | zap sim / multipath | callers | return pack | |
| `DepositFlexibleVars` (orbital) | Target:1439 | stack-relief / execution-context | internal | 12 | `depositFlexible` | fill/pull/buffer | call chain | 3-leg B6 |
| `WithdrawFlexibleVars` (orbital) | Target:1455 | stack-relief | internal | 12 | `withdrawFlexible` | withdraw | call chain | **a0–a2 unused** |
| `FlexScratch` | Target:1619 | stack-relief | internal | 7 | `_fillComputeAddFlexible` | first/full/partial | call chain | Nested under deposit flex |
| `ZapPlan` | Target:1895 | execution-context | internal | 12 | `_planZap` | execute zap | call chain | Overlaps SharesUsed |
| `ZapSimArgs` | Target:2195 | stack-relief | internal | 9 | post-zap share sim | `_computeAddAfterSimulatedZapEffective` | call chain | Overlaps ZapPlan sales/outs |
| `PartialJoinArgs` | `.../se/weighted/...LiquidityLib.sol:14` | stack-relief | library | 7 arrays + supply | partial join | lib | call chain | n∈[2,8] |
| `PartialJoinResult` | same:24 | result | library | shares + usedPair[] | partialJoin | callers | return | |
| `Layout` (SE weighted) | `.../se/weighted/...Repo.sol:28` | storage | library | dynamic + rawReserves | init | Targets | permanent | |
| `Layout` (SE balancer quad) | `.../se/stable/.../balancer/...Repo.sol:31` | storage | library | fixed[4] + scales | init | Targets | permanent | Twin of SE curve |
| `Layout` (SE curve quad) | `.../se/stable/.../curve/...Repo.sol:31` | storage | library | same as SE balancer | init | Targets | permanent | |
| `Layout` (SE CP single) | `.../constantProduct/single/...Repo.sol:21` | storage | library | ~12 + lock | init | Targets | permanent | `pairToken` + `rawToken` |
| `Layout` (single SE buffer) | `.../single/...Repo.sol:14` | storage | library | 7 | `_initialize` | Target | permanent | **No reentrancy field** |

### PkgInit / PkgArgs file list (grouped pattern)

| Family | Interface path | PkgInit gist | PkgArgs gist |
|--------|----------------|--------------|--------------|
| Orbital swap | `orbital/interfaces/IUniswapV4OrbitalSwapHookPackage.sol` | registry, feeOracle, hooks, liq, ERC20Permit set, multi-asset | PM, feeOracle, t0–2, tick, sqrtP |
| Weighted swap | `weighted/interfaces/IUniswapV4WeightedSwapHookPackage.sol` | same ERC20Permit pattern | PM, feeOracle, tokens[], weights[], RPs[], tick, sqrtP |
| Balancer quad stable | `stable/quad/balancer/interfaces/...Package.sol` | hooks+liq+ERC20Permit | PM, t0–3, fee, amp, RPs[4] |
| Curve quad stable | `stable/quad/curve/interfaces/...Package.sol` | same | same shape |
| Dual SE CP | `standardExchange/dual/interfaces/...Package.sol` | hooks, deposit, withdraw, se, ERC20Permit | PM, feeOracle, se0/t0, se1/t1 |
| SE orbital buffer | `standardExchange/orbital/interfaces/...Package.sol` | deposit/withdraw/se/hooks + ERC20Permit | PM, feeOracle, t0–2, se0–2, rp0–2, tick, sqrtP |
| SE weighted buffer | `standardExchange/weighted/interfaces/...Package.sol` | liq/se/hooks + ERC20Permit | n, tokens[], weights[], SEs[], RPs[] |
| SE balancer buffer | `standardExchange/stable/quad/balancer/interfaces/...` | liq/se/hooks + ERC20Permit | tokens[4], SEs[4], RPs[4], amp |
| SE curve buffer | `standardExchange/stable/quad/curve/interfaces/...` | same | same |
| SE CP single | `standardExchange/constantProduct/single/interfaces/...` | se/deposit/withdraw + ERC20Permit | PM, feeOracle, SE, pairToken, rawToken |
| Single SE buffer | `standardExchange/single/interfaces/...` | registry + product + multi-asset only | PM, SE, pairToken |

---

## 3. Redundant members

| ID | Severity | Category | Title | Evidence (path:lines) | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------------------|--------|-----------------|---------|------------|--------------------|------------|----------|
| S-A-hooks-v4-001 | Medium | struct-redundant | Orbital `WithdrawFlexibleVars.a0/a1/a2` never used | `.../orbital/UniswapV4StandardExchangeOrbitalBufferHookTarget.sol:1455-1467`, `_withdrawFlexible` uses local returns only (`1521-1557`) | Dead memory slots; auditor confusion | Drop `a0`/`a1`/`a2` from struct; keep return locals | positive | low | No (internal) | medium | Yes |
| S-A-hooks-v4-002 | Medium | struct-redundant | `feeWad` param on execute paths discarded | Target `:615-631`, `:633-648`, `_internalSwapExactIn` `:1963-1979` (`feeWad;`) | Dual fee source (arg vs re-fetch in preview); wasted stack/arg | Remove param **or** pass fee into preview helpers so fee is single-sourced | positive | low–med | No | medium | Yes |
| S-A-hooks-v4-003 | Low | struct-redundant | Flat `zapSplitWad(8 args)` rebuilds `ZapSplitArgs` then calls packed | Math `:269-294` | Extra memory copies on convenience path | Prefer only packed entry; mark flat overload `@deprecated` for internal callers | neutral/positive | low | No | medium | No |
| S-A-hooks-v4-004 | Low | struct-redundant | `protocolLp` discarded after preview mint | Target `:1585`, `:1867` (`protocolLp;`) | Warning silence only | Return only `supplyAfter` helper or use value | neutral | low | No | high | No |
| S-A-hooks-v4-005 | Low | struct-redundant | Dual flexible loads `se*/currency*` into vars always | dual Target `DepositFlexibleVars` `:1024-1038`, `_loadFlexibleLegs` | Extra MSTORE vs reading Repo when needed | Accept as stack-relief; optional lazy load | unknown | med if removed | No | low | No |
| S-A-hooks-v4-006 | Nit | struct-redundant | Nested `ResidualSearchCtx.a` copies full `ZapSplitArgs` | Math `:297-324` | Nested pointer OK; fields eIn/eJ/eK derived | Keep; document derived fields | n/a | high if flattened poorly | No | medium | No |

---

## 4. Collapse / consolidation proposals

| ID | Severity | Category | Title | Evidence | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------|--------|-----------------|---------|------------|--------------------|------------|----------|
| S-A-hooks-v4-010 | High | struct-collapse **C3** | Duplicate `SphereLegsWad` Math vs Target | Math `:455-461`, Target `:667-673` | Bytecode + maintenance dual | Export single `Math.SphereLegsWad`; Target uses library type; load helpers stay in Target | positive (bytecode) | **med** — verify compile under default profile | No | medium | Yes (after stack compile gate) |
| S-A-hooks-v4-011 | Medium | struct-collapse **C3** | Duplicate `QuoteCtx` Balancer/Curve Math | balancer Math `:162-169`, curve Math `:206-213` | Twin families diverge risk | Shared pure stable math types lib (only if math libs can share without product coupling) | neutral | low | No | medium | No |
| S-A-hooks-v4-012 | Medium | struct-collapse **C3** | Duplicate `ZapWork` Balancer/Curve Target | balancer Target `:701-707`, curve Target `:699-705` | Same | Extract shared zap work struct to shared library or keep clones if isolation preferred | neutral | low | No | medium | No |
| S-A-hooks-v4-013 | Medium | struct-collapse **C2** | `ZapPlan` embeds `SharesUsed` fields | Target `:683-688`, `:1895-1908` | Parallel fields | `struct ZapPlan { …; SharesUsed used; }` or plan returns `SharesUsed` | neutral/positive | med | No | medium | Later |
| S-A-hooks-v4-014 | Medium | struct-collapse **C1/C2** | `ZapSimArgs` overlaps zap sales/outs with `ZapPlan` | Target `:1895-1908`, `:2195-2205` | Two contexts for one zap | Build `ZapSimArgs` from `ZapPlan` slice / single ZapExecCtx | unknown | med | No | low | Later |
| S-A-hooks-v4-015 | Low | struct-collapse **C3** | Dual vs Orbital `DepositFlexibleVars` near-twins | dual `:1024`, orbital `:1439` | 2-leg vs 3-leg arity | Do **not** force one type; optional shared “leg flag + amount” pattern only | n/a | high if forced | No | high | No |
| S-A-hooks-v4-016 | Low | struct-collapse **C3** | Near-clone `PkgInit` across SE buffer packages | SE orbital/weighted/balancer/curve package interfaces | ABI noise | Keep separate per product (facet sets differ); document template only | n/a | n/a | Yes if shared ABI type forced | high | No |
| S-A-hooks-v4-017 | Medium | struct-split **C6** | SE Orbital `Layout` packing | Repo `:25-50` | Extra SLOAD slots for bools/uint8s | Pack `decimals0-2 + bindingsInitialized`; pack `kLastMode + reentrancyStatus` | positive (cold/hot storage) | low | **Yes — storage migration risk** | medium | Later + layout tests |
| S-A-hooks-v4-018 | Medium | struct-split **C6** | Dual/CP Layout bool packing | dual Repo `:22-38`, CP single Repo `:21-36` | Same | Pack decimals + bools + reentrancy | positive | low | storage migration risk | medium | Later |
| S-A-hooks-v4-019 | High | gas / stack | Stack-relief already present on exact-out path | Target `:666-767` (`SwapLiveCtx`, `SphereLegsWad`, `_sphereExactOut`) | Addresses HANDOFF ~740 | **Do not collapse** these; measure if further helper split still needed for default build | n/a | **high if collapsed** | No | high | N/A (keep) |
| S-A-hooks-v4-020 | Low | struct-collapse **C5** | `BindingsInit` vs writing Layout fields | Repo `:59-100` | Init stack safety | Keep BindingsInit; collapsing reintroduces init stack-too-deep | negative if collapsed | high | No | high | No |

**Sketches (selected):**

**C3 SphereLegsWad (S-010)**  
- Before: two identical `{R, L2, xWad, yWad, zWad}`  
- After: only `UniswapV4StandardExchangeOrbitalBufferHookMath.SphereLegsWad`  
- Affected: `_loadSphereLegs`, `_sphereExactIn/Out`, Math residual packing  

**C2 ZapPlan (S-013)**  
- Before: ZapPlan has `shares, used0, used1, used2`  
- After: `SharesUsed r` nested or returned separately  
- Affected: `_planZap`, `_depositSingle`, preview zap  

**C6 Layout packing (S-017)** — storage migration risk; pre-launch allowed with tests.

---

## 5. Do-not-collapse list

| Struct | Reason |
|--------|--------|
| `SwapLiveCtx` + `SphereLegsWad` (quote path) | Known stack-too-deep history; current compile relief for exact-in/out |
| `DepositFlexibleVars` / `FlexScratch` (orbital) | Nested stack frames for B6 flexible; collapsing risks reintroducing stack-too-deep |
| `ZapSplitArgs` / `ResidualSearchCtx` / `EvalResidualResult` | Binary search + 14-arg stack avoidance; nesting is intentional |
| `BindingsInit` | Init-only stack relief; mirrors storage but must stay memory bag |
| `PkgInit` / `PkgArgs` per package interface | Public deploy ABI + salt identity; product-specific |
| `DeployCtx` | Factory mine/deploy stack + clarity |
| `PartialJoinArgs` / `PartialJoinResult` | n-token weighted external pure call boundary |
| `Layout` / `Storage` (all Repos) | Permanent diamond storage; change only as labeled C6 + tests |
| `InitArgs` (hook factory) | Shared factory constructor ABI |
| Dual `DepositSinglePreview` | Local zap preview isolation; not same as orbital `ZapPlan` |
| Pure stable `Layout` vs SE stable `Layout` | Different inventory models (raw reserves vs SE/raw mix) |
| Single SE `Layout` vs SE CP `Layout` | Different product (wrap-only vs CP AMM buffer) |

---

## 6. Gas notes

### Hot paths (this area)

| Path | Where | Struct load | Notes |
|------|-------|-------------|-------|
| Uni V4 `beforeSwap` exact-in/out | SE orbital Target `:534-581` | `_lock`, fee oracle, `_swapExact*Execute` → preview sphere | Hottest; PM-only |
| Preview swap exact in/out | Target `:690-722` | `SwapLiveCtx`, `SphereLegsWad` | View; still gas-relevant for routers |
| Multipath add/remove liquidity | Target `:927+` | various | nonReentrant |
| Zap `depositSingle` | Target `:1910+` | `ZapPlan`, `ZapSimArgs`, Math zapSplit | Double sphere math + internal swaps |
| Flexible deposit/withdraw B6 | Target `:994+` | `DepositFlexibleVars`, `FlexScratch` | SE share legs |
| Dual CP deposit/swap | dual Target | flexible + CP math | Parallel product |
| Pure stable quote/zap | balancer/curve Math+Target | `QuoteCtx`, `ZapWork` | 4-asset Newton-style |
| Hook diamond deploy | factory `DeployCtx` | cold path | mineNonce |

### Classification notes (no invented %)

- Collapsing **stack-critical** quote structs → expected gas **neutral/negative** and **high stack risk** (prefer keep).  
- Removing dead `WithdrawFlexibleVars` outs + `feeWad;` → **small positive**, hot path adjacent.  
- C6 packing → **positive** on bind-heavy SLOAD paths after warm layout; needs measurement.  
- Sharing library types → mainly **bytecode size**, weak per-tx gas.

### Hermetic measurement ideas (implementation phase)

```bash
# Default profile only (no via_ir). Prefer TestBases under contracts/hooks/**.
forge test --match-path 'contracts/hooks/uniswap/v4/standardExchange/orbital/*' --gas-report
forge snapshot --match-test 'test_.*Swap|test_.*Deposit|test_.*Zap|test_.*Flexible'

# Dual CP + pure stable peers for comparison
forge test --match-path 'contracts/hooks/uniswap/v4/standardExchange/dual/*' --gas-report
forge test --match-path 'contracts/hooks/uniswap/v4/stable/quad/**/*' --gas-report
```

Fork only if hermetic TestBase cannot spin PM + SE mocks without production mocks of SUT (prefer gold TestBase patterns out-of-area).

**Note:** HANDOFF mentioned package profiles with `via_ir`; current `foundry.toml` default/fork keep `via_ir = false`, and monorepo law forbids package-specific via_ir workarounds. **Do not recommend via_ir.**

---

## 7. Audit readiness findings

| ID | Severity | Category | Title | Evidence (path:lines) | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------------------|--------|-----------------|---------|------------|--------------------|------------|----------|
| A-A-hooks-v4-001 | **Blocker** | test-gap / compile | Stack-too-deep CI history may still block default `forge build` | `docs/HANDOFF_CI_BUILD_BLOCKER_STACK_TOO_DEEP.md` (error at Target:740); current Target `:666-767` shows partial Strategy B | CI cannot reach tests; audit of uncompilable tree blocked | Confirm `forge build` (default). If still red: more helper splits on quote/zap — **never via_ir**. If green: close handoff | n/a | n/a | n/a | medium (code evolved; compile not re-run here) | **Yes** |
| A-A-hooks-v4-002 | Medium | economic | Fee double-source on swap execute | Target `:550` vs `_previewSwapExactIn` reloading fee; execute drops `feeWad` (`:630`, `:647`) | Theoretical fee mismatch if oracle changes mid-tx; wasted gas | Thread single `feeWad` into preview/execute; drop silent `feeWad;` | positive | low–med | No | medium | Yes |
| A-A-hooks-v4-003 | Medium | reentrancy | Single SE buffer Layout lacks reentrancy status | `.../single/UniswapV4SingleStandardExchangeBufferHookRepo.sol:14-22` | If any external non-PM path exists, reentrancy unprotected; peers lock | Confirm only PM callbacks; if external liquidity/API exists, add lock parity | n/a | n/a | storage if add field | medium | Review now |
| A-A-hooks-v4-004 | Low | reentrancy | SE orbital uses both `nonReentrant` and `_lock` on same status | Target `:81-86`, `:337-344`, `:540` | Correct if same slot; document invariant | NatSpec: “liquidity + beforeSwap share `reentrancyStatus`” | n/a | n/a | No | high | Nit doc |
| A-A-hooks-v4-005 | Low | errors | String `require` on storage init | SE orbital Repo `:81` `"bound"`; SE weighted Repo lock `"REENTRANCY"` | Inconsistent with custom errors; slightly higher gas | Align custom errors with Targets | positive small | n/a | No | high | Later |
| A-A-hooks-v4-006 | Medium | tokens | Buffer / unwrap / free-balance refunds | Target refund + `InsufficientPretransfer` `:2432`; ClaimLib SE paths | Fee-on-transfer / odd SE share tokens can break conservation | Document FoT unsupported; adversarial tests for SE callback reentry under lock | n/a | n/a | n/a | medium | Test plan |
| A-A-hooks-v4-007 | Medium | economic | Preview vs execute for zap/flexible | `_planZap` / `_depositSingle` uses planned used then buffers | Drift if internal swap path diverges from plan | Invariant tests: preview shares ≤ actual refund residual; no silent shortfall | n/a | n/a | n/a | medium | Yes (tests) |
| A-A-hooks-v4-008 | Low | storage | Layout packing undocumented | SE orbital Layout `:25-50` | Auditor hard to see slot map | Comment slot packing intent; ERC-7201 slot names already good | n/a | n/a | if repack | medium | Later |
| A-A-hooks-v4-009 | Low | NatSpec | Money paths partially documented | Target liquidity/swap regions have section banners; some internals thin | Audit navigation cost | NatSpec on external `addLiquidity`, `beforeSwap`, flexible, zap | n/a | n/a | No | medium | Later |
| A-A-hooks-v4-010 | Nit | deploy | Factory `new MinimalDiamondCallBackProxy{salt}` | factory `:163` | Expected CREATE2 proxy; not facet `new` | Keep; document as CREATE2 salt mine path | n/a | n/a | n/a | high | No |
| A-A-hooks-v4-011 | Low | naming | Hook products use token0/1/2, pairToken, standardExchange | single package `pairToken`; SE packages `standardExchanges` | DETF role names apply when wiring DETF; hooks OK as AMM legs | When docs mention DETF attach, use `underlyingVault`/`pairToken` roles | n/a | n/a | No | high | Docs only |
| A-A-hooks-v4-012 | Medium | access | Hook callbacks `_onlyPoolManager` | Target `:278-279`, `:475`, `:539` | Correct Uni v4 pattern | Ensure all IHooks entrypoints check PM (after* pure reverts OK) | n/a | n/a | n/a | high | Spot-check peers |
| A-A-hooks-v4-013 | Medium | test-gap | Hermetic gas + adversarial coverage for orbital SE buffer | TestBase co-located under orbital package; HANDOFF notes profile confusion | Audit readiness incomplete without green hermetic suite | Run TestBase hermetically; adversarial: reenter SE on unwrap, min-SE legs, drain bounds | n/a | n/a | n/a | medium | Yes |
| A-A-hooks-v4-014 | Low | dead-code | `afterSwap` etc. pure revert HookNotImplemented | Target `:584-608` | Intentional permissions | Keep; ensure permissions bitmap matches | n/a | n/a | n/a | high | No |
| A-A-hooks-v4-015 | Nit | PkgInit placement | PkgInit/PkgArgs on interfaces | All `I*Package.sol` under hooks | Compliant with Crane/IndexedEx law | Maintain interface ownership | n/a | n/a | n/a | high | No |

**Access / reentrancy summary (orbital SE buffer):** PM gate on hooks; `nonReentrant` on user liquidity/swap-facing external APIs; shared lock with beforeSwap — **good**.  

**Deploy summary:** DFPkgs take `PkgInit` on interface; product path comments say registry → hook factory — consistent with monorepo deploy law (out-of-area manager/registry not re-audited).

---

## 8. Suggested implementation order (for later plan)

1. **Compile gate:** default `forge build` green for `contracts/hooks/**` (close A-001 / HANDOFF). Struct-only / helper splits if still failing — no via_ir.  
2. **Quick wins:** remove dead `WithdrawFlexibleVars.a0–a2`; thread or drop discarded `feeWad` (S-001, S-002, A-002).  
3. **C3 `SphereLegsWad` unify** under Math; recompile orbital Target (S-010).  
4. **Hermetic gas snapshot** on swap / zap / flexible (baseline before further collapses).  
5. **Optional C2** ZapPlan ↔ SharesUsed / ZapSimArgs after snapshots.  
6. **C6 storage packing** only with storage layout tests + migration notes (pre-launch).  
7. **Peer hygiene:** QuoteCtx/ZapWork share (optional); string require → custom errors; single SE reentrancy review.  
8. **Do not** merge PkgInit families or collapse quote stack structs without compile proof.

---

## 9. Open questions

1. Does **current** default-profile `forge build` still hit stack-too-deep on SE Orbital Target after `SwapLiveCtx`/`SphereLegsWad` landing? (Not executed in this read-only pass.)  
2. Is single SE buffer **hooks-only** (no user deposit API), making missing reentrancy lock acceptable?  
3. Product owner: prefer **bytecode dedup** (shared QuoteCtx/ZapWork) vs **family isolation** for pure Balancer vs Curve hooks?  
4. Are any external integrators already consuming hook `PkgArgs` ABIs (breaks if API structs change)? Pre-launch assumption: no — confirm.  
5. Should `BindingsInit` pattern be copied to SE weighted init (long arg lists) if stack pressure appears there?  
6. Out-of-area: does DETF orbital still pull this Target under default compile graph (HANDOFF Strategy A isolation)?

---

### Inventory completeness note

- **62** struct definitions verified under `contracts/hooks/**`.  
- Grep reported 65 hits; 2–3 lines are non-struct noise (e.g. comment lines near constantProduct targets without `struct` definitions).  
- All workstreams §6.1–6.5 addressed; status **COMPLETE**.
