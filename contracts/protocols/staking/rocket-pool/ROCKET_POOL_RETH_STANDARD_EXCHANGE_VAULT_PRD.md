# PRD: Rocket Pool rETH Standard Exchange Vault

**Date:** 2026-07-25  
**Status:** Draft for implementation  
**Package path (target):** `contracts/protocols/staking/rocket-pool/`  
**Crane integration:** `lib/crane/contracts/protocols/staking/ethereum/rocket-pool/`  
**Rocket Pool vendor (reference):** `lib/crane/contracts/external/rocketpool/`  
**Shape references (shipping peers / patterns):**  
- `contracts/protocols/staking/etherfi/` (bi-directional sleeve economics, dual SE surface, production-first tests)  
- `contracts/protocols/staking/lido/` (staking SE layout; reference only — not a shipping track for this epic)

**Related docs:**
- Impl plan: [`ROCKET_POOL_RETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md`](./ROCKET_POOL_RETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md)
- Research: `docs/research/2026-07-23-ethereum-staking-ported-protocols-custom-se-assessment.md` (§4.3 Rocket Pool; §6 easiest custom SE)
- Market: `docs/research/2026-07-21-ethereum-staking-protocols-se-vault-assessment.md` (P0 rETH)
- Crane RP README: `lib/crane/contracts/protocols/staking/ethereum/rocket-pool/README.md`
- Fee Oracle: `contracts/oracles/fee/`, liquid reserve % cascade
- Gold SE surface: `IStandardExchangeIn` / `IStandardExchangeOut` only
- Peer PRDs: ether.fi weETH SE; Lido wstETH SE (reference)

---

## 1. Goal

Deliver a production-first **Standard Exchange (SE)** vault for Rocket Pool liquid staking:

1. Prefer **`rETH`** as the non-rebasing locked yield reserve (`IERC4626.asset()`).  
2. Hold a **liquid WETH sleeve** so closed-form routes that **pay WETH** work when inventory (and optional primary burn) allow.  
3. Target liquid vs locked mix via Vault Fee Oracle **`liquidReservePercentage`** (same three-tier cascade as peer staking SEs).  
4. Treat the sleeve as a **bi-directional buffer** (this PRD’s distinctive product rule — §5):  
   - **Inflows:** best-effort stake excess WETH → rETH **only when deposit-pool capacity allows**; otherwise **leave WETH liquid**.  
   - **Outflows:** pay WETH from sleeve first; if short, optional **`rETH.burn`** when protocol collateral allows; else revert.  
5. **No async exit queue** on user exchange or rebalance — Rocket Pool has no user withdraw-NFT surface on this integration.  
6. Deploy via CREATE3 facets + IndexedEx vault registry; opaque `IStandardExchange` leg for DETF / router composition.  
7. Rest of IndexedEx passes **WETH** — stake paths **unwrap WETH → ETH** inside the vault; **no** `exchangeInEth` / native-ETH SE surface.

This is **not** a generic ERC-4626 SE: Rocket Pool mint is payable deposit-pool deposit with **capacity gates**; primary exit is **liquidity-gated burn**.

---

## 2. Locked product decisions

### 2.1 Inherited from peer staking SEs (Lido / ether.fi family)

These match AGENTS.md / peer PRDs unless this PRD explicitly overrides.

| # | Topic | Decision |
|---|--------|----------|
| D1 | Protocol | **Rocket Pool** — reserve **rETH** |
| D2 | SE surface | **`IStandardExchangeIn` + `IStandardExchangeOut` only** |
| D3 | Route symmetry | **Every defined pair is supported on both In (exact-in) and Out (exact-out)** |
| D4 | Native ETH user routes | **Forbidden** — no `address(0)` token, no `exchangeInEth` |
| D5 | WETH stake mechanic | On stake routes: **WETH.withdraw → RocketDepositPool.deposit{value} → mint rETH** (via pool → rETH mint path) |
| D6 | Liquid sleeve | **WETH**; policy via fee oracle `liquidReservePercentage` |
| D7 | Default liquid % | **`0.20e18` (20%)** unless vault/type/global override (aligned with ether.fi staking SE default) |
| D8 | Async exit on user exchange | **Forbidden** — never open protocol queues / NFTs inside In/Out (RP has none for liquid stakers on this surface) |
| D9 | WETH pay path | **Sleeve first → optional primary burn → revert** |
| D10 | Primary burn surface | **`rETH.burn(rethAmount)`** pays **ETH** at `getEthValue`; vault wraps to **WETH** |
| D10b | Burn / shortfall error | **`InsufficientLiquidReserve(requested, available)` only** when paying WETH fails after sleeve + burn attempt (no separate burn error on user routes) |
| D11 | Yield → WETH (asset↔asset) | **Inventory swap**: keep credited rETH locked, pay WETH via D9 |
| D12 | Sleeve target — continuous | Permissionless **`rebalance()`** (stake excess when capacity; burn deficit when collateral) |
| D13 | Previews | **Never gate** on sleeve, deposit-pool capacity, or burn collateral; full NAV / closed-form rates |
| D14 | Share math | Apportion against **entire** `totalReserveEth` (liquid + locked) |
| D15 | Usage fee default | **0** for type unless operator sets |
| D16 | Lido package | **Reference only** for layout patterns — not a shipping dependency of this epic |
| D17 | Deploy | CREATE3 facets + **registry** DFPkg; never `new` SUT |
| D18 | Mocks | **Forbidden** for Rocket Pool SUT, manager, registry, fee oracle, SE diamond |
| D19 | Fork ship gate | Mainnet fork **required** including live deposit (when capacity) and live burn (when collateral) — do not soft-pass empty capacity forever without documenting a capacity window |

