# Foundry Invariant Testing

Invariant testing verifies properties that must always hold true, regardless of the sequence of actions taken.

## Core Concepts

**Invariants**: Properties that should never be violated. Examples:
- Total supply equals sum of all balances
- Contract balance >= sum of user deposits
- Owner cannot be address(0) after initialization

**Handlers**: Contracts that wrap target functions to bound inputs and manage state.

**Actors**: Addresses that perform actions (simulating multiple users).

## Basic Structure

```solidity
// test/invariants/MyContract.invariants.t.sol
contract MyContractInvariantTest is Test {
    MyContract public target;
    MyContractHandler public handler;

    function setUp() public {
        target = new MyContract();
        handler = new MyContractHandler(target);

        // Register handler as the target for fuzzing
        targetContract(address(handler));
    }

    // Invariant: Total deposited always matches contract balance
    function invariant_SolvencyCheck() public view {
        assertGe(
            address(target).balance,
            handler.ghost_totalDeposited()
        );
    }

    // Invariant: No user can have negative balance (will revert if violated)
    function invariant_NoNegativeBalances() public view {
        for (uint256 i = 0; i < handler.actorCount(); i++) {
            address actor = handler.actors(i);
            assertGe(target.balanceOf(actor), 0);
        }
    }
}
```

## Handler Pattern

```solidity
contract MyContractHandler is Test {
    MyContract public target;

    // Actors (simulated users)
    address[] public actors;
    address internal currentActor;

    // Ghost variables track state for invariant checks
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalWithdrawn;
    mapping(address => uint256) public ghost_userDeposits;

    // Call tracking
    mapping(bytes32 => uint256) public calls;

    constructor(MyContract _target) {
        target = _target;

        // Create actors
        actors.push(makeAddr("alice"));
        actors.push(makeAddr("bob"));
        actors.push(makeAddr("charlie"));

        // Fund actors
        for (uint256 i = 0; i < actors.length; i++) {
            vm.deal(actors[i], 100 ether);
        }
    }

    // ============ Utility Functions ============

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    // ============ Handler Functions ============

    function deposit(uint256 actorSeed, uint256 amount)
        public
        useActor(actorSeed)
        countCall("deposit")
    {
        amount = bound(amount, 0, currentActor.balance);
        if (amount == 0) return;

        target.deposit{value: amount}();

        // Update ghost variables
        ghost_totalDeposited += amount;
        ghost_userDeposits[currentActor] += amount;
    }

    function withdraw(uint256 actorSeed, uint256 amount)
        public
        useActor(actorSeed)
        countCall("withdraw")
    {
        uint256 balance = target.balanceOf(currentActor);
        amount = bound(amount, 0, balance);
        if (amount == 0) return;

        target.withdraw(amount);

        // Update ghost variables
        ghost_totalWithdrawn += amount;
        ghost_userDeposits[currentActor] -= amount;
    }
}
```

## Ghost Variables

Ghost variables track state that isn't directly stored in the target contract:

```solidity
contract Handler is Test {
    // Track cumulative values
    uint256 public ghost_totalMinted;
    uint256 public ghost_totalBurned;

    // Track per-user state
    mapping(address => uint256) public ghost_userMints;

    // Track call sequences
    bytes32[] public ghost_callSequence;

    function mint(uint256 actorSeed, uint256 amount) public {
        // ... mint logic ...

        ghost_totalMinted += amount;
        ghost_userMints[currentActor] += amount;
        ghost_callSequence.push("mint");
    }
}
```

## Configuration

### Target Selection

```solidity
function setUp() public {
    // Single handler
    targetContract(address(handler));

    // Multiple handlers
    targetContract(address(depositHandler));
    targetContract(address(withdrawHandler));

    // Exclude specific contracts
    excludeContract(address(token));

    // Target specific selectors only
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = Handler.deposit.selector;
    selectors[1] = Handler.withdraw.selector;
    targetSelector(FuzzSelector({
        addr: address(handler),
        selectors: selectors
    }));
}
```

### foundry.toml Settings

```toml
[invariant]
runs = 256           # Number of invariant test runs
depth = 15           # Calls per run
fail_on_revert = false  # Don't fail on handler reverts
shrink_run_limit = 5000  # Shrinking attempts
```

