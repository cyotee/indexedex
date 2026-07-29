# ether.fi weETH Standard Exchange Vault — Implementation and Testing Plan

**Date:** 2026-07-24  
**Status:** READY TO IMPLEMENT  
**Normative product:** [`ETHERFI_WEETH_STANDARD_EXCHANGE_VAULT_PRD.md`](./ETHERFI_WEETH_STANDARD_EXCHANGE_VAULT_PRD.md)  
**Shape reference:** `contracts/protocols/staking/lido/` (reference only; not shipping track)  
**Research:** `docs/research/2026-07-23-ethereum-staking-ported-protocols-custom-se-assessment.md`  

**Methodology skills:** `crane-deployment`, `crane-testing`, `indexedex-testing`, `crane-adversarial-testing`, `indexedex-adversarial-testing`

Ordered for incremental delivery. Each phase leaves a green, reviewable slice. Do not reopen PRD locked decisions D1–D19 without a PRD revision.

---

## 0. Locked decisions (copy — PRD is source of truth)

| Topic | Decision |
|-------|----------|
| Yield / `asset()` | **weETH** |
| Intermediate | **eETH** |
| Liquid sleeve | **WETH** |
| SE surfaces | **In + Out**; **all** defined pairs on **both** |
| Native ETH routes | **None** (no `exchangeInEth`) |
| WETH stake | unwrap → `LiquidityPool.deposit` → wrap as needed |
| WETH pay | sleeve → optional `RedemptionManager` instant redeem → revert |
| User async queue | **Forbidden** |
| Sleeve / rebalance | **`rebalance()`** + **WETH→SE split mint** (target %) + **large-mint stake helper** |
| Default liquid % | **`0.20e18` (20%)** |
| eETH/weETH → WETH | **Inventory swap** + WETH pay ladder |
| Instant redeem out | **ETH → wrap WETH** |
| Shortfall error | **`InsufficientLiquidReserve` only** |
| Previews | **ungated** on sleeve/redeem; full `totalReserveEth` share math |
| Usage fee default | **0** |
| Fork ship gate | **Required including live instant redeem** |
| Lido package | **Reference only** |
| Deploy | CREATE3 + registry DFPkg |
| SUT mocks | Forbidden |

### Clarifications locked 2026-07-24 (user Q&A)

| # | Topic | Choice |
|---|--------|--------|
| 1 | Liquid target maintenance | `rebalance()` **+** after large WETH→SE mints |
| 2 | Yield → WETH | Inventory swap (recommended) |
| 3 | Default liquid % | **20%** |
| 4 | WETH→SE disposition | **Split on mint** (keep target liquid %, stake rest same tx) |
| 5 | Redeem output | ETH → wrap WETH |
| 6 | Error surface | `InsufficientLiquidReserve` only |
| 7 | Fork | Required **including live instant redeem** |
| 8 | Lido | Reference only |

---

## 1. Goals and non-goals

### Goals

1. Package: facets, repo, common, DFPkg, FactoryService, marker.  
2. Full dual-surface route matrix (§3).  
3. WETH pay ladder with optional RedemptionManager.  
4. Rebalance: claim → stake excess → queue deficit.  
5. Preview == execution; ungated previews.  
6. Hermetic + fee/oracle wiring + invariant + adversarial P0.  
7. Mainnet fork: deposit/wrap, sleeve pays, rebalance, request/claim as available, and **live instant redeem** (hard ship gate).  
8. WETH→SE mint **split**: leave ~20% (oracle %) liquid, stake overage same tx.

### Non-goals

- DEX secondary market inside SE.  
- User-facing withdraw NFT UX.  
- On-chain ETA for queue finalization.  
- `exchangeInEth` / native SE token routes.  
- DETF composition beyond optional opaque-leg smoke.  
- EigenLayer operator flows.  
- Priority queue as a **user** route (rebalance inventory only if used).  
- Separate `InstantRedeemUnavailable` error (folded into `InsufficientLiquidReserve`).

---

## 2. Error surface

### 2.1 WETH shortfall

```solidity
/// @param requested WETH wei required
/// @param available WETH.balanceOf(vault) at check (sleeve only; before redeem attempt may differ — document)
error InsufficientLiquidReserve(uint256 requested, uint256 available);
```

After failed redeem attempt, prefer either:

- same error with post-attempt sleeve, or  
- `InstantRedeemUnavailable(uint256 shortfall)` if redeem was required and capacity/policy blocked.

**Previews must not emit these for capacity.** Execution only.

### 2.2 Other

| Error | When |
|-------|------|
| `InsufficientLockedReserve(requested, available)` | weETH/eETH pay shortfall |
| `InvalidRoute(tokenIn, tokenOut)` | unsupported / native ETH |
| `DeadlineExpired` | past deadline |
| `Slippage` | minOut / maxIn |
| `ZeroAmount` / `ZeroAddress` | guards |
| `InsufficientDeposit` | pull / pretransferred delta |
| Protocol bubbles | pause, blacklist, stake, redeem limits |

