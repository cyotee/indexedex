# PRD: Lido wstETH Standard Exchange Vault

**Date:** 2026-07-23  
**Status:** Draft for implementation planning  
**Package path (target):** `contracts/protocols/staking/lido/`  
**Crane integration:** `lib/crane/contracts/protocols/staking/ethereum/lido/`  
**Lido vendor (reference):** `lib/crane/contracts/external/lido/`  

**Related docs:**
- Research: `docs/research/2026-07-23-ethereum-staking-ported-protocols-custom-se-assessment.md`
- Market assessment: `docs/research/2026-07-21-ethereum-staking-protocols-se-vault-assessment.md`
- Gold reference (shape): `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md`
- Generic ERC-4626 SE (not sufficient alone): `contracts/vaults/standard/erc4626/`
- Vault Fee Oracle: `contracts/oracles/fee/`, `contracts/interfaces/IVaultFeeOracleQuery.sol`, `IVaultFeeOracleManager.sol`

---

## 1. Goal

Deliver a production-first **Standard Exchange (SE) vault** that wraps Lido liquid staking for IndexedEx:

1. Prefer **`wstETH`** as the yield / locked reserve (non-rebasing).  
2. Hold a **liquid WETH sleeve** so closed-form **WETH ↔ SE** routes work when inventory allows.  
3. Target liquid vs locked mix via **Vault Fee Oracle** policy (`defaultLiquidReservePercentage` + per-vault override), same three-tier cascade as existing fee/incentive parameters.  
4. **Rebalance:** when liquid is above target → stake excess into Lido (ETH/WETH → stETH → wstETH); when below → queue Lido withdrawals, later claim **native ETH** and wrap to WETH.  
5. Deploy via CREATE3 + IndexedEx vault registry; composable as an `IStandardExchange` leg for Balancer buffers and DETFs.

This is **not** a pure generic ERC-4626 SE: Lido mint/wrap and WithdrawalQueue are protocol-specific.

---

## 2. Product summary

### 2.1 User-facing value

| Capability | v1 |
|------------|----|
| Stake ETH/WETH into Lido via SE | Yes (submit + wrap; stake limit / pause apply) |
| Hold yield as wstETH | Yes |
| Mint/burn SE shares against WETH when liquid sleeve funded | Yes (closed-form) |
| Mint/burn SE shares against wstETH | Yes (closed-form) |
| Instant stETH ↔ wstETH | Yes (wrap/unwrap) |
| Instant primary ETH out from Lido in one user tx | **No** (protocol constraint) |
| Instant WETH out from **vault buffer** | Yes, **iff** liquid sleeve ≥ amount |
| Async Lido exit managed by vault | Yes (rebalance queues; claim + wrap) |

### 2.2 Non-goals (v1)

- Exact wall-clock ETA for Lido queue finalization on-chain.  
- Guaranteed always-on WETH Out (buffer can empty).  
- Secondary-market DEX routing inside the SE diamond (optional later).  
- User-facing unstETH NFT UX as the primary product (vault owns NFTs for rebalance).  
- Borrowing, restaking, or multi-LST baskets.  
- Treating rebasing **stETH** as the SE `asset()` / primary reserve accounting unit.

---

## 3. Lido protocol constraints (normative)

These are hard product constraints from Lido core (see vendor tree + Crane `LidoService`).

### 3.1 Deposit (ETH → stETH)

- `submit(referral) payable` mints stETH shares; any size &gt; 0 (not 32 ETH only).  
- Reverts: `ZERO_DEPOSIT`, `STAKING_PAUSED`, `STAKE_LIMIT` (rate limit).  
- Views for gates/UX: `isStakingPaused()`, `getCurrentStakeLimit()`.  
- Crane `IStETH` / `LidoService` today cover submit + wrap; stake-limit views should be added to the integration surface.

### 3.2 Wrap / unwrap

- `wstETH.wrap` / `unwrap` are **instant**; unwrap returns **stETH**, not ETH.  
- Prefer vault inventory in **wstETH**, not rebasing stETH.

### 3.3 Primary withdraw (stETH/wstETH → ETH)

