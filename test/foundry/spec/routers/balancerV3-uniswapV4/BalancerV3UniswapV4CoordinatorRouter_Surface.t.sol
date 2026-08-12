// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETHTestToken} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/WETHTestToken.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    TestBase_BalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/TestBase_BalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouter_FactoryService
} from "contracts/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol";

/**
 * @title BalancerV3UniswapV4CoordinatorRouter_Surface_Test
 * @notice WP-J-RTR-001 / TCA-RTR-003: Target ⊆ facetFuncs ⊆ loupe ⊆ **proxy** smoke (not facet impl alone).
 */
contract BalancerV3UniswapV4CoordinatorRouter_Surface_Test is TestBase_BalancerV3UniswapV4CoordinatorRouter {
    using BalancerV3UniswapV4CoordinatorRouter_FactoryService for *;

    IWETH internal weth;
    IFacet internal exactInFacet;
    IFacet internal queryFacet;
    IFacet internal adminFacet;
    IFacet internal witnessFacet;

    function setUp() public override {
        super.setUp();
        weth = IWETH(address(new WETHTestToken()));

        // CREATE3 facets are idempotent — capture addresses then deploy diamond (same salts).
        exactInFacet = BalancerV3UniswapV4CoordinatorRouter_FactoryService.deployExactInFacet(create3Factory);
        queryFacet = BalancerV3UniswapV4CoordinatorRouter_FactoryService.deployQueryFacet(create3Factory);
        adminFacet = BalancerV3UniswapV4CoordinatorRouter_FactoryService.deployAdminFacet(create3Factory);
        witnessFacet = BalancerV3UniswapV4CoordinatorRouter_FactoryService.deployPermit2WitnessFacet(create3Factory);

        IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[] memory seed =
            new IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[](1);
        seed[0] = IBalancerV3UniswapV4CoordinatorRouter.InitialRouter({
            router: address(0xBEEF), kind: IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        });
        _deployCoordinator(weth, address(0), seed);
    }

    function _contains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    /* ---------------------------------------------------------------------- */
    /*  J1: Target / interface money+admin selectors ⊆ facetFuncs             */
    /* ---------------------------------------------------------------------- */

    /// @notice J1: ExactIn money entrypoints are cut into facetFuncs.
    function test_J1_exactIn_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = exactInFacet.facetFuncs();
        assertTrue(
            _contains(funcs_, IBalancerV3UniswapV4CoordinatorRouter.swapExactInWithPermit.selector),
            "J1 swapExactInWithPermit"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3UniswapV4CoordinatorRouter.swapExactInEth.selector), "J1 swapExactInEth"
        );
        assertEq(funcs_.length, 2, "J1 ExactIn facetFuncs length");
    }

    /// @notice J1: Query surface is cut.
    function test_J1_query_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = queryFacet.facetFuncs();
        assertTrue(_contains(funcs_, IBalancerV3UniswapV4CoordinatorRouter.queryExactIn.selector), "J1 queryExactIn");
        assertEq(funcs_.length, 1, "J1 Query facetFuncs length");
    }

    /// @notice J1: Admin / rescue / allowlist controls are cut.
    function test_J1_admin_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = adminFacet.facetFuncs();
        assertTrue(
            _contains(funcs_, IBalancerV3UniswapV4CoordinatorRouter.registerRouter.selector), "J1 registerRouter"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3UniswapV4CoordinatorRouter.unregisterRouter.selector), "J1 unregisterRouter"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3UniswapV4CoordinatorRouter.isRouterAllowed.selector), "J1 isRouterAllowed"
        );
        assertTrue(_contains(funcs_, IBalancerV3UniswapV4CoordinatorRouter.routerKind.selector), "J1 routerKind");
        assertTrue(
            _contains(funcs_, IBalancerV3UniswapV4CoordinatorRouter.allowedRouterCount.selector),
            "J1 allowedRouterCount"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3UniswapV4CoordinatorRouter.allowedRouterAt.selector), "J1 allowedRouterAt"
        );
        assertTrue(_contains(funcs_, IBalancerV3UniswapV4CoordinatorRouter.rescueTokens.selector), "J1 rescueTokens");
        assertTrue(_contains(funcs_, IBalancerV3UniswapV4CoordinatorRouter.rescueETH.selector), "J1 rescueETH");
        assertEq(funcs_.length, 8, "J1 Admin facetFuncs length");
    }

    /// @notice J1: Permit2 witness getters are cut.
    function test_J1_witness_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = witnessFacet.facetFuncs();
        assertTrue(
            _contains(funcs_, IBalancerV3UniswapV4CoordinatorRouter.WITNESS_TYPE_STRING.selector),
            "J1 WITNESS_TYPE_STRING"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3UniswapV4CoordinatorRouter.WITNESS_TYPEHASH.selector), "J1 WITNESS_TYPEHASH"
        );
        assertEq(funcs_.length, 2, "J1 Witness facetFuncs length");
    }

    /* ---------------------------------------------------------------------- */
    /*  J2: facetFuncs ⊆ loupe on production proxy                            */
    /* ---------------------------------------------------------------------- */

    function _assertFacetFuncsOnLoupe(IFacet facet_, address expectedFacet_) internal view {
        bytes4[] memory funcs_ = facet_.facetFuncs();
        IDiamondLoupe loupe_ = IDiamondLoupe(address(coordinator));
        for (uint256 i; i < funcs_.length; ++i) {
            address loupeFacet_ = loupe_.facetAddress(funcs_[i]);
            assertEq(loupeFacet_, expectedFacet_, "J2 loupe maps selector to CREATE3 facet");
            assertTrue(loupeFacet_ != address(0), "J2 not zero");
            assertTrue(loupeFacet_ != address(coordinator), "J2 not self-facet");
        }
    }

    /// @notice J2: ExactIn facetFuncs registered on proxy loupe to CREATE3 ExactIn facet.
    function test_J2_exactIn_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(exactInFacet, address(exactInFacet));
    }

    /// @notice J2: Query facetFuncs on proxy loupe.
    function test_J2_query_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(queryFacet, address(queryFacet));
    }

    /// @notice J2: Admin facetFuncs on proxy loupe.
    function test_J2_admin_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(adminFacet, address(adminFacet));
    }

    /// @notice J2: Witness facetFuncs on proxy loupe.
    function test_J2_witness_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(witnessFacet, address(witnessFacet));
    }

    /* ---------------------------------------------------------------------- */
    /*  J3: proxy smoke — loupe-routed calls (not facet impl address)         */
    /* ---------------------------------------------------------------------- */

    /// @notice J3: money + view selectors execute on the production diamond proxy.
    function test_J3_proxySmoke_moneyAndAdminViews() public {
        IBalancerV3UniswapV4CoordinatorRouter proxy_ = coordinator;
        IDiamondLoupe loupe_ = IDiamondLoupe(address(proxy_));

        // View surface via proxy
        assertTrue(bytes(proxy_.WITNESS_TYPE_STRING()).length > 0, "J3 witness string on proxy");
        assertTrue(proxy_.WITNESS_TYPEHASH() != bytes32(0), "J3 witness typehash on proxy");
        assertTrue(proxy_.isRouterAllowed(address(0xBEEF)), "J3 isRouterAllowed on proxy");
        assertEq(
            uint8(proxy_.routerKind(address(0xBEEF))),
            uint8(IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router),
            "J3 routerKind on proxy"
        );
        assertEq(proxy_.allowedRouterCount(), 1, "J3 allowedRouterCount on proxy");
        assertEq(proxy_.allowedRouterAt(0), address(0xBEEF), "J3 allowedRouterAt on proxy");
        assertEq(IMultiStepOwnable(address(proxy_)).owner(), owner, "J3 owner on proxy");

        // Mutating admin surface via proxy (not facet impl)
        address r = address(0xCAFE);
        proxy_.registerRouter(r, IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.IndexedExSERouter);
        assertTrue(proxy_.isRouterAllowed(r), "J3 register on proxy");
        proxy_.unregisterRouter(r);
        assertFalse(proxy_.isRouterAllowed(r), "J3 unregister on proxy");

        // Money selector product fail on proxy (not FunctionNotFound / missing cut)
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](0);
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory emptyParams = IBalancerV3UniswapV4CoordinatorRouter
            .SwapExactInParams({
            recipient: bob,
            tokenIn: address(weth),
            amountIn: 1e18,
            tokenOut: address(weth),
            minAmountOut: 0,
            deadline: block.timestamp + 1 days,
            ethIn: true,
            ethOut: false,
            steps: steps
        });
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.EmptyRoute.selector);
        proxy_.swapExactInEth{value: 1e18}(emptyParams);

        // Loupe: money selector routes to CREATE3 ExactIn facet, not proxy self
        address loupeExactIn_ =
            loupe_.facetAddress(IBalancerV3UniswapV4CoordinatorRouter.swapExactInWithPermit.selector);
        assertEq(loupeExactIn_, address(exactInFacet), "J3 withPermit loupe");
        assertTrue(loupeExactIn_ != address(proxy_), "J3 not self-facet");

        address loupeEth_ = loupe_.facetAddress(IBalancerV3UniswapV4CoordinatorRouter.swapExactInEth.selector);
        assertEq(loupeEth_, address(exactInFacet), "J3 eth entry loupe");

        address loupeQuery_ = loupe_.facetAddress(IBalancerV3UniswapV4CoordinatorRouter.queryExactIn.selector);
        assertEq(loupeQuery_, address(queryFacet), "J3 query loupe");
    }

    /// @notice J facet metadata parity on CREATE3 ExactIn facet.
    function test_J_facetMetadata_exactIn_matches_CREATE3_facet() public view {
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = exactInFacet.facetMetadata();
        assertEq(
            keccak256(bytes(name_)),
            keccak256(bytes("BalancerV3UniswapV4CoordinatorRouterExactInFacet")),
            "J metadata name"
        );
        assertTrue(ifaces_.length >= 1, "J interfaces");
        assertEq(exactInFacet.facetFuncs().length, funcs_.length, "J funcs match metadata");
        assertEq(
            keccak256(abi.encodePacked(funcs_)),
            keccak256(abi.encodePacked(exactInFacet.facetFuncs())),
            "J metadata funcs == facetFuncs"
        );
    }
}
