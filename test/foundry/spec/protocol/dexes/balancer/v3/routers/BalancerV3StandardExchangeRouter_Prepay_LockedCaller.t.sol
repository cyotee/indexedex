// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
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
import {ISenderGuard} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/ISenderGuard.sol";

import {
    IBalancerV3StandardExchangeRouterDFPkg
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterDFPkg.sol";

import {
    BalancerV3StandardExchangeRouterRepo
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterRepo.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";

import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

interface IBalancerV3StandardExchangeRouterTestHarness {
    function callWithCurrentStandardExchange(IStandardExchangeProxy current, address target, bytes calldata data)
        external
        returns (bytes memory);
}

contract BalancerV3StandardExchangeRouterTestHarnessFacet is IFacet, IBalancerV3StandardExchangeRouterTestHarness {
    using BalancerV3StandardExchangeRouterRepo for *;

    function facetName() public pure returns (string memory name) {
        return type(BalancerV3StandardExchangeRouterTestHarnessFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBalancerV3StandardExchangeRouterTestHarness).interfaceId;
        return interfaces;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IBalancerV3StandardExchangeRouterTestHarness.callWithCurrentStandardExchange.selector;
        return funcs;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }

    function callWithCurrentStandardExchange(IStandardExchangeProxy current, address target, bytes calldata data)
        external
        returns (bytes memory)
    {
        BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(current);

        (bool ok, bytes memory ret) = target.call(data);

        // Always clear, regardless of success.
        BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(IStandardExchangeProxy(address(0)));

        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }

        return ret;
    }
}

contract PrepayAttacker {
    function attackPrepayAddLiquidityUnbalanced(
        address router,
        address pool,
        uint256[] calldata exactAmountsIn,
        uint256 minBptAmountOut
    ) external {
        IBalancerV3StandardExchangeRouterPrepay(router)
            .prepayAddLiquidityUnbalanced(pool, exactAmountsIn, minBptAmountOut, "");
    }
}

contract BalancerV3StandardExchangeRouterDFPkg_WithHarness is IBalancerV3StandardExchangeRouterDFPkg {
    struct PkgInitWithHarness {
        IFacet senderGuardFacet;
        IFacet balancerV3StandardExchangeRouterExactInQueryFacet;
        IFacet balancerV3StandardExchangeRouterExactOutQueryFacet;
        IFacet balancerV3StandardExchangeRouterExactInSwapFacet;
        IFacet balancerV3StandardExchangeRouterExactOutSwapFacet;
        IFacet balancerV3StandardExchangeRouterPrepayFacet;
        IFacet balancerV3StandardExchangeRouterPrepayHooksFacet;
        IFacet balancerV3StandardExchangeBatchRouterExactInFacet;
        IFacet balancerV3StandardExchangeBatchRouterExactOutFacet;
        IFacet testHarnessFacet;
        IVault balancerV3Vault;
        IPermit2 permit2;
        IWETH weth;
    }

    IFacet public immutable SENDER_GUARD_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_QUERY_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_QUERY_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_SWAP_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_SWAP_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_HOOKS_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_IN_FACET;
    IFacet public immutable BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_OUT_FACET;
    IFacet public immutable TEST_HARNESS_FACET;

    IVault public immutable BALANCER_V3_VAULT;
    IPermit2 public immutable PERMIT2;
    IWETH public immutable WETH;

    constructor(PkgInitWithHarness memory pkgInit) {
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
        TEST_HARNESS_FACET = pkgInit.testHarnessFacet;

        BALANCER_V3_VAULT = pkgInit.balancerV3Vault;
        PERMIT2 = pkgInit.permit2;
        WETH = pkgInit.weth;
    }

    function packageName() public pure returns (string memory name_) {
        return type(BalancerV3StandardExchangeRouterDFPkg_WithHarness).name;
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
        facetAddresses_[9] = address(TEST_HARNESS_FACET);
        return facetAddresses_;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        // Keep production interface set unchanged; harness is callable by selector without ERC165 registration.
        interfaces = new bytes4[](9);

        interfaces[0] = type(ISenderGuard).interfaceId;
        interfaces[1] = type(IBalancerV3StandardExchangeRouterExactInSwap).interfaceId;
        interfaces[2] = type(IBalancerV3StandardExchangeRouterExactInSwapQuery).interfaceId;
        interfaces[3] = type(IBalancerV3StandardExchangeRouterExactOutSwap).interfaceId;
        interfaces[4] = type(IBalancerV3StandardExchangeRouterExactOutSwapQuery).interfaceId;
        interfaces[5] = type(IBalancerV3StandardExchangeBatchRouterExactIn).interfaceId;
        interfaces[6] = type(IBalancerV3StandardExchangeBatchRouterExactOut).interfaceId;
        interfaces[7] = type(IBalancerV3StandardExchangeRouterPrepay).interfaceId;
        interfaces[8] = type(IBalancerV3StandardExchangeRouterPrepayHooks).interfaceId;
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
            facetAddress: address(SENDER_GUARD_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: SENDER_GUARD_FACET.facetFuncs()
        });
        facetCuts_[1] = IDiamond.FacetCut({
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_QUERY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_QUERY_FACET.facetFuncs()
        });
        facetCuts_[2] = IDiamond.FacetCut({
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_QUERY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_QUERY_FACET.facetFuncs()
        });
        facetCuts_[3] = IDiamond.FacetCut({
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_SWAP_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_IN_SWAP_FACET.facetFuncs()
        });
        facetCuts_[4] = IDiamond.FacetCut({
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_SWAP_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_ROUTER_EXACT_OUT_SWAP_FACET.facetFuncs()
        });
        facetCuts_[5] = IDiamond.FacetCut({
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_FACET.facetFuncs()
        });
        facetCuts_[6] = IDiamond.FacetCut({
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_HOOKS_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_ROUTER_PREPAY_HOOKS_FACET.facetFuncs()
        });
        facetCuts_[7] = IDiamond.FacetCut({
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_IN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_IN_FACET.facetFuncs()
        });
        facetCuts_[8] = IDiamond.FacetCut({
            facetAddress: address(BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_OUT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BALANCER_V3_STANDARD_EXCHANGE_BATCH_ROUTER_EXACT_OUT_FACET.facetFuncs()
        });
        facetCuts_[9] = IDiamond.FacetCut({
            facetAddress: address(TEST_HARNESS_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: TEST_HARNESS_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory) public pure returns (bytes32) {
        return keccak256(abi.encode(packageName()));
    }

    function processArgs(bytes memory) public pure returns (bytes memory) {
        return "";
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory) public {
        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);
        Permit2AwareRepo._initialize(PERMIT2);
        WETHAwareRepo._initialize(WETH);
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}

contract BalancerV3StandardExchangeRouter_Prepay_LockedCaller_Test is TestBase_BalancerV3StandardExchangeRouter {
    IFacet internal harnessFacet;

    function _deployRouterFacets() internal override {
        super._deployRouterFacets();
        harnessFacet = IFacet(address(new BalancerV3StandardExchangeRouterTestHarnessFacet()));
    }

    function _deployRouterPackage() internal override {
        BalancerV3StandardExchangeRouterDFPkg_WithHarness.PkgInitWithHarness memory pkgInit;
        pkgInit.senderGuardFacet = senderGuardFacet;
        pkgInit.balancerV3StandardExchangeRouterExactInQueryFacet = exactInQueryFacet;
        pkgInit.balancerV3StandardExchangeRouterExactOutQueryFacet = exactOutQueryFacet;
        pkgInit.balancerV3StandardExchangeRouterExactInSwapFacet = exactInSwapFacet;
        pkgInit.balancerV3StandardExchangeRouterExactOutSwapFacet = exactOutSwapFacet;
        pkgInit.balancerV3StandardExchangeRouterPrepayFacet = prepayFacet;
        pkgInit.balancerV3StandardExchangeRouterPrepayHooksFacet = prepayHooksFacet;
        pkgInit.balancerV3StandardExchangeBatchRouterExactInFacet = batchExactInFacet;
        pkgInit.balancerV3StandardExchangeBatchRouterExactOutFacet = batchExactOutFacet;
        pkgInit.testHarnessFacet = harnessFacet;
        pkgInit.balancerV3Vault = IVault(address(vault));
        pkgInit.permit2 = permit2;
        pkgInit.weth = IWETH(address(weth));

        seRouterDFPkg = IBalancerV3StandardExchangeRouterDFPkg(
            address(new BalancerV3StandardExchangeRouterDFPkg_WithHarness(pkgInit))
        );
    }

    function test_prepay_locked_wrongCaller_reverts_when_currentSE_is_set() public {
        // vault is locked in normal context
        assertFalse(vault.isUnlocked(), "precondition: vault should be locked");

        PrepayAttacker attacker = new PrepayAttacker();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        // Set current standard exchange token to a real deployed vault, then attempt prepay from attacker.
        vm.expectRevert(
            abi.encodeWithSelector(
                IBalancerV3StandardExchangeRouterPrepay.NotCurrentStandardExchangeToken.selector,
                address(attacker),
                address(daiUsdcVault)
            )
        );

        IBalancerV3StandardExchangeRouterTestHarness(address(seRouter))
            .callWithCurrentStandardExchange(
                daiUsdcVault,
                address(attacker),
                abi.encodeCall(
                    attacker.attackPrepayAddLiquidityUnbalanced, (address(seRouter), daiUsdcPool, amounts, 1)
                )
            );
    }
}
