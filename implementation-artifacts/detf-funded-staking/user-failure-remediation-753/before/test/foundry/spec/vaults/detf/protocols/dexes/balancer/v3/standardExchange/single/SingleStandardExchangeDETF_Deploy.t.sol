// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @notice Phase 0/1: package deploys inert against production SE vault; mint blocked until first bond.
contract SingleStandardExchangeDETF_Deploy_Test is TestBase_SingleStandardExchangeDETF {
    function test_deploy_inert_notLive() public view {
        _assertInert();
        assertEq(detfInfo.standardExchangeVault(), address(seVault), "se vault wiring");
        assertEq(detfInfo.standardExchangeVaultShare(), address(seShare), "se share wiring");
        assertEq(detfInfo.rateTarget(), address(rateTargetToken), "rateTarget wiring");
        assertTrue(detfInfo.reservePool() != address(0), "reserve pool created at deploy");
        assertTrue(detfInfo.bondNftVault() != address(0), "bond nft vault created at deploy");
        assertEq(detfInfo.mintThreshold(), 1.05e18, "default mint threshold");
        assertEq(detfInfo.burnThreshold(), 0.95e18, "default burn threshold");
        assertEq(uint8(detfInfo.thresholdMode()), uint8(ThresholdMode.Policy), "default mode Policy");
        assertFalse(detfInfo.isMintingAllowed(), "inert mint false");
        assertFalse(detfInfo.isBurningAllowed(), "inert burn false");
    }

    function test_deploy_mintRevertsWhileInert() public {
        uint256 seShares_ = _fundSeShares(alice, 100e18);
        vm.startPrank(alice);
        seShare.approve(detf, seShares_);
        vm.expectRevert(SingleStandardExchangeDETFRepo.ReservePoolNotInitialized.selector);
        detfExchangeIn.exchangeIn(
            seShare, seShares_, IERC20(detf), 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_deploy_syntheticPriceAtOneWhenNoSupply() public view {
        // No DETF supply yet → synthetic peg 1e18 abstract.
        assertEq(detfInfo.syntheticPrice(), 1e18, "synthetic peg at zero supply");
    }

    function test_deploy_packageRegistered() public view {
        assertTrue(address(singleStandardExchangeDetfPkg) != address(0), "pkg deployed");
        assertTrue(detf != address(0), "instance deployed");
        assertEq(IERC20(detf).totalSupply(), 0, "inert has zero supply");
    }
}
