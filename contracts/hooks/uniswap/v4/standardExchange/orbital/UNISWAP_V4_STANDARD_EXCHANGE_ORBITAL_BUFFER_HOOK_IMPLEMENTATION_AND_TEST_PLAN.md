# Implementation & Test Plan: Uniswap V4 Standard Exchange Orbital Buffer Hook

**PRD (product law SoT):** [`UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md`](./UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md) (**v0.5 — product law, plan-ready**)  
**This plan (implementor SoT once accepted):** greenfield package under `standardExchange/orbital/` — **no** existing scaffold.  
**Package:** `contracts/hooks/uniswap/v4/standardExchange/orbital/`  
**Date:** 2026-08-04  
**Status:** **Canonical plan — aligned to PRD v0.5**. Ready for implementor stamp, then code. **No production code in this doc-only pass.**

**Authority**

| Layer | Role |
|-------|------|
| **PRD v0.5** | Product law (D1–D68, O1–O12, Q1–Q14, §0–§11, §4.3–§4.6). **PRD wins** on conflict |
| **This plan** | Implementor SoT for phases, file map, helpers, algebra expansions, tests, deploy wiring |
| Orbital monomorph | Sphere / multipath LP / partial book / dual-channel fees / three-door **behavioral** reference only — **do not subclass**; **do not** copy monomorph CREATE3 factory law |
| Single SE Buffer CP | Buffer-last / claim-in-out / SE I/O / zap-in UX / SE In/Out **process** reference only — **do not subclass** |
| Dual SE Buffer CP | Dual SE inventory + claim helpers **pattern** only — adapt to N ≤ 3 optional legs + sphere |
| Weighted hook | Rate-provider **law** reference (shares × `getRate` / 1e18) |
| Hook diamond factory | Deploy / salt / flags / immutability — factory PRD + `indexedex-uniswap-v4-hook-packages` skill |

**Read order for implementors**

1. PRD §0 terminology + §1.1 user story + §13 law index  
2. PRD §3 locked tables (D4–D68, O1–O12) + §9 clarification locks  
3. PRD §4.3 effective reserves, §4.4 sphere + SE composition, §4.5 liquidity / zap / SE In/Out, §4.6 fees  
4. PRD §5 layout, §6 surface, §7 deploy, §8 / §11 DoD  
5. **This plan** §1–§9 (scope, files, helpers, phases, tests)  
6. Skill `indexedex-uniswap-v4-hook-packages` for registry → hook factory path  

**Process rule:** If this plan and PRD disagree, **PRD wins** and this plan must be patched. Do not reopen PRD-locked decisions without a PRD revision. After each phase: `forge build` green and that phase’s tests green before the next.

**Conversation locks (v0.2–v0.5) — implementor card**

| Lock | Value |
|------|--------|
| Product name | `UniswapV4StandardExchangeOrbitalBufferHook` (D1) |
| Deploy | **Hook diamond package only** — registry `deployHookVault` + shared hook factory CREATE2 mine (D57). **Not** monomorph CREATE3 product factory |
| SEs | Optional per leg (0–3); non-zero SEs **pairwise distinct** (D5a / Q1) |
| Rate providers | Optional **only** on SE legs; rates **SE shares** (Balancer SE RP peer); native×rate then `toWad` (D26 / Q2) |
| Fees | **Orbital dual-channel:** `dexSwapFeeOfVault` trading residual; `usageFeeOfVault` growth mint (D50–D56 / Q6) |
| Zap | **Zap-in only** (`depositSingle`); **no** `withdrawSingle` (D41a–D41b / Q10) |
| SE invert | Missing exact-out / invert → **full tx revert** (D31a / Q12) |
| Dust | `MAX_DUST_WEI = 10` free buffered-token refund (D35 / Q4) |
| Pool init | **`postDeploy` initializes all three doors** (D60 / Q5) |
| SE In/Out pull | ERC-20 `transferFrom` if allowance ≥ amount, else Permit2 **AllowanceTransfer** (D49c / Q11) |
| Forks | **Ethereum + Base + Robinhood (4663)** all required (D66 / Q13) |
| LP symbol | **`SEORB-{s0}-{s1}-{s2}`** (D46 / Q14) |
| Test SE | Production ERC-4626 **wrapper** SE(s) + mintable tokens; matrix **0/1/2/3** SE (D65) |
| Integration tests | Prefer full production stack; no mock SUT hook / SE / manager / registry / factory / fee oracle / PM |

---

## 0. Starting state

| Item | Status |
|------|--------|
| PRD v0.5 | Present at package path |
| Hook / DFPkg / FactoryService / interface Solidity | **None** — greenfield |
| Tests / TestBase | **None** (TestBase will be package-adjacent) |
| Orbital monomorph | Peer under `…/hooks/uniswap/v4/orbital/` — sphere/LP/fee **behavioral** reference only |
| Single SE BCP diamond package | Peer under `…/constantProduct/single/` — gold **deploy shape** + buffer/zap process |
| Dual SE BCP | Peer under `…/standardExchange/dual/` — multi-SE claim helpers pattern |
| Hook diamond factory | Present under `contracts/hooks/uniswap/v4/factory/` — **required** production path |
| ERC-4626 wrapper SE | Exists at `contracts/vaults/standard/erc4626/` — thin Phase 0 verify/deploy |

**Do not** start by forking monomorph orbital sources into this package:

| Monomorph orbital | This package |
|-------------------|--------------|
| Raw ERC-20 inventory only | Optional SE shares per leg + raw legs |
| CREATE3 product factory | Hook diamond + registry `deployHookVault` |
| No zap | **Zap-in required** |
| No SE In/Out product surface | **SE In/Out required** |
| Wire inherits Target/Common | Facets + Targets + Repo; cut shared ERC20/vault facets |

**Do not** subclass Single/Dual SE BCP types either — fresh codepath; libs OK for pure math.

---

## 1. Scope (v1 DoD)

Implement production-first package **`UniswapV4StandardExchangeOrbitalBufferHook`**:

