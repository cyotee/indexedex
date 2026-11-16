// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/**
 * @title Backed mint fee and yield matrix.
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Fees_Test is TestBase {
    function test_F3_feeOff_kLastZero() public {
        IVaultFeeOracleManager manager_ = IVaultFeeOracleManager(address(indexedexManager));
        bytes4[] memory types_ = IVaultFeeOracleQuery(address(indexedexManager)).dexSwapFeeVaultTypeIds();
        vm.startPrank(owner);
        manager_.setDefaultDexSwapFee(0);
        manager_.setVaultDexSwapFee(hook, 0);
        for (uint256 i_; i_ < types_.length; ++i_) manager_.setDefaultDexSwapFeeOfTypeId(types_[i_], 0);
        vm.stopPrank();
        _seedLiveLiquidity();
        (address feeTo_, uint256 wad_) = single.dexSwapFeeAndFeeTo();
        assertEq(wad_, 0, "all fallback tiers inactive");
        assertEq(IERC20(hook).balanceOf(feeTo_), 0, "inactive fee issues no treasury LP");
        assertEq(IERC20(hook).totalSupply(), IERC20(hook).balanceOf(user) + 1000, "floor allocated once");
        assertEq(single.kLast(), 0, "no growth checkpoint");
    }

    function test_F2_protocolFee_mintsToFeeTo_onBackedMintAfterYield() public {
        _enableProtocolFee(0.05e18);
        _seedLiveLiquidity();
        assertEq(single.kLast(), 0, "retired growth checkpoint");
        uint256 supplyBefore_ = IERC20(hook).totalSupply();

        // Yield grows SE claim (virtual pair) without user capital
        pairToken.mint(address(this), 20 ether);
        pairToken.approve(address(pairProtocolVault), 20 ether);
        pairProtocolVault.simulateYield(20 ether);

        address feeTo_ = _feeTo();
        uint256 feeLpBefore = IERC20(hook).balanceOf(feeTo_);
        assertEq(IERC20(hook).totalSupply(), supplyBefore_, "yield alone mints nothing");
        uint256 net_ = _depositBoth(10 ether, 10 ether);
        uint256 gross_ = IERC20(hook).totalSupply() - supplyBefore_;
        assertEq(IERC20(hook).balanceOf(feeTo_) - feeLpBefore, gross_ * 0.05e18 / 1e18, "backed gross fee");
        assertEq(net_, gross_ - gross_ * 0.05e18 / 1e18, "net fee split");
        uint256 feeAfter_ = IERC20(hook).balanceOf(feeTo_);
        uint256 supplyAfter_ = IERC20(hook).totalSupply();
        vm.prank(user);
        single.withdraw(net_, user, 0, 0, block.timestamp);
        assertEq(IERC20(hook).totalSupply(), supplyAfter_ - net_, "withdrawal only burns");
        assertEq(IERC20(hook).balanceOf(feeTo_), feeAfter_, "withdrawal has no fee");
        assertEq(single.kLast(), 0);
    }

    function test_F2_zeroRecipient_backedGrossGoesToDepositor() public {
        _enableProtocolFee(0.05e18);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(address(0)));
        uint256 net_ = _seedLiveLiquidity();
        assertEq(_feeTo(), address(0));
        assertEq(IERC20(hook).balanceOf(address(0)), 1000, "only genesis floor");
        assertEq(IERC20(hook).totalSupply(), net_ + 1000, "zero recipient disables fee");
    }

    function test_Y1_yieldMovesVirtualPairWithoutSwap() public {
        _seedLiveLiquidity();
        uint256 claimBefore = single.seClaimSupply();
        pairToken.mint(address(this), 15 ether);
        pairToken.approve(address(pairProtocolVault), 15 ether);
        pairProtocolVault.simulateYield(15 ether);
        // SE claim rate rose; hook still holds same SE shares → claim supply up
        // Need to re-read seClaim via preview — balance of SE shares unchanged
        uint256 seBal = IERC20(se).balanceOf(hook);
        assertGt(seBal, 0);
        uint256 claimAfter = single.seClaimSupply();
        assertGt(claimAfter, claimBefore);
    }

    function test_F5_feeOn_depositPreviewEqualsExec() public {
        _enableProtocolFee(0.03e18);
        _seedLiveLiquidity();
        uint256 a0 = _amountForCurrency(single.currency0(), 20 ether, 20 ether);
        uint256 a1 = _amountForCurrency(single.currency1(), 20 ether, 20 ether);
        (uint256 predLp, uint256 predU0, uint256 predU1) = single.previewDeposit(a0, a1);
        vm.prank(user);
        (uint256 lp, uint256 u0, uint256 u1) = single.deposit(a0, a1, user, 0, block.timestamp + 1);
        assertEq(lp, predLp);
        assertEq(u0, predU0);
        assertEq(u1, predU1);
    }
}
