// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @notice Phase 6.3: default Policy thresholds — drive synthetic via real reserve depth + dilution.
/// @dev Mint-allowed and burn-allowed must both be proven under Policy (not Open-only).
contract UniswapV4SingleStandardExchangeDETF_PriceMovementTest is TestBase_UniswapV4SingleStandardExchangeDETF {
    address internal constant EXTERNAL_LP = address(0xBEEF);

    /// @dev Raise synthetic without minting free DETF: single-sided pair deposit into protocol LP holder.
    function _skewSyntheticUp(address d, uint256 pairAmt) internal {
        IUniswapV4SingleStandardExchangeDETF info = IUniswapV4SingleStandardExchangeDETF(d);
        address hook = info.reserveHook();
        address claim = info.rebasingClaimToken();
        address lpTo = claim == address(0) ? d : claim;
        pairToken.mint(detfUser, pairAmt);
        vm.startPrank(detfUser);
        pairToken.approve(hook, type(uint256).max);
        IHook(hook).depositSingle(address(pairToken), pairAmt, lpTo, 0, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    /// @dev Dilute synthetic: ungated live bond free seigniorage legs increase supply.
    function _diluteViaBond(address d, uint256 pairAmt) internal {
        pairToken.mint(detfUser, pairAmt * 2);
        vm.startPrank(detfUser);
        pairToken.approve(d, type(uint256).max);
        IUniswapV4SingleStandardExchangeDETF(d).bond(
            IERC20(address(pairToken)),
            pairAmt,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /// @dev Skew pool DETF-heavy: single-sided DETF deposit to external LP (not counted in FD).
    ///      Reduces pair claim of owned protocol/bond LP → synthetic falls.
    function _skewSyntheticDownViaDetfDeposit(address d, uint256 detfAmt) internal {
        if (detfAmt == 0) return;
        address hook = IUniswapV4SingleStandardExchangeDETF(d).reserveHook();
        uint256 bal = IERC20(d).balanceOf(detfUser);
        if (bal < detfAmt) detfAmt = bal;
        if (detfAmt == 0) return;
        vm.startPrank(detfUser);
        IERC20(d).approve(hook, detfAmt);
        try IHook(hook).depositSingle(d, detfAmt, EXTERNAL_LP, 0, block.timestamp + 1 hours) returns (uint256) {}
        catch {}
        vm.stopPrank();
    }

    function _tryMint(address d, uint256 pairAmt) internal {
        pairToken.mint(detfUser, pairAmt);
        vm.startPrank(detfUser);
        pairToken.approve(d, type(uint256).max);
        try IStandardExchangeIn(d).exchangeIn(
            IERC20(address(pairToken)), pairAmt, IERC20(d), 0, detfUser, false, block.timestamp + 1 hours
        ) {} catch {}
        vm.stopPrank();
    }

    function test_policy_defaultThresholds_mintAndBurnRegimes_viaRealTrades() public {
        // Policy defaults (mint 1.05 / burn 0.95)
        address d = _deployDetfWired(_policyArgsUnique("pm"));
        IUniswapV4SingleStandardExchangeDETF info = IUniswapV4SingleStandardExchangeDETF(d);
        assertEq(uint8(info.thresholdMode()), uint8(ThresholdMode.Policy));
        assertEq(info.mintThreshold(), 1.05e18);
        assertEq(info.burnThreshold(), 0.95e18);

        pairToken.mint(detfUser, 20_000_000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(d, type(uint256).max);
        // First bond at creation rate 1:1 — free legs dilute synthetic below mint threshold typically.
        info.bond(
            IERC20(address(pairToken)),
            500 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(info.isReserveLive());

        uint256 synth0 = info.syntheticPrice();
        emit log_named_uint("synth_after_first_bond", synth0);
        assertEq(info.isMintingAllowed(), synth0 > info.mintThreshold(), "mint gate coupling");
        assertEq(info.isBurningAllowed(), synth0 < info.burnThreshold(), "burn gate coupling");

        // --- Mint regime (synthetic > mintThreshold) under Policy ---
        // Small steps so we do not overshoot too far above mintThreshold (eases burn later).
        for (uint256 i; i < 24 && !info.isMintingAllowed(); ++i) {
            _skewSyntheticUp(d, 40 ether * (i + 1));
            emit log_named_uint("synth_mint_skew", info.syntheticPrice());
        }
        assertTrue(info.isMintingAllowed(), "mint must open under default Policy thresholds after real depth skew");
        assertTrue(info.syntheticPrice() > info.mintThreshold());

        // Execute a real Policy mint (pair → free DETF) while mint-allowed.
        uint256 previewMint = IStandardExchangeIn(d).previewExchangeIn(
            IERC20(address(pairToken)), 40 ether, IERC20(d)
        );
        assertGt(previewMint, 0, "mint quote while allowed");
        vm.startPrank(detfUser);
        uint256 minted = IStandardExchangeIn(d).exchangeIn(
            IERC20(address(pairToken)), 40 ether, IERC20(d), 0, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(minted, previewMint, "preview==exec mint under Policy");
        assertGt(info.protocolLp(), 0, "mint deposited protocol LP on claim");

        // --- Burn regime (synthetic < burnThreshold) under Policy ---
        // Combine: free seigniorage dilution (bond/mint), expansion debt realize, DETF-heavy pool skew.
        for (uint256 k; k < 30 && !info.isBurningAllowed(); ++k) {
            _diluteViaBond(d, 100 ether * (k + 1));
            if (info.isMintingAllowed()) {
                _tryMint(d, 50 ether * (k + 1));
            }
            // Realize expansion free DETF (supply ↑ without capital) when epochs pass under Policy mint-allowed.
            if (info.isMintingAllowed() || info.syntheticPrice() > 1e18) {
                vm.warp(block.timestamp + 8 hours * 4);
                _diluteViaBond(d, 20 ether); // bond is a realize path
            }
            // Skew reserve DETF-heavy with free DETF inventory (external LP not in FD set).
            uint256 freeDetf = IERC20(d).balanceOf(detfUser);
            if (freeDetf > 1 ether) {
                _skewSyntheticDownViaDetfDeposit(d, freeDetf / 2);
            }
            emit log_named_uint("synth_burn_skew", info.syntheticPrice());
        }

        uint256 synthBurn = info.syntheticPrice();
        emit log_named_uint("synth_for_burn", synthBurn);
        assertTrue(info.isBurningAllowed(), "burn must open under default Policy thresholds");
        assertTrue(synthBurn < info.burnThreshold(), "synthetic below burnThreshold");

        // Execute a real Policy burn when protocol LP exists.
        uint256 free = IERC20(d).balanceOf(detfUser);
        if (free > 1 ether && info.protocolLp() > 0) {
            uint256 burnAmt = free / 4;
            if (burnAmt == 0) burnAmt = free;
            // Cap by protocol LP economics
            uint256 previewBurn =
                IStandardExchangeIn(d).previewExchangeIn(IERC20(d), burnAmt, IERC20(address(pairToken)));
            if (previewBurn > 0) {
                vm.startPrank(detfUser);
                IERC20(d).approve(d, type(uint256).max);
                uint256 pairOut = IStandardExchangeIn(d).exchangeIn(
                    IERC20(d), burnAmt, IERC20(address(pairToken)), 0, detfUser, false, block.timestamp + 1 hours
                );
                vm.stopPrank();
                assertEq(pairOut, previewBurn, "preview==exec burn under Policy");
            }
        }
    }
}
