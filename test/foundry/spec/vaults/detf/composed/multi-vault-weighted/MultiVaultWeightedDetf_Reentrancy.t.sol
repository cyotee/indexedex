// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/composed/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfDFPkg
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @dev Hostile share: transferFrom re-enters DETF, then ALWAYS completes transfer so probe state persists.
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
            }
            _depth = 0;
        }
        return super.transferFrom(from_, to_, value_);
    }
}

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
        IMultiVaultWeightedDetfBonding(detf_).bond(
            share_, amountIn_, lock_, recipient_, false, block.timestamp + 1 hours
        );
    }
}

/// @notice Proves nonReentrant via nested exchangeIn/bond during hostile share transferFrom.
contract MultiVaultWeightedDetf_Reentrancy_Test is TestBase_MultiVaultWeightedDetf {
    RecordingReentrantShare internal hostileShare;
    DetfReentryTarget internal reentryTarget;
    address internal outerDetf;
    IMultiVaultWeightedDetfInfo internal outerInfo;
    IStandardExchangeIn internal outerEx;
    IMultiVaultWeightedDetfBonding internal outerBonding;

    function setUp() public virtual override {
        super.setUp();

        hostileShare = new RecordingReentrantShare();
        reentryTarget = new DetfReentryTarget();
        hostileShare.mint(alice, 1_000_000e18);
        hostileShare.mint(bob, 1_000_000e18);

        // Deploy DETF with hostileShare as the configured vault share (production DFPkg path).
        IStandardExchangeProxy[] memory vaults_ = new IStandardExchangeProxy[](1);
        IERC20[] memory shares_ = new IERC20[](1);
        IRateProvider[] memory rps_ = new IRateProvider[](1);
        IERC20[] memory ras_ = new IERC20[](1);
        uint256[] memory weights_ = new uint256[](1);
        vaults_[0] = seVault0;
        shares_[0] = IERC20(address(hostileShare));
        rps_[0] = IRateProvider(address(0));
        ras_[0] = IERC20(address(0)); // unrated hostile share
        weights_[0] = 20e16;

        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = IMultiVaultWeightedDetfDFPkg.PkgArgs({
            name: "Reentrancy Outer MVW",
            symbol: "rMVW",
            vaults: vaults_,
            vaultShares: shares_,
            rateProviders: rps_,
            rateAssets: ras_,
            weightDetf: 80e16,
            vaultWeights: weights_,
            mintThreshold: 1,
            burnThreshold: type(uint256).max
        });
        vm.startPrank(owner);
        outerDetf = indexedexManager.deployVault(
            IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
        outerInfo = IMultiVaultWeightedDetfInfo(outerDetf);
        outerEx = IStandardExchangeIn(outerDetf);
        outerBonding = IMultiVaultWeightedDetfBonding(outerDetf);

        // Initialize reserve + first BPT bond with hostile share.
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = 5_000e18;
        vm.startPrank(alice);
        hostileShare.approve(outerDetf, type(uint256).max);
        uint256 bpt_ = outerBonding.initializeReserve(amounts_, block.timestamp + 1 hours);
        IERC20(outerInfo.reservePool()).approve(outerDetf, bpt_);
        outerBonding.bond(
            IERC20(outerInfo.reservePool()), bpt_, DEFAULT_MIN_LOCK, alice, false, block.timestamp + 1 hours
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

        bytes memory reentry = abi.encodeCall(
            DetfReentryTarget.reenterExchangeIn,
            (outerDetf, IERC20(address(hostileShare)), uint256(1e18), IERC20(outerDetf), bob)
        );
        hostileShare.arm(address(reentryTarget), reentry);

        uint256 balBefore_ = IERC20(outerDetf).balanceOf(bob);
        vm.startPrank(bob);
        hostileShare.approve(outerDetf, amountIn_);
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