1. Bind **exactly three** ERC-20 pool tokens + optional `standardExchange[3]` + optional `rateProvider[3]` + `poolManager` + `feeOracle` (set-once at init). Permit2 = Uniswap well-known constant (not binding arg).  
2. For each leg: raw face inventory **or** SE shares (not both as book). Pool currencies = the three tokens only — **never** SE share addresses.  
3. **Orbital sphere** on **effective reserves** \(e_0,e_1,e_2\) in 1e18: \((R-e_0)^2+(R-e_1)^2+(R-e_2)^2=L^2\); \(R\) set once on first liquidity (`max × 10`); \(L^2\) stored and recomputed after state changes.  
4. **Three Uni V4 pair doors** (01, 12, 02), all `hooks = this`, `fee = DYNAMIC_FEE_FLAG`; shared book + witness.  
5. Buffer pool→SE on add / swap-in / zap used legs; unwrap SE→pool on remove / swap-out — **buffer-last** (D32).  
6. Fungible **ERC-20 LP** on the mined hook proxy (decimals **18**); EIP-2612 via shared facets; prefix **`SEORB-`**.  
7. Multipath **`addLiquidity` / `removeLiquidity`** + **`depositSingle` (zap-in only)**; native CL `modifyLiquidity` **reverts**. **No zap-out.**  
8. **`IStandardExchangeIn` / `IStandardExchangeOut`** for tokenᵢ ↔ tokenⱼ on same sphere book (internal settle; not LP).  
9. Swaps via **`beforeSwap` + `beforeSwapReturnDelta`** (custom accounting / NoOp curve); pattern-copy settle — **no** BaseHook / DeltaResolver inheritance.  
10. Trading residual = live `dexSwapFeeOfVault`; protocol growth = Uni V2–style `kLast` + dual mode from `usageFeeOfVault` (orbital peer).  
11. Deploy: facets CREATE3 + DFPkg via registry; instances via `deployHookVault` + shared hook factory; **`postDeploy` inits all three pools**.  
12. Vault discovery: `IBasicVault` + `IStandardVault` multi-asset; `reserveOfToken` = **effective** reserve.  
13. Hermetic config matrix 0–3 SE + RP on/off; adversarial suite; forks Ethereum + Base + RH 4663.  
14. Size within real CREATE2/runtime limits; split facets/libs as needed without dropping §6 surface.

**Out of scope (v1):** Zap-out / `withdrawSingle`; \(n>3\); multi-orbit ticks; same SE on two legs; monomorph CREATE3 product factory; subclassing orbital/single/dual/weighted contracts; FoT/rebasing pool tokens; native ETH currency; binary-search as primary product law; auto-deploy SE/RP inside package; owner/pause on instance; growing/resetting \(R\); treating V4 `sqrtPriceX96` as product mid; DETF coupling / shared DETF TestBases; rate provider on raw legs; SignatureTransfer on canonical SE In/Out ABI.

**Peer patterns (copy, do not inherit):**

| Peer | Copy what |
|------|-----------|
| Single SE BCP DFPkg + facets | Hook package shape, `deployVault` → `deployHookVault`, shared ERC20/vault facet cuts, FactoryService |
| Orbital monomorph Math / LP / fees | Sphere exact-in/out, multipath first/full/partial, sphere-NAV, dual-mode `kLast`, three-door topology |
| Single SE BCP ClaimLib / buffer-last | Claim-in composition, SE buffer/unwrap tight bounds, dust refund |
| Dual Target settle | `beforeSwap` take / settle / `BeforeSwapDelta` discipline |
| Weighted rate law | Fail-closed `getRate` via staticcall; shares×rate native then toWad |
| Hook factory skill | Salt without package; flags; immutability; postDeploy |

---

## 2. File map (target)

```text
contracts/hooks/uniswap/v4/standardExchange/orbital/
  UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md
  UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # this file

  interfaces/
    IUniswapV4StandardExchangeOrbitalBufferHook.sol
      // product surface + PkgInit/PkgArgs OR split package interface
    IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol
      // IUniswapV4HookDiamondPackage + IStandardVaultPkg + PkgInit/PkgArgs

  UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol
  UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol
  UniswapV4StandardExchangeOrbitalBufferHookRepo.sol
  UniswapV4StandardExchangeOrbitalBufferHookMath.sol          # pure: sphere, WAD, NAV, growth, zap split
  UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol     # SE claim + rate + buffer/unwrap helpers
  UniswapV4StandardExchangeOrbitalBufferHookPullLib.sol      # optional: LP Permit2 + transferFrom packing
  UniswapV4StandardExchangeOrbitalBufferHookTarget.sol       # shared book/guards (or split Targets)
  UniswapV4StandardExchangeOrbitalBufferHookDepositTarget.sol
  UniswapV4StandardExchangeOrbitalBufferHookWithdrawTarget.sol
  UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol     # SE In/Out + vault-facing routes
  UniswapV4StandardExchangeOrbitalBufferHookHooksTarget.sol  # IHooks callbacks (or fold into Target)

  facets/
    UniswapV4StandardExchangeOrbitalBufferHookDepositFacet.sol
    UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet.sol
    UniswapV4StandardExchangeOrbitalBufferHookSeFacet.sol
    UniswapV4StandardExchangeOrbitalBufferHookHooksFacet.sol  # if split from deposit/SE
```

**Shared facets cut into proxy (mandatory — skill law):**

| Cut | Source |
|-----|--------|
| `ERC20Facet` + `ERC5267Facet` + `ERC2612Facet` | ERC20PermitDFPkg parity — LP = proxy |
| `MultiAssetBasicVaultFacet` + `MultiAssetStandardVaultFacet` | vaultTokens / reserveOfToken / vaultConfig / vaultTypes |
| Product facets only | hooks + book + multipath LP + zap + SE In/Out + buffer |

**FORBIDDEN**

- `new` SUT facets/DFPkg/hook instances  
- Monomorph CREATE3 product factory for this package  
- Vault factory salt / `deployVault` path that skips hook factory (wrong flags)  
- Package/facet addresses in `packageSalt`  
- Live `diamondCut` after postDeploy  
- Solidity inheritance of Crane/OZ `BaseHook`, `BaseTokenWrapperHook`, `DeltaResolver`  
- Short production type names (`SEORBHook`, `OrbSEBHook`, …)  

**Tests (canonical names):**

```text
# Package-adjacent TestBase
contracts/hooks/uniswap/v4/standardExchange/orbital/
  TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol

test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/
  UniswapV4StandardExchangeOrbitalBufferHook_Deploy.t.sol
  UniswapV4StandardExchangeOrbitalBufferHook_Binding.t.sol      # 0–3 SE, distinct SE reject, RP rules
  UniswapV4StandardExchangeOrbitalBufferHook_Liquidity.t.sol    # first / full / partial / remove
  UniswapV4StandardExchangeOrbitalBufferHook_ZapIn.t.sol        # depositSingle only
  UniswapV4StandardExchangeOrbitalBufferHook_Swap.t.sol         # 6 dirs × 3 doors, exact-in/out
  UniswapV4StandardExchangeOrbitalBufferHook_SeExchange.t.sol   # IStandardExchangeIn/Out
  UniswapV4StandardExchangeOrbitalBufferHook_Buffer.t.sol       # buffer-last, dust, claim≠raw
  UniswapV4StandardExchangeOrbitalBufferHook_RateProvider.t.sol # RP on/off, fail-closed
  UniswapV4StandardExchangeOrbitalBufferHook_Fees.t.sol         # dual-channel trading + growth
  UniswapV4StandardExchangeOrbitalBufferHook_Preview.t.sol      # bit-exact previews
  UniswapV4StandardExchangeOrbitalBufferHook_Permit2.t.sol      # LP + SE In/Out allowance path
  UniswapV4StandardExchangeOrbitalBufferHook_VaultViews.t.sol   # IBasicVault + IStandardVault
  UniswapV4StandardExchangeOrbitalBufferHook_Adversarial.t.sol  # O12 suite

test/foundry/fork/eth_main/hooks/uniswap/v4/standardExchange/orbital/
  UniswapV4StandardExchangeOrbitalBufferHook_Ethereum.t.sol

test/foundry/fork/base_main/hooks/uniswap/v4/standardExchange/orbital/
  UniswapV4StandardExchangeOrbitalBufferHook_Base.t.sol

test/foundry/fork/robinhood_4663/hooks/uniswap/v4/standardExchange/orbital/
  UniswapV4StandardExchangeOrbitalBufferHook_Robinhood.t.sol
```

