// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRouter} from "@crane/contracts/protocols/dexes/aerodrome/v1/interfaces/IRouter.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";

/// @notice Trade underlying Aerodrome pool + seigniorage mint to open mint/burn under **default** thresholds.
/// @dev Synthetic ≈ (owned DETF leg + owned shares·rate) / DETF supply. Bootstrap is often ~1.25e18.
///      Free seigniorage mint (join shares only) dilutes supply so synthetic can fall below burnThreshold.
contract MultiVaultWeightedDetf_PriceShift_Test is TestBase_MultiVaultWeightedDetf {
    function test_defaultThresholds_deadband_afterLive() public {
        _goLiveViaBptBond(detf, alice, 2_000e18);
        uint256 synth_ = detfInfo.syntheticPrice();
        assertEq(detfInfo.isMintingAllowed(), synth_ > detfInfo.mintThreshold(), "mint gate coupling");
        assertEq(detfInfo.isBurningAllowed(), synth_ < detfInfo.burnThreshold(), "burn gate coupling");
    }

    function _swapUnderlying(address tokenIn, address tokenOut, uint256 amount, address trader) internal {
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: tokenIn,
            to: tokenOut,
            stable: false,
            factory: address(aerodromePoolFactory)
        });
        vm.startPrank(trader);
        IERC20(tokenIn).approve(address(aerodromeRouter), amount);
        aerodromeRouter.swapExactTokensForTokens(amount, 0, routes, trader, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    /// @dev Raise vault-share rate (dai→usdc into underlying LP pool: LP becomes dai-heavy, share→dai richer).
    function _skewSyntheticUp(address trader, uint256 swapAmt_) internal {
        dai.mint(trader, swapAmt_);
        _swapUnderlying(address(dai), address(usdc), swapAmt_, trader);
    }

    /// @dev Lower vault-share rate (usdc→dai: LP becomes usdc-heavy, share→dai poorer).
    function _skewSyntheticDown(address trader, uint256 swapAmt_) internal {
        usdc.mint(trader, swapAmt_);
        _swapUnderlying(address(usdc), address(dai), swapAmt_, trader);
    }

    function _mintVaultShareToDetf(address user, uint256 lpAmount)
        internal
        returns (uint256 out_)
    {
        uint256 seShares_ = _fundSeShares0(user, lpAmount);
        uint256 preview_ = detfExchangeIn.previewExchangeIn(seShare0, seShares_, IERC20(detf));
        vm.startPrank(user);
        seShare0.approve(detf, seShares_);
        out_ = detfExchangeIn.exchangeIn(
            seShare0, seShares_, IERC20(detf), 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(preview_, out_, "mint preview==exec (default thresholds)");
    }

    function _burnDetfToVaultShare(address user, uint256 burnAmt)
        internal
        returns (uint256 out_)
    {
        uint256 preview_ = detfExchangeIn.previewExchangeIn(IERC20(detf), burnAmt, seShare0);
        vm.startPrank(user);
        IERC20(detf).approve(detf, burnAmt);
        out_ = detfExchangeIn.exchangeIn(
            IERC20(detf), burnAmt, seShare0, 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        // Multi-leg proportional exit uses Balancer vault math; closed-form muldiv preview can
        // differ by a few wei from router amountsOut (not binary-search; same order of magnitude).
        assertApproxEqAbs(preview_, out_, 10, "burn preview~=exec under default thresholds (le 10 wei)");
    }

    /// @notice Required: open mint then open burn under default 1.05/0.95 gates via real underlying trades + dilution.
    function test_underlyingSwap_opensMintAndBurn_underDefaultThresholds() public {
        _goLiveViaBptBond(detf, alice, 2_000e18);
        uint256 synth0_ = detfInfo.syntheticPrice();
        emit log_named_uint("synth_after_live", synth0_);

        // --- Mint regime (synthetic > mintThreshold) ---
        // Bootstrap synthetic is often already ~1.25e18 (> 1.05). If not, skew rate up.
        for (uint256 i; i < 8 && !detfInfo.isMintingAllowed(); ++i) {
            _skewSyntheticUp(alice, 20_000e18 * (i + 1));
            emit log_named_uint("synth_mint_skew", detfInfo.syntheticPrice());
        }
        assertTrue(detfInfo.isMintingAllowed(), "mint must open under default thresholds after skew");

        // Bob mints (holder for burn path - alice has no free DETF after BPT-only bond).
        uint256 mintOut_ = _mintVaultShareToDetf(bob, 300e18);
        assertTrue(mintOut_ > 0, "bob minted detf");
        assertTrue(IERC20(detf).balanceOf(bob) >= mintOut_, "bob holds detf");

        // Additional dilution mints while mint still open (free DETF supply without matching DETF leg join).
        for (uint256 j; j < 3 && detfInfo.isMintingAllowed(); ++j) {
            _mintVaultShareToDetf(bob, 200e18);
        }
        emit log_named_uint("synth_after_mints", detfInfo.syntheticPrice());

        // --- Burn regime (synthetic < burnThreshold) ---
        // Crash underlying rate + further dilution until burn opens.
        for (uint256 k; k < 15 && !detfInfo.isBurningAllowed(); ++k) {
            _skewSyntheticDown(alice, 80_000e18 * (k + 1));
            // If mint re-opens after rate moves, dilute more free DETF.
            if (detfInfo.isMintingAllowed()) {
                _mintVaultShareToDetf(bob, 150e18);
            }
            emit log_named_uint("synth_burn_skew", detfInfo.syntheticPrice());
        }

        uint256 synthBurn_ = detfInfo.syntheticPrice();
        emit log_named_uint("synth_for_burn", synthBurn_);
        assertTrue(
            detfInfo.isBurningAllowed(),
            "burn must open under default thresholds after opposite skew + dilution"
        );
        assertTrue(synthBurn_ < detfInfo.burnThreshold(), "synthetic below burnThreshold");

        uint256 bobBal_ = IERC20(detf).balanceOf(bob);
        assertTrue(bobBal_ > 0, "bob still holds detf to burn");
        uint256 burnAmt_ = bobBal_ / 2;
        if (burnAmt_ == 0) burnAmt_ = bobBal_;

        uint256 burnOut_ = _burnDetfToVaultShare(bob, burnAmt_);
        assertTrue(burnOut_ > 0, "burn returned vault shares");
        _assertNoFreeInventory(detf);
    }
}
