# NatSpec Documentation Examples

Complete examples of properly documented Crane contracts.

## Interface with Full Documentation

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// tag::IOperable[]
/// @title IOperable
/// @notice Interface for operator-based access control
/// @dev Allows granular permission management at address and function levels
/// @custom:interfaceid 0x7c9c1a3e
interface IOperable {

    /* ------ Events ------ */

    // tag::OperatorSet[]
    /// @notice Emitted when an operator status is changed
    /// @param operator The operator address
    /// @param status The new operator status
    /// @custom:signature OperatorSet(address,bool)
    /// @custom:topiczero 0x7a33d97b5c0c5cd90bcc7c827edb8a8d8e3b76d15cbdec7556fcfba5ecf55d85
    event OperatorSet(address indexed operator, bool indexed status);
    // end::OperatorSet[]

    // tag::FunctionOperatorSet[]
    /// @notice Emitted when a function-specific operator is set
    /// @param selector The function selector
    /// @param operator The operator address
    /// @param status The new operator status
    /// @custom:signature FunctionOperatorSet(bytes4,address,bool)
    /// @custom:topiczero 0x3b5b7a5d87b5f9e15a8b9c0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e
    event FunctionOperatorSet(bytes4 indexed selector, address indexed operator, bool indexed status);
    // end::FunctionOperatorSet[]

    /* ------ Errors ------ */

    // tag::NotOperator[]
    /// @notice Thrown when caller lacks operator privileges
    /// @param caller The address that attempted the operation
    /// @custom:signature NotOperator(address)
    /// @custom:selector 0x7a5a2f72
    error NotOperator(address caller);
    // end::NotOperator[]

    // tag::NotFunctionOperator[]
    /// @notice Thrown when caller lacks function-specific operator privileges
    /// @param selector The function selector
    /// @param caller The address that attempted the operation
    /// @custom:signature NotFunctionOperator(bytes4,address)
    /// @custom:selector 0x8b3e1f4a
    error NotFunctionOperator(bytes4 selector, address caller);
    // end::NotFunctionOperator[]

    /* ------ View Functions ------ */

    // tag::isOperator[]
    /// @notice Checks if an address is a global operator
    /// @param query_ The address to check
    /// @return isOperator_ True if the address is an operator
    /// @custom:signature isOperator(address)
    /// @custom:selector 0x6d70f7ae
    function isOperator(address query_) external view returns (bool isOperator_);
    // end::isOperator[]

    // tag::isFunctionOperator[]
    /// @notice Checks if an address is an operator for a specific function
    /// @param selector_ The function selector
    /// @param query_ The address to check
    /// @return isFunctionOperator_ True if the address is a function operator
    /// @custom:signature isFunctionOperator(bytes4,address)
    /// @custom:selector 0x9c5e1f3b
    function isFunctionOperator(bytes4 selector_, address query_) external view returns (bool isFunctionOperator_);
    // end::isFunctionOperator[]

    /* ------ State-Changing Functions ------ */

    // tag::setOperator[]
    /// @notice Sets the operator status for an address
    /// @param operator_ The address to set as operator
    /// @param status_ The operator status to set
    /// @custom:signature setOperator(address,bool)
    /// @custom:selector 0x558a7297
    function setOperator(address operator_, bool status_) external;
    // end::setOperator[]

    // tag::setFunctionOperator[]
    /// @notice Sets the operator status for a specific function
    /// @param selector_ The function selector
    /// @param operator_ The address to set as function operator
    /// @param status_ The operator status to set
    /// @custom:signature setFunctionOperator(bytes4,address,bool)
    /// @custom:selector 0x7b2e5f1c
    function setFunctionOperator(bytes4 selector_, address operator_, bool status_) external;
    // end::setFunctionOperator[]
}
// end::IOperable[]
```

## Repo with Full Documentation

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IOperable} from "./interfaces/IOperable.sol";

// tag::OperableRepo[]
/// @title OperableRepo
/// @notice Storage library for operator-based access control
/// @dev Uses Diamond storage pattern with dual function overloads
library OperableRepo {

    /* ------ Storage ------ */

    // tag::STORAGE_SLOT[]
    /// @notice Storage slot for Operable storage
    /// @dev keccak256(abi.encode("crane.access.operable"))
    bytes32 internal constant STORAGE_SLOT = 0x7a3b5c9d1e2f4a8b6c0d9e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b;
    // end::STORAGE_SLOT[]

    // tag::Storage[]
    /// @notice Storage struct for Operable
    /// @param operators Mapping of global operators
    /// @param functionOperators Mapping of function-specific operators
    struct Storage {
        mapping(address => bool) operators;
        mapping(bytes4 => mapping(address => bool)) functionOperators;
    }
    // end::Storage[]

    /* ------ Layout Functions ------ */

    // tag::_layout_parameterized[]
    /// @notice Returns storage at a custom slot
    /// @param slot_ The storage slot
    /// @return layout_ The storage struct reference
    function _layout(bytes32 slot_) internal pure returns (Storage storage layout_) {
        assembly { layout_.slot := slot_ }
    }
    // end::_layout_parameterized[]

    // tag::_layout_default[]
    /// @notice Returns storage at the default slot
    /// @return The storage struct reference
    function _layout() internal pure returns (Storage storage) {
        return _layout(STORAGE_SLOT);
    }
    // end::_layout_default[]

    /* ------ Guard Functions ------ */

    // tag::_onlyOperator[]
    /// @notice Reverts if caller is not an operator
    /// @param layout_ The storage struct
    function _onlyOperator(Storage storage layout_) internal view {
        if (!_isOperator(layout_, msg.sender) && !_isFunctionOperator(layout_, msg.sig, msg.sender)) {
            revert IOperable.NotOperator(msg.sender);
        }
    }

    /// @notice Reverts if caller is not an operator (default slot)
    function _onlyOperator() internal view {
        _onlyOperator(_layout());
    }
    // end::_onlyOperator[]
}
// end::OperableRepo[]
```

## Computing Selectors Script

```bash
#!/bin/bash
# compute-selectors.sh - Compute selectors for a contract

echo "=== Functions ==="
cast sig "isOperator(address)"
cast sig "isFunctionOperator(bytes4,address)"
cast sig "setOperator(address,bool)"
cast sig "setFunctionOperator(bytes4,address,bool)"

echo ""
echo "=== Errors ==="
cast sig "NotOperator(address)"
cast sig "NotFunctionOperator(bytes4,address)"

echo ""
echo "=== Events (topic0) ==="
cast keccak "OperatorSet(address,bool)"
cast keccak "FunctionOperatorSet(bytes4,address,bool)"
```

## Verifying Interface ID

```solidity
// In a test file
function test_interfaceId() public {
    bytes4 expected = type(IOperable).interfaceId;

    // Manual computation
    bytes4 manual =
        IOperable.isOperator.selector ^
        IOperable.isFunctionOperator.selector ^
        IOperable.setOperator.selector ^
        IOperable.setFunctionOperator.selector;

    assertEq(expected, manual);
    console.log("Interface ID:", vm.toString(expected));
}
```
