---
name: reliquary-deployment
description: This skill should be used when the user asks to "deploy Reliquary", "add a Reliquary pool", "set up rolling rewarder", "create relic", "deposit into Reliquary", "withdraw from Reliquary", or needs practical guidance on deploying and interacting with Reliquary smart contracts.
license: MIT
---

# Reliquary Deployment & Usage

## Deployment Approaches

### 1. Direct Deployment (Tests / Development)

Reliquary is a standard non-Diamond contract. Deploy it directly with `new`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Reliquary} from "@crane/contracts/protocols/staking/reliquary/v1/Reliquary.sol";
import {LinearCurve} from "@crane/contracts/protocols/staking/reliquary/v1/curves/LinearCurve.sol";
import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";

contract MyReliquaryDeploy {
    function deploy() external {
        // 1. Deploy reward token (any ERC20)
        MockERC20 rewardToken = new MockERC20("Reward", "RWD", 18);

        // 2. Deploy Reliquary — deployer gets DEFAULT_ADMIN_ROLE
        Reliquary reliquary = new Reliquary({
            _rewardToken: address(rewardToken),
            _emissionRate: 1e18,       // 1 reward token per second
            _name: "Reliquary Deposit",
            _symbol: "RELIC"
        });

        // 3. Fund Reliquary with reward tokens (must have balance to pay rewards)
        rewardToken.mint(address(this), 1_000_000e18);
        rewardToken.transfer(address(reliquary), 1_000_000e18);

        // 4. Deploy a curve for the pool
        LinearCurve curve = new LinearCurve({
            _slope: 100,                // multiplier increases by 100 per second
            _minMultiplier: 365 days * 100  // f(0) = 365e5 (no lock = 100% annual boost)
        });

        // 5. Approve Reliquary to spend pool token (for addPool bootstrap)
        MockERC20 poolToken = new MockERC20("Pool", "POOL", 18);
        poolToken.mint(address(this), 1_000_000e18);
        poolToken.approve(address(reliquary), type(uint256).max);

        // 6. Add pool — triggers 1 wei bootstrap deposit (caller must hold + approve 1 wei)
        reliquary.addPool({
            _allocPoint: 100,
            _poolToken: address(poolToken),
            _rewarder: address(0),           // or address of ParentRollingRewarder
            _curve: curve,
            _name: "My Pool",
            _nftDescriptor: address(0),
            _allowPartialWithdrawals: true,
            _to: address(this)               // receives the bootstrap 1 wei Relic
        });

        // 7. Create a Relic and deposit actual tokens
        poolToken.approve(address(reliquary), type(uint256).max);
        uint256 relicId = reliquary.createRelicAndDeposit({
            _to: address(this),
            _poolId: 0,
            _amount: 1000e18
        });
    }
}
```

### 2. Deterministic Deployment (Crane Create3Factory)

For production with deterministic addresses, use Crane's `Create3Factory`:

```solidity
// Deploy Reliquary deterministically via Create3Factory
ICreate3FactoryProxy create3Factory = ...; // from InitDevService.initEnv()

bytes memory initArgs = abi.encode(
    address(rewardToken),   // _rewardToken
    1e18,                   // _emissionRate
    "Reliquary Deposit",     // _name
    "RELIC"                 // _symbol
);

// Salt derived from type name (Crane convention)
bytes32 salt = keccak256(abi.encode("Reliquary"));

address reliquaryAddr = create3Factory.deploy(
    type(Reliquary).creationCode,
    initArgs,
    salt
);
vm.label(reliquaryAddr, "Reliquary");
```

---

## Adding a Pool

### Prerequisites

Before calling `addPool`, the caller must:

1. **Have `DEFAULT_ADMIN_ROLE`** on Reliquary
2. **Hold at least 1 unit** of the pool token
3. **Have approved** Reliquary to spend that 1 unit

```solidity
// Approve and add pool
IERC20(poolToken).approve(address(reliquary), type(uint256).max);
reliquary.addPool({
    _allocPoint: 100,
    _poolToken: address(poolToken),
    _rewarder: address(0),
    _curve: curve,
    _name: "ETH/USDC LP",
    _nftDescriptor: nftDescriptor,
    _allowPartialWithdrawals: true,
    _to: address(dao)      // DAO receives the bootstrap Relic
});
```

### Pool with Rolling Rewarder

```solidity
// 1. Deploy ParentRollingRewarder first (its owner will manage children)
ParentRollingRewarder rewarder = new ParentRollingRewarder();

// 2. Add pool with rewarder — Reliquary calls rewarder.initialize(poolId)
reliquary.addPool({
    _allocPoint: 100,
    _poolToken: address(poolToken),
    _rewarder: address(rewarder),
    _curve: curve,
    _name: "My Pool",
    _nftDescriptor: address(0),
    _allowPartialWithdrawals: true,
    _to: address(this)
});

// 3. As rewarder owner: create a child for each reward token
address child = rewarder.createChild(address(rewardToken));

// 4. Fund the child — owner approves and calls fund()
IERC20(rewardToken).approve(child, type(uint256).max);
RollingRewarder(child).fund(100_000e18);

// 5. Optionally set distribution period before funding
RollingRewarder(child).updateDistributionPeriod(30 days);
```

---

## User Operations

### Deposit into Existing Relic

```solidity
// Approve Reliquary to spend your pool tokens
IERC20(poolToken).approve(address(reliquary), type(uint256).max);

