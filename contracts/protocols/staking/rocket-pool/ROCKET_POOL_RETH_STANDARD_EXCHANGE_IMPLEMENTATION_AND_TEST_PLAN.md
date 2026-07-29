# Rocket Pool rETH Standard Exchange Vault — Implementation and Testing Plan

**Date:** 2026-07-25  
**Status:** READY TO IMPLEMENT  
**Normative product:** [`ROCKET_POOL_RETH_STANDARD_EXCHANGE_VAULT_PRD.md`](./ROCKET_POOL_RETH_STANDARD_EXCHANGE_VAULT_PRD.md)  
**Shape references:**  
- `contracts/protocols/staking/etherfi/` (bi-directional sleeve economics peer; dual SE surface; production-first suites)  
- `contracts/protocols/staking/lido/` (layout / FactoryService patterns; **reference only**)  
**Research:** `docs/research/2026-07-23-ethereum-staking-ported-protocols-custom-se-assessment.md`  

**Methodology skills:** `crane-deployment`, `crane-testing`, `indexedex-testing`, `crane-adversarial-testing`, `indexedex-adversarial-testing`

Ordered for incremental delivery. Each phase leaves a green, reviewable slice. Do not reopen PRD locked decisions D1–D29 without a PRD revision.

---

## 0. Locked decisions (copy — PRD is source of truth)

| Topic | Decision |
|-------|----------|
| Yield / `asset()` | **rETH** |
| Intermediate | **None** |
| Liquid sleeve | **WETH** |
| SE surfaces | **In + Out**; **all** defined pairs on **both** |
| Native ETH routes | **None** (no `exchangeInEth`) |
| WETH stake | unwrap → `RocketDepositPool.deposit{value}` → mint rETH |
| WETH pay | sleeve → optional **`rETH.burn`** → ETH wrap WETH → revert |
| User async queue | **Forbidden** (and unavailable on RP surface) |
| Sleeve / rebalance | **Bi-directional buffer**: soft target; stake only if capacity; burn deficit if collateral |
| WETH→SE | **Best-effort** stake overage (capacity-capped); mint always on full eth face |
| WETH→rETH | **Hard** capacity gate |
| Default liquid % | **`0.20e18` (20%)** |
| rETH → WETH | **Inventory swap** + WETH pay ladder |
| Burn out | **ETH → wrap WETH** |
| Shortfall error | **`InsufficientLiquidReserve` only** (user WETH pays) |
| Previews | **ungated** on sleeve / deposit capacity / burn collateral; full `totalReserveEth` share math |
| Usage fee default | **0** |
| Fork ship gate | **Required** including live deposit (when capacity) + live burn (when collateral) |
| Lido / ether.fi packages | **Reference / peers only** — not shipping tracks for this epic |
| Deploy | CREATE3 + registry DFPkg |
| SUT mocks | Forbidden |

### Clarifications locked 2026-07-25 (user Q&A)

| # | Topic | Choice |
|---|--------|--------|
| 1 | Liquid target | Soft band via `rebalance()` + best-effort stake on WETH inflows |
| 2 | Deposit pool full on WETH→SE | Leave excess WETH liquid; still mint SE |
| 3 | Explicit WETH→rETH | Hard capacity fail |
| 4 | Primary exit | Burn only; no withdraw NFT |
| 5 | Shortfall error | `InsufficientLiquidReserve` only |
| 6 | Default liquid % | **20%** |
| 7 | Hard post-mint liquid ≈ target (ether.fi M1/M2) | **No** |
| 8 | Secondary DEX inside SE | Out of scope |

---

## 1. Goals and non-goals

### Goals

1. Package: facets, repo, common, DFPkg, FactoryService, marker.  
2. Full dual-surface route matrix (§3).  
3. WETH pay ladder with optional `rETH.burn`.  
4. Bi-directional sleeve buffer on WETH→SE + `rebalance()`.  
5. Soft capacity (WETH→SE) vs hard capacity (WETH→rETH).  
6. Preview == execution; ungated previews.  
7. Hermetic + fee/oracle + invariant + **adversarial P0**.  
8. Mainnet fork: capacity-aware deposit, sleeve pays, rebalance, **live burn** when collateral allows.

### Non-goals

- DEX secondary market inside SE.  
- User-facing withdraw NFT / async queue UX.  
- `exchangeInEth` / native SE token routes.  
- DETF composition beyond optional opaque-leg smoke.  
- Node operator / minipool / RPL staking flows.  
- Hard forced split-mint to exact liquid % when deposit pool is full.  
- Shipping or finishing Lido/ether.fi packages in this epic.

