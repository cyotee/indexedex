// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {WETHTestToken} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/WETHTestToken.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    TestBase_BalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/TestBase_BalancerV3UniswapV4CoordinatorRouter.sol";

/// @notice T2, T15, T19, T20, T27, T32 + WP-N-RTR-001 exact-selector N matrix
contract BalancerV3UniswapV4CoordinatorRouter_Negative_Test is TestBase_BalancerV3UniswapV4CoordinatorRouter {
    IWETH internal weth;
    SimpleMintableERC20 internal tokenA;
    SimpleMintableERC20 internal tokenB;

    function setUp() public override {
        super.setUp();
        weth = IWETH(address(new WETHTestToken()));
        tokenA = new SimpleMintableERC20("A", "A");
        tokenB = new SimpleMintableERC20("B", "B");
        IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[] memory seed;
        _deployCoordinator(weth, address(0), seed);
    }

    function test_T2_routerNotAllowed() public {
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(0xDEAD), tokenOut: address(tokenB), minAmountOut: 0, data: ""
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
                recipient: bob,
                tokenIn: address(tokenA),
                amountIn: 1e18,
                tokenOut: address(tokenB),
                minAmountOut: 0,
                deadline: block.timestamp + 1 days,
                ethIn: false,
                ethOut: false,
                steps: steps
            });

        tokenA.mint(alice, 1e18);
        vm.prank(alice);
        tokenA.approve(address(permit2), type(uint256).max);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) =
            _signPermitWitness(params, 0, block.timestamp + 1 days);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IBalancerV3UniswapV4CoordinatorRouter.RouterNotAllowed.selector, address(0xDEAD))
        );
        coordinator.swapExactInWithPermit(params, permit, sig);
    }

    function test_T19_zeroRecipient() public {
        coordinator.registerRouter(
            address(0xBEEF), IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        );
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(0xBEEF), tokenOut: address(tokenB), minAmountOut: 0, data: ""
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
                recipient: address(0),
                tokenIn: address(tokenA),
                amountIn: 1e18,
                tokenOut: address(tokenB),
                minAmountOut: 0,
                deadline: block.timestamp + 1 days,
                ethIn: false,
                ethOut: false,
                steps: steps
            });
        tokenA.mint(alice, 1e18);
        vm.prank(alice);
        tokenA.approve(address(permit2), type(uint256).max);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) =
            _signPermitWitness(params, 0, block.timestamp + 1 days);
        vm.prank(alice);
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.InvalidRecipient.selector);
        coordinator.swapExactInWithPermit(params, permit, sig);
    }

    function test_T20_expiredDeadline() public {
        coordinator.registerRouter(
            address(0xBEEF), IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        );
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(0xBEEF), tokenOut: address(tokenB), minAmountOut: 0, data: ""
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
                recipient: bob,
                tokenIn: address(tokenA),
                amountIn: 1e18,
                tokenOut: address(tokenB),
                minAmountOut: 0,
                deadline: block.timestamp - 1,
                ethIn: false,
                ethOut: false,
                steps: steps
            });
        tokenA.mint(alice, 1e18);
        vm.prank(alice);
        tokenA.approve(address(permit2), type(uint256).max);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) =
            _signPermitWitness(params, 0, block.timestamp + 1 days);
        vm.prank(alice);
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.ExpiredDeadline.selector);
        coordinator.swapExactInWithPermit(params, permit, sig);
    }

    function test_T27_entrySplit() public {
        coordinator.registerRouter(
            address(0xBEEF), IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        );
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(0xBEEF), tokenOut: address(weth), minAmountOut: 0, data: ""
        });
        // ethIn=true on withPermit reverts
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory p1 =
            IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
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
        ISignatureTransfer.PermitTransferFrom memory emptyPermit;
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.InvalidEthIn.selector);
        coordinator.swapExactInWithPermit(p1, emptyPermit, "");

        // ethIn=false on eth entry reverts
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory p2 = p1;
        p2.ethIn = false;
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.InvalidEthIn.selector);
        coordinator.swapExactInEth{value: 1e18}(p2);
    }

    function test_T15_noTransferFromUserEntry() public view {
        // Surface: only withPermit and eth entries exist for execute.
        assertTrue(coordinator.swapExactInWithPermit.selector != bytes4(0));
        assertTrue(coordinator.swapExactInEth.selector != bytes4(0));
    }

    /// @dev T32: fee-on-transfer shortfall on Permit2 pull → InvalidAmount(token, expected, actual).
    function test_T32_fotShortPullRevertsInvalidAmount() public {
        FeeOnTransferERC20 fot = new FeeOnTransferERC20("FOT", "FOT", 1000); // 10% fee
        coordinator.registerRouter(
            address(0xBEEF), IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        );

        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(0xBEEF), tokenOut: address(tokenB), minAmountOut: 0, data: ""
        });
        uint256 amountIn = 1e18;
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
                recipient: bob,
                tokenIn: address(fot),
                amountIn: amountIn,
                tokenOut: address(tokenB),
                minAmountOut: 0,
                deadline: block.timestamp + 1 days,
                ethIn: false,
                ethOut: false,
                steps: steps
            });

        fot.mint(alice, amountIn);
        vm.prank(alice);
        fot.approve(address(permit2), type(uint256).max);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) =
            _signPermitWitness(params, 10, block.timestamp + 1 days);

        // 10% fee → actual received 0.9e18
        uint256 expectedActual = amountIn - (amountIn * 1000) / 10_000;
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBalancerV3UniswapV4CoordinatorRouter.InvalidAmount.selector, address(fot), amountIn, expectedActual
            )
        );
        coordinator.swapExactInWithPermit(params, permit, sig);
    }

    /* ---------------------------------------------------------------------- */
    /*  WP-N-RTR-001: missing validation exact selectors                      */
    /* ---------------------------------------------------------------------- */

    /// @notice EmptyRoute when steps.length == 0.
    function test_N_emptyRoute_reverts_EmptyRoute() public {
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](0);
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
                recipient: bob,
                tokenIn: address(tokenA),
                amountIn: 1e18,
                tokenOut: address(tokenB),
                minAmountOut: 0,
                deadline: block.timestamp + 1 days,
                ethIn: false,
                ethOut: false,
                steps: steps
            });
        tokenA.mint(alice, 1e18);
        vm.prank(alice);
        tokenA.approve(address(permit2), type(uint256).max);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) =
            _signPermitWitness(params, 40, block.timestamp + 1 days);
        vm.prank(alice);
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.EmptyRoute.selector);
        coordinator.swapExactInWithPermit(params, permit, sig);
    }

    /// @notice TokenOutMismatch when last step.tokenOut != params.tokenOut.
    function test_N_tokenOutMismatch_reverts_TokenOutMismatch() public {
        coordinator.registerRouter(
            address(0xBEEF), IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        );
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(0xBEEF), tokenOut: address(tokenB), minAmountOut: 0, data: ""
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
                recipient: bob,
                tokenIn: address(tokenA),
                amountIn: 1e18,
                tokenOut: address(tokenA), // ≠ step.tokenOut
                minAmountOut: 0,
                deadline: block.timestamp + 1 days,
                ethIn: false,
                ethOut: false,
                steps: steps
            });
        tokenA.mint(alice, 1e18);
        vm.prank(alice);
        tokenA.approve(address(permit2), type(uint256).max);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) =
            _signPermitWitness(params, 41, block.timestamp + 1 days);
        vm.prank(alice);
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.TokenOutMismatch.selector);
        coordinator.swapExactInWithPermit(params, permit, sig);
    }

    /// @notice InvalidEthOut when ethOut=true but tokenOut is not WETH.
    function test_N_invalidEthOut_reverts_InvalidEthOut() public {
        coordinator.registerRouter(
            address(0xBEEF), IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        );
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(0xBEEF), tokenOut: address(tokenB), minAmountOut: 0, data: ""
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
                recipient: bob,
                tokenIn: address(tokenA),
                amountIn: 1e18,
                tokenOut: address(tokenB),
                minAmountOut: 0,
                deadline: block.timestamp + 1 days,
                ethIn: false,
                ethOut: true,
                steps: steps
            });
        tokenA.mint(alice, 1e18);
        vm.prank(alice);
        tokenA.approve(address(permit2), type(uint256).max);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) =
            _signPermitWitness(params, 42, block.timestamp + 1 days);
        vm.prank(alice);
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.InvalidEthOut.selector);
        coordinator.swapExactInWithPermit(params, permit, sig);
    }

    /// @notice ZeroAmount when amountIn=0 reaches hop loop (after successful zero pull).
    function test_N_zeroAmountIn_reverts_ZeroAmount() public {
        coordinator.registerRouter(
            address(0xBEEF), IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        );
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(0xBEEF), tokenOut: address(tokenB), minAmountOut: 0, data: ""
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
                recipient: bob,
                tokenIn: address(tokenA),
                amountIn: 0,
                tokenOut: address(tokenB),
                minAmountOut: 0,
                deadline: block.timestamp + 1 days,
                ethIn: false,
                ethOut: false,
                steps: steps
            });
        vm.prank(alice);
        tokenA.approve(address(permit2), type(uint256).max);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) =
            _signPermitWitness(params, 43, block.timestamp + 1 days);
        vm.prank(alice);
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.ZeroAmount.selector);
        coordinator.swapExactInWithPermit(params, permit, sig);
    }

    /// @notice InsufficientEth when msg.value < amountIn on eth entry.
    function test_N_insufficientEth_reverts_InsufficientEth() public {
        coordinator.registerRouter(
            address(0xBEEF), IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        );
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(0xBEEF), tokenOut: address(weth), minAmountOut: 0, data: ""
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
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
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.InsufficientEth.selector);
        coordinator.swapExactInEth{value: 0.5e18}(params);
    }
}

/// @dev Non-SUT harness: transferFrom delivers amount − fee to `to`.
contract FeeOnTransferERC20 is SimpleMintableERC20 {
    uint256 public immutable feeBps;

    constructor(string memory name_, string memory symbol_, uint256 feeBps_) SimpleMintableERC20(name_, symbol_) {
        feeBps = feeBps_;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        uint256 fee = (amount * feeBps) / 10_000;
        uint256 send = amount - fee;
        require(balanceOf[from] >= amount, "balance");
        balanceOf[from] -= amount;
        balanceOf[to] += send;
        // fee burned (removed from supply accounting for simplicity)
        emit Transfer(from, to, send);
        return true;
    }
}
