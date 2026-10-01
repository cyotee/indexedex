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
    IUniswapV4FullSpreadHooklessStandardExchangeVaultPositionImport,
    UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget.sol";
import {
    UniswapV4FullSpreadHooklessStandardExchangeVaultInBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInBase.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo.sol";

contract UniswapV4FullSpreadHooklessStandardExchangeVaultPositionImportTarget is
    UniswapV4FullSpreadHooklessStandardExchangeVaultInBase,
    IUniswapV4FullSpreadHooklessStandardExchangeVaultPositionImport
{
    using CurrencyLibrary for *;

    function importPosition(
        IPositionManager positionManager,
        uint256 positionTokenId,
        uint256 minSharesOut,
        address owner,
        address recipient,
        uint256 deadline
    ) external nonReentrant operationScope returns (uint256 sharesOut) {
        _requireNotDisabled();
        if (recipient == address(0)) revert UniswapV4Exchange_ZeroAmount();
        if (deadline < block.timestamp) revert UniswapV4ExchangeIn_DeadlineExceeded();
        // D15 / T4e: position import hard-reverts while PoolManager is in-session.
        _requireCanOpenPoolManagerUnlock();
        _requireAuthorizedImport(positionManager, owner, positionTokenId);
        if (IERC20(address(this)).totalSupply() != 0 || UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo._isPositionCreated()) {
            revert UniswapV4ExchangeIn_PositionImportUnavailable();
        }
        sharesOut = _executeAuthorizedImport(positionManager, positionTokenId, minSharesOut, recipient);
        _pokeBoundPoolTwap();
    }

    function _requireAuthorizedImport(IPositionManager positionManager, address owner, uint256 positionTokenId)
        internal
        view
    {
        address authorized = address(UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo._authorizedPositionManager());
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
        UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo._finishImportedConversion();
        _createManagedPositionsIfNeeded(_deriveManagedTicks());
        sharesOut = _executeZapInDualDeposit(funded0, funded1, minSharesOut, recipient);
    }

    function _collectImportedAssets(
        IPositionManager positionManager, uint256 positionTokenId, PositionInfo info, uint128 liquidity
    ) private {
        IERC721(address(positionManager)).transferFrom(msg.sender, address(this), positionTokenId);
        UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo._initializeImportedPosition(
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