// Deposit and harvest rewards in one transaction
reliquary.deposit({
    _amount: 500e18,
    _relicId: 1,
    _harvestTo: address(this)  // non-zero = harvest too
});
```

### Create New Relic + Deposit

```solidity
uint256 relicId = reliquary.createRelicAndDeposit({
    _to: address(this),
    _poolId: 0,
    _amount: 1000e18
});
```

### Withdraw + Harvest

```solidity
reliquary.withdraw({
    _amount: 200e18,
    _relicId: 1,
    _harvestTo: address(this)  // harvests rewards while withdrawing
});
```

### Harvest Only (No Deposit/Withdraw)

```solidity
reliquary.update({
    _relicId: 1,
    _harvestTo: address(this)   // non-zero address triggers harvest
});
```

### Split a Relic

```solidity
// Requires allowPartialWithdrawals == true for this pool
uint256 newId = reliquary.split({
    _relicId: 1,
    _amount: 100e18,
    _to: address(otherPerson)
});
```

### Merge Two Relics

```solidity
// Both relics must be in the same pool
reliquary.merge({
    _fromId: 2,
    _toId: 1   // burns fromId, moves all amount into toId
});
```

### Burn Empty Relic

```solidity
// Can only burn if amount == 0 AND no pending rewards
reliquary.burn(relicId);
```

---

## Using Deposit Helpers

For pools with ERC4626 vault or Reaper vault poolTokens, use the helpers instead of direct Reliquary calls.

### ERC4626 Vault Pool

```solidity
// Deploy helper
DepositHelperERC4626 helper = new DepositHelperERC4626({
    _reliquary: reliquary,
    _weth: address(weth)
});

// Approve helper to pull underlying (e.g., USDC)
IERC20(underlying).approve(address(helper), type(uint256).max);

// Create relic + deposit underlying (helper converts to vault shares, deposits to Reliquary)
uint256 relicId = helper.createRelicAndDeposit{value: 0}(0, amount);

// Withdraw — optionally as ETH
helper.withdraw(amount, relicId, harvest, withdrawAsETH);

// Deposit ETH directly
uint256 relicId = helper.createRelicAndDeposit{value: 1 ether}(0, 1 ether);
```

### Reaper Vault Pool

```solidity
DepositHelperReaperVault helper = new DepositHelperReaperVault({
    _reliquary: reliquary,
    _weth: address(weth)
});

// Approve underlying token
IERC20(underlying).approve(address(helper), type(uint256).max);

// Deposit
(uint256 relicId, uint256 shares) = helper.createRelicAndDeposit(0, amount);

// Withdraw underlying (optionally as ETH)
helper.withdraw(amount, relicId, harvest, asETH);
```

---

## Important Constraints

### Reward Funding
Reliquary pays rewards from its own balance. If `rewardToken.balanceOf(reliquary) < pendingReward`, users receive less than shown in `pendingReward()`. **Keep Reliquary funded** by topping up its balance periodically.

### Partial Withdrawals
If `allowPartialWithdrawals == false`:
- Users cannot withdraw less than their full position
- `split()` and `shift()` are disabled

### Pool Token Restrictions
- Pool token cannot be the reward token (reverts in `addPool`)
- Pool token `totalSupply()` must be ≤ `100e9 ether`

### Curve Constraints
- `curve.getFunction(0)` must be > 0
- 10-year projection must not overflow: `emissionRate * 10years * ACC_REWARD_PRECISION * curve.getFunction(10years)` checked at `addPool` time

### Max Pools
Pool IDs are `uint8` — maximum 255 pools per Reliquary.

---

## Testing Pattern (Crane)

Use `TestBase_Reliquary` for tests:

```solidity
contract MyReliquaryTest is TestBase_Reliquary {
    function testDeposit() public {
        // Inherits: reliquary, linearCurve, rewardToken, poolToken, etc.
        // setUp() already: deploys Reliquary, adds pool 0 with linearCurve
        
        uint256 relicId = _createAndDeposit(0, 1000e18);
        assertEq(reliquary.getPositionForId(relicId).amount, 1000e18);
    }
}
```

For ERC4626/Reaper vault pools, extend `TestBase_Reliquary`:

```solidity
contract MyERC4626PoolTest is TestBase_Reliquary {
    DepositHelperERC4626 helper;
    IERC4626 vault;
    MockERC20 oath;
    WETH9 weth;

    function setUp() public override {
        TestBase_Reliquary.setUp();
        
        oath = new MockERC20("Oath", "OATH", 18);
        Reliquary r = new Reliquary(address(oath), 1e17, "Rel", "REL");
        reliquary = IReliquary(address(r));
        
        weth = new WETH9();
        vault = new ERC4626Mock(address(weth), "Vault", "VLT", 18);
        linearCurve = new LinearCurve(100, 365 days * 100);
        
        // ... add pool with vault as poolToken
    }
}
```

---

## See Also

- `skill:reliquary-architecture` — conceptual model, curves, rewarders
- `contracts/protocols/staking/reliquary/v1/test/bases/TestBase_Reliquary.sol` — test deployment pattern
- `contracts/protocols/staking/reliquary/v1/helpers/` — helper contracts for ERC4626/Reaper/BPT pools
