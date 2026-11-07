// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {CustomRevert} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/CustomRevert.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault as FullSpreadSingleRow} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault as FullSpreadDualRow, FullSpreadV4MatrixChecks} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault as FullSpreadOrbitalRow} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault as FullSpreadWeightedRow} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3 as FullSpreadWeightedThreeRow} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault as FullSpreadCurveRow} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault as FullSpreadBalancerRow} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5 as FullSpreadBalancerFiveRow} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol";

interface IFullSpreadHookTuple {
    function exchangeIn(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountRefunded);
}
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {SeMatrix_FullSpreadV4Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault
        as FullSpreadCpRow
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";

/// @notice H10 approval and payment evidence shared only by these integration specs.
abstract contract FullSpreadUnwrapChecks is Test {
    function _assertHookExit(address vault_, address hook_, address face_, address user_, bytes memory call_) internal {
        uint256 supply_ = IERC20(vault_).totalSupply();
        uint256 before_ = IERC20(face_).balanceOf(user_);
        vm.recordLogs();
        vm.prank(user_);
        (bool ok_, bytes memory reason_) = hook_.call(call_);
        if (!ok_) {
            assembly {
                revert(add(reason_, 32), mload(reason_))
            }
        }
        _assertUnwrapResult(vault_, hook_, face_, user_, supply_, before_);
    }

    function _assertUnwrapResult(
        address vault_, address hook_, address face_, address user_, uint256 supply_, uint256 before_
    ) internal {
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        bool approved_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            Vm.Log memory log_ = logs_[i_];
            if (log_.emitter == vault_ && log_.topics.length == 3
                && log_.topics[0] == keccak256("Approval(address,address,uint256)")
                && log_.topics[1] == bytes32(uint256(uint160(hook_)))
                && log_.topics[2] == bytes32(uint256(uint160(vault_)))
                && abi.decode(log_.data, (uint256)) != 0) approved_ = true;
        }
        assertTrue(approved_, "unwrap hook approves the vault for its shares");
        assertLt(IERC20(vault_).totalSupply(), supply_, "unwrap burns real vault shares");
        assertGt(IERC20(face_).balanceOf(user_), before_, "unwrap completes the face payment");
    }
}

