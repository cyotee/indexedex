---
name: Aave V4 Position Manager
description: This skill should be used when the user asks about "position manager", "gateway", "NativeTokenGateway", "SignatureGateway", "onBehalfOf", "meta-transactions", or needs to understand Aave V4's gateway contracts.
version: 0.1.0
---

# Aave V4 Position Manager

Position Managers are gateway contracts that operate on users' positions with their authorization. They enable meta-transactions, native token handling, and composability.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                   POSITION MANAGERS                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Direct User Interaction:                                    │
│  User ──────────────────────────────────────────► Spoke      │
│                                                              │
│  Via Position Manager:                                       │
│  User ─► Position Manager ─► Spoke ─► Hub                    │
│       (authorized)      (onBehalfOf=user)                    │
│                                                              │
│  Common Position Managers:                                   │
│  • NativeTokenGateway - ETH ↔ WETH wrapping                  │
│  • SignatureGateway - EIP-712 meta-transactions              │
│  • Custom - Integrator-specific logic                        │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Authorization System

### Position Manager Modifier

```solidity
modifier onlyPositionManager(address onBehalfOf) {
    require(_isPositionManager({user: onBehalfOf, manager: msg.sender}), Unauthorized());
    _;
}

function _isPositionManager(address user, address manager) internal view returns (bool) {
    // User is always their own position manager
    if (user == manager) return true;

    // Check if user has approved this manager
    return _positionManager[manager].approvedForUser[user];
}
```

### Approving Position Managers

```solidity
/// @notice Approve/revoke a position manager
function setUserPositionManager(address manager, bool approved) external {
    _positionManager[manager].approvedForUser[msg.sender] = approved;
    emit SetUserPositionManager(msg.sender, manager, approved);
}

/// @notice Check if manager is approved for user
function isPositionManager(address user, address manager) external view returns (bool) {
    return _isPositionManager(user, manager);
}
```

### EIP-712 Signature Approval

```solidity
bytes32 public constant SET_USER_POSITION_MANAGER_TYPEHASH =
    keccak256('SetUserPositionManager(address positionManager,address user,bool approve,uint256 nonce,uint256 deadline)');

/// @notice Approve position manager via signature
function setUserPositionManagerWithSig(
    address positionManager,
    address user,
    bool approve,
    uint256 deadline,
    bytes calldata signature
) external {
    require(block.timestamp <= deadline, ExpiredSignature());

    bytes32 structHash = keccak256(abi.encode(
        SET_USER_POSITION_MANAGER_TYPEHASH,
        positionManager,
        user,
        approve,
        _useNonce(user),
        deadline
    ));

    bytes32 digest = _hashTypedData(structHash);
    require(SignatureChecker.isValidSignatureNow(user, digest, signature), InvalidSignature());

    _positionManager[positionManager].approvedForUser[user] = approve;
    emit SetUserPositionManager(user, positionManager, approve);
}
```

## NativeTokenGateway

Handles ETH ↔ WETH wrapping for native token operations:

```solidity
contract NativeTokenGateway is GatewayBase, INativeTokenGateway {
    ISpoke public immutable SPOKE;
    IWETH public immutable WETH;
    uint256 public immutable RESERVE_ID;

    constructor(address spoke_, address weth_, uint256 reserveId_) {
        SPOKE = ISpoke(spoke_);
        WETH = IWETH(weth_);
        RESERVE_ID = reserveId_;
    }

    /// @notice Supply ETH (wraps to WETH)
    function supplyNative(address onBehalfOf) external payable {
        // Wrap ETH to WETH
        WETH.deposit{value: msg.value}();

        // Approve Spoke
        WETH.approve(address(SPOKE), msg.value);

        // Supply on behalf of user
        SPOKE.supply(RESERVE_ID, msg.value, onBehalfOf);
    }

    /// @notice Withdraw to ETH (unwraps WETH)
    function withdrawNative(uint256 amount, address onBehalfOf) external {
        // Withdraw WETH (comes to this contract)
        SPOKE.withdraw(RESERVE_ID, amount, onBehalfOf);

        // Unwrap WETH to ETH
        WETH.withdraw(amount);

        // Send ETH to caller
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, TransferFailed());
    }

    /// @notice Borrow and receive ETH
    function borrowNative(uint256 amount, address onBehalfOf) external {
        // Borrow WETH (comes to this contract)
        SPOKE.borrow(RESERVE_ID, amount, onBehalfOf);

        // Unwrap to ETH
        WETH.withdraw(amount);

        // Send to caller
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, TransferFailed());
    }

    /// @notice Repay with ETH
    function repayNative(address onBehalfOf) external payable {
        // Wrap ETH
        WETH.deposit{value: msg.value}();

        // Approve Spoke
        WETH.approve(address(SPOKE), msg.value);

        // Repay on behalf of user
        SPOKE.repay(RESERVE_ID, msg.value, onBehalfOf);
    }

    receive() external payable {
        require(msg.sender == address(WETH), OnlyWETH());
    }
}
```

## SignatureGateway

Enables meta-transactions via EIP-712 signatures:

