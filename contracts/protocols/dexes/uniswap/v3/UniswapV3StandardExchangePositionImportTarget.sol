// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {
    INonfungiblePositionManager
} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {UniswapV3Utils} from "@crane/contracts/utils/math/UniswapV3Utils.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {UniswapV3VaultRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3VaultRepo.sol";
import {
    UniswapV3StandardExchangeCommon
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeCommon.sol";

interface IUniswapV3StandardExchangePositionImport {
    function previewImportPosition(INonfungiblePositionManager positionManager, uint256 positionTokenId)
        external
        view
        returns (uint256 sharesOut);

    function importPosition(
        INonfungiblePositionManager positionManager,
        uint256 positionTokenId,
        uint256 minSharesOut,
        address owner,
        address recipient,
        uint256 deadline
    ) external returns (uint256 sharesOut);
}

/**
 * @title UniswapV3StandardExchangePositionImportTarget
 * @notice Convert an NPM NFT into a vault-owned direct-pool center position.
 * @dev Leaves the empty NFT on the vault (does not burn). Wings remain uncreated.
 */
contract UniswapV3StandardExchangePositionImportTarget is
    UniswapV3StandardExchangeCommon,
    ReentrancyLockModifiers,
    IUniswapV3StandardExchangePositionImport
{
    using BetterSafeERC20 for IERC20;

    error UniswapV3ExchangeImport_DeadlineExceeded();
    error UniswapV3ExchangeImport_Unavailable();
    error UniswapV3ExchangeImport_InvalidImportedPool();
    error UniswapV3ExchangeImport_ZeroLiquidity();
    error UniswapV3ExchangeImport_SlippageExceeded();

    function previewImportPosition(INonfungiblePositionManager positionManager, uint256 positionTokenId)
        external
        view
        override
        returns (uint256 sharesOut)
    {
        return _quoteImportShares(positionManager, positionTokenId);
    }

    function importPosition(
        INonfungiblePositionManager positionManager,
        uint256 positionTokenId,
        uint256 minSharesOut,
        address owner,
        address recipient,
        uint256 deadline
    ) external override nonReentrant returns (uint256 sharesOut) {
        if (deadline < block.timestamp) revert UniswapV3ExchangeImport_DeadlineExceeded();
        _requireNotDisabled();

        if (IERC20(address(this)).totalSupply() != 0 || UniswapV3VaultRepo._isPositionCreated()) {
            revert UniswapV3ExchangeImport_Unavailable();
        }

        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,
        ) = positionManager.positions(positionTokenId);

        if (liquidity == 0) revert UniswapV3ExchangeImport_ZeroLiquidity();
        _requireMatchingPool(token0, token1, fee);

        sharesOut = _quoteImportShares(positionManager, positionTokenId);
        if (sharesOut < minSharesOut) revert UniswapV3ExchangeImport_SlippageExceeded();

        // Pull NFT into vault (requires approval / operator from owner).
        IERC721(address(positionManager)).transferFrom(owner, address(this), positionTokenId);

        // Full exit of NFT liquidity + collect all tokensOwed into vault balances.
        positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: positionTokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: deadline
            })
        );
        positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: positionTokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        // Leave empty NFT on vault — do not burn.

        UniswapV3VaultRepo._initializeImportedCenter(address(positionManager), positionTokenId, tickLower, tickUpper);

        // Remint center at same ticks with principal + compoundable fees now in free inventory.
        uint256 available0 = IERC20(token0).balanceOf(address(this));
        uint256 available1 = IERC20(token1).balanceOf(address(this));
        (,, uint160 sqrtPriceX96,,) = _loadPoolState();
        uint128 remintLiquidity =
            UniswapV3Utils._quoteLiquidityForAmounts(sqrtPriceX96, tickLower, tickUpper, available0, available1);
        _mintLiquidity(address(this), tickLower, tickUpper, remintLiquidity);
        _updateManagedPositionLiquidities();

        ERC20Repo._mint(recipient, sharesOut);
        // Residual free inventory (dust) stays as working capital / refund policy: refund dust to recipient.
        _refundRemainderTo(token0, recipient);
        _refundRemainderTo(token1, recipient);
    }

    function _quoteImportShares(INonfungiblePositionManager positionManager, uint256 positionTokenId)
        internal
        view
        returns (uint256 sharesOut)
    {
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = positionManager.positions(positionTokenId);

        if (liquidity == 0) revert UniswapV3ExchangeImport_ZeroLiquidity();
        _requireMatchingPool(token0, token1, fee);

        (,, uint160 sqrtPriceX96,,) = _loadPoolState();
        (uint256 amount0, uint256 amount1) =
            UniswapV3Utils._quoteAmountsForLiquidity(sqrtPriceX96, tickLower, tickUpper, liquidity);

        // First deposit share mint: amount0 + amount1 of principal + compoundable fees (tokensOwed).
        sharesOut = amount0 + amount1 + uint256(tokensOwed0) + uint256(tokensOwed1);
    }

    function _requireMatchingPool(address token0, address token1, uint24 fee) internal view {
        IUniswapV3Pool pool = _pool();
        if (pool.token0() != token0 || pool.token1() != token1 || pool.fee() != fee) {
            revert UniswapV3ExchangeImport_InvalidImportedPool();
        }
    }

    function _refundRemainderTo(address token, address recipient) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(recipient, balance);
        }
    }
}