/// @notice Composed hook controls for this vault. The matrix rows remain the topology proofs.
contract UniswapV4FullSpreadStandardExchangeVault_BufferHookIntegration_Test is FullSpreadCpRow, FullSpreadUnwrapChecks {
    /// forge-config: default.isolate = true
    function test_composedRouteGasFitsCeiling() public override {
        _seed();
        bool zeroForOne_ = face < raw;
        SwapParams memory params_ = SwapParams({
            zeroForOne: zeroForOne_,
            amountSpecified: -int256(_f(1)),
            sqrtPriceLimitX96: _sqrtLimit(zeroForOne_)
        });
        uint256 preview_ = single.previewSwapExactIn(face, raw, _f(1));
        uint256 previewGas_ = vm.lastFrameGas().gasTotalUsed;
        assertGt(preview_, 0, "measured preview is executable");
        assertLe(previewGas_, 5_000_000, "G04 cold preview ceiling");
        emit log_named_uint("G04.coldPreviewGas", previewGas_);
        uint256 transactionGas_ = FullSpreadV4MatrixChecks.coldSwap(swapRouter, poolKey, params_, user, seUT);
        assertLe(transactionGas_, 12_000_000, "G04 cold composed transaction including calldata");
        emit log_named_uint("G04.coldWholeTransactionGas", transactionGas_);
    }

    /// @notice H10: disabling the underlying vault does not block a real buffered withdrawal.
    function test_disabledBufferedWithdrawalApprovesAndCompletesExit() public {
        uint256 lp_ = _seed() / 10;
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(seUT, true);
        _assertHookExit(seUT, hook, face, user, abi.encodeWithSignature(
            "withdraw(uint256,address,uint256,uint256,uint256)", lp_, user, 0, 0, block.timestamp
        ));
    }

    /// @notice FS-A38/42: disabled buffering keeps paid input locally without a prohibited SE mint.
    function test_disabledBufferedInputBooksLocallyWithoutVaultMint() public {
        _seed();
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(seUT, true);
        uint256 shares_ = IERC20(seUT).totalSupply();
        uint256 faceBefore_ = IERC20(face).balanceOf(user);
        uint256 rawBefore_ = IERC20(raw).balanceOf(user);
        uint256 vaultFace_ = IERC20(face).balanceOf(seUT);
        uint256 hookFace_ = IERC20(face).balanceOf(hook);
        uint256 hookShares_ = IERC20(seUT).balanceOf(hook);
        uint256 reserve_ = face < raw ? single.reserveCurrency0() : single.reserveCurrency1();
        uint256 expected_ = single.previewSwapExactIn(face, raw, _f(1));
        assertGt(expected_, 0);
        vm.expectCall(seUT, abi.encodeWithSelector(IFullSpreadHookTuple.exchangeIn.selector, face), uint64(0));
        _swapExactIn(face, raw, _f(1));
        assertEq(IERC20(seUT).totalSupply(), shares_);
        assertEq(faceBefore_ - IERC20(face).balanceOf(user), _f(1));
        assertEq(IERC20(raw).balanceOf(user) - rawBefore_, expected_);
        assertEq(IERC20(face).balanceOf(hook), hookFace_ + _f(1), "accepted input remains local");
        assertEq(IERC20(seUT).balanceOf(hook), hookShares_, "no disabled SE deposit");
        assertEq(face < raw ? single.reserveCurrency0() : single.reserveCurrency1(), reserve_ + _f(1));
        assertEq(IERC20(face).balanceOf(seUT), vaultFace_);
    }

    /// @notice H10: a staged vault transfer is neither a hook payer's credit nor its refund.
    function test_stagedVaultPretransferDoesNotIncreaseLaterHookOutput() public {
        _seed();
        uint256 staged_ = _f(100);
        fx.fund(rowEoa, staged_);
        uint256 snapshot_ = vm.snapshotState();
        uint256 before_ = IERC20(raw).balanceOf(user);
        _swapExactIn(face, raw, _f(1));
        uint256 control_ = IERC20(raw).balanceOf(user) - before_;
        uint256 controlVaultAfter_ = IERC20(face).balanceOf(seUT);
        assertTrue(vm.revertToState(snapshot_));
        vm.prank(rowEoa);
        IERC20(face).transfer(seUT, staged_);
        uint256 payerBefore_ = IERC20(face).balanceOf(user);
        before_ = IERC20(raw).balanceOf(user);
        _swapExactIn(face, raw, _f(1));
        assertEq(IERC20(raw).balanceOf(user) - before_, control_, "staged input buys no later output");
        assertEq(payerBefore_ - IERC20(face).balanceOf(user), _f(1), "later payer funds its own input");
        assertEq(
            IERC20(face).balanceOf(seUT), controlVaultAfter_ + staged_,
            "staged inventory remains beside the same newly booked fees"
        );
    }

    function test_getRateAbsentAndProviderReadsTuple() public {
        (bool ok_,) = seUT.staticcall(abi.encodeWithSignature("getRate()"));
        assertFalse(ok_, "getRate is absent");
        address provider_ = SeMatrix_FullSpreadV4Fixture(address(fx)).currency0Provider();
        assertGt(IRateProvider(provider_).getRate(), 0, "external provider reads the tuple");
    }

    function test_stagedPretransferIsNotCreditedToLaterCaller() public {
        _seed();
        uint256 amt_ = _f(1);
        fx.fund(rowEoa, amt_);
        vm.prank(rowEoa);
        IERC20(face).transfer(hook, amt_);
        uint256 resting_ = IERC20(face).balanceOf(hook);
        uint256 bobBefore_ = IERC20(raw).balanceOf(rowBob);
        fx.fund(rowBob, amt_);
        vm.startPrank(rowBob);
        IERC20(face).approve(address(swapRouter), amt_);
        vm.stopPrank();
        bool zeroForOne_ = face < raw;
        vm.prank(rowBob);
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({
                zeroForOne: zeroForOne_,
                amountSpecified: -int256(amt_),
                sqrtPriceLimitX96: _sqrtLimit(zeroForOne_)
            }),
            ""
        );
        assertGt(IERC20(raw).balanceOf(rowBob), bobBefore_, "later caller is paid for its own input");
        assertGe(IERC20(face).balanceOf(hook), resting_, "staged pretransfer is not consumed by the later caller");
        assertEq(IERC20(face).balanceOf(rowBob), 0, "later caller is not refunded the staged pretransfer");
    }

    function test_exactOutHookPaysNeitherToken() public {
        _seed();
        uint256 faceBefore_ = IERC20(face).balanceOf(user);
        uint256 rawBefore_ = IERC20(raw).balanceOf(user);
        uint256 local_ = IERC20(face).balanceOf(hook);
        uint256 hookRaw_ = IERC20(raw).balanceOf(hook);
        uint256 hookShares_ = IERC20(seUT).balanceOf(hook);
        uint256 supply_ = IERC20(seUT).totalSupply();
        uint256 lpSupply_ = IERC20(hook).totalSupply();
        uint256 reserve0_ = single.reserveCurrency0();
        uint256 reserve1_ = single.reserveCurrency1();
        // Seed custody contains no ambient transfers: request strictly more than all local face.
        uint256 requested_ = local_ + _f(1);
        bool zeroForOne_ = raw < face;
        vm.expectCall(seUT, abi.encodeWithSelector(
            IStandardExchangeOut.previewExchangeOut.selector, IERC20(seUT), IERC20(face), _f(1)
        ), uint64(1));
        vm.expectRevert(abi.encodeWithSelector(
            CustomRevert.WrappedError.selector, hook, IHooks.beforeSwap.selector,
            abi.encodeWithSelector(IStandardExchangeOut.ExchangeOutNotAvailable.selector),
            abi.encodePacked(Hooks.HookCallFailed.selector)
        ));
        vm.prank(user);
        swapRouter.swapExactOut(
            poolKey,
            SwapParams({
                zeroForOne: zeroForOne_,
                amountSpecified: int256(requested_),
                sqrtPriceLimitX96: _sqrtLimit(zeroForOne_)
            }),
            rawBefore_,
            ""
        );
        assertEq(IERC20(face).balanceOf(user), faceBefore_, "exact-out pays no face");
        assertEq(IERC20(raw).balanceOf(user), rawBefore_, "exact-out pays no raw");
        assertEq(IERC20(face).balanceOf(hook), local_);
        assertEq(IERC20(raw).balanceOf(hook), hookRaw_);
        assertEq(IERC20(seUT).balanceOf(hook), hookShares_);
        assertEq(IERC20(seUT).totalSupply(), supply_);
        assertEq(IERC20(hook).totalSupply(), lpSupply_);
        assertEq(single.reserveCurrency0(), reserve0_);
        assertEq(single.reserveCurrency1(), reserve1_);
    }

    function test_identityAttemptDoesNotBurnCallerPosition() public {
        _seed();
        uint256 amount_ = _f(1);
        fx.fund(user, amount_);
        vm.startPrank(user);
        IERC20(face).approve(seUT, amount_);
        (uint256 minted_,) = IFullSpreadHookTuple(seUT).exchangeIn(
            face, amount_, seUT, 0, user, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(minted_, 0, "caller has a position to protect");
        uint256 shares_ = IERC20(seUT).balanceOf(user);
        uint256 faceBefore_ = IERC20(face).balanceOf(user);
        vm.prank(user);
        vm.expectRevert();
        IFullSpreadHookTuple(seUT).exchangeIn(seUT, shares_, seUT, 0, user, false, block.timestamp);
        assertEq(IERC20(seUT).balanceOf(user), shares_, "identity attempt burns no position");
        assertEq(IERC20(face).balanceOf(user), faceBefore_, "identity attempt pays nothing");
        (bool ok_,) = seUT.staticcall(abi.encodeWithSignature("asset()"));
        assertFalse(ok_, "asset is absent");
    }
}