- **Async only:** `requestWithdrawals` / `requestWithdrawalsWstETH` → oracle finalization → `claimWithdrawal*`.  
- Claim pays **native ETH** (`call{value:}`), **not WETH**.  
- Min **100 wei** stETH / request; max **1000 stETH** / request (split larger exits).  
- `finalize` requires `FINALIZE_ROLE` (protocol/oracle path) — **users/vault cannot finalize from buffer in the same tx as request**.  
- Lido internal buffer speeds finalization; it does **not** enable atomic user redeem.

### 3.4 Queue observability

- **Efficient on-chain:** `unfinalizedStETH()`, `unfinalizedRequestNumber()`, bunker flag, `getBufferedEther()`, per-request status.  
- **Not on-chain:** reliable duration ETA (use off-chain / Lido withdrawals API for UI).

---

## 4. Reserve model (vault accounting)

### 4.1 Buckets

All amounts valued in ETH terms (1e18) for NAV and policy:

| Bucket | Asset | Role |
|--------|--------|------|
| **Liquid** | WETH | Closed-form WETH In/Out inventory |
| **Locked yield** | wstETH | Staked Lido exposure |
| **In-flight** | WithdrawalQueue request NFTs (unstETH) | Pending / claimable primary exits |
| **Transient** | ETH (pre-wrap), stETH (pre-wrap) | Must not linger after ops |

```text
totalReserveEth ≈
    WETH.balance(vault)
  + wstETH_to_ETH(wstETH.balance(vault))
  + sum(claimable ETH for vault-owned finalized requests)
  + sum(pending request value)   // see valuation rule below
```

### 4.2 In-flight valuation (v1 rule)

| State | Value for NAV |
|-------|----------------|
| Pending (not finalized) | stETH face amount at request (or shares × current rate — **pick one in implementation plan; prefer face stETH locked at request for conservatism docs**) |
| Finalized, unclaimed | `getClaimableEther` (may be discounted) |
| Claimed | 0 (ETH/WETH already in liquid) |

PRD lock for v1 implementation plan: **pending = request stETH amount in ETH units (1:1 face)**; **finalized = claimable ether view**. Document share-price sensitivity in tests.

### 4.3 SE share layer

- Vault is an ERC-20 / ERC-4626-style SE share.  
- **Primary yield reserve for 4626 `asset()`:** recommend **`wstETH`** as the named reserve asset for registry/composability, **with multi-bucket NAV** for share conversion (liquid + locked + in-flight).  
- Alternative (reject for v1 unless needed): synthetic multi-asset 4626 without single `asset()` — prefer single `asset() = wstETH` plus explicit liquid accounting like Stata SE multi-layer routes.

**Decision (v1):**  
- `IERC4626.asset()` / marker “primary locked asset” = **wstETH**.  
- Liquid WETH is an explicit second inventory tracked in vault repo, included in total assets for share mint/burn math.  
- `IBasicVault.vaultTokens()` includes at least: **wstETH, WETH, stETH** (and SE share is `address(this)` on exchange routes).

---

## 5. Liquid reserve policy via Vault Fee Oracle

### 5.1 Why Fee Oracle

Existing oracle already implements **immutable vault instances + mutable policy off-instance**:

- Three-tier fallback: **vault override → type default → global default**  
- Percentages in **WAD** (`1e18 = 100%`)  
- `0` stored value means **unset** (fall through), not necessarily “zero policy”  
- Manager: owner/operator; Query: anyone  

Relevant existing parallels:

| Domain | Global | Type | Vault |
|--------|--------|------|-------|
| Usage fee | `defaultUsageFee` | `defaultUsageFeeOfTypeId` | `usageFeeOfVault` |
| DEX swap fee | `defaultDexSwapFee` | `defaultDexSwapFeeOfTypeId` | `dexSwapFeeOfVault` |
| Seigniorage incentive | `defaultSeigniorageIncentivePercentage` | `seigniorageIncentivePercentageOfTypeId` | `seigniorageIncentivePercentageOfVault` |

Lido SE will add the same pattern for **liquid reserve target percentage** (WETH sleeve size).

### 5.2 Why `liquidReservePercentage` (not locked)

Rebalance compares **actual liquid WETH** to a liquid target. Orienting the oracle knob the same way keeps math and UX aligned:

```text
targetLiquidEth = totalReserveEth * liquidReservePercentage / 1e18
excess          = actualLiquid - targetLiquid   // stake this
deficit         = targetLiquid - actualLiquid   // queue this
```