### 2.2 Rocket Pool–specific locks (this vault)

| # | Topic | Decision |
|---|--------|----------|
| D20 | Intermediate token | **None** — no rebasing intermediate; single yield token **rETH** |
| D21 | Sleeve as bi-directional buffer | **Yes** — soft liquid target; stake only when deposit capacity allows; leave overage as WETH otherwise |
| D22 | WETH→SE mint disposition | **Best-effort stake of overage** toward oracle target (capacity-capped). **Not** ether.fi hard split-mint. Post-tx liquid **may** exceed target when pool is full |
| D23 | Deposit capacity on WETH→SE | **Soft:** never fail SE mint solely because deposit pool cannot take overage |
| D24 | Deposit capacity on WETH→rETH | **Hard:** user requested rETH; revert with capacity/protocol error if mint cannot complete |
| D25 | Rebalance stake leg | Stake liquid excess **only if** `amount ≤ getMaximumDepositAmount()` (and deposits enabled); otherwise no-op stake |
| D26 | Rebalance deficit leg | Attempt **`rETH.burn`** to refill sleeve when liquid ≪ target **and** collateral allows; **no** async queue if burn fails |
| D27 | Deposit fee | Protocol deposit fee reduces rETH minted; quotes for WETH→rETH / stake use live rate helpers; minOut/maxIn enforced after fee |
| D28 | Secondary market | **Out of scope** inside SE (no DEX swap of rETH for WETH) |
| D29 | ether.fi / Lido shipping | **Not** this epic; reuse patterns only |

### 2.3 Clarifications locked 2026-07-25 (design Q&A)

| Topic | Choice |
|-------|--------|
| Liquid target maintenance | `rebalance()` + best-effort stake on WETH inflows |
| Deposit pool full on WETH→SE | Leave new / excess WETH in sleeve; still mint SE on full eth face |
| Explicit WETH→rETH | Hard capacity gate |
| Primary exit | Burn only (collateral-gated); no withdraw NFT |
| Shortfall error | `InsufficientLiquidReserve` only on WETH pays |
| Default liquid % | **20%** |
| Hard post-mint liquid band (ether.fi M1/M2) | **No** — soft target when capacity blocked |

---

## 3. Token roles

| Role | Token | Notes |
|------|--------|------|
| Locked yield / `IERC4626.asset()` | **rETH** | Non-rebasing; rate via `getExchangeRate` / `getEthValue` |
| Liquid sleeve | **WETH** | Instant WETH pays; may hold **above** target when deposits gated |
| SE share | `address(this)` | On exchange routes; not necessarily listed in `vaultTokens()` |
| Transient | ETH (pre-deposit / post-burn) | Must not linger after ops (wrap or stake immediately) |

**No intermediate rebasing token** in v1.

**`IBasicVault.vaultTokens()` (v1):**

```text
[0] rETH
[1] WETH
```

---

## 4. Route matrix (normative — both SE surfaces)

Assets: `WETH`, `rETH`, `SE = address(this)`.

### 4.1 Classes

| Class | Pairs |
|-------|--------|
| Mint SE | `WETH→SE`, `rETH→SE` |
| Redeem SE | `SE→WETH`, `SE→rETH` |
| Asset ↔ asset | `WETH↔rETH` |

**Every pair above MUST implement:**

- `previewExchangeIn` / `exchangeIn` (exact-in)  
- `previewExchangeOut` / `exchangeOut` (exact-out)  

Shared quote helpers (peer `_quoteExactIn` / `_quoteExactOut`). Do **not** implement a route on only one surface.

