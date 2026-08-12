// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
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
    IFacet aerodromeStandardExchangeOutQueryFacet;
    IAerodromeStandardExchangeDFPkg aerodromeStandardExchangeDFPkg;

    function setUp() public virtual override(TestBase_Permit2, TestBase_Aerodrome_Pools, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_Aerodrome_Pools.setUp();
        TestBase_VaultComponents.setUp();
        aerodromeStandardExchangeInFacet = create3Factory.deployAerodromeStandardExchangeInFacet();
        aerodromeStandardExchangeOutFacet = create3Factory.deployAerodromeStandardExchangeOutFacet();
        aerodromeStandardExchangeOutQueryFacet = create3Factory.deployAerodromeStandardExchangeOutQueryFacet();
        // Deploy DFPkg as owner (who has operator permissions)
        vm.startPrank(owner);
        {
            IAerodromeStandardExchangeDFPkg.PkgInit memory pkgInit_;
            pkgInit_.erc20Facet = erc20Facet;
            pkgInit_.erc2612Facet = erc2612Facet;
            pkgInit_.erc5267Facet = erc5267Facet;
            pkgInit_.erc4626Facet = erc4626Facet;
            pkgInit_.multiAssetBasicVaultFacet = erc4626BasicVaultFacet;
            pkgInit_.multiAssetStandardVaultFacet = erc4626StandardVaultFacet;
            pkgInit_.aerodromeStandardExchangeInFacet = aerodromeStandardExchangeInFacet;
            pkgInit_.aerodromeStandardExchangeOutFacet = aerodromeStandardExchangeOutFacet;
            pkgInit_.aerodromeStandardExchangeOutQueryFacet = aerodromeStandardExchangeOutQueryFacet;
            pkgInit_.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(indexedexManager));
            pkgInit_.vaultRegistryDeployment = IVaultRegistryDeployment(address(indexedexManager));
            pkgInit_.permit2 = permit2;
            pkgInit_.aerodromeRouter = aerodromeRouter;
            pkgInit_.aerodromePoolFactory = aerodromePoolFactory;
            aerodromeStandardExchangeDFPkg = indexedexManager.deployAerodromeStandardExchangeDFPkg(pkgInit_);
        }
        vm.stopPrank();
    }
}
