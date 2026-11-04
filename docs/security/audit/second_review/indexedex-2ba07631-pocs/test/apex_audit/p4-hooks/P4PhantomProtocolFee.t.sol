// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeMultiAssetLiquidity as ILiq} from
    "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4StandardExchangeOrbitalBufferHook as TB_Orbital} from
    "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TB_Curve} from
    "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as TB_Bal} from
    "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";

/// @notice NEW (p4-hooks): protocol-fee K proxy is not the curve invariant (orbital: r0*r1*r2 on a sphere AMM;
///         curve quad: geometricMean4 on a stableswap). kLast is snapshotted at whatever imbalanced state the
///         last liquidity op saw; when swaps rebalance the pool, the product rises with no fee income and the
///         next liquidity op mints "growth" LP to feeTo. Passive LPs lose value to the treasury far beyond the
///         configured fee share. Balancer quad (proper StableMath D) is the control.
abstract contract PhantomFeeScenario is Test {
    address internal constant LP = address(0x1111);
    address internal constant TRADER = address(0x7777);
    address internal constant POKER = address(0x9999);
    uint256 internal constant SEED = 100_000e18;

    function _hook() internal view virtual returns (address);
    function _toks() internal view virtual returns (SimpleMintableERC20[] memory);
    function _feeTo() internal view virtual returns (address);
    function _setFees(uint256 dex, uint256 usage) internal virtual;

    function _approveAll(address a) internal {
        SimpleMintableERC20[] memory t = _toks();
        vm.startPrank(a);
        for (uint256 i; i < t.length; ++i) {
            t[i].approve(_hook(), type(uint256).max);
        }
        vm.stopPrank();
    }

    function _join(address a, uint256 each) internal {
        SimpleMintableERC20[] memory t = _toks();
        uint256[] memory amts = new uint256[](t.length);
        for (uint256 i; i < t.length; ++i) {
            amts[i] = each;
            t[i].mint(a, each);
        }
        vm.prank(a);
        ILiq(_hook()).joinProportional(amts, a, 0, block.timestamp + 1 hours);
    }

    function _swap(uint256 i, uint256 j, uint256 amt) internal returns (uint256 out) {
        SimpleMintableERC20[] memory t = _toks();
        t[i].mint(TRADER, amt);
        vm.prank(TRADER);out = IStandardExchangeIn(_hook()).exchangeIn(IERC20(address(t[i])), amt, IERC20(address(t[j])), 0, TRADER, false, block.timestamp + 1 hours
        );
    }

    function _value(uint256 shares) internal view returns (uint256 v) {
        if (shares == 0) return 0;
        uint256[] memory a = ILiq(_hook()).previewExitProportional(shares);
        for (uint256 i; i < a.length; ++i) {
            v += a[i];
        }
    }

    struct R {
        uint256 lpShares;
        uint256 v0;
        uint256 spent;
        uint256 back;
        uint256 lpValue;
        uint256 feeToLp;
        uint256 feeToValue;
        uint256 traderCost;
    }

    /// cycles of: swap 0->1 (M), tiny join (snapshots kLast at the imbalanced state), swap 1->0 back, tiny join.
    function _scenario(uint256 usage, uint256 cyclesN, uint256 m) internal returns (R memory r) {
        _setFees(3e15, usage);
        _approveAll(LP);
        _approveAll(TRADER);
        _approveAll(POKER);
        _join(LP, SEED);
        r.lpShares = IERC20(_hook()).balanceOf(LP);
        r.v0 = _value(r.lpShares);
        for (uint256 c; c < cyclesN; ++c) {
            _cycle(r, m);
        }
        r.lpValue = _value(r.lpShares);
        r.feeToLp = IERC20(_hook()).balanceOf(_feeTo());
        r.feeToValue = _value(r.feeToLp);
        r.traderCost = r.spent - r.back;
        _log(r, usage);
    }

    function _cycle(R memory r, uint256 m) internal {
        uint256 got = _swap(0, 1, m);
        r.spent += m;
        _join(POKER, 1e18);
        r.back += _swap(1, 0, got);
        _join(POKER, 1e18);
    }

    function _log(R memory r, uint256 usage) internal pure {
        console2.log("  usageFee (protocol share)", usage);
        console2.log("  passive LP value before   ", r.v0);
        console2.log("  passive LP value after    ", r.lpValue);
        console2.log("  feeTo LP minted           ", r.feeToLp);
        console2.log("  feeTo LP value            ", r.feeToValue);
        console2.log("  trader round-trip cost (= fee income to the pool)", r.traderCost);
        if (r.traderCost > 0) console2.log("  feeTo value / fee income (bps)", r.feeToValue * 10000 / r.traderCost);
    }

    function _run(uint256 cyclesN, uint256 m) internal returns (R memory on, R memory off) {
        uint256 snap = vm.snapshotState();
        // usage fee 1 wei -> ownerFeeShare rounds to 0 -> feeOn == false (0 would fall back to the oracle default)
        console2.log("-- protocol fee OFF (usage 1 wei => feeOn false)");
        off = _scenario(1, cyclesN, m);
        vm.revertToState(snap);
        console2.log("-- protocol fee ON (usage 10%)");
        on = _scenario(1e17, cyclesN, m);
        int256 lpExtraLoss = int256(off.lpValue) - int256(on.lpValue);
        console2.log("-- passive LP value lost to protocol mint (on vs off)");
        console2.logInt(lpExtraLoss);
    }
}

