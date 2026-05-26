// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {BetterSafeERC20} from '@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol';
import {IProtocolNFTVault} from 'contracts/interfaces/IProtocolNFTVault.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardExchangeProxy} from 'contracts/interfaces/proxies/IStandardExchangeProxy.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfRepo.sol';
import {ComposedStableCommonDetfCommon} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfCommon.sol';

contract ComposedStableCommonDetfExchangeIn is ComposedStableCommonDetfCommon, IStandardExchangeIn, IFacet {
    using BetterSafeERC20 for IERC20;

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

    function _executeUnderlyingVaultRoute(
        ComposedStableCommonDetfRepo.RouteConfig storage route_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 deadline_
    ) internal returns (uint256 vaultTokenOut_) {
        tokenIn_.transfer(address(route_.underlyingVault), amountIn_);
        vaultTokenOut_ = route_.underlyingVault.exchangeIn(
            tokenIn_,
            amountIn_,
            route_.vaultToken,
            0,
            address(this),
            true,
            deadline_
        );
    }

    function _executeComposedPoolRoute(
        ComposedStableCommonDetfRepo.RouteConfig storage route_,
        RoutedPoolSelection memory selection_,
        uint256 vaultTokenOut_,
        uint256 deadline_
    ) internal returns (uint256 poolBptOut_) {
        route_.vaultToken.transfer(address(selection_.poolRouter), vaultTokenOut_);
        poolBptOut_ = selection_.poolRouter.exchangeIn(
            route_.vaultToken,
            vaultTokenOut_,
            selection_.poolBptToken,
            0,
            address(this),
            true,
            deadline_
        );
    }

    function _depositIntoReservePool(
        ComposedStableCommonDetfRepo.Storage storage layoutStruct_,
        RoutedPoolSelection memory selection_,
        uint256 poolBptOut_,
        uint256 deadline_
    ) internal returns (uint256 reservePoolBptOut_) {
        IERC20 reservePoolToken = IERC20(address(ComposedStableCommonDetfRepo._reservePool(layoutStruct_)));
        uint256 balanceBefore = reservePoolToken.balanceOf(address(this));

        selection_.poolBptToken.transfer(
            address(ComposedStableCommonDetfRepo._reservePoolEntryRouter(layoutStruct_)), poolBptOut_
        );
        ComposedStableCommonDetfRepo._reservePoolEntryRouter(layoutStruct_).exchangeIn(
            selection_.poolBptToken,
            poolBptOut_,
            reservePoolToken,
            0,
            address(this),
            true,
            deadline_
        );

        reservePoolBptOut_ = reservePoolToken.balanceOf(address(this)) - balanceBefore;
    }

    function _accrueMintProtocolInventory(
        ComposedStableCommonDetfRepo.Storage storage layoutStruct_,
        uint256 reservePoolBptOut_,
        uint256 protocolDetfOut_
    ) internal {
        IProtocolNFTVault bondNftVault = ComposedStableCommonDetfRepo._bondNftVault(layoutStruct_);
        if (address(bondNftVault) == address(0)) {
            revert ExchangeInNotAvailable();
        }

        if (reservePoolBptOut_ > 0) {
            bondNftVault.addToProtocolNFT(bondNftVault.protocolNFTId(), reservePoolBptOut_);
        }

        if (protocolDetfOut_ > 0) {
            _mintDetf(address(bondNftVault), protocolDetfOut_);
        }
    }

    function _approvePermit2Spend(IERC20 token_, uint256 amount_) internal {
        if (amount_ == 0) {
            return;
        }

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        if (
            address(ComposedStableCommonDetfRepo._permit2(layoutStruct)) == address(0)
                || address(ComposedStableCommonDetfRepo._balancerV3Router(layoutStruct)) == address(0)
        ) {
            revert ExchangeInNotAvailable();
        }

        token_.forceApprove(address(ComposedStableCommonDetfRepo._permit2(layoutStruct)), amount_);
        ComposedStableCommonDetfRepo._permit2(layoutStruct).approve(
            address(token_), address(ComposedStableCommonDetfRepo._balancerV3Router(layoutStruct)), uint160(amount_), type(uint48).max
        );
    }

    function _executeReservePoolSwapExactIn(ExactInUnwindSelection memory selection_, uint256 exactAmountIn_, uint256 deadline_)
        internal
        returns (uint256 poolBptAmountOut_)
    {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        IERC20 detfToken = ComposedStableCommonDetfRepo._detfToken(layoutStruct);

        _approvePermit2Spend(detfToken, exactAmountIn_);

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

    function _executeComposedPoolExitExactIn(
        ComposedStableCommonDetfRepo.RouteConfig storage route_,
        ExactInUnwindSelection memory selection_,
        uint256 poolBptAmountOut_,
        uint256 deadline_
    ) internal returns (uint256 vaultTokenAmountOut_) {
        IStandardExchangeIn poolExitPricer = selection_.exitFromStablePool
            ? ComposedStableCommonDetfRepo._stablePoolExitPricer()
            : ComposedStableCommonDetfRepo._commonPoolExitPricer();

        selection_.poolBptToken.safeTransfer(address(poolExitPricer), poolBptAmountOut_);
        vaultTokenAmountOut_ = poolExitPricer.exchangeIn(
            selection_.poolBptToken,
            poolBptAmountOut_,
            route_.vaultToken,
            0,
            address(this),
            true,
            deadline_
        );
    }

    function _executeUnderlyingExitExactIn(
        ComposedStableCommonDetfRepo.RouteConfig storage route_,
        IERC20 tokenOut_,
        uint256 vaultTokenAmountOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        if (address(route_.vaultToken) == address(tokenOut_)) {
            route_.vaultToken.safeTransfer(recipient_, vaultTokenAmountOut_);
            return vaultTokenAmountOut_;
        }

        route_.vaultToken.transfer(address(route_.underlyingVault), vaultTokenAmountOut_);
        amountOut_ = route_.underlyingVault.exchangeIn(
            route_.vaultToken,
            vaultTokenAmountOut_,
            tokenOut_,
            0,
            recipient_,
            true,
            deadline_
        );
    }

    function _executeMintRoute(IStandardExchangeIn.InArgs memory args_) internal returns (uint256 amountOut_) {
        uint256 syntheticPrice = _syntheticDetfEthPrice();
        if (!_isMintingAllowed(syntheticPrice)) {
            revert MintingNotAllowed(syntheticPrice, ComposedStableCommonDetfRepo._mintThreshold());
        }

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        RoutedPoolSelection memory selection = _selectRoutingPath(args_.tokenIn);
        ComposedStableCommonDetfRepo.RouteConfig storage route = ComposedStableCommonDetfRepo._routeAt(
            layoutStruct, selection.routeIndex
        );

        uint256 actualIn = _secureTokenTransfer(args_.tokenIn, args_.amountIn, args_.pretransferred);
        uint256 vaultTokenOut = _executeUnderlyingVaultRoute(route, args_.tokenIn, actualIn, args_.deadline);
        uint256 poolBptOut = _executeComposedPoolRoute(route, selection, vaultTokenOut, args_.deadline);

        MintSplit memory mintSplit = _previewMintSplit(poolBptOut, selection.depositToStablePool);

        amountOut_ = mintSplit.userDetfOut;
        if (amountOut_ < args_.minAmountOut) {
            revert SlippageExceeded(args_.minAmountOut, amountOut_);
        }

        uint256 reservePoolBptOut = _depositIntoReservePool(layoutStruct, selection, poolBptOut, args_.deadline);

        _accrueMintProtocolInventory(layoutStruct, reservePoolBptOut, mintSplit.protocolDetfOut);
        _mintDetf(args_.recipient == address(0) ? msg.sender : args_.recipient, amountOut_);
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
        uint256 vaultTokenAmountOut = _executeComposedPoolExitExactIn(route, selection, poolBptAmountOut, args_.deadline);
        amountOut_ = _executeUnderlyingExitExactIn(
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
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](2);
        funcs_[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.exchangeIn.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        name_ = type(ComposedStableCommonDetfExchangeIn).name;

        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;

        functions_ = new bytes4[](2);
        functions_[0] = IStandardExchangeIn.previewExchangeIn.selector;
        functions_[1] = IStandardExchangeIn.exchangeIn.selector;
    }
}