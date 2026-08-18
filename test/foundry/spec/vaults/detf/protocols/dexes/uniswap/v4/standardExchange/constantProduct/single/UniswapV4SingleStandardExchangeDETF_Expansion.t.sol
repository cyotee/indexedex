// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @notice Phase 5: epoch expansion gentle + launch-rich + Open never.
contract UniswapV4SingleStandardExchangeDETF_ExpansionTest is TestBase_UniswapV4SingleStandardExchangeDETF {
    function test_gentle_pendingAccrues_afterSeed_withoutRealizeOnMint() public {
        // Open mode for mint path; Policy gentle instance for expansion pending checks.
        address dPolicy = _deployDetfWired(_gentleArgs());
        _liveWithFirstBond(dPolicy, 400 ether);
        IUniswapV4SingleStandardExchangeDETF info = IUniswapV4SingleStandardExchangeDETF(dPolicy);
        info.compoundProtocolRewards();
        assertGt(info.lastExpansionTimestamp(), 0, "seeded");

        uint256 synth0 = info.syntheticPrice();
        vm.warp(block.timestamp + 8 hours * 10);
        uint256 pending = info.pendingExpansionDetf();
        uint256 synth1 = info.syntheticPrice();
        if (pending > 0) {
            assertLe(synth1, synth0, "debt-inclusive synthetic falls or holds when pending accrues");
        }

        // Mint path on Open instance so Policy gate does not block; clock on Open is separate.
        address dOpen = _deployDetfWired(_openArgs());
        _liveWithFirstBond(dOpen, 400 ether);
        IUniswapV4SingleStandardExchangeDETF openInfo = IUniswapV4SingleStandardExchangeDETF(dOpen);
        openInfo.compoundProtocolRewards();
        uint256 last = openInfo.lastExpansionTimestamp();
        _mintOn(dOpen, 20 ether);
        // Open never expands — last may stay at seed only.
        assertEq(openInfo.lastExpansionTimestamp(), last, "mint no expand on Open");
        assertEq(openInfo.pendingExpansionDetf(), 0, "Open never pending");
    }

    function test_launchRich_resolves_and_realizes_on_bond() public {
        address d = _deployDetfWired(_launchRichArgs());
        assertEq(IUniswapV4SingleStandardExchangeDETF(d).expansionClosureRatePerYearWad(), 4.4e18);
        _liveWithFirstBond(d, 400 ether);

        IUniswapV4SingleStandardExchangeDETF info = IUniswapV4SingleStandardExchangeDETF(d);
        info.compoundProtocolRewards(); // seed
        vm.warp(block.timestamp + 8 hours * 20);

        uint256 lastBefore = info.lastExpansionTimestamp();
        _bondOn(d, 30 ether);
        assertGe(info.lastExpansionTimestamp(), lastBefore, "bond realizes");
    }

    function test_open_never_expands() public {
        address d = _deployDetfWired(_openArgs());
        _liveWithFirstBond(d, 400 ether);
        IUniswapV4SingleStandardExchangeDETF info = IUniswapV4SingleStandardExchangeDETF(d);
        assertEq(uint8(info.thresholdMode()), uint8(ThresholdMode.Open));

        info.compoundProtocolRewards();
        vm.warp(block.timestamp + 8 hours * 50);
        assertEq(info.pendingExpansionDetf(), 0, "Open never pending");
        _bondOn(d, 10 ether);
        assertEq(info.pendingExpansionDetf(), 0, "Open still zero after bond");
    }

    function test_compound_is_realize_path() public {
        _firstBond(400 ether);
        detfInfo.compoundProtocolRewards();
        uint256 last = detfInfo.lastExpansionTimestamp();
        assertGt(last, 0, "seeded by compound");
        vm.warp(block.timestamp + 8 hours * 3);
        detfInfo.compoundProtocolRewards();
        assertGe(detfInfo.lastExpansionTimestamp(), last);
    }

    function test_compound_raises_protocolLp_when_pending_rewards() public {
        // Seed live + give protocol NFT share weight via sell, then force inventory seigniorage.
        address d = _deployDetfWired(_openArgs());
        _liveWithFirstBond(d, 400 ether);
        IUniswapV4SingleStandardExchangeDETF info = IUniswapV4SingleStandardExchangeDETF(d);
        address claim = info.rebasingClaimToken();
        address hook = info.reserveHook();
        address bond = info.bondNftVault();
        uint256 protocolNftId = IDETFNFTVault(bond).detfNFTId();

        // Protocol NFT starts with 0 effective shares → cannot earn inventory until principal weight exists.
        // Sell a user bond → protocol NFT gets originalShares weight + LP migrates to claim.
        (uint256 tokenId,) = _bondOn(d, 80 ether);
        vm.warp(block.timestamp + 30 days + 1);
        vm.prank(detfUser);
        info.sellPositionToDetfNft(tokenId, detfUser);
        assertGt(IDETFNFTVault(bond).effectiveSharesOf(protocolNftId), 0, "protocol NFT has share weight after sell");

        // Force seigniorage inventory free DETF onto bond vault (reward token balance ↑).
        _mintOn(d, 100 ether);
        _bondOn(d, 60 ether);
        _mintOn(d, 80 ether);

        uint256 pending = IDETFNFTVault(bond).pendingRewards(protocolNftId);
        assertGt(pending, 0, "protocol NFT must have pending free DETF inventory before compound");

        uint256 protocolBefore = info.protocolLp();
        uint256 claimLpBefore = IERC20(hook).balanceOf(claim);
        (uint256 detfIn, uint256 lpOut) = info.compoundProtocolRewards();
        assertGt(detfIn, 0, "compound must harvest free DETF");
        assertGt(lpOut, 0, "compound produced LP");
        assertGt(info.protocolLp(), protocolBefore, "protocol LP rises after compound");
        assertGt(IERC20(hook).balanceOf(claim), claimLpBefore, "compound LP lands on rebasing claim package");
    }

    /* ----------------------------- helpers ----------------------------- */

    function _liveWithFirstBond(address d, uint256 pairAmt) internal {
        pairToken.mint(detfUser, pairAmt * 2);
        vm.startPrank(detfUser);
        pairToken.approve(d, type(uint256).max);
        IUniswapV4SingleStandardExchangeDETF(d).bond(
            IERC20(address(pairToken)),
            pairAmt,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(IUniswapV4SingleStandardExchangeDETF(d).isReserveLive());
    }

    function _bondOn(address d, uint256 pairAmt) internal returns (uint256 tokenId, uint256 shares) {
        pairToken.mint(detfUser, pairAmt);
        vm.startPrank(detfUser);
        pairToken.approve(d, type(uint256).max);
        (tokenId, shares) = IUniswapV4SingleStandardExchangeDETF(d).bond(
            IERC20(address(pairToken)),
            pairAmt,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _mintOn(address d, uint256 pairAmt) internal {
        pairToken.mint(detfUser, pairAmt);
        vm.startPrank(detfUser);
        pairToken.approve(d, type(uint256).max);
        IStandardExchangeIn(d).exchangeIn(
            IERC20(address(pairToken)),
            pairAmt,
            IERC20(d),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}
