# FactoryService Pattern

FactoryService libraries encapsulate CREATE3 deployment logic for related facets and packages.

## Purpose

Group deployment functions by domain:
- `AccessFacetFactoryService` - Access control facets
- `IntrospectionFacetFactoryService` - ERC165, ERC2535 facets
- `TokenFacetFactoryService` - ERC20, ERC721 facets

## Structure

```solidity
library IntrospectionFacetFactoryService {
    using BetterEfficientHashLib for bytes;
    Vm constant vm = Vm(VM_ADDRESS);

    // Deploy a facet - salt derived from type name
    function deployERC165Facet(
        ICreate3Factory create3Factory
    ) internal returns (IFacet erc165Facet) {
        erc165Facet = create3Factory.deployFacet(
            type(ERC165Facet).creationCode,
            abi.encode(type(ERC165Facet).name)._hash()  // Deterministic salt
        );
        vm.label(address(erc165Facet), type(ERC165Facet).name);  // Label for traces
    }

    // Deploy a package - includes constructor args
    function deployDiamondCutDFPkg(
        ICreate3Factory create3Factory,
        IFacet multiStepOwnableFacet,
        IFacet diamondCutFacet
    ) internal returns (IDiamondCutFacetDFPkg diamondCutDFPkg) {
        diamondCutDFPkg = IDiamondCutFacetDFPkg(address(
            create3Factory.deployPackageWithArgs(
                type(DiamondCutFacetDFPkg).creationCode,
                abi.encode(IDiamondCutFacetDFPkg.PkgInit({
                    diamondCutFacet: diamondCutFacet,
                    multiStepOwnableFacet: multiStepOwnableFacet
                })),
                abi.encode(type(DiamondCutFacetDFPkg).name)._hash()
            )
        ));
        vm.label(address(diamondCutDFPkg), type(DiamondCutFacetDFPkg).name);
    }
}
```

## Key Conventions

### Salt from Type Name

Always derive salt from the type name for deterministic addresses:

```solidity
abi.encode(type(MyFacet).name)._hash()
```

### Label Deployed Contracts

Always label for debugging with `vm.label()`:

```solidity
vm.label(address(facet), type(MyFacet).name);
```

### Use Appropriate Deploy Method

| Contract Type | Method |
|---------------|--------|
| Facet (no constructor args) | `deployFacet()` |
| Package (has constructor args) | `deployPackageWithArgs()` |
| Any contract | `deploy()` |

### Group by Domain

Organize FactoryService libraries by feature area:

```
contracts/
├── access/
│   └── AccessFacetFactoryService.sol
├── introspection/
│   └── IntrospectionFacetFactoryService.sol
└── tokens/
    └── TokenFacetFactoryService.sol
```

## Complete Example

```solidity
library MyFeatureFactoryService {
    using BetterEfficientHashLib for bytes;
    Vm constant vm = Vm(VM_ADDRESS);

    function deployMyFeatureFacet(
        ICreate3Factory create3Factory
    ) internal returns (IFacet myFeatureFacet) {
        myFeatureFacet = create3Factory.deployFacet(
            type(MyFeatureFacet).creationCode,
            abi.encode(type(MyFeatureFacet).name)._hash()
        );
        vm.label(address(myFeatureFacet), type(MyFeatureFacet).name);
    }

    function deployMyFeatureDFPkg(
        ICreate3Factory create3Factory,
        IFacet myFeatureFacet,
        IFacet accessFacet
    ) internal returns (IMyFeatureDFPkg pkg) {
        pkg = IMyFeatureDFPkg(address(
            create3Factory.deployPackageWithArgs(
                type(MyFeatureDFPkg).creationCode,
                abi.encode(IMyFeatureDFPkg.PkgInit({
                    myFeatureFacet: myFeatureFacet,
                    accessFacet: accessFacet
                })),
                abi.encode(type(MyFeatureDFPkg).name)._hash()
            )
        ));
        vm.label(address(pkg), type(MyFeatureDFPkg).name);
    }
}
```

## Key Files

- `/contracts/access/AccessFacetFactoryService.sol` - Access control deployments
- `/contracts/introspection/IntrospectionFacetFactoryService.sol` - Introspection deployments
- `/contracts/InitDevService.sol` - Factory initialization for tests/scripts
