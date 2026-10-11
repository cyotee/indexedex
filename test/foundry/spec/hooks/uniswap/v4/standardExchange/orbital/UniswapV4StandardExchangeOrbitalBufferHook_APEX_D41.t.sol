// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";
import {ApexD41RateProviderFixture} from "contracts/test/stubs/ApexD41RateProviderFixture.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_APEX_D41 is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function _deployWithRp(ApexD41RateProviderFixture rp) internal returns (IUniswapV4StandardExchangeOrbitalBufferHook) {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            _argsWithSE(true, false, false);
        args.rp0 = address(rp);
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(h);
        return IUniswapV4StandardExchangeOrbitalBufferHook(h);
    }

    function _seed(IUniswapV4StandardExchangeOrbitalBufferHook o, address h) internal {
        token0.mint(user, 500 ether);
        token1.mint(user, 500 ether);
        token2.mint(user, 500 ether);
        vm.startPrank(user);
        token0.approve(h, type(uint256).max);
        token1.approve(h, type(uint256).max);
        token2.approve(h, type(uint256).max);
        o.addLiquidity(50 ether, 50 ether, 50 ether, user, 0, block.timestamp + 1 hours, "");
        vm.stopPrank();
    }

    function _projectedQuote(address target) internal view returns (bool, bytes memory) {
        return target.staticcall(abi.encodeWithSignature(
            "previewSwapAfterExchange(address,address,address,uint256)",
            se0, address(token0), address(token1), uint256(1 ether)
        ));
    }

    function _fundProjectionShares() internal {
        token0.mint(address(this), 10 ether);
        token0.approve(se0, 10 ether);
        assertGt(IStandardExchangeIn(se0).exchangeIn(
            IERC20(address(token0)), 10 ether, IERC20(se0), 0,
            address(this), false, block.timestamp
        ), 1 ether, "external caller owns shares used by the composed quote");
    }

    function test_recurrence_D41_projectionFallbackProbeMatrix() public {
        ApexD41RateProviderFixture rp = new ApexD41RateProviderFixture();
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Value, 1e18);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Zero, 0);
        IUniswapV4StandardExchangeOrbitalBufferHook o = _deployWithRp(rp);
        _seed(o, address(o));
        address target = address(o);
        _fundProjectionShares();
        uint256 baselineQuote;
        for (uint256 mode; mode <= uint256(ApexD41RateProviderFixture.ProbeKind.DecodeFalse); ++mode) {
            if (mode == uint256(ApexD41RateProviderFixture.ProbeKind.DecodeTrue)) continue;
            rp.setProbe(ApexD41RateProviderFixture.ProbeKind(mode));
            (bool ok, bytes memory result) = _projectedQuote(target);
            assertTrue(ok, "real hook projection accepts getRate fallback");
            uint256 output = abi.decode(result, (uint256));
            assertGt(output, 0, "funded composed route reaches projection");
            if (baselineQuote == 0) baselineQuote = output;
            else assertEq(output, baselineQuote, "fallback probe shape does not change quote");
        }
        vm.expectCall(address(rp), abi.encodeWithSelector(
            bytes4(keccak256("quoteRate(address,address,bytes)"))
        ), uint64(0));
        (bool finalOk,) = _projectedQuote(target);
        assertTrue(finalOk);
    }

    function test_recurrence_D41_projectionUsesQuoteRateAndFailsClosed() public {
        ApexD41RateProviderFixture rp = new ApexD41RateProviderFixture();
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Value, 1e18);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Value, 1e18);
        IUniswapV4StandardExchangeOrbitalBufferHook o = _deployWithRp(rp);
        _seed(o, address(o));
        address target = address(o);
        _fundProjectionShares();
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeTrue);
        (bool ok, bytes memory result) = _projectedQuote(target);
        assertTrue(ok, "valid projected provider control");
        assertGt(abi.decode(result, (uint256)), 0);
        for (uint256 mode = 1; mode <= uint256(ApexD41RateProviderFixture.RateKind.Zero); ++mode) {
            rp.setQuoteRate(ApexD41RateProviderFixture.RateKind(mode), 1e18);
            (ok, result) = _projectedQuote(target);
            assertFalse(ok, "selected quoteRate failure cannot use valid live rate");
            assertEq(result, abi.encodeWithSignature("RateProviderFailed()"), "exact projected-rate boundary");
        }
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Value, 1e18);
        vm.expectCall(address(rp), abi.encodeWithSelector(
            bytes4(keccak256("quoteRate(address,address,bytes)")), se0, address(token0)
        ), uint64(1));
        (ok, result) = _projectedQuote(target);
        assertTrue(ok, "restoring the selected dependency restores the same route");
    }

    function test_APEX_D41_orbital_getRateOnly_effectiveReserve() public {
        ApexD41RateProviderFixture rp = new ApexD41RateProviderFixture();
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.Revert);
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Value, 2e18);
        IUniswapV4StandardExchangeOrbitalBufferHook o = _deployWithRp(rp);
        _seed(o, address(o));
        uint256 seBal = o.seBalance(0);
        assertGt(seBal, 0);
        assertEq(o.effectiveReserve(0), (seBal * 2e18) / 1e18);
    }

    function test_APEX_D41_orbital_probeTrue_stillQuotes() public {
        ApexD41RateProviderFixture rp = new ApexD41RateProviderFixture();
        rp.setProbe(ApexD41RateProviderFixture.ProbeKind.DecodeTrue);
        rp.setGetRate(ApexD41RateProviderFixture.RateKind.Value, 1e18);
        rp.setQuoteRate(ApexD41RateProviderFixture.RateKind.Value, 3e18);
        IUniswapV4StandardExchangeOrbitalBufferHook o = _deployWithRp(rp);
        _seed(o, address(o));
        assertGt(o.effectiveReserve(0), 0);
        assertEq(o.rateProvider(0), address(rp));
    }
}
