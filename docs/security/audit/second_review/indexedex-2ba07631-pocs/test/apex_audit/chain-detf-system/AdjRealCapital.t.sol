// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {
    ChainDetfSystemTest, ChainDetfSystemDeployedThrTest, ChainDetfAttacker, ChainDetfLender
} from "./ChainDetfSystem.t.sol";

/// @notice Business-logic adjudication: whale's own DETF, lent to itself at 0 fee (replaces the simulated 0.10% lender).
contract AdjZeroFeeWhale {
    IERC20 public immutable detf;
    constructor(IERC20 d) { detf = d; }
    function flashLoan(uint256 amount) external {
        uint256 b = detf.balanceOf(address(this));
        detf.transfer(msg.sender, amount);
        ChainDetfAttacker(msg.sender).onChainFlash(amount, 0);
        require(detf.balanceOf(address(this)) >= b, "whale inventory not restored");
    }
    function give(address to, uint256 amt) external { detf.transfer(to, amt); }
}

/// @notice Tries to source DETF from Uniswap V4 PoolManager flash accounting (take inside unlock).
contract AdjPmFlashProbe {
    IPoolManager immutable pm;
    address immutable detf;
    constructor(IPoolManager p, address d) { pm = p; detf = d; }
    function go(uint256 amt) external { pm.unlock(abi.encode(amt)); }
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        uint256 amt = abi.decode(data, (uint256));
        pm.take(Currency.wrap(detf), address(this), amt);
        return "";
    }
}

