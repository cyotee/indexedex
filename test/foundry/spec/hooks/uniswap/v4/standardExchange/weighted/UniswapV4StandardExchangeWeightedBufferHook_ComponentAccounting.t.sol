// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {SeMatrixFixture} from "../SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "../SeMatrix_FullSpreadV4Fixture.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {TestBase_UniswapV4StandardExchangeWeightedBufferHook} from "./TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as IPackage} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IUniswapV4SeBufferHook, IUniswapV4SeBufferHookNativeLiquidity as INativeLiquidity} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {HookExactNetComponentAccountingBehavior} from "../HookComponentAccountingBehavior.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault as FullSpreadRow} from "./UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHookMath as WeightedMath} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";

/// @notice Real FullSpread component-accounting adapter; no substitute vault or synthetic balances.
contract UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting is FullSpreadRow, HookExactNetComponentAccountingBehavior {
    function _hbHook() internal view override returns (address) { return hook; }

    function _hbPairs() internal view override returns (address[] memory pairs_) {
        pairs_ = new address[](rowTokens.length);
        for (uint256 i_; i_ < pairs_.length; ++i_) pairs_[i_] = rowTokens[_hbNativeIndex(i_)];
    }

    function _hbExchanges() internal view override returns (address[] memory exchanges_) {
        exchanges_ = new address[](rowTokens.length);
        for (uint256 i_; i_ < exchanges_.length; ++i_) exchanges_[i_] = rowSes[_hbNativeIndex(i_)];
    }

    /// @dev Reorder whole records for the behavior: primary buffered, counter, remaining legs.
    function _hbNativeIndex(uint256 index_) internal view returns (uint256) {
        if (index_ == 0) return faceIdx;
        if (index_ == 1) return otherIdx;
        uint256 canonical_ = 2;
        for (uint256 i_; i_ < rowTokens.length; ++i_) {
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
    function _hbFeeRecipient() internal view override returns (address) { return weighted.feeTo(); }

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
        (net_,) = weighted.joinProportionalFlexible(native_, flags_, actor_, minimum_, block.timestamp);
    }

    function _hbJoinPairs(address actor_, uint256[] memory amounts_, uint256 minimum_)
        internal override returns (uint256 net_)
    {
        uint256[] memory native_ = _hbNativeAmounts(amounts_);
        bool[] memory flags_ = new bool[](amounts_.length);
        vm.prank(actor_);
        (net_,) = weighted.joinProportionalFlexible(native_, flags_, actor_, minimum_, block.timestamp);
    }

    function _hbExitPairs(address actor_, uint256 burned_) internal override {
        uint256[] memory minima_ = new uint256[](rowTokens.length);
        bool[] memory flags_ = new bool[](rowTokens.length);
        for (uint256 i_; i_ < minima_.length; ++i_) minima_[i_] = 1;
        vm.prank(actor_);
        weighted.exitProportionalFlexible(burned_, actor_, flags_, minima_, block.timestamp);
    }

    function _hbMoveUnderlyingMarket() internal override {
        fullSpread.acquireShares(seUT, face, address(0xCAFE40), 50_000 ether);
    }

    function _hbRate() internal view override returns (uint256) { return IRateProvider(weighted.rateProvider(face)).getRate(); }
    function _hbMinimumError() internal pure override returns (bytes4) { return bytes4(keccak256("Slippage()")); }
    function _hbInitialPairError() internal pure override returns (bytes4) { return bytes4(keccak256("InvalidRoute(address,address)")); }
    function _hbInitialPairErrorData() internal view override returns (bytes memory) {
        return abi.encodeWithSelector(_hbInitialPairError(), face, hook);
    }

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
        net_ = weighted.previewJoinSingleAssetExactIn(other, maximum_);
    }

    function _hbExactNet(address actor_, uint256 net_, uint256 maximum_) internal override returns (uint256) {
        vm.prank(actor_);
        return IUniswapV4SeBufferHook(hook).joinSingleAssetExactOut(other, net_, actor_, maximum_, block.timestamp);
    }

    function test_HB42_exactLocalEqualityUsesNoUnavailableExchangeOut() public {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        uint256 local = IERC20(face).balanceOf(hook);
        uint256 supply = IERC20(seUT).totalSupply();
        uint256 shares = IERC20(seUT).balanceOf(hook);
        uint256 quoted = IStandardExchangeOut(hook).previewExchangeOut(IERC20(other), IERC20(face), local);
        uint256 beforePair = IERC20(face).balanceOf(HB_BOB);
        vm.prank(HB_BOB);
        uint256 spent = IStandardExchangeOut(hook).exchangeOut(IERC20(other), quoted, IERC20(face), local, HB_BOB, false, block.timestamp);
        assertEq(spent, quoted);
        assertEq(IERC20(face).balanceOf(HB_BOB) - beforePair, local);
        assertEq(IERC20(face).balanceOf(hook), 0);
        assertEq(IERC20(seUT).totalSupply(), supply);
        assertEq(IERC20(seUT).balanceOf(hook), shares);
        uint256[] memory amounts = _hbFundPairs(HB_BOB, 10 ether);
        ComponentSnapshot memory beforeJoin = _hbSnapshot(HB_BOB);
        uint256 net = _hbJoinPairs(HB_BOB, amounts, 1);
        assertGt(net, 0);
        _hbAssertContributions(beforeJoin, _hbSnapshot(HB_BOB));
        assertEq(IERC20(face).balanceOf(hook), 0, "zero local component requires no contribution");
    }

    function test_HB44_disabledShareRequestRollsBackButPairExitWorks() public {
        _hbBootstrap();
        _hbDisable(false, true);
        ComponentSnapshot memory beforeExit = _hbSnapshot(HB_ALICE);
        bool[] memory flags = new bool[](rowTokens.length);
        flags[faceIdx] = true;
        uint256[] memory minima = new uint256[](rowTokens.length);
        vm.expectRevert(bytes4(keccak256("UnwrapFailed()")));
        vm.prank(HB_ALICE);
        weighted.exitProportionalFlexible(beforeExit.userLp / 4, HB_ALICE, flags, minima, block.timestamp);
        assertEq(abi.encode(_hbSnapshot(HB_ALICE)), abi.encode(beforeExit));
        _hbExitPairs(HB_ALICE, beforeExit.userLp / 4);
        assertGt(IERC20(face).balanceOf(HB_ALICE), beforeExit.userPairs[0]);
    }

    function test_HB45_disabledShareGenesisCompletesActualRedemption() public {
        uint256[] memory amounts = _hbFundShares(HB_ALICE, 100 ether);
        _hbDisable(true, true);
        ComponentSnapshot memory beforeSeed = _hbSnapshot(HB_ALICE);
        uint256 net = _hbJoinShares(HB_ALICE, amounts, 1);
        ComponentSnapshot memory afterSeed = _hbSnapshot(HB_ALICE);
        assertGt(net, 0);
        assertEq(beforeSeed.shareSupply[0] - afterSeed.shareSupply[0], amounts[0] / 20);
        assertEq(afterSeed.shares[0], amounts[0] - amounts[0] / 20);
        assertGt(afterSeed.pairs[0], 0);
    }

    function test_HB48_dustShareGenesisRestoresEveryLeg() public {
        uint256[] memory amounts = _hbFundShares(HB_ALICE, 100 ether);
        amounts[0] = 19;
        ComponentSnapshot memory beforeSeed = _hbSnapshot(HB_ALICE);
        vm.expectRevert(bytes4(keccak256("ZeroLiquidityAmount()")));
        this.hbJoinShares(HB_ALICE, amounts, 1);
        assertEq(abi.encode(_hbSnapshot(HB_ALICE)), abi.encode(beforeSeed));
    }

    function test_HB47_zeroRecipientReceivesEntireBackedGross() public {
        uint256[] memory amounts = _hbFundShares(HB_ALICE, 100 ether);
        _hbSetFee(HB_FEE);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(address(0)));
        uint256 net = _hbJoinShares(HB_ALICE, amounts, 1);
        assertEq(IERC20(hook).totalSupply(), net + 1000);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
    }

    function test_HB47_inactiveFeeUsesOracleFallbackCorrectly() public {
        uint256[] memory amounts = _hbFundShares(HB_ALICE, 100 ether);
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook, 0);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        vm.stopPrank();
        assertEq(weighted.usageFee(), 0);
        uint256 net = _hbJoinShares(HB_ALICE, amounts, 1);
        assertEq(IERC20(hook).totalSupply(), net + 1000);
        assertEq(IERC20(hook).balanceOf(weighted.feeTo()), 0);
    }

    function test_HB43_allProportionalAliasesShareTheSameAcceptance() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts = _hbFundPairs(HB_BOB, 10 ether);
        uint256[] memory nativeAmounts = _hbNativeAmounts(amounts);
        uint256 checkpoint = vm.snapshotState();
        ComponentSnapshot memory beforeJoin = _hbSnapshot(HB_BOB);
        vm.prank(HB_BOB);
        (uint256 net,) = weighted.joinProportional(nativeAmounts, HB_BOB, 1, block.timestamp);
        ComponentSnapshot memory control = _hbSnapshot(HB_BOB);
        _hbAssertContributions(beforeJoin, control);
        _hbAssertFee(beforeJoin, control, net);
        assertTrue(vm.revertToState(checkpoint));
        uint256 flexible = _hbJoinPairs(HB_BOB, amounts, 1);
        assertEq(flexible, net);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(control));
    }

    function test_HB43_unbalancedShareAliasReachesBackedMint() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts = _hbFundShares(HB_BOB, 10 ether);
        address[] memory edges = _hbExchanges();
        address[] memory pairs = _hbPairs();
        for (uint256 i; i < edges.length; ++i) if (edges[i] == address(0)) edges[i] = pairs[i];
        ComponentSnapshot memory beforeJoin = _hbSnapshot(HB_BOB);
        vm.prank(HB_BOB);
        uint256 net = IUniswapV4SeBufferHook(hook).joinUnbalanced(edges, amounts, HB_BOB, 1, block.timestamp);
        assertGt(net, 0);
        _hbAssertFee(beforeJoin, _hbSnapshot(HB_BOB), net);
    }

    function test_HB47_singleAliasesPayForTheirMissingComponents() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        bytes[] memory calls_ = new bytes[](5);
        calls_[0] = abi.encodeCall(weighted.depositSingle, (other, 1 ether, HB_BOB, 1, block.timestamp));
        calls_[1] = abi.encodeCall(weighted.joinSingleAssetExactIn, (other, 1 ether, HB_BOB, 1, block.timestamp));
        calls_[2] = abi.encodeCall(weighted.depositSingleFlexible, (other, 1 ether, false, HB_BOB, 1, block.timestamp));
        calls_[3] = abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(other), 1 ether, IERC20(hook), 1, HB_BOB, false, block.timestamp));
        calls_[4] = abi.encodeCall(IStandardizedYield.deposit, (HB_BOB, other, 1 ether, 1));
        _assertPaidAliases(HB_BOB, calls_);
    }

    function test_HB43_seFacadeFundsMissingComponents() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 10 ether);
        bytes[] memory calls_ = new bytes[](1);
        calls_[0] = abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(other), 1 ether, IERC20(hook), 1, HB_BOB, false, block.timestamp));
        _assertPaidAliases(HB_BOB, calls_);
    }

    function _assertPaidAliases(address actor, bytes[] memory calls) internal {
        uint256 checkpoint = vm.snapshotState();
        uint256 controlNet;
        bytes32 controlState;
        for (uint256 i; i < calls.length; ++i) {
            assertTrue(vm.revertToState(checkpoint));
            checkpoint = vm.snapshotState();
            ComponentSnapshot memory beforeJoin = _hbSnapshot(actor);
            vm.prank(actor);
            (bool ok, bytes memory result) = hook.call(calls[i]);
            assertTrue(ok, "caller-funded paid preparation succeeds");
            uint256 net = abi.decode(result, (uint256));
            ComponentSnapshot memory afterJoin = _hbSnapshot(actor);
            assertGt(net, 0);
            assertEq(afterJoin.userLp - beforeJoin.userLp, net);
            _hbAssertFee(beforeJoin, afterJoin, net);
            assertEq(IERC20(hook).balanceOf(address(0)), 1000, "locked floor survives preparation");
            if (i == 0) {
                controlNet = net;
                controlState = _hbCompleteState(actor);
            } else {
                assertEq(net, controlNet, "aliases mint the same backed LP");
                assertEq(_hbCompleteState(actor), controlState, "aliases have identical actual receipts and refunds");
            }
        }
    }

    function test_HB48_pairGenesisAcquiresSharesBeforeFivePercentRedemption() public {
        uint256[] memory amounts = _hbFundPairs(HB_ALICE, 100 ether);
        ComponentSnapshot memory beforeQuote = _hbSnapshot(HB_ALICE);
        vm.expectRevert(Transition.InvalidQuoteState.selector);
        weighted.previewJoinProportional(_hbNativeAmounts(amounts));
        assertEq(abi.encode(_hbSnapshot(HB_ALICE)), abi.encode(beforeQuote), "unsupported sequential preview stays read-only");
        vm.recordLogs();
        assertGt(_hbJoinPairs(HB_ALICE, amounts, 1), 0);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 minted;
        uint256 burned;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != seUT || logs[i].topics.length != 3
                || logs[i].topics[0] != keccak256("Transfer(address,address,uint256)")) continue;
            address from = address(uint160(uint256(logs[i].topics[1])));
            address to = address(uint160(uint256(logs[i].topics[2])));
            if (from == address(0) && to == hook) minted += abi.decode(logs[i].data, (uint256));
            if (from == hook && to == address(0)) burned += abi.decode(logs[i].data, (uint256));
        }
        assertGt(minted, 0, "caller pair funds actual SE issuance");
        assertEq(burned, minted / 20, "seed rule applies to actual received shares");
        assertEq(IERC20(seUT).balanceOf(hook), minted - burned);
        assertGt(IERC20(face).balanceOf(hook), 0, "actual redemption receipt backs the local component");
    }

    function test_HB44_crossLegExitAliasesPayActualCallerBasket() public {
        _hbBootstrap();
        uint256 burned = IERC20(hook).balanceOf(HB_ALICE) / 20;
        assertFalse(IERC165(seUT).supportsInterface(type(Transition).interfaceId), "FullSpread has no projected-state interface");
        bytes32 beforeQuote = _hbCompleteState(HB_ALICE);
        vm.expectRevert(Transition.InvalidQuoteState.selector);
        weighted.previewWithdrawSingle(other, burned);
        assertEq(_hbCompleteState(HB_ALICE), beforeQuote, "unavailable sequential quote changes no state");
        uint256 checkpoint = vm.snapshotState();
        uint256 controlOutput;
        bytes32 controlState;
        for (uint256 route; route < 4; ++route) {
            assertTrue(vm.revertToState(checkpoint)); checkpoint = vm.snapshotState();
            uint256 beforeOut = IERC20(other).balanceOf(HB_ALICE);
            uint256 beforeSupply = IERC20(hook).totalSupply();
            vm.prank(HB_ALICE);
            uint256 out;
            if (route == 0) out = weighted.withdrawSingle(other, burned, HB_ALICE, 1, block.timestamp);
            else if (route == 1) out = weighted.exitSingleAssetExactBptIn(other, burned, HB_ALICE, 1, block.timestamp);
            else if (route == 2) (out,) = IStandardExchangeIn(hook).exchangeIn(IERC20(hook), burned, IERC20(other), 1, HB_ALICE, false, block.timestamp);
            else out = IStandardizedYield(hook).redeem(HB_ALICE, burned, other, 1, false);
            assertGt(out, 0, "actual allocated-basket exit remains supported");
            assertEq(IERC20(other).balanceOf(HB_ALICE) - beforeOut, out);
            assertEq(IERC20(hook).totalSupply(), beforeSupply - burned);
            if (route == 0) {
                controlOutput = out;
                controlState = _hbCompleteState(HB_ALICE);
            } else {
                assertEq(out, controlOutput, "every installed alias pays the same actual receipt");
                assertEq(_hbCompleteState(HB_ALICE), controlState, "aliases preserve the same caller and incumbent state");
            }
        }
    }

    function test_HB43_permit2ShareFundingHasExactReceipts() public {
        uint256[] memory amounts = _hbFundShares(HB_ALICE, 100 ether);
        address[] memory shares = _hbExchanges();
        address[] memory pairs = _hbPairs();
        vm.startPrank(HB_ALICE);
        for (uint256 i; i < amounts.length; ++i) {
            address input = shares[i] == address(0) ? pairs[i] : shares[i];
            IERC20(input).approve(hook, 0);
            IERC20(input).approve(PERMIT2_ADDR, type(uint256).max);
            IAllowanceTransfer(PERMIT2_ADDR).approve(input, hook, type(uint160).max, type(uint48).max);
        }
        vm.stopPrank();
        uint256 net = _hbJoinShares(HB_ALICE, amounts, 1);
        assertGt(net, 0);
        assertEq(IERC20(seUT).balanceOf(hook), amounts[0] - amounts[0] / 20);
    }

    /// @notice Price the paid in-kind sales separately, then enforce native
    /// component ownership against that post-trade book, not pre-trade value.
    function test_HB43_paidBasketMintUsesPostTradeNativeOwnership() public {
        _hbSetFee(HB_FEE);
        _setDexFee(3e15);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 20 ether);
        ComponentSnapshot memory beforeJoin = _hbSnapshot(HB_BOB);
        ComponentSnapshot memory postTrade = abi.decode(abi.encode(beforeJoin), (ComponentSnapshot));
        uint256[] memory local = new uint256[](rowTokens.length);
        uint256[] memory shares = new uint256[](rowTokens.length);
        local[1] = 1 ether;
        uint256[] memory rated = weighted.ratedBalances();
        uint256 totalRated;
        for (uint256 i; i < rated.length; ++i) {
            rated[i] = rated[i] * weighted.ratedScale(i) / 1e18;
            totalRated += rated[i];
        }
        for (uint256 target; target < rowTokens.length; ++target) {
            if (target == otherIdx) continue;
            uint256 canonical;
            while (_hbNativeIndex(canonical) != target) ++canonical;
            uint256 trade = 1 ether * rated[target] / totalRated;
            uint256 fee = IVaultFeeOracleQuery(address(indexedexManager)).dexSwapFeeOfVault(hook);
            uint256 budget = WeightedMath.quoteLiquidityExactIn(
                rated[otherIdx], rowWeights[otherIdx], rated[target], rowWeights[target],
                trade * (1e18 - fee) / 1e18
            );
            shares[canonical] = postTrade.shares[canonical] * budget / rated[target];
            local[canonical] = postTrade.pairs[canonical] * budget / rated[target];
            postTrade.shares[canonical] -= shares[canonical];
            postTrade.pairs[canonical] -= local[canonical];
            postTrade.pairs[1] += trade;
            local[1] -= trade;
            rated[otherIdx] += trade;
        }
        uint256 gross = type(uint256).max;
        for (uint256 i; i < local.length; ++i) {
            if (postTrade.pairs[i] != 0) gross = _min(gross, local[i] * beforeJoin.supply / postTrade.pairs[i]);
            if (postTrade.shares[i] != 0) gross = _min(gross, shares[i] * beforeJoin.supply / postTrade.shares[i]);
        }
        assertGt(gross, 0);
        uint256 expected = gross - gross * HB_FEE / 1e18;
        assertEq(weighted.previewDepositSingle(other, 1 ether), expected, "in-kind preparation needs no projected SE mutation");
        vm.prank(HB_BOB);
        uint256 actual = weighted.joinSingleAssetExactInFlexible(other, 1 ether, false, HB_BOB, 1, block.timestamp);
        assertEq(actual, expected, "mint ownership is measured after paid trades, not against pre-trade PnL");
        ComponentSnapshot memory afterJoin = _hbSnapshot(HB_BOB);
        assertEq(afterJoin.supply - beforeJoin.supply, gross);
        _hbAssertFee(beforeJoin, afterJoin, actual);
        for (uint256 i; i < local.length; ++i) {
            uint256 acceptedLocal = (gross * postTrade.pairs[i] + beforeJoin.supply - 1) / beforeJoin.supply;
            uint256 acceptedShares = (gross * postTrade.shares[i] + beforeJoin.supply - 1) / beforeJoin.supply;
            assertEq(afterJoin.pairs[i], postTrade.pairs[i] + acceptedLocal);
            assertEq(afterJoin.shares[i], postTrade.shares[i] + acceptedShares);
            assertEq(afterJoin.shareSupply[i], beforeJoin.shareSupply[i], "paid in-kind transfers do not redeem or mint SE shares");
            assertEq(afterJoin.userShares[i], beforeJoin.userShares[i] + shares[i] - acceptedShares);
            assertEq(afterJoin.userPairs[i], beforeJoin.userPairs[i] - (i == 1 ? 1 ether : 0) + local[i] - acceptedLocal);
        }
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) { return a < b ? a : b; }

    function test_HB43_disabledShareAliasesPayForMissingLegs() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory funded_ = _hbFundShares(HB_BOB, 10 ether);
        _hbDisable(false, true);
        uint256 input_ = funded_[0];
        bytes[] memory calls_ = new bytes[](4);
        calls_[0] = abi.encodeCall(weighted.depositSingleFlexible, (face, input_, true, HB_BOB, 1, block.timestamp));
        calls_[1] = abi.encodeCall(weighted.joinSingleAssetExactIn, (seUT, input_, HB_BOB, 1, block.timestamp));
        calls_[2] = abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(seUT), input_, IERC20(hook), 1, HB_BOB, false, block.timestamp));
        calls_[3] = abi.encodeCall(IStandardizedYield.deposit, (HB_BOB, seUT, input_, 1));
        assertGt(weighted.previewDepositSingleFlexible(face, input_, true), 0);
        _assertPaidAliases(HB_BOB, calls_);
    }

    function test_HB48_shortShareFundingRollsBackAndValidFundingSucceeds() public {
        uint256[] memory amounts = _hbFundShares(HB_ALICE, 100 ether);
        ComponentSnapshot memory beforeSeed = _hbSnapshot(HB_ALICE);
        amounts[0] += 1;
        vm.expectRevert();
        this.hbJoinShares(HB_ALICE, amounts, 1);
        assertEq(abi.encode(_hbSnapshot(HB_ALICE)), abi.encode(beforeSeed));
        amounts[0] -= 1;
        assertGt(_hbJoinShares(HB_ALICE, amounts, 1), 0);
    }

    function test_HB42_outerManagerFailureRestoresActualHookSettlement() public {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        WeightedUnsettledSwapCaller caller = new WeightedUnsettledSwapCaller(pm);
        vm.prank(HB_BOB);
        IERC20(other).approve(address(caller), 1 ether);
        ComponentSnapshot memory beforeSwap = _hbSnapshot(HB_BOB);
        uint256 managerInput = IERC20(other).balanceOf(address(pm));
        uint256 managerOutput = IERC20(face).balanceOf(address(pm));
        bool direction = other < face;
        PoolKey memory key = PairPoolLib.pairKey(other, face, 1, IHooks(hook));
        assertTrue(PairPoolLib.isPoolLive(pm, key), "rollback exercises an initialized product door");
        vm.expectRevert(IPoolManager.CurrencyNotSettled.selector);
        vm.prank(HB_BOB);
        caller.run(key, direction, 1 ether);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(beforeSwap));
        assertEq(IERC20(other).balanceOf(address(pm)), managerInput);
        assertEq(IERC20(face).balanceOf(address(pm)), managerOutput);
        assertEq(IERC20(other).allowance(HB_BOB, address(caller)), 1 ether);
        assertGt(_hbTrade(HB_BOB, 1, 0, 1 ether), 0);
    }

    function test_HB43_expiredJoinRestoresFundingAndBooks() public {
        _hbBootstrap();
        uint256[] memory amounts = _hbNativeAmounts(_hbFundPairs(HB_BOB, 10 ether));
        ComponentSnapshot memory beforeJoin = _hbSnapshot(HB_BOB);
        vm.expectRevert(bytes4(keccak256("DeadlineExpired()")));
        vm.prank(HB_BOB);
        weighted.joinProportional(amounts, HB_BOB, 1, block.timestamp - 1);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(beforeJoin));
    }
}

