// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {
    SwapKind,
    VaultSwapParams,
    AddLiquidityParams,
    AddLiquidityKind,
    RemoveLiquidityParams,
    RemoveLiquidityKind
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

/* ------------------------------------------------------------------------------------------ */
/*  Minimal address-typed interfaces (ABI-identical to the real ones; avoids type plumbing).   */
/* ------------------------------------------------------------------------------------------ */

interface IP4Mint {
    function mint(address to, uint256 amount) external;
}

interface IP4Permit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

interface IP4BRouter {
    function swapSingleTokenExactIn(address pool, address tokenIn, address tokenOut, uint256 exactAmountIn, uint256 minAmountOut, uint256 deadline, bool wethIsEth, bytes calldata userData) external payable returns (uint256);
    function swapSingleTokenExactOut(address pool, address tokenIn, address tokenOut, uint256 exactAmountOut, uint256 maxAmountIn, uint256 deadline, bool wethIsEth, bytes calldata userData) external payable returns (uint256);
    function querySwapSingleTokenExactOut(address pool, address tokenIn, address tokenOut, uint256 exactAmountOut, address sender, bytes calldata userData) external returns (uint256);
    function addLiquidityUnbalanced(address pool, uint256[] memory exactAmountsIn, uint256 minBptAmountOut, bool wethIsEth, bytes memory userData) external payable returns (uint256);
    function addLiquidityProportional(address pool, uint256[] memory maxAmountsIn, uint256 exactBptAmountOut, bool wethIsEth, bytes memory userData) external payable returns (uint256[] memory);
    function donate(address pool, uint256[] memory amountsIn, bool wethIsEth, bytes memory userData) external payable;
    function removeLiquidityProportional(address pool, uint256 exactBptAmountIn, uint256[] memory minAmountsOut, bool wethIsEth, bytes memory userData) external payable returns (uint256[] memory);
    function removeLiquiditySingleTokenExactOut(address pool, uint256 maxBptAmountIn, address tokenOut, uint256 exactAmountOut, bool wethIsEth, bytes memory userData) external payable returns (uint256);
}

interface IP4SERouter {
    function swapSingleTokenExactIn(address pool, address tokenIn, address tokenInVault, address tokenOut, address tokenOutVault, uint256 exactAmountIn, uint256 minAmountOut, uint256 deadline, bool wethIsEth, bytes calldata userData) external payable returns (uint256);
    function swapSingleTokenExactOut(address pool, address tokenIn, address tokenInVault, address tokenOut, address tokenOutVault, uint256 exactAmountOut, uint256 maxAmountIn, uint256 deadline, bool wethIsEth, bytes calldata userData) external payable returns (uint256);
    function querySwapSingleTokenExactOut(address pool, address tokenIn, address tokenInVault, address tokenOut, address tokenOutVault, uint256 exactAmountOut, address sender, bytes calldata userData) external returns (uint256);
    function prepaySessionActive() external view returns (bool);
}

interface IP4BufPool {
    function virtualTTA() external view returns (uint256);
    function hookSharesDelta() external view returns (int256);
    function ttaIndex() external view returns (uint256);
    function sharesIndex() external view returns (uint256);
    function baselineRate() external view returns (uint256);
    function exchangeIn(address tokenIn, uint256 amountIn, address tokenOut, uint256 minOut, address to, bool prepaid, uint256 deadline) external returns (uint256);
}

interface IP4AeroPool {
    function getReserves() external view returns (uint256, uint256, uint256);
    function token0() external view returns (address);
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function totalSupply() external view returns (uint256);
}

interface IP4AeroRouter {
    function addLiquidity(address tokenA, address tokenB, bool stable, uint256 aDesired, uint256 bDesired, uint256 aMin, uint256 bMin, address to, uint256 deadline) external returns (uint256, uint256, uint256);
}

