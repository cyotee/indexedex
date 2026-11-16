---
name: resupply-architecture
description: This skill should be used when the user asks about "Resupply architecture", "Resupply protocol overview", "ResupplyRegistry", "Core contract", "operator pattern", "Resupply system design", or needs to understand how the Resupply protocol components connect together.
---

# Resupply Protocol Architecture

Resupply is a CDP-based (Collateralized Debt Position) stablecoin lending protocol enabling users to borrow reUSD stablecoins against ERC4626 vault tokens as collateral. The protocol integrates with Curve Lend, Frax Lend, Convex, and Yearn for yield-bearing collateral support.

## Core Components

### Core Contract (`/src/dao/Core.sol`)

The central authority contract managing system-wide configuration:

```solidity
// Key state variables
address public feeReceiver;           // Protocol fee recipient
uint256 public epochLength;           // Default: 1 week (604800 seconds)
uint256 public startTime;             // Protocol start timestamp

// Operator management
mapping(address operator => bool isEnabled) public operatorPermissions;
mapping(address operator => IAuthHook hook) public authHooks;
```

**Key functions:**
- `execute(address target, bytes calldata data)` - Execute calls through Core with operator permissions
- `setOperatorPermissions(address operator, bool enabled)` - Enable/disable operators
- `setAuthHook(address operator, IAuthHook hook)` - Set pre/post execution hooks

### ResupplyRegistry (`/src/protocol/ResupplyRegistry.sol`)

Single source of truth for all protocol addresses and deployed pairs:

```solidity
// Registry mappings
address[] public pairs;                          // All deployed lending pairs
mapping(address => bool) public isPair;          // Pair validation
mapping(bytes32 => address) public coreHandlers; // Named component lookup

// Core handler keys
bytes32 constant PAIR_DEPLOYER = keccak256("PAIR_DEPLOYER");
bytes32 constant LIQUIDATION_HANDLER = keccak256("LIQUIDATION_HANDLER");
bytes32 constant REDEMPTION_HANDLER = keccak256("REDEMPTION_HANDLER");
bytes32 constant REWARD_HANDLER = keccak256("REWARD_HANDLER");
bytes32 constant INSURANCE_POOL = keccak256("INSURANCE_POOL");
```

**Registry access pattern:**
```solidity
address deployer = registry.coreHandlers(PAIR_DEPLOYER);
address[] memory allPairs = registry.getAllPairs();
bool valid = registry.isPair(pairAddress);
```

## Operator Pattern

Operators are authorized contracts that can execute privileged actions through Core:

| Operator | Purpose |
|----------|---------|
| `Guardian` | Emergency pause, access control |
| `TreasuryManager` | Treasury fund management |
| `BorrowLimitController` | Dynamic borrow limit adjustments |
| `PairAdder` | Adding new lending pairs |
| `EmissionsController` | Governance token emissions |

**Auth Hook Pattern:**
```solidity
interface IAuthHook {
    function canCall(address caller, address target, bytes4 selector) external view returns (bool);
    function preHook(address caller, address target, bytes calldata data) external;
    function postHook(address caller, address target, bytes calldata data, bytes calldata result) external;
}
```

## Token Architecture

### reUSD Stablecoin (`/src/protocol/Stablecoin.sol`)

The protocol's native stablecoin with controlled minting:

```solidity
// LayerZero OFT for cross-chain support
contract Stablecoin is OFT {
    address public minter;  // Only minter can mint/burn

    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
}
```

### RSUP Governance Token (`/src/dao/GovToken.sol`)

Governance token for protocol voting and staking rewards:

```solidity
contract GovToken is OFT {
    address public minter;
    uint256 public maxMintable;  // Capped supply
}
```

## Precision Constants

All contracts use consistent precision values:

```solidity
uint256 constant LTV_PRECISION = 1e5;        // Loan-to-value ratios (95% = 95_000)
uint256 constant EXCHANGE_PRECISION = 1e18;  // Exchange rates
uint256 constant RATE_PRECISION = 1e18;      // Interest rates per second
uint256 constant PAIR_DECIMALS = 1e18;       // Token decimals assumption
```

## Epoch System

The protocol operates on weekly epochs for reward distribution and governance:

```solidity
uint256 constant EPOCH_LENGTH = 604800;  // 1 week in seconds

function getEpoch() public view returns (uint256) {
    return (block.timestamp - startTime) / epochLength;
}
```

## Integration Points

Resupply integrates with external protocols through pair deployers:

- **Curve Lend**: `CurveLendMinterFactory`, `CurveLendOperator`
- **Frax Lend**: Frax lending pair configurations
- **Convex**: CRV/CVX reward routing
- **LayerZero**: Cross-chain token bridging (OFT standard)

## Additional Resources

For a complete list of all protocol contracts with paths, see **`references/contracts.md`**.
