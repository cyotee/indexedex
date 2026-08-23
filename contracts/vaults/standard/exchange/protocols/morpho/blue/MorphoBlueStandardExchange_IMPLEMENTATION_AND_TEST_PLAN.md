# Morpho Blue Standard Exchange — Implementation and Testing Plan

**Date:** 2026-08-22
**Status:** READY TO IMPLEMENT
**Normative product:** [`MorphoBlueStandardExchange_PRD.md`](./MorphoBlueStandardExchange_PRD.md)
**Shape references:**
- `contracts/protocols/lending/aave/v3.6/` (lending SE: marker, LENDING fee type, registry DFPkg)
- `contracts/vaults/standard/erc4626/` (SE In/Out + MultiAsset vault cuts; **not** sufficient for Blue NAV)
- Crane `TestBase_MorphoBlue` + `MorphoBlueService` + `MorphoBalancesLib`

**Methodology skills:** `crane-deployment`, `crane-architecture`, `crane-testing`, `indexedex-testing`, `crane-adversarial-testing`, `indexedex-adversarial-testing`, `crane-morpho`, `morpho-blue-operations`

Ordered for incremental delivery. Each phase leaves a green, reviewable slice. Do **not** reopen PRD D1–D37 without a PRD revision.

**Forge:** first compile in a cold or new worktree commonly takes 20–40+ minutes. Wait for process exit. Do not kill `forge` / `solc`. Timeout hours, not minutes. Seed `cache_forge/` + `out/` into new worktrees before the first compile (root `CLAUDE.md`).

---

## 0. Locked decisions (copy — PRD is source of truth)

| Topic | Decision |
|-------|----------|
| Protocol | Morpho Blue v1.0.0 singleton; one `MarketParams` per vault |
| `asset()` | Market **`loanToken`** (`rateAsset`) |
| Mode | Lend / supply only |
| SE surface | `IStandardExchangeIn` + `IStandardExchangeOut` + IERC4626 + Basic/Standard vault |
| Sleeve / `rebalance()` | **None in v1** |
| Missing market | **Revert.** Never `createMarket` from this vault |
| Inflow | Supply full measured inbound to Morpho; supply fail reverts the whole deposit |
| Preview | Full live NAV (accrued) |
| `maxWithdraw` / `maxRedeem` | Conservative: idle + Morpho free cash, capped by this vault's expected supply |
| Rate provider | **v1 smoke** against existing DFPkg; do not edit provider source |
| Uni V4 hook | Out of v1 |
| Vault V2 wrap | Follow-on package |
| Forks | Robinhood **and** Ethereum **and** Base |
| Usage fee default | **0** (tests also cover non-zero) |
| Decimal offset | **0** (A0 is the inflation gate) |
| Deploy | CREATE3 facets + vault **registry** DFPkg |
| SUT mocks | Forbidden (Morpho, this vault, manager, registry, fee oracle, rate-provider diamond) |

### Clarifications locked 2026-08-22 (user Q&A)

| # | Topic | Choice |
|---|--------|--------|
| 1 | Blue vs Vault V2 | Blue now; Vault V2 later |
| 2 | v1 done | Lend/withdraw + rate-provider smoke |
| 3 | Sleeve | None |
| 4 | Missing market | Bind existing only |
| 5 | Utilized unwrap quotes | Full-NAV preview; conservative maxWithdraw |
| 6 | Forks | Robinhood + Ethereum + Base |

---

## 1. Goals and non-goals

### Goals

1. Package: repo, common, Morpho-aware ERC4626, In/Out, marker, DFPkg, FactoryService, TestBase.
2. Dual-surface routes: `loanToken` ↔ SE only (exact-in and exact-out).
3. Same economics on IERC4626 `deposit` / `mint` / `withdraw` / `redeem`.
4. Live NAV = idle `loanToken` + `expectedSupplyAssets`.
5. Hermetic interest (warp + borrower) with exact Blue-expected deltas.
6. Utilization: `maxWithdraw` shrinks; unwrap reverts `InsufficientLiquidity`; deposit still works.
7. Rate-provider smoke (existing DFPkg).
8. Adversarial P0 on the production proxy.
9. Forks: Robinhood, Ethereum, Base against **live existing** markets with free cash.

### Non-goals

- `createMarket`, sleeve, `rebalance()`, `liquidReservePercentage`.
- Borrow, collateral, liquidate, flash loan, Bundler3, Public Allocator.
- Morpho Vault V2 / MetaMorpho / Midnight.
- Uni V4 hook e2e.
- Editing `StandardExchangeRateProvider` source.
- FoT / rebasing underlyings (forbidden; `test_L2_FoT_forbidden` only).

