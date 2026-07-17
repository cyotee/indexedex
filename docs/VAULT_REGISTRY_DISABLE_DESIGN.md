# Vault Registry — Owner Kill-Switch / Disable Design

**Status:** Implemented (2026-07-17, vault + package only). Emergency withdraw still deferred.  
**Related:** `docs/LAUNCH_PLAN.md` (security / kill-switch decision), fee-oracle tier pattern, `VaultRegistryVaultRepo`  
**Goal:** Owner can disable vaults by **address** or **deploy package**. Vaults make **one registry call** to learn effective disabled state (and thus whether emergency withdraw is allowed).

---

## 1. Fee-oracle pattern we are mirroring

`VaultFeeOracleQueryFacet.usageFeeOfVault(address vault)` resolves tiers so callers only pass the vault address. Disable uses the same **single-call** idea for vaults:

| | Fee oracle | Kill-switch |
|--|------------|-------------|
| Admin axes | vault, type, global | **vault address**, **package** only |
| Query for vaults | one `*OfVault(address)` | one `isDisabled(address)` |
| Combine rule | fallback (first non-zero) | **OR** (vault disabled **or** its package disabled) |
| Default | `0` = fall through | **not in disable set = active** (no write for active vaults) |

**Active by default:** Crane `AddressSet` membership is false until `_add`. Re-enable is `_remove`. We never write “active” storage for every vault.

---

## 2. Disable axes (v1 — no vault type IDs)

| Axis | Key | Effect |
|------|-----|--------|
| **Vault** | `address vault` | That instance only |
| **Package** | `address pkg` | All proxies registered under that DFPkg |

A vault is **effectively disabled** if:

1. it is a member of the **disabled vaults** set, **or**  
2. its **package** (one-to-one registration mapping) is a member of the **disabled packages** set.

Otherwise it is **active**.

### 2.1 Why not vault type ID?

**Out of scope for v1 (and intentionally rejected).**

- Vaults carry **many** type IDs (`VaultConfig.vaultTypes`). Checking “is any of my types disabled?” requires either:
  - iterating **that vault’s** type list against a disabled-types set, or  
  - iterating **all disabled type IDs** and testing membership in `vaultsOfType[typeId]`.  
- Both are heavier and messier than the package path for a hot `isDisabled` call.
- **Package disable is sufficient** to freeze every proxy from a DFPkg (where a bug is likely to live).
- If a bad **Facet** is shared by several packages, the owner disables **each of those packages** — same operational end without type-ID state on the hot path.

### 2.2 Why package works well

- Registration is **one package per vault** (passed into `_registerVault(vault, pkg, …)`).  
- With a reverse **`pkgOfVault[vault]`** (or equivalent), resolution is:
  1. read `pkg = pkgOfVault[vault]`  
  2. `disabledPackages._contains(pkg)`  
- Constant-time package tier; no iteration.  
- Correlates to deploy unit / DFPkg surface area — natural blast radius for emergency response.

### 2.3 Emergency withdraw (product rule)

| Effective state | Normal ops (deposit / swap / bond / …) | Emergency withdraw |
|-----------------|----------------------------------------|--------------------|
| **Active** (`isDisabled == false`) | Allowed (subject to other guards) | **Reverts** (not available) |
| **Disabled** (`isDisabled == true`) | **Reverts** | **Allowed** (subject to own share/asset accounting) |

Registry does **not** implement emergency withdraw. It only answers `isDisabled`. Vaults/DETFs enforce the table above.

### 2.4 Optional: vault force-enable (deferred)

Not in v1. Later: re-enable a single vault while its package stays disabled. v1 is pure OR of vault-set and package-set membership.

---

## 3. What registration already stores (`VaultRegistryVaultRepo`)

On `_registerVault(vault, pkg, vaultConfig)` today:

| Storage | Written? | Notes |
|---------|----------|--------|
| `vaults` | Yes | Global vault AddressSet |
| `vaultsOfPkg[pkg]` | **Yes** | Package → vaults (pkg passed from `deployVault` / register) |
| `vaultsOfType[typeId]` | Yes | For indexing / queries — **not used by kill-switch** |
| Fee type IDs, tokens, contents | Yes | Unrelated to kill-switch |
| **`pkgOfVault[vault]`** | **No** | Reverse package pointer **missing** |

Deploy path already passes package:

```solidity
// VaultRegistryDeploymentTarget.deployVault
VaultRegistryVaultRepo._registerVault(vault, address(pkg), IStandardVault(vault).vaultConfig());
```

