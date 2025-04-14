---
name: Comet Configurator
description: This skill should be used when the user asks about "Configurator", "governance", "governor", "setConfiguration", "deploy", "CometFactory", "market admin", or needs to understand Comet's governance and upgrade system.
version: 0.1.0
---

# Comet Configurator

The Configurator contract manages Comet configuration and deploys new implementations. Most Comet parameters are immutable, so configuration changes require deploying a new implementation and upgrading the proxy.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                 CONFIGURATOR SYSTEM                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Governance Flow:                                            │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                                                         │ │
│  │  Governor ──► Configurator ──► CometFactory             │ │
│  │                    │                │                   │ │
│  │         setConfiguration()    clone(config)             │ │
│  │         setBorrowKink()            │                    │ │
│  │         addAsset()                 ▼                    │ │
│  │                           New Comet Implementation      │ │
│  │                                    │                    │ │
│  │  Timelock ─────────────────────────┘                    │ │
│  │         │                                               │ │
│  │         ▼                                               │ │
│  │  Comet Proxy ──► upgrade(newImplementation)             │ │
│  │                                                         │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  Key: Most params are immutable - changes require redeploy   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Configurator Contract

```solidity
// contracts/Configurator.sol
contract Configurator is ConfiguratorStorage {
    // Storage for each Comet proxy's configuration
    mapping(address => Configuration) public configuratorParams;

    // Factory for each Comet proxy
    mapping(address => address) public factory;

    address public governor;

    // MarketAdmin can update certain parameters
    MarketAdminPermissionCheckerInterface public marketAdminPermissionChecker;

    modifier governorOrMarketAdmin {
        if (msg.sender != governor) {
            marketAdminPermissionChecker.checkUpdatePermission(msg.sender);
        }
        _;
    }
}
```

## Initialize

```solidity
/// @notice Initialize the Configurator (for proxy)
function initialize(address governor_) public {
    if (version != 0) revert AlreadyInitialized();
    if (governor_ == address(0)) revert InvalidAddress();

    governor = governor_;
    version = 1;
}
```

## Set Full Configuration

```solidity
/// @notice Set entire configuration for a Comet proxy
/// @dev baseToken and trackingIndexScale cannot be changed once set
function setConfiguration(address cometProxy, Configuration calldata newConfiguration) external {
    if (msg.sender != governor) revert Unauthorized();

    Configuration memory oldConfiguration = configuratorParams[cometProxy];

    // Prevent changing immutable params after initial setup
    if (oldConfiguration.baseToken != address(0) &&
        (oldConfiguration.baseToken != newConfiguration.baseToken ||
         oldConfiguration.trackingIndexScale != newConfiguration.trackingIndexScale))
        revert ConfigurationAlreadyExists();

    configuratorParams[cometProxy] = newConfiguration;
    emit SetConfiguration(cometProxy, oldConfiguration, newConfiguration);
}
```

## Governor-Only Parameters

```solidity
// Set factory for deploying new implementations
function setFactory(address cometProxy, address newFactory) external {
    if (msg.sender != governor) revert Unauthorized();
    address oldFactory = factory[cometProxy];
    factory[cometProxy] = newFactory;
    emit SetFactory(cometProxy, oldFactory, newFactory);
}

// Set the Comet governor
function setGovernor(address cometProxy, address newGovernor) external {
    if (msg.sender != governor) revert Unauthorized();
    address oldGovernor = configuratorParams[cometProxy].governor;
    configuratorParams[cometProxy].governor = newGovernor;
    emit SetGovernor(cometProxy, oldGovernor, newGovernor);
}

// Set pause guardian
function setPauseGuardian(address cometProxy, address newPauseGuardian) external {
    if (msg.sender != governor) revert Unauthorized();
    address oldPauseGuardian = configuratorParams[cometProxy].pauseGuardian;
    configuratorParams[cometProxy].pauseGuardian = newPauseGuardian;
    emit SetPauseGuardian(cometProxy, oldPauseGuardian, newPauseGuardian);
}

// Set base token price feed
function setBaseTokenPriceFeed(address cometProxy, address newBaseTokenPriceFeed) external {
    if (msg.sender != governor) revert Unauthorized();
    address oldBaseTokenPriceFeed = configuratorParams[cometProxy].baseTokenPriceFeed;
    configuratorParams[cometProxy].baseTokenPriceFeed = newBaseTokenPriceFeed;
    emit SetBaseTokenPriceFeed(cometProxy, oldBaseTokenPriceFeed, newBaseTokenPriceFeed);
}

// Set extension delegate (CometExt)
function setExtensionDelegate(address cometProxy, address newExtensionDelegate) external {
    if (msg.sender != governor) revert Unauthorized();
    address oldExtensionDelegate = configuratorParams[cometProxy].extensionDelegate;
    configuratorParams[cometProxy].extensionDelegate = newExtensionDelegate;
    emit SetExtensionDelegate(cometProxy, oldExtensionDelegate, newExtensionDelegate);
}

// Set storefront price factor (liquidation discount distribution)
function setStoreFrontPriceFactor(address cometProxy, uint64 newStoreFrontPriceFactor) external {
    if (msg.sender != governor) revert Unauthorized();
    uint64 oldStoreFrontPriceFactor = configuratorParams[cometProxy].storeFrontPriceFactor;
    configuratorParams[cometProxy].storeFrontPriceFactor = newStoreFrontPriceFactor;
    emit SetStoreFrontPriceFactor(cometProxy, oldStoreFrontPriceFactor, newStoreFrontPriceFactor);
}

// Set minimum base for rewards
function setBaseMinForRewards(address cometProxy, uint104 newBaseMinForRewards) external {
    if (msg.sender != governor) revert Unauthorized();
    uint104 oldBaseMinForRewards = configuratorParams[cometProxy].baseMinForRewards;
    configuratorParams[cometProxy].baseMinForRewards = newBaseMinForRewards;
    emit SetBaseMinForRewards(cometProxy, oldBaseMinForRewards, newBaseMinForRewards);
}

// Set target reserves
function setTargetReserves(address cometProxy, uint104 newTargetReserves) external {
    if (msg.sender != governor) revert Unauthorized();
    uint104 oldTargetReserves = configuratorParams[cometProxy].targetReserves;
    configuratorParams[cometProxy].targetReserves = newTargetReserves;
    emit SetTargetReserves(cometProxy, oldTargetReserves, newTargetReserves);
}
```

