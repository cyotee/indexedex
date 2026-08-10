// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {Vm} from "forge-std/Vm.sol";
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

/// @notice T26 donation-safe ledger; T31 residual + rescue + mid-swap reentrancy → IsLocked.
contract BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue_Test is TestBase_BalancerV3_8020WeightedPool {
    using BalancerV3UniswapV4CoordinatorRouter_FactoryService for *;

    IBalancerV3UniswapV4CoordinatorRouter internal coordinator;
    uint256 internal alicePk = 0xA11CE;
    address internal aliceUser;
    address internal recipient;
    SimpleMintableERC20 internal stray;

    function setUp() public override {
        super.setUp();
        initDaiUsdc8020WeightedPool();
        aliceUser = vm.addr(alicePk);
        recipient = makeAddr("ledgerRecipient");
        stray = new SimpleMintableERC20("STRAY", "STRAY");

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

    function test_T31_rescueTokensAndEth() public {
        stray.mint(address(coordinator), 100e18);
        uint256 before = stray.balanceOf(recipient);
        coordinator.rescueTokens(address(stray), recipient, 40e18);
        assertEq(stray.balanceOf(recipient) - before, 40e18);
        assertEq(stray.balanceOf(address(coordinator)), 60e18);

        vm.deal(address(coordinator), 1 ether);
        uint256 bobEth = recipient.balance;
        coordinator.rescueETH(recipient, 0.3 ether);
        assertEq(recipient.balance - bobEth, 0.3 ether);
    }

    function test_T31_rescueOnlyOwner() public {
        stray.mint(address(coordinator), 1e18);
        vm.prank(aliceUser);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, aliceUser));
        coordinator.rescueTokens(address(stray), aliceUser, 1e18);
    }

    /// @dev Residual inventory after successful swap can be owner-rescued (swap pays ledger amountOut only).
    function test_T31_residualAfterSwapRescueable() public {
        // Pre-donate USDC residual that must NOT be paid out as swap proceeds.
        usdc.mint(address(coordinator), 7e18);
        bytes memory stepData = abi.encode(pool, address(dai), address(usdc), uint256(0), false, bytes(""));
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(router), tokenOut: address(usdc), minAmountOut: 0, data: stepData
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params = _params(10e18, steps);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 31);
        uint256 before = IERC20(address(usdc)).balanceOf(recipient);
        vm.prank(aliceUser);
        uint256 amountOut = coordinator.swapExactInWithPermit(params, permit, sig);
        assertEq(IERC20(address(usdc)).balanceOf(recipient) - before, amountOut);
        // Donated residual remains on diamond for rescue.
        assertEq(IERC20(address(usdc)).balanceOf(address(coordinator)), 7e18);
        coordinator.rescueTokens(address(usdc), recipient, 7e18);
        assertEq(IERC20(address(usdc)).balanceOf(address(coordinator)), 0);
    }

    /// @dev T31: hostile tokenIn re-enters queryExactIn mid-pull and observes IsLocked.
    function test_T31_reentrancyDuringPullIsLocked() public {
        HostileReenterERC20 hostile = new HostileReenterERC20("H", "H");
        coordinator.registerRouter(
            address(0xBEEF), IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router
        );

        IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps =
            new IBalancerV3UniswapV4CoordinatorRouter.RouteStep[](1);
        steps[0] = IBalancerV3UniswapV4CoordinatorRouter.RouteStep({
            router: address(0xBEEF), tokenOut: address(usdc), minAmountOut: 0, data: ""
        });
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params =
            IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams({
                recipient: recipient,
                tokenIn: address(hostile),
                amountIn: 1e18,
                tokenOut: address(usdc),
                minAmountOut: 1,
                deadline: block.timestamp + 1 days,
                ethIn: false,
                ethOut: false,
                steps: steps
            });
        hostile.setReenter(address(coordinator), params);
        hostile.mint(aliceUser, 1e18);
        vm.prank(aliceUser);
        hostile.approve(address(permit2), type(uint256).max);
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(params, 99);
        // Outer call reverts (fake child), rolling back token storage — observe via event logs.
        vm.recordLogs();
        vm.prank(aliceUser);
        try coordinator.swapExactInWithPermit(params, permit, sig) {} catch {}
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256("SawIsLocked()");
        bool found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == topic) {
                found = true;
                break;
            }
        }
        assertTrue(found, "nested query must emit SawIsLocked (IsLocked under shared lock)");
    }

    function _params(uint256 amountIn, IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] memory steps)
        internal
        view
        returns (IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory)
    {
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

/// @dev On transferFrom, re-enters coordinator.queryExactIn (shared nonReentrant) and emits SawIsLocked.
/// Stores reenter calldata as bytes so nested RouteStep[] is not copied into storage (legacy solc ban).
contract HostileReenterERC20 is SimpleMintableERC20 {
    event SawIsLocked();

    IBalancerV3UniswapV4CoordinatorRouter public target;
    bytes internal reenterCalldata;
    bool public armed;

    constructor(string memory n, string memory s) SimpleMintableERC20(n, s) {}

    function setReenter(address coordinator_, IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params_)
        external
    {
        target = IBalancerV3UniswapV4CoordinatorRouter(coordinator_);
        reenterCalldata = abi.encodeWithSelector(
            IBalancerV3UniswapV4CoordinatorRouter.queryExactIn.selector, params_
        );
        armed = true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        if (armed) {
            armed = false;
            (bool ok, bytes memory reason) = address(target).call(reenterCalldata);
            if (!ok && reason.length >= 4) {
                bytes4 sel;
                assembly {
                    sel := mload(add(reason, 0x20))
                }
                if (sel == IReentrancyLock.IsLocked.selector) emit SawIsLocked();
            }
        }
        return true;
    }
}
