---
name: Aave V3 Flash Loans
description: This skill should be used when the user asks about "flash loan", "flashLoan", "flashLoanSimple", "FlashLoanLogic", "IFlashLoanReceiver", "flash borrower", or needs to understand Aave V3 flash loan functionality.
version: 0.1.0
---

# Aave V3 Flash Loans

Flash loans allow borrowing assets without collateral, provided the borrowed amount plus fee is returned within the same transaction. Aave V3 offers two flash loan variants: full-featured and simple.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                      FLASH LOAN FLOW                         │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. User calls Pool.flashLoan() or flashLoanSimple()         │
│                                                              │
│  2. Pool transfers requested assets to receiver              │
│                                                              │
│  3. Pool calls receiver.executeOperation()                   │
│     • Receiver has the borrowed funds                        │
│     • Receiver performs arbitrage, liquidation, etc.         │
│                                                              │
│  4. Receiver must return: borrowed + premium                 │
│     OR open debt position (modes 1/2)                        │
│                                                              │
│  5. If funds not returned, transaction reverts               │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Flash Loan Types

### flashLoan() - Full Featured

Supports multiple assets and debt modes:

```solidity
function flashLoan(
    address receiverAddress,        // Contract implementing IFlashLoanReceiver
    address[] calldata assets,      // Array of tokens to borrow
    uint256[] calldata amounts,     // Amount of each token
    uint256[] calldata interestRateModes,  // 0 = no debt, 2 = open variable debt
    address onBehalfOf,             // Who gets the debt (if mode != 0)
    bytes calldata params,          // Arbitrary data passed to receiver
    uint16 referralCode             // Referral tracking
) external;
```

### flashLoanSimple() - Gas Optimized

Single asset, must repay (no debt opening):

```solidity
function flashLoanSimple(
    address receiverAddress,    // Contract implementing IFlashLoanSimpleReceiver
    address asset,              // Single token to borrow
    uint256 amount,             // Amount to borrow
    bytes calldata params,      // Arbitrary data passed to receiver
    uint16 referralCode         // Referral tracking
) external;
```

## Interest Rate Modes

```solidity
// For flashLoan() interestRateModes array:
0 = NONE      // Must repay in same transaction
1 = DEPRECATED // Was stable rate (removed in V3.2)
2 = VARIABLE  // Open variable debt position instead of repaying
```

## Flash Loan Premiums

```solidity
// Premium rates (stored in Pool)
uint128 _flashLoanPremiumTotal;        // Total premium (e.g., 0.09%)
uint128 _flashLoanPremiumToProtocol;   // Protocol share (e.g., 0%)

// Default: 9 basis points (0.09%)
// Authorized flash borrowers can get 0 premium

// Example:
// Borrow 1000 USDC
// Premium = 1000 × 0.0009 = 0.9 USDC
// Must repay 1000.9 USDC
```

## IFlashLoanReceiver Interface

```solidity
interface IFlashLoanReceiver {
    /// @notice Executes the flash loan operation
    /// @param assets Array of borrowed asset addresses
    /// @param amounts Array of borrowed amounts
    /// @param premiums Array of premiums to pay
    /// @param initiator Address that initiated the flash loan
    /// @param params Arbitrary data passed from flashLoan call
    /// @return True if operation was successful
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool);

    function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);
    function POOL() external view returns (IPool);
}
```

## IFlashLoanSimpleReceiver Interface

```solidity
interface IFlashLoanSimpleReceiver {
    /// @notice Executes the simple flash loan operation
    /// @param asset Borrowed asset address
    /// @param amount Borrowed amount
    /// @param premium Premium to pay
    /// @param initiator Address that initiated the flash loan
    /// @param params Arbitrary data passed from flashLoanSimple call
    /// @return True if operation was successful
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);

    function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);
    function POOL() external view returns (IPool);
}
```

## FlashLoanLogic

```solidity
library FlashLoanLogic {
    function executeFlashLoan(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(uint8 => DataTypes.EModeCategory) storage eModeCategories,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.FlashloanParams memory params
    ) external {
        // Validate each asset is flashloanable
        for (uint256 i = 0; i < params.assets.length; i++) {
            ValidationLogic.validateFlashloan(
                reservesData[params.assets[i]].configuration
            );
        }

        // Calculate premiums
        uint256[] memory premiums = new uint256[](params.assets.length);
        uint256 totalPremium;

        for (uint256 i = 0; i < params.assets.length; i++) {
            if (params.isAuthorizedFlashBorrower) {
                premiums[i] = 0;  // Authorized borrowers get 0 premium
            } else {
                premiums[i] = params.amounts[i].percentMul(params.flashLoanPremiumTotal);
            }
        }

        // Transfer assets to receiver
        for (uint256 i = 0; i < params.assets.length; i++) {
            IAToken(reservesData[params.assets[i]].aTokenAddress)
                .transferUnderlyingTo(params.receiverAddress, params.amounts[i]);
        }

        // Call receiver
        require(
            IFlashLoanReceiver(params.receiverAddress).executeOperation(
                params.assets,
                params.amounts,
                premiums,
                msg.sender,
                params.params
            ),
            Errors.INVALID_FLASHLOAN_EXECUTOR_RETURN
        );

        // Handle repayment or debt opening
        for (uint256 i = 0; i < params.assets.length; i++) {
            if (params.interestRateModes[i] == 0) {
                // Mode 0: Must repay
                _handleFlashLoanRepayment(
                    reservesData[params.assets[i]],
                    params.assets[i],
                    params.amounts[i],
                    premiums[i],
                    params.receiverAddress
                );
            } else {
                // Mode 2: Open debt position
                BorrowLogic.executeBorrow(...);
            }
        }
    }

    function executeFlashLoanSimple(
        DataTypes.ReserveData storage reserve,
        DataTypes.FlashloanSimpleParams memory params
    ) external {
        ValidationLogic.validateFlashloanSimple(reserve.configuration);

        uint256 premium = params.amount.percentMul(params.flashLoanPremiumTotal);

        // Transfer to receiver
        IAToken(reserve.aTokenAddress).transferUnderlyingTo(
            params.receiverAddress,
            params.amount
        );

        // Call receiver
        require(
            IFlashLoanSimpleReceiver(params.receiverAddress).executeOperation(
                params.asset,
                params.amount,
                premium,
                msg.sender,
                params.params
            ),
            Errors.INVALID_FLASHLOAN_EXECUTOR_RETURN
        );

        // Handle repayment
        _handleFlashLoanRepayment(reserve, params.asset, params.amount, premium, params.receiverAddress);
    }
}
```