## Market Admin Parameters

Certain parameters can be updated by market admins (not just governor):

```solidity
// Interest rate model
function setSupplyKink(address cometProxy, uint64 newSupplyKink) external governorOrMarketAdmin {
    uint64 oldSupplyKink = configuratorParams[cometProxy].supplyKink;
    configuratorParams[cometProxy].supplyKink = newSupplyKink;
    emit SetSupplyKink(cometProxy, oldSupplyKink, newSupplyKink);
}

function setSupplyPerYearInterestRateSlopeLow(address cometProxy, uint64 newSlope) external governorOrMarketAdmin {
    uint64 oldSlope = configuratorParams[cometProxy].supplyPerYearInterestRateSlopeLow;
    configuratorParams[cometProxy].supplyPerYearInterestRateSlopeLow = newSlope;
    emit SetSupplyPerYearInterestRateSlopeLow(cometProxy, oldSlope, newSlope);
}

function setSupplyPerYearInterestRateSlopeHigh(address cometProxy, uint64 newSlope) external governorOrMarketAdmin {
    // Similar pattern...
}

function setSupplyPerYearInterestRateBase(address cometProxy, uint64 newBase) external governorOrMarketAdmin {
    // Similar pattern...
}

// Same for borrow rates
function setBorrowKink(address cometProxy, uint64 newBorrowKink) external governorOrMarketAdmin;
function setBorrowPerYearInterestRateSlopeLow(address cometProxy, uint64 newSlope) external governorOrMarketAdmin;
function setBorrowPerYearInterestRateSlopeHigh(address cometProxy, uint64 newSlope) external governorOrMarketAdmin;
function setBorrowPerYearInterestRateBase(address cometProxy, uint64 newBase) external governorOrMarketAdmin;

// Reward speeds
function setBaseTrackingSupplySpeed(address cometProxy, uint64 newSpeed) external governorOrMarketAdmin {
    uint64 oldSpeed = configuratorParams[cometProxy].baseTrackingSupplySpeed;
    configuratorParams[cometProxy].baseTrackingSupplySpeed = newSpeed;
    emit SetBaseTrackingSupplySpeed(cometProxy, oldSpeed, newSpeed);
}

function setBaseTrackingBorrowSpeed(address cometProxy, uint64 newSpeed) external governorOrMarketAdmin;

// Minimum borrow
function setBaseBorrowMin(address cometProxy, uint104 newBaseBorrowMin) external governorOrMarketAdmin;

// Collateral factors
function updateAssetBorrowCollateralFactor(address cometProxy, address asset, uint64 newBorrowCF)
    external governorOrMarketAdmin;
function updateAssetLiquidateCollateralFactor(address cometProxy, address asset, uint64 newLiquidateCF)
    external governorOrMarketAdmin;
function updateAssetLiquidationFactor(address cometProxy, address asset, uint64 newLiquidationFactor)
    external governorOrMarketAdmin;
function updateAssetSupplyCap(address cometProxy, address asset, uint128 newSupplyCap)
    external governorOrMarketAdmin;
```

## Asset Management

