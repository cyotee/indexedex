# Implementation & Test Plan: Uniswap V4 Orbital Swap Hook

**PRD (product law SoT):** [`UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md`](./UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md) (**v1.14 plan-ready**)  
**This plan (implementor SoT once accepted):** phased delivery, file map, algorithms, tests.  
**Package:** `contracts/hooks/uniswap/v4/orbital/`  
**Date:** 2026-08-03  
**Status:** **Canonical plan — written from PRD v1.14.** Greenfield (no production sources yet). **No code in this plan-only pass.**

**Authority**

| Layer | Role |
|-------|------|
| **PRD v1.14** | Product law (O1–O9, Q1–Q62, D1–D96, §0–§11). **PRD wins** on conflict |
| **This plan** | Implementor SoT for phases, files, tests, peer paths |
| ETHGlobal / Paradigm / Revert factory | Behavioral/math/UX reference only — not deploy law |
| Dual / single buffer hooks | Pattern-copy settle, Permit2 packing spirit, Repo+Target layering — **no inheritance** |

**Read order for implementors**

1. PRD §0 terminology + §1.1 user story + canonical law index  
2. PRD §3 locked tables (focus D14–D35, D48–D59, D72, D78–D96)  
3. PRD §4.3 sphere math, §4.4 fees, §4.5 liquidity + §4.5.1 sphere-NAV, §4.6 settle  
4. PRD §5.2 / §5.6 / §5.7 factory + Permit2 + events  
5. **This plan** §1–§8  

**Methodology skills:** `crane-deployment`, `crane-architecture`, `crane-testing`, `indexedex-testing`, `crane-adversarial-testing`, `uniswap-v4-hooks` / `v4-security-foundations` (permissions + NoOp deltas), dual buffer Target settle pattern-copy.

**Process rule:** Do not reopen PRD-locked decisions without a PRD revision. After each phase: `forge build` green and that phase’s tests green before the next.

---

## 1. Scope (v1 DoD)

Implement production-first package **`UniswapV4OrbitalSwapHook`** + permissionless **`UniswapV4OrbitalSwapHookFactory`**:

1. Bind **three** ERC-20s + **PoolManager** + **feeOracle** (hook ctor immutables).  
2. **Orbital sphere** single orbit: \((R-x)^2+(R-y)^2+(R-z)^2=L^2\) on **1e18** reserves; \(R\) set once on first LP (`max × 10`); \(L^2\) stored sphere parameter recomputed after state changes.  
3. **Three V4 pair pools** as doors; factory **always initializes all three** with `DYNAMIC_FEE_FLAG` + `hooks = hook`.  
4. Hook holds **raw ERC-20** inventory; Repo reserves are SoT (ignore donations).  
5. Fungible **ERC-20 LP** on same contract: decimals **18**, EIP-2612, auto `ORB-{s0}-{s1}-{s2}`, `MINIMUM_LIQUIDITY = 1000` to `address(0)`.  
6. Custom **`addLiquidity` / `removeLiquidity`** only; native CL `modifyLiquidity` reverts.  
7. Swaps via **`beforeSwap` + `beforeSwapReturnDelta`** (custom curve / NoOp); trading fee residual in reserves; V4 fee override with `OVERRIDE_FEE_FLAG`.  
8. Protocol growth: Uni V2–style **`kLast` + dual mode** (`FullProduct` / `SumInterim`); mint LP to `feeTo` from **`usageFeeOfVault`**.  
9. Partial book: prop min over maxed positive legs only; **sphere-NAV** shares (not sum-NAV); seed-only OK. Full book: three-leg Uni V2 only — **no zap**.  
10. Previews **bit-exact** vs execution at same oracle reads.  
11. **Permissionless factory:** CREATE3 (`deployer = factory`), user salt mined off-chain, **`effectiveSalt = keccak256(abi.encodePacked(salt, msg.sender))`**, init all three pools, **AddressSetRepo** binding→hooks.  
12. Hermetic DoD + forks **Ethereum + Base + Robinhood 4663**.  

