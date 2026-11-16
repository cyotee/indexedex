# FactoryService Examples

Complete examples of FactoryService libraries for common deployment patterns.

## Access Control FactoryService

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ICreate3Factory} from "@crane/contracts/factories/create3/interfaces/ICreate3Factory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@solady/utils/BetterEfficientHashLib.sol";
import {Vm, VM_ADDRESS} from "forge-std/Vm.sol";

import {OperableFacet} from "@crane/contracts/access/operable/OperableFacet.sol";
import {MultiStepOwnableFacet} from "@crane/contracts/access/ERC8023/MultiStepOwnableFacet.sol";
import {ReentrancyGuardFacet} from "@crane/contracts/access/reentrancy/ReentrancyGuardFacet.sol";

library AccessFacetFactoryService {
    using BetterEfficientHashLib for bytes;
    Vm constant vm = Vm(VM_ADDRESS);

    function deployOperableFacet(
        ICreate3Factory create3Factory
    ) internal returns (IFacet operableFacet) {
        operableFacet = create3Factory.deployFacet(
            type(OperableFacet).creationCode,
            abi.encode(type(OperableFacet).name)._hash()
        );
        vm.label(address(operableFacet), type(OperableFacet).name);
    }

    function deployMultiStepOwnableFacet(
        ICreate3Factory create3Factory
    ) internal returns (IFacet multiStepOwnableFacet) {
        multiStepOwnableFacet = create3Factory.deployFacet(
            type(MultiStepOwnableFacet).creationCode,
            abi.encode(type(MultiStepOwnableFacet).name)._hash()
        );
        vm.label(address(multiStepOwnableFacet), type(MultiStepOwnableFacet).name);
    }

    function deployReentrancyGuardFacet(
        ICreate3Factory create3Factory
    ) internal returns (IFacet reentrancyGuardFacet) {
        reentrancyGuardFacet = create3Factory.deployFacet(
            type(ReentrancyGuardFacet).creationCode,
            abi.encode(type(ReentrancyGuardFacet).name)._hash()
        );
        vm.label(address(reentrancyGuardFacet), type(ReentrancyGuardFacet).name);
    }
}
```

## Introspection FactoryService

```solidity
library IntrospectionFacetFactoryService {
    using BetterEfficientHashLib for bytes;
    Vm constant vm = Vm(VM_ADDRESS);

    function deployERC165Facet(
        ICreate3Factory create3Factory
    ) internal returns (IFacet erc165Facet) {
        erc165Facet = create3Factory.deployFacet(
            type(ERC165Facet).creationCode,
            abi.encode(type(ERC165Facet).name)._hash()
        );
        vm.label(address(erc165Facet), type(ERC165Facet).name);
    }

    function deployDiamondLoupeFacet(
        ICreate3Factory create3Factory
    ) internal returns (IFacet diamondLoupeFacet) {
        diamondLoupeFacet = create3Factory.deployFacet(
            type(DiamondLoupeFacet).creationCode,
            abi.encode(type(DiamondLoupeFacet).name)._hash()
        );
        vm.label(address(diamondLoupeFacet), type(DiamondLoupeFacet).name);
    }

    // Package deployment with constructor args
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

## Token FactoryService

```solidity
library TokenFacetFactoryService {
    using BetterEfficientHashLib for bytes;
    Vm constant vm = Vm(VM_ADDRESS);

    function deployERC20Facet(
        ICreate3Factory create3Factory
    ) internal returns (IFacet erc20Facet) {
        erc20Facet = create3Factory.deployFacet(
            type(ERC20Facet).creationCode,
            abi.encode(type(ERC20Facet).name)._hash()
        );
        vm.label(address(erc20Facet), type(ERC20Facet).name);
    }

    function deployERC20DFPkg(
        ICreate3Factory create3Factory,
        IFacet erc20Facet,
        IFacet erc165Facet,
        IFacet multiStepOwnableFacet
    ) internal returns (IERC20DFPkg erc20DFPkg) {
        erc20DFPkg = IERC20DFPkg(address(
            create3Factory.deployPackageWithArgs(
                type(ERC20DFPkg).creationCode,
                abi.encode(IERC20DFPkg.PkgInit({
                    erc20Facet: erc20Facet,
                    erc165Facet: erc165Facet,
                    multiStepOwnableFacet: multiStepOwnableFacet
                })),
                abi.encode(type(ERC20DFPkg).name)._hash()
            )
        ));
        vm.label(address(erc20DFPkg), type(ERC20DFPkg).name);
    }
}
```

## Usage in Tests

```solidity
contract MyTest is CraneTest {
    using AccessFacetFactoryService for ICreate3Factory;
    using IntrospectionFacetFactoryService for ICreate3Factory;
    using TokenFacetFactoryService for ICreate3Factory;

    IFacet operableFacet;
    IFacet erc165Facet;
    IERC20DFPkg erc20Pkg;

    function setUp() public override {
        super.setUp();

        // Clean deployment using FactoryService
        operableFacet = create3Factory.deployOperableFacet();
        erc165Facet = create3Factory.deployERC165Facet();

        IFacet erc20Facet = create3Factory.deployERC20Facet();
        IFacet multiStepOwnableFacet = create3Factory.deployMultiStepOwnableFacet();

        erc20Pkg = create3Factory.deployERC20DFPkg(
            erc20Facet,
            erc165Facet,
            multiStepOwnableFacet
        );
    }
}
```

## Conventions

1. **Library name**: `{Domain}FacetFactoryService`
2. **Function name**: `deploy{ContractName}`
3. **Salt**: Always `abi.encode(type(X).name)._hash()`
4. **Labeling**: Always `vm.label()` deployed contracts
5. **Return type**: Interface type, not concrete type