---

## 2. Error surface

### 2.1 WETH shortfall

```solidity
/// @param requested WETH wei required
/// @param available WETH.balanceOf(vault) at final check (post optional burn)
error InsufficientLiquidReserve(uint256 requested, uint256 available);
```

After failed burn attempt, use **same error** with post-attempt sleeve (PRD D10b).  
**Previews must not emit this.** Execution only.

### 2.2 Deposit capacity (hard routes only)

```solidity
/// @param maxDeposit getMaximumDepositAmount() at check
/// @param requested ETH wei attempted
error InsufficientDepositCapacity(uint256 maxDeposit, uint256 requested);
// or bubble RocketPoolService.InsufficientDepositCapacity
```

| Surface | Behavior |
|---------|----------|
| WETH→rETH (In/Out) | **Revert** capacity error |
| WETH→SE best-effort stake | **Do not** revert SE mint; leave WETH liquid |
| rebalance stake | **No-op** if capacity 0 |

### 2.3 Other

| Error | When |
|-------|------|
| `InsufficientLockedReserve(requested, available)` | rETH pay shortfall |
| `InvalidRoute(tokenIn, tokenOut)` | unsupported / native ETH |
| `DeadlineExpired` | past deadline |
| `Slippage` | minOut / maxIn (incl. deposit fee under-delivery on hard stake) |
| `ZeroAmount` / `ZeroAddress` | guards |
| `InsufficientDeposit` | pull / pretransferred delta |
| Protocol bubbles | deposit disabled, min deposit, burn collateral, pause |

---

## 3. Route matrix checklist (In **and** Out)

Assets: `W` = WETH, `R` = rETH, `S` = SE.

| # | Pair | Exact-in | Exact-out | Exec notes |
|---|------|----------|-----------|------------|
| R1 | W→S | ☐ | ☐ | Mint vs full NAV; **best-effort** stake overage ≤ capacity; rest sleeve |
| R2 | R→S | ☐ | ☐ | Lock R; mint |
| R3 | S→W | ☐ | ☐ | Burn SE; WETH pay ladder (sleeve → burn) |
| R4 | S→R | ☐ | ☐ | Burn SE; transfer rETH |
| R5 | W→R | ☐ | ☐ | Hard capacity; unwrap+deposit; fee-aware |
| R6 | R→W | ☐ | ☐ | Inventory swap; WETH pay ladder |

For each: `preview*` then execute; `assertEq(preview, executed)` (or documented dust).

---

## 4. Layout

```text
contracts/protocols/staking/rocket-pool/
  ROCKET_POOL_RETH_STANDARD_EXCHANGE_VAULT_PRD.md
  ROCKET_POOL_RETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md
  interfaces/
    IRocketPoolRETHStandardVault.sol
    IRocketPoolRETHStandardExchangeDFPkg.sol   # PkgInit / PkgArgs HERE only
  RocketPoolRETHStandardExchangeRepo.sol
  RocketPoolRETHStandardExchangeCommon.sol
  RocketPoolRETHStandardExchangeInTarget.sol
  RocketPoolRETHStandardExchangeInFacet.sol     # facetFuncs: previewExchangeIn, exchangeIn ONLY
  RocketPoolRETHStandardExchangeOutTarget.sol
  RocketPoolRETHStandardExchangeOutFacet.sol
  RocketPoolRETHRebalanceTarget.sol
  RocketPoolRETHRebalanceFacet.sol
  RocketPoolRETHMarkerTarget.sol
  RocketPoolRETHMarkerFacet.sol
  RocketPoolRETHStandardExchangeDFPkg.sol
  RocketPoolRETH_Component_FactoryService.sol
  test/hermetic/
    HermeticRocketPoolPorts.sol   # WETH, rETH, DepositPool (capacity + fee), burn collateral
    HostileWETH.sol               # reentrancy harness only

contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol

test/foundry/spec/protocol/staking/rocket-pool/
  RocketPoolRETHStandardExchange_Core.t.sol
  RocketPoolRETHStandardExchange_Capacity.t.sol
  RocketPoolRETHStandardExchange_BurnPay.t.sol
  RocketPoolRETHStandardExchange_Fees.t.sol
  invariant/
    RocketPoolRETHStandardExchange_Invariant.t.sol
  adversarial/
    Adversarial_RocketPoolRETH_P0.t.sol

test/foundry/fork/eth_main/vaults/staking/rocket-pool/
  RocketPoolRETHStandardExchange_Fork.t.sol
```