```solidity
/// @notice Add a new collateral asset
function addAsset(address cometProxy, AssetConfig calldata assetConfig) external {
    if (msg.sender != governor) revert Unauthorized();

    configuratorParams[cometProxy].assetConfigs.push(assetConfig);
    emit AddAsset(cometProxy, assetConfig);
}

/// @notice Update entire asset configuration
function updateAsset(address cometProxy, AssetConfig calldata newAssetConfig) external {
    if (msg.sender != governor) revert Unauthorized();

    uint assetIndex = getAssetIndex(cometProxy, newAssetConfig.asset);
    AssetConfig memory oldAssetConfig = configuratorParams[cometProxy].assetConfigs[assetIndex];
    configuratorParams[cometProxy].assetConfigs[assetIndex] = newAssetConfig;
    emit UpdateAsset(cometProxy, oldAssetConfig, newAssetConfig);
}

/// @notice Update asset price feed
function updateAssetPriceFeed(address cometProxy, address asset, address newPriceFeed) external {
    if (msg.sender != governor) revert Unauthorized();

    uint assetIndex = getAssetIndex(cometProxy, asset);
    address oldPriceFeed = configuratorParams[cometProxy].assetConfigs[assetIndex].priceFeed;
    configuratorParams[cometProxy].assetConfigs[assetIndex].priceFeed = newPriceFeed;
    emit UpdateAssetPriceFeed(cometProxy, asset, oldPriceFeed, newPriceFeed);
}

/// @dev Get index of asset in config array
function getAssetIndex(address cometProxy, address asset) public view returns (uint) {
    AssetConfig[] memory assetConfigs = configuratorParams[cometProxy].assetConfigs;
    for (uint i = 0; i < assetConfigs.length; ) {
        if (assetConfigs[i].asset == asset) {
            return i;
        }
        unchecked { i++; }
    }
    revert AssetDoesNotExist();
}
```

## Deploy New Implementation

```solidity
/// @notice Deploy a new Comet implementation using factory
/// @dev Callable by anyone - governance must then upgrade the proxy
function deploy(address cometProxy) external returns (address) {
    address newComet = CometFactory(factory[cometProxy]).clone(configuratorParams[cometProxy]);
    emit CometDeployed(cometProxy, newComet);
    return newComet;
}
```

## CometFactory

```solidity
// contracts/CometFactory.sol
contract CometFactory {
    /// @notice Deploy a new Comet implementation
    function clone(Configuration calldata config) external returns (address) {
        return address(new Comet(config));
    }
}
```

## View Functions

```solidity
/// @notice Get current configuration for a Comet proxy
function getConfiguration(address cometProxy) external view returns (Configuration memory) {
    return configuratorParams[cometProxy];
}
```

## Governor Transfer

```solidity
/// @notice Transfer governor rights
function transferGovernor(address newGovernor) external {
    if (msg.sender != governor) revert Unauthorized();
    address oldGovernor = governor;
    governor = newGovernor;
    emit GovernorTransferred(oldGovernor, newGovernor);
}
```

## Market Admin Permission Checker

```solidity
/// @notice Set the permission checker for market admins
function setMarketAdminPermissionChecker(
    MarketAdminPermissionCheckerInterface newMarketAdminPermissionChecker
) external {
    if (msg.sender != governor) revert Unauthorized();
    address old = address(marketAdminPermissionChecker);
    marketAdminPermissionChecker = newMarketAdminPermissionChecker;
    emit SetMarketAdminPermissionChecker(old, address(newMarketAdminPermissionChecker));
}
```

## Upgrade Process

```
┌──────────────────────────────────────────────────────────────┐
│                  UPGRADE WORKFLOW                            │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Governor updates configuration in Configurator           │
│     configurator.setBorrowKink(cometProxy, newKink)          │
│                                                              │
│  2. Deploy new implementation via factory                    │
│     newImpl = configurator.deploy(cometProxy)                │
│                                                              │
│  3. Governor creates proposal to upgrade proxy               │
│     proposal = [                                             │
│       cometProxyAdmin.upgrade(cometProxy, newImpl)           │
│     ]                                                        │
│                                                              │
│  4. After timelock delay, execute upgrade                    │
│     timelock.execute(proposal)                               │
│                                                              │
│  5. Proxy now points to new implementation                   │
│     All state preserved; new immutables active               │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Events

```solidity
event AddAsset(address indexed cometProxy, AssetConfig assetConfig);
event CometDeployed(address indexed cometProxy, address indexed newComet);
event GovernorTransferred(address indexed oldGovernor, address indexed newGovernor);
event SetFactory(address indexed cometProxy, address indexed oldFactory, address indexed newFactory);
event SetGovernor(address indexed cometProxy, address indexed oldGovernor, address indexed newGovernor);
event SetConfiguration(address indexed cometProxy, Configuration oldConfiguration, Configuration newConfiguration);
event SetPauseGuardian(address indexed cometProxy, address indexed oldPauseGuardian, address indexed newPauseGuardian);
event SetMarketAdminPermissionChecker(address indexed old, address indexed newChecker);
event SetBaseTokenPriceFeed(address indexed cometProxy, address indexed old, address indexed newFeed);
event SetExtensionDelegate(address indexed cometProxy, address indexed old, address indexed newExt);
event SetSupplyKink(address indexed cometProxy, uint64 oldKink, uint64 newKink);
// ... many more events for each parameter
```

## Reference Files

- `contracts/Configurator.sol` - Main configurator
- `contracts/ConfiguratorStorage.sol` - Storage layout
- `contracts/CometFactory.sol` - Implementation factory
- `contracts/CometConfiguration.sol` - Configuration structs
- `contracts/marketupdates/MarketAdminPermissionCheckerInterface.sol` - Permission interface