Prefer **`FOUNDRY_PROFILE=hook_factory`** (or repo equivalent) for this tree when factory/registry stack requires it.

---

## 3. Asymmetry implementor card (do not forget)

| Topic | Raw Orbital monomorph | Single SE BCP | **This package** |
|-------|----------------------|---------------|------------------|
| Assets | 3 raw | 1 raw + 1 SE claim | **3 legs; 0–3 optional SE** |
| AMM | Sphere on raw face | CP on raw × SE claim | **Sphere on effective reserves** |
| V4 doors | 3 pairs | 1 pair | **3 pairs** |
| Inventory SoT | Repo raw reserves | raw bal + SE shares | **raw Repo and/or SE shares per leg** |
| Free pool token (buffered) | N/A | Not book | **Not book — dust ≤ 10 refund** |
| Rate provider | None | None | **Optional per SE leg** |
| Zap-in | Out of monomorph v1 | Yes | **Yes (required)** |
| Zap-out | N/A | Yes | **No (v1)** |
| SE In/Out | No | Yes | **Yes (required)** |
| Deploy | CREATE3 monomorph factory | Hook diamond package | **Hook diamond package** |
| Pool fee key | `DYNAMIC_FEE_FLAG` | Often `0` (peer) | **`DYNAMIC_FEE_FLAG` only** |
| Growth fee channel | `usageFeeOfVault` | Peer-specific | **`usageFeeOfVault` (orbital dual-channel)** |
| Trading fee | `dexSwapFeeOfVault` residual | Peer fixed % or oracle | **`dexSwapFeeOfVault` residual** |
| LP prefix | `ORB-` | `SSEBCP-` | **`SEORB-`** |
| PRODUCT_ID / salt ns | monomorph salt | `uv4-single-se-buffer-constant-product-hook` | **`uv4-se-orbital-buffer-hook`** (locked below) |
| Distinct SE rule | N/A | One SE | **Non-zero SEs pairwise distinct** |
| First mint | ≥2 multipath | 2-leg geometric | **≥2 multipath only (not zap)** |

---

## 4. Normative helpers (implement early)

### 4.1 Effective reserves (PRD §4.3)

```text
// INTENTIONAL INVENTORY — free buffered-token balance is NOT e_i
for i in 0..2:
  if SE[i] == 0:
      e_i_native = Repo.rawReserve[i]                 // intentional raw inventory
  else:
      seBal_i = IERC20(SE[i]).balanceOf(hook)
      if RP[i] != 0:
          rate = IRateProvider(RP[i]).getRate()       // staticcall; fail-closed if fail or rate == 0
          e_i_native = seBal_i * rate / 1e18          // Q2: native FIRST
      else:
          e_i_native = SE[i].previewExchangeIn(SE[i], seBal_i, token[i])  // fee-inclusive claim
  e_i_wad = toWad(e_i_native, decimals[i])

// Sphere / kLast / NAV / swap quotes use e_i_wad only
// seClaim(i) view always = unwrap preview (before rate)
// effectiveReserve(i) = e_i_native (document units in NatSpec) or expose both native + wad
```

**Views (O1–O2):** `effectiveReserve(i)`, `effectiveReserves()`, `rawReserve(i)`, `seBalance(i)`, `seClaim(i)`, `standardExchange(i)`, `rateProvider(i)`, `isBuffered(i)`, `radius()`, `lSquared()`.

**Never** treat free `token_i.balanceOf(hook)` as book when buffered.  
**Never** multiply RP × SE claim (RP **is** the share→token conversion).

### 4.2 Buffer-last sequencing (D32 / O7 / O11)

```text
1) Quote / size ALL amounts on PRE-BUFFER effective book (snapshot e, R, L²)
2) Pull natives / execute non-buffer inventory moves (unwrap outs, raw credits)
3) Buffer SE legs LAST in BINDING INDEX ORDER for used amounts > 0
4) Re-read effective reserves; mint LP / set kLast / recompute L² from POST-BUFFER book
// Forbidden: re-solve sphere mid-flight after buffer
```

### 4.3 Share / claim composition (D31 / D31a)

```text
// Buffered tokenIn → effective inflow
sharesIn = preview_buffer_token_to_shares(SE_in, amountInNative)   // fee-aware
if RP_in:
    dIn_native = sharesIn * getRate() / 1e18
else:
    dIn_native = claim delta for those shares (preview unwrap of sharesIn)
dIn_wad = toWad(dIn_native)
dIn_net = dIn_wad - floor(dIn_wad * feeWad / 1e18)                 // trading residual

// Sphere solve Δe_out_wad on (e_in, e_out, e_wit, R, L²)

// Buffered tokenOut → native out
if RP_out:
    sharesOut = invert Δe_out_native via rate (ceil/floor per exact-in vs exact-out peer)
    amountOutNative = unwrap sharesOut → token (floor; fee-inclusive)
else:
    amountOutNative = fromWadFloor(claim-out path for Δe_out)

// If required SE exact-out / invert unsupported → FULL TX REVERT (D31a)
// No partial fill; no approximate solver
```

Shared composition for **V4 doors**, **SE In/Out**, and **zap internal** swaps.

### 4.4 Sphere math (pure Math lib — O10)

Behavioral peer: orbital plan §5.5 + PRD §4.4. Domain in **1e18**.

| Function group | Law |
|----------------|-----|
| `toWad` / `fromWadFloor` / `fromWadCeil` | D23 |
| Sphere exact-in / exact-out | PRD §4.4; witness participates; interior branch only |
| Trading residual + exact-out gross-up | D50; exact-out WAD gross-up `+1` peer orbital |
| V4 pips from feeWad + `OVERRIDE_FEE_FLAG` | D51 — informational only; **no double-haircut** |
| First mint shares | `sumWad(used) - MINIMUM_LIQUIDITY` |
| Full-book used amounts | three-leg Uni V2 min-ratio on effective WAD |
| Partial used + sphere-NAV shares | orbital peer (prop on maxed positive; seed zeros; NAV not sum-NAV) |
| `cbrt` + protocol LP algebra | D54–D56; ConstProdUtils-generic branch |
| SumInterim rootK = k | partial book mode |
| **Zap multi-leg closed-form split** | §4.5 this plan + PRD §4.5.3 |
| Shares×rate pure helper | no external calls in pure Math |

**Pure Math must not call SE / RP.** ClaimLib owns external previews.

### 4.5 Zap-in closed-form algebra (PRD §4.5.3 / D41c / Q9)

**Eligibility:** all three \(e_i^{\mathrm{wad}} > 0\) **and** `totalSupply > MINIMUM_LIQUIDITY`.  
**tokenIn** = leg \(i\); others \(j < k\) in binding index order (sequential swap order locked).

