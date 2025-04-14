# Diamond Factory Package (DFPkg) Pattern

Diamond Factory Packages bundle facets into deployable packages with initialization logic.

## Structure

Every DFPkg has an interface and implementation:

```solidity
// Interface defines structs for constructor and deployment args
interface IERC20DFPkg {
    struct PkgInit {           // Constructor arguments (immutable facet references)
        IFacet erc20Facet;
    }
    struct PkgArgs {           // Deployment arguments (per-instance config)
        string name;
        string symbol;
        uint8 decimals;
    }
}

contract ERC20DFPkg is IERC20DFPkg, IDiamondFactoryPackage {
    IFacet immutable ERC20_FACET;

    constructor(PkgInit memory pkgInit) {
        ERC20_FACET = pkgInit.erc20Facet;
    }

    function packageName() public pure returns (string memory);
    function facetCuts() public view returns (IDiamond.FacetCut[] memory);
    function diamondConfig() public view returns (DiamondConfig memory);
    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32);
    function initAccount(bytes memory initArgs) public;  // Called via delegatecall on proxy
    function postDeploy(address account) public returns (bool);
}
```

## Key Methods

### `PkgInit` Struct

Constructor arguments for the package. Typically contains facet references:

```solidity
struct PkgInit {
    IFacet erc20Facet;
    IFacet accessFacet;
    IFacet introspectionFacet;
}
```

### `PkgArgs` Struct

Per-deployment configuration:

```solidity
struct PkgArgs {
    string name;
    string symbol;
    uint8 decimals;
    uint256 initialSupply;
    address initialHolder;
}
```

### `facetCuts()`

Returns the facet cut array for Diamond initialization:

```solidity
function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts) {
    cuts = new IDiamond.FacetCut[](1);
    cuts[0] = IDiamond.FacetCut({
        facetAddress: address(ERC20_FACET),
        action: IDiamond.FacetCutAction.Add,
        functionSelectors: ERC20_FACET.facetFuncs()
    });
}
```

### `calcSalt(bytes memory pkgArgs)`

Calculate deterministic deployment salt from package arguments:

```solidity
function calcSalt(bytes memory pkgArgs) public pure returns (bytes32) {
    PkgArgs memory args = abi.decode(pkgArgs, (PkgArgs));
    return keccak256(abi.encode(args.name, args.symbol));
}
```

### `initAccount(bytes memory initArgs)`

Called via delegatecall on the proxy to initialize storage:

```solidity
function initAccount(bytes memory initArgs) public {
    PkgArgs memory args = abi.decode(initArgs, (PkgArgs));
    ERC20Repo._initialize(args.name, args.symbol, args.decimals);
    if (args.initialSupply > 0) {
        ERC20Repo._mint(args.initialHolder, args.initialSupply);
    }
}
```

### `postDeploy(address account)`

Optional post-deployment hook (called externally, not delegatecall):

```solidity
function postDeploy(address account) public returns (bool) {
    // Register in external registry, emit events, etc.
    return true;
}
```

## Deployment Flow

See `/contracts/interfaces/IDiamondFactoryPackage.sol` for the complete ASCII sequence diagram:

1. User calls `factory.deploy(pkg, pkgArgs)`
2. Factory calculates deterministic address via `pkg.calcSalt()`
3. Factory deploys `MinimalDiamondCallBackProxy` via CREATE2
4. Proxy calls back to factory's `initAccount()`
5. Factory delegatecalls `pkg.initAccount()` to initialize storage
6. Factory calls `pkg.postDeploy()` for any post-deployment hooks

## Complete Example

```solidity
interface IMyFeatureDFPkg {
    struct PkgInit {
        IFacet myFeatureFacet;
        IFacet accessFacet;
    }
    struct PkgArgs {
        string name;
        address owner;
    }
}

contract MyFeatureDFPkg is IMyFeatureDFPkg, IDiamondFactoryPackage {
    IFacet immutable MY_FEATURE_FACET;
    IFacet immutable ACCESS_FACET;

    constructor(PkgInit memory pkgInit) {
        MY_FEATURE_FACET = pkgInit.myFeatureFacet;
        ACCESS_FACET = pkgInit.accessFacet;
    }

    function packageName() public pure returns (string memory) {
        return type(MyFeatureDFPkg).name;
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts) {
        cuts = new IDiamond.FacetCut[](2);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(MY_FEATURE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MY_FEATURE_FACET.facetFuncs()
        });
        cuts[1] = IDiamond.FacetCut({
            facetAddress: address(ACCESS_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ACCESS_FACET.facetFuncs()
        });
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32) {
        PkgArgs memory args = abi.decode(pkgArgs, (PkgArgs));
        return keccak256(abi.encode(args.name));
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));
        MyFeatureRepo._initialize(args.name);
        MultiStepOwnableRepo._initialize(args.owner);
    }

    function postDeploy(address) public returns (bool) {
        return true;
    }
}
```

## Key Files

- `/contracts/interfaces/IDiamondFactoryPackage.sol` - Interface with sequence diagram
- `/contracts/tokens/ERC20/ERC20DFPkg.sol` - Complete ERC20 example
- `/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` - Factory implementation