### Crane

- Reuse: `IRETH`, `IRocketDepositPool`, `IRocketStorage`, `RocketPoolService`, `RETHRateProvider`.  
- Extend only if SE needs thin capacity/burn helpers — still no minipool/RPL surface.

---

## 5. Implementation phases

### Phase 0 — Scaffold + addresses

- [ ] Package dirs + interfaces with NatSpec  
- [ ] Verify mainnet: rETH, RocketStorage, deposit pool (via storage key), WETH  
- [ ] `PkgArgs`: `rETH`, `weth`, `depositPool` and/or `rocketStorage`  
- [ ] `PkgInit` / `PkgArgs` **on interface only**

**Exit:** compiles stubs; address table in package README or PRD §10 checked.

---

### Phase 1 — Common: NAV, quotes, pull, mint fee, stake/burn helpers

**Deliverables**

- Repo storage: token addrs (no request-id set — no queue)  
- `liquidReserveEth`, `lockedReserveEth`, `totalReserveEth`  
  - liquid = WETH balance  
  - locked = `rETH.getEthValue(rETH.balanceOf(vault))`  
- `_quoteExactIn` / `_quoteExactOut` for full matrix (no sleeve/capacity/burn gate)  
- `_creditEthValueOfAsset` / rate-safe conversions (rETH floor rates)  
- `_securePull`, `_mintWithUsageFee`, `_burnShares`  
- `_creditAssetToReserve`: WETH→liquid; rETH→locked  
- `_stakeWethToReth(amount)`: capacity check; unwrap → deposit; measure rETH delta  
- `_payWeth`: sleeve → burn shortfall → `InsufficientLiquidReserve`  
- `_tryBurnRethForWeth(shortfallEth)`: compute reth needed (ceil), burn, wrap ETH  
- `_bestEffortStakeOverageTowardTarget()`: soft buffer helper for WETH→SE / rebalance  

**Tests**

| ID | Case |
|----|------|
| Q1 | Quote matrix unit/view (hermetic rates) |
| Q2 | Preview WETH-out with **zero sleeve** still returns non-zero quote |
| Q3 | Preview WETH→SE / WETH→rETH with **capacity 0** still returns non-zero quote |

**Exit:** Common + hermetic ports compile; quote tests green.

---

### Phase 2 — In + Out facets (closed-form, dual surface)

**Deliverables**

- InTarget / OutTarget: exact-in/out for R1–R6  
- Facet `facetFuncs`: **only** standard SE selectors (no eth helper)  
- Marker views + interface id  
- DFPkg: vaultTokens `[rETH, WETH]`, ERC4626 asset=rETH, fee type = marker id  
- FactoryService + TestBase registry deploy  
- Default liquid policy **20%** in TestBase  

**Tests**

| ID | Case |
|----|------|
| D1 | Deploy marker, vaultTokens, asset=rETH; liquid policy **20%** |
| P* | For each R1–R6: preview==exec on **In** and **Out** (capacity open; sleeve funded as needed) |
| B1 | W→S exact-in: capacity open → liquid near target band; overage staked as rETH |
| B2 | W→S exact-out: same best-effort semantics |
| B3 | W→S capacity **0**: SE mint succeeds; liquid ≈ full amountIn; rETH unlocked inventory unchanged |
| L1 | S→W / R→W with funded sleeve |
| L2 | S→W empty sleeve, burn collateral 0 → `InsufficientLiquidReserve` exact args |
| L3 | Preview still quotes when L2 would revert |
| N1 | Native ETH / zero address → `InvalidRoute` |
| H1 | W→R capacity 0 → `InsufficientDepositCapacity` (or service error) **exact** |
| H2 | W→R capacity open → preview==exec (fee-aware minOut) |

**Exit:** Core + capacity suites green hermetically (burn port off → sleeve-only WETH pays).

---

### Phase 3 — Burn pay ladder

**Deliverables**

- Wire `rETH.burn` → ETH → WETH  
- Hermetic rETH with controllable collateral / total collateral  
- Ceil reth amount for shortfall (rate-safe)  

**Tests**

| ID | Case |
|----|------|
| BP1 | Sleeve short, burn collateral ≥ shortfall → success; locked rETH down |
| BP2 | Sleeve short, burn collateral 0 → `InsufficientLiquidReserve` |
| BP3 | Exact-in **and** exact-out S→W both use ladder |
| BP4 | R→W inventory swap uses ladder (In and Out) |
| BP5 | minOut still enforced when burn used |

