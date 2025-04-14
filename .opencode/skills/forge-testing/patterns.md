# Foundry Testing Patterns

Common patterns and best practices for writing Foundry tests.

## Test File Organization

### Standard Structure

```
test/
├── MyContract.t.sol        # Unit tests for MyContract
├── Integration.t.sol       # Integration tests
├── Fork.t.sol              # Fork tests against mainnet
├── invariants/
│   └── MyContract.invariants.t.sol
└── mocks/
    └── MockOracle.sol
```

### Test Contract Structure

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {MyContract} from "../src/MyContract.sol";

contract MyContractTest is Test {
    // ============ State Variables ============
    MyContract public target;
    address public alice;
    address public bob;
    address public admin;

    // ============ Events (for expectEmit) ============
    event Deposited(address indexed user, uint256 amount);

    // ============ Setup ============
    function setUp() public {
        // Create labeled addresses
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        admin = makeAddr("admin");

        // Deploy contract
        vm.prank(admin);
        target = new MyContract();

        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    // ============ Unit Tests ============
    function test_InitialState() public view {
        assertEq(target.owner(), admin);
    }

    // ============ Access Control Tests ============
    function test_RevertWhen_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        target.adminFunction();
    }
}
```

## Testing Access Control

### Owner-Only Functions

```solidity
function test_OwnerCanCall() public {
    vm.prank(admin);
    target.setFee(100);
    assertEq(target.fee(), 100);
}

function test_RevertWhen_NonOwnerCalls() public {
    vm.prank(alice);
    vm.expectRevert("Ownable: caller is not the owner");
    target.setFee(100);
}
```

### Role-Based Access

```solidity
function test_RevertWhen_MissingRole() public {
    vm.prank(alice);
    vm.expectRevert(
        abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector,
            alice,
            MINTER_ROLE
        )
    );
    target.mint(alice, 100);
}

function test_CanCallWithRole() public {
    vm.prank(admin);
    target.grantRole(MINTER_ROLE, alice);

    vm.prank(alice);
    target.mint(bob, 100);
    assertEq(target.balanceOf(bob), 100);
}
```

## Testing Token Operations

### ERC20 Transfers

```solidity
function test_Transfer() public {
    uint256 amount = 100e18;
    deal(address(token), alice, amount);

    uint256 aliceBalanceBefore = token.balanceOf(alice);
    uint256 bobBalanceBefore = token.balanceOf(bob);

    vm.prank(alice);
    token.transfer(bob, amount);

    assertEq(token.balanceOf(alice), aliceBalanceBefore - amount);
    assertEq(token.balanceOf(bob), bobBalanceBefore + amount);
}
```

### Approval Flow

```solidity
function test_TransferFrom() public {
    uint256 amount = 100e18;
    deal(address(token), alice, amount);

    // Alice approves Bob
    vm.prank(alice);
    token.approve(bob, amount);

    // Bob transfers from Alice
    vm.prank(bob);
    token.transferFrom(alice, bob, amount);

    assertEq(token.balanceOf(bob), amount);
}
```

## Testing ETH Operations

### Deposits

```solidity
function test_Deposit() public {
    uint256 amount = 1 ether;

    vm.prank(alice);
    target.deposit{value: amount}();

    assertEq(target.balanceOf(alice), amount);
    assertEq(address(target).balance, amount);
}
```

### Withdrawals

```solidity
function test_Withdraw() public {
    // Setup: deposit first
    vm.prank(alice);
    target.deposit{value: 1 ether}();

    uint256 balanceBefore = alice.balance;

    vm.prank(alice);
    target.withdraw(1 ether);

    assertEq(alice.balance, balanceBefore + 1 ether);
}
```

## Testing Events

### Single Event

```solidity
function test_EmitsDepositEvent() public {
    vm.expectEmit(true, true, true, true);
    emit Deposited(alice, 1 ether);

    vm.prank(alice);
    target.deposit{value: 1 ether}();
}
```

### Multiple Events

```solidity
function test_EmitsMultipleEvents() public {
    vm.expectEmit(true, true, true, true);
    emit Approval(alice, address(target), 100);

    vm.expectEmit(true, true, true, true);
    emit Transfer(alice, address(target), 100);

    vm.prank(alice);
    target.depositToken(100);
}
```

## Testing Time-Dependent Logic

### Time Locks

```solidity
function test_RevertWhen_TimeLockNotExpired() public {
    vm.prank(alice);
    target.initiateWithdrawal(100);

    // Try to complete before timelock
    vm.prank(alice);
    vm.expectRevert("Timelock not expired");
    target.completeWithdrawal();
}

