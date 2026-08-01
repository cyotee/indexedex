// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {HostileReentrantShare} from "contracts/test/adversarial/HostileReentrantShare.sol";
import {DetfReentryTarget} from "contracts/test/adversarial/DetfReentryTarget.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    ISingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETDFPkg.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @title TestBase_SingleStandardExchangeDETF_Adversarial
/// @notice Production Single SE DETF + shared hostile harness (Wave 1A).
abstract contract TestBase_SingleStandardExchangeDETF_Adversarial is TestBase_SingleStandardExchangeDETF {
    address internal attacker;
    address internal victim;

    HostileReentrantShare internal hostileShare;
    DetfReentryTarget internal reentryTarget;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        hostileShare = new HostileReentrantShare();
        reentryTarget = new DetfReentryTarget();
        hostileShare.mint(attacker, 10_000_000e18);
        hostileShare.mint(victim, 10_000_000e18);
        hostileShare.mint(alice, 10_000_000e18);
        hostileShare.mint(bob, 10_000_000e18);
    }

    function _openLiveOpenThreshold() internal returns (address instance_) {
        instance_ = _deployOpenThresholdDetf("Adv Open SSE", "advSSE");
        _bootstrapDetf(instance_, alice, 2_000e18);
        assertTrue(ISingleStandardExchangeDETFInfo(instance_).isReserveLive(), "live");
    }

    function _deployHostileShareDetf(uint256 mintTh_, uint256 burnTh_) internal returns (address instance_) {
        // Match existing SingleStandardExchangeDETF_Reentrancy.t.sol wiring (rateTarget=0).
        // When callers pass historical dual-path (1, max), use Open - 1/max fails mint>burn validation.
        ThresholdMode mode_ = ThresholdMode.Policy;
        uint256 mintArg_ = mintTh_;
        uint256 burnArg_ = burnTh_;
        if (mintTh_ <= burnTh_) {
            mode_ = ThresholdMode.Open;
            mintArg_ = 0;
            burnArg_ = 0;
        }
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: "Adv Hostile SSE",
            symbol: "advHSSE",
            standardExchangeVault: seVault,
            standardExchangeVaultShare: IERC20(address(hostileShare)),
            rateTarget: IERC20(address(0)),
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: mintArg_,
            burnThreshold: burnArg_,
            thresholdMode: mode_,
            expansionClosureRatePerSecond: 0,
            expansionCatchUpMaxSeconds: 0,
            expansionCatchUpCapBps: 0
        });
        vm.startPrank(owner);
        instance_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(singleStandardExchangeDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    function _bootstrapHostile(address instance_, address user, uint256 amount_)
        internal
        returns (uint256 tokenId_)
    {
        vm.startPrank(user);
        hostileShare.approve(instance_, amount_);
        (tokenId_,) = ISingleStandardExchangeDETFBonding(instance_).bond(
            IERC20(address(hostileShare)),
            amount_,
            DEFAULT_MIN_LOCK,
            user,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _mintSeSharesToDetf(address instance_, address user, uint256 lpAmount)
        internal
        returns (uint256 out_)
    {
        uint256 shares_ = _fundSeShares(user, lpAmount);
        vm.startPrank(user);
        seShare.approve(instance_, shares_);
        out_ = IStandardExchangeIn(instance_).exchangeIn(
            seShare, shares_, IERC20(instance_), 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}
