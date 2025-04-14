# Test Plan: BalancerV3 Strategy Vault Adaptor Pool

chore: updating test plan to remove redundancy and improve clarity

This document outlines the testing strategy for pools deployed via the `BalancerV3StrategyVaultAdaptorPoolAndHooksFacetDFPkg.sol`. Adherence to the project's architectural principles, particularly the CREATE3 deployment pattern, is mandatory.

## 1. Test Objective

The primary goal is to write a Foundry test that successfully deploys a Balancer V3 pool which adapts a standard `IStandardStrategyVault`. This test will verify that the pool is correctly initialized, registered with the Balancer V3 Vault, and that its core functionalities behave as expected through the proxy.

## 2. Core Architectural Principles to Uphold

- **NO `new` KEYWORD**: All contract instantiations, both in scripts and tests, **MUST** use the `factory().create3()` method.
- **Proxy Interaction**: All interactions with the pool MUST occur through the final diamond proxy address, never by calling facets directly.
- **Script-Based Deployment**: The test will inherit from `Script_Indexedex.sol` via `TestBase_Indexedex` to handle the deployment of all necessary components, ensuring a consistent environment.
- **Registry-Managed Deployments**: The final pool proxy will be deployed via the `vaultRegistryDeploymentFacet()`, not by directly calling a `deployVault` function on the package itself. This is a critical architectural pattern.

## 3. Test Implementation Plan

The test will be implemented in `test/foundry/pools/balancer/v3/adaptor/BalancerV3StrategyVaultAdaptorPoolAndHooksFacet_Test.t.sol`.

### Step 1: Contract and Inheritance Setup

The test contract will inherit from `BetterBalancerV3BasePoolTest`, which provides the necessary Balancer V3 testing infrastructure and already inherits from `TestBase_Indexedex`.

### Step 2: Deploy Core Indexedex Infrastructure

Override the `onAfterDeployMainContracts()` hook to deploy all required facets and the package, making it available to the registry.

### Step 3: Set Up Test-Specific Dependencies

Explicitly call `setUp()` from each parent contract in the correct order. After setup, the `uniswapVault` instance and test tokens are available for use.

### Step 4: Pool Creation and Initialization

- Pool creation is handled in the `createHooks()` override, which deploys the pool via the registry and stores the result for later use.
- The `createPool()` override simply returns the stored values.
- The `initPool()` override mints LP tokens, deposits them into the strategy vault, and adds the resulting shares as liquidity to the Balancer pool.
- Use the correct protocol flows for minting and depositing tokens (see below for details).

### Step 5: Inherited Test Functions: Override Requirements

Override all inherited test functions that assume multi-token, unbalanced, or arbitrary swap support, or that assume the pool accepts tokens other than the strategy vault token. Override swap fee tests if your pool has fixed or zero swap fees. Leave generic address and rate tests as-is unless your pool logic requires otherwise.

## Swap Routes to Test

Implement and validate the following swap routes for the pool:

| Route                                 | Should Succeed? | Notes                                                      |
|---------------------------------------|-----------------|------------------------------------------------------------|
| TokenA → Vault Shares                 | Yes             | Deposit TokenA, receive vault shares (via underlying vault) |
| TokenB → Vault Shares                 | Yes             | Deposit TokenB, receive vault shares (via underlying vault) |
| Vault Shares → TokenA                 | Yes             | Redeem vault shares for TokenA                             |
| Vault Shares → TokenB                 | Yes             | Redeem vault shares for TokenB                             |
| TokenA → TokenB                       | Maybe/No        | Only if supported by vault logic; otherwise should revert   |
| TokenB → TokenA                       | Maybe/No        | Only if supported by vault logic; otherwise should revert   |
| Vault Shares → Vault Shares           | No              | Should revert or be a no-op                                 |
| TokenA → TokenA                       | No              | Should revert or be a no-op                                 |
| TokenB → TokenB                       | No              | Should revert or be a no-op                                 |

For each route, write tests that confirm successful swaps where supported and correct error handling for unsupported routes. Pay special attention to edge cases (minimum/maximum amounts, slippage, rounding).

## Current Status

- Test contract and harness are set up and compile.
- Initialization and pool deployment via the registry are working.
- Pool tokens and strategy vault are correctly created and sorted.
- Pool initialization (minting LP tokens, depositing to the strategy vault, adding liquidity) is functional.
- All required test function overrides are present as stubs with TODOs.
- The test plan is mapped to code and ready for incremental implementation.

## Remaining Work

1. Implement custom test logic for add/remove liquidity, swaps, swap fee, and edge cases.
2. Implement swap route coverage for all valid and invalid routes.
3. Test minimum/maximum amounts, slippage, rounding, and error handling.
4. Document each test and any deviations from inherited base logic.
5. Run and debug the full test suite incrementally, using `-vvvv` for full traces.

---

### Liquidity Buffers and ERC4626 Wrappers for Swap Testing

