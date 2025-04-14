# Foundry Cheatcodes Reference

Cheatcodes are special functions that manipulate blockchain state during testing. Access them via the `vm` instance from forge-std's Test contract.

## Caller & Identity

### vm.prank

Set `msg.sender` for the next call only.

```solidity
vm.prank(alice);
target.ownerOnlyFunction(); // msg.sender = alice
target.anotherFunction();   // msg.sender = test contract again
```

### vm.startPrank / vm.stopPrank

Set `msg.sender` for multiple calls.

```solidity
vm.startPrank(alice);
target.deposit();
target.withdraw();
target.transfer(bob, 100);
vm.stopPrank();
```

### vm.startPrank with origin

Set both `msg.sender` and `tx.origin`.

```solidity
vm.startPrank(alice, alice); // Both sender and origin are alice
```

### makeAddr

Create a labeled address from a name.

```solidity
address alice = makeAddr("alice");
address bob = makeAddr("bob");
// Addresses are deterministic and labeled in traces
```

### makeAddrAndKey

Create address and get private key.

```solidity
(address alice, uint256 alicePk) = makeAddrAndKey("alice");
```

## Balance & Value

### vm.deal

Set ETH balance for an address.

```solidity
vm.deal(alice, 10 ether);
assertEq(alice.balance, 10 ether);
```

### deal (ERC20)

Set ERC20 balance using storage manipulation.

```solidity
deal(address(token), alice, 1000e18);
// Also works with additional flag to update totalSupply:
deal(address(token), alice, 1000e18, true);
```

### hoax

Combines `prank` and `deal` - sets caller and gives them ETH.

```solidity
hoax(alice, 1 ether);
target.deposit{value: 1 ether}();
```

### startHoax

Combines `startPrank` and `deal`.

```solidity
startHoax(alice, 10 ether);
target.deposit{value: 1 ether}();
target.deposit{value: 1 ether}();
vm.stopPrank();
```

## Time & Block

### vm.warp

Set `block.timestamp`.

```solidity
vm.warp(1641070800); // Set to specific timestamp
vm.warp(block.timestamp + 1 days); // Skip forward
```

### vm.roll

Set `block.number`.

```solidity
vm.roll(15_000_000); // Set to specific block
vm.roll(block.number + 100); // Skip blocks
```

### skip

Skip forward in time (adds to timestamp).

```solidity
skip(1 days);
skip(1 hours);
```

### rewind

Go back in time (subtracts from timestamp).

```solidity
rewind(1 hours);
```

## Expecting Reverts

### vm.expectRevert

Assert the next call reverts.

```solidity
// Expect any revert
vm.expectRevert();
target.willRevert();

// Expect revert with string message
vm.expectRevert("Insufficient balance");
target.withdraw(tooMuch);

// Expect revert with bytes
vm.expectRevert(bytes("Insufficient balance"));
target.withdraw(tooMuch);

// Expect custom error (no parameters)
vm.expectRevert(Unauthorized.selector);
target.adminFunction();

// Expect custom error with parameters
vm.expectRevert(
    abi.encodeWithSelector(InsufficientBalance.selector, balance, amount)
);
target.withdraw(amount);
```

## Expecting Events

### vm.expectEmit

Assert an event is emitted with specific values.

```solidity
// Parameters: checkTopic1, checkTopic2, checkTopic3, checkData
vm.expectEmit(true, true, true, true);
emit Transfer(from, to, amount); // Expected event
target.transfer(to, amount);     // Actual call that should emit
```

```solidity
// Only check that the event is emitted (don't verify values)
vm.expectEmit();
emit Transfer(address(0), address(0), 0); // Placeholder values
target.transfer(to, amount);
```

### Multiple events

```solidity
vm.expectEmit(true, true, true, true);
emit Approval(owner, spender, amount);
vm.expectEmit(true, true, true, true);
emit Transfer(from, to, amount);
target.transferFrom(from, to, amount);
```

## Storage Manipulation

### vm.store

Write to a storage slot.

```solidity
vm.store(
    address(target),           // Contract address
    bytes32(uint256(0)),       // Slot number
    bytes32(uint256(100))      // New value
);
```

### vm.load

Read from a storage slot.

```solidity
bytes32 value = vm.load(address(target), bytes32(uint256(0)));
```

## Mocking

### vm.mockCall

Mock the return value of a call.

```solidity
vm.mockCall(
    address(oracle),
    abi.encodeWithSelector(IOracle.getPrice.selector),
    abi.encode(1000e8) // Return value
);
```

### vm.mockCall with value

Mock calls that send ETH.

```solidity
vm.mockCall(
    address(target),
    1 ether, // msg.value
    abi.encodeWithSelector(Target.deposit.selector),
    abi.encode(true)
);
```

### vm.clearMockedCalls

Remove all mocked calls.

```solidity
vm.clearMockedCalls();
```

## Snapshots

### vm.snapshot

Take a snapshot of current state.

```solidity
uint256 snapshotId = vm.snapshot();
```

### vm.revertTo

Revert to a snapshot.

```solidity
vm.revertTo(snapshotId);
```

## Environment & Config

### vm.envUint / vm.envAddress / vm.envString

Read environment variables.

```solidity
uint256 privateKey = vm.envUint("PRIVATE_KEY");
address deployer = vm.envAddress("DEPLOYER");
string memory rpcUrl = vm.envString("RPC_URL");

// With default value
uint256 forkBlock = vm.envOr("FORK_BLOCK", uint256(0));
```

### vm.setEnv

Set environment variable.

```solidity
vm.setEnv("MY_VAR", "value");
```

## Forking

### vm.createFork

Create a fork at latest block.

```solidity
uint256 forkId = vm.createFork("mainnet");
```

### vm.createSelectFork

Create and select a fork.

```solidity
vm.createSelectFork("mainnet");
vm.createSelectFork("mainnet", 15_000_000); // At specific block
```

### vm.selectFork

Switch between forks.

```solidity
uint256 mainnetFork = vm.createFork("mainnet");
uint256 arbitrumFork = vm.createFork("arbitrum");

vm.selectFork(mainnetFork);
// ... test on mainnet
vm.selectFork(arbitrumFork);
// ... test on arbitrum
```

### vm.rollFork

Roll the current fork to a different block.

```solidity
vm.rollFork(15_000_000);
```

## Labels & Debugging

### vm.label

Add a label to an address for better traces.

```solidity
vm.label(address(token), "USDC");
vm.label(alice, "Alice");
```

### vm.assume

Skip fuzz runs with invalid inputs.

```solidity
function testFuzz_Withdraw(uint256 amount) public {
    vm.assume(amount > 0);
    vm.assume(amount <= maxBalance);
    // Test with valid amounts only
}
```

### bound

Bound a fuzz input to a range.

```solidity
function testFuzz_Deposit(uint256 amount) public {
    amount = bound(amount, 1, 1000 ether);
    // amount is now between 1 and 1000 ether
}
```

## Gas

### vm.pauseGasMetering / vm.resumeGasMetering

Exclude setup from gas reports.

```solidity
vm.pauseGasMetering();
// Setup code not counted in gas
vm.resumeGasMetering();
// This code is measured
```

### vm.txGasPrice

Set `tx.gasprice`.

```solidity
vm.txGasPrice(100 gwei);
```

## Signing

### vm.sign

Sign a digest with a private key.

```solidity
(uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
```

### vm.signP256

Sign with P256 curve (for passkeys/WebAuthn).

```solidity
(bytes32 r, bytes32 s) = vm.signP256(privateKey, digest);
```
