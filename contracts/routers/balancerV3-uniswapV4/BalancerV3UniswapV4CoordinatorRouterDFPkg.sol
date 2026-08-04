// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter,
    IBalancerV3UniswapV4CoordinatorRouterDFPkg
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterRepo
} from "contracts/routers/balancerV3-uniswapV4/common/BalancerV3UniswapV4CoordinatorRouterRepo.sol";

contract BalancerV3UniswapV4CoordinatorRouterDFPkg is
    IBalancerV3UniswapV4CoordinatorRouterDFPkg,
    IDiamondFactoryPackage
{
    using BetterEfficientHashLib for bytes;

    IFacet public immutable MULTI_STEP_OWNABLE_FACET;
    IFacet public immutable EXACT_IN_FACET;
    IFacet public immutable QUERY_FACET;
    IFacet public immutable ADMIN_FACET;
    IFacet public immutable PERMIT2_WITNESS_FACET;
    IPermit2 public immutable PERMIT2;
    IWETH public immutable WETH;
    address public immutable V4_QUOTER;

    constructor(PkgInit memory pkgInit) {
        MULTI_STEP_OWNABLE_FACET = pkgInit.multiStepOwnableFacet;
        EXACT_IN_FACET = pkgInit.exactInFacet;
        QUERY_FACET = pkgInit.queryFacet;
        ADMIN_FACET = pkgInit.adminFacet;
        PERMIT2_WITNESS_FACET = pkgInit.permit2WitnessFacet;
        PERMIT2 = pkgInit.permit2;
        WETH = pkgInit.weth;
        V4_QUOTER = pkgInit.v4Quoter;
    }

    function packageName() public pure returns (string memory) {
        return type(BalancerV3UniswapV4CoordinatorRouterDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](5);
        facetAddresses_[0] = address(MULTI_STEP_OWNABLE_FACET);
        facetAddresses_[1] = address(EXACT_IN_FACET);
        facetAddresses_[2] = address(QUERY_FACET);
        facetAddresses_[3] = address(ADMIN_FACET);
        facetAddresses_[4] = address(PERMIT2_WITNESS_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IMultiStepOwnable).interfaceId;
        interfaces[1] = type(IBalancerV3UniswapV4CoordinatorRouter).interfaceId;
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
        facetCuts_ = new IDiamond.FacetCut[](5);
        facetCuts_[0] = IDiamond.FacetCut({
            facetAddress: address(MULTI_STEP_OWNABLE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_STEP_OWNABLE_FACET.facetFuncs()
        });
        facetCuts_[1] = IDiamond.FacetCut({
            facetAddress: address(EXACT_IN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: EXACT_IN_FACET.facetFuncs()
        });
        facetCuts_[2] = IDiamond.FacetCut({
            facetAddress: address(QUERY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: QUERY_FACET.facetFuncs()
        });
        facetCuts_[3] = IDiamond.FacetCut({
            facetAddress: address(ADMIN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ADMIN_FACET.facetFuncs()
        });
        facetCuts_[4] = IDiamond.FacetCut({
            facetAddress: address(PERMIT2_WITNESS_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: PERMIT2_WITNESS_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        return pkgArgs._hash();
    }

    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory processedPkgArgs) {
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));
        MultiStepOwnableRepo._initialize(args.owner, 1 days);
        Permit2AwareRepo._initialize(PERMIT2);
        WETHAwareRepo._initialize(WETH);
        BalancerV3UniswapV4CoordinatorRouterRepo._setV4Quoter(V4_QUOTER);

        uint256 n = args.initialRouters.length;
        for (uint256 i; i < n; ++i) {
            BalancerV3UniswapV4CoordinatorRouterRepo._registerRouter(
                args.initialRouters[i].router, args.initialRouters[i].kind
            );
        }
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}
