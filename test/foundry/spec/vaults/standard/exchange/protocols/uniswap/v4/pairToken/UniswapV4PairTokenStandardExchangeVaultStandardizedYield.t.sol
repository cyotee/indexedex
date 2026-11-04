// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {PairTokenIOTestBase, PairTokenIOCreditRouter} from "./UniswapV4PairTokenStandardExchangeVaultStandardExchange.t.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {SYUtils} from "@crane/contracts/protocols/perps/pendle/core/StandardizedYield/SYUtils.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {NativeStandardYieldErrors} from "contracts/vaults/standard/sy/NativeStandardYieldErrors.sol";
import {UniswapV4PairTokenStandardExchangeVaultMath as Math} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultMath.sol";

/// @notice Constructor-time internal-share callers must not bypass the code guard.
contract PairTokenSYConstructionCaller {
    constructor(address vault_, address token_) {
        IStandardizedYield(vault_).redeem(msg.sender, 1, token_, 0, true);
    }
}

/// @notice S1-A29-A33: all native SY methods operate on the registered share diamond.
// tag::UniswapV4PairTokenStandardExchangeVaultStandardizedYieldTest[]
contract UniswapV4PairTokenStandardExchangeVaultStandardizedYieldTest is PairTokenIOTestBase {
    function test_SY_FullSurfaceAndEmptyRate() public {
        assertEq(_sy().yieldToken(), address(vault));
        assertEq(_sy().exchangeRate(), 0, "zero supply has no synthetic rate");
        address[] memory in_ = _sy().getTokensIn();
        address[] memory out_ = _sy().getTokensOut();
        assertEq(in_.length, 2);
        assertEq(out_.length, 2);
        for (uint256 i; i < 2; ++i) {
            assertEq(in_[i], i == 0 ? address(token0) : address(token1));
            assertEq(out_[i], in_[i]);
            assertTrue(_sy().isValidTokenIn(in_[i]));
            assertTrue(_sy().isValidTokenOut(in_[i]));
            vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
            _sy().previewDeposit(in_[i], 1e18);
        }
        assertFalse(_sy().isValidTokenIn(address(0)));
        assertFalse(_sy().isValidTokenOut(address(0)));
        (IStandardizedYield.AssetType type_, address asset_, uint8 decimals_) = _sy().assetInfo();
        assertEq(uint256(type_), uint256(IStandardizedYield.AssetType.TOKEN));
        assertEq(asset_, address(token0));
        assertEq(decimals_, 18);
        _bootstrap(1e21, 1e21, address(this));
        assertEq(_share().totalSupply(), 1e21, "full geometric mean, sole receipt");
        _fund(address(this), 1e19, 1e19);
        _fund(address(poolActor), 1e18, 2e18);
        poolActor.donate(key, 1e18, 2e18);
        _assertEmptyRewards();
        _assertStable();
    }

    function test_SY_ExecutionEventsAndSEEqualityBothDirections() public {
        _bootstrap(1e21, 1e21, address(this));
        _fund(address(this), 1e20, 1e20);
        for (uint256 i; i < 2; ++i) {
            address token_ = i == 0 ? address(token0) : address(token1);
            uint256 amount_ = 1e18;
            uint256 quoted_ = _sy().previewDeposit(token_, amount_);
            (uint256 previewAmountOut1,) = _se().previewExchangeIn(IERC20(token_), amount_, _share());
            assertEq(quoted_, previewAmountOut1);
            uint256 snapshot_ = vm.snapshotState();_se().exchangeIn(IERC20(token_), amount_, _share(), quoted_, address(this), false, block.timestamp);
            bytes32 expected_ = _stateHash();
            assertTrue(vm.revertToState(snapshot_));
            uint256 supply_ = _share().totalSupply();
            uint256 balance_ = IERC20(token_).balanceOf(address(this));
            vm.expectEmit(true, true, true, true, address(vault));
            emit IStandardizedYield.Deposit(address(this), address(this), token_, amount_, quoted_);
            assertEq(_sy().deposit(address(this), token_, amount_, quoted_), quoted_);
            assertEq(_stateHash(), expected_, "SE and SY deposit state equality");
            assertEq(IERC20(token_).balanceOf(address(this)), balance_ - amount_);
            assertEq(_share().totalSupply(), supply_ + quoted_);
            _assertStable();

            uint256 shares_ = _share().balanceOf(address(this)) / 100;
            quoted_ = _sy().previewRedeem(token_, shares_);
            (uint256 previewAmountOut2,) = _se().previewExchangeIn(_share(), shares_, IERC20(token_));
            assertEq(quoted_, previewAmountOut2);
            snapshot_ = vm.snapshotState();_se().exchangeIn(_share(), shares_, IERC20(token_), quoted_, address(this), false, block.timestamp);
            expected_ = _stateHash();
            assertTrue(vm.revertToState(snapshot_));
            supply_ = _share().totalSupply();
            balance_ = IERC20(token_).balanceOf(address(this));
            vm.expectEmit(true, true, true, true, address(vault));
            emit IStandardizedYield.Redeem(address(this), address(this), token_, shares_, quoted_);
            assertEq(_sy().redeem(address(this), shares_, token_, quoted_, false), quoted_);
            assertEq(_stateHash(), expected_, "SE and SY redeem state equality");
            assertEq(IERC20(token_).balanceOf(address(this)), balance_ + quoted_);
            assertEq(_share().totalSupply(), supply_ - shares_);
            _assertStable();
        }
    }

    function test_SY_InternalShareAuthorityMissingShortAndExcess() public {
        _bootstrap(1e21, 1e21, address(this));
        PairTokenIOCreditRouter router_ = new PairTokenIOCreditRouter();
        uint256 amount_ = 1e18;
        bytes32 before_ = _stateHash();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, amount_, 0));
        router_.redeemInternal(address(vault), 0, amount_, address(token0), address(this));
        assertEq(_stateHash(), before_);
        _share().transfer(address(router_), amount_ * 2);
        before_ = _stateHash();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, amount_, amount_ - 1));
        router_.redeemInternal(address(vault), amount_ - 1, amount_, address(token0), address(this));
        assertEq(_stateHash(), before_);
        assertEq(_share().balanceOf(address(router_)), amount_ * 2, "failed staging rolled back");
        uint256 expected_ = _sy().previewRedeem(address(token0), amount_);
        uint256 supply_ = _share().totalSupply();
        uint256 received_ = token0.balanceOf(address(this));
        assertEq(router_.redeemInternal(address(vault), amount_ * 2, amount_, address(token0), address(this)), expected_);
        assertEq(_share().totalSupply(), supply_ - amount_);
        assertEq(_share().balanceOf(address(vault)), amount_, "excess held shares not burned/refunded");
        assertEq(_share().balanceOf(address(router_)), 0);
        assertEq(token0.balanceOf(address(this)), received_ + expected_);
        _assertStable();
    }

    function test_SY_InternalEOAAndConstructorRejectEvenWithHeldShares() public {
        _bootstrap(1e21, 1e21, address(this));
        _share().transfer(address(vault), 1e18);
        bytes32 before_ = _stateHash();
        vm.prank(address(0xa11ce));
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        _sy().redeem(address(this), 1, address(token0), 0, true);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        new PairTokenSYConstructionCaller(address(vault), address(token0));
        assertEq(_stateHash(), before_);
    }

    function test_SY_FalseFlagCannotBurnAnotherHoldersShares() public {
        _bootstrap(1e21, 1e21, address(this));
        address attacker_ = address(0xbad);
        bytes32 before_ = _stateHash();
        vm.prank(attacker_);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, attacker_, 0, 1e18));
        _sy().redeem(address(this), 1e18, address(token0), 0, false);
        assertEq(_stateHash(), before_);
    }

    function test_SY_InvalidTokensZeroPreviewsButExecutionReverts() public {
        address invalid_ = address(0xbad);
        assertEq(_sy().previewDeposit(invalid_, 1), 0);
        assertEq(_sy().previewRedeem(invalid_, 1), 0);
        assertFalse(_sy().isValidTokenIn(invalid_));
        assertFalse(_sy().isValidTokenOut(invalid_));
        bytes32 before_ = _stateHash();
        vm.expectRevert(abi.encodeWithSelector(NativeStandardYieldErrors.InvalidSYToken.selector, invalid_));
        _sy().deposit(address(this), invalid_, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(NativeStandardYieldErrors.InvalidSYToken.selector, invalid_));
        _sy().redeem(address(this), 1, invalid_, 0, false);
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        _sy().previewDeposit(address(token0), 1);
        vm.expectRevert(Math.InvalidAllocation.selector);
        _sy().previewRedeem(address(token0), 1);
        assertEq(_stateHash(), before_, "valid economic failure not zero success");
    }

    function test_SY_ValidationReceiverAmountAndNativeValue() public {
        _bootstrap(1e21, 1e21, address(this));
        _fund(address(this), 1e18, 1e18);
        vm.deal(address(this), 1 ether);
        bytes32 before_ = _stateHash();
        for (uint256 i; i < 2; ++i) {
            address invalid_ = i == 0 ? address(0) : address(vault);
            vm.expectRevert(NativeStandardYieldErrors.InvalidSYReceiver.selector);
            _sy().deposit(invalid_, address(token0), 1, 0);
            vm.expectRevert(NativeStandardYieldErrors.InvalidSYReceiver.selector);
            _sy().redeem(invalid_, 1, address(token0), 0, false);
        }
        vm.expectRevert(NativeStandardYieldErrors.ZeroSYAmount.selector);
        _sy().deposit(address(this), address(token0), 0, 0);
        vm.expectRevert(NativeStandardYieldErrors.ZeroSYAmount.selector);
        _sy().redeem(address(this), 0, address(token0), 0, false);
        vm.expectRevert(NativeStandardYieldErrors.UnsupportedNativePayment.selector);
        _sy().deposit{value: 1}(address(this), address(token0), 1, 0);
        vm.expectRevert(abi.encodeWithSelector(NativeStandardYieldErrors.InvalidSYToken.selector, address(0)));
        _sy().deposit{value: 1}(address(this), address(0), 1, 0);
        assertEq(_stateHash(), before_);
    }

    function test_SY_RawRateCachedMetadataSixEightEighteenDecimals() public {
        uint8[3] memory decimals_ = [uint8(6), uint8(8), uint8(18)];
        for (uint256 i; i < decimals_.length; ++i) {
            _deployPool(false, decimals_[i], 18);
            address asset_ = IERC20Metadata(address(token0)).decimals() == decimals_[i] ? address(token0) : address(token1);
            vault = _deployVault(_defaultArgs(key, asset_, "mixed-decimal SY"));
            assertEq(_sy().exchangeRate(), 0);
            _bootstrap(1e12, 1e12, address(this));
            (IStandardizedYield.AssetType type_, address actualAsset_, uint8 actualDecimals_) = _sy().assetInfo();
            assertEq(uint256(type_), uint256(IStandardizedYield.AssetType.TOKEN));
            assertEq(actualAsset_, asset_);
            assertEq(actualDecimals_, decimals_[i]);
            // Pool price is exactly Q96 and no fees/swap occurred: one rational
            // conversion is identity in raw units regardless of token metadata.
            (uint256 basket0_, uint256 basket1_) = vault.basket();
            uint256 rawValue_ = basket0_ + basket1_;
            uint256 expectedRate_ = rawValue_ * 1e18 / _share().totalSupply();
            assertEq(_sy().exchangeRate(), expectedRate_);
            assertEq(SYUtils.syToAsset(expectedRate_, 1e18), expectedRate_);
            assertEq(SYUtils.syToAsset(expectedRate_, _share().totalSupply()),
                _share().totalSupply() * expectedRate_ / 1e18);
            _assertStable();
        }
    }

    /// @notice A32: raw conversion floors at a non-unit rational price in both orientations.
    function test_SY_NonUnitFractionRateBothAssetsAndDecimals() public {
        uint8[3] memory decimals_ = [uint8(6), uint8(8), uint8(18)];
        for (uint256 i_; i_ < decimals_.length; ++i_) {
            _deployPool(false, decimals_[i_], 18);
            key.fee = 500;
            pool.initialize(key, uint160(3) << 95); // sqrt price = 3/2, price = 9/4.
            for (uint256 j_; j_ < 2; ++j_) {
                address asset_ = j_ == 0 ? address(token0) : address(token1);
                vault = _deployVault(_defaultArgs(key, asset_, "fractional raw SY"));
                _bootstrap(1e12, 1e12, address(this));
                _fund(address(this), 17, 29);
                vault.donate(address(token0), 17);
                vault.donate(address(token1), 29);
                (uint256 a0_, uint256 a1_) = vault.basket();
                uint256 value_ = j_ == 0 ? a0_ + a1_ * 4 / 9 : a1_ + a0_ * 9 / 4;
                uint256 supply_ = _share().totalSupply();
                uint256 rate_ = value_ * 1e18 / supply_;
                assertEq(_sy().exchangeRate(), rate_, "independent rational conversion");
                uint256 shares_ = supply_ / 7 + 1;
                assertEq(SYUtils.syToAsset(rate_, shares_), shares_ * rate_ / 1e18);
                assertEq(SYUtils.assetToSy(rate_, 1_000_003), 1_000_003 * uint256(1e18) / rate_);
                (, address observed_, uint8 cached_) = _sy().assetInfo();
                assertEq(observed_, asset_);
                assertEq(cached_, IERC20Metadata(asset_).decimals());
            }
        }
    }

    function _assertEmptyRewards() internal {
        bytes32 before_ = _stateHash();
        assertEq(_sy().getRewardTokens().length, 0);
        assertEq(_sy().accruedRewards(address(this)).length, 0);
        assertEq(_sy().rewardIndexesStored().length, 0);
        assertEq(_sy().rewardIndexesCurrent().length, 0);
        vm.expectEmit(true, false, false, true, address(vault));
        emit IStandardizedYield.ClaimRewards(address(this), new address[](0), new uint256[](0));
        assertEq(_sy().claimRewards(address(this)).length, 0);
        assertEq(_stateHash(), before_, "LP backing cannot be claimed as external rewards");
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultStandardizedYieldTest[]
