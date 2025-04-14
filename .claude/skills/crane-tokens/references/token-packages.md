# Token Package Reference

## Package Comparison

| Feature | ERC20DFPkg | ERC20PermitDFPkg | ERC20PermitMintBurnLockedOwnableDFPkg |
|---------|------------|------------------|---------------------------------------|
| ERC20 transfer/approve | Yes | Yes | Yes |
| ERC20 metadata | Yes | Yes | Yes |
| EIP-2612 permit | No | Yes | Yes |
| EIP-5267 domain | No | Yes | Yes |
| Mint function | No | No | Yes (onlyOwner) |
| Burn function | No | No | Yes (onlyOwner) |
| Ownership | No | No | Yes (MultiStepOwnable) |
| Built-in deploy() | Yes | No | Yes |

## Deployment Patterns

### Pattern 1: Direct Factory Deployment

Use when you have existing facets and want to deploy a token:

```solidity
// Encode deployment arguments
bytes memory pkgArgs = abi.encode(IERC20PermitDFPkg.PkgArgs({
    name: "My Token",
    symbol: "MTK",
    decimals: 18,
    totalSupply: 1_000_000e18,
    recipient: msg.sender,
    optionalSalt: bytes32(0)
}));

// Deploy via factory
address token = diamondFactory.deploy(erc20PermitPkg, pkgArgs);
```

### Pattern 2: Package Helper Function

Some packages include convenience deploy functions:

```solidity
// ERC20DFPkg has deploy() helper
IERC20 token = erc20Pkg.deploy(
    diamondFactory,
    "My Token",
    "MTK",
    18,
    1_000_000e18,
    msg.sender,
    bytes32(0)
);

// ERC20PermitMintBurnLockedOwnableDFPkg has deployToken()
address token = mintBurnPkg.deployToken(
    "My Token",
    "MTK",
    18,
    owner,
    bytes32(0)
);
```

### Pattern 3: FactoryService for Infrastructure

For deploying facets and packages in tests/scripts:

```solidity
library TokenFactoryService {
    using BetterEfficientHashLib for bytes;

    function deployERC20Facet(ICreate3Factory factory) internal returns (IFacet) {
        return factory.deployFacet(
            type(ERC20Facet).creationCode,
            abi.encode(type(ERC20Facet).name)._hash()
        );
    }

    function deployERC20PermitDFPkg(
        ICreate3Factory factory,
        IFacet erc20Facet,
        IFacet erc5267Facet,
        IFacet erc2612Facet
    ) internal returns (IERC20PermitDFPkg) {
        return IERC20PermitDFPkg(address(
            factory.deployPackageWithArgs(
                type(ERC20PermitDFPkg).creationCode,
                abi.encode(IERC20PermitDFPkg.PkgInit({
                    erc20Facet: erc20Facet,
                    erc5267Facet: erc5267Facet,
                    erc2612Facet: erc2612Facet
                })),
                abi.encode(type(ERC20PermitDFPkg).name)._hash()
            )
        ));
    }
}
```

## Salt Calculation

Packages compute deterministic salts from arguments:

```solidity
// Salt is computed from normalized arguments
function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
    (PkgArgs memory decodedArgs) = abi.decode(pkgArgs, (PkgArgs));

    // Normalization: name/symbol can be inferred from each other
    if (bytes(decodedArgs.name).length == 0) {
        if (bytes(decodedArgs.symbol).length != 0) {
            decodedArgs.name = decodedArgs.symbol;
        } else {
            revert NoNameAndSymbol();
        }
    }

    // Decimals defaults to 18
    if (decodedArgs.decimals == 0) {
        decodedArgs.decimals = 18;
    }

    return abi.encode(decodedArgs)._hash();
}
```

## Initialization Flow

During `initAccount()` (called via delegatecall on the proxy):

```solidity
function initAccount(bytes memory initArgs) public {
    (PkgArgs memory decodedArgs) = abi.decode(initArgs, (PkgArgs));

    // Initialize ERC20 storage
    ERC20Repo._initialize(
        decodedArgs.name,
        decodedArgs.symbol,
        decodedArgs.decimals
    );

    // Initialize EIP-712 for permit (if applicable)
    EIP712Repo._initialize(decodedArgs.name, "1");

    // Initialize ownership (for MintBurnOwnable package)
    MultiStepOwnableRepo._initialize(decodedArgs.owner, 1 days);

    // Mint initial supply
    if (decodedArgs.totalSupply > 0) {
        ERC20Repo._mint(decodedArgs.recipient, decodedArgs.totalSupply);
    }
}
```

## ERC20Repo Functions

Core storage operations:

```solidity
// Initialization
function _initialize(string memory name_, string memory symbol_, uint8 decimals_) internal;

// Balance operations
function _balanceOf(address account_) internal view returns (uint256);
function _transfer(address from_, address to_, uint256 amount_) internal;
function _mint(address to_, uint256 amount_) internal;
function _burn(address from_, uint256 amount_) internal;

// Allowance operations
function _allowance(address owner_, address spender_) internal view returns (uint256);
function _approve(address owner_, address spender_, uint256 amount_) internal;
function _spendAllowance(address owner_, address spender_, uint256 amount_) internal;

// Metadata
function _name() internal view returns (string memory);
function _symbol() internal view returns (string memory);
function _decimals() internal view returns (uint8);
function _totalSupply() internal view returns (uint256);
```

## Testing Infrastructure

### TestBase_ERC20

Base contract for ERC20 invariant testing with Handler pattern:

```solidity
abstract contract TestBase_ERC20 is Test {
    ERC20TargetStubHandler public handler;

    function setUp() public virtual {
        handler = new ERC20TargetStubHandler();
        IERC20 token = _deployToken(handler);
        handler.attachToken(token);

        targetContract(address(handler));
    }

    // Override to deploy your token
    function _deployToken(ERC20TargetStubHandler handler_) internal virtual returns (IERC20);

    // Invariant: totalSupply == sum of balances
    function invariant_totalSupply_equals_sumBalances() public view;

    // Invariant: allowances match expected state
    function invariant_allowances_consistent() public view;
}
```

### TestBase_ERC20Permit

Extends ERC20 testing with permit functionality:

```solidity
abstract contract TestBase_ERC20Permit is TestBase_ERC20 {
    // Override to deploy permit-enabled token
    function _deployToken() internal virtual returns (IERC20Permit);

    // Test permit signature validation
    function test_permit_validSignature() public;

    // Test permit nonce handling
    function test_permit_noncesIncrement() public;
}
```

## Extending Token Packages

To create a custom token package:

1. Define interface with PkgInit and PkgArgs structs
2. Extend IDiamondFactoryPackage
3. Store facet references as immutables
4. Implement facetCuts() to return facet configuration
5. Implement initAccount() to initialize storage

```solidity
interface IMyTokenDFPkg {
    struct PkgInit {
        IFacet erc20Facet;
        IFacet myCustomFacet;
    }

    struct PkgArgs {
        string name;
        string symbol;
        uint256 customValue;
    }
}

contract MyTokenDFPkg is IMyTokenDFPkg, IDiamondFactoryPackage {
    IFacet immutable ERC20_FACET;
    IFacet immutable MY_CUSTOM_FACET;

    constructor(PkgInit memory pkgInit) {
        ERC20_FACET = pkgInit.erc20Facet;
        MY_CUSTOM_FACET = pkgInit.myCustomFacet;
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory) {
        // Return array of FacetCut structs
    }

    function initAccount(bytes memory initArgs) public {
        // Initialize storage
    }
}
```
