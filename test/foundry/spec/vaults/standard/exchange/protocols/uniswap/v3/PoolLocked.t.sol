// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IOperable} from "@crane/contracts/access/operable/IOperable.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {INonfungiblePositionManager} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {NonfungiblePositionManager} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/NonfungiblePositionManager.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as Family} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultPositionImport as Import} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol";
import {TestBase_UniswapV3FullSpreadMaintenance} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadMaintenance.sol";
import {UniswapV3PoolLockProbe} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/helpers/UniswapV3PoolLockProbe.sol";

/// @notice V3-ACC-15/16/17 and V3-OWN-01/02: exercise actual pool locking and execution precedence.
contract UniswapV3FullSpreadAccounting_PoolLocked_Test is TestBase_UniswapV3FullSpreadMaintenance {
    UniswapV3PoolLockProbe internal probe;
    INonfungiblePositionManager internal npm;
    uint256 internal sourceId;

    function setUp() public override {
        super.setUp();
        _seedVault(SEED);
        probe = new UniswapV3PoolLockProbe(pool, address(vault));
        _fundAccount(address(probe));
        vm.prank(alice);
        vault.transfer(address(probe), SEED / 2);
        _setFeeRecipient(address(probe));
    }

    function test_lockedPoolBlocksEveryExecutionThatNeedsPoolActions() public {
        _mintSourceNft();
        _poolFees(1e12, 1e12);
        uint128 liquidity_ = _positionLiquidity();
        uint256 supply_ = vault.totalSupply();
        uint256 shares_ = vault.balanceOf(address(probe));
        uint256 balance0_ = token0.balanceOf(address(vault));
        uint256 balance1_ = token1.balanceOf(address(vault));
        (bool[] memory success_, bytes[] memory result_) = probe.run(_executionCalls(block.timestamp));
        assertTrue(probe.observedLocked());
        bytes memory blocked_ = abi.encodeWithSelector(Common.UniswapV3Exchange_BoundPoolInteractionBlocked.selector);
        for (uint256 i_; i_ < success_.length; ++i_) {
            assertFalse(success_[i_], "execution must not settle locally while pool is locked");
            assertEq(result_[i_], blocked_);
        }
        assertEq(_positionLiquidity(), liquidity_);
        assertEq(vault.totalSupply(), supply_);
        assertEq(vault.balanceOf(address(probe)), shares_);
        assertEq(token0.balanceOf(address(vault)), balance0_);
        assertEq(token1.balanceOf(address(vault)), balance1_);
        assertEq(IERC721(address(npm)).ownerOf(sourceId), address(probe));
        _assertSettled();
    }

    function testFuzz_lockedPoolPreviewsIgnoreDisableIncludingImportAndExactOut(bool disabled_) public {
        _mintSourceNft();
        _setDisabled(disabled_);
        bytes[] memory calls_ = new bytes[](9);
        calls_[0] = abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (IERC20(address(token0)), 1e8, IERC20(address(vault))));
        calls_[1] = abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (IERC20(address(vault)), 1e6, IERC20(address(token0))));
        calls_[2] = abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (IERC20(address(token0)), 1e6, IERC20(address(token1))));
        calls_[3] = abi.encodeCall(IStandardExchangeBundleIn.previewExchangeBundleInForSingleOut, (_amountArray(1e8, 1e8), address(vault)));
        calls_[4] = abi.encodeCall(IStandardExchangeBundleOut.previewExchangeBundleOut, (address(vault), 1e6, _tokensOut()));
        calls_[5] = abi.encodeCall(IStandardExchangeOut.previewExchangeOut, (IERC20(address(token0)), IERC20(address(vault)), 1e8));
        calls_[6] = abi.encodeCall(Import.previewImportPosition, (npm, sourceId));
        calls_[7] = abi.encodeCall(IBasicVault.reserves, ());
        calls_[8] = abi.encodeWithSignature("canOpenBoundPoolOps()");
        (bool[] memory success_, bytes[] memory result_) = probe.run(calls_);
        assertTrue(probe.observedLocked());
        for (uint256 i_; i_ < calls_.length; ++i_) assertTrue(success_[i_], "view reverted during real pool lock");
        assertEq(result_[0].length, 64);
        assertEq(result_[1].length, 64);
        assertEq(result_[2].length, 64);
        assertEq(abi.decode(result_[5], (uint256)), 0);
        assertEq(result_[6].length, 96);
        assertFalse(abi.decode(result_[8], (bool)));
        assertEq(vault.totalSupply(), SEED);
    }

    function test_deadlinesPrecedeDisableForAllDeadlineRoutes() public {
        vm.warp(100);
        _setDisabled(true);
        bytes[] memory calls_ = _executionCalls(99);
        for (uint256 i_; i_ < calls_.length; ++i_) {
            if (i_ == 5 || i_ == 6) continue; // Maintenance has no deadline.
            vm.prank(address(probe));
            (bool success_, bytes memory reason_) = address(vault).call(calls_[i_]);
            assertFalse(success_);
            assertEq(reason_, abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, 99, 100));
        }
    }

    function test_disabledInboundAndPassThroughRevertBeforePoolAction() public {
        _setDisabled(true);
        bytes[] memory calls_ = _executionCalls(block.timestamp);
        for (uint256 i_; i_ < calls_.length; ++i_) {
            if (i_ == 2 || i_ == 4 || i_ == 5 || i_ == 6) continue;
            vm.prank(address(probe));
            (bool success_, bytes memory reason_) = address(vault).call(calls_[i_]);
            assertFalse(success_);
            assertEq(reason_, abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(vault)));
        }
    }

    function testFuzz_disabledWithdrawalsRemainAvailableWhenPoolIsIdle(bool bundle_) public {
        _setDisabled(true);
        uint256 shares_ = 1e6;
        uint256 supply_ = vault.totalSupply();
        uint256 before0_ = token0.balanceOf(recipient);
        uint256 before1_ = token1.balanceOf(recipient);
        if (bundle_) {
            (uint256[] memory expected_,) = IStandardExchangeBundleOut(address(vault)).previewExchangeBundleOut(address(vault), shares_, _tokensOut());
            uint256[] memory actual_ = _bundleOut(alice, shares_, recipient, false);
            assertEq(actual_, expected_);
            assertEq(token1.balanceOf(recipient), before1_ + expected_[1]);
            assertEq(token0.balanceOf(recipient), before0_ + expected_[0]);
        } else {
            (uint256 expected_,) = vault.previewExchangeIn(IERC20(address(vault)), shares_, IERC20(address(token0)));
            assertGt(expected_, 0);
            vm.prank(alice);
            (uint256 actual_,) = vault.exchangeIn(IERC20(address(vault)), shares_, IERC20(address(token0)), expected_, recipient, false, block.timestamp);
            assertEq(actual_, expected_);
            assertEq(token0.balanceOf(recipient), before0_ + expected_);
            assertEq(token1.balanceOf(recipient), before1_);
        }
        assertEq(vault.totalSupply(), supply_ - shares_);
        _assertSettled();
    }

    function test_disabledWithdrawalsStillRequireAnIdleBoundPool() public {
        _setDisabled(true);
        bytes[] memory all_ = _executionCalls(block.timestamp);
        bytes[] memory withdrawals_ = new bytes[](2);
        withdrawals_[0] = all_[2];
        withdrawals_[1] = all_[4];
        (bool[] memory success_, bytes[] memory result_) = probe.run(withdrawals_);
        for (uint256 i_; i_ < 2; ++i_) {
            assertFalse(success_[i_]);
            assertEq(result_[i_], abi.encodeWithSelector(Common.UniswapV3Exchange_BoundPoolInteractionBlocked.selector));
        }
    }

    function test_enabledAppointmentsAndEmptyCompoundIgnorePoolLock() public {
        bytes[] memory calls_ = new bytes[](3);
        calls_[0] = abi.encodeCall(Family.setOperator, (bob, true));
        calls_[1] = abi.encodeCall(Family.setOperatorFor, (Family.compound.selector, recipient, true));
        calls_[2] = abi.encodeCall(Family.compound, ());
        (bool[] memory success_, bytes[] memory result_) = probe.run(calls_);
        assertTrue(probe.observedLocked());
        for (uint256 i_; i_ < 3; ++i_) assertTrue(success_[i_]);
        assertTrue(abi.decode(result_[0], (bool)));
        assertTrue(abi.decode(result_[1], (bool)));
        vm.prank(bob);
        Family(address(vault)).compound();
        vm.prank(recipient);
        Family(address(vault)).compound();
        vm.expectRevert(abi.encodeWithSelector(IOperable.NotOperator.selector, recipient));
        _donate(recipient, address(token0), 1);
    }

    function test_lockedUnformableMaintenanceBooksWithoutOpeningPoolActions() public {
        bytes[] memory calls_ = new bytes[](2);
        calls_[0] = abi.encodeCall(Family.donate, (address(token0), 1, false));
        calls_[1] = abi.encodeCall(Family.compound, ());
        uint128 liquidity_ = _positionLiquidity();
        vm.recordLogs();
        (bool[] memory success_,) = probe.run(calls_);
        assertTrue(probe.observedLocked());
        assertTrue(success_[0]);
        assertTrue(success_[1]);
        _maintenanceEvents(vm.getRecordedLogs(), 1, 0);
        (uint256 booked0_, uint256 booked1_) = _booked();
        assertEq(booked0_, 1);
        assertEq(booked1_, 0);
        assertEq(_positionLiquidity(), liquidity_);
        _assertSettled();
    }

    function testFuzz_exactOutDeadlineThenDisableThenUnavailableEvenWhileLocked(bool disabled_, bool expired_) public {
        vm.warp(100);
        _setDisabled(disabled_);
        bytes[] memory calls_ = new bytes[](1);
        calls_[0] = abi.encodeCall(IStandardExchangeOut.exchangeOut, (
            IERC20(address(token0)), 1e8, IERC20(address(vault)), 1e6, recipient, false, expired_ ? 99 : 100
        ));
        uint256 supply_ = vault.totalSupply();
        uint256[4] memory balances_ = [
            token0.balanceOf(address(vault)), token1.balanceOf(address(vault)),
            token0.balanceOf(recipient), token1.balanceOf(recipient)
        ];
        (bool[] memory success_, bytes[] memory result_) = probe.run(calls_);
        bytes memory expected_ = expired_
            ? abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, 99, 100)
            : disabled_ ? abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(vault))
            : abi.encodeWithSelector(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        assertFalse(success_[0]);
        assertEq(result_[0], expected_);
        assertEq(vault.totalSupply(), supply_);
        assertEq(token0.balanceOf(address(vault)), balances_[0]);
        assertEq(token1.balanceOf(address(vault)), balances_[1]);
        assertEq(token0.balanceOf(recipient), balances_[2]);
        assertEq(token1.balanceOf(recipient), balances_[3]);
    }

    function _executionCalls(uint256 deadline_) private view returns (bytes[] memory calls_) {
        calls_ = new bytes[](8);
        calls_[0] = abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(address(token0)), 1e8, IERC20(address(vault)), 0, recipient, false, deadline_));
        calls_[1] = abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(address(token0)), 1e6, IERC20(address(token1)), 0, recipient, false, deadline_));
        calls_[2] = abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(address(vault)), 1e6, IERC20(address(token0)), 0, recipient, false, deadline_));
        calls_[3] = abi.encodeCall(IStandardExchangeBundleIn.exchangeBundleInForSingleOut, (_amountArray(1e8, 1e8), address(vault), 0, recipient, false, deadline_));
        calls_[4] = abi.encodeCall(IStandardExchangeBundleOut.exchangeBundleOut, (address(vault), 1e6, _tokensOut(), _amountArray(0, 0), recipient, false, deadline_));
        calls_[5] = abi.encodeCall(Family.donate, (address(token0), 1e8, false));
        calls_[6] = abi.encodeCall(Family.compound, ());
        calls_[7] = abi.encodeCall(Import.importPosition, (npm, sourceId, 0, address(probe), recipient, deadline_));
    }

    function _mintSourceNft() private {
        npm = INonfungiblePositionManager(address(new NonfungiblePositionManager(address(uniswapV3Factory), address(1), address(0))));
        token0.approve(address(npm), type(uint256).max);
        token1.approve(address(npm), type(uint256).max);
        (sourceId,,,) = npm.mint(INonfungiblePositionManager.MintParams({
            token0: address(token0), token1: address(token1), fee: FEE_MEDIUM,
            tickLower: lower, tickUpper: upper, amount0Desired: 1e8, amount1Desired: 1e8,
            amount0Min: 0, amount1Min: 0, recipient: address(probe), deadline: block.timestamp
        }));
        vm.prank(address(probe));
        IERC721(address(npm)).approve(address(vault), sourceId);
    }
}
