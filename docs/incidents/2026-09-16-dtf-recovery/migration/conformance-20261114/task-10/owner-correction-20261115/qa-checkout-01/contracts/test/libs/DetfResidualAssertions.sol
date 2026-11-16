// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IUniswapV4SeBufferHook, IUniswapV4SeBufferHookNativeLiquidity} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";

/// @notice R19 permits only booked capital below the host's actual join minimum.
/// @dev No fixed native-unit tolerance: check single routes and complete residual baskets.
library DetfResidualAssertions {
    struct Choices {
        address[] pairInputs;
        address[] shareInputs;
        uint256[] pairAmounts;
        uint256[] shareAmounts;
        uint256[] bits;
        uint256[] nativeLocal;
        uint256[] nativeShares;
        uint256 count;
        uint256 fundedLegs;
    }

    error RetainedHookLp(uint256 amount);
    error JoinableResidual(address token, uint256 amount, uint256 quotedLp, bytes4 route);
    error UnbookedResidual(address token, uint256 held, uint256 booked);
    error JoinableResidualBasket(uint256 shareChoiceMask, uint256 quotedLp);
    error JoinableNativeResidualBasket(uint256 quotedLp);
    error HookPairClaimMismatch(address pair, uint256 quoted, uint256 heldClaim);
    error UnconsumedClaimShares(address se, uint256 shares);

    /// @notice Local pair inventory is backing, not dust that must be rebuffered.
    /// @dev These lifecycle fixtures have no ambient hook donations. Reconcile
    /// the full remaining LP claim with actual local cash and held SE shares.
    function assertHookPairClaim(address hook, uint256 index) internal view {
        address[] memory tokens = IUniswapV4SeBufferHook(hook).tokens();
        uint256[] memory claims = IUniswapV4SeBufferHook(hook).previewExitProportional(IERC20(hook).totalSupply());
        address pair = tokens[index];
        uint256 heldClaim = IERC20(pair).balanceOf(hook);
        address se = IUniswapV4SeBufferHook(hook).standardExchangeOf(pair);
        if (se != address(0)) {
            uint256 shares = IERC20(se).balanceOf(hook);
            if (shares != 0) {
                (uint256 assets, uint256 refunded) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), shares, IERC20(pair));
                if (refunded != 0) revert UnconsumedClaimShares(se, refunded);
                heldClaim += assets;
            }
        }
        if (claims[index] != heldClaim) revert HookPairClaimMismatch(pair, claims[index], heldClaim);
    }

    function assertNoJoinableDust(address detf, address hook) internal view {
        uint256 lp = IERC20(hook).balanceOf(detf);
        if (lp != 0) revert RetainedHookLp(lp);
        address[] memory pairs = IUniswapV4SeBufferHook(hook).tokens();
        Choices memory c;
        c.pairInputs = new address[](pairs.length);
        c.shareInputs = new address[](pairs.length);
        c.pairAmounts = new uint256[](pairs.length);
        c.shareAmounts = new uint256[](pairs.length);
        c.bits = new uint256[](pairs.length);
        c.nativeLocal = new uint256[](pairs.length);
        c.nativeShares = new uint256[](pairs.length);
        for (uint256 i; i < pairs.length; ++i) {
            uint256 pairAmount = IERC20(pairs[i]).balanceOf(detf);
            if (pairAmount != 0) _assertToken(detf, hook, pairs[i], pairAmount);
            address se = IUniswapV4SeBufferHook(hook).standardExchangeOf(pairs[i]);
            uint256 shares = se == address(0) ? 0 : IERC20(se).balanceOf(detf);
            if (shares != 0) _assertToken(detf, hook, se, shares);
            c.nativeLocal[i] = pairAmount;
            c.nativeShares[i] = shares;
            c.pairInputs[i] = pairAmount != 0 || shares == 0 ? pairs[i] : se;
            c.pairAmounts[i] = pairAmount != 0 || shares == 0 ? pairAmount : shares;
            c.shareInputs[i] = shares != 0 ? se : pairs[i];
            c.shareAmounts[i] = shares != 0 ? shares : pairAmount;
            if (pairAmount != 0 || shares != 0) ++c.fundedLegs;
            if (pairAmount != 0 && shares != 0) c.bits[i] = uint256(1) << c.count++;
        }
        if (c.fundedLegs != 0
            && IERC165(hook).supportsInterface(type(IUniswapV4SeBufferHookNativeLiquidity).interfaceId)) {
            uint256 quoted = IUniswapV4SeBufferHookNativeLiquidity(hook).previewJoinNativeComponents(
                c.nativeLocal, c.nativeShares
            );
            if (quoted != 0) revert JoinableNativeResidualBasket(quoted);
        }
        if (c.fundedLegs < 2) return;
        address[] memory inputs = new address[](c.fundedLegs);
        uint256[] memory amounts = new uint256[](c.fundedLegs);
        for (uint256 mask; mask < (uint256(1) << c.count); ++mask) {
            uint256 next;
            for (uint256 i; i < pairs.length; ++i) {
                if (c.pairAmounts[i] == 0 && c.shareAmounts[i] == 0) continue;
                bool share = (mask & c.bits[i]) != 0;
                inputs[next] = share ? c.shareInputs[i] : c.pairInputs[i];
                amounts[next++] = share ? c.shareAmounts[i] : c.pairAmounts[i];
            }
            uint256 quoted = IUniswapV4SeBufferHook(hook).previewJoinUnbalanced(inputs, amounts);
            if (quoted != 0) revert JoinableResidualBasket(mask, quoted);
        }
    }

    function _assertToken(address detf, address hook, address token, uint256 held) private view {
        uint256 quoted = IDetfReserveDonation(detf).previewJoinDonatedCapital(IERC20(token), held);
        if (quoted != 0) {
            revert JoinableResidual(token, held, quoted, IDetfReserveDonation.previewJoinDonatedCapital.selector);
        }
        address[] memory inputs = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        inputs[0] = token;
        amounts[0] = held;
        quoted = IUniswapV4SeBufferHook(hook).previewJoinUnbalanced(inputs, amounts);
        if (quoted != 0) revert JoinableResidual(token, held, quoted, IUniswapV4SeBufferHook.previewJoinUnbalanced.selector);
        uint256 booked = IBasicVault(detf).reserveOfToken(token);
        if (booked != held) revert UnbookedResidual(token, held, booked);
    }
}