/// @notice H10: single hook unwrap, including the disabled withdrawal exception.
contract UniswapV4FullSpreadStandardExchangeVault_SingleUnwrap_Test is FullSpreadSingleRow, FullSpreadUnwrapChecks {
    function test_singleUnwrapApprovesAndCompletesExit() public {
        uint256 supply_ = IERC20(seUT).totalSupply();
        uint256 before_ = IERC20(face).balanceOf(user);
        vm.recordLogs();
        _unwrapExactIn(_seOf(user) / 10);
        _assertUnwrapResult(seUT, hook, face, user, supply_, before_);
    }
}

/// @notice H10: two valid FullSpread bindings complete a real dual-hook unwrap.
contract UniswapV4FullSpreadStandardExchangeVault_DualUnwrap_Test is FullSpreadDualRow, FullSpreadUnwrapChecks {
    function test_dualUnwrapApprovesAndCompletesExit() public {
        assertTrue(identityAccepted, "FS-HOOK-04: required PairToken identity rejected");
        uint256 lp_ = _seed() / 10;
        _assertHookExit(seUT, hook, face, user, abi.encodeWithSignature(
            "withdraw(uint256,address,uint256,uint256,uint256)", lp_, user, 0, 0, block.timestamp
        ));
    }
}

/// @notice H10: orbital unwrap on the converting face; sibling identity is not a cross-vault pass.
contract UniswapV4FullSpreadStandardExchangeVault_OrbitalUnwrap_Test is FullSpreadOrbitalRow, FullSpreadUnwrapChecks {
    function test_orbitalUnwrapApprovesAndCompletesExit() public {
        _seedMixed();
        uint256 lp_ = IERC20(hook).balanceOf(user) / 10;
        _assertHookExit(seUT0, hook, face0, user, abi.encodeWithSignature(
            "withdrawFlexible(uint256,address,bool,bool,bool,uint256,uint256,uint256,uint256)",
            lp_, user, false, false, false, 0, 0, 0, block.timestamp
        ));
    }
}