---

## 3. Route matrix checklist (In **and** Out)

Assets: `W`, `E` = eETH, `Y` = weETH, `S` = SE.

| # | Pair | Exact-in | Exact-out | Exec notes |
|---|------|----------|-----------|------------|
| R1 | W→S | ☐ | ☐ | Mint vs full NAV; **split** sleeve to target %; stake overage same tx |
| R2 | E→S | ☐ | ☐ | Wrap to Y; mint |
| R3 | Y→S | ☐ | ☐ | Lock Y; mint |
| R4 | S→W | ☐ | ☐ | Burn; WETH pay ladder |
| R5 | S→E | ☐ | ☐ | Burn; unlock via unwrap |
| R6 | S→Y | ☐ | ☐ | Burn; transfer Y |
| R7 | W→E | ☐ | ☐ | unwrap+deposit |
| R8 | W→Y | ☐ | ☐ | unwrap+deposit+wrap |
| R9 | E→W | ☐ | ☐ | inventory swap; WETH pay ladder |
| R10 | Y→W | ☐ | ☐ | inventory swap; WETH pay ladder |
| R11 | E→Y | ☐ | ☐ | wrap |
| R12 | Y→E | ☐ | ☐ | unwrap |

For each: `preview*` then execute; `assertEq(preview, executed)` (or documented dust).

---

## 4. Layout

```text
contracts/protocols/staking/etherfi/
  ETHERFI_WEETH_STANDARD_EXCHANGE_VAULT_PRD.md
  ETHERFI_WEETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md
  interfaces/
    IEtherFiWeETHStandardVault.sol
    IEtherFiWeETHStandardExchangeDFPkg.sol   # PkgInit / PkgArgs HERE only
  EtherFiWeETHStandardExchangeRepo.sol
  EtherFiWeETHStandardExchangeCommon.sol
  EtherFiWeETHStandardExchangeInTarget.sol
  EtherFiWeETHStandardExchangeInFacet.sol     # facetFuncs: previewExchangeIn, exchangeIn ONLY
  EtherFiWeETHStandardExchangeOutTarget.sol
  EtherFiWeETHStandardExchangeOutFacet.sol
  EtherFiWeETHRebalanceTarget.sol
  EtherFiWeETHRebalanceFacet.sol
  EtherFiWeETHMarkerTarget.sol
  EtherFiWeETHMarkerFacet.sol
  EtherFiWeETHStandardExchangeDFPkg.sol
  EtherFiWeETH_Component_FactoryService.sol
  test/hermetic/
    HermeticEtherFiPorts.sol
    HostileWETH.sol   # optional reentrancy

contracts/test/bases/TestBase_EtherFiWeETHStandardExchange.sol

test/foundry/spec/protocol/staking/etherfi/
  EtherFiWeETHStandardExchange_Core.t.sol
  EtherFiWeETHStandardExchange_Fees.t.sol
  EtherFiWeETHStandardExchange_InstantRedeem.t.sol
  invariant/
    EtherFiWeETHStandardExchange_Invariant.t.sol
  adversarial/
    Adversarial_EtherFiWeETH_P0.t.sol

test/foundry/fork/eth_main/vaults/staking/etherfi/
  EtherFiWeETHStandardExchange_Fork.t.sol
  EtherFiWeETHStandardExchange_Rebalance_Fork.t.sol
```

### Crane deltas (as needed)

```text
lib/crane/.../etherfi/interfaces/  # IWithdrawRequest*, IEtherFiRedemptionManager integration iface
lib/crane/.../etherfi/services/EtherFiService.sol  # queue + redeem helpers; still no EigenLayer
```

---

## 5. Implementation phases

### Phase 0 — Scaffold + addresses

- [ ] Package dirs + empty interfaces with NatSpec  
- [ ] Verify mainnet addresses (pool, eETH, weETH, WRNFT, RedemptionManager, WETH)  
- [ ] PkgArgs: `eETH`, `weETH`, `weth`, `liquidityPool`, `withdrawalQueue` / request NFT, `redemptionManager`  
- [ ] `PkgInit` / `PkgArgs` **on interface only**

**Exit:** compiles stubs; address table in package README or PRD §9 checked.

---

### Phase 1 — Common: NAV, quotes, pull, mint fee

**Deliverables**