Before testing swaps, ensure the Balancer V3 Vault is pre-funded with sufficient balances of all tokens the pool will accept:
- **TokenA** (first underlying token of the Uniswap V2 pair)
- **TokenB** (second underlying token of the Uniswap V2 pair)
- **Uniswap V2 LP Token** (the LP token for the TokenA/TokenB pair)
- **Strategy Vault Token** (ERC20 representing shares in the Uniswap V2 strategy vault)

#### Canonical Balancer V3 Liquidity Buffer Pattern

For any ERC4626 (or similar) token that needs to be available for swaps, you **must** initialize a liquidity buffer using the BufferRouter's `initializeBuffer` function. This is the only way to ensure the vault's buffer is correctly initialized and available for use in Balancer V3's internal accounting and swap logic.

**Example:**
```solidity
vm.prank(lp);
bufferRouter.initializeBuffer(IERC4626(address(wrapper)), underlyingAmount, wrappedAmount, minIssuedShares);
```
- `IERC4626(address(wrapper))`: The ERC4626 wrapper token.
- `underlyingAmount`: Amount of underlying tokens to deposit into the buffer.
- `wrappedAmount`: Amount of wrapped tokens to deposit into the buffer.
- `minIssuedShares`: Minimum shares to be issued (for slippage protection, usually 0 in tests).

See `BufferVaultPrimitive.t.sol` and `BufferDoSProtection.t.sol` in the Balancer V3 monorepo for canonical usage.

**This step is a prerequisite for all swap route tests.**

#### **Where to Perform Wrapper and Buffer Initialization**

> **Important:**
> All ERC4626 wrapper creation and buffer initialization must be performed in the `initPool()` function, **not** in `onAfterDeployMainContracts()`. This is because:
>
> - `onAfterDeployMainContracts()` is responsible only for deploying and registering contracts (tokens, vaults, pools, etc.), not for funding or initializing protocol state.
> - At the time `onAfterDeployMainContracts()` runs, the test contract may not have the correct balances or approvals to perform deposits or buffer initialization.
> - Canonical DeFi and Balancer V3 test patterns always separate contract deployment from state initialization. All actions that require protocol flows (minting, depositing, buffer setup) are performed in `initPool()`, after all contracts are deployed and the test contract has the correct balances and approvals.
>
> **Summary:**
> - Deploy contracts in `onAfterDeployMainContracts()`
> - Mint tokens, deposit, and initialize wrappers/buffers in `initPool()`
> - This ensures correctness, matches canonical patterns, and avoids subtle test bugs.

---

#### Creating and Funding ERC4626 Wrappers and Buffers Using Pool Tokens

For each token in the `poolTokens` array declared in `BetterBalancerV3BasePoolTest.sol`:

1. **Create ERC4626 Wrappers as Needed:**
   - Use the facet and package instances from `Script_Crane`.
   - Example:
     ```solidity
     IERC4626 erc4626Wrapper = IERC4626(diamondFactory().deploy(
         erc4626Pkg,
         abi.encode(IERC4626DFPkg.ERC4626DFPkgArgs({
             underlying: address(uniswapVault), // or LP token
             decimalsOffset: 0,
             name: "Wrapped Strategy Vault",
             symbol: "WSV"
         }))
     ));
     ```

2. **Mint Underlying Tokens via Real Protocol Flows:**
   - **Do NOT use `vm.deal()` to mint vault or LP tokens.**
   - For UniswapV2 LP tokens: Add liquidity to the UniswapV2 pair using the router and underlying tokens (TokenA, TokenB).
   - For Strategy Vault tokens: Deposit LP tokens into the strategy vault using the correct protocol interface (e.g., `IStandardExchangeIn`).
   - Only use `vm.deal()` for the base underlying tokens (TokenA, TokenB) if needed for test setup.

3. **Deposit Underlying Tokens into the ERC4626 Wrapper:**
   - Approve the wrapper to spend the underlying tokens.
   - Call `deposit()` on the wrapper to mint wrapped tokens.
   - Example:
     ```solidity
     IERC20(underlying).approve(address(erc4626Wrapper), amount);
     erc4626Wrapper.deposit(amount, address(this));
     ```

4. **Deposit Both Underlying and Wrapped Tokens into the Liquidity Buffer:**
   - Use `bufferRouter.initializeBuffer` to deposit both the underlying and wrapped tokens into the buffer for the Balancer V3 Vault.
   - Example:
     ```solidity
     bufferRouter.initializeBuffer(
         erc4626Wrapper,
         underlyingAmount, // amount of underlying token
         wrappedAmount,    // amount of wrapped token
         0                 // minIssuedShares (usually 0 in tests)
     );
     ```

5. **Repeat for Each Relevant Token:**
   - Ensure all tokens in `poolTokens` that require ERC4626 wrappers and/or liquidity buffers are handled using this process.
   - This ensures all swap routes have sufficient liquidity and that the Balancer V3 Vault's internal accounting is correct.

**Important:**
- You MUST use real protocol flows to mint LP and vault tokens (add liquidity, deposit to vault, etc.).
- Do NOT use `vm.deal()` to mint or assign balances of LP tokens or vault tokens directly.
- Only use `vm.deal()` for base tokens (TokenA, TokenB) as needed for test setup.
- This process is required for all swap route tests and for accurate simulation of real-world pool behavior.
