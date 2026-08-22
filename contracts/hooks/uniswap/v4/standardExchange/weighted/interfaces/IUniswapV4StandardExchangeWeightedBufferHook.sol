// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

/**
 * @title IUniswapV4StandardExchangeWeightedBufferHook
 * @notice Public product surface: n-asset (2–8) Balancer weighted book with ≥1 SE buffer legs.
 * @dev LP ERC-20 + EIP-2612 + vault discovery via shared diamond facets (not redeclared here).
 *      Canonical SE In/Out selectors live on IStandardExchangeIn / IStandardExchangeOut.
 *      Multi-token liquidity also on IStandardExchangeMultiAssetLiquidity (1:1 with this surface).
 *      No permit2Data on join ABI (Q24) — transferFrom if allowance else Permit2 AllowanceTransfer.
 *      B6: *Flexible paths accept pair token and/or SE vault share per buffered leg.
 */
interface IUniswapV4StandardExchangeWeightedBufferHook {
    enum KLastMode {
        FullProduct,
        PartialInterim
    }

    event Join(
        address indexed sender,
        address indexed to,
        uint256 shares,
        int256[] deltas,
        uint256 protocolSharesMinted
    );
    event Exit(
        address indexed sender,
        address indexed to,
        uint256 shares,
        int256[] deltas,
        uint256 protocolSharesMinted
    );
    event DepositSingle(
        address indexed sender,
        address indexed to,
        address token,
        uint256 amountIn,
        uint256 shares,
        uint256 protocolSharesMinted
    );
    event WithdrawSingle(
        address indexed sender,
        address indexed to,
        address token,
        uint256 amountOut,
        uint256 shares,
        uint256 protocolSharesMinted
    );
    event WithdrawSingleExactOut(
        address indexed sender,
        address indexed to,
        address token,
        uint256 amountOut,
        uint256 sharesBurned,
        uint256 protocolSharesMinted
    );
    event ProtocolFeeMinted(address indexed feeTo, uint256 shares);
    event PairPoolsEnsured(address indexed hook, uint256 doorsEnsured);

    /// @notice B6 proportional join with per-leg pair vs SE-share units (`amountIsSeShare`).
    event JoinFlexible(
        address indexed sender,
        address indexed to,
        uint256 shares,
        uint256[] amounts,
        bool[] amountIsSeShare,
        uint256[] usedAmounts,
        uint256 protocolSharesMinted
    );

    /// @notice B6 proportional exit paying pair and/or SE shares per leg (`receiveSeShare`).
    event ExitFlexible(
        address indexed sender,
        address indexed to,
        uint256 shares,
        bool[] receiveSeShare,
        uint256[] amounts,
        uint256 protocolSharesMinted
    );

    event DepositSingleFlexible(
        address indexed sender,
        address indexed to,
        address token,
        uint256 amountIn,
        bool amountIsSeShare,
        uint256 shares,
        uint256 protocolSharesMinted
    );

    event WithdrawSingleFlexible(
        address indexed sender,
        address indexed to,
        address token,
        uint256 amountOut,
        bool receiveSeShare,
        uint256 shares,
        uint256 protocolSharesMinted
    );

    /* ------------------------------- Binding -------------------------------- */

    function poolManager() external view returns (IPoolManager);
    function feeOracle() external view returns (IVaultFeeOracleQuery);
    function permit2() external view returns (address);
    function numTokens() external view returns (uint8);
    function tokens() external view returns (address[] memory);
    function token(uint256 index) external view returns (address);
    function getNormalizedWeights() external view returns (uint256[] memory);
    function weight(uint256 index) external view returns (uint256);
    function standardExchange(uint256 index) external view returns (address);
    function rateProvider(uint256 index) external view returns (address);
    function isBuffered(uint256 index) external view returns (bool);

    /* --------------------------- Inventory / rated -------------------------- */

    function nativeReserve(uint256 index) external view returns (uint256);
    function nativeReserves() external view returns (uint256[] memory);
    function ratedBalance(uint256 index) external view returns (uint256);
    function ratedBalances() external view returns (uint256[] memory);
    function seBalance(uint256 index) external view returns (uint256);
    function seClaim(uint256 index) external view returns (uint256);
    function invScale(uint256 index) external view returns (uint256);
    function ratedScale(uint256 index) external view returns (uint256);

    /* -------------------------------- Fees ---------------------------------- */

