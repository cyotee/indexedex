// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as FamilyBase} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IUniswapV4BalancerStableLiquidityUnits} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4BalancerStableLiquidityUnits.sol";
import {HookExactNetComponentAccountingBehavior} from "../../../HookComponentAccountingBehavior.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault as FullSpreadRow} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";

/// @notice Real FullSpread component-accounting adapter; no substitute vault or synthetic balances.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting is FullSpreadRow, HookExactNetComponentAccountingBehavior {
    function test_component_bufferedUnbalancedQuoteRequiresProjectionButExecutionWorks() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory funded = _hbFundShares(HB_BOB, 10 ether);
        _hbFundPairs(HB_BOB, 10 ether);
        for (uint256 mode; mode < 2; ++mode) {
            uint256 checkpoint = vm.snapshotState();
            address[] memory inputs = new address[](1);
            uint256[] memory amounts = new uint256[](1);
            inputs[0] = mode == 0 ? face : seUT;
            amounts[0] = mode == 0 ? 1 ether : funded[0] / 10;
            vm.expectRevert(bytes4(keccak256("InvalidQuoteState()")));
            IUniswapV4SeBufferHook(hook).previewJoinUnbalanced(inputs, amounts);
            ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
            vm.prank(HB_BOB);
            uint256 net = IUniswapV4SeBufferHook(hook).joinUnbalanced(inputs, amounts, HB_BOB, 1, block.timestamp);
            assertGt(net, 0);
            _hbAssertFee(before_, _hbSnapshot(HB_BOB), net);
            assertTrue(vm.revertToState(checkpoint));
        }
    }

    function test_component_oneConversionPerLegQuoteRemainsAvailable() public {
        _hbBootstrap();
        uint256[] memory amounts = _hbFundShares(HB_BOB, 10 ether);
        bool[] memory flags = new bool[](amounts.length);
        for (uint256 i; i < flags.length; ++i) flags[i] = legSes[i] != address(0);
        (uint256 quote,) = IUniswapV4BalancerStableLiquidityUnits(hook).previewJoinProportionalFlexible(
            _hbNativeAmounts(amounts), flags
        );
        assertGt(quote, 0);
        assertEq(_hbJoinShares(HB_BOB, amounts, quote), quote);
    }

    function test_component_sequentialRawExitQuoteRequiresProjectionButExecutionWorks() public {
        _hbBootstrap();
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        uint256 burned = before_.userLp / 10;
        uint256[] memory proportional = IUniswapV4SeBufferHook(hook).previewExitProportional(burned);
        assertGt(proportional[faceIdx], 0, "independent one-conversion payout remains quotable");
        vm.expectRevert(bytes4(keccak256("InvalidQuoteState()")));
        IUniswapV4SeBufferHook(hook).previewExitSingleAssetExactBptIn(other, burned);
        vm.expectRevert(bytes4(keccak256("InvalidQuoteState()")));
        IUniswapV4SeBufferHook(hook).previewExitSingleAssetExactTokenOut(other, 1);
        vm.expectRevert(bytes4(keccak256("InvalidQuoteState()")));
        IStandardizedYield(hook).previewRedeem(other, burned);
        vm.prank(HB_ALICE);
        uint256 paid = IUniswapV4SeBufferHook(hook).exitSingleAssetExactBptIn(
            other, burned, HB_ALICE, 1, block.timestamp
        );
        assertGt(paid, 0);
        assertEq(IERC20(other).balanceOf(HB_ALICE) - before_.userPairs[1], paid);
        assertEq(IERC20(hook).balanceOf(HB_ALICE), before_.userLp - burned);
        assertEq(IERC20(hook).totalSupply(), before_.supply - burned);
        assertEq(IERC20(hook).balanceOf(_hbFeeRecipient()), before_.feeLp);
    }

    function _hbHook() internal view override returns (address) { return hook; }

    function _hbPairs() internal view override returns (address[] memory pairs_) {
        pairs_ = new address[](legTokens.length);
        for (uint256 i_; i_ < pairs_.length; ++i_) pairs_[i_] = legTokens[_hbNativeIndex(i_)];
    }

    function _hbExchanges() internal view override returns (address[] memory exchanges_) {
        exchanges_ = new address[](legTokens.length);
        for (uint256 i_; i_ < exchanges_.length; ++i_) exchanges_[i_] = legSes[_hbNativeIndex(i_)];
    }

    /// @dev Reorder whole records for the behavior: primary buffered, counter, remaining legs.
    function _hbNativeIndex(uint256 index_) internal view returns (uint256) {
        if (index_ == 0) return faceIdx;
        if (index_ == 1) return otherIdx;
        uint256 canonical_ = 2;
        for (uint256 i_; i_ < legTokens.length; ++i_) {
            if (i_ == faceIdx || i_ == otherIdx) continue;
            if (canonical_++ == index_) return i_;
        }
        revert("invalid component index");
    }

    function _hbNativeAmounts(uint256[] memory amounts_) internal view returns (uint256[] memory native_) {
        native_ = new uint256[](amounts_.length);
        for (uint256 i_; i_ < amounts_.length; ++i_) native_[_hbNativeIndex(i_)] = amounts_[i_];
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
    function _hbFeeRecipient() internal view override returns (address) { return quad.feeTo(); }

    function _hbEffectiveMintFee(uint256 configured_) internal pure override returns (uint256) {
        // Preserve the existing family's 100,000-unit activation threshold and cap.
        return configured_ < 1e13 || configured_ >= 1e18 ? 0 : configured_;
    }

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
        uint256[] memory native_ = _hbNativeAmounts(amounts_);
        bool[] memory flags_ = new bool[](amounts_.length);
        address[] memory exchanges_ = _hbExchanges();
        for (uint256 i_; i_ < amounts_.length; ++i_) flags_[_hbNativeIndex(i_)] = exchanges_[i_] != address(0);
        vm.prank(actor_);
        (net_,) = IUniswapV4BalancerStableLiquidityUnits(hook).joinProportionalFlexible(native_, flags_, actor_, minimum_, block.timestamp);
    }

    function _hbJoinPairs(address actor_, uint256[] memory amounts_, uint256 minimum_)
        internal override returns (uint256 net_)
    {
        uint256[] memory native_ = _hbNativeAmounts(amounts_);
        bool[] memory flags_ = new bool[](amounts_.length);
        vm.prank(actor_);
        (net_,) = IUniswapV4BalancerStableLiquidityUnits(hook).joinProportionalFlexible(native_, flags_, actor_, minimum_, block.timestamp);
    }

    function _hbExitPairs(address actor_, uint256 burned_) internal override {
        uint256[] memory minima_ = new uint256[](legTokens.length);
        bool[] memory flags_ = new bool[](legTokens.length);
        for (uint256 i_; i_ < minima_.length; ++i_) minima_[i_] = 1;
        vm.prank(actor_);
        IUniswapV4BalancerStableLiquidityUnits(hook).exitProportionalFlexible(burned_, actor_, flags_, minima_, block.timestamp);
    }

    function _hbMoveUnderlyingMarket() internal override {
        fullSpread.acquireShares(seUT, face, address(0xCAFE40), 50_000 ether);
    }

    function _hbRate() internal view override returns (uint256) { return IRateProvider(quad.rateProvider(face)).getRate(); }
    function _hbMinimumError() internal pure override returns (bytes4) { return bytes4(keccak256("Slippage()")); }
    function _hbInitialPairError() internal pure override returns (bytes4) { return bytes4(keccak256("InvalidRoute()")); }

    function _hbDisable(bool byPackage_, bool disabled_) internal override {
        address package_ = fullSpread.pkg();
        vm.prank(owner);
        if (byPackage_) IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(package_, disabled_);
        else IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(seUT, disabled_);
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

    function _hbExactNetRequest() internal view override returns (uint256 net_, uint256 maximum_) {
        maximum_ = 1 ether;
        net_ = IUniswapV4SeBufferHook(hook).previewJoinSingleAssetExactIn(other, maximum_);
    }

    function _hbExactNet(address actor_, uint256 net_, uint256 maximum_) internal override returns (uint256) {
        vm.prank(actor_);
        return IUniswapV4SeBufferHook(hook).joinSingleAssetExactOut(other, net_, actor_, maximum_, block.timestamp);
    }

    function test_component_allSwapInputRefundIsBookedLocally() public {
        uint256[] memory seed = _hbFundShares(HB_ALICE, 10000 ether);
        seed[0] /= 100;
        assertGt(_hbJoinShares(HB_ALICE, seed, 1), 0);
        _hbFundPairs(HB_BOB, 100 ether);
        uint256 amount = 2;
        (uint256 minted, uint256 refunded) = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), amount, IERC20(seUT));
        assertEq(minted, 0, "49% swap rounds to zero for this real vault input");
        assertEq(refunded, amount, "whole input returned by the SE");
        uint256 local = IERC20(face).balanceOf(hook);
        uint256 shares = IERC20(seUT).balanceOf(hook);
        uint256 supply = IERC20(hook).totalSupply();
        assertGt(_hbTrade(HB_BOB, 0, 1, amount), 0, "refund still funds a real local-input swap");
        assertEq(IERC20(face).balanceOf(hook), local + amount);
        assertEq(IERC20(seUT).balanceOf(hook), shares);
        assertEq(IERC20(hook).totalSupply(), supply);
    }

    function test_component_partialSwapRefundBecomesLocalExactlyOnce() public {
        _hbBootstrap(); _hbFundPairs(HB_BOB, 100 ether);
        uint256 amount = 10 ether;
        (, uint256 refund) = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), amount, IERC20(seUT));
        assertGt(refund, 0, "real FullSpread partial receipt"); assertLt(refund, amount);
        uint256 local = IERC20(face).balanceOf(hook);
        uint256 shares = IERC20(seUT).balanceOf(hook);
        uint256 supply = IERC20(hook).totalSupply();
        assertGt(_hbTrade(HB_BOB, 0, 1, amount), 0);
        assertEq(IERC20(face).balanceOf(hook), local + refund, "one refund credit");
        assertGt(IERC20(seUT).balanceOf(hook), shares);
        assertEq(IERC20(hook).totalSupply(), supply, "swap has no mint fee");
    }

    function test_component_disabledInputRetainsWholeCallerBudget() public {
        _hbBootstrap(); _hbFundPairs(HB_BOB, 100 ether); _hbDisable(false, true);
        uint256 local = IERC20(face).balanceOf(hook);
        uint256 shares = IERC20(seUT).balanceOf(hook);
        uint256 seSupply = IERC20(seUT).totalSupply();
        assertGt(_hbTrade(HB_BOB, 0, 1, 1 ether), 0);
        assertEq(IERC20(face).balanceOf(hook), local + 1 ether);
        assertEq(IERC20(seUT).balanceOf(hook), shares);
        assertEq(IERC20(seUT).totalSupply(), seSupply, "no disabled mint attempted");
    }

    function test_component_outerManagerRevertRestoresSuccessfulJoin() public {
        BalancerComponentRollback caller = new BalancerComponentRollback();
        uint256[] memory amounts = _hbNativeAmounts(_hbFundShares(address(caller), 100 ether));
        bool[] memory flags = new bool[](amounts.length);
        for (uint256 i; i < flags.length; ++i) flags[i] = legSes[i] != address(0);
        ComponentSnapshot memory before_ = _hbSnapshot(address(caller));
        vm.expectRevert(BalancerComponentRollback.RollbackAfterJoin.selector);
        caller.run(pm, hook, amounts, flags);
        assertEq(abi.encode(_hbSnapshot(address(caller))), abi.encode(before_), "outer unlock restores token, LP, allowance and SE state");
    }

    function test_component_localEqualityExactOutDoesNotCallUnavailableSeOut() public {
        _hbBootstrap(); _hbFundPairs(HB_BOB, 100 ether);
        uint256 local = IERC20(face).balanceOf(hook);
        uint256 shares = IERC20(seUT).balanceOf(hook);
        uint256 underlyingSupply = IERC20(seUT).totalSupply();
        uint256 required = IStandardExchangeOut(hook).previewExchangeOut(IERC20(other), IERC20(face), local);
        uint256 beforeOutput = IERC20(face).balanceOf(HB_BOB);
        vm.prank(HB_BOB);
        uint256 spent = IStandardExchangeOut(hook).exchangeOut(IERC20(other), required, IERC20(face), local, HB_BOB, false, block.timestamp);
        assertEq(spent, required);
        assertEq(IERC20(face).balanceOf(HB_BOB) - beforeOutput, local);
        assertEq(IERC20(face).balanceOf(hook), 0);
        assertEq(IERC20(seUT).balanceOf(hook), shares);
        assertEq(IERC20(seUT).totalSupply(), underlyingSupply);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(hook).previewExchangeOut(IERC20(other), IERC20(face), 1 ether);
        uint256[] memory amounts = _hbFundShares(HB_BOB, 10 ether);
        ComponentSnapshot memory beforeJoin = _hbSnapshot(HB_BOB);
        uint256 seSupply = IERC20(seUT).totalSupply();
        assertGt(_hbJoinShares(HB_BOB, amounts, 1), 0, "zero-local component needs no local contribution");
        assertEq(IERC20(face).balanceOf(hook), 0);
        assertEq(IERC20(seUT).totalSupply(), seSupply, "no needless conversion for zero local component");
        _hbAssertContributions(beforeJoin, _hbSnapshot(HB_BOB));
    }

    function test_component_refundedLocalShareConversionRestoresExit() public {
        _hbBootstrap();
        uint256 burned = IERC20(hook).balanceOf(HB_ALICE) / 7;
        bool[] memory flags = new bool[](legTokens.length);
        flags[faceIdx] = true;
        uint256 localClaim = IERC20(face).balanceOf(hook) * burned / IERC20(hook).totalSupply();
        (uint256 converted, uint256 refunded) = IStandardExchangeIn(seUT).previewExchangeIn(
            IERC20(face), localClaim, IERC20(seUT));
        assertGt(converted, 0, "real partial conversion produces shares");
        assertGt(refunded, 0, "requested share-only payout cannot consume its full local claim");
        bytes32 before_ = _hbCompleteState(HB_ALICE);
        vm.expectRevert(bytes4(keccak256("BufferFailed()")));
        IUniswapV4BalancerStableLiquidityUnits(hook).previewExitProportionalFlexible(burned, flags);
        vm.prank(HB_ALICE);
        vm.expectRevert(bytes4(keccak256("UnwrapFailed()")));
        IUniswapV4BalancerStableLiquidityUnits(hook).exitProportionalFlexible(
            burned, HB_ALICE, flags, new uint256[](flags.length), block.timestamp);
        assertEq(_hbCompleteState(HB_ALICE), before_, "incomplete requested conversion restores all exit state");
    }

    function test_component_disabledShareExitRollsBackButPairExitWorks() public {
        _hbBootstrap(); _hbDisable(true, true);
        uint256 burned = IERC20(hook).balanceOf(HB_ALICE) / 7;
        bool[] memory flags = new bool[](legTokens.length); flags[faceIdx] = true;
        uint256[] memory minimum = new uint256[](flags.length);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        vm.prank(HB_ALICE);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, seUT));
        IUniswapV4BalancerStableLiquidityUnits(hook).exitProportionalFlexible(burned, HB_ALICE, flags, minimum, block.timestamp);
        assertEq(abi.encode(_hbSnapshot(HB_ALICE)), abi.encode(before_));
        _hbExitPairs(HB_ALICE, burned);
        assertEq(IERC20(hook).balanceOf(HB_ALICE), before_.userLp - burned);
    }


    function test_component_singleSeAndSyAliasesUsePaidPreparation() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        uint256 expected = IUniswapV4SeBufferHook(hook).previewJoinSingleAssetExactIn(other, 1 ether);
        assertGt(expected, 0);
        bytes[] memory calls_ = new bytes[](4);
        calls_[0] = abi.encodeCall(quad.depositSingle, (other, 1 ether, HB_BOB, expected, block.timestamp));
        calls_[1] = abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(other), 1 ether, IERC20(hook), expected, HB_BOB, false, block.timestamp));
        calls_[2] = abi.encodeCall(IStandardizedYield.deposit, (HB_BOB, other, 1 ether, expected));
        calls_[3] = abi.encodeCall(IUniswapV4SeBufferHook.joinSingleAssetExactOut, (other, expected, HB_BOB, 1 ether, block.timestamp));
        for (uint256 i; i < calls_.length; ++i) {
            uint256 snapshot = vm.snapshotState();
            uint256 supply = IERC20(hook).totalSupply();
            uint256 userLp = IERC20(hook).balanceOf(HB_BOB);
            uint256 feeLp = IERC20(hook).balanceOf(_hbFeeRecipient());
            vm.prank(HB_BOB);
            (bool success, bytes memory result) = hook.call(calls_[i]);
            if (!success) assembly { revert(add(result, 32), mload(result)) }
            assertEq(IERC20(hook).balanceOf(HB_BOB) - userLp, expected);
            uint256 gross = IERC20(hook).totalSupply() - supply;
            assertEq(IERC20(hook).balanceOf(_hbFeeRecipient()) - feeLp, gross - expected);
            assertTrue(vm.revertToState(snapshot));
        }
    }

    /// @notice Pair genesis returns real FullSpread deposit refunds and seeds only its redemption.
    function test_component_pairGenesisRefundIsCallerOwned() public {
        uint256[] memory amounts = _hbFundPairs(HB_ALICE, 100 ether);
        address[] memory pairs = _hbPairs();
        address[] memory exchanges = _hbExchanges();
        uint256[] memory beforePair = new uint256[](pairs.length);
        for (uint256 i; i < pairs.length; ++i) beforePair[i] = IERC20(pairs[i]).balanceOf(HB_ALICE);
        _ledgerInit(hook, pairs, exchanges, _hbFeeRecipient());
        vm.recordLogs();
        uint256 minted = _hbJoinPairs(HB_ALICE, amounts, 1);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertGt(minted, 0);
        for (uint256 i; i < pairs.length; ++i) {
            if (exchanges[i] == address(0)) continue;
            ConversionReceipt memory receipt = _ledgerReceipt(logs, i, HB_ALICE, address(0));
            uint256 refund = IERC20(pairs[i]).balanceOf(HB_ALICE) + amounts[i] - beforePair[i];
            if (exchanges[i] == seUT) assertGt(refund, 0, "real partial FullSpread deposit");
            assertGt(receipt.sharesMinted, 0);
            assertEq(receipt.sharesBurned, receipt.sharesMinted / 20, "five percent of actually acquired shares");
            assertEq(quad.seBalance(_hbNativeIndex(i)), receipt.sharesMinted - receipt.sharesBurned);
            assertGt(receipt.pairIn, refund, "redemption yields a positive local seed");
            assertEq(IERC20(pairs[i]).balanceOf(hook), receipt.pairIn - refund, "refund is not incumbent local inventory");
        }
    }

    function test_component_permit2FlexibleJoinAcceptsRealFunding() public {
        _hbBootstrap();
        uint256[] memory amounts = _hbNativeAmounts(_hbFundPairs(HB_BOB, 10 ether));
        vm.startPrank(HB_BOB);
        for (uint256 i; i < legTokens.length; ++i) {
            IERC20(legTokens[i]).approve(hook, 0);
            IERC20(legTokens[i]).approve(PERMIT2_ADDR, type(uint256).max);
            IAllowanceTransfer(PERMIT2_ADDR).approve(legTokens[i], hook, type(uint160).max, type(uint48).max);
        }
        vm.stopPrank();
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.prank(HB_BOB);
        (uint256 net,) = IUniswapV4BalancerStableLiquidityUnits(hook).joinProportionalFlexible(
            amounts, new bool[](amounts.length), HB_BOB, 1, block.timestamp);
        assertGt(net, 0);
        _hbAssertContributions(before_, _hbSnapshot(HB_BOB));
    }

    function test_component_zeroRoundedGenesisAndExpiredDeadlineRollBack() public {
        uint256[] memory amounts = _hbFundShares(HB_ALICE, 100 ether);
        uint256 saved = amounts[0]; amounts[0] = 19;
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        vm.expectRevert(bytes4(keccak256("ZeroLiquidityAmount()")));
        this.hbJoinShares(HB_ALICE, amounts, 1);
        assertEq(abi.encode(_hbSnapshot(HB_ALICE)), abi.encode(before_));
        amounts[0] = saved;
        uint256[] memory native_ = _hbNativeAmounts(amounts);
        bool[] memory flags = new bool[](amounts.length);
        for (uint256 i; i < flags.length; ++i) flags[i] = legSes[i] != address(0);
        vm.warp(2);
        vm.prank(HB_ALICE);
        vm.expectRevert(bytes4(keccak256("DeadlineExpired()")));
        IUniswapV4BalancerStableLiquidityUnits(hook).joinProportionalFlexible(native_, flags, HB_ALICE, 1, 1);
        assertEq(abi.encode(_hbSnapshot(HB_ALICE)), abi.encode(before_));
        assertGt(_hbJoinShares(HB_ALICE, amounts, 1), 0, "same funded basket succeeds with valid bounds");
    }

    function test_component_existingInactiveFeePolicyMintsNoProtocolLp() public {
        _hbSetFee(1);
        assertEq(quad.usageFee(), 1, "nonzero stored fee avoids the unset fallback");
        uint256 net = _hbBootstrap();
        assertEq(IERC20(hook).totalSupply(), net + 1000);
        assertEq(IERC20(hook).balanceOf(_hbFeeRecipient()), 0, "existing owner-share activation threshold remains inactive");
    }

    function test_component_zeroRecipientDisablesMintFee() public {
        _hbSetFee(HB_FEE);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(address(0)));
        uint256 net = _hbBootstrap();
        assertEq(IERC20(hook).totalSupply(), net + 1000);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000, "floor is not a fee");
    }

    function test_component_duplicateInputLegRejectsBeforeFunding() public {
        _hbBootstrap(); _hbFundPairs(HB_BOB, 10 ether);
        address[] memory inputs = new address[](2); inputs[0] = face; inputs[1] = seUT;
        uint256[] memory amounts = new uint256[](2); amounts[0] = 1 ether; amounts[1] = 1 ether;
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.prank(HB_BOB);
        vm.expectRevert(bytes4(keccak256("InvalidPair()")));
        IUniswapV4BalancerStableLiquidityUnits(hook).joinUnbalanced(inputs, amounts, HB_BOB, 1, block.timestamp);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(before_));
    }
}

contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting_N5 is UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting {
    function setUp() public override {
        FamilyBase.setUp();
        _initializeBalancer(5);
    }
}

/// @notice Positive requested-share control using a real, fully consuming ERC4626 SE.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_ShareExitLocalClaim is FamilyBase {
    function test_component_shareRequestedExitIncludesLocalClaim() public {
        _seedFullBook(100 ether);
        uint256 burned = IERC20(hook).balanceOf(user) / 7;
        uint256 supply = IERC20(hook).totalSupply();
        uint256 n = quad.numTokens();
        bool[] memory flags = new bool[](n);
        uint256 index;
        bool found;
        for (uint256 i; i < n; ++i) {
            if (quad.standardExchange(i) == se0) { flags[i] = true; index = i; found = true; }
        }
        assertTrue(found, "configured real SE leg");
        uint256 oldShares = IERC20(se0).balanceOf(hook);
        uint256 shareClaim = burned * oldShares / supply;
        uint256 localClaim = burned * IERC20(quad.token(index)).balanceOf(hook) / supply;
        (uint256 converted, uint256 refund) = IStandardExchangeIn(se0).previewExchangeIn(
            IERC20(quad.token(index)), localClaim, IERC20(se0));
        assertGt(converted, 0);
        assertEq(refund, 0, "positive control consumes the whole local claim");
        uint256[] memory quote = IUniswapV4BalancerStableLiquidityUnits(hook).previewExitProportionalFlexible(burned, flags);
        uint256 beforeUser = IERC20(se0).balanceOf(user);
        vm.prank(user);
        uint256[] memory outputs = IUniswapV4BalancerStableLiquidityUnits(hook).exitProportionalFlexible(
            burned, user, flags, new uint256[](n), block.timestamp);
        assertEq(outputs[index], shareClaim + converted, "local claim and allocated shares belong to the exiting holder");
        assertGt(outputs[index], shareClaim);
        assertEq(IERC20(se0).balanceOf(user) - beforeUser, outputs[index]);
        assertEq(outputs, quote);
        assertEq(IERC20(se0).balanceOf(hook), oldShares - shareClaim);
    }
}

/// @dev Non-SUT caller forces an outer-manager failure only after a positive installed join.
contract BalancerComponentRollback is IUnlockCallback {
    error RollbackAfterJoin();
    function run(IPoolManager manager, address hook, uint256[] memory amounts, bool[] memory flags) external {
        manager.unlock(abi.encode(hook, amounts, flags));
    }
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        (address hook, uint256[] memory amounts, bool[] memory flags) = abi.decode(data, (address, uint256[], bool[]));
        (uint256 net,) = IUniswapV4BalancerStableLiquidityUnits(hook).joinProportionalFlexible(amounts, flags, address(this), 1, block.timestamp);
        require(net != 0, "positive join before rollback");
        revert RollbackAfterJoin();
    }
}
