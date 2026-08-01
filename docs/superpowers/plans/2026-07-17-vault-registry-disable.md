# Plan: Vault Registry Kill-Switch (Disable by Address + Package)

**Status:** IMPLEMENTED (tests green 2026-07-17)  
**Date:** 2026-07-17  
**Design:** [`docs/VAULT_REGISTRY_DISABLE_DESIGN.md`](../../VAULT_REGISTRY_DISABLE_DESIGN.md)  
**Related:** [`docs/LAUNCH_PLAN.md`](../../LAUNCH_PLAN.md) (security / kill-switch)

## Why

Owner needs a circuit breaker to freeze vault/DETF instances by **address** or by **DFPkg**, without per-vault fan-out storage and without vault-type-ID iteration. Vaults and DETFs must **refuse mutating operations** when effectively disabled. Re-enable must restore normal ops.

## Explicitly out of scope (this plan)

| Item | Notes |
|------|--------|
| **Emergency withdraw** | Design + implement **after** disable/re-enable is proven. Do **not** add emergency-exit paths on vaults/DETFs here. |
| Vault type ID disable | Rejected in design — too much hot-path state. |
| Force-enable one vault under a disabled package | Deferred (v2). |
| Donation / fee-make | Separate LAUNCH_PLAN workstream. |

While disabled, vaults/DETFs simply **revert** on protected mutations. Users cannot withdraw via a special path yet.

---

## Goals

1. Registry: owner can disable/re-enable by **vault address** and by **package address**.  
2. `isDisabled(vault)` is a **single call** (fee-oracle style):  
   `disabledVaults ∋ vault` **OR** `disabledPackages ∋ pkgOfVault[vault]`.  
3. Active by default (not in either set ⇒ no storage write).  
4. Wire facets into Indexedex manager diamond.  
5. Vaults/DETFs check disable on mutating paths and **revert** when disabled.  
6. Tests: registry unit + vault/DETF integration for **address** and **package** disable/re-enable.

---

## Decisions (locked)

| Decision | Choice |
|----------|--------|
| Axes | Vault address + package only |
| Storage | Two `AddressSet`s: `disabledVaults`, `disabledPackages` |
| Package reverse map | Add `pkgOfVault[vault]` in `VaultRegistryVaultRepo` on register/remove |
| Access | `onlyOwner` for writers |
| Vault resolution source | Same diamond as fee oracle (`StandardVaultRepo._feeOracle()` → cast to disable query) — manager hosts both registry + fee oracle |
| Mutating ops when disabled | Revert (custom error, e.g. `VaultDisabled(address)`) |
| Views / previews when disabled | **Allowed** (no disable check on pure views) |
| Emergency withdraw | **Not implemented** |
| Deploy under disabled package | `deployVault` reverts if package disabled |

---

## Architecture sketch

```text
Owner
  │ setVaultAddressDisabled / setPackageDisabled
  ▼
IndexedexManager diamond
  ├─ VaultRegistryDisableManagerFacet
  ├─ VaultRegistryDisableQueryFacet  ← isDisabled(vault)
  ├─ VaultRegistryVaultRepo (+ pkgOfVault)
  └─ existing vault registry / fee oracle facets

Vault / DETF (mutating entrypoint)
  │ _requireNotDisabled()
  │   IVaultRegistryDisableQuery(feeOracle).isDisabled(address(this))
  ▼
  revert VaultDisabled if true; else continue
```

---

## Phase 0 — Interfaces

### Files to add

| File | Contents |
|------|----------|
| `contracts/interfaces/IVaultRegistryDisableQuery.sol` | `isDisabled`, `isDisabledDetailed`, raw contains, `packageOfVault`, enumerate sets |
| `contracts/interfaces/IVaultRegistryDisableManager.sol` | `setVaultAddressDisabled`, `setPackageDisabled`, events |

Match design doc §4 exactly (no type-ID functions).

### Proxy aggregate

Update `contracts/interfaces/proxies/IVaultRegistryProxy.sol` (and `IIndexedexManagerProxy` if it mirrors registry surface) to inherit the new interfaces so the manager proxy type-checks.

---

## Phase 1 — Registry storage + repo

### 1.1 `pkgOfVault` on registration

**File:** `contracts/registries/vault/VaultRegistryVaultRepo.sol`

- Add to `Storage`: `mapping(address vault => address pkg) pkgOfVault;`  
- `_registerVault`: `layoutStruct.pkgOfVault[vault] = pkg;`  
- `_removeVault`: `delete layoutStruct.pkgOfVault[vault];`  
- Internal getters: `_packageOfVault(vault)`  

