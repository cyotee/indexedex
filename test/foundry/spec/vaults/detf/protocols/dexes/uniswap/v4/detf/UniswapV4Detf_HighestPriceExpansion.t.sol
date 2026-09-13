// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IDETFStandardizedYield} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IDETFFundedRewards, IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {
    TestBase_UniswapV4Detf_Weighted
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";

/// @notice Real manager/package/weighted-hook regression for multi-leg epoch settlement.
contract UniswapV4Detf_HighestPriceExpansionTest is TestBase_UniswapV4Detf_Weighted {
    uint256 private anchor;
    bytes32 private constant EXPANDED = keccak256("NaturalSupplyExpanded(uint256,uint256,uint256)");

    struct SettlementSnapshot {
        uint256 highest;
        uint256 supply;
        address staking;
        uint256 backing;
        uint256 accounted;
        uint256 expected;
    }

    function _launch(uint256 creation0_, uint256 creation1_, uint256 threshold_) private {
        IUniswapV4Detf.PkgArgs memory args_ = _nLegDetfArgs(2);
        args_.name = "Highest Price Expansion";
        args_.symbol = "HPE";
        args_.creationPairPerDetfWad[0] = creation0_;
        args_.creationPairPerDetfWad[1] = creation1_;
        args_.openingPairPerDetfWad = new uint256[](2);
        args_.openingPairPerDetfWad[0] = 100e18;
        args_.openingPairPerDetfWad[1] = 100e18;
        args_.mintThreshold = threshold_;
        detf = _deployWeightedHookThenDetf(args_);
        detfInfo = IUniswapV4Detf(detf);
        _fundActor(detf, detfUser, 10_000 ether);
        _firstBond(100 ether);
        anchor = block.timestamp;
    }

    function _prices() private view returns (address[] memory pairs_, uint256[] memory prices_) {
        address hook_ = detfInfo.hook();
        address[] memory tokens_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint256[] memory creation_ = detfInfo.creationPairPerDetfWad();
        pairs_ = new address[](2);
        prices_ = new uint256[](2);
        uint256 lp_ = IERC20(hook_).balanceOf(detf) + IERC20(hook_).balanceOf(detfInfo.bondNftVault());
        uint256 supplyWad_ = IERC20(detf).totalSupply() * 1e9;
        uint256 p_;
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (tokens_[i_] == detf) continue;
            pairs_[p_] = tokens_[i_];
            // Independent oracle: liquidate protocol LP into this token, then normalize by
            // actual supply and that leg's creation price. Fixture capital tokens have 18 decimals.
            uint256 value_ = IDetfReserveQuote(hook_).previewBurnToToken(lp_, tokens_[i_]);
            uint256 pairPerDetf_ = value_ * 1e18 / supplyWad_;
            prices_[p_] = pairPerDetf_ * 1e18 / creation_[p_];
            ++p_;
        }
        assertEq(p_, 2);
        assertEq(detfInfo.syntheticPrice(), prices_[0], "legacy public price stays first leg");
    }

    function _expected(uint256 supply_, uint256 price_, uint256 epochs_) private view returns (uint256 mint_) {
        if (price_ <= detfInfo.mintThreshold() || price_ <= 1e18) return 0;
        uint256 rate_ = uint256(0.1e18) * 8 hours / 365 days;
        mint_ = (supply_ * (price_ - 1e18) / price_) * rate_ / 1e18 * epochs_;
        if (mint_ <= 1) mint_ = 0;
    }

    function _snapshot(uint256 epochs_) private view returns (SettlementSnapshot memory s_) {
        (, uint256[] memory prices_) = _prices();
        s_.highest = prices_[0] > prices_[1] ? prices_[0] : prices_[1];
        s_.supply = IERC20(detf).totalSupply();
        s_.staking = detfInfo.rebasingClaimToken();
        s_.backing = IERC20(detf).balanceOf(s_.staking);
        s_.accounted = IStakedDETF(s_.staking).stakingState().accountedBacking;
        s_.expected = _expected(s_.supply, s_.highest, epochs_);
    }

    function _assertExpansionLogs(Vm.Log[] memory logs_, SettlementSnapshot memory s_, uint256 boundary_) private view {
        uint256 expansions_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != detf || logs_[i_].topics[0] != EXPANDED) continue;
            ++expansions_;
            (uint256 minted_, uint256 price_, uint256 timestamp_) =
                abi.decode(logs_[i_].data, (uint256, uint256, uint256));
            assertEq(minted_, s_.expected);
            assertEq(price_, s_.highest, "event identifies highest price");
            assertEq(timestamp_, boundary_);
        }
        assertEq(expansions_, s_.expected == 0 ? 0 : 1, "one aggregate expansion event");
    }

    function _assertSettlement(uint256 epochs_, uint256 remainder_) private {
        SettlementSnapshot memory s_ = _snapshot(epochs_);
        vm.warp(anchor + epochs_ * 8 hours + remainder_);
        assertEq(detfInfo.pendingExpansionDetf(), s_.expected, "preview uses maximum once");
        assertEq(IERC20(detf).totalSupply(), s_.supply, "preview cannot fund rewards");
        vm.recordLogs();
        assertEq(IDETFFundedRewards(detf).synchronizeRewards(), s_.expected, "realization matches preview");
        _assertExpansionLogs(vm.getRecordedLogs(), s_, anchor + epochs_ * 8 hours);
        assertEq(IERC20(detf).totalSupply(), s_.supply + s_.expected);
        assertEq(IERC20(detf).balanceOf(s_.staking), s_.backing + s_.expected, "mint reaches staking custody");
        assertEq(IStakedDETF(s_.staking).stakingState().accountedBacking, s_.accounted + s_.expected);
        assertLe(IERC20(s_.staking).totalSupply(), IERC20(detf).balanceOf(s_.staking), "receipts are funded");
        assertEq(detfInfo.pendingExpansionDetf(), 0);
        assertEq(IDETFFundedRewards(detf).synchronizeRewards(), 0, "cannot mint twice in an epoch");
        assertEq(IERC20(detf).totalSupply(), s_.supply + s_.expected);
    }

    function test_incompleteAndConsumedEpochsDoNotValueReserve() public {
        _launch(1e18, 1e18, 1.05e18);
        _assertNoExpansionReserveValuation();
        vm.warp(anchor + 8 hours - 1);
        _assertNoExpansionReserveValuation();
        vm.warp(anchor + 8 hours);
        uint256 pending_ = detfInfo.pendingExpansionDetf();
        assertGt(pending_, 0, "exact boundary remains eligible");
        assertEq(IDETFFundedRewards(detf).synchronizeRewards(), pending_);
        _assertNoExpansionReserveValuation();
        vm.warp(anchor + 16 hours - 1);
        _assertNoExpansionReserveValuation();
        vm.warp(anchor + 16 hours);
        assertGt(detfInfo.pendingExpansionDetf(), 0, "next boundary was not consumed early");
    }

    function _assertNoExpansionReserveValuation() private {
        address hook_ = detfInfo.hook();
        vm.startStateDiffRecording();
        assertEq(detfInfo.pendingExpansionDetf(), 0);
        assertEq(IDETFFundedRewards(detf).synchronizeRewards(), 0);
        Vm.AccountAccess[] memory accesses_ = vm.stopAndReturnStateDiff();
        assertGt(accesses_.length, 0, "record actual synchronization calls");
        for (uint256 i_; i_ < accesses_.length; ++i_) {
            if (accesses_[i_].account == hook_ && accesses_[i_].data.length >= 4) {
                assertNotEq(bytes4(accesses_[i_].data), IDetfReserveQuote.previewSynthetic.selector,
                    "no reserve valuation without a completed epoch");
            }
        }
    }

    function test_secondLegAloneTriggersExpansionAndKeepsRouteGates() public {
        _launch(1_000e18, 1e18, 1.05e18);
        (address[] memory pairs_, uint256[] memory prices_) = _prices();
        assertLt(prices_[0], detfInfo.mintThreshold());
        assertGt(prices_[1], detfInfo.mintThreshold());
        assertFalse(detfInfo.isMintingAllowed(IERC20(pairs_[0])));
        assertTrue(detfInfo.isMintingAllowed(IERC20(pairs_[1])));
        assertTrue(detfInfo.isBurningAllowed(IERC20(pairs_[0])));
        assertFalse(detfInfo.isBurningAllowed(IERC20(pairs_[1])));
        _assertSettlement(3, 1 hours);
    }

    function test_firstLegAloneTriggersExpansion() public {
        _launch(1e18, 1_000e18, 1.05e18);
        (, uint256[] memory prices_) = _prices();
        assertGt(prices_[0], detfInfo.mintThreshold());
        assertLt(prices_[1], detfInfo.mintThreshold());
        _assertSettlement(1, 0);
    }

    function test_bothEligibleUseHighestRatherThanSum() public {
        _launch(2e18, 1e18, 1.05e18);
        (, uint256[] memory prices_) = _prices();
        assertGt(prices_[0], detfInfo.mintThreshold());
        assertGt(prices_[1], prices_[0]);
        _assertSettlement(21, 0);
    }

    function test_neitherEligibleConsumesEpoch() public {
        _launch(1_000e18, 2_000e18, 1.05e18);
        (, uint256[] memory prices_) = _prices();
        assertLt(prices_[0], detfInfo.mintThreshold());
        assertLt(prices_[1], detfInfo.mintThreshold());
        _assertSettlement(3, 1 hours);
    }

    function test_customThresholdBlocksOtherwiseRichPrices() public {
        _launch(1e18, 2e18, 1_000e18);
        (, uint256[] memory prices_) = _prices();
        assertGt(prices_[0], 1.05e18);
        assertGt(prices_[1], 1.05e18);
        assertLt(prices_[0], detfInfo.mintThreshold());
        assertLt(prices_[1], detfInfo.mintThreshold());
        _assertSettlement(1, 0);
    }

    function test_reselectsHighestAfterReserveCompositionChanges() public {
        _launch(1e18, 2e18, 1.05e18);
        (address[] memory pairs_, uint256[] memory before_) = _prices();
        assertGt(before_[0], before_[1]);
        _assertSettlement(1, 0);
        vm.startPrank(detfUser);
        IERC20(pairs_[1]).approve(detfInfo.bondNftVault(), 1_000 ether);
        detfInfo.donate(IERC20(pairs_[1]), 1_000 ether, false);
        vm.stopPrank();
        (, uint256[] memory after_) = _prices();
        assertGt(after_[1], after_[0], "real reserve donation changes the highest leg");
        assertEq(detfInfo.pendingExpansionDetf(), 0, "changed prices cannot replay a settled epoch");
        anchor = block.timestamp;
        _assertSettlement(1, 0);
    }

    function testFuzz_highestPriceSettlement(uint16 creation0_, uint16 creation1_, uint8 epochs_) public {
        _launch(bound(creation0_, 1, 1_000) * 1e18, bound(creation1_, 1, 1_000) * 1e18, 1.05e18);
        _assertSettlement(bound(epochs_, 1, 255), 123);
    }

    function test_stakingSyDepositSettlesHighestBeforeNewPrincipal() public {
        _launch(1_000e18, 1e18, 1.05e18);
        (address[] memory pairs_,) = _prices();
        vm.startPrank(detfUser);
        uint256 raw_ = IStandardExchangeIn(detf)
            .exchangeIn(IERC20(pairs_[1]), 1 ether, IERC20(detf), 0, detfUser, false, block.timestamp + 1 hours);
        IStandardizedYield sy_ = IStandardizedYield(IDETFStandardizedYield(detf).stakingSY());
        IERC20(detf).approve(address(sy_), raw_);
        uint256 amount_ = raw_ / 2;
        assertGt(sy_.deposit(detfUser, detf, amount_, 0), 0);
        vm.stopPrank();
        (, uint256[] memory prices_) = _prices();
        assertGt(prices_[1], prices_[0]);
        SettlementSnapshot memory s_ = _snapshot(3);
        assertGt(s_.expected, 0);
        uint256 sharesBefore_ = sy_.balanceOf(detfUser);
        vm.warp(anchor + 25 hours);
        uint256 preview_ = sy_.previewDeposit(detf, amount_);
        assertEq(detfInfo.pendingExpansionDetf(), s_.expected);
        vm.prank(detfUser);
        uint256 minted_ = sy_.deposit(detfUser, detf, amount_, preview_);
        assertEq(minted_, preview_, "SY preview includes the selected expansion before new stake");
        assertEq(sy_.balanceOf(detfUser), sharesBefore_ + minted_);
        assertEq(IERC20(detf).totalSupply(), s_.supply + s_.expected, "nested callbacks settle once");
        assertEq(IERC20(detf).balanceOf(s_.staking), s_.backing + s_.expected + amount_);
        assertEq(detfInfo.pendingExpansionDetf(), 0);
        assertEq(IDETFFundedRewards(detf).synchronizeRewards(), 0);
    }

    function test_changedDetfFacetsFitProductionCodeLimit() public view {
        IDiamondLoupe.Facet[] memory facets_ = IDiamondLoupe(detf).facets();
        for (uint256 i_; i_ < facets_.length; ++i_) {
            assertLe(facets_[i_].facetAddress.code.length, 24_576);
        }
    }
}
