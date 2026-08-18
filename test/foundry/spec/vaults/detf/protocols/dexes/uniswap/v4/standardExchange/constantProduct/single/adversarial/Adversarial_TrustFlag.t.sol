// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @dev Same-tx helper for I2 short under durable U.
contract UniV4CPPretransferRouterHelper {
    function mintPretransfer(
        address detf_,
        IERC20 pairToken_,
        uint256 transferAmt_,
        uint256 claimAmt_,
        address recipient_
    ) external returns (uint256 out_) {
        if (transferAmt_ > 0) {
            pairToken_.transferFrom(msg.sender, detf_, transferAmt_);
        }
        out_ = IStandardExchangeIn(detf_).exchangeIn(
            pairToken_, claimAmt_, IERC20(detf_), 0, recipient_, true, block.timestamp + 1 hours
        );
    }
}

/// @notice Catalog I1–I3 for Uniswap V4 Single SE CP DETF secure pull (WP-I-DETF-SSE-CP-001).
/// @dev Durable U = B - R. I1 requires booked residual; bare donation free-credits until end-sync (L-RSRV-DUST).
contract Adversarial_UniswapV4SingleSE_CP_TrustFlag_Test is TestBase_UniswapV4SingleStandardExchangeDETF {
    address internal attacker;
    address internal victim;
    address internal aliceAdv;
    UniV4CPPretransferRouterHelper internal preHelper;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        aliceAdv = makeAddr("aliceAdv");
        preHelper = new UniV4CPPretransferRouterHelper();
    }

    function _openLiveOpenThreshold() internal returns (address instance_) {
        instance_ = _deployDetfWired(_openArgs());
        pairToken.mint(aliceAdv, 5_000_000 ether);
        vm.startPrank(aliceAdv);
        pairToken.approve(instance_, type(uint256).max);
        IUniswapV4SingleStandardExchangeDETF(instance_).bond(
            IERC20(address(pairToken)),
            500 ether,
            DEFAULT_MIN_LOCK,
            aliceAdv,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(IUniswapV4SingleStandardExchangeDETF(instance_).isReserveLive(), "live");
    }

    function _fundPair(address to_, uint256 amount_) internal returns (uint256) {
        pairToken.mint(to_, amount_);
        return amount_;
    }

    function _mintPairTo(address instance_, address user_, uint256 pairIn_) internal returns (uint256 out_) {
        pairToken.mint(user_, pairIn_);
        vm.startPrank(user_);
        pairToken.approve(instance_, pairIn_);
        out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            pairIn_,
            IERC20(instance_),
            0,
            user_,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /// @dev Donate residual then honest !pretransferred mint so end-sync books residual (R==B).
    function _bookPairResidual(address instance_, uint256 residual_) internal {
        _fundPair(aliceAdv, residual_);
        vm.prank(aliceAdv);
        pairToken.transfer(instance_, residual_);

        uint256 honestIn_ = residual_ / 2;
        if (honestIn_ == 0) honestIn_ = residual_;
        _fundPair(victim, honestIn_);
        vm.startPrank(victim);
        pairToken.approve(instance_, honestIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            honestIn_,
            IERC20(instance_),
            0,
            victim,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "book residual: honest mint ok");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: booked inventory, no in-call transfer, pretransferred=true        */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 mint: booked pairToken residual cannot free-credit pretransfer mint.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 residual_ = 80 ether;
        _bookPairResidual(instance_, residual_);

        uint256 invBefore_ = pairToken.balanceOf(instance_);
        assertGe(invBefore_, residual_, "absolute inventory present (anti-theater)");
        uint256 claimed_ = residual_;
        uint256 attDetfBefore_ = IERC20(instance_).balanceOf(attacker);
        assertEq(pairToken.balanceOf(attacker), 0, "attacker drained");
        assertEq(pairToken.allowance(attacker, instance_), 0, "no allowance");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            claimed_,
            IERC20(instance_),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(IERC20(instance_).balanceOf(attacker), attDetfBefore_, "I1: no free detfToken mint");
        assertEq(pairToken.balanceOf(instance_), invBefore_, "I1: inventory unchanged (no in-call transfer)");
    }

    /// @notice I1 burn: booked detfToken residual cannot fund pretransfer burn extract.
    function test_I1_burn_pretransferred_true_usesOnlyCallerTransferredDetf() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 minted_ = _mintPairTo(instance_, aliceAdv, 40 ether);
        assertGt(minted_, 0, "minted detfToken");
        uint256 donateAmt_ = minted_ / 2;
        if (donateAmt_ == 0) donateAmt_ = minted_;
        uint256 burnHonest_ = minted_ - donateAmt_;
        if (burnHonest_ == 0) burnHonest_ = 1;

        // Free detf inventory on diamond, then honest burn books residual.
        vm.startPrank(aliceAdv);
        IERC20(instance_).transfer(instance_, donateAmt_);
        IERC20(instance_).approve(instance_, burnHonest_);
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_),
            burnHonest_,
            IERC20(address(pairToken)),
            0,
            aliceAdv,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        uint256 freeBal_ = IERC20(instance_).balanceOf(instance_);
        assertGt(freeBal_, 0, "booked detf residual present");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "attacker has 0 detfToken");

        address hook_ = IUniswapV4SingleStandardExchangeDETF(instance_).reserveHook();
        uint256 lpBefore_ = IERC20(hook_).balanceOf(instance_);
        uint256 pairBefore_ = pairToken.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, freeBal_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_),
            freeBal_,
            IERC20(address(pairToken)),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(IERC20(instance_).balanceOf(instance_), freeBal_, "free detf still on diamond");
        assertEq(IERC20(hook_).balanceOf(instance_), lpBefore_, "I1 burn: LP intact");
        assertEq(pairToken.balanceOf(attacker), pairBefore_, "I1 burn: no free pair extract");
    }

    /// @notice I1 bond: booked pair residual cannot fund free pretransfer bond.
    function test_I1_bond_pretransferred_inventoryNoTransfer_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        uint256 residual_ = 60 ether;
        _bookPairResidual(instance_, residual_);

        uint256 claimed_ = residual_;
        uint256 invBefore_ = pairToken.balanceOf(instance_);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IUniswapV4SingleStandardExchangeDETF(instance_).bond(
            IERC20(address(pairToken)),
            claimed_,
            DEFAULT_MIN_LOCK,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(pairToken.balanceOf(instance_), invBefore_, "bond I1: inventory unchanged");
    }

    /* ---------------------------------------------------------------------- */
    /*  I2: claimed > U                                                       */
    /* ---------------------------------------------------------------------- */

    /// @notice I2 short: book residual, same-tx push shortDelta, claim > short → (claimed, shortDelta).
    function test_I2_pretransferred_claimedGtDelta0_reverts() public {
        address instance_ = _openLiveOpenThreshold();
        _bookPairResidual(instance_, 30 ether);

        uint256 claimed_ = _fundPair(attacker, 50 ether);
        uint256 shortDelta_ = claimed_ / 2;
        require(shortDelta_ > 0 && shortDelta_ < claimed_, "need short < claimed");

        vm.startPrank(attacker);
        pairToken.approve(address(preHelper), shortDelta_);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, shortDelta_
            )
        );
        preHelper.mintPretransfer(
            instance_, IERC20(address(pairToken)), shortDelta_, claimed_, attacker
        );
        vm.stopPrank();

        assertEq(IERC20(instance_).balanceOf(attacker), 0, "I2: no mint on short");
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual inventory cannot fund second free pretransfer            */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: after honest pull end-sync, residual is booked; free true reverts U=0.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        address instance_ = _openLiveOpenThreshold();

        // Pre-seed residual inventory that remains after an honest mint joins only the pulled amount.
        uint256 residual_ = _fundPair(aliceAdv, 30 ether);
        vm.prank(aliceAdv);
        pairToken.transfer(instance_, residual_);
        assertEq(pairToken.balanceOf(instance_), residual_, "residual seeded");

        // Honest first mint via pull path (not pretransfer) — end-sync books residual.
        uint256 victimIn_ = _fundPair(victim, 20 ether);
        vm.startPrank(victim);
        pairToken.approve(instance_, victimIn_);
        uint256 out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            victimIn_,
            IERC20(instance_),
            0,
            victim,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "honest mint ok");
        // Residual donation (plus any mint dust) remains on diamond — booked after end-sync.
        uint256 residualAfter_ = pairToken.balanceOf(instance_);
        assertGe(residualAfter_, residual_, "residual still on diamond after honest mint");

        // Second call: pretransferred against residual free balance, no new inbound transfer.
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residualAfter_, uint256(0)
            )
        );
        IStandardExchangeIn(instance_).exchangeIn(
            IERC20(address(pairToken)),
            residualAfter_,
            IERC20(instance_),
            0,
            attacker,
            true,
            block.timestamp + 1 hours
        );

        assertEq(pairToken.balanceOf(instance_), residualAfter_, "I3: residual not free-credited");
    }
}
