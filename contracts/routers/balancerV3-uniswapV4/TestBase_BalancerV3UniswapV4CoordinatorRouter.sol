// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {CraneTest} from "@crane/contracts/test/CraneTest.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter,
    IBalancerV3UniswapV4CoordinatorRouterDFPkg
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouter_FactoryService
} from "contracts/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol";

/// @title TestBase_BalancerV3UniswapV4CoordinatorRouter
/// @notice Pure Crane deploy of Coordinator diamond (not vault registry).
abstract contract TestBase_BalancerV3UniswapV4CoordinatorRouter is CraneTest, TestBase_Permit2 {
    using BalancerV3UniswapV4CoordinatorRouter_FactoryService for *;

    IBalancerV3UniswapV4CoordinatorRouter internal coordinator;
    address internal owner;
    address internal alice;
    uint256 internal alicePk;
    address internal bob;
    address internal v4QuoterAddr;
    IWETH internal coordinatorWeth;

    function setUp() public virtual override(CraneTest, TestBase_Permit2) {
        CraneTest.setUp();
        TestBase_Permit2.setUp();

        owner = address(this);
        alicePk = 0xA11CE;
        alice = vm.addr(alicePk);
        bob = makeAddr("bob");
        vm.label(alice, "alice");
        vm.label(bob, "bob");
    }

    /// @dev Deploy Coordinator with given WETH and optional seed routers. Pure Crane path.
    function _deployCoordinator(
        IWETH weth_,
        address v4Quoter_,
        IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[] memory seed
    ) internal returns (IBalancerV3UniswapV4CoordinatorRouter) {
        coordinatorWeth = weth_;
        v4QuoterAddr = v4Quoter_;
        IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgArgs memory args =
            IBalancerV3UniswapV4CoordinatorRouterDFPkg.PkgArgs({owner: owner, initialRouters: seed});
        coordinator = BalancerV3UniswapV4CoordinatorRouter_FactoryService.deployCoordinator(
            create3Factory, diamondPackageFactory, permit2, weth_, v4Quoter_, args
        );
        return coordinator;
    }

    function _signPermitWitness(
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams memory params,
        uint256 nonce,
        uint256 permitDeadline
    ) internal view returns (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory signature) {
        permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: params.tokenIn, amount: params.amountIn}),
            nonce: nonce,
            deadline: permitDeadline
        });

        bytes32 stepsHash = keccak256(abi.encode(params.steps));
        bytes32 typehash = coordinator.WITNESS_TYPEHASH();
        bytes32 witness = keccak256(
            abi.encode(
                typehash,
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

        // PermitWitnessTransferFrom typehash per Permit2
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

        bytes32 domainSeparator = permit2.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function _fundAndApprovePermit2(address token, address who, uint256 amount) internal {
        deal(token, who, amount);
        vm.prank(who);
        IERC20(token).approve(address(permit2), type(uint256).max);
    }
}
