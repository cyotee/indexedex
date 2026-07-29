# PRD: ether.fi weETH Standard Exchange Vault

**Date:** 2026-07-24  
**Status:** Draft for implementation  
**Package path (target):** `contracts/protocols/staking/etherfi/`  
**Crane integration:** `lib/crane/contracts/protocols/staking/ethereum/etherfi/`  
**ether.fi vendor (reference):** `lib/crane/contracts/external/etherfi/`  
**Shape reference (not a shipping product track):** `contracts/protocols/staking/lido/`  

**Related docs:**
- Research: `docs/research/2026-07-23-ethereum-staking-ported-protocols-custom-se-assessment.md`
- Market: `docs/research/2026-07-21-ethereum-staking-protocols-se-vault-assessment.md`
- Impl plan: [`ETHERFI_WEETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md`](./ETHERFI_WEETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md)
- Fee Oracle: `contracts/oracles/fee/`, liquid reserve % cascade
- Gold SE surface: `IStandardExchangeIn` / `IStandardExchangeOut` only

---

## 1. Goal

Deliver a production-first **Standard Exchange (SE)** vault for ether.fi liquid restaking:

1. Prefer **`weETH`** as the non-rebasing locked yield reserve (`IERC4626.asset()`).  
2. Hold a **liquid WETH sleeve** so closed-form routes that **pay WETH** work when inventory (and optional instant redeem) allow.  
3. Target liquid vs locked mix via Vault Fee Oracle **`liquidReservePercentage`** (same three-tier cascade as Lido-shaped staking SEs).  
4. **Rebalance** (permissionless): claim async exits → wrap to WETH; stake sleeve excess into ether.fi; queue deficit via protocol request path.  
5. **Optional instant redeem** via `EtherFiRedemptionManager` when paying WETH and the sleeve is short (capacity-limited).  
6. Deploy via CREATE3 facets + IndexedEx vault registry; opaque `IStandardExchange` leg for DETF / router composition.  
7. Rest of IndexedEx passes **WETH** — stake paths **unwrap WETH → ETH** inside the vault; **no** `exchangeInEth` / native-ETH SE surface.

This is **not** a generic ERC-4626 SE: ether.fi mint is payable pool deposit + wrap; primary exit is async and/or liquidity-gated.

---

## 2. Locked product decisions

| # | Topic | Decision |
|---|--------|----------|
| D1 | Protocol | **ether.fi** — reserve **weETH** |
| D2 | SE surface | **`IStandardExchangeIn` + `IStandardExchangeOut` only** |
| D3 | Route symmetry | **Every defined pair is supported on both In (exact-in) and Out (exact-out)** |
| D4 | Native ETH user routes | **Forbidden** — no `address(0)` token, no `exchangeInEth` |
| D5 | WETH stake | On stake routes: **WETH.withdraw → LiquidityPool.deposit{value} → eETH → weETH.wrap** as needed |
| D6 | Liquid sleeve | **WETH**; policy via fee oracle `liquidReservePercentage` |
| D7 | Default liquid % | **`0.20e18` (20%)** unless vault/type/global override |
| D8 | Async exit on user exchange | **Forbidden** — never `requestWithdraw*` inside In/Out |
| D9 | WETH pay path | **Sleeve first → optional instant redeem → revert** |
| D10 | Instant redeem surface | **`EtherFiRedemptionManager.redeemWeEth` / `redeemEEth`**; **ETH** output then vault wraps to **WETH** |
| D10b | Instant redeem failure error | **`InsufficientLiquidReserve(requested, available)` only** (no separate redeem error) |
| D11 | Yield → WETH (asset↔asset) | **Inventory swap**: keep credited yield locked, pay WETH via D9 |
| D12 | Sleeve target — continuous | Permissionless **`rebalance()`** (claim / stake excess / queue deficit) |
| D12b | Sleeve target — WETH→SE mint | **Split on mint**: after credit, leave sleeve at target liquid % of **post-mint** total; **stake the rest** to weETH in the **same tx** (exact-in and exact-out) |
| D12c | Sleeve target — large WETH→SE | After WETH→SE mint, if liquid still **far above band** (implementation threshold), run **internal rebalance helper** (stake excess; do **not** open user-facing queue mid-mint — queue remains rebalance-only) |
| D13 | Previews | **Never gate** on sleeve or redeem capacity; full NAV / closed-form rates |
| D14 | Share math | Apportion against **entire** `totalReserveEth` (liquid + locked + in-flight) |
| D15 | Usage fee default | **0** for type unless operator sets |
| D16 | Lido package | **Reference only** — not a shipping track for this epic |
| D17 | Deploy | CREATE3 facets + **registry** DFPkg; never `new` SUT |
| D18 | Mocks | **Forbidden** for ether.fi SUT, manager, registry, fee oracle, SE diamond |
| D19 | Fork ship gate | Mainnet fork **required** including **live instant redeem** proof (not document-skip) |