    function dexSwapFee() external view returns (uint256);
    function usageFee() external view returns (uint256);
    function feeTo() external view returns (address);
    function kLast() external view returns (uint256);
    function kLastMode() external view returns (KLastMode);
    function isFullBook() external view returns (bool);

    /* ----------------------------- Pair doors ------------------------------- */

    function ensurePairPools() external returns (uint256 doorsEnsured);
    function pairDoorCount() external view returns (uint256);

    /* ------------------------------ Previews -------------------------------- */

    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn);

    /// @notice D89 / D30: owner exact-in on the weighted book. Internal settlement (no nested unlock).
    function ownerSwapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /// @notice D89 / D30: owner exact-out on the weighted book. Internal settlement (no nested unlock).
    function ownerSwapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        uint256 deadline
    ) external returns (uint256 amountIn);

    function previewJoinProportional(uint256[] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[] memory usedAmounts);

    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 shares);

    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut)
        external
        view
        returns (uint256 amountIn);

    function previewJoinUnbalanced(uint256[] calldata amounts) external view returns (uint256 shares);

    function previewExitProportional(uint256 shares) external view returns (uint256[] memory amounts);

    function previewExitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn)
        external
        view
        returns (uint256 amountOut);

    function previewExitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 sharesIn);

    function previewDepositSingle(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 shares);

    function previewWithdrawSingle(address tokenOut, uint256 sharesIn)
        external
        view
        returns (uint256 amountOut);

    function previewWithdrawSingleExactOut(address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 sharesIn);

    /// @notice B6: proportional join preview; `amountIsSeShare[i]` selects SE vault share vs pair for leg i.
    function previewJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata amountIsSeShare)
        external
        view
        returns (uint256 shares, uint256[] memory usedAmounts);

    function previewExitProportionalFlexible(uint256 shares, bool[] calldata receiveSeShare)
        external
        view
        returns (uint256[] memory amounts);

    function previewJoinSingleAssetExactInFlexible(address tokenIn, uint256 amountIn, bool amountIsSeShare)
        external
        view
        returns (uint256 shares);

    function previewDepositSingleFlexible(address tokenIn, uint256 amountIn, bool amountIsSeShare)
        external
        view
        returns (uint256 shares);

    function previewExitSingleAssetExactBptInFlexible(address tokenOut, uint256 sharesIn, bool receiveSeShare)
        external
        view
        returns (uint256 amountOut);

    function previewWithdrawSingleFlexible(address tokenOut, uint256 sharesIn, bool receiveSeShare)
        external
        view
        returns (uint256 amountOut);

    /* ------------------------------ Liquidity ------------------------------- */

    function joinProportional(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external returns (uint256 shares, uint256[] memory usedAmounts);

    function joinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external returns (uint256 shares);

    function joinSingleAssetExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline
    ) external returns (uint256 amountIn);

    function joinUnbalanced(uint256[] calldata amounts, address to, uint256 sharesMin, uint256 deadline)
        external
        returns (uint256 shares);

    function exitProportional(uint256 shares, address to, uint256[] calldata amountsMin, uint256 deadline)
        external
        returns (uint256[] memory amounts);

    function exitSingleAssetExactBptIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function exitSingleAssetExactTokenOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) external returns (uint256 sharesIn);

    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external returns (uint256 shares);

    function withdrawSingle(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function withdrawSingleExactOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) external returns (uint256 sharesIn);

    /* ------------------------- B6: SE-share flexible LP ------------------------- */

    /// @notice B6 proportional join: per leg pair token and/or SE vault share (buffered legs only).
    function joinProportionalFlexible(
        uint256[] calldata amounts,
        bool[] calldata amountIsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external returns (uint256 shares, uint256[] memory usedAmounts);

    /// @notice B6 proportional exit: pay pair tokens and/or SE vault shares per buffered leg.
    function exitProportionalFlexible(
        uint256 shares,
        address to,
        bool[] calldata receiveSeShare,
        uint256[] calldata amountsMin,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function joinSingleAssetExactInFlexible(
        address tokenIn,
        uint256 amountIn,
        bool amountIsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external returns (uint256 shares);

    function depositSingleFlexible(
        address tokenIn,
        uint256 amountIn,
        bool amountIsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external returns (uint256 shares);

    function exitSingleAssetExactBptInFlexible(
        address tokenOut,
        uint256 sharesIn,
        bool receiveSeShare,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function withdrawSingleFlexible(
        address tokenOut,
        uint256 sharesIn,
        bool receiveSeShare,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) external returns (uint256 amountOut);
}
