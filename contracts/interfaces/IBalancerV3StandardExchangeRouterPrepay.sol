// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                OpenZeppelin                                */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";

interface IBalancerV3StandardExchangeRouterPrepay {
    /// @dev Legacy error retained for ABI compatibility; prefer session-auth errors from the repo.
    error NotCurrentStandardExchangeToken(address provided, address current);

    function isPrepaid() external view returns (bool);

    function currentStandardExchange() external view returns (IStandardExchangeProxy);

    /* ---------------------------------------------------------------------- */
    /*                         Prepay session auth API                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Pass prepay authorization to `next` for nested SE / Buffer→SE calls.
     * @dev No-op success if no prepay session. Reverts if session active and caller is not stack top.
     */
    function passPrepayAuth(address next) external returns (bool);

    /**
     * @notice Restore prepay authorization after a nested call returns.
     * @dev No-op success if no prepay session. Reverts if caller is not the parent principal.
     */
    function restorePrepayAuth() external returns (bool);

    function prepaySessionActive() external view returns (bool);

    function prepayAuthTop() external view returns (address);

    function prepayAuthDepth() external view returns (uint256);

    /* ---------------------------------------------------------------------- */
    /*                              Prepay liquidity                            */
    /* ---------------------------------------------------------------------- */

    function prepayInitialize(
        address pool,
        IERC20[] memory tokens,
        uint256[] memory exactAmountsIn,
        uint256 minBptAmountOut,
        // bool wethIsEth,
        bytes memory userData
    ) external returns (uint256 bptAmountOut);

    function prepayAddLiquidityUnbalanced(
        address pool,
        uint256[] memory exactAmountsIn,
        uint256 minBptAmountOut,
        // bool wethIsEth,
        bytes memory userData
    ) external returns (uint256 bptAmountOut);

    function prepayRemoveLiquidityProportional(
        address pool,
        uint256 exactBptAmountIn,
        uint256[] memory minAmountsOut,
        // bool wethIsEth,
        bytes memory userData
    ) external returns (uint256[] memory amountsOut);

    function prepayRemoveLiquiditySingleTokenExactIn(
        address pool,
        uint256 exactBptAmountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        // bool wethIsEth,
        bytes memory userData
    ) external returns (uint256 amountOut);
}
