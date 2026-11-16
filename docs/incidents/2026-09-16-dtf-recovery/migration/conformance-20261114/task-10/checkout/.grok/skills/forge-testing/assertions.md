# Foundry Assertions Reference

Assertions from forge-std's Test contract for validating test conditions.

## Equality Assertions

### assertEq

Assert two values are equal.

```solidity
assertEq(a, b);
assertEq(a, b, "values should be equal");

// Works with many types:
assertEq(uint256(1), uint256(1));
assertEq(address(0x1), address(0x1));
assertEq(bytes32(0), bytes32(0));
assertEq(myString, "expected");
assertEq(myBytes, hex"1234");
```

### assertNotEq

Assert two values are not equal.

```solidity
assertNotEq(a, b);
assertNotEq(a, b, "values should differ");
```

### Array Equality

```solidity
uint256[] memory expected = new uint256[](2);
expected[0] = 1;
expected[1] = 2;
assertEq(actual, expected);
```

## Comparison Assertions

### assertGt

Assert greater than.

```solidity
assertGt(a, b); // a > b
assertGt(a, b, "a should be greater than b");
```

### assertGe

Assert greater than or equal.

```solidity
assertGe(a, b); // a >= b
```

### assertLt

Assert less than.

```solidity
assertLt(a, b); // a < b
```

### assertLe

Assert less than or equal.

```solidity
assertLe(a, b); // a <= b
```

## Approximate Equality

For testing with acceptable margins (useful for calculations with rounding).

### assertApproxEqAbs

Assert approximate equality with absolute delta.

```solidity
// Pass if |a - b| <= maxDelta
assertApproxEqAbs(a, b, maxDelta);
assertApproxEqAbs(calculated, expected, 1); // Allow 1 wei difference
```

### assertApproxEqRel

Assert approximate equality with relative delta (percentage).

```solidity
// Pass if |a - b| <= b * maxPercentDelta / 1e18
assertApproxEqRel(a, b, 0.01e18); // 1% tolerance
assertApproxEqRel(a, b, 0.001e18); // 0.1% tolerance
```

### assertApproxEqAbsDecimal

Same as assertApproxEqAbs but formats output with decimals.

```solidity
assertApproxEqAbsDecimal(a, b, maxDelta, 18); // Show as 18 decimal token
```

### assertApproxEqRelDecimal

Same as assertApproxEqRel but formats output with decimals.

```solidity
assertApproxEqRelDecimal(a, b, 0.01e18, 18);
```

## Boolean Assertions

### assertTrue

Assert condition is true.

```solidity
assertTrue(condition);
assertTrue(balance > 0, "balance should be positive");
```

### assertFalse

Assert condition is false.

```solidity
assertFalse(condition);
assertFalse(paused, "contract should not be paused");
```

## Failure Assertions

### fail

Unconditionally fail the test.

```solidity
if (unexpectedCondition) {
    fail("Should not reach here");
}

// With reason
fail("Unexpected state");
```

## Common Testing Patterns

### Checking Balance Changes

```solidity
uint256 balanceBefore = address(user).balance;
target.withdraw();
uint256 balanceAfter = address(user).balance;
assertEq(balanceAfter - balanceBefore, expectedAmount);
```

### Checking Token Balances

```solidity
uint256 balanceBefore = token.balanceOf(user);
target.deposit(amount);
assertEq(token.balanceOf(user), balanceBefore - amount);
```

### Checking State Changes

```solidity
assertEq(target.owner(), address(0)); // Before
target.initialize(newOwner);
assertEq(target.owner(), newOwner);   // After
```

### Testing Revert Messages

```solidity
vm.expectRevert("Insufficient balance");
target.withdraw(tooMuch);
// Test passes if it reverts with exact message
```

### Testing Custom Errors

```solidity
// For errors without parameters
vm.expectRevert(Unauthorized.selector);
target.adminFunction();

// For errors with parameters
vm.expectRevert(
    abi.encodeWithSelector(
        InsufficientBalance.selector,
        currentBalance,
        requestedAmount
    )
);
target.withdraw(requestedAmount);
```

### Testing Events

```solidity
vm.expectEmit(true, true, true, true);
emit Transfer(from, to, amount);
target.transfer(to, amount);
```

## Decimal Formatting

For clearer test output with token amounts:

```solidity
// These show values formatted with decimals in failure messages
assertEqDecimal(balance, 1000e18, 18); // Shows "1000" not "1000000000000000000000"
assertGtDecimal(balance, minAmount, 18);
assertLtDecimal(balance, maxAmount, 18);
```

## Tips

1. **Always add error messages for complex assertions**
   ```solidity
   assertEq(result, expected, "calculation should match expected value");
   ```

2. **Use appropriate assertion type**
   - `assertEq` for exact matches
   - `assertApproxEqAbs` for calculations with rounding
   - `assertApproxEqRel` for percentage-based tolerances

3. **Test both success and failure cases**
   ```solidity
   function test_Success() public { ... }
   function test_RevertWhen_Unauthorized() public {
       vm.expectRevert(Unauthorized.selector);
       target.adminFunction();
   }
   ```

4. **Use descriptive test names**
   - `test_Deposit_IncreasesBalance`
   - `test_RevertWhen_InsufficientFunds`
   - `test_EmitsTransferEvent`
