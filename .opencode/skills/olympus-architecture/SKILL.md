---
name: olympus-architecture
description: This skill should be used when the user asks about "Olympus architecture", "Olympus V3", "Bophades", "Default Framework", "Kernel module policy", "Keycode", "permissioned module", "how Olympus works", or needs a high-level map of Olympus Kernel / modules / policies and how pieces connect.
license: MIT
---

# Olympus Architecture (Default Framework / Bophades)

Olympus V3 is a **Default Framework** protocol: a central **Kernel** registry installs **Modules** (state) and activates **Policies** (application logic + external UX). Policies call modules only when Kernel has granted **Permissions**.

## Stack map

```text
┌──────────────────────────────────────────────────────────────┐
│  End users / DAO MS / integrators / Crane strategies         │
├──────────────────────────────────────────────────────────────┤
│  Policies  (UX + app logic; activated by Kernel executor)    │
│  Minter · RolesAdmin · TreasuryCustodian · Emergency · …     │
├──────────────────────────────────────────────────────────────┤
│  Kernel  (registry + Actions + modulePermissions)            │
│  executor-only: Install/UpgradeModule, Activate/Deactivate…  │
├──────────┬──────────┬──────────┬──────────┬──────────────────┤
│ MINTR    │ TRSRY    │ ROLES    │ RANGE    │ INSTR / VOTES /… │
│ mint OHM │ assets   │ roles    │ RBS band │ gov / other      │
├──────────┴──────────┴──────────┴──────────┴──────────────────┤
│  Protocol tokens / periphery                                 │
│  OlympusERC20 (OHM) · Cooler (P2P loans) · gOHM integrations │
└──────────────────────────────────────────────────────────────┘
```

## Core ideas

| Concept | Detail |
|---------|--------|
| **Kernel** | Sole mutator of the module/policy graph via `executeAction` |
| **Module** | Stateful building block with 5-letter `KEYCODE()` (A–Z only), versioned, `permissioned` gate |
| **Policy** | External interface; declares `configureDependencies()` + `requestPermissions()` |
| **Permissions** | `(Keycode, bytes4 selector)` granted to a policy when activated |
| **Executor** | Address that may call Kernel actions (multisig / governance) |
| **Roles** | Policy-defined `bytes32` roles stored in ROLES module; not the same as Kernel permissions |

## Kernel Actions

```solidity
enum Actions {
    InstallModule,   // first install of a keycode
    UpgradeModule,   // replace module impl; reconfigure dependents
    ActivatePolicy,  // wire deps + grant requested permissions
    DeactivatePolicy,// revoke permissions + remove from active set
    ChangeExecutor,
    MigrateKernel
}
```

Call path: `kernel.executeAction(Actions.InstallModule, address(module))` (executor only).

## Module catalog (in-tree Crane port)

| Keycode | Role |
|---------|------|
| `MINTR` | Mint/burn OHM; per-policy mint approvals |
| `TRSRY` | Hold ERC20s; withdraw + debt approvals |
| `ROLES` | Grant/revoke policy-defined roles |
| `RANGE` | Range-bound stability (RBS) state |
| `INSTR` | Instruction batches / proposals |
| `VOTES` | Voting power module |
| `CHREG` | Clearinghouse registry |
| `BLREG` | Boosted liquidity registry |
| `RGSTY` | Contract registry |
| `DLGTE` | Governance delegation |
| `PRICE` | Price feeds / submodules (partial in port) |

## Crane placement

| Tree | Path |
|------|------|
| Domain port (forward) | `contracts/protocols/tokens/stable/olympus/v3/` |
| Pin / scope | `…/olympus/v3/VENDOR.md` |
| Tests | `test/foundry/spec/protocols/tokens/stable/olympus/v3/` |
| Service / Aware / TestBase | `…/v3/services/`, `…/v3/aware/`, `…/v3/test/bases/` |
| Profile | `FOUNDRY_PROFILE=olympus_v3_port` |
| Upstream | OlympusDAO/olympus-v3 (AGPL-3.0-only; see VENDOR.md pin) |
| Research dual tree | `olympus/v2/` + `olympus_port`; skills archive `docs/archive/skills/olympus-v2/` |

## Navigation

| Need | Go to |
|------|--------|
| User/policy call flows | `skill:olympus-operations` |
| Crane build/test/integration | `skill:crane-olympus` |
| Kernel + Policy authoring detail | `references/kernel-and-policies.md` |
| Module surface map | `references/modules.md` |

## Constraints

- Policies **must not** call module functions without Kernel permissions; modules use `permissioned`.
- Direct module calls from EOAs/strategies fail with `Module_PolicyNotPermitted` unless routed through an active policy (or Kernel).
- Keycodes are exactly 5 uppercase ASCII letters (`toKeycode("MINTR")`).
- Phase-2 / out-of-tree: CCIP/LZ bridges, deposit facility, many PRICE.v2 feeds — see `VENDOR.md`.

## See also

- `skill:olympus-operations`, `skill:crane-olympus`
- `skill:crane-porting`, `skill:crane-testing`
