// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ReentrancyLockModifiers} from '@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol';
import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {BetterSafeERC20} from '@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol';

import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {IDetf} from 'contracts/interfaces/detf/IDetf.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {IStandardExchangeProxy} from 'contracts/interfaces/proxies/IStandardExchangeProxy.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol';
import {ComposedStableCommonDetfCommon} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol';

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

    function claimLiquidity(uint256 lpAmount, address recipient) external nonReentrant returns (uint256 extractedRateAsset) {
        if (lpAmount == 0) {
            revert ZeroAmount();
        }

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        if (
            msg.sender != address(this)
                && msg.sender != address(ComposedStableCommonDetfRepo._bondNftVault(layoutStruct))
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

        address payoutRecipient = recipient == address(0) ? msg.sender : recipient;
        extractedRateAsset = _exitRedepositSettle(
            lpAmount,
            ComposedStableCommonDetfRepo._rateAsset(layoutStruct),
            0,
            payoutRecipient,
            block.timestamp
        );
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

        if (address(ComposedStableCommonDetfRepo._balancerV3Router()) == address(0)) {
            revert ExchangeOutNotAvailable();
        }
        uint256 depositedIn = _secureTokenTransfer(args_.tokenIn, args_.maxAmountIn, args_.pretransferred);
        amountIn_ = selection.detfAmountIn;
        if (amountIn_ > depositedIn) {
            revert SlippageExceeded(args_.maxAmountIn, amountIn_);
        }
        uint256 bptIn_ = _bptForDetfShares(amountIn_);
        if (bptIn_ == 0) revert ZeroAmount();
        _burnDetf(address(this), amountIn_);

        ComposedStableCommonDetfRepo.Storage storage layoutStruct = ComposedStableCommonDetfRepo._layoutStruct();
        ComposedStableCommonDetfRepo.RouteConfig storage route = ComposedStableCommonDetfRepo._routeAt(
            layoutStruct, selection.routeIndex
        );

        (uint256 detfLeg_,,) = _exitReserveProportional(bptIn_);
        _redepositDetfSelfLeg(detfLeg_);

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

        // Outermost exact-out: re-forward unused *caller-paid* input to entry msg.sender
        // (L-DETF-REFUND-OUTER / L-DETF-REFUND-SCOPE). Prior residual detf on the diamond is
        // not part of this refund; it is absorbed into R at end-sync (L-RSRV-ABSORB).
        // Do not require remainingIn == refund — residual inventory is expected after partial
        // routes / dust retention.
        uint256 refundFromReturn = depositedIn > amountIn_ ? depositedIn - amountIn_ : 0;
        if (refundFromReturn > 0) {
            uint256 remainingIn = args_.tokenIn.balanceOf(address(this));
            if (remainingIn < refundFromReturn) {
                revert SlippageExceeded(refundFromReturn, remainingIn);
            }
            args_.tokenIn.safeTransfer(msg.sender, refundFromReturn);
        }
        _syncAllExpectedHoldReserves();
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountIn) {
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
        funcs_[2] = IDetf.previewClaimLiquidity.selector;
        funcs_[3] = IDetf.claimLiquidity.selector;
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
        functions_[2] = IDetf.previewClaimLiquidity.selector;
        functions_[3] = IDetf.claimLiquidity.selector;
    }
}