---

## 2. Critical implementation traps

### 2.1 Do not cut stock `ERC4626Facet` money paths

Crane `ERC4626Target.deposit` / `withdraw` / `redeem`:

- Convert shares against **`_lastTotalAssets`**, not a Morpho-aware `totalAssets()`.
- `withdraw` / `redeem` `safeTransfer` the **idle** `loanToken` balance, then set `_lastTotalAssets = balanceOf(this)` (Morpho position **dropped from the snapshot**).
- Never `Morpho.supply`.

**Lock:** Cut **`MorphoBlueERC4626Facet`** instead of `ERC4626Facet`. Override **all 16 IERC4626 selectors** so they call Common (same helpers as SE In/Out). Overriding only `totalAssets()` is not enough.

### 2.2 Two books

| Book | Meaning |
|------|---------|
| `IBasicVault.reserveOfToken(loanToken)` | **Idle** `loanToken` only (last end-of-op sync). Used for I1 reserve-delta pulls. |
| ERC4626 `totalAssets` / SE previews | **NAV** = idle + `MorphoBalancesLib.expectedSupplyAssets(...)`. |

Do not sync `reserveOfToken` to NAV. After Morpho.supply, idle ≈ rounding; booked reserve ≈ rounding; NAV is the Morpho position.

End of every successful money route:

1. `_syncReserveToBalance(loanToken)` (idle book).
2. `_setLastTotalAssets(_liveNav())` (4626 snapshot for any leftover reader).
3. Views (`totalAssets`, `convert*`, `preview*`) **must** call `_liveNav()`, not the snapshot, so rate-provider quotes accrue between txs.

### 2.3 Write-path NAV sync

At the **start** of every write:

```text
_syncNavSnapshot(); // lastTotalAssets := _liveNav()  (Morpho view-accrue)
```

Then pull, mint/burn against that NAV, Morpho.supply / withdraw, then write lastTotalAssets := `_liveNav()` again.

### 2.4 Stock ERC4626 `deposit` vs PRD D26

After mint, **`MorphoBlueService._supply`** the measured inbound (assets mode, `shares = 0`, `onBehalf = address(this)`, `data = ""`). **No try/catch.** If supply reverts, the whole tx reverts (D26).

### 2.5 Multiple inheritance in TestBase

`TestBase_MorphoBlue` extends `Test` and **creates the market in `setUp`**. `TestBase_VaultComponents` extends `IndexedexTest` → `CraneTest` → `Test`.

```text
TestBase_MorphoBlueStandardExchange
  is TestBase_Permit2, TestBase_VaultComponents, TestBase_MorphoBlue
```

`setUp` must call parents by name. Order: Permit2 + VaultComponents (IndexedEx stack), then MorphoBlue (`new Morpho` + `createMarket`), then CREATE3 SE facets + `indexedexManager.deployPkg` + `deployVault` on the **already-created** `marketParams`.

Fork bases: **do not** inherit MorphoBlue's `new Morpho`. Bind `ROBINHOOD_MAIN` / `ETHEREUM_MAIN` / `BASE_MAIN`.

---

## 3. Error surface

```solidity
/// @param requested loanToken amount required to pay
/// @param available idle + Morpho free cash usable by this vault
error InsufficientLiquidity(uint256 requested, uint256 available);

error MarketNotCreated(Id id);
error ZeroMorpho();
error ZeroLoanToken();
error ZeroOracle();
error ZeroIrm();
```

| Error | When | Preview? |
|-------|------|----------|
| `InsufficientLiquidity` | Execute unwrap / withdraw / redeem short of cash (D24) | **No.** Preview still returns full-NAV quote (D27). |
| `MarketNotCreated` | `initAccount` if `market(id).lastUpdate == 0` | n/a |
| `UnsupportedRoute` / `InvalidRoute` | Any pair other than loanToken ↔ SE | Yes (view) |
| `DeadlineExpired` | past deadline | n/a |
| `Slippage` | minOut / maxIn | n/a |
| `ZeroAmount` / `ZeroAddress` | guards | n/a |
| `TransferDeltaInsufficient` / peer pull errors | I1 / I2 | n/a |
| Blue protocol bubbles | assets XOR shares, insufficient Morpho cash, etc. | Prefer wrap pay-path as `InsufficientLiquidity` so UX is one error |