### 4.2 Execution sketches

| Route | Exact-in / exact-out behavior (same economics) |
|-------|-----------------------------------------------|
| **WETH → rETH** | Unwrap; capacity check; `deposit{value}`; transfer rETH. **Hard fail** if capacity/settings block mint |
| **rETH → WETH** | Inventory swap: lock rETH; **pay WETH via §5.2** |
| **WETH → SE** | (1) pull WETH; (2) mint SE vs full NAV on full eth face; (3) **best-effort** reduce liquid toward target by staking overage **up to remaining deposit capacity**; (4) any unstaked WETH stays sleeve. Exact-in and exact-out |
| **rETH → SE** | Lock rETH; mint SE vs full NAV (**no** forced WETH stake) |
| **SE → rETH** | Burn SE; transfer rETH from locked inventory |
| **SE → WETH** | Burn SE; **pay WETH via §5.2** |
| **WETH stake failures on hard routes** | Bubble capacity / pause / fee / deposit reverts |

### 4.3 Explicitly invalid user routes

| Route | Error |
|-------|--------|
| Native ETH as tokenIn/tokenOut | `InvalidRoute` |
| Unsupported token | `InvalidRoute` |
| Async queue as user Out | **Not a route** (does not exist) |

---

## 5. Reserve model and bi-directional sleeve buffer

### 5.1 NAV buckets (ETH units, 1e18)

```text
totalReserveEth =
    WETH.balance(vault)                          // liquid sleeve
  + rETH_to_ETH(rETH.balance(vault))             // locked yield via getEthValue
```

No in-flight request face (no withdraw NFT bookkeeping).

Share mint/burn: BetterMath virtual offset (ERC-4626-style), against **`totalReserveEth`**, not liquid alone.

### 5.2 Paying WETH (any route that pays WETH — In or Out)

Normative order (inverse of stake buffer on the way in):

```text
1) If WETH.balance(vault) >= needed:
     transfer WETH from sleeve
2) Else if primary burn can cover shortfall (§5.3):
     burn vault rETH → ETH → wrap WETH → transfer
3) Else:
     revert InsufficientLiquidReserve(requested, availableSleeveAfterAttempt)
4) NEVER invent an async exit queue
```

**Applies equally** to exact-in and exact-out when `tokenOut == WETH`.

### 5.3 Primary burn (optional step 2)

| Item | Rule |
|------|------|
| Call | `rETH.burn(rethAmount)` |
| ETH out | `getEthValue(rethAmount)`; requires `getTotalCollateral() ≥ ethAmount` (protocol) |
| Wrap | Vault receives ETH → `WETH.deposit` |
| Capacity | Execution only; previews ungated |
| Inventory | Burn **vault-owned** rETH (post user pull + credit for asset→WETH; post burn SE for SE→WETH) |
| Failure | Fold into `InsufficientLiquidReserve` on user WETH pays (D10b) |

### 5.4 Bi-directional buffer — inflows (D21–D23)

```text
// After pull of amountIn WETH (exact-in) or computed amountIn (exact-out) for WETH→SE:
// 1) NAV credit = full amountIn (share mint uses full eth delta)
// 2) postTotal ≈ totalReserveEth after credit (include new WETH before stake attempt)
// 3) targetLiquid = postTotal * liquidReservePercentageOfVault(this) / 1e18
// 4) excess = max(0, WETH.balance - targetLiquid)
// 5) stakeable = min(excess, getMaximumDepositAmount())  // and deposits enabled
// 6) if stakeable > 0: unwrap → deposit{value} → rETH locked
// 7) remainder WETH stays sleeve (may leave liquid >> target if capacity 0)
// 8) NEVER revert the SE mint solely because stakeable == 0
```

**Contrast ether.fi D12b:** ether.fi **hard-stakes** overage same tx. Rocket Pool **soft-stakes** overage capacity-capped.

### 5.5 Explicit WETH → rETH (D24)

User is not buying SE shares — they want rETH:

```text
required capacity / mint path must fully succeed or whole exchange reverts
```

Use a dedicated capacity/protocol error surface (e.g. `InsufficientDepositCapacity(maxDeposit, requested)` from Crane `RocketPoolService` or vault-wrapped equivalent). Do **not** silently leave WETH and transfer 0 rETH.

### 5.6 Previews (both surfaces)

- Use full `totalReserveEth` and closed-form rETH rates (`getEthValue` / `getRethValue`).  
- **Do not** reduce WETH→SE quotes when deposit capacity is zero.  
- **Do not** reduce WETH-out quotes when burn collateral is zero.  
- Clients discover payability / mintability via simulation of the state-changing call.  
- Optional **view helpers** (non-SE surface, nice-to-have): `maxDepositableEth()`, `liquidReserveEth()`, `burnableEthEstimate()` — not required for v1 SE selectors.

