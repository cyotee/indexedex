// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
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

/// @dev Minimal IRateProvider harness (not a mock of the hook SUT).
contract StaticRateProvider {
    uint256 public immutable rate;
    bool public fail;

    constructor(uint256 rate_) {
        rate = rate_;
    }

    function setFail(bool f) external {
        fail = f;
    }

    function getRate() external view returns (uint256) {
        if (fail) revert("rate fail");
        return rate;
    }
}

contract UniswapV4StandardExchangeOrbitalBufferHook_RateProviderTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function test_rp_onlyOnSeLeg_binding() public {
        StaticRateProvider rp = new StaticRateProvider(1e18);
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            _argsWithSE(true, false, false);
        args.rp0 = address(rp);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_rp_withoutSe_reverts() public {
        StaticRateProvider rp = new StaticRateProvider(1e18);
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.rp0 = address(rp);
        vm.expectRevert();
        hookPkg.processArgs(abi.encode(args));
    }

    function test_RP1_effectiveReserve_is_sharesTimesRate() public {
        StaticRateProvider rp = new StaticRateProvider(2e18); // 2.0 rate
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            _argsWithSE(true, false, false);
        args.rp0 = address(rp);
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        IUniswapV4StandardExchangeOrbitalBufferHook o = IUniswapV4StandardExchangeOrbitalBufferHook(h);

        token0.mint(user, 500 ether);
        token1.mint(user, 500 ether);
        token2.mint(user, 500 ether);
        vm.startPrank(user);
        token0.approve(h, type(uint256).max);
        token1.approve(h, type(uint256).max);
        token2.approve(h, type(uint256).max);
        o.addLiquidity(100 ether, 100 ether, 100 ether, user, 0, block.timestamp + 1 hours, "");
        vm.stopPrank();

        uint256 seBal = o.seBalance(0);
        assertGt(seBal, 0, "SE shares");
        uint256 expected = (seBal * 2e18) / 1e18;
        assertEq(o.effectiveReserve(0), expected, "effective = shares * rate / 1e18");
        // seClaim is unwrap path (not rate); should differ under non-1 rate or dilution
        assertEq(o.rateProvider(0), address(rp));
    }

    function test_RP3_failClosed_getRate_reverts_effectiveRead() public {
        StaticRateProvider rp = new StaticRateProvider(1e18);
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            _argsWithSE(true, false, false);
        args.rp0 = address(rp);
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        IUniswapV4StandardExchangeOrbitalBufferHook o = IUniswapV4StandardExchangeOrbitalBufferHook(h);

        token0.mint(user, 500 ether);
        token1.mint(user, 500 ether);
        token2.mint(user, 500 ether);
        vm.startPrank(user);
        token0.approve(h, type(uint256).max);
        token1.approve(h, type(uint256).max);
        token2.approve(h, type(uint256).max);
        o.addLiquidity(50 ether, 50 ether, 50 ether, user, 0, block.timestamp + 1 hours, "");
        vm.stopPrank();

        rp.setFail(true);
        vm.expectRevert();
        o.effectiveReserve(0);
    }
}