Exact selector from repo; no bare `vm.expectRevert()`.

---

## 4. Route matrix checklist (In **and** Out)

Assets: `L` = `loanToken`, `S` = SE share (`address(this)`).

| # | Pair | Exact-in | Exact-out | Exec notes |
|---|------|----------|-----------|------------|
| R1 | L→S | ☐ | ☐ | Pull delta; mint vs `_liveNav()`; fee shares; **hard** Morpho.supply inbound |
| R2 | S→L | ☐ | ☐ | Burn SE; idle first then Morpho.withdraw; `InsufficientLiquidity` if short |

IERC4626 mapping (same Common; must `assertEq` with R1/R2):

| IERC4626 | SE equivalent |
|----------|----------------|
| `deposit` / `previewDeposit` | R1 exact-in |
| `mint` / `previewMint` | R1 exact-out (shares out) |
| `withdraw` / `previewWithdraw` | R2 exact-out (assets out) |
| `redeem` / `previewRedeem` | R2 exact-in (shares in) |

`previewWithdraw` / `previewRedeem` stay **full NAV**. `maxWithdraw` / `maxRedeem` are the conservative caps.

For each R1/R2 on In and Out: `assertEq(preview, executed)` (or documented 1-wei Blue rounding).

---

## 5. Layout

```text
contracts/vaults/standard/exchange/protocols/morpho/blue/
  MorphoBlueStandardExchange_PRD.md
  MorphoBlueStandardExchange_IMPLEMENTATION_AND_TEST_PLAN.md
  IMorphoBlueStandardExchange.sol              # marker; fee type id
  IMorphoBlueStandardExchangeDFPkg.sol         # PkgInit / PkgArgs HERE only
  MorphoBlueStandardExchangeRepo.sol
  MorphoBlueStandardExchangeCommon.sol
  MorphoBlueERC4626Target.sol
  MorphoBlueERC4626Facet.sol
  MorphoBlueStandardExchangeInTarget.sol
  MorphoBlueStandardExchangeInFacet.sol        # facetFuncs: previewExchangeIn, exchangeIn ONLY
  MorphoBlueStandardExchangeOutTarget.sol
  MorphoBlueStandardExchangeOutFacet.sol       # previewExchangeOut, exchangeOut ONLY
  MorphoBlueStandardExchangeMarkerTarget.sol
  MorphoBlueStandardExchangeMarkerFacet.sol
  MorphoBlueStandardExchangeDFPkg.sol
  MorphoBlue_Component_FactoryService.sol
  test/bases/TestBase_MorphoBlueStandardExchange.sol

test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/
  MorphoBlueStandardExchange_Deploy.t.sol
  MorphoBlueStandardExchange_Routes.t.sol
  MorphoBlueStandardExchange_Interest.t.sol
  MorphoBlueStandardExchange_Liquidity.t.sol
  MorphoBlueStandardExchange_RateProvider.t.sol
  MorphoBlueStandardExchange_Fees.t.sol
  invariant/
    MorphoBlueStandardExchange_Invariant.t.sol
  adversarial/
    Adversarial_MorphoBlueStandardExchange_P0.t.sol

test/foundry/fork/robinhood_main/vaults/standard/exchange/protocols/morpho/blue/
  MorphoBlueStandardExchange_RobinhoodFork.t.sol
test/foundry/fork/ethereum_main/vaults/standard/exchange/protocols/morpho/blue/
  MorphoBlueStandardExchange_EthereumFork.t.sol
test/foundry/fork/base_main/vaults/standard/exchange/protocols/morpho/blue/
  MorphoBlueStandardExchange_BaseFork.t.sol
```

Marker interface may instead live under `contracts/interfaces/` if registry peers require it (Stata pattern). Keep the **type name** `IMorphoBlueStandardExchange`.

### Crane reuse (no v1 Crane edits unless a hole is proven)

| Need | Use |
|------|-----|
| Supply / withdraw | `MorphoBlueService` |
| Morpho address storage | `MorphoBlueAwareRepo` |
| NAV of this vault's supply | `MorphoBalancesLib.expectedSupplyAssets` |
| Free cash | `expectedTotalSupplyAssets - expectedTotalBorrowAssets` |
| Hermetic Morpho | `TestBase_MorphoBlue` |
| Types | `IMorpho`, `MarketParams`, `Id` from Crane Morpho Blue interfaces |

---

## 6. Implementation phases

### Phase 0 — Scaffold + Crane check