**Out of scope (v1):** multi-orbit ticks; \(n>3\); SE buffer legs; Facet/DFPkg/diamond hook; CREATE2 instance deploy; on-chain salt mine loop; factory owner/pause; on-hook zap/`depositSingle`; FoT/rebasing; native ETH currency; vault registry `deployPkg` for instances; BaseHook inheritance.

---

## 2. File map (target)

```text
contracts/hooks/uniswap/v4/orbital/
  UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md
  UNISWAP_V4_ORBITAL_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md   # this file

  interfaces/
    IUniswapV4OrbitalSwapHook.sol
    IUniswapV4OrbitalSwapHookFactory.sol

  UniswapV4OrbitalSwapHookMath.sol        # pure: sphere, WAD, shares, NAV, cbrt/growth
  UniswapV4OrbitalSwapHookRepo.sol        # diamond-style storage slot
  UniswapV4OrbitalSwapHookCommon.sol      # reserves, decimals, guards, fee oracle reads
  UniswapV4OrbitalSwapHookTarget.sol      # IHooks + LP execute + settle
  UniswapV4OrbitalSwapHook.sol            # wire: IHooks + ERC-20 + EIP-2612 + ctor

  UniswapV4OrbitalSwapHookFactory.sol     # on-chain CREATE3 + 3× pool init + AddressSet
  UniswapV4OrbitalSwapHook_FactoryService.sol  # mineSalt*, deployFactory helpers
```

**FORBIDDEN:** `*Facet.sol`, `*DFPkg.sol`, Solidity inheritance of Crane/OZ `BaseHook`, `BaseTokenWrapperHook`, `DeltaResolver`, reference `BaseHook`.

**Tests:**

```text
test/foundry/spec/hooks/uniswap/v4/orbital/
  TestBase_UniswapV4OrbitalSwapHook.sol          # or contracts/…/TestBase_*.sol peer style
  UniswapV4OrbitalSwapHook_Factory.t.sol         # F1–F14 + PRD §9.4
  UniswapV4OrbitalSwapHook_Deploy.t.sol          # flags, immutables, radius 0, three pools
  UniswapV4OrbitalSwapHook_Liquidity.t.sol       # first / full / partial / seed / remove
  UniswapV4OrbitalSwapHook_Swap.t.sol            # 6 directions exact-in/out, no drain
  UniswapV4OrbitalSwapHook_Fees.t.sol            # trading residual + growth kLast modes
  UniswapV4OrbitalSwapHook_Preview.t.sol         # bit-exact + ceil/floor
  UniswapV4OrbitalSwapHook_Permit2.t.sol         # empty / sig batch 1–3 / allowance
  UniswapV4OrbitalSwapHook_Reentrancy.t.sol      # LP ↔ swap global lock
  UniswapV4OrbitalSwapHook_Decimals.t.sol        # mixed + >18 / 0

test/foundry/fork/eth_main/hooks/uniswap/v4/orbital/
  UniswapV4OrbitalSwapHook_Ethereum.t.sol

test/foundry/fork/base_main/hooks/uniswap/v4/orbital/
  UniswapV4OrbitalSwapHook_Base.t.sol

test/foundry/fork/robinhood_4663/hooks/uniswap/v4/orbital/   # match repo RH path convention
  UniswapV4OrbitalSwapHook_Robinhood.t.sol
```

---

## 3. Current state (greenfield)

| Item | Status |
|------|--------|
| PRD v1.14 | Present |
| Implementation plan | **This file** |
| Production Solidity | **None** |
| Tests / TestBase | **None** |

**Peers to pattern-copy (do not subclass):**

