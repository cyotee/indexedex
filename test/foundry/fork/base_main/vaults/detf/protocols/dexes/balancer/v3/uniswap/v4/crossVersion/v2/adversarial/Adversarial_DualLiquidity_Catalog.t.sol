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

/// @notice DualLiquidity adversarial catalog fill + ID map of existing security suites.
/// @dev Existing coverage (do not duplicate):
///      - A0: Adversarial_DualLiquidity_A0 (idle reserveBpt first mint) — not ShareInflation
///      - A3-class: DualLiquidity..._ShareInflation (post-bootstrap BPT donation) — NOT I1/K1
///      - C-class: DualLiquidity..._Reentrancy / _ReentrancyRedeem
///      - E/H residual: DualLiquidity..._Residual
///      - F immutability: DualLiquidity..._Immutability
///      - B rate: DualLiquidity..._RateExtremes
///      - Guards: DualLiquidity..._Guards
/// @dev Same-tx delta law **B** (`SEC-DETF-DL-003`): I1–I3/K1 do **not** use MultiAsset `R`
///      (`commonToken` is not on `vaultTokens()`; package never `_updateReserve`s face tokens).
///      ShareInflation is A3 only. Happy `pretransferred=true` with a real in-call transfer is not I.
/// @dev Deferred: D2–D6 / F2–F3 (no bond NFT / claim); L2 FoT not claimed; I5 Permit2 verify is
///      router-owned; M* no user `target+calldata`.
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

    function test_H3_failedMint_minOut_leavesNoInventoryOnVault() public {
        _bootstrapReserve();
        uint256 supplyBefore_ = IERC20(linkedVault).totalSupply();
        uint256 commonBefore_ = commonToken.balanceOf(linkedVault);
        _fund(commonToken, attacker, LEG_SEED);
        vm.startPrank(attacker);
        commonToken.approve(linkedVault, LEG_SEED);
        vm.expectRevert();
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, LEG_SEED, IERC20(linkedVault), type(uint256).max, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(IERC20(linkedVault).totalSupply(), supplyBefore_, "H3: supply unchanged on fail");
        assertEq(IERC20(linkedVault).balanceOf(linkedVault), 0, "H3: no free vault shares on diamond");
        assertEq(commonToken.balanceOf(linkedVault), commonBefore_, "H3: no stranded commonToken");
        assertEq(commonToken.balanceOf(attacker), LEG_SEED, "H3: attacker input returned");
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
    /*  I1–I3 / K1 — same-tx delta (law B). No MultiAsset R / hold-set.       */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 mint: diamond already holds inventory; attacker `true` with **no** transfer.
    function test_I1_pretransferred_mint_inventoryNoInCallTransfer_revertsDelta0() public {
        _bootstrapReserve();
        _fund(commonToken, linkedVault, CLAIMED);

        assertEq(commonToken.balanceOf(attacker), 0);
        assertEq(commonToken.allowance(attacker, linkedVault), 0);

        uint256 balBefore_ = commonToken.balanceOf(linkedVault);
        uint256 attackerSharesBefore_ = IERC20(linkedVault).balanceOf(attacker);
        uint256 supplyBefore_ = IERC20(linkedVault).totalSupply();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, CLAIMED, IERC20(linkedVault), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(commonToken.balanceOf(linkedVault), balBefore_, "I1 must not move inventory");
        assertEq(IERC20(linkedVault).balanceOf(attacker), attackerSharesBefore_, "I1: no free share mint");
        assertEq(IERC20(linkedVault).totalSupply(), supplyBefore_, "I1: supply unchanged");
    }

    /// @notice I1: two-tx push then `true` is **not** durable U — same-tx snapshot is 0.
    function test_I1_twoTx_pushThenTrue_revertsDelta0() public {
        _bootstrapReserve();
        _fund(tokenB, attacker, LEG_SEED);
        vm.prank(attacker);
        tokenB.transfer(linkedVault, LEG_SEED);

        uint256 sharesBefore_ = IERC20(linkedVault).balanceOf(attacker);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, LEG_SEED, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            tokenB, LEG_SEED, IERC20(linkedVault), 0, attacker, true, block.timestamp
        );
        assertEq(IERC20(linkedVault).balanceOf(attacker), sharesBefore_, "I1 two-tx: no mint");
        assertEq(tokenB.balanceOf(linkedVault), LEG_SEED, "I1 two-tx: inventory sticks (accepted under B)");
    }

    /// @notice I1: Permit2 prefund into the diamond then `true` reverts (not a happy path).
    function test_I1_permit2PrefundThenTrue_revertsDelta0() public {
        _bootstrapReserve();
        _permit2PrefundVault(attacker, commonToken, CLAIMED);
        assertEq(commonToken.balanceOf(linkedVault), CLAIMED);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, CLAIMED, IERC20(linkedVault), 0, attacker, true, block.timestamp
        );
        assertEq(IERC20(linkedVault).balanceOf(attacker), 0, "I1 Permit2-true: no shares");
        assertEq(commonToken.balanceOf(linkedVault), CLAIMED, "I1 Permit2-true: prefund stuck");
    }

    /// @notice I1 receiveOut: donated inventory + exact-out `true` without in-call push.
    function test_I1_pretransferred_receiveOut_inventoryNoInCallTransfer_revertsDelta0() public {
        _bootstrapReserve();

        uint256 probeIn_ = 50e18;
        uint256 amountOut_ = IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, probeIn_, tokenA);
        amountOut_ = amountOut_ > 1 ? amountOut_ / 2 : amountOut_;
        require(amountOut_ > 0, "need positive swap out");

        uint256 maxIn_ = IStandardExchangeOut(linkedVault).previewExchangeOut(commonToken, tokenA, amountOut_);
        require(maxIn_ > 0, "need positive exact-out quote");

        _fund(commonToken, linkedVault, maxIn_ * 3);

        uint256 balBefore_ = commonToken.balanceOf(linkedVault);
        uint256 attackerOutBefore_ = tokenA.balanceOf(attacker);
        uint256 attackerTokenBefore_ = commonToken.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, maxIn_, uint256(0))
        );
        IStandardExchangeOut(linkedVault).exchangeOut(
            commonToken, maxIn_, tokenA, amountOut_, attacker, true, block.timestamp + 1 hours
        );

        assertEq(commonToken.balanceOf(linkedVault), balBefore_, "I1 out: inventory unmoved");
        assertEq(tokenA.balanceOf(attacker), attackerOutBefore_, "I1 out: no free tokenOut");
        assertEq(commonToken.balanceOf(attacker), attackerTokenBefore_, "I1 out: no surplus refund theft");
    }

    /// @notice I2 collapses to I1 under same-tx law (no in-window push ⇒ delta 0).
    function test_I2_pretransferred_mint_claimedGtDelta0_reverts() public {
        _bootstrapReserve();
        _fund(commonToken, linkedVault, RESIDUAL);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, CLAIMED, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, CLAIMED, IERC20(linkedVault), 0, attacker, true, block.timestamp + 1 hours
        );
    }

    /// @notice I2 receiveOut: same-tx short (delta 0) ≡ I1.
    function test_I2_pretransferred_receiveOut_claimedGtDelta0_reverts() public {
        _bootstrapReserve();

        uint256 probeIn_ = 50e18;
        uint256 amountOut_ = IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, probeIn_, tokenA);
        amountOut_ = amountOut_ > 1 ? amountOut_ / 2 : amountOut_;
        require(amountOut_ > 0, "need positive swap out");

        uint256 maxIn_ = IStandardExchangeOut(linkedVault).previewExchangeOut(commonToken, tokenA, amountOut_);
        require(maxIn_ > 0, "need positive exact-out quote");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, maxIn_, uint256(0))
        );
        IStandardExchangeOut(linkedVault).exchangeOut(
            commonToken, maxIn_, tokenA, amountOut_, attacker, true, block.timestamp + 1 hours
        );
    }

    /// @notice I3: after an honest `!pretransferred` mint, a second `true` cannot free-credit residual.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer_mint() public {
        _bootstrapReserve();
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
        uint256 claim_ = residual_ > 0 ? residual_ : uint256(1);

        uint256 attackerSharesBefore_ = IERC20(linkedVault).balanceOf(attacker);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claim_, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, claim_, IERC20(linkedVault), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(commonToken.balanceOf(linkedVault), residual_, "I3 residual unmoved");
        assertEq(IERC20(linkedVault).balanceOf(attacker), attackerSharesBefore_, "I3 no free mint");
    }

    /// @notice Positive control: honest `!pretransferred` deposit (in-call transferFrom) succeeds.
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

    /// @notice K1: donate `commonToken` then `true` without transfer — no free credit. Not ShareInflation.
    function test_K1_donation_cannotFundPretransferCredit_mint() public {
        _bootstrapReserve();
        uint256 donated_ = CLAIMED;
        _fund(commonToken, linkedVault, donated_);

        uint256 balBefore_ = commonToken.balanceOf(linkedVault);
        uint256 attackerSharesBefore_ = IERC20(linkedVault).balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, donated_, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, donated_, IERC20(linkedVault), 0, attacker, true, block.timestamp + 1 hours
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
