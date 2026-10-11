// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookExitTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookExitTarget.sol";

contract UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet is
    UniswapV4StandardExchangeCurveQuadStableBufferHookExitTarget,
    IFacet
{
    address private immutable NATIVE_SY_SELF = address(this);
    error DelegateCallRequired();

    /// @dev Not installed on the proxy. The native SY facet retains authorization and its lock.
    function executeVaultHeldRedemption(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        external returns (uint256 amount_)
    {
        if (address(this) == NATIVE_SY_SELF) revert DelegateCallRequired();
        Repo.Layout storage l_ = Repo._layout();
        bool asShare_ = LegLib.classify(l_.legs, tokenOut_) == LegLib.LegKind.StandardExchange;
        address pair_ = asShare_ ? l_.legs.pairOfStandardExchange[tokenOut_] : tokenOut_;
        return _exitSingleAssetFrom(address(this), pair_, shares_, asShare_, receiver_, minimum_);
    }

    function facetName() public pure returns (string memory) {
        return type(UniswapV4StandardExchangeCurveQuadStableBufferHookExitFacet).name;
    }
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) { interfaces = new bytes4[](0); }
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](19);
        funcs[0] = IUniswapV4SeBufferHook.previewExitProportional.selector;
        funcs[1] = IUniswapV4SeBufferHook.exitProportional.selector;
        funcs[2] = IUniswapV4SeBufferHook.previewExitSingleAssetExactBptIn.selector;
        funcs[3] = IUniswapV4SeBufferHook.exitSingleAssetExactBptIn.selector;
        funcs[4] = IUniswapV4SeBufferHook.previewExitSingleAssetExactTokenOut.selector;
        funcs[5] = IUniswapV4SeBufferHook.exitSingleAssetExactTokenOut.selector;
        funcs[6] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewWithdrawSingle.selector;
        funcs[7] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.withdrawSingle.selector;
        funcs[8] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewWithdrawSingleExactOut.selector;
        funcs[9] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.withdrawSingleExactOut.selector;
        funcs[10] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewExitProportionalFlexible.selector;
        funcs[11] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.exitProportionalFlexible.selector;
        funcs[12] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewExitSingleAssetExactBptInFlexible.selector;
        funcs[13] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.exitSingleAssetExactBptInFlexible.selector;
        funcs[14] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.previewWithdrawSingleFlexible.selector;
        funcs[15] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.withdrawSingleFlexible.selector;
        funcs[16] = IDetfReserveQuote.previewBurnToToken.selector;
        funcs[17] = IUniswapV4StandardExchangeCurveQuadStableBufferHook.rateProviders.selector; // D60
        funcs[18] = bytes4(keccak256("rateProvider(address)")); // D60
    }
    function facetMetadata() external pure returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions) {
        name_ = facetName(); interfaces = facetInterfaces(); functions = facetFuncs();
    }
}