## Common Invariant Patterns

### Accounting Invariants

```solidity
// Sum of parts equals whole
function invariant_TotalSupplyMatchesBalances() public {
    uint256 sumOfBalances;
    for (uint256 i = 0; i < handler.actorCount(); i++) {
        sumOfBalances += token.balanceOf(handler.actors(i));
    }
    assertEq(token.totalSupply(), sumOfBalances);
}

// Conservation of value
function invariant_ConservationOfValue() public {
    assertEq(
        handler.ghost_totalDeposited(),
        handler.ghost_totalWithdrawn() + address(target).balance
    );
}
```

### State Invariants

```solidity
// Valid state transitions
function invariant_ValidState() public {
    MyContract.State state = target.currentState();
    assertTrue(
        state == MyContract.State.Active ||
        state == MyContract.State.Paused ||
        state == MyContract.State.Closed
    );
}

// Monotonic property (value only increases)
function invariant_MonotonicTimestamp() public {
    assertGe(target.lastUpdate(), handler.ghost_initialTimestamp());
}
```

### Access Control Invariants

```solidity
// Owner cannot be zero after initialization
function invariant_OwnerNeverZero() public {
    if (handler.ghost_initialized()) {
        assertTrue(target.owner() != address(0));
    }
}

// Admin count within bounds
function invariant_AdminCountBounded() public {
    assertLe(target.adminCount(), target.MAX_ADMINS());
}
```

### Protocol Invariants

```solidity
// AMM constant product
function invariant_ConstantProduct() public {
    uint256 reserve0 = pair.reserve0();
    uint256 reserve1 = pair.reserve1();
    uint256 k = reserve0 * reserve1;
    assertGe(k, handler.ghost_lastK());
}

// Lending protocol health
function invariant_HealthFactor() public {
    for (uint256 i = 0; i < handler.actorCount(); i++) {
        address user = handler.actors(i);
        if (protocol.hasDebt(user)) {
            assertGe(protocol.healthFactor(user), 1e18);
        }
    }
}
```

## Advanced Patterns

### Bounded Actor Pattern

```solidity
contract BoundedHandler is Test {
    address[] public actors;
    mapping(address => bool) public isActor;

    function createActor(uint256 seed) internal returns (address) {
        address actor = makeAddr(string(abi.encodePacked("actor", seed)));
        if (!isActor[actor]) {
            actors.push(actor);
            isActor[actor] = true;
        }
        return actor;
    }
}
```

### Time-Based Invariants

```solidity
contract TimeSensitiveHandler is Test {
    uint256 public ghost_timeElapsed;

    function warpTime(uint256 secondsSeed) public {
        uint256 warpAmount = bound(secondsSeed, 0, 365 days);
        skip(warpAmount);
        ghost_timeElapsed += warpAmount;
    }
}

function invariant_TimeConsistency() public {
    assertEq(
        block.timestamp,
        handler.ghost_initialTimestamp() + handler.ghost_timeElapsed()
    );
}
```

### Call Summary

```solidity
function invariant_callSummary() public view {
    console.log("deposit calls:", handler.calls("deposit"));
    console.log("withdraw calls:", handler.calls("withdraw"));
    console.log("total deposited:", handler.ghost_totalDeposited());
}
```

## Running Invariant Tests

```bash
# Run all invariant tests
forge test --match-contract Invariant

# Run with more depth
forge test --match-contract Invariant -vvv

# Specific configuration
forge test --match-contract Invariant \
    --invariant-runs 500 \
    --invariant-depth 50
```

## Debugging Failures

When an invariant fails, Foundry shows the call sequence:

```
[FAIL. Reason: assertion failed]
        [Sequence]
                sender=0x... addr=[handler] calldata=deposit(1,1000)
                sender=0x... addr=[handler] calldata=withdraw(1,2000)
```

### Reproduce with explicit test

```solidity
function test_ReproduceInvariantFailure() public {
    handler.deposit(1, 1000);
    handler.withdraw(1, 2000);
    invariant_SolvencyCheck(); // Should fail
}
```
