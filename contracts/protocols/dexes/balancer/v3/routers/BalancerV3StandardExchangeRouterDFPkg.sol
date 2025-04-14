// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {ISenderGuard} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/ISenderGuard.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";
import {
    IBalancerV3StandardExchangeRouterExactInSwap
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwap.sol";
import {
    IBalancerV3StandardExchangeRouterExactInSwapQuery
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwapQuery.sol";
import {
    IBalancerV3StandardExchangeRouterExactOutSwap
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactOutSwap.sol";
import {
    IBalancerV3StandardExchangeRouterExactOutSwapQuery
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactOutSwapQuery.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactIn
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactIn.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactOut
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactOut.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    IBalancerV3StandardExchangeRouterPrepayHooks
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepayHooks.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IBalancerV3StandardExchangeRouterPermit2Witness} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPermit2Witness.sol";

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

contract BalancerV3StandardExchangeRouterDFPkg is IBalancerV3StandardExchangeRouterDFPkg {
    using BetterEfficientHashLib for bytes;

    IFacet public immutable SENDER_GUARD_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_QUERY_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_QUERY_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_SWAP_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_SWAP_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_HOOKS_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_IN_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_OUT_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_PERMIT2_WITNESS_FACET;
    IVault public immutable BALANCER_V3_VAULT;
    IPermit2 public immutable PERMIT2;
    IWETH public immutable WETH;

    constructor(PkgInit memory pkgInit) {
        SENDER_GUARD_FACET = pkgInit.senderGuardFacet;
        BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_QUERY_FACET =
        pkgInit.balancerV3StandardExchangeRouterExactInQueryFacet;
        BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_QUERY_FACET =
        pkgInit.balancerV3StandardExchangeRouterExactOutQueryFacet;
        BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_SWAP_FACET =
        pkgInit.balancerV3StandardExchangeRouterExactInSwapFacet;
        BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_SWAP_FACET =
        pkgInit.balancerV3StandardExchangeRouterExactOutSwapFacet;
        BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_FACET = pkgInit.balancerV3StandardExchangeRouterPrepayFacet;
        BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_HOOKS_FACET =
        pkgInit.balancerV3StandardExchangeRouterPrepayHooksFacet;
        BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_IN_FACET =
        pkgInit.balancerV3StandardExchangeBatchRouterExactInFacet;
        BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_OUT_FACET =
        pkgInit.balancerV3StandardExchangeBatchRouterExactOutFacet;
        BALANCER_V3_STANDARD_EXCHANGE_PERMIT2_WITNESS_FACET = pkgInit.balancerV3StandardExchangePermit2WitnessFacet;
        BALANCER_V3_VAULT = pkgInit.balancerV3Vault;
        PERMIT2 = pkgInit.permit2;
        WETH = pkgInit.weth;
    }

    /* -------------------------------------------------------------------------- */
    /*                           IDiamondFactoryPackage                           */
    /* -------------------------------------------------------------------------- */

    function packageName() public pure returns (string memory name_) {
        return type(BalancerV3StandardExchangeRouterDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](10);
        facetAddresses_[0] = address(SENDER_GUARD_FACET);
        facetAddresses_[1] = address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_QUERY_FACET);
        facetAddresses_[2] = address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_QUERY_FACET);
        facetAddresses_[3] = address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_SWAP_FACET);
        facetAddresses_[4] = address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_SWAP_FACET);
        facetAddresses_[5] = address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_FACET);
        facetAddresses_[6] = address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_HOOKS_FACET);
        facetAddresses_[7] = address(BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_IN_FACET);
        facetAddresses_[8] = address(BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_OUT_FACET);
        facetAddresses_[9] = address(BALANCER_V3_STANDARD_EXCHANGE_PERMIT2_WITNESS_FACET);
        return facetAddresses_;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](10);

        interfaces[0] = type(ISenderGuard).interfaceId;
        interfaces[1] = type(IBalancerV3StandardExchangeRouterExactInSwap).interfaceId;
        interfaces[2] = type(IBalancerV3StandardExchangeRouterExactInSwapQuery).interfaceId;
        interfaces[3] = type(IBalancerV3StandardExchangeRouterExactOutSwap).interfaceId;
        interfaces[4] = type(IBalancerV3StandardExchangeRouterExactOutSwapQuery).interfaceId;
        interfaces[5] = type(IBalancerV3StandardExchangeBatchRouterExactIn).interfaceId;
        interfaces[6] = type(IBalancerV3StandardExchangeBatchRouterExactOut).interfaceId;
        interfaces[7] = type(IBalancerV3StandardExchangeRouterPrepay).interfaceId;
        interfaces[8] = type(IBalancerV3StandardExchangeRouterPrepayHooks).interfaceId;
        interfaces[9] = type(IBalancerV3StandardExchangeRouterPermit2Witness).interfaceId;
        return interfaces;
    }

    function packageMetadata()
        public
        view
        returns (string memory name_, bytes4[] memory interfaces, address[] memory facets)
    {
        name_ = packageName();
        interfaces = facetInterfaces();
        facets = facetAddresses();
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](10);

        facetCuts_[0] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(SENDER_GUARD_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: SENDER_GUARD_FACET.facetFuncs()
        });
        facetCuts_[1] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_QUERY_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_QUERY_FACET.facetFuncs()
        });
        facetCuts_[2] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_QUERY_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_QUERY_FACET.facetFuncs()
        });
        facetCuts_[3] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_SWAP_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_SWAP_FACET.facetFuncs()
        });
        facetCuts_[4] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_SWAP_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_SWAP_FACET.facetFuncs()
        });
        facetCuts_[5] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_FACET.facetFuncs()
        });
        facetCuts_[6] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_HOOKS_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_HOOKS_FACET.facetFuncs()
        });
        facetCuts_[7] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_IN_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_IN_FACET.facetFuncs()
        });
        facetCuts_[8] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_OUT_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_OUT_FACET.facetFuncs()
        });
        facetCuts_[9] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_PERMIT2_WITNESS_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_PERMIT2_WITNESS_FACET.facetFuncs()
        });
    }

    /**
     * @return config Unified function to retrieved `facetInterfaces()` AND `facetCuts()` in one call.
     */
    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(
        bytes memory /*pkgArgs*/
    )
        public
        pure
        returns (bytes32 salt)
    {
        // return keccak256(abi.encode(pkgArgs));
        return abi.encode(packageName())._hash();
    }

    function processArgs(
        bytes memory /*pkgArgs*/
    )
        public
        pure
        returns (bytes memory processedPkgArgs)
    {
        return "";
    }

    function updatePkg(
        address,
        /* expectedProxy */
        bytes memory /* pkgArgs */
    )
        public
        pure
        virtual
        returns (bool)
    {
        return true;
    }

    function initAccount(
        bytes memory /*initArgs*/
    )
        public
    {
        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);
        Permit2AwareRepo._initialize(PERMIT2);
        WETHAwareRepo._initialize(WETH);
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}
