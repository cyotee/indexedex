// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {BetterAddress} from "@crane/contracts/utils/BetterAddress.sol";
import {
    TokenConfig,
    PoolRoleAccounts
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {WeightedPool} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool.sol";
import {
    TestBase_BalancerV3_8020WeightedPool
} from "@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3_8020WeightedPool.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter,
    IBalancerV3UniswapV4CoordinatorRouterDFPkg
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouter_FactoryService
} from "contracts/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol";

/// @notice T16–T18 ETH entry/exit success + structural negatives.
contract BalancerV3UniswapV4CoordinatorRouter_Eth_Test is TestBase_BalancerV3_8020WeightedPool {
    using BalancerV3UniswapV4CoordinatorRouter_FactoryService for *;

    IBalancerV3UniswapV4CoordinatorRouter internal coordinator;
    uint256 internal alicePk = 0xA11CE;
    address internal aliceUser;
    address internal recipient;
    address internal wethUsdcPool;

    function setUp() public override {
        super.setUp();
        initDaiUsdc8020WeightedPool();
        wethUsdcPool = _createAndInitWethUsdcPool();

        aliceUser = vm.addr(alicePk);
        recipient = makeAddr("ethRecipient");

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
        vm.startPrank(aliceUser);
        dai.approve(address(permit2), type(uint256).max);
        vm.stopPrank();
    }

    function _createAndInitWethUsdcPool() internal returns (address p) {
        TokenConfig memory wethCfg = standardTokenConfig(IERC20(address(weth)));
        TokenConfig memory usdcCfg = standardTokenConfig(usdc);
        PoolRoleAccounts memory roleAccounts;
        WeightedPool wp = WeightedPool(weighted8020Factory.create(wethCfg, usdcCfg, roleAccounts, 1e16));
        p = address(wp);
        _approveForAllUsers(IERC20(p));
        _approveSpenderForAllUsers(address(router), IERC20(p));
        _approveSpenderForAllUsers(address(vault), IERC20(p));

        address[] memory tokens = new address[](2);
        tokens[0] = address(weth);
        tokens[1] = address(usdc);
        tokens = BetterAddress._sort(tokens);
        uint256[] memory amounts = new uint256[](2);
        for (uint256 i; i < 2; ++i) {
            amounts[i] = tokens[i] == address(weth) ? 50 ether : 50e18;
        }
        // Fresh Permit2 allowances for init join. mintPoolTokens may clear prank for WETH deposit.
        vm.startPrank(lp);
        IERC20(address(weth)).approve(address(permit2), type(uint256).max);
        usdc.approve(address(permit2), type(uint256).max);
        permit2.approve(address(weth), address(router), type(uint160).max, type(uint48).max);
        permit2.approve(address(usdc), address(router), type(uint160).max, type(uint48).max);
        vm.stopPrank();
        vm.prank(lp);
        mintPoolTokens(tokens, amounts);
        vm.startPrank(lp);
        _initPool(p, amounts, 0);
        vm.stopPrank();
    }

    function test_T16_insufficientEthReverts() public {
        bytes memory stepData = abi.encode(wethUsdcPool, address(weth), address(usdc), uint256(0), false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(router), tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _ethParams(1 ether, address(usdc), false, steps);
        vm.deal(aliceUser, 0.5 ether);
        vm.prank(aliceUser);
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.InsufficientEth.selector);
        coordinator.swapExactInEth{value: 0.5 ether}(params);
    }

    function test_InvalidEthInWhenTokenNotWeth() public {
        bytes memory stepData = abi.encode(wethUsdcPool, address(weth), address(usdc), uint256(0), false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(router), tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _ethParams(1 ether, address(usdc), false, steps);
        params.tokenIn = address(0xBAD);
        vm.deal(aliceUser, 1 ether);
        vm.prank(aliceUser);
        vm.expectRevert(IBalancerV3UniswapV4CoordinatorRouter.InvalidEthIn.selector);
        coordinator.swapExactInEth{value: 1 ether}(params);
    }

    /// @dev T16 success: ethIn wrap + swap; excess ETH refunded to principal (msg.sender).
    function test_T16_ethInSuccessExcessRefundedToPrincipal() public {
        bytes memory stepData = abi.encode(wethUsdcPool, address(weth), address(usdc), uint256(0), false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(router), tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });
        uint256 amountIn = 1 ether;
        uint256 sendValue = 1.25 ether;
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _ethParams(amountIn, address(usdc), false, steps);

        vm.deal(aliceUser, sendValue);
        uint256 aliceBefore = aliceUser.balance;
        uint256 recipBefore = IERC20(address(usdc)).balanceOf(recipient);
        vm.prank(aliceUser);
        uint256 amountOut = coordinator.swapExactInEth{value: sendValue}(params);

        assertGt(amountOut, 0);
        assertEq(IERC20(address(usdc)).balanceOf(recipient) - recipBefore, amountOut);
        // Excess 0.25 ether returned to principal
        assertEq(aliceUser.balance, aliceBefore - amountIn);
    }

    /// @dev T17: ethOut unwraps WETH and pays ETH to recipient.
    function test_T17_ethOutToRecipient() public {
        bytes memory stepData = abi.encode(wethUsdcPool, address(usdc), address(weth), uint256(0), false, bytes(""));
        // Fund USDC for alice
        usdc.mint(aliceUser, 20e18);
        vm.prank(aliceUser);
        usdc.approve(address(permit2), type(uint256).max);

        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(router), tokenOut: address(weth), minAmountOut: 0, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
                recipient: recipient,
                tokenIn: address(usdc),
                amountIn: 5e18,
                tokenOut: address(weth),
                minAmountOut: 1,
                deadline: block.timestamp + 1 days,
                ethIn: false,
                ethOut: true,
                steps: steps
            });
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 17);
        uint256 ethBefore = recipient.balance;
        vm.prank(aliceUser);
        uint256 amountOut = coordinator.swapExactInWithPermit(params, permit, sig);
        assertGt(amountOut, 0);
        assertEq(recipient.balance - ethBefore, amountOut);
        assertEq(IERC20(address(weth)).balanceOf(recipient), 0);
    }

    /// @dev T18: ethIn + ethOut; recipient ≠ principal.
    function test_T18_ethInEthOutRecipientNotPrincipal() public {
        // Hop1: WETH → USDC, hop2: USDC → WETH, unwrap to recipient
        bytes memory step1 = abi.encode(wethUsdcPool, address(weth), address(usdc), uint256(0), false, bytes(""));
        bytes memory step2 = abi.encode(wethUsdcPool, address(usdc), address(weth), uint256(0), false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](2);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(router), tokenOut: address(usdc), minAmountOut: 0, data: step1
        });
        steps[1] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(router), tokenOut: address(weth), minAmountOut: 0, data: step2
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            _ethParams(1 ether, address(weth), true, steps);
        assertTrue(recipient != aliceUser);

        vm.deal(aliceUser, 1 ether);
        uint256 ethBefore = recipient.balance;
        vm.prank(aliceUser);
        uint256 amountOut = coordinator.swapExactInEth{value: 1 ether}(params);
        assertGt(amountOut, 0);
        assertEq(recipient.balance - ethBefore, amountOut);
        assertEq(aliceUser.balance, 0);
    }

    function _ethParams(
        uint256 amountIn,
        address tokenOut,
        bool ethOut,
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps
    ) internal view returns (IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory) {
        return IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
            recipient: recipient,
            tokenIn: address(weth),
            amountIn: amountIn,
            tokenOut: tokenOut,
            minAmountOut: 1,
            deadline: block.timestamp + 1 days,
            ethIn: true,
            ethOut: ethOut,
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
                permitWitnessTypehash,
                tokenPermissionsHash,
                address(coordinator),
                permit.nonce,
                permit.deadline,
                witness
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", permit2.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