/// @notice Production parameters from scripts/foundry/anvil_robinhood_main + live 4663 reads:
/// weights DETF 60 / pair 20 / pair 20, thresholds 1.05/0.95 (parent), dexSwapFee 3e14, seigniorage 1% (live).
contract AdjRealCapitalTest is ChainDetfSystemDeployedThrTest {
    AdjZeroFeeWhale whale;

    function _prodFees() internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(detfInfo.hook(), 3e14);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultSeigniorageIncentivePercentage(1e16);
        vm.stopPrank();
    }

    /// (1) V4 PoolManager flash accounting cannot provide DETF: the buffer hook custodies its book as ERC20 itself.
    function test_adj_v4PoolManagerHoldsNoDetf() public {
        _setupHonest();
        console2.log("ADJ DETF held by PoolManager", IERC20(detf).balanceOf(address(pm)));
        console2.log("ADJ DETF held by reserve hook", IERC20(detf).balanceOf(reserveHook));
        assertEq(IERC20(detf).balanceOf(address(pm)), 0, "PM holds no DETF");
        AdjPmFlashProbe p = new AdjPmFlashProbe(pm, detf);
        try p.go(1e9) { console2.log("ADJ PM take(DETF) SUCCEEDED"); fail(); }
        catch (bytes memory e) { console2.log("ADJ PM take(DETF, 1e9) inside unlock reverted:"); console2.logBytes(e); }
    }

    function _liq(address holder, uint256 amt) internal returns (uint256 out) {
        uint256 snap = vm.snapshotState();
        address seller = address(0x5E11E5);
        vm.prank(holder); AdjZeroFeeWhale(holder).give(seller, amt);
        vm.startPrank(seller);
        IERC20(detf).approve(reserveHook, type(uint256).max);
        uint256 left = amt;
        while (left > 0) {
            uint256 c = IERC20(detf).balanceOf(reserveHook) / 5;
            if (c > left) c = left;out += ExchangeInAmount.exchangeOut(IStandardExchangeIn(reserveHook), IERC20(detf), c, IERC20(address(pair0)), 0, seller, false, block.timestamp + 1 hours);
            left -= c;
        }
        vm.stopPrank();
        vm.revertToState(snap);
    }

    function ext_whale(string memory tag, ChainDetfAttacker.Cfg memory c) external returns (int256 real, int256 atomic, int256 net) {
        require(msg.sender == address(this));
        // counterfactual: no attack, same elapsed time, whale liquidates its inventory
        uint256 snap = vm.snapshotState();
        vm.warp(block.timestamp + c.lock + 1);
        uint256 liqNoAtk = _liq(address(whale), c.delta);
        vm.revertToState(snap);
        R memory r = _scn(tag, c);
        uint256 liqAtk = _liq(address(whale), c.delta);
        real = r.realPnl; atomic = r.txPnl;
        net = r.realPnl + int256(liqAtk) - int256(liqNoAtk);
        console2.log("  ADJ whale inventory DETF", c.delta);
        console2.log("  ADJ whale liquidation value (pair0) no-attack / after-attack", liqNoAtk, liqAtk);
    }

    /// (2) Own capital fully counted: attacker is the DETF whale (0 fee), production fees + seigniorage.
    function test_adj_prodWhale() public {
        _setupHonest();
        _prodFees();
        s0 = _spotDetfIn(IERC20(address(pair0)));
        s1 = _spotDetfIn(IERC20(address(pair1)));
        uint256 lend = IERC20(detf).balanceOf(address(lender));
        uint256 poolD = _reserveOf(detf);
        whale = new AdjZeroFeeWhale(IERC20(detf));
        vm.prank(address(lender)); IERC20(detf).transfer(address(whale), lend);
        lender = ChainDetfLender(address(whale));
        console2.log("ADJ whale DETF / pool DETF (bps)", lend * 10_000 / poolD);
        console2.log("ADJ DETF supply", IERC20(detf).totalSupply());
        uint256[5] memory bps = [uint256(550), 1000, 2500, 5000, 0];
        for (uint256 i; i < 5; ++i) {
            uint256 d = bps[i] == 0 ? lend : poolD * bps[i] / 10_000;
            if (d > lend) d = lend;
            // X2 composite (pair0-leg dump, bond 1000 then mint 300)
            ChainDetfAttacker.Cfg memory c = _cfg(d, 0, 300 ether, 1000 ether);
            c.bondChunks = 2; c.chunks = 3; c.dumpLeg0 = true; c.bondFirst = true;
            uint256 snap = vm.snapshotState();
            try this.ext_whale("ADJ X2 whale composite", c) returns (int256 a, int256 b, int256 n) {
                console2.log("ADJ ROW X2 inventory bps of pool DETF", d * 10_000 / poolD);
                console2.log("ADJ ROW X2 realized / atomic / whale-net (realized + liquidation-value change):");
                console2.logInt(a); console2.logInt(b); console2.logInt(n);
            } catch (bytes memory e) { console2.log("ADJ ROW X2 REVERTED bps", bps[i]); console2.logBytes(e); }
            vm.revertToState(snap);
            // third-leg spot mint only (dump into pair1, mint 300 via pair0)
            ChainDetfAttacker.Cfg memory m = _cfg(d, 0, 300 ether, 0);
            m.chunks = 3;
            snap = vm.snapshotState();
            try this.ext_whale("ADJ third-leg spot-mint whale", m) returns (int256 a, int256 b, int256 n) {
                console2.log("ADJ ROW MINT inventory bps of pool DETF", d * 10_000 / poolD);
                console2.log("ADJ ROW MINT realized / atomic / whale-net:");
                console2.logInt(a); console2.logInt(b); console2.logInt(n);
            } catch (bytes memory e) { console2.log("ADJ ROW MINT REVERTED bps", bps[i]); console2.logBytes(e); }
            vm.revertToState(snap);
        }
        // honest same-capital baseline, production fees
        ChainDetfAttacker.Cfg memory h = _cfg(0, 0, 300 ether, 1000 ether); h.bondChunks = 2; h.chunks = 3;
        R memory hr = _scn("ADJ honest bond 1000 + mint 300", h);
        console2.log("ADJ honest realized:"); console2.logInt(hr.realPnl);
    }

    /* ---------------------------------- 033 ---------------------------------- */

    function _protocolLpA() internal view returns (uint256) {
        return IERC20(reserveHook).balanceOf(detf) + IERC20(reserveHook).balanceOf(detfInfo.bondNftVault());
    }

    function _idx(address t) internal view returns (uint256) {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) if (toks[i] == t) return i;
        revert("idx");
    }

    struct BurnM { uint256 d; uint256 lp0; uint256 sliceOut; uint256 sliceOther; uint256 otherVal; uint256 preview; uint256 marketAlt; uint256 recv; }

    function _logB(BurnM memory b) internal view {
        console2.log("ADJ burn DETF in", b.d);
        console2.log("ADJ preview / received", b.preview, b.recv);
        console2.log("ADJ slice pair0 (paid leg) / slice pair1 (forfeited leg)", b.sliceOut, b.sliceOther);
        console2.log("ADJ forfeited leg value in pair0 (after-fee swap quote)", b.otherVal);
        console2.log("ADJ fair non-DETF value of slice", b.sliceOut + b.otherVal);
        console2.log("ADJ redeemer loss bps of non-DETF backing", b.otherVal * 1e4 / (b.otherVal + b.sliceOut));
        console2.log("ADJ market-sell alternative for same DETF (pair0)", b.marketAlt);
        console2.log("ADJ protocol LP before / after", b.lp0, _protocolLpA());
    }

    /// (3) APEX-033 at production weights 60/20/20 and production thresholds; gate opened by public market sells.
    function test_adj_burnForfeit_prod() public {
        _setupHonest();
        _prodFees();
        address victim = address(0xA11CE);
        pair0.mint(victim, 100 ether);
        vm.startPrank(victim);
        pair0.approve(detf, type(uint256).max);(uint256 got,) = IStandardExchangeIn(detf).exchangeIn(IERC20(address(pair0)), 100 ether, IERC20(detf), 0, victim, false, block.timestamp + 1 hours);
        vm.stopPrank();
        console2.log("ADJ victim minted DETF / mint gate was open", got, detfInfo.isMintingAllowed(IERC20(address(pair0))));
        // ordinary market activity by unrelated actors: mint while the mint gate is open, sell DETF on the hook
        console2.log("ADJ synthetic at start", detfInfo.syntheticPrice());
        address mkt = address(lender);
        pair0.mint(mkt, 10_000_000 ether);
        vm.startPrank(mkt);
        IERC20(detf).approve(reserveHook, type(uint256).max);
        pair0.approve(detf, type(uint256).max);
        // phase 1: ordinary primary demand while the mint gate is open (buyers mint at the D8 spot quote)
        // (buyers pay with pair1; the pair0 gate reads only the pair0 leg, so pair1 inflow does not lift it)
        pair1.mint(mkt, 10_000_000 ether);
        pair1.approve(detf, type(uint256).max);
        for (uint256 i; i < 150 && detfInfo.isMintingAllowed(IERC20(address(pair1))); ++i) {IStandardExchangeIn(detf).exchangeIn(IERC20(address(pair1)), 500 ether, IERC20(detf), 0, mkt, false, block.timestamp + 1 hours);
        }
        console2.log("ADJ after primary demand: synthetic / holder DETF", detfInfo.syntheticPrice(), IERC20(detf).balanceOf(mkt));
        // phase 2: those holders sell on the hook (market sell-off) until the pair0 burn gate opens
        for (uint256 i; i < 400 && !detfInfo.isBurningAllowed(IERC20(address(pair0))); ++i) {
            uint256 c = IERC20(detf).balanceOf(reserveHook) / 10;
            uint256 lb = IERC20(detf).balanceOf(mkt);
            if (c > lb) c = lb;
            if (c == 0) break;IStandardExchangeIn(reserveHook).exchangeIn(IERC20(detf), c, IERC20(address(pair0)), 0, mkt, false, block.timestamp + 1 hours);
            if (i % 40 == 0) console2.log("ADJ iter / synthetic", i, detfInfo.syntheticPrice());
        }
        vm.stopPrank();
        console2.log("ADJ synthetic / burnThreshold", detfInfo.syntheticPrice(), detfInfo.burnThreshold());
        require(detfInfo.isBurningAllowed(IERC20(address(pair0))), "burn gate did not open");

        BurnM memory b;
        b.d = got / 2;
        b.lp0 = _protocolLpA();
        uint256[] memory ex = IUniswapV4SeBufferHook(reserveHook).previewExitProportional(b.d * b.lp0 / IERC20(detf).totalSupply());
        b.sliceOut = ex[_idx(address(pair0))];
        b.sliceOther = ex[_idx(address(pair1))];
        b.otherVal = IUniswapV4SeBufferHook(reserveHook).previewSwapExactIn(address(pair1), address(pair0), b.sliceOther);(b.preview,) = IStandardExchangeIn(detf).previewExchangeIn(IERC20(detf), b.d, IERC20(address(pair0)));
        b.marketAlt = IUniswapV4SeBufferHook(reserveHook).previewSwapExactIn(detf, address(pair0), b.d);
        vm.startPrank(victim);
        IERC20(detf).approve(detf, b.d);(b.recv,) = IStandardExchangeIn(detf).exchangeIn(IERC20(detf), b.d, IERC20(address(pair0)), 0, victim, false, block.timestamp + 1 hours);
        vm.stopPrank();
        _logB(b);
        assertApproxEqRel(b.recv, b.sliceOut, 1e15, "paid only the tokenOut leg");
        assertEq(b.recv, b.preview, "preview == execution (minOut cannot protect)");
    }
}