- [x] Package files + interfaces with NatSpec / `// tag::` where peers tag
- [x] `PkgInit` / `PkgArgs` **on the interface only**
- [x] Confirm `MorphoBlueService._supply` / `_withdraw` and `expectedSupplyAssets` cover SE needs
- [x] Slot: `indexedex.vaults.standard.exchange.protocols.morpho.blue` (ERC1967 `keccak-1` form)

**Exit:** empty targets compile; no `new` facets.

---

### Phase 1 — Repo + Common

**Deliverables**

- Repo: `MarketParams`, `Id` (and morpho via AwareRepo)
- `_liveNav()` = idle `loanToken.balanceOf(this)` + `expectedSupplyAssets(morpho, params, address(this))`
- `_morphoFreeCash()` = min(vault expected supply, expectedTotalSupply − expectedTotalBorrow)
- `_syncNavSnapshot()`, `_securePull` (BasicVault reserve-delta), `_mintWithUsageFee`, `_burnShares`
- `_supplyInBound(assets)` → `MorphoBlueService._supply` (D26, no try/catch)
- `_payLoanToken(assets, receiver)` → idle first, then withdraw assets mode; full position close uses shares mode (PRD D19)
- Quotes: L↔S exact-in/out from `_liveNav()` (ungated on Morpho cash)

**Tests (can be internal/common-facing via TestBase once Phase 3 exists; until then, defer execute tests to Phase 3 and keep helpers `internal`)**

**Exit:** Common compiles; no sleeve/rebalance symbols.

---

### Phase 2 — ERC4626 + Marker

**Deliverables**

- `MorphoBlueERC4626Target`: override deposit/mint/withdraw/redeem + all view/preview/max to Common
- Facet: `facetInterfaces` = `IERC4626`; `facetFuncs` = **all 16** IERC4626 selectors (copy list from `ERC4626Facet`, not a subset)
- Marker: `morpho()`, `marketParams()`, `marketId()`, `loanToken()`; **no** `rebalance()`
- `maxWithdraw(owner)` = min(`convertToAssets(balanceOf(owner))`, idle + `_morphoFreeCash()`)
- `maxRedeem` = convert that cap to shares (ceil/floor match Crane 4626 direction)

**Exit:** Facets compile; declaration controls derived from Target.

---

### Phase 3 — In/Out + DFPkg + FactoryService + TestBase

**Deliverables**

- In/Out targets: R1/R2; Permit2/deadline/`pretransferred` via Common pull
- Facet `facetFuncs`: **only** the two In / two Out selectors
- DFPkg:
  - Cuts: ERC20 + ERC5267 + ERC2612 + **MorphoBlueERC4626** + MultiAsset Basic + MultiAsset Standard + In + Out + Marker
  - **Do not** cut stock `ERC4626Facet` or `ERC4626StandardVaultFacet` (selector clash with MultiAsset Standard / Morpho 4626)
  - `vaultFeeTypeIds`: `VaultFeeType.LENDING` + `type(IMorphoBlueStandardExchange).interfaceId`
  - `initAccount`: bind repos; ERC20 18 dec; ERC4626 `asset=loanToken`; vaultTokens `[loanToken]`; **revert `MarketNotCreated`** if `lastUpdate == 0`
  - `deployVault(PkgArgs)` → `VAULT_REGISTRY_DEPLOYMENT.deployVault`
- FactoryService: CREATE3 In/Out/Marker/ERC4626 facets + `deployMorphoBlueStandardExchangeDFPkg(indexedexManager, pkgInit)` via `deployPkg`
- TestBase: inherit as §2.5; `vm.prank(owner)` for DFPkg; `deployVault` after MorphoBlue `createMarket`

**Tests**

| ID | Case |
|----|------|
| D1 | Registry deploy; `asset() == loanToken`; `vaultTokens == [loanToken]`; marker getters |
| D2 | `deployVault` with never-created `MarketParams` → `MarketNotCreated` |
| J1–J3 | Target API ⊆ facetFuncs ⊆ cuts ⊆ proxy loupe; smoke **on proxy** |

**Exit:** Deploy suite green hermetically.

---

### Phase 4 — Routes + IERC4626 parity

| ID | Case |
|----|------|
| P1 | R1 In: preview == exec; Morpho expected supply ↑; idle ~ rounding |
| P2 | R1 Out (exact shares out / mint) |
| P3 | R2 In: redeem shares → loanToken; Morpho supply ↓ |
| P4 | R2 Out: withdraw exact assets |
| P5 | IERC4626 deposit/mint/withdraw/redeem match P1–P4 amounts |
| P6 | InvalidRoute for L→L, S→S, collateralToken, random ERC20 |
| P7 | Non-18 `loanToken` (6 decimals mock) mint/redeem conservation |