contract UniswapV4FullSpreadStandardExchangeVault_WeightedUnwrap_Test is FullSpreadWeightedRow, FullSpreadUnwrapChecks {
    function test_weightedUnwrapApprovesAndCompletesExit() public {
        uint256 lp_ = _seedWeighted() / 10;
        _assertHookExit(seUT, hook, face, user, abi.encodeWithSignature(
            "exitProportional(uint256,address,uint256[],uint256)", lp_, user, new uint256[](2), block.timestamp
        ));
    }
}

contract UniswapV4FullSpreadStandardExchangeVault_WeightedThreeUnwrap_Test is FullSpreadWeightedThreeRow, FullSpreadUnwrapChecks {
    function test_weightedThreeUnwrapApprovesAndCompletesExit() public {
        uint256 lp_ = _seedThree() / 10;
        _assertHookExit(seUT, hook, face, user, abi.encodeWithSignature(
            "exitProportional(uint256,address,uint256[],uint256)", lp_, user, new uint256[](3), block.timestamp
        ));
    }
}

contract UniswapV4FullSpreadStandardExchangeVault_CurveUnwrap_Test is FullSpreadCurveRow, FullSpreadUnwrapChecks {
    function test_curveUnwrapApprovesAndCompletesExit() public {
        uint256 lp_ = _seedCurve() / 10;
        _assertHookExit(seUT, hook, face, user, abi.encodeWithSignature(
            "exitProportionalFlexible(uint256,address,bool[],uint256[],uint256)",
            lp_, user, new bool[](4), new uint256[](4), block.timestamp
        ));
    }
}

contract UniswapV4FullSpreadStandardExchangeVault_BalancerUnwrap_Test is FullSpreadBalancerRow, FullSpreadUnwrapChecks {
    function test_balancerUnwrapApprovesAndCompletesExit() public {
        uint256 lp_ = _seedBalancer() / 10;
        _assertHookExit(seUT, hook, face, user, abi.encodeWithSignature(
            "exitProportional(uint256,address,uint256[],uint256)", lp_, user, new uint256[](2), block.timestamp
        ));
    }
}

contract UniswapV4FullSpreadStandardExchangeVault_BalancerFiveUnwrap_Test is FullSpreadBalancerFiveRow, FullSpreadUnwrapChecks {
    function test_balancerFiveUnwrapApprovesAndCompletesExit() public {
        uint256 lp_ = _seedBalancer() / 10;
        _assertHookExit(seUT, hook, face, user, abi.encodeWithSignature(
            "exitProportional(uint256,address,uint256[],uint256)", lp_, user, new uint256[](5), block.timestamp
        ));
    }
}