**Exit:** Burn pay suite green hermetically.

---

### Phase 4 — Rebalance

**Deliverables**

- `rebalance()`: stake excess (capacity-capped) / burn deficit (collateral-capped)  
- Band + no request bookkeeping  
- `receive()` + reentrancy lock  

**Tests**

| ID | Case |
|----|------|
| RB1 | liquid ≫ target, capacity open → stake; WETH down; rETH up |
| RB2 | liquid ≫ target, capacity 0 → **no-op** (liquid unchanged) |
| RB3 | liquid ≪ target, collateral open → burn; WETH up; rETH down |
| RB4 | liquid ≪ target, collateral 0 → **no-op** |
| RB5 | User In/Out does **not** enqueue (no request ids exist) |
| RB6 | rebalance never reverts solely on capacity/collateral dry (prefer no-op) |

**Exit:** Rebalance hermetic green.

---

### Phase 5 — Fees + oracle liquid %

| ID | Case |
|----|------|
| F1 | Usage fee 0 vs non-zero feeTo shares |
| F2 | liquid % vault/type/global resolution smoke |
| F3 | Default **20%** resolved in TestBase |

---

### Phase 6 — Invariants

Handler (production vault, hermetic ports):

| Action | Notes |
|--------|--------|
| exchangeIn W→S, R→S | |
| exchangeOut S→W, S→R | catch sleeve/burn reverts |
| exchangeIn/Out W↔R | catch capacity reverts |
| rebalance | |
| donate WETH/rETH | |
| setCapacity / setCollateral | hermetic control (via test helper) |
| optional warp | |

| Inv | Statement |
|-----|-----------|
| I1 | `totalReserveEth == liquid + locked` |
| I2 | `liquidReserveEth == WETH.balance` |
| I4 | share supply conservation (user + feeTo) |
| I5 | donation does not free-mint extractable principal |
| I8 | no nested reentrancy success |
| I9 | policy % does not mint WETH without burn |
| I10 | capacity 0 never creates phantom rETH on W→S |

```bash
forge test --match-path 'test/foundry/spec/protocol/staking/rocket-pool/invariant/**' -vv
```

---

### Phase 7 — Adversarial P0

Follow `crane-adversarial-testing` + `indexedex-adversarial-testing`: production deploy path, no SUT mocks, exact selectors, residual inventory zero on failed txs.

| ID | Theme | Pass criteria |
|----|--------|----------------|
| A0 | pretransferred=true, no balance delta | `InsufficientDeposit`; no mint; sleeve unchanged |
| A1 | Donate WETH | no free SE mint; victim fair claim |
| A2 | Donate rETH | no free SE mint |
| C1 | Reentrancy In (HostileWETH transferFrom) | nested `IsLocked`; outer may succeed |
| C2 | Reentrancy Out (HostileWETH transfer) | nested `IsLocked` |
| C3 | Reentrancy rebalance (if ETH/WETH callback path) | nested `IsLocked` |
| E1 | Round-trip W↔S | conservation of sleeve+locked eth face ± dust |
| E2 | Round-trip R↔S | conservation ± dust |
| E5 | zero amount / deadline | exact errors |
| H1 | empty sleeve + no burn collateral | `InsufficientLiquidReserve` exact args |
| H3 | minOut fail | full revert; residual free inventory 0 |
| S1 | drain sleeve then fail | correct `available` |
| S2 | WETH out does not silently burn more rETH than ladder requires | locked accounting tight |
| S3 | capacity 0 W→S does **not** hard-fail mint | SE shares minted |
| S4 | capacity 0 W→R **does** hard-fail | capacity error; no partial rETH |
| R-route | native ETH | `InvalidRoute` |
| G1 | deposit fee + hard W→R | minOut enforced; no free fee bypass |

```bash
forge test --match-path 'test/foundry/spec/protocol/staking/rocket-pool/adversarial/**' -vv
```

**Deferred P2 (document in suite NatSpec if not shipped):** capacity grief via external pool fill mid-tx MEV (fork-only); burn sandwich on rate update; multi-block collateral drain narratives.

---

### Phase 8 — Mainnet fork