| Peer | Path | Use |
|------|------|-----|
| Dual Target settle | `…/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookTarget.sol` | take / sync / transfer / settle order |
| Dual Permit2 packing | Dual PRD §7.3 (orbital SoT is PRD §5.6) | spirit only |
| Dual growth fee | Dual D57 / `ConstProdUtils._calculateProtocolFee` | D56 algebra |
| Single buffer Target | `…/standardExchange/single/…Target.sol` | settle / permissions |
| HookMinerCreate3 | `lib/crane/.../HookMinerCreate3.sol` | `computeAddress`, `FLAG_MASK`, `MAX_LOOP` spirit for **off-chain** mine |
| CREATE3 | `lib/crane/.../solmate/utils/CREATE3.sol` (or Crane Creation peer) | factory local CREATE3 |
| AddressSetRepo | `lib/crane/contracts/utils/collections/sets/AddressSetRepo.sol` | binding→hooks |
| LPFeeLibrary | Crane Uni V4 | `DYNAMIC_FEE_FLAG`, `OVERRIDE_FEE_FLAG` |
| FixedPointMathLib / BetterMath | Crane utils | sqrt, cbrt, WAD |

---

## 4. Implementation phases

Ordered for reviewable green slices. **Hook math + LP can start before factory**, but package DoD requires factory path for production deploy tests (hermetic uses factory as product path).

### Phase 0 — Skeleton + interfaces + Repo

**Deliverables**

1. `IUniswapV4OrbitalSwapHook` / `IUniswapV4OrbitalSwapHookFactory` per PRD §5.1 / §5.2.  
2. `UniswapV4OrbitalSwapHookRepo` storage under unique slot e.g.  
   `"indexedex.hooks.uv4.orbital.swap.storage"`:  
   - immutables mirrored or only on wire: prefer **ctor immutables on wire** for pm/feeOracle/tokens/decimals; Repo for `R`, `reserves`, `L_SQUARED`, `kLast`, `kLastMode`, reentrancy lock, ERC-20 balances/allowances/nonces if using Uni V2–style custom ERC-20.  
   - Decide ERC-20 layout: custom Uni V2–style (must support balance on `address(0)`) **not** OZ `_update` that burns `to==0`.  
3. Empty Target/Common/Math/wire compiling with correct hook permissions bitmask.  
4. Factory stub with immutables `poolManager`, `HOOK_FLAGS` constant.  

**Exit:** `forge build` green; NatSpec headers; BUSL/peer license.

### Phase 1 — Math library (pure)

**File:** `UniswapV4OrbitalSwapHookMath.sol`

