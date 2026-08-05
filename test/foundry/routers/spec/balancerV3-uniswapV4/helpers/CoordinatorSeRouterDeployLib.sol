// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {SenderGuardFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/SenderGuardFacet.sol";
import {
    IBalancerV3StandardExchangeRouterDFPkg
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterDFPkg.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    BalancerV3StandardExchangeRouter_FactoryService
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_FactoryService.sol";

/// @dev Stack-safe SE diamond deploy for coordinator hermetic tests (public library funcs).
library CoordinatorSeRouterDeployLib {
    using BalancerV3StandardExchangeRouter_FactoryService for *;

    function deploy(
        ICreate3FactoryProxy create3Factory,
        IDiamondPackageCallBackFactory diamondPackageFactory,
        IVault vault,
        IPermit2 permit2,
        IWETH weth
    ) public returns (IBalancerV3StandardExchangeRouterProxy se) {
        IBalancerV3StandardExchangeRouterDFPkg.PkgInit memory pkgInit = _pkgInit(create3Factory, vault, permit2, weth);
        IBalancerV3StandardExchangeRouterDFPkg sePkg =
            create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(pkgInit);
        se = diamondPackageFactory.deployBalancerV3StandardExchangeRouter(sePkg);
    }

    function _pkgInit(ICreate3FactoryProxy create3Factory, IVault vault, IPermit2 permit2, IWETH weth)
        private
        returns (IBalancerV3StandardExchangeRouterDFPkg.PkgInit memory pkgInit)
    {
        pkgInit.senderGuardFacet = IFacet(address(new SenderGuardFacet()));
        pkgInit.balancerV3StandardExchangeRouterExactInQueryFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterExactInQueryFacet();
        pkgInit.balancerV3StandardExchangeRouterExactInSwapFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterExactInSwapFacet();
        pkgInit.balancerV3StandardExchangeRouterExactOutQueryFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterExactOutQueryFacet();
        pkgInit.balancerV3StandardExchangeRouterExactOutSwapFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterExactOutSwapFacet();
        pkgInit.balancerV3StandardExchangeBatchRouterExactInFacet =
            create3Factory.deployBalancerV3StandardExchangeBatchRouterExactInFacet();
        pkgInit.balancerV3StandardExchangeBatchRouterExactOutFacet =
            create3Factory.deployBalancerV3StandardExchangeBatchRouterExactOutFacet();
        pkgInit.balancerV3StandardExchangeRouterPrepayFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterPrepayFacet();
        pkgInit.balancerV3StandardExchangeRouterPrepayHooksFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterPrepayHooksFacet();
        pkgInit.balancerV3StandardExchangePermit2WitnessFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterPermit2WitnessFacet();
        pkgInit.balancerV3Vault = vault;
        pkgInit.permit2 = permit2;
        pkgInit.weth = weth;
    }
}