---

## 6. Rebalance (permissionless)

### 6.1 `rebalance()` (D12, D25–D26)

```text
rebalance():
  1) targetLiquid = totalReserveEth * liquidReservePercentageOfVault(this) / 1e18
  2) band = targetLiquid * REBALANCE_BAND_WAD / 1e18   // e.g. 10% of target
  3) liquid = WETH.balance(vault)
  4) if liquid > target + band:
       stakeable = min(liquid - target, getMaximumDepositAmount())
       if stakeable > 0: unwrap → deposit → rETH
       // if capacity 0: no-op (leave liquid high)
  5) if liquid + band < target:
       try burn enough rETH to refill toward target (collateral-limited)
       // if burn fails capacity: no-op (leave liquid low)
```

| Item | Rule |
|------|------|
| Queue | **None** |
| Claim | N/A (no request ids) |
| Who | Permissionless |
| Receive | `receive()` + reentrancy lock for burn ETH |

### 6.2 Relationship to mint-time stake

| Trigger | Action |
|---------|--------|
| **WETH→SE** | Best-effort stake overage (capacity-capped) |
| **rebalance** | Same stake/burn maintainers continuously |
| Other routes | No automatic queue; hard stake only on WETH→rETH |

---

## 7. Fee Oracle

| Param | Behavior |
|-------|----------|
| `liquidReservePercentage` | vault → type (marker iface id) → global; `0` stored = unset |
| **Recommended default for this SE** | **`0.20e18` (20%)** — set in TestBase / deploy docs |
| Usage fee | type default **0**; inflation mint to `feeTo` when &gt; 0 |
| Marker | `IRocketPoolRETHStandardVault` (name TBD in impl) interface id keys fee type |

---

## 8. Error surface

### 8.1 WETH shortfall

```solidity
/// @param requested WETH wei required
/// @param available WETH.balanceOf(vault) at final check (post optional burn)
error InsufficientLiquidReserve(uint256 requested, uint256 available);
```

Previews must **not** emit this for capacity. Execution only.

### 8.2 Deposit capacity (hard routes only)

```solidity
/// @param maxDeposit getMaximumDepositAmount() at check
/// @param requested ETH/WETH wei user tried to stake
error InsufficientDepositCapacity(uint256 maxDeposit, uint256 requested);
// or bubble RocketPoolService.InsufficientDepositCapacity
```

Use on **WETH→rETH** (and any other hard stake). **Not** on WETH→SE when soft-leaving sleeve.

### 8.3 Other

| Error | When |
|-------|------|
| `InsufficientLockedReserve(requested, available)` | rETH pay shortfall |
| `InvalidRoute(tokenIn, tokenOut)` | unsupported / native ETH |
| `DeadlineExpired` | past deadline |
| `Slippage` | minOut / maxIn (incl. deposit fee under-delivery on hard stake) |
| `ZeroAmount` / `ZeroAddress` | guards |
| `InsufficientDeposit` | pull / pretransferred delta |
| Protocol bubbles | pause, deposit disabled, min deposit, burn collateral |

---

## 9. Architecture (package)

```text
contracts/protocols/staking/rocket-pool/
  ROCKET_POOL_RETH_STANDARD_EXCHANGE_VAULT_PRD.md          # this file
  ROCKET_POOL_RETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md  # follow-on
  interfaces/
    IRocketPoolRETHStandardVault.sol       # marker + views + errors
    IRocketPoolRETHStandardExchangeDFPkg.sol  # PkgInit / PkgArgs on interface
  RocketPoolRETHStandardExchangeRepo.sol
  RocketPoolRETHStandardExchangeCommon.sol   # NAV, quotes, sleeve buffer, burn pay
  RocketPoolRETHStandardExchangeInTarget.sol / InFacet.sol
  RocketPoolRETHStandardExchangeOutTarget.sol / OutFacet.sol
  RocketPoolRETHRebalanceTarget.sol / RebalanceFacet.sol
  RocketPoolRETHMarkerTarget.sol / MarkerFacet.sol
  RocketPoolRETHStandardExchangeDFPkg.sol
  RocketPoolRETH_Component_FactoryService.sol
  test/hermetic/                           # rETH/deposit pool/WETH ports
```

**Crane:** reuse `RocketPoolService`, `IRETH`, `IRocketDepositPool`, `IRocketStorage`, `RETHRateProvider`. Extend only if SE needs thin helpers (capacity views). No EigenLayer / minipool ops in SE.

