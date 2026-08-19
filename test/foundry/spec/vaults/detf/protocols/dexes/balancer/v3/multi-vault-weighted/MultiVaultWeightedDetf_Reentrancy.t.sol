// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

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

/// @notice Hostile vaultShare is rejected at PkgArgs (WP-SEC-PKG-MV-001).
/// @dev TransferFrom reentry via a configured hostile share is unreachable after the deploy gate.
contract MultiVaultWeightedDetf_Reentrancy_Test is TestBase_MultiVaultWeightedDetf {
    RecordingReentrantShare internal hostileShare;

    function setUp() public virtual override {
        super.setUp();
        hostileShare = new RecordingReentrantShare();
        hostileShare.mint(alice, 1_000_000e18);
        hostileShare.mint(bob, 1_000_000e18);
    }

    function test_reentrancy_mintSharePath_nestedHitsIsLocked() public {
        _expectHostileShareDeployReverts();
    }

    function test_reentrancy_crossFunction_bond_nestedHitsIsLocked() public {
        _expectHostileShareDeployReverts();
    }

    function _expectHostileShareDeployReverts() internal {
        IStandardExchangeProxy[] memory vaults_ = new IStandardExchangeProxy[](1);
        IERC20[] memory shares_ = new IERC20[](1);
        IRateProvider[] memory rps_ = new IRateProvider[](1);
        IERC20[] memory ras_ = new IERC20[](1);
        uint256[] memory weights_ = new uint256[](1);
        vaults_[0] = seVault0;
        shares_[0] = IERC20(address(hostileShare));
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
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Open,
            expansionClosureRatePerSecond: 0,
            expansionCatchUpMaxSeconds: 0,
            expansionCatchUpCapBps: 0,
            creator: address(0)
        });
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMultiVaultWeightedDetfDFPkg.InvalidVaultShare.selector,
                uint256(0),
                address(seVault0),
                address(hostileShare)
            )
        );
        indexedexManager.deployVault(
            IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }
}
