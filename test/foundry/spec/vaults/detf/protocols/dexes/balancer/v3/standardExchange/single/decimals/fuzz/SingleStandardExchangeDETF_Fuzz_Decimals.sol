// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_SingleStandardExchangeDETF_Decimals
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF_Decimals.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISingleStandardExchangeDETFInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFInfo.sol";

/// @notice L1 property fuzz for SingleStandardExchangeDETF (Wave 1B).
/// forge-config: default.fuzz.runs = 64
abstract contract SingleStandardExchangeDETF_Fuzz_Decimals is TestBase_SingleStandardExchangeDETF_Decimals {
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

    /// forge-config: default.fuzz.runs = 512
    function testFuzz_mintThenPartialBurn_conservation(uint256 lpSeed, uint256 burnSeed) public {
        // The fixture scales seed and payment together for low-decimal books.
        address instance_ = _openLive();
        uint256 lpAmount_ = bound(lpSeed, 50e18, 200e18);

        uint256 sharesIn_ = _fundSeShares(actorB, lpAmount_);
        assertGt(sharesIn_, 0, "funded SE shares");

        vm.startPrank(actorB);
        seShare.approve(instance_, sharesIn_);
        uint256 detfOut_ = IStandardExchangeIn(instance_)
            .exchangeIn(seShare, sharesIn_, IERC20(instance_), 0, actorB, false, block.timestamp + 1 hours);
        vm.stopPrank();
        // DETF has nine decimals; bound the burn to the actual funded output.
        assertGe(detfOut_, 10, "funded DETF supports a partial burn");

        uint256 burnAmt_ = _boundPartialBurn(instance_, detfOut_, burnSeed);
        uint256 sharesBefore_ = seShare.balanceOf(actorB);
        vm.startPrank(actorB);
        IERC20(instance_).approve(instance_, burnAmt_);
        uint256 sharesBack_ = IStandardExchangeIn(instance_)
            .exchangeIn(IERC20(instance_), burnAmt_, seShare, 1, actorB, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(sharesBack_, 0, "partial burn executes");
        assertLe(sharesBack_, sharesIn_, "P-CONS: sharesBack <= sharesIn");
        assertEq(seShare.balanceOf(actorB), sharesBefore_ + sharesBack_, "shares credited");
        assertEq(IERC20(instance_).balanceOf(actorB), detfOut_ - burnAmt_, "funded DETF debited");
        _assertNoFreeInventory(instance_);
    }

    function _boundPartialBurn(address instance_, uint256 detfOut_, uint256 seed_) internal view returns (uint256) {
        ISingleStandardExchangeDETFInfo info_ = ISingleStandardExchangeDETFInfo(instance_);
        assertTrue(info_.isBurningAllowed(), "fixture supports primary burn");
        IERC20 reserve_ = IERC20(info_.reservePool());
        (IERC20[] memory tokens_,, uint256[] memory balances_,) =
            IVault(address(vault)).getPoolTokenInfo(address(reserve_));
        uint256 reserveShares_ = balances_[address(tokens_[0]) == address(seShare) ? 0 : 1];

        // Invert DETF -> protocol LP -> SE shares with upward rounding. Target two
        // native SE shares so the rated proportional exit has a rounding margin.
        // A percentage of a nonzero DETF balance alone can still pay zero SE shares.
        uint256 lpNeeded_ = Math.mulDiv(2, reserve_.totalSupply(), reserveShares_, Math.Rounding.Ceil);
        uint256 ownedLp_ = reserve_.balanceOf(instance_) + reserve_.balanceOf(info_.bondNftVault());
        uint256 minBurn_ = Math.mulDiv(lpNeeded_, IERC20(instance_).totalSupply(), ownedLp_, Math.Rounding.Ceil);
        minBurn_ = Math.max(minBurn_, detfOut_ / 10);
        assertLe(minBurn_, detfOut_ / 2, "funded position supports a payable partial burn");
        return bound(seed_, minBurn_, detfOut_ / 2);
    }

    function test_partialBurn_minPayment_minBurn() public {
        testFuzz_mintThenPartialBurn_conservation(0, 0);
    }

    function test_partialBurn_minPayment_maxBurn() public {
        testFuzz_mintThenPartialBurn_conservation(0, type(uint256).max);
    }

    function test_partialBurn_maxPayment_minBurn() public {
        testFuzz_mintThenPartialBurn_conservation(type(uint256).max, 0);
    }

    function test_partialBurn_maxPayment_maxBurn() public {
        testFuzz_mintThenPartialBurn_conservation(type(uint256).max, type(uint256).max);
    }

    function testFuzz_holderBalance_notDilutedByOthersMint(uint256 aLp, uint256 bLp) public {
        address instance_ = _openLive();
        aLp = bound(aLp, 40e18, 150e18);
        bLp = bound(bLp, 30e18, 120e18);

        uint256 sharesA_ = _fundSeShares(actorA, aLp);
        vm.startPrank(actorA);
        seShare.approve(instance_, sharesA_);
        IStandardExchangeIn(instance_)
            .exchangeIn(seShare, sharesA_, IERC20(instance_), 0, actorA, false, block.timestamp + 1 hours);
        vm.stopPrank();
        uint256 balA_ = IERC20(instance_).balanceOf(actorA);

        uint256 sharesB_ = _fundSeShares(actorB, bLp);
        vm.startPrank(actorB);
        seShare.approve(instance_, sharesB_);
        IStandardExchangeIn(instance_)
            .exchangeIn(seShare, sharesB_, IERC20(instance_), 0, actorB, false, block.timestamp + 1 hours);
        vm.stopPrank();

        assertEq(IERC20(instance_).balanceOf(actorA), balA_, "P-NODILUTE");
        _assertNoFreeInventory(instance_);
    }

    function testFuzz_zeroPreview(uint256) public {
        address instance_ = _openLive();
        assertEq(IStandardExchangeIn(instance_).previewExchangeIn(seShare, 0, IERC20(instance_)), 0, "P-BOUND zero");
    }
}
