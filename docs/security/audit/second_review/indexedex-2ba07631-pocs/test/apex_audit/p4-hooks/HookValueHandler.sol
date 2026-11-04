// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeMultiAssetLiquidity as ILiq} from
    "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";

interface IP4Orbital {
    function radius() external view returns (uint256);
    function effectiveReserves() external view returns (uint256, uint256, uint256);
}

interface IP4Book {
    function reserveOfToken(address token) external view returns (uint256);
}

/// @notice Adversary helper that moves the hook's own V4 pool price INSIDE its own PoolManager unlock,
///         acts on the hook's SE / LP surface while the price is moved, then restores and settles.
contract P4UnlockActor is IUnlockCallback {
    using TransientStateLibrary for IPoolManager;

    IPoolManager public immutable pm;
    address public immutable hook;
    address public immutable owner;

    struct Plan {
        PoolKey key;
        bool zeroForOne;
        uint256 moveIn;
        uint8 kind; // 0 join single tokenK, 1 SE swap tokenK->tokenL, 2 exit single (all held LP) -> tokenK
        address tokenK;
        address tokenL;
        uint256 amtK;
    }

    constructor(IPoolManager pm_, address hook_) {
        pm = pm_;
        hook = hook_;
        owner = msg.sender;
    }

    function approveAll(address[] calldata toks) external {
        require(msg.sender == owner, "own");
        for (uint256 i; i < toks.length; ++i) {
            IERC20(toks[i]).approve(hook, type(uint256).max);
        }
    }

    function run(Plan calldata p) external {
        require(msg.sender == owner, "own");
        pm.unlock(abi.encode(p));
    }

    function sweep(address[] calldata toks, address to) external {
        require(msg.sender == owner, "own");
        for (uint256 i; i < toks.length; ++i) {
            uint256 b = IERC20(toks[i]).balanceOf(address(this));
            if (b > 0) IERC20(toks[i]).transfer(to, b);
        }
    }

    function unlockCallback(bytes calldata raw) external returns (bytes memory) {
        require(msg.sender == address(pm), "pm");
        Plan memory p = abi.decode(raw, (Plan));
        (Currency cin, Currency cout) =
            p.zeroForOne ? (p.key.currency0, p.key.currency1) : (p.key.currency1, p.key.currency0);
        _settle(cin, p.moveIn);
        pm.swap(
            p.key,
            SwapParams(p.zeroForOne, -int256(p.moveIn), p.zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1),
            ""
        );
        uint256 got = _take(cout);
        if (p.kind == 0) {IStandardExchangeIn(hook).exchangeIn(IERC20(p.tokenK), p.amtK, IERC20(hook), 0, address(this), false, block.timestamp + 1 hours
            );
        } else if (p.kind == 1) {IStandardExchangeIn(hook).exchangeIn(IERC20(p.tokenK), p.amtK, IERC20(p.tokenL), 0, address(this), false, block.timestamp + 1 hours
            );
        } else {
            uint256 lp = IERC20(hook).balanceOf(address(this));IStandardExchangeIn(hook).exchangeIn(IERC20(hook), lp, IERC20(p.tokenK), 0, address(this), false, block.timestamp + 1 hours
            );
        }
        _settle(cout, got);
        pm.swap(
            p.key,
            SwapParams(!p.zeroForOne, -int256(got), !p.zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1),
            ""
        );
        _take(cin);
        return "";
    }

    function _settle(Currency c, uint256 amount) internal {
        if (amount == 0) return;
        pm.sync(c);
        IERC20(Currency.unwrap(c)).transfer(address(pm), amount);
        pm.settle();
    }

    function _take(Currency c) internal returns (uint256 amt) {
        int256 d = pm.currencyDelta(address(this), c);
        if (d > 0) {
            amt = uint256(d);
            pm.take(c, address(this), amt);
        }
    }
}

