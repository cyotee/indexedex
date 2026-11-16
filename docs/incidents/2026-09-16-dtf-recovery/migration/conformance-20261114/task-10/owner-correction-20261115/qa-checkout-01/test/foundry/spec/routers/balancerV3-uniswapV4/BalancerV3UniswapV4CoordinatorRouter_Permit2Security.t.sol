// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {InvalidNonce} from "@crane/contracts/protocols/utils/permit2/PermitErrors.sol";
import {SignatureVerification} from "@crane/contracts/protocols/utils/permit2/SignatureVerification.sol";
import {
    TestBase_BalancerV3_8020WeightedPool
} from "@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3_8020WeightedPool.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter,
    IBalancerV3UniswapV4CoordinatorRouterDFPkg
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouter_FactoryService
} from "contracts/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol";

/**
 * @title BalancerV3UniswapV4CoordinatorRouter_Permit2Security_Test
 * @notice WP-I5-RTR-001 / TCA-RTR-001: Permit2 P0 — replay, wrong spender, token mismatch, short amount, witness tamper.
 * @dev Production Permit2 (TestBase); exact fail selectors; no mockCall on Permit2/Coordinator.
 */
contract BalancerV3UniswapV4CoordinatorRouter_Permit2Security_Test is TestBase_BalancerV3_8020WeightedPool {
    using BalancerV3UniswapV4CoordinatorRouter_FactoryService for *;

    IBalancerV3UniswapV4CoordinatorRouter internal coordinator;
    uint256 internal alicePk = 0xA11CE;
    address internal aliceUser;
    address internal recipient;
    SimpleMintableERC20 internal otherToken;

    function setUp() public override {
        super.setUp();
        initDaiUsdc8020WeightedPool();

        aliceUser = vm.addr(alicePk);
        recipient = makeAddr("i5Recipient");
        otherToken = new SimpleMintableERC20("OTHER", "OTH");

        IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[] memory seed =
            new IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[](1);
        seed[0] = IBalancerV3UniswapV4CoordinatorRouter.InitialRouter({
            router: address(router), kind: IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        });
        IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgArgs memory args =
            IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgArgs({owner: address(this), initialRouters: seed});
        coordinator = BalancerV3UniswapV4CoordinatorRouter_FactoryService.deployCoordinator(
            create3Factory, diamondPackageFactory, permit2, IWETH(address(weth)), address(0), args
        );

        dai.mint(aliceUser, 50_000e18);
        otherToken.mint(aliceUser, 50_000e18);
        vm.startPrank(aliceUser);
        dai.approve(address(permit2), type(uint256).max);
        otherToken.approve(address(permit2), type(uint256).max);
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*  I5: signature replay (nonce spent)                                    */
    /* ---------------------------------------------------------------------- */

    /// @notice Successful spend then same permit/sig → Permit2 InvalidNonce.
    function test_I5_signatureReplay_sameNonce_reverts() public {
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params = _stockParams(5e18);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 100);

        uint256 balBefore = IERC20(address(dai)).balanceOf(aliceUser);
        vm.prank(aliceUser);
        uint256 out1 = coordinator.swapExactInWithPermit(params, permit, sig);
        assertGt(out1, 0, "I5 first spend succeeds");
        assertEq(IERC20(address(dai)).balanceOf(aliceUser), balBefore - 5e18, "I5 principal moved once");

        // Re-fund so a second pull would succeed if nonce were not spent.
        dai.mint(aliceUser, 5e18);

        uint256 balBeforeReplay = IERC20(address(dai)).balanceOf(aliceUser);
        vm.prank(aliceUser);
        vm.expectRevert(InvalidNonce.selector);
        coordinator.swapExactInWithPermit(params, permit, sig);
        assertEq(IERC20(address(dai)).balanceOf(aliceUser), balBeforeReplay, "I5 replay: no second pull");
    }

    /* ---------------------------------------------------------------------- */
    /*  I5: wrong spender                                                     */
    /* ---------------------------------------------------------------------- */

    /// @notice Cryptographically valid sig for spender≠Coordinator must not authorize Coordinator pull.
    function test_I5_wrongSpender_signatureForOtherRouter_reverts() public {
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params = _stockParams(1e18);
        address wrongSpender = makeAddr("wrongSpender");
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) =
            _signWithSpender(params, 101, wrongSpender);

        uint256 balBefore = IERC20(address(dai)).balanceOf(aliceUser);
        vm.prank(aliceUser);
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        coordinator.swapExactInWithPermit(params, permit, sig);
        assertEq(IERC20(address(dai)).balanceOf(aliceUser), balBefore, "I5 wrong spender: state unchanged");
    }

    /* ---------------------------------------------------------------------- */
    /*  I5: permit.token ≠ tokenIn                                            */
    /* ---------------------------------------------------------------------- */

    /// @notice Coordinator gate: permit.permitted.token != params.tokenIn → InvalidPermitWitness (before Permit2).
    function test_I5_permitTokenMismatch_reverts_InvalidPermitWitness() public {
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params = _stockParams(1e18);
        // Sign over otherToken as permitted token (cryptographically valid for that token).
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(otherToken), amount: params.amountIn}),
            nonce: 102,
            deadline: block.timestamp + 1 days
        });
        bytes memory sig = _rawSign(params, permit, address(coordinator));

        uint256 daiBefore = IERC20(address(dai)).balanceOf(aliceUser);
        uint256 otherBefore = IERC20(address(otherToken)).balanceOf(aliceUser);
        vm.prank(aliceUser);
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.InvalidPermitWitness.selector);
        coordinator.swapExactInWithPermit(params, permit, sig);
        assertEq(IERC20(address(dai)).balanceOf(aliceUser), daiBefore, "I5 token mismatch: no DAI pull");
        assertEq(IERC20(address(otherToken)).balanceOf(aliceUser), otherBefore, "I5 token mismatch: no OTHER pull");
    }

    /* ---------------------------------------------------------------------- */
    /*  I5: permit amount short vs amountIn                                   */
    /* ---------------------------------------------------------------------- */

    /// @notice Permit2 InvalidAmount when permitted.amount < requested amountIn.
    function test_I5_permitAmountShort_reverts() public {
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params = _stockParams(10e18);
        uint256 shortAmount = 1e18;
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: params.tokenIn, amount: shortAmount}),
            nonce: 103,
            deadline: block.timestamp + 1 days
        });
        bytes memory sig = _rawSign(params, permit, address(coordinator));

        uint256 balBefore = IERC20(address(dai)).balanceOf(aliceUser);
        vm.prank(aliceUser);
        vm.expectRevert(abi.encodeWithSelector(ISignatureTransfer.InvalidAmount.selector, shortAmount));
        coordinator.swapExactInWithPermit(params, permit, sig);
        assertEq(IERC20(address(dai)).balanceOf(aliceUser), balBefore, "I5 short amount: no pull");
    }

    /* ---------------------------------------------------------------------- */
    /*  I5: witness field tamper (amountIn / steps)                           */
    /* ---------------------------------------------------------------------- */

    /// @notice Sign honest amountIn then raise amountIn → Permit2 InvalidSigner (witness bound).
    function test_I5_witness_amountIn_tamper_reverts() public {
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params = _stockParams(1e18);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 104);
        params.amountIn = 2e18;
        // Keep permit amount in sync so fail is witness (not Permit2 amount) — token perms still 1e18.
        // Requested amount becomes 2e18 > permitted 1e18 → InvalidAmount first. Use matching permit amount
        // but still wrong witness by only changing params after signing without re-signing.
        permit.permitted.amount = 2e18;

        uint256 balBefore = IERC20(address(dai)).balanceOf(aliceUser);
        vm.prank(aliceUser);
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        coordinator.swapExactInWithPermit(params, permit, sig);
        assertEq(IERC20(address(dai)).balanceOf(aliceUser), balBefore, "I5 amountIn tamper: no pull");
    }

    /// @notice Sign honest steps then replace step data → InvalidSigner.
    function test_I5_witness_steps_tamper_reverts() public {
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params = _stockParams(1e18);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 105);
        // Tamper minAmountOut on step (included in stepsHash via abi.encode of RouteStep[]).
        params.steps[0].minAmountOut = 1;

        uint256 balBefore = IERC20(address(dai)).balanceOf(aliceUser);
        vm.prank(aliceUser);
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        coordinator.swapExactInWithPermit(params, permit, sig);
        assertEq(IERC20(address(dai)).balanceOf(aliceUser), balBefore, "I5 steps tamper: no pull");
    }

    /* ---------------------------------------------------------------------- */
    /*  Helpers                                                               */
    /* ---------------------------------------------------------------------- */

    function _stockParams(uint256 amountIn)
        internal
        view
        returns (IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory)
    {
        bytes memory stepData = abi.encode(pool, address(dai), address(usdc), uint256(0), false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(router), tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });
        return IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
            recipient: recipient,
            tokenIn: address(dai),
            amountIn: amountIn,
            tokenOut: address(usdc),
            minAmountOut: 1,
            deadline: block.timestamp + 1 days,
            ethIn: false,
            ethOut: false,
            steps: steps
        });
    }

    function _sign(IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params, uint256 nonce)
        internal
        view
        returns (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory signature)
    {
        permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: params.tokenIn, amount: params.amountIn}),
            nonce: nonce,
            deadline: block.timestamp + 1 days
        });
        signature = _rawSign(params, permit, address(coordinator));
    }

    function _signWithSpender(
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params,
        uint256 nonce,
        address spender
    ) internal view returns (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory signature) {
        permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: params.tokenIn, amount: params.amountIn}),
            nonce: nonce,
            deadline: block.timestamp + 1 days
        });
        signature = _rawSign(params, permit, spender);
    }

    function _rawSign(
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params,
        ISignatureTransfer.PermitTransferFrom memory permit,
        address spender
    ) internal view returns (bytes memory signature) {
        bytes32 stepsHash = keccak256(abi.encode(params.steps));
        bytes32 witness = keccak256(
            abi.encode(
                coordinator.WITNESS_TYPEHASH(),
                params.recipient,
                params.tokenIn,
                params.amountIn,
                params.tokenOut,
                params.minAmountOut,
                params.deadline,
                params.ethIn,
                params.ethOut,
                stepsHash
            )
        );
        bytes32 tokenPermissionsHash = keccak256(
            abi.encode(
                keccak256("TokenPermissions(address token,uint256 amount)"),
                permit.permitted.token,
                permit.permitted.amount
            )
        );
        bytes32 permitWitnessTypehash = keccak256(
            abi.encodePacked(
                "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,Witness witness)",
                "TokenPermissions(address token,uint256 amount)",
                "Witness(address recipient,address tokenIn,uint256 amountIn,address tokenOut,uint256 minAmountOut,uint256 deadline,bool ethIn,bool ethOut,bytes32 stepsHash)"
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                permitWitnessTypehash, tokenPermissionsHash, spender, permit.nonce, permit.deadline, witness
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", permit2.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
