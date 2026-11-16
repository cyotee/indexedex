# Resupply Contract Reference

Complete list of Resupply protocol contracts organized by category.

## Core Infrastructure

| Contract | Path | Description |
|----------|------|-------------|
| Core | `/src/dao/Core.sol` | Central authority, operator permissions |
| ResupplyRegistry | `/src/protocol/ResupplyRegistry.sol` | Protocol address registry |

## Token Contracts

| Contract | Path | Description |
|----------|------|-------------|
| Stablecoin | `/src/protocol/Stablecoin.sol` | reUSD token (OFT) |
| GovToken | `/src/dao/GovToken.sol` | RSUP governance token (OFT) |

## Lending System

| Contract | Path | Description |
|----------|------|-------------|
| ResupplyPair | `/src/protocol/ResupplyPair.sol` | Lending pair implementation |
| ResupplyPairCore | `/src/protocol/pair/ResupplyPairCore.sol` | Core lending logic |
| ResupplyPairDeployer | `/src/protocol/ResupplyPairDeployer.sol` | Pair factory |

## Risk Management

| Contract | Path | Description |
|----------|------|-------------|
| LiquidationHandler | `/src/protocol/LiquidationHandler.sol` | Liquidation processing |
| RedemptionHandler | `/src/protocol/RedemptionHandler.sol` | Collateral redemption |
| InsurancePool | `/src/protocol/InsurancePool.sol` | Bad debt coverage (reIP) |

## Interest & Oracles

| Contract | Path | Description |
|----------|------|-------------|
| InterestRateCalculator | `/src/protocol/InterestRateCalculator.sol` | Interest rate model |
| InterestRateCalculatorV2 | `/src/protocol/InterestRateCalculatorV2.sol` | Updated rate model |
| BasicVaultOracle | `/src/protocol/BasicVaultOracle.sol` | ERC4626 price oracle |
| UnderlyingOracle | `/src/protocol/UnderlyingOracle.sol` | Underlying asset prices |

## Reward Distribution

| Contract | Path | Description |
|----------|------|-------------|
| RewardHandler | `/src/protocol/RewardHandler.sol` | Central reward distribution |
| RewardDistributorMultiEpoch | `/src/protocol/RewardDistributorMultiEpoch.sol` | Multi-epoch reward tracking |
| MultiRewardsDistributor | `/src/dao/staking/MultiRewardsDistributor.sol` | Multi-token rewards |

## Governance & Staking

| Contract | Path | Description |
|----------|------|-------------|
| Voter | `/src/dao/Voter.sol` | DAO voting |
| GovStaker | `/src/dao/staking/GovStaker.sol` | RSUP staking |
| GovStakerEscrow | `/src/dao/staking/GovStakerEscrow.sol` | Locked staking |

## DAO Operators

| Contract | Path | Description |
|----------|------|-------------|
| Guardian | `/src/dao/operators/Guardian.sol` | Emergency controls |
| TreasuryManager | `/src/dao/operators/TreasuryManager.sol` | Treasury management |
| BorrowLimitController | `/src/dao/operators/BorrowLimitController.sol` | Borrow limits |
| PairAdder | `/src/dao/operators/PairAdder.sol` | Pair management |

## Token Generation & Vesting

| Contract | Path | Description |
|----------|------|-------------|
| VestManager | `/src/dao/tge/VestManager.sol` | Vesting management |
| VestManagerBase | `/src/dao/tge/VestManagerBase.sol` | Vesting base |
| PermaStaker | `/src/dao/tge/PermaStaker.sol` | Permanent staking |
| EmissionsController | `/src/dao/emissions/EmissionsController.sol` | Token emissions |

## External Integrations

| Contract | Path | Description |
|----------|------|-------------|
| CurveLendMinterFactory | `/src/protocol/integrations/` | Curve Lend integration |
| CurveLendOperator | `/src/protocol/integrations/` | Curve Lend operations |

## Interfaces

Key interfaces for integration:

- `IResupplyPair` - Lending pair interface
- `ICore` - Core contract interface
- `IResupplyRegistry` - Registry interface
- `IStablecoin` - Stablecoin interface
- `IGovStaker` - Staking interface
- `IVoter` - Governance interface
- `IRewardHandler` - Rewards interface
- `IInsurancePool` - Insurance interface

## Registry Handler Keys

```solidity
bytes32 constant PAIR_DEPLOYER = keccak256("PAIR_DEPLOYER");
bytes32 constant LIQUIDATION_HANDLER = keccak256("LIQUIDATION_HANDLER");
bytes32 constant REDEMPTION_HANDLER = keccak256("REDEMPTION_HANDLER");
bytes32 constant REWARD_HANDLER = keccak256("REWARD_HANDLER");
bytes32 constant INSURANCE_POOL = keccak256("INSURANCE_POOL");
bytes32 constant GOV_STAKER = keccak256("GOV_STAKER");
bytes32 constant VOTER = keccak256("VOTER");
```
