// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IRouter} from "@crane/contracts/protocols/dexes/aerodrome/v1/interfaces/IRouter.sol";
import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
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
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ThresholdMode} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";

/// @dev Hostile share: transferFrom re-enters DETF, then completes transfer so probe state persists.
contract AdvRecordingReentrantShare is MockERC20 {
    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;
    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    constructor() MockERC20("AdvHostileShare", "AHSHR", 18) {}

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
            }
            _depth = 0;
        }
        return super.transferFrom(from_, to_, value_);
    }
}

contract AdvReentryTarget {
    function reenterExchangeIn(address detf_, IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_, address recipient_)
        external
    {
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

    function reenterInitializeReserve(address detf_, uint256[] calldata amounts_, uint256 deadline_) external {
        IMultiVaultWeightedDetfBonding(detf_).initializeReserve(amounts_, deadline_);
    }

    function reenterRedeemClaim(
        address detf_,
        uint256 claimAmount_,
        IERC20 rateAssetOut_,
        address recipient_
    ) external {
        IMultiVaultWeightedDetfBonding(detf_).redeemClaim(
            claimAmount_, rateAssetOut_, 0, recipient_, block.timestamp + 1 hours
        );
    }
}

/// @title TestBase_MultiVaultWeightedDetf_Adversarial
/// @notice Helpers for adversarial suites. Production DETF + SE only (CREATE3 + registry DFPkg path).
/// @dev Peer DETF ports (Phase 6: single SE, stable composed) deferred — non-goal for MultiVault green.
abstract contract TestBase_MultiVaultWeightedDetf_Adversarial is TestBase_MultiVaultWeightedDetf {
    address internal attacker;
    address internal victim;

    AdvRecordingReentrantShare internal hostileShare;
    AdvReentryTarget internal reentryTarget;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        hostileShare = new AdvRecordingReentrantShare();
        reentryTarget = new AdvReentryTarget();
        hostileShare.mint(attacker, 10_000_000e18);
        hostileShare.mint(victim, 10_000_000e18);
        hostileShare.mint(alice, 10_000_000e18);
        hostileShare.mint(bob, 10_000_000e18);
    }

    function _openLiveN1() internal returns (address instance_) {
        instance_ = _deployOpenThresholdDetfN(1);
        _goLiveViaBptBond(instance_, alice, 1_000e18);
        _assertLive(instance_);
    }

    function _openLiveN1DefaultThresholds() internal returns (address instance_) {
        instance_ = _deployDetfN(1, 0, 0, true);
        _goLiveViaBptBond(instance_, alice, 2_000e18);
        _assertLive(instance_);
    }

    function _deployHostileShareDetf(uint256 mintTh_, uint256 burnTh_) internal returns (address instance_) {
        // Historical (1, max) dual-path always-allow → product Open under §16.3.
        ThresholdMode mode_ = ThresholdMode.Policy;
        if (mintTh_ == 1 && burnTh_ == type(uint256).max) {
            mintTh_ = 0;
            burnTh_ = 0;
            mode_ = ThresholdMode.Open;
        }
        IStandardExchangeProxy[] memory vaults_ = new IStandardExchangeProxy[](1);
        IERC20[] memory shares_ = new IERC20[](1);
        IRateProvider[] memory rps_ = new IRateProvider[](1);
        IERC20[] memory ras_ = new IERC20[](1);
        uint256[] memory weights_ = new uint256[](1);
        vaults_[0] = seVaults[0];
        shares_[0] = IERC20(address(hostileShare));
        ras_[0] = IERC20(address(0));
        weights_[0] = 20e16;

        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = IMultiVaultWeightedDetfDFPkg.PkgArgs({
            name: "Adv Hostile MVW",
            symbol: "advH",
            vaults: vaults_,
            vaultShares: shares_,
            rateProviders: rps_,
            rateAssets: ras_,
            weightDetf: 80e16,
            vaultWeights: weights_,
            mintThreshold: mintTh_,
            burnThreshold: burnTh_,
            thresholdMode: mode_,
            expansionClosureRatePerSecond: 0,
            expansionCatchUpMaxSeconds: 0,
            expansionCatchUpCapBps: 0
        });
        vm.startPrank(owner);
        instance_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    function _goLiveHostile(address instance_, address user, uint256 amount_)
        internal
        returns (uint256 tokenId_, uint256 bpt_)
    {
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = amount_;
        vm.startPrank(user);
        hostileShare.approve(instance_, type(uint256).max);
        bpt_ = IMultiVaultWeightedDetfBonding(instance_).initializeReserve(
            amounts_, block.timestamp + 1 hours
        );
        address pool_ = IMultiVaultWeightedDetfInfo(instance_).reservePool();
        IERC20(pool_).approve(instance_, bpt_);
        (tokenId_,) = IMultiVaultWeightedDetfBonding(instance_).bond(
            IERC20(pool_), bpt_, DEFAULT_MIN_LOCK, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _swapUnderlying(address tokenIn, address tokenOut, uint256 amount, address trader) internal {
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: tokenIn, to: tokenOut, stable: false, factory: address(aerodromePoolFactory)
        });
        vm.startPrank(trader);
        IERC20(tokenIn).approve(address(aerodromeRouter), amount);
        aerodromeRouter.swapExactTokensForTokens(amount, 0, routes, trader, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _assertNoFreeInventoryStrict(address instance_) internal view {
        _assertNoFreeInventory(instance_);
    }

    function _claimBalance(address instance_, address user) internal view returns (uint256) {
        address claim_ = IMultiVaultWeightedDetfInfo(instance_).rebasingClaimToken();
        if (claim_ == address(0)) return 0;
        return IERC20(claim_).balanceOf(user);
    }
}
