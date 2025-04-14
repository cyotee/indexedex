// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {TestBase_UniswapV2} from "@crane/contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {BetterPermit2} from "@crane/contracts/protocols/utils/permit2/BetterPermit2.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";

import {IRouter} from "@crane/contracts/protocols/dexes/aerodrome/v1/interfaces/IRouter.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {Pool} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol";
import {
    TestBase_Aerodrome_Pools
} from "@crane/contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_Aerodrome_Pools.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {
    IAerodromeStandardExchangeDFPkg,
    AerodromeStandardExchangeDFPkg
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {
    Aerodrome_Component_FactoryService
} from "contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol";

/**
 * @title TestBase_AerodromeStandardExchange
 * @notice Test base for Aerodrome Standard Exchange vault testing.
 * @dev Inherits from:
 *      - TestBase_Permit2: Provides permit2 contract
 *      - TestBase_Aerodrome_Pools: Provides Aerodrome router, factory, and 3 pool configurations
 *      - TestBase_VaultComponents: Provides core vault facets and IndexedexManager
 */
contract TestBase_AerodromeStandardExchange is TestBase_Permit2, TestBase_Aerodrome_Pools, TestBase_VaultComponents {
    using Aerodrome_Component_FactoryService for ICreate3FactoryProxy;
    // using Aerodrome_Component_FactoryService for IDiamondPackageCallBackFactory;
    // using Aerodrome_Component_FactoryService for IVaultRegistryDeployment;
    using Aerodrome_Component_FactoryService for IIndexedexManagerProxy;

    IFacet aerodromeStandardExchangeInFacet;
    IFacet aerodromeStandardExchangeOutFacet;
    IAerodromeStandardExchangeDFPkg aerodromeStandardExchangeDFPkg;

    function setUp() public virtual override(TestBase_Permit2, TestBase_Aerodrome_Pools, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_Aerodrome_Pools.setUp();
        TestBase_VaultComponents.setUp();
        aerodromeStandardExchangeInFacet = create3Factory.deployAerodromeStandardExchangeInFacet();
        aerodromeStandardExchangeOutFacet = create3Factory.deployAerodromeStandardExchangeOutFacet();
        // Deploy DFPkg as owner (who has operator permissions)
        vm.startPrank(owner);
        aerodromeStandardExchangeDFPkg = indexedexManager.deployAerodromeStandardExchangeDFPkg(
            // IVaultRegistryDeployment vaultRegistry,
            // IFacet erc20Facet,
            erc20Facet,
            // IFacet erc2612Facet,
            erc2612Facet,
            // IFacet erc5267Facet,
            erc5267Facet,
            // IFacet erc4626Facet,
            erc4626Facet,
            // IFacet erc4626BasicVaultFacet,
            erc4626BasicVaultFacet,
            // IFacet erc4626StandardVaultFacet,
            erc4626StandardVaultFacet,
            // IFacet aerodromeStandardExchangeInFacet,
            aerodromeStandardExchangeInFacet,
            // IFacet aerodromeStandardExchangeOutFacet,
            aerodromeStandardExchangeOutFacet,
            // IVaultFeeOracleQuery vaultFeeOracleQuery,
            indexedexManager,
            // IVaultRegistryDeployment vaultRegistryDeployment,
            indexedexManager,
            permit2,
            // IRouter aerodromeRouter
            aerodromeRouter,
            aerodromePoolFactory
        );
        vm.stopPrank();
    }
}
