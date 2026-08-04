// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

/**
 * @title IUniswapV4OrbitalSwapHook
 * @notice Public surface for 3-asset Orbital sphere V4 hook + LP ERC-20 (PRD §5.1).
 * @dev Q44 sphere-NAV, D20 trading residual, D51–D59 growth fee. LP ERC-20 + EIP-2612 on same contract.
 */
interface IUniswapV4OrbitalSwapHook {
    enum KLastMode {
        FullProduct,
        SumInterim
    }

    function poolManager() external view returns (IPoolManager);
    function feeOracle() external view returns (IVaultFeeOracleQuery);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function token2() external view returns (address);
    /// @notice Sphere radius R in 1e18; 0 until first mint.
    function radius() external view returns (uint256);
    function dexSwapFee() external view returns (uint256);
    function usageFee() external view returns (uint256);
    function feeTo() external view returns (address);
    function kLast() external view returns (uint256);
    function kLastMode() external view returns (KLastMode);
    function lSquared() external view returns (uint256);
    function reserveOf(address token) external view returns (uint256);

    function previewAddLiquidity(uint256 a0Max, uint256 a1Max, uint256 a2Max)
        external
        view
        returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2);

    function previewRemoveLiquidity(uint256 shares)
        external
        view
        returns (uint256 a0, uint256 a1, uint256 a2);

    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn);

    /// @param permit2Data empty => SafeERC20 transferFrom only; non-empty => Permit2 (§5.6)
    function addLiquidity(
        uint256 a0Max,
        uint256 a1Max,
        uint256 a2Max,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2);

    /// @dev Burns `shares` from msg.sender only (Q41). Pays native legs to `to`.
    function removeLiquidity(
        uint256 shares,
        address to,
        uint256 a0Min,
        uint256 a1Min,
        uint256 a2Min,
        uint256 deadline
    ) external returns (uint256 a0, uint256 a1, uint256 a2);
}
