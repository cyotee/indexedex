// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {ComposedStableCommonDetfRepo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

/// @dev Hostile pairToken that is also a 1:1 rateAsset wrapper SE.
///      transferFrom re-enters the DETF then always completes so probe state persists.
contract HostilePairTokenSE is MockERC20, IStandardExchangeIn {
    IERC20 public immutable vaultShare;
    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;

    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    constructor(IERC20 vaultShare_) MockERC20("HostilePairToken", "HPAIR", 18) {
        vaultShare = vaultShare_;
    }

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

    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        external
        view
        returns (uint256)
    {
        if (amountIn_ == 0) return 0;
        if (address(tokenIn_) == address(this) && address(tokenOut_) == address(vaultShare)) return amountIn_;
        return 0;
    }

    function exchangeIn(
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        bool pretransferred_,
        uint256 /* deadline_ */
    ) external returns (uint256 amountOut_) {
        if (recipient_ == address(0)) recipient_ = msg.sender;
        if (address(tokenIn_) != address(this) || address(tokenOut_) != address(vaultShare)) {
            revert("HostileSE: route");
        }
        if (!pretransferred_) {
            transferFrom(msg.sender, address(this), amountIn_);
        }
        vaultShare.transfer(recipient_, amountIn_);
        amountOut_ = amountIn_;
        require(amountOut_ >= minAmountOut_, "min");
    }
}

contract CsDetfReentryTarget {
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

    function reenterBond(address detf_, IERC20 tokenIn_, uint256 amountIn_, uint256 lock_, address recipient_)
        external
    {
        IComposedStableCommonDetfBonding(detf_).bond(
            tokenIn_, amountIn_, lock_, recipient_, block.timestamp + 1 hours
        );
    }
}