| Function group | Law |
|----------------|-----|
| `toWad` / `fromWadFloor` / `fromWadCeil` | D17 / Q32 / D64 |
| Sphere exact-in / exact-out (1e18 domain) | PRD §4.3 |
| Trading fee residual + exact-out WAD gross-up `+1` | D20 / D20a |
| V4 pips from feeWad + OVERRIDE bit | D20b |
| First mint shares `sumWad - MIN` | O2 / Q33 |
| Full-book Uni V2 min-ratio used amounts | D24 / Q39 |
| Partial used amounts \(P\) / \(Z\) | D24a / Q43 |
| Sphere-NAV shares | D72 / Q44 / §4.5.1: \(p_i=R-r_i\), \(shares = supply' · V_{in}/V_{before}\) |
| `cbrt` + protocol LP algebra | D55–D56; ConstProdUtils generic branch |
| SumInterim rootK = k | Q11 / Q20 |

**Tests (unit pure):** domain reverts (`T<0`, \(r \ge R\), zero out, drain); floor/ceil symmetry golden; worked SumInterim protocol mint from PRD; worked seed-only NAV example (§4.5.1); prop-only partial reduces to Uni V2 when \(P\) = all positive legs.

**Exit:** Math covered without PoolManager.

### Phase 2 — Common + Target LP (no swap)

**Implement**

1. Decimal cache at ctor (missing → 18).  
2. LP name/symbol `ORB-{s0}-{s1}-{s2}` + address-fragment fallback.  
3. EIP-2612 permit (DOMAIN_SEPARATOR, nonces).  
4. Global reentrancy lock on LP entrypoints (Q34).  
5. `addLiquidity` / `removeLiquidity` / previews:  
   - deadline, mins  
   - D57 protocol mint first when fee-on  
   - first mint / full / partial branches  
   - returns `(shares, a0, a1, a2)` (Q46)  
   - remove burns **msg.sender** only (Q41)  
6. SafeERC20 pulls; Permit2 path can be stubbed to transferFrom-only until Phase 5 **or** land empty `permit2Data` first.  
7. Events `LiquidityAdded` / `LiquidityRemoved` / `ProtocolFeeMinted`.  
8. `beforeAddLiquidity` / `beforeRemoveLiquidity` **revert**.  
9. `beforeInitialize`: pair ⊂ bound, `fee == DYNAMIC_FEE_FLAG`.  

**Peer:** dual/single for structure; **no SE**.

**Exit:** Hermetic TestBase deploys hook via temporary CREATE3 helper **or** early factory; first LP + remove bit-exact previews; MIN on address(0); fee-on growth mint after synthetic reserve growth (can set reserves via controlled swaps later — until then grow via sequential adds + oracle usage fee).

### Phase 3 — Swap settle + dynamic fee

**Implement**

1. `beforeSwap`: only `msg.sender == poolManager`; acquire reentrancy lock.  
2. Exact-in / exact-out sphere paths; update raw reserves; recompute \(L^2\).  
3. **No** protocol mint / **no** `kLast` update on swap (D57).  
4. Return fee override: `uint24(feeWad * 1e6 / 1e18) | OVERRIDE_FEE_FLAG`.  
5. `BeforeSwapDelta` custom curve — pattern-copy dual/single settle (take specified / settle unspecified). Golden tests **all six** directed pairs.  
6. Event `Swap` with native amounts + `feeWad` rate.  
7. Q27 / D63: no full drain; post both trade legs > 0.  

**Exit:** Six directions exact-in/out; bit-exact previews; mid-life fee change; zero fee path; double-haircut not applied.

### Phase 4 — On-chain factory (product deploy path)

**Files:** `UniswapV4OrbitalSwapHookFactory.sol`, `IUniswapV4OrbitalSwapHookFactory.sol`, `*_FactoryService.sol`

| Requirement | Implementation note |
|-------------|---------------------|
| CREATE3 | Local CREATE3; **deployer = factory** (solmate/Crane CREATE3). **Not** ecosystem create3Factory for instances |
| Salt | `effectiveSalt = keccak256(abi.encodePacked(salt, msg.sender))` (Q53/Q61) |
| Flag check | `predict` must have `HOOK_FLAGS` else `InvalidHookSalt` |
| Embed bytecode | `type(UniswapV4OrbitalSwapHook).creationCode` + ctor args |
| Three pools | Binding pairs 01, 12, 02; address-sort currencies; `DYNAMIC_FEE_FLAG`; shared spacing/price (0→60 / tick0 mid) |
| Idempotent | Same caller+salt+binding: skip CREATE3; init missing PoolIds for **this call’s** plumbing (Q54) |
| SaltOccupied | Code present, wrong binding → revert |
| AddressSetRepo | `hooksByBinding[key]._add(hook)` on first CREATE3; key exact binding order (Q62) |
| Views | `predictHookAddress(salt, deployer)`, `isDeployedByFactory`, `hooksOfBinding` / Count / At (0-based external) |
| Events | `HookDeployed` (include effectiveSalt), `PoolsInitialized` |
| Access | No owner, no pause |
| FactoryService | `mineSalt(factory, deployer, flags)`, `mineSaltForBinding(...)`, `deployFactory(pm)` |

**Exit:** PRD §9.4 F1–F14 green; permissionless EOA deploy; different callers same userSalt → different hooks.

### Phase 5 — Permit2 packing

Per PRD §5.6:

| `permit2Data` | Behavior |
|---------------|----------|
| empty | SafeERC20 `transferFrom` all pulled legs |
| `abi.encode(uint8(0), PermitBatchTransferFrom, signature)` | Signature batch; binding-order pulled legs only |
| `abi.encode(uint8(1))` | AllowanceTransfer pulls for all used legs |

No mix; no witness; Permit2 well-known constant.

**Exit:** 1/2/3-leg batch; allowance mode; wrong order reverts.

### Phase 6 — Fees hardening + partial book matrix

1. Dual-mode `kLast` / `kLastMode`; cross-mode no mint.  
2. SumInterim ↔ FullProduct re-seed path.  
3. Seed-only sphere-NAV vs sum-NAV golden (shares ≠ sum-NAV).  
4. Partial prop min only over maxed positive legs (Q43).  
5. Full-book one-/two-sided reverts (Q39).  
6. `ownerFeeShare == 0` fee-off (Q18).  

### Phase 7 — Adversarial + reentrancy + donations

1. Global lock: LP during swap callback and reverse (hostile ERC-20).  
2. Donations ignored for pricing.  
3. Reserve ≥ R reverts.  
4. Full exit dust + R sticky + sumPos > 0.  
5. External second PoolKey (other tickSpacing) allowed; wrong fee reverts.  

### Phase 8 — Forks

Each of Ethereum, Base, Robinhood **4663**:

1. Deploy factory (or use script).  
2. Mine salt for test EOA; `factory.deploy`.  
3. Live or mintable tokens (Q23).  
4. LP + swap ≥1 door; optional growth fee path.  
5. Deploy-if-missing PM / Permit2 / fee oracle (dual D74 peer).  

---

## 5. Algorithm cards (implementor)

### 5.1 Hook permissions (mined into address)

```text
BEFORE_INITIALIZE | BEFORE_ADD_LIQUIDITY | BEFORE_REMOVE_LIQUIDITY
| BEFORE_SWAP | BEFORE_SWAP_RETURNS_DELTA
```

### 5.2 First mint (totalSupply == 0)

```text
require deadline; count(a_iMax > 0) >= 2
used_i = a_iMax (full)
require sum(toWad(used)) > MINIMUM_LIQUIDITY
shares = sumWad - 1000
R = max(a_iWad) * 10
pull; mint 1000 to address(0); mint shares to `to`
reserves = used; recompute L²
if feeOn: set kLast/mode from post reserves else kLast = 0
// no protocol mint
return (shares, used0, used1, used2)
```

### 5.3 Full-book later mint

```text
protocol mint from k_pre vs kLast (if fee-on same mode)
supply' = totalSupply
shares = min_i(a_iMaxWad * supply' / r_iWad)  // all three
used_i = fromWadFloor(shares * r_iWad / supply')
require used_i > 0 for all three; post r < R
pull used only; mint; set kLast post
```

### 5.4 Partial mint (sphere-NAV)

```text
protocol mint SumInterim path if applicable
P = {i: r_i > 0 && a_iMax > 0}; Z = {j: r_j == 0 && a_jMax > 0}
require P ∪ Z ≠ ∅
// used from Uni V2 min over P only (or 0 if P empty)
// used_j = a_jMax for j in Z
p_i = R - toWad(r_i)  // zero leg ⇒ R
V_before = Σ p_i * toWad(r_i)  // > 0 (Q45)
V_in = Σ p_i * toWad(used_i)
shares = supply' * V_in / V_before  // floor
require shares > 0 && >= sharesMin
pull; update; L²; kLast/mode post
```

### 5.5 Swap exact-in (1e18 then denorm)

```text
feeWad = dexSwapFeeOfVault(this); require feeWad < 1e18
dxWad = toWad(amountIn); dxNet = dxWad - floor(dxWad * feeWad / 1e18)
solve y' = R - sqrt(L² - (R-x')² - (R-z)²); dy = y - y'
require 0 < y' < y; amountOut = fromWadFloor(dy); post out raw > 0
reserves[in] += amountIn; reserves[out] -= amountOut; recompute L²
// no kLast update
return override pips | OVERRIDE_FEE_FLAG + BeforeSwapDelta
```

### 5.6 Protocol mint (both modes)

```text
ownerFeeShare = usageFeeWad * 100_000 / 1e18
feeOn = feeTo != 0 && usageFeeWad != 0 && usageFeeWad < 1e18 && ownerFeeShare != 0
FullProduct: rootK = cbrt(x*y*z); SumInterim: rootK = x+y+z
if mode != kLastMode or kLast == 0: protocolLp = 0 (then snapshot post)
else ConstProdUtils-generic:
  protocolLp = supply * (rootK - rootKLast)
    / (rootK * 100_000 / ownerFeeShare + rootK - rootKLast)
mint to feeTo; emit ProtocolFeeMinted if > 0
```

### 5.7 Factory deploy

```text
effectiveSalt = keccak256(abi.encodePacked(salt, msg.sender))
predicted = CREATE3.getDeployed(effectiveSalt, address(this))
require flags OK
if no code:
  CREATE3 deploy hook(pm, feeOracle, t0, t1, t2)
  isDeployedByFactory[hook] = true
  AddressSetRepo._add(hooksByBinding[key], hook)
else require isExpectedHook else SaltOccupied
spacing' = tickSpacing==0 ? 60 : tickSpacing
price' = sqrtPriceX96==0 ? getSqrtPriceAtTick(0) : sqrtPriceX96
for pairs (t0,t1), (t1,t2), (t0,t2):
  key = sorted currencies + DYNAMIC_FEE_FLAG + spacing' + hooks
  if not initialized: initialize(key, price')
return (hook, key01, key12, key02)
```

---

## 6. Storage sketch (Repo)

| Field | Notes |
|-------|--------|
| `R` | Set-once; 0 until first mint |
| `reserves` mapping | Raw native; SoT |
| `L_SQUARED` | Recomputed after LP/swap |
| `kLast` / `kLastMode` | Growth fee |
| reentrancy `locked` | bool or uint |
| ERC-20 | totalSupply, balanceOf, allowance, nonces (if not immutables-only wire) |

**Wire immutables:** `poolManager`, `feeOracle`, `token0/1/2`, `decimals0/1/2`, name/symbol strings.

**Factory storage:**

| Field | Notes |
|-------|--------|
| `poolManager` | immutable |
| `isDeployedByFactory` | mapping |
| `hooksByBinding` | `mapping(bytes32 => AddressSet)` or nested key; encode key = `keccak256(abi.encode(feeOracle,t0,t1,t2))` |

---

## 7. Testing plan

### 7.1 TestBase requirements

- Inherit `CraneTest` → `IndexedexTest` (fee oracle + create3 for **factory deploy only** if used).  
- Deploy real V4 PoolManager (Crane hermetic).  
- Real Vault Fee Oracle (not mock SUT).  
- Three mintable ERC-20s mixed decimals (6/6/18 minimum; include 0 or >18 if practical).  
- **Product path:** `deployFactory` → `mineSalt(factory, address(this), flags)` → `factory.deploy(...)`.  
- Helpers: set per-address dex/usage fees; fund + approve; optional Permit2 at well-known.  

**Never mock:** hook, factory, PoolManager, fee oracle under test.

### 7.2 Hermetic matrix (map to PRD §9.1)

| Area | Cases |
|------|--------|
| Factory | F1–F14 (§9.4): flags, three pools, idempotent, SaltOccupied, deployer scope, AddressSet, binding order key |
| First mint | ≥2 legs; sumWad ≤ MIN reverts; R = max×10; MIN on address(0); LP decimals 18 |
| Full book | three-leg only; one/two-sided revert; unused max not pulled |
| Partial | seed-only NAV; prop on subset of positive; sphere-NAV ≠ sum-NAV golden |
| Remove | bit-exact; msg.sender burn; mins/deadline |
| Swap | 6 dirs exact-in/out; no drain; override bit; fee residual in input reserve |
| Fees | growth mint after swaps; fee-off; cross-mode kLast; ownerFeeShare 0 |
| Preview | bit-exact all routes at same oracle reads; ceil in / floor out |
| Permit2 | empty; mode 0 batch 1–3; mode 1; no mix; bad sig |
| Reentrancy | hostile ERC-20 on LP and swap |
| Init | wrong fee reverts; extra tickSpacing OK |
| Radius | post ≥ R reverts; full exit R sticky |

### 7.3 Fork matrix (PRD §9.2)

| Chain | ID | Notes |
|-------|-----|--------|
| Ethereum mainnet | 1 | factory + deploy + LP + swap |
| Base mainnet | 8453 | same |
| Robinhood Chain | **4663** | same; deploy-if-missing stack |

Tokens free (live or mintable). At least one growth-fee path when configured.

### 7.4 Invariants / fuzz (recommended)

1. \(L^2 = \sum (R - r_i^{18})^2\) after success when \(R>0\).  
2. Swaps: gross in increases input reserve; out decreases; both legs > 0.  
3. Partial mint shares == floor sphere-NAV formula.  
4. Protocol mint ≤ D56 algebra.  
5. `totalSupply > 0` ⇒ sumPosWad > 0.  

### 7.5 Suggested `forge` filters

```bash
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/orbital/*'
forge test --match-contract UniswapV4OrbitalSwapHook_Factory
forge test --match-path 'test/foundry/fork/*/hooks/uniswap/v4/orbital/*'
```

---

## 8. Definition of done (package)

Mirror PRD §11 + this plan:

- [ ] All §2 production files present and NatSpec’d  
- [ ] No BaseHook inheritance; no Facet/DFPkg; no console.log  
- [ ] Factory CREATE3 + off-chain mine helpers green  
- [ ] Hermetic §7.2 green (incl. bit-exact previews, sphere-NAV, Permit2, reentrancy)  
- [ ] Factory F1–F14 green  
- [ ] Forks Ethereum + Base + Robinhood 4663 green  
- [ ] AGENTS.md CREATE3 / production-first compliance  
- [ ] PRD decision IDs cited in NatSpec where helpful (`@dev Q44`, etc.)  

---

## 9. Anti-patterns (fail review)

| Do not | Why |
|--------|-----|
| CREATE2 / Revert Create2.deploy for hook instances | Q49 / D81 |
| Ecosystem `create3Factory.create3*` for each instance | Operator-gated; D78 |
| On-chain salt mine loop in `deploy` | Q50 |
| Sum-NAV seed formula | Superseded by D72 |
| OZ ERC-20 that treats `to==0` as burn | Breaks MIN dead shares D46 |
| Inherit BaseHook / DeltaResolver | D12 |
| Double-haircut trading fee (PM + residual) | D20c |
| Update kLast on swap | D57 |
| `depositSingle` / on-hook zap | Q40 |
| Mock hook/factory/PM/oracle SUT | AGENTS production-first |
| Sort tokens for binding map key | Q62 exact order |
| Use `tx.origin` in salt | Q61 |

---

## 10. Suggested implementor checklist by PRD ID

| Cluster | IDs | Phase |
|---------|-----|-------|
| Shape / no diamond | D1–D13, D46 | 0–2 |
| Sphere / decimals | D14–D19, D17, Q30–Q32 | 1–3 |
| Trading fee | D20–D21, D20a–c, Q7 | 3 |
| Growth fee | D51–D59, Q11, Q18 | 2, 6 |
| LP routes | D22–D25a, D72, Q38–Q41, Q43–Q46 | 2, 6 |
| Settle / reentrancy | D30, D39–D40, Q34 | 3, 7 |
| Factory | D78–D96, Q49–Q62 | 4 |
| Permit2 | D48–D49, Q22, Q36, Q47, §5.6 | 5 |
| Tests | D41–D42, Q9, Q16, Q23, Q48, Q52 | 7–8 |

---

## 11. Revision log

| Date | Change |
|------|--------|
| 2026-08-03 | Initial plan from PRD **v1.14** (factory + sphere-NAV + bit-exact + AddressSetRepo) |

---

**End of plan — implement from this file + PRD v1.14; PRD wins on conflict.**