---

## 3. Token roles

| Role | Token | Notes |
|------|--------|------|
| Locked yield / `IERC4626.asset()` | **weETH** | Non-rebasing; DeFi-preferred |
| Intermediate | **eETH** | Rebasing; wrap/unwrap only; do not use as naked primary reserve |
| Liquid sleeve | **WETH** | Instant WETH pays |
| SE share | `address(this)` | On exchange routes; not necessarily listed in `vaultTokens()` |
| In-flight | WithdrawRequestNFT / tracked request ids | Async primary exit for rebalance |
| Transient | ETH (pre-wrap), bare eETH mid-op | Must not linger after ops |

**`IBasicVault.vaultTokens()` (v1):**

```text
[0] weETH
[1] WETH
[2] eETH
```

---

## 4. Route matrix (normative — both SE surfaces)

Assets: `WETH`, `eETH`, `weETH`, `SE = address(this)`.

### 4.1 Classes

| Class | Pairs |
|-------|--------|
| Mint SE | `WETH→SE`, `eETH→SE`, `weETH→SE` |
| Redeem SE | `SE→WETH`, `SE→eETH`, `SE→weETH` |
| Asset ↔ asset | `WETH↔eETH`, `WETH↔weETH`, `eETH↔weETH` |

**Every pair above MUST implement:**

- `previewExchangeIn` / `exchangeIn` (exact-in)  
- `previewExchangeOut` / `exchangeOut` (exact-out)  

Shared quote helpers (mirror Lido `_quoteExactIn` / `_quoteExactOut`). Do **not** implement a route on only one surface.

### 4.2 Execution sketches

| Route | Exact-in / exact-out behavior (same economics) |
|-------|-----------------------------------------------|
| **WETH → weETH** | Unwrap; pool.deposit; wrap; transfer weETH (or credit vault if minting SE in one flow) |
| **WETH → eETH** | Unwrap; pool.deposit; transfer eETH |
| **WETH → SE** | **D12b split mint:** (1) pull WETH; (2) mint SE vs full NAV using eth credit of full amountIn; (3) set sleeve to `targetLiquid` of post-tx total; (4) stake **overage** WETH → weETH same tx; (5) optional D12c rebalance helper if still above band. Same economics on exact-in and exact-out. |
| **eETH → weETH** | wrap |
| **weETH → eETH** | unwrap |
| **eETH/weETH → SE** | Normalize to locked weETH; mint SE vs full NAV (**no** forced WETH sleeve split — liquid policy applies when WETH inventory changes via rebalance / WETH mint) |
| **SE → weETH / eETH** | Burn SE; pay from locked (unwrap weETH→eETH if needed) |
| **SE → WETH** | Burn SE; **pay WETH via §5.2** |
| **eETH/weETH → WETH** | Inventory swap: lock input as yield inventory; **pay WETH via §5.2** |
| **WETH → … stake failures** | Bubble pool pause / blacklist / deposit reverts |

### 4.3 Explicitly invalid user routes

| Route | Error |
|-------|--------|
| Native ETH as tokenIn/tokenOut | `InvalidRoute` |
| Unsupported token | `InvalidRoute` |
| Async queue as user Out | **Not a route** (rebalance only) |

---

## 5. Reserve model and WETH payment

### 5.1 NAV buckets (ETH units, 1e18)

```text
totalReserveEth =
    WETH.balance(vault)                                           // liquid
  + weETH_to_ETH(weETH.balance(vault))                            // locked yield
  + sum(pending request face eth)                                 // in-flight
  + sum(claimable eth for finalized unclaimed requests)           // optional refine
```

