# Complete Crane Style Guide

Comprehensive style reference for Crane development.

## File Structure Template

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/* -------------------------------------------------------------------------- */
/*                                  IMPORTS                                   */
/* -------------------------------------------------------------------------- */

// External libraries
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Crane interfaces
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

// Crane contracts
import {OperableRepo} from "@crane/contracts/access/operable/OperableRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                 INTERFACES                                 */
/* -------------------------------------------------------------------------- */

interface IMyContract {
    // Events
    event ValueSet(address indexed setter, uint256 value);

    // Errors
    error InvalidValue(uint256 provided, uint256 expected);

    // Functions
    function getValue() external view returns (uint256);
    function setValue(uint256 value_) external;
}

/* -------------------------------------------------------------------------- */
/*                                  CONTRACT                                  */
/* -------------------------------------------------------------------------- */

/// @title MyContract
/// @notice Brief description
/// @dev Implementation details
contract MyContract is IMyContract {
    using SafeERC20 for IERC20;

    /* ------ State Variables ------ */

    uint256 private _value;

    /* ------ Constructor ------ */

    constructor(uint256 initialValue_) {
        _value = initialValue_;
    }

    /* ------ External Functions ------ */

    /// @inheritdoc IMyContract
    function getValue() external view returns (uint256) {
        return _value;
    }

    /// @inheritdoc IMyContract
    function setValue(uint256 value_) external {
        _value = value_;
        emit ValueSet(msg.sender, value_);
    }

    /* ------ Internal Functions ------ */

    function _validateValue(uint256 value_) internal pure returns (bool) {
        return value_ > 0;
    }
}
```

## Repo File Structure

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/* -------------------------------------------------------------------------- */
/*                                  IMPORTS                                   */
/* -------------------------------------------------------------------------- */

import {IMyFeature} from "./interfaces/IMyFeature.sol";

/* -------------------------------------------------------------------------- */
/*                                   LIBRARY                                  */
/* -------------------------------------------------------------------------- */

/// @title MyFeatureRepo
/// @notice Storage library for MyFeature
library MyFeatureRepo {

    /* ------ Storage ------ */

    bytes32 internal constant STORAGE_SLOT = keccak256(abi.encode("crane.feature.myfeature"));

    struct Storage {
        uint256 value;
        mapping(address => bool) operators;
    }

    /* ------ Layout Functions ------ */

    function _layout(bytes32 slot_) internal pure returns (Storage storage layout_) {
        assembly { layout_.slot := slot_ }
    }

    function _layout() internal pure returns (Storage storage) {
        return _layout(STORAGE_SLOT);
    }

    /* ------ Initialization ------ */

    function _initialize(Storage storage layout_, uint256 value_) internal {
        layout_.value = value_;
    }

    function _initialize(uint256 value_) internal {
        _initialize(_layout(), value_);
    }

    /* ------ Getters ------ */

    function _getValue(Storage storage layout_) internal view returns (uint256) {
        return layout_.value;
    }

    function _getValue() internal view returns (uint256) {
        return _getValue(_layout());
    }

    /* ------ Setters ------ */

    function _setValue(Storage storage layout_, uint256 value_) internal {
        layout_.value = value_;
    }

    function _setValue(uint256 value_) internal {
        _setValue(_layout(), value_);
    }

    /* ------ Guards ------ */

    function _onlyOperator(Storage storage layout_) internal view {
        if (!layout_.operators[msg.sender]) {
            revert IMyFeature.NotOperator(msg.sender);
        }
    }

    function _onlyOperator() internal view {
        _onlyOperator(_layout());
    }
}
```

## Facet File Structure

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/* -------------------------------------------------------------------------- */
/*                                  IMPORTS                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IMyFeature} from "./interfaces/IMyFeature.sol";
import {MyFeatureTarget} from "./MyFeatureTarget.sol";

/* -------------------------------------------------------------------------- */
/*                                   FACET                                    */
/* -------------------------------------------------------------------------- */

/// @title MyFeatureFacet
/// @notice Diamond facet for MyFeature
contract MyFeatureFacet is MyFeatureTarget, IFacet {

    /* ------ IFacet Implementation ------ */

    /// @inheritdoc IFacet
    function facetName() external pure returns (string memory) {
        return type(MyFeatureFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IMyFeature).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](2);
        funcs_[0] = IMyFeature.getValue.selector;
        funcs_[1] = IMyFeature.setValue.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata() external pure returns (
        string memory name_,
        bytes4[] memory interfaces_,
        bytes4[] memory funcs_
    ) {
        name_ = this.facetName();
        interfaces_ = this.facetInterfaces();
        funcs_ = this.facetFuncs();
    }
}
```

## Error and Event Naming

### Errors

```solidity
// Pattern: {Condition}{Subject} or {Action}Failed
error NotOperator(address caller);
error InvalidAmount(uint256 provided, uint256 minimum);
error TransferFailed(address token, address to, uint256 amount);
error ZeroAddress();
error Unauthorized();
```

### Events

```solidity
// Pattern: {Subject}{Action}(ed)
event OperatorSet(address indexed operator, bool indexed status);
event ValueUpdated(uint256 indexed oldValue, uint256 indexed newValue);
event TransferCompleted(address indexed from, address indexed to, uint256 amount);
```

## Modifier Pattern

```solidity
// In Modifiers contract
abstract contract MyFeatureModifiers {
    modifier onlyOperator() {
        MyFeatureRepo._onlyOperator();
        _;
    }

    modifier nonZero(uint256 value_) {
        if (value_ == 0) revert ZeroValue();
        _;
    }
}
```

## Interface Pattern

```solidity
interface IMyFeature {
    // Events first
    event ValueSet(uint256 value);

    // Errors second
    error NotOperator(address caller);
    error InvalidValue(uint256 value);

    // View functions
    function getValue() external view returns (uint256);
    function isOperator(address query_) external view returns (bool);

    // State-changing functions
    function setValue(uint256 value_) external;
    function setOperator(address operator_, bool status_) external;
}
```

## Test File Structure

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";

contract MyFeature_Test is CraneTest {

    /* ------ State ------ */

    IMyFeature subject;

    /* ------ Setup ------ */

    function setUp() public override {
        super.setUp();
        // Deploy subject
    }

    /* ------ Tests ------ */

    function test_getValue_returnsInitialValue() public view {
        assertEq(subject.getValue(), 0);
    }

    function test_setValue_updatesValue() public {
        subject.setValue(100);
        assertEq(subject.getValue(), 100);
    }

    function test_setValue_revertsWhenNotOperator() public {
        vm.prank(address(0xdead));
        vm.expectRevert(abi.encodeWithSelector(IMyFeature.NotOperator.selector, address(0xdead)));
        subject.setValue(100);
    }
}
```

## Foundry Configuration

```toml
[profile.default]
src = 'contracts'
out = 'out'
libs = ['lib']
solc_version = '0.8.30'
evm_version = 'prague'
optimizer = true
optimizer_runs = 1
via_ir = false  # NEVER enable

[fmt]
line_length = 120
tab_width = 4
bracket_spacing = false
```
