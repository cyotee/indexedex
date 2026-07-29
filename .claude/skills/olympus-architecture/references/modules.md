# Module surface map

## Contents

- [MINTR](#mintr)
- [TRSRY](#trsry)
- [ROLES](#roles)
- [Others (brief)](#others-brief)
- [External products](#external-products)

Paths under `contracts/protocols/tokens/stable/olympus/`.

## MINTR

| Item | Path |
|------|------|
| Interface | `modules/MINTR/MINTR.v1.sol` |
| Impl | `modules/MINTR/OlympusMinter.sol` |
| Token | `external/OlympusERC20.sol` (`OHM`) |

**State:** `ohm`, `active`, `mintApproval[policy]`.

**Permissioned API (typical):** `mintOhm`, `burnOhm`, `increaseMintApproval`, `decreaseMintApproval`, `activate`/`deactivate`.

Policies request mint/approval selectors then call after ROLES checks (see `policies/Minter.sol`).

## TRSRY

| Item | Path |
|------|------|
| Interface | `modules/TRSRY/TRSRY.v1.sol` |
| Impl | `modules/TRSRY/OlympusTreasury.sol` |

**State:** `active`, `withdrawApproval[withdrawer][token]`, `debtApproval[debtor][token]`, debt tracking.

**Patterns:** Policies increase their own withdraw approval then pull tokens; debt accounting for temporary borrowing from treasury.

Related policies: `TreasuryCustodian`, `Emergency`, `ReserveWrapper`, `ReserveMigrator`.

## ROLES

| Item | Path |
|------|------|
| Interface | `modules/ROLES/ROLES.v1.sol` |
| Impl | `modules/ROLES/OlympusRoles.sol` (+ `RolesConsumer`) |

**API:** `saveRole`, `removeRole`, `requireRole`, `hasRole`, `ensureValidRole`.

**Admin policy:** `policies/RolesAdmin.sol` — only `admin` may grant/revoke; two-step admin transfer (`pushNewAdmin` / `pullRolesAdmin`).

Role strings are policy-defined (e.g. `"minter_admin"` on `Minter`).

## Others (brief)

| Keycode | Purpose | Primary paths |
|---------|---------|---------------|
| RANGE | RBS range state | `modules/RANGE/` |
| INSTR | Instruction lists | `modules/INSTR/` |
| VOTES | Vote balances | `modules/VOTES/` |
| CHREG | Clearinghouse registry | `modules/CHREG/` |
| BLREG | Boosted LP registry | `modules/BLREG/` |
| RGSTY | Named contract registry | `modules/RGSTY/` |
| DLGTE | Gov delegation | `modules/DLGTE/` |
| PRICE | Oracles / submodules | `modules/PRICE/` (partial port) |

## External products

| Product | Path | Notes |
|---------|------|-------|
| OHM ERC20 | `external/OlympusERC20.sol` | Mint authority historically via OlympusAuthority; MINTR wires mint/burn |
| Cooler | `external/cooler/Cooler.sol` | Clone escrow; P2P fixed-duration loans (collateral/debt immutables) |
| CoolerFactory | `external/cooler/CoolerFactory.sol` | Deploys Cooler clones |
| ClaimTransfer | `external/ClaimTransfer.sol` | Claim migration helper |

Cooler is **not** a Kernel module; users interact via factory + Cooler instance (see `skill:olympus-operations`).
