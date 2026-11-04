// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeMultiAssetLiquidity as ILiq} from
    "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_UniswapV4DualSEBCPHook as TB_Dual} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";

/// @notice p4-hooks decomposition of the INV-5 break on the DUAL hook: which step leaks passive-LP value,
///         and is it the SE dilution (usage) fee that the hook pays when it re-buffers internally?
contract P4DualFeeLeak is TB_Dual {
    address internal constant LP = address(0x1111);
    address internal constant ACT = address(0xA77);

    function setUp() public override {
        super.setUp();
        _initPool();
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(hook, 3e15);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook, 1); // hook protocol fee off
        vm.stopPrank();
        _fundApprove(LP, 100_000e18);
        uint256[] memory a = new uint256[](2);
        a[0] = 100_000e18;
        a[1] = 100_000e18;
        vm.prank(LP);
        ILiq(hook).joinProportional(a, LP, 0, block.timestamp + 1 hours);
    }

    function _fundApprove(address who, uint256 amt) internal {
        tokenA.mint(who, amt);
        tokenB.mint(who, amt);
        vm.startPrank(who);
        tokenA.approve(hook, type(uint256).max);
        tokenB.approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function _seVal(address se, address tok, address who) internal view returns (uint256) {
        uint256 sh = IERC20(se).balanceOf(who);
        if (sh == 0) return 0;(uint256 quotedAmountOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), sh, IERC20(tok));
        return quotedAmountOut;
    }

    function _feeSink() internal view returns (uint256) {
        address ft = address(feeCollector);
        return _seVal(seA, address(tokenA), ft) + _seVal(seB, address(tokenB), ft);
    }

    function _lpPerShare() internal view returns (uint256) {
        uint256[] memory o = ILiq(hook).previewExitProportional(1e21);
        return (o[0] + o[1]) * 1e18 / 1e21;
    }

    function _actVal() internal view returns (uint256) {
        return tokenA.balanceOf(ACT) + tokenB.balanceOf(ACT);
    }

    struct S {
        uint256 ps;
        uint256 sink;
        uint256 act;
    }

    function _snap() internal view returns (S memory s) {
        s.ps = _lpPerShare();
        s.sink = _feeSink();
        s.act = _actVal();
    }

    function _log(string memory tag, S memory a, S memory b, uint256 minted) internal pure {
        console2.log(tag);
        console2.log("   passive LP per-share delta (wei per 1e18 LP)");
        console2.logInt(int256(b.ps) - int256(a.ps));
        console2.log("   SE fee sink gain", b.sink - a.sink);
        console2.log("   actor P&L");
        console2.logInt(int256(b.act) - int256(a.act) - int256(minted));
    }

    /// returns (passive per-share delta over the zap-join + single-exit cycle, SE fee sink gain over the same cycle)
    function _scenario() internal returns (int256 cycDps, uint256 cycSink) {
        uint256 X = 20_000e18;
        S memory s0 = _snap();
        tokenA.mint(ACT, X);
        vm.startPrank(ACT);
        tokenA.approve(hook, type(uint256).max);
        tokenB.approve(hook, type(uint256).max);(uint256 lp,) = IStandardExchangeIn(hook).exchangeIn(IERC20(address(tokenA)), X, IERC20(hook), 0, ACT, false, block.timestamp + 1 hours);
        vm.stopPrank();
        S memory s1 = _snap();
        _log("step1 zap-join tokenA (exchangeIn A->LP)", s0, s1, X);
        vm.prank(ACT);IStandardExchangeIn(hook).exchangeIn(IERC20(hook), lp, IERC20(address(tokenA)), 0, ACT, false, block.timestamp + 1 hours);
        S memory s2 = _snap();
        _log("step2 single exit LP->tokenA", s1, s2, 0);
        cycDps = int256(s2.ps) - int256(s0.ps);
        cycSink = s2.sink - s0.sink;
        // control: plain swap round trip A->B->A of the same size
        tokenA.mint(ACT, X);
        vm.startPrank(ACT);(uint256 b,) = IStandardExchangeIn(hook).exchangeIn(IERC20(address(tokenA)), X, IERC20(address(tokenB)), 0, ACT, false, block.timestamp + 1 hours);
        S memory s3 = _snap();
        _log("step3 swap A->B", s2, s3, X);IStandardExchangeIn(hook).exchangeIn(IERC20(address(tokenB)), b, IERC20(address(tokenA)), 0, ACT, false, block.timestamp + 1 hours);
        vm.stopPrank();
        S memory s4 = _snap();
        _log("step4 swap B->A", s3, s4, 0);
    }

    function test_dual_feeLeak_defaultSeUsageFee() public {
        console2.log("SE usage fee (seA)", IVaultFeeOracleManagerView(address(indexedexManager)).usageFeeOfVault(seA));
        (int256 dps, uint256 sink) = _scenario();
        // quarantine Q-SEFEE justification (asserted, was log-only): with the default SE usage fee the passive LP
        // pays the SE dilution fee on someone else's zap-join/exit, and the fee sink receives it
        assertLt(dps, 0, "default SE fee: passive LP per-share falls over a third-party zap cycle");
        assertGt(sink, 0, "default SE fee: SE fee sink gains");
    }

    function test_dual_feeLeak_seUsageFeeOff() public {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seA, 1);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seB, 1);
        vm.stopPrank();
        (int256 dps,) = _scenario();
        // control: SE fee off -> the same cycle does not cost the passive LP (fees accrue to LPs)
        assertGe(dps, 0, "SE fee off: passive LP does not pay for a third-party zap cycle");
    }
}

interface IVaultFeeOracleManagerView {
    function usageFeeOfVault(address vault) external view returns (uint256);
}