Locked inventory is **derived**: `targetLockedEth = totalReserveEth - targetLiquidEth` (wstETH ETH value + in-flight). Operators think in “keep X% liquid for WETH Out,” not “keep Y% locked.”

### 5.3 Semantics of `liquidReservePercentage`

**Definition (normative):**

```text
liquidReservePercentage ∈ [0, 1e18]  // WAD

targetLiquidEth = totalReserveEth * liquidReservePercentage / 1e18
targetLockedEth = totalReserveEth - targetLiquidEth
```

- **Liquid** inventory = WETH (ETH value).  
- **Locked** inventory for policy purposes = wstETH (ETH value) + in-flight queue value.  
- Rebalance moves inventory toward these targets (see §6).

**Default recommendation:** `0.05e18` (5% liquid / 95% locked) unless product sets otherwise at deploy-time oracle config.

### 5.4 Query API (`IVaultFeeOracleQuery`)

Add:

```solidity
/* -------------------------------------------------------------------------- */
/*                         Liquid reserve policy (WAD)                        */
/* -------------------------------------------------------------------------- */

/// @notice Global default fraction of total reserve that should remain liquid (WETH sleeve).
/// @dev WAD: 1e18 = 100%. Resolution: vault → type → global. Stored 0 = unset (fallback).
function defaultLiquidReservePercentage() external view returns (uint256 percentage);

/// @notice Type-level default (vault fee type id / marker interface id).
function defaultLiquidReservePercentageOfTypeId(bytes4 vaultTypeId)
    external
    view
    returns (uint256 percentage);

/// @notice Effective liquid-reserve target for `vault` after three-tier resolution.
function liquidReservePercentageOfVault(address vault) external view returns (uint256 percentage);
```

Optional convenience (mirror seigniorage):

```solidity
function liquidReservePercentageOfVaultAndFeeTo(address vault)
    external
    view
    returns (IFeeCollectorProxy feeTo, uint256 percentage);
```

Optional enumeration (if registry tracks type ids for this domain):

```solidity
function liquidReserveVaultTypeIds() external view returns (bytes4[] memory vaultTypeIds_);
```

**Resolution algorithm** (identical structure to `seigniorageIncentivePercentageOfVault` / `usageFeeOfVault`):

```solidity
function liquidReservePercentageOfVault(address vault) public view returns (uint256 percentage) {
    percentage = VaultFeeOracleRepo._liquidReservePercentageOfVault(vault);
    if (percentage == 0) {
        percentage = defaultLiquidReservePercentageOfTypeId(
            // v1: reuse usage fee type id of vault (marker interface id)
            VaultRegistryVaultRepo._usageFeeIdOfVault(vault)
        );
        if (percentage == 0) {
            percentage = defaultLiquidReservePercentage();
        }
    }
    return percentage;
}
```

**Type id key (v1 decision):** use the vault’s **usage fee type id** (marker interface id registered on DFPkg `vaultFeeTypeIds` under `VaultFeeType.USAGE` and/or staking/lending slot as package declares). Avoids expanding packed `VaultFeeType` in v1 unless we already need a dedicated partition.

**Known limitation (existing oracle semantics):** stored `0` means unset. An explicit policy of **0% liquid (all staked)** cannot be set via “store 0” at vault tier. Mitigations (pick in implementation plan):

1. **Sentinel:** treat `1` wei as “explicit near-zero liquid” and document; or  
2. **Separate boolean** `liquidReservePercentageSet[vault]`; or  
3. **Disallow 0% liquid** in v1 (min liquid e.g. 1% / `1e16`).  

PRD preference: **(2) explicit set flag** in repo if product needs true 0% liquid; otherwise document 0=unset and use a non-zero global default (e.g. `0.05e18`). Explicit **100% liquid** is fine (`1e18`).

### 5.5 Manager API (`IVaultFeeOracleManager`)

```solidity
/// @param percentage Global default liquid reserve fraction in WAD. Prefer non-zero global (e.g. 0.05e18).
function setDefaultLiquidReservePercentage(uint256 percentage) external returns (bool success);

/// @param vaultTypeId Marker / fee type id (e.g. ILidoWstETHStandardVault interface id).
/// @param percentage Type default in WAD. 0 = clear type override (unset → fall back to global).
function setDefaultLiquidReservePercentageOfTypeId(bytes4 vaultTypeId, uint256 percentage)
    external
    returns (bool success);

/// @param vault Vault instance.
/// @param percentage Vault override in WAD. 0 = clear override (fall back to type/global) under current 0=unset rules.
function setLiquidReservePercentageOfVault(address vault, uint256 percentage)
    external
    returns (bool success);
```

