# Balancer V3 Router Integration Task List

## Overview
This task list tracks the progress of the Balancer V3 Router Integration with Strategy Vaults for the `indexedex` project. Tasks are organized by development phases as outlined in the Project Requirement Document (PRD). Checkboxes will be marked as completed (`[x]`) when tasks are done, and left unchecked (`[ ]`) for tasks in progress or not started.

## Phase 1: Standard Exchange Router Completion

- [ ] Task 1: Implement `swapSingleTokenExactOut` with Strategy Vault support
  - [x] Support for Strategy Vault token input and output (Completed on [current date])
  - [x] Handle WETH wrapping/unwrapping for ETH swaps (Completed on [current date])
  - [x] Ensure proper settlement with Balancer V3 Vault (Completed on [current date])
- [ ] Task 2: Add liquidity management functions (add/remove liquidity in all modes)
  - [x] **Add Liquidity (Proportional)**: Implement `addLiquidityProportional` function for proportional liquidity addition.
  - [x] **Add Liquidity (Unbalanced)**: Implement `addLiquidityUnbalanced` function for unbalanced liquidity addition.
  - [ ] Unbalanced liquidity addition/removal
  - [ ] Single token liquidity addition/removal
  - [ ] Custom liquidity addition/removal
  - [ ] Recovery mode liquidity removal
- [ ] Task 3: Implement pool initialization functionality
  - [ ] Support initialization with tokens from Strategy Vaults if needed
  - [ ] Ensure proper token crediting to Vault
- [ ] Task 4: Add query functions for all operations
  - [ ] Query functions for swaps (exact in and out)
  - [ ] Query functions for liquidity operations (add/remove in all modes)
  - [ ] Query functions for pool initialization
- [ ] Task 5: Test and validate all specified swap routes
  - [ ] Balancer Pool Contained Token -> Balancer Pool Contained Token
  - [ ] Strategy Vault Contained Token -> Strategy Vault -> Balancer Pool Contained Token
  - [ ] Balancer Pool Contained Token -> Strategy Vault -> Strategy Vault Contained Token
  - [ ] Strategy Vault Contained Token -> Strategy Vault -> Strategy Vault -> Strategy Vault Contained Token
  - [ ] Ethereum -> WETH -> Balancer Pool Contained Token
  - [ ] Balancer Pool Contained Token -> WETH -> Ethereum
  - [ ] Ethereum -> WETH -> Strategy Vault -> Balancer Pool Contained Token
  - [ ] Ethereum -> WETH -> Strategy Vault -> Strategy Vault -> WETH -> Ethereum

## Phase 2: Batch Router Development

- [ ] Task 1: Create a new contract based on `BatchRouter.sol`
  - [ ] Set up basic structure and inheritance from Balancer V3 interfaces
  - [ ] Integrate with Crane Framework for modularity
- [ ] Task 2: Implement batch swap functionality with Strategy Vault support
  - [ ] Support multi-step swap paths involving multiple pools
  - [ ] Handle Strategy Vault interactions within batch swaps
  - [ ] Ensure WETH wrapping/unwrapping for ETH batch swaps
- [ ] Task 3: Add query functions for batch operations
  - [ ] Query functions for previewing batch swap outcomes
  - [ ] Support for complex path analysis in queries
- [ ] Task 4: Test complex multi-step swap paths
  - [ ] Validate batch swaps with multiple Balancer V3 pools
  - [ ] Validate batch swaps involving Strategy Vaults
  - [ ] Validate batch swaps with ETH/WETH conversions

## Phase 3: Integration and Testing

- [ ] Task 1: Integrate both routers with Crane Framework facets
  - [ ] Ensure Standard Exchange Router operates as a facet
  - [ ] Ensure Batch Router operates as a facet
- [ ] Task 2: Conduct comprehensive testing using base test classes from Crane Framework
  - [ ] Unit tests for individual functions in both routers
  - [ ] Integration tests for full swap routes and batch operations
  - [ ] Edge case and failure mode testing (e.g., insufficient approvals, Vault reverts)
- [ ] Task 3: Document any deviations from standard Balancer V3 lifecycle
  - [ ] Note custom handling for Strategy Vault interactions
  - [ ] Document ETH/WETH handling specifics
  - [ ] Update PRD with any new findings or limitations

## Additional Notes
- Tasks will be updated with completion dates and relevant commit references as they are completed.
- This task list is a living document and may be revised if new tasks or requirements emerge during development.

## Revision History
- **Version 1.0:** Initial task list created on [current date] by AI assistant for tracking progress.
- **Version 1.1:** Updated on [current date] to reflect start of work on Task 1 of Phase 1.
- **Version 1.2:** Updated on [current date] to reflect completion of subtasks for Task 1 of Phase 1.
- **Version 1.3:** Updated on [current date] to reflect start of work on Task 2 of Phase 1.
- **Version 1.4:** Updated on [current date] to reflect completion of proportional liquidity addition subtask for Task 2 of Phase 1.
- **Version 1.5:** Updated on [current date] to reflect completion of unbalanced liquidity addition and liquidity removal subtasks for Task 2 of Phase 1. 