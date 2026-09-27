// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
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

/// @dev Minimal IRateProvider harness (not a mock of the hook SUT). Distinct name to avoid
///      colliding with the RateProvider suite's StaticRateProvider.
contract FixedRateProviderR68 {
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

/**
 * @title APEX 2026-09-17 R6.8 — orbital rated valuation + raw-leg settle boundary.
 * @notice ClaimLib.effectiveNative (D59/D60): a raw leg (no SE) values reserve as the raw
 *         balance, or rawReserve*rate/1e18 when a provider is configured; a buffered leg
 *         values reserve as SE shares * rate (ratedNative). A buffered leg with no provider
 *         is refused at init (RateProviderRequired); a failing provider fails closed at read
 *         time (RateProviderFailed). RateProviderWithoutSE is declared on the package
 *         interface but is never reverted by the orbital hook (a provider is accepted on any
 *         leg per D60), so it is unreachable and not asserted here.
 *
 * RED: against a build that ignored the rate on a buffered leg (valued shares 1:1),
 *      effectiveReserve(0) would equal seBalance(0) instead of shares*rate; against a build
 *      that applied a rate to an unrated raw leg, effectiveReserve(1) would drift off
 *      rawReserve(1); against a build without fail-closed rate reads, effectiveReserve would
 *      return a stale/zero value instead of reverting.
 */
contract UniswapV4StandardExchangeOrbitalBufferHook_RatedReserve_Test is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    // R6.8 test 1: a rated buffered leg values its reserve as SE shares * rate.
    function test_R6_8_ratedLeg_valuesReserveAsSharesTimesRate() public {
        FixedRateProviderR68 rp = new FixedRateProviderR68(1.2e18);
        IUniswapV4StandardExchangeOrbitalBufferHook o = _deployBufferedLeg0(address(rp));
        _fundAndSeed(o, 100 ether);

        uint256 seBal = o.seBalance(0);
        assertGt(seBal, 0, "buffered leg has SE shares");
        uint256 expected = (seBal * 1.2e18) / 1e18;

        assertEq(o.effectiveReserve(0), expected, "rated buffered leg = shares * rate / 1e18");
        assertEq(o.seClaim(0), expected, "seClaim == ratedNative(seBal, rate)");
        assertTrue(o.effectiveReserve(0) != seBal, "rated effective differs from raw SE-share face");
        assertEq(o.rateProvider(0), address(rp), "rate provider bound to leg0");
    }

    // R6.8 test 2: an unrated raw leg settles on its raw balance (no rate applied).
    function test_R6_8_rawLeg_settlesOnRawBalances() public {
        FixedRateProviderR68 rp = new FixedRateProviderR68(1.2e18);
        IUniswapV4StandardExchangeOrbitalBufferHook o = _deployBufferedLeg0(address(rp));
        (, , uint256 u1, uint256 u2) = _fundAndSeed(o, 100 ether);

        // Legs 1 & 2 are raw with no provider: effective == raw == the booked amount.
        assertTrue(!o.isBuffered(1), "leg1 raw");
        assertTrue(!o.isBuffered(2), "leg2 raw");
        assertEq(o.rateProvider(1), address(0), "leg1 has no provider");
        assertEq(o.rawReserve(1), u1, "leg1 raw reserve == booked");
        assertEq(o.effectiveReserve(1), o.rawReserve(1), "leg1 effective settles on raw balance");
        assertEq(o.rawReserve(2), u2, "leg2 raw reserve == booked");
        assertEq(o.effectiveReserve(2), o.rawReserve(2), "leg2 effective settles on raw balance");
        assertEq(o.seClaim(1), 0, "raw leg1 has no SE claim");
        assertEq(o.seClaim(2), 0, "raw leg2 has no SE claim");
    }

    // R6.8 test 3a: a raw leg carrying a rate provider is valued rawReserve*rate (D59),
    // distinct from an unrated raw leg's face value.
    function test_R6_8_boundary_ratedVsRaw() public {
        FixedRateProviderR68 rawRp = new FixedRateProviderR68(1.5e18);
        // leg0 raw (with a provider), leg1 buffered (SE + auto provider), leg2 raw (unrated).
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _argsWithSE(false, true, false);
        args.rp0 = address(rawRp);
        IUniswapV4StandardExchangeOrbitalBufferHook o = _deploy(args);
        _fundAndSeed(o, 100 ether);

        assertTrue(!o.isBuffered(0), "leg0 raw");
        assertTrue(o.isBuffered(1), "leg1 buffered");
        uint256 raw0 = o.rawReserve(0);
        assertGt(raw0, 0, "raw leg0 has reserve");
        assertEq(o.effectiveReserve(0), (raw0 * 1.5e18) / 1e18, "D59: raw leg valued rawReserve * rate");
        assertTrue(o.effectiveReserve(0) != raw0, "rated raw leg differs from unrated face");
        // leg2 unrated raw settles on face.
        assertEq(o.effectiveReserve(2), o.rawReserve(2), "unrated raw leg2 settles on face");
    }

    // R6.8 test 3b: a buffered leg declared without a rate provider is refused at init.
    function test_R6_8_bufferedLegRequiresRateProvider() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _argsWithSE(false, true, false);
        args.rp1 = address(0); // buffered leg1 with no provider
        vm.expectRevert(abi.encodeWithSignature("RateProviderRequired()"));
        hookPkg.processArgs(abi.encode(args));
    }

    // R6.8 test 3c: a failing rate provider fails closed at read time.
    function test_R6_8_failingRateProvider_failsClosed() public {
        FixedRateProviderR68 rp = new FixedRateProviderR68(1e18);
        IUniswapV4StandardExchangeOrbitalBufferHook o = _deployBufferedLeg0(address(rp));
        _fundAndSeed(o, 50 ether);

        rp.setFail(true);
        vm.expectRevert(abi.encodeWithSignature("RateProviderFailed()"));
        o.effectiveReserve(0);
    }

    /// @notice A rated raw leg cannot credit tokens already held for LPs as new input.
    function test_APEX008_ratedRawLeg_unfundedPretransferRejected() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _argsWithSE(false, true, false);
        args.rp0 = address(new FixedRateProviderR68(1.5e18));
        IUniswapV4StandardExchangeOrbitalBufferHook o = _deploy(args);
        _fundAndSeed(o, 100 ether);
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 backing = token0.balanceOf(address(o));
        uint256 outputBacking = token2.balanceOf(address(o));
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (token0, 1 ether, token2, 0, address(caller), true, block.timestamp + 1 hours));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1 ether, 0));
        caller.execute(address(o), data);
        assertEq(token0.balanceOf(address(o)), backing, "input backing unchanged");
        assertEq(token2.balanceOf(address(o)), outputBacking, "output backing unchanged");
        assertEq(token2.balanceOf(address(caller)), 0, "no unfunded output");

        // The same raw leg accepts fully funded atomic credit in native token units.
        token0.mint(address(this), 1 ether);
        token0.approve(address(caller), 1 ether);
        uint256 quote = IStandardExchangeIn(address(o)).previewExchangeIn(token0, 1 ether, token2);
        caller.consumePretransfer(token0, address(this), address(o), 1 ether, data);
        assertEq(token2.balanceOf(address(caller)), quote, "funded output matches preview");
    }

    // --- helpers ---

    function _deployBufferedLeg0(address rp0)
        internal
        returns (IUniswapV4StandardExchangeOrbitalBufferHook o)
    {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _argsWithSE(true, false, false);
        args.rp0 = rp0;
        o = _deploy(args);
    }

    function _deploy(IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args)
        internal
        returns (IUniswapV4StandardExchangeOrbitalBufferHook o)
    {
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(h);
        o = IUniswapV4StandardExchangeOrbitalBufferHook(h);
    }

    function _fundAndSeed(IUniswapV4StandardExchangeOrbitalBufferHook o, uint256 amount)
        internal
        returns (uint256 shares, uint256 u0, uint256 u1, uint256 u2)
    {
        address h = address(o);
        token0.mint(user, amount * 5);
        token1.mint(user, amount * 5);
        token2.mint(user, amount * 5);
        vm.startPrank(user);
        token0.approve(h, type(uint256).max);
        token1.approve(h, type(uint256).max);
        token2.approve(h, type(uint256).max);
        (shares, u0, u1, u2) = o.addLiquidity(amount, amount, amount, user, 0, block.timestamp + 1 hours, "");
        vm.stopPrank();
    }
}