## Example Flash Loan Receiver

```solidity
contract MyFlashLoanReceiver is IFlashLoanSimpleReceiver {
    IPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
    IPool public immutable override POOL;

    constructor(IPoolAddressesProvider provider) {
        ADDRESSES_PROVIDER = provider;
        POOL = IPool(provider.getPool());
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        // Ensure caller is the Pool
        require(msg.sender == address(POOL), "Caller must be Pool");

        //
        // Your flash loan logic here
        // Examples:
        // - Arbitrage between DEXes
        // - Self-liquidation
        // - Collateral swap
        //

        // Calculate amount to repay
        uint256 amountOwed = amount + premium;

        // Approve Pool to pull funds
        IERC20(asset).approve(address(POOL), amountOwed);

        return true;
    }

    // Initiate flash loan
    function executeFlashLoan(address asset, uint256 amount) external {
        POOL.flashLoanSimple(
            address(this),  // receiver
            asset,
            amount,
            "",             // no params
            0               // no referral
        );
    }
}
```

## Authorized Flash Borrowers

Whitelisted addresses get 0 premium:

```solidity
// Check if address is authorized
function isFlashBorrower(address borrower) external view returns (bool);

// In ACLManager
function addFlashBorrower(address borrower) external onlyRole(POOL_ADMIN_ROLE);
function removeFlashBorrower(address borrower) external onlyRole(POOL_ADMIN_ROLE);
```

## Flash Loan with Debt Opening

```solidity
// Instead of repaying, open a debt position
// Useful for: collateral migration, leveraging up

Pool.flashLoan(
    receiverAddress,
    [USDC, DAI],           // assets to borrow
    [1000e6, 1000e18],     // amounts
    [2, 0],                // mode: USDC becomes debt, DAI must be repaid
    msg.sender,            // debt goes to caller
    abi.encode(...),       // params
    0
);

// After flash loan:
// - Caller has 1000 USDC variable debt
// - DAI was repaid with premium
```

## Validation

```solidity
function validateFlashloan(
    DataTypes.ReserveConfigurationMap memory configuration
) internal pure {
    require(!configuration.getPaused(), Errors.RESERVE_PAUSED);
    require(configuration.getActive(), Errors.RESERVE_INACTIVE);
    require(configuration.getFlashLoanEnabled(), Errors.FLASHLOAN_DISABLED);
}

// Additional validation for debt mode:
// - Check borrowing is enabled
// - Check health factor will remain >= 1
// - Check borrow cap not exceeded
```

## Flash Loan Configuration

```solidity
// Enable/disable flash loans for an asset
function setReserveFlashLoaning(
    address asset,
    bool enabled
) external onlyRiskAdmin;

// Update flash loan premium
function updateFlashloanPremiums(
    uint128 flashLoanPremiumTotal,
    uint128 flashLoanPremiumToProtocol
) external onlyPoolAdmin;

// Query premiums
function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);
function FLASHLOAN_PREMIUM_TO_PROTOCOL() external view returns (uint128);
```

## Common Use Cases

| Use Case | Description |
|----------|-------------|
| Arbitrage | Exploit price differences across DEXes |
| Self-Liquidation | Repay debt to avoid liquidation penalty |
| Collateral Swap | Change collateral type without closing position |
| Leveraged Positions | Open leveraged position in one transaction |
| Debt Refinancing | Move debt between protocols |

## Events

```solidity
event FlashLoan(
    address indexed target,
    address initiator,
    address indexed asset,
    uint256 amount,
    DataTypes.InterestRateMode interestRateMode,
    uint256 premium,
    uint16 indexed referralCode
);
```

## Reference Files

- `src/contracts/protocol/libraries/logic/FlashLoanLogic.sol` - Flash loan logic
- `src/contracts/misc/flashloan/base/FlashLoanSimpleReceiverBase.sol` - Receiver base
- `src/contracts/interfaces/IFlashLoanReceiver.sol` - Receiver interface
- `src/contracts/interfaces/IFlashLoanSimpleReceiver.sol` - Simple receiver interface
- `src/contracts/protocol/pool/Pool.sol` - flashLoan, flashLoanSimple