Access control: same as peers — `onlyOwnerOrOperator` (and `setFeeTo` remains owner-only if applicable).

### 5.6 Repo storage (`VaultFeeOracleRepo.Storage`)

Extend:

```solidity
uint256 defaultLiquidReservePercentage;
mapping(bytes4 vaultFeeTypeId => uint256) defaultLiquidReservePercentageOfType;
mapping(address vault => uint256) liquidReservePercentageOfVault;
// if explicit-zero liquid required:
// mapping(address vault => bool) liquidReservePercentageVaultSet;
// mapping(bytes4 => bool) liquidReservePercentageTypeSet;
```

- Validate with existing `_validateWadPercentage` (`<= 1e18`).  
- Init path (`_initVaultRegistryFeeOracle` or follow-on init): set a non-zero global default (e.g. `0.05e18`) when rolling out.

### 5.7 Events

```solidity
event NewDefaultLiquidReservePercentage(uint256 indexed oldPercentage, uint256 indexed newPercentage);
event NewDefaultLiquidReservePercentageOfTypeId(
    bytes4 indexed vaultTypeId, uint256 indexed oldPercentage, uint256 indexed newPercentage
);
event NewLiquidReservePercentageOfVault(
    address indexed vault, uint256 indexed oldPercentage, uint256 indexed newPercentage
);
```

### 5.8 Facet wiring

| File | Change |
|------|--------|
| `IVaultFeeOracleQuery.sol` | Query functions §5.4 |
| `IVaultFeeOracleManager.sol` | Manager functions §5.5 + events |
| `VaultFeeOracleRepo.sol` | Storage + getters/setters |
| `VaultFeeOracleQueryFacet.sol` | Implement resolution + `facetFuncs` list growth |
| `VaultFeeOracleManagerFacet.sol` | Implement setters + `facetFuncs` list growth |
| Fee oracle DFPkg / diamond cut | Include new selectors on manager deploy / upgrade path |
| Tests | Unit resolution cascade; integration with Lido SE rebalance |

### 5.9 Vault consumption

```solidity
uint256 liquidBpsWad = feeOracle.liquidReservePercentageOfVault(address(this));
uint256 targetLiquid = totalReserveEth * liquidBpsWad / ONE_WAD;
// actualLiquid = WETH balance (ETH units)
// actualLocked = totalReserveEth - actualLiquid  // derived
```

Optional **hysteresis band** (v1 recommended constants on vault or oracle later):

- Rebalance deposit only if `actualLiquid > targetLiquid * (1 + band)`  
- Rebalance withdraw only if `actualLiquid < targetLiquid * (1 - band)`  
- Band e.g. 10% of target liquid or fixed 0.5% of total NAV — finalize in implementation plan to avoid thrashing the WithdrawalQueue.

---

## 6. Rebalance state machine

Permissionless `rebalance()` (or split `claimAndWrap` / `stakeExcess` / `queueDeficit`):

```text
1) Claim all claimable vault-owned requests → receive ETH → WETH.deposit
2) Refresh totalReserveEth; targetLiquid from feeOracle.liquidReservePercentageOfVault(this)
3) If actualLiquid > targetLiquid + band:
      amount = excess WETH
      WETH.withdraw → Lido.submit → wstETH.wrap (or submitAndWrap helper)
      respect stake pause / stake limit (partial stake OK if limit binds)
4) If actualLiquid < targetLiquid - band:
      deficitEth = targetLiquid - actualLiquid
      convert deficit to wstETH amount to exit
      split into ≤ 1000 stETH-equivalent requests
      requestWithdrawalsWstETH(...); vault is owner of NFTs
5) Emit Rebalance event with before/after liquid & locked
```

### 6.1 Rules

- Vault must implement `receive()` for claim ETH; reentrancy-locked claim/rebalance.  
- Vault is **owner** of WithdrawalQueue NFTs; do not transfer NFTs to users in v1 rebalance path.  
- Max requests enqueued per `rebalance` call: gas-bound constant (e.g. 5–10).  
- If staking paused, skip stake leg; if queue paused for placement, skip queue leg; always allow claim of finalized.  
- **WETH Out does not call rebalance implicitly** unless gas-safe and product wants “try claim first”; v1: user/keeper calls rebalance separately.