function test_WithdrawAfterTimelock() public {
    vm.prank(alice);
    target.initiateWithdrawal(100);

    // Skip past timelock
    skip(7 days);

    vm.prank(alice);
    target.completeWithdrawal();
    // Assert withdrawal completed
}
```

### Vesting

```solidity
function test_VestingSchedule() public {
    uint256 totalAmount = 1000e18;
    uint256 vestingDuration = 365 days;

    vm.prank(admin);
    target.createVesting(alice, totalAmount, vestingDuration);

    // At start: nothing vested
    assertEq(target.vestedAmount(alice), 0);

    // After half the duration: half vested
    skip(vestingDuration / 2);
    assertApproxEqAbs(target.vestedAmount(alice), totalAmount / 2, 1);

    // After full duration: all vested
    skip(vestingDuration / 2);
    assertEq(target.vestedAmount(alice), totalAmount);
}
```

## Fork Testing

### Basic Fork Test

```solidity
contract ForkTest is Test {
    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createSelectFork("mainnet");
    }

    function test_InteractWithUniswap() public {
        IUniswapV2Router router = IUniswapV2Router(UNISWAP_ROUTER);

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        vm.deal(address(this), 1 ether);

        router.swapExactETHForTokens{value: 1 ether}(
            0,
            path,
            address(this),
            block.timestamp
        );

        assertGt(IERC20(USDC).balanceOf(address(this)), 0);
    }
}
```

### Fork at Specific Block

```solidity
function setUp() public {
    // Fork at specific block for reproducible tests
    vm.createSelectFork("mainnet", 18_000_000);
}
```

### Multi-Chain Fork

```solidity
uint256 mainnetFork;
uint256 arbitrumFork;

function setUp() public {
    mainnetFork = vm.createFork("mainnet");
    arbitrumFork = vm.createFork("arbitrum");
}

function test_CrossChainScenario() public {
    vm.selectFork(mainnetFork);
    // Test on mainnet

    vm.selectFork(arbitrumFork);
    // Test on arbitrum
}
```

## Testing with Mocks

### Mock Contract

```solidity
contract MockOracle is IOracle {
    int256 public price;

    function setPrice(int256 _price) external {
        price = _price;
    }

    function latestAnswer() external view returns (int256) {
        return price;
    }
}

contract MyContractTest is Test {
    MockOracle oracle;

    function setUp() public {
        oracle = new MockOracle();
        oracle.setPrice(1000e8);
        target = new MyContract(address(oracle));
    }
}
```

### Using vm.mockCall

```solidity
function test_WithMockedOracle() public {
    vm.mockCall(
        address(oracle),
        abi.encodeWithSelector(IOracle.latestAnswer.selector),
        abi.encode(int256(2000e8))
    );

    // target will see oracle price as 2000e8
    uint256 result = target.calculateValue(100);
    assertEq(result, 200000);
}
```

## State Management

### Using Snapshots

```solidity
function test_MultipleScenarios() public {
    // Setup base state
    vm.prank(alice);
    target.deposit{value: 10 ether}();

    uint256 snapshot = vm.snapshot();

    // Scenario 1
    vm.prank(alice);
    target.withdraw(5 ether);
    assertEq(target.balanceOf(alice), 5 ether);

    // Reset to snapshot
    vm.revertTo(snapshot);

    // Scenario 2 from same starting point
    vm.prank(alice);
    target.withdrawAll();
    assertEq(target.balanceOf(alice), 0);
}
```

## Common Anti-Patterns to Avoid

### Don't hardcode addresses in tests

```solidity
// Bad
address user = 0x1234567890123456789012345678901234567890;

// Good
address user = makeAddr("user");
```

### Don't forget to prank before user actions

```solidity
// Bad - runs as test contract
target.deposit{value: 1 ether}();

// Good - runs as alice
vm.prank(alice);
target.deposit{value: 1 ether}();
```

### Don't use magic numbers

```solidity
// Bad
assertEq(result, 1000000000000000000);

// Good
assertEq(result, 1 ether);
assertEq(result, 1e18);
```

### Don't skip error message assertions

```solidity
// Bad - any revert passes
vm.expectRevert();
target.withdraw(tooMuch);

// Good - specific error required
vm.expectRevert("Insufficient balance");
target.withdraw(tooMuch);
```