**Exit:** Routes suite green.

---

### Phase 5 — Interest + utilization

Hermetic: fund Morpho supplier via the SE; borrower posts collateral + borrows; `vm.warp`.

| ID | Case |
|----|------|
| I1 | After warp, `convertToAssets` / `_liveNav()` match `expectedSupplyAssets + idle` (exact) |
| I2 | Redeem after interest: `assetsOut > assetsIn` for same shares; delta vs Blue expected |
| U1 | Borrow until free cash ≈ 0; `maxWithdraw` shrinks toward idle (~0) |
| U2 | R2 execute above `maxWithdraw` → `InsufficientLiquidity(requested, available)` exact args |
| U3 | Preview R2 still returns **full NAV** quote while U2 would revert |
| U4 | Deposit / R1 still succeeds while utilized (Blue still accepts supply) |
| U5 | Partial withdraw equal to `maxWithdraw` succeeds |

**Exit:** Interest + liquidity suites green.

---

### Phase 6 — Rate provider smoke

Use existing `StandardExchangeRateProvider_FactoryService` + DFPkg. Deploy via **`diamondPackageFactory`** (not vault registry). `rateSubject = address(0)` (defaults to SE). `rateTarget = loanToken`.

| ID | Case |
|----|------|
| RP0 | Empty SE: `getRate() == 0` |
| RP1 | After deposit: `getRate()` matches provider's `previewExchangeIn` scaling (see `StandardExchangeRateProviderFacet`) |
| RP2 | After interest warp: `getRate()` rises with `convertToAssets` |
| RP3 | Do not modify provider source; failures here are **this vault's** preview/NAV bugs unless proven otherwise |

**Exit:** Rate-provider spec green.

---

### Phase 7 — Fees

| ID | Case |
|----|------|
| F1 | Usage fee 0: no feeTo shares; supply == user shares |
| F2 | Type usage fee > 0: fee shares to `feeTo()`; user still gets full `sharesForDeposit` (Stata inflation) |
| F3 | Marker interface id is the LENDING type key used by the oracle lookup |

---

### Phase 8 — Adversarial P0

Production proxy only. Catalog: `crane-adversarial-testing` + `indexedex-adversarial-testing`. Exact selectors. Failed txs leave residual free inventory ~0.

| ID | Theme | Pass |
|----|--------|------|
| A0 | Donate `loanToken` or Morpho.supply onBehalf of vault **before first mint** | First depositor does not extract donation as free shares |
| A1 | Donate `loanToken` after live | No free mint; victim NAV rises (K1), credit still delta-based |
| I1 | `pretransferred=true`, no transfer, vault already holds inventory | No mint; revert pull error |
| I2 | Short pretransfer vs claimed | Exact revert |
| I3 | Residual cannot fund a second free mint | |
| E1 | Round-trip L↔S | Conservation idle+Morpho vs shares ± Blue dust |
| E5 | ZeroAmount / DeadlineExpired | Exact |
| E6 | Fat `maxAmountIn` + transfer only `used` + pretransfer | Booked idle / Morpho position intact; attacker does not receive booked inventory |
| H3 | minOut fail | Full revert; no shares; Morpho position unchanged |
| C* | Reentrancy via hostile `loanToken` (non-SUT) | Nested `IsLocked` |
| L2 | Real FoT as **configured** `loanToken` | `test_L2_FoT_forbidden`; never `credits_actualIn` |
| CROPS | `setVaultAddressDisabled(true)` | `exchangeOut` / redeem still work |
| O1–O2 | Permit2 / permit if exposed | Invalid/replay revert |
| J* | Already Phase 3; keep on adversarial proxy smoke | |

**Deferred (NatSpec on suite):** M* (no user calldata forwarder); N* (no external callback between quote and settle besides Morpho itself; Morpho `data=""`); sleeve/rebalance IDs; Vault V2; hook.

```bash
forge test --match-contract Adversarial_MorphoBlueStandardExchange_P0 -vv
```

Do **not** `--match-test test_C` / `test_A0` under a wide path (collides with DETF compound / other A0).

---

### Phase 9 — Invariants / fuzz

Handler on production vault + hermetic Morpho:

