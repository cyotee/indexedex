// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";

/// @notice L1 property fuzz for SingleStandardExchangeDETF (Wave 1B).
/// forge-config: default.fuzz.runs = 64
contract SingleStandardExchangeDETF_Fuzz_Test is TestBase_SingleStandardExchangeDETF {
    address internal actorA;
    address internal actorB;

    function setUp() public virtual override {
        super.setUp();
        actorA = makeAddr("sseFuzzA");
        actorB = makeAddr("sseFuzzB");
    }

    function _openLive() internal returns (address instance_) {
        instance_ = _deployOpenThresholdDetf("SSE Fuzz", "sseF");
        _bootstrapDetf(instance_, actorA, 2_000e18);
        assertTrue(ISingleStandardExchangeDETFInfo(instance_).isReserveLive(), "live");
    }

    function testFuzz_mintThenPartialBurn_conservation(uint256 lpSeed, uint256 burnSeed) public {
        address instance_ = _openLive();
        uint256 lpAmount_ = bound(lpSeed, 50e18, 200e18);

        uint256 sharesIn_ = _fundSeShares(actorB, lpAmount_);
        vm.assume(sharesIn_ > 1e15);

        vm.startPrank(actorB);
        seShare.approve(instance_, sharesIn_);
        uint256 detfOut_ = IStandardExchangeIn(instance_).exchangeIn(
            seShare, sharesIn_, IERC20(instance_), 0, actorB, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        vm.assume(detfOut_ > 1e12);

        uint256 burnAmt_ = bound(burnSeed, 1e12, detfOut_ / 2);
        if (burnAmt_ == 0) return;
        vm.startPrank(actorB);
        IERC20(instance_).approve(instance_, burnAmt_);
        try IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), burnAmt_, seShare, 0, actorB, false, block.timestamp + 1 hours
        ) returns (uint256 sharesBack_) {
            vm.stopPrank();
            assertLe(sharesBack_, sharesIn_, "P-CONS: sharesBack <= sharesIn");
        } catch {
            vm.stopPrank();
        }
        _assertNoFreeInventory(instance_);
    }

    function testFuzz_holderBalance_notDilutedByOthersMint(uint256 aLp, uint256 bLp) public {
        address instance_ = _openLive();
        aLp = bound(aLp, 40e18, 150e18);
        bLp = bound(bLp, 30e18, 120e18);

        uint256 sharesA_ = _fundSeShares(actorA, aLp);
        vm.startPrank(actorA);
        seShare.approve(instance_, sharesA_);
        IStandardExchangeIn(instance_).exchangeIn(
            seShare, sharesA_, IERC20(instance_), 0, actorA, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        uint256 balA_ = IERC20(instance_).balanceOf(actorA);

        uint256 sharesB_ = _fundSeShares(actorB, bLp);
        vm.startPrank(actorB);
        seShare.approve(instance_, sharesB_);
        IStandardExchangeIn(instance_).exchangeIn(
            seShare, sharesB_, IERC20(instance_), 0, actorB, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(IERC20(instance_).balanceOf(actorA), balA_, "P-NODILUTE");
        _assertNoFreeInventory(instance_);
    }

    function testFuzz_zeroPreview(uint256) public {
        address instance_ = _openLive();
        assertEq(
            IStandardExchangeIn(instance_).previewExchangeIn(seShare, 0, IERC20(instance_)),
            0,
            "P-BOUND zero"
        );
    }
}