/// @notice Explicit two-component caller budgets against a real FullSpread SE.
contract UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting_NativeComponents is
    UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting
{
    /// @notice A deficient but nonzero buffered leg is prepared before native ceil acceptance.
    function test_nativeComponentsPaidBookQuoteFeesAndRefunds() public {
        _hbSetFee(HB_FEE);
        _setDexFee(3e15);
        _hbBootstrap();
        _hbFundShares(HB_BOB, 20 ether);
        _hbFundPairs(HB_BOB, 20 ether);
        ComponentSnapshot memory beforeJoin = _hbSnapshot(HB_BOB);
        ComponentSnapshot memory postTrade = abi.decode(abi.encode(beforeJoin), (ComponentSnapshot));
        uint256[] memory local = new uint256[](2);
        uint256[] memory shares = new uint256[](2);
        local[0] = beforeJoin.pairs[0] / 100;
        shares[0] = beforeJoin.shares[0] / 100;
        local[1] = beforeJoin.pairs[1] / 50;
        uint256[] memory offeredLocal = _hbNativeAmounts(local);
        uint256[] memory offeredShares = _hbNativeAmounts(shares);
        // This fixture has one raw excess leg and one already-funded deficient leg.
        {
            uint256 bufferedValue = _nativeBufferedValue(beforeJoin.shares[0], beforeJoin.pairs[0]);
            uint256 callerValue = _nativeBufferedValue(shares[0], local[0]);
            uint256 trade = local[1] - (callerValue + local[1]) * beforeJoin.pairs[1]
                / (bufferedValue + beforeJoin.pairs[1]);
            // Independently floored targets need not sum to the full offer.
            // The paid sale cannot exceed the deficient leg's own target gap.
            uint256 deficit = (callerValue + local[1]) * bufferedValue
                / (bufferedValue + beforeJoin.pairs[1]) - callerValue;
            trade = FullMath.min(trade, deficit);
            uint256 fee = IVaultFeeOracleQuery(address(indexedexManager)).dexSwapFeeOfVault(hook);
            uint256 budget = WeightedMath.quoteLiquidityExactIn(
                beforeJoin.pairs[1], rowWeights[otherIdx], bufferedValue, rowWeights[faceIdx],
                trade * (1e18 - fee) / 1e18
            );
            uint256 outputValue = WeightedMath.componentValueUp(
                beforeJoin.shares[0], beforeJoin.pairs[0], weighted.invScale(faceIdx),
                weighted.ratedScale(faceIdx), _hbRate()
            );
            uint256 sharesOut = beforeJoin.shares[0] * budget / outputValue;
            uint256 localOut = beforeJoin.pairs[0] * budget / outputValue;
            shares[0] += sharesOut;
            local[0] += localOut;
            local[1] -= trade;
            postTrade.shares[0] -= sharesOut;
            postTrade.pairs[0] -= localOut;
            postTrade.pairs[1] += trade;
            assertGt(trade, 0, "nonzero deficient legs still receive paid preparation");
        }
        uint256 gross = FullMath.min(
            shares[0] * beforeJoin.supply / postTrade.shares[0],
            FullMath.min(local[0] * beforeJoin.supply / postTrade.pairs[0],
                local[1] * beforeJoin.supply / postTrade.pairs[1])
        );
        uint256 expected = gross - gross * HB_FEE / 1e18;
        assertGt(expected, 0);
        assertEq(INativeLiquidity(hook).previewJoinNativeComponents(offeredLocal, offeredShares), expected);
        vm.expectRevert(bytes4(keccak256("Slippage()")));
        vm.prank(HB_BOB);
        INativeLiquidity(hook).joinNativeComponents(offeredLocal, offeredShares, HB_BOB, expected + 1, block.timestamp);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(beforeJoin), "minimum failure restores pulls and paid book");
        vm.prank(HB_BOB);
        uint256 net = INativeLiquidity(hook).joinNativeComponents(offeredLocal, offeredShares, HB_BOB, expected, block.timestamp);
        assertEq(net, expected);
        ComponentSnapshot memory afterJoin = _hbSnapshot(HB_BOB);
        _hbAssertFee(beforeJoin, afterJoin, net);
        _hbAssertContributions(postTrade, afterJoin);
        for (uint256 i; i < 2; ++i) {
            uint256 acceptedLocal = (gross * postTrade.pairs[i] + beforeJoin.supply - 1) / beforeJoin.supply;
            uint256 acceptedShares = (gross * postTrade.shares[i] + beforeJoin.supply - 1) / beforeJoin.supply;
            assertEq(afterJoin.userPairs[i], beforeJoin.userPairs[i] - offeredLocal[_hbNativeIndex(i)] + local[i] - acceptedLocal);
            assertEq(afterJoin.userShares[i], beforeJoin.userShares[i] - offeredShares[_hbNativeIndex(i)] + shares[i] - acceptedShares);
            assertEq(afterJoin.shareSupply[i], beforeJoin.shareSupply[i], "in-kind preparation retains both components");
        }
        assertGt(shares[0], afterJoin.shares[0] - postTrade.shares[0], "unused shares refunded");
        assertTrue(
            local[0] > afterJoin.pairs[0] - postTrade.pairs[0]
                || local[1] > afterJoin.pairs[1] - postTrade.pairs[1],
            "unused local component refunded"
        );
    }

    function _nativeBufferedValue(uint256 shares, uint256 local) private view returns (uint256) {
        return WeightedMath.scaleTo(local + WeightedMath.ratedPairUnits(
            shares, _hbRate(), weighted.invScale(faceIdx), weighted.ratedScale(faceIdx)
        ), weighted.ratedScale(faceIdx));
    }

    /// @notice The package installs both selectors and advertises the split interface on its proxy.
    function test_nativeComponentsDeployedSurfaceAndValidation() public {
        assertTrue(IERC165(hook).supportsInterface(type(INativeLiquidity).interfaceId));
        assertTrue(IDiamondLoupe(hook).facetAddress(INativeLiquidity.previewJoinNativeComponents.selector) != address(0));
        assertTrue(IDiamondLoupe(hook).facetAddress(INativeLiquidity.joinNativeComponents.selector) != address(0));
        uint256[] memory local = new uint256[](2);
        uint256[] memory shares = new uint256[](2);
        vm.expectRevert(bytes4(keccak256("NotLive()")));
        INativeLiquidity(hook).previewJoinNativeComponents(local, shares);
        vm.expectRevert(bytes4(keccak256("NotLive()")));
        INativeLiquidity(hook).joinNativeComponents(local, shares, HB_BOB, 0, block.timestamp);
        _hbBootstrap();
        shares[otherIdx] = 1;
        vm.expectRevert(bytes4(keccak256("SeShareNotBuffered()")));
        INativeLiquidity(hook).previewJoinNativeComponents(local, shares);
        vm.expectRevert(bytes4(keccak256("SeShareNotBuffered()")));
        INativeLiquidity(hook).joinNativeComponents(local, shares, HB_BOB, 0, block.timestamp);
        shares[otherIdx] = 0;
        vm.expectRevert(bytes4(keccak256("ArrayLengthMismatch()")));
        INativeLiquidity(hook).previewJoinNativeComponents(new uint256[](1), shares);
        vm.expectRevert(bytes4(keccak256("ArrayLengthMismatch()")));
        INativeLiquidity(hook).joinNativeComponents(local, new uint256[](1), HB_BOB, 0, block.timestamp);
        vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
        INativeLiquidity(hook).joinNativeComponents(local, shares, address(0), 0, block.timestamp);
        vm.expectRevert(bytes4(keccak256("DeadlineExpired()")));
        INativeLiquidity(hook).joinNativeComponents(local, shares, HB_BOB, 0, block.timestamp - 1);
    }

    /// @notice Donated custody changes neither the caller quote nor either component's funding.
    function test_nativeComponentsAmbientCustodyCannotFundCaller() public {
        _hbBootstrap();
        uint256[] memory shares = _hbFundShares(HB_BOB, 10 ether);
        uint256[] memory local = _hbFundPairs(HB_BOB, 10 ether);
        shares[1] = 0;
        local = _hbNativeAmounts(local);
        shares = _hbNativeAmounts(shares);
        uint256[] memory donatedShares = _hbFundShares(HB_ALICE, 2 ether);
        _hbFundPairs(HB_ALICE, 2 ether);
        uint256 checkpoint = vm.snapshotState();
        uint256 quote = INativeLiquidity(hook).previewJoinNativeComponents(local, shares);
        vm.prank(HB_BOB);
        assertEq(INativeLiquidity(hook).joinNativeComponents(local, shares, HB_BOB, quote, block.timestamp), quote);
        ComponentSnapshot memory control = _hbSnapshot(HB_BOB);
        assertTrue(vm.revertToState(checkpoint));
        vm.startPrank(HB_ALICE);
        IERC20(face).transfer(hook, 2 ether);
        IERC20(other).transfer(hook, 2 ether);
        IERC20(seUT).transfer(hook, donatedShares[0]);
        vm.stopPrank();
        assertEq(INativeLiquidity(hook).previewJoinNativeComponents(local, shares), quote);
        // Exhaust one real input while the hook still holds its ambient donation.
        uint256 fundedCheckpoint = vm.snapshotState();
        uint256 availableShares = IERC20(seUT).balanceOf(HB_BOB);
        vm.prank(HB_BOB);
        IERC20(seUT).transfer(address(0xDEAD), availableShares);
        ComponentSnapshot memory unfunded = _hbSnapshot(HB_BOB);
        vm.expectRevert();
        vm.prank(HB_BOB);
        INativeLiquidity(hook).joinNativeComponents(local, shares, HB_BOB, 1, block.timestamp);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(unfunded));
        assertTrue(vm.revertToState(fundedCheckpoint));
        vm.prank(HB_BOB);
        assertEq(INativeLiquidity(hook).joinNativeComponents(local, shares, HB_BOB, quote, block.timestamp), quote);
        ComponentSnapshot memory donated = _hbSnapshot(HB_BOB);
        assertEq(donated.userPairs, control.userPairs);
        assertEq(donated.userShares, control.userShares);
        assertEq(donated.supply, control.supply);
        assertEq(donated.pairs[0], control.pairs[0] + 2 ether);
        assertEq(donated.pairs[1], control.pairs[1] + 2 ether);
        assertEq(donated.shares[0], control.shares[0] + donatedShares[0]);
    }

    /// @notice Owner-only additions retain the existing caller gate on the native route.
    function test_nativeComponentsOwnerPolicy() public {
        IPackage.PkgArgs memory args = _pkgArgs(rowTokens, rowWeights, rowSes, rowProviders);
        args.ownerOnlyLiquidity = true;
        _deployHookWithArgs(args);
        uint256[] memory seed = _hbFundShares(owner, 100 ether);
        _hbJoinShares(owner, seed, 1);
        uint256[] memory local = _hbNativeAmounts(_hbFundPairs(HB_BOB, 1 ether));
        uint256[] memory shares = new uint256[](2);
        ComponentSnapshot memory beforeJoin = _hbSnapshot(HB_BOB);
        assertGt(INativeLiquidity(hook).previewJoinNativeComponents(local, shares), 0);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, HB_BOB));
        vm.prank(HB_BOB);
        INativeLiquidity(hook).joinNativeComponents(local, shares, HB_BOB, 1, block.timestamp);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(beforeJoin));
        local = _hbNativeAmounts(_hbFundPairs(owner, 1 ether));
        vm.prank(owner);
        assertGt(INativeLiquidity(hook).joinNativeComponents(local, shares, owner, 1, block.timestamp), 0);
    }
}