- Repo storage: token addrs, request id set, pending face totals  
- `liquidReserveEth`, `lockedReserveEth`, `totalReserveEth`  
- `_quoteExactIn` / `_quoteExactOut` for full matrix (no sleeve gate)  
- `_securePull`, `_mintWithUsageFee`, `_burnShares`  
- `_creditAssetToReserve`: WETH→liquid; eETH→wrap Y; Y→locked  
- `_stakeWethToEEth` / `_stakeWethToWeEth`: WETH.withdraw → pool.deposit → optional wrap  
- `_payWeth(needed, recipient)`: sleeve → redeem shortfall → revert  
- `_payYield` for Y/E outs  

**Tests**

| ID | Case |
|----|------|
| Q1 | Quote matrix unit/view (hermetic rates) |
| Q2 | Preview WETH-out with **zero sleeve** still returns non-zero quote |

**Exit:** Common + hermetic ports compile; quote tests green.

---

### Phase 2 — In + Out facets (closed-form, dual surface)

**Deliverables**

- InTarget: exact-in for all R1–R12  
- OutTarget: exact-out for all R1–R12  
- Facet `facetFuncs`: **only** standard SE selectors (no eth helper)  
- Marker views + interface id  
- DFPkg: multi-asset vaultTokens `[weETH, WETH, eETH]`, ERC4626 asset=weETH, fee type = marker id  
- FactoryService + TestBase registry deploy  

**Tests**

| ID | Case |
|----|------|
| D1 | Deploy marker, vaultTokens, asset=weETH; default liquid policy **20%** in TestBase |
| P* | For each R1–R12: preview==exec on **In** and **Out** |
| M1 | W→S exact-in: after mint, `liquid ≈ target` (band); overage staked as weETH |
| M2 | W→S exact-out: same split semantics |
| L1 | S→W / Y→W with funded sleeve |
| L2 | S→W empty sleeve, redeem disabled → `InsufficientLiquidReserve` exact args |
| L3 | Preview still quotes when L2 would revert |
| N1 | Native ETH / zero address route → `InvalidRoute` |

**Exit:** Core route suite green hermetically (redeem port off → sleeve-only WETH pays).

---

### Phase 3 — Instant redeem integration

**Deliverables**

- Wire RedemptionManager; `outputToken = ETH`; wrap to WETH  
- Capacity check before redeem; fee-aware slippage  
- Hermetic redeem port with controllable capacity  

**Tests**

| ID | Case |
|----|------|
| IR1 | Sleeve short, redeem capacity ≥ shortfall → success; locked Y down |
| IR2 | Sleeve short, redeem capacity 0 → revert |
| IR3 | Redeem fee: minOut still enforced |
| IR4 | Exact-in **and** exact-out S→W both use ladder |
| IR5 | Y→W inventory swap uses ladder (In and Out) |

**Exit:** Instant redeem suite green hermetically.

---

### Phase 4 — Rebalance + queue lifecycle

**Deliverables**

- `rebalance()`: claim+wrap, stake excess, queue deficit  
- Band + max requests per tx  
- `receive()` + reentrancy lock  
- Track request ids; only vault claims  

**Tests**

| ID | Case |
|----|------|
| R1 | liquid ≫ target → stake; WETH down; weETH up |
| R2 | liquid ≪ target → request tracked; weETH down |
| R3 | finalize+claim → WETH up; id cleared |
| R4 | User In/Out does **not** enqueue |
| R5 | Attacker cannot claim vault request |

**Exit:** Rebalance hermetic green.

---

### Phase 5 — Fees + oracle liquid %

- Usage fee 0 vs non-zero feeTo shares  
- liquid % vault/type/global resolution (reuse existing FO tests; smoke vault resolves)  

---

### Phase 6 — Invariants

Handler (production vault, hermetic ports):

| Action | |
|--------|--|
| exchangeIn W→S, Y→S | |
| exchangeOut S→W, S→Y | catch sleeve/redeem reverts |
| exchangeIn/Out asset pairs | |
| rebalance | |
| donate WETH/weETH | |
| optional warp | |

| Inv | Statement |
|-----|-----------|
| I1 | `totalReserveEth ≈ liquid + locked (+ in-flight)` |
| I2 | `liquidReserveEth == WETH.balance` |
| I4 | share supply conservation (user + feeTo) |
| I5 | donation does not free-mint extractable principal |
| I8 | no nested reentrancy success |
| I9 | policy % does not mint WETH without claim/redeem |

```bash
forge test --match-path 'test/foundry/spec/protocol/staking/etherfi/invariant/**' -vv
```

---

### Phase 7 — Adversarial P0

| ID | Theme | Pass |
|----|--------|------|
| A1–A2 | Donation WETH/weETH | no free mint drain |
| C1–C3 | Reentrancy In/Out/rebalance | `IsLocked` |
| E1–E2 | Round-trip W↔S, Y↔S | conservation ± dust |
| E5 | zero amount / deadline | exact errors |
| H1 | empty sleeve + no redeem | InsufficientLiquidReserve |
| H3 | minOut fail | full revert |
| S1–S2 | sleeve drain; WETH out does not silently unstake via queue | |
| R-route | native ETH | InvalidRoute |
| Q1–Q2 | claim theft / double claim | revert |