interface IP4SEVault {
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

interface IP4RP {
    function getRate() external view returns (uint256);
}

struct P4Env {
    IVault vault;
    address router; // Balancer RouterMock
    address seRouter; // IndexedEx BalancerV3StandardExchangeRouter diamond (prepay-capable)
    address pool; // StandardExchangeBufferPool (constProd) diamond = BPT
    address seVault; // Aerodrome DAI/USDC SE vault = share token
    address tta; // DAI
    address usdc;
    address aeroPool;
    address aeroRouter;
    address permit2;
    address rp; // StandardExchangeRateProvider (pool's WITH_RATE provider)
}

/* ------------------------------------------------------------------------------------------ */
/*  Adversary: unprivileged contract that drives the Balancer Vault directly inside its own    */
/*  unlock. It deliberately does NOT implement prepaySessionActive() (QUARANTINE of the known  */
/*  hook-midstate-reentrancy callback path).                                                    */
/* ------------------------------------------------------------------------------------------ */

contract P4Adversary {
    struct Op {
        uint8 kind;
        uint256 a;
    }

    uint8 internal constant K_SWAP_TTA_IN = 0;
    uint8 internal constant K_SWAP_SH_IN = 1;
    uint8 internal constant K_SWAP_TTA_IN_EXOUT = 2;
    uint8 internal constant K_SWAP_SH_IN_EXOUT = 3;
    uint8 internal constant K_ADD_UNBAL_TTA = 4;
    uint8 internal constant K_ADD_UNBAL_SH = 5;
    uint8 internal constant K_ADD_PROP = 6;
    uint8 internal constant K_REMOVE_PROP = 7;
    uint8 internal constant K_REMOVE_EXOUT_TTA = 8;
    uint8 internal constant K_REMOVE_EXOUT_SH = 9;
    uint8 internal constant K_DONATE = 10;
    uint8 internal constant K_NATIVE_JOIN_TTA = 11;
    uint8 internal constant K_NATIVE_JOIN_SH = 12;
    uint8 internal constant K_AERO_MOVE = 13;
    // KNOWN-BUG kinds (quarantined unless allowKnown): balancer-buffer-computebalance-domain
    uint8 internal constant K_KNOWN_REMOVE_EXIN_SH = 14;
    uint8 internal constant K_KNOWN_ADD_EXOUT_TTA = 15;
    // Separately-switchable kind (used to quarantine a NEW finding for deeper hunting)
    uint8 public constant N_KINDS = 16;

    IVault public immutable vault;
    address public immutable handler;
    address public immutable pool;
    IERC20 public immutable tta;
    IERC20 public immutable shares;
    IERC20 public immutable usdc;
    address public immutable aeroPool;
    uint256 public immutable ttaIdx;
    uint256 public immutable shIdx;

    bool internal _allowKnown;

    constructor(P4Env memory e, address handler_) {
        vault = e.vault;
        handler = handler_;
        pool = e.pool;
        tta = IERC20(e.tta);
        shares = IERC20(e.seVault);
        usdc = IERC20(e.usdc);
        aeroPool = e.aeroPool;
        ttaIdx = IP4BufPool(e.pool).ttaIndex();
        shIdx = IP4BufPool(e.pool).sharesIndex();
    }

    modifier onlyHandler() {
        require(msg.sender == handler, "adv:H");
        _;
    }

    function exec(address t, bytes calldata d) external onlyHandler returns (bytes memory r) {
        bool ok;
        (ok, r) = t.call(d);
        require(ok, "adv:exec");
    }

    function run(Op[] calldata ops, bool allowKnown_) external onlyHandler returns (uint256 mask) {
        _allowKnown = allowKnown_;
        bytes memory ret = vault.unlock(abi.encodeCall(this.onUnlock, (ops)));
        mask = abi.decode(ret, (uint256));
        _allowKnown = false;
    }

    function onUnlock(Op[] calldata ops) external returns (uint256 mask) {
        require(msg.sender == address(vault), "adv:V");
        for (uint256 i; i < ops.length; ++i) {
            try this.doOp(ops[i]) {
                mask |= (1 << i);
            } catch {}
        }
        _exitAllBpt();
        _normalize();
    }

    /* --------------------------------- state helpers --------------------------------- */

    function _b(uint256 x, uint256 lo, uint256 hi) internal pure returns (uint256) {
        if (hi <= lo) return lo;
        return lo + (x % (hi - lo + 1));
    }

    function _state() internal view returns (uint256 vt, uint256 dRaw, uint256 rawSh, uint256 rawTta, uint256 supply, uint256 bpt) {
        (,, uint256[] memory raw,) = vault.getPoolTokenInfo(pool);
        rawSh = raw[shIdx];
        rawTta = raw[ttaIdx];
        vt = IP4BufPool(pool).virtualTTA();
        int256 h = IP4BufPool(pool).hookSharesDelta();
        if (h >= 0) dRaw = rawSh > uint256(h) ? rawSh - uint256(h) : 0;
        else dRaw = rawSh + uint256(-h);
        supply = vault.totalSupply(pool);
        bpt = vault.balanceOf(pool, address(this));
    }

    function _swap(SwapKind kind, IERC20 tin, IERC20 tout, uint256 amt) internal {
        vault.swap(
            VaultSwapParams({
                kind: kind,
                pool: pool,
                tokenIn: tin,
                tokenOut: tout,
                amountGivenRaw: amt,
                limitRaw: kind == SwapKind.EXACT_IN ? 0 : type(uint256).max,
                userData: ""
            })
        );
    }

    function _add(AddLiquidityKind kind, uint256 ttaAmt, uint256 shAmt, uint256 minBpt) internal {
        uint256[] memory m = new uint256[](2);
        m[ttaIdx] = ttaAmt;
        m[shIdx] = shAmt;
        vault.addLiquidity(AddLiquidityParams({pool: pool, to: address(this), maxAmountsIn: m, minBptAmountOut: minBpt, kind: kind, userData: ""}));
    }

    function _remove(RemoveLiquidityKind kind, uint256 maxBpt, uint256 ttaMin, uint256 shMin) internal {
        uint256[] memory m = new uint256[](2);
        m[ttaIdx] = ttaMin;
        m[shIdx] = shMin;
        vault.removeLiquidity(RemoveLiquidityParams({pool: pool, from: address(this), maxBptAmountIn: maxBpt, minAmountsOut: m, kind: kind, userData: ""}));
    }

    /* ------------------------------------- ops -------------------------------------- */

    function doOp(Op calldata op) external {
        require(msg.sender == address(this), "adv:self");
        (uint256 vt, uint256 dRaw, uint256 rawSh, uint256 rawTta, uint256 supply, uint256 bpt) = _state();
        uint8 k = op.kind;
        uint256 a = op.a;
        if (k == K_SWAP_TTA_IN) {
            _swap(SwapKind.EXACT_IN, tta, shares, _b(a, 1e16, vt / 5));
        } else if (k == K_SWAP_SH_IN) {
            _swap(SwapKind.EXACT_IN, shares, tta, _b(a, 1e16, dRaw / 5));
        } else if (k == K_SWAP_TTA_IN_EXOUT) {
            _swap(SwapKind.EXACT_OUT, tta, shares, _b(a, 1e16, dRaw / 5));
        } else if (k == K_SWAP_SH_IN_EXOUT) {
            _swap(SwapKind.EXACT_OUT, shares, tta, _b(a, 1e16, vt / 5));
        } else if (k == K_ADD_UNBAL_TTA) {
            _add(AddLiquidityKind.UNBALANCED, _b(a, 1e16, 2000e18), 0, 0);
        } else if (k == K_ADD_UNBAL_SH) {
            _add(AddLiquidityKind.UNBALANCED, 0, _b(a, 1e16, 1000e18), 0);
        } else if (k == K_ADD_PROP) {
            _add(AddLiquidityKind.PROPORTIONAL, type(uint128).max, type(uint128).max, _b(a, 1e15, supply / 5));
        } else if (k == K_REMOVE_PROP) {
            require(bpt > 0, "nobpt");
            uint256 amt = bpt * _b(a, 1, 10000) / 10000;
            _remove(RemoveLiquidityKind.PROPORTIONAL, amt == 0 ? bpt : amt, 0, 0);
        } else if (k == K_REMOVE_EXOUT_TTA) {
            require(bpt > 0 && rawTta > 2e15, "noexo");
            _remove(RemoveLiquidityKind.SINGLE_TOKEN_EXACT_OUT, bpt, _b(a, 1e15, rawTta - 1e15), 0);
        } else if (k == K_REMOVE_EXOUT_SH) {
            require(bpt > 0, "nobpt");
            _remove(RemoveLiquidityKind.SINGLE_TOKEN_EXACT_OUT, bpt, 0, _b(a, 1e15, rawSh / 5));
        } else if (k == K_DONATE) {
            uint256 amt = _b(a >> 1, 1e15, 100e18);
            if (a & 1 == 0) _add(AddLiquidityKind.DONATION, amt, 0, 0);
            else _add(AddLiquidityKind.DONATION, 0, amt, 0);
        } else if (k == K_NATIVE_JOIN_TTA) {
            uint256 amt = _b(a, 1e16, 1000e18);
            tta.approve(pool, amt);IP4BufPool(pool).exchangeIn(address(tta), amt, pool, 0, address(this), false, block.timestamp);
        } else if (k == K_NATIVE_JOIN_SH) {
            uint256 amt = _b(a, 1e16, 500e18);
            vault.sendTo(shares, address(this), amt); // flash-borrow shares from the Vault (debt, normalized later)
            shares.approve(pool, amt);IP4BufPool(pool).exchangeIn(address(shares), amt, pool, 0, address(this), false, block.timestamp);
        } else if (k == K_AERO_MOVE) {
            _aeroMove(a);
        } else if (k == K_KNOWN_REMOVE_EXIN_SH) {
            require(_allowKnown, "quarantined");
            require(bpt > 0, "nobpt");
            uint256 amt = bpt * _b(a, 1, 10000) / 10000;
            _remove(RemoveLiquidityKind.SINGLE_TOKEN_EXACT_IN, amt == 0 ? 1 : amt, 0, 1);
        } else if (k == K_KNOWN_ADD_EXOUT_TTA) {
            require(_allowKnown, "quarantined");
            _add(AddLiquidityKind.SINGLE_TOKEN_EXACT_OUT, type(uint128).max, 0, _b(a, 1e15, supply / 50));
        } else {
            revert("kind");
        }
    }

    function _aeroMove(uint256 a) internal {
        uint256 amt = _b(a >> 1, 1e16, 3000e18);
        IERC20 tin = (a & 1) == 0 ? tta : usdc;
        tin.transfer(aeroPool, amt);
        uint256 out = IP4AeroPool(aeroPool).getAmountOut(amt, address(tin));
        if (IP4AeroPool(aeroPool).token0() == address(tin)) IP4AeroPool(aeroPool).swap(0, out, address(this), "");
        else IP4AeroPool(aeroPool).swap(out, 0, address(this), "");
    }

    function aeroMoveExt(uint256 a) external onlyHandler {
        _aeroMove(a);
    }

    /* --------------------------------- normalization --------------------------------- */

    function _exitAllBpt() internal {
        uint256 bpt = vault.balanceOf(pool, address(this));
        if (bpt == 0) return;
        uint256[] memory m = new uint256[](2);
        try vault.removeLiquidity(
            RemoveLiquidityParams({pool: pool, from: address(this), maxBptAmountIn: bpt, minAmountsOut: m, kind: RemoveLiquidityKind.PROPORTIONAL, userData: ""})
        ) {} catch {}
    }

    /// @dev Converts every open Vault delta into DAI using the SAME venue (the buffer pool), so the
    ///      adversary's P&L is measured exactly in DAI (+ small share inventory dust at fair value).
    function _normalize() internal {
        int256 dS = vault.getTokenDelta(shares);
        if (dS > 0) {
            uint256 owe = uint256(dS);
            if (owe <= 1e15 && shares.balanceOf(address(this)) >= owe) {
                shares.transfer(address(vault), owe);
                vault.settle(shares, owe);
            } else {
                try this.swapExt(SwapKind.EXACT_OUT, tta, shares, owe) {} catch {
                    // fall back to paying from inventory (valued at fair price by the handler)
                    shares.transfer(address(vault), owe);
                    vault.settle(shares, owe);
                }
            }
        } else if (dS < 0) {
            uint256 c = uint256(-dS);
            if (c >= 1e15) {
                // sell the credit back into the SAME venue, splitting it if one swap exceeds pool limits
                uint256 parts = 1;
                while (parts <= 16) {
                    try this.sellChunks(c, parts) {
                        break;
                    } catch {
                        parts *= 2;
                    }
                }
                int256 left = vault.getTokenDelta(shares);
                if (left < 0) vault.sendTo(shares, address(this), uint256(-left));
            } else {
                vault.sendTo(shares, address(this), c);
            }
        }
        // residual shares delta from the normalization swap itself (should be zero)
        dS = vault.getTokenDelta(shares);
        if (dS > 0) {
            shares.transfer(address(vault), uint256(dS));
            vault.settle(shares, uint256(dS));
        } else if (dS < 0) {
            vault.sendTo(shares, address(this), uint256(-dS));
        }
        int256 dT = vault.getTokenDelta(tta);
        if (dT > 0) {
            tta.transfer(address(vault), uint256(dT));
            vault.settle(tta, uint256(dT));
        } else if (dT < 0) {
            vault.sendTo(tta, address(this), uint256(-dT));
        }
    }

    function sellChunks(uint256 c, uint256 parts) external {
        require(msg.sender == address(this), "adv:self");
        uint256 each = c / parts;
        for (uint256 i; i < parts; ++i) {
            uint256 amt = i + 1 == parts ? c - each * (parts - 1) : each;
            _swap(SwapKind.EXACT_IN, shares, tta, amt);
        }
    }

    function swapExt(SwapKind kind, IERC20 tin, IERC20 tout, uint256 amt) external {
        require(msg.sender == address(this), "adv:self");
        _swap(kind, tin, tout, amt);
    }
}

/* ------------------------------------------------------------------------------------------ */
/*                                          Handler                                           */
/* ------------------------------------------------------------------------------------------ */

contract P4BalancerHandler is Test {
    P4Env internal e;
    P4Adversary public adv;
    address[3] internal honest;
    address internal market;
    address internal arbitrageur;
    uint256 internal ttaIdx;
    uint256 internal shIdx;

    bool public allowKnown; // un-quarantine known computeBalance-domain kinds (sanity test only)
    bool public quarantineTtaDomain; // quarantine of NEW finding B1/B2 (live-TTA invisible to computeInvariant) for deep hunting

    /* ------------------------------------ ghosts ------------------------------------ */
    uint256 public limitViolations;
    string public lastLimitViolation;
    uint256 public invDropViolations;
    string public lastInvDrop;
    uint256 public worstInvDropPpb;
    uint256 public profitViolations;
    int256 public maxProgramProfit;
    string public lastProfitViolation;
    int256 public cumAdvPnl;
    uint256 public advGiftsOutstanding;
    uint256 public bookDropViolations;
    string public lastBookDrop;
    uint256 public joinViolations;
    uint256 public qJoinEvents; // quarantined B1/B3 occurrences (logged, not asserted)
    uint256 public qExitEvents; // quarantined B2/B3 occurrences (logged, not asserted)
    uint256 public exitViolations;
    string public lastJoinExitViolation;
    uint256 public worstExitOverpayBps;
    uint256 public worstJoinShortfallBps;
    // non-vacuity of the per-action checks (audit fix: silent early-returns were uncounted)
    uint256 public invChecks; // _checkInv evaluated all four invariant values
    uint256 public invSkips; // _checkInv returned early (rate/weights unavailable)
    uint256 public joinChecks; // _joinCheck asserted (not quarantined)
    uint256 public joinQuarantined; // _joinCheck routed to the quarantine counter (TTA>0 joins only)
    uint256 public joinSkips; // _joinCheck returned early (no pool price / dust)
    uint256 public giftRecaptured; // DAI-value of gift residue the adversary recaptured inside programs
    mapping(address => mapping(address => uint256)) public gifted;

    /* ----------------------------------- counters ----------------------------------- */
    string[] internal names;
    mapping(bytes32 => bool) internal known;
    mapping(bytes32 => uint256) public att;
    mapping(bytes32 => uint256) public okc;
    uint256 public totalAtt;
    uint256 public totalOk;
    uint256[16] public opAtt;
    uint256[16] public opOk;
    uint256[8] public seInAtt;
    uint256[8] public seInOk;
    uint256[8] public seOutAtt;
    uint256[8] public seOutOk;
    uint256 public programsOk;
    uint256 public programsAtt;

    uint256 internal constant PROFIT_TOL = 1e16; // 0.01 DAI (absorbs residual Aerodrome re-par dust)

    struct Snap {
        uint256 vt;
        int256 h;
        uint256 rawSh;
        uint256 rawTta;
        uint256 supply;
        uint256 rate;
        bool ok;
    }

    constructor(P4Env memory env) {
        e = env;
        ttaIdx = IP4BufPool(env.pool).ttaIndex();
        shIdx = IP4BufPool(env.pool).sharesIndex();
    }

    function init() external {
        honest[0] = makeAddr("p4_honest0");
        honest[1] = makeAddr("p4_honest1");
        honest[2] = makeAddr("p4_honest2");
        market = makeAddr("p4_market");
        arbitrageur = makeAddr("p4_arb");
        for (uint256 i; i < 3; ++i) _approveAll(honest[i]);
        _approveAll(market);
        _approveAll(arbitrageur);
        adv = new P4Adversary(e, address(this));
        vm.label(address(adv), "P4Adversary");
        // adversary capital: DAI/USDC and a small share inventory used only for dust settlement
        IP4Mint(e.tta).mint(address(adv), 50_000e18);
        IP4Mint(e.usdc).mint(address(adv), 50_000e18);
        uint256 sh = _fundShares(address(this), 20e18);
        IERC20(e.seVault).transfer(address(adv), sh);
    }

    function setAllowKnown(bool v) external {
        allowKnown = v;
    }

    function setQuarantineTtaDomain(bool v) external {
        quarantineTtaDomain = v;
    }

    function _approveAll(address a) internal {
        address[5] memory toks = [e.tta, e.usdc, e.seVault, e.pool, e.aeroPool];
        vm.startPrank(a);
        for (uint256 i; i < toks.length; ++i) {
            IERC20(toks[i]).approve(e.permit2, type(uint256).max);
            IP4Permit2(e.permit2).approve(toks[i], e.router, type(uint160).max, type(uint48).max);
            IP4Permit2(e.permit2).approve(toks[i], e.seRouter, type(uint160).max, type(uint48).max);
            IERC20(toks[i]).approve(e.pool, type(uint256).max); // native SE join pulls via transferFrom
        }
        IERC20(e.pool).approve(e.router, type(uint256).max); // BPT allowance for Vault removals via router
        IERC20(e.tta).approve(e.aeroRouter, type(uint256).max);
        IERC20(e.usdc).approve(e.aeroRouter, type(uint256).max);
        IERC20(e.aeroPool).approve(e.seVault, type(uint256).max);
        vm.stopPrank();
    }

    /* ---------------------------------- counting ----------------------------------- */

    function _count(string memory name, bool success) internal {
        bytes32 k = keccak256(bytes(name));
        if (!known[k]) {
            known[k] = true;
            names.push(name);
        }
        att[k]++;
        totalAtt++;
        if (success) {
            okc[k]++;
            totalOk++;
        }
    }

    function counts(string memory name) external view returns (uint256 a, uint256 o) {
        bytes32 k = keccak256(bytes(name));
        a = att[k];
        o = okc[k];
    }

    function nameCount() external view returns (uint256) {
        return names.length;
    }

    function nameAt(uint256 i) external view returns (string memory n, uint256 a, uint256 o) {
        n = names[i];
        bytes32 k = keccak256(bytes(n));
        a = att[k];
        o = okc[k];
    }

    /* ------------------------------- state / valuation ------------------------------- */

    function _snap() internal view returns (Snap memory s) {
        (,, uint256[] memory raw,) = e.vault.getPoolTokenInfo(e.pool);
        s.rawSh = raw[shIdx];
        s.rawTta = raw[ttaIdx];
        s.vt = IP4BufPool(e.pool).virtualTTA();
        s.h = IP4BufPool(e.pool).hookSharesDelta();
        s.supply = e.vault.totalSupply(e.pool);
        try e.vault.getPoolTokenRates(e.pool) returns (uint256[] memory, uint256[] memory rates) {
            s.rate = rates[shIdx];
            s.ok = s.rate > 0;
        } catch {}
    }

    function _dRaw(Snap memory s) internal pure returns (uint256) {
        if (s.h >= 0) return s.rawSh > uint256(s.h) ? s.rawSh - uint256(s.h) : 0;
        return s.rawSh + uint256(-s.h);
    }

    function _weights(uint256 rate) internal view returns (uint256 wT, uint256 wS, bool ok) {
        uint256 base = IP4BufPool(e.pool).baselineRate();
        if (base == 0) return (0, 0, false);
        uint256 rr = Math.mulDiv(rate, 1e18, base);
        wS = Math.mulDiv(rr, 1e18, rr + 1e18);
        wT = 1e18 - wS;
        ok = wT >= 1e16 && wS >= 1e16;
    }

    /// @notice Pool (virtual-book) invariant per BPT, evaluated at a caller-chosen share rate.
    function invPerBptExt(Snap memory s, uint256 rate) external view returns (uint256) {
        (uint256 wT, uint256 wS, bool ok) = _weights(rate);
        if (!ok || s.supply == 0) return 0;
        uint256 y = Math.mulDiv(_dRaw(s), rate, 1e18);
        if (y == 0 || s.vt == 0) return 0;
        uint256[] memory w = new uint256[](2);
        uint256[] memory b = new uint256[](2);
        w[ttaIdx] = wT;
        w[shIdx] = wS;
        b[ttaIdx] = s.vt;
        b[shIdx] = y;
        return Math.mulDiv(WeightedMath.computeInvariantDown(w, b), 1e18, s.supply);
    }

    function _invPerBpt(Snap memory s, uint256 rate) internal view returns (uint256 v) {
        try this.invPerBptExt(s, rate) returns (uint256 r) {
            v = r;
        } catch {}
    }

    /// @dev Pool marginal price, TTA per raw share (1e18), from the pool's own weighted math.
    function _poolPrice(Snap memory s) internal view returns (uint256) {
        if (!s.ok) return 0;
        (uint256 wT, uint256 wS, bool ok) = _weights(s.rate);
        uint256 y = Math.mulDiv(_dRaw(s), s.rate, 1e18);
        if (!ok || y == 0) return 0;
        return Math.mulDiv(Math.mulDiv(s.vt, wS, wT), s.rate, y);
    }

    /// @dev Proportional-exit book value per BPT at pool price (1e18).
    function _bookPerBpt(Snap memory s, uint256 p) internal pure returns (uint256) {
        if (s.supply == 0) return 0;
        return Math.mulDiv(s.rawTta + Math.mulDiv(s.rawSh, p, 1e18), 1e18, s.supply);
    }

    /// @notice Fair (manipulation-resistant) value of one SE share in DAI: LP backing per share x
    ///         2*sqrt(r0*r1)/LPsupply (DAI and USDC are both 18-dec $1 mocks).
    function fairShareValue() public view returns (uint256) {
        uint256 sup = IERC20(e.seVault).totalSupply();
        if (sup == 0) return 0;
        uint256 lpBal = IERC20(e.aeroPool).balanceOf(e.seVault);
        (uint256 r0, uint256 r1,) = IP4AeroPool(e.aeroPool).getReserves();
        uint256 lpSup = IP4AeroPool(e.aeroPool).totalSupply();
        uint256 k2 = 2 * Math.sqrt(r0 * r1);
        return Math.mulDiv(Math.mulDiv(lpBal, k2, lpSup), 1e18, sup);
    }

    function aeroNearPar() public view returns (bool) {
        (uint256 r0, uint256 r1,) = IP4AeroPool(e.aeroPool).getReserves();
        uint256 hi = r0 > r1 ? r0 : r1;
        uint256 lo = r0 > r1 ? r1 : r0;
        return hi * 1000 <= lo * 1005; // within 0.5%
    }

    function bptFairValue() public view returns (uint256) {
        Snap memory s = _snap();
        if (s.supply == 0) return 0;
        return Math.mulDiv(s.rawTta + Math.mulDiv(s.rawSh, fairShareValue(), 1e18), 1e18, s.supply);
    }

    /* ------------------------------ per-action invariant ------------------------------ */

    function _checkInv(Snap memory pre, string memory tag) internal {
        Snap memory post = _snap();
        if (!pre.ok || !post.ok) {
            invSkips++;
            return;
        }
        uint256 aPre = _invPerBpt(pre, pre.rate);
        uint256 aPost = _invPerBpt(post, pre.rate);
        uint256 bPre = _invPerBpt(pre, post.rate);
        uint256 bPost = _invPerBpt(post, post.rate);
        if (aPre == 0 || bPre == 0 || aPost == 0 || bPost == 0) {
            invSkips++;
            return;
        }
        invChecks++;
        // relative drop in ppb under each rate
        uint256 dropA = aPost >= aPre ? 0 : Math.mulDiv(aPre - aPost, 1e9, aPre);
        uint256 dropB = bPost >= bPre ? 0 : Math.mulDiv(bPre - bPost, 1e9, bPre);
        uint256 drop = dropA < dropB ? dropA : dropB;
        if (drop > 1) {
            invDropViolations++;
            if (drop > worstInvDropPpb) worstInvDropPpb = drop;
            lastInvDrop = string.concat(tag, " dropPpb=", vm.toString(drop));
        }
    }

    function _limitFail(string memory why) internal {
        limitViolations++;
        lastLimitViolation = why;
    }

    /* ------------------------------------ funding ------------------------------------ */

    function _actor(uint256 seed) internal view returns (address) {
        return honest[seed % 3];
    }

    function _fundTta(address a, uint256 amt) internal {
        if (IERC20(e.tta).balanceOf(a) < amt) IP4Mint(e.tta).mint(a, amt - IERC20(e.tta).balanceOf(a));
    }

    function _fundUsdc(address a, uint256 amt) internal {
        if (IERC20(e.usdc).balanceOf(a) < amt) IP4Mint(e.usdc).mint(a, amt - IERC20(e.usdc).balanceOf(a));
    }

    function _fundShares(address a, uint256 daiAmt) internal returns (uint256 sharesOut) {
        IP4Mint(e.tta).mint(a, daiAmt);
        IP4Mint(e.usdc).mint(a, daiAmt);
        vm.startPrank(a);
        IERC20(e.tta).approve(e.aeroRouter, type(uint256).max);
        IERC20(e.usdc).approve(e.aeroRouter, type(uint256).max);
        (,, uint256 lp) = IP4AeroRouter(e.aeroRouter).addLiquidity(e.tta, e.usdc, false, daiAmt, daiAmt, 1, 1, a, block.timestamp + 1 hours);
        IERC20(e.aeroPool).approve(e.seVault, lp);
        sharesOut = IP4SEVault(e.seVault).deposit(lp, a);
        vm.stopPrank();
    }

    function _ensureShares(address a, uint256 amt) internal {
        uint256 guard;
        while (IERC20(e.seVault).balanceOf(a) < amt && guard < 4) {
            _fundShares(a, amt * 2 + 1e18);
            guard++;
        }
    }

    /* ==================================================================================== */
    /*                               HONEST ACTIONS (targeted)                              */
    /* ==================================================================================== */

    function h_mockSwapExactIn(uint256 actorSeed, uint256 dir, uint256 amt) external {
        address a = _actor(actorSeed);
        Snap memory pre = _snap();
        bool ttaIn = dir % 2 == 0;
        address tin = ttaIn ? e.tta : e.seVault;
        address tout = ttaIn ? e.seVault : e.tta;
        amt = ttaIn ? bound(amt, 1e16, pre.vt / 10) : bound(amt, 1e16, _dRaw(pre) / 10);
        if (ttaIn) _fundTta(a, amt);
        else _ensureShares(a, amt);
        uint256 in0 = IERC20(tin).balanceOf(a);
        uint256 out0 = IERC20(tout).balanceOf(a);
        vm.prank(a);
        try IP4BRouter(e.router).swapSingleTokenExactIn(e.pool, tin, tout, amt, 0, block.timestamp + 1 hours, false, "") returns (uint256 out) {
            _count("h_mockSwapExactIn", true);
            uint256 spent = in0 - IERC20(tin).balanceOf(a);
            uint256 got = IERC20(tout).balanceOf(a) - out0;
            if (spent != amt) _limitFail("mockExactIn: spent != exactIn");
            if (got < out) _limitFail("mockExactIn: received < returned");
        } catch {
            _count("h_mockSwapExactIn", false);
        }
        _checkInv(pre, "h_mockSwapExactIn");
    }

    function _quoteMockExactOut(address a, address tin, address tout, uint256 out) internal returns (uint256 q, bool ok) {
        uint256 snap = vm.snapshotState();
        vm.prank(address(0), address(0));
        try IP4BRouter(e.router).querySwapSingleTokenExactOut(e.pool, tin, tout, out, a, "") returns (uint256 r) {
            q = r;
            ok = true;
        } catch {}
        vm.revertToState(snap);
    }

    function h_mockSwapExactOut(uint256 actorSeed, uint256 dir, uint256 amt, bool tight) external {
        address a = _actor(actorSeed);
        Snap memory pre = _snap();
        bool ttaIn = dir % 2 == 0;
        address tin = ttaIn ? e.tta : e.seVault;
        address tout = ttaIn ? e.seVault : e.tta;
        uint256 out = ttaIn ? bound(amt, 1e16, _dRaw(pre) / 10) : bound(amt, 1e16, pre.vt / 10);
        // generous funding
        if (ttaIn) _fundTta(a, out * 4 + 1e18);
        else _ensureShares(a, out * 2 + 1e18);
        uint256 maxIn = IERC20(tin).balanceOf(a);
        if (tight) {
            (uint256 q, bool ok) = _quoteMockExactOut(a, tin, tout, out);
            if (ok && q > 0) maxIn = q + q / 200 + 1 < maxIn ? q + q / 200 + 1 : maxIn;
        }
        uint256 in0 = IERC20(tin).balanceOf(a);
        uint256 out0 = IERC20(tout).balanceOf(a);
        vm.prank(a);
        try IP4BRouter(e.router).swapSingleTokenExactOut(e.pool, tin, tout, out, maxIn, block.timestamp + 1 hours, false, "") returns (uint256 amtIn) {
            _count("h_mockSwapExactOut", true);
            uint256 spent = in0 - IERC20(tin).balanceOf(a);
            uint256 got = IERC20(tout).balanceOf(a) - out0;
            if (spent > maxIn) _limitFail("mockExactOut: spent > maxIn");
            if (spent > amtIn) _limitFail("mockExactOut: spent > returned amountIn");
            if (got < out) _limitFail("mockExactOut: received < exactOut");
        } catch {
            _count("h_mockSwapExactOut", false);
        }
        _checkInv(pre, "h_mockSwapExactOut");
    }

    struct Route {
        address pool;
        address tin;
        address vin;
        address tout;
        address vout;
    }

    function _seRouteIn(uint256 r) internal view returns (Route memory x) {
        if (r == 0) x = Route(e.pool, e.tta, address(0), e.seVault, address(0)); // direct DAI->shares
        else if (r == 1) x = Route(e.pool, e.seVault, address(0), e.tta, address(0)); // direct shares->DAI
        else if (r == 2) x = Route(e.pool, e.usdc, e.seVault, e.tta, address(0)); // USDC->(SE)->shares->(buffer)->DAI
        else if (r == 3) x = Route(e.pool, e.tta, address(0), e.usdc, e.seVault); // DAI->(buffer)->shares->(SE)->USDC
        else if (r == 4) x = Route(e.seVault, e.tta, e.seVault, e.seVault, address(0)); // vault deposit
        else if (r == 5) x = Route(e.seVault, e.seVault, address(0), e.usdc, e.seVault); // vault withdrawal
        else x = Route(e.seVault, e.tta, e.seVault, e.usdc, e.seVault); // pass-through exact-in
    }

    function _fundFor(address a, address tok, uint256 amt) internal {
        if (tok == e.tta) _fundTta(a, amt);
        else if (tok == e.usdc) _fundUsdc(a, amt);
        else _ensureShares(a, amt);
    }

    function h_seSwapExactIn(uint256 actorSeed, uint256 routeSeed, uint256 amt) external {
        address a = _actor(actorSeed);
        Snap memory pre = _snap();
        uint256 r = routeSeed % 7;
        Route memory x = _seRouteIn(r);
        if (x.tin == e.seVault) amt = bound(amt, 1e16, r == 1 ? _dRaw(pre) / 10 : 100e18);
        else amt = bound(amt, 1e16, (r == 0 || r == 3) ? pre.vt / 10 : 200e18);
        _fundFor(a, x.tin, amt);
        uint256 in0 = IERC20(x.tin).balanceOf(a);
        uint256 out0 = IERC20(x.tout).balanceOf(a);
        seInAtt[r]++;
        vm.prank(a);
        try IP4SERouter(e.seRouter).swapSingleTokenExactIn(x.pool, x.tin, x.vin, x.tout, x.vout, amt, 0, block.timestamp + 1 hours, false, "") returns (uint256 out) {
            seInOk[r]++;
            _count("h_seSwapExactIn", true);
            uint256 spent = in0 - IERC20(x.tin).balanceOf(a);
            uint256 got = IERC20(x.tout).balanceOf(a) - out0;
            if (spent != amt) _limitFail(string.concat("seExactIn r", vm.toString(r), ": spent != exactIn"));
            if (got < out) _limitFail(string.concat("seExactIn r", vm.toString(r), ": received < returned"));
        } catch {
            _count("h_seSwapExactIn", false);
        }
        _checkInv(pre, "h_seSwapExactIn");
    }

    function _seRouteOut(uint256 r) internal view returns (Route memory x) {
        // r in [0,5]; pass-through exact-out (pool==tokenInVault==tokenOutVault) is QUARANTINED
        // (balancer-router-permit-overpull: commented-out limit check in ExactOutSwapTarget).
        x = _seRouteIn(r);
    }

    function _quoteSeExactOut(address a, Route memory x, uint256 out) internal returns (uint256 q, bool ok) {
        uint256 snap = vm.snapshotState();
        vm.prank(address(0), address(0));
        try IP4SERouter(e.seRouter).querySwapSingleTokenExactOut(x.pool, x.tin, x.vin, x.tout, x.vout, out, a, "") returns (uint256 v) {
            q = v;
            ok = true;
        } catch {}
        vm.revertToState(snap);
    }

    function h_seSwapExactOut(uint256 actorSeed, uint256 routeSeed, uint256 amt, bool tight) external {
        address a = _actor(actorSeed);
        Snap memory pre = _snap();
        uint256 r = routeSeed % 6;
        Route memory x = _seRouteOut(r);
        uint256 out;
        if (r == 0) out = bound(amt, 1e16, _dRaw(pre) / 10);
        else if (r == 1 || r == 2) out = bound(amt, 1e16, pre.vt / 10);
        else out = bound(amt, 1e16, 100e18);
        if (x.tin == e.seVault) _ensureShares(a, out * 3 + 10e18);
        else _fundFor(a, x.tin, out * 4 + 10e18);
        uint256 maxIn = IERC20(x.tin).balanceOf(a);
        if (tight) {
            (uint256 q, bool ok) = _quoteSeExactOut(a, x, out);
            if (ok && q > 0 && q + q / 200 + 1 < maxIn) maxIn = q + q / 200 + 1;
        }
        uint256 in0 = IERC20(x.tin).balanceOf(a);
        uint256 out0 = IERC20(x.tout).balanceOf(a);
        seOutAtt[r]++;
        vm.prank(a);
        try IP4SERouter(e.seRouter).swapSingleTokenExactOut(x.pool, x.tin, x.vin, x.tout, x.vout, out, maxIn, block.timestamp + 1 hours, false, "") returns (uint256 amtIn) {
            seOutOk[r]++;
            _count("h_seSwapExactOut", true);
            uint256 spent = in0 - IERC20(x.tin).balanceOf(a);
            uint256 got = IERC20(x.tout).balanceOf(a) - out0;
            if (spent > maxIn) _limitFail(string.concat("seExactOut r", vm.toString(r), ": spent > maxIn"));
            if (got < out) _limitFail(string.concat("seExactOut r", vm.toString(r), ": received < exactOut"));
            // return value is in tokenIn units on direct / vault routes
            if ((r == 0 || r == 1 || r == 4 || r == 5) && spent > amtIn) {
                _limitFail(string.concat("seExactOut r", vm.toString(r), ": spent > returned amountIn"));
            }
        } catch {
            _count("h_seSwapExactOut", false);
        }
        _checkInv(pre, "h_seSwapExactOut");
    }

    /// @dev Virtual-book value per BPT (the pool's OWN pricing model: virtualTTA + derived shares at pool price).
    function _virtBookPerBpt(Snap memory s, uint256 p) internal pure returns (uint256) {
        if (s.supply == 0) return 0;
        return Math.mulDiv(s.vt + Math.mulDiv(_dRaw(s), p, 1e18), 1e18, s.supply);
    }

    function _joinCheck(Snap memory pre, uint256 ttaIn, uint256 shIn, uint256 bpt, string memory tag) internal {
        uint256 p = _poolPrice(pre);
        Snap memory post = _snap();
        uint256 valueIn = ttaIn + Math.mulDiv(shIn, p, 1e18);
        if (p == 0 || valueIn < 1e15) {
            joinSkips++;
            return;
        }
        uint256 pPost = _poolPrice(post);
        uint256 floor_ = Math.mulDiv(valueIn, 1e18 - e.vault.getStaticSwapFeePercentage(e.pool) - 3e16, 1e18);
        // REAL book claim (live TTA + raw shares): what the joiner can actually redeem proportionally.
        uint256 claim = Math.mulDiv(bpt, _bookPerBpt(post, pPost), 1e18);
        // Audit fix (was: every join quarantined -> I6-join vacuous in *Q/Medium).
        // The pool prices BPT on virtualTTA (computeInvariant ignores live TTA); at deployment virtualTTA (3662)
        // already exceeds live TTA (2000), so EVERY non-proportional join is shorted on the real book (~23-28%,
        // test_diag_sharesOnlyJoin_initialState) - same root as B1/B2. In quarantine mode we therefore:
        //  - TTA-carrying joins (B1, TTA part mints ~0 BPT): log only;
        //  - shares-only joins: ASSERT fairness inside the pool's own virtual-book model (catches any other
        //    join mispricing: hook bugs, rate/scaling, h accounting), and log the real-book shortfall.
        bool realShort = claim < floor_;
        if (quarantineTtaDomain) {
            if (ttaIn > 0) {
                joinQuarantined++;
                if (realShort) qJoinEvents++;
                return;
            }
            joinChecks++;
            if (realShort) qJoinEvents++;
            claim = Math.mulDiv(bpt, _virtBookPerBpt(post, pPost), 1e18);
            if (claim >= floor_) return;
            tag = string.concat(tag, " [virtual-book]");
        } else {
            joinChecks++;
            if (!realShort) return;
        }
        joinViolations++;
        uint256 shortBps = Math.mulDiv(valueIn - claim, 10000, valueIn);
        if (shortBps > worstJoinShortfallBps) worstJoinShortfallBps = shortBps;
        lastJoinExitViolation = string.concat(tag, " join shortfallBps=", vm.toString(shortBps), " valueIn=", vm.toString(valueIn), " claim=", vm.toString(claim));
    }

    function h_addUnbalanced(uint256 actorSeed, uint256 t, uint256 s, uint256 mode) external {
        address a = _actor(actorSeed);
        Snap memory pre = _snap();
        mode = mode % 3;
        // Audit fix: TTA-only UNBALANCED join deterministically reverts (B1, test_B1_ttaOnlyUnbalancedJoin_reverts);
        // in quarantine mode it only burned ~1/3 of this selector's budget -> exercise shares-only instead.
        if (quarantineTtaDomain && mode == 0) mode = 1;
        t = mode == 1 ? 0 : bound(t, 1e16, pre.vt / 20);
        s = mode == 0 ? 0 : bound(s, 1e16, _dRaw(pre) / 20);
        if (t > 0) _fundTta(a, t);
        if (s > 0) _ensureShares(a, s);
        uint256[] memory amts = new uint256[](2);
        amts[ttaIdx] = t;
        amts[shIdx] = s;
        vm.prank(a);
        try IP4BRouter(e.router).addLiquidityUnbalanced(e.pool, amts, 0, false, "") returns (uint256 bpt) {
            _count("h_addUnbalanced", true);
            _joinCheck(pre, t, s, bpt, mode == 0 ? "addUnbalanced(TTA)" : mode == 1 ? "addUnbalanced(SH)" : "addUnbalanced(both)");
        } catch {
            _count("h_addUnbalanced", false);
        }
        _checkInv(pre, "h_addUnbalanced");
    }

    function h_nativeJoin(uint256 actorSeed, uint256 tokSeed, uint256 amt) external {
        address a = _actor(actorSeed);
        Snap memory pre = _snap();
        // Audit fix: TTA is NOT a valid native tokenIn of the buffer pool (exchangeIn(DAI->BPT) reverts
        // InvalidRoute(dai,pool), see test_probe_nativeJoinTta_revertReason) -> that branch was 0/111 dead budget.
        tokSeed;
        bool useTta = false;
        address tin = useTta ? e.tta : e.seVault;
        amt = useTta ? bound(amt, 1e16, pre.vt / 20) : bound(amt, 1e16, _dRaw(pre) / 20);
        if (useTta) _fundTta(a, amt);
        else _ensureShares(a, amt);
        vm.prank(a);try IP4BufPool(e.pool).exchangeIn(tin, amt, e.pool, 0, a, false, block.timestamp + 1 hours) returns (uint256 bpt, uint256) {
            _count(useTta ? "h_nativeJoin(TTA)" : "h_nativeJoin(SH)", true);
            _joinCheck(pre, useTta ? amt : 0, useTta ? 0 : amt, bpt, useTta ? "nativeJoin(TTA)" : "nativeJoin(SH)");
        } catch {
            _count(useTta ? "h_nativeJoin(TTA)" : "h_nativeJoin(SH)", false);
        }
        _checkInv(pre, "h_nativeJoin");
    }

    function _addProp(address a, uint256 bptAmt) internal returns (bool ok) {
        Snap memory s = _snap();
        uint256 needT = Math.mulDiv(s.rawTta, bptAmt, s.supply) + 1e15;
        uint256 needS = Math.mulDiv(s.rawSh, bptAmt, s.supply) + 1e15;
        _fundTta(a, needT);
        _ensureShares(a, needS);
        uint256[] memory maxIn = new uint256[](2);
        maxIn[ttaIdx] = IERC20(e.tta).balanceOf(a);
        maxIn[shIdx] = IERC20(e.seVault).balanceOf(a);
        vm.prank(a);
        try IP4BRouter(e.router).addLiquidityProportional(e.pool, maxIn, bptAmt, false, "") {
            ok = true;
        } catch {}
    }

    function h_addProportional(uint256 actorSeed, uint256 bptAmt) external {
        address a = _actor(actorSeed);
        Snap memory pre = _snap();
        bptAmt = bound(bptAmt, 1e15, pre.supply / 20);
        _count("h_addProportional", _addProp(a, bptAmt));
        _checkInv(pre, "h_addProportional");
    }

    function h_removeProportional(uint256 actorSeed, uint256 frac) external {
        address a = _actor(actorSeed);
        Snap memory pre = _snap();
        uint256 bal = IERC20(e.pool).balanceOf(a);
        if (bal == 0) {
            _addProp(a, pre.supply / 100);
            bal = IERC20(e.pool).balanceOf(a);
            pre = _snap();
        }
        uint256 amt = bal * bound(frac, 1, 10000) / 10000;
        if (amt == 0) amt = bal;
        uint256[] memory mins = new uint256[](2);
        vm.prank(a);
        try IP4BRouter(e.router).removeLiquidityProportional(e.pool, amt, mins, false, "") {
            _count("h_removeProportional", true);
        } catch {
            _count("h_removeProportional", false);
        }
        _checkInv(pre, "h_removeProportional");
    }

    function h_removeSingleExactOut(uint256 actorSeed, uint256 tokSeed, uint256 amt) external {
        address a = _actor(actorSeed);
        Snap memory pre = _snap();
        if (IERC20(e.pool).balanceOf(a) == 0) {
            _addProp(a, pre.supply / 50);
            pre = _snap();
        }
        bool ttaOut = tokSeed % 2 == 0 && pre.rawTta > 2e15;
        address tout = ttaOut ? e.tta : e.seVault;
        uint256 out = ttaOut ? bound(amt, 1e15, pre.rawTta / 2) : bound(amt, 1e15, pre.rawSh / 20);
        uint256 bal = IERC20(e.pool).balanceOf(a);
        uint256 p = _poolPrice(pre);
        uint256 book = _bookPerBpt(pre, p);
        vm.prank(a);
        try IP4BRouter(e.router).removeLiquiditySingleTokenExactOut(e.pool, bal, tout, out, false, "") returns (uint256 bptIn) {
            _count(ttaOut ? "h_removeSingleExactOut(TTA)" : "h_removeSingleExactOut(SH)", true);
            if (p > 0) {
                uint256 valueOut = ttaOut ? out : Math.mulDiv(out, p, 1e18);
                uint256 claim = Math.mulDiv(bptIn, book, 1e18);
                if (valueOut > claim + claim / 100 + 1e12) {
                    if (quarantineTtaDomain) qExitEvents++; // NEW B2/B3 (single-sided exit overpay) quarantined
                    else exitViolations++;
                    uint256 overBps = claim == 0 ? type(uint32).max : Math.mulDiv(valueOut - claim, 10000, claim);
                    if (overBps > worstExitOverpayBps) worstExitOverpayBps = overBps;
                    lastJoinExitViolation = string.concat(
                        ttaOut ? "removeSingleExactOut(TTA)" : "removeSingleExactOut(SH)",
                        " valueOut=", vm.toString(valueOut), " bptIn=", vm.toString(bptIn), " proportionalClaim=", vm.toString(claim)
                    );
                }
            }
        } catch {
            _count(ttaOut ? "h_removeSingleExactOut(TTA)" : "h_removeSingleExactOut(SH)", false);
        }
        _checkInv(pre, "h_removeSingleExactOut");
    }

    function h_donate(uint256 actorSeed, uint256 t, uint256 s) external {
        address a = _actor(actorSeed);
        Snap memory pre = _snap();
        t = bound(t, 0, 50e18);
        s = bound(s, 0, 20e18);
        if (t == 0 && s == 0) t = 1e16;
        _fundTta(a, t);
        if (s > 0) _ensureShares(a, s);
        uint256[] memory amts = new uint256[](2);
        amts[ttaIdx] = t;
        amts[shIdx] = s;
        vm.prank(a);
        try IP4BRouter(e.router).donate(e.pool, amts, false, "") {
            _count("h_donate", true);
        } catch {
            _count("h_donate", false);
        }
        _checkInv(pre, "h_donate");
    }

    /// @notice Honest external market flow on the SE vault's bound pool (moves the share rate).
    function h_aeroMarket(uint256 dir, uint256 amt) external {
        Snap memory pre = _snap();
        amt = bound(amt, 1e16, 1000e18);
        address tin = dir % 2 == 0 ? e.tta : e.usdc;
        _fundFor(market, tin, amt);
        vm.startPrank(market);
        IERC20(tin).transfer(e.aeroPool, amt);
        uint256 out = IP4AeroPool(e.aeroPool).getAmountOut(amt, tin);
        if (IP4AeroPool(e.aeroPool).token0() == tin) IP4AeroPool(e.aeroPool).swap(0, out, market, "");
        else IP4AeroPool(e.aeroPool).swap(out, 0, market, "");
        vm.stopPrank();
        _count("h_aeroMarket", true);
        _checkInv(pre, "h_aeroMarket");
    }

    /// @notice Arbitrageur restores the Aerodrome DAI/USDC price to ~1 (keeps the fair price anchor honest).
    function h_aeroArb() external {
        _aeroRestore();
        _count("h_aeroArb", true);
    }

    function _aeroRestore() internal {
        (uint256 r0, uint256 r1,) = IP4AeroPool(e.aeroPool).getReserves();
        uint256 g = Math.sqrt(r0 * r1);
        address t0 = IP4AeroPool(e.aeroPool).token0();
        address t1 = t0 == e.tta ? e.usdc : e.tta;
        address tin;
        uint256 amt;
        if (r0 < g) {
            tin = t0;
            amt = (g - r0) * 1003 / 1000;
        } else if (r1 < g) {
            tin = t1;
            amt = (g - r1) * 1003 / 1000;
        }
        if (amt < 1e15) return;
        _fundFor(arbitrageur, tin, amt);
        vm.startPrank(arbitrageur);
        IERC20(tin).transfer(e.aeroPool, amt);
        uint256 out = IP4AeroPool(e.aeroPool).getAmountOut(amt, tin);
        if (t0 == tin) IP4AeroPool(e.aeroPool).swap(0, out, arbitrageur, "");
        else IP4AeroPool(e.aeroPool).swap(out, 0, arbitrageur, "");
        vm.stopPrank();
    }

    function h_warp(uint256 dt) external {
        dt = bound(dt, 1, 7 days);
        vm.warp(block.timestamp + dt);
        vm.roll(block.number + 1 + dt / 12);
        _count("h_warp", true);
    }

    /* ==================================================================================== */
    /*                             ADVERSARIAL ACTIONS (targeted)                           */
    /* ==================================================================================== */

    function _topUpAdversary() internal {
        if (IERC20(e.tta).balanceOf(address(adv)) < 20_000e18) IP4Mint(e.tta).mint(address(adv), 20_000e18);
        if (IERC20(e.usdc).balanceOf(address(adv)) < 20_000e18) IP4Mint(e.usdc).mint(address(adv), 20_000e18);
        if (IERC20(e.seVault).balanceOf(address(adv)) < 5e18) {
            uint256 sh = _fundShares(address(this), 10e18);
            IERC20(e.seVault).transfer(address(adv), sh);
        }
    }

    /// @notice Adversarial program: up to 6 ops executed inside ONE Vault.unlock opened by the
    ///         adversary contract (price moves on the bound pool inside its own unlock, LP ops,
    ///         donations, native SE joins, Aerodrome moves of the share rate), followed by a full
    ///         BPT exit and same-venue normalization to DAI. P&L must be <= dust.
    function a_program(uint256[6] calldata kinds, uint256[6] calldata amts, uint256 n) external {
        n = bound(n, 1, 6);
        P4Adversary.Op[] memory ops = new P4Adversary.Op[](n);
        uint8 nk = allowKnown ? 16 : 14;
        for (uint256 i; i < n; ++i) {
            uint8 k = uint8(kinds[i] % nk);
            // NEW B2/B3: single-sided exact-out exits overpay vs proportional claim -> quarantined in deep mode
            if (quarantineTtaDomain && (k == 8 || k == 9)) k = 7;
            // NEW B3 (join direction): UNBALANCED / native joins mint on derivedY = raw - h while the proportional
            // exit pays raw (incl. h) -> overpay when h is large. Quarantined in deep mode (mapped to proportional add).
            if (quarantineTtaDomain && (k == 4 || k == 5 || k == 11 || k == 12)) k = 6;
            ops[i] = P4Adversary.Op(k, amts[i]);
        }
        _runProgram(ops, "a_program");
    }

    /// @dev Non-targeted entry used by the deterministic sanity / reproduction tests.
    function runProgramExt(P4Adversary.Op[] memory ops) external returns (int256 profit) {
        return _runProgram(ops, "runProgramExt");
    }

    struct Bal {
        uint256 d;
        uint256 u;
        uint256 s;
        uint256 b;
    }

    function _advBal() internal view returns (Bal memory x) {
        address A = address(adv);
        x.d = IERC20(e.tta).balanceOf(A);
        x.u = IERC20(e.usdc).balanceOf(A);
        x.s = IERC20(e.seVault).balanceOf(A);
        x.b = e.vault.balanceOf(e.pool, A);
    }

    function _advVal(Bal memory x, uint256 fsv, uint256 bptV) internal pure returns (int256) {
        return int256(x.d + x.u + Math.mulDiv(x.s, fsv, 1e18) + Math.mulDiv(x.b, bptV, 1e18));
    }

    function _fairBookPerBpt(Snap memory s_, uint256 fsv) internal pure returns (uint256) {
        if (s_.supply == 0) return 0;
        return Math.mulDiv(s_.rawTta + Math.mulDiv(s_.rawSh, fsv, 1e18), 1e18, s_.supply);
    }

    function _runProgram(P4Adversary.Op[] memory ops, string memory tag) internal returns (int256 profit) {
        _topUpAdversary();
        // An Aerodrome leg must not be able to arbitrage displacement left by honest market flow (that is
        // legitimate arbitrage, not a protocol bug): an honest arbitrageur restores par first.
        for (uint256 i; i < ops.length; ++i) {
            if (ops[i].kind == 13) {
                _aeroRestore();
                break;
            }
        }
        Snap memory pre = _snap();
        uint256 bookPre = _fairBookPerBpt(pre, fairShareValue());
        Bal memory b0 = _advBal();
        (_resD0, _resS0) = _giftResidue();
        programsAtt++;
        for (uint256 i; i < ops.length; ++i) opAtt[ops[i].kind]++;
        bool success;
        try adv.run(ops, allowKnown) returns (uint256 mask) {
            success = true;
            programsOk++;
            for (uint256 i; i < ops.length; ++i) if (mask & (1 << i) != 0) opOk[ops[i].kind]++;
        } catch {}
        _count("a_program", success);
        if (success) profit = _settleProgram(ops, tag, b0, pre.rate);
        bool movesRate;
        for (uint256 i; i < ops.length; ++i) if (ops[i].kind == 13) movesRate = true;
        // I5 is only meaningful when every swap of the action is priced at (approximately) one rate; an
        // Aerodrome move inside the program re-prices later swaps at a different rate (false drop). Those
        // programs are covered by I7 (adversary P&L) and I9 (fair book per BPT) instead.
        if (!movesRate) _checkInv(pre, string.concat(tag, " ok=", success ? "1" : "0", " ops=", _opsDesc(ops)));
        // I9: LP fair book value per BPT must not drop materially during an adversarial program
        uint256 bookPost = _fairBookPerBpt(_snap(), fairShareValue());
        if (bookPre > 0 && bookPost * 10000 < bookPre * 9950) {
            bookDropViolations++;
            lastBookDrop = string.concat(tag, " dropBps=", vm.toString((bookPre - bookPost) * 10000 / bookPre), " ops=", _opsDesc(ops));
        }
    }

    function _opsDesc(P4Adversary.Op[] memory ops) internal pure returns (string memory d) {
        for (uint256 i; i < ops.length; ++i) {
            d = string.concat(d, "(", vm.toString(uint256(ops[i].kind)), ",", vm.toString(ops[i].a), ")");
        }
    }

    /// @dev Stray balances any caller could pick up: Vault surplus over tracked reserves + raw balances of
    ///      the routers and the pool/hook diamond (DAI and shares are the only gifted tokens).
    function _giftResidue() internal view returns (uint256 d, uint256 s) {
        address[3] memory holders = [e.pool, e.router, e.seRouter];
        for (uint256 i; i < 3; ++i) {
            d += IERC20(e.tta).balanceOf(holders[i]);
            s += IERC20(e.seVault).balanceOf(holders[i]);
        }
        uint256 vb = IERC20(e.tta).balanceOf(address(e.vault));
        uint256 vr = e.vault.getReservesOf(IERC20(e.tta));
        if (vb > vr) d += vb - vr;
        vb = IERC20(e.seVault).balanceOf(address(e.vault));
        vr = e.vault.getReservesOf(IERC20(e.seVault));
        if (vb > vr) s += vb - vr;
    }

    uint256 internal _resD0;
    uint256 internal _resS0;

    function _recaptured(uint256 fsv) internal view returns (uint256) {
        (uint256 resD1, uint256 resS1) = _giftResidue();
        int256 dRes = int256(_resD0) - int256(resD1) + int256(Math.mulDiv(_resS0, fsv, 1e18)) - int256(Math.mulDiv(resS1, fsv, 1e18));
        return dRes > 0 ? uint256(dRes) : 0;
    }

    function _settleProgram(P4Adversary.Op[] memory ops, string memory tag, Bal memory b0, uint256 ratePre)
        internal
        returns (int256 profit)
    {
        // Conservative valuation of residual shares: min(fair LP value, pool NAV rate before, after). The pool
        // prices shares off the whole-book rate (known se-rate-provider understatement) - valuing leftovers at
        // the higher fair value would report that known cross-venue gap as "profit".
        uint256 fsv = fairShareValue();
        Snap memory post = _snap();
        if (ratePre > 0 && ratePre < fsv) fsv = ratePre;
        if (post.rate > 0 && post.rate < fsv) fsv = post.rate;
        uint256 bptV = post.supply == 0 ? 0 : Math.mulDiv(post.rawTta + Math.mulDiv(post.rawSh, fsv, 1e18), 1e18, post.supply);
        profit = _advVal(_advBal(), fsv, bptV) - _advVal(b0, fsv, bptV);
        cumAdvPnl += profit;
        if (profit > maxProgramProfit) maxProgramProfit = profit;
        // Audit fix: the old allowance was the CUMULATIVE gift total (grew to ~100 DAI per run and masked real
        // profit). Allow only the stray residue the adversary actually removed during THIS program.
        uint256 recaptured = _recaptured(fsv);
        giftRecaptured += recaptured;
        if (profit > int256(PROFIT_TOL + recaptured)) {
            profitViolations++;
            lastProfitViolation = string.concat(tag, " profit=", vm.toString(profit), " ops=", _opsDesc(ops));
        }
    }

    /// @notice Pretransfer / stray-balance action: adversary sends DAI or shares directly to the
    ///         Vault, the pool/hook diamond, the RouterMock or the SE router. Tracked as attacker loss
    ///         and as an allowance for any later recapture.
    function a_gift(uint256 targetSeed, uint256 tokSeed, uint256 amt) external {
        _topUpAdversary();
        address[4] memory targets = [address(e.vault), e.pool, e.router, e.seRouter];
        address target = targets[targetSeed % 4];
        address tok = tokSeed % 2 == 0 ? e.tta : e.seVault;
        amt = bound(amt, 1, tok == e.tta ? 1e18 : 1e17);
        adv.exec(tok, abi.encodeCall(IERC20.transfer, (target, amt)));
        gifted[target][tok] += amt;
        uint256 v = tok == e.tta ? amt : Math.mulDiv(amt, fairShareValue(), 1e18);
        advGiftsOutstanding += v;
        cumAdvPnl -= int256(v);
        _count("a_gift", true);
    }

    /// @notice Adversary moves the SE vault's bound pool (Aerodrome) and LEAVES it moved
    ///         (persistent rate manipulation; the next actions see the moved rate).
    function a_aeroMovePersistent(uint256 a) external {
        _topUpAdversary();
        Snap memory pre = _snap();
        address A = address(adv);
        int256 v0 = int256(IERC20(e.tta).balanceOf(A) + IERC20(e.usdc).balanceOf(A));
        try adv.aeroMoveExt(a) {
            _count("a_aeroMovePersistent", true);
        } catch {
            _count("a_aeroMovePersistent", false);
        }
        cumAdvPnl += int256(IERC20(e.tta).balanceOf(A) + IERC20(e.usdc).balanceOf(A)) - v0;
        _checkInv(pre, "a_aeroMovePersistent");
    }

    /* ==================================================================================== */
    /*                                       reporting                                      */
    /* ==================================================================================== */

    function logSummary() external view {
        console2.log("==== P4 balancer handler summary ====");
        console2.log("totalAtt", totalAtt, "totalOk", totalOk);
        for (uint256 i; i < names.length; ++i) {
            bytes32 k = keccak256(bytes(names[i]));
            console2.log(string.concat("  ", names[i], " ok/att"), okc[k], att[k]);
        }
        console2.log("programs ok/att", programsOk, programsAtt);
        for (uint256 k; k < 16; ++k) {
            if (opAtt[k] > 0) console2.log(string.concat("  op kind ", vm.toString(k), " ok/att"), opOk[k], opAtt[k]);
        }
        for (uint256 r; r < 7; ++r) {
            if (seInAtt[r] > 0) console2.log(string.concat("  seRouter exactIn route ", vm.toString(r), " ok/att"), seInOk[r], seInAtt[r]);
        }
        for (uint256 r; r < 6; ++r) {
            if (seOutAtt[r] > 0) console2.log(string.concat("  seRouter exactOut route ", vm.toString(r), " ok/att"), seOutOk[r], seOutAtt[r]);
        }
        console2.log("limitViolations", limitViolations, lastLimitViolation);
        console2.log("invDropViolations", invDropViolations, lastInvDrop);
        console2.log("worstInvDropPpb", worstInvDropPpb);
        console2.log("profitViolations", profitViolations, lastProfitViolation);
        console2.log("maxProgramProfit");
        console2.logInt(maxProgramProfit);
        console2.log("cumAdvPnl");
        console2.logInt(cumAdvPnl);
        console2.log("bookDropViolations", bookDropViolations, lastBookDrop);
        console2.log("joinViolations", joinViolations, "exitViolations", exitViolations);
        console2.log("quarantined NEW-B events: join / exit", qJoinEvents, qExitEvents);
        console2.log("worstJoinShortfallBps", worstJoinShortfallBps, "worstExitOverpayBps", worstExitOverpayBps);
        console2.log("lastJoinExitViolation", lastJoinExitViolation);
        console2.log("I5 checks / skips", invChecks, invSkips);
        console2.log("I6 join checks / quarantined / skips", joinChecks, joinQuarantined, joinSkips);
        console2.log("gift outstanding (cum) / recaptured in programs", advGiftsOutstanding, giftRecaptured);
    }
}
