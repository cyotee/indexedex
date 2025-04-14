# Project Requirement Document (PRD)
## Balancer V3 Router Integration with Strategy Vaults for Indexedex

### 1. Overview

#### 1.1 Project Name

Balancer V3 Router Integration with Strategy Vaults

#### 1.2 Purpose

The purpose of this project is to develop two specialized routers for the `indexedex` platform to integrate with Balancer V3, a decentralized exchange (DEX) protocol. These routers will facilitate token swaps and liquidity operations involving Balancer V3 pools and custom Strategy Vaults, addressing limitations found in the initial Strategy Vault Adaptor Pool approach. This integration aims to provide users with flexible swap routes, including direct pool swaps, Strategy Vault interactions, and Ethereum (ETH) to Wrapped ETH (WETH) conversions.

#### 1.3 Background

The `indexedex` project is a DEX integration platform built using the Crane Framework, which emphasizes modularity and upgradeability through the Diamond Proxy pattern. Initial attempts to integrate Balancer V3 using a Strategy Vault Adaptor Pool were deprecated due to a limitation in the Balancer V3 Vault system: pools cannot swap tokens not credited to them in the Vault, and must return a non-zero value from the `onSwap` function. This PRD outlines the shift to a router-based approach to overcome these constraints.

### 2. Objectives

#### 2.1 Primary Goal

Develop two routers to handle token swaps and liquidity operations with Balancer V3 pools, supporting interactions with Strategy Vaults for token wrapping and unwrapping, and ensuring compatibility with ETH/WETH conversions.

#### 2.2 Specific Objectives

- **Standard Exchange Router:** Complete the development of `BalancerV3StandardExchangeRouterDFPkg.sol` to match and extend the functionality of Balancer V3's `Router.sol`, supporting specified swap routes involving Strategy Vaults.
- **Batch Router:** Develop a new router based on Balancer V3's `BatchRouter.sol` to handle complex, multi-step batch swap operations involving multiple pools and Strategy Vault interactions.
- Ensure modularity and future-proofing by leveraging the Crane Framework's Diamond Proxy pattern for easy upgrades and additions.

### 3. Scope

#### 3.1 In-Scope

- **Standard Exchange Router (`BalancerV3StandardExchangeRouterDFPkg.sol`):**
  - Implementation of exact input and output swaps with Strategy Vault support.
  - Liquidity addition and removal operations (proportional, unbalanced, single token, custom, recovery).
  - Pool initialization with tokens from Strategy Vaults if needed.
  - Query functions for previewing swap and liquidity operation outcomes.
  - Support for the following swap routes:
    - Balancer Pool Contained Token -> Balancer Pool Contained Token (no WETH or Strategy Vault)
    - Strategy Vault Contained Token -> Strategy Vault -> Balancer Pool Contained Token
    - Balancer Pool Contained Token -> Strategy Vault -> Strategy Vault Contained Token
    - Strategy Vault Contained Token -> Strategy Vault -> Strategy Vault -> Strategy Vault Contained Token
    - Ethereum -> WETH -> Balancer Pool Contained Token
    - Balancer Pool Contained Token -> WETH -> Ethereum
    - Ethereum -> WETH -> Strategy Vault -> Balancer Pool Contained Token
    - Ethereum -> WETH -> Strategy Vault -> Strategy Vault -> WETH -> Ethereum
- **Batch Router (to be developed):**
  - Implementation based on `BatchRouter.sol` for batch swaps.
  - Support for multi-step swap paths involving Balancer V3 pools and Strategy Vaults.
  - Query functions for batch operations.
- Integration with Crane Framework for modularity and upgradeability.
- Use of Permit2 for efficient token transfers and Vault interactions.

#### 3.2 Out-of-Scope

- Development of new pool types or hooks beyond router functionality (to be addressed in separate PRDs if needed).
- Integration with other DEX protocols beyond Balancer V3 at this stage (e.g., Uniswap V2 integration is noted but not prioritized in this PRD).
- User interface development for interacting with these routers (assumed to be handled separately).

### 4. Requirements

#### 4.1 Functional Requirements

- **Standard Exchange Router:**
  - Must support all swap routes listed in the scope, handling token transfers through Strategy Vaults and WETH conversions.
  - Must provide functions for pool initialization, adding liquidity (all modes), removing liquidity (all modes), and swaps (exact in and out).
  - Must include query functions for all operations to preview outcomes without executing transactions.
  - Must handle ETH/WETH wrapping and unwrapping seamlessly.
- **Batch Router:**
  - Must support batch swaps with multiple steps, including Strategy Vault interactions.
  - Must handle complex paths with multiple pools and token transformations.
  - Must include query functions for batch operations.
