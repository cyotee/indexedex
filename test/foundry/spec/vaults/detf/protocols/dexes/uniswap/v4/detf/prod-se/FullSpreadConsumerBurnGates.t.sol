// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Vm} from "forge-std/Vm.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Cp_Univ4Se} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_Univ4Se.sol";
import {TestBase_UniswapV4Detf_Quad_PonsV2Se} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_PonsV2Se.sol";

library FullSpreadLpLogLedger {
    function reconcile(Vm.Log[] memory logs, address lp, address detf, address nft, uint256 beforeBalance)
        internal pure returns (uint256 afterBalance, uint256 burned)
    {
        afterBalance = beforeBalance;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != lp || logs[i].topics.length != 3 || logs[i].topics[0] != keccak256("Transfer(address,address,uint256)")) continue;
            address from = address(uint160(uint256(logs[i].topics[1])));
            address to = address(uint160(uint256(logs[i].topics[2])));
            uint256 amount = abi.decode(logs[i].data, (uint256));
            bool fromHolder = from == detf || from == nft;
            bool toHolder = to == detf || to == nft;
            if (fromHolder && !toHolder) afterBalance -= amount;
            if (toHolder && !fromHolder) afterBalance += amount;
            if (fromHolder && to == address(0)) burned += amount;
        }
    }
}

/// @notice Deployment policy selects the tested gate; no storage writes, impersonated DETF, or gate bypass.
abstract contract HooklessConsumerBurnGateCase is TestBase_UniswapV4Detf_Cp_Univ4Se {
    function _primaryCase() internal pure virtual returns (bool);
    function _defaultDetfArgs() internal view override returns (IUniswapV4Detf.PkgArgs memory args) {
        args = super._defaultDetfArgs();
        args.mintThreshold = 3e18;
        args.burnThreshold = _primaryCase() ? 2e18 : 0.1e18;
    }
    function test_consumer_hGateControlsPrimaryBurnVersusOwnerEiSwap() public {
        _firstBond(100 ether);
        vm.prank(detfUser);
        uint256 received = detfExchangeIn.exchangeIn(IERC20(mintToken), 1 ether, IERC20(detf), 0, detfUser, false, block.timestamp);
        uint256 burn = received / 10;
        assertGt(burn, 0);
        assertEq(detfInfo.isBurningAllowed(IERC20(mintToken)), _primaryCase(), "explicit gate regime");
        uint256 quote = detfExchangeIn.previewExchangeIn(IERC20(detf), burn, IERC20(mintToken));
        uint256 supply = IERC20(detf).totalSupply();
        uint256 lp = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()) + IERC20(reserveHook).balanceOf(detf);
        uint256 pairBefore = IERC20(mintToken).balanceOf(detfUser);
        uint256 detfBefore = IERC20(detf).balanceOf(detfUser);
        if (!_primaryCase()) vm.expectCall(reserveHook, abi.encodeWithSelector(IUniswapV4SeBufferHook.ownerSwapExactIn.selector));
        else vm.expectCall(reserveHook, abi.encodeWithSelector(IUniswapV4SeBufferHook.exitProportional.selector, lp * burn / supply, detf));
        vm.recordLogs();
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burn);
        uint256 paid = detfExchangeIn.exchangeIn(IERC20(detf), burn, IERC20(mintToken), quote, detfUser, false, block.timestamp);
        vm.stopPrank();
        assertEq(paid, quote);
        assertEq(IERC20(mintToken).balanceOf(detfUser), pairBefore + paid);
        assertEq(IERC20(detf).balanceOf(detfUser), detfBefore - burn);
        assertEq(IERC20(detf).totalSupply(), supply - (_primaryCase() ? burn : 0));
        (uint256 finalLp, uint256 grossBurn) = FullSpreadLpLogLedger.reconcile(vm.getRecordedLogs(), reserveHook, detf, detfInfo.bondNftVault(), lp);
        assertEq(grossBurn, _primaryCase() ? lp * burn / supply : 0, "gross proportional exit, not net after rejoin");
        assertEq(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()) + IERC20(reserveHook).balanceOf(detf), finalLp, "LP rejoin/return reconciled");
        _assertSeAllowancesZero();
    }
}
contract HooklessConsumerFallbackGateTest is HooklessConsumerBurnGateCase {
    function _primaryCase() internal pure override returns (bool) { return false; }
}
contract HooklessConsumerPrimaryGateTest is HooklessConsumerBurnGateCase {
    function _primaryCase() internal pure override returns (bool) { return true; }
}

abstract contract PonsConsumerBurnGateCase is TestBase_UniswapV4Detf_Quad_PonsV2Se {
    function _primaryCase() internal pure virtual returns (bool);
    function _defaultDetfArgs() internal view override returns (IUniswapV4Detf.PkgArgs memory args) {
        args = super._defaultDetfArgs();
        args.mintThreshold = 3e18;
        args.burnThreshold = _primaryCase() ? 2e18 : 0.1e18;
    }
    function test_consumer_pGateControlsPrimaryBurnVersusOwnerEiSwap() public {
        _firstBond(100 ether);
        vm.prank(detfUser);
        uint256 received = detfExchangeIn.exchangeIn(IERC20(mintToken), 1 ether, IERC20(detf), 0, detfUser, false, block.timestamp);
        uint256 burn = received / 10;
        assertGt(burn, 0);
        assertEq(detfInfo.isBurningAllowed(IERC20(mintToken)), _primaryCase(), "explicit gate regime");
        uint256 quote = detfExchangeIn.previewExchangeIn(IERC20(detf), burn, IERC20(mintToken));
        uint256 supply = IERC20(detf).totalSupply();
        uint256 lp = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()) + IERC20(reserveHook).balanceOf(detf);
        uint256 pairBefore = IERC20(mintToken).balanceOf(detfUser);
        uint256 detfBefore = IERC20(detf).balanceOf(detfUser);
        if (!_primaryCase()) vm.expectCall(reserveHook, abi.encodeWithSelector(IUniswapV4SeBufferHook.ownerSwapExactIn.selector));
        else vm.expectCall(reserveHook, abi.encodeWithSelector(IUniswapV4SeBufferHook.exitProportional.selector, lp * burn / supply, detf));
        vm.recordLogs();
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burn);
        uint256 paid = detfExchangeIn.exchangeIn(IERC20(detf), burn, IERC20(mintToken), quote, detfUser, false, block.timestamp);
        vm.stopPrank();
        assertEq(paid, quote);
        assertEq(IERC20(mintToken).balanceOf(detfUser), pairBefore + paid);
        assertEq(IERC20(detf).balanceOf(detfUser), detfBefore - burn);
        assertEq(IERC20(detf).totalSupply(), supply - (_primaryCase() ? burn : 0));
        (uint256 finalLp, uint256 grossBurn) = FullSpreadLpLogLedger.reconcile(vm.getRecordedLogs(), reserveHook, detf, detfInfo.bondNftVault(), lp);
        assertEq(grossBurn, _primaryCase() ? lp * burn / supply : 0, "gross proportional exit, not net after rejoin");
        assertEq(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()) + IERC20(reserveHook).balanceOf(detf), finalLp, "LP rejoin/return reconciled");
        _assertSeAllowancesZero();
    }
}
contract PonsConsumerFallbackGateTest is PonsConsumerBurnGateCase {
    function _primaryCase() internal pure override returns (bool) { return false; }
}
contract PonsConsumerPrimaryGateTest is PonsConsumerBurnGateCase {
    function _primaryCase() internal pure override returns (bool) { return true; }
}