**Tests:** extend `test/foundry/spec/registries/vault/VaultRegistry_Registration.t.sol`  
- After register: `packageOfVault(vault1) == pkg1`  
- After unregister: `packageOfVault(vault1) == address(0)`  

### 1.2 Disable repo

**File:** `contracts/registries/vault/VaultRegistryDisableRepo.sol` (new)

```solidity
struct Storage {
    AddressSet disabledVaults;
    AddressSet disabledPackages;
}
// _add/_remove/_contains/_values helpers for both sets
// _isDisabled(vault): vault set OR (pkgOfVault(vault) != 0 && package set)
```

Use Crane `AddressSetRepo`. Prefer **emit only on change** in the Target (compare before `_add`/`_remove`).

---

## Phase 2 — Facets + diamond cut

### 2.1 Facets (Crane Facet-Target-Repo pattern)

| File | Role |
|------|------|
| `VaultRegistryDisableManagerTarget.sol` | `onlyOwner` writers |
| `VaultRegistryDisableManagerFacet.sol` | `IFacet` + selector list |
| `VaultRegistryDisableQueryTarget.sol` | Views + `isDisabled` resolution |
| `VaultRegistryDisableQueryFacet.sol` | `IFacet` + selector list |

Manager Target:

- `setVaultAddressDisabled(vault, disabled)` → add/remove `disabledVaults`  
- `setPackageDisabled(pkg, disabled)` → add/remove `disabledPackages`  
- Events: `VaultAddressDisabled`, `PackageDisabled`

Query Target:

- `isDisabled(vault)` using `VaultRegistryDisableRepo` + `VaultRegistryVaultRepo._packageOfVault`  
- `isDisabledDetailed`, raw contains, enumerators, `packageOfVault`

### 2.2 Factory + DFPkg wiring

| File | Change |
|------|--------|
| `contracts/manager/IndexedexManagerFactoryService.sol` | `deployVaultRegistryDisable*Facet` helpers |
| `contracts/manager/IndexedexManagerDFPkg.sol` | Immutable facet refs; diamond cut entries; `facetInterfaces` include new interface IDs |
| Any test/init that deploys manager facets | Deploy new facets via CREATE3 (never `new`) |

### 2.3 Deploy gate

**File:** `contracts/registries/vault/VaultRegistryDeploymentTarget.sol`

In `deployVault`, after package registered check:

```solidity
if (VaultRegistryDisableRepo._isPackageDisabled(address(pkg))) {
    revert PackageDisabled(address(pkg)); // or shared error
}
```

Do **not** block `deployPkg` unless product later requires it (disabling a package freezes instances; new package deploys remain owner/operator controlled).

---

## Phase 3 — Vault / DETF enforcement (no emergency withdraw)

### 3.1 Shared check pattern

Vaults already store `feeOracle` (`IVaultFeeOracleQuery`) pointing at the Indexedex manager diamond (same address as registry). Prefer:

```solidity
function _requireNotDisabled() internal view {
    address reg = address(StandardVaultRepo._feeOracle()); // or DETF-equivalent oracle/manager ref
    if (IVaultRegistryDisableQuery(reg).isDisabled(address(this))) {
        revert VaultDisabled(address(this));
    }
}
```

Define `VaultDisabled(address vault)` once (e.g. on `IVaultRegistryDisableQuery` or a small shared errors interface) so tests can `vm.expectRevert` consistently.

**If a family does not have feeOracle on manager:** use `VaultRegistryAwareRepo` or the same manager address already used for fee oracle at init — do not invent a second admin path without need.

### 3.2 Where to call `_requireNotDisabled`

Call on **mutating** entrypoints only. Do **not** gate pure preview/query functions.

| Family | Integration point (representative) | Guard locations |
|--------|-------------------------------------|-----------------|
| DualLiquidityLinked | `DualLiquidityLinkedCrossVersionUniswapVaultCommon` | Start of `_requireActive` **or** first line of `exchangeIn` / `exchangeOut` targets (all non-view routes) |
| SingleStandardExchange DETF | `SingleStandardExchangeDETFCommon` | Same: `_requireActive` or exchange/bond mutation targets |
| MultiVaultWeighted DETF | `MultiVaultWeightedDetfCommon` | Mutating exchange/deposit/redeem paths |
| Standard SE vaults (V2/V4/Aerodrome/etc.) | Shared Common / ExchangeIn-Out targets if present | Primary deposit/redeem/swap mutations |
| Other DETFs (ComposedStable, Seigniorage, …) | Their Common / Target mutators | Same rule |

**Bootstrap deposits:** still subject to disable — if the vault/package is disabled, bootstrap must also revert (no special carve-out).

**Minimum viable surface for this plan (must ship):**

