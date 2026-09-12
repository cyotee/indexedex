// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
// Explicit dependencies keep factory-loaded bytecode available in focused builds.
import {UniswapV4DetfExchangeFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfExchangeFacet.sol";
import {UniswapV4DetfBondFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfBondFacet.sol";
import {UniswapV4DetfMaintenanceFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfMaintenanceFacet.sol";
import {UniswapV4DetfClaimFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfClaimFacet.sol";
import {UniswapV4DetfQueryFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfQueryFacet.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

library UniswapV4Detf_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    /// @notice Deploy the complete product selector set as independently sized facets.
    /// @dev Order matches IUniswapV4DetfDFPkg.PkgInit.productFacets.
    function deployUniswapV4DetfFacets(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet[5] memory instances)
    {
        instances[0] = deployUniswapV4DetfExchangeFacet(create3Factory);
        instances[1] = deployUniswapV4DetfBondFacet(create3Factory);
        instances[2] = deployUniswapV4DetfMaintenanceFacet(create3Factory);
        instances[3] = deployUniswapV4DetfClaimFacet(create3Factory);
        instances[4] = deployUniswapV4DetfQueryFacet(create3Factory);
    }

    function deployUniswapV4DetfExchangeFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("UniswapV4DetfExchangeFacet.sol:UniswapV4DetfExchangeFacet");
        instance = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4DetfExchangeFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(instance), "UniswapV4DetfExchangeFacet");
    }

    function deployUniswapV4DetfBondFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("UniswapV4DetfBondFacet.sol:UniswapV4DetfBondFacet");
        instance = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4DetfBondFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(instance), "UniswapV4DetfBondFacet");
    }

    function deployUniswapV4DetfMaintenanceFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("UniswapV4DetfMaintenanceFacet.sol:UniswapV4DetfMaintenanceFacet");
        instance = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4DetfMaintenanceFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(instance), "UniswapV4DetfMaintenanceFacet");
    }

    function deployUniswapV4DetfClaimFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("UniswapV4DetfClaimFacet.sol:UniswapV4DetfClaimFacet");
        instance = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4DetfClaimFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(instance), "UniswapV4DetfClaimFacet");
    }

    function deployUniswapV4DetfQueryFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("UniswapV4DetfQueryFacet.sol:UniswapV4DetfQueryFacet");
        instance = create3Factory.deployFacet(
            initCode_, ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4DetfQueryFacet")._hash(), initCode_, bytes(""))
        );
        vm.label(address(instance), "UniswapV4DetfQueryFacet");
    }

}
