# Policy call flows

## Contents

- [Minter (OHM)](#minter-ohm)
- [RolesAdmin](#rolesadmin)
- [Treasury / Emergency](#treasury--emergency)
- [Integrating as a custom policy](#integrating-as-a-custom-policy)

All paths relative to `contracts/protocols/tokens/stable/olympus/v3/`.

## Minter (OHM)

**Contract:** `policies/Minter.sol`  
**Modules:** MINTR, ROLES  
**Role:** `"minter_admin"`

### Setup (executor + admin)

```text
1. Install MINTR, ROLES modules
2. Activate RolesAdmin, Minter policies
3. RolesAdmin.grantRole("minter_admin", opsSafe)
4. Minter.addCategory(bytes32("PRODUCT_X"))  // as minter_admin
```

### Mint

```solidity
// msg.sender must have minter_admin role
Minter(minterPolicy).mint(recipient, amount, bytes32("PRODUCT_X"));
// emits Minter.Mint(to, category, amount)
// internally: increaseMintApproval(this, amount) + mintOhm(to, amount)
```

### Failure modes

| Symptom | Cause |
|---------|--------|
| `ROLES_RequireRole` | Caller lacks `minter_admin` |
| `Minter_CategoryNotApproved` | Forgot `addCategory` |
| `MINTR_NotActive` / `MINTR_NotApproved` | Module deactivated or approval accounting broken |
| `Module_PolicyNotPermitted` | Minter policy not activated or missing selectors |

## RolesAdmin

**Contract:** `policies/RolesAdmin.sol`  
**Modules:** ROLES  
**Gate:** `admin` address (not a ROLES role)

```solidity
RolesAdmin(rolesAdmin).grantRole(bytes32("minter_admin"), wallet);
RolesAdmin(rolesAdmin).revokeRole(bytes32("minter_admin"), wallet);

// two-step admin transfer
RolesAdmin(rolesAdmin).pushNewAdmin(newAdmin);
// newAdmin:
RolesAdmin(rolesAdmin).pullRolesAdmin();
```

Permissions requested on activate: `ROLES.saveRole`, `ROLES.removeRole`.

## Treasury / Emergency

### TreasuryCustodian

**Contract:** `policies/TreasuryCustodian.sol`  
Used for curated treasury movements through TRSRY withdraw approvals. Inspect current ABI for exact role names and token params before scripting.

### Emergency

**Contract:** `policies/Emergency.sol`  
Shutdown-oriented withdraw paths when TRSRY/MINTR are toggled inactive. Treat as privileged ops — confirm role gates and active policy status on-chain.

### Pattern shared by treasury policies

```text
policy.fn() 
  → TRSRY.increaseWithdrawApproval(policy, token, amount)  // permissioned
  → TRSRY.withdrawReserves / similar                     // permissioned
  → token leaves treasury to target
```

EOAs never call TRSRY withdraw directly.

## Integrating as a custom policy

For a **strategy contract** that needs mint or treasury access:

1. Implement `Policy` with `configureDependencies` + `requestPermissions`.
2. Deploy with Kernel address.
3. Executor `ActivatePolicy`.
4. Grant any ROLES your policy checks.
5. Users/ops call **your** policy functions only.

Do **not** attempt to `vm.prank` a random EOA into module functions in production design — permissions are policy-address-based (`msg.sender`).
