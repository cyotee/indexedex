// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_CamelotV2StandardExchange_Decimals} from
    "contracts/protocols/dexes/camelot/v2/test/bases/TestBase_CamelotV2StandardExchange_Decimals.sol";

/**
 * @title CamelotSE_Adversarial_Decimals
 * @notice Wave 2B SE adversarial P0 on combo decimals. pairToken = tokenA.
 * @dev After Camelot pair address sort, token0/token1 may swap; roles stay pairToken vs other.
 *      vaultShare stays 18. EX-J: test_J1/J2/J3 facet/loupe/proxy smoke are not cloned.
 */
abstract contract CamelotSE_Adversarial_Decimals is TestBase_CamelotV2StandardExchange_Decimals {
    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    IStandardExchangeProxy internal vault;
    ICamelotPair internal pair;
    address internal attacker;
    address internal victim;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("camelotSeAttacker");
        victim = makeAddr("camelotSeVictim");
        tokenA = new MintableERC20Decimals("Token A", "TKNA", _tokenADecimals());
        tokenB = new MintableERC20Decimals("Token B", "TKNB", _tokenBDecimals());
        tokenA.mint(address(this), _uA(10_000));
        tokenB.mint(address(this), _uB(10_000));

        vm.label(address(tokenA), "pairToken-tokenA");
        vm.label(address(tokenB), "otherToken-tokenB");

        uint256 seedA = _uA(1000);
        uint256 seedB = _uB(1000);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), seedA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), seedB);
        vault = IStandardExchangeProxy(
            camelotV2StandardExchangeDFPkg.deployVault(
                IERC20(address(tokenA)), seedA, IERC20(address(tokenB)), seedB, address(this)
            )
        );
        pair = ICamelotPair(camelotV2Factory.getPair(address(tokenA), address(tokenB)));
        require(address(pair) != address(0), "pair");
        uint256 lpSeedA = _uA(500);
        uint256 lpSeedB = _uB(500);
        tokenA.approve(address(camelotV2Router), lpSeedA);
        tokenB.approve(address(camelotV2Router), lpSeedB);
        camelotV2Router.addLiquidity(
            address(tokenA), address(tokenB), lpSeedA, lpSeedB, 1, 1, address(this), _deadline()
        );
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _expiredDeadline() internal view returns (uint256) {
        return block.timestamp - 1;
    }

    /// @dev Route4 LP → SE shares for catalog donation/non-dilution cases.
    function _mintSeShares(address to_, uint256 lpAmount_) internal returns (uint256 shares_) {
        IERC20 lp_ = IERC20(address(pair));
        require(lp_.balanceOf(address(this)) >= lpAmount_, "need LP inventory");
        lp_.transfer(to_, lpAmount_);
        vm.startPrank(to_);
        lp_.approve(address(vault), lpAmount_);
        shares_ = vault.exchangeIn(lp_, lpAmount_, IERC20(address(vault)), 0, to_, false, _deadline());
        vm.stopPrank();
        assertGt(shares_, 0, "minted SE shares");
    }

    function test_A1_donateToken_cannotMintFreeShares() public {
        uint256 amount_ = _uA(50);
        tokenA.mint(attacker, amount_);
        uint256 sharesBefore_ = IERC20(address(vault)).balanceOf(attacker);
        vm.prank(attacker);
        tokenA.transfer(address(vault), amount_);
        assertEq(IERC20(address(vault)).balanceOf(attacker), sharesBefore_, "A1: no free SE shares");
    }

    function test_E5_zeroAmount_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
    }

    function test_F1_diamondCut_blocked() public {
        (bool ok,) = address(vault).call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)", new bytes(0), address(0), ""
            )
        );
        assertFalse(ok, "F1 cut blocked");
    }

    /// @notice H3: failed Route1 minOut leaves no free vault share inventory. Amount `_uA(50)`.
    function test_H3_minOutTooHigh_noFreeShares() public {
        uint256 amount_ = _uA(50);
        tokenA.mint(attacker, amount_);
        uint256 preview_ = vault.previewExchangeIn(IERC20(address(tokenA)), amount_, IERC20(address(tokenB)));
        vm.startPrank(attacker);
        tokenA.approve(address(vault), amount_);
        vm.expectRevert();
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(tokenA)),
            amount_,
            IERC20(address(tokenB)),
            preview_ + type(uint128).max,
            attacker,
            false,
            _deadline()
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), 0, "H3 residual");
    }

    /* ---------------------------------------------------------------------- */
    /*  A2–A3 / E1 / E4 / E5 / H2–H3 residual (WP-ADV-SE-AC-001)              */
    /* ---------------------------------------------------------------------- */

    /// @notice A2: donate SE shares (product token) to diamond — idle inventory; no free mint.
    function test_A2_donateSeShares_noFreeMintOrTheft() public {
        uint256 lpAmt_ = IERC20(address(pair)).balanceOf(address(this)) / 20;
        require(lpAmt_ > MIN_TEST_AMOUNT, "lp");
        uint256 shares_ = _mintSeShares(attacker, lpAmt_);
        uint256 donate_ = shares_ / 2;
        if (donate_ == 0) donate_ = shares_;

        uint256 victimShares_ = _mintSeShares(victim, lpAmt_ / 2);
        uint256 supplyBefore_ = vault.totalSupply();
        uint256 victimBefore_ = vault.balanceOf(victim);

        vm.prank(attacker);
        vault.transfer(address(vault), donate_);

        assertEq(vault.balanceOf(attacker), shares_ - donate_, "A2 attacker spent donation");
        assertEq(vault.balanceOf(address(vault)), donate_, "A2 idle product on diamond");
        assertEq(vault.balanceOf(victim), victimBefore_, "A2 victim shares untouched");
        assertEq(victimBefore_, victimShares_, "A2 victim mint stable");
        assertEq(vault.totalSupply(), supplyBefore_, "A2 transfer does not mint/burn");
    }

    /// @notice A3: donate reserve LP to vault without deposit call — no free SE shares.
    function test_A3_donateLp_cannotMintFreeShares() public {
        IERC20 lp_ = IERC20(address(pair));
        uint256 lpAmt_ = lp_.balanceOf(address(this)) / 50;
        require(lpAmt_ > MIN_TEST_AMOUNT, "lp");

        uint256 supplyBefore_ = vault.totalSupply();
        uint256 attackerSharesBefore_ = vault.balanceOf(attacker);
        uint256 vaultLpBefore_ = lp_.balanceOf(address(vault));

        lp_.transfer(attacker, lpAmt_);
        vm.prank(attacker);
        lp_.transfer(address(vault), lpAmt_);

        assertEq(lp_.balanceOf(address(vault)), vaultLpBefore_ + lpAmt_, "A3 LP sits idle");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "A3 no free SE shares");
        assertEq(vault.totalSupply(), supplyBefore_, "A3 supply unchanged");
    }

    /// @notice E1: swap A→B→A conservation (fee-aware; no free lunch). Amount `_uA(25)`.
    function test_E1_swapRoundTrip_bounded() public {
        uint256 amount_ = _uA(25);
        tokenA.mint(attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault), amount_);
        uint256 outB_ = IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
        assertTrue(outB_ > 0, "got tokenB");
        tokenB.approve(address(vault), outB_);
        uint256 backA_ = IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(tokenB)), outB_, IERC20(address(tokenA)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertLe(backA_, amount_, "E1: no free lunch on SE swap round-trip");
    }

    /// @notice E4: existing SE share holder balance units not diluted by others' swaps.
    function test_E4_holderBalance_notDilutedByOthersSwap() public {
        uint256 lpAmt_ = IERC20(address(pair)).balanceOf(address(this)) / 30;
        require(lpAmt_ > MIN_TEST_AMOUNT, "lp");
        uint256 victimShares_ = _mintSeShares(victim, lpAmt_);
        assertEq(vault.balanceOf(victim), victimShares_, "victim seeded");

        uint256 amount_ = _uA(25);
        tokenA.mint(attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault), amount_);
        uint256 out_ = vault.exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertGt(out_, 0, "attacker swap");
        assertEq(vault.balanceOf(victim), victimShares_, "E4: victim share balance unchanged");
    }

    /// @notice E5: expired deadline reverts with DeadlineExceeded (Camelot parity).
    function test_E5_expiredDeadline_reverts() public {
        uint256 amount_ = _uA(25);
        uint256 expired_ = _expiredDeadline();
        tokenA.mint(attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault), amount_);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, expired_, block.timestamp)
        );
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, expired_
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), 0, "H3 residual vault shares");
    }

    /// @notice E5: InvalidRoute when tokenOut is unsupported junk (exact selector).
    function test_E5_invalidRoute_unsupportedToken_reverts() public {
        MintableERC20Decimals junk_ = new MintableERC20Decimals("Junk", "JNK", 18);
        uint256 amount_ = _uA(5);
        tokenA.mint(attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault), amount_);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(tokenA), address(junk_))
        );
        vault.exchangeIn(IERC20(address(tokenA)), amount_, IERC20(address(junk_)), 0, attacker, false, _deadline());
        vm.stopPrank();
    }

    /// @notice E5: exchangeOut expired deadline — exact DeadlineExceeded; no residual shares.
    /// @dev amountOut is `_uB(1)` of the other token.
    function test_E5_exchangeOut_expiredDeadline_reverts() public {
        uint256 amountOut_ = _uB(1);
        uint256 previewIn_ =
            vault.previewExchangeOut(IERC20(address(tokenA)), IERC20(address(tokenB)), amountOut_);
        uint256 expired_ = _expiredDeadline();
        tokenA.mint(attacker, previewIn_ * 2);
        vm.startPrank(attacker);
        tokenA.approve(address(vault), previewIn_ * 2);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, expired_, block.timestamp)
        );
        vault.exchangeOut(
            IERC20(address(tokenA)), previewIn_ * 2, IERC20(address(tokenB)), amountOut_, attacker, false, expired_
        );
        vm.stopPrank();
        assertEq(vault.balanceOf(address(vault)), 0, "E5 out residual shares");
    }

    /// @notice H2: failed exchangeOut (maxIn too low) is atomic — attacker inventory unchanged.
    /// @dev amountOut is `_uB(1)` of the other token; pairToken in is tokenA.
    function test_H2_exchangeOut_maxInTooLow_balancesUnchanged() public {
        uint256 amountOut_ = _uB(1);
        uint256 requiredIn_ =
            vault.previewExchangeOut(IERC20(address(tokenA)), IERC20(address(tokenB)), amountOut_);
        require(requiredIn_ > 1, "preview");
        uint256 tooLow_ = requiredIn_ / 4;
        if (tooLow_ == 0) tooLow_ = 1;

        tokenA.mint(attacker, requiredIn_);
        uint256 aBefore_ = tokenA.balanceOf(attacker);
        uint256 bBefore_ = tokenB.balanceOf(attacker);
        uint256 supplyBefore_ = vault.totalSupply();

        vm.startPrank(attacker);
        tokenA.approve(address(vault), requiredIn_);
        vm.expectRevert();
        vault.exchangeOut(
            IERC20(address(tokenA)), tooLow_, IERC20(address(tokenB)), amountOut_, attacker, false, _deadline()
        );
        vm.stopPrank();

        assertEq(tokenA.balanceOf(attacker), aBefore_, "H2 tokenIn unchanged");
        assertEq(tokenB.balanceOf(attacker), bBefore_, "H2 tokenOut unchanged");
        assertEq(vault.totalSupply(), supplyBefore_, "H2 supply unchanged");
        assertEq(vault.balanceOf(address(vault)), 0, "H2 no free vault shares");
    }

    /// @notice H3: exchangeOut maxIn fail leaves no free inventory on diamond.
    /// @dev amountOut is `_uB(2)` of the other token.
    function test_H3_exchangeOut_maxInTooLow_noFreeShares() public {
        uint256 amountOut_ = _uB(2);
        uint256 requiredIn_ =
            vault.previewExchangeOut(IERC20(address(tokenA)), IERC20(address(tokenB)), amountOut_);
        uint256 tooLow_ = requiredIn_ / 2;
        if (tooLow_ == 0) tooLow_ = 1;

        tokenA.mint(attacker, requiredIn_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault), requiredIn_);
        vm.expectRevert();
        vault.exchangeOut(
            IERC20(address(tokenA)), tooLow_, IERC20(address(tokenB)), amountOut_, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertEq(vault.balanceOf(address(vault)), 0, "H3 out residual vault shares");
        assertEq(tokenA.balanceOf(address(vault)), 0, "H3 out residual tokenIn");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1–I3: pretransfer trust flags must not free-credit inventory         */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 booked: residual after honest money-route sync cannot free-credit via pretransfer.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        uint256 residual_ = _uA(50);
        uint256 pull_ = _uA(5);

        tokenA.mint(address(vault), residual_);
        tokenA.mint(attacker, pull_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault), pull_);
        vault.exchangeIn(IERC20(address(tokenA)), pull_, IERC20(address(tokenB)), 0, attacker, false, _deadline());
        vm.stopPrank();

        uint256 supplyBefore_ = vault.totalSupply();
        uint256 attackerSharesBefore_ = vault.balanceOf(attacker);
        uint256 invBefore_ = tokenA.balanceOf(address(vault));

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, residual_, uint256(0))
        );
        vault.exchangeIn(IERC20(address(tokenA)), residual_, IERC20(address(tokenB)), 0, attacker, true, _deadline());

        assertEq(vault.totalSupply(), supplyBefore_, "I1: no free share mint");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "I1: attacker shares unchanged");
        assertEq(tokenA.balanceOf(address(vault)), invBefore_, "I1: inventory unmoved");
    }

    /// @notice I1 claimed ≤ booked inventory still reverts (absolute free credit forbidden).
    function test_I1_pretransferred_claimedLeInventory_stillReverts() public {
        uint256 inventory_ = _uA(100);
        uint256 claimed_ = _uA(25);
        uint256 pull_ = _uA(2);

        tokenA.mint(address(vault), inventory_);
        tokenA.mint(attacker, pull_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault), pull_);
        vault.exchangeIn(IERC20(address(tokenA)), pull_, IERC20(address(tokenB)), 0, attacker, false, _deadline());
        vm.stopPrank();
        assertGe(tokenA.balanceOf(address(vault)), claimed_, "claimed <= booked inventory");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        vault.exchangeIn(IERC20(address(tokenA)), claimed_, IERC20(address(tokenB)), 0, attacker, true, _deadline());
    }

    /// @notice Reserve-delta push: transfer-before-call + pretransferred=true succeeds when claimed ≤ U.
    function test_I2_transferBeforeCall_pretransferred_revertsDelta0() public {
        uint256 claimed_ = _uA(50);

        tokenA.mint(attacker, claimed_);
        vm.prank(attacker);
        tokenA.transfer(address(vault), claimed_);

        vm.prank(attacker);
        uint256 out_ = vault.exchangeIn(
            IERC20(address(tokenA)), claimed_, IERC20(address(tokenB)), 0, attacker, true, _deadline()
        );
        assertGt(out_, 0, "push pretransfer succeeds under reserve-delta");
        assertEq(tokenB.balanceOf(attacker), out_, "attacker received tokenB");
    }

    /// @notice I3: residual inventory after honest pull cannot fund second free pretransfer credit.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        uint256 amount_ = _uA(50);
        uint256 residualSeed_ = _uA(10);

        tokenA.mint(address(vault), residualSeed_);

        tokenA.mint(attacker, amount_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault), amount_);
        uint256 out_ = vault.exchangeIn(
            IERC20(address(tokenA)), amount_, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest first pull");

        uint256 residual_ = tokenA.balanceOf(address(vault));
        assertGe(residual_, residualSeed_, "residual inventory remains");

        uint256 claim_ = residualSeed_;
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claim_, uint256(0))
        );
        vault.exchangeIn(IERC20(address(tokenA)), claim_, IERC20(address(tokenB)), 0, attacker, true, _deadline());

        assertEq(tokenA.balanceOf(address(vault)), residual_, "I3 second call must not move inventory");
    }

    /// @notice Positive control: honest !pretransferred pull succeeds. Amount `_uA(50)`.
    function test_I_positive_honestPullSwap_succeeds() public {
        uint256 amountIn_ = _uA(50);
        tokenA.mint(attacker, amountIn_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault), amountIn_);
        uint256 out_ = vault.exchangeIn(
            IERC20(address(tokenA)), amountIn_, IERC20(address(tokenB)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest !pretransferred swap");
        assertEq(tokenB.balanceOf(attacker), out_, "attacker received tokenB");
    }
}
