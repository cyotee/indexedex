// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib
 * @notice SE buffer / unwrap + claim / rate helpers (external lib keeps diamond under EIP-170).
 * @dev Buffer uses exchangeIn(pair→SE); unwrap uses exchangeIn(SE→pair) with exchangeOut fallback.
 *      High-level library calls use DELEGATECALL so address(this) remains the hook.
 */
library UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib {
    using SafeERC20 for IERC20;

    error BufferFailed();
    error UnwrapFailed();
    error RateProviderFailed();
    error SeInvertUnavailable();

    function getRateFailClosed(address rp) external view returns (uint256 rate) {
        if (rp == address(0)) return 0;
        (bool ok, bytes memory data) =
            rp.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || data.length < 32) revert RateProviderFailed();
        rate = abi.decode(data, (uint256));
        if (rate == 0) revert RateProviderFailed();
    }

    function seClaimOf(address se, address pairToken, uint256 seAmount) external view returns (uint256) {
        if (seAmount == 0 || se == address(0)) return 0;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
    }

    function previewBufferShares(address se, address pairToken, uint256 amountInRaw)
        external
        view
        returns (uint256 sharesOut)
    {
        if (amountInRaw == 0 || se == address(0)) return 0;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
    }

    function previewUnwrap(address se, address pairToken, uint256 seAmount)
        external
        view
        returns (uint256 amountOut)
    {
        if (seAmount == 0 || se == address(0)) return 0;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
    }

    function invertUnwrapExactTokenOut(address se, address pairToken, uint256 amountOutNative)
        external
        view
        returns (uint256 sharesIn)
    {
        if (amountOutNative == 0) return 0;
        try IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(pairToken), amountOutNative)
        returns (uint256 seIn) {
            return seIn;
        } catch {
            revert SeInvertUnavailable();
        }
    }

    function invertBufferExactSharesOut(address se, address pairToken, uint256 sharesOut)
        external
        view
        returns (uint256 amountInRaw)
    {
        if (sharesOut == 0) return 0;
        try IStandardExchangeOut(se).previewExchangeOut(IERC20(pairToken), IERC20(se), sharesOut)
        returns (uint256 pairIn) {
            return pairIn;
        } catch {
            revert SeInvertUnavailable();
        }
    }

    function buffer(address se, address pairToken, uint256 amountInRaw) external returns (uint256 sharesOut) {
        if (amountInRaw == 0) return 0;
        uint256 minOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
        if (minOut == 0) revert BufferFailed();
        IERC20(pairToken).forceApprove(se, amountInRaw);
        uint256 balBefore = IERC20(se).balanceOf(address(this));
        sharesOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(pairToken),
            amountInRaw,
            IERC20(se),
            minOut,
            address(this),
            false,
            block.timestamp
        );
        uint256 delta = IERC20(se).balanceOf(address(this)) - balBefore;
        if (delta > sharesOut) sharesOut = delta;
        if (sharesOut < minOut) revert BufferFailed();
    }

    function unwrap(address se, address pairToken, uint256 seAmount, address to)
        external
        returns (uint256 amountOut)
    {
        if (seAmount == 0) return 0;
        uint256 minOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
        if (minOut == 0) revert UnwrapFailed();
        IERC20(se).forceApprove(se, seAmount);
        amountOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(se), seAmount, IERC20(pairToken), minOut, to, false, block.timestamp
        );
        if (amountOut < minOut) revert UnwrapFailed();
    }

    function unwrapExactTokenOut(address se, address pairToken, uint256 amountOut, address to)
        external
        returns (uint256 seIn)
    {
        if (amountOut == 0) return 0;
        seIn = IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(pairToken), amountOut);
        IERC20(se).forceApprove(se, seIn);
        uint256 got = IStandardExchangeOut(se).exchangeOut(
            IERC20(se), seIn, IERC20(pairToken), amountOut, to, false, block.timestamp
        );
        if (got < amountOut) revert UnwrapFailed();
    }

    function previewBufferClaimIn(address se, address pairToken, uint256 amountInRaw, address hook)
        external
        view
        returns (uint256)
    {
        if (amountInRaw == 0 || se == address(0)) return 0;
        uint256 sharesOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
        if (sharesOut == 0) return 0;
        uint256 seBalBefore = IERC20(se).balanceOf(hook);
        uint256 claimBefore = seBalBefore == 0
            ? 0
            : IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBalBefore, IERC20(pairToken));
        uint256 claimAfter =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBalBefore + sharesOut, IERC20(pairToken));
        return claimAfter > claimBefore ? claimAfter - claimBefore : 0;
    }
}