**Gap for O(1) package disable:** store `pkgOfVault[vault] = pkg` on register; `delete` / clear on remove. Package is already known at that point — no new external inputs.

`vaultsOfPkg` remains useful for ops enumeration (“which vaults did this package deploy?”) but **`isDisabled` does not iterate it**.

---

## 3.1 Disable storage (new)

```solidity
// VaultRegistryDisableRepo
struct Storage {
    AddressSet disabledVaults;    // instance denylist
    AddressSet disabledPackages;  // package denylist
}
```

| Writer | Operation |
|--------|-----------|
| Disable vault | `disabledVaults._add(vault)` |
| Re-enable vault | `disabledVaults._remove(vault)` |
| Disable package | `disabledPackages._add(pkg)` |
| Re-enable package | `disabledPackages._remove(pkg)` |

**No per-vault fan-out** when disabling a package. Query-time OR uses `pkgOfVault` + set membership.

---

## 3.2 Registration storage add-on (required)

In `VaultRegistryVaultRepo.Storage`:

```solidity
mapping(address vault => address pkg) pkgOfVault;
```

| Hook | Action |
|------|--------|
| `_registerVault` | `layoutStruct.pkgOfVault[vault] = pkg` |
| `_removeVault` | `delete layoutStruct.pkgOfVault[vault]` |

Expose via query as `packageOfVault(address vault)` (and/or reuse for disable detailed path).

**No vault-type list storage** for kill-switch.

---

## 3.3 Resolution (normative)

```text
function isDisabled(vault):
    if disabledVaults._contains(vault):
        return true
    pkg = pkgOfVault[vault]          // one SLOAD (after register add-on)
    if pkg != address(0) && disabledPackages._contains(pkg):
        return true
    return false                     // active
```

Two membership checks, no loops.

---

## 4. Proposed interfaces

Split like existing registry / fee-oracle: **Manager** (write) + **Query** (read).

### 4.1 `IVaultRegistryDisableQuery`

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title IVaultRegistryDisableQuery
 * @notice Read-side kill-switch for vaults and DETFs.
 * @notice Effective disable is OR of vault-address set and the vault's package set.
 * @notice Vaults should call only `isDisabled(address(this))`.
 * @dev Single-call resolution (fee-oracle style). No vault-type-ID axis.
 */
interface IVaultRegistryDisableQuery {
    /* ---------------------------------------------------------------------- */
    /*                         Single-call (vault use)                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Whether `vault` is effectively disabled.
     * @dev True if vault ∈ disabledVaults
     *      OR packageOfVault(vault) ∈ disabledPackages (when pkg != address(0)).
     * @custom:selector TBD
     */
    function isDisabled(address vault) external view returns (bool disabled);

    /**
     * @notice Effective disable plus which axes contributed (UI / operators).
     * @custom:selector TBD
     */
    function isDisabledDetailed(address vault)
        external
        view
        returns (bool disabled, bool byVault, bool byPackage);

    /* ---------------------------------------------------------------------- */
    /*                         Raw / admin reads                              */
    /* ---------------------------------------------------------------------- */

    /// @notice `disabledVaults._contains(vault)` only.
    function isVaultAddressDisabled(address vault) external view returns (bool);

    /// @notice `disabledPackages._contains(pkg)` only.
    function isPackageDisabled(address pkg) external view returns (bool);

    /// @notice Package recorded at registration (`address(0)` if unregistered / unknown).
    function packageOfVault(address vault) external view returns (address pkg);

    /// @notice Enumerate disable sets (off-chain / admin; not for hot vault paths).
    function disabledVaults() external view returns (address[] memory);

    function disabledPackages() external view returns (address[] memory);
}
```

### 4.2 `IVaultRegistryDisableManager`

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title IVaultRegistryDisableManager
 * @notice Owner-controlled kill-switch writers.
 * @notice Access: onlyOwner (not operator).
 * @notice Axes: vault address and package only — no vault type IDs.
 */
interface IVaultRegistryDisableManager {
    event VaultAddressDisabled(address indexed vault, bool disabled);
    event PackageDisabled(address indexed package, bool disabled);

    /**
     * @notice Disable or re-enable a single vault instance.
     * @param disabled True → `_add` to disabledVaults; false → `_remove` (active by absence).
     *        Package disable may still keep the vault effectively disabled.
     */
    function setVaultAddressDisabled(address vault, bool disabled) external returns (bool success);

    /**
     * @notice Disable or re-enable all vaults registered under package `pkg`
     *         (via pkgOfVault → disabledPackages membership at query time).
     */
    function setPackageDisabled(address pkg, bool disabled) external returns (bool success);
}
```

