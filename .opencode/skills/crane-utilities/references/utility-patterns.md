# Utility Pattern Reference

## Set Collections in Diamond Storage

### Defining Storage with Sets

```solidity
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {Bytes4Set, Bytes4SetRepo} from "@crane/contracts/utils/collections/sets/Bytes4SetRepo.sol";

library MyFeatureRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256("my.feature");

    struct Storage {
        AddressSet allowedAddresses;
        Bytes4Set supportedSelectors;
        mapping(address => UInt256Set) userTokenIds;
    }

    function _layout() internal pure returns (Storage storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly { s.slot := slot }
    }
}
```

### CRUD Operations

```solidity
library MyFeatureRepo {
    using AddressSetRepo for AddressSet;

    function _addAllowed(address addr) internal returns (bool) {
        return _layout().allowedAddresses._add(addr);
    }

    function _removeAllowed(address addr) internal returns (bool) {
        return _layout().allowedAddresses._remove(addr);
    }

    function _isAllowed(address addr) internal view returns (bool) {
        return _layout().allowedAddresses._contains(addr);
    }

    function _getAllowed() internal view returns (address[] memory) {
        return _layout().allowedAddresses._asArray();
    }

    function _getAllowedCount() internal view returns (uint256) {
        return _layout().allowedAddresses._length();
    }
}
```

### Pagination Pattern

For exposing large sets via public functions:

```solidity
contract MyFacet {
    function getAllowedAddresses(
        uint256 pageIndex,
        uint256 pageSize
    ) external view returns (
        address[] memory addresses,
        bool hasMore
    ) {
        return AddressSetRepo._getPage(
            MyFeatureRepo._layout().allowedAddresses,
            pageIndex,
            pageSize
        );
    }
}
```

### Idempotent Operations

Sets are designed to be idempotent:

```solidity
// Adding twice is safe - second add is no-op
set._add(addr);  // Returns true (added)
set._add(addr);  // Returns true (already present, desired state achieved)

// Removing twice is safe
set._remove(addr);  // Returns true (removed)
set._remove(addr);  // Returns true (already absent, desired state achieved)
```

## AMM Math with ConstProdUtils

### Swap Quote Calculations

```solidity
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";

contract MyDEXIntegration {
    using ConstProdUtils for uint256;

    // Fee constants (common values)
    uint256 constant FEE_0_3_PERCENT = 9970;   // 0.3% fee
    uint256 constant FEE_0_25_PERCENT = 9975;  // 0.25% fee
    uint256 constant FEE_1_PERCENT = 9900;     // 1% fee

    function quoteSwap(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut) {
        // purchaseQuote: Given amountIn, calculate amountOut
        return amountIn._purchaseQuote(
            amountIn,
            reserveIn,
            reserveOut,
            FEE_0_3_PERCENT
        );
    }

    function quoteInput(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn) {
        // saleQuote: Given desired amountOut, calculate required amountIn
        return ConstProdUtils._saleQuote(
            amountOut,
            reserveIn,
            reserveOut,
            FEE_0_3_PERCENT
        );
    }
}
```

### Optimal Deposit Calculation

Calculate how much to swap before depositing to balance:

```solidity
function calculateOptimalSwap(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut
) external pure returns (uint256 swapAmount) {
    // Returns the amount of tokenIn to swap to tokenOut
    // so that remaining tokenIn and received tokenOut are in proportion
    return ConstProdUtils._quoteSaleAmountIn(
        amountIn,
        reserveIn,
        reserveOut,
        FEE_0_3_PERCENT
    );
}
```

### LP Token Calculations

```solidity
// Calculate LP tokens to mint
uint256 lpAmount = ConstProdUtils._quoteDepositMint(
    amountADeposit,
    amountBDeposit,
    lpTotalSupply,
    lpReserveA,
    lpReserveB
);

// Calculate tokens received for burning LP
(uint256 amountA, uint256 amountB) = ConstProdUtils._quoteWithdrawal(
    lpAmount,
    lpTotalSupply,
    reserveA,
    reserveB
);
```

## BetterMath Patterns

### Safe Arithmetic

```solidity
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";

using BetterMath for uint256;

// All operations are checked
uint256 sum = a._add(b);      // Reverts on overflow
uint256 diff = a._sub(b);     // Reverts on underflow
uint256 prod = a._mul(b);     // Reverts on overflow
uint256 quot = a._div(b);     // Reverts on division by zero
```

