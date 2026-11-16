# Kernel and Policies (detail)

## Contents

- [Permission model](#permission-model)
- [Policy lifecycle](#policy-lifecycle)
- [Writing a Policy](#writing-a-policy)
- [Writing a Module](#writing-a-module)
- [Common errors](#common-errors)

## Permission model

```text
User/EOA ──► Policy.publicFn() ──permissioned──► Module.stateFn()
                 ▲
                 │ activate grants
              Kernel.modulePermissions[keycode][policy][selector]
```

1. Policy lists needed module selectors in `requestPermissions()`.
2. On `ActivatePolicy`, Kernel records those grants and calls `configureDependencies()`.
3. Module functions marked `permissioned` check:
   - `msg.sender == kernel`, **or**
   - `kernel.modulePermissions(KEYCODE(), Policy(msg.sender), msg.sig)`.

Roles (`ROLES.requireRole` / `onlyRole`) are a **second** gate used by many policies for *who may call the policy*, not for Kernel↔module access.

## Policy lifecycle

Typical bootstrap (executor = deployer or DAO):

1. `new Kernel()` → deployer is `executor`.
2. `executeAction(InstallModule, mintr)` … for each module (each `INIT()` runs).
3. `executeAction(ActivatePolicy, rolesAdmin)` …
4. Optionally `executeAction(ChangeExecutor, multisig)`.

Upgrade path: `UpgradeModule` swaps the module for a keycode and re-runs dependent policies’ `configureDependencies()`.

Deactivate: `DeactivatePolicy` clears permissions so the policy can no longer touch modules.

## Writing a Policy

```solidity
contract MyPolicy is Policy, RolesConsumer {
    MINTRv1 public MINTR;
    // ROLES from RolesConsumer

    constructor(Kernel k) Policy(k) {}

    function configureDependencies() external override returns (Keycode[] memory deps) {
        deps = new Keycode[](2);
        deps[0] = toKeycode("MINTR");
        deps[1] = toKeycode("ROLES");
        MINTR = MINTRv1(getModuleAddress(deps[0]));
        ROLES = ROLESv1(getModuleAddress(deps[1]));
        // assert VERSION majors match expected
    }

    function requestPermissions() external view override returns (Permissions[] memory req) {
        Keycode k = toKeycode("MINTR");
        req = new Permissions[](1);
        req[0] = Permissions(k, MINTR.mintOhm.selector);
    }

    function doThing(uint256 amt) external onlyRole("my_role") {
        MINTR.mintOhm(msg.sender, amt); // only works if active + permission granted
    }
}
```

**Rules**

- Bind module handles in `configureDependencies` via `getModuleAddress`, not constructor hardcodes (supports upgrades).
- Request **only** selectors you call; over-requesting expands attack surface if policy is compromised.
- Gate public entrypoints with ROLES / admin patterns consistent with existing policies (`RolesAdmin`, `Minter`).

## Writing a Module

```solidity
contract OlympusThing is THINGv1 {
    constructor(Kernel k) Module(k) {}

    function KEYCODE() public pure override returns (Keycode) {
        return toKeycode("THING");
    }

    function VERSION() external pure override returns (uint8, uint8) {
        return (1, 0);
    }

    function INIT() external override onlyKernel {}

    function mutate(uint256 x) external permissioned {
        // state changes
    }
}
```

Keep interface abstracts in `*.v1.sol` (or versioned files); implementations in `Olympus*.sol`.

## Common errors

| Error | Meaning |
|-------|---------|
| `Kernel_OnlyExecutor` | Non-executor called `executeAction` |
| `Kernel_ModuleAlreadyInstalled` | Install twice for same keycode — use Upgrade |
| `Kernel_PolicyAlreadyActivated` | Activate twice |
| `Module_PolicyNotPermitted` | Caller is not Kernel and lacks selector permission |
| `Policy_ModuleDoesNotExist` | `getModuleAddress` for uninstalled keycode |
| `Policy_WrongModuleVersion` | Major VERSION mismatch in configureDependencies |
| `InvalidKeycode` | Keycode not 5× A–Z |
