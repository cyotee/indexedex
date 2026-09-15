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
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {FixedPoint128} from "@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint128.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {UniswapV3VaultRepoV2} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3VaultRepoV2.sol";
import {
    UniswapV3StandardExchangeCommonV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3StandardExchangeCommonV2.sol";

interface IUniswapV3StandardExchangePositionImportV2 {
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
 * @title UniswapV3StandardExchangePositionImportTargetV2
 * @notice Convert an NPM NFT into a vault-owned direct-pool center position.
 * @dev Leaves the empty NFT on the vault (does not burn). Collected principal and fees join the canonical full-range book (D57).
 */
contract UniswapV3StandardExchangePositionImportTargetV2 is
    UniswapV3StandardExchangeCommonV2,
    ReentrancyLockModifiers,
    IUniswapV3StandardExchangePositionImportV2
{
    using BetterSafeERC20 for IERC20;

    error UniswapV3ExchangeImport_DeadlineExceeded();
    error UniswapV3ExchangeImport_Unavailable();
    error UniswapV3ExchangeImport_InvalidImportedPool();
    error UniswapV3ExchangeImport_ZeroLiquidity();
    error UniswapV3ExchangeImport_SlippageExceeded();
    error UniswapV3ExchangeImport_UnauthorizedOwner();

    struct ImportRemintState {
        uint256 booked0;
        uint256 booked1;
        uint256 inbound0;
        uint256 inbound1;
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
    ) external override nonReentrant inputOperation returns (uint256 sharesOut) {
        if (deadline < block.timestamp) revert UniswapV3ExchangeImport_DeadlineExceeded();
        _requireNotDisabled();
        _requireCanOpenBoundPoolOps();
        IERC721 nft = IERC721(address(positionManager));
        if (nft.ownerOf(positionTokenId) != owner || (msg.sender != owner && nft.getApproved(positionTokenId) != msg.sender
            && !nft.isApprovedForAll(owner, msg.sender))) revert UniswapV3ExchangeImport_UnauthorizedOwner();

        if (IERC20(address(this)).totalSupply() != 0 || UniswapV3VaultRepoV2._isPositionCreated()) {
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

        uint256 quoted = _quoteImportShares(positionManager, positionTokenId);
        if (quoted < minSharesOut) revert UniswapV3ExchangeImport_SlippageExceeded();

        sharesOut = _exitNftAndSleeve(
            positionManager, positionTokenId, owner, deadline, token0, token1, liquidity
        );
        if (sharesOut < minSharesOut) revert UniswapV3ExchangeImport_SlippageExceeded();
        ERC20Repo._mint(recipient, sharesOut);
        _syncVaultReserves();
        _rebalanceLiquidReserveBestEffort();
    }

    /// @dev Exit the NFT to the sleeve, select full-range ticks, and credit only actual inbound assets.
    function _exitNftAndSleeve(
        INonfungiblePositionManager positionManager,
        uint256 positionTokenId,
        address owner,
        uint256 deadline,
        address token0,
        address token1,
        uint128 liquidity
    ) internal returns (uint256 sharesOut) {
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

        ManagedTicks memory fullRange = _deriveManagedTicks();
        UniswapV3VaultRepoV2._createPositionIfNeeded(fullRange.centerLower, fullRange.centerUpper);

        state.inbound0 = IERC20(token0).balanceOf(address(this)) - state.booked0;
        state.inbound1 = IERC20(token1).balanceOf(address(this)) - state.booked1;

        sharesOut = _sharesOutForDeposit(state.inbound0, state.inbound1, 0, state.booked0, state.booked1);
        if (sharesOut == 0) revert UniswapV3Exchange_ZeroAmount();
        uint256 residual = _initialResidualShares(state.inbound0, state.inbound1, state.booked0, state.booked1, sharesOut);
        if (residual > 0) {
            ERC20Repo._mint(DEAD_SHARES_SINK, residual);
        }

    }

    struct ImportedPosition {
        uint96 nonce;
        address operator;
        address token0;
        address token1;
        uint24 fee;
        int24 lower;
        int24 upper;
        uint128 liquidity;
        uint256 growth0;
        uint256 growth1;
        uint128 owed0;
        uint128 owed1;
    }

    function _quoteImportShares(INonfungiblePositionManager positionManager, uint256 positionTokenId)
        internal view returns (uint256 sharesOut)
    {
        (bool ok, bytes memory result) = address(positionManager).staticcall(
            abi.encodeCall(INonfungiblePositionManager.positions, (positionTokenId))
        );
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        ImportedPosition memory p = abi.decode(result, (ImportedPosition));
        if (p.liquidity == 0) revert UniswapV3ExchangeImport_ZeroLiquidity();
        _requireMatchingPool(p.token0, p.token1, p.fee);
        if (positionManager.factory() != _pool().factory()) revert UniswapV3ExchangeImport_InvalidImportedPool();
        (,, uint160 price,,) = _loadPoolState();
        (uint256 amount0, uint256 amount1) = UniswapV3Utils._quoteAmountsForLiquidity(price, p.lower, p.upper, p.liquidity);
        (uint256 growth0, uint256 growth1) = _feeGrowthInside(p.lower, p.upper);
        uint256 fee0; uint256 fee1;
        unchecked {
            fee0 = FullMath.mulDiv(growth0 - p.growth0, p.liquidity, FixedPoint128.Q128);
            fee1 = FullMath.mulDiv(growth1 - p.growth1, p.liquidity, FixedPoint128.Q128);
        }
        sharesOut = _quoteInitialShares(amount0 + p.owed0 + fee0, amount1 + p.owed1 + fee1);
        if (sharesOut == 0) revert UniswapV3Exchange_ZeroAmount();
    }

    function _requireMatchingPool(address token0, address token1, uint24 fee) internal view {
        IUniswapV3Pool pool = _pool();
        if (pool.token0() != token0 || pool.token1() != token1 || pool.fee() != fee) {
            revert UniswapV3ExchangeImport_InvalidImportedPool();
        }
    }

}