Share mint/burn: BetterMath virtual offset (ERC-4626-style), against **`totalReserveEth`**, not liquid alone.

### 5.2 Paying WETH (any route that pays WETH — In or Out)

Normative order:

```text
1) If WETH.balance(vault) >= needed:
     transfer WETH from sleeve
2) Else if instant redeem can cover shortfall (see §5.3):
     redeem vault weETH/eETH inventory → ETH → wrap WETH → transfer
3) Else:
     revert InsufficientLiquidReserve(requested, availableSleeve)
     // single error surface even if redeem was attempted (D10b)
4) NEVER requestWithdraw / queue on this path
```

**Applies equally** to exact-in and exact-out when `tokenOut == WETH` (or eth-value path settles in WETH).

### 5.3 Instant redeem (optional step 2)

| Item | Rule |
|------|------|
| Contract | Mainnet `EtherFiRedemptionManager` (address verify at implement) |
| Calls | `redeemWeEth` / `redeemEEth` with `outputToken = ETH` (or documented ETH sentinel); vault wraps to WETH |
| Capacity | `canRedeem` / rate limits / low watermark / pause / blacklist — **execution only** |
| Fees | Exit fee reduces ETH received; quotes for pure sleeve paths stay 1:1 eth face; if redeem used, execution must still meet minOut / maxIn **after fees** or revert Slippage |
| Inventory | Redeem **vault-owned** weETH/eETH (post user pull + credit for asset→WETH; post burn for SE→WETH) |
| Ship proof | **Mainnet fork must exercise live redeem** (D19) — not hermetic-only |

### 5.4 WETH → SE mint split (D12b)

```text
// After pull of amountIn WETH (exact-in) or computed amountIn (exact-out):
// 1) NAV credit = full amountIn (share mint uses full eth delta / full reserve)
// 2) postTotal ≈ totalReserveEth after credit (include new WETH before split)
// 3) targetLiquid = postTotal * liquidReservePercentageOfVault(this) / 1e18
// 4) keep  min(WETH.balance, targetLiquid) as sleeve
// 5) stake  WETH.balance - keep  via unwrap → deposit → wrap weETH
// 6) if still liquid > target + band: stake further excess (D12c); never queue on mint
```

Previews for WETH→SE quote **share amounts from full WETH eth-value**; they do **not** require the sleeve to already hold `targetLiquid`. Execution performs the split.

### 5.5 Previews (both surfaces)

- Use full `totalReserveEth` and closed-form wrap/stake rates.  
- **Do not** reduce quotes when sleeve is empty or redeem capacity is zero.  
- Clients discover payability via simulation / `eth_call` of the state-changing call.

---

## 6. Rebalance (permissionless) + mint-time stake

### 6.1 `rebalance()` (D12)

```text
rebalance():
  1) Claim finalized vault-owned withdraw requests → ETH → WETH (refill sleeve)
  2) targetLiquid = totalReserveEth * liquidReservePercentageOfVault(this) / 1e18
  3) band = targetLiquid * REBALANCE_BAND_WAD / 1e18  // e.g. 10% of target
  4) if liquid > target + band:
       stake excess WETH → deposit → wrap weETH (locked)
  5) if liquid + band < target:
       request protocol withdraw of deficit (weETH/eETH path), track request ids
       split by protocol min/max request sizes; cap requests per tx
```

| Item | Rule |
|------|------|
| Queue | **Only** here (and never inside WETH pay ladder or yield→WETH) |
| Claim | Native ETH → always wrap to WETH |
| Who | Permissionless |

### 6.2 Mint-time liquid split (D12b) + large-mint helper (D12c)

| Trigger | Action |
|---------|--------|
| Every **WETH→SE** (In and Out) | Split to target liquid %; stake overage same tx |
| After that mint, if liquid still > target + band | Stake further excess (no queue) |
| Other routes | No automatic queue; use `rebalance()` for deficit/claim |

---

## 7. Fee Oracle

| Param | Behavior |
|-------|----------|
| `liquidReservePercentage` | vault → type (marker iface id) → global; `0` stored = unset |
| **Recommended global/type default for this SE** | **`0.20e18` (20%)** — set in TestBase / deploy docs; oracle cascade still applies |
| Usage fee | type default **0**; inflation mint to `feeTo` when &gt; 0 |
| Marker | `IEtherFiWeETHStandardVault` interface id keys fee type |

