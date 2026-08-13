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

    struct ImportRemintState {
        uint256 booked0;
        uint256 booked1;
        uint256 inbound0;
        uint256 inbound1;
        uint160 sqrtPriceX96;
        uint128 remintLiquidity;
        uint256 amount0Used;
        uint256 amount1Used;
    }

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

        _exitNftRemintAndRefund(
            positionManager, positionTokenId, owner, recipient, deadline, token0, token1, tickLower, tickUpper, liquidity
        );
        ERC20Repo._mint(recipient, sharesOut);
    }

    /// @dev Snapshot booked pair balances, exit the NFT, remint this-call inbound only, refund unused inbound.
    function _exitNftRemintAndRefund(
        INonfungiblePositionManager positionManager,
        uint256 positionTokenId,
        address owner,
        address recipient,
        uint256 deadline,
        address token0,
        address token1,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal {
        ImportRemintState memory state;
        state.booked0 = IERC20(token0).balanceOf(address(this));
        state.booked1 = IERC20(token1).balanceOf(address(this));

        IERC721(address(positionManager)).transferFrom(owner, address(this), positionTokenId);

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

        UniswapV3VaultRepo._initializeImportedCenter(address(positionManager), positionTokenId, tickLower, tickUpper);

        state.inbound0 = IERC20(token0).balanceOf(address(this)) - state.booked0;
        state.inbound1 = IERC20(token1).balanceOf(address(this)) - state.booked1;
        (,, state.sqrtPriceX96,,) = _loadPoolState();
        state.remintLiquidity = UniswapV3Utils._quoteLiquidityForAmounts(
            state.sqrtPriceX96, tickLower, tickUpper, state.inbound0, state.inbound1
        );
        (state.amount0Used, state.amount1Used) =
            _mintLiquidity(address(this), tickLower, tickUpper, state.remintLiquidity);
        _updateManagedPositionLiquidities();

        _refundRemainderTo(
            token0, recipient, state.inbound0 > state.amount0Used ? state.inbound0 - state.amount0Used : 0
        );
        _refundRemainderTo(
            token1, recipient, state.inbound1 > state.amount1Used ? state.inbound1 - state.amount1Used : 0
        );
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

    /// @dev E6: refund only this-call unused inbound, never the entire `balanceOf(this)`.
    function _refundRemainderTo(address token, address recipient, uint256 unusedInbound) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 refund = unusedInbound < balance ? unusedInbound : balance;
        if (refund > 0) {
            IERC20(token).safeTransfer(recipient, refund);
        }
    }
}