| ID | Case |
|----|------|
| FK1 | Registry deploy with live addrs (storage → deposit pool) |
| FK2 | WETH→rETH when `getMaximumDepositAmount()` allows (hard path) |
| FK3 | WETH→SE best-effort: if capacity, liquid near target; if not, mint still works (document capacity state) |
| FK4 | Fund sleeve; S→W In and Out |
| FK5 | rebalance stake excess when capacity; no-op path when not |
| FK6 | **Live rETH.burn** tops up WETH pay when sleeve short (**required ship gate** when collateral > 0) |
| FK7 | Soft capacity proof: force large WETH→SE and assert mint success regardless of capacity |

**FK6 note:** If mainnet rETH collateral is temporarily zero, **do not soft-pass forever**. Options: (1) choose a block/window with collateral; (2) deal/fund vault rETH and burn against live contract when collateral exists; (3) fail CI until a window works. Hermetic BP* is unit proof but **does not replace** FK6 when collateral is available in the fork environment.

**FK2 note:** If deposit capacity is zero at tip, record `getMaximumDepositAmount()` and either pin a historical block with capacity or assert hard-fail path + FK7 soft path. Prefer a block where both soft and hard deposit paths are exercisable across the suite.

```bash
forge test --fork-url $ETH_RPC_URL \
  --match-path 'test/foundry/fork/eth_main/vaults/staking/rocket-pool/**' -vv
```

---

## 6. Component checklist

### Crane

- [ ] Confirm `RocketPoolService` deposit/burn/capacity covers SE needs  
- [ ] Add thin helpers only if required (no minipool surface)

### Package

- [ ] Repo + Common (quotes dual-surface; soft buffer; burn pay ladder)  
- [ ] In/Out targets + facets (**no** eth entrypoint in facetFuncs)  
- [ ] Rebalance + Marker  
- [ ] DFPkg + FactoryService  
- [ ] Hermetic ports (capacity + collateral knobs)  
- [ ] TestBase registry path  

### Tests

- [ ] Core R1–R6 × In × Out  
- [ ] Capacity soft/hard  
- [ ] Burn pay  
- [ ] Rebalance  
- [ ] Fees  
- [ ] Invariant  
- [ ] Adversarial P0  
- [ ] Fork FK*  

---

## 7. Acceptance criteria

- [ ] PRD D1–D29 respected in code  
- [ ] All routes on **both** `exchangeIn` and `exchangeOut`  
- [ ] Preview ungated; share math on full reserve  
- [ ] WETH pay: sleeve → burn → revert; no user queue  
- [ ] WETH→SE soft stake; mint succeeds at capacity 0  
- [ ] WETH→rETH hard capacity fail  
- [ ] Stake: WETH unwrap → deposit pool  
- [ ] rebalance stake/burn no-ops when gated  
- [ ] Hermetic + adversarial P0 + invariant green  
- [ ] Fork green **including live burn when collateral allows (FK6)**  
- [ ] Best-effort buffer tests (B1–B3) green  
- [ ] Default liquid policy **20%** in test/deploy docs  
- [ ] No SUT mocks; no `new` DFPkg/facets  
- [ ] No `exchangeInEth` in facetFuncs  

---

## 8. Testing best practices (mandatory)

### 8.1 Production-first ladder (AGENTS.md / indexedex-testing)

1. Real production contracts via CREATE3 + FactoryService + **vault registry** DFPkg.  
2. Gold TestBase chain: `CraneTest` → `IndexedexTest` → `TestBase_VaultComponents` → `TestBase_RocketPoolRETHStandardExchange`.  
3. Hermetic **protocol ports** (real iface-shaped deposit pool / rETH) — **not** mocks of the SE diamond, manager, registry, fee oracle.  
4. Mintable / hostile ERC20 **outside SUT** only for funding / reentrancy.  
5. `vm.mockCall` last resort for non-SUT only.

### 8.2 Deploy path anti-patterns

```solidity
// WRONG
new RocketPoolRETHStandardExchangeInFacet();
new RocketPoolRETHStandardExchangeDFPkg(init);
diamondPackageFactory.deploy(pkg, args); // bypass registry for vault DFPkg

// CORRECT
create3Factory.deployRocketPoolRETHStandardExchangeInFacet();
vm.prank(owner);
indexedexManager.deployRocketPoolRETHStandardExchangeDFPkg(pkgInit);
pkg.deployVault(...);
```

### 8.3 Preview / execution

- Single shared quote path for preview and execute.  
- Assert `preview == execution` where closed-form; document ≤ dust only if forced.  
- Never re-implement quote math inside the test — call production `preview*` then `exchange*`.

### 8.4 Capacity and collateral control (hermetic)

Hermetic deposit pool must expose at least:

