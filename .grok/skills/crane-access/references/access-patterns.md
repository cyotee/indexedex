# Access Control Integration Patterns

## Combining Access Control in DFPkg

When creating a Diamond Factory Package with access control:

```solidity
interface IMyDFPkg {
    struct PkgInit {
        IFacet myFacet;
        IFacet multiStepOwnableFacet;
        IFacet operableFacet;
    }

    struct PkgArgs {
        address owner;
        address[] initialOperators;
    }
}

contract MyDFPkg is IMyDFPkg, IDiamondFactoryPackage {
    IFacet immutable MY_FACET;
    IFacet immutable MULTI_STEP_OWNABLE_FACET;
    IFacet immutable OPERABLE_FACET;

    constructor(PkgInit memory pkgInit) {
        MY_FACET = pkgInit.myFacet;
        MULTI_STEP_OWNABLE_FACET = pkgInit.multiStepOwnableFacet;
        OPERABLE_FACET = pkgInit.operableFacet;
    }

    function initAccount(bytes memory initArgs) public {
        (PkgArgs memory args) = abi.decode(initArgs, (PkgArgs));

        // Initialize ownership
        MultiStepOwnableRepo._initialize(args.owner, 1 days);

        // Set initial operators
        for (uint256 i = 0; i < args.initialOperators.length; i++) {
            OperableRepo._layout().isOperator[args.initialOperators[i]] = true;
        }
    }
}
```

## Target Contract with Mixed Access Control

```solidity
import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";
import {OperableModifiers} from "@crane/contracts/access/operable/OperableModifiers.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

abstract contract MyTarget is
    MultiStepOwnableModifiers,
    OperableModifiers,
    ReentrancyLockModifiers
{
    // Only owner can call - highest privilege
    function setConfig(Config memory config_) external onlyOwner {
        // Critical configuration changes
    }

    // Owner or any operator can call
    function executeStrategy() external onlyOwnerOrOperator nonReentrant {
        // Strategy execution with reentrancy protection
    }

    // Only operators (global or function-specific)
    function processQueue() external onlyOperator {
        // Delegated task processing
    }

    // Custom access logic combining patterns
    function emergencyWithdraw() external {
        // Either owner OR specific function operator
        if (
            MultiStepOwnableRepo._owner() != msg.sender &&
            !OperableRepo._isFunctionOperator(
                this.emergencyWithdraw.selector,
                msg.sender
            )
        ) {
            revert NotAuthorized();
        }
        // Emergency logic
    }
}
```

## Storage Slot Naming

Access control uses standardized slots:

| Component | Slot |
|-----------|------|
| MultiStepOwnable | `keccak256("eip.erc.8023")` |
| Operable | `keccak256("crane.access.operable")` |
| ReentrancyLock | `keccak256("crane.access.reentrancy")` |

## Operable Depends on MultiStepOwnable

The Operable pattern requires ownership for setting operator permissions:

```solidity
function _setOperatorStatus(Storage storage layout, address operator, bool approval) internal {
    MultiStepOwnableRepo._onlyOwner();  // <-- Requires owner
    layout.isOperator[operator] = approval;
    emit IOperable.NewGlobalOperatorStatus(operator, approval);
}
```

Always initialize `MultiStepOwnableRepo` before using `OperableRepo` setter functions.

## Events

### MultiStepOwnable Events

```solidity
event OwnershipTransferInitiated(address indexed previousOwner, address indexed pendingOwner);
event OwnershipTransferConfirmed(address indexed previousOwner, address indexed pendingOwner);
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
```

### Operable Events

```solidity
event NewGlobalOperatorStatus(address indexed operator, bool approval);
event NewFunctionOperatorStatus(address indexed operator, bytes4 indexed func, bool approval);
```

## Error Handling

### MultiStepOwnable Errors

```solidity
error NotOwner(address account);
error NotPending(address account);
error BufferPeriodNotElapsed(uint256 currentTime, uint256 bufferEnd);
```

### Operable Errors

```solidity
error NotOperator(address account);
```

### ReentrancyLock Errors

```solidity
error IsLocked();
```

## Testing Access Control

```solidity
import {TestBase_IMultiStepOwnable} from "@crane/contracts/access/ERC8023/TestBase_IMultiStepOwnable.sol";

contract MyContract_AccessControl_Test is TestBase_IMultiStepOwnable {
    function test_onlyOwner_revertsForNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, nonOwner));
        myContract.adminFunction();
    }

    function test_ownershipTransfer_fullFlow() public {
        // Step 1: Initiate
        vm.prank(owner);
        myContract.initiateOwnershipTransfer(newOwner);

        // Step 2: Wait
        vm.warp(block.timestamp + 1 days + 1);

        // Step 3: Confirm
        vm.prank(owner);
        myContract.confirmOwnershipTransfer(newOwner);

        // Step 4: Accept
        vm.prank(newOwner);
        myContract.acceptOwnershipTransfer();

        assertEq(myContract.owner(), newOwner);
    }

    function test_operator_functionLevel() public {
        // Grant function-level access
        vm.prank(owner);
        myContract.setFunctionOperatorStatus(
            IMyContract.restrictedFunc.selector,
            operator,
            true
        );

        // Operator can call specific function
        vm.prank(operator);
        myContract.restrictedFunc();

        // But not other restricted functions
        vm.prank(operator);
        vm.expectRevert();
        myContract.otherRestrictedFunc();
    }
}
```

## Security Considerations

### Buffer Period

The ownership buffer period prevents instant hostile takeovers:

- **Minimum recommended**: 1 day
- **High-value protocols**: 3-7 days
- **Allows time for**: Community notification, emergency response

### Operator Granularity

Use function-level operators for least-privilege:

```solidity
// Good: Specific function access
OperableRepo._setFunctionOperatorStatus(
    IVault.rebalance.selector,
    rebalancer,
    true
);

// Avoid: Global operator when not needed
// OperableRepo._setOperatorStatus(rebalancer, true);
```

### Reentrancy Lock Scope

The transient storage lock protects the entire transaction:

```solidity
contract Vulnerable {
    function withdraw() external nonReentrant {
        // Safe: lock applies to all functions using ReentrancyLockRepo
    }

    function callback() external {
        // Also protected if it uses nonReentrant
        // ReentrancyLockRepo._onlyUnlocked() will revert
    }
}
```