**Goal after two internal exact-in swaps on a fixed pre-zap snapshot:** residual \(a_i\) plus proceeds \(a_j, a_k\) proportional to pre-zap effective WAD reserves:

\[
\frac{\mathrm{toWad}(a_i)}{e_i}
=
\frac{\mathrm{toWad}(a_j)}{e_j}
=
\frac{\mathrm{toWad}(a_k)}{e_k}
= \lambda > 0
\]

**Implementor algebra (locked sequential model):**

```text
// Work in WAD domain on SNAPSHOT (e_i, e_j, e_k, R, L²) after protocol mint.
// Let amountInWad = toWad(amountIn).
// Trading fee on each internal swap: same dexSwapFeeWad as public swaps.

// Parameterize by λ:
//   a_i_wad = λ * e_i
//   a_j_wad = λ * e_j
//   a_k_wad = λ * e_k
// Sales s_j_wad, s_k_wad of token i:
//   a_i_wad = amountInWad - s_j_wad - s_k_wad
//   a_j_wad = sphereExactIn_outWad(i→j, s_j_net) on snapshot book (before any swap)
//   a_k_wad = sphereExactIn_outWad(i→k, s_k_net) on book AFTER first internal swap j
//
// LOCKED execution order: lower other-index first (j), then higher (k).
// Previews must be bit-identical to sequential execution.

// Preferred closed form (implementor derives and unit-checks via integration):
// 1) Express a_j_wad as f_j(s_j) = sphere exact-in out on snapshot.
// 2) Require a_j_wad / e_j = a_i_wad / e_i = (amountInWad - s_j - s_k) / e_i
//    → relation between s_j and residual (and similarly for s_k after first swap).
// 3) Solve for λ such that total sales s_j(λ) + s_k(λ) = amountInWad - λ*e_i
//    with 0 ≤ s_j, s_k and s_j+s_k ≤ amountInWad, interior sphere domain.
// 4) If no interior solution (would drain, ≥ R, negative sales) → revert.

// Practical implementation path (allowed if bit-identical):
// - Expose pure `zapSplitWad(e0,e1,e2,R,L2,feeWad,inIdx,amountInWad) → (sJ,sK,a0,a1,a2)`
// - Use simultaneous snapshot quotes ONLY if proven equal to sequential j→k
//   under sphere exact-in; otherwise implement sequential inverse:
//     solve s_j so that prop holds with provisional s_k=0 then refine,
//     OR solve λ via one-shot invert of monotone map g(λ) = sales needed − budget.
// - Unbounded binary search as *primary product law* is FORBIDDEN (PRD §2.3 #6).
//   A bounded fixed-iteration invert (≤ N steps, N constant, documented) is OK only
//   as numerical invert of a proven monotone closed map — prefer algebraic invert.

// Native mapping:
//   s_j = fromWadCeil(s_j_wad) for sale input (user pays more dust-safe)
//   a_* = fromWadFloor for proceeds / residual used in multipath add
// SE composition (D31) applied on each internal swap leg when buffered.
```

**Exit proof for Math phase:** golden integration cases where `previewZapSplit == execution` at same oracle/SE/RP reads; partial/empty/dust-only revert; SE invert fail reverts whole zap (D31a).

### 4.6 Multipath LP (orbital peer adapted to effective book)

#### First mint (`totalSupply == 0`)

```text
require count(a_iMax > 0) >= 2; multipath only (zap reverts)
used_i = a_iMax for positive maxes
require sum(toWad(used_effective)) > MINIMUM_LIQUIDITY
// used effective = face for raw; claim-in map for buffered after buffer-last path
R = max(e_i_used_wad) * R_SAFETY_MULTIPLIER (10)
shares = sumWad - 1000
pull natives; buffer-last SE legs; mint 1000 to address(0); mint shares to `to`
recompute L²; if feeOn set kLast/mode else kLast = 0
// no protocol mint while kLast == 0
```

#### Full-book subsequent

```text
protocol mint from pre-intake k vs kLast if fee-on
shares = min over i of (a_iMaxWad * supply' / e_iWad)   // all three e_i > 0
used_i from shares; require used_i > 0 all three; post e < R
pull; buffer-last; mint; set kLast post
```

#### Partial book

```text
protocol mint SumInterim path if applicable
P = positive effective maxed legs; Z = zero effective with max > 0
prop min over P; seed Z with full max; sphere-NAV shares (orbital §4.5.1 peer)
// zap FORBIDDEN while partial
```

#### Remove

```text
protocol mint if fee-on; pro-rata raw and/or SE share balances on pre-burn supply
burn msg.sender LP only; pay raw; unwrap SE slices → pool tokens to `to`
set kLast; refund free buffered dust > 10 wei to msg.sender
// no zap-out
```

### 4.7 SE I/O matrix (D33)

| Path | Call |
|------|------|
| Buffer token → SE | `exchangeIn(token → SE)`; minOut = tight fee-inclusive preview |
| Unwrap SE → token (pro-rata remove) | `exchangeIn(SE → token)` of seOut shares **or** peer exact-in |
| Unwrap SE → token (swap-out / exact token out) | `exchangeOut(SE → token)` when required; else **full revert** (D31a) |

Prefer **pretransfer** + `pretransferred=true` when SE supports it. SE deadline = `block.timestamp` when required. User liquidity `deadline` is separate.

### 4.8 SE In/Out funding (D49c)

```text
// Canonical IStandardExchangeIn / Out only — no sig fields
if pretransferred:
    require hook holds enough tokenIn (delta/absolute peer)
else:
    if tokenIn.allowance(msg.sender, hook) >= amount:
        SafeERC20.transferFrom(msg.sender, hook, amount)
    else:
        permit2.transferFrom(msg.sender, hook, amount, tokenIn)  // AllowanceTransfer
// pay tokenOut to recipient via transfer
// NEVER mint/burn LP
// same sphere + fee + composition as V4 directed pair
```

Hook is Permit2-aware (`IPermit2Aware` / well-known constant). LP deposits still support transferFrom **and** Permit2 Signature + Allowance (D47) — separate from SE In/Out ABI.

### 4.9 Protocol growth (D52–D56)

```text
feeWad = usageFeeOfVault(this)   // NOT dexSwapFee
ownerFeeShare = feeWad * 100_000 / 1e18
feeOn = feeTo != 0 && feeWad != 0 && feeWad < 1e18 && ownerFeeShare != 0

// k measure on EFFECTIVE wad reserves:
if e0>0 && e1>0 && e2>0: k = e0*e1*e2; rootK = cbrt(k); mode = FullProduct
else:                    k = e0+e1+e2; rootK = k;       mode = SumInterim

// Cross-mode: no mint from incompatible kLastMode; snapshot post-op
// Timing: mint from pre-intake k on add; mint before user burn on remove
// Swaps: no protocol mint; no kLast update
// LP previews simulate dilution when fee-on
```

