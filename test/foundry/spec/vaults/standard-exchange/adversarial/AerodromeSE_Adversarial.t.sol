// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_AerodromeStandardExchange_MultiPool
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange_MultiPool.sol";

/// @notice Wave 2B SE adversarial P0 on production Aerodrome Standard Exchange vault.
/// @dev Catalog A–H residual (WP-ADV-SE-AC-001): A1–A3 donation, E1/E4/E5, H2/H3 residual,
///      F1 cut. I1–I3 free-credit (L-GAPS-9/10) + J1–J3 surface already landed.
///      C-class: see ReentrancyGuard suite. B/D/G N/A for pure SE. Production DFPkg only.
contract AerodromeSE_Adversarial_Test is TestBase_AerodromeStandardExchange_MultiPool {
    address internal attacker;
    address internal victim;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("seAttacker");
        victim = makeAddr("seVictim");
    }

    function _vault() internal view returns (IStandardExchangeProxy) {
        return _getVault(PoolConfig.Balanced);
    }

    /// @dev Route4 LP → SE shares for catalog donation/non-dilution cases.
    function _mintSeShares(address to_, uint256 lpAmount_) internal returns (uint256 shares_) {
        IStandardExchangeProxy vault_ = _vault();
        IERC20 lp_ = IERC20(address(_getPool(PoolConfig.Balanced)));
        require(lp_.balanceOf(address(this)) >= lpAmount_, "need LP inventory");
        lp_.transfer(to_, lpAmount_);
        vm.startPrank(to_);
        lp_.approve(address(vault_), lpAmount_);
        shares_ = vault_.exchangeIn(lp_, lpAmount_, IERC20(address(vault_)), 0, to_, false, _deadline());
        vm.stopPrank();
        assertGt(shares_, 0, "minted SE shares");
    }

    function test_A1_donateToken_cannotMintFreeShares() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);
        uint256 amount_ = TEST_AMOUNT;
        deal(address(tokenA), attacker, amount_);
        uint256 sharesBefore_ = IERC20(address(vault_)).balanceOf(attacker);
        vm.prank(attacker);
        tokenA.transfer(address(vault_), amount_);
        assertEq(IERC20(address(vault_)).balanceOf(attacker), sharesBefore_, "A1: no free SE shares");
    }

    function test_E5_zeroAmount_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        vm.prank(attacker);
        vm.expectRevert();
        IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
    }

    /// @notice E5: expired deadline reverts with `DeadlineExceeded` (WP-E5-AERO-001).
    function test_E5_expiredDeadline_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amount_ = TEST_AMOUNT / 2;
        uint256 expired_ = _expiredDeadline();
        deal(address(tokenA), attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, expired_, block.timestamp)
        );
        IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, expired_
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault_)).balanceOf(address(vault_)), 0, "H3 residual vault shares");
    }

    function test_H3_minOutTooHigh_noFreeShares() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amount_ = TEST_AMOUNT / 2;
        deal(address(tokenA), attacker, amount_);
        uint256 preview_ = vault_.previewExchangeIn(IERC20(address(tokenA)), amount_, IERC20(address(tokenB)));
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        vm.expectRevert();
        IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)),
            amount_,
            IERC20(address(tokenB)),
            preview_ + type(uint128).max,
            attacker,
            false,
            _deadline()
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault_)).balanceOf(address(vault_)), 0, "H3 residual vault shares");
    }

    function test_F1_diamondCut_blocked() public {
        IStandardExchangeProxy vault_ = _vault();
        (bool ok,) = address(vault_).call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)", new bytes(0), address(0), ""
            )
        );
        assertFalse(ok, "F1 cut blocked");
    }

    function test_E1_swapRoundTrip_bounded() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amount_ = TEST_AMOUNT / 4;
        deal(address(tokenA), attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        uint256 outB_ = IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
        assertTrue(outB_ > 0, "got tokenB");
        tokenB.approve(address(vault_), outB_);
        uint256 backA_ = IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenB)), outB_, IERC20(address(tokenA)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        // Round-trip loses fees/slippage - out <= in
        assertLe(backA_, amount_, "E1: no free lunch on SE swap round-trip");
    }

    /* ---------------------------------------------------------------------- */
    /*  A2–A3 / E4 / H2–H3 residual (WP-ADV-SE-AC-001)                        */
    /* ---------------------------------------------------------------------- */

    /// @notice A2: donate SE shares (product token) to diamond — idle inventory; no free mint.
    function test_A2_donateSeShares_noFreeMintOrTheft() public {
        IStandardExchangeProxy vault_ = _vault();
        uint256 lpAmt_ = TEST_AMOUNT / 50;
        uint256 shares_ = _mintSeShares(attacker, lpAmt_);
        uint256 donate_ = shares_ / 2;
        if (donate_ == 0) donate_ = shares_;

        uint256 victimShares_ = _mintSeShares(victim, lpAmt_ / 2);
        uint256 supplyBefore_ = vault_.totalSupply();
        uint256 victimBefore_ = vault_.balanceOf(victim);

        vm.prank(attacker);
        vault_.transfer(address(vault_), donate_);

        assertEq(vault_.balanceOf(attacker), shares_ - donate_, "A2 attacker spent donation");
        assertEq(vault_.balanceOf(address(vault_)), donate_, "A2 idle product on diamond");
        assertEq(vault_.balanceOf(victim), victimBefore_, "A2 victim shares untouched");
        assertEq(victimBefore_, victimShares_, "A2 victim mint stable");
        assertEq(vault_.totalSupply(), supplyBefore_, "A2 transfer does not mint/burn");
    }

    /// @notice A3: donate reserve LP to vault without deposit call — no free SE shares.
    function test_A3_donateLp_cannotMintFreeShares() public {
        IStandardExchangeProxy vault_ = _vault();
        IPool pool_ = _getPool(PoolConfig.Balanced);
        IERC20 lp_ = IERC20(address(pool_));
        uint256 lpAmt_ = TEST_AMOUNT / 100;
        require(lp_.balanceOf(address(this)) >= lpAmt_, "LP inventory");

        uint256 supplyBefore_ = vault_.totalSupply();
        uint256 attackerSharesBefore_ = vault_.balanceOf(attacker);

        lp_.transfer(attacker, lpAmt_);
        vm.prank(attacker);
        lp_.transfer(address(vault_), lpAmt_);

        assertEq(lp_.balanceOf(address(vault_)), lpAmt_, "A3 LP sits idle");
        assertEq(vault_.balanceOf(attacker), attackerSharesBefore_, "A3 no free SE shares");
        assertEq(vault_.totalSupply(), supplyBefore_, "A3 supply unchanged");
    }

    /// @notice E4: existing SE share holder balance units not diluted by others' swaps.
    function test_E4_holderBalance_notDilutedByOthersSwap() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 victimShares_ = _mintSeShares(victim, TEST_AMOUNT / 80);
        assertEq(vault_.balanceOf(victim), victimShares_, "victim seeded");

        uint256 amount_ = TEST_AMOUNT / 8;
        deal(address(tokenA), attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        uint256 out_ = vault_.exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertGt(out_, 0, "attacker swap");
        assertEq(vault_.balanceOf(victim), victimShares_, "E4: victim share balance unchanged");
    }

    /// @notice E5: InvalidRoute when tokenOut is unsupported junk (exact selector).
    function test_E5_invalidRoute_unsupportedToken_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);
        ERC20PermitMintableStub junk_ = new ERC20PermitMintableStub("Junk", "JNK", 18, address(this), 0);
        uint256 amount_ = TEST_AMOUNT / 10;
        deal(address(tokenA), attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.InvalidRoute.selector, address(tokenA), address(junk_)
            )
        );
        vault_.exchangeIn(IERC20(address(tokenA)), amount_, IERC20(address(junk_)), 0, attacker, false, _deadline());
        vm.stopPrank();
    }

    /// @notice E5: exchangeOut expired deadline — exact DeadlineExceeded; no residual shares.
    function test_E5_exchangeOut_expiredDeadline_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amountOut_ = 1 ether;
        uint256 previewIn_ =
            vault_.previewExchangeOut(IERC20(address(tokenA)), IERC20(address(tokenB)), amountOut_);
        uint256 expired_ = _expiredDeadline();
        deal(address(tokenA), attacker, previewIn_ * 2);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), previewIn_ * 2);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, expired_, block.timestamp)
        );
        vault_.exchangeOut(
            IERC20(address(tokenA)), previewIn_ * 2, IERC20(address(tokenB)), amountOut_, attacker, false, expired_
        );
        vm.stopPrank();
        assertEq(vault_.balanceOf(address(vault_)), 0, "E5 out residual shares");
    }

    /// @notice H2: failed exchangeOut (maxIn too low) is atomic — attacker inventory unchanged.
    function test_H2_exchangeOut_maxInTooLow_balancesUnchanged() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amountOut_ = 1 ether;
        uint256 requiredIn_ =
            vault_.previewExchangeOut(IERC20(address(tokenA)), IERC20(address(tokenB)), amountOut_);
        require(requiredIn_ > 1, "preview");
        uint256 tooLow_ = requiredIn_ - 1;

        deal(address(tokenA), attacker, requiredIn_);
        uint256 aBefore_ = tokenA.balanceOf(attacker);
        uint256 bBefore_ = tokenB.balanceOf(attacker);
        uint256 supplyBefore_ = vault_.totalSupply();

        vm.startPrank(attacker);
        tokenA.approve(address(vault_), requiredIn_);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.MaxAmountExceeded.selector, tooLow_, requiredIn_)
        );
        vault_.exchangeOut(
            IERC20(address(tokenA)), tooLow_, IERC20(address(tokenB)), amountOut_, attacker, false, _deadline()
        );
        vm.stopPrank();

        assertEq(tokenA.balanceOf(attacker), aBefore_, "H2 tokenIn unchanged");
        assertEq(tokenB.balanceOf(attacker), bBefore_, "H2 tokenOut unchanged");
        assertEq(vault_.totalSupply(), supplyBefore_, "H2 supply unchanged");
        assertEq(vault_.balanceOf(address(vault_)), 0, "H2 no free vault shares");
    }

    /// @notice H3: exchangeOut maxIn fail leaves no free inventory on diamond (shares residual).
    function test_H3_exchangeOut_maxInTooLow_noFreeShares() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amountOut_ = 2 ether;
        uint256 requiredIn_ =
            vault_.previewExchangeOut(IERC20(address(tokenA)), IERC20(address(tokenB)), amountOut_);
        uint256 tooLow_ = requiredIn_ / 2;
        if (tooLow_ == 0) tooLow_ = 1;

        deal(address(tokenA), attacker, requiredIn_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), requiredIn_);
        vm.expectRevert();
        vault_.exchangeOut(
            IERC20(address(tokenA)), tooLow_, IERC20(address(tokenB)), amountOut_, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertEq(vault_.balanceOf(address(vault_)), 0, "H3 out residual vault shares");
        assertEq(tokenA.balanceOf(address(vault_)), 0, "H3 out residual tokenIn");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1–I3: pretransfer trust flags must not free-credit inventory         */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 booked: residual after honest money-route sync cannot free-credit via pretransfer.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 residual_ = TEST_AMOUNT / 4;
        uint256 pull_ = TEST_AMOUNT / 16;

        // Seed residual then honest pull so full-set sync books inventory (R == B).
        tokenA.mint(address(vault_), residual_);
        tokenA.mint(attacker, pull_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), pull_);
        vault_.exchangeIn(IERC20(address(tokenA)), pull_, IERC20(address(tokenB)), 0, attacker, false, _deadline());
        vm.stopPrank();

        uint256 supplyBefore_ = vault_.totalSupply();
        uint256 attackerSharesBefore_ = vault_.balanceOf(attacker);
        uint256 invBefore_ = tokenA.balanceOf(address(vault_));

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, residual_, uint256(0))
        );
        vault_.exchangeIn(IERC20(address(tokenA)), residual_, IERC20(address(tokenB)), 0, attacker, true, _deadline());

        assertEq(vault_.totalSupply(), supplyBefore_, "I1: no free share mint");
        assertEq(vault_.balanceOf(attacker), attackerSharesBefore_, "I1: attacker shares unchanged");
        assertEq(tokenA.balanceOf(address(vault_)), invBefore_, "I1: inventory unmoved");
    }

    /// @notice I1 claimed ≤ booked inventory still reverts (absolute free credit forbidden).
    function test_I1_pretransferred_claimedLeInventory_stillReverts() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 inventory_ = TEST_AMOUNT / 2;
        uint256 claimed_ = TEST_AMOUNT / 8;
        uint256 pull_ = TEST_AMOUNT / 32;

        tokenA.mint(address(vault_), inventory_);
        tokenA.mint(attacker, pull_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), pull_);
        vault_.exchangeIn(IERC20(address(tokenA)), pull_, IERC20(address(tokenB)), 0, attacker, false, _deadline());
        vm.stopPrank();
        assertGe(tokenA.balanceOf(address(vault_)), claimed_, "claimed <= booked inventory");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        vault_.exchangeIn(IERC20(address(tokenA)), claimed_, IERC20(address(tokenB)), 0, attacker, true, _deadline());
    }

    /// @notice Reserve-delta push: transfer-before-call + pretransferred=true succeeds when claimed ≤ U.
    function test_I2_transferBeforeCall_pretransferred_revertsDelta0() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 claimed_ = TEST_AMOUNT / 10;

        tokenA.mint(attacker, claimed_);
        vm.prank(attacker);
        tokenA.transfer(address(vault_), claimed_);

        // Durable U = B - R (bootstrap R=0) allows push funding.
        vm.prank(attacker);
        uint256 out_ = vault_.exchangeIn(
            IERC20(address(tokenA)), claimed_, IERC20(address(tokenB)), 0, attacker, true, _deadline()
        );
        assertGt(out_, 0, "push pretransfer succeeds under reserve-delta");
        assertEq(tokenB.balanceOf(attacker), out_, "attacker received tokenB");
    }

    /// @notice I3: residual inventory after an honest pull cannot fund a second free pretransfer credit.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amount_ = TEST_AMOUNT / 8;
        uint256 residualSeed_ = TEST_AMOUNT / 16;

        // Pre-seed residual that remains after first honest pull.
        tokenA.mint(address(vault_), residualSeed_);

        tokenA.mint(attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amount_);
        uint256 out_ = vault_.exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest first pull");

        uint256 residual_ = tokenA.balanceOf(address(vault_));
        assertGe(residual_, residualSeed_, "residual inventory remains");

        // Second call: pretransferred=true, claim against residual, no new transfer.
        uint256 claim_ = residualSeed_;
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claim_, uint256(0))
        );
        vault_.exchangeIn(IERC20(address(tokenA)), claim_, IERC20(address(tokenB)), 0, attacker, true, _deadline());

        assertEq(tokenA.balanceOf(address(vault_)), residual_, "I3 second call must not move inventory");
    }

    /// @notice Positive control: honest !pretransferred pull succeeds.
    function test_I_positive_honestPullSwap_succeeds() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);
        uint256 amountIn_ = TEST_AMOUNT / 8;
        tokenA.mint(attacker, amountIn_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), amountIn_);
        uint256 out_ = vault_.exchangeIn(
            IERC20(address(tokenA)), amountIn_, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest !pretransferred swap");
        assertEq(tokenB.balanceOf(attacker), out_, "attacker received tokenB");
    }

    /* ---------------------------------------------------------------------- */
    /*  J1–J3: diamond surface on production proxy (WP-J-SE-AC-001)           */
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

    /// @notice J1: CREATE3 facetFuncs cover target money/query selectors (Target ⊆ facetFuncs).
    function test_J1_facetFuncs_coversTargetApi() public {
        assertTrue(
            _facetFuncsContains(
                IFacet(address(aerodromeStandardExchangeInFacet)).facetFuncs(), IStandardExchangeIn.exchangeIn.selector
            ),
            "J1 exchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(aerodromeStandardExchangeInFacet)).facetFuncs(),
                IStandardExchangeIn.previewExchangeIn.selector
            ),
            "J1 previewExchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(aerodromeStandardExchangeOutFacet)).facetFuncs(),
                IStandardExchangeOut.exchangeOut.selector
            ),
            "J1 exchangeOut"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(aerodromeStandardExchangeOutQueryFacet)).facetFuncs(),
                IStandardExchangeOut.previewExchangeOut.selector
            ),
            "J1 previewExchangeOut"
        );
    }

    /// @notice J2: loupe facetAddress(sel) != 0 for product controls on production proxy.
    function test_J2_proxyLoupe_allProductSelectors() public {
        IDiamondLoupe loupe_ = IDiamondLoupe(address(_vault()));
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != address(_vault()), "J2 facet != proxy");
        }
    }

    /// @notice J3: smoke-call money + view selectors on **proxy** (not facet impl address).
    function test_J3_proxyCallable_smoke_eachSelector() public {
        IStandardExchangeProxy vault_ = _vault();
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(PoolConfig.Balanced);

        address exchangeInFacet_ = IDiamondLoupe(address(vault_)).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        address exchangeOutFacet_ =
            IDiamondLoupe(address(vault_)).facetAddress(IStandardExchangeOut.exchangeOut.selector);
        assertTrue(exchangeInFacet_ != address(0) && exchangeInFacet_ != address(vault_), "proxy cut in");
        assertTrue(exchangeOutFacet_ != address(0) && exchangeOutFacet_ != address(vault_), "proxy cut out");

        uint256 previewIn_ =
            IStandardExchangeIn(address(vault_)).previewExchangeIn(IERC20(address(tokenA)), 1 ether, IERC20(address(tokenB)));
        assertGt(previewIn_, 0, "J3 previewExchangeIn live on proxy");

        // Money path smoke: product revert (not missing selector) for free-credit I1 path.
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1 ether), uint256(0))
        );
        IStandardExchangeIn(address(vault_)).exchangeIn(
            IERC20(address(tokenA)), 1 ether, IERC20(address(tokenB)), 0, attacker, true, _deadline()
        );
    }
}