1. DualLiquidityLinked (vault product home)  
2. At least one Standard Exchange vault path used in fork tests (e.g. Uni V4 or V2 SE)  
3. SingleStandardExchange DETF **or** MultiVaultWeighted DETF  

**Stretch (same PR if cheap):** remaining DETF/SE families that share a Common helper — add guard in the shared Common once so all routes inherit.

### 3.3 Explicit non-goals for vaults

- No `emergencyWithdraw`  
- No alternate exit when disabled  
- No pause of views  

Disabled = stuck for users until owner re-enables (or package re-enabled). Acceptable for this milestone.

---

## Phase 4 — Testing plan

### 4.1 Registry unit tests (new + extend)

**New file (recommended):**  
`test/foundry/spec/registries/vault/VaultRegistry_Disable.t.sol`  
Base: `IndexedexTest` (same as `VaultRegistry_Registration.t.sol`).

| Test | Behavior |
|------|----------|
| `test_isDisabled_defaultActive` | Unregistered/registered vault not in sets → `isDisabled == false` |
| `test_packageOfVault_setOnRegister` | After `registerVault`, `packageOfVault == pkg` |
| `test_packageOfVault_clearedOnUnregister` | After unregister → `address(0)` |
| `test_setVaultAddressDisabled_onlyOwner` | Non-owner reverts |
| `test_setPackageDisabled_onlyOwner` | Non-owner reverts |
| `test_disableVaultAddress_isDisabled` | Disable vault1 → true; vault2 same pkg still false (unless package disabled) |
| `test_reenableVaultAddress_isActive` | Disable then enable → false |
| `test_disablePackage_disablesAllVaultsOfPkg` | vault1 + vault2 same pkg; disable pkg → both true; different pkg vault3 false |
| `test_reenablePackage_restoresActive` | Package re-enable → vaults active (if not address-disabled) |
| `test_vaultAddressAndPackage_OR` | Address re-enabled but package still disabled → still disabled |
| `test_packageDisabled_addressStillIndependent` | Package active, vault address disabled → that vault only |
| `test_events_onChange` | Expect `VaultAddressDisabled` / `PackageDisabled` when state flips |
| `test_deployVault_revertsWhenPackageDisabled` | Disable pkg → `deployVault` reverts; re-enable → deploy works |
| `test_isDisabledDetailed` | Flags `byVault` / `byPackage` correctly |

Use synthetic `registerVault` where possible; use real `deployPkg`/`deployVault` for deploy-gate test if harness already supports it.

### 4.2 Vault / DETF behavior tests (disable + re-enable)

**Principle:** for each in-scope product, prove:

1. **Disable by vault address** → mutation reverts with `VaultDisabled`  
2. **Re-enable by vault address** → mutation succeeds again  
3. **Disable by package address** → mutation reverts for a vault of that package  
4. **Re-enable package** → mutation succeeds again  

Do **not** assert emergency withdraw (does not exist yet).

#### DualLiquidityLinked

**Location:**  
`test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/`  
Add e.g. `DualLiquidityLinkedCrossVersionUniswapVault_Disable.t.sol` on existing production/fork TestBase.

| Test | Steps |
|------|--------|
| `test_disableByVaultAddress_blocksExchangeIn` | Bootstrap if needed; owner disable vault address; `exchangeIn` expects revert; previews may still succeed |
| `test_reenableVaultAddress_allowsExchangeIn` | Disable → re-enable → exchangeIn succeeds |
| `test_disableByPackage_blocksExchangeIn` | Resolve package via `packageOfVault(vault)` or known DFPkg address; disable package; exchangeIn reverts |
| `test_reenablePackage_allowsExchangeIn` | Re-enable package → exchangeIn succeeds |
| `test_disableByPackage_blocksExchangeOut` | Same for redeem path after a successful deposit (while active) |

Owner prank: MultiStepOwnable owner of `indexedexManager`.

#### Standard Exchange vault (pick one fork suite with live deploy)

E.g. Uni V4 SE or existing SE TestBase under `test/foundry/fork/...`:

| Test | Steps |
|------|--------|
| Address disable / re-enable | Block + restore primary deposit or swap |
| Package disable / re-enable | Same via package of vault |

#### DETF (SingleStandardExchange and/or MultiVaultWeighted)

| Test | Steps |
|------|--------|
| Address disable blocks DETF mutation | e.g. deposit / exchangeIn / bond entry as applicable |
| Package disable blocks DETF mutation | Disable DETF’s DFPkg |
| Re-enable restores | Address and package cases |

**If DETF and leg vaults are separate packages:** disabling the **DETF package** must block DETF; leg vaults remain active unless their packages are disabled too. Add one test documenting that blast radius (expected product behavior).