/// @notice APEX-033 payout math at production weights 60/20/20 near equilibrium; burn gate opened by CONFIG
/// (burnThreshold 100e18, mintThreshold 200e18) to isolate the payout from how the market reaches the band.
contract AdjBurnGateCfgTest is ChainDetfSystemTest {
    function _mintThrArg() internal pure override returns (uint256) { return 200e18; }
    function _burnThrArg() internal pure override returns (uint256) { return 100e18; }

    function _idx2(address t) internal view returns (uint256) {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) if (toks[i] == t) return i;
        revert("idx");
    }

    function test_adj_burnForfeit_602020_cfgGate() public {
        _setupHonest();
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultSeigniorageIncentivePercentage(1e16);
        vm.stopPrank();
        address victim = address(0xA11CE);
        pair0.mint(victim, 100 ether);
        vm.startPrank(victim);
        pair0.approve(detf, type(uint256).max);(uint256 got,) = IStandardExchangeIn(detf).exchangeIn(IERC20(address(pair0)), 100 ether, IERC20(detf), 0, victim, false, block.timestamp + 1 hours);
        vm.stopPrank();
        require(detfInfo.isBurningAllowed(IERC20(address(pair0))), "gate");
        uint256 d = got / 2;
        uint256 lp0 = IERC20(reserveHook).balanceOf(detf) + IERC20(reserveHook).balanceOf(detfInfo.bondNftVault());
        uint256[] memory ex = IUniswapV4SeBufferHook(reserveHook).previewExitProportional(d * lp0 / IERC20(detf).totalSupply());
        uint256 sOut = ex[_idx2(address(pair0))];
        uint256 oVal = IUniswapV4SeBufferHook(reserveHook).previewSwapExactIn(address(pair1), address(pair0), ex[_idx2(address(pair1))]);
        vm.startPrank(victim);
        IERC20(detf).approve(detf, d);(uint256 recv,) = IStandardExchangeIn(detf).exchangeIn(IERC20(detf), d, IERC20(address(pair0)), 0, victim, false, block.timestamp + 1 hours);
        vm.stopPrank();
        console2.log("ADJCFG synthetic", detfInfo.syntheticPrice());
        console2.log("ADJCFG burn d / received / slice pair0", d, recv, sOut);
        console2.log("ADJCFG forfeited pair1 slice valued in pair0", oVal);
        console2.log("ADJCFG loss bps of non-DETF backing", oVal * 1e4 / (oVal + sOut));
        assertApproxEqRel(recv, sOut, 1e15, "paid only tokenOut leg");
    }
}
