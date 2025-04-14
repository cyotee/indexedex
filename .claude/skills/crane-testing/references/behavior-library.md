# Behavior Library Guide

Behavior libraries encapsulate validation logic for interface compliance testing.

## Naming Convention

Libraries are named `Behavior_I{Interface}`:

- `Behavior_IERC165` - ERC165 interface validation
- `Behavior_IFacet` - IFacet interface validation
- `Behavior_IERC20` - ERC20 interface validation

## Structure

```solidity
library Behavior_IERC165 {
    using UInt256 for uint256;
    Vm constant vm = Vm(VM_ADDRESS);

    // Behavior name for logging
    function _Behavior_IERC165Name() internal pure returns (string memory) {
        return type(Behavior_IERC165).name;
    }

    // Error message helpers
    function funcSig_IERC165_supportsInterFace() public pure returns (string memory) {
        return "supportsInterFace(bytes4)";
    }
}
```

## Function Types

### expect_* Functions

Store expected values in ComparatorRepo for later validation:

```solidity
function expect_IERC165_supportsInterface(
    IERC165 subject,
    bytes4[] memory expectedInterfaces_
) public {
    console.logBehaviorEntry(_Behavior_IERC165Name(), "expect_IERC165_supportsInterface");
    Bytes4SetComparatorRepo._recExpectedBytes4(
        address(subject),
        IERC165.supportsInterface.selector,
        expectedInterfaces_
    );
    console.logBehaviorExit(_Behavior_IERC165Name(), "expect_IERC165_supportsInterface");
}
```

### isValid_* Functions

Compare expected vs actual directly, return boolean:

```solidity
function isValid_IERC165_supportsInterfaces(
    IERC165 subject,
    bool expected,
    bool actual
) public view returns (bool valid) {
    valid = expected == actual;
    if (!valid) {
        console.logBehaviorError(
            _Behavior_IERC165Name(),
            funcSig_IERC165_supportsInterFace(),
            abi.encode(expected),
            abi.encode(actual)
        );
    }
    return valid;
}
```

### areValid_* Functions

Validate arrays or sets of values:

```solidity
function areValid_IFacet_facetInterfaces(
    IFacet subject,
    bytes4[] memory expected,
    bytes4[] memory actual
) public view returns (bool) {
    if (expected.length != actual.length) return false;
    for (uint256 i = 0; i < expected.length; i++) {
        if (expected[i] != actual[i]) return false;
    }
    return true;
}
```

### hasValid_* Functions

Validate against stored expectations from expect_* calls:

```solidity
function hasValid_IERC165_supportsInterface(
    IERC165 subject
) public view returns (bool isValid_) {
    console.logBehaviorEntry(_Behavior_IERC165Name(), "hasValid_IERC165_supportsInterface");

    bytes4[] memory expected = _expected_IERC165_supportsInterface(subject);
    isValid_ = true;

    for (uint256 i = 0; i < expected.length; i++) {
        bytes4 interfaceId = expected[i];
        bool supports = subject.supportsInterface(interfaceId);
        if (!supports) {
            console.logBehaviorError(...);
            isValid_ = false;
        }
    }

    console.logBehaviorExit(_Behavior_IERC165Name(), "hasValid_IERC165_supportsInterface");
}
```

## Supporting Infrastructure

### ComparatorRepo

Stores expected values keyed by (address, selector):

```solidity
// Store expected bytes4 array
Bytes4SetComparatorRepo._recExpectedBytes4(
    address(subject),
    IERC165.supportsInterface.selector,
    expectedInterfaces
);

// Retrieve stored expectations
bytes4[] memory expected = Bytes4SetComparatorRepo._expectedBytes4(
    address(subject),
    IERC165.supportsInterface.selector
);
```

### console.logBehavior* Helpers

Structured logging for test debugging:

```solidity
console.logBehaviorEntry(behaviorName, functionName);
console.logBehaviorExit(behaviorName, functionName);
console.logBehaviorError(behaviorName, funcSig, expected, actual);
```

## Complete Example

```solidity
library Behavior_IMyInterface {
    using UInt256 for uint256;
    Vm constant vm = Vm(VM_ADDRESS);

    function _Behavior_IMyInterfaceName() internal pure returns (string memory) {
        return type(Behavior_IMyInterface).name;
    }

    // Store expectations
    function expect_IMyInterface_getValue(
        IMyInterface subject,
        uint256 expectedValue
    ) public {
        console.logBehaviorEntry(_Behavior_IMyInterfaceName(), "expect_IMyInterface_getValue");
        UInt256ComparatorRepo._recExpectedUInt256(
            address(subject),
            IMyInterface.getValue.selector,
            expectedValue
        );
        console.logBehaviorExit(_Behavior_IMyInterfaceName(), "expect_IMyInterface_getValue");
    }

    // Direct comparison
    function isValid_IMyInterface_getValue(
        IMyInterface subject,
        uint256 expected,
        uint256 actual
    ) public view returns (bool valid) {
        valid = expected == actual;
        if (!valid) {
            console.logBehaviorError(
                _Behavior_IMyInterfaceName(),
                "getValue()",
                abi.encode(expected),
                abi.encode(actual)
            );
        }
    }

    // Validate against stored expectation
    function hasValid_IMyInterface_getValue(
        IMyInterface subject
    ) public view returns (bool) {
        uint256 expected = UInt256ComparatorRepo._expectedUInt256(
            address(subject),
            IMyInterface.getValue.selector
        );
        uint256 actual = subject.getValue();
        return isValid_IMyInterface_getValue(subject, expected, actual);
    }
}
```

## Usage in Tests

```solidity
contract MyInterfaceTest is TestBase_IMyInterface {
    function test_IMyInterface_getValue() public {
        // Option 1: Direct comparison
        assertTrue(Behavior_IMyInterface.isValid_IMyInterface_getValue(
            testSubject,
            expectedValue(),
            testSubject.getValue()
        ));

        // Option 2: Store then validate
        Behavior_IMyInterface.expect_IMyInterface_getValue(testSubject, expectedValue());
        assertTrue(Behavior_IMyInterface.hasValid_IMyInterface_getValue(testSubject));
    }
}
```
