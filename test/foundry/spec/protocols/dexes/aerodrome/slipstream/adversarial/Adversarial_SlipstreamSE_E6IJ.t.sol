// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_SlipstreamStandardExchange
} from "contracts/protocols/dexes/aerodrome/slipstream/test/bases/TestBase_SlipstreamStandardExchange.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

/// @notice WP-SEC-E6-SLIP-001: E6 refund cap + I1 skip-pull + J1–J3 proxy surface.
/// @dev Production DFPkg via manager registry. Hermetic CL book is not SUT.
///      I1 does **not** transfer in-call. Happy push+true is not I1.
contract Adversarial_SlipstreamSE_E6IJ_Test is TestBase_SlipstreamStandardExchange {
    uint256 internal constant BOOKED = 100e18;
    uint256 internal constant AMOUNT_IN = 10e18;

    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("slipAttacker");
    }

    function _facetFuncsContains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    /* ---------------------------------------------------------------------- */
    /*  E6: seed booked R; leftover refund must not pay R                     */
    /* ---------------------------------------------------------------------- */

    /// @notice E6 In: seed pair inventory; zap-in refund must not sweep booked R.
    /// @dev Anti-theater: seed **before** the attacker call. Leftover-from-this-call is not booked.
    function test_E6_in_refund_doesNotSweepBookedInventory() public {
        pairToken0.mint(address(vault), BOOKED);
        pairToken1.mint(address(vault), BOOKED);
        uint256 vault0Before = pairToken0.balanceOf(address(vault));
        uint256 vault1Before = pairToken1.balanceOf(address(vault));
        assertGe(vault0Before, BOOKED, "seed token0");
        assertGe(vault1Before, BOOKED, "seed token1");

        pairToken0.mint(attacker, AMOUNT_IN);

        vm.startPrank(attacker);
        pairToken0.approve(address(vault), AMOUNT_IN);
        uint256 sharesOut = vault.exchangeIn(
            IERC20(address(pairToken0)),
            AMOUNT_IN,
            IERC20(address(vault)),
            0,
            attacker,
            false,
            _deadline()
        );
        vm.stopPrank();

        assertGt(sharesOut, 0, "honest zap minted");
        // APEX D15/D33: exact-in never refunds. Unpaired zap leftover stays with the vault and is
        // booked as local NAV at the end-of-route sync; the caller holds no pair tokens afterwards.
        uint256 attTokensAfter = pairToken0.balanceOf(attacker) + pairToken1.balanceOf(attacker);
        assertEq(attTokensAfter, 0, "D15: exact-in refunds nothing");
        assertGe(pairToken0.balanceOf(address(vault)), BOOKED, "E6: booked token0 remains");
        assertGe(pairToken1.balanceOf(address(vault)), BOOKED, "E6: booked token1 remains");
        assertEq(vault.reserveOfToken(address(pairToken0)), pairToken0.balanceOf(address(vault)), "leftover token0 booked");
        assertEq(vault.reserveOfToken(address(pairToken1)), pairToken1.balanceOf(address(vault)), "leftover token1 booked");
    }

    /// @notice E6 Out: seed booked R; fat max + transfer-only-used must not skim R.
    function test_E6_out_pretransferred_fatMax_doesNotSkimBook() public {
        pairToken0.mint(address(vault), BOOKED);
        pairToken0.mint(attacker, AMOUNT_IN);
        vm.startPrank(attacker);
        pairToken0.approve(address(vault), AMOUNT_IN);
        vault.exchangeIn(
            IERC20(address(pairToken0)), AMOUNT_IN, IERC20(address(pairToken1)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();

        uint256 amountOut = 1e17;
        uint256 quotedUsed = vault.previewExchangeOut(
            IERC20(address(pairToken0)), IERC20(address(pairToken1)), amountOut
        );
        assertGt(quotedUsed, 0, "quoted used");
        uint256 fatMax = quotedUsed + 50e18;

        pairToken0.mint(attacker, quotedUsed);
        vm.prank(attacker);
        pairToken0.transfer(address(vault), quotedUsed);

        vm.prank(attacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeOut(
            IERC20(address(pairToken0)),
            fatMax,
            IERC20(address(pairToken1)),
            amountOut,
            attacker,
            true,
            _deadline()
        );

        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 vaultBefore = pairToken0.balanceOf(address(vault));
        uint256 callerBefore = pairToken0.balanceOf(address(caller));
        vm.prank(address(caller));
        vault.exchangeOut(
            IERC20(address(pairToken0)),
            fatMax,
            IERC20(address(pairToken1)),
            amountOut,
            address(caller),
            true,
            _deadline()
        );
        assertGe(pairToken0.balanceOf(address(vault)), BOOKED, "E6 out: booked R stays");
        assertLe(pairToken0.balanceOf(address(caller)) - callerBefore, quotedUsed, "E6 out: no booked skim");
        assertLe(pairToken0.balanceOf(address(vault)), vaultBefore, "E6 out: used consumed from unbooked");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: pretransferred, no in-call transfer, inventory held → revert      */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 exchangeIn: booked pair inventory cannot free-credit a zap or swap.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        pairToken0.mint(attacker, AMOUNT_IN);
        vm.startPrank(attacker);
        pairToken0.approve(address(vault), AMOUNT_IN);
        vault.exchangeIn(
            IERC20(address(pairToken0)), AMOUNT_IN, IERC20(address(vault)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();

        uint256 invBefore = pairToken0.balanceOf(address(vault));
        uint256 claimed = 1 ether;
        uint256 attSharesBefore = IERC20(address(vault)).balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeIn(
            IERC20(address(pairToken0)),
            claimed,
            IERC20(address(vault)),
            0,
            attacker,
            true,
            _deadline()
        );

        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        vm.prank(address(caller));
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, uint256(0))
        );
        vault.exchangeIn(
            IERC20(address(pairToken0)),
            claimed,
            IERC20(address(vault)),
            0,
            address(caller),
            true,
            _deadline()
        );

        assertEq(IERC20(address(vault)).balanceOf(attacker), attSharesBefore, "I1: no free vaultShare");
        assertEq(pairToken0.balanceOf(address(vault)), invBefore, "I1: inventory unchanged");
    }

    /// @notice I1 exchangeOut: booked inventory cannot fund exact-out without inbound delta.
    function test_I1_exchangeOut_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        pairToken0.mint(address(vault), BOOKED);
        uint256 amountOut = 1e17;
        uint256 claimed = 1e18;

        pairToken0.mint(attacker, AMOUNT_IN);
        vm.startPrank(attacker);
        pairToken0.approve(address(vault), AMOUNT_IN);
        vault.exchangeIn(
            IERC20(address(pairToken0)), AMOUNT_IN, IERC20(address(pairToken1)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        uint256 invBefore = pairToken0.balanceOf(address(vault));
        uint256 quotedUsed = vault.previewExchangeOut(
            IERC20(address(pairToken0)), IERC20(address(pairToken1)), amountOut
        );
        assertGt(quotedUsed, 0, "quoted used");
        assertLe(quotedUsed, claimed, "quoted fits claimed max");
        uint256 att0Before = pairToken0.balanceOf(attacker);
        uint256 att1Before = pairToken1.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeOut(
            IERC20(address(pairToken0)),
            claimed,
            IERC20(address(pairToken1)),
            amountOut,
            attacker,
            true,
            _deadline()
        );
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        vm.prank(address(caller));
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, quotedUsed, uint256(0))
        );
        vault.exchangeOut(
            IERC20(address(pairToken0)),
            claimed,
            IERC20(address(pairToken1)),
            amountOut,
            address(caller),
            true,
            _deadline()
        );

        assertEq(pairToken0.balanceOf(attacker), att0Before, "I1 out: not refunded R");
        assertEq(pairToken1.balanceOf(attacker), att1Before, "I1 out: no free pairToken");
        assertEq(pairToken0.balanceOf(address(vault)), invBefore, "I1 out: inventory unchanged");
    }

    /* ---------------------------------------------------------------------- */
    /*  J1–J3: Target ⊆ facetFuncs ⊆ cuts ⊆ loupe ⊆ proxy smoke               */
    /* ---------------------------------------------------------------------- */

    /// @notice J1: CREATE3 facetFuncs cover target money/query selectors.
    function test_J1_facetFuncs_coversTargetApi() public view {
        assertTrue(
            _facetFuncsContains(
                IFacet(address(slipstreamStandardExchangeInFacet)).facetFuncs(),
                IStandardExchangeIn.exchangeIn.selector
            ),
            "J1 exchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(slipstreamStandardExchangeInFacetExt)).facetFuncs(),
                IStandardExchangeIn.previewExchangeIn.selector
            ),
            "J1 previewExchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(slipstreamStandardExchangeOutFacet)).facetFuncs(),
                IStandardExchangeOut.exchangeOut.selector
            ),
            "J1 exchangeOut"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(slipstreamStandardExchangeOutFacet)).facetFuncs(),
                IStandardExchangeOut.previewExchangeOut.selector
            ),
            "J1 previewExchangeOut"
        );
    }

    /// @notice J2: loupe facetAddress(sel) != 0 on the production proxy.
    function test_J2_proxyLoupe_allProductSelectors() public view {
        IDiamondLoupe loupe_ = IDiamondLoupe(address(vault));
        bytes4[4] memory controls_ = [
            IStandardExchangeIn.exchangeIn.selector,
            IStandardExchangeIn.previewExchangeIn.selector,
            IStandardExchangeOut.exchangeOut.selector,
            IStandardExchangeOut.previewExchangeOut.selector
        ];
        for (uint256 i; i < controls_.length; ++i) {
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != address(vault), "J2 facet != proxy");
        }
    }

    /// @notice J3: smoke-call money + view selectors on the **proxy**, never the facet impl.
    function test_J3_proxyCallable_smoke_eachSelector() public {
        address exchangeInFacet_ = IDiamondLoupe(address(vault)).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        address exchangeOutFacet_ =
            IDiamondLoupe(address(vault)).facetAddress(IStandardExchangeOut.exchangeOut.selector);
        assertTrue(exchangeInFacet_ != address(0) && exchangeInFacet_ != address(vault), "proxy cut in");
        assertTrue(exchangeOutFacet_ != address(0) && exchangeOutFacet_ != address(vault), "proxy cut out");

        uint256 previewIn_ = IStandardExchangeIn(address(vault)).previewExchangeIn(
            IERC20(address(pairToken0)), 1 ether, IERC20(address(pairToken1))
        );
        assertGt(previewIn_, 0, "J3 previewExchangeIn live on proxy");

        uint256 previewOut_ = IStandardExchangeOut(address(vault)).previewExchangeOut(
            IERC20(address(pairToken0)), IERC20(address(pairToken1)), 1e17
        );
        assertGt(previewOut_, 0, "J3 previewExchangeOut live on proxy");

        vm.prank(attacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(pairToken0)), 1 ether, IERC20(address(pairToken1)), 0, attacker, true, _deadline()
        );
    }

    /* ---------------------------------------------------------------------- */
    /*  APEX-2026-004B / D15: token exact-out refund is `min(availableBefore, max) - used`  */
    /* ---------------------------------------------------------------------- */

    function test_APEX004B_exactOut_refundTriples_contractCaller() public {
        uint256 amountOut = 1e18;
        uint256 used_ = vault.previewExchangeOut(IERC20(address(pairToken0)), IERC20(address(pairToken1)), amountOut);
        require(used_ > 0, "preview used");
        uint256 hundred_ = (used_ * 100) / 60;
        uint256 eighty_ = (used_ * 80) / 60;
        uint256[3] memory available_ = [hundred_, hundred_, used_];
        uint256[3] memory maximum_ = [hundred_, eighty_, hundred_];
        for (uint256 i; i < 3; ++i) {
            uint256 snap = vm.snapshotState();
            AtomicPretransferCaller caller = new AtomicPretransferCaller();
            pairToken0.mint(address(this), available_[i]);
            pairToken0.approve(address(caller), available_[i]);
            uint256 bookedBefore_ = vault.reserveOfToken(address(pairToken0));
            bytes memory data = abi.encodeCall(
                IStandardExchangeOut.exchangeOut,
                (IERC20(address(pairToken0)), maximum_[i], IERC20(address(pairToken1)), amountOut, address(caller), true, _deadline())
            );
            uint256 spent_ = abi.decode(
                caller.consumePretransfer(IERC20(address(pairToken0)), address(this), address(vault), available_[i], data), (uint256)
            );
            uint256 credit_ = available_[i] < maximum_[i] ? available_[i] : maximum_[i];
            assertLe(spent_, credit_, "used within credit");
            assertEq(pairToken0.balanceOf(address(caller)), credit_ - spent_, "refund = min(available, max) - used");
            assertEq(pairToken1.balanceOf(address(caller)), amountOut, "exact output");
            assertGe(vault.reserveOfToken(address(pairToken0)), bookedBefore_, "booked backing never paid out");
            assertTrue(vm.revertToState(snap));
        }
    }

    /// @dev D9: a short or zero self-funded EOA is rejected with the exact error on both modes.
    function test_APEX005_eoaPretransfer_bothModes_rejected() public {
        pairToken0.mint(attacker, 1e18);
        vm.startPrank(attacker);
        pairToken0.transfer(address(vault), 1e18);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeIn(IERC20(address(pairToken0)), 1e18, IERC20(address(pairToken1)), 0, attacker, true, _deadline());
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeOut(IERC20(address(pairToken0)), 1e18, IERC20(address(pairToken1)), 1e15, attacker, true, _deadline());
        vm.stopPrank();
    }
}
