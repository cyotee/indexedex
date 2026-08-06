// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @notice Epoch expansion: hard pending > 0 + realize mint; Open never; gentle vs launch-rich rates.
contract UniswapV4StandardExchangeOrbitalDETF_ExpansionTest is TestBase_UniswapV4StandardExchangeOrbitalDETF {
    function test_open_never_expands() public {
        address d_ = _deployDetfInstance(_openArgs());
        IUniswapV4StandardExchangeOrbitalDETF info_ = IUniswapV4StandardExchangeOrbitalDETF(d_);
        _firstBondOn(d_, 200 ether, 200 ether);
        info_.compoundProtocolRewards();
        _pushSyntheticMintAllowed(info_); // rich book even under Open
        vm.warp(block.timestamp + 30 days);
        assertEq(info_.pendingExpansionDetf(), 0, "Open never expands");
        uint256 supplyBefore = IERC20(d_).totalSupply();
        info_.compoundProtocolRewards();
        assertEq(IERC20(d_).totalSupply(), supplyBefore, "Open compound does not mint expansion");
    }

    function test_policy_pending_gt_zero_and_realize_mints() public {
        address d = _deployDetfInstance(_gentleArgs());
        IUniswapV4StandardExchangeOrbitalDETF info = IUniswapV4StandardExchangeOrbitalDETF(d);
        assertEq(uint8(info.thresholdMode()), uint8(ThresholdMode.Policy));

        (uint256 tokenId,) = _firstBondOn(d, 300 ether, 300 ether);
        tokenId; // silence
        // Seed expansion clock (realize path; no pre-live backlog).
        info.compoundProtocolRewards();
        assertGt(info.lastExpansionTimestamp(), 0, "seeded lastExpansionTimestamp");

        // Drive S_spot > 1e18 so expansion formula produces pending after warp.
        _pushSyntheticMintAllowed(info);
        // Spot synthetic (not only debt-inclusive) must be > peg for expansion.
        // Donations raise FD; require mint-allowed which needs debt-inclusive S > 1.05,
        // which implies spot is also rich.
        assertGt(info.syntheticPrice(), 1e18, "synthetic premium after push");

        uint256 epoch_ = info.expansionEpochLength();
        if (epoch_ == 0) epoch_ = 8 hours;
        vm.warp(block.timestamp + epoch_ * 5 + 1);

        uint256 pending = info.pendingExpansionDetf();
        assertGt(pending, 0, "pendingExpansionDetf must be > 0 after premium + warp");

        uint256 supplyBefore = IERC20(d).totalSupply();
        uint256 lastBefore = info.lastExpansionTimestamp();

        // Realize on public compound (realize path).
        info.compoundProtocolRewards();

        assertGt(IERC20(d).totalSupply(), supplyBefore, "realize mint increased totalSupply");
        assertGt(info.lastExpansionTimestamp(), lastBefore, "realize advanced lastExpansionTimestamp");
        // Pending should drop after realize (may still be residual if catch-up capped mid-epoch).
        assertLe(info.pendingExpansionDetf(), pending, "pending does not increase on realize");

        // Primary mint must not advance expansion clock.
        uint256 last2 = info.lastExpansionTimestamp();
        if (info.isMintingAllowed()) {
            _mintOn(d, info.pairToken0(), 1 ether);
            assertEq(info.lastExpansionTimestamp(), last2, "mint must not realize expansion");
        }
    }

    function test_launch_rich_pending_ge_gentle_when_premium() public {
        address g = _deployDetfInstance(_gentleArgs());
        address lr = _deployDetfInstance(_launchRichArgs());
        IUniswapV4StandardExchangeOrbitalDETF gInfo = IUniswapV4StandardExchangeOrbitalDETF(g);
        IUniswapV4StandardExchangeOrbitalDETF lrInfo = IUniswapV4StandardExchangeOrbitalDETF(lr);
        assertEq(gInfo.expansionClosureRatePerYearWad(), 0.10e18);
        assertEq(lrInfo.expansionClosureRatePerYearWad(), 4.4e18);

        _firstBondOn(g, 250 ether, 250 ether);
        _firstBondOn(lr, 250 ether, 250 ether);
        gInfo.compoundProtocolRewards();
        lrInfo.compoundProtocolRewards();
        _pushSyntheticMintAllowed(gInfo);
        _pushSyntheticMintAllowed(lrInfo);

        uint256 epoch_ = gInfo.expansionEpochLength();
        if (epoch_ == 0) epoch_ = 8 hours;
        vm.warp(block.timestamp + epoch_ * 5 + 1);

        uint256 pendingG = gInfo.pendingExpansionDetf();
        uint256 pendingLr = lrInfo.pendingExpansionDetf();
        assertGt(pendingG, 0, "gentle pending > 0");
        assertGt(pendingLr, 0, "launch-rich pending > 0");
        assertGe(pendingLr, pendingG, "launch-rich closure rate yields >= gentle pending");
    }

    function test_compound_skip_when_not_zap_eligible_pre_live() public {
        // Default setUp deploys inert Policy instance first — compound before live is no-op.
        // Use a fresh inert deploy via open args then check pre-first-bond compound.
        address d = _deployDetfInstance(_openArgs());
        IUniswapV4StandardExchangeOrbitalDETF info = IUniswapV4StandardExchangeOrbitalDETF(d);
        assertFalse(info.isReserveLive());
        (uint256 a, uint256 b) = info.compoundProtocolRewards();
        assertEq(a, 0);
        assertEq(b, 0);
    }
}