---

## 8. Architecture (package)

```text
contracts/protocols/staking/etherfi/
  ETHERFI_WEETH_STANDARD_EXCHANGE_VAULT_PRD.md          # this file
  ETHERFI_WEETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md
  interfaces/
    IEtherFiWeETHStandardVault.sol       # marker + views + errors
    IEtherFiWeETHStandardExchangeDFPkg.sol  # PkgInit / PkgArgs on interface
  EtherFiWeETHStandardExchangeRepo.sol
  EtherFiWeETHStandardExchangeCommon.sol   # NAV, quotes, WETH pay, stake helpers
  EtherFiWeETHStandardExchangeInTarget.sol / InFacet.sol
  EtherFiWeETHStandardExchangeOutTarget.sol / OutFacet.sol
  EtherFiWeETHRebalanceTarget.sol / RebalanceFacet.sol
  EtherFiWeETHMarkerTarget.sol / MarkerFacet.sol
  EtherFiWeETHStandardExchangeDFPkg.sol
  EtherFiWeETH_Component_FactoryService.sol
  test/hermetic/                           # eETH/weETH/pool/queue/redeem ports
```

**Crane:** extend `EtherFiService` / interfaces as needed for queue + redemption manager helpers (no new remapping aliases).

---

## 9. Mainnet addresses (verify at implement)

| Contract | Address (verify) |
|----------|------------------|
| eETH | `0x35fA164735182de50811E8e2E824cFb9B6118ac2` |
| weETH | `0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee` |
| LiquidityPool | `0x308861A430be4cce5502d0A12724771Fc6DaF216` |
| WithdrawRequestNFT / RedemptionManager / PriorityQueue | From ether.fi deployments docs at pin |
| WETH | chain canonical |

---

## 10. Risks

1. Restaking / AVS / EigenLayer risk (document; separate from pure LST).  
2. Instant redeem capacity, exit fees, rate limits, low watermark.  
3. Async queue latency; sleeve can empty → WETH pays revert.  
4. Rebasing eETH accounting — minimize hold time; prefer weETH inventory.  
5. Pause / blacklist on pool, weETH, redemption manager.  
6. Upgradeable ether.fi proxies — pin interfaces; fork tests.

---

## 11. Acceptance criteria (product)

- [ ] All §4 routes work on **both** `exchangeIn` and `exchangeOut` with closed-form previews.  
- [ ] Preview == execution for closed-form paths (document ≤ few-wei only if forced).  
- [ ] Previews **not** gated on sleeve or redeem capacity.  
- [ ] WETH pay path: sleeve → instant redeem → revert; **no** user queue.  
- [ ] Stake routes unwrap WETH → pool deposit.  
- [ ] `rebalance` claim / stake excess / queue deficit.  
- [ ] Registry deploy only; production-first tests.  
- [ ] Hermetic + adversarial/invariant + mainnet fork gates (see impl plan).  
- [ ] Fork proves **live instant redeem** (D19).  
- [ ] WETH→SE mint leaves sleeve near target % and stakes overage (D12b).

---

## 12. Decision log (clarifications 2026-07-24)

| Topic | Choice |
|-------|--------|
| Liquid target maintenance | `rebalance()` **+** post large WETH→SE mint stake helper |
| eETH/weETH → WETH | Inventory swap + WETH pay ladder |
| Default liquid % | **20%** |
| WETH→SE WETH disposition | **Split on mint** (target liquid %, stake rest same tx) |
| Redeem output | ETH → wrap WETH |
| Shortfall error | `InsufficientLiquidReserve` only |
| Fork bar | Required **including live instant redeem** |
| Lido package | Reference only |

---

## 13. Changelog

| Date | Change |
|------|--------|
| 2026-07-24 | Initial PRD: Lido-shaped sleeve SE for ether.fi weETH; dual SE surfaces; optional RedemptionManager; no exchangeInEth |
| 2026-07-24 | Locked clarifications: 20% liquid default; WETH→SE split mint; rebalance + large-mint helper; fork must prove live redeem |

---

*Implementation plan is normative for phases and tests. Do not reopen D1–D19 without PRD revision.*
