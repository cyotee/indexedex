---
name: EVK Architecture
description: This skill should be used when the user asks about "EVK", "Euler Vault Kit", "EVault", "modular vault", "dispatch pattern", "vault modules", or needs to understand Euler's vault architecture.
version: 0.1.0
---

# Euler Vault Kit (EVK) Architecture

The Euler Vault Kit is a modular credit vault system built on EVC. EVaults are ERC-4626 compliant vaults with added borrowing functionality, implemented via a dispatch pattern that routes calls to specialized modules.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    EVK ARCHITECTURE                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  User Request                                                │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                   EVault (Dispatcher)                   │ │
│  │    Routes calls to appropriate module via delegatecall  │ │
│  └────────────────────────┬────────────────────────────────┘ │
│                           │                                  │
│     ┌─────────────────────┼─────────────────────────┐        │
│     │                     │                         │        │
│     ▼                     ▼                         ▼        │
│  ┌──────────┐  ┌──────────────────┐  ┌──────────────────┐    │
│  │ Token    │  │ Vault            │  │ Borrowing        │    │
│  │ Module   │  │ Module           │  │ Module           │    │
│  │          │  │                  │  │                  │    │
│  │ transfer │  │ deposit/withdraw │  │ borrow/repay     │    │
│  │ approve  │  │ mint/redeem      │  │ pullDebt         │    │
│  └──────────┘  └──────────────────┘  └──────────────────┘    │
│                                                              │
│  ┌──────────────┐  ┌────────────────┐  ┌─────────────────┐   │
│  │ Liquidation  │  │ RiskManager    │  │ Governance      │   │
│  │ Module       │  │ Module         │  │ Module          │   │
│  │              │  │                │  │                 │   │
│  │ liquidate    │  │ setLTV/caps    │  │ setGovernor     │   │
│  │ checkHealth  │  │ setIRM/oracle  │  │ setFeeReceiver  │   │
│  └──────────────┘  └────────────────┘  └─────────────────┘   │
│                                                              │
│  ┌────────────────────┐  ┌─────────────────────────────────┐ │
│  │ BalanceForwarder   │  │ Initialize                      │ │
│  │ Module             │  │ Module                          │ │
│  │                    │  │                                 │ │
│  │ Balance tracking   │  │ One-time setup                  │ │
│  └────────────────────┘  └─────────────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Dispatch Pattern

EVault uses a modular architecture where the main contract delegates calls to separate module contracts:

```solidity
// EVault.sol - Main dispatcher
contract EVault is Dispatch {
    address public immutable MODULE_TOKEN;
    address public immutable MODULE_VAULT;
    address public immutable MODULE_BORROWING;
    address public immutable MODULE_LIQUIDATION;
    address public immutable MODULE_RISKMANAGER;
    address public immutable MODULE_BALANCE_FORWARDER;
    address public immutable MODULE_GOVERNANCE;
    address public immutable MODULE_INITIALIZE;

    constructor(Integrations memory integrations, DeployedModules memory modules) {
        // Store EVC, oracle, unit of account, etc.
        // Store module addresses
    }
}
```

### Routing Modifiers

```solidity
// Dispatch.sol
modifier use(address module) {
    _; // Execute function body (usually empty)
    // Then delegatecall to module
    assembly {
        // Copy calldata and delegatecall to module
        // Return or revert with result
    }
}

modifier useView(address module) {
    // For view functions - similar but staticcall
}

// Usage in EVault
function deposit(uint256 assets, address receiver)
    public
    virtual
    override
    use(MODULE_VAULT)
    returns (uint256)
{}

function borrow(uint256 assets, address receiver)
    public
    virtual
    use(MODULE_BORROWING)
    returns (uint256)
{}
```

## Storage Layout

All modules share the same storage layout via inheritance:

```solidity
// Base.sol - Shared storage
abstract contract Base is EVCUtil, Cache {
    // Core integrations
    IEVC public immutable evc;
    address public immutable protocolConfigAddress;
    address public immutable oracle;
    address public immutable unitOfAccount;

    // Vault state
    VaultStorage internal vaultStorage;
    mapping(address => UserStorage) internal users;
}

struct VaultStorage {
    // Snapshot
    uint48 lastInterestAccumulatorUpdate;
    uint144 interestAccumulator;

    // Supply side
    uint72 totalShares;            // eToken total supply
    uint168 totalBorrows;          // Total debt (in internal units)

    // Cash = vault's balance of underlying
    // (calculated from ERC20 balance)

    // Interest rate model
    address interestRateModel;

    // Fees
    uint16 interestFee;            // Protocol fee on interest
    address feeReceiver;

    // Debt token
    address dToken;
}

struct UserStorage {
    uint256 balance;               // eToken balance
    uint256 borrowed;              // Debt principal
    uint256 interestAccumulator;   // User's last accumulator snapshot
    SetStorage collaterals;        // Enabled collateral vaults
}
```

## Module Contracts

Each module is a standalone contract that implements a subset of vault functionality:

```solidity
// Token.sol
contract Token is Base, IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFromMax(address from, address to) external returns (bool);
}

// Vault.sol
contract Vault is Base, IERC4626 {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}

// Borrowing.sol
contract Borrowing is Base {
    function borrow(uint256 assets, address receiver) external returns (uint256);
    function repay(uint256 assets, address receiver) external returns (uint256);
    function pullDebt(uint256 assets, address from) external returns (uint256);
    function touch() external;  // Trigger interest accrual
}

// Liquidation.sol
contract Liquidation is Base {
    function liquidate(
        address violator,
        address collateral,
        uint256 repayAssets,
        uint256 minYieldBalance
    ) external;
    function checkAccountStatus(address account, address[] calldata collaterals)
        external view returns (bytes4);
}

// RiskManager.sol
contract RiskManager is Base {
    function setLTV(address collateral, uint16 borrowLTV, uint16 liquidationLTV, uint32 rampDuration);
    function setInterestRateModel(address newModel);
    function setMaxLiquidationDiscount(uint16 newDiscount);
    function setCaps(uint16 supplyCap, uint16 borrowCap);
}

// Governance.sol
contract Governance is Base {
    function setGovernorAdmin(address newGovernorAdmin);
    function setFeeReceiver(address newFeeReceiver);
    function setInterestFee(uint16 newFee);
    function convertFees() external;
}

// Initialize.sol
contract Initialize is Base {
    function initialize(address proxyCreator) external;
}

// BalanceForwarder.sol
contract BalanceForwarder is Base {
    function enableBalanceForwarder() external;
    function disableBalanceForwarder() external;
}
```

## Debt Token (DToken)

Separate ERC20-like token representing debt:

```solidity
// DToken.sol
contract DToken {
    address public immutable eVault;

    function balanceOf(address account) external view returns (uint256) {
        return IEVault(eVault).debtOf(account);
    }

    function totalSupply() external view returns (uint256) {
        return IEVault(eVault).totalBorrows();
    }

    // Transfer debt between accounts
    function transfer(address to, uint256 amount) external returns (bool);
}
```

## Factory Deployment

```solidity
// GenericFactory.sol
contract GenericFactory {
    struct DeploymentParams {
        // Core integrations
        address evc;
        address protocolConfig;
        address oracle;
        address unitOfAccount;
        address asset;

        // Modules
        address moduleToken;
        address moduleVault;
        address moduleBorrowing;
        address moduleLiquidation;
        address moduleRiskManager;
        address moduleBalanceForwarder;
        address moduleGovernance;
        address moduleInitialize;
    }

    function deploy(DeploymentParams calldata params) external returns (address vault);
}
```

## EVC Integration

EVault inherits from EVCUtil for EVC integration:

```solidity
// EVCUtil.sol
abstract contract EVCUtil {
    IEVC public immutable evc;

    // Get authenticated caller from EVC context
    function msgSender() internal view returns (address) {
        if (msg.sender == address(evc)) {
            (address onBehalfOf, bool controllerEnabled) =
                evc.getCurrentOnBehalfOfAccount(address(this));
            return onBehalfOf;
        }
        return msg.sender;
    }

    // Schedule status checks
    function requireAccountStatusCheck(address account) internal {
        evc.requireAccountStatusCheck(account);
    }

    function requireVaultStatusCheck() internal {
        evc.requireVaultStatusCheck(address(this));
    }
}
```

## Cache System

Vault uses caching to optimize gas during multi-step operations:

```solidity
// Cache.sol
struct VaultCache {
    // Snapshot state
    uint48 lastInterestAccumulatorUpdate;
    uint144 interestAccumulator;

    // Current state
    uint72 totalShares;
    uint168 totalBorrows;
    uint256 cash;

    // Config
    address interestRateModel;
    uint16 interestFee;

    // Computed
    uint256 borrowAPY;
    uint256 supplyAPY;
}

abstract contract Cache {
    function loadVault() internal view returns (VaultCache memory cache);
    function updateVault(VaultCache memory cache) internal;
    function initOperation(uint32 operationFlags) internal returns (VaultCache memory);
}
```

## Key Design Decisions

1. **Modular Architecture**: Separate contracts for each concern
   - Easier upgrades (deploy new modules)
   - Code size optimization
   - Clear separation of concerns

2. **Delegatecall Dispatch**: All modules share vault's storage
   - Single storage layout
   - No cross-contract state sync

3. **EVC as Single Entry Point**: Most operations go through EVC
   - Consistent authentication
   - Deferred checks for batching

4. **Debt Token Separation**: DToken is view-only wrapper
   - Tracks debt in vault storage
   - Enables debt transfer market

## Reference Files

- `euler-vault-kit/src/EVault/EVault.sol` - Main dispatcher
- `euler-vault-kit/src/EVault/Dispatch.sol` - Dispatch modifiers
- `euler-vault-kit/src/EVault/shared/Base.sol` - Shared storage
- `euler-vault-kit/src/EVault/modules/*.sol` - Individual modules
- `euler-vault-kit/src/EVault/DToken.sol` - Debt token