### 6.2 What rebalance is not

- Not a user SE route.  
- Not a guarantee of meeting target after one call (async queue).  
- Not finalization (protocol-only).

---

## 7. Supported exchange routes (v1)

Use `IStandardExchangeIn` / `IStandardExchangeOut` with previews. Prefer exact preview == execution where closed-form.

### 7.1 Closed-form (must implement)

| tokenIn | tokenOut | Notes |
|---------|----------|--------|
| WETH | SE | Mint using liquid sleeve +/or stake path per design |
| SE | WETH | **Only if** liquid WETH ≥ amountOut path; else revert `InsufficientLiquidReserve` |
| wstETH | SE | Deposit locked inventory |
| SE | wstETH | Redeem from locked inventory (respect keep liquid target optionally) |
| stETH | wstETH | wrap |
| wstETH | stETH | unwrap |
| ETH | stETH / wstETH / SE | native path via submit (+ wrap); WETH-aware where peers do |
| stETH | SE | wrap then mint |

**Mint with WETH when over liquid target after mint:** may auto-stake excess in same tx (optional; document gas).

**Redeem SE → WETH:** burn shares against NAV; pay WETH; do **not** start Lido queue inside `exchangeOut` for the shortfall.

### 7.2 Explicit non-routes / multi-step (v1)

| Intent | Handling |
|--------|----------|
| SE → ETH via Lido primary in one `exchangeOut` | `InvalidRoute` or unsupported |
| SE → WETH when liquid empty | `InsufficientLiquidReserve` (not silent queue) |
| Exact-out solvers over queue | Forbidden |

### 7.3 Optional later

- User-initiated `requestProtocolExit` / `claimProtocolExit` facets.  
- DEX fallback for WETH Out.  
- Auto-rebalance hook at start of `exchangeOut` (claim only).

---

## 8. Marker, fees, registry

### 8.1 Marker interface

```solidity
interface ILidoWstETHStandardVault {
    function wstETH() external view returns (address);
    function stETH() external view returns (address);
    function weth() external view returns (address);
    function withdrawalQueue() external view returns (address);
    // optional views:
    function liquidReserveEth() external view returns (uint256);
    function lockedReserveEth() external view returns (uint256); // derived: total - liquid (+ in-flight split as defined)
    function actualLiquidReservePercentage() external view returns (uint256); // current, not target
    function targetLiquidReservePercentage() external view returns (uint256); // oracle effective
}
```

- Marker **interface id** keys usage fee type (and liquid-reserve type resolution via usage id in v1).  
- Usage fee: default may be non-zero in tests; production often override type fee to 0 (Stata pattern).

### 8.2 DFPkg

- `PkgInit` / `PkgArgs` on **interface** (Crane rule).  
- `deployVault` args: wire mainnet/fork addresses for stETH, wstETH, WETH, WithdrawalQueue (or locator).  
- `vaultFeeTypeIds`: insert marker id under `VaultFeeType.USAGE` (and any staking-specific slot if introduced).  
- Registry path only: `indexedexManager.deploy*DFPkg` / `deployVault` — never `new`.

### 8.3 Facets (indicative)

```text
contracts/protocols/staking/lido/
  ILidoWstETHStandardVault.sol
  LidoWstETHStandardExchangeDFPkg.sol
  LidoWstETH_Component_FactoryService.sol
  LidoWstETHMarkerFacet.sol / Target
  LidoWstETHStandardExchangeInFacet.sol / Target
  LidoWstETHStandardExchangeOutFacet.sol / Target
  LidoWstETHRebalanceFacet.sol / Target   // claim, stake excess, queue deficit
  LidoWstETHStandardExchangeCommon.sol
  LidoWstETHStandardExchangeRepo.sol      // liquid accounting, request id set
  TestBase_LidoWstETHStandardExchange.sol
  LIDO_WSTETH_STANDARD_EXCHANGE_VAULT_PRD.md  (this file)
  LIDO_WSTETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md  (follow-on)
```

---

## 9. Crane surface extensions

Expand beyond current `LidoService` submit/wrap/unwrap:

| Addition | Purpose |
|----------|---------|
| Stake limit / pause views on `IStETH` or service | Previews and rebalance guards |
| `IWithdrawalQueue` integration interface | request / status / claim / min-max |
| Claim → wrap helper | ETH → WETH |
| Rate: `WstETHRateProvider` already present | Balancer / NAV |

Mainnet addresses: see Crane `staking/ethereum/README.md` (verify at deploy).

---

## 10. Testing requirements (production-first)

Inherit: `CraneTest` → `IndexedexTest` → vault components → `TestBase_LidoWstETHStandardExchange`.

**Must cover:**

1. Deploy via registry; marker + fee type id wiring.  
2. ETH/WETH → wstETH → SE mint; preview == execution.  
3. SE → WETH when liquid sufficient; revert when insufficient.  
4. SE ↔ wstETH.  
5. stETH ↔ wstETH.  
6. Fee oracle cascade: global / type / vault for `liquidReservePercentage`.  
7. Rebalance: over-liquid → stake; under-liquid → queue NFT owned by vault.  
8. Claim finalized → WETH increases liquid.  
9. NAV includes in-flight (mint/burn fairness under pending requests).  
10. Stake pause / stake limit handling on deposit path.  
11. Request size split &gt; 1000 stETH-equivalent.  
12. Reentrancy: claim / rebalance / exchange.  
13. Fork tests against Ethereum mainnet Lido + WithdrawalQueue (no mock SUT).

**Do not mock:** Lido stETH, wstETH, WithdrawalQueue, IndexedexManager, fee oracle, SE diamond under test.

---

## 11. Risks

1. Buffer drain / temporary WETH Out unavailability.  
2. Yield drag from liquid sleeve.  
3. Queue delay / bunker mode.  
4. Discounted finalization vs face value (NAV).  
5. Share-price manipulation via donations (standard vault inflation defenses).  
6. Operator mis-set liquid % (too high → yield drag; too low → WETH Out failures).  
7. Gas / DoS on unbounded request sets — cap enumerations.

---

## 12. Implementation phases

| Phase | Deliverable |
|------:|-------------|
| **0** | This PRD accepted; implementation + test plan written |
| **1** | Fee Oracle liquid-reserve API + tests (no Lido dependency) |
| **2** | Crane interface/service expansions (queue + stake limit) |
| **3** | Lido SE DFPkg + In/Out closed-form routes + TestBase |
| **4** | Rebalance facet + NAV with in-flight + fork tests |
| **5** | Docs, rate provider wiring notes, DETF composition smoke (opaque SE) |

---

## 13. Open questions (resolve in implementation plan)

1. Exact NAV formula for pending requests (face vs live share rate).  
2. Whether mint with WETH auto-stakes excess in the same tx.  
3. Hysteresis band parameters.  
4. Explicit-zero liquid % support (set flag vs forbid).  
5. Dedicated `VaultFeeType` partition vs usage type id for type-level policy.  
6. Package path under `protocols/staking/lido` vs `protocols/staking/ethereum/lido`.

---

## 14. Acceptance criteria

- [ ] `liquidReservePercentageOfVault` resolves vault → type → global in WAD.  
- [ ] Manager can set default / type / vault liquid reserve percentages with events.  
- [ ] Lido SE deploys via IndexedEx registry path only.  
- [ ] Closed-form WETH Out works when liquid sleeve funded; reverts cleanly when not.  
- [ ] Rebalance can stake excess and enqueue Lido withdrawals; claim wraps to WETH.  
- [ ] No single-tx primary Lido ETH Out masquerading as closed-form SE Out.  
- [ ] Production-first tests green on hermetic where possible + mainnet fork for Lido.  
- [ ] DETF/router consumers only need `IStandardExchange*` opacity.

---

## 15. Changelog

| Date | Change |
|------|--------|
| 2026-07-23 | Initial PRD: Lido wstETH SE + liquid sleeve + Fee Oracle locked-reserve percentage API |
| 2026-07-23 | Reoriented oracle knob to **`liquidReservePercentage`** (easier rebalance math / UX); default `0.05e18`; locked is derived |

---

*Normative for Lido SE v1. Implementation plan should not reopen deposit/withdraw Lido constraints or Fee Oracle three-tier cascade without explicit PRD revision.*