| Action | Notes |
|--------|--------|
| exchangeIn L→S / deposit / mint | |
| exchangeOut S→L / withdraw / redeem | catch `InsufficientLiquidity` |
| donate loanToken | |
| Morpho.supply onBehalf vault (donation) | |
| borrower borrow/repay + warp | utilization + interest |
| skip createMarket / sleeve | |

| Inv | Statement |
|-----|-----------|
| N1 | `_liveNav() == idle + expectedSupplyAssets` |
| N2 | `reserveOfToken(loanToken) == idle` (not NAV) |
| N3 | `totalSupply == user shares + feeTo shares` |
| N4 | donation does not free-mint extractable principal (A0/A1) |
| N5 | no Morpho authorization for third parties |
| N6 | vault Morpho position `onBehalf` is only `address(this)` |

```bash
forge test --match-path 'test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/invariant/**' -vv
```

---

### Phase 10 — Forks (`FOUNDRY_PROFILE=fork`)

Each chain: bind Morpho + **one live market with free cash** at the pin. Record `MarketParams` / `Id` in the TestBase (do not guess). Discover via Morpho app / `morpho.id` / existing fork helpers.

| Chain | Morpho |
|-------|--------|
| Robinhood 4663 | `ROBINHOOD_MAIN.MORPHO` = `0x9D53d5E3bd5E8d4Cbfa6DB1ca238AEA02E651010` |
| Ethereum | `ETHEREUM_MAIN.MORPHO` = `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |
| Base | `BASE_MAIN.MORPHO` = `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |

| ID | Case |
|----|------|
| FK0 | `morpho.code.length > 0`; `market.lastUpdate != 0` |
| FK1 | Registry `deployVault` against that live market |
| FK2 | Deposit / exchangeIn L→S; Morpho expected supply of vault ↑ |
| FK3 | Withdraw / exchangeOut S→L while free cash > 0 |
| FK4 | Missing-market `deployVault` still reverts on fork Morpho |
| FK5 | Do **not** wrap Steakhouse / Vault V2 |

If the pin has **zero free cash** on the chosen market: pick another market or another block. Do not soft-pass FK3 forever.

**IRM mismatch:** live AdaptiveCurveIRM is bound to that Morpho. Hermetic IRM is a different instance. Fork tests call **live** Morpho only.

```bash
FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/robinhood_main/vaults/standard/exchange/protocols/morpho/blue/**' -vv
FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/ethereum_main/vaults/standard/exchange/protocols/morpho/blue/**' -vv
FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/base_main/vaults/standard/exchange/protocols/morpho/blue/**' -vv
```

---

## 7. Component checklist

### Crane

- [x] Service/Balances/Aware/TestBase sufficient (edit Crane only if a proven hole)

### Package

- [x] Repo + Common (two books; hard supply; idle-first pay)
- [x] MorphoBlue ERC4626 Target/Facet (all 16 selectors)
- [x] In/Out + Marker
- [x] DFPkg + FactoryService (registry `deployPkg`)
- [x] TestBase: VaultComponents + MorphoBlue + Permit2

### Tests

- [x] Deploy D1–D2 + J
- [x] Routes P1–P7
- [x] Interest + utilization
- [x] Rate provider RP0–RP3
- [x] Fees F1–F3
- [x] Adversarial P0
- [x] Invariant
- [x] Fork FK* × 3 chains

---

## 8. Acceptance criteria

- [x] PRD D1–D37 respected in code
- [x] R1 and R2 on **both** In and Out; IERC4626 parity
- [x] Preview full NAV; `maxWithdraw` conservative; execute `InsufficientLiquidity` when dry
- [x] Deposit always Morpho.supply; no sleeve; no `createMarket`
- [x] Rate-provider smoke green without editing provider
- [x] A0 / I1–I3 / E6 / L2 / CROPS / J on production proxy
- [x] Forks: Robinhood + Ethereum + Base, live existing markets
- [x] No `new` facets/DFPkg; no Morpho/vault/manager mocks
- [x] `via_ir` still off

Ship gate: `lib/crane/.claude/skills/crane-adversarial-testing/references/implementation-test-dod.md`

---

## 9. Commands

Hermetic (default profile):

```bash
forge test --match-path 'test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/**' -vv
forge test --match-contract Adversarial_MorphoBlueStandardExchange_P0 -vv
```

Fork: see Phase 10. Prefer `--match-contract` over short `--match-test` prefixes.

---

## 10. Follow-on (not this plan)

1. Sleeve / `rebalance()` PRD revision if Uni V4 unwraps need cash under utilization.
2. Hook composition e2e.
3. Vault V2 / Steakhouse package.
