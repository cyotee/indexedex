---
name: forge-fuzz-testing
description: Property-based testing with Foundry's fuzzer. Use when writing fuzz tests, invariant tests, or testing edge cases. Covers fuzz test structure, input constraints, fixtures, and invariant testing patterns.
---

# Forge Fuzz Testing

Property-based testing using Foundry's built-in fuzzer to test contract behavior across many inputs.

## When to Use

- Testing mathematical operations for edge cases
- Finding unexpected inputs that break invariants
- Testing boundary conditions automatically
- Verifying properties hold across all valid inputs
- Security testing for unexpected behaviors

## Quick Start

Any test function with parameters becomes a fuzz test:

```solidity
// Regular test - one specific case
function test_Withdraw() public {
    target.deposit{value: 1 ether}();
    target.withdraw(1 ether);
}

// Fuzz test - 256 random cases by default
function testFuzz_Withdraw(uint256 amount) public {
    vm.deal(address(this), amount);
    target.deposit{value: amount}();
    target.withdraw(amount);
    assertEq(address(target).balance, 0);
}
```

## Interpreting Results

```
[PASS] testFuzz_Withdraw(uint256) (runs: 256, μ: 28453, ~: 28453)
```

| Symbol | Meaning |
|--------|---------|
| `runs` | Number of test cases executed |
| `μ` (mu) | Mean gas consumption |
| `~` (tilde) | Median gas consumption |

## Input Constraints

### Using vm.assume

Filter out invalid inputs:

```solidity
function testFuzz_Divide(uint256 a, uint256 b) public {
    vm.assume(b != 0); // Skip division by zero
    uint256 result = target.divide(a, b);
    assertEq(result, a / b);
}
```

### Using bound

Constrain inputs to a range (preferred over assume for efficiency):

```solidity
function testFuzz_Deposit(uint256 amount) public {
    // Bound amount between 1 wei and 100 ether
    amount = bound(amount, 1, 100 ether);

    vm.deal(address(this), amount);
    target.deposit{value: amount}();
    assertEq(target.balanceOf(address(this)), amount);
}
```

### Combining Constraints

```solidity
function testFuzz_Transfer(address to, uint256 amount) public {
    // Filter invalid addresses
    vm.assume(to != address(0));
    vm.assume(to != address(target));

    // Bound amount
    amount = bound(amount, 1, token.balanceOf(address(this)));

    token.transfer(to, amount);
}
```

## Test Fixtures

Define specific values that must be tested:

### Array Fixtures

```solidity
// These values will definitely be tested
uint256[] public fixtureAmount = [0, 1, type(uint256).max];
address[] public fixtureRecipient;

constructor() {
    fixtureRecipient.push(address(0));
    fixtureRecipient.push(address(1));
}

function testFuzz_EdgeCases(uint256 amount, address recipient) public {
    // Fuzzer includes fixture values plus random values
}
```

### Function Fixtures

```solidity
function fixtureAmount() public pure returns (uint256[] memory) {
    uint256[] memory amounts = new uint256[](3);
    amounts[0] = 0;
    amounts[1] = 1;
    amounts[2] = type(uint256).max;
    return amounts;
}
```

## Configuration

### foundry.toml Settings

```toml
[fuzz]
runs = 256              # Number of fuzz runs (default: 256)
max_test_rejects = 65536  # Max rejected inputs before failing
seed = "0x1234"         # Deterministic seed for reproducibility
dictionary_weight = 40  # Weight for dictionary-based inputs
```

### Per-Test Configuration

```solidity
/// forge-config: default.fuzz.runs = 1000
function testFuzz_HighRuns(uint256 x) public {
    // This test runs 1000 times
}
```

## Invariant Testing

See [invariants.md](invariants.md) for comprehensive invariant testing patterns.

### Basic Structure

```solidity
contract MyInvariantTest is Test {
    MyContract target;
    Handler handler;

    function setUp() public {
        target = new MyContract();
        handler = new Handler(target);

        // Tell fuzzer which contract to call
        targetContract(address(handler));
    }

    // Invariant functions start with "invariant_"
    function invariant_TotalSupplyMatchesBalances() public {
        uint256 totalFromBalances = handler.sumOfAllBalances();
        assertEq(target.totalSupply(), totalFromBalances);
    }
}

// Handler wraps calls to bound inputs
contract Handler is Test {
    MyContract target;
    address[] public actors;

    constructor(MyContract _target) {
        target = _target;
        actors.push(makeAddr("alice"));
        actors.push(makeAddr("bob"));
    }

    function deposit(uint256 actorIndex, uint256 amount) public {
        actorIndex = bound(actorIndex, 0, actors.length - 1);
        amount = bound(amount, 0, 10 ether);

        address actor = actors[actorIndex];
        vm.deal(actor, amount);
        vm.prank(actor);
        target.deposit{value: amount}();
    }
}
```

## Common Fuzz Testing Patterns

### Testing Mathematical Properties

```solidity
// Commutative property
function testFuzz_AdditionCommutative(uint128 a, uint128 b) public {
    assertEq(a + b, b + a);
}

// Associative property
function testFuzz_AdditionAssociative(uint64 a, uint64 b, uint64 c) public {
    assertEq((a + b) + c, a + (b + c));
}

// Identity property
function testFuzz_MultiplicationIdentity(uint256 a) public {
    assertEq(a * 1, a);
}
```

### Testing Reversibility

```solidity
function testFuzz_DepositWithdrawRoundTrip(uint256 amount) public {
    amount = bound(amount, 1, 100 ether);
    vm.deal(address(this), amount);

    uint256 balanceBefore = address(this).balance;

    target.deposit{value: amount}();
    target.withdraw(amount);

    assertEq(address(this).balance, balanceBefore);
}
```

### Testing Encoding/Decoding

```solidity
function testFuzz_EncodeDecode(
    address addr,
    uint256 amount,
    bytes32 data
) public {
    bytes memory encoded = target.encode(addr, amount, data);
    (address decodedAddr, uint256 decodedAmount, bytes32 decodedData) =
        target.decode(encoded);

    assertEq(decodedAddr, addr);
    assertEq(decodedAmount, amount);
    assertEq(decodedData, data);
}
```

### Testing Against Reference Implementation

```solidity
function testFuzz_MatchesReference(uint256 a, uint256 b) public {
    vm.assume(b != 0);

    uint256 optimized = target.optimizedDivide(a, b);
    uint256 reference = a / b; // Simple reference

    assertEq(optimized, reference);
}
```

## Running Fuzz Tests

```bash
# Run all tests (including fuzz)
forge test

# Run with more fuzz runs
forge test --fuzz-runs 1000

# Run specific fuzz test
forge test --match-test testFuzz_Withdraw

# Run with seed for reproducibility
forge test --fuzz-seed 0x1234

# Show fuzz input on failure
forge test -vvvv
```

## Debugging Failures

When a fuzz test fails, Foundry shows the failing input:

```
[FAIL. Reason: assertion failed; counterexample: calldata=0x... args=[12345]]
```

### Reproduce the failure

```solidity
function test_ReproduceFailure() public {
    // Use the exact failing input
    testFuzz_MyFunction(12345);
}
```

### Shrinking

Foundry automatically tries to find the smallest failing input.
