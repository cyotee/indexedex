# Handler Pattern for Invariant Testing

The Handler pattern enables declarative invariant testing with Foundry.

## Overview

A Handler contract:
1. Wraps the Subject Under Test (SUT)
2. Normalizes fuzz inputs to bounded ranges
3. Tracks expected state alongside actual state
4. Declares expected behavior (reverts, events) before actions

## Handler Structure

```solidity
contract ERC20Handler is Test {
    // Subject Under Test
    IERC20 public sut;

    // State tracking
    mapping(address => bool) internal _seen;
    address[] internal _addresses;
    mapping(bytes32 => uint256) internal _expectedAllowance;

    // Bounded address set
    address[] internal _actors = [
        address(0x1111),
        address(0x2222),
        address(0x3333),
        address(0x4444)
    ];

    function attachToken(IERC20 token) external {
        sut = token;
    }

    // Normalize seed to bounded actor
    function addrFromSeed(uint256 seed) internal view returns (address) {
        return _actors[seed % _actors.length];
    }
}
```

## Fuzzable Operations

Each public function is a fuzzable operation:

```solidity
function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
    address from = addrFromSeed(fromSeed);
    address to = addrFromSeed(toSeed);

    _trackAddress(from);
    _trackAddress(to);

    uint256 balance = sut.balanceOf(from);
    vm.prank(from);

    if (amount > balance) {
        // Declare expected revert
        vm.expectRevert(abi.encodeWithSelector(
            IERC20.InsufficientBalance.selector,
            from,
            balance,
            amount
        ));
        sut.transfer(to, amount);
        return;
    }

    // Declare expected event
    vm.expectEmit(true, true, false, true);
    emit IERC20.Transfer(from, to, amount);

    sut.transfer(to, amount);
}

function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) external {
    address owner = addrFromSeed(ownerSeed);
    address spender = addrFromSeed(spenderSeed);

    _trackAddress(owner);
    _trackAddress(spender);

    // Track expected state
    bytes32 key = keccak256(abi.encodePacked(owner, spender));
    _expectedAllowance[key] = amount;

    vm.prank(owner);

    vm.expectEmit(true, true, false, true);
    emit IERC20.Approval(owner, spender, amount);

    sut.approve(spender, amount);
}
```

## State Tracking

Track addresses that have been involved in operations:

```solidity
function _trackAddress(address addr) internal {
    if (!_seen[addr]) {
        _seen[addr] = true;
        _addresses.push(addr);
    }
}

function asAddresses() external view returns (address[] memory) {
    return _addresses;
}

function pairCount() external view returns (uint256) {
    return _addresses.length * _addresses.length;
}

function pairAt(uint256 index) external view returns (
    address owner,
    address spender,
    uint256 expected
) {
    uint256 ownerIdx = index / _addresses.length;
    uint256 spenderIdx = index % _addresses.length;
    owner = _addresses[ownerIdx];
    spender = _addresses[spenderIdx];
    bytes32 key = keccak256(abi.encodePacked(owner, spender));
    expected = _expectedAllowance[key];
}
```

## Invariant TestBase

Declares invariants and sets up fuzzing:

```solidity
abstract contract TestBase_ERC20Invariant is Test {
    ERC20Handler public handler;

    function _deployToken(ERC20Handler handler_) internal virtual returns (IERC20);

    function setUp() public virtual {
        handler = new ERC20Handler();
        IERC20 token = _deployToken(handler);
        handler.attachToken(token);

        // Configure Foundry fuzzer
        targetContract(address(handler));
        targetSelector(FuzzSelector({
            addr: address(handler),
            selectors: _getTargetSelectors()
        }));
    }

    function _getTargetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = ERC20Handler.transfer.selector;
        selectors[1] = ERC20Handler.approve.selector;
        selectors[2] = ERC20Handler.transferFrom.selector;
        return selectors;
    }

    // Invariant: total supply equals sum of balances
    function invariant_totalSupply() public view {
        address[] memory addrs = handler.asAddresses();
        uint256 sum = 0;
        for (uint256 i = 0; i < addrs.length; i++) {
            sum += handler.sut().balanceOf(addrs[i]);
        }
        assertEq(sum, handler.sut().totalSupply());
    }

    // Invariant: allowances match expected state
    function invariant_allowances() public view {
        uint256 count = handler.pairCount();
        for (uint256 i = 0; i < count; i++) {
            (address owner, address spender, uint256 expected) = handler.pairAt(i);
            assertEq(handler.sut().allowance(owner, spender), expected);
        }
    }
}
```

## Concrete Test

Implement the virtual deployment function:

```solidity
contract ERC20Facet_Invariant is TestBase_ERC20Invariant {
    function _deployToken(ERC20Handler handler_) internal override returns (IERC20) {
        // Deploy via Diamond factory
        IERC20 token = erc20DFPkg.deploy(
            diamondFactory,
            "Test",
            "TST",
            18,
            1000e18,
            address(handler_),
            bytes32(0)
        );
        return token;
    }
}
```

## Key Patterns

### Bounded Actors

Limit address space for meaningful coverage:

```solidity
address[] internal _actors = [...];
function addrFromSeed(uint256 seed) internal view returns (address) {
    return _actors[seed % _actors.length];
}
```

### Declarative Expectations

Declare expected behavior before action:

```solidity
// Before revert
vm.expectRevert(...);
// Before event
vm.expectEmit(true, true, false, true);
emit Event(...);
```

### State Synchronization

Track expected state in handler, compare in invariants:

```solidity
// In handler operation
_expectedAllowance[key] = amount;

// In invariant
assertEq(sut.allowance(owner, spender), expected);
```

### Invariant Naming

Name functions `invariant_*` for Foundry discovery:

```solidity
function invariant_totalSupply() public view { ... }
function invariant_allowances() public view { ... }
function invariant_noNegativeBalances() public view { ... }
```