### Precision-Safe Multiplication

For calculations where intermediate values might overflow:

```solidity
import {Uint512, BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";

using BetterMath for uint256;
using BetterMath for Uint512;

// Problem: a * b might overflow before dividing by c
// Solution: Use 512-bit intermediate
function safeMulDiv(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
    Uint512 memory product = a._mul512(b);
    return product._div(c);
}

// mulDivDown rounds down (default)
uint256 result = total._mulDivDown(portion, WAD);

// mulDivUp rounds up
uint256 minRequired = debt._mulDivUp(collateralRatio, WAD);
```

## EIP-712 Typed Data

### Setting Up EIP-712

```solidity
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";

// In DFPkg initialization
function initAccount(bytes memory initArgs) public {
    // Initialize EIP-712 domain
    EIP712Repo._initialize(
        "MyContract",  // Name
        "1"            // Version
    );
}
```

### Creating Typed Data Hash

```solidity
// Define type hash (constant)
bytes32 constant PERMIT_TYPEHASH = keccak256(
    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
);

// Hash struct
function _hashPermit(
    address owner,
    address spender,
    uint256 value,
    uint256 nonce,
    uint256 deadline
) internal view returns (bytes32) {
    bytes32 structHash = keccak256(abi.encode(
        PERMIT_TYPEHASH,
        owner,
        spender,
        value,
        nonce,
        deadline
    ));

    return keccak256(abi.encodePacked(
        "\x19\x01",
        EIP712Repo._domainSeparator(),
        structHash
    ));
}
```

## Efficient Hashing

### CREATE3 Salt Generation

```solidity
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

using BetterEfficientHashLib for bytes;

// Generate deterministic salt from type name
bytes32 salt = abi.encode(type(MyContract).name)._hash();

// Or from multiple values
bytes32 salt = abi.encode(name, symbol, decimals)._hash();
```

### String to Bytes32

```solidity
// Convert string identifier to storage-efficient bytes32
bytes32 id = keccak256(abi.encode("my.identifier"));

// Or use hash library for bytes
bytes32 hash = abi.encode(data)._hash();
```

## Constants Usage

### Network Constants

```solidity
// Import network-specific constants
import "@crane/contracts/constants/networks/BASE_MAIN.sol";

// Use predefined addresses
address constant WETH = BASE_MAIN_WETH;
address constant USDC = BASE_MAIN_USDC;
```

### Protocol Constants

```solidity
// Permit2 addresses (same across all chains)
import "@crane/contracts/constants/protocols/utils/permit2/PERMIT2_CONSTANTS.sol";

IPermit2 permit2 = IPermit2(PERMIT2_ADDRESS);
```

### Global Constants

```solidity
import "@crane/contracts/constants/Constants.sol";

// Standard precision values
uint256 constant WAD = 1e18;   // 18 decimal precision
uint256 constant RAY = 1e27;   // 27 decimal precision

// Time constants
uint256 constant SECONDS_PER_DAY = 86400;
uint256 constant SECONDS_PER_YEAR = 31536000;
```

## Testing Utilities

### Set Assertions

```solidity
function test_setOperations() public {
    AddressSet storage set = MyRepo._layout().addresses;

    // Add and verify
    set._add(alice);
    assertTrue(set._contains(alice));
    assertEq(set._length(), 1);

    // Remove and verify
    set._remove(alice);
    assertFalse(set._contains(alice));
    assertEq(set._length(), 0);
}
```

### Math Fuzz Testing

```solidity
function testFuzz_swapQuote(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut
) public {
    // Bound inputs to reasonable ranges
    amountIn = bound(amountIn, 1, reserveIn / 10);
    reserveIn = bound(reserveIn, 1e18, 1e30);
    reserveOut = bound(reserveOut, 1e18, 1e30);

    uint256 amountOut = ConstProdUtils._purchaseQuote(
        amountIn, reserveIn, reserveOut, 9970
    );

    // Invariant: output should be less than reserveOut
    assertLt(amountOut, reserveOut);

    // Invariant: k should increase or stay same (due to fees)
    uint256 kBefore = reserveIn * reserveOut;
    uint256 kAfter = (reserveIn + amountIn) * (reserveOut - amountOut);
    assertGe(kAfter, kBefore);
}
```