```bash
forge test --match-path 'test/foundry/spec/protocol/staking/etherfi/adversarial/**' -vv
```

---

### Phase 8 — Mainnet fork

| ID | Case |
|----|------|
| FK1 | Registry deploy with live addrs |
| FK2 | WETH→weETH / WETH→SE (unwrap+deposit+wrap; **split mint** leaves ~20% liquid) |
| FK3 | Fund sleeve; S→W both In and Out semantics |
| FK4 | rebalance stake excess / queue deficit |
| FK5 | request withdraw from vault |
| FK6 | **Live instant redeem** tops up WETH pay when sleeve short (**required ship gate**) |
| FK7 | claim if finalized state available |

**FK6 note:** If mainnet capacity is temporarily zero, **do not soft-pass**. Options: (1) fund/use a block where `canRedeem` is true; (2) deal vault weETH and redeem against live manager when liquid ETH exists; (3) fail CI until a window works. Hermetic IR remains unit proof but **does not replace** FK6.

```bash
forge test --fork-url $ETH_RPC_URL \
  --match-path 'test/foundry/fork/eth_main/vaults/staking/etherfi/**' -vv
```

---

## 6. Component checklist

### Crane

- [ ] RedemptionManager + withdraw request interfaces (integration surface)  
- [ ] Service helpers: deposit, wrap/unwrap, request, claim, redeem→ETH  

### Package

- [ ] Repo + Common (quotes dual-surface; WETH pay ladder)  
- [ ] In/Out targets + facets (**no** eth entrypoint in facetFuncs)  
- [ ] Rebalance + Marker  
- [ ] DFPkg + FactoryService  
- [ ] Hermetic ports  
- [ ] TestBase registry path  

### Tests

- [ ] Core R1–R12 × In × Out  
- [ ] Instant redeem  
- [ ] Rebalance  
- [ ] Fees  
- [ ] Invariant  
- [ ] Adversarial P0  
- [ ] Fork FK*  

---

## 7. Acceptance criteria

- [ ] PRD D1–D18 respected in code  
- [ ] All routes on **both** `exchangeIn` and `exchangeOut`  
- [ ] Preview ungated; share math on full reserve  
- [ ] WETH pay: sleeve → instant redeem → revert; no user queue  
- [ ] Stake: WETH unwrap → pool deposit  
- [ ] rebalance claim/stake/queue  
- [ ] Hermetic + adversarial P0 + invariant green  
- [ ] Fork green **including live instant redeem (FK6)**  
- [ ] WETH→SE split mint (M1/M2) green  
- [ ] Default liquid policy **20%** in test/deploy docs  
- [ ] No SUT mocks; no `new` DFPkg/facets  

---

## 8. Suggested commands

```bash
# Spec
forge test --match-path 'test/foundry/spec/protocol/staking/etherfi/**' -vv

# Fork
forge test --fork-url $ETH_RPC_URL \
  --match-path 'test/foundry/fork/eth_main/vaults/staking/etherfi/**' -vv
```

---

## 9. Implementation order (agent checklist)

```text
Phase 0  scaffold + address verify
Phase 1  Common + hermetic ports + quotes
Phase 2  In/Out + DFPkg + TestBase + route matrix
Phase 3  Instant redeem ladder
Phase 4  Rebalance + queue
Phase 5  Fees / oracle smoke
Phase 6  Invariants
Phase 7  Adversarial P0
Phase 8  Mainnet fork
Polish   NatSpec, README, research doc link
```

**Commit cadence suggestion:** one commit per phase exit.

---

## 10. Risks during implementation

| Risk | Mitigation |
|------|------------|
| Redeem fees break preview==exec | Sleeve-only quotes 1:1 eth; when redeem used, require execution minOut after fee or separate IR tests without forcing preview equality across fee |
| eETH rebase mid-tx | Minimize eETH hold; wrap ASAP |
| Fork cannot redeem/claim | Hermetic IR + FK5 request-only |
| Gas on multi-request rebalance | Cap per tx |
| Confusing In vs Out | Single Common quote/exec; tests always pair both surfaces |

---

## 11. Changelog

| Date | Change |
|------|--------|
| 2026-07-24 | Initial plan: dual-surface ether.fi weETH SE; sleeve + optional RedemptionManager; rebalance async; no exchangeInEth |
| 2026-07-24 | User Q&A: 20% liquid; WETH→SE split mint; rebalance + large-mint helper; fork must prove live redeem; InsufficientLiquidReserve only |

---

*Do not mark IMPLEMENTED until §7 acceptance has command evidence. Dual-surface route matrix and live-redeem fork (FK6) are ship gates.*
