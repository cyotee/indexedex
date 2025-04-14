// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactIn
} from "contracts/protocols/dexes/balancer/v3/routers/batch/IBalancerV3StandardExchangeBatchRouterExactIn.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactOut
} from "contracts/protocols/dexes/balancer/v3/routers/batch/IBalancerV3StandardExchangeBatchRouterExactOut.sol";
import {
    IBalancerV3StandardExchangeBatchRouterTypes
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterTypes.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/**
 * @title BalancerV3StandardExchangeRouter_BatchPermit2_Test
 * @notice Tests for Batch Router Permit2 (First-Token-Only) functionality.
 * @dev Covers:
 *      - swapExactInWithPermit: Pre-pull first token of each path via Permit2
 *      - swapExactOutWithPermit: Pre-pull first token of each path via Permit2
 *      - Array length validation
 *      - Token mismatch validation
 */
contract BalancerV3StandardExchangeRouter_BatchPermit2_Test is TestBase_BalancerV3StandardExchangeRouter {
    using BetterEfficientHashLib for bytes;

    // Batch router interfaces
    IBalancerV3StandardExchangeBatchRouterExactIn internal batchExactInRouter;
    IBalancerV3StandardExchangeBatchRouterExactOut internal batchExactOutRouter;

    // Permit2 type hashes for non-witness permitTransferFrom
    bytes32 constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 constant PERMIT_TRANSFER_FROM_TYPEHASH =
        keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)"
            "TokenPermissions(address token,uint256 amount)"
        );
    bytes32 constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    uint256 internal constant SWAP_AMOUNT = 100e18;
    uint256 internal constant MAX_AMOUNT_IN = SWAP_AMOUNT * 10;

    function setUp() public override {
        super.setUp();
        batchExactInRouter = IBalancerV3StandardExchangeBatchRouterExactIn(address(seRouter));
        batchExactOutRouter = IBalancerV3StandardExchangeBatchRouterExactOut(address(seRouter));
    }

    /* -------------------------------------------------------------------------- */
    /*                      Permit2 Signature Helpers                              */
    /* -------------------------------------------------------------------------- */

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256("Permit2"), block.chainid, address(permit2))
        );
    }

    /**
     * @dev Sign a Permit2 permitTransferFrom (non-witness) signature
     */
    function _signPermit(
        address token,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        uint256 signerPk
    ) internal view returns (bytes memory signature) {
        bytes32 domainSep = _domainSeparator();

        // TokenPermissions struct hash
        bytes32 tokenPermissionsHash = keccak256(
            abi.encode(TOKEN_PERMISSIONS_TYPEHASH, token, amount)
        );

        // PermitTransferFrom struct hash: keccak256(abi.encode(PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissionsHash, spender, nonce, deadline))
        bytes32 permitHash = keccak256(
            abi.encode(PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissionsHash, address(seRouter), nonce, deadline)
        );

        // Final digest
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSep, permitHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        return bytes.concat(r, s, bytes1(v));
    }

    function _singleStepToUsdc()
        internal
        view
        returns (IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps)
    {
        steps = new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });
    }

    function _singleExactInPath(uint256 exactAmountIn, uint256 minAmountOut)
        internal
        view
        returns (IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths)
    {
        paths = new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](1);
        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(dai)),
            steps: _singleStepToUsdc(),
            exactAmountIn: exactAmountIn,
            minAmountOut: minAmountOut
        });
    }

    function _strategyVaultDepositExactInPath(uint256 exactAmountIn, uint256 minAmountOut)
        internal
        view
        returns (IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths)
    {
        paths = new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdcVault), tokenOut: IERC20(address(daiUsdcVault)), isBuffer: false, isStrategyVault: true
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(dai)),
            steps: steps,
            exactAmountIn: exactAmountIn,
            minAmountOut: minAmountOut
        });
    }

    function _singleExactOutPath(uint256 exactAmountOut, uint256 maxAmountIn)
        internal
        view
        returns (IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths)
    {
        paths = new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);
        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)),
            steps: _singleStepToUsdc(),
            exactAmountOut: exactAmountOut,
            maxAmountIn: maxAmountIn
        });
    }

    function _strategyVaultWithdrawalExactOutPath(uint256 exactAmountOut, uint256 maxAmountIn)
        internal
        view
        returns (IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths)
    {
        paths = new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](2);
        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: address(daiUsdcVault), tokenOut: IERC20(address(dai)), isBuffer: false, isStrategyVault: true
        });
        steps[1] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(daiUsdcVault)),
            steps: steps,
            exactAmountOut: exactAmountOut,
            maxAmountIn: maxAmountIn
        });
    }

    function _permit(address token, uint256 amount, uint256 nonce, uint256 deadline)
        internal
        pure
        returns (ISignatureTransfer.PermitTransferFrom memory permit)
    {
        permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: token, amount: amount}),
            nonce: nonce,
            deadline: deadline
        });
    }

    /* -------------------------------------------------------------------------- */
    /*                      ExactIn With Permit Tests                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Single path with permit - first token is pre-pulled via Permit2
     */
    function test_swapExactInWithPermit_singlePath_succeeds() public {
        (address bob, uint256 bobPk) = makeAddrAndKey("bob");
        dai.mint(bob, SWAP_AMOUNT);

        vm.startPrank(bob);

        uint256 usdcBalBefore = usdc.balanceOf(bob);
        uint256 daiBalBefore = dai.balanceOf(bob);
        uint256 routerDaiBefore = dai.balanceOf(address(seRouter));
        uint256 routerUsdcBefore = usdc.balanceOf(address(seRouter));
        uint256 pathAmountOut;

        {
            uint256 deadline = block.timestamp + 1 hours;
            ISignatureTransfer.PermitTransferFrom[] memory permits =
                new ISignatureTransfer.PermitTransferFrom[](1);
            permits[0] = _permit(address(dai), SWAP_AMOUNT, 0, deadline);

            bytes[] memory signatures = new bytes[](1);
            signatures[0] = _signPermit(address(dai), SWAP_AMOUNT, 0, deadline, bobPk);

            (uint256[] memory pathAmountsOut,,) = batchExactInRouter.swapExactInWithPermit(
                _singleExactInPath(SWAP_AMOUNT, 1), deadline, false, "", permits, signatures
            );
            pathAmountOut = pathAmountsOut[0];
        }

        vm.stopPrank();

        uint256 usdcBalAfter = usdc.balanceOf(bob);
        uint256 daiBalAfter = dai.balanceOf(bob);

        assertGt(usdcBalAfter - usdcBalBefore, 0, "Should receive USDC");
        assertEq(daiBalBefore - daiBalAfter, SWAP_AMOUNT, "Should spend exact permitted input amount");
        assertGt(pathAmountOut, 0, "Path should have output");
        assertEq(dai.balanceOf(address(seRouter)), routerDaiBefore, "Router should not retain DAI");
        assertEq(usdc.balanceOf(address(seRouter)), routerUsdcBefore, "Router should not retain USDC");
    }

    function test_swapExactInWithPermit_strategyVaultDeposit_succeeds() public {
        (address bob, uint256 bobPk) = makeAddrAndKey("bob_strategy_vault_exact_in");
        dai.mint(bob, SWAP_AMOUNT);

        vm.startPrank(bob);
        dai.approve(address(permit2), type(uint256).max);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 daiBalBefore = dai.balanceOf(bob);
        uint256 shareBalBefore = IERC20(address(daiUsdcVault)).balanceOf(bob);
        uint256 routerDaiBefore = dai.balanceOf(address(seRouter));
        uint256 routerShareBefore = IERC20(address(daiUsdcVault)).balanceOf(address(seRouter));

        ISignatureTransfer.PermitTransferFrom[] memory permits =
            new ISignatureTransfer.PermitTransferFrom[](1);
        permits[0] = _permit(address(dai), SWAP_AMOUNT, 0, deadline);

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signPermit(address(dai), SWAP_AMOUNT, 0, deadline, bobPk);

        (uint256[] memory pathAmountsOut,,) = batchExactInRouter.swapExactInWithPermit(
            _strategyVaultDepositExactInPath(SWAP_AMOUNT, 1), deadline, false, "", permits, signatures
        );

        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(bob);
        uint256 shareBalAfter = IERC20(address(daiUsdcVault)).balanceOf(bob);

        assertEq(daiBalBefore - daiBalAfter, SWAP_AMOUNT, "Should spend exact permitted DAI amount");
        assertGt(shareBalAfter - shareBalBefore, 0, "Should receive strategy vault shares");
        assertEq(shareBalAfter - shareBalBefore, pathAmountsOut[0], "Reported output should match received shares");
        assertEq(dai.balanceOf(address(seRouter)), routerDaiBefore, "Router should not retain DAI");
        assertEq(
            IERC20(address(daiUsdcVault)).balanceOf(address(seRouter)),
            routerShareBefore,
            "Router should not retain strategy vault shares"
        );
    }

    /**
     * @notice Reverts when permits length doesn't match paths length
     */
    function test_swapExactInWithPermit_reverts_permitsLengthMismatch() public {
        (address bob, uint256 bobPk) = makeAddrAndKey("bob");
        dai.mint(bob, SWAP_AMOUNT);

        vm.startPrank(bob);

        uint256 deadline = block.timestamp + 1 hours;

        // Build only 1 permit but 2 paths
        ISignatureTransfer.PermitTransferFrom[] memory permits =
            new ISignatureTransfer.PermitTransferFrom[](1);
        permits[0] = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(dai), amount: SWAP_AMOUNT}),
            nonce: 0,
            deadline: deadline
        });

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signPermit(address(dai), SWAP_AMOUNT, 0, deadline, bobPk);

        // Build 2 paths
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](2);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps1 =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        steps1[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });
        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(dai)), steps: steps1, exactAmountIn: SWAP_AMOUNT, minAmountOut: 1
        });

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps2 =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        steps2[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });
        paths[1] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(dai)), steps: steps2, exactAmountIn: SWAP_AMOUNT, minAmountOut: 1
        });

        // Should revert with PermitPathLengthMismatch
        vm.expectRevert(
            abi.encodeWithSignature(
                "PermitPathLengthMismatch(uint256,uint256,uint256)", 2, 1, 1
            )
        );
        batchExactInRouter.swapExactInWithPermit(paths, deadline, false, "", permits, signatures);

        vm.stopPrank();
    }

    /**
     * @notice Reverts when permit token doesn't match path's first token
     */
    function test_swapExactInWithPermit_reverts_tokenMismatch() public {
        (address bob, uint256 bobPk) = makeAddrAndKey("bob");
        dai.mint(bob, SWAP_AMOUNT);
        usdc.mint(bob, SWAP_AMOUNT);

        vm.startPrank(bob);

        uint256 deadline = block.timestamp + 1 hours;

        // Build permit for USDC but path starts with DAI
        ISignatureTransfer.PermitTransferFrom[] memory permits =
            new ISignatureTransfer.PermitTransferFrom[](1);
        permits[0] = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(usdc), amount: SWAP_AMOUNT}), // Wrong token!
            nonce: 0,
            deadline: deadline
        });

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signPermit(address(usdc), SWAP_AMOUNT, 0, deadline, bobPk);

        // Build path starting with DAI
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });
        paths[0] = IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn({
            tokenIn: IERC20(address(dai)), steps: steps, exactAmountIn: SWAP_AMOUNT, minAmountOut: 1
        });

        // Should revert with PermitPathTokenMismatch
        vm.expectRevert(
            abi.encodeWithSignature(
                "PermitPathTokenMismatch(uint256,address,address)", 0, address(dai), address(usdc)
            )
        );
        batchExactInRouter.swapExactInWithPermit(paths, deadline, false, "", permits, signatures);

        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                      ExactOut With Permit Tests                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Single path exact out with permit - first token is pre-pulled
     */
    function test_swapExactOutWithPermit_singlePath_succeeds() public {
        (address bob, uint256 bobPk) = makeAddrAndKey("bob");
        dai.mint(bob, MAX_AMOUNT_IN);

        vm.startPrank(bob);
        dai.approve(address(permit2), type(uint256).max);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signPermit(address(dai), MAX_AMOUNT_IN, 0, deadline, bobPk);

        uint256 daiBalBefore = dai.balanceOf(bob);
        uint256 usdcBalBefore = usdc.balanceOf(bob);
        uint256 routerDaiBefore = dai.balanceOf(address(seRouter));
        uint256 routerUsdcBefore = usdc.balanceOf(address(seRouter));
        uint256 pathAmountIn;

        {
            ISignatureTransfer.PermitTransferFrom[] memory permits =
                new ISignatureTransfer.PermitTransferFrom[](1);
            permits[0] = _permit(address(dai), MAX_AMOUNT_IN, 0, deadline);

            bytes[] memory signatures = new bytes[](1);
            signatures[0] = signature;

            (uint256[] memory pathAmountsIn,,) = batchExactOutRouter.swapExactOutWithPermit(
                _singleExactOutPath(SWAP_AMOUNT, MAX_AMOUNT_IN), deadline, false, "", permits, signatures
            );
            pathAmountIn = pathAmountsIn[0];
        }

        vm.stopPrank();

        uint256 daiBalAfter = dai.balanceOf(bob);
        uint256 usdcBalAfter = usdc.balanceOf(bob);

        assertGt(daiBalBefore - daiBalAfter, 0, "Should spend DAI");
        assertLe(daiBalBefore - daiBalAfter, MAX_AMOUNT_IN, "Spent input should respect maxAmountIn");
        assertEq(usdcBalAfter - usdcBalBefore, SWAP_AMOUNT, "Should receive exact requested output");
        assertEq(daiBalBefore - daiBalAfter, pathAmountIn, "Reported path input should match actual user spend");
        assertEq(dai.balanceOf(address(seRouter)), routerDaiBefore, "Router should not retain DAI");
        assertEq(usdc.balanceOf(address(seRouter)), routerUsdcBefore, "Router should not retain USDC");
    }

    function test_swapExactInWithPermit_reverts_amountInsufficient() public {
        (address bob, uint256 bobPk) = makeAddrAndKey("bob_exact_in_amount_insufficient");
        dai.mint(bob, SWAP_AMOUNT);

        vm.startPrank(bob);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 insufficientAmount = SWAP_AMOUNT - 1;

        ISignatureTransfer.PermitTransferFrom[] memory permits = new ISignatureTransfer.PermitTransferFrom[](1);
        permits[0] = _permit(address(dai), insufficientAmount, 0, deadline);

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signPermit(address(dai), insufficientAmount, 0, deadline, bobPk);

        vm.expectRevert(
            abi.encodeWithSignature(
                "PermitPathAmountInsufficient(uint256,uint256,uint256)", 0, SWAP_AMOUNT, insufficientAmount
            )
        );
        batchExactInRouter.swapExactInWithPermit(
            _singleExactInPath(SWAP_AMOUNT, 1), deadline, false, "", permits, signatures
        );

        vm.stopPrank();
    }

    function test_swapExactOutWithPermit_reverts_permitsLengthMismatch() public {
        (address bob, uint256 bobPk) = makeAddrAndKey("bob_exact_out_length_mismatch");
        dai.mint(bob, MAX_AMOUNT_IN);

        vm.startPrank(bob);

        uint256 deadline = block.timestamp + 1 hours;

        ISignatureTransfer.PermitTransferFrom[] memory permits =
            new ISignatureTransfer.PermitTransferFrom[](1);
        permits[0] = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(dai), amount: MAX_AMOUNT_IN}),
            nonce: 0,
            deadline: deadline
        });

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signPermit(address(dai), MAX_AMOUNT_IN, 0, deadline, bobPk);

        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](2);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps1 =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        steps1[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });
        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)), steps: steps1, exactAmountOut: SWAP_AMOUNT, maxAmountIn: MAX_AMOUNT_IN
        });

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps2 =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        steps2[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });
        paths[1] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)), steps: steps2, exactAmountOut: SWAP_AMOUNT, maxAmountIn: MAX_AMOUNT_IN
        });

        vm.expectRevert(
            abi.encodeWithSignature("PermitPathLengthMismatch(uint256,uint256,uint256)", 2, 1, 1)
        );
        batchExactOutRouter.swapExactOutWithPermit(paths, deadline, false, "", permits, signatures);

        vm.stopPrank();
    }

    function test_swapExactOutWithPermit_reverts_tokenMismatch() public {
        (address bob, uint256 bobPk) = makeAddrAndKey("bob_exact_out_token_mismatch");
        dai.mint(bob, MAX_AMOUNT_IN);
        usdc.mint(bob, MAX_AMOUNT_IN);

        vm.startPrank(bob);

        uint256 deadline = block.timestamp + 1 hours;

        ISignatureTransfer.PermitTransferFrom[] memory permits =
            new ISignatureTransfer.PermitTransferFrom[](1);
        permits[0] = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(usdc), amount: MAX_AMOUNT_IN}),
            nonce: 0,
            deadline: deadline
        });

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signPermit(address(usdc), MAX_AMOUNT_IN, 0, deadline, bobPk);

        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });
        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)), steps: steps, exactAmountOut: SWAP_AMOUNT, maxAmountIn: MAX_AMOUNT_IN
        });

        vm.expectRevert(
            abi.encodeWithSignature(
                "PermitPathTokenMismatch(uint256,address,address)", 0, address(dai), address(usdc)
            )
        );
        batchExactOutRouter.swapExactOutWithPermit(paths, deadline, false, "", permits, signatures);

        vm.stopPrank();
    }

    function test_swapExactOutWithPermit_reverts_amountInsufficient() public {
        (address bob, uint256 bobPk) = makeAddrAndKey("bob_exact_out_amount_insufficient");
        dai.mint(bob, MAX_AMOUNT_IN);

        vm.startPrank(bob);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 insufficientAmount = MAX_AMOUNT_IN - 1;

        ISignatureTransfer.PermitTransferFrom[] memory permits =
            new ISignatureTransfer.PermitTransferFrom[](1);
        permits[0] = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(dai), amount: insufficientAmount}),
            nonce: 0,
            deadline: deadline
        });

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signPermit(address(dai), insufficientAmount, 0, deadline, bobPk);

        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)), steps: steps, exactAmountOut: SWAP_AMOUNT, maxAmountIn: MAX_AMOUNT_IN
        });

        vm.expectRevert(
            abi.encodeWithSignature(
                "PermitPathAmountInsufficient(uint256,uint256,uint256)", 0, MAX_AMOUNT_IN, insufficientAmount
            )
        );
        batchExactOutRouter.swapExactOutWithPermit(paths, deadline, false, "", permits, signatures);

        vm.stopPrank();
    }

    function test_swapExactOutWithPermit_multiPath_succeeds() public {
        (address bob, uint256 bobPk) = makeAddrAndKey("bob_exact_out_multi_path");
        dai.mint(bob, MAX_AMOUNT_IN * 2);

        vm.startPrank(bob);
        dai.approve(address(permit2), type(uint256).max);

        uint256 deadline = block.timestamp + 1 hours;

        ISignatureTransfer.PermitTransferFrom[] memory permits =
            new ISignatureTransfer.PermitTransferFrom[](2);
        permits[0] = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(dai), amount: MAX_AMOUNT_IN}),
            nonce: 0,
            deadline: deadline
        });
        permits[1] = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(dai), amount: MAX_AMOUNT_IN}),
            nonce: 1,
            deadline: deadline
        });

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = _signPermit(address(dai), MAX_AMOUNT_IN, 0, deadline, bobPk);
        signatures[1] = _signPermit(address(dai), MAX_AMOUNT_IN, 1, deadline, bobPk);

        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](2);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory stepsA =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        stepsA[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });
        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)), steps: stepsA, exactAmountOut: SWAP_AMOUNT / 2, maxAmountIn: MAX_AMOUNT_IN
        });

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory stepsB =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        stepsB[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });
        paths[1] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)), steps: stepsB, exactAmountOut: SWAP_AMOUNT / 2, maxAmountIn: MAX_AMOUNT_IN
        });

        uint256 usdcBalBefore = usdc.balanceOf(bob);
        uint256 routerDaiBefore = dai.balanceOf(address(seRouter));
        uint256 routerUsdcBefore = usdc.balanceOf(address(seRouter));

        (uint256[] memory pathAmountsIn,,) =
            batchExactOutRouter.swapExactOutWithPermit(paths, deadline, false, "", permits, signatures);

        vm.stopPrank();

        assertEq(pathAmountsIn.length, 2, "Should have 2 path amounts in");
        assertEq(usdc.balanceOf(bob) - usdcBalBefore, SWAP_AMOUNT, "Should receive total exact output across paths");
        assertEq(dai.balanceOf(address(seRouter)), routerDaiBefore, "Router should not retain DAI");
        assertEq(usdc.balanceOf(address(seRouter)), routerUsdcBefore, "Router should not retain USDC");
    }

    function test_swapExactOutWithPermit_strategyVaultWithdrawal_succeeds() public {
        (address bob, uint256 bobPk) = makeAddrAndKey("bob_exact_out_strategy_vault");
        uint256 shareBalance = _depositToVault(bob, MAX_AMOUNT_IN);
        uint256 maxSharesIn = shareBalance / 2;

        vm.startPrank(bob);
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 shareBalBefore = IERC20(address(daiUsdcVault)).balanceOf(bob);
        uint256 usdcBalBefore = usdc.balanceOf(bob);
        uint256 pathAmountIn;

        ISignatureTransfer.PermitTransferFrom[] memory permits =
            new ISignatureTransfer.PermitTransferFrom[](1);
        permits[0] = _permit(address(daiUsdcVault), maxSharesIn, 0, deadline);

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _signPermit(address(daiUsdcVault), maxSharesIn, 0, deadline, bobPk);

        {
            (uint256[] memory pathAmountsIn,,) = batchExactOutRouter.swapExactOutWithPermit(
                _strategyVaultWithdrawalExactOutPath(SWAP_AMOUNT, maxSharesIn), deadline, false, "", permits, signatures
            );
            pathAmountIn = pathAmountsIn[0];
        }

        vm.stopPrank();

        uint256 shareSpent = shareBalBefore - IERC20(address(daiUsdcVault)).balanceOf(bob);

        assertEq(usdc.balanceOf(bob) - usdcBalBefore, SWAP_AMOUNT, "Should receive exact requested output");
        assertEq(shareSpent, pathAmountIn, "Reported path input should match actual share spend");
        assertLe(shareSpent, maxSharesIn, "Share spend should respect maxAmountIn");
        assertEq(IERC20(address(daiUsdcVault)).balanceOf(address(seRouter)), 0, "Router should not retain vault shares");
        assertEq(dai.balanceOf(address(seRouter)), 0, "Router should not retain DAI");
        assertEq(usdc.balanceOf(address(seRouter)), 0, "Router should not retain USDC");
    }

    function test_swapExactOutWithPermit_refundsUnusedAndNoRouterRetention() public {
        (address bob, uint256 bobPk) = makeAddrAndKey("bob_exact_out_refund");
        dai.mint(bob, MAX_AMOUNT_IN);

        vm.startPrank(bob);
        dai.approve(address(permit2), type(uint256).max);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signPermit(address(dai), MAX_AMOUNT_IN, 0, deadline, bobPk);

        ISignatureTransfer.PermitTransferFrom[] memory permits =
            new ISignatureTransfer.PermitTransferFrom[](1);
        permits[0] = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(dai), amount: MAX_AMOUNT_IN}),
            nonce: 0,
            deadline: deadline
        });

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = signature;

        IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[] memory paths =
            new IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut[](1);

        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[] memory steps =
            new IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep[](1);
        steps[0] = IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep({
            pool: daiUsdcPool, tokenOut: IERC20(address(usdc)), isBuffer: false, isStrategyVault: false
        });

        paths[0] = IBalancerV3StandardExchangeBatchRouterExactOut.SESwapPathExactAmountOut({
            tokenIn: IERC20(address(dai)), steps: steps, exactAmountOut: SWAP_AMOUNT, maxAmountIn: MAX_AMOUNT_IN
        });

        uint256 daiBalBefore = dai.balanceOf(bob);
        uint256 routerDaiBefore = dai.balanceOf(address(seRouter));
        uint256 routerUsdcBefore = usdc.balanceOf(address(seRouter));

        (uint256[] memory pathAmountsIn,,) =
            batchExactOutRouter.swapExactOutWithPermit(paths, deadline, false, "", permits, signatures);

        vm.stopPrank();

        uint256 daiSpent = daiBalBefore - dai.balanceOf(bob);
        assertEq(pathAmountsIn.length, 1, "Should have 1 path amount in");
        assertEq(daiSpent, pathAmountsIn[0], "User spend should match reported path input");
        assertLt(daiSpent, MAX_AMOUNT_IN, "Unused pre-pulled amount should be refunded");
        assertEq(dai.balanceOf(address(seRouter)), routerDaiBefore, "Router should not retain DAI");
        assertEq(usdc.balanceOf(address(seRouter)), routerUsdcBefore, "Router should not retain USDC");
    }
}