### 4.3 Optional batch helpers (v1.1)

```solidity
function setVaultAddressDisabledBatch(address[] calldata vaults, bool disabled) external returns (bool);
function setPackageDisabledBatch(address[] calldata pkgs, bool disabled) external returns (bool);
```

Not required for v1.

---

## 5. Unregistered vaults

- `pkgOfVault[vault] == address(0)` ⇒ package tier cannot match.  
- Only an explicit `disabledVaults` entry can disable an unregistered address (preemptive denylist).  
- Production vaults register before use; ops may still `require(isVault(vault))` where appropriate.

---

## 6. Vault integration (call pattern)

```solidity
IVaultRegistryDisableQuery reg = IVaultRegistryDisableQuery(address(vaultRegistry));

function _requireActive() internal view {
    if (reg.isDisabled(address(this))) revert VaultDisabled(address(this));
}

function emergencyWithdraw(...) external {
    if (!reg.isDisabled(address(this))) revert EmergencyWithdrawNotAvailable();
    // family-specific exit ...
}
```

Apply `_requireActive` to mutating paths (deposit / redeem normal path / swap / bond / etc.).  
Prefer **allowing pure previews** while disabled (indexers); execution must not.

---

## 7. Access control

| Action | Who |
|--------|-----|
| `setVaultAddressDisabled` / `setPackageDisabled` | **`onlyOwner`** |
| Query functions | Anyone (view) |

---

## 8. Events & ops notes

- Emit only **on change** when possible (noise reduction).  
- Indexers: `VaultAddressDisabled`, `PackageDisabled`; effective state via `isDisabled` or `packageOfVault` + sets.  
- Shared facet bug across packages: disable **each affected package** (and/or specific vaults).  
- Package disable does **not** loop vaults on-chain; all proxies with that `pkgOfVault` fail `isDisabled` at call time.

---

## 9. Facet / diamond layout

| Piece | Role |
|-------|------|
| `VaultRegistryDisableRepo` | `disabledVaults`, `disabledPackages` AddressSets |
| `VaultRegistryVaultRepo` | Add `pkgOfVault` write/clear on register/remove |
| `VaultRegistryDisableManagerFacet` / `Target` | Writers + `IFacet` |
| `VaultRegistryDisableQueryFacet` / `Target` | `isDisabled` + raw reads |
| Diamond cut | Same manager / registry diamond as existing vault registry |

---

## 10. Open points (not interface blockers)

1. **Emergency withdraw mechanics** per vault family (product-specific).  
2. **Preview while disabled** — allow vs revert (recommend allow views).  
3. **`deployVault` under disabled package** — should `require(!isPackageDisabled(pkg))`.  
4. **Force-enable one vault under a disabled package** (v2).  
5. **Historical vaults** registered before `pkgOfVault` — migration/re-register or one-time backfill if any mainnet instances exist before the mapping ships.

---

## 11. Implementation plan (high level)

1. **Interfaces** — `IVaultRegistryDisableQuery`, `IVaultRegistryDisableManager` (vault + package only).  
2. **`pkgOfVault`** — extend `VaultRegistryVaultRepo` register/remove; unit tests.  
3. **`VaultRegistryDisableRepo`** — two AddressSets.  
4. **Facets** — Manager + Query; resolution = vault set OR package set via `pkgOfVault`.  
5. **Diamond cut** — manager / registry package.  
6. **Deploy gate** — reject `deployVault` if package disabled.  
7. **Vault guards** + emergency withdraw when `isDisabled`.  
8. **Tests** — default active; address disable; package disable freezes all vaults of that pkg without writing each vault into `disabledVaults`; re-enable vault address still blocked if package disabled; deploy under disabled package fails.  
9. **Docs** — LAUNCH_PLAN / AGENTS.

---

## 12. Summary for implementers

- **Axes:** vault address + package **only** — **no vault type ID** disable.  
- **Default active:** not in disable sets; no storage write to mark active.  
- **Hot path:** `isDisabled(vault)` = `disabledVaults.contains(vault) || disabledPackages.contains(pkgOfVault[vault])`.  
- **Registration:** already receives `pkg`; **add `pkgOfVault`** for one-to-one reverse lookup.  
- **Multi-package facet bug:** disable each affected package.  
- **Semantics:** disabled ⇒ no normal mutations; emergency withdraw allowed on vault side.

**Implementation + testing plan:** [`docs/superpowers/plans/2026-07-17-vault-registry-disable.md`](superpowers/plans/2026-07-17-vault-registry-disable.md)  
(Emergency withdraw is explicitly deferred until disable/re-enable is proven.)