### 4.3 Regression

- Existing registry registration/query tests still pass (pkgOfVault additive).  
- Existing DualLiquidity / DETF suites still pass when nothing is disabled (default active).  
- No new emergency-withdraw tests.

### 4.4 Suggested forge commands

```bash
# Registry disable unit
forge test --match-contract VaultRegistry_Disable -vv

# DualLiquidity disable
forge test --match-contract DualLiquidityLinkedCrossVersionUniswapVault_Disable -vv

# Broader registry + disable
forge test --match-path 'test/foundry/spec/registries/vault/*' -vv

# Full DualLiquidity fork suite (regression)
forge test --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/*' -vv
```

(Adjust paths/names if TestBase requires fork flags already used by the suite.)

---

## Phase 5 — Docs

| Doc | Update |
|-----|--------|
| `docs/VAULT_REGISTRY_DISABLE_DESIGN.md` | Mark implementation status when done; note emergency withdraw still deferred |
| `docs/LAUNCH_PLAN.md` | Kill-switch Phase 0 item: registry disable + vault guards done; emergency withdraw still open |
| `AGENTS.md` (if operators run disables) | One short note: owner disable via manager; vaults revert when disabled |

---

## File checklist (implementation)

### New

- [ ] `contracts/interfaces/IVaultRegistryDisableQuery.sol`  
- [ ] `contracts/interfaces/IVaultRegistryDisableManager.sol`  
- [ ] `contracts/registries/vault/VaultRegistryDisableRepo.sol`  
- [ ] `contracts/registries/vault/VaultRegistryDisableManagerTarget.sol`  
- [ ] `contracts/registries/vault/VaultRegistryDisableManagerFacet.sol`  
- [ ] `contracts/registries/vault/VaultRegistryDisableQueryTarget.sol`  
- [ ] `contracts/registries/vault/VaultRegistryDisableQueryFacet.sol`  
- [ ] `test/foundry/spec/registries/vault/VaultRegistry_Disable.t.sol`  
- [ ] `test/foundry/.../DualLiquidityLinkedCrossVersionUniswapVault_Disable.t.sol`  
- [ ] DETF disable test file(s)  
- [ ] SE vault disable test file (or section)

### Modify

- [ ] `VaultRegistryVaultRepo.sol` — `pkgOfVault`  
- [ ] `VaultRegistryDeploymentTarget.sol` — deploy gate  
- [ ] `IVaultRegistryProxy.sol` (+ manager proxy if needed)  
- [ ] `IndexedexManagerFactoryService.sol`  
- [ ] `IndexedexManagerDFPkg.sol`  
- [ ] DualLiquidity / DETF / SE Common or Targets — `_requireNotDisabled`  
- [ ] `VaultRegistry_Registration.t.sol` — packageOfVault assertions  

---

## Implementation order (PR-friendly)

```text
PR / step 1  Interfaces + DisableRepo + pkgOfVault + Manager/Query facets
             + diamond cut + registry unit tests (no vault behavior yet)

PR / step 2  deployVault package-disabled gate + test

PR / step 3  DualLiquidityLinked _requireNotDisabled + Disable.t.sol
             (address + package disable/re-enable)

PR / step 4  DETF + SE vault guards + tests

PR / step 5  Docs / LAUNCH_PLAN tick boxes
```

Steps 1–2 can merge as one PR if small. Do **not** ship vault guards without registry tests green.

---

## Acceptance criteria

- [ ] Owner can disable/re-enable by vault address and by package.  
- [ ] Non-owner cannot.  
- [ ] `isDisabled` defaults false; no storage for active vaults.  
- [ ] `packageOfVault` set on register, cleared on unregister.  
- [ ] Package disable freezes all registered vaults of that package without writing each into `disabledVaults`.  
- [ ] DualLiquidity + at least one DETF + at least one SE vault: mutations revert when address- or package-disabled; succeed after re-enable.  
- [ ] Views/previews still callable while disabled.  
- [ ] `deployVault` blocked when package disabled.  
- [ ] **No** emergency withdraw code or tests.  
- [ ] Existing green suites remain green with default (nothing disabled).

---

## Follow-on (separate plan, after this)

1. Emergency withdraw design when `isDisabled` (share/BPT/residual paths per family).  
2. Optional force-enable vault under disabled package.  
3. Operator runbooks / BattleChain drills using package disable.

---

## Summary

Implement registry kill-switch (**vault + package** AddressSets + **`pkgOfVault`**), wire manager facets, gate deploy, and make vaults/DETFs **`_requireNotDisabled`** on mutations with tests for **disable and re-enable by address and by package**. Defer emergency withdrawal until disable/re-enable is solid.