**PkgArgs (sketch):** `rETH`, `weth`, `depositPool` and/or `rocketStorage` (resolve pool via storage keys as Crane service does).

---

## 10. Mainnet addresses (verify at implement)

| Contract | Address (verify) |
|----------|------------------|
| rETH | `0xae78736Cd615f374D3085123A210448E74Fc6393` |
| RocketStorage | `0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46` |
| RocketDepositPool | Resolve via storage key `rocketDepositPool` |
| WETH | chain canonical |

---

## 11. Testing expectations (summary)

Inherit production-first rules from AGENTS.md / `indexedex-testing` / peer ether.fi plan:

1. CREATE3 facets + registry DFPkg; no SUT mocks.  
2. Hermetic ports for deposit capacity + burn collateral (controllable).  
3. Dual-surface route matrix; preview==exec on closed-form paths.  
4. **Soft stake tests:** WETH→SE with capacity 0 still mints SE; liquid rises; no rETH mint.  
5. **Hard stake tests:** WETH→rETH with capacity 0 reverts capacity error.  
6. **WETH pay:** sleeve; burn tops up; empty sleeve + no collateral → `InsufficientLiquidReserve`.  
7. **Previews ungated** when capacity/collateral zero.  
8. Rebalance: stake excess when capacity; no-op when not; burn deficit when collateral; no-op when not.  
9. Adversarial P0 + invariants (sleeve accounting, donation, reentrancy).  
10. Mainnet fork: registry deploy; WETH→SE best-effort stake when capacity; live burn when collateral (hard gates — do not soft-pass forever).

Full phase checklist lives in [`ROCKET_POOL_RETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md`](./ROCKET_POOL_RETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md).

---

## 12. Risks

1. **Deposit pool full for long periods** — sleeve grows; yield drag vs all-rETH; acceptable if documented.  
2. **Burn collateral dry** — WETH outs revert; no queue recovery (unlike Lido/ether.fi rebalance queue).  
3. **Deposit fees** — hard WETH→rETH previews must match post-fee mint or enforce minOut.  
4. **Rate updates** — rETH eth-value changes; share math on full NAV.  
5. **Upgradeable RP proxies** — pin interfaces; fork tests against live addresses.  
6. **Confusion with ether.fi hard split** — agents must not reintroduce forced stake-overage.

---

## 13. Acceptance criteria (product)

- [ ] D1–D29 respected in code  
- [ ] All §4 routes on **both** `exchangeIn` and `exchangeOut` with closed-form previews  
- [ ] Preview == execution for closed-form paths (document ≤ few-wei only if forced)  
- [ ] Previews **not** gated on sleeve, deposit capacity, or burn collateral  
- [ ] WETH pay: sleeve → burn → `InsufficientLiquidReserve`; no user queue  
- [ ] WETH→SE: best-effort capacity-capped stake; mint succeeds when capacity 0  
- [ ] WETH→rETH: hard capacity fail  
- [ ] `rebalance` stake/burn as §6  
- [ ] Registry deploy only; production-first tests  
- [ ] Hermetic + adversarial/invariant + mainnet fork gates  
- [ ] Default liquid policy **20%** in TestBase / deploy docs  
- [ ] No SUT mocks; no `new` DFPkg/facets  

---

## 14. Comparison to peer staking SEs (for agents)

| Topic | Lido / ether.fi | **This RP rETH SE** |
|-------|-----------------|---------------------|
| Yield token | wstETH / weETH (+ intermediate) | **rETH only** |
| Primary mint | Usually open when not paused | **Capacity-gated deposit pool** |
| WETH→SE overage | Hard stake (ether.fi) / liquid keep (Lido WETH mint) | **Best-effort stake; leave liquid if no capacity** |
| Primary exit | Async queue + optional instant redeem | **Burn only** (collateral-gated) |
| Rebalance refill | Claim queue / request withdraw | **Burn if collateral; else no-op** |
| User async queue | Forbidden on In/Out | Forbidden (and **unavailable**) |

---

## 15. Changelog

| Date | Change |
|------|--------|
| 2026-07-25 | Initial PRD: Rocket Pool rETH SE; bi-directional WETH sleeve buffer; soft stake on WETH→SE; hard stake on WETH→rETH; burn-only WETH pay; inherited dual-surface staking SE rules |

---

*Implementation plan is normative for phases and tests once written. Dual-surface route matrix, soft capacity buffer on WETH→SE, and hard capacity on WETH→rETH are ship gates. Do not reopen D1–D29 without PRD revision.*
