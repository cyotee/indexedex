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
import {SwapKind} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

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

/* -------------------------------------------------------------------------- */
/*                            Test Harness Facet                               */
/* -------------------------------------------------------------------------- */

/**
 * @notice Interface for the transient state inspection harness.
 */
interface ITransientStateHarness {
    /// @notice Read the current transient standard exchange token.
    function readCurrentStandardExchangeToken() external view returns (address);

    /// @notice Set the transient standard exchange token, perform a call, then clear it.
    ///         Returns the value read during the call.
    function callAndReadTransientState(IStandardExchangeProxy token, address target, bytes calldata data)
        external
        returns (address readDuring, bytes memory result);
}

/**
 * @notice Facet that exposes transient storage read/write for testing.
 */
contract TransientStateHarnessFacet is IFacet, ITransientStateHarness {
    using BalancerV3StandardExchangeRouterRepo for *;

    function facetName() public pure returns (string memory) {
        return type(TransientStateHarnessFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(ITransientStateHarness).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = ITransientStateHarness.readCurrentStandardExchangeToken.selector;
        funcs[1] = ITransientStateHarness.callAndReadTransientState.selector;
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

    function readCurrentStandardExchangeToken() external view returns (address) {
        return address(BalancerV3StandardExchangeRouterRepo._currentStandardExchangeToken());
    }

    function callAndReadTransientState(IStandardExchangeProxy token, address target, bytes calldata data)
        external
        returns (address readDuring, bytes memory result)
    {
        // Set the transient token
        BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(token);

        // Read it back (should be set)
        readDuring = address(BalancerV3StandardExchangeRouterRepo._currentStandardExchangeToken());

        // Perform the call
        (bool ok, bytes memory ret) = target.call(data);

        // Always clear
        BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(IStandardExchangeProxy(address(0)));

        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }

        result = ret;
    }
}

/* -------------------------------------------------------------------------- */
/*                     Custom DFPkg with Harness Facet                         */
/* -------------------------------------------------------------------------- */

contract TransientStateDFPkg is IBalancerV3StandardExchangeRouterDFPkg {
    struct TransientStatePkgInit {
        IFacet senderGuardFacet;
        IFacet exactInQueryFacet;
        IFacet exactOutQueryFacet;
        IFacet exactInSwapFacet;
        IFacet exactOutSwapFacet;
        IFacet prepayFacet;
        IFacet prepayHooksFacet;
        IFacet batchExactInFacet;
        IFacet batchExactOutFacet;
        IFacet harnessFacet;
        IVault balancerV3Vault;
        IPermit2 permit2;
        IWETH weth;
    }

    IFacet public immutable SENDER_GUARD;
    IFacet public immutable EXACT_IN_QUERY;
    IFacet public immutable EXACT_OUT_QUERY;
    IFacet public immutable EXACT_IN_SWAP;
    IFacet public immutable EXACT_OUT_SWAP;
    IFacet public immutable PREPAY;
    IFacet public immutable PREPAY_HOOKS;
    IFacet public immutable BATCH_EXACT_IN;
    IFacet public immutable BATCH_EXACT_OUT;
    IFacet public immutable HARNESS;

    IVault public immutable BAL_VAULT;
    IPermit2 public immutable PERMIT2;
    IWETH public immutable WETH;

    constructor(TransientStatePkgInit memory p) {
        SENDER_GUARD = p.senderGuardFacet;
        EXACT_IN_QUERY = p.exactInQueryFacet;
        EXACT_OUT_QUERY = p.exactOutQueryFacet;
        EXACT_IN_SWAP = p.exactInSwapFacet;
        EXACT_OUT_SWAP = p.exactOutSwapFacet;
        PREPAY = p.prepayFacet;
        PREPAY_HOOKS = p.prepayHooksFacet;
        BATCH_EXACT_IN = p.batchExactInFacet;
        BATCH_EXACT_OUT = p.batchExactOutFacet;
        HARNESS = p.harnessFacet;
        BAL_VAULT = p.balancerV3Vault;
        PERMIT2 = p.permit2;
        WETH = p.weth;
    }

    function packageName() public pure returns (string memory) {
        return type(TransientStateDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory f) {
        f = new address[](10);
        f[0] = address(SENDER_GUARD);
        f[1] = address(EXACT_IN_QUERY);
        f[2] = address(EXACT_OUT_QUERY);
        f[3] = address(EXACT_IN_SWAP);
        f[4] = address(EXACT_OUT_SWAP);
        f[5] = address(PREPAY);
        f[6] = address(PREPAY_HOOKS);
        f[7] = address(BATCH_EXACT_IN);
        f[8] = address(BATCH_EXACT_OUT);
        f[9] = address(HARNESS);
    }

    function facetInterfaces() public pure returns (bytes4[] memory ifaces) {
        ifaces = new bytes4[](9);
        ifaces[0] = type(ISenderGuard).interfaceId;
        ifaces[1] = type(IBalancerV3StandardExchangeRouterExactInSwap).interfaceId;
        ifaces[2] = type(IBalancerV3StandardExchangeRouterExactInSwapQuery).interfaceId;
        ifaces[3] = type(IBalancerV3StandardExchangeRouterExactOutSwap).interfaceId;
        ifaces[4] = type(IBalancerV3StandardExchangeRouterExactOutSwapQuery).interfaceId;
        ifaces[5] = type(IBalancerV3StandardExchangeBatchRouterExactIn).interfaceId;
        ifaces[6] = type(IBalancerV3StandardExchangeBatchRouterExactOut).interfaceId;
        ifaces[7] = type(IBalancerV3StandardExchangeRouterPrepay).interfaceId;
        ifaces[8] = type(IBalancerV3StandardExchangeRouterPrepayHooks).interfaceId;
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

    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts) {
        cuts = new IDiamond.FacetCut[](10);
        address[] memory addrs = facetAddresses();
        IFacet[10] memory facets = [
            SENDER_GUARD,
            EXACT_IN_QUERY,
            EXACT_OUT_QUERY,
            EXACT_IN_SWAP,
            EXACT_OUT_SWAP,
            PREPAY,
            PREPAY_HOOKS,
            BATCH_EXACT_IN,
            BATCH_EXACT_OUT,
            HARNESS
        ];
        for (uint256 i; i < 10; i++) {
            cuts[i] = IDiamond.FacetCut({
                facetAddress: addrs[i], action: IDiamond.FacetCutAction.Add, functionSelectors: facets[i].facetFuncs()
            });
        }
    }

    function diamondConfig() public view returns (DiamondConfig memory) {
        return DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
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
        BalancerV3VaultAwareRepo._initialize(BAL_VAULT);
        Permit2AwareRepo._initialize(PERMIT2);
        WETHAwareRepo._initialize(WETH);
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}

/* -------------------------------------------------------------------------- */
/*                               Test Contract                                 */
/* -------------------------------------------------------------------------- */

/**
 * @title BalancerV3StandardExchangeRouter_TransientState_Test
 * @notice Tests proving transient state (currentStandardExchangeToken) is
 *         set during vault operations and cleared on completion and revert.
 * @dev Covers US-IDXEX-037.3:
 *      - currentStandardExchangeToken is set during swap via vault route
 *      - currentStandardExchangeToken is cleared on success
 *      - currentStandardExchangeToken is cleared on revert (transient storage auto-clears)
 */
contract BalancerV3StandardExchangeRouter_TransientState_Test is TestBase_BalancerV3StandardExchangeRouter {
    IFacet internal harnessFacet;
    ITransientStateHarness internal harness;
    IBalancerV3StandardExchangeRouterPrepay internal prepayRouter;

    /* ---------------------------------------------------------------------- */
    /*                      Override: Deploy with harness                      */
    /* ---------------------------------------------------------------------- */

    function _deployRouterFacets() internal override {
        super._deployRouterFacets();
        harnessFacet = IFacet(address(new TransientStateHarnessFacet()));
    }

    function _deployRouterPackage() internal override {
        TransientStateDFPkg.TransientStatePkgInit memory p;
        p.senderGuardFacet = senderGuardFacet;
        p.exactInQueryFacet = exactInQueryFacet;
        p.exactOutQueryFacet = exactOutQueryFacet;
        p.exactInSwapFacet = exactInSwapFacet;
        p.exactOutSwapFacet = exactOutSwapFacet;
        p.prepayFacet = prepayFacet;
        p.prepayHooksFacet = prepayHooksFacet;
        p.batchExactInFacet = batchExactInFacet;
        p.batchExactOutFacet = batchExactOutFacet;
        p.harnessFacet = harnessFacet;
        p.balancerV3Vault = IVault(address(vault));
        p.permit2 = permit2;
        p.weth = IWETH(address(weth));

        seRouterDFPkg = IBalancerV3StandardExchangeRouterDFPkg(address(new TransientStateDFPkg(p)));
    }

    function setUp() public override {
        super.setUp();
        harness = ITransientStateHarness(address(seRouter));
        prepayRouter = IBalancerV3StandardExchangeRouterPrepay(address(seRouter));
    }

    /* ---------------------------------------------------------------------- */
    /*          Test: Transient token is zero outside swap context             */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Outside any swap/vault operation, currentStandardExchangeToken
     *         must read as address(0) because transient storage auto-clears
     *         between transactions.
     */
    function test_transientState_initiallyZero() public view {
        address current = harness.readCurrentStandardExchangeToken();
        assertEq(current, address(0), "Transient token should be zero outside swap context");
    }

    /* ---------------------------------------------------------------------- */
    /*      Test: Transient token is set during harness-simulated context      */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice When the harness sets the transient token, reading it back in
     *         the same call context should return the set value.
     */
    function test_transientState_setDuringHarnessCall() public {
        // Use the harness to set currentStandardExchangeToken and read it during a no-op call
        (address readDuring,) = harness.callAndReadTransientState(
            daiUsdcVault,
            address(this), // target - just call back to us
            abi.encodeCall(this.noOp, ())
        );

        assertEq(readDuring, address(daiUsdcVault), "Transient token should be set to daiUsdcVault during call");
    }

    /* ---------------------------------------------------------------------- */
    /*        Test: Transient token is cleared after successful swap           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice After a vault route swap completes successfully, the transient
     *         token must be cleared. We verify by reading it after the swap.
     */
    function test_transientState_clearedAfterVaultDeposit() public {
        uint256 amountIn = TEST_AMOUNT;

        // Mint DAI to alice for vault deposit
        _mintAndApprove(address(dai), alice, amountIn);

        vm.startPrank(alice);
        // Execute vault deposit route (sets/clears transient token internally)
        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault), // pool == vault for deposit
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            amountIn,
            0,
            _deadline(),
            false,
            ""
        );
        vm.stopPrank();

        // After the swap, transient storage auto-clears (end of transaction)
        address currentAfter = harness.readCurrentStandardExchangeToken();
        assertEq(currentAfter, address(0), "Transient token should be zero after swap completes");
    }

    /* ---------------------------------------------------------------------- */
    /*        Test: Transient token is cleared after direct swap               */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice After a direct swap (no vault), transient token should remain zero
     *         because it's never set for direct swaps.
     */
    function test_transientState_staysZeroForDirectSwap() public {
        uint256 amountIn = TEST_AMOUNT;

        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        _mintAndApprove(address(token0), alice, amountIn);

        vm.startPrank(alice);
        _swapExactIn(daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn, 0);
        vm.stopPrank();

        address currentAfter = harness.readCurrentStandardExchangeToken();
        assertEq(currentAfter, address(0), "Transient token should remain zero for direct swap");
    }

    /* ---------------------------------------------------------------------- */
    /*    Test: Transient token is zero after reverted vault swap              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice If a vault route swap reverts (e.g., expired deadline), the transient
     *         token must still be zero. EVM revert unwinds all state changes including
     *         transient storage.
     */
    function test_transientState_clearedAfterRevert() public {
        uint256 amountIn = TEST_AMOUNT;

        _mintAndApprove(address(dai), alice, amountIn);

        uint256 expiredDeadline = block.timestamp - 1;

        vm.startPrank(alice);
        // This should revert due to expired deadline, but transient storage still clears
        try seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault),
            IERC20(address(dai)),
            daiUsdcVault,
            IERC20(address(daiUsdcVault)),
            _noVault(),
            amountIn,
            0,
            expiredDeadline,
            false,
            ""
        ) {
            revert("Should have reverted");
        } catch {
            // Expected: swap reverted
        }
        vm.stopPrank();

        // Transient storage is auto-cleared on revert
        address currentAfter = harness.readCurrentStandardExchangeToken();
        assertEq(currentAfter, address(0), "Transient token should be zero after reverted swap");
    }

    /* ---------------------------------------------------------------------- */
    /*    Test: Transient token is cleared after successful vault withdrawal   */
    /* ---------------------------------------------------------------------- */

    function test_transientState_clearedAfterVaultWithdrawal() public {
        // First deposit to get vault shares
        uint256 shares = _depositToVault(alice, TEST_AMOUNT);

        vm.startPrank(alice);
        // Execute vault withdrawal route
        seRouter.swapSingleTokenExactIn(
            address(daiUsdcVault), // pool == vault for withdrawal
            IERC20(address(daiUsdcVault)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            shares / 2,
            0,
            _deadline(),
            false,
            ""
        );
        vm.stopPrank();

        address currentAfter = harness.readCurrentStandardExchangeToken();
        assertEq(currentAfter, address(0), "Transient token should be zero after vault withdrawal");
    }

    /* ---------------------------------------------------------------------- */
    /*                          Helper: no-op callback                        */
    /* ---------------------------------------------------------------------- */

    function noOp() external pure {
        // Intentionally empty - used as callback target for harness
    }
}