- `setMaxDepositAmount(uint256)` / `setDepositEnabled(bool)`  
- `setDepositFeeBps(uint16)` optional  
- rETH `setExchangeRate` or fixed rate + `fundCollateral(uint256)` for burns  

Tests must **drive the real vault entrypoints** under those controls — not skip into internal helpers.

### 8.5 Adversarial discipline (crane + indexedex adversarial skills)

| Rule | Apply |
|------|--------|
| Attack catalog IDs | Stable A*/C*/E*/H*/S*/R* in suite NatSpec |
| Residual inventory | Failed txs leave zero free rETH/WETH/SE residue on diamond (except intentional sleeve) |
| Exact errors | `abi.encodeWithSelector` for capacity and liquid shortfall |
| Hostile WETH | Production PkgArgs weth=hostile only in adversarial suite |
| No profit exploit | If unbounded extract works → **production fix before green** |
| Deferred P2 | Document in suite NatSpec, not silent |

### 8.6 Invariant discipline

- Handler uses **try/catch** on expected capacity/burn reverts.  
- Prefer property checks over brittle absolute balances after donations.  
- I5: meaningful deposit still mints &gt; 0 shares after donation (virtual offset).

### 8.7 Fork discipline

- Resolve deposit pool via RocketStorage keys (do not hardcode a stale pool if storage is source of truth).  
- Log capacity and collateral at setUp for triage.  
- FK6 burn: hard gate when collateral exists; if tip has zero collateral, pin block or fail honestly.

---

## 9. Suggested commands

```bash
# Spec (all hermetic)
forge test --match-path 'test/foundry/spec/protocol/staking/rocket-pool/**' -vv

# Adversarial only
forge test --match-path 'test/foundry/spec/protocol/staking/rocket-pool/adversarial/**' -vv

# Invariants only
forge test --match-path 'test/foundry/spec/protocol/staking/rocket-pool/invariant/**' -vv

# Fork
forge test --fork-url $ETH_RPC_URL \
  --match-path 'test/foundry/fork/eth_main/vaults/staking/rocket-pool/**' -vv
```

---

## 10. Implementation order (agent checklist)

```text
Phase 0  scaffold + address verify
Phase 1  Common + hermetic ports + quotes
Phase 2  In/Out + DFPkg + TestBase + route matrix + soft/hard capacity
Phase 3  Burn pay ladder
Phase 4  Rebalance
Phase 5  Fees / oracle smoke
Phase 6  Invariants
Phase 7  Adversarial P0
Phase 8  Mainnet fork
Polish   NatSpec, README, research doc link
```

**Commit cadence suggestion:** one commit per phase exit.

---

## 11. Risks during implementation

| Risk | Mitigation |
|------|------------|
| Confusing soft vs hard capacity | Separate Capacity suite; S3/S4 adversarial; PRD D23/D24 in Common comments |
| Agents reintroduce ether.fi hard split | PRD D22; B3 test capacity 0 mint succeeds with high liquid |
| Burn fees / rate dust break preview==exec | Ceil reth for shortfall; sleeve-only 1:1 when no burn; BP fee tests separate |
| Fork capacity/collateral dry | Hermetic full proof + FK pin/window; no eternal soft-pass on FK6 |
| Deposit fee on hard W→R | minOut after fee; H2/G1 |
| Gas on rebalance burn chunks | Cap burn iterations per rebalance tx if needed |

---

## 12. Comparison to ether.fi plan (for agents)

| Topic | ether.fi plan | **This RP plan** |
|-------|---------------|------------------|
| Yield | weETH + eETH intermediate | **rETH only** |
| WETH→SE | Hard split to target % | **Best-effort stake ≤ capacity** |
| WETH shortfall #2 | Instant redeem manager | **`rETH.burn`** |
| Rebalance queue | Yes (request ids) | **No** |
| Capacity tests | Redeem capacity | **Deposit soft/hard + burn collateral** |
| Adversarial extras | Claim theft Q* | **S3/S4 capacity duality** |

---

## 13. Changelog

| Date | Change |
|------|--------|
| 2026-07-25 | Initial plan: dual-surface Rocket Pool rETH SE; bi-directional sleeve buffer; soft WETH→SE stake; hard WETH→rETH capacity; burn pay ladder; no async queue; hermetic + invariant + adversarial P0 + fork |

---

*Do not mark IMPLEMENTED until §7 acceptance has command evidence. Dual-surface route matrix, soft/hard capacity duality, and live-burn fork (FK6 when collateral allows) are ship gates.*