```solidity
contract SignatureGateway is GatewayBase, EIP712, NoncesKeyed {
    ISpoke public immutable SPOKE;

    bytes32 public constant SUPPLY_TYPEHASH = keccak256(
        'Supply(uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
    );

    bytes32 public constant BORROW_TYPEHASH = keccak256(
        'Borrow(uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
    );

    /// @notice Supply with user signature
    function supplyWithSig(
        uint256 reserveId,
        uint256 amount,
        address onBehalfOf,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, ExpiredSignature());

        bytes32 structHash = keccak256(abi.encode(
            SUPPLY_TYPEHASH,
            reserveId,
            amount,
            onBehalfOf,
            _useNonce(onBehalfOf),
            deadline
        ));

        require(
            SignatureChecker.isValidSignatureNow(onBehalfOf, _hashTypedData(structHash), signature),
            InvalidSignature()
        );

        // Transfer tokens from signer to this contract
        address underlying = SPOKE.getReserveUnderlying(reserveId);
        IERC20(underlying).safeTransferFrom(onBehalfOf, address(this), amount);

        // Approve and supply
        IERC20(underlying).approve(address(SPOKE), amount);
        SPOKE.supply(reserveId, amount, onBehalfOf);
    }

    /// @notice Borrow with user signature
    function borrowWithSig(
        uint256 reserveId,
        uint256 amount,
        address onBehalfOf,
        address receiver,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, ExpiredSignature());

        bytes32 structHash = keccak256(abi.encode(
            BORROW_TYPEHASH,
            reserveId,
            amount,
            onBehalfOf,
            _useNonce(onBehalfOf),
            deadline
        ));

        require(
            SignatureChecker.isValidSignatureNow(onBehalfOf, _hashTypedData(structHash), signature),
            InvalidSignature()
        );

        // Borrow on behalf of signer
        SPOKE.borrow(reserveId, amount, onBehalfOf);

        // Send borrowed tokens to receiver
        address underlying = SPOKE.getReserveUnderlying(reserveId);
        IERC20(underlying).safeTransfer(receiver, amount);
    }
}
```

## GatewayBase

Common base for gateway contracts:

```solidity
abstract contract GatewayBase {
    /// @notice Rescue tokens stuck in gateway
    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    /// @notice Rescue ETH stuck in gateway
    function rescueETH(address to, uint256 amount) external onlyOwner {
        (bool success, ) = to.call{value: amount}("");
        require(success, TransferFailed());
    }
}
```

## Custom Position Manager Example

```solidity
/// @notice Custom Position Manager for leveraged positions
contract LeverageManager is GatewayBase {
    ISpoke public immutable SPOKE;

    /// @notice Create leveraged position in one transaction
    function leverageUp(
        uint256 collateralReserveId,
        uint256 borrowReserveId,
        uint256 initialAmount,
        uint256 leverage // e.g., 2x = 2e18
    ) external {
        address collateralAsset = SPOKE.getReserveUnderlying(collateralReserveId);
        address borrowAsset = SPOKE.getReserveUnderlying(borrowReserveId);

        // Transfer initial collateral from user
        IERC20(collateralAsset).safeTransferFrom(msg.sender, address(this), initialAmount);

        // Calculate borrow amount for desired leverage
        uint256 borrowAmount = initialAmount.wadMul(leverage - WadRayMath.WAD);

        // Supply initial collateral
        IERC20(collateralAsset).approve(address(SPOKE), initialAmount);
        SPOKE.supply(collateralReserveId, initialAmount, msg.sender);

        // Borrow
        SPOKE.borrow(borrowReserveId, borrowAmount, msg.sender);

        // Swap borrowed asset for collateral (via DEX)
        uint256 additionalCollateral = _swap(borrowAsset, collateralAsset, borrowAmount);

        // Supply additional collateral
        IERC20(collateralAsset).approve(address(SPOKE), additionalCollateral);
        SPOKE.supply(collateralReserveId, additionalCollateral, msg.sender);
    }
}
```

## Usage Flow

```
┌──────────────────────────────────────────────────────────────┐
│                POSITION MANAGER FLOW                         │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Step 1: User authorizes Position Manager                    │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ spoke.setUserPositionManager(gateway, true)            │  │
│  │ // or via EIP-712 signature                            │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  Step 2: User calls Position Manager                         │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ gateway.supplyNative{value: 1 ether}(user)             │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  Step 3: Position Manager calls Spoke                        │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ spoke.supply(reserveId, amount, user)                  │  │
│  │ // msg.sender = gateway, onBehalfOf = user             │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  Step 4: Spoke validates & executes                          │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ require(_isPositionManager(user, gateway)) ✓           │  │
│  │ // Position updated for user                           │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Security Considerations

```
┌──────────────────────────────────────────────────────────────┐
│              SECURITY CONSIDERATIONS                         │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  For Users:                                                  │
│  • Only approve trusted Position Managers                    │
│  • Review permissions before approving                       │
│  • Can revoke anytime via setUserPositionManager(false)      │
│                                                              │
│  For Integrators:                                            │
│  • Position Managers have full control of user positions     │
│  • Implement proper access control                           │
│  • Handle edge cases (reverts, reentrancy)                   │
│  • Consider token approvals carefully                        │
│                                                              │
│  For Protocol:                                               │
│  • Gateway contracts are external to core protocol           │
│  • Core contracts (Hub, Spoke) are minimally affected        │
│  • Signature replay protection via nonces                    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Events

```solidity
// Spoke events
event SetUserPositionManager(
    address indexed user,
    address indexed positionManager,
    bool approved
);

// Gateway-specific events
event SupplyNative(address indexed user, uint256 amount);
event WithdrawNative(address indexed user, uint256 amount);
event BorrowNative(address indexed user, uint256 amount);
event RepayNative(address indexed user, uint256 amount);
```

## Reference Files

- `src/position-manager/GatewayBase.sol` - Base gateway
- `src/position-manager/NativeTokenGateway.sol` - ETH gateway
- `src/position-manager/SignatureGateway.sol` - Meta-tx gateway
- `src/position-manager/interfaces/` - Gateway interfaces
- `src/spoke/Spoke.sol` - Position manager authorization
