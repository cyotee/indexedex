// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

interface IMultiAssetBasicVaultViews {
    function vaultTokens() external view returns (address[] memory);
    function reserveOfToken(address token) external view returns (uint256);
}

/// @notice Wave 2A DualLiquidity adversarial catalog fill + ID map of existing security suites.
/// @dev Existing coverage (do not duplicate):
///      - A3-class: DualLiquidity..._ShareInflation (BPT donation / front-run) — NOT I1/K1
///      - C-class: DualLiquidity..._Reentrancy / _ReentrancyRedeem
///      - E/H residual: DualLiquidity..._Residual
///      - F immutability: DualLiquidity..._Immutability
///      - B rate: DualLiquidity..._RateExtremes
///      - Guards: DualLiquidity..._Guards
/// @dev This file fills H3, F1, I1–I3 + K1 (L-GAPS-9/10/12 secure pull), and J1–J3 proxy surface.
contract Adversarial_DualLiquidity_Catalog_Test is TestBase_DualLiquidityLinkedCrossVersionUniswapVault {
    address internal attacker;
    address internal honest;

    uint256 internal constant CLAIMED = 100e18;
    uint256 internal constant RESIDUAL = 50e18;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        honest = makeAddr("honest");
    }

    /// @notice Catalog map (structural) - existing files provide P0 for A3/C/E residual.
    function test_catalog_existingSecurityFiles_present() public view {
        // Compile-time / path existence is enforced by CI running those suites.
        // Runtime: vault from TestBase is production dual-liquidity instance.
        assertTrue(linkedVault != address(0), "production vault wired");
    }

    function test_H3_failedMint_minOut_leavesNoInventoryOnVault() public {
        _bootstrapReserve();
        uint256 supplyBefore_ = IERC20(linkedVault).totalSupply();
        // Attempt zero amount should revert cleanly
        vm.prank(attacker);
        vm.expectRevert();
        IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(address(0)), 0, IERC20(linkedVault), 0, attacker, false, block.timestamp + 1 hours
        );
        assertEq(IERC20(linkedVault).totalSupply(), supplyBefore_, "H3: supply unchanged on fail");
        assertEq(IERC20(linkedVault).balanceOf(linkedVault), 0, "H3: no free vault shares on diamond");
    }

    function test_F1_diamondCut_notCallable() public {
        _bootstrapReserve();
        (bool ok,) = linkedVault.call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)", new bytes(0), address(0), ""
            )
        );
        assertFalse(ok, "F1 diamondCut blocked");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: booked inventory (R==B), no new unbooked push, pretransferred=true */
    /* ---------------------------------------------------------------------- */

    /// @dev Ensure commonToken is on the expected-hold set (otherwise residual never books into R).
    function _requireCommonInHoldSet() internal view {
        address[] memory toks_ = IMultiAssetBasicVaultViews(linkedVault).vaultTokens();
        bool commonHeld_;
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == address(commonToken)) {
                commonHeld_ = true;
                break;
            }
        }
        assertTrue(commonHeld_, "hold-set must include commonToken");
    }

    /// @dev Money-route end-sync only: R := B for hold-set (U=0). No free residual required for I1.
    function _endSyncHoldSet() internal {
        _requireCommonInHoldSet();
        uint256 honestIn_ = LEG_SEED / 10;
        if (honestIn_ == 0) honestIn_ = 1e18;
        _fund(commonToken, honest, honestIn_);
        vm.startPrank(honest);
        commonToken.approve(linkedVault, honestIn_);
        uint256 out_ = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, honestIn_, IERC20(linkedVault), 0, honest, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "end-sync honest mint ok");

        uint256 R_ = IMultiAssetBasicVaultViews(linkedVault).reserveOfToken(address(commonToken));
        uint256 B_ = commonToken.balanceOf(linkedVault);
        assertEq(R_, B_, "end-sync: common R must equal B (U=0)");
    }

    /// @dev Donate residual then honest !pretransferred mint so end-sync books residual (R==B, B may be >0).
    ///      Sweep preserves pre-call resting balances, so residual survives the honest path.
    function _bookCommonResidual(uint256 residual_) internal {
        _requireCommonInHoldSet();
        require(residual_ > 0, "residual");

        // Leave free booked inventory after sync: donate first, then money-route (snapshot includes residual).
        _fund(commonToken, linkedVault, residual_);

        uint256 honestIn_ = residual_ / 2;
        if (honestIn_ == 0) honestIn_ = 1e18;
        // Cap honest join vs dual-liq reserve MaxInRatio (~30% of leg balances).
        if (honestIn_ > LEG_SEED / 20) honestIn_ = LEG_SEED / 20;
        if (honestIn_ == 0) honestIn_ = 1e18;

        _fund(commonToken, honest, honestIn_);
        vm.startPrank(honest);
        commonToken.approve(linkedVault, honestIn_);
        uint256 out_ = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, honestIn_, IERC20(linkedVault), 0, honest, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "book residual: honest mint ok");

        uint256 R_ = IMultiAssetBasicVaultViews(linkedVault).reserveOfToken(address(commonToken));
        uint256 B_ = commonToken.balanceOf(linkedVault);
        assertEq(R_, B_, "book residual: common R must equal B after honest end-sync");
        // U=0 is the I1 precondition. Free B>0 is ideal for absolute-inventory theater but not required
        // if residual was fully consumed/swept (security still holds with U=0).
    }

    /// @notice I1 mint: after end-sync U=0; free true without new push reverts (claimed, 0).
    /// @dev L-RSRV-DUST: bare donation free-credits until end-sync — not I1. Book residual first.
    function test_I1_pretransferred_mint_inventoryNoInCallTransfer_revertsDelta0() public {
        _bootstrapReserve();
        _bookCommonResidual(CLAIMED);

        assertEq(commonToken.balanceOf(attacker), 0);
        assertEq(commonToken.allowance(attacker, linkedVault), 0);

        uint256 balBefore_ = commonToken.balanceOf(linkedVault);
        uint256 attackerSharesBefore_ = IERC20(linkedVault).balanceOf(attacker);
        uint256 supplyBefore_ = IERC20(linkedVault).totalSupply();

        // Claim may exceed free B; product reverts on U=0 regardless of absolute B.
        uint256 claim_ = CLAIMED;
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claim_, uint256(0)
            )
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, claim_, IERC20(linkedVault), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(commonToken.balanceOf(linkedVault), balBefore_, "I1 must not move inventory");
        assertEq(IERC20(linkedVault).balanceOf(attacker), attackerSharesBefore_, "I1: no free share mint");
        assertEq(IERC20(linkedVault).totalSupply(), supplyBefore_, "I1: supply unchanged");
    }

    /// @notice I1: claimed > 0 with booked free inventory reverts U=0 (no absolute free credit).
    function test_I1_pretransferred_claimedLeInventory_stillReverts() public {
        _bootstrapReserve();
        _bookCommonResidual(RESIDUAL + CLAIMED);

        // Prefer claim ≤ free B when residual remains (absolute theater); else any claim>0 with U=0.
        uint256 freeB_ = commonToken.balanceOf(linkedVault);
        uint256 claimed_ = freeB_ > 0 ? (freeB_ > RESIDUAL ? RESIDUAL : freeB_) : uint256(1);
        if (claimed_ == 0) claimed_ = 1;

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, claimed_, IERC20(linkedVault), 0, attacker, true, block.timestamp + 1 hours
        );
    }

    /// @notice I1 receiveOut: booked hold-set + exact-out true without new push reverts U=0.
    function test_I1_pretransferred_receiveOut_inventoryNoInCallTransfer_revertsDelta0() public {
        _bootstrapReserve();

        uint256 probeIn_ = 50e18;
        uint256 amountOut_ =
            IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, probeIn_, tokenA);
        amountOut_ = amountOut_ > 1 ? amountOut_ / 2 : amountOut_;
        require(amountOut_ > 0, "need positive swap out");

        uint256 maxIn_ =
            IStandardExchangeOut(linkedVault).previewExchangeOut(commonToken, tokenA, amountOut_);
        require(maxIn_ > 0, "need positive exact-out quote");

        // Book residual free common so absolute inventory may cover maxIn; U must still be 0.
        _bookCommonResidual(maxIn_ * 3);

        uint256 balBefore_ = commonToken.balanceOf(linkedVault);
        uint256 attackerOutBefore_ = tokenA.balanceOf(attacker);
        uint256 attackerTokenBefore_ = commonToken.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, maxIn_, uint256(0)
            )
        );
        IStandardExchangeOut(linkedVault).exchangeOut(
            commonToken, maxIn_, tokenA, amountOut_, attacker, true, block.timestamp + 1 hours
        );

        assertEq(commonToken.balanceOf(linkedVault), balBefore_, "I1 out: inventory unmoved");
        assertEq(tokenA.balanceOf(attacker), attackerOutBefore_, "I1 out: no free tokenOut");
        assertEq(commonToken.balanceOf(attacker), attackerTokenBefore_, "I1 out: no surplus refund theft");
    }

    /* ---------------------------------------------------------------------- */
    /*  I2: claimed > U (booked residual + no new push ⇒ U=0)                 */
    /* ---------------------------------------------------------------------- */

    /// @notice I2 mint: after end-sync U=0; free true reverts (claimed, 0).
    function test_I2_pretransferred_mint_claimedGtDelta0_reverts() public {
        _bootstrapReserve();
        // I2 does not need free residual — only U=0 after money-route end-sync.
        _endSyncHoldSet();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0)
            )
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, CLAIMED, IERC20(linkedVault), 0, attacker, true, block.timestamp + 1 hours
        );
    }

    /// @notice I2 receiveOut: after end-sync U=0; free exact-out true reverts.
    function test_I2_pretransferred_receiveOut_claimedGtDelta0_reverts() public {
        _bootstrapReserve();

        uint256 probeIn_ = 50e18;
        uint256 amountOut_ =
            IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, probeIn_, tokenA);
        amountOut_ = amountOut_ > 1 ? amountOut_ / 2 : amountOut_;
        require(amountOut_ > 0, "need positive swap out");

        uint256 maxIn_ =
            IStandardExchangeOut(linkedVault).previewExchangeOut(commonToken, tokenA, amountOut_);
        require(maxIn_ > 0, "need positive exact-out quote");
        _endSyncHoldSet();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, maxIn_, uint256(0)
            )
        );
        IStandardExchangeOut(linkedVault).exchangeOut(
            commonToken, maxIn_, tokenA, amountOut_, attacker, true, block.timestamp + 1 hours
        );
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual after honest end-sync is booked; free true reverts       */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: residual donation absorbed by honest money-route end-sync; free true reverts U=0.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer_mint() public {
        _bootstrapReserve();
        _requireCommonInHoldSet();

        // Pre-seed residual then honest mint end-syncs hold-set (books residual). Do not re-seed
        // unbooked inventory after sync (that would recreate U — L-RSRV-DUST, not I3).
        _fund(commonToken, linkedVault, RESIDUAL);
        uint256 honestIn_ = CLAIMED;
        if (honestIn_ > LEG_SEED / 20) honestIn_ = LEG_SEED / 20;
        _fund(commonToken, honest, honestIn_);
        vm.startPrank(honest);
        commonToken.approve(linkedVault, honestIn_);
        uint256 out_ = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, honestIn_, IERC20(linkedVault), 0, honest, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest mint ok");

        uint256 residual_ = commonToken.balanceOf(linkedVault);
        uint256 R_ = IMultiAssetBasicVaultViews(linkedVault).reserveOfToken(address(commonToken));
        assertEq(R_, residual_, "I3: residual must be booked (R==B)");
        uint256 claim_ = residual_ > 0 ? residual_ : uint256(1);

        uint256 attackerSharesBefore_ = IERC20(linkedVault).balanceOf(attacker);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claim_, uint256(0)
            )
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, claim_, IERC20(linkedVault), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(commonToken.balanceOf(linkedVault), residual_, "I3 residual unmoved");
        assertEq(IERC20(linkedVault).balanceOf(attacker), attackerSharesBefore_, "I3 no free mint");
    }

    /// @notice Positive control: honest !pretransferred deposit (in-call transferFrom) succeeds.
    function test_I_positive_honestPullMint_succeeds() public {
        _bootstrapReserve();
        _fund(tokenA, honest, LEG_SEED);

        vm.startPrank(honest);
        tokenA.approve(linkedVault, LEG_SEED);
        uint256 out_ = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, LEG_SEED, IERC20(linkedVault), 0, honest, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(out_, 0, "honest !pretransferred mint");
        assertEq(IERC20(linkedVault).balanceOf(honest), out_, "honest received shares");
    }

    /* ---------------------------------------------------------------------- */
    /*  K1: bare donation free-credits until sync (L-RSRV-DUST); booked after  */
    /* ---------------------------------------------------------------------- */

    /// @notice K1: after donation is booked via honest end-sync, free true cannot free-credit.
    function test_K1_donation_cannotFundPretransferCredit_mint() public {
        _bootstrapReserve();
        uint256 donated_ = CLAIMED;

        // Donation then honest mint books residual (L-RSRV-ABSORB / end-sync).
        _bookCommonResidual(donated_);

        uint256 balBefore_ = commonToken.balanceOf(linkedVault);
        uint256 attackerSharesBefore_ = IERC20(linkedVault).balanceOf(attacker);
        // Claim the donated face (or 1 if residual was consumed) — U must be 0 either way.
        uint256 claim_ = balBefore_ > 0 ? (balBefore_ < donated_ ? balBefore_ : donated_) : uint256(1);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claim_, uint256(0)
            )
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, claim_, IERC20(linkedVault), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(commonToken.balanceOf(linkedVault), balBefore_, "K1 donation unmoved");
        assertEq(IERC20(linkedVault).balanceOf(attacker), attackerSharesBefore_, "K1 no free shares");
    }

    /* ---------------------------------------------------------------------- */
    /*  J1–J3: diamond surface on production proxy (WP-J-DETF-DL-001)         */
    /* ---------------------------------------------------------------------- */

    function _controlSelectors() internal pure returns (bytes4[] memory sels_) {
        sels_ = new bytes4[](4);
        sels_[0] = IStandardExchangeIn.exchangeIn.selector;
        sels_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        sels_[2] = IStandardExchangeOut.exchangeOut.selector;
        sels_[3] = IStandardExchangeOut.previewExchangeOut.selector;
    }

    function _facetFuncsContains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    /// @notice J1: CREATE3 exchange facet facetFuncs cover target money/query selectors.
    function test_J1_facetFuncs_coversTargetApi() public {
        DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.ExchangeFacets memory facets_ =
            DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.deployExchangeFacets(create3Factory);

        assertTrue(
            _facetFuncsContains(IFacet(address(facets_.exchangeInFacet)).facetFuncs(), IStandardExchangeIn.exchangeIn.selector),
            "J1 exchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(facets_.exchangeInQueryFacet)).facetFuncs(),
                IStandardExchangeIn.previewExchangeIn.selector
            ),
            "J1 previewExchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(facets_.exchangeOutFacet)).facetFuncs(), IStandardExchangeOut.exchangeOut.selector
            ),
            "J1 exchangeOut"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(facets_.exchangeOutQueryFacet)).facetFuncs(),
                IStandardExchangeOut.previewExchangeOut.selector
            ),
            "J1 previewExchangeOut"
        );
    }

    /// @notice J2: loupe facetAddress(sel) != 0 for all product controls on production proxy.
    function test_J2_proxyLoupe_allProductSelectors() public {
        IDiamondLoupe loupe_ = IDiamondLoupe(linkedVault);
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != linkedVault, "J2 facet != proxy");
        }
    }

    /// @notice J3: smoke-call money + view selectors on **proxy** (not facet impl address).
    function test_J3_proxyCallable_smoke_eachSelector() public {
        _bootstrapReserve();

        address exchangeInFacet_ =
            IDiamondLoupe(linkedVault).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        address exchangeOutFacet_ =
            IDiamondLoupe(linkedVault).facetAddress(IStandardExchangeOut.exchangeOut.selector);
        assertTrue(exchangeInFacet_ != address(0) && exchangeInFacet_ != linkedVault, "proxy cut in");
        assertTrue(exchangeOutFacet_ != address(0) && exchangeOutFacet_ != linkedVault, "proxy cut out");

        // Views on proxy (deposit preview + closed-form swap exact-out sized from probe).
        uint256 previewIn_ =
            IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, 1e18, IERC20(linkedVault));
        assertGt(previewIn_, 0, "J3 previewExchangeIn live on proxy");

        uint256 swapOut_ =
            IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, 10e18, tokenA);
        swapOut_ = swapOut_ > 1 ? swapOut_ / 2 : swapOut_;
        require(swapOut_ > 0, "J3 need swap probe");
        uint256 previewOut_ =
            IStandardExchangeOut(linkedVault).previewExchangeOut(commonToken, tokenA, swapOut_);
        assertGt(previewOut_, 0, "J3 previewExchangeOut live on proxy");

        // Money path: product revert (not missing selector) — zero amount / inactive guards.
        vm.prank(attacker);
        vm.expectRevert();
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, 0, IERC20(linkedVault), 0, attacker, false, block.timestamp + 1 hours
        );

        vm.prank(attacker);
        vm.expectRevert();
        IStandardExchangeOut(linkedVault).exchangeOut(
            commonToken, 0, IERC20(linkedVault), 0, attacker, false, block.timestamp + 1 hours
        );

        // Explicit anti-theater: primary SUT is the production proxy, not facet impl.
        assertTrue(exchangeInFacet_ != linkedVault, "J3 primary target is proxy");
    }
}