/// @notice The same component oracles on two SE legs plus one raw leg.
contract UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting_N3 is UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting {
    function setUp() public override {
        super.setUp();
        _initializeWeighted(3);
    }

    function test_HB48_mixedGenesisChoosesOneFundingAssetPerLeg() public {
        uint256[] memory shares = _hbFundShares(HB_ALICE, 100 ether);
        uint256[] memory pairs = _hbFundPairs(HB_ALICE, 100 ether);
        address[] memory edges = _hbPairs();
        uint256[] memory amounts = pairs;
        edges[0] = seUT;
        amounts[0] = shares[0];
        uint256 untouchedPair = IERC20(face).balanceOf(HB_ALICE);
        vm.prank(HB_ALICE);
        uint256 net = IUniswapV4SeBufferHook(hook).joinUnbalanced(edges, amounts, HB_ALICE, 1, block.timestamp);
        assertGt(net, 0);
        assertTrue(weighted.isFullBook());
        assertEq(IERC20(seUT).balanceOf(hook), shares[0] - shares[0] / 20);
        assertEq(IERC20(face).balanceOf(HB_ALICE), untouchedPair, "unused funding alternative is not taken");
    }

    function test_HB43_partialBookCanAddAndOwnAnAllLocalDisabledLeg() public {
        _hbSetFee(HB_FEE);
        uint256[] memory shares = _hbFundShares(HB_ALICE, 100 ether);
        shares[0] = 0;
        assertGt(_hbJoinShares(HB_ALICE, shares, 1), 0);
        assertFalse(weighted.isFullBook());
        assertEq(IERC20(seUT).balanceOf(hook), 0);
        _hbDisable(false, true);
        uint256[] memory pairs = _hbFundPairs(HB_BOB, 10 ether);
        uint256 seSupply = IERC20(seUT).totalSupply();
        assertGt(_hbJoinPairs(HB_BOB, pairs, 1), 0);
        assertTrue(weighted.isFullBook(), "local-only funded leg is live");
        assertEq(IERC20(seUT).balanceOf(hook), 0);
        assertEq(IERC20(seUT).totalSupply(), seSupply);
        assertGt(IERC20(face).balanceOf(hook), 0);
        pairs = _hbFundPairs(HB_BOB, 5 ether);
        ComponentSnapshot memory beforeJoin = _hbSnapshot(HB_BOB);
        assertGt(_hbJoinPairs(HB_BOB, pairs, 1), 0);
        _hbAssertContributions(beforeJoin, _hbSnapshot(HB_BOB));
        _hbFundPairs(HB_BOB, 0.01 ether);
        assertGt(_hbTrade(HB_BOB, 1, 0, 0.01 ether), 0);
        assertEq(IERC20(seUT).totalSupply(), seSupply, "local-only swap does not touch the disabled SE");
    }
}

