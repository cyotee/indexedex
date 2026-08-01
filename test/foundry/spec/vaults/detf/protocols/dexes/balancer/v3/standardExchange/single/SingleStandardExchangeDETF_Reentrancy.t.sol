// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";
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

/// @dev Hostile share token: on transferFrom, re-enters target then ALWAYS completes the transfer
///      so probe state (reentryAttempts / nested error) is not rolled back by a bubbling revert.
///      The security claim is that nested exchangeIn/bond fails with IsLocked - not that outer aborts.
contract RecordingReentrantShare is MockERC20 {
    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;

    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    constructor() MockERC20("HostileShare", "HSHR", 18) {}

    function arm(address target_, bytes memory reentryCall_) external {
        target = target_;
        reentryCall = reentryCall_;
        armed = true;
        reentryAttempts = 0;
        nestedCallSucceeded = false;
        nestedErrorSelector = bytes4(0);
    }

    function disarm() external {
        armed = false;
    }

    function transferFrom(address from_, address to_, uint256 value_) public override returns (bool) {
        if (armed && _depth == 0) {
            _depth = 1;
            unchecked {
                ++reentryAttempts;
            }
            (bool ok_, bytes memory ret_) = target.call(reentryCall);
            nestedCallSucceeded = ok_;
            if (!ok_ && ret_.length >= 4) {
                bytes4 sel;
                assembly {
                    sel := mload(add(ret_, 0x20))
                }
                nestedErrorSelector = sel;
            } else if (ok_) {
                nestedErrorSelector = bytes4(0);
            }
            _depth = 0;
            // Intentionally do NOT bubble nested failure - outer transfer completes so state sticks.
        }
        return super.transferFrom(from_, to_, value_);
    }
}

/// @dev Nested callee invoked from transferFrom; pure reentry into DETF entrypoints.
contract DetfReentryTarget {
    function reenterExchangeIn(
        address detf_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        address recipient_
    ) external {
        IStandardExchangeIn(detf_).exchangeIn(
            tokenIn_, amountIn_, tokenOut_, 0, recipient_, false, block.timestamp + 1 hours
        );
    }

    function reenterBond(address detf_, IERC20 share_, uint256 amountIn_, uint256 lock_, address recipient_)
        external
    {
        ISingleStandardExchangeDETFBonding(detf_).bond(
            share_, amountIn_, lock_, recipient_, false, block.timestamp + 1 hours
        );
    }
}

/// @notice Proves nonReentrant on exchangeIn/bond via hostile share transferFrom reentry.
/// @dev Catalog: BASE-C / C3-class (mint→bond nested IsLocked). Partial adversarial baseline.
///      Full C1–C2 expansion lives under `adversarial/Adversarial_Reentrancy.t.sol`.
///      Requirements for a green test (no theater):
///      1) Control mint succeeds unarmed on the same path
///      2) reentryAttempts == 1 (nested call ran)
///      3) nestedCallSucceeded == false
///      4) nestedErrorSelector == IsLocked (nested entry hit the guard, not an unrelated revert)
contract SingleStandardExchangeDETF_Reentrancy_Test is TestBase_SingleStandardExchangeDETF {
    RecordingReentrantShare internal hostileShare;
    DetfReentryTarget internal reentryTarget;
    address internal outerDetf;
    ISingleStandardExchangeDETFInfo internal outerInfo;
    IStandardExchangeIn internal outerEx;
    ISingleStandardExchangeDETFBonding internal outerBonding;

    function setUp() public virtual override {
        super.setUp();

        hostileShare = new RecordingReentrantShare();
        reentryTarget = new DetfReentryTarget();
        hostileShare.mint(alice, 1_000_000e18);
        hostileShare.mint(bob, 1_000_000e18);

        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: "Reentrancy Outer DETF",
            symbol: "rDETF",
            standardExchangeVault: seVault,
            standardExchangeVaultShare: IERC20(address(hostileShare)),
            rateTarget: IERC20(address(0)),
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Open,
        expansionClosureRatePerSecond: 0,
        expansionCatchUpMaxSeconds: 0,
        expansionCatchUpCapBps: 0
        });
        vm.startPrank(owner);
        outerDetf = indexedexManager.deployVault(
            IStandardVaultPkg(address(singleStandardExchangeDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
        outerInfo = ISingleStandardExchangeDETFInfo(outerDetf);
        outerEx = IStandardExchangeIn(outerDetf);
        outerBonding = ISingleStandardExchangeDETFBonding(outerDetf);

        uint256 bondIn_ = 5_000e18;
        vm.startPrank(alice);
        hostileShare.approve(outerDetf, bondIn_);
        outerBonding.bond(
            IERC20(address(hostileShare)), bondIn_, DEFAULT_MIN_LOCK, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        require(outerInfo.isReserveLive(), "outer live");
    }

    function test_reentrancy_mintSharePath_nestedHitsIsLocked() public {
        uint256 amountIn_ = 50e18;

        // Control: unarmed mint succeeds.
        vm.startPrank(bob);
        hostileShare.approve(outerDetf, amountIn_);
        uint256 okOut_ = outerEx.exchangeIn(
            IERC20(address(hostileShare)), amountIn_, IERC20(outerDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(okOut_ > 0, "control mint works");

        // Arm: re-enter exchangeIn mid-transferFrom; transfer still completes so probe state persists.
        bytes memory reentry = abi.encodeCall(
            DetfReentryTarget.reenterExchangeIn,
            (outerDetf, IERC20(address(hostileShare)), uint256(1e18), IERC20(outerDetf), bob)
        );
        hostileShare.arm(address(reentryTarget), reentry);

        uint256 balBefore_ = IERC20(outerDetf).balanceOf(bob);
        vm.startPrank(bob);
        hostileShare.approve(outerDetf, amountIn_);
        // Outer mint may succeed after failed nested reentry (transfer completes); that is fine -
        // the attack (nested mint under lock) must have been blocked with IsLocked.
        outerEx.exchangeIn(
            IERC20(address(hostileShare)), amountIn_, IERC20(outerDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(hostileShare.reentryAttempts(), 1, "nested reentry attempted exactly once");
        assertFalse(hostileShare.nestedCallSucceeded(), "nested exchangeIn must not succeed");
        assertEq(
            hostileShare.nestedErrorSelector(),
            IReentrancyLock.IsLocked.selector,
            "nested exchangeIn must revert IsLocked (nonReentrant)"
        );
        // Outer path still ran after reentry (transfer completed); balance may increase by outer mint only.
        assertGe(IERC20(outerDetf).balanceOf(bob), balBefore_, "outer path continued after blocked reentry");
    }

    function test_reentrancy_crossFunction_bond_nestedHitsIsLocked() public {
        uint256 amountIn_ = 50e18;
        bytes memory reentry = abi.encodeCall(
            DetfReentryTarget.reenterBond,
            (outerDetf, IERC20(address(hostileShare)), uint256(1e18), DEFAULT_MIN_LOCK, bob)
        );
        hostileShare.arm(address(reentryTarget), reentry);

        vm.startPrank(bob);
        hostileShare.approve(outerDetf, amountIn_);
        outerEx.exchangeIn(
            IERC20(address(hostileShare)), amountIn_, IERC20(outerDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(hostileShare.reentryAttempts(), 1, "nested reentry attempted exactly once");
        assertFalse(hostileShare.nestedCallSucceeded(), "nested bond must not succeed");
        assertEq(
            hostileShare.nestedErrorSelector(),
            IReentrancyLock.IsLocked.selector,
            "nested bond must revert IsLocked (nonReentrant)"
        );
    }
}