/// @notice WP-SEC-DETF-CS-LOCK-001 / TOKEN-001 / A0-001 on the production CS proxy.
/// @dev Hostile pairToken is a configured route `baseToken` (not vm.mockCall on SUT).
contract Adversarial_ComposedStable_SecRemediation_Test is ComposedStableCommonDetf_IntegratedDeploy_Test {
    HostilePairTokenSE internal hostilePair;
    CsDetfReentryTarget internal reentryTarget;
    address internal attacker;
    address internal victim;

    uint256 internal constant LOCK_DURATION = 30 days;

    function _composedThresholdMode() internal pure override returns (ThresholdMode) {
        return ThresholdMode.Open;
    }

    function _composedMintThreshold() internal pure override returns (uint256) {
        return 0;
    }

    function _composedBurnThreshold() internal pure override returns (uint256) {
        return 0;
    }

    function _primaryRoutes() internal override returns (ComposedStableCommonDetfRepo.RouteConfig[] memory routes) {
        if (address(hostilePair) == address(0)) {
            hostilePair = new HostilePairTokenSE(IERC20(address(weth)));
            reentryTarget = new CsDetfReentryTarget();
            hostilePair.mint(bob, 1_000_000e18);
        }
        routes = new ComposedStableCommonDetfRepo.RouteConfig[](2);
        routes[0] = ComposedStableCommonDetfRepo.RouteConfig({
            baseToken: dai,
            vaultToken: IERC20(address(daiUsdcVault)),
            underlyingVault: daiUsdcVault,
            stablePoolRouter: stablePoolAdapter,
            commonPoolRouter: commonPoolAdapter,
            stablePoolTokenIndex: 0,
            commonPoolTokenIndex: 0
        });
        routes[1] = ComposedStableCommonDetfRepo.RouteConfig({
            baseToken: IERC20(address(hostilePair)),
            vaultToken: IERC20(address(weth)),
            underlyingVault: IStandardExchangeIn(address(hostilePair)),
            stablePoolRouter: stablePoolAdapter,
            commonPoolRouter: commonPoolAdapter,
            stablePoolTokenIndex: 0,
            commonPoolTokenIndex: 0
        });
    }

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
    }

    function _fundHostileVaultShares(address to_, uint256 wethIn_) internal {
        deal(address(weth), to_, wethIn_, true);
    }

    /* ---------------------------------------------------------------------- */
    /*  C lock                                                                */
    /* ---------------------------------------------------------------------- */

    function test_C1_hostilePairToken_reenterExchangeIn_hitsIsLocked() public {
        _bootstrapReserveGraphBalanced();
        _fundHostileVaultShares(address(hostilePair), 5_000e18);
        uint256 amountIn_ = 50e18;
        vm.startPrank(bob);
        hostilePair.approve(deployedDetfVault, amountIn_);
        uint256 okOut_ = IStandardExchangeIn(deployedDetfVault).exchangeIn(
            IERC20(address(hostilePair)), amountIn_, detfToken, 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(okOut_ > 0, "control mint works");

        bytes memory reentry = abi.encodeCall(
            CsDetfReentryTarget.reenterExchangeIn,
            (deployedDetfVault, IERC20(address(hostilePair)), uint256(1e18), detfToken, bob)
        );
        hostilePair.arm(address(reentryTarget), reentry);

        uint256 balBefore_ = detfToken.balanceOf(bob);
        vm.startPrank(bob);
        hostilePair.approve(deployedDetfVault, amountIn_);
        IStandardExchangeIn(deployedDetfVault).exchangeIn(
            IERC20(address(hostilePair)), amountIn_, detfToken, 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(hostilePair.reentryAttempts(), 1, "nested reentry attempted exactly once");
        assertFalse(hostilePair.nestedCallSucceeded(), "nested exchangeIn must not succeed");
        assertEq(
            hostilePair.nestedErrorSelector(),
            IReentrancyLock.IsLocked.selector,
            "nested exchangeIn must revert IsLocked"
        );
        assertGe(detfToken.balanceOf(bob), balBefore_, "outer path continued after blocked reentry");
    }

    function test_C2_hostilePairToken_reenterBond_hitsIsLocked() public {
        _bootstrapReserveGraphBalanced();
        _fundHostileVaultShares(address(hostilePair), 5_000e18);
        uint256 amountIn_ = 50e18;
        bytes memory reentry = abi.encodeCall(
            CsDetfReentryTarget.reenterBond,
            (deployedDetfVault, IERC20(address(hostilePair)), uint256(1e18), LOCK_DURATION, bob)
        );
        hostilePair.arm(address(reentryTarget), reentry);

        vm.startPrank(bob);
        hostilePair.approve(deployedDetfVault, amountIn_);
        IComposedStableCommonDetfBonding(deployedDetfVault).bond(
            IERC20(address(hostilePair)), amountIn_, LOCK_DURATION, bob, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(hostilePair.reentryAttempts(), 1, "nested reentry attempted exactly once");
        assertFalse(hostilePair.nestedCallSucceeded(), "nested bond must not succeed");
        assertEq(
            hostilePair.nestedErrorSelector(),
            IReentrancyLock.IsLocked.selector,
            "nested bond must revert IsLocked"
        );
    }

    function test_C3_mintReenterBond_hitsIsLocked() public {
        _bootstrapReserveGraphBalanced();
        _fundHostileVaultShares(address(hostilePair), 5_000e18);
        uint256 amountIn_ = 50e18;
        bytes memory reentry = abi.encodeCall(
            CsDetfReentryTarget.reenterBond,
            (deployedDetfVault, IERC20(address(hostilePair)), uint256(1e18), LOCK_DURATION, bob)
        );
        hostilePair.arm(address(reentryTarget), reentry);

        vm.startPrank(bob);
        hostilePair.approve(deployedDetfVault, amountIn_);
        IStandardExchangeIn(deployedDetfVault).exchangeIn(
            IERC20(address(hostilePair)), amountIn_, detfToken, 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(hostilePair.reentryAttempts(), 1, "nested reentry attempted exactly once");
        assertFalse(hostilePair.nestedCallSucceeded(), "nested bond must not succeed");
        assertEq(
            hostilePair.nestedErrorSelector(),
            IReentrancyLock.IsLocked.selector,
            "mint reenter bond must revert IsLocked"
        );
    }

    /* ---------------------------------------------------------------------- */
    /*  F leftover minter                                                     */
    /* ---------------------------------------------------------------------- */

    function test_F_detfToken_ownerIsDetfOrRenounced() public {
        _transferDetfTokenOwnership(deployedDetfVault);
        address shareOwner_ = IMultiStepOwnable(address(detfToken)).owner();
        assertTrue(
            shareOwner_ == address(0) || shareOwner_ == deployedDetfVault,
            "family share leftover EOA owner revoked"
        );
        assertTrue(shareOwner_ != owner, "deployer is not family-share owner");
    }

    function test_F_rebasingClaimToken_ownerIsZero() public view {
        assertEq(IMultiStepOwnable(address(rebasingDetfToken)).owner(), address(0), "satellite owner()==0");
    }

    function test_F_deployer_cannotMintAfterGoLive() public {
        _transferDetfTokenOwnership(deployedDetfVault);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, owner));
        IERC20MintBurn(address(detfToken)).mint(owner, 1e18);
    }

    function test_F_stranger_mint_reverts() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, attacker));
        IERC20MintBurn(address(detfToken)).mint(attacker, 1e18);
    }

    function test_F_onlyDetfOperator_mints() public {
        uint256 before_ = detfToken.balanceOf(deployedDetfVault);
        vm.prank(deployedDetfVault);
        IERC20MintBurn(address(detfToken)).mint(deployedDetfVault, 1e18);
        assertEq(detfToken.balanceOf(deployedDetfVault), before_ + 1e18, "DETF operator still mints");
    }

    function test_F_rebasingClaimToken_strangerMintReverts() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        rebasingDetfToken.mintFromNFTSale(1e18, attacker);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, owner));
        rebasingDetfToken.mintFromNFTSale(1e18, owner);
    }

    /* ---------------------------------------------------------------------- */
    /*  A0 empty / first mint                                                 */
    /* ---------------------------------------------------------------------- */

    function test_A0_cs_preLive_donatedPairToken_cannotBeFirstMinted() public {
        // Fresh instance stays inert until this test bootstraps; donate first.
        address instance_ = _deployOpenModeDetf();
        uint256 donated_ = 500e18;
        deal(address(dai), attacker, donated_, true);
        vm.prank(attacker);
        dai.transfer(instance_, donated_);
        assertEq(dai.balanceOf(instance_), donated_, "pairToken idle on diamond");

        vm.startPrank(attacker);
        dai.approve(instance_, 1_000e18);
        vm.expectRevert();
        IStandardExchangeIn(instance_).exchangeIn(
            dai, 100e18, detfToken, 0, attacker, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertEq(detfToken.balanceOf(attacker), 0, "A0: pre-live mint cannot drain donation");
        assertEq(dai.balanceOf(instance_), donated_, "donation still idle");
    }

    function test_A0_cs_preLive_donatedPairToken_survivesFirstBond() public {
        uint256 donated_ = 400e18;
        deal(address(dai), attacker, donated_, true);
        vm.prank(attacker);
        dai.transfer(deployedDetfVault, donated_);
        assertEq(dai.balanceOf(deployedDetfVault), donated_, "pairToken idle before live");

        _bootstrapReserveGraphBalanced();

        assertEq(dai.balanceOf(deployedDetfVault), donated_, "bootstrap does not consume donated pairToken");
        assertEq(detfToken.balanceOf(attacker), 0, "A0: first bond does not credit donor");
    }
}