/// @notice Maximum topology uses one real FullSpread leg and seven raw legs.
contract UniswapV4StandardExchangeWeightedBufferHook_ComponentAccounting_N8 is TestBase_UniswapV4StandardExchangeWeightedBufferHook, HookExactNetComponentAccountingBehavior {
    SeMatrix_FullSpreadV4Fixture internal fullSpread;
    address[] internal rowTokens;
    address[] internal rowSes;
    address[] internal rowProviders;
    uint256[] internal rowWeights;
    uint256 internal rowCount;
    uint256 internal faceIdx;
    uint256 internal otherIdx;
    address internal face;
    address internal other;
    address internal seUT;
    function setUp() public override {
        super.setUp();
        fullSpread = new SeMatrix_FullSpreadV4Fixture(SeMatrixFixture.Ctx({
            create3Factory: create3Factory, indexedexManager: IIndexedexManagerProxy(address(indexedexManager)), owner: owner,
            permit2: permit2, erc20Facet: erc20Facet, erc2612Facet: erc2612Facet, erc5267Facet: erc5267Facet,
            erc4626Facet: erc4626Facet, erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet, multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
        }), address(0));
        face = fullSpread.faceToken(); seUT = fullSpread.se(); pm = fullSpread.poolManager();
        rowCount = 8;
        delete rowTokens;
        rowTokens.push(face);
        for (uint256 i; i < 7; ++i) rowTokens.push(address(new SimpleMintableERC20("Weighted raw", "RAW")));
        other = rowTokens[1];
        for (uint256 i; i < 8; ++i) for (uint256 j = i + 1; j < 8; ++j) {
            if (rowTokens[j] < rowTokens[i]) (rowTokens[i], rowTokens[j]) = (rowTokens[j], rowTokens[i]);
        }
        delete rowSes; delete rowProviders; delete rowWeights;
        for (uint256 i; i < 8; ++i) {
            bool buffered = rowTokens[i] == face;
            rowSes.push(buffered ? seUT : address(0));
            rowProviders.push(buffered ? fullSpread.currency0Provider() : address(0));
            rowWeights.push(0.125e18);
            if (buffered) faceIdx = i;
            if (rowTokens[i] == other) otherIdx = i;
        }
        IPackage.PkgArgs memory args = _pkgArgs(rowTokens, rowWeights, rowSes, rowProviders);
        _deployHookWithArgs(args);
        _setUsageFee(HB_FEE);
    }
    function _hbHook() internal view override returns (address) { return hook; }

    function _hbPairs() internal view override returns (address[] memory pairs_) {
        pairs_ = new address[](rowTokens.length);
        for (uint256 i_; i_ < pairs_.length; ++i_) pairs_[i_] = rowTokens[_hbNativeIndex(i_)];
    }

    function _hbExchanges() internal view override returns (address[] memory exchanges_) {
        exchanges_ = new address[](rowTokens.length);
        for (uint256 i_; i_ < exchanges_.length; ++i_) exchanges_[i_] = rowSes[_hbNativeIndex(i_)];
    }

    /// @dev Reorder whole records for the behavior: primary buffered, counter, remaining legs.
    function _hbNativeIndex(uint256 index_) internal view returns (uint256) {
        if (index_ == 0) return faceIdx;
        if (index_ == 1) return otherIdx;
        uint256 canonical_ = 2;
        for (uint256 i_; i_ < rowTokens.length; ++i_) {
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
            vm.prank(owner);
            IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        }
        _setUsageFee(fee_);
        assertEq(IVaultFeeOracleQuery(address(indexedexManager)).usageFeeOfVault(hook),
            fee_, "configured hook LP fee");
    }
    function _hbFeeRecipient() internal view override returns (address) { return weighted.feeTo(); }

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
        (net_,) = weighted.joinProportionalFlexible(native_, flags_, actor_, minimum_, block.timestamp);
    }

    function _hbJoinPairs(address actor_, uint256[] memory amounts_, uint256 minimum_)
        internal override returns (uint256 net_)
    {
        uint256[] memory native_ = _hbNativeAmounts(amounts_);
        bool[] memory flags_ = new bool[](amounts_.length);
        vm.prank(actor_);
        (net_,) = weighted.joinProportionalFlexible(native_, flags_, actor_, minimum_, block.timestamp);
    }

    function _hbExitPairs(address actor_, uint256 burned_) internal override {
        uint256[] memory minima_ = new uint256[](rowTokens.length);
        bool[] memory flags_ = new bool[](rowTokens.length);
        for (uint256 i_; i_ < minima_.length; ++i_) minima_[i_] = 1;
        vm.prank(actor_);
        weighted.exitProportionalFlexible(burned_, actor_, flags_, minima_, block.timestamp);
    }

    function _hbMoveUnderlyingMarket() internal override {
        fullSpread.acquireShares(seUT, face, address(0xCAFE40), 50_000 ether);
    }

    function _hbRate() internal view override returns (uint256) { return IRateProvider(weighted.rateProvider(face)).getRate(); }
    function _hbMinimumError() internal pure override returns (bytes4) { return bytes4(keccak256("Slippage()")); }
    function _hbInitialPairError() internal pure override returns (bytes4) { return bytes4(keccak256("InvalidRoute(address,address)")); }
    function _hbInitialPairErrorData() internal view override returns (bytes memory) {
        return abi.encodeWithSelector(_hbInitialPairError(), face, hook);
    }

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
        net_ = weighted.previewJoinSingleAssetExactIn(other, maximum_);
    }

    function _hbExactNet(address actor_, uint256 net_, uint256 maximum_) internal override returns (uint256) {
        vm.prank(actor_);
        return IUniswapV4SeBufferHook(hook).joinSingleAssetExactOut(other, net_, actor_, maximum_, block.timestamp);
    }
    function test_HB43_n8SingleAndUnbalancedUseSamePaidPreparation() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 10 ether);
        ComponentSnapshot memory beforeJoin = _hbSnapshot(HB_BOB);
        uint256 checkpoint = vm.snapshotState();
        vm.prank(HB_BOB);
        uint256 single = weighted.depositSingle(other, 1 ether, HB_BOB, 1, block.timestamp);
        assertGt(single, 0);
        ComponentSnapshot memory control = _hbSnapshot(HB_BOB);
        _hbAssertFee(beforeJoin, control, single);
        assertTrue(vm.revertToState(checkpoint));
        uint256[] memory amounts = new uint256[](8);
        amounts[otherIdx] = 1 ether;
        vm.prank(HB_BOB);
        assertEq(weighted.joinUnbalanced(amounts, HB_BOB, 1, block.timestamp), single);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(control));
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
    }
}

/// @dev Non-SUT integration caller leaves output credit unsettled after a real swap.
contract WeightedUnsettledSwapCaller is IUnlockCallback {
    IPoolManager private immutable manager;
    constructor(IPoolManager manager_) { manager = manager_; }
    function run(PoolKey memory key, bool zeroForOne, uint256 amount) external {
        manager.unlock(abi.encode(msg.sender, key, zeroForOne, amount));
    }
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(manager), "manager");
        (address payer, PoolKey memory key, bool zeroForOne, uint256 amount) = abi.decode(data, (address, PoolKey, bool, uint256));
        Currency input = zeroForOne ? key.currency0 : key.currency1;
        manager.sync(input);
        IERC20(Currency.unwrap(input)).transferFrom(payer, address(manager), amount);
        manager.settle();
        manager.swap(key, SwapParams(zeroForOne, -int256(amount), zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), "");
        return "";
    }
}
