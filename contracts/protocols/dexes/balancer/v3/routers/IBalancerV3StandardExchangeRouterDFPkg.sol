// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

interface IBalancerV3StandardExchangeRouterDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet senderGuardFacet;
        IFacet balancerV3StandardExchangeRouterExactInQueryFacet;
        IFacet balancerV3StandardExchangeRouterExactOutQueryFacet;
        IFacet balancerV3StandardExchangeRouterExactInSwapFacet;
        IFacet balancerV3StandardExchangeRouterExactOutSwapFacet;
        IFacet balancerV3StandardExchangeRouterPrepayFacet;
        IFacet balancerV3StandardExchangeRouterPrepayHooksFacet;
        IFacet balancerV3StandardExchangeBatchRouterExactInFacet;
        IFacet balancerV3StandardExchangeBatchRouterExactOutFacet;
        IFacet balancerV3StandardExchangePermit2WitnessFacet;
        IVault balancerV3Vault;
        IPermit2 permit2;
        IWETH weth;
    }
}