- **Error Handling:**
  - Must implement robust error handling for failed Strategy Vault operations, insufficient approvals, and Vault reverts.
  - Must ensure proper ETH refunds in all scenarios.

#### 4.2 Technical Requirements

- **Smart Contract Language:** Solidity ^0.8.0.
- **Framework:** Crane Framework using Diamond Proxy pattern (EIP-2535) for modularity.
- **Dependencies:**
  - Balancer V3 interfaces and libraries (`@balancer-labs/v3-interfaces`, `@balancer-labs/v3-solidity-utils`).
  - OpenZeppelin contracts for ERC20 interactions and utilities.
  - Permit2 for token transfers.
- **Integration Points:**
  - Balancer V3 Vault for settling and swapping tokens.
  - Strategy Vaults for token wrapping/unwrapping via `exchangeIn` function.
  - WETH contract for ETH conversions.
- **Gas Optimization:** Minimize token transfers and approvals using Permit2 and efficient settlement logic.

#### 4.3 Security Requirements

- **Access Control:** Ensure only authorized calls (e.g., from Vault) can execute critical functions using modifiers like `onlyVault`.
- **Reentrancy Protection:** Use `nonReentrant` modifiers to prevent reentrancy attacks.
- **Token Safety:** Validate token amounts and approvals to prevent over-spending or unauthorized transfers.
- **Audit Readiness:** Structure code for clarity and document deviations from standard Balancer V3 lifecycle for future audits.

### 5. Development Plan

#### 5.1 Phases

- **Phase 1: Standard Exchange Router Completion**
  - Task 1: Implement `swapSingleTokenExactOut` with Strategy Vault support.
  - Task 2: Add liquidity management functions (add/remove liquidity in all modes).
  - Task 3: Implement pool initialization functionality.
  - Task 4: Add query functions for all operations.
  - Task 5: Test and validate all specified swap routes.
- **Phase 2: Batch Router Development**
  - Task 1: Create a new contract based on `BatchRouter.sol`.
  - Task 2: Implement batch swap functionality with Strategy Vault support.
  - Task 3: Add query functions for batch operations.
  - Task 4: Test complex multi-step swap paths.
- **Phase 3: Integration and Testing**
  - Task 1: Integrate both routers with Crane Framework facets.
  - Task 2: Conduct comprehensive testing using base test classes from Crane Framework.
  - Task 3: Document any deviations from standard Balancer V3 lifecycle.

#### 5.2 Timeline

- **Phase 1:** 2-3 weeks (depending on complexity of Strategy Vault interactions).
- **Phase 2:** 2-3 weeks (post-completion of Phase 1).
- **Phase 3:** 1-2 weeks (post-completion of Phase 2).
- **Total Estimated Time:** 5-8 weeks.

#### 5.3 Resources

- **Development Team:** AI-assisted coding with user oversight for strategic decisions.
- **Tools:** Foundry for smart contract development and testing, leveraging Crane Framework's base test classes.
- **Documentation:** Balancer V3 lifecycle guides, Crane Framework documentation, and this PRD.

### 6. Success Criteria

- **Functional Success:** All specified swap routes are operational, with successful token swaps and liquidity operations involving Balancer V3 pools and Strategy Vaults.
- **Technical Success:** Routers are integrated with Crane Framework, gas-optimized, and pass comprehensive tests without security vulnerabilities.
- **User Experience:** Users can seamlessly interact with the routers for swaps and liquidity operations, with clear query results for planning transactions.

### 7. Risks and Mitigation

- **Risk 1: Complexity of Strategy Vault Interactions**
  - **Mitigation:** Break down development into smaller, testable components; prioritize thorough testing of each swap route.
- **Risk 2: Balancer V3 Vault Limitations**
  - **Mitigation:** Design routers to handle token crediting and settlements explicitly, avoiding reliance on pool-level token balances.
- **Risk 3: Gas Costs for Multi-Step Operations**
  - **Mitigation:** Optimize token transfers using Permit2 and minimize on-chain operations where possible.

### 8. References

- **Balancer V3 Documentation:** Lifecycle and architecture guides for pool and router interactions.
- **Crane Framework Documentation:** Guidelines for Diamond Proxy pattern and facet development.
- **Project Files:**
  - `BalancerV3StandardExchangeRouterDFPkg.sol` (Standard Exchange Router implementation).
  - Balancer V3's `Router.sol` and `BatchRouter.sol` as base references.

### 9. Revision History

- **Version 1.0:** Initial draft created on [current date] by AI assistant for user review and future reference.

---
**Note:** This PRD is a living document and may be updated as development progresses or new requirements emerge. Future chat sessions should refer to this document for continuity and alignment on project goals. 