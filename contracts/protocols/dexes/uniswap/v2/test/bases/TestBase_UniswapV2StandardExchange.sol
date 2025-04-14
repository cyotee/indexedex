// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {TestBase_UniswapV2} from "@crane/contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {BetterPermit2} from "@crane/contracts/protocols/utils/permit2/BetterPermit2.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {
    IUniswapV2StandardExchangeDFPkg,
    UniswapV2StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {
    UniswapV2_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol";

contract TestBase_UniswapV2StandardExchange is TestBase_Permit2, TestBase_UniswapV2, TestBase_VaultComponents {
    using UniswapV2_Component_FactoryService for IFacet;
    using UniswapV2_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV2_Component_FactoryService for IIndexedexManagerProxy;

    IFacet uniswapV2StandardExchangeInFacet;
    IFacet uniswapV2StandardExchangeOutFacet;
    IUniswapV2StandardExchangeDFPkg uniswapV2StandardExchangeDFPkg;

    function setUp() public virtual override(TestBase_Permit2, TestBase_UniswapV2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_UniswapV2.setUp();
        TestBase_VaultComponents.setUp();
        uniswapV2StandardExchangeInFacet = create3Factory.deployUniswapV2StandardExchangeInFacet();
        uniswapV2StandardExchangeOutFacet = create3Factory.deployUniswapV2StandardExchangeOutFacet();
        // Deploy package as owner (who is an operator on the vaultRegistry/indexedexManager)
        vm.startPrank(owner);
        uniswapV2StandardExchangeDFPkg = indexedexManager.deployUniswapV2StandardExchangeDFPkg(
            erc20Facet.buildArgsUniswapV2StandardExchangePkgInit(
                erc2612Facet,
                erc5267Facet,
                erc4626Facet,
                erc4626BasicVaultFacet,
                erc4626StandardVaultFacet,
                uniswapV2StandardExchangeInFacet,
                uniswapV2StandardExchangeOutFacet,
                indexedexManager,
                indexedexManager,
                permit2,
                uniswapV2Factory,
                uniswapV2Router
            )
        );
        vm.stopPrank();
    }
}
