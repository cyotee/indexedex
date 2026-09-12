// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {CurrencyLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PositionInfo} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/PositionInfoLibrary.sol";

import {
    IUniswapV4StandardExchangePositionImport,
    UniswapV4StandardExchangeInTarget
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol";
import {
    UniswapV4StandardExchangeInBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol";
import {UniswapV4PositionRepo} from "contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol";

contract UniswapV4StandardExchangePositionImportTarget is
    UniswapV4StandardExchangeInBase,
    IUniswapV4StandardExchangePositionImport
{
    using CurrencyLibrary for *;

    function importPosition(
        IPositionManager positionManager,
        uint256 positionTokenId,
        uint256 minSharesOut,
        address owner,
        address recipient,
        uint256 deadline
    ) external nonReentrant returns (uint256 sharesOut) {
        _requireNotDisabled();
        if (recipient == address(0)) revert UniswapV4Exchange_ZeroAmount();
        if (deadline < block.timestamp) revert UniswapV4ExchangeIn_DeadlineExceeded();
        // D15 / T4e: position import hard-reverts while PoolManager is in-session.
        _requireCanOpenPoolManagerUnlock();
        _requireAuthorizedImport(positionManager, owner, positionTokenId);
        if (IERC20(address(this)).totalSupply() != 0 || UniswapV4PositionRepo._isPositionCreated()) {
            revert UniswapV4ExchangeIn_PositionImportUnavailable();
        }
        sharesOut = _executeAuthorizedImport(positionManager, positionTokenId, minSharesOut, recipient);
        _pokeBoundPoolTwap();
    }

    function _requireAuthorizedImport(IPositionManager positionManager, address owner, uint256 positionTokenId)
        internal
        view
    {
        address authorized = address(UniswapV4PositionRepo._authorizedPositionManager());
        if (authorized == address(0) || address(positionManager) != authorized) {
            revert UniswapV4ExchangeIn_UntrustedPositionManager();
        }
        if (owner != msg.sender || IERC721(address(positionManager)).ownerOf(positionTokenId) != msg.sender) {
            revert UniswapV4ExchangeIn_UntrustedImportOwner();
        }
    }

    function _executeAuthorizedImport(
        IPositionManager positionManager,
        uint256 positionTokenId,
        uint256 minSharesOut,
        address recipient
    ) internal returns (uint256 sharesOut) {
        (PoolKey memory poolKey, PositionInfo info) = positionManager.getPoolAndPositionInfo(positionTokenId);
        if (keccak256(abi.encode(poolKey)) != keccak256(abi.encode(_poolKey()))) {
            revert UniswapV4ExchangeIn_InvalidImportedPool();
        }

        uint256 liquidity = positionManager.getPositionLiquidity(positionTokenId);
        if (liquidity == 0) {
            revert UniswapV4Exchange_ZeroAmount();
        }

        // Only the assets actually delivered by this NFT fund the importer's shares.
        // The existing sleeve is assigned its own sink shares and cannot be claimed by importing.
        (uint256 sleeve0, uint256 sleeve1) = _freeBalances();
        _collectImportedAssets(positionManager, positionTokenId, info, uint128(liquidity));
        (uint256 funded0, uint256 funded1) = _freeBalances();
        funded0 -= sleeve0;
        funded1 -= sleeve1;
        sharesOut = _sharesOutForDeposit(funded0, funded1, 0, sleeve0, sleeve1);
        if (sharesOut == 0) revert UniswapV4Exchange_ZeroAmount();
        if (sharesOut < minSharesOut) revert UniswapV4ExchangeIn_SlippageExceeded();
        uint256 residual = _initialResidualShares(funded0, funded1, sleeve0, sleeve1, sharesOut);

        UniswapV4PositionRepo._finishImportedConversion();
        _createManagedPositionsIfNeeded(_deriveManagedTicks());
        if (residual > 0) ERC20Repo._mint(DEAD_SHARES_SINK, residual);
        ERC20Repo._mint(recipient, sharesOut);
        _rebalanceLiquidReserveBestEffort();
        _syncVaultReserves();
    }

    function _collectImportedAssets(
        IPositionManager positionManager, uint256 positionTokenId, PositionInfo info, uint128 liquidity
    ) private {
        IERC721(address(positionManager)).transferFrom(msg.sender, address(this), positionTokenId);
        UniswapV4PositionRepo._initializeImportedPosition(
            positionManager, positionTokenId, info.tickLower(), info.tickUpper()
        );
        uint256 nativeBefore = address(this).balance;
        // Decrease collects principal and all earned fees in one settlement.
        _burnImportedLiquidityCommon(liquidity);
        if (_currency0().isAddressZero() || _currency1().isAddressZero()) {
            uint256 nativeReceived = address(this).balance - nativeBefore;
            if (nativeReceived != 0) _weth().deposit{value: nativeReceived}();
        }
    }
}
