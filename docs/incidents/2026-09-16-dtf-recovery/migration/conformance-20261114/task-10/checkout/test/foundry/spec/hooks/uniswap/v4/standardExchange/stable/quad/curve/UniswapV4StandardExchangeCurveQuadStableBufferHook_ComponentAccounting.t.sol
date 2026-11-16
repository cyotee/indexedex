// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IStandardExchangeMultiAssetLiquidity} from "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {SeMatrix_FullSpreadV4Fixture} from "../../../SeMatrix_FullSpreadV4Fixture.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4SeBufferHookNativeLiquidity} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";
import {HookExactNetComponentAccountingBehavior} from "../../../HookComponentAccountingBehavior.sol";
import {Vm} from "forge-std/Vm.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookMath as CurveMath} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault as FullSpreadRow} from "./UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";

/// @notice Real FullSpread component-accounting adapter; no substitute vault or synthetic balances.
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_ComponentAccounting is FullSpreadRow, HookExactNetComponentAccountingBehavior {
    struct NativeJoinWitness {
        uint256[4] shares;
        uint256[4] local;
        uint256[4] incomingShares;
        uint256[4] incomingLocal;
    }

    /// @notice Mixed inputs pay for nonzero deficiencies without redeeming either buffered leg.
    function test_nativeJoinMixedBasketUsesPostPaidBooksAndRefunds() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundShares(HB_BOB, 100 ether);
        _hbFundPairs(HB_BOB, 100 ether);
        _setDexFee(3e15);
        (uint256[] memory local, uint256[] memory shares) = _nativeInputs();
        NativeJoinWitness memory paid = _nativePaidWitness(local, shares);
        uint256 supply = IERC20(hook).totalSupply();
        uint256 gross = type(uint256).max;
        for (uint256 i; i < 4; ++i) {
            gross = FullMath.min(gross, FullMath.mulDiv(paid.incomingLocal[i], supply, paid.local[i]));
            if (paid.shares[i] != 0) {
                gross = FullMath.min(gross, FullMath.mulDiv(paid.incomingShares[i], supply, paid.shares[i]));
            }
        }
        assertGt(paid.local[otherIdx], IERC20(other).balanceOf(hook), "excess raw input pays incumbent book");
        assertLt(paid.shares[faceIdx], quad.seBalance(faceIdx), "nonzero deficient leg buys actual shares");
        uint256 predicted = quad.previewJoinNativeComponents(local, shares);
        assertEq(predicted, gross - FullMath.mulDiv(gross, HB_FEE, 1e18));
        assertTrue(IERC165(hook).supportsInterface(type(IUniswapV4SeBufferHookNativeLiquidity).interfaceId));
        assertTrue(IDiamondLoupe(hook).facetAddress(IUniswapV4SeBufferHookNativeLiquidity.joinNativeComponents.selector) != address(0));
        assertTrue(IDiamondLoupe(hook).facetAddress(IUniswapV4SeBufferHookNativeLiquidity.previewJoinNativeComponents.selector) != address(0));
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.prank(HB_BOB);
        uint256 net = quad.joinNativeComponents(local, shares, HB_BOB, predicted, block.timestamp);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertEq(net, predicted);
        _hbAssertFee(before_, after_, net);
        assertEq(after_.shareSupply, before_.shareSupply, "complete native basket never churns through SE conversion");
        assertEq(after_.supply - supply, gross);
        uint256 returnedLocal;
        uint256 returnedShares;
        for (uint256 i; i < 4; ++i) {
            uint256 acceptedLocal = FullMath.mulDiv(gross, paid.local[i], supply, FullMath.Rounding.Ceil);
            uint256 acceptedShares = FullMath.mulDiv(gross, paid.shares[i], supply, FullMath.Rounding.Ceil);
            assertLe(acceptedLocal, paid.incomingLocal[i]);
            assertLe(acceptedShares, paid.incomingShares[i]);
            assertEq(IERC20(rowTokens[i]).balanceOf(hook), paid.local[i] + acceptedLocal);
            assertEq(quad.seBalance(i), paid.shares[i] + acceptedShares);
            uint256 canonical = _nativeBehaviorIndex(i);
            uint256 localRefund = paid.incomingLocal[i] - acceptedLocal;
            assertEq(IERC20(rowTokens[i]).balanceOf(HB_BOB), before_.userPairs[canonical] - local[i] + localRefund);
            returnedLocal += localRefund;
            if (rowSes[i] != address(0)) {
                uint256 shareRefund = paid.incomingShares[i] - acceptedShares;
                assertEq(IERC20(rowSes[i]).balanceOf(hook), paid.shares[i] + acceptedShares);
                assertEq(IERC20(rowSes[i]).balanceOf(HB_BOB), before_.userShares[canonical] - shares[i] + shareRefund);
                returnedShares += shareRefund;
            }
        }
        assertGt(returnedLocal, 0, "local surplus belongs to caller");
        assertGt(returnedShares, 0, "share surplus belongs to caller");
    }

    /// @notice A genuinely absent local component is assembled with an actual caller-share receipt.
    function test_nativeJoinConvertsOnlyMissingComponentWithPreviewParity() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundShares(HB_BOB, 100 ether);
        _hbFundPairs(HB_BOB, 100 ether);
        (uint256[] memory local, uint256[] memory shares) = _nativeInputs();
        local[otherIdx] = IERC20(other).balanceOf(hook) / 100;
        local[faceIdx] = 0;
        shares[faceIdx] = quad.seBalance(faceIdx) / 2;
        uint256 predicted = quad.previewJoinNativeComponents(local, shares);
        assertGt(predicted, 0);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.prank(HB_BOB);
        uint256 net = quad.joinNativeComponents(local, shares, HB_BOB, predicted, block.timestamp);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertEq(net, predicted);
        _hbAssertFee(before_, after_, net);
        assertLt(after_.shareSupply[0], before_.shareSupply[0], "missing face local uses a real redemption");
        for (uint256 i; i < 4; ++i) {
            if (i == faceIdx || rowSes[i] == address(0)) continue;
            uint256 canonical = _nativeBehaviorIndex(i);
            assertEq(after_.shareSupply[canonical], before_.shareSupply[canonical], "already mixed sibling does not convert");
        }
    }

    function test_nativeJoinLiveOnlyAndInvalidComponents() public {
        uint256[] memory local = new uint256[](4);
        uint256[] memory shares = new uint256[](4);
        vm.expectRevert(bytes4(keccak256("NotLive()")));
        quad.previewJoinNativeComponents(local, shares);
        vm.expectRevert(bytes4(keccak256("NotLive()")));
        quad.joinNativeComponents(local, shares, HB_BOB, 0, block.timestamp);
        _hbBootstrap();
        shares[otherIdx] = 1;
        vm.expectRevert(bytes4(keccak256("SeShareNotBuffered()")));
        quad.previewJoinNativeComponents(local, shares);
        vm.expectRevert(bytes4(keccak256("SeShareNotBuffered()")));
        quad.joinNativeComponents(local, shares, HB_BOB, 0, block.timestamp);
        vm.expectRevert(bytes4(keccak256("InvalidN()")));
        quad.previewJoinNativeComponents(new uint256[](3), new uint256[](4));
        vm.expectRevert(bytes4(keccak256("InvalidN()")));
        quad.joinNativeComponents(new uint256[](4), new uint256[](3), HB_BOB, 0, block.timestamp);
    }

    function test_nativeJoinCannotSpendAmbientCustody() public {
        _hbBootstrap();
        _hbFundShares(HB_BOB, 100 ether);
        _hbFundPairs(HB_BOB, 100 ether);
        (uint256[] memory local, uint256[] memory shares) = _nativeInputs();
        address unfunded = address(0xBADC040);
        for (uint256 i; i < 4; ++i) {
            vm.prank(HB_BOB);
            IERC20(rowTokens[i]).transfer(hook, local[i]);
            vm.prank(unfunded);
            IERC20(rowTokens[i]).approve(hook, type(uint256).max);
            if (shares[i] != 0) {
                vm.prank(HB_BOB);
                IERC20(rowSes[i]).transfer(hook, shares[i]);
                vm.prank(unfunded);
                IERC20(rowSes[i]).approve(hook, type(uint256).max);
            }
        }
        bytes memory before_ = _strictSnapshot(unfunded);
        vm.prank(unfunded);
        (bool ok,) = hook.call(abi.encodeCall(
            IUniswapV4SeBufferHookNativeLiquidity.joinNativeComponents, (local, shares, unfunded, 0, block.timestamp)
        ));
        assertFalse(ok, "ambient inventory cannot replace caller funding");
        assertEq(_strictSnapshot(unfunded), before_);
        assertEq(quad.previewJoinNativeComponents(new uint256[](4), new uint256[](4)), 0);
    }

    function test_nativeJoinMinimumDeadlineAndRecipientRollback() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundShares(HB_BOB, 100 ether);
        _hbFundPairs(HB_BOB, 100 ether);
        (uint256[] memory local, uint256[] memory shares) = _nativeInputs();
        uint256 predicted = quad.previewJoinNativeComponents(local, shares);
        bytes memory before_ = _strictSnapshot(HB_BOB);
        vm.startPrank(HB_BOB);
        vm.expectRevert(bytes4(keccak256("Slippage()")));
        quad.joinNativeComponents(local, shares, HB_BOB, predicted + 1, block.timestamp);
        vm.expectRevert(bytes4(keccak256("ZeroAddress()")));
        quad.joinNativeComponents(local, shares, address(0), 0, block.timestamp);
        vm.expectRevert(bytes4(keccak256("DeadlineExpired()")));
        quad.joinNativeComponents(local, shares, HB_BOB, 0, block.timestamp - 1);
        vm.stopPrank();
        assertEq(_strictSnapshot(HB_BOB), before_);
    }

    function _nativeInputs() private view returns (uint256[] memory local, uint256[] memory shares) {
        local = new uint256[](4);
        shares = new uint256[](4);
        for (uint256 i; i < 4; ++i) {
            local[i] = IERC20(rowTokens[i]).balanceOf(hook) / 100;
            shares[i] = quad.seBalance(i) / 100;
        }
        local[otherIdx] = IERC20(other).balanceOf(hook) / 2;
    }

    function _nativeBehaviorIndex(uint256 nativeIndex) private view returns (uint256) {
        for (uint256 i; i < 4; ++i) if (_hbNativeIndex(i) == nativeIndex) return i;
        revert("invalid native index");
    }

    /// @dev Independent witness for one raw excess source and three nonzero deficient legs.
    /// No component conversion is needed; each paid Curve output buys incumbent S/L pro rata.
    function _nativePaidWitness(uint256[] memory local, uint256[] memory shares)
        private view returns (NativeJoinWitness memory paid)
    {
        uint256[4] memory rated;
        uint256[4] memory supplied;
        uint256[4] memory target;
        uint256 totalBook;
        uint256 totalIn;
        for (uint256 i; i < 4; ++i) {
            paid.shares[i] = quad.seBalance(i);
            paid.local[i] = IERC20(rowTokens[i]).balanceOf(hook);
            paid.incomingShares[i] = shares[i];
            paid.incomingLocal[i] = local[i];
            rated[i] = _nativeComponentValue(i, paid.shares[i], paid.local[i]);
            supplied[i] = _nativeComponentValue(i, shares[i], local[i]);
            totalBook += rated[i];
            totalIn += supplied[i];
        }
        for (uint256 i; i < 4; ++i) target[i] = FullMath.mulDiv(totalIn, rated[i], totalBook);
        for (uint256 j; j < 4; ++j) {
            if (j == otherIdx) continue;
            uint256 sale = FullMath.min(supplied[otherIdx] - target[otherIdx], target[j] - supplied[j]);
            uint256 localIn = FullMath.mulDiv(paid.incomingLocal[otherIdx], sale, supplied[otherIdx]);
            uint256 budget = CurveMath.quoteExactInRated(
                rated, otherIdx, j,
                CurveMath.applyTradingFeeNet(_nativeComponentValue(otherIdx, 0, localIn), quad.dexSwapFee()),
                quad.getCurrentAmp()
            );
            uint256 sharesOut = FullMath.mulDiv(paid.shares[j], budget, rated[j]);
            uint256 localOut = FullMath.mulDiv(paid.local[j], budget, rated[j]);
            paid.local[otherIdx] += localIn;
            paid.incomingLocal[otherIdx] -= localIn;
            paid.shares[j] -= sharesOut;
            paid.local[j] -= localOut;
            paid.incomingShares[j] += sharesOut;
            paid.incomingLocal[j] += localOut;
            for (uint256 k; k < 4; ++k) rated[k] = _nativeComponentValue(k, paid.shares[k], paid.local[k]);
            supplied[otherIdx] = _nativeComponentValue(otherIdx, 0, paid.incomingLocal[otherIdx]);
        }
    }

    function _nativeComponentValue(uint256 i, uint256 shares, uint256 local) private view returns (uint256) {
        uint256 rate = rowProviders[i] == address(0) ? 1e18 : IRateProvider(rowProviders[i]).getRate();
        uint256 pairUnits = rowSes[i] == address(0) ? local
            : local + CurveMath.ratedPairUnits(shares, rate, quad.invScale(i), quad.ratedScale(i));
        return CurveMath.scaleTo(pairUnits, quad.ratedScale(i));
    }

    function test_H643_singleJoinPaysForMissingComponents() public { _singleAlias(0); }
    function test_H643_depositAliasPaysForMissingComponents() public { _singleAlias(1); }
    function test_H643_flexibleJoinPaysForMissingComponents() public { _singleAlias(2); }
    function test_H643_flexibleDepositPaysForMissingComponents() public { _singleAlias(3); }
    function test_H643_seJoinPaysForMissingComponents() public { _singleAlias(4); }
    function test_H643_syJoinPaysForMissingComponents() public { _singleAlias(5); }
    function test_H643_orderedSparseJoinPaysForMissingComponents() public { _singleAlias(6); }
    function test_H643_listedSparseJoinPaysForMissingComponents() public { _singleAlias(7); }
    function test_H643_permit2SingleJoinPaysForMissingComponents() public { _singleAlias(8); }

    function test_H643_sparseUnbalancedConvertsButProportionalRequiresComponents() public {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 10 ether);
        vm.startPrank(HB_BOB);
        for (uint256 i; i < 4; ++i) IERC20(rowTokens[i]).approve(hook, 1 ether);
        vm.stopPrank();
        for (uint256 missing; missing < 4; ++missing) {
            uint256 checkpoint = vm.snapshotState();
            uint256[] memory ordered = new uint256[](4);
            address[] memory inputs = new address[](3);
            uint256[] memory amounts = new uint256[](3);
            uint256 next;
            for (uint256 i; i < 4; ++i) {
                if (i == missing) continue;
                ordered[i] = 1 ether;
                inputs[next] = rowTokens[i];
                amounts[next++] = 1 ether;
            }
            uint256 orderedQuote = quad.previewJoinUnbalanced(ordered);
            assertGt(orderedQuote, 0);
            assertEq(quad.previewJoinUnbalanced(inputs, amounts), orderedQuote);
            (uint256 net, uint256[] memory used) =
                quad.previewJoinProportionalFlexible(ordered, new bool[](4));
            assertEq(net, 0);
            assertEq(used, new uint256[](4), "unaccepted basket has no usable input quote");
            bytes memory before_ = _strictSnapshot(HB_BOB);
            vm.prank(HB_BOB);
            vm.expectRevert(bytes4(keccak256("ZeroAmount()")));
            quad.joinProportionalFlexible(ordered, new bool[](4), HB_BOB, 0, block.timestamp);
            assertEq(_strictSnapshot(HB_BOB), before_);
            vm.prank(HB_BOB);
            uint256 orderedNet = quad.joinUnbalanced(ordered, HB_BOB, 1, block.timestamp);
            assertGt(orderedNet, 0);
            assertTrue(vm.revertToState(checkpoint));
            checkpoint = vm.snapshotState();
            vm.prank(HB_BOB);
            uint256 listedNet = quad.joinUnbalanced(inputs, amounts, HB_BOB, 1, block.timestamp);
            assertEq(listedNet, orderedNet, "both installed unbalanced facades use the same paid basket");
            assertTrue(vm.revertToState(checkpoint));
        }
    }

    function _singleAlias(uint8 route) private {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        uint256 amount = 1 ether;
        uint256 predicted = quad.previewJoinSingleAssetExactIn(other, amount);
        assertGt(predicted, 0);
        uint256[] memory ordered = new uint256[](4);
        ordered[otherIdx] = amount;
        address[] memory inputs = new address[](1);
        inputs[0] = other;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        if (route == 8) {
            vm.startPrank(HB_BOB);
            IERC20(other).approve(hook, 0);
            IERC20(other).approve(PERMIT2_ADDR, type(uint256).max);
            IAllowanceTransfer(PERMIT2_ADDR).approve(other, hook, type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }
        assertEq(quad.previewJoinUnbalanced(ordered), predicted);
        assertEq(quad.previewJoinUnbalanced(inputs, amounts), predicted);
        (uint256 seQuote, uint256 refundQuote) = IStandardExchangeIn(hook).previewExchangeIn(IERC20(other), amount, IERC20(hook));
        assertEq(seQuote, predicted);
        assertLe(refundQuote, amount);
        assertEq(IStandardizedYield(hook).previewDeposit(other, amount), predicted);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.prank(HB_BOB);
        if (route == 0 || route == 8) quad.joinSingleAssetExactIn(other, amount, HB_BOB, predicted, block.timestamp);
        else if (route == 1) quad.depositSingle(other, amount, HB_BOB, predicted, block.timestamp);
        else if (route == 2) quad.joinSingleAssetExactInFlexible(other, amount, false, HB_BOB, predicted, block.timestamp);
        else if (route == 3) quad.depositSingleFlexible(other, amount, false, HB_BOB, predicted, block.timestamp);
        else if (route == 4) IStandardExchangeIn(hook).exchangeIn(
            IERC20(other), amount, IERC20(hook), predicted, HB_BOB, false, block.timestamp
        );
        else if (route == 5) IStandardizedYield(hook).deposit(HB_BOB, other, amount, predicted);
        else if (route == 6) quad.joinUnbalanced(ordered, HB_BOB, predicted, block.timestamp);
        else quad.joinUnbalanced(inputs, amounts, HB_BOB, predicted, block.timestamp);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        _hbAssertFee(before_, after_, predicted);
        assertEq(before_.userPairs[1] - after_.userPairs[1], amount - refundQuote);
        assertEq(after_.shareSupply, before_.shareSupply, "in-kind trades do not mint or redeem SE inventory");
        assertLe(after_.shares[0], before_.shares[0], "only paid inventory can leave incumbent custody");
    }

    function test_H643_preownedShareSingleJoinUsesActualRedemption() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts = _hbFundShares(HB_BOB, 10 ether);
        uint256 predicted = quad.previewDepositSingleFlexible(face, amounts[0], true);
        assertGt(predicted, 0);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.prank(HB_BOB);
        uint256 net = quad.depositSingleFlexible(face, amounts[0], true, HB_BOB, 1, block.timestamp);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertGt(net, 0);
        _hbAssertFee(before_, after_, net);
        assertLt(after_.shareSupply[0], before_.shareSupply[0], "only actual caller-share conversion burns SE shares");
    }

    function test_H643_shareAddressAliasPaysForMissingComponents() public { _shareAlias(0); }
    function test_H643_flexibleShareJoinPaysForMissingComponents() public { _shareAlias(1); }
    function test_H643_seShareAliasPaysForMissingComponents() public { _shareAlias(2); }
    function test_H643_syShareAliasPaysForMissingComponents() public { _shareAlias(3); }

    function _shareAlias(uint8 route) private {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts = _hbFundShares(HB_BOB, 10 ether);
        uint256 predicted = quad.previewJoinSingleAssetExactIn(seUT, amounts[0]);
        assertGt(predicted, 0);
        assertEq(predicted, quad.previewJoinSingleAssetExactInFlexible(face, amounts[0], true));
        (uint256 seQuote, uint256 refundQuote) =
            IStandardExchangeIn(hook).previewExchangeIn(IERC20(seUT), amounts[0], IERC20(hook));
        assertEq(seQuote, predicted);
        assertLe(refundQuote, amounts[0]);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.prank(HB_BOB);
        if (route == 0) quad.joinSingleAssetExactIn(seUT, amounts[0], HB_BOB, 1, block.timestamp);
        else if (route == 1) quad.joinSingleAssetExactInFlexible(face, amounts[0], true, HB_BOB, 1, block.timestamp);
        else if (route == 2) IStandardExchangeIn(hook).exchangeIn(
            IERC20(seUT), amounts[0], IERC20(hook), 1, HB_BOB, false, block.timestamp
        );
        else IStandardizedYield(hook).deposit(HB_BOB, seUT, amounts[0], 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        uint256 net = after_.userLp - before_.userLp;
        assertGt(net, 0);
        _hbAssertFee(before_, after_, net);
    }

    function test_H643_bufferedPairSingleJoinUsesActualConversion() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        uint256 predicted = quad.previewJoinSingleAssetExactIn(face, 1 ether);
        assertGt(predicted, 0);
        (uint256 seQuote, uint256 refundQuote) =
            IStandardExchangeIn(hook).previewExchangeIn(IERC20(face), 1 ether, IERC20(hook));
        assertEq(seQuote, predicted);
        assertLe(refundQuote, 1 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.prank(HB_BOB);
        uint256 net = quad.joinSingleAssetExactIn(face, 1 ether, HB_BOB, 1, block.timestamp);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        _hbAssertFee(before_, after_, net);
        assertGt(after_.shareSupply[0], before_.shareSupply[0]);
    }

    function test_H647_exactNetInsufficientMaximumRejectsBeforeFunding() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        uint256 requested = 1 ether;
        bytes memory before_ = _strictSnapshot(HB_BOB);
        uint256 required = quad.previewJoinSingleAssetExactOut(other, requested);
        assertGt(required, 1 ether, "the caller maximum really cannot fund this mint");
        vm.prank(HB_BOB);
        vm.expectRevert(bytes4(keccak256("Slippage()")));
        quad.joinSingleAssetExactOut(other, requested, HB_BOB, 1 ether, block.timestamp);
        assertEq(_strictSnapshot(HB_BOB), before_);
    }

    function test_H647_seExactNetInsufficientMaximumRollsBack() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        uint256 requested = 1 ether;
        bytes memory before_ = _strictSnapshot(HB_BOB);
        uint256 required = quad.previewJoinSingleAssetExactOut(other, requested);
        assertGt(required, 1 ether);
        vm.prank(HB_BOB);
        vm.expectRevert(abi.encodeWithSelector(
            bytes4(keccak256("LiquidityMaximumExceeded(uint256,uint256)")), 1 ether, required
        ));
        IStandardExchangeOut(hook).exchangeOut(
            IERC20(other), 1 ether, IERC20(hook), requested, HB_BOB, false, block.timestamp
        );
        assertEq(_strictSnapshot(HB_BOB), before_);
    }

    function test_H647_infeasibleExactNetFeeFailsBeforeFunding() public {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        _hbSetFee(1e18);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.prank(HB_BOB);
        vm.expectRevert(bytes4(keccak256("ExactNetLiquidityUnavailable()")));
        quad.joinSingleAssetExactOut(other, 1, HB_BOB, 100 ether, block.timestamp);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(before_));
    }

    function test_H645_rawSingleJoinPaysForDisabledInventoryWithoutMintingShares() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        _hbDisable(true, true);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        uint256 predicted = quad.previewJoinSingleAssetExactIn(other, 1 ether);
        assertGt(predicted, 0);
        vm.prank(HB_BOB);
        uint256 net = quad.joinSingleAssetExactIn(other, 1 ether, HB_BOB, predicted, block.timestamp);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        _hbAssertFee(before_, after_, net);
        assertEq(after_.shareSupply, before_.shareSupply, "no disabled SE deposit is attempted");
    }

    function test_H645_reenableKeepsLocalOwnershipOnNextShareJoin() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        _hbDisable(false, true);
        _hbTrade(HB_BOB, 0, 1, 10 ether);
        _hbDisable(false, false);
        uint256[] memory amounts = _hbFundShares(HB_BOB, 10 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        uint256 net = _hbJoinShares(HB_BOB, amounts, 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        _hbAssertFee(before_, after_, net);
        _hbAssertContributions(before_, after_);
    }

    /// @notice Price the raw caller's actual sales independently, then assert every
    /// accepted component against that post-swap book, not the original LP book.
    function test_H643_singleJoinMintBoundaryUsesPaidPostSwapComponents() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        uint256 amount = 1 ether;
        uint256 supply = IERC20(hook).totalSupply();
        uint256[4] memory shares;
        uint256[4] memory local;
        uint256[4] memory boughtShares;
        uint256[4] memory boughtLocal;
        uint256[4] memory rated;
        uint256[4] memory targets;
        uint256 total;
        for (uint256 i; i < 4; ++i) {
            shares[i] = quad.seBalance(i);
            local[i] = IERC20(rowTokens[i]).balanceOf(hook);
            rated[i] = CurveMath.scaleTo(quad.ratedBalance(i), quad.ratedScale(i));
            total += rated[i];
        }
        assertEq(rowSes[otherIdx], address(0));
        uint256 inputValue = CurveMath.scaleTo(amount, quad.ratedScale(otherIdx));
        for (uint256 i; i < 4; ++i) targets[i] = FullMath.mulDiv(inputValue, rated[i], total);
        uint256 remaining = amount;
        for (uint256 j; j < 4; ++j) {
            if (j == otherIdx) continue;
            uint256 available = CurveMath.scaleTo(remaining, quad.ratedScale(otherIdx));
            uint256 sale = FullMath.min(available - targets[otherIdx], targets[j]);
            uint256 localIn = FullMath.mulDiv(remaining, sale, available);
            uint256 budget = CurveMath.quoteExactInRated(
                rated, otherIdx, j,
                CurveMath.applyTradingFeeNet(CurveMath.scaleTo(localIn, quad.ratedScale(otherIdx)), quad.dexSwapFee()),
                quad.getCurrentAmp()
            );
            boughtShares[j] = FullMath.mulDiv(shares[j], budget, rated[j]);
            boughtLocal[j] = FullMath.mulDiv(local[j], budget, rated[j]);
            shares[j] -= boughtShares[j];
            local[j] -= boughtLocal[j];
            local[otherIdx] += localIn;
            remaining -= localIn;
            // Same independent rated units after each completed paid trade.
            for (uint256 k; k < 4; ++k) {
                uint256 rate = rowProviders[k] == address(0) ? 1e18 : IRateProvider(rowProviders[k]).getRate();
                uint256 pairUnits = rowSes[k] == address(0) ? local[k]
                    : local[k] + CurveMath.ratedPairUnits(shares[k], rate, quad.invScale(k), quad.ratedScale(k));
                rated[k] = CurveMath.scaleTo(pairUnits, quad.ratedScale(k));
            }
        }
        boughtLocal[otherIdx] = remaining;
        uint256[4] memory userPairs;
        uint256[4] memory userShares;
        for (uint256 i; i < 4; ++i) {
            userPairs[i] = IERC20(rowTokens[i]).balanceOf(HB_BOB);
            if (rowSes[i] != address(0)) userShares[i] = IERC20(rowSes[i]).balanceOf(HB_BOB);
        }
        vm.prank(HB_BOB);
        uint256 net = quad.joinSingleAssetExactIn(other, amount, HB_BOB, 1, block.timestamp);
        uint256 gross = IERC20(hook).totalSupply() - supply;
        assertGt(net, 0);
        for (uint256 i; i < 4; ++i) {
            uint256 requiredShares = FullMath.mulDiv(gross, shares[i], supply, FullMath.Rounding.Ceil);
            uint256 requiredLocal = FullMath.mulDiv(gross, local[i], supply, FullMath.Rounding.Ceil);
            assertLe(requiredShares, boughtShares[i]);
            assertLe(requiredLocal, boughtLocal[i]);
            assertEq(quad.seBalance(i), shares[i] + requiredShares, "post-swap ceil share backing");
            assertEq(IERC20(rowTokens[i]).balanceOf(hook), local[i] + requiredLocal, "post-swap ceil local backing");
            uint256 contributed = i == otherIdx ? amount : 0;
            assertEq(IERC20(rowTokens[i]).balanceOf(HB_BOB),
                userPairs[i] - contributed + boughtLocal[i] - requiredLocal, "caller owns every local remainder");
            if (rowSes[i] != address(0)) {
                assertEq(IERC20(rowSes[i]).balanceOf(HB_BOB),
                    userShares[i] + boughtShares[i] - requiredShares, "caller owns every share remainder");
            }
        }
    }

    function test_H647_exactNetPaidSingleJoinMintsOnlyRequestedNet() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        uint256 requested = 1 ether;
        uint256 maximum = quad.previewJoinSingleAssetExactOut(other, requested);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.prank(HB_BOB);
        uint256 used = quad.joinSingleAssetExactOut(other, requested, HB_BOB, maximum, block.timestamp);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        _hbAssertFee(before_, after_, requested);
        assertLe(used, maximum);
        assertEq(before_.userPairs[1] - after_.userPairs[1], used);
    }

    function test_H648_pairGenesisRedeemsFivePercentOfActuallyAcquiredShares() public {
        _hbSetFee(HB_FEE);
        uint256[] memory amounts = _hbNativeAmounts(_hbFundPairs(HB_ALICE, 100 ether));
        uint256[4] memory pairBefore;
        for (uint256 i; i < 4; ++i) pairBefore[i] = IERC20(rowTokens[i]).balanceOf(HB_ALICE);
        vm.recordLogs();
        vm.prank(HB_ALICE);
        (uint256 net, uint256[] memory used) =
            quad.joinProportional(amounts, HB_ALICE, 1, block.timestamp);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertGt(net, 0);
        bool partialRefund;
        for (uint256 i; i < 4; ++i) {
            assertEq(pairBefore[i] - IERC20(rowTokens[i]).balanceOf(HB_ALICE), used[i]);
            if (rowSes[i] == address(0)) continue;
            uint256 acquired;
            uint256 redeemed;
            for (uint256 j; j < logs.length; ++j) {
                if (logs[j].emitter != rowSes[i] || logs[j].topics.length != 3
                    || logs[j].topics[0] != keccak256("Transfer(address,address,uint256)")) continue;
                if (logs[j].topics[1] == bytes32(0)
                    && logs[j].topics[2] == bytes32(uint256(uint160(hook)))) {
                    acquired += abi.decode(logs[j].data, (uint256));
                }
                if (logs[j].topics[1] == bytes32(uint256(uint160(hook))) && logs[j].topics[2] == bytes32(0)) {
                    redeemed += abi.decode(logs[j].data, (uint256));
                }
            }
            assertGt(acquired, 0);
            assertEq(redeemed, acquired / 20, "actual acquired shares, not pair input or preview output");
            assertEq(quad.seBalance(i), acquired - redeemed);
            assertGt(IERC20(rowTokens[i]).balanceOf(hook), 0, "actual redemption seeds local backing");
            if (used[i] < amounts[i]) partialRefund = true;
        }
        assertTrue(partialRefund, "real FullSpread acquisition refund is returned, not seeded");
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
    }

    function test_H648_mixedPairAndShareGenesisSuppliesEachLegOnce() public {
        _hbSetFee(HB_FEE);
        uint256[] memory shares = _hbNativeAmounts(_hbFundShares(HB_ALICE, 100 ether));
        uint256[] memory pairs = _hbNativeAmounts(_hbFundPairs(HB_ALICE, 100 ether));
        bool[] memory flags = new bool[](4);
        flags[faceIdx] = true;
        pairs[faceIdx] = shares[faceIdx];
        vm.prank(HB_ALICE);
        (uint256 net,) = quad.joinProportionalFlexible(pairs, flags, HB_ALICE, 1, block.timestamp);
        assertGt(net, 0);
        assertEq(quad.seBalance(faceIdx), shares[faceIdx] - shares[faceIdx] / 20);
        for (uint256 i; i < 4; ++i) assertGt(quad.nativeReserve(i), 0);
    }

    function test_H646_basketMinimumRestoresCallerConversionState() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts = _hbFundPairs(HB_BOB, 10 ether);
        bytes memory before_ = _strictSnapshot(HB_BOB);
        uint256 rate = _hbRate();
        vm.expectRevert(_hbMinimumError());
        this.hbJoinPairs(HB_BOB, amounts, type(uint256).max);
        assertEq(_strictSnapshot(HB_BOB), before_);
        assertEq(_hbRate(), rate);
    }

    function test_H646_paidSingleMinimumRestoresConversionsAndSwapBooks() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        uint256[] memory shares = _hbFundShares(HB_BOB, 10 ether);
        address[3] memory inputs = [other, face, seUT];
        for (uint256 i; i < inputs.length; ++i) {
            bytes memory before_ = _strictSnapshot(HB_BOB);
            vm.prank(HB_BOB);
            vm.expectRevert(bytes4(keccak256("Slippage()")));
            quad.joinSingleAssetExactIn(
                inputs[i], i == 2 ? shares[0] : 1 ether, HB_BOB, type(uint256).max, block.timestamp
            );
            assertEq(_strictSnapshot(HB_BOB), before_, "paid swaps, conversions and approvals roll back together");
        }
    }

    function test_H643_paidSingleJoinDoesNotSpendAmbientComponents() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        uint256[] memory donated = _hbNativeAmounts(_hbFundShares(HB_ALICE, 3 ether));
        uint256 checkpoint = vm.snapshotState();
        vm.prank(HB_BOB);
        uint256 control = quad.joinSingleAssetExactIn(other, 1 ether, HB_BOB, 1, block.timestamp);
        ComponentSnapshot memory expected = _hbSnapshot(HB_BOB);
        uint256[4] memory expectedShares;
        uint256[] memory expectedNative = quad.nativeReserves();
        for (uint256 i; i < 4; ++i) expectedShares[i] = quad.seBalance(i);
        assertTrue(vm.revertToState(checkpoint));
        for (uint256 i; i < 4; ++i) {
            address input = rowSes[i] == address(0) ? rowTokens[i] : rowSes[i];
            vm.prank(HB_ALICE);
            IERC20(input).transfer(hook, donated[i]);
            SimpleMintableERC20(rowTokens[i]).mint(hook, 3 ether);
        }
        vm.prank(HB_BOB);
        uint256 actual = quad.joinSingleAssetExactIn(other, 1 ether, HB_BOB, 1, block.timestamp);
        ComponentSnapshot memory observed = _hbSnapshot(HB_BOB);
        assertEq(actual, control);
        assertEq(observed.supply, expected.supply);
        assertEq(observed.userPairs, expected.userPairs);
        assertEq(observed.userShares, expected.userShares);
        assertEq(quad.nativeReserves(), expectedNative);
        for (uint256 i; i < 4; ++i) {
            assertEq(quad.seBalance(i), expectedShares[i], "paid sale sees booked shares only");
            uint256 nativeIndex = _hbNativeIndex(i);
            uint256 pairDonation = 3 ether + (rowSes[nativeIndex] == address(0) ? donated[nativeIndex] : 0);
            assertEq(observed.pairs[i] - expected.pairs[i], pairDonation);
            assertEq(observed.shares[i] - expected.shares[i],
                rowSes[nativeIndex] == address(0) ? 0 : donated[nativeIndex]);
        }
    }

    function test_H648_disabledPairGenesisRestoresAllAcquisitions() public {
        _hbSetFee(HB_FEE);
        uint256[] memory amounts = _hbFundPairs(HB_ALICE, 100 ether);
        _hbDisable(true, true);
        bytes memory before_ = _strictSnapshot(HB_ALICE);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, seUT));
        this.hbJoinPairs(HB_ALICE, amounts, 1);
        assertEq(_strictSnapshot(HB_ALICE), before_);
    }

    function test_H644_exactTokenExitPaysExactAmountWithoutWithdrawalFee() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256 quoted = quad.previewExitSingleAssetExactTokenOut(other, 1 ether);
        assertGt(quoted, 0);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        vm.prank(HB_ALICE);
        uint256 burned = quad.exitSingleAssetExactTokenOut(other, 1 ether, HB_ALICE, quoted, block.timestamp);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_ALICE);
        assertEq(burned, quoted);
        assertEq(after_.userPairs[1] - before_.userPairs[1], 1 ether);
        assertEq(after_.supply, before_.supply - burned);
        assertEq(after_.feeLp, before_.feeLp);
    }

    function test_H641_partialRefundIsCreditedOnceToPoolInput() public {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        (uint256 minted, uint256 refund) = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), 10 ether, IERC20(seUT));
        assertGt(minted, 0);
        assertGt(refund, 0);
        assertLt(refund, 10 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        uint256 output = _hbTrade(HB_BOB, 0, 1, 10 ether);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertGt(output, 0);
        assertEq(after_.shares[0], before_.shares[0] + minted);
        assertEq(after_.pairs[0], before_.pairs[0] + refund);
        assertEq(before_.userPairs[0] - after_.userPairs[0], 10 ether);
        assertEq(after_.supply, before_.supply, "conversion-only swap mints no hook LP");
    }

    function test_H641_allRefundJoinRollsBackWithoutFreeShares() public {
        _hbBootstrap();
        uint256[] memory amounts = _hbFundPairs(HB_BOB, 10 ether);
        (uint256 minted, uint256 refund) = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), 1, IERC20(seUT));
        assertEq(minted, 0);
        assertEq(refund, 1);
        amounts[0] = 1;
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.expectRevert(bytes4(keccak256("ZeroAmount()")));
        this.hbJoinPairs(HB_BOB, amounts, 0);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(before_));
    }

    /// @dev A controlled external raw-token provider makes a one-wei all-refund input quote
    /// positive output; the hook and both SEs remain real registry-deployed production instances.
    function test_H641_allRefundSwapBooksWholeInputLocally() public {
        RateProviderMock rawProvider = new RateProviderMock();
        rawProvider.mockRate(1e6);
        rowProviders[otherIdx] = address(rawProvider);
        _deployHookWithArgs(_pkgArgs(rowTokens, rowSes, rowProviders, DEFAULT_BASE_AMP));
        uint256[] memory amounts = _hbFundShares(HB_ALICE, 100 ether);
        amounts[1] = 1e18 ether;
        SimpleMintableERC20(other).mint(HB_ALICE, amounts[1]);
        _hbJoinShares(HB_ALICE, amounts, 1);
        _hbFundPairs(HB_BOB, 1 ether);
        (uint256 minted, uint256 refund) = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(face), 1, IERC20(seUT));
        assertEq(minted, 0);
        assertEq(refund, 1);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        uint256 output = _hbTrade(HB_BOB, 0, 1, 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertGt(output, 0);
        assertEq(after_.pairs[0], before_.pairs[0] + 1);
        assertEq(after_.shares[0], before_.shares[0]);
        assertEq(after_.shareSupply[0], before_.shareSupply[0]);
        assertEq(before_.userPairs[0] - after_.userPairs[0], 1);
        assertEq(after_.userPairs[1] - before_.userPairs[1], output);
    }

    /// @dev Include books as well as custody, incumbent LP, underlying custody and Permit2 state.
    function _strictSnapshot(address actor) private view returns (bytes memory) {
        uint256[4] memory shares;
        uint256[4] memory nativeBook;
        uint256[4] memory seAllowances;
        uint256[4] memory redeemAllowances;
        int256[4] memory deltas;
        bytes memory permits;
        for (uint256 i; i < 4; ++i) {
            shares[i] = quad.seBalance(i);
            nativeBook[i] = quad.nativeReserve(i);
            if (rowSes[i] != address(0)) {
                seAllowances[i] = IERC20(rowTokens[i]).allowance(hook, rowSes[i]);
                redeemAllowances[i] = IERC20(rowSes[i]).allowance(hook, rowSes[i]);
            }
            deltas[i] = TransientStateLibrary.currencyDelta(pm, hook, Currency.wrap(rowTokens[i]));
            (uint160 amount, uint48 expiration, uint48 nonce) =
                IAllowanceTransfer(PERMIT2_ADDR).allowance(actor, rowTokens[i], hook);
            permits = abi.encode(permits, amount, expiration, nonce);
            if (rowSes[i] != address(0)) {
                (amount, expiration, nonce) = IAllowanceTransfer(PERMIT2_ADDR).allowance(actor, rowSes[i], hook);
                permits = abi.encode(permits, amount, expiration, nonce);
            }
        }
        return abi.encode(
            _hbSnapshot(actor), shares, nativeBook, seAllowances, redeemAllowances, permits, deltas, _hbRate(),
            TransientStateLibrary.isUnlocked(pm), TransientStateLibrary.getNonzeroDeltaCount(pm),
            TransientStateLibrary.getSyncedCurrency(pm), TransientStateLibrary.getSyncedReserves(pm),
            IERC20(hook).balanceOf(HB_ALICE),
            IERC20(fullSpread.faceToken()).balanceOf(seUT),
            IERC20(fullSpread.otherToken()).balanceOf(seUT),
            IERC20(fullSpread.faceToken()).balanceOf(address(pm)),
            IERC20(fullSpread.otherToken()).balanceOf(address(pm))
        );
    }

    function test_H648_disabledGenesisUsesOnlyPermittedRedemptions() public {
        _hbSetFee(HB_FEE);
        uint256[] memory amounts = _hbFundShares(HB_ALICE, 100 ether);
        _hbDisable(true, true);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        uint256 net = _hbJoinShares(HB_ALICE, amounts, 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_ALICE);
        _hbAssertFee(before_, after_, net);
        for (uint256 i; i < amounts.length; ++i) {
            if (_hbExchanges()[i] == address(0)) continue;
            assertEq(before_.shareSupply[i] - after_.shareSupply[i], amounts[i] / 20);
            assertGt(after_.pairs[i] - before_.pairs[i], 0);
        }
    }

    function test_H648_dustGenesisRollsBackEveryComponent() public {
        uint256[] memory amounts = _hbFundShares(HB_ALICE, 100 ether);
        amounts[0] = 19;
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        vm.expectRevert(bytes4(keccak256("ZeroLiquidityAmount()")));
        this.hbJoinShares(HB_ALICE, amounts, 0);
        assertEq(abi.encode(_hbSnapshot(HB_ALICE)), abi.encode(before_));
    }

    function test_H645_disabledPairJoinDoesNotBorrowShares() public {
        _hbBootstrap();
        uint256[] memory amounts = _hbFundPairs(HB_BOB, 10 ether);
        _hbDisable(true, true);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, seUT));
        this.hbJoinPairs(HB_BOB, amounts, 1);
        assertEq(abi.encode(_hbSnapshot(HB_BOB)), abi.encode(before_));
    }

    function test_H645_disabledRequestedSharesRollBack_pairExitRemainsLive() public {
        _hbBootstrap();
        _hbDisable(false, true);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        bool[] memory flags = new bool[](4);
        flags[faceIdx] = true;
        uint256[] memory minima = new uint256[](4);
        vm.prank(HB_ALICE);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, seUT));
        quad.exitProportionalFlexible(before_.userLp / 4, HB_ALICE, flags, minima, block.timestamp);
        assertEq(abi.encode(_hbSnapshot(HB_ALICE)), abi.encode(before_));
        _hbExitPairs(HB_ALICE, before_.userLp / 4);
        assertLt(IERC20(hook).balanceOf(HB_ALICE), before_.userLp);
    }

    function test_H642_exactLocalEqualityNeedsNoSeExactOutput() public {
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        uint256 local = before_.pairs[0];
        uint256 input = IStandardExchangeOut(hook).previewExchangeOut(IERC20(other), IERC20(face), local);
        assertGt(input, 0);
        vm.prank(HB_BOB);
        uint256 paid = IStandardExchangeOut(hook).exchangeOut(
            IERC20(other), input, IERC20(face), local, HB_BOB, false, block.timestamp
        );
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertEq(paid, input);
        assertEq(after_.pairs[0], 0);
        assertEq(after_.shares[0], before_.shares[0]);
        assertEq(after_.shareSupply[0], before_.shareSupply[0]);
        assertEq(after_.userPairs[0] - before_.userPairs[0], local);
    }

    function test_H643_zeroLocalAfterSwapStillAcceptsBackedPairJoin() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        _hbFundPairs(HB_BOB, 100 ether);
        uint256 local = IERC20(face).balanceOf(hook);
        _hbTrade(HB_BOB, 1, 0, local * 4);
        assertEq(IERC20(face).balanceOf(hook), 0);
        uint256[] memory amounts = _hbFundPairs(HB_BOB, 10 ether);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        uint256 net = _hbJoinPairs(HB_BOB, amounts, 1);
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        _hbAssertContributions(before_, after_);
        _hbAssertFee(before_, after_, net);
        assertEq(after_.pairs[0], 0, "zero local component requires no contribution");
    }

    function test_H647_zeroRecipientReceivesNoFeeOnGenesisOrLaterJoin() public {
        _hbSetFee(HB_FEE);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(address(0)));
        uint256 net = _hbBootstrap();
        assertEq(IERC20(hook).totalSupply(), net + 1000);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
        uint256[] memory amounts = _hbFundShares(HB_BOB, 10 ether);
        uint256 supply = IERC20(hook).totalSupply();
        net = _hbJoinShares(HB_BOB, amounts, 1);
        assertEq(IERC20(hook).totalSupply() - supply, net);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
    }

    function test_H647_zeroResolvedFeeLeavesAllBackedMintToCaller() public {
        _hbSetFee(0);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        assertEq(quad.usageFee(), 0);
        uint256 net = _hbBootstrap();
        assertEq(IERC20(hook).totalSupply(), net + 1000);
        assertEq(IERC20(hook).balanceOf(quad.feeTo()), 0);
    }

    function test_H647_subLegacyFeePrecisionStillSplitsGross() public {
        _hbSetFee(1);
        uint256 net = _hbBootstrap();
        uint256 gross = IERC20(hook).totalSupply() - 1000;
        uint256 fee = IERC20(hook).balanceOf(quad.feeTo());
        assertEq(fee, gross / 1e18, "use WAD percentage without legacy fee-scale truncation");
        assertEq(net + fee, gross);
    }

    function test_H647_protocolLpWithdrawsOrdinaryComponentFraction() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        address recipient = quad.feeTo();
        ComponentSnapshot memory before_ = _hbSnapshot(recipient);
        uint256 burn = before_.userLp / 2;
        assertGt(burn, 0);
        _hbExitPairs(recipient, burn);
        ComponentSnapshot memory after_ = _hbSnapshot(recipient);
        assertEq(after_.supply, before_.supply - burn);
        assertEq(after_.feeLp, before_.feeLp - burn);
        for (uint256 i; i < before_.pairs.length; ++i) {
            assertEq(after_.pairs[i], before_.pairs[i] - burn * before_.pairs[i] / before_.supply);
            assertEq(after_.shares[i], before_.shares[i] - burn * before_.shares[i] / before_.supply);
        }
    }

    function test_H643_permit2ShareSeedReachesActualPositiveJoin() public {
        _hbSetFee(HB_FEE);
        uint256[] memory amounts = _hbFundShares(HB_ALICE, 100 ether);
        address[] memory pairs = _hbPairs();
        address[] memory exchanges = _hbExchanges();
        for (uint256 i; i < pairs.length; ++i) {
            address input = exchanges[i] == address(0) ? pairs[i] : exchanges[i];
            vm.startPrank(HB_ALICE);
            IERC20(input).approve(hook, 0);
            IERC20(input).approve(PERMIT2_ADDR, type(uint256).max);
            IAllowanceTransfer(PERMIT2_ADDR).approve(input, hook, type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        uint256 net = _hbJoinShares(HB_ALICE, amounts, 1);
        assertGt(net, 0);
        _hbAssertFee(before_, _hbSnapshot(HB_ALICE), net);
    }

    function test_H644_standardExchangeAndSyWithdrawAllocatedBasket() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256 burn = IERC20(hook).balanceOf(HB_ALICE) / 10;
        uint256 quoted = quad.previewWithdrawSingle(other, burn);
        uint256 receivedBefore = IERC20(other).balanceOf(HB_ALICE);
        uint256 feeBefore = IERC20(hook).balanceOf(quad.feeTo());
        vm.prank(HB_ALICE);
        (uint256 actual, uint256 refunded) = IStandardExchangeIn(hook).exchangeIn(
            IERC20(hook), burn, IERC20(other), quoted, HB_ALICE, false, block.timestamp
        );
        assertGt(actual, 0);
        assertEq(actual, quoted);
        assertEq(refunded, 0);
        assertEq(IERC20(other).balanceOf(HB_ALICE) - receivedBefore, actual);
        assertEq(IERC20(hook).balanceOf(quad.feeTo()), feeBefore);
        quoted = IStandardizedYield(hook).previewRedeem(other, burn);
        receivedBefore = IERC20(other).balanceOf(HB_ALICE);
        vm.prank(HB_ALICE);
        actual = IStandardizedYield(hook).redeem(HB_ALICE, burn, other, quoted, false);
        assertGt(actual, 0);
        assertEq(actual, quoted);
        assertEq(IERC20(other).balanceOf(HB_ALICE) - receivedBefore, actual);
        assertEq(IERC20(hook).balanceOf(quad.feeTo()), feeBefore);
    }

    function test_H643_orderedFacadeAndFlexiblePreviewAgree() public {
        _hbSetFee(HB_FEE);
        _hbBootstrap();
        uint256[] memory amounts = _hbNativeAmounts(_hbFundPairs(HB_BOB, 10 ether));
        (uint256 quoted, uint256[] memory expectedUsed) = quad.previewJoinProportional(amounts);
        (uint256 flexible, uint256[] memory flexibleUsed) =
            quad.previewJoinProportionalFlexible(amounts, new bool[](4));
        assertEq(quoted, flexible);
        assertEq(expectedUsed, flexibleUsed);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.prank(HB_BOB);
        (uint256 net, uint256[] memory used) = IStandardExchangeMultiAssetLiquidity(hook).joinProportional(
            amounts, HB_BOB, quoted, block.timestamp
        );
        assertGt(net, 0);
        assertEq(net, quoted);
        assertEq(used, expectedUsed);
        _hbAssertContributions(before_, _hbSnapshot(HB_BOB));
        _hbAssertFee(before_, _hbSnapshot(HB_BOB), net);
    }

    function test_H643_addressListedShareBasketReachesPositiveJoin() public {
        _hbSetFee(HB_FEE);
        _ledgerInit(hook, _hbPairs(), _hbExchanges(), _hbFeeRecipient());
        _hbBootstrap();
        uint256[] memory amounts = _hbNativeAmounts(_hbFundShares(HB_BOB, 10 ether));
        address[] memory inputs = quad.tokens();
        for (uint256 i; i < 4; ++i) if (rowSes[i] != address(0)) inputs[i] = rowSes[i];
        uint256 quoted = quad.previewJoinUnbalanced(inputs, amounts);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_BOB);
        vm.recordLogs();
        vm.prank(HB_BOB);
        uint256 net = quad.joinUnbalanced(inputs, amounts, HB_BOB, quoted, block.timestamp);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        ComponentSnapshot memory after_ = _hbSnapshot(HB_BOB);
        assertGt(net, 0);
        assertEq(net, quoted);
        // Every leg is supplied, so no cross-leg trade is needed. Preserve both
        // pre-intake native ownership and the exact external conversion receipts.
        _hbAssertContributions(before_, after_);
        for (uint256 i_; i_ < before_.pairs.length; ++i_) {
            ConversionReceipt memory receipt_ = _ledgerReceipt(logs_, i_, HB_BOB, address(0));
            assertEq(after_.pairs[i_] + after_.userPairs[i_],
                before_.pairs[i_] + before_.userPairs[i_] + receipt_.pairIn - receipt_.pairOut);
            assertEq(after_.shares[i_] + after_.userShares[i_],
                before_.shares[i_] + before_.userShares[i_] + receipt_.sharesMinted - receipt_.sharesBurned);
        }
        _hbAssertFee(before_, after_, net);
    }

    function test_H646_deadlineRestoresFundedInputsAndAllowances() public {
        uint256[] memory amounts = _hbNativeAmounts(_hbFundShares(HB_ALICE, 100 ether));
        bool[] memory flags = new bool[](4);
        for (uint256 i; i < 4; ++i) flags[i] = rowSes[i] != address(0);
        ComponentSnapshot memory before_ = _hbSnapshot(HB_ALICE);
        vm.prank(HB_ALICE);
        vm.expectRevert(bytes4(keccak256("DeadlineExpired()")));
        quad.joinProportionalFlexible(amounts, flags, HB_ALICE, 1, block.timestamp - 1);
        assertEq(abi.encode(_hbSnapshot(HB_ALICE)), abi.encode(before_));
    }

    function test_H646_bookedLocalCannotFinancePretransfer() public {
        _hbBootstrap();
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 before_ = IERC20(other).balanceOf(address(caller));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, 0));
        caller.consumePretransfer(IERC20(face), address(this), hook, 0, abi.encodeCall(
            IStandardExchangeIn.exchangeIn, (IERC20(face), 1 ether, IERC20(other), 1, address(caller), true, block.timestamp)
        ));
        assertEq(IERC20(other).balanceOf(address(caller)), before_);
    }

    function test_H648_fourSeLegsSeedAndExitOnRealProxies() public {
        SeMatrix_FullSpreadV4Fixture[4] memory fixtures;
        address[4] memory pairs;
        address[4] memory exchanges;
        address[4] memory providers;
        for (uint256 i; i < 4; ++i) {
            fixtures[i] = new SeMatrix_FullSpreadV4Fixture(_ctx(), sharedPkg);
            pairs[i] = fixtures[i].faceToken();
            exchanges[i] = fixtures[i].se();
            providers[i] = fixtures[i].currency0Provider();
            fixtures[i].fund(user, 1000 ether);
        }
        for (uint256 i; i < 4; ++i) for (uint256 j = i + 1; j < 4; ++j) {
            if (pairs[j] < pairs[i]) {
                (pairs[i], pairs[j]) = (pairs[j], pairs[i]);
                (exchanges[i], exchanges[j]) = (exchanges[j], exchanges[i]);
                (providers[i], providers[j]) = (providers[j], providers[i]);
            }
        }
        _deployHookWithArgs(_pkgArgs(pairs, exchanges, providers, DEFAULT_BASE_AMP));
        _hbSetFee(HB_FEE);
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 100 ether;
        bool[] memory flags = _prepareShareSeed(amounts, user);
        uint256[4] memory supplies;
        for (uint256 i; i < 4; ++i) supplies[i] = IERC20(exchanges[i]).totalSupply();
        (uint256 expected,) = quad.previewJoinProportionalFlexible(amounts, flags);
        vm.prank(user);
        (uint256 net,) = quad.joinProportionalFlexible(amounts, flags, user, expected, block.timestamp);
        assertGt(net, 0);
        assertEq(net, expected);
        for (uint256 i; i < 4; ++i) {
            assertEq(quad.seBalance(i), amounts[i] - amounts[i] / 20);
            assertEq(supplies[i] - IERC20(exchanges[i]).totalSupply(), amounts[i] / 20);
            assertGt(IERC20(pairs[i]).balanceOf(hook), 0);
        }
        uint256[] memory predicted = quad.previewExitProportional(net / 3);
        vm.prank(user);
        uint256[] memory output = quad.exitProportional(net / 3, user, predicted, block.timestamp);
        assertEq(output, predicted);
    }

    function _hbHook() internal view override returns (address) { return hook; }

    function _hbPairs() internal view override returns (address[] memory pairs_) {
        pairs_ = new address[](4);
        for (uint256 i_; i_ < pairs_.length; ++i_) pairs_[i_] = rowTokens[_hbNativeIndex(i_)];
    }

    function _hbExchanges() internal view override returns (address[] memory exchanges_) {
        exchanges_ = new address[](4);
        for (uint256 i_; i_ < exchanges_.length; ++i_) exchanges_[i_] = rowSes[_hbNativeIndex(i_)];
    }

    /// @dev Reorder whole records for the behavior: primary buffered, counter, remaining legs.
    function _hbNativeIndex(uint256 index_) internal view returns (uint256) {
        if (index_ == 0) return faceIdx;
        if (index_ == 1) return otherIdx;
        uint256 canonical_ = 2;
        for (uint256 i_; i_ < 4; ++i_) {
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
        (net_,) = quad.joinProportionalFlexible(native_, flags_, actor_, minimum_, block.timestamp);
    }

    function _hbJoinPairs(address actor_, uint256[] memory amounts_, uint256 minimum_)
        internal override returns (uint256 net_)
    {
        uint256[] memory native_ = _hbNativeAmounts(amounts_);
        bool[] memory flags_ = new bool[](amounts_.length);
        vm.prank(actor_);
        (net_,) = quad.joinProportionalFlexible(native_, flags_, actor_, minimum_, block.timestamp);
    }

    function _hbExitPairs(address actor_, uint256 burned_) internal override {
        uint256[] memory minima_ = new uint256[](4);
        bool[] memory flags_ = new bool[](4);
        for (uint256 i_; i_ < minima_.length; ++i_) minima_[i_] = 1;
        vm.prank(actor_);
        quad.exitProportionalFlexible(burned_, actor_, flags_, minima_, block.timestamp);
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
        net_ = quad.previewJoinSingleAssetExactIn(other, maximum_);
    }

    function _hbExactNet(address actor_, uint256 net_, uint256 maximum_) internal override returns (uint256) {
        vm.prank(actor_);
        return IUniswapV4SeBufferHook(hook).joinSingleAssetExactOut(other, net_, actor_, maximum_, block.timestamp);
    }
}
