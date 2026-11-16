// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IUniswapV4SeBufferHook, IUniswapV4SeBufferHookNativeLiquidity} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookMath as Sphere} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {HookComponentAccountingBehavior} from "../HookComponentAccountingBehavior.sol";
import {UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault as FullSpreadRow} from "./UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";

/// @notice Real FullSpread component-accounting adapter; no substitute vault or synthetic balances.
contract UniswapV4StandardExchangeOrbitalBufferHook_ComponentAccounting is FullSpreadRow, HookComponentAccountingBehavior {
    struct NativeJoinControl {
        uint256[3] local;
        uint256[3] shares;
        uint256[3] bookLocal;
        uint256[3] bookShares;
        uint256[3] rate;
    }

    /// @notice Mixed inventory buys even nonzero deficient legs, without an SE round trip.
    function test_component_nativeMixedPaysAndMintsAgainstPostTradeBook() public {
        _hbSetFee(HB_FEE);
        _setDexFee(3e15);
        _hbBootstrap();
        (uint256[] memory local, uint256[] memory shares) = _fundNativeMixed();
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        NativeJoinControl memory control = _nativePaidControl(before_, local, shares);
        uint256 gross = type(uint256).max;
        for (uint8 i; i < 3; ++i) {
            if (control.bookLocal[i] != 0) gross = FullMath.min(gross,
                FullMath.mulDiv(control.local[i], before_.supply, control.bookLocal[i]));
            if (control.bookShares[i] != 0) gross = FullMath.min(gross,
                FullMath.mulDiv(control.shares[i], before_.supply, control.bookShares[i]));
        }
        uint256 expected = gross - FullMath.mulDiv(gross, HB_FEE, 1e18);
        IUniswapV4SeBufferHookNativeLiquidity native = IUniswapV4SeBufferHookNativeLiquidity(hook);
        assertGt(expected, 0);
        assertEq(native.previewJoinNativeComponents(local, shares), expected, "independent post-paid mint");
        vm.expectCall(seUT0, abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector), uint64(0));
        vm.expectCall(seUT1, abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector), uint64(0));
        vm.prank(HB_BOB);
        uint256 net = native.joinNativeComponents(local, shares, HB_BOB, expected, block.timestamp);
        assertEq(net, expected, "preview parity");
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        _hbAssertFee(before_, after_, net);
        bool refundedLocal;
        bool refundedShares;
        for (uint8 i; i < 3; ++i) {
            uint256 acceptedLocal = FullMath.mulDiv(gross, control.bookLocal[i], before_.supply, FullMath.Rounding.Ceil);
            uint256 acceptedShares = FullMath.mulDiv(gross, control.bookShares[i], before_.supply, FullMath.Rounding.Ceil);
            uint256 localRefund = control.local[i] - acceptedLocal;
            uint256 shareRefund = control.shares[i] - acceptedShares;
            refundedLocal = refundedLocal || localRefund != 0;
            refundedShares = refundedShares || shareRefund != 0;
            assertEq(after_.pairs[i], control.bookLocal[i] + acceptedLocal, "post-trade ceil local ownership");
            assertEq(after_.shares[i], control.bookShares[i] + acceptedShares, "post-trade ceil share ownership");
            assertEq(after_.userPairs[i], before_.userPairs[i] - local[i] + localRefund, "actual local refund");
            assertEq(after_.userShares[i], before_.userShares[i] - shares[i] + shareRefund, "actual share refund");
            assertEq(before_.pairs[i] + local[i], after_.pairs[i] + localRefund, "native local conservation");
            assertEq(before_.shares[i] + shares[i], after_.shares[i] + shareRefund, "native share conservation");
            assertEq(after_.shareSupply[i], before_.shareSupply[i], "no consolidation or redeposit");
            assertEq(orbital.rawReserve(i), after_.pairs[i], "no orphan local custody");
            assertEq(orbital.seBalance(i), after_.shares[i], "no orphan share custody");
        }
        assertTrue(refundedLocal, "nonlimiting local refunded");
        assertTrue(refundedShares, "nonlimiting shares refunded");
    }

    function test_component_nativeConvertsOnlyStillMissingLocal() public {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 10 ether);
        _hbFundShares(HB_BOB, 10 ether);
        uint256[] memory local = new uint256[](3);
        uint256[] memory shares = new uint256[](3);
        shares[0] = orbital.seBalance(0) / 20;
        local[1] = orbital.rawReserve(1) / 100;
        shares[1] = orbital.seBalance(1) / 100;
        local[2] = orbital.rawReserve(2) / 100;
        IUniswapV4SeBufferHookNativeLiquidity native = IUniswapV4SeBufferHookNativeLiquidity(hook);
        uint256 quote = native.previewJoinNativeComponents(local, shares);
        assertGt(quote, 0);
        uint256 seSupply = IERC20(seUT0).totalSupply();
        vm.expectCall(seUT0, abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector, IERC20(seUT0)));
        vm.expectCall(seUT1, abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector), uint64(0));
        vm.prank(HB_BOB);
        assertEq(native.joinNativeComponents(local, shares, HB_BOB, quote, block.timestamp), quote);
        assertLt(IERC20(seUT0).totalSupply(), seSupply, "only missing local is redeemed");
        for (uint8 i; i < 3; ++i) {
            assertEq(orbital.rawReserve(i), IERC20(_hbPairs()[i]).balanceOf(hook));
            if (i < 2) assertEq(orbital.seBalance(i), IERC20(_hbExchanges()[i]).balanceOf(hook));
        }
    }

    function _fundNativeMixed() private returns (uint256[] memory local, uint256[] memory shares) {
        _hbFundPairs(HB_BOB, 10 ether);
        _hbFundShares(HB_BOB, 10 ether);
        local = new uint256[](3);
        shares = new uint256[](3);
        for (uint8 i; i < 3; ++i) {
            uint256 divisor = i == 0 ? 100 : i == 1 ? 200 : 10;
            local[i] = orbital.rawReserve(i) / divisor;
            shares[i] = orbital.seBalance(i) / divisor;
            assertGt(local[i], 0, "all legs nonempty before paid preparation");
            if (i < 2) assertGt(shares[i], 0, "explicit mixed buffered inventory");
        }
    }

    /// @dev Fixture-specific independent oracle: raw leg 2 is the sole excess seller.
    /// Both nonzero buffered buyers receive their incumbent native proportions.
    function _nativePaidControl(ComponentSnapshot memory before_, uint256[] memory local, uint256[] memory shares)
        private view returns (NativeJoinControl memory c)
    {
        uint256[3] memory bookValue;
        uint256[3] memory offered;
        uint256 totalBook;
        uint256 totalOffered;
        for (uint8 i; i < 3; ++i) {
            c.local[i] = local[i];
            c.shares[i] = shares[i];
            c.bookLocal[i] = before_.pairs[i];
            c.bookShares[i] = before_.shares[i];
            c.rate[i] = i < 2 ? IRateProvider(orbital.rateProvider(_hbPairs()[i])).getRate() : 0;
            // This real FullSpread row uses 18 decimal pair and share units.
            bookValue[i] = before_.pairs[i] + FullMath.mulDiv(before_.shares[i], c.rate[i], 1e18);
            offered[i] = local[i] + FullMath.mulDiv(shares[i], c.rate[i], 1e18);
            totalBook += bookValue[i];
            totalOffered += offered[i];
        }
        uint256[2] memory deficit;
        for (uint8 j; j < 2; ++j) {
            uint256 target = FullMath.mulDiv(totalOffered, bookValue[j], totalBook);
            assertGt(target, offered[j], "nonzero leg is nevertheless deficient");
            deficit[j] = target - offered[j];
        }
        uint256 excess = offered[2] - FullMath.mulDiv(totalOffered, bookValue[2], totalBook);
        uint256 fee = IVaultFeeOracleQuery(address(indexedexManager)).dexSwapFeeOfVault(hook);
        for (uint8 j; j < 2; ++j) {
            uint256 sale = FullMath.mulDiv(excess, deficit[j], deficit[0] + deficit[1]);
            uint256[3] memory e;
            for (uint8 k; k < 3; ++k) e[k] = c.bookLocal[k] + FullMath.mulDiv(c.bookShares[k], c.rate[k], 1e18);
            uint256 budget = Sphere.sphereLiquidityExactInOutWad(orbital.radius(),
                Sphere.recomputeL2(orbital.radius(), e[2], e[j], e[1 - j]),
                e[2], e[j], e[1 - j], Sphere.applyTradingFeeNet(sale, fee));
            uint256 boughtLocal = FullMath.mulDiv(c.bookLocal[j], budget, e[j]);
            uint256 boughtShares = FullMath.mulDiv(c.bookShares[j], budget, e[j]);
            assertGt(boughtLocal, 0);
            assertGt(boughtShares, 0);
            c.local[2] -= sale;
            c.bookLocal[2] += sale;
            c.bookLocal[j] -= boughtLocal;
            c.bookShares[j] -= boughtShares;
            c.local[j] += boughtLocal;
            c.shares[j] += boughtShares;
        }
    }

    function test_component_nativeLiveOnlyAndArrayValidation() public {
        IUniswapV4SeBufferHookNativeLiquidity native = IUniswapV4SeBufferHookNativeLiquidity(hook);
        uint256[] memory local = new uint256[](3);
        uint256[] memory shares = new uint256[](3);
        vm.expectRevert(bytes4(keccak256("NotLive()")));
        native.previewJoinNativeComponents(local, shares);
        vm.prank(HB_BOB);
        vm.expectRevert(bytes4(keccak256("NotLive()")));
        native.joinNativeComponents(local, shares, HB_BOB, 0, block.timestamp);
        vm.expectRevert(abi.encodeWithSignature("InvalidRoute(address,address)", address(0), address(0)));
        native.previewJoinNativeComponents(new uint256[](2), shares);
        vm.prank(HB_BOB);
        vm.expectRevert(abi.encodeWithSignature("InvalidRoute(address,address)", address(0), address(0)));
        native.joinNativeComponents(local, new uint256[](4), HB_BOB, 0, block.timestamp);
        _hbBootstrap();
        shares[2] = 1;
        vm.expectRevert(bytes4(keccak256("InvalidSeShareLeg()")));
        native.previewJoinNativeComponents(local, shares);
        vm.prank(HB_BOB);
        vm.expectRevert(bytes4(keccak256("InvalidSeShareLeg()")));
        native.joinNativeComponents(local, shares, HB_BOB, 0, block.timestamp);
    }

    function test_component_nativeMinimumDeadlineAndRecipientRestoreInventory() public {
        _hbBootstrap();
        (uint256[] memory local, uint256[] memory shares) = _fundNativeMixed();
        IUniswapV4SeBufferHookNativeLiquidity native = IUniswapV4SeBufferHookNativeLiquidity(hook);
        bytes memory before_ = _strictJoinState(HB_BOB);
        assertGt(native.previewJoinNativeComponents(local, shares), 0);
        vm.prank(HB_BOB);
        vm.expectRevert(bytes4(keccak256("InsufficientSharesOut()")));
        native.joinNativeComponents(local, shares, HB_BOB, type(uint256).max, block.timestamp);
        assertEq(_strictJoinState(HB_BOB), before_, "minimum restores paid trades and both inventories");
        vm.warp(block.timestamp + 2);
        vm.prank(HB_BOB);
        vm.expectRevert(bytes4(keccak256("DeadlineExpired()")));
        native.joinNativeComponents(local, shares, HB_BOB, 0, block.timestamp - 1);
        vm.prank(HB_BOB);
        vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
        native.joinNativeComponents(local, shares, address(0), 0, block.timestamp);
        assertEq(_strictJoinState(HB_BOB), before_);
    }

    function _hbHook() internal view override returns (address) { return hook; }

    function _hbPairs() internal view override returns (address[] memory pairs_) {
        pairs_ = new address[](3);
        pairs_[0] = face0; pairs_[1] = face1; pairs_[2] = face2;
    }

    function _hbExchanges() internal view override returns (address[] memory exchanges_) {
        exchanges_ = new address[](3);
        exchanges_[0] = seUT0; exchanges_[1] = seUT1;
    }

    function _hbSetFee(uint256 fee_) internal override {
        if (fee_ == 0) {
            // Zero clears the vault override; clear the fixture's global fallback too.
            vm.prank(owner);
            IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        }
        _setUsageFee(fee_);
        assertEq(IVaultFeeOracleQuery(address(indexedexManager)).usageFeeOfVault(hook),
            fee_, "configured hook LP fee");
    }
    function _hbFeeRecipient() internal view override returns (address) { return orbital.feeTo(); }

    function _hbFundShares(address actor_, uint256 budget_) internal override returns (uint256[] memory amounts_) {
        address[] memory pairs_ = _hbPairs();
        address[] memory exchanges_ = _hbExchanges();
        amounts_ = new uint256[](pairs_.length);
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            address input_ = exchanges_[i_];
            if (input_ == address(0)) {
                input_ = pairs_[i_];
                SimpleMintableERC20(input_).mint(actor_, budget_);
                amounts_[i_] = budget_;
            } else {
                amounts_[i_] = fullSpread.acquireShares(input_, pairs_[i_], actor_, budget_);
            }
            vm.prank(actor_);
            IERC20(input_).approve(hook, type(uint256).max);
        }
    }

    function _hbFundPairs(address actor_, uint256 budget_) internal override returns (uint256[] memory amounts_) {
        address[] memory pairs_ = _hbPairs();
        amounts_ = new uint256[](pairs_.length);
        for (uint256 i_; i_ < pairs_.length; ++i_) {
            SimpleMintableERC20(pairs_[i_]).mint(actor_, budget_);
            amounts_[i_] = budget_;
            vm.prank(actor_);
            IERC20(pairs_[i_]).approve(hook, type(uint256).max);
        }
    }

    function _hbJoinShares(address actor_, uint256[] memory amounts_, uint256 minimum_)
        internal override returns (uint256 net_)
    {
        vm.prank(actor_);
        (net_,,,) = orbital.depositFlexible(amounts_[0], true, amounts_[1], true, amounts_[2], false, actor_, minimum_, block.timestamp);
    }

    function _hbJoinPairs(address actor_, uint256[] memory amounts_, uint256 minimum_)
        internal override returns (uint256 net_)
    {
        vm.prank(actor_);
        (net_,,,) = orbital.addLiquidity(amounts_[0], amounts_[1], amounts_[2], actor_, minimum_, block.timestamp, "");
    }

    function _hbExitPairs(address actor_, uint256 burned_) internal override {
        vm.prank(actor_);
        orbital.removeLiquidity(burned_, actor_, 1, 1, 1, block.timestamp);
    }

    function _hbMoveUnderlyingMarket() internal override {
        fullSpread.acquireShares(seUT0, face0, address(0xCAFE40), 50_000 ether);
    }

    function _hbRate() internal view override returns (uint256) { return IRateProvider(orbital.rateProvider(face0)).getRate(); }
    function _hbMinimumError() internal pure override returns (bytes4) { return bytes4(keccak256("InsufficientSharesOut()")); }
    function _hbInitialPairError() internal pure override returns (bytes4) { return bytes4(keccak256("InvalidRoute(address,address)")); }
    function _hbInitialPairErrorData() internal view override returns (bytes memory) {
        return abi.encodeWithSelector(_hbInitialPairError(), face0, seUT0);
    }

    function _hbDisable(bool byPackage_, bool disabled_) internal override {
        address package_ = fullSpread.pkg();
        vm.prank(owner);
        if (byPackage_) IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(package_, disabled_);
        else IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(seUT0, disabled_);
    }

    function _hbTrade(address actor_, uint256 inputIndex_, uint256 outputIndex_, uint256 amount_)
        internal override returns (uint256 output_)
    {
        address[] memory pairs_ = _hbPairs();
        vm.prank(actor_);
        (output_,) = IStandardExchangeIn(hook).exchangeIn(
            IERC20(pairs_[inputIndex_]), amount_, IERC20(pairs_[outputIndex_]), 1, actor_, false, block.timestamp
        );
    }

    /// @notice Unsupported exact-net is a product rejection, not a skipped LP assertion.
    function test_HB47_exactNetRejectedAndRollsBack() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        address token_ = _hbPairs()[1];
        assertEq(IUniswapV4SeBufferHook(hook).previewJoinSingleAssetExactOut(token_, 1 ether), 0);
        vm.prank(HB_BOB);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidRoute(address,address)")), token_, address(0)));
        IUniswapV4SeBufferHook(hook).joinSingleAssetExactOut(token_, 1 ether, HB_BOB, 100 ether, block.timestamp);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(before_), "unsupported exact-net restores every leg");
    }

    function test_component_exactLocalEqualityNeedsNoSeExactOutput() public {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        uint256 local = orbital.rawReserve(0);
        uint256 shares = orbital.seBalance(0);
        uint256 seSupply = IERC20(seUT0).totalSupply();
        uint256 needed = IStandardExchangeOut(hook).previewExchangeOut(IERC20(face2), IERC20(face0), local);
        uint256 beforeOut = IERC20(face0).balanceOf(HB_BOB);
        vm.expectCall(seUT0, abi.encodeWithSelector(IStandardExchangeOut.exchangeOut.selector), uint64(0));
        vm.prank(HB_BOB);
        uint256 used = IStandardExchangeOut(hook).exchangeOut(
            IERC20(face2), needed, IERC20(face0), local, HB_BOB, false, block.timestamp
        );
        assertEq(used, needed);
        assertEq(IERC20(face0).balanceOf(HB_BOB) - beforeOut, local);
        assertEq(orbital.rawReserve(0), 0);
        assertEq(orbital.seBalance(0), shares);
        assertEq(IERC20(seUT0).totalSupply(), seSupply);
        vm.expectRevert(bytes4(keccak256("InsufficientTokenOut()")));
        IStandardExchangeOut(hook).previewExchangeOut(IERC20(face2), IERC20(face0), 1 ether);
    }

    function test_component_partialInputRefundIsBookedOnce() public {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 10 ether);
        (uint256 acquired, uint256 refund) = IStandardExchangeIn(seUT0).previewExchangeIn(
            IERC20(face0), 10 ether, IERC20(seUT0)
        );
        assertGt(refund, 0);
        assertLt(refund, 10 ether);
        uint256 local = orbital.rawReserve(0);
        uint256 shares = orbital.seBalance(0);
        uint256 supply = IERC20(hook).totalSupply();
        assertGt(_hbTrade(HB_BOB, 0, 2, 10 ether), 0);
        assertEq(orbital.rawReserve(0), local + refund);
        assertEq(orbital.seBalance(0), shares + acquired);
        assertEq(IERC20(face0).balanceOf(hook), local + refund);
        assertEq(IERC20(hook).totalSupply(), supply);
    }

    function test_component_allRefundInputStillFundsLocalSwap() public {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 1 ether);
        (uint256 acquired, uint256 refund) = IStandardExchangeIn(seUT0).previewExchangeIn(
            IERC20(face0), 1, IERC20(seUT0)
        );
        assertEq(acquired, 0);
        assertEq(refund, 1, "real dust mint returns all input");
        uint256 local = orbital.rawReserve(0);
        uint256 shares = orbital.seBalance(0);
        uint256 quote = orbital.previewSwapExactIn(face0, face2, 1);
        assertGt(quote, 0, "local unit has an executable sphere payout");
        assertEq(_hbTrade(HB_BOB, 0, 2, 1), quote);
        assertEq(orbital.rawReserve(0), local + 1);
        assertEq(orbital.seBalance(0), shares);
    }

    function test_component_disabledShareExitAddressRollsBack() public { _disabledShareExit(false); }
    function test_component_disabledShareExitPackageRollsBack() public { _disabledShareExit(true); }

    function _disabledShareExit(bool byPackage) private {
        _hbBootstrap();
        _hbDisable(byPackage, true);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        uint256 burn = before_.userLp / 4;
        vm.prank(HB_ALICE);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, seUT0));
        orbital.withdrawFlexible(burn, HB_ALICE, true, false, false, 0, 0, 0, block.timestamp);
        assertEq(abi.encode(_hbSnapshot(HB_ALICE)), abi.encode(before_));
        _hbExitPairs(HB_ALICE, burn);
        assertEq(IERC20(hook).totalSupply(), before_.supply - burn, "permitted pair exit reaches execution");
    }

    function test_component_proportionalAliasUsesCommonBasket() public { _pairAlias(0); }
    function test_component_flexibleAliasUsesCommonBasket() public { _pairAlias(1); }
    function test_component_unbalancedAliasUsesCommonBasket() public { _pairAlias(2); }
    function test_component_permit2AliasUsesCommonBasket() public { _pairAlias(3); }

    function test_component_shareRedemptionsMatchPreIntakeCeils() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts = _hbFundShares(HB_BOB, 10 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        (uint256 quote,,,) = orbital.previewDepositFlexible(amounts[0], true, amounts[1], true, amounts[2], false);
        assertGt(quote, 0, "complete caller-owned basket remains supported");
        vm.expectCall(seUT0, abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector, IERC20(seUT0)));
        vm.expectCall(seUT1, abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector, IERC20(seUT1)));
        uint256 net = _hbJoinShares(HB_BOB, amounts, quote);
        assertEq(net, quote);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        _hbAssertContributions(before_, after_);
        _hbAssertFee(before_, after_, net);
        for (uint8 i; i < 3; ++i) {
            assertEq(orbital.rawReserve(i), after_.pairs[i], "accepted local custody only");
            assertEq(orbital.seBalance(i), after_.shares[i], "accepted shares only");
        }
    }

    function _pairAlias(uint8 mode) private {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts = _hbFundPairs(HB_BOB, 10 ether);
        address[] memory pairs = _hbPairs();
        if (mode == 3) {
            vm.startPrank(HB_BOB);
            for (uint256 i; i < 3; ++i) {
                IERC20(pairs[i]).approve(PERMIT2_ADDR, amounts[i]);
                IAllowanceTransfer(PERMIT2_ADDR).approve(pairs[i], hook, uint160(amounts[i]), type(uint48).max);
            }
            vm.stopPrank();
        }
        (uint256 quote,,,) = orbital.previewAddLiquidity(amounts[0], amounts[1], amounts[2]);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        uint256 net;
        vm.prank(HB_BOB);
        if (mode == 0) (net,) = orbital.joinProportional(amounts, HB_BOB, quote, block.timestamp);
        else if (mode == 1) (net,,,) = orbital.depositFlexible(
            amounts[0], false, amounts[1], false, amounts[2], false, HB_BOB, quote, block.timestamp
        );
        else if (mode == 2) net = orbital.joinUnbalanced(pairs, amounts, HB_BOB, quote, block.timestamp);
        else (net,,,) = orbital.addLiquidity(
            amounts[0], amounts[1], amounts[2], HB_BOB, quote, block.timestamp, abi.encode(uint8(1))
        );
        assertGt(net, 0);
        assertEq(net, quote);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        _hbAssertContributions(before_, after_);
        _hbAssertFee(before_, after_, net);
    }

    function test_component_seFacadeSingleJoinPaysForBasket() public { _singleFacade(0, false); }
    function test_component_syFacadeSingleJoinPaysForBasket() public { _singleFacade(1, false); }
    function test_component_directZapPaysForBasket() public { _singleFacade(2, false); }
    function test_component_singleJoinPaysForBasket() public { _singleFacade(3, false); }
    function test_component_permit2ZapPaysForBasket() public { _singleFacade(4, false); }
    function test_component_seFacadeShareJoinPaysForBasket() public { _singleFacade(0, true); }
    function test_component_syFacadeShareJoinPaysForBasket() public { _singleFacade(1, true); }
    function test_component_singleShareJoinPaysForBasket() public { _singleFacade(3, true); }

    function _strictJoinState(address actor) private view returns (bytes memory) {
        uint256[3] memory local;
        uint256[3] memory shares;
        for (uint8 i; i < 3; ++i) {
            local[i] = orbital.rawReserve(i);
            shares[i] = orbital.seBalance(i);
        }
        return abi.encode(_hbSnapshot(actor), local, shares, orbital.radius(), orbital.lSquared());
    }

    function _singleFacade(uint8 mode, bool asShare) private {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts = asShare ? _hbFundShares(HB_BOB, 3 ether) : _hbFundPairs(HB_BOB, 3 ether);
        address input = asShare ? seUT0 : face2;
        uint256 amount = amounts[asShare ? 0 : 2];
        if (mode == 4) {
            vm.startPrank(HB_BOB);
            IERC20(input).approve(PERMIT2_ADDR, amount);
            IAllowanceTransfer(PERMIT2_ADDR).approve(input, hook, uint160(amount), type(uint48).max);
            vm.stopPrank();
        }
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        (uint256 quote, uint256 refund) = IStandardExchangeIn(hook).previewExchangeIn(IERC20(input), amount, IERC20(hook));
        assertGt(quote, 0, "caller-paid sales prepare the missing components");
        assertLt(refund, amount);
        assertEq(IStandardizedYield(hook).previewDeposit(input, amount), quote);
        assertEq(orbital.previewJoinSingleAssetExactIn(input, amount), quote);
        if (!asShare) assertEq(orbital.previewDepositSingle(input, amount), quote);
        vm.expectCall(seUT1, abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector), uint64(0));
        if (!asShare) vm.expectCall(seUT0, abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector), uint64(0));
        vm.prank(HB_BOB);
        uint256 net;
        if (mode == 1) net = IStandardizedYield(hook).deposit(HB_BOB, input, amount, quote);
        else if (mode == 2 || mode == 4) net = orbital.depositSingle(input, amount, HB_BOB, quote, block.timestamp,
            mode == 4 ? abi.encode(uint8(1)) : bytes(""));
        else if (mode == 3) net = orbital.joinSingleAssetExactIn(input, amount, HB_BOB, quote, block.timestamp);
        else (net,) = IStandardExchangeIn(hook).exchangeIn(IERC20(input), amount, IERC20(hook), quote, HB_BOB, false, block.timestamp);
        assertEq(net, quote);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertEq(after_.userLp - before_.userLp, net);
        _hbAssertFee(before_, after_, net);
        for (uint8 i; i < 3; ++i) {
            assertEq(IERC20(_hbPairs()[i]).balanceOf(hook), orbital.rawReserve(i), "no caller dust left unbooked");
        }
    }

    function test_component_partialFlexiblePurchasesMissingLeg() public { _partialBasket(0); }
    function test_component_partialUnbalancedPurchasesMissingLeg() public { _partialBasket(1); }
    function test_component_partialProportionalPurchasesMissingLeg() public { _partialBasket(2); }

    function test_component_paidSingleMinimumRestoresTradesAndInventory() public {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 10 ether);
        bytes memory before_ = _strictJoinState(HB_BOB);
        assertGt(orbital.previewJoinSingleAssetExactIn(face2, 3 ether), 0);
        vm.prank(HB_BOB);
        vm.expectRevert(bytes4(keccak256("InsufficientSharesOut()")));
        orbital.joinSingleAssetExactIn(face2, 3 ether, HB_BOB, type(uint256).max, block.timestamp);
        assertEq(_strictJoinState(HB_BOB), before_, "paid transfers and funding revert with the failed mint");
    }

    function _partialBasket(uint8 mode) private {
        _hbBootstrap();
        uint256[] memory amounts = _hbFundPairs(HB_BOB, 10 ether);
        amounts[1] = 0;
        (uint256 quote,,,) = orbital.previewAddLiquidity(amounts[0], 0, amounts[2]);
        assertGt(quote, 0);
        (uint256 flexibleQuote,,,) = orbital.previewDepositFlexible(amounts[0], false, 0, false, amounts[2], false);
        assertEq(quote, flexibleQuote);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        address[] memory pairs = _hbPairs();
        vm.prank(HB_BOB);
        uint256 net;
        if (mode == 0) (net,,,) = orbital.depositFlexible(amounts[0], false, 0, false, amounts[2], false, HB_BOB, quote, block.timestamp);
        else if (mode == 1) net = orbital.joinUnbalanced(pairs, amounts, HB_BOB, quote, block.timestamp);
        else (net,) = orbital.joinProportional(amounts, HB_BOB, quote, block.timestamp);
        assertEq(net, quote);
        assertEq(IERC20(hook).balanceOf(HB_BOB) - before_.userLp, net);
    }

    function test_component_postPaidTradesMintBoundaryDoesNotDilute() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 10 ether);
        uint256 supply = IERC20(hook).totalSupply();
        assertGt(_hbTrade(HB_BOB, 2, 0, 1 ether), 0);
        assertGt(_hbTrade(HB_BOB, 2, 1, 1 ether), 0);
        assertEq(IERC20(hook).totalSupply(), supply, "priced trades mint no LP");
        uint256[] memory amounts = _hbFundShares(HB_BOB, 10 ether);
        ComponentSnapshot memory mintBoundary = _hbSnapshot(HB_BOB);
        uint256 net = _hbJoinShares(HB_BOB, amounts, 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        _hbAssertContributions(mintBoundary, after_);
        _hbAssertFee(mintBoundary, after_, net);
    }

    function test_component_crossLegExitBurnsOnlyCallerLp() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts = _hbFundShares(HB_BOB, 10 ether);
        _hbJoinShares(HB_BOB, amounts, 1);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        uint256 bobLp = IERC20(hook).balanceOf(HB_BOB);
        uint256 burn = before_.userLp / 10;
        vm.expectRevert(bytes4(keccak256("InvalidQuoteState()")));
        orbital.previewExitSingleAssetExactBptIn(face2, burn);
        vm.prank(HB_ALICE);
        uint256 received = orbital.exitSingleAssetExactBptIn(face2, burn, HB_ALICE, 1, block.timestamp);
        assertGt(received, 0);
        assertEq(IERC20(face2).balanceOf(HB_ALICE) - before_.userPairs[2], received);
        assertEq(IERC20(hook).balanceOf(HB_BOB), bobLp);
        assertEq(IERC20(hook).totalSupply(), before_.supply - burn);
        assertEq(IERC20(hook).balanceOf(_hbFeeRecipient()), before_.feeLp);
    }

    function test_component_lateAmbientSharesDoNotEnterTheBook() public {
        _hbBootstrap();
        uint256[] memory staged = _hbFundShares(HB_ALICE, 3 ether);
        uint256[] memory offered = _hbFundShares(HB_BOB, 10 ether);
        (uint256 quote,,,) = orbital.previewDepositFlexible(offered[0], true, offered[1], true, offered[2], false);
        uint256 booked = orbital.seBalance(0);
        vm.prank(HB_ALICE);
        IERC20(seUT0).transfer(hook, staged[0]);
        assertEq(orbital.seBalance(0), booked);
        (uint256 afterQuote,,,) = orbital.previewDepositFlexible(offered[0], true, offered[1], true, offered[2], false);
        assertEq(afterQuote, quote);
        assertEq(_hbJoinShares(HB_BOB, offered, quote), quote);
        assertEq(IERC20(seUT0).balanceOf(hook) - orbital.seBalance(0), staged[0]);
    }

    function test_component_expiredJoinRestoresFundingAndBooks() public {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 10 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.warp(block.timestamp + 2);
        vm.prank(HB_BOB);
        vm.expectRevert(bytes4(keccak256("DeadlineExpired()")));
        orbital.addLiquidity(10 ether, 10 ether, 10 ether, HB_BOB, 1, block.timestamp - 1, "");
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(before_));
    }

    function test_component_zeroRecipientDisablesMintFee() public {
        _hbSetFee(HB_FEE);
        uint256[] memory amounts = _hbFundShares(HB_ALICE, 100 ether);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(address(0)));
        uint256 net = _hbJoinShares(HB_ALICE, amounts, 1);
        assertEq(IERC20(hook).totalSupply(), net + 1000);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000, "zero recipient receives only locked floor");
    }

    function test_component_outerManagerRevertRestoresLocalSettlement() public {
        _hbBootstrap();
        _hbFundPairs(address(this), 10 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(address(this));
        uint256 managerPair = IERC20(face0).balanceOf(address(pm));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "outer abort"));
        pm.unlock(abi.encode(face2, face0));
        assertEq(abi.encode(_hbSnapshot(address(this))), abi.encode(before_));
        assertEq(IERC20(face0).balanceOf(address(pm)), managerPair);
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(pm), "manager only");
        (address input, address output) = abi.decode(data, (address, address));
        (uint256 received,) = IStandardExchangeIn(hook).exchangeIn(
            IERC20(input), 1 ether, IERC20(output), 1, address(this), false, block.timestamp
        );
        assertGt(received, 0, "positive local settlement before outer rollback");
        revert("outer abort");
    }
}
