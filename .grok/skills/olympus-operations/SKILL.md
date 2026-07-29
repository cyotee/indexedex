---
name: olympus-operations
description: This skill should be used when the user asks about "Olympus mint", "mint OHM", "Olympus treasury withdraw", "RolesAdmin grantRole", "Cooler loan", "clear Cooler request", "use Olympus as user", "call Minter policy", "Emergency withdraw", or needs end-user / operator call flows against Olympus policies and Cooler.
license: MIT
---

# Olympus Operations (end users & operators)

How to **call** Olympus as a user, operator, or DAO role — not how to design the Kernel (see architecture) or Crane test plumbing (see `crane-olympus`).

## Mental model for callers

| You are… | You call… | You do **not** call… |
|----------|-----------|----------------------|
| End user | Active **policies** / Cooler / OHM ERC20 | Module `permissioned` functions |
| Role holder (`minter_admin`, …) | Policy admin entrypoints | Kernel (unless you are executor) |
| Executor (DAO MS) | `Kernel.executeAction` | — |
| Integrator contract | Same as policy or approved periphery | Modules unless you *are* an activated policy |

Direct `MINTR.mintOhm` from an EOA → `Module_PolicyNotPermitted`.

## Quick start: read path

```solidity
Kernel kernel = Kernel(kernelAddr);
Module mintr = kernel.getModuleForKeycode(toKeycode("MINTR"));
bool active = kernel.isPolicyActive(Policy(minterPolicy));
bool canMint = kernel.modulePermissions(
    toKeycode("MINTR"),
    Policy(minterPolicy),
    MINTRv1.mintOhm.selector
);
```

## Common flows

| Goal | Entry | Role / gate | Detail |
|------|-------|-------------|--------|
| Mint OHM (ops) | `Minter.mint(to, amount, category)` | `onlyRole("minter_admin")` + approved category | Policy bumps MINTR approval then mints |
| Grant/revoke role | `RolesAdmin.grantRole` / `revokeRole` | RolesAdmin `admin` | Writes ROLES module |
| Treasury ops | `TreasuryCustodian` / `Emergency` | Policy-specific roles | Withdraw via TRSRY approvals |
| Transfer OHM | `OHM.transfer` / `transferFrom` | ERC20 allowances | Standard token UX |
| Cooler borrow request | `Cooler.requestLoan(...)` | Cooler `owner` | Peer loan escrow |
| Lend into Cooler | `Cooler.clearRequest(...)` | Anyone with debt tokens | Converts request → loan |
| Repay / default | Cooler repay / claim default | Borrower / lender | See Cooler refs |

## Operator checklist (DAO bootstrap)

1. Confirm `kernel.executor()`.
2. Install modules → activate policies (order: ROLES + RolesAdmin early).
3. `RolesAdmin.grantRole` for product roles.
4. Configure policy params (e.g. `Minter.addCategory`).
5. Verify with read path above before moving funds.

## Navigation

| Topic | File |
|-------|------|
| Mint / roles / treasury call recipes | `references/policy-call-flows.md` |
| Cooler user journey | `references/cooler-user.md` |
| Architecture map | `skill:olympus-architecture` |
| Tests & Crane paths | `skill:crane-olympus` |

## Constraints

- Always use **activated** policy addresses from the live Kernel, not stale deploys.
- Categories/roles are bytes32 strings — match exact on-chain values.
- Cooler uses clone immutables (owner, collateral, debt, factory) — verify before approving tokens.
- Fork-only products (bridges, full clearinghouse stack) may be out of Crane hermetic suite — check `VENDOR.md`.

## See also

- `skill:olympus-architecture`, `skill:crane-olympus`
- Paths: `contracts/protocols/tokens/stable/olympus/policies/`, `…/external/cooler/`