/// @notice p4-hooks: value-level stateful handler shared by the six V4 SE buffer hook families
///         (weighted, CP single, CP dual, orbital, curve quad, balancer quad). All families expose
///         IStandardExchangeIn/Out (swaps + LP routes token<->hook) and IStandardExchangeMultiAssetLiquidity.
/// @dev   Every action runs as an atomic self-call: on revert the whole action is rolled back and only the
///        per-selector failure counter moves. Breaks are recorded in ghosts (never asserted inside actions,
///        which would just turn a break into a counted failure). Fair price of every underlying = prices[i].
contract HookValueHandler is Test {
    struct Config {
        address hook;
        SimpleMintableERC20[] tokens;
        address[] ses; // per leg SE (buffered) or 0 (raw)
        address[] vaults; // per leg SimpleYieldERC4626 behind the SE, or 0
        uint256[] prices; // fair price per token (WAD)
        WrapperExactOutRouter router;
        IPoolManager pm;
        PoolKey[] keys;
        address feeTo;
        bool orbital;
        bool allowYield; // quarantine switch (curve quad: SE rate != 1 re-triggers rawleg-rp-lp-and-fee (1))
        bool unbalancedPropOnly; // narrow quarantine (orbital): joinUnbalanced only at the current reserve ratio
        uint256 seedEach;
        string family;
    }

    uint256 internal constant WAD = 1e18;
    uint256 internal constant N_ACTIONS = 16;

    address public hook;
    SimpleMintableERC20[] internal tokens;
    address[] internal ses;
    address[] internal vaults;
    uint256[] internal prices;
    WrapperExactOutRouter internal router;
    IPoolManager internal pm;
    PoolKey[] internal keys;
    address public feeTo;
    bool public orbital;
    bool public allowYield;
    bool public unbalancedPropOnly;
    uint256 public seedEach;
    string public family;
    uint256 internal n;

    address[3] public honest = [address(0xA11CE1), address(0xA11CE2), address(0xA11CE3)];
    address public constant passive = address(0xFA551E);
    address public constant attacker = address(0xBADBAD);
    address public constant yielder = address(0x7E1D);
    AtomicPretransferCaller public caller; // attacker contract (pretransfer / refunds land here)
    AtomicPretransferCaller public honestCaller; // honest integrator contract (atomic pretransfer only)
    P4UnlockActor public unlocker;

    // ---------------- non-vacuity ----------------
    string[N_ACTIONS] internal names = [
        "h_joinProp",
        "h_exitProp",
        "h_joinSingle",
        "h_exitSingle",
        "h_swapRT",
        "h_yield",
        "h_warp",
        "a_roundTrip",
        "a_manipulate",
        "a_unlockSandwich",
        "a_yieldThenAct",
        "a_donateThenClaim",
        "a_sweep",
        "a_exactOutRefund",
        "c_bankRun",
        "a_joinUnbalanced"
    ];
    uint256[N_ACTIONS] public attempts;
    uint256[N_ACTIONS] public successes;
    bytes4[N_ACTIONS] public lastRevert;

    // ---------------- ghosts ----------------
    uint256 public mintedValue; // value minted to actor set (fair)
    uint256 public injectedValue; // honest yield injected (fair)
    uint256 public exogenous; // hook TVL gained from honest yield
    uint256 public mintedAtk; // value minted to attacker side

    uint256 public cycles;
    uint256 public cycleBreaks;
    int256 public worstCycle = type(int256).min;
    int256 public attackerCumulative;
    string public firstCycleBreak;

    uint256 public quoteChecks;
    uint256 public quoteBreaks; // SE swap delivered != returned, or returned > quote, or returned < quote - tol
    string public firstQuoteBreak;
    uint256 public pmQuoteChecks;
    uint256 public pmOverQuote; // PM path paid more than SE-path previewExchangeIn (informational)
    int256 public worstPmVsQuote = type(int256).min;

    uint256 public exitChecks;
    uint256 public exitBreaks; // preview > 0 but paid 0, or paid > preview, or paid < preview - tol
    string public firstExitBreak;

    uint256 public consChecks;
    uint256 public consBreaks;
    int256 public worstLeak; // signed, largest |leak| kept with sign
    string public firstConsBreak;

    uint256 public lpPerShareInit;
    uint256 public lpPerShareMin = type(uint256).max;
    uint256 public lpBreaks;
    string public firstLpBreak;

    uint256 public bankRuns;
    uint256 public bankRunBreaks;
    string public firstBankRunBreak;

    uint256 public sweepGains; // successful claims of unbooked balances by attacker (count)
    uint256 public sweepValue;

    // ---------------- audit additions: effective-interaction + hidden-break accounting ----------------
    /// harness-level "cycle could not be closed" rollbacks per selector. Breaks recorded inside such an action are
    /// carried out in the revert data (error Unclosed) and merged, instead of being silently rolled back.
    error Unclosed(uint256 qb, uint256 eb, string fq, string fe);
    uint256[N_ACTIONS] public unclosed;
    uint256 public sweepProbesTried; // pretransfer-claim probes actually sent to the hook
    uint256 public sweepProbesOk; // ... of which the hook accepted (0-output or not)
    uint256 public sweepActionsEffective; // a_sweep / a_donateThenClaim calls with >= 1 probe sent
    uint256 public previewMissing; // INV-3 checks skipped because the preview reverted (check would be vacuous)
    uint256 public consolidateFallback; // LP unwound via exitProportional because single exit reverted
    /// INV-5b: per adversarial action, passive per-share value may not drop (> 1 ppm) unless the action minted a
    /// protocol fee (feeTo LP up) or paid an SE fee (feeTo SE value up). Closes the yield/fee masking gap of INV-5
    /// (which only compares against the seed value, so earlier honest yield/fees could hide a later extraction).
    uint256 public lpAdvChecks;
    uint256 public lpAdvBreaks;
    string public firstLpAdvBreak;

    constructor(Config memory c) {
        hook = c.hook;
        n = c.tokens.length;
        for (uint256 i; i < n; ++i) {
            tokens.push(c.tokens[i]);
            ses.push(c.ses[i]);
            vaults.push(c.vaults[i]);
            prices.push(c.prices[i]);
        }
        for (uint256 i; i < c.keys.length; ++i) {
            keys.push(c.keys[i]);
        }
        router = c.router;
        pm = c.pm;
        feeTo = c.feeTo;
        orbital = c.orbital;
        allowYield = c.allowYield;
        unbalancedPropOnly = c.unbalancedPropOnly;
        seedEach = c.seedEach;
        family = c.family;
        caller = new AtomicPretransferCaller();
        honestCaller = new AtomicPretransferCaller();
        unlocker = new P4UnlockActor(pm, hook);
        address[] memory all = new address[](n);
        for (uint256 i; i < n; ++i) {
            all[i] = address(tokens[i]);
        }
        unlocker.approveAll(all);
        address[5] memory eoas = [honest[0], honest[1], honest[2], passive, attacker];
        for (uint256 a; a < 5; ++a) {
            vm.startPrank(eoas[a]);
            for (uint256 i; i < n; ++i) {
                tokens[i].approve(hook, type(uint256).max);
                tokens[i].approve(address(router), type(uint256).max);
                tokens[i].approve(address(caller), type(uint256).max);
                tokens[i].approve(address(honestCaller), type(uint256).max);
                if (ses[i] != address(0)) {
                    tokens[i].approve(ses[i], type(uint256).max);
                    IERC20(ses[i]).approve(hook, type(uint256).max);
                }
                if (vaults[i] != address(0)) tokens[i].approve(vaults[i], type(uint256).max);
            }
            vm.stopPrank();
        }
        vm.startPrank(yielder);
        for (uint256 i; i < n; ++i) {
            if (vaults[i] != address(0)) tokens[i].approve(vaults[i], type(uint256).max);
        }
        vm.stopPrank();
    }

    // =====================================================================================
    // Seed (setup only, not a campaign action)
    // =====================================================================================
    function seed() external {
        uint256[] memory amts = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            amts[i] = seedEach;
            tokens[i].mint(passive, seedEach);
        }
        vm.prank(passive);
        ILiq(hook).joinProportional(amts, passive, 0, block.timestamp + 1 hours);
        lpPerShareInit = _passivePerShare();
        lpPerShareMin = lpPerShareInit;
    }

    // =====================================================================================
    // Public fuzz entrypoints (targeted selectors). Each wraps an atomic self-call.
    // =====================================================================================
    function h_joinProp(uint256 a, uint256 s) external { _run(0, abi.encodeCall(this.x_joinProp, (a, s))); }
    function h_exitProp(uint256 a, uint256 s) external { _run(1, abi.encodeCall(this.x_exitProp, (a, s))); }
    function h_joinSingle(uint256 a, uint256 k, uint256 s) external { _run(2, abi.encodeCall(this.x_joinSingle, (a, k, s))); }
    function h_exitSingle(uint256 a, uint256 k, uint256 s) external { _run(3, abi.encodeCall(this.x_exitSingle, (a, k, s))); }
    function h_swapRT(uint256 a, uint256 i, uint256 j, uint256 s, uint256 m) external {
        _run(4, abi.encodeCall(this.x_swapRT, (a, i, j, s, m)));
    }
    function h_yield(uint256 k, uint256 s) external { _run(5, abi.encodeCall(this.x_yield, (k, s))); }
    function h_warp(uint256 s) external { _run(6, abi.encodeCall(this.x_warp, (s))); }
    function a_roundTrip(uint256 i, uint256 j, uint256 s, uint256 m) external {
        _run(7, abi.encodeCall(this.x_roundTrip, (i, j, s, m)));
    }
    function a_manipulate(uint256 kp, uint256 dir, uint256 k, uint256 sm, uint256 sa, uint256 kind) external {
        _run(8, abi.encodeCall(this.x_manipulate, (kp, dir, k, sm, sa, kind)));
    }
    function a_unlockSandwich(uint256 kp, uint256 dir, uint256 k, uint256 sm, uint256 sa, uint256 kind) external {
        _run(9, abi.encodeCall(this.x_unlockSandwich, (kp, dir, k, sm, sa, kind)));
    }
    function a_yieldThenAct(uint256 k, uint256 g, uint256 i, uint256 j, uint256 s, uint256 kind) external {
        _run(10, abi.encodeCall(this.x_yieldThenAct, (k, g, i, j, s, kind)));
    }
    function a_donateThenClaim(uint256 k, uint256 s, uint256 j, uint256 m) external {
        _run(11, abi.encodeCall(this.x_donateThenClaim, (k, s, j, m)));
    }
    function a_sweep(uint256 j) external { _run(12, abi.encodeCall(this.x_sweep, (j))); }
    function a_exactOutRefund(uint256 i, uint256 j, uint256 s, uint256 over) external {
        _run(13, abi.encodeCall(this.x_exactOutRefund, (i, j, s, over)));
    }
    function c_bankRun() external { _run(14, abi.encodeCall(this.x_bankRun, ())); }
    function a_joinUnbalanced(uint256 k, uint256 s, uint256 e) external {
        _run(15, abi.encodeCall(this.x_joinUnbalanced, (k, s, e)));
    }

    struct Pre {
        uint256 actorVal;
        uint256 tvl;
        uint256 minted;
        uint256 injected;
        uint256 ps;
        uint256 feeLp;
        uint256 feeSe;
    }

    function _run(uint256 id, bytes memory data) internal {
        ++attempts[id];
        Pre memory p = Pre(
            _actorTokenValue(),
            _hookTVL(),
            mintedValue,
            injectedValue,
            _passivePerShare(),
            IERC20(hook).balanceOf(feeTo),
            _seValueOf(feeTo)
        );
        (bool ok, bytes memory ret) = address(this).call(data);
        if (!ok) {
            if (ret.length >= 4) lastRevert[id] = bytes4(ret);
            if (ret.length >= 4 && bytes4(ret) == Unclosed.selector) _mergeUnclosed(id, ret);
            return;
        }
        ++successes[id];
        _postChecks(id, p);
    }

    function _mergeUnclosed(uint256 id, bytes memory ret) internal {
        ++unclosed[id];
        bytes memory body = new bytes(ret.length - 4);
        for (uint256 i; i < body.length; ++i) {
            body[i] = ret[i + 4];
        }
        (uint256 qb, uint256 eb, string memory fq, string memory fe) = abi.decode(body, (uint256, uint256, string, string));
        if (qb > quoteBreaks) {
            quoteBreaks = qb;
            if (bytes(firstQuoteBreak).length == 0) firstQuoteBreak = string.concat("[in unclosed ", names[id], "] ", fq);
        }
        if (eb > exitBreaks) {
            exitBreaks = eb;
            if (bytes(firstExitBreak).length == 0) firstExitBreak = string.concat("[in unclosed ", names[id], "] ", fe);
        }
    }

    function _revertUnclosed() internal view {
        revert Unclosed(quoteBreaks, exitBreaks, firstQuoteBreak, firstExitBreak);
    }

    modifier self() {
        require(msg.sender == address(this), "self");
        _;
    }

    // =====================================================================================
    // Post-action global checks (conservation + LP value)
    // =====================================================================================
    function _postChecks(uint256 id, Pre memory p) internal {
        uint256 tvl1 = _hookTVL();
        uint256 act1 = _actorTokenValue();
        if (id == 5) {
            // honest yield: exogenous value enters through the SE vault
            if (tvl1 > p.tvl) exogenous += tvl1 - p.tvl;
        } else if (id != 14) {
            // value in from outside (mints + injected) must equal actor delta + hook TVL delta
            int256 leak = int256(mintedValue - p.minted) + int256(injectedValue - p.injected)
                - (int256(act1) - int256(p.actorVal)) - (int256(tvl1) - int256(p.tvl));
            ++consChecks;
            int256 absLeak = leak < 0 ? -leak : leak;
            int256 absWorst = worstLeak < 0 ? -worstLeak : worstLeak;
            if (absLeak > absWorst) worstLeak = leak;
            uint256 tol = 1e9 + (p.tvl + tvl1) / 1e12;
            if (uint256(absLeak) > tol) {
                ++consBreaks;
                if (bytes(firstConsBreak).length == 0) {
                    firstConsBreak = string.concat(names[id], " leak=", vm.toString(leak));
                }
            }
        }
        uint256 ps = _passivePerShare();
        if (ps < lpPerShareMin) lpPerShareMin = ps;
        if (id >= 7 && id != 14) {
            // adversarial closed cycle (a_*): passive LPs must not pay for it
            ++lpAdvChecks;
            bool feeEvent = IERC20(hook).balanceOf(feeTo) > p.feeLp || _seValueOf(feeTo) > p.feeSe + 1e12;
            if (!feeEvent && ps < p.ps && (p.ps - ps) * 1e6 > p.ps) {
                ++lpAdvBreaks;
                if (bytes(firstLpAdvBreak).length == 0) {
                    firstLpAdvBreak =
                        string.concat(names[id], " perShare before=", vm.toString(p.ps), " after=", vm.toString(ps));
                }
            }
        }
        // 5 bp slack for impermanent loss from honest single-sided price impact (pool vs fair price)
        if (ps * 10000 < lpPerShareInit * 9995) {
            ++lpBreaks;
            if (bytes(firstLpBreak).length == 0) {
                firstLpBreak = string.concat(names[id], " perShare=", vm.toString(ps), " init=", vm.toString(lpPerShareInit));
            }
        }
    }

    // =====================================================================================
    // Honest actions
    // =====================================================================================
    function x_joinProp(uint256 a, uint256 s) external self {
        address actor = honest[a % 3];
        uint256 amt = _joinCap(bound(s, 1e15, seedEach / 50));
        uint256[] memory amts = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            amts[i] = amt;
            _mint(i, actor, amt);
        }
        (uint256 pv,) = ILiq(hook).previewJoinProportional(amts);
        uint256 lp0 = IERC20(hook).balanceOf(actor);
        vm.prank(actor);
        (uint256 sh,) = ILiq(hook).joinProportional(amts, actor, 0, block.timestamp + 1 hours);
        ++exitChecks;
        if (IERC20(hook).balanceOf(actor) - lp0 != sh || sh > pv || sh + sh / 1e12 + 10 < pv) {
            _exitBreak("joinProp", pv, sh);
        }
    }

    function _ensureLp(address actor) internal returns (uint256 bal) {
        bal = IERC20(hook).balanceOf(actor);
        if (bal > 0) return bal;
        uint256 amt = _joinCap(seedEach / 100);
        uint256[] memory amts = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            amts[i] = amt;
            _mint(i, actor, amt);
        }
        vm.prank(actor);
        ILiq(hook).joinProportional(amts, actor, 0, block.timestamp + 1 hours);
        bal = IERC20(hook).balanceOf(actor);
    }

    function x_exitProp(uint256 a, uint256 s) external self {
        address actor = honest[a % 3];
        uint256 bal = _ensureLp(actor);
        uint256 sh = bound(s, bal / 10 + 1, bal);
        _exitPropChecked(actor, sh, "exitProp");
    }

    function x_joinSingle(uint256 a, uint256 k, uint256 s) external self {
        address actor = honest[a % 3];
        uint256 i = k % n;
        uint256 amt = _joinCap(bound(s, 1e15, seedEach / 200));
        _mint(i, actor, amt);
        _joinSingleChecked(actor, i, amt, "joinSingle");
    }

    function x_exitSingle(uint256 a, uint256 k, uint256 s) external self {
        address actor = honest[a % 3];
        uint256 i = k % n;
        uint256 bal = _ensureLp(actor);
        uint256 cap = IERC20(hook).totalSupply() / 200;
        uint256 hiS = bal < cap ? bal : cap;
        // dust (< 1e12 shares) exits revert on balancer-quad (Panic) and weighted (0x1f2a2005) and made ~40% of
        // h_exitSingle calls no-ops; honest exits are sized >= 1e12 shares (dust behaviour covered by a diag test).
        uint256 sh = bound(s, hiS < 1e12 ? 1 : 1e12, hiS);
        _exitSingleChecked(actor, i, sh, "exitSingle");
    }

    /// honest round trip i->j->i with mixed paths; round trips must never profit (same check as attacker).
    function x_swapRT(uint256 a, uint256 i, uint256 j, uint256 s, uint256 m) external self {
        address actor = honest[a % 3];
        (i, j) = _pair(i, j);
        uint256 amt = bound(s, 1e15, seedEach / 50);
        Cyc memory c = _cBeginFor(actor);
        _mint(i, actor, amt);
        uint256 got = _leg(actor, i, j, amt, m % 4, honestCaller);
        _leg(actor, j, i, got, (m / 4) % 4, honestCaller);
        _cEndFor(actor, c, i, amt, "h_swapRT");
    }

    function x_yield(uint256 k, uint256 s) external self {
        require(allowYield, "quarantined");
        uint256 i = _bufferedLeg(k);
        SimpleYieldERC4626 v = SimpleYieldERC4626(vaults[i]);
        uint256 ta = v.totalAssets();
        require(ta > 0, "empty");
        uint256 amt = bound(s, ta / 1e7 + 1, ta / 2000 + 2); // <= 5 bp per accrual
        tokens[i].mint(yielder, amt);
        vm.prank(yielder);
        v.simulateYield(amt);
        injectedValue += amt * prices[i] / WAD;
    }

    function x_warp(uint256 s) external self {
        vm.warp(block.timestamp + bound(s, 1, 3 days));
        vm.roll(block.number + 1);
    }

    // =====================================================================================
    // Adversarial actions (closed cycles: start with fresh mint, end consolidated to one token)
    // =====================================================================================
    function x_roundTrip(uint256 i, uint256 j, uint256 s, uint256 m) external self {
        (i, j) = _pair(i, j);
        uint256 amt = bound(s, 1e12, seedEach / 5);
        Cyc memory c = _cBegin();
        _mint(i, attacker, amt);
        uint256 got = _leg(attacker, i, j, amt, m % 4, caller);
        _leg(attacker, j, i, got, (m / 4) % 4, caller);
        _cEnd(c, i, amt, 0, "a_roundTrip");
    }

    struct M {
        PoolKey key;
        bool z;
        uint256 ti;
        uint256 move;
        uint256 act;
        uint256 k;
        uint256 kind;
        uint256 got;
    }

    function _plan(uint256 kp, uint256 dir, uint256 k, uint256 sm, uint256 sa, uint256 kind, uint256 kinds)
        internal
        view
        returns (M memory m)
    {
        require(keys.length > 0, "nokey");
        m.key = keys[kp % keys.length];
        m.z = dir % 2 == 0;
        m.ti = _idx(Currency.unwrap(m.z ? m.key.currency0 : m.key.currency1));
        m.move = bound(sm, seedEach / 1000, seedEach / 4);
        m.act = _joinCap(bound(sa, seedEach / 1000, seedEach / 5));
        m.k = k % n;
        m.kind = kind % kinds;
    }

    /// move the hook's own pool price (PM swap), act on the SE / LP surface, restore, unwind.
    function x_manipulate(uint256 kp, uint256 dir, uint256 k, uint256 sm, uint256 sa, uint256 kind) external self {
        M memory m = _plan(kp, dir, k, sm, sa, kind, 6);
        Cyc memory c = _cBegin();
        if (m.kind >= 4) _attackerJoinProp(m.act, m.ti); // hold LP through the manipulation
        _mint(m.ti, attacker, m.move);
        m.got = _pmSwap(attacker, m.key, m.z, m.move);
        _manipMiddle(m);
        _pmSwap(attacker, m.key, !m.z, m.got);
        _cEnd(c, m.ti, m.move + m.act, 0, "a_manipulate");
    }

    function _manipMiddle(M memory m) internal {
        if (m.kind == 0) {
            _fund(m.k, m.act, m.ti);
            _joinSingleChecked(attacker, m.k, m.act, "manip.joinSingle");
        } else if (m.kind == 1) {
            _attackerJoinProp(m.act, m.ti);
        } else if (m.kind == 2) {
            _fund(m.k, m.act, m.ti);
            _seIn(attacker, m.k, (m.k + 1) % n, m.act, false, caller);
        } else if (m.kind == 3) {
            _fund(m.k, m.act, m.ti);
            _seExactOut(attacker, m.k, (m.k + 1) % n, m.act / 2, false, caller);
        } else if (m.kind == 4) {
            _exitSingleChecked(attacker, m.k, IERC20(hook).balanceOf(attacker), "manip.exitSingle");
        } else {
            _exitPropChecked(attacker, IERC20(hook).balanceOf(attacker), "manip.exitProp");
        }
    }

    function x_unlockSandwich(uint256 kp, uint256 dir, uint256 k, uint256 sm, uint256 sa, uint256 kind)
        external
        self
    {
        M memory m = _plan(kp, dir, k, sm, sa, kind, 3);
        Cyc memory c = _cBegin();
        if (m.kind == 2) {
            _attackerJoinProp(m.act, m.ti);
            uint256 lp = IERC20(hook).balanceOf(attacker);
            vm.prank(attacker);
            IERC20(hook).transfer(address(unlocker), lp);
        } else {
            _fund(m.k, m.act, m.ti);
            vm.prank(attacker);
            tokens[m.k].transfer(address(unlocker), m.act);
        }
        _mint(m.ti, attacker, m.move);
        vm.prank(attacker);
        tokens[m.ti].transfer(address(unlocker), m.move);
        P4UnlockActor.Plan memory pl;
        pl.key = m.key;
        pl.zeroForOne = m.z;
        pl.moveIn = m.move;
        pl.kind = uint8(m.kind);
        pl.tokenK = address(tokens[m.k]);
        pl.tokenL = address(tokens[(m.k + 1) % n]);
        pl.amtK = m.act;
        unlocker.run(pl);
        _cEnd(c, m.ti, m.move + m.act, 0, "a_unlockSandwich");
    }

    /// attacker pays SE yield (raises the rate provider read), then trades / zaps.
    function x_yieldThenAct(uint256 k, uint256 g, uint256 i, uint256 j, uint256 s, uint256 kind) external self {
        require(allowYield, "quarantined");
        uint256 b = _bufferedLeg(k);
        SimpleYieldERC4626 v = SimpleYieldERC4626(vaults[b]);
        uint256 gift = bound(g, v.totalAssets() / 10000 + 1, v.totalAssets() / 20 + 2);
        (i, j) = _pair(i, j);
        uint256 amt = _joinCap(bound(s, 1e15, seedEach / 5));
        Cyc memory c = _cBegin();
        _fund(b, gift, i);
        vm.prank(attacker);
        v.simulateYield(gift);
        _mint(i, attacker, amt);
        kind = kind % 3;
        if (kind == 0) {
            uint256 got = _leg(attacker, i, j, amt, 0, caller);
            _leg(attacker, j, i, got, 0, caller);
        } else if (kind == 1) {
            _joinSingleChecked(attacker, i, amt, "yield.joinSingle");
            _exitSingleChecked(attacker, j, IERC20(hook).balanceOf(attacker), "yield.exitSingle");
        } else {
            _joinSingleChecked(attacker, i, amt, "yield.joinSingle");
            _exitPropChecked(attacker, IERC20(hook).balanceOf(attacker), "yield.exitProp");
        }
        _cEnd(c, i, amt + gift, 0, "a_yieldThenAct");
    }

    /// donate raw face or SE shares to the hook, then try to claim them through the pretransfer credit path.
    function x_donateThenClaim(uint256 k, uint256 s, uint256 j, uint256 m) external self {
        k = k % n;
        uint256 jj = j % n;
        if (jj == k) jj = (k + 1) % n;
        uint256 amt = bound(s, 1e12, seedEach / 100);
        Cyc memory c = _cBegin();
        _fund(k, amt, jj);
        if (m % 2 == 1 && ses[k] != address(0)) {
            vm.prank(attacker);(uint256 sh,) = IStandardExchangeIn(ses[k]).exchangeIn(IERC20(address(tokens[k])), amt, IERC20(ses[k]), 0, attacker, false, block.timestamp + 1 hours
            );
            vm.prank(attacker);
            IERC20(ses[k]).transfer(hook, sh);
        } else {
            vm.prank(attacker);
            tokens[k].transfer(hook, amt);
        }
        _trySweep(jj);
        _cEnd(c, jj, amt, 0, "a_donateThenClaim");
    }

    /// claim any unbooked balance on the hook that the attacker did not provide (pure free money probe).
    function x_sweep(uint256 j) external self {
        Cyc memory c = _cBegin();
        _trySweep(j % n);
        _cEnd(c, j % n, 0, 0, "a_sweep");
    }

    /// pretransfer a generous maxIn, exact-out swap; refund goes to msg.sender (attacker contract).
    function x_exactOutRefund(uint256 i, uint256 j, uint256 s, uint256 over) external self {
        (i, j) = _pair(i, j);
        uint256 out = bound(s, 1e12, seedEach / 20);
        Cyc memory c = _cBegin();
        uint256 q = IStandardExchangeOut(hook).previewExchangeOut(IERC20(address(tokens[i])), IERC20(address(tokens[j])), out);
        require(q > 0, "q0");
        uint256 maxIn = q + q * bound(over, 0, 300) / 100;
        _mint(i, attacker, maxIn);
        _seExactOutMax(attacker, i, j, out, maxIn, true, caller);
        _cEnd(c, i, maxIn, 0, "a_exactOutRefund");
    }

    function x_joinUnbalanced(uint256 k, uint256 s, uint256 e) external self {
        k = k % n;
        uint256 amt = _joinCap(bound(s, 1e15, seedEach / 10));
        Cyc memory c = _cBegin();
        uint256[] memory amts = new uint256[](n);
        uint256 total;
        uint256[] memory ratio;
        if (unbalancedPropOnly) {
            ratio = ILiq(hook).previewExitProportional(1e18);
            require(ratio[k] > 0, "ratio");
        }
        for (uint256 i; i < n; ++i) {
            if (unbalancedPropOnly) amts[i] = i == k ? amt : amt * ratio[i] / ratio[k];
            else amts[i] = i == k ? amt : amt * bound(e, 0, 100) / 100;
            if (amts[i] > 0) _fund(i, amts[i], k);
            total += amts[i];
        }
        uint256 pv = _previewJoinUnbalanced(amts);
        uint256 sh = _joinUnbalanced(amts);
        ++exitChecks;
        if (pv == 0) ++previewMissing;
        if (pv > 0 && (sh > pv || sh + sh / 1e12 + 10 < pv)) _exitBreak("joinUnbalanced", pv, sh);
        _cEnd(c, k, total, 0, "a_joinUnbalanced");
    }

    function _previewJoinUnbalanced(uint256[] memory amts) internal view returns (uint256 pv) {
        try ILiq(hook).previewJoinUnbalanced(amts) returns (uint256 p_) {
            return p_;
        } catch {}
        address[] memory toks = new address[](n);
        for (uint256 i; i < n; ++i) {
            toks[i] = address(tokens[i]);
        }
        (bool ok, bytes memory r) =
            hook.staticcall(abi.encodeWithSignature("previewJoinUnbalanced(address[],uint256[])", toks, amts));
        if (ok && r.length >= 32) pv = abi.decode(r, (uint256));
    }

    function _joinUnbalanced(uint256[] memory amts) internal returns (uint256 sh) {
        vm.prank(attacker);
        try ILiq(hook).joinUnbalanced(amts, attacker, 0, block.timestamp + 1 hours) returns (uint256 s_) {
            return s_;
        } catch {}
        address[] memory toks = new address[](n);
        for (uint256 i; i < n; ++i) {
            toks[i] = address(tokens[i]);
        }
        uint256 lp0 = IERC20(hook).balanceOf(attacker);
        vm.prank(attacker);
        (bool ok, bytes memory r) = hook.call(
            abi.encodeWithSignature(
                "joinUnbalanced(address[],uint256[],address,uint256,uint256)", toks, amts, attacker, 0, block.timestamp + 1 hours
            )
        );
        if (!ok) {
            assembly ("memory-safe") {
                revert(add(r, 32), mload(r))
            }
        }
        sh = IERC20(hook).balanceOf(attacker) - lp0;
    }

    /// sequential exit of every LP holder (except a passive remainder) inside a snapshot:
    /// every holder must be paid the same value per share (no first-come advantage / hidden insolvency).
    function x_bankRun() external self {
        _bankRun();
    }

    function checkBankRun() external {
        _bankRun();
    }

    function _bankRun() internal {
        uint256 snap = vm.snapshotState();
        address[7] memory hs =
            [honest[0], honest[1], honest[2], attacker, address(caller), feeTo, passive];
        uint256 lo = type(uint256).max;
        uint256 hi;
        bool failed;
        for (uint256 h; h < 7; ++h) {
            if (hs[h] == address(0)) continue;
            uint256 bal = IERC20(hook).balanceOf(hs[h]);
            if (h == 6) bal = bal / 2;
            if (bal < 1e12) continue;
            uint256 v0 = _tokenValueOf(hs[h]);
            vm.prank(hs[h]);
            try ILiq(hook).exitProportional(bal, hs[h], new uint256[](n), block.timestamp + 1 hours) {
                uint256 ps = (_tokenValueOf(hs[h]) - v0) * WAD / bal;
                if (ps < lo) lo = ps;
                if (ps > hi) hi = ps;
            } catch {
                failed = true;
            }
        }
        vm.revertToStateAndDelete(snap);
        ++bankRuns;
        if (failed || (hi > 0 && lo * (1e12 + 1) < hi * 1e12 - 1e3 * 1e12)) {
            ++bankRunBreaks;
            if (bytes(firstBankRunBreak).length == 0) {
                firstBankRunBreak = string.concat(
                    failed ? "exit failed " : "", "lo=", vm.toString(lo), " hi=", vm.toString(hi)
                );
            }
        }
    }

    // =====================================================================================
    // Cycle accounting
    // =====================================================================================
    struct Cyc {
        uint256 v0;
        uint256 lp0;
        uint256 minted0;
        uint256[] bal0;
    }

    function _balances(address a) internal view returns (uint256[] memory b) {
        b = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            b[i] = tokens[i].balanceOf(a);
        }
    }

    function _cBegin() internal view returns (Cyc memory c) {
        c.v0 = _attackerSideValue();
        c.lp0 = IERC20(hook).balanceOf(attacker);
        c.minted0 = mintedAtk;
        c.bal0 = _balances(attacker);
    }

    function _cEnd(Cyc memory c, uint256 x, uint256 gross, uint256 giftVal, string memory tag) internal {
        _consolidate(attacker, x, c);
        uint256 lpNow = IERC20(hook).balanceOf(attacker);
        uint256 lpVal = lpNow > c.lp0 ? _lpValue(lpNow - c.lp0) : 0;
        int256 pnl = int256(_attackerSideValue() + lpVal) - int256(c.v0) - int256(mintedAtk - c.minted0);
        _recordCycle(pnl, gross, giftVal, tag, x);
    }

    function _cBeginFor(address actor) internal view returns (Cyc memory c) {
        c.v0 = _tokenValueOf(actor) + _tokenValueOf(address(honestCaller));
        c.minted0 = mintedValue;
        c.lp0 = IERC20(hook).balanceOf(actor);
        c.bal0 = _balances(actor);
    }

    function _cEndFor(address actor, Cyc memory c, uint256 x, uint256 gross, string memory tag) internal {
        // pull honest caller refunds back to the actor, consolidate to x
        _drainCaller(honestCaller, actor);
        _consolidate(actor, x, c);
        int256 pnl = int256(_tokenValueOf(actor) + _tokenValueOf(address(honestCaller))) - int256(c.v0)
            - int256(mintedValue - c.minted0);
        _recordCycle(pnl, gross, 0, tag, x);
    }

    function _recordCycle(int256 pnl, uint256 gross, uint256 giftVal, string memory tag, uint256 x) internal {
        ++cycles;
        attackerCumulative += pnl;
        if (pnl > worstCycle) worstCycle = pnl;
        uint256 tol = 1e9 + gross / 1e12 + giftVal * 2 / 100;
        if (pnl > int256(tol)) {
            ++cycleBreaks;
            if (bytes(firstCycleBreak).length == 0) {
                firstCycleBreak = string.concat(
                    tag, " x=", vm.toString(x), " gross=", vm.toString(gross), " pnl=", vm.toString(pnl)
                );
            }
        }
    }

    /// convert everything the actor-side gained in this cycle back into token x
    /// (LP gained via single exit, other tokens gained via SE swap). Pre-existing holdings are untouched.
    function _consolidate(address actor, uint256 x, Cyc memory c) internal {
        if (actor == attacker) {
            _drainCaller(caller, attacker);
            address[] memory all = new address[](n + 1);
            for (uint256 i; i < n; ++i) {
                all[i] = address(tokens[i]);
            }
            all[n] = hook;
            unlocker.sweep(all, attacker);
            uint256 clp = IERC20(hook).balanceOf(address(caller));
            if (clp > 0) caller.execute(hook, abi.encodeCall(IERC20.transfer, (attacker, clp)));
        }
        uint256 lpNow = IERC20(hook).balanceOf(actor);
        if (lpNow > c.lp0) {
            uint256 lp = lpNow - c.lp0;
            vm.prank(actor);try IStandardExchangeIn(hook).exchangeIn(IERC20(hook), lp, IERC20(address(tokens[x])), 0, actor, false, block.timestamp + 1 hours) {}
            catch {
                vm.prank(actor);
                try ILiq(hook).exitProportional(lp, actor, new uint256[](n), block.timestamp + 1 hours) {
                    ++consolidateFallback;
                } catch {}
            }
        }
        for (uint256 k; k < n; ++k) {
            if (k == x) continue;
            _swapBackChunked(actor, k, x, c.bal0[k]);
        }
        // closure: a cycle that cannot be fully unwound back into x is rolled back (counted as a failed action),
        // otherwise a stranded position would let the NEXT cycle harvest a legit arbitrage and look like a break.
        if (IERC20(hook).balanceOf(actor) > c.lp0 + 1e9) _revertUnclosed();
        for (uint256 k; k < n; ++k) {
            if (k == x) continue;
            uint256 b = tokens[k].balanceOf(actor);
            if (b > c.bal0[k] + 1e12) _revertUnclosed();
        }
    }

    function _swapBackChunked(address actor, uint256 k, uint256 x, uint256 base) internal {
        for (uint256 it; it < 12; ++it) {
            uint256 b = tokens[k].balanceOf(actor);
            if (b <= base + 1e9) return;
            uint256 excess = b - base;
            uint256 chunk = excess;
            bool done;
            for (uint256 h; h < 6 && !done; ++h) {
                uint256 q;try IStandardExchangeIn(hook).previewExchangeIn(IERC20(address(tokens[k])), chunk, IERC20(address(tokens[x]))) returns (uint256 q_, uint256) { q = q_; } catch {}
                if (q > 0) {
                    try this.seInExt(actor, k, x, chunk) { done = true; } catch {}
                }
                if (!done) chunk /= 2;
                if (chunk < 1e9) return;
            }
            if (!done) return;
        }
    }

    function _drainCaller(AtomicPretransferCaller cl, address to) internal {
        for (uint256 i; i < n; ++i) {
            uint256 b = tokens[i].balanceOf(address(cl));
            if (b > 0) cl.execute(address(tokens[i]), abi.encodeCall(IERC20.transfer, (to, b)));
        }
    }

    // =====================================================================================
    // Instrumented primitives
    // =====================================================================================
    /// one swap leg i->j by path: 0 SE exactIn, 1 SE exactIn pretransferred (contract), 2 SE exactOut, 3 PM swap
    function _leg(address actor, uint256 i, uint256 j, uint256 amt, uint256 path, AtomicPretransferCaller cl)
        internal
        returns (uint256 got)
    {
        if (path == 3) {
            (bool has, PoolKey memory key, bool z) = _keyFor(i, j);
            if (has) return _pmSwapChecked(actor, key, z, amt, i, j);
            path = 0;
        }
        if (path == 2) {(uint256 q,) = IStandardExchangeIn(hook).previewExchangeIn(IERC20(address(tokens[i])), amt, IERC20(address(tokens[j])));
            require(q > 1, "q");
            // exact out for ~half the reachable output, maxIn = amt (the rest stays with the actor)
            return _seExactOutMax(actor, i, j, q / 2, amt, false, cl);
        }
        return _seIn(actor, i, j, amt, path == 1, cl);
    }

    function _seIn(address actor, uint256 i, uint256 j, uint256 amt, bool pre, AtomicPretransferCaller cl)
        internal
        returns (uint256 got)
    {
        SI memory v;
        v.i = i;
        v.j = j;
        v.pre = pre;
        v.amt = amt;(v.q,) = IStandardExchangeIn(hook).previewExchangeIn(IERC20(address(tokens[i])), amt, IERC20(address(tokens[j])));
        uint256 b0 = tokens[j].balanceOf(actor);
        got = _seInExec(actor, i, j, amt, pre, cl);
        v.got = got;
        v.d = tokens[j].balanceOf(actor) - b0;
        _checkSeIn(v);
    }

    struct SI {
        uint256 i;
        uint256 j;
        bool pre;
        uint256 amt;
        uint256 q;
        uint256 got;
        uint256 d;
    }

    function _seInExec(address actor, uint256 i, uint256 j, uint256 amt, bool pre, AtomicPretransferCaller cl)
        internal
        returns (uint256 got)
    {
        bytes memory data = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (IERC20(address(tokens[i])), amt, IERC20(address(tokens[j])), 0, actor, pre, block.timestamp + 1 hours)
        );
        bytes memory r;
        if (pre) {
            r = cl.consumePretransfer(IERC20(address(tokens[i])), actor, hook, amt, data);
        } else {
            vm.prank(actor);
            bool ok;
            (ok, r) = hook.call(data);
            if (!ok) {
                assembly ("memory-safe") {
                    revert(add(r, 32), mload(r))
                }
            }
        }
        (got,) = abi.decode(r, (uint256, uint256));
    }

    uint256 public preInShort; // pretransferred exact-in paid less than preview (H6-class, self-harm), not a break
    uint256 public preInShortWorstPpm;
    uint256 public preOutOver; // pretransferred exact-out charged more than preview (H6-class), not a break
    uint256 public preOutOverWorstPpm;
    string public firstPreOutOver;

    function _checkSeIn(SI memory v) internal {
        ++quoteChecks;
        if (v.pre && v.d == v.got && v.got < v.q && v.got + v.got / 1e12 + 10 < v.q) {
            ++preInShort;
            uint256 ppm = (v.q - v.got) * 1e6 / v.q;
            if (ppm > preInShortWorstPpm) preInShortWorstPpm = ppm;
            return;
        }
        if (v.d != v.got || v.got > v.q || v.got + v.got / 1e12 + 10 < v.q) {
            ++quoteBreaks;
            if (bytes(firstQuoteBreak).length == 0) {
                firstQuoteBreak = string.concat(
                    string.concat("seIn i=", vm.toString(v.i), " j=", vm.toString(v.j), " pre=", v.pre ? "1" : "0"),
                    string.concat(" amt=", vm.toString(v.amt), " q=", vm.toString(v.q), " got=", vm.toString(v.got)),
                    string.concat(" delivered=", vm.toString(v.d))
                );
            }
        }
    }

    function _seInNoRevert(address actor, uint256 i, uint256 j, uint256 amt) internal {
        try this.seInExt(actor, i, j, amt) {} catch {}
    }

    function seInExt(address actor, uint256 i, uint256 j, uint256 amt) external self {
        _seIn(actor, i, j, amt, false, caller);
    }

    function _seExactOut(address actor, uint256 i, uint256 j, uint256 out, bool pre, AtomicPretransferCaller cl)
        internal
        returns (uint256)
    {
        uint256 q = IStandardExchangeOut(hook).previewExchangeOut(IERC20(address(tokens[i])), IERC20(address(tokens[j])), out);
        require(q > 0 && tokens[i].balanceOf(actor) >= q, "eo");
        return _seExactOutMax(actor, i, j, out, q, pre, cl);
    }

    struct EO {
        IERC20 ti;
        IERC20 tj;
        address actor;
        AtomicPretransferCaller cl;
        uint256 out;
        uint256 maxIn;
        bool pre;
        uint256 q;
        uint256 in0;
        uint256 out0;
        uint256 cl0;
        uint256 used;
        uint256 netPaid;
        uint256 delivered;
    }

    /// exact-out i->j for `out`, paying at most maxIn. Returns amount of j received.
    function _seExactOutMax(
        address actor,
        uint256 i,
        uint256 j,
        uint256 out,
        uint256 maxIn,
        bool pre,
        AtomicPretransferCaller cl
    ) internal returns (uint256) {
        EO memory e;
        e.ti = IERC20(address(tokens[i]));
        e.tj = IERC20(address(tokens[j]));
        e.actor = actor;
        e.cl = cl;
        e.out = out;
        e.maxIn = maxIn;
        e.pre = pre;
        _eoExec(e);
        _checkEO(e, i, j, out, pre);
        return out;
    }

    function _eoExec(EO memory e) internal {
        e.q = IStandardExchangeOut(hook).previewExchangeOut(e.ti, e.tj, e.out);
        require(e.q > 0 && e.q <= e.maxIn, "eoq");
        e.in0 = e.ti.balanceOf(e.actor);
        e.out0 = e.tj.balanceOf(e.actor);
        e.cl0 = e.ti.balanceOf(address(e.cl));
        if (e.pre) {
            bytes memory data = abi.encodeCall(
                IStandardExchangeOut.exchangeOut, (e.ti, e.maxIn, e.tj, e.out, e.actor, true, block.timestamp + 1 hours)
            );
            bytes memory r = e.cl.consumePretransfer(e.ti, e.actor, hook, e.maxIn, data);
            e.used = abi.decode(r, (uint256));
            e.netPaid = (e.in0 - e.ti.balanceOf(e.actor)) - (e.ti.balanceOf(address(e.cl)) - e.cl0);
        } else {
            vm.prank(e.actor);
            e.used = IStandardExchangeOut(hook).exchangeOut(e.ti, e.maxIn, e.tj, e.out, e.actor, false, block.timestamp + 1 hours);
            e.netPaid = e.in0 - e.ti.balanceOf(e.actor);
        }
        e.delivered = e.tj.balanceOf(e.actor) - e.out0;
    }

    function _checkEO(EO memory e, uint256 i, uint256 j, uint256 out, bool pre) internal {
        ++quoteChecks;
        if (pre && e.delivered == out && e.netPaid == e.used && e.used > e.q) {
            ++preOutOver;
            uint256 ppm = (e.used - e.q) * 1e6 / e.q;
            if (ppm > preOutOverWorstPpm) preOutOverWorstPpm = ppm;
            if (bytes(firstPreOutOver).length == 0) {
                firstPreOutOver = string.concat(
                    string.concat("i=", vm.toString(i), " j=", vm.toString(j), " out=", vm.toString(out)),
                    string.concat(" maxIn=", vm.toString(e.maxIn), " q=", vm.toString(e.q), " used=", vm.toString(e.used))
                );
            }
            return;
        }
        if (e.delivered != out || e.netPaid != e.used || e.used > e.q) {
            ++quoteBreaks;
            if (bytes(firstQuoteBreak).length == 0) {
                firstQuoteBreak = string.concat(
                    string.concat("seExactOut i=", vm.toString(i), " j=", vm.toString(j), " pre=", pre ? "1" : "0"),
                    string.concat(" out=", vm.toString(out), " delivered=", vm.toString(e.delivered), " q=", vm.toString(e.q)),
                    string.concat(" used=", vm.toString(e.used), " netPaid=", vm.toString(e.netPaid))
                );
            }
        }
    }

    function _pmSwap(address actor, PoolKey memory key, bool z, uint256 amt) internal returns (uint256 got) {
        IERC20 tin = IERC20(Currency.unwrap(z ? key.currency0 : key.currency1));
        IERC20 tout = IERC20(Currency.unwrap(z ? key.currency1 : key.currency0));
        require(tin.balanceOf(actor) >= amt, "pmbal");
        uint256 b0 = tout.balanceOf(actor);
        vm.prank(actor);
        router.swapExactIn(key, SwapParams(z, -int256(amt), z ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), "");
        got = tout.balanceOf(actor) - b0;
    }

    function _pmSwapChecked(address actor, PoolKey memory key, bool z, uint256 amt, uint256 i, uint256 j)
        internal
        returns (uint256 got)
    {(uint256 q,) = IStandardExchangeIn(hook).previewExchangeIn(IERC20(address(tokens[i])), amt, IERC20(address(tokens[j])));
        got = _pmSwap(actor, key, z, amt);
        ++pmQuoteChecks;
        int256 d = int256(got) - int256(q);
        if (d > worstPmVsQuote) worstPmVsQuote = d;
        if (got > q + 10) ++pmOverQuote;
    }

    function _joinSingleChecked(address actor, uint256 i, uint256 amt, string memory tag) internal returns (uint256 sh) {
        IERC20 ti = IERC20(address(tokens[i]));
        uint256 pv;try IStandardExchangeIn(hook).previewExchangeIn(ti, amt, IERC20(hook)) returns (uint256 p_, uint256) { pv = p_; } catch {}
        uint256 lp0 = IERC20(hook).balanceOf(actor);
        vm.prank(actor);(sh,) = IStandardExchangeIn(hook).exchangeIn(ti, amt, IERC20(hook), 0, actor, false, block.timestamp + 1 hours);
        ++exitChecks;
        if (pv == 0) ++previewMissing;
        if (IERC20(hook).balanceOf(actor) - lp0 != sh || (pv > 0 && (sh > pv || sh + sh / 1e12 + 10 < pv))) {
            _exitBreak(tag, pv, sh);
        }
    }

    function _exitSingleChecked(address actor, uint256 i, uint256 sh, string memory tag) internal returns (uint256 got) {
        IERC20 ti = IERC20(address(tokens[i]));
        uint256 pv;try IStandardExchangeIn(hook).previewExchangeIn(IERC20(hook), sh, ti) returns (uint256 p_, uint256) { pv = p_; } catch {}
        uint256 b0 = ti.balanceOf(actor);
        vm.prank(actor);(got,) = IStandardExchangeIn(hook).exchangeIn(IERC20(hook), sh, ti, 0, actor, false, block.timestamp + 1 hours);
        uint256 d = ti.balanceOf(actor) - b0;
        ++exitChecks;
        if (pv == 0) ++previewMissing;
        if (d != got || (pv > 0 && got == 0) || (pv > 0 && (got > pv || got + got / 1e12 + 10 < pv))) {
            _exitBreak(tag, pv, got);
        }
    }

    function _exitPropChecked(address actor, uint256 sh, string memory tag) internal {
        uint256[] memory pv = ILiq(hook).previewExitProportional(sh);
        uint256 pvVal;
        for (uint256 i; i < pv.length; ++i) {
            pvVal += pv[i] * prices[i] / WAD;
        }
        uint256 v0 = _tokenValueOf(actor);
        vm.prank(actor);
        ILiq(hook).exitProportional(sh, actor, new uint256[](n), block.timestamp + 1 hours);
        uint256 got = _tokenValueOf(actor) - v0;
        ++exitChecks;
        if ((pvVal > 0 && got == 0) || got > pvVal + 10 || got + got / 1e12 + 10 < pvVal) _exitBreak(tag, pvVal, got);
    }

    function _attackerJoinProp(uint256 amt, uint256 x) internal {
        uint256[] memory amts = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            amts[i] = amt;
            _fund(i, amt, x);
        }
        vm.prank(attacker);
        ILiq(hook).joinProportional(amts, attacker, 0, block.timestamp + 1 hours);
    }

    function _exitBreak(string memory tag, uint256 pv, uint256 got) internal {
        ++exitBreaks;
        if (bytes(firstExitBreak).length == 0) {
            firstExitBreak = string.concat(tag, " preview=", vm.toString(pv), " got=", vm.toString(got));
        }
    }

    /// try to claim unbooked balance of every leg via pretransferred=true without sending anything.
    function _trySweep(uint256 j) internal returns (uint256 gained) {
        uint256 tried0 = sweepProbesTried;
        for (uint256 k; k < n; ++k) {
            uint256 tgt = k == j ? (j + 1) % n : j;
            uint256 bal = tokens[k].balanceOf(hook);
            uint256 booked;
            if (ses[k] == address(0)) {
                try IP4Book(hook).reserveOfToken(address(tokens[k])) returns (uint256 r) { booked = r; } catch {}
            }
            uint256 u = bal > booked ? bal - booked : 0;
            uint256[3] memory probes = [u, u / 2, uint256(1e12)];
            for (uint256 p; p < 3; ++p) {
                if (probes[p] == 0 || probes[p] > bal) continue;
                bytes memory data = abi.encodeCall(
                    IStandardExchangeIn.exchangeIn,
                    (IERC20(address(tokens[k])), probes[p], IERC20(address(tokens[tgt])), 0, attacker, true, block.timestamp + 1 hours)
                );
                ++sweepProbesTried;
                try caller.execute(hook, data) returns (bytes memory r) {
                    ++sweepProbesOk;
                    (uint256 got,) = abi.decode(r, (uint256, uint256));
                    if (got > 0) {
                        ++sweepGains;
                        sweepValue += got * prices[tgt] / WAD;
                        gained += got;
                    }
                    break;
                } catch {}
            }
        }
        if (sweepProbesTried > tried0) ++sweepActionsEffective;
    }

    // =====================================================================================
    // Valuation helpers
    // =====================================================================================
    /// closed-cycle funding: the attacker only has capital in token x; any other token is bought from the
    /// hook with an exact-out swap (so every cycle starts and ends in x and is price-free).
    function _fund(uint256 k, uint256 amt, uint256 x) internal {
        if (k == x) {
            _mint(x, attacker, amt);
            return;
        }
        uint256 q = IStandardExchangeOut(hook).previewExchangeOut(IERC20(address(tokens[x])), IERC20(address(tokens[k])), amt);
        require(q > 0, "fundq");
        _mint(x, attacker, q);
        _seExactOutMax(attacker, x, k, amt, q, false, caller);
    }

    function _mint(uint256 i, address to, uint256 amt) internal {
        tokens[i].mint(to, amt);
        uint256 v = amt * prices[i] / WAD;
        mintedValue += v;
        if (to == attacker) mintedAtk += v;
    }

    function _tokenValueOf(address a) internal view returns (uint256 v) {
        for (uint256 i; i < n; ++i) {
            v += tokens[i].balanceOf(a) * prices[i] / WAD;
        }
    }

    function _attackerSideValue() internal view returns (uint256) {
        return _tokenValueOf(attacker) + _tokenValueOf(address(caller)) + _tokenValueOf(address(unlocker));
    }

    function _actorTokenValue() internal view returns (uint256 v) {
        v = _attackerSideValue() + _tokenValueOf(passive) + _tokenValueOf(address(honestCaller)) + _seValueOf(feeTo);
        for (uint256 h; h < 3; ++h) {
            v += _tokenValueOf(honest[h]);
        }
    }

    /// hook assets at fair price: raw face + SE shares redeemed through the SE's own (fee-free) unwrap quote.
    function _hookTVL() public view returns (uint256 v) {
        for (uint256 i; i < n; ++i) {
            v += tokens[i].balanceOf(hook) * prices[i] / WAD;
        }
        v += _seValueOf(hook);
    }

    /// SE shares held by `a` (all legs) valued via SE unwrap preview. Includes the SE dilution-fee sink (feeTo).
    function _seValueOf(address a) internal view returns (uint256 v) {
        if (a == address(0)) return 0;
        for (uint256 i; i < n; ++i) {
            if (ses[i] == address(0)) continue;
            uint256 sh = IERC20(ses[i]).balanceOf(a);
            if (sh == 0) continue;try IStandardExchangeIn(ses[i]).previewExchangeIn(IERC20(ses[i]), sh, IERC20(address(tokens[i]))) returns (uint256 a_, uint256) {
                v += a_ * prices[i] / WAD;
            } catch {}
        }
    }

    function _lpValue(uint256 sh) internal view returns (uint256 v) {
        if (sh == 0) return 0;
        try ILiq(hook).previewExitProportional(sh) returns (uint256[] memory a) {
            for (uint256 i; i < a.length; ++i) {
                v += a[i] * prices[i] / WAD;
            }
        } catch {}
    }

    function _passivePerShare() internal view returns (uint256) {
        uint256 bal = IERC20(hook).balanceOf(passive);
        uint256 probe = bal / 10;
        if (probe == 0) return 0;
        return _lpValue(probe) * WAD / probe;
    }

    function dumpState(string memory tag) external view {
        console2.log("---- dump:", tag);
        console2.log("  totalSupply", IERC20(hook).totalSupply());
        console2.log("  LP passive ", IERC20(hook).balanceOf(passive));
        console2.log("  LP attacker", IERC20(hook).balanceOf(attacker));
        console2.log("  LP feeTo   ", IERC20(hook).balanceOf(feeTo));
        console2.log("  LP hook    ", IERC20(hook).balanceOf(hook));
        console2.log("  LP unlocker/caller", IERC20(hook).balanceOf(address(unlocker)), IERC20(hook).balanceOf(address(caller)));
        console2.log("  LP addr0   ", IERC20(hook).balanceOf(address(0)));
        for (uint256 i; i < n; ++i) {
            console2.log("  token", i);
            console2.log("    hook raw  ", tokens[i].balanceOf(hook));
            if (ses[i] != address(0)) console2.log("    hook SE sh", IERC20(ses[i]).balanceOf(hook));
            console2.log("    attacker  ", tokens[i].balanceOf(attacker));
        }
        uint256[] memory pv = ILiq(hook).previewExitProportional(1e18);
        for (uint256 i; i < pv.length; ++i) {
            console2.log("  previewExitProportional(1e18)[i]", i, pv[i]);
        }
        console2.log("  passivePerShare", _passivePerShare());
        console2.log("  TVL", _hookTVL());
    }

    function feeToSeValue() external view returns (uint256) {
        return _seValueOf(feeTo);
    }

    function hookTVL() external view returns (uint256) {
        return _hookTVL();
    }

    function passivePerShare() external view returns (uint256) {
        return _passivePerShare();
    }

    function _joinCap(uint256 amt) internal view returns (uint256) {
        if (!orbital || IERC20(hook).totalSupply() == 0) return amt;
        (uint256 e0, uint256 e1, uint256 e2) = IP4Orbital(hook).effectiveReserves();
        uint256 largest = e0 > e1 ? e0 : e1;
        if (e2 > largest) largest = e2;
        uint256 r = IP4Orbital(hook).radius();
        uint256 cap = r > largest ? (r - largest) / 4 : 0;
        require(cap > 1e12, "orbital headroom");
        return amt > cap ? cap : amt;
    }

    function _pair(uint256 i, uint256 j) internal view returns (uint256, uint256) {
        i = i % n;
        j = j % n;
        if (i == j) j = (i + 1) % n;
        return (i, j);
    }

    function _idx(address t) internal view returns (uint256) {
        for (uint256 i; i < n; ++i) {
            if (address(tokens[i]) == t) return i;
        }
        revert("idx");
    }

    function _bufferedLeg(uint256 k) internal view returns (uint256) {
        for (uint256 d; d < n; ++d) {
            uint256 i = (k + d) % n;
            if (vaults[i] != address(0)) return i;
        }
        revert("nobuf");
    }

    function _keyFor(uint256 i, uint256 j) internal view returns (bool, PoolKey memory key, bool z) {
        address a = address(tokens[i]);
        address b = address(tokens[j]);
        for (uint256 k; k < keys.length; ++k) {
            address c0 = Currency.unwrap(keys[k].currency0);
            address c1 = Currency.unwrap(keys[k].currency1);
            if (c0 == a && c1 == b) return (true, keys[k], true);
            if (c0 == b && c1 == a) return (true, keys[k], false);
        }
        return (false, key, false);
    }

    // =====================================================================================
    // Reporting
    // =====================================================================================
    function logStats() external view {
        console2.log("=== p4-hooks family:", family);
        uint256 ta;
        uint256 ts;
        for (uint256 i; i < N_ACTIONS; ++i) {
            console2.log(string.concat("  ", names[i], " ok/attempt ", vm.toString(successes[i]), "/", vm.toString(attempts[i]), " lastRevert ", vm.toString(abi.encodePacked(lastRevert[i]))));
            ta += attempts[i];
            ts += successes[i];
        }
        console2.log("  TOTAL ok/attempt", ts, ta);
        console2.log("  cycles", cycles, "cycleBreaks", cycleBreaks);
        console2.log("  worstCycle pnl (wei)");
        console2.logInt(worstCycle);
        console2.log("  attackerCumulative (wei)");
        console2.logInt(attackerCumulative);
        console2.log("  exogenous yield into hook TVL", exogenous);
        console2.log("  quoteChecks", quoteChecks, "quoteBreaks", quoteBreaks);
        console2.log("  preInShort (H6-class)", preInShort, "worst ppm", preInShortWorstPpm);
        console2.log("  preOutOver (H6-class)", preOutOver, "worst ppm", preOutOverWorstPpm);
        if (bytes(firstPreOutOver).length > 0) console2.log("  firstPreOutOver:", firstPreOutOver);
        console2.log("  pmQuoteChecks", pmQuoteChecks, "pmOverQuote", pmOverQuote);
        console2.logInt(worstPmVsQuote);
        console2.log("  exitChecks", exitChecks, "exitBreaks", exitBreaks);
        console2.log("  consChecks", consChecks, "consBreaks", consBreaks);
        console2.logInt(worstLeak);
        console2.log("  lpPerShare init/min", lpPerShareInit, lpPerShareMin);
        console2.log("  lpBreaks", lpBreaks);
        console2.log("  bankRuns", bankRuns, "bankRunBreaks", bankRunBreaks);
        console2.log("  sweepGains", sweepGains, "sweepValue", sweepValue);
        console2.log("  sweepProbes tried/ok", sweepProbesTried, sweepProbesOk);
        console2.log("  sweepActionsEffective", sweepActionsEffective);
        console2.log("  previewMissing (INV-3 skipped)", previewMissing, "consolidateFallback", consolidateFallback);
        console2.log("  lpAdvChecks", lpAdvChecks, "lpAdvBreaks", lpAdvBreaks);
        {
            string memory u = "  unclosed rollbacks per selector:";
            for (uint256 i; i < N_ACTIONS; ++i) {
                if (unclosed[i] > 0) u = string.concat(u, " ", names[i], "=", vm.toString(unclosed[i]));
            }
            console2.log(u);
        }
        if (bytes(firstLpAdvBreak).length > 0) console2.log("  firstLpAdvBreak:", firstLpAdvBreak);
        if (bytes(firstCycleBreak).length > 0) console2.log("  firstCycleBreak:", firstCycleBreak);
        if (bytes(firstQuoteBreak).length > 0) console2.log("  firstQuoteBreak:", firstQuoteBreak);
        if (bytes(firstExitBreak).length > 0) console2.log("  firstExitBreak:", firstExitBreak);
        if (bytes(firstConsBreak).length > 0) console2.log("  firstConsBreak:", firstConsBreak);
        if (bytes(firstLpBreak).length > 0) console2.log("  firstLpBreak:", firstLpBreak);
        if (bytes(firstBankRunBreak).length > 0) console2.log("  firstBankRunBreak:", firstBankRunBreak);
    }

    /// append one CSV line per campaign run (aggregated off-chain for cross-run non-vacuity evidence)
    function appendStats(string memory path) external {
        string memory line = string.concat(family, ",ok");
        for (uint256 i; i < N_ACTIONS; ++i) {
            line = string.concat(line, ",", vm.toString(successes[i]));
        }
        line = string.concat(line, ",att");
        for (uint256 i; i < N_ACTIONS; ++i) {
            line = string.concat(line, ",", vm.toString(attempts[i]));
        }
        line = string.concat(
            line,
            string.concat(",cycles,", vm.toString(cycles), ",quote,", vm.toString(quoteChecks), ",exit,", vm.toString(exitChecks)),
            string.concat(",cons,", vm.toString(consChecks), ",bank,", vm.toString(bankRuns), ",pm,", vm.toString(pmQuoteChecks)),
            string.concat(",preIn,", vm.toString(preInShort), ",preOut,", vm.toString(preOutOver), ",sweep,", vm.toString(sweepGains))
        );
        uint256 unc;
        for (uint256 i; i < N_ACTIONS; ++i) {
            unc += unclosed[i];
        }
        line = string.concat(
            line,
            string.concat(",unclosed,", vm.toString(unc), ",probeTried,", vm.toString(sweepProbesTried), ",probeOk,", vm.toString(sweepProbesOk)),
            string.concat(",pvMiss,", vm.toString(previewMissing), ",lpAdv,", vm.toString(lpAdvChecks), ",lpAdvBrk,", vm.toString(lpAdvBreaks))
        );
        vm.writeLine(path, line);
    }

    function totals() external view returns (uint256 ok, uint256 tried) {
        for (uint256 i; i < N_ACTIONS; ++i) {
            ok += successes[i];
            tried += attempts[i];
        }
    }
}
