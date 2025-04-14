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
// import {TestBase_Aerodrome} from "@crane/contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_Aerodrome.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {Pool} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol";
import {TestBase_CamelotV2} from "@crane/contracts/protocols/dexes/camelot/v2/test/bases/TestBase_CamelotV2.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {
    ICamelotV2StandardExchangeDFPkg,
    CamelotV2StandardExchangeDFPkg
} from "contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeDFPkg.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {
    CamelotV2_Component_FactoryService
} from "contracts/protocols/dexes/camelot/v2/CamelotV2_Component_FactoryService.sol";

contract TestBase_CamelotV2StandardExchange is TestBase_Permit2, TestBase_CamelotV2, TestBase_VaultComponents {
    using CamelotV2_Component_FactoryService for ICreate3FactoryProxy;
    // using CamelotV2_Component_FactoryService for IDiamondPackageCallBackFactory;
    // using CamelotV2_Component_FactoryService for IVaultRegistryDeployment;
    using CamelotV2_Component_FactoryService for IIndexedexManagerProxy;

    IFacet camelotV2StandardExchangeInFacet;
    IFacet camelotV2StandardExchangeOutFacet;
    ICamelotV2StandardExchangeDFPkg camelotV2StandardExchangeDFPkg;

    function setUp() public virtual override(TestBase_Permit2, TestBase_CamelotV2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_CamelotV2.setUp();
        TestBase_VaultComponents.setUp();
        camelotV2StandardExchangeInFacet = create3Factory.deployCamelotV2StandardExchangeInFacet();
        camelotV2StandardExchangeOutFacet = create3Factory.deployCamelotV2StandardExchangeOutFacet();
        vm.prank(owner);
        camelotV2StandardExchangeDFPkg = indexedexManager.deployCamelotV2StandardExchangeDFPkg(_buildCamelotV2PkgInit());
    }

    function _buildCamelotV2PkgInit() internal view returns (ICamelotV2StandardExchangeDFPkg.PkgInit memory) {
        return ICamelotV2StandardExchangeDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc2612Facet: erc2612Facet,
            erc5267Facet: erc5267Facet,
            erc4626Facet: erc4626Facet,
            erc4626BasicVaultFacet: erc4626BasicVaultFacet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            camelotV2StandardExchangeInFacet: camelotV2StandardExchangeInFacet,
            camelotV2StandardExchangeOutFacet: camelotV2StandardExchangeOutFacet,
            vaultFeeOracleQuery: indexedexManager,
            vaultRegistryDeployment: indexedexManager,
            permit2: permit2,
            camelotV2Factory: camelotV2Factory,
            camelotV2Router: camelotV2Router
        });
    }
}
