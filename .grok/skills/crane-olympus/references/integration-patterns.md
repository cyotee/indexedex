# Integration patterns (Crane + Olympus)

## Contents

- [Direct policy integration](#direct-policy-integration)
- [Strategy / vault that holds OHM](#strategy--vault-that-holds-ohm)
- [Diamond / Facet later](#diamond--facet-later)
- [Hermetic test sketch](#hermetic-test-sketch)

## Direct policy integration

**Use when:** Your product *is* an Olympus policy (DAO-activated).

1. Subclass `Policy` (+ `RolesConsumer` if role-gated).
2. Declare module deps + selectors.
3. Executor installs modules (if new env) and activates your policy.
4. External UX is your policy’s public functions.

Imports always `@crane/contracts/protocols/tokens/stable/olympus/...`.

## Strategy / vault that holds OHM

**Use when:** A Crane Diamond or vault needs OHM balances but is **not** a Kernel policy.

| Need | Approach |
|------|----------|
| Hold/transfer OHM | Standard ERC20 against `OlympusERC20` / live OHM address |
| Mint OHM | Cannot call MINTR directly — need an activated policy path or DAO mint ops |
| Treasury assets | Same: go through activated treasury policies, not TRSRY as EOA |
| Cooler loans | Call Cooler/Factory as any user; no Kernel permission required |

Prefer composing with **existing** policies over forking module permissions.

## Diamond / Facet later

When wrapping Olympus into Crane FTR/DFPkg (not required for current port DoD):

| Piece | Pattern |
|-------|---------|
| AwareRepo | Store Kernel + key policy addresses |
| Service | Stateless helpers: `execute` mint via policy, read keycodes |
| Facet | Thin external ABI for Diamond users |
| DFPkg | Bundle facets; `initAccount` sets Aware storage |

Do **not** reimplement MINTR/TRSRY inside Diamond storage — treat Olympus Kernel as the system of record.

## Hermetic test sketch

```solidity
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.15;

import {Test} from "forge-std/Test.sol";
import {Kernel, Actions} from
    "@crane/contracts/protocols/tokens/stable/olympus/Kernel.sol";
// + module impls, policies, ModuleTestFixtureGenerator as needed

contract MyOlympusIntegrationTest is Test {
    Kernel internal kernel;

    function setUp() public {
        kernel = new Kernel();
        // install modules, activate policies under prank(executor)
        // grant roles via RolesAdmin
    }

    function test_flow() public {
        // call policies as role holders; assert balances / events
    }
}
```

Run with `FOUNDRY_PROFILE=olympus_port`. Reuse patterns from `Kernel.t.sol` and `modules/MINTR.t.sol` rather than inventing mocks for Kernel.
