// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

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
