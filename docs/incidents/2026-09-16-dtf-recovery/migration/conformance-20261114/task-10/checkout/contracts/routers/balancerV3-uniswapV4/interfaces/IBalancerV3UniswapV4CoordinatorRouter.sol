// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

/// @title IBalancerV3UniswapV4CoordinatorRouter
/// @notice Types, errors, events, and full Coordinator diamond surface (exact-in, query, admin, witness).
interface IBalancerV3UniswapV4CoordinatorRouter {
    /* --------------------------------- Enums -------------------------------- */

    enum AdapterKind {
        StockBalancerV3Router,
        StockBalancerV3BatchRouter,
        IndexedExSERouter,
        UniswapV4UniversalRouter
    }

    enum StepCallMode {
        SingleExactIn,
        BatchExactIn
    }

    /* -------------------------------- Structs ------------------------------- */

    struct RouteStep {
        address router;
        address tokenOut;
        uint256 minAmountOut;
        bytes data;
    }

    struct SwapExactInParams {
        address recipient;
        address tokenIn;
        uint256 amountIn;
        address tokenOut;
        uint256 minAmountOut;
        uint256 deadline;
        bool ethIn;
        bool ethOut;
        RouteStep[] steps;
    }

    struct InitialRouter {
        address router;
        AdapterKind kind;
    }

    /* --------------------------------- Errors ------------------------------- */

    error ExpiredDeadline();
    error EmptyRoute();
    error RouterNotAllowed(address router);
    error InvalidRouterKind();
    error TokenOutMismatch();
    error InvalidRecipient();
    error InvalidEthIn();
    error InvalidEthOut();
    error InsufficientEth();
    error MinAmountOutNotMet(uint256 min, uint256 actual);
    error ZeroAddress();
    error InvalidStepData();
    error InvalidPermitWitness();
    error PermitRequired();
    error InvalidAmount(address token, uint256 expected, uint256 actual);
    error ZeroAmount();

    /* --------------------------------- Events ------------------------------- */

    event RouterRegistered(address indexed router, AdapterKind kind);
    event RouterUnregistered(address indexed router);
    event RouteExecuted(
        address indexed principal,
        address indexed recipient,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 stepCount
    );
    event StepExecuted(uint256 indexed index, address indexed router, address tokenOut, uint256 amountOut);
    event TokensRescued(address indexed token, address indexed to, uint256 amount);
    event ETHRescued(address indexed to, uint256 amount);

    /* -------------------------------- Execute ------------------------------- */

    function swapExactInWithPermit(
        SwapExactInParams calldata params,
        ISignatureTransfer.PermitTransferFrom calldata permit,
        bytes calldata signature
    ) external payable returns (uint256 amountOut);

    function swapExactInEth(SwapExactInParams calldata params) external payable returns (uint256 amountOut);

    function queryExactIn(SwapExactInParams calldata params) external returns (uint256 amountOut);

    /* --------------------------------- Admin -------------------------------- */

    function registerRouter(address router, AdapterKind kind) external;

    function unregisterRouter(address router) external;

    function isRouterAllowed(address router) external view returns (bool);

    function routerKind(address router) external view returns (AdapterKind);

    function allowedRouterCount() external view returns (uint256);

    function allowedRouterAt(uint256 index) external view returns (address);

    function rescueTokens(address token, address to, uint256 amount) external;

    function rescueETH(address to, uint256 amount) external;

    /* -------------------------------- Witness ------------------------------- */

    function WITNESS_TYPE_STRING() external pure returns (string memory);

    function WITNESS_TYPEHASH() external pure returns (bytes32);
}

/// @title IBalancerV3UniswapV4CoordinatorRouterDFPkg
/// @notice DFPkg init/args (Crane rule: structs on interface).
interface IBalancerV3UniswapV4CoordinatorRouterDFPkg {
    struct PkgInit {
        IFacet multiStepOwnableFacet;
        IFacet exactInFacet;
        IFacet queryFacet;
        IFacet adminFacet;
        IFacet permit2WitnessFacet;
        IPermit2 permit2;
        IWETH weth;
        address v4Quoter;
    }

    struct PkgArgs {
        address owner;
        IBalancerV3UniswapV4CoordinatorRouter.InitialRouter[] initialRouters;
    }
}
