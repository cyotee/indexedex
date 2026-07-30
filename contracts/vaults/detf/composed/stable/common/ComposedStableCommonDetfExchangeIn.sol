// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {BetterSafeERC20} from '@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardExchangeProxy} from 'contracts/interfaces/proxies/IStandardExchangeProxy.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfRepo.sol';
import {ComposedStableCommonDetfCommon} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfCommon.sol';
import {
    IComposedStableCommonDetfInfo
} from 'contracts/vaults/detf/composed/stable/common/IComposedStableCommonDetfInfo.sol';
import {ThresholdMode} from 'contracts/vaults/detf/core/DETFThresholdPolicy.sol';

contract ComposedStableCommonDetfExchangeIn is
    ComposedStableCommonDetfCommon,
    IStandardExchangeIn,
    IComposedStableCommonDetfInfo,
    IFacet
{
    using BetterSafeERC20 for IERC20;

    function mintThreshold() external view returns (uint256) {
        return ComposedStableCommonDetfRepo._mintThreshold();
    }

    function burnThreshold() external view returns (uint256) {
        return ComposedStableCommonDetfRepo._burnThreshold();
    }

    function thresholdMode() external view returns (ThresholdMode) {
        return ComposedStableCommonDetfRepo._thresholdMode();
    }

    function isMintingAllowed() external view returns (bool) {
        return _isMintingAllowed();
    }

    function isBurningAllowed() external view returns (bool) {
        return _isBurningAllowed();
    }

    function lastExpansionTimestamp() external view returns (uint256) {
        return ComposedStableCommonDetfRepo._lastExpansionTimestamp();
    }

    function expansionClosureRatePerSecond() external view returns (uint256) {
        return ComposedStableCommonDetfRepo._expansionClosureRatePerSecond();
    }

    function expansionCatchUpMaxSeconds() external view returns (uint256) {
        return ComposedStableCommonDetfRepo._expansionCatchUpMaxSeconds();
    }

    function expansionCatchUpCapBps() external view returns (uint256) {
        return ComposedStableCommonDetfRepo._expansionCatchUpCapBps();
    }

    /// @inheritdoc IComposedStableCommonDetfInfo
    function compoundProtocolRewards() external returns (uint256 detfIn, uint256 bptOut) {
        return _tryCompoundProtocolRewards();
    }

    /**
     * @param tokenIn The token provided to the vault for an exchange.
     * @param amountIn The amount of `tokenIn` the users wishes to exchange for `tokenOut`.
     * @param tokenOut The token the caller wishes to receive in exchange for `tokenIn`.
     * @return amountOut The amount of `tokenOut` the caller will receive in exchange for `amountIn` of `tokenIn`.
     * @custom:selector 0x89d61912
     */
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut) {
        if (amountIn == 0) {
            return 0;
        }

        IERC20 detfToken = ComposedStableCommonDetfRepo._detfToken();
        if (address(tokenOut) == address(detfToken) && address(tokenIn) != address(detfToken)) {
            uint256 syntheticPrice = _syntheticDetfEthPrice();
            if (!_isMintingAllowed(syntheticPrice)) {
                revert MintingNotAllowed(syntheticPrice, ComposedStableCommonDetfRepo._mintThreshold());
            }

            (RoutedPoolSelection memory selection,, uint256 poolBptOut) = _previewRoutedPoolBpt(tokenIn, amountIn);
            return _previewMintSplit(poolBptOut, selection.depositToStablePool).userDetfOut;
        }

        if (address(tokenIn) == address(detfToken) && address(tokenOut) != address(detfToken)) {
            uint256 syntheticPrice = _syntheticDetfEthPrice();
            if (!_isBurningAllowed(syntheticPrice)) {
                revert BurningNotAllowed(syntheticPrice, ComposedStableCommonDetfRepo._burnThreshold());
            }

            _requireReservePoolInitialized();
            amountOut = _previewMostLiquidUnwindSelectionForExactIn(tokenOut, amountIn).tokenOutAmountOut;
            return amountOut;
        }

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }

    function _accrueMintInventory(
        ComposedStableCommonDetfRepo.Storage storage layoutStruct_,
        uint256 reservePoolBptOut_,
        uint256 inventoryDetfOut_
    ) internal {
        IDETFNFTVault bondNftVault = ComposedStableCommonDetfRepo._bondNftVault(layoutStruct_);
        if (address(bondNftVault) == address(0)) {
            revert ExchangeInNotAvailable();
        }

        if (reservePoolBptOut_ > 0) {
            bondNftVault.addToDETFNFT(bondNftVault.detfNFTId(), reservePoolBptOut_);
        }

        if (inventoryDetfOut_ > 0) {
            _mintDetf(address(bondNftVault), inventoryDetfOut_);
        }
    }

    function _executeReservePoolSwapExactIn(ExactInUnwindSelection memory selection_, uint256 exactAmountIn_, uint256 deadline_)
        internal
        returns (uint256 poolBptAmountOut_)
    {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        IERC20 detfToken = ComposedStableCommonDetfRepo._detfToken(layoutStruct);

        _approvePermit2Spend(detfToken, exactAmountIn_, false);

        poolBptAmountOut_ = ComposedStableCommonDetfRepo._balancerV3Router(layoutStruct).swapSingleTokenExactIn(
            address(ComposedStableCommonDetfRepo._reservePool(layoutStruct)),
            detfToken,
            IStandardExchangeProxy(address(0)),
            selection_.poolBptToken,
            IStandardExchangeProxy(address(0)),
            exactAmountIn_,
            0,
            deadline_,
            false,
            ''
        );
    }

    function _executeMintRoute(IStandardExchangeIn.InArgs memory args_) internal returns (uint256 amountOut_) {
        uint256 syntheticPrice = _syntheticDetfEthPrice();
        if (!_isMintingAllowed(syntheticPrice)) {
            revert MintingNotAllowed(syntheticPrice, ComposedStableCommonDetfRepo._mintThreshold());
        }

        RoutedPoolSelection memory selection = _selectRoutingPath(args_.tokenIn);
        ComposedStableCommonDetfRepo.RouteConfig storage route = ComposedStableCommonDetfRepo._routeAt(
            ComposedStableCommonDetfRepo._layoutStruct(), selection.routeIndex
        );

        uint256 actualIn = _secureTokenTransfer(args_.tokenIn, args_.amountIn, args_.pretransferred);
        uint256 poolBptOut =
            _executeRoutedEntryToPoolBptShared(route, selection, args_.tokenIn, actualIn, args_.deadline);

        MintSplit memory mintSplit = _previewMintSplit(poolBptOut, selection.depositToStablePool);

        amountOut_ = mintSplit.userDetfOut;
        if (amountOut_ < args_.minAmountOut) {
            revert SlippageExceeded(args_.minAmountOut, amountOut_);
        }

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        uint256 reservePoolBptOut = _depositIntoReservePoolShared(layoutStruct, selection, poolBptOut, args_.deadline);

        _accrueMintInventory(layoutStruct, reservePoolBptOut, mintSplit.inventoryDetfOut);
        _mintDetf(args_.recipient == address(0) ? msg.sender : args_.recipient, amountOut_);
        // Lazy protocol seigniorage compound (best-effort; never fails user mint).
        _tryCompoundProtocolRewards();
    }

    function _executeBurnRoute(IStandardExchangeIn.InArgs memory args_) internal returns (uint256 amountOut_) {
        _requireReservePoolInitialized();

        uint256 syntheticPrice = _syntheticDetfEthPrice();
        if (!_isBurningAllowed(syntheticPrice)) {
            revert BurningNotAllowed(syntheticPrice, ComposedStableCommonDetfRepo._burnThreshold());
        }

        ExactInUnwindSelection memory selection = _previewMostLiquidUnwindSelectionForExactIn(args_.tokenOut, args_.amountIn);
        uint256 actualIn = _secureTokenTransfer(args_.tokenIn, args_.amountIn, args_.pretransferred);

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        ComposedStableCommonDetfRepo.RouteConfig storage route = ComposedStableCommonDetfRepo._routeAt(
            layoutStruct, selection.routeIndex
        );

        uint256 poolBptAmountOut = _executeReservePoolSwapExactIn(selection, actualIn, args_.deadline);
        uint256 vaultTokenAmountOut = _executeComposedPoolExitExactInShared(
            selection.exitFromStablePool,
            selection.poolBptToken,
            poolBptAmountOut,
            route.vaultToken,
            args_.deadline
        );
        amountOut_ = _executeUnderlyingExitExactInShared(
            route,
            args_.tokenOut,
            vaultTokenAmountOut,
            args_.recipient == address(0) ? msg.sender : args_.recipient,
            args_.deadline
        );

        if (amountOut_ < args_.minAmountOut) {
            revert SlippageExceeded(args_.minAmountOut, amountOut_);
        }
    }

    /**
     * @param tokenIn The token provided to the vault for an exchange.
     * @param amountIn The amount of `tokenIn` the users wishes to exchange for `tokenOut`.
     * @param tokenOut The token the caller wishes to receive in exchange for `tokenIn`.
     * @param minAmountOut The minimum amount of `tokenOut` the caller is willing to accept.
     * @param recipient The address to receive the `tokenOut` tokens.
     * @param pretransferred Whether the `tokenIn` tokens have already been transferred to the vault.
     * @return amountOut The amount of `tokenOut` the caller has received in exchange for `amountIn` of `tokenIn`.
     * @custom:selector 0x05562cc8
     */
    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }
        if (amountIn == 0) {
            revert ZeroAmount();
        }

        IERC20 detfToken = ComposedStableCommonDetfRepo._detfToken();
        if (address(tokenOut) == address(detfToken) && address(tokenIn) != address(detfToken)) {
            return _executeMintRoute(
                IStandardExchangeIn.InArgs({
                    tokenIn: tokenIn,
                    amountIn: amountIn,
                    tokenOut: tokenOut,
                    minAmountOut: minAmountOut,
                    recipient: recipient,
                    pretransferred: pretransferred,
                    deadline: deadline
                })
            );
        }

        if (address(tokenIn) == address(detfToken) && address(tokenOut) != address(detfToken)) {
            return _executeBurnRoute(
                IStandardExchangeIn.InArgs({
                    tokenIn: tokenIn,
                    amountIn: amountIn,
                    tokenOut: tokenOut,
                    minAmountOut: minAmountOut,
                    recipient: recipient,
                    pretransferred: pretransferred,
                    deadline: deadline
                })
            );
        }

        revert InvalidRoute(address(tokenIn), address(tokenOut));
    }

    function facetName() external pure returns (string memory name_) {
        return type(ComposedStableCommonDetfExchangeIn).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IComposedStableCommonDetfInfo).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](13);
        funcs_[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[2] = IComposedStableCommonDetfInfo.mintThreshold.selector;
        funcs_[3] = IComposedStableCommonDetfInfo.burnThreshold.selector;
        funcs_[4] = IComposedStableCommonDetfInfo.thresholdMode.selector;
        funcs_[5] = IComposedStableCommonDetfInfo.isMintingAllowed.selector;
        funcs_[6] = IComposedStableCommonDetfInfo.isBurningAllowed.selector;
        funcs_[7] = IComposedStableCommonDetfInfo.lastExpansionTimestamp.selector;
        funcs_[8] = IComposedStableCommonDetfInfo.expansionClosureRatePerSecond.selector;
        funcs_[9] = IComposedStableCommonDetfInfo.expansionCatchUpMaxSeconds.selector;
        funcs_[10] = IComposedStableCommonDetfInfo.expansionCatchUpCapBps.selector;
        funcs_[11] = IComposedStableCommonDetfInfo.compoundProtocolRewards.selector;
        funcs_[12] = bytes4(keccak256('compoundProtocolRewardsAtomic()'));
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        name_ = type(ComposedStableCommonDetfExchangeIn).name;

        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IComposedStableCommonDetfInfo).interfaceId;

        functions_ = new bytes4[](13);
        functions_[0] = IStandardExchangeIn.previewExchangeIn.selector;
        functions_[1] = IStandardExchangeIn.exchangeIn.selector;
        functions_[2] = IComposedStableCommonDetfInfo.mintThreshold.selector;
        functions_[3] = IComposedStableCommonDetfInfo.burnThreshold.selector;
        functions_[4] = IComposedStableCommonDetfInfo.thresholdMode.selector;
        functions_[5] = IComposedStableCommonDetfInfo.isMintingAllowed.selector;
        functions_[6] = IComposedStableCommonDetfInfo.isBurningAllowed.selector;
        functions_[7] = IComposedStableCommonDetfInfo.lastExpansionTimestamp.selector;
        functions_[8] = IComposedStableCommonDetfInfo.expansionClosureRatePerSecond.selector;
        functions_[9] = IComposedStableCommonDetfInfo.expansionCatchUpMaxSeconds.selector;
        functions_[10] = IComposedStableCommonDetfInfo.expansionCatchUpCapBps.selector;
        functions_[11] = IComposedStableCommonDetfInfo.compoundProtocolRewards.selector;
        functions_[12] = bytes4(keccak256('compoundProtocolRewardsAtomic()'));
    }
}