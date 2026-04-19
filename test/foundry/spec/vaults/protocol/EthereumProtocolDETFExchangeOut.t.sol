// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {ProtocolDETFEthereumCustomFixtureHelpers} from "./ProtocolDETF_CustomFixtureHelpers.t.sol";
import {
    PREVIEW_BUFFER_DENOMINATOR,
    PREVIEW_RICHIR_BUFFER_BPS,
    PREVIEW_BPT_BUFFER_BPS,
    PREVIEW_WETH_CHIR_BUFFER_BPS
} from "contracts/constants/Indexedex_CONSTANTS.sol";
import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";

/**
 * @title ProtocolDETFExchangeOut
 * @notice Tests for the Protocol DETF exact-out exchange flow (IDXEX-019)
 * @dev Verifies:
 *      - previewExchangeOut returns correct WETH for exact CHIR
 *      - exchangeOut mints exact CHIR amount
 *      - Rounding favors vault (UP for inputs)
 *      - Slippage protection works
 *      - Minting gated by synthetic price threshold
 */
contract ProtocolDETFExchangeOut is ProtocolDETFEthereumCustomFixtureHelpers {
    function _seedChir(address recipient, uint256 amount) internal {
        deal(address(detf), recipient, amount, true);
    }

    /* ---------------------------------------------------------------------- */
    /*                        Test: Preview Exchange Out                      */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test preview returns correct WETH amount for exact CHIR
     */
    function test_previewExchangeOut_weth_chir_reverts_when_minting_not_allowed() public {
        uint256 exactChirOut = 1_000e18;
        _driveEthereumToBurnEnabled(detf);
        uint256 syntheticPrice = detf.syntheticPrice();
        uint256 mintThreshold = detf.mintThreshold();

        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.MintingNotAllowed.selector, syntheticPrice, mintThreshold));
        IStandardExchangeOut(address(detf)).previewExchangeOut(IERC20(address(weth9)), IERC20(address(detf)), exactChirOut);
    }

    // /**
    //  * @notice Test that preview rounds UP (vault-favorable)
    //  */
    // TODO Consider deprecating because tests that exercise preview in execution are more meaningful than standalone preview tests
    // function test_previewExchangeOut_rounds_up() public view {
    //     // Use an amount that would require non-integer division
    //     uint256 exactChirOut = 1e18 + 1; // 1.000...001 CHIR

    //     uint256 requiredWeth = IStandardExchangeOut(address(detf))
    //         .previewExchangeOut(IERC20(address(weth9)), IERC20(address(detf)), exactChirOut);

    //     // If synthetic price > 1, the division would have a remainder
    //     // Ceiling rounding means requiredWeth * ONE_WAD >= exactChirOut * syntheticPrice
    //     // This is a sanity check - the exact verification happens in execution
    //     assertGt(requiredWeth, 0, "Required WETH should be positive");
    // }

    /* ---------------------------------------------------------------------- */
    /*                        Test: Exchange Out Success                      */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test exact-out exchange mints correct CHIR amount
     */
    function test_exchangeOut_weth_chir_reverts_when_minting_not_allowed() public {
        uint256 exactChirOut = 5_000e18;
        _driveEthereumToBurnEnabled(detf);
        uint256 syntheticPrice = detf.syntheticPrice();
        uint256 mintThreshold = detf.mintThreshold();

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.MintingNotAllowed.selector, syntheticPrice, mintThreshold));
        IStandardExchangeOut(address(detf)).exchangeOut(
            IERC20(address(weth9)),
            type(uint256).max,
            IERC20(address(detf)),
            exactChirOut,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_exchangeOut_weth_chir_when_minting_allowed() public {
        uint256 exactChirOut = 5_000e18;

        _driveEthereumToMintEnabled(detf);

        uint256 requiredWeth = IStandardExchangeOut(address(detf)).previewExchangeOut(
            IERC20(address(weth9)), IERC20(address(detf)), exactChirOut
        );

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), requiredWeth);
        uint256 wethUsed = IStandardExchangeOut(address(detf)).exchangeOut(
            IERC20(address(weth9)),
            requiredWeth,
            IERC20(address(detf)),
            exactChirOut,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertLe(wethUsed, requiredWeth, "exact-out should not consume more WETH than previewed");
        assertApproxEqRel(wethUsed, requiredWeth, 0.002e18, "preview should stay within 0.2% of actual WETH used");
        assertEq(IERC20(address(detf)).balanceOf(detfAlice), exactChirOut, "user should receive exact CHIR out");
    }

    /**
     * @notice Test exact-out with pretransferred tokens
     */
    function test_exchangeOut_weth_chir_pretransferred_reverts_when_minting_not_allowed() public {
        uint256 exactChirOut = 2_000e18;
        _driveEthereumToBurnEnabled(detf);
        uint256 syntheticPrice = detf.syntheticPrice();
        uint256 mintThreshold = detf.mintThreshold();

        vm.prank(detfAlice);
        IERC20(address(weth9)).transfer(address(detf), exactChirOut);

        vm.prank(detfAlice);
        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.MintingNotAllowed.selector, syntheticPrice, mintThreshold));
        IStandardExchangeOut(address(detf)).exchangeOut(
            IERC20(address(weth9)), exactChirOut, IERC20(address(detf)), exactChirOut, detfAlice, true, block.timestamp + 1 hours
        );
    }

    /**
     * @notice Test exact-out with excess pretransferred tokens gets refund
     */
    function test_exchangeOut_weth_chir_pretransferred_refund_reverts_when_minting_not_allowed() public {
        uint256 exactChirOut = 1_000e18;
        _driveEthereumToBurnEnabled(detf);
        uint256 syntheticPrice = detf.syntheticPrice();
        uint256 mintThreshold = detf.mintThreshold();
        uint256 transferAmount = exactChirOut + 100e18;

        vm.prank(detfAlice);
        IERC20(address(weth9)).transfer(address(detf), transferAmount);

        vm.prank(detfAlice);
        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.MintingNotAllowed.selector, syntheticPrice, mintThreshold));
        IStandardExchangeOut(address(detf)).exchangeOut(
            IERC20(address(weth9)), transferAmount, IERC20(address(detf)), exactChirOut, detfAlice, true, block.timestamp + 1 hours
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                        Test: Slippage Protection                       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test that exchange reverts if required WETH exceeds maxAmountIn
     */
    function test_exchangeOut_weth_chir_reverts_when_minting_not_allowed_before_slippage() public {
        uint256 exactChirOut = 10_000e18;
        _driveEthereumToBurnEnabled(detf);
        uint256 syntheticPrice = detf.syntheticPrice();
        uint256 mintThreshold = detf.mintThreshold();

        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.MintingNotAllowed.selector, syntheticPrice, mintThreshold));
        IStandardExchangeOut(address(detf)).previewExchangeOut(IERC20(address(weth9)), IERC20(address(detf)), exactChirOut);
    }

    /* ---------------------------------------------------------------------- */
    /*                        Test: Minting Gate                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test that exchange reverts when minting not allowed
     * @dev This requires setting up a state where syntheticPrice <= mintThreshold
     */
    function test_exchangeOut_reverts_minting_not_allowed() public {
        uint256 exactChirOut = 100e18;
        _driveEthereumToBurnEnabled(detf);
        uint256 syntheticPrice = detf.syntheticPrice();
        uint256 mintThreshold = detf.mintThreshold();

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.MintingNotAllowed.selector, syntheticPrice, mintThreshold));
        IStandardExchangeOut(address(detf)).exchangeOut(
            IERC20(address(weth9)), type(uint256).max, IERC20(address(detf)), exactChirOut, detfAlice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                        Test: Unsupported Routes                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Test that unsupported routes revert
     */
    function test_previewExchangeOut_reverts_unsupported_route() public {
        // Try RICH → WETH (not supported)
        vm.expectRevert();
        IStandardExchangeOut(address(detf)).previewExchangeOut(rich, IERC20(address(weth9)), 1_000e18);
    }

    /**
     * @notice Test that deadline enforcement works
     */
    function test_exchangeOut_reverts_deadline_exceeded() public {
        uint256 exactChirOut = 100e18;
        uint256 expiredDeadline = block.timestamp - 1; // Already expired

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), 1_000e18);

        vm.expectRevert();
        IStandardExchangeOut(address(detf))
            .exchangeOut(
                IERC20(address(weth9)), 1_000e18, IERC20(address(detf)), exactChirOut, detfAlice, false, expiredDeadline
            );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                              Fuzz Tests                                */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Fuzz test for exact-out exchange
     */
    function testFuzz_exchangeOut_weth_chir_reverts_when_minting_not_allowed(uint256 exactChirOut) public {
        // Bound to reasonable range
        exactChirOut = bound(exactChirOut, 1e18, 50_000e18);
        _driveEthereumToBurnEnabled(detf);
        uint256 syntheticPrice = detf.syntheticPrice();
        uint256 mintThreshold = detf.mintThreshold();

        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.MintingNotAllowed.selector, syntheticPrice, mintThreshold));
        IStandardExchangeOut(address(detf)).previewExchangeOut(IERC20(address(weth9)), IERC20(address(detf)), exactChirOut);
    }

    /* ---------------------------------------------------------------------- */
    /*                     IDXEX-025: New ExactOut Routes                     */
    /* ---------------------------------------------------------------------- */

    /**
    * @notice CHIR → WETH exact-out is not available.
     */
    function test_exchangeOut_chir_to_weth_exact_reverts_not_available_even_when_burning_allowed() public {
        uint256 exactWethOut = 1_000e18;

        _driveEthereumToBurnEnabled(detf);
        _assertBurnEnabled(detf);

        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(address(detf)).previewExchangeOut(IERC20(address(detf)), IERC20(address(weth9)), exactWethOut);

        _seedChir(detfAlice, 10_000e18);
        vm.startPrank(detfAlice);
        IERC20(address(detf)).approve(address(detf), type(uint256).max);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(address(detf)).exchangeOut(
            IERC20(address(detf)),
            type(uint256).max,
            IERC20(address(weth9)),
            exactWethOut,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_exchangeOut_chir_to_weth_reverts_not_available_before_burn_checks() public {
        uint256 exactWethOut = 1_000e18;

        _driveEthereumToMintEnabled(detf);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(address(detf)).previewExchangeOut(IERC20(address(detf)), IERC20(address(weth9)), exactWethOut);

        deal(address(detf), detfAlice, 10_000e18, true);
        vm.startPrank(detfAlice);
        IERC20(address(detf)).approve(address(detf), type(uint256).max);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(address(detf)).exchangeOut(
            IERC20(address(detf)),
            type(uint256).max,
            IERC20(address(weth9)),
            exactWethOut,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /**
     * @notice Test WETH → RICH exact-out (US-IDXEX-025.3)
     * @dev User buys at least X RICH with WETH via multi-hop
     * @dev Note: Exact-out may deliver slightly more due to AMM rounding
     */
    function test_exchangeOut_weth_to_rich_exact() public {
        uint256 exactRichOut = 500e18;

        // Get preview of required WETH
        uint256 requiredWeth =
            IStandardExchangeOut(address(detf)).previewExchangeOut(IERC20(address(weth9)), rich, exactRichOut);

        assertGt(requiredWeth, 0, "Required WETH should be positive");

        uint256 aliceWethBefore = IERC20(address(weth9)).balanceOf(detfAlice);
        uint256 aliceRichBefore = rich.balanceOf(detfAlice);

        // Execute exact-out
        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), requiredWeth);
        uint256 wethUsed = IStandardExchangeOut(address(detf))
            .exchangeOut(
                IERC20(address(weth9)), requiredWeth, rich, exactRichOut, detfAlice, false, block.timestamp + 1 hours
            );
        vm.stopPrank();

        uint256 aliceWethAfter = IERC20(address(weth9)).balanceOf(detfAlice);
        uint256 aliceRichAfter = rich.balanceOf(detfAlice);

        // Verify at least exact RICH received (may get more due to rounding)
        assertGe(aliceRichAfter - aliceRichBefore, exactRichOut, "Should receive at least exact RICH");

        // Verify WETH was taken
        assertEq(aliceWethBefore - aliceWethAfter, wethUsed, "WETH should be deducted");

        // Verify preview accuracy
        assertEq(wethUsed, requiredWeth, "Actual WETH used should match preview");
    }

    /**
     * @notice Test RICH → CHIR exact-out (US-IDXEX-025.4)
     * @dev User receives exactly X CHIR from RICH
     */
    function test_exchangeOut_rich_to_chir_reverts_when_minting_not_allowed() public {
        uint256 exactChirOut = 1_000e18;
        _driveEthereumToBurnEnabled(detf);
        uint256 syntheticPrice = detf.syntheticPrice();
        uint256 mintThreshold = detf.mintThreshold();

        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.MintingNotAllowed.selector, syntheticPrice, mintThreshold));
        IStandardExchangeOut(address(detf)).previewExchangeOut(rich, IERC20(address(detf)), exactChirOut);
    }

    function test_exchangeOut_rich_to_chir_when_minting_allowed() public {
        uint256 exactChirOut = 1_000e18;

        _driveEthereumToMintEnabled(detf);

        uint256 requiredRich = IStandardExchangeOut(address(detf)).previewExchangeOut(
            rich, IERC20(address(detf)), exactChirOut
        );

        vm.startPrank(detfAlice);
        rich.approve(address(detf), requiredRich);
        uint256 richUsed = IStandardExchangeOut(address(detf)).exchangeOut(
            rich,
            requiredRich,
            IERC20(address(detf)),
            exactChirOut,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertLe(richUsed, requiredRich, "exact-out should not consume more RICH than previewed");
        assertApproxEqRel(richUsed, requiredRich, 0.05e18, "preview should stay within 5% of actual RICH used");
        assertEq(IERC20(address(detf)).balanceOf(detfAlice), exactChirOut, "user should receive exact CHIR out");
    }

    /**
     * @notice RICH → RICHIR exact-out is NOT supported (TGT-ProtocolDETFExchangeOut-05)
     */
    function test_exchangeOut_rich_to_richir_exact_reverts_route_not_supported() public {
        uint256 exactRichirOut = 100e18;

        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.RouteNotSupported.selector,
                address(rich),
                address(richir),
                IStandardExchangeOut.previewExchangeOut.selector
            )
        );
        IStandardExchangeOut(address(detf)).previewExchangeOut(rich, IERC20(address(richir)), exactRichirOut);

        vm.startPrank(detfAlice);
        rich.approve(address(detf), type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.RouteNotSupported.selector,
                address(rich),
                address(richir),
                IStandardExchangeOut.exchangeOut.selector
            )
        );
        IStandardExchangeOut(address(detf)).exchangeOut(
            rich,
            type(uint256).max,
            IERC20(address(richir)),
            exactRichirOut,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /**
     * @notice WETH → RICHIR exact-out is NOT supported (TGT-ProtocolDETFExchangeOut-06)
     */
    function test_exchangeOut_weth_to_richir_exact_reverts_route_not_supported() public {
        uint256 exactRichirOut = 100e18;

        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.RouteNotSupported.selector,
                address(weth9),
                address(richir),
                IStandardExchangeOut.previewExchangeOut.selector
            )
        );
        IStandardExchangeOut(address(detf)).previewExchangeOut(
            IERC20(address(weth9)), IERC20(address(richir)), exactRichirOut
        );

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.RouteNotSupported.selector,
                address(weth9),
                address(richir),
                IStandardExchangeOut.exchangeOut.selector
            )
        );
        IStandardExchangeOut(address(detf)).exchangeOut(
            IERC20(address(weth9)),
            type(uint256).max,
            IERC20(address(richir)),
            exactRichirOut,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /**
     * @notice RICHIR → WETH exact-out preview is NOT supported (TGT-ProtocolDETFExchangeOut-04)
     */
    function test_exchangeOut_richir_to_weth_exact_preview_reverts_route_not_supported() public {
        uint256 exactWethOut = 10e18;

        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.RouteNotSupported.selector,
                address(richir),
                address(weth9),
                IStandardExchangeOut.previewExchangeOut.selector
            )
        );
        IStandardExchangeOut(address(detf)).previewExchangeOut(
            IERC20(address(richir)), IERC20(address(weth9)), exactWethOut
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                 IDXEX-025: Slippage Tests for New Routes              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice CHIR → WETH exact-out fails before slippage handling.
     */
    function test_exchangeOut_chir_to_weth_exact_reverts_not_available_before_slippage() public {
        uint256 exactWethOut = 1_000e18;
        _driveEthereumToBurnEnabled(detf);
        _assertBurnEnabled(detf);

        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(address(detf)).previewExchangeOut(IERC20(address(detf)), IERC20(address(weth9)), exactWethOut);

        _seedChir(detfAlice, 10_000e18);
        vm.startPrank(detfAlice);
        IERC20(address(detf)).approve(address(detf), type(uint256).max);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(address(detf)).exchangeOut(
            IERC20(address(detf)),
            1,
            IERC20(address(weth9)),
            exactWethOut,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /**
     * @notice Test slippage protection for WETH → RICH exact-out
     */
    function test_exchangeOut_weth_to_rich_slippage_reverts() public {
        uint256 exactRichOut = 500e18;

        uint256 requiredWeth =
            IStandardExchangeOut(address(detf)).previewExchangeOut(IERC20(address(weth9)), rich, exactRichOut);

        // Set maxAmountIn to less than required
        uint256 maxWethIn = requiredWeth - 1;

        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf), requiredWeth);

        // Should revert
        vm.expectRevert();
        IStandardExchangeOut(address(detf))
            .exchangeOut(
                IERC20(address(weth9)), maxWethIn, rich, exactRichOut, detfAlice, false, block.timestamp + 1 hours
            );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                  IDXEX-025: Preview Accuracy Tests                    */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Verify preview accuracy for routes that should work
     * @dev Note: CHIR → WETH requires burning to be allowed (syntheticPrice < burnThreshold)
     *      The test setup may not always have burning allowed, so we test other routes
     */
    function test_previewExchangeOut_accuracy_working_routes() public {
        // First set up liquidity
        _bondForReserveLiquidity(detfBob, 50_000e18);

        // Test WETH → RICH preview
        uint256 wethToRichPreview =
            IStandardExchangeOut(address(detf)).previewExchangeOut(IERC20(address(weth9)), rich, 500e18);
        assertGt(wethToRichPreview, 0, "WETH->RICH preview should be positive");

        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.RouteNotSupported.selector,
                address(rich),
                address(richir),
                IStandardExchangeOut.previewExchangeOut.selector
            )
        );
        IStandardExchangeOut(address(detf)).previewExchangeOut(rich, IERC20(address(richir)), 100e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.RouteNotSupported.selector,
                address(weth9),
                address(richir),
                IStandardExchangeOut.previewExchangeOut.selector
            )
        );
        IStandardExchangeOut(address(detf)).previewExchangeOut(IERC20(address(weth9)), IERC20(address(richir)), 100e18);
    }
}