Trading residual uses **`dexSwapFeeOfVault`** only (D50). Do not use trading fee as growth rate (non-goal #12).

### 4.10 Hook permissions (D59)

```text
BEFORE_INITIALIZE
| BEFORE_ADD_LIQUIDITY
| BEFORE_REMOVE_LIQUIDITY
| BEFORE_SWAP
| BEFORE_SWAP_RETURNS_DELTA
```

Mask against `Hooks.ALL_HOOK_MASK` in factory. `beforeAddLiquidity` / `beforeRemoveLiquidity` always revert. `beforeInitialize`: pair ⊂ bound tokens + `fee == DYNAMIC_FEE_FLAG`.

### 4.11 Algorithm pointers (PRD sections)

| Path | PRD |
|------|-----|
| Effective reserves | §4.3 |
| Sphere exact-in/out + SE invert | §4.4, D31a |
| Multipath add / remove | §4.5.1–§4.5.2 |
| Zap-in | §4.5.3 |
| SE In/Out | §4.5.4 |
| Fees | §4.6 |
| Surface | §6 |
| Deploy / postDeploy | §7, D60 |
| DoD | §8, §11 |

---

## 5. Implementation phases

### Phase 0 — ERC-4626 wrapper SE thin gate **[TestBase gate only]**

**Not** “build ERC-4626.” **Not** invent SE exit fees.

1. Confirm production ERC-4626 wrapper SE deploys via manager/registry path.  
2. Confirm closed-form **token ↔ SE** buffer and unwrap (exact-in + exact-out) with **preview == execution**.  
3. Confirm ability to deploy **up to three distinct** wrapper SEs (one per mintable pool token) for matrix row (d).  
4. Confirm rate provider peer (or mintable/static `IRateProvider` harness implementing real interface) for RP rows — **not** a mock of the hook SUT.

**Exit:** Package-adjacent TestBase can deploy 0–3 real wrapper SEs + mintable tokens + optional RP; buffer/unwrap both directions with preview fidelity.

---

### Phase A — Package skeleton + diamond deploy path

1. Create §2 file map (interfaces, Repo, empty Targets/Facets, DFPkg, FactoryService).  
2. **Interface:** PRD §6 surface + `IStandardExchangeIn`/`Out` + vault discovery selectors; `PkgInit` / `PkgArgs` **on interface** (Crane rule).  
3. **PkgArgs binding:**  
   `(poolManager, feeOracle, token0, token1, token2, se0, se1, se2, rp0, rp1, rp2, tickSpacing?, sqrtPriceX96?)`  
   Permit2 **not** in args.  
4. **Validation (init / processArgs):**  
   - tokens non-zero, pairwise distinct  
   - SE zero **or** `token_i ∈ SE.vaultTokens()`, `token_i != SE`, SEs pairwise distinct when non-zero  
   - RP non-zero **only if** SE non-zero  
   - feeOracle + poolManager non-zero  
5. **DFPkg:**  
   - `PRODUCT_ID = keccak256("uv4-se-orbital-buffer-hook")`  
   - `requiredHookFlags()` = §4.10 mask  
   - `calcSalt` = PRODUCT_ID + pm + feeOracle + tokens[3] + ses[3] + rps[3] — **no** package/facet addresses  
   - `deployVault(args, mineNonce)` → `registry.deployHookVault`  
   - **`postDeploy`:** initialize all three pair doors (address-sorted currencies, `DYNAMIC_FEE_FLAG`, shared spacing default 60, 1:1 mid if zero args)  
   - `diamondConfig` **without** `diamondCut`  
   - Cut shared ERC20Permit + MultiAsset vault facets + product facets  
6. **initAccount:** ERC20Repo + EIP712Repo + product Repo binding + LP name/symbol `SEORB-{s0}-{s1}-{s2}` (address-fragment fallback).  
7. **FactoryService:** CREATE3 facets; `deploy*DFPkg` via manager; mine helpers for flags.  
8. Hook callbacks stubs; reentrancy lock in Repo; disabled CL reverts.  

**Exit:** `forge build` green; TestBase deploys package via registry + hook factory; three pools initialized; flags correct; binding views return args; `R == 0`.

---

### Phase B — Math + ClaimLib (reserves / composition / sphere)

1. Pure `UniswapV4StandardExchangeOrbitalBufferHookMath.sol` per §4.4–§4.5.  
2. `UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol`:  
   - effective reserve read (raw / claim / shares×rate)  
   - buffer claim-in / unwrap claim-out  
   - invert helpers; **revert whole op** on missing exact-out (D31a)  
   - fail-closed RP `getRate`  
3. Common Target helpers: decimals cache (missing → 18), index maps, pair door key builders, fee oracle reads (`dexSwapFee`, `usageFee`, `feeTo`).  
4. Wire `effectiveReserve*` / `seClaim` / `rawReserve` views.  
5. Recompute \(L^2\) helper after inventory changes.

**Exit:** Views compile; hermetic smoke reads zero book; Math pure functions wired (proofs via integration in later phases — prefer no isolated pure-only suite as sole DoD, but pure zap-split golden helpers may be exercised through hook previews).

---

### Phase C — Multipath LP (add / remove) — no swap / no zap

1. Global nonReentrant on add/remove.  
2. `addLiquidity` / `previewAddLiquidity`: first / full / partial branches on **effective** book; buffer-last; MIN → `address(0)`.  
3. Protocol mint pre-intake when fee-on (D55); first mint no growth while `kLast==0`.  
4. Funding: SafeERC20 transferFrom first (Permit2 Phase G).  
5. `removeLiquidity` / preview: pro-rata raw + SE shares; unwrap; mins/deadline; dust refund.  
6. Events: `LiquidityAdded`, `LiquidityRemoved`, `ProtocolFeeMinted` (orbital peer spirit).  
7. Reject reserve ≥ \(R\) post-op; set \(R\) only on first successful add.

**Exit:** Hermetic: first mint (≥2 legs) sets \(R\); full + partial + remove bit-exact previews; buffer-last under SE dilution; dust refund; 0-SE raw-only path green.

---

### Phase D — V4 swaps (three doors) + dynamic fee

1. Shared book swap core: composition → sphere → buffer-last in → unwrap out.  
2. `beforeSwap`: `msg.sender == poolManager` only; reentrancy lock; exact-in/out.  
3. No protocol mint / no `kLast` update on swap.  
4. Return override pips + `OVERRIDE_FEE_FLAG`; residual stays in book.  
5. `BeforeSwapDelta` custom curve — pattern-copy dual/single settle.  
6. Golden: **all six directed pairs** exact-in/out; witness participation; no full drain (D30).  
7. Swaps require \(R > 0\), initialized pool, both trade-leg effective > 0.  
8. Event `Swap` with native amounts + feeWad.

**Exit:** Six directions on all three doors; bit-exact `previewSwapExactIn/Out`; zero-fee path; fee residual grows book; drain attempts revert.

---

### Phase E — SE In/Out compatibility surface

1. `exchangeIn` / `exchangeOut` / previews — **same core** as Phase D book math.  
2. Internal settle only (no PoolManager unlock).  
3. Funding D49c: transferFrom **or** Permit2 AllowanceTransfer fallback; pretransferred path.  
4. Reject SE share addresses, unbound tokens, same in/out.  
5. **Does not** mint/burn LP.  
6. SE missing exact-out invert → full revert (D31a) — explicit test.  
7. Preview SE In/Out matches V4 swap preview for same directed pair (within dust).

**Exit:** Both directions for each token pair; both funding paths; pretransferred; not LP; D31a covered.

---

### Phase F — Zap-in (`depositSingle`) only

1. Gate zap-eligible (full book + supply > MIN).  
2. Protocol mint pre-zap if fee-on.  
3. Closed-form split §4.5; sequential internal swaps j then k by index; emit `ZapSwap` each.  
4. Multipath prop add of residual + proceeds; **buffer-last**; mint LP; set kLast.  
5. No PoolManager unlock on internal swaps.  
6. `previewDepositSingle` + `previewZapSplit` bit-exact.  
7. Revert: partial book, empty, dust-only MIN residual, first mint, SE invert fail mid-zap.  
8. **Do not** implement `withdrawSingle`.

**Exit:** Zap-in green on full book for each of three tokenIn; previews exact; forbidden states revert; no zap-out surface.

---

### Phase G — Permit2 on LP deposits + polish funding

1. Well-known Permit2 constant; not in salt/args.  
2. `addLiquidity` / `depositSingle`: empty `permit2Data` → transferFrom only; non-empty → Permit2 for **every** pulled leg — **no mixed** path (D47).  
3. SignatureTransfer + AllowanceTransfer as packing requires (peer dual/orbital § packing).  
4. Refund unused deposit tokens to **msg.sender**.  
5. SE In/Out remains AllowanceTransfer fallback only (no SignatureTransfer on that ABI).

**Exit:** LP Permit2 matrix green; SE In/Out allowance path still green; bad sig / wrong order / expired reverts.

---

### Phase H — Fees hardening + vault discovery + views

1. Dual-channel fee views: `dexSwapFee()`, `usageFee()`, `feeTo()`, `kLast()`, `kLastMode()`.  
2. Full-book product vs partial SumInterim growth paths; cross-mode no mint.  
3. feeTo non-receivable → whole liquidity op reverts (adversarial).  
4. Yield / rate move mid without swap (re-read SE + RP).  
5. `IBasicVault`: `vaultTokens()` = binding tokens; `reserveOfToken` = **effective** (not free dust).  
6. `IStandardVault`: vaultTypes includes SE In/Out + Basic + Standard + product ids; contentsId / fee type ids.  
7. ERC165 supportsInterface for required ids.

**Exit:** Fee matrix + vault views green; yield moves effective mid; growth mint after reserve growth.

---

### Phase I — Config matrix + adversarial + hermetic complete

1. Matrix rows: **0 SE**, **1 SE**, **2 SE**, **3 SE**; for ≥1 buffered config, RP on and RP off.  
2. Distinct-SE binding rejects (same SE twice). RP on raw leg rejects.  
3. Adversarial O12:  
   - reentrancy LP ↔ swap ↔ SE In/Out  
   - donation dilution (SE shares / raw inventory components)  
   - feeTo non-receivable  
   - SE revert mid-buffer / mid-zap → full tx revert  
   - RP fail-closed  
   - partial-book drain attempts  
4. Mixed decimals (6/6/18 minimum).  
5. Full §8.2 matrix green.

**Exit:** Hermetic DoD matrix complete; no mock SUT.

---

### Phase J — Forks (D66)

| Chain | ID | Notes |
|-------|-----|--------|
| Ethereum mainnet | 1 | deploy-if-missing PM / Permit2 / fee oracle stack |
| Base mainnet | 8453 | same |
| Robinhood Chain | **4663** | same |

**Tokens:** mintable test ERC-20s + wrapper SEs OK (fork = protocol integration, not live stables).  
**Smoke minimum:** deploy package → first add (≥2 legs, ≥1 buffered config preferred) → swap on ≥2 doors → remove; include one zap-in when full book; one SE In/Out path.

**Exit:** All three fork smokes green.

---

### Phase K — Polish

1. NatSpec: binding vs pool order; effective reserve; buffer-last; SE In/Out vs LP; dual-channel fees; no zap-out; `SEORB-` prefix.  
2. `forge build --sizes` vs real limits; externalize PullLib/ClaimLib if needed without dropping surface.  
3. Confirm no monomorph factory; no SE shares as pool currencies; no peer subclassing; no DETF imports.  
4. Confirm `postDeploy` three doors; salt excludes package.  
5. PRD decision IDs in NatSpec where helpful (`@dev D31a`, `@dev D41c`).

**Exit:** Package ready for merge per §10.

---

## 6. Locked constants (implementor card)

| Item | Value | PRD |
|------|--------|-----|
| Product name | `UniswapV4StandardExchangeOrbitalBufferHook` | D1 |
| PRODUCT_ID | `keccak256("uv4-se-orbital-buffer-hook")` | plan / D58 |
| MINIMUM_LIQUIDITY | `1000` → `address(0)` | D40 |
| R_SAFETY_MULTIPLIER | `10` | D21 |
| MAX_DUST_WEI | `10` | D35 |
| LP decimals | `18` | D38 |
| LP symbol prefix | `SEORB-` | D46 |
| Pool fee | `LPFeeLibrary.DYNAMIC_FEE_FLAG` | D14 |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` | D7 |
| Hook flags | §4.10 mask | D59 |
| Pool init defaults | tickSpacing `60`, 1:1 mid if zero | D60 |
| ownerFeeShare | `usageFeeWad * 100_000 / 1e18` floor | D53 |
| Repo slot (suggested) | `indexedex.hooks.uv4.se.orbital.buffer.storage` | plan |
| Asset count | exactly 3 | D4 |

**Custom errors:** implementor invents names (PRD plan-only remaining). Prefer clear reasons: `InvalidBinding`, `DuplicateSE`, `RateProviderWithoutSE`, `ReserveGteRadius`, `NotZapEligible`, `InvalidRoute`, `SeInvertUnsupported`, `Reentrancy`, `Expired`, `Slippage`, `UnauthorizedPoolManager`, etc.

**Events (minimum):** `LiquidityAdded`, `LiquidityRemoved`, `DepositSingle`, `ZapSwap`, `Swap`, `ProtocolFeeMinted`, `PoolsInitialized` (package/factory as appropriate).

---

## 7. Deploy architecture (normative)

### 7.1 Path

```text
1. setHookDiamondPackageFactory(hookFactory)   # once per manager
2. indexedexManager.deployPkg / FactoryService deploy DFPkg (CREATE3 + vault registry)
3. off-chain mine mineNonce so CREATE2 address flags match requiredHookFlags()
4. pkg.deployVault(typedArgs, mineNonce)
     → registry.deployHookVault(pkg, abi.encode(args), mineNonce)
       → hookFactory.deployWithMineNonce(...)
       → package postDeploy: init Pool 01, 12, 02
       → _registerVault(hook)
```

### 7.2 Salt law (D58)

```text
packageSalt = keccak256(abi.encode(
  PRODUCT_ID,
  poolManager,
  feeOracle,
  token0, token1, token2,
  se0, se1, se2,
  rp0, rp1, rp2
))
// tickSpacing / sqrtPrice plumbing MAY be omitted from salt if not product identity
// NEVER include package address, facet addresses, or Permit2

finalSalt = keccak256(abi.encode(packageSalt, mineNonce))
```

### 7.3 FactoryService sketch

```solidity
// Facets via create3Factory.deployFacet(...)
// DFPkg via indexedexManager.deployPkg / typed deploy*DFPkg (vm.prank owner in tests)
// Instance:
function deployHook(
    IUniswapV4StandardExchangeOrbitalBufferHookPackage pkg,
    PkgArgs memory args,
    uint256 mineNonce
) internal returns (address hook) {
    hook = pkg.deployVault(args, mineNonce);
}
// Helpers: mineNonceForArgs(pkg, args), predictHookAddress(...), isExpectedInstance thin check
```

**Idempotent deploy:** same binding + mineNonce → expected instance; wrong code at address → revert.

### 7.4 postDeploy pool keys

```text
for each pair in (0,1), (1,2), (0,2):
  currency0, currency1 = sort(token_a, token_b)
  PoolKey{ currency0, currency1, fee: DYNAMIC_FEE_FLAG, tickSpacing, hooks: this }
  if not initialized: poolManager.initialize(key, sqrtPriceX96)
```

LP add/remove **do not** require init (D62). Swaps do.

---

## 8. Testing plan

### 8.1 Rules

- Production-first (AGENTS.md, `indexedex-testing`, `crane-testing`, hook package skill).  
- **No** mock hook / SE SUT / manager / registry / hook factory / fee oracle / PoolManager.  
- Hermetic SE = production **ERC-4626 wrapper** SE (and/or production SE ports).  
- Mintable ERC-20s OK (non-SUT harness). Optional static rate provider implementing `IRateProvider`.  
- Hostile reentrancy ERC-20 only for attack tests (non-SUT).  
- Package-adjacent TestBase: `CraneTest` → `IndexedexTest` → vault components → hook factory registry path → this package.  
- **No** DETF package dependency for merge.  
- Previews bit-exact at same oracle / SE / RP reads (D49).

### 8.2 Hermetic DoD matrix

| ID | Case | PRD |
|----|------|-----|
| Ph0 | Wrapper SE deploy; token↔SE routes; preview==exec | D65 |
| Dep1 | Registry + hook factory deploy; flags match; three pools postDeploy | D57/D59/D60 |
| Dep2 | Salt excludes package; PRODUCT_ID binding fields include SE+RP | D58 |
| Dep3 | Idempotent redeploy same binding+nonce | plan |
| B1 | Reject zero tokens / duplicate tokens / zero pm / zero feeOracle | D8 |
| B2 | Reject SE not listing token; SE==token; **duplicate non-zero SE** | D5a/D9 |
| B3 | Reject RP without SE; allow RP=0 with SE | D6 |
| B4 | Allow all SE=0 (raw-only degenerate) | D11/Q7 |
| M0–M3 | Config matrix 0/1/2/3 buffered legs | D65 |
| RP1 | RP set: effective = shares×rate native then toWad | D26 |
| RP2 | RP unset: effective = SE claim | D25 |
| RP3 | RP fail / rate 0 reverts paths needing leg | O6 |
| L1 | First mint ≥2 legs sets R=max×10; MIN on address(0) | D21/D40/D42 |
| L2 | First mint 1 leg / zap reverts | D42/D41a |
| L3 | Full-book three-leg min-ratio; buffer-last; preview==exec | D43/D32 |
| L4 | Partial sphere-NAV; zap forbidden while partial | D44 |
| L5 | Remove pro-rata unwrap; mins/deadline; dust refund | D45/D35 |
| L6 | Post e ≥ R reverts | D21 |
| Z1 | depositSingle each tokenIn when zap-eligible | D41a |
| Z2 | previewZapSplit / previewDepositSingle bit-exact | D41c/D49 |
| Z3 | Zap reverts empty / partial / MIN-only residual | D41a |
| Z4 | Sequential j then k; ZapSwap×2; buffer-last; no PM unlock | Q9/O5 |
| Z5 | No withdrawSingle in ABI | D41b |
| S1 | Six directed exact-in on three doors | D37 |
| S2 | Six directed exact-out | D37 |
| S3 | Witness participates (third effective) | D29 |
| S4 | No full drain trade legs | D30 |
| S5 | Trading residual in book; override pips informational | D50/D51 |
| S6 | Swaps before R>0 revert | D21/D62 |
| SE1 | exchangeIn all pairs; preview==exec | D49a |
| SE2 | exchangeOut all pairs; preview==exec | D49a |
| SE3 | SE preview matches V4 swap preview | D49a |
| SE4 | transferFrom path + AllowanceTransfer fallback | D49c |
| SE5 | pretransferred path | D49c |
| SE6 | Not LP mint/burn | D49a |
| SE7 | SE invert unsupported → whole tx reverts | D31a |
| SE8 | SE share / unbound / same token reverts | D49b |
| F1 | Growth mint on add/remove when fee-on; kLast modes | D52–D56 |
| F2 | Fee-off; no growth mint | D53 |
| F3 | Previews simulate dilution | D56 |
| F4 | Swaps do not mint growth LP | D55 |
| Y1 | SE yield / rate move mid without swap | D28 |
| V1 | vaultTokens = binding tokens; reserveOfToken = effective | D64 |
| V2 | vaultTypes / ERC165 includes SE In/Out + Basic + Standard | D64 |
| P1 | LP transferFrom + Permit2 packing; no mixed legs | D47 |
| N1 | Reentrancy LP↔swap↔SE reverts | D48/O12 |
| N2 | Donation dilutes LPs (accepted) | D36 |
| N3 | feeTo non-receivable reverts whole op | O12 |
| N4 | SE revert mid-buffer/zap: full tx reverts | O12/D31a |
| E1 | LP symbol `SEORB-…` | D46 |
| E2 | Free buffered dust not book | D24–D27/D35 |

### 8.3 Fork matrix

| ID | Case |
|----|------|
| FK1 | Ethereum: deploy + LP + swap + remove (+ zap smoke) |
| FK2 | Base: same |
| FK3 | Robinhood 4663: same |

Mintable tokens + wrapper SEs allowed. Production PM/Permit2/oracle when present; deploy-if-missing production-equivalent.

### 8.4 Commands

```bash
forge build
forge build --sizes

# Hermetic
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/*' -vv

# Forks (use repo profiles / RPC env)
forge test --match-path 'test/foundry/fork/**/hooks/uniswap/v4/standardExchange/orbital/*' -vv
```

---

## 9. Storage sketch (Repo)

| Field | Notes |
|-------|--------|
| Binding | tokens[3], se[3], rp[3], poolManager, feeOracle (or immutables via init) |
| Decimals | cached uint8[3]; missing → 18 |
| `R` | set-once; 0 until first mint |
| `L_SQUARED` | recomputed after LP/swap |
| `rawReserve[3]` | intentional raw inventory (0 when leg fully buffered book) |
| `kLast` / `kLastMode` | FullProduct vs SumInterim |
| Reentrancy lock | global for LP / zap / SE In/Out / beforeSwap body |
| LP metadata | name/symbol (ERC20Repo shared) |
| Optional | cached PoolId/keys for doors; not required if recomputed |

**Shared repos:** ERC20Repo, EIP712Repo, MultiAssetBasicVaultRepo / StandardVaultRepo as peers for discovery init.

**Do not** store free buffered-token balances as pricing SoT.

---

## 10. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Size (3-door + SE×3 + RP + zap + SE In/Out + diamond) | Facet split; ClaimLib/Math/PullLib; shared ERC20/vault facets; `--sizes` early |
| Agent copies monomorph orbital deploy | §3 card; Phase A hook factory only; anti-patterns §12 |
| Agent treats free pair as book | Effective reserve helpers + E2/VR tests |
| Agent multiplies RP × claim | D26 / RP1 tests |
| Agent re-quotes after buffer | Buffer-last O13 sequencing tests L3/Z4/S* |
| Agent implements zap-out | Explicit non-goal; Z5 ABI assert |
| Zap sequential vs simultaneous preview drift | Lock sequential j→k; bit-exact previewZapSplit |
| SE exact-out soft-fail | D31a full revert + SE7 |
| Same SE on two legs | B2 binding reject |
| Using monomorph CREATE3 for instances | Deploy tests Dep1; skill checklist |
| Package address in salt | Dep2 + review |
| Double-haircut trading fee | D51 residual only; S5 |
| Growth uses dexSwapFee | Dual-channel tests F*; non-goal #12 |
| Mixed Permit2 + transferFrom on one deposit | D47 no mixed + P1 |
| SignatureTransfer on SE In/Out ABI | D49c only AllowanceTransfer fallback |
| DETF creep | No DETF imports; independent TestBase (D67) |
| Incomplete matrix ship | M0–M3 + forks all three chains required |

---

## 11. Definition of done (package)

Mirror PRD §11 + this plan:

- [ ] All §2 production files present and NatSpec’d  
- [ ] Diamond package deploys via registry + hook factory; correct flags; **postDeploy** three doors  
- [ ] Binding validates tokens, distinct optional SEs, RP-only-with-SE  
- [ ] Effective reserves = raw **or** shares×rate **or** SE claim; free buffered dust not book  
- [ ] Sphere exact-in/out + partial + full multipath LP green; buffer-last under SE dilution  
- [ ] Zap-in green when zap-eligible; reverts otherwise; **no zap-out**  
- [ ] SE In/Out green (transferFrom + AllowanceTransfer + pretransferred); not LP; D31a covered  
- [ ] Dual-channel fees green; previews bit-exact  
- [ ] LP Permit2 + transferFrom; symbol `SEORB-`  
- [ ] Config matrix 0–3 SE + RP rows green  
- [ ] Adversarial O12 green  
- [ ] Forks Ethereum + Base + Robinhood 4663 green  
- [ ] No monomorph CREATE3 product factory; no SE shares as pool currencies; no peer subclassing  
- [ ] Size within real limits  

---

## 12. Explicit non-actions for coding agents

Do **not**:

- Subclass monomorph orbital, Single SE BCP, Dual SE BCP, weighted, or wrapper buffer contracts.  
- Deploy instances via monomorph CREATE3 product factory or vault-factory salt (wrong V4 flags).  
- Put package/facet addresses or Permit2 in `packageSalt`.  
- Treat SE share addresses as pool currencies.  
- Treat free buffered-token balance as effective reserve.  
- Multiply rate provider on top of SE claim.  
- Put rate provider on raw legs.  
- Bind the same non-zero SE on two legs.  
- Re-solve sphere mid-flight after buffer (buffer-last).  
- Ship `withdrawSingle` / zap-out.  
- Soft-fail SE exact-out invert (must full-revert).  
- Use binary search as primary zap/swap product law.  
- Collapse multipath/zap LP into `exchangeIn`/`exchangeOut` only (or reverse).  
- Use `dexSwapFeeOfVault` as protocol growth rate.  
- Update `kLast` or mint growth LP on every swap.  
- Inherit `BaseHook` / `BaseTokenWrapperHook` / `DeltaResolver`.  
- Reimplement ERC-20 / EIP-2612 / multi-asset vault view facets in product code.  
- Mock hook / SE SUT / manager / registry / factory / fee oracle / PoolManager.  
- Require DETF packages for hermetic DoD.  
- Post-deploy `diamondCut` on live instances.  
- Grow or reset \(R\) after first mint / full exit.  
- Treat V4 `sqrtPriceX96` as product mid after init.  
- Skip any of Ethereum / Base / Robinhood 4663 fork DoD.  
- Invent short production type names (`SEORBHook*`, etc.).

---

## 13. Suggested coding order (single agent or handoff)

```text
0. Phase 0  — wrapper SE verify/deploy in TestBase (0–3 SEs)
1. Phase A  — interfaces + Repo + DFPkg + FactoryService + postDeploy three doors
2. Phase B  — Math + ClaimLib + effective reserve views
3. Phase C  — multipath add/remove + first R + buffer-last (0-SE + 1-SE smoke)
4. Phase D  — V4 beforeSwap three doors + trading residual
5. Phase E  — SE In/Out shared core + D49c funding
6. Phase F  — zap-in closed-form + previewZapSplit
7. Phase G  — LP Permit2 packing
8. Phase H  — growth fees + vault discovery + yield/rate mid
9. Phase I  — full matrix 0–3 SE + RP + adversarial
10. Phase J — Ethereum + Base + RH 4663 forks
11. Phase K — sizes / NatSpec / anti-pattern audit
```

---

## 14. Revision log (this plan)

| Date | Change |
|------|--------|
| 2026-08-04 | **Initial plan from PRD v0.5:** greenfield SE Orbital Buffer Hook diamond package; effective-reserve sphere; 0–3 optional distinct SEs; optional RP (shares×rate); buffer-last; three doors via postDeploy; zap-in only; SE In/Out with BasicVaultCommon pull; dual-channel fees; hermetic matrix + ETH/Base/RH forks; phases 0–K; anti-patterns; implementor SoT. |

---

## 15. Summary for coding agents

```text
PRODUCT: UniswapV4StandardExchangeOrbitalBufferHook
PATH:    contracts/hooks/uniswap/v4/standardExchange/orbital/
LAW:     PRD v0.5 + THIS PLAN (PRD wins on conflict)
DEPLOY:  Hook diamond package → registry.deployHookVault → shared hook factory
         postDeploy inits ALL THREE pair doors (DYNAMIC_FEE_FLAG)
BOOK:    Sphere on effective reserves (raw | SE claim | shares×rate)
SE:      Optional per leg; non-zero SEs distinct; buffer-last; free dust ≠ book
ZAP:     depositSingle only (full book); NO withdrawSingle
SWAP:    Three V4 doors + SE In/Out share one composition core
FEES:    dexSwapFee = trading residual; usageFee = growth mint (orbital dual-channel)
TESTS:   Production-first; matrix 0–3 SE; adversarial; forks 1 + 8453 + 4663
NEVER:   Subclass peers; monomorph factory; SE as pool currency; mock SUT; zap-out
```
