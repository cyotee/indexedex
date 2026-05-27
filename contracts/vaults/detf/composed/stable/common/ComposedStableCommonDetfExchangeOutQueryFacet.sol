// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ReentrancyLockModifiers} from '@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol';
import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IERC20MintBurn} from '@crane/contracts/interfaces/IERC20MintBurn.sol';
import {BetterSafeERC20} from '@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol';

import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {IProtocolDETF} from 'contracts/interfaces/IProtocolDETF.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {IStandardExchangeProxy} from 'contracts/interfaces/proxies/IStandardExchangeProxy.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfRepo.sol';
import {ComposedStableCommonDetfCommon} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfCommon.sol';

contract ComposedStableCommonDetfExchangeOutQueryFacet is
    ComposedStableCommonDetfCommon,
    ReentrancyLockModifiers,
    IStandardExchangeOut,
    IFacet
{
    using BetterSafeERC20 for IERC20;

    function previewClaimLiquidity(uint256 lpAmount) external view returns (uint256 wethOut) {
        if (lpAmount == 0) {
            return 0;
        }

        _requireReservePoolInitialized();

        (, uint256 stablePoolBptAmount, uint256 commonPoolBptAmount) =
            IDETF(address(this)).previewReservePoolDecomposition(lpAmount);

        if (stablePoolBptAmount != 0) {
            wethOut += IDETF(address(this)).previewStablePoolBptEthValue(stablePoolBptAmount);
        }
        if (commonPoolBptAmount != 0) {
            wethOut += IDETF(address(this)).previewCommonPoolBptEthValue(commonPoolBptAmount);
        }

        if (wethOut != 0) {
            wethOut -= wethOut / 100000;
        }
    }

    function claimLiquidity(uint256 lpAmount, address recipient) external lock returns (uint256 extractedWeth) {
        if (lpAmount == 0) {
            revert ZeroAmount();
        }

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        if (
            msg.sender != address(ComposedStableCommonDetfRepo._bondNftVault(layoutStruct))
                && msg.sender != address(ComposedStableCommonDetfRepo._rebasingDetfToken(layoutStruct))
        ) {
            revert NotAuthorized(msg.sender);
        }

        _requireReservePoolInitialized();

        IERC20 reservePoolToken = IERC20(address(ComposedStableCommonDetfRepo._reservePool(layoutStruct)));
        uint256 availableLp = reservePoolToken.balanceOf(address(this));
        if (availableLp < lpAmount) {
            revert InsufficientBalance(lpAmount, availableLp);
        }

        reservePoolToken.forceApprove(address(ComposedStableCommonDetfRepo._balancerV3Router(layoutStruct)), lpAmount);

        uint256[] memory minAmountsOut = new uint256[](3);
        uint256[] memory amountsOut = ComposedStableCommonDetfRepo._balancerV3Router(layoutStruct).prepayRemoveLiquidityProportional(
            address(ComposedStableCommonDetfRepo._reservePool(layoutStruct)), lpAmount, minAmountsOut, ''
        );

        uint256 detfAmount = amountsOut[ComposedStableCommonDetfRepo._detfIndex(layoutStruct)];
        uint256 stablePoolBptAmount = amountsOut[ComposedStableCommonDetfRepo._stablePoolBptIndex(layoutStruct)];
        uint256 commonPoolBptAmount = amountsOut[ComposedStableCommonDetfRepo._commonPoolBptIndex(layoutStruct)];

        if (detfAmount != 0) {
            IERC20MintBurn(address(ComposedStableCommonDetfRepo._detfToken(layoutStruct))).burn(address(this), detfAmount);
        }

        address payoutRecipient = recipient == address(0) ? msg.sender : recipient;
        if (stablePoolBptAmount != 0) {
            IERC20 stablePoolBpt = ComposedStableCommonDetfRepo._stablePoolBpt(layoutStruct);
            stablePoolBpt.forceApprove(address(ComposedStableCommonDetfRepo._stablePoolExitPricer(layoutStruct)), stablePoolBptAmount);
            extractedWeth += ComposedStableCommonDetfRepo._stablePoolExitPricer(layoutStruct).exchangeIn(
                stablePoolBpt,
                stablePoolBptAmount,
                ComposedStableCommonDetfRepo._wethToken(layoutStruct),
                0,
                payoutRecipient,
                false,
                block.timestamp
            );
        }

        if (commonPoolBptAmount != 0) {
            IERC20 commonPoolBpt = ComposedStableCommonDetfRepo._commonPoolBpt(layoutStruct);
            commonPoolBpt.forceApprove(address(ComposedStableCommonDetfRepo._commonPoolExitPricer(layoutStruct)), commonPoolBptAmount);
            extractedWeth += ComposedStableCommonDetfRepo._commonPoolExitPricer(layoutStruct).exchangeIn(
                commonPoolBpt,
                commonPoolBptAmount,
                ComposedStableCommonDetfRepo._wethToken(layoutStruct),
                0,
                payoutRecipient,
                false,
                block.timestamp
            );
        }
    }

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        if (amountOut == 0) {
            return 0;
        }

        _requireReservePoolInitialized();

        if (address(tokenIn) != address(ComposedStableCommonDetfRepo._detfToken())) {
            revert InvalidToken(tokenIn);
        }

        uint256 syntheticPrice = _syntheticDetfEthPrice();
        if (!_isBurningAllowed(syntheticPrice)) {
            revert BurningNotAllowed(syntheticPrice, ComposedStableCommonDetfRepo._burnThreshold());
        }

        amountIn = _previewMostLiquidUnwindSelection(tokenOut, amountOut).detfAmountIn;
    }

    function _executeReservePoolSwap(UnwindPreviewSelection memory selection_, uint256 maxAmountIn_, uint256 deadline_)
        internal
        returns (uint256 detfAmountIn_)
    {
        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        IERC20 detfToken = ComposedStableCommonDetfRepo._detfToken(layoutStruct);

        _approvePermit2Spend(detfToken, maxAmountIn_, true);

        detfAmountIn_ = ComposedStableCommonDetfRepo._balancerV3Router(layoutStruct).swapSingleTokenExactOut(
            address(ComposedStableCommonDetfRepo._reservePool(layoutStruct)),
            detfToken,
            IStandardExchangeProxy(address(0)),
            selection_.poolBptToken,
            IStandardExchangeProxy(address(0)),
            selection_.poolBptAmountOut,
            maxAmountIn_,
            deadline_,
            false,
            ''
        );
    }

    function _executeExchangeOut(IStandardExchangeOut.OutArgs memory args_) internal returns (uint256 amountIn_) {
        _requireReservePoolInitialized();

        uint256 syntheticPrice = _syntheticDetfEthPrice();
        if (!_isBurningAllowed(syntheticPrice)) {
            revert BurningNotAllowed(syntheticPrice, ComposedStableCommonDetfRepo._burnThreshold());
        }

        UnwindPreviewSelection memory selection = _previewMostLiquidUnwindSelection(args_.tokenOut, args_.amountOut);
        if (selection.detfAmountIn > args_.maxAmountIn) {
            revert SlippageExceeded(args_.maxAmountIn, selection.detfAmountIn);
        }

        uint256 depositedIn = _secureTokenTransfer(args_.tokenIn, args_.maxAmountIn, args_.pretransferred);
        amountIn_ = _executeReservePoolSwap(selection, depositedIn, args_.deadline);
        if (amountIn_ > args_.maxAmountIn) {
            revert SlippageExceeded(args_.maxAmountIn, amountIn_);
        }

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        ComposedStableCommonDetfRepo.RouteConfig storage route = ComposedStableCommonDetfRepo._routeAt(
            layoutStruct, selection.routeIndex
        );

        _executeComposedPoolExitExactOutShared(
            selection.exitFromStablePool,
            selection.poolBptToken,
            selection.poolBptAmountOut,
            route.vaultToken,
            selection.vaultTokenAmountOut,
            args_.deadline
        );
        _executeUnderlyingExitExactOutShared(
            route,
            args_.tokenOut,
            args_.amountOut,
            args_.recipient == address(0) ? msg.sender : args_.recipient,
            args_.deadline
        );

        if (depositedIn > amountIn_) {
            args_.tokenIn.safeTransfer(msg.sender, depositedIn - amountIn_);
        }
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external lock returns (uint256 amountIn) {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }
        if (amountOut == 0) {
            revert ZeroAmount();
        }
        if (address(tokenIn) != address(ComposedStableCommonDetfRepo._detfToken())) {
            revert InvalidToken(tokenIn);
        }

        amountIn = _executeExchangeOut(
            IStandardExchangeOut.OutArgs({
                tokenIn: tokenIn,
                maxAmountIn: maxAmountIn,
                tokenOut: tokenOut,
                amountOut: amountOut,
                recipient: recipient,
                pretransferred: pretransferred,
                deadline: deadline
            })
        );
    }

    function facetName() external pure returns (string memory name_) {
        return type(ComposedStableCommonDetfExchangeOutQueryFacet).name;
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeOut).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](4);
        funcs_[0] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs_[1] = IStandardExchangeOut.exchangeOut.selector;
        funcs_[2] = IProtocolDETF.previewClaimLiquidity.selector;
        funcs_[3] = IProtocolDETF.claimLiquidity.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory functions_)
    {
        name_ = type(ComposedStableCommonDetfExchangeOutQueryFacet).name;

        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IStandardExchangeOut).interfaceId;

        functions_ = new bytes4[](4);
        functions_[0] = IStandardExchangeOut.previewExchangeOut.selector;
        functions_[1] = IStandardExchangeOut.exchangeOut.selector;
        functions_[2] = IProtocolDETF.previewClaimLiquidity.selector;
        functions_[3] = IProtocolDETF.claimLiquidity.selector;
    }
}