contract P4PhantomFee_Orbital is TB_Orbital, PhantomFeeScenario {
    function _hook() internal view override returns (address) { return hook; }
    function _feeTo() internal view override returns (address) { return address(feeCollector); }
    function _toks() internal view override returns (SimpleMintableERC20[] memory t) {
        t = new SimpleMintableERC20[](3);
        t[0] = token0; t[1] = token1; t[2] = token2;
    }
    function _setFees(uint256 dex, uint256 usage) internal override { _setDexFee(dex); _setUsageFee(usage); }

    function test_orbital_phantomProtocolFee() public {
        (R memory on, R memory off) = _run(5, 25_000e18);
        // the protocol is entitled to at most usageFee (10%) of fee income; it takes far more
        assertGt(on.feeToValue, on.traderCost, "feeTo value exceeds 100% of the fee income");
        assertLt(on.lpValue, off.lpValue, "passive LP loses to the protocol mint");
    }
}

contract P4PhantomFee_CurveQuad is TB_Curve, PhantomFeeScenario {
    function _hook() internal view override returns (address) { return hook; }
    function _feeTo() internal view override returns (address) { return address(feeCollector); }
    function _toks() internal view override returns (SimpleMintableERC20[] memory t) {
        t = new SimpleMintableERC20[](4);
        t[0] = token0; t[1] = token1; t[2] = token2; t[3] = token3;
    }
    function _setFees(uint256 dex, uint256 usage) internal override { _setDexFee(dex); _setUsageFee(usage); }

    function test_curveQuad_phantomProtocolFee() public {
        (R memory on, R memory off) = _run(5, 25_000e18);
        assertGt(on.feeToValue, on.traderCost, "feeTo value exceeds 100% of the fee income");
        assertLt(on.lpValue, off.lpValue, "passive LP loses to the protocol mint");
    }
}

/// Control: Balancer quad measures K with the StableMath invariant -> protocol takes ~usageFee of fee income.
contract P4PhantomFee_BalancerQuadControl is TB_Bal, PhantomFeeScenario {
    function _hook() internal view override returns (address) { return hook; }
    function _feeTo() internal view override returns (address) { return address(feeCollector); }
    function _toks() internal view override returns (SimpleMintableERC20[] memory t) {
        t = new SimpleMintableERC20[](4);
        t[0] = token0; t[1] = token1; t[2] = token2; t[3] = token3;
    }
    function _setFees(uint256 dex, uint256 usage) internal override { _setDexFee(dex); _setUsageFee(usage); }

    function test_balancerQuad_control_protocolFeeBounded() public {
        (R memory on,) = _run(5, 25_000e18);
        assertLe(on.feeToValue * 10000, on.traderCost * 1500, "control: protocol take <= ~15% of fee income");
    }
}
