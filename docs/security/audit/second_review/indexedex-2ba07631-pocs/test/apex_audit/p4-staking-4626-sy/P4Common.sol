// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";

/// @dev Native SY surface (Pendle IStandardizedYield subset) hosted on the SE diamonds.
interface ISYLocal {
    function deposit(address receiver, address tokenIn, uint256 amount, uint256 minSharesOut)
        external payable returns (uint256);
    function redeem(address receiver, uint256 shares, address tokenOut, uint256 minOut, bool internalBalance)
        external returns (uint256);
    function previewDeposit(address tokenIn, uint256 amount) external view returns (uint256);
    function previewRedeem(address tokenOut, uint256 shares) external view returns (uint256);
}

interface IRebalanceLocal {
    function rebalance() external;
}

/// @dev Smart-contract wallet used by every actor (honest integrators and the adversary), so the
///      contract-only pretransfer gate is reachable for both.
contract P4Wallet {
    address public immutable controller;

    constructor() {
        controller = msg.sender;
    }

    function exec(address target, bytes calldata data) external returns (bytes memory ret) {
        require(msg.sender == controller, "ctl");
        bool ok;
        (ok, ret) = target.call(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    /// @dev atomic transfer-then-consume (router pattern): both or neither
    function exec2(address t1, bytes calldata d1, address t2, bytes calldata d2) external returns (bytes memory ret) {
        require(msg.sender == controller, "ctl");
        bool ok;
        (ok, ret) = t1.call(d1);
        if (ok) (ok, ret) = t2.call(d2);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    receive() external payable {}
}

/// @dev Family adapter implemented by each test contract (has cheatcodes; owns the hermetic ports).
interface IP4Host {
    function se() external view returns (address);
    function tokens() external view returns (address[] memory); // vault-side asset tokens
    function fund(address token, address to, uint256 amount) external; // exogenous mint of `token`
    function fairValue(address token, uint256 amount) external view returns (uint256); // numeraire units
    function fairNav() external view returns (uint256); // independent valuation of vault-counted backing
    function reportedNav() external view returns (uint256); // vault's own NAV in numeraire
    function virtShares() external view returns (uint256); // V in (S+V)
    function navPlus() external view returns (uint256); // +1 in (NAV+1)
    function outCap(address token) external view returns (uint256); // max sensible payout of token
    function bare() external view returns (address); // held but not counted (eETH/stETH), or 0
    function hasQueue() external view returns (bool);
    function portPending() external view returns (uint256 pend, uint256 fin); // unclaimed / finalized-unclaimed
    function finalizeAll() external;
    function moveRate(uint256 seed) external returns (bool);
    function hasRebalance() external view returns (bool);
    function supportsSwap() external view returns (bool);
    function has4626Mutators() external view returns (bool); // IERC4626 deposit/redeem safe to fuzz
}

/// @notice Stateful handler: 3 honest wallets + 1 adversary wallet; ghost value accounting at fair price.
contract P4Handler is Test {
    uint256 public constant N = 4; // actor 3 = adversary
    uint256 public constant ADV = 3;

    IP4Host public host;
    address public se;
    P4Wallet[N] public wallets;

    // ---- ghost value accounting (numeraire units, signed) ----
    // netGain(actor) = wealth(actor) - exo(actor); exo = exogenous value injected (funding, rate moves).
    int256[N] public exo;

    // ---- quarantine switches (known confirmed findings) ----
    bool public allowRequeue; // staking-rebalance-requeue-pending
    bool public allow4626; // crane-erc4626facet-mint (staking families only)

    // ---- per-op violation log ----
    uint256 public violations;
    string public firstViolation;
    uint256 public queueViolations;
    string public firstQueueViolation;

    // ---- non-vacuity ----
    mapping(bytes32 => uint256) public okCalls;
    mapping(bytes32 => uint256) public failCalls;
    mapping(bytes32 => uint256) public skipCalls;
    bytes32[] public tags;
    mapping(bytes32 => bool) internal seenTag;

    uint256 public ghostBareDonated;
    uint256 public rateMoves;

    uint256 internal constant OP_TOL = 4; // wei-level rounding slack per op
    uint256 internal constant REQUEUE_BUDGET = 2; // see rebalance(): bounded exposure of the known requeue DoS
    uint256 public requeueUsed;

    struct Snap {
        uint256 nav;
        uint256 supply;
        uint256 vaultHeld;
    }

    constructor(IP4Host host_) {
        host = host_;
        se = host_.se();
        for (uint256 i; i < N; ++i) {
            wallets[i] = new P4Wallet();
        }
    }

    // ------------------------------------------------------------------ config
    function setAllowRequeue(bool v) external {
        allowRequeue = v;
    }

    function setAllow4626(bool v) external {
        allow4626 = v;
    }

    function wallet(uint256 i) external view returns (address) {
        return address(wallets[i]);
    }

    // ------------------------------------------------------------------ valuation
    function shareValue(uint256 sh) public view returns (uint256) {
        uint256 d = IERC20(se).totalSupply() + host.virtShares();
        if (sh == 0 || d == 0) return 0;
        return sh * (host.fairNav() + host.navPlus()) / d;
    }

    function _snap() internal view returns (Snap memory x) {
        x.nav = host.fairNav();
        x.supply = IERC20(se).totalSupply();
        x.vaultHeld = IERC20(se).balanceOf(se);
    }

    function _sharesFor(Snap memory x, uint256 value) internal view returns (uint256) {
        uint256 d = x.nav + host.navPlus();
        if (d == 0 || x.supply == 0 && host.virtShares() == 0) return value * 10 ** 30; // empty: any mint ok
        return value * (x.supply + host.virtShares()) / d;
    }

    /// @dev Rounding-aware fair bounds. Each oracle read (deposit value, NAV) may be off by OP_TOL wei;
    ///      when a deposit is many times the vault's NAV that wei error is amplified by deposit/NAV in
    ///      share units (observed: 12 shares on a 2e20 deposit into a 4e18 Stata vault). These bounds
    ///      give the user the full OP_TOL on both reads, so only super-rounding mispricing is flagged.
    function _sharesForMax(Snap memory x, uint256 value) internal view returns (uint256) {
        uint256 d = x.nav + host.navPlus();
        if (d <= OP_TOL || x.supply == 0 && host.virtShares() == 0) return value * 10 ** 30;
        return (value + OP_TOL) * (x.supply + host.virtShares()) / (d - OP_TOL) + OP_TOL;
    }

    function _valueOfSharesMin(Snap memory x, uint256 sh) internal view returns (uint256) {
        uint256 d = x.supply + host.virtShares();
        uint256 n = x.nav + host.navPlus();
        if (d == 0 || n <= OP_TOL) return 0;
        uint256 v = sh * (n - OP_TOL) / d;
        return v > OP_TOL ? v - OP_TOL : 0;
    }

    function _valueOfShares(Snap memory x, uint256 sh) internal view returns (uint256) {
        uint256 d = x.supply + host.virtShares();
        if (d == 0) return 0;
        return sh * (x.nav + host.navPlus()) / d;
    }

    function wealth(uint256 i) public view returns (uint256 w) {
        address a = address(wallets[i]);
        address[] memory t = host.tokens();
        for (uint256 k; k < t.length; ++k) {
            uint256 b = IERC20(t[k]).balanceOf(a);
            if (b > 0) w += host.fairValue(t[k], b);
        }
        uint256 sh = IERC20(se).balanceOf(a);
        // Shares the adversary parked on the vault are reclaimable by it (honest actors never park).
        if (i == ADV) sh += IERC20(se).balanceOf(se);
        w += shareValue(sh);
    }

    function netGain(uint256 i) public view returns (int256) {
        return int256(wealth(i)) - exo[i];
    }

    // ------------------------------------------------------------------ helpers
    function _tag(string memory s) internal returns (bytes32 t) {
        t = keccak256(bytes(s));
        if (!seenTag[t]) {
            seenTag[t] = true;
            tags.push(t);
            tagName[t] = s;
        }
    }

    mapping(bytes32 => string) public tagName;

    function tagCount() external view returns (uint256) {
        return tags.length;
    }

    function _violate(string memory what) internal {
        if (violations == 0) firstViolation = what;
        ++violations;
        console2.log("VIOLATION", what);
    }

    function _qviolate(string memory what) internal {
        if (queueViolations == 0) firstQueueViolation = what;
        ++queueViolations;
        console2.log("QUEUE VIOLATION", what);
    }

    function _fund(uint256 i, address token, uint256 amt) internal {
        uint256 v = host.fairValue(token, amt);
        host.fund(token, address(wallets[i]), amt);
        exo[i] += int256(v);
    }

    function _call(uint256 i, address target, bytes memory data) internal returns (bool ok, bytes memory ret) {
        try wallets[i].exec(target, data) returns (bytes memory r) {
            ok = true;
            ret = r;
        } catch (bytes memory r) {
            ret = r;
        }
    }

    function _approve(uint256 i, address token) internal {
        _call(i, token, abi.encodeCall(IERC20.approve, (se, type(uint256).max)));
    }

    function _tok(uint256 seed) internal view returns (address) {
        address[] memory t = host.tokens();
        return t[seed % t.length];
    }

    function _honest(uint256 seed) internal pure returns (uint256) {
        return seed % 3;
    }

    function _actor(uint256 seed) internal pure returns (uint256) {
        return seed % N;
    }

    function _res(bytes32 t, bool ok) internal {
        if (ok) ++okCalls[t];
        else ++failCalls[t];
    }

    // ---- revert-reason histogram (so failures are attributable, not silently swallowed) ----
    mapping(bytes32 => bytes4[]) internal failSels;
    mapping(bytes32 => mapping(bytes4 => uint256)) public failSelCount;

    function _res(bytes32 t, bool ok, bytes memory ret) internal {
        _res(t, ok);
        if (ok) return;
        bytes4 sel;
        if (ret.length >= 4) sel = bytes4(ret);
        if (failSelCount[t][sel]++ == 0) failSels[t].push(sel);
    }

    /// @dev non-money bookkeeping ops (always succeed) are excluded from the success-rate gate
    function _isMoneyTag(bytes32 t) internal pure returns (bool) {
        return t != keccak256("warp") && t != keccak256("advRateMove") && t != keccak256("finalizeQueue")
            && t != keccak256("advDonate") && t != keccak256("advDonateShares")
            && t != keccak256("erc4626DepositExisting"); // attack probe: a revert is the vault defending
    }

    function _u(bytes memory r) internal pure returns (uint256 x) {
        if (r.length >= 32) x = abi.decode(r, (uint256));
    }

    /// @dev honest ops must never consume or create vault-held (parked) shares
    function _checkVaultHeldUnchanged(uint256 i, uint256 before_, string memory what) internal {
        if (i != ADV && IERC20(se).balanceOf(se) != before_) _violate(string.concat(what, ": honest op moved vault-held shares"));
    }

    // ================================================================== ACTIONS
    struct Op {
        uint256 i;
        address tok;
        uint256 amt;
        uint256 sh;
        uint256 prev;
        uint256 balB;
        uint256 shB;
        uint256 out;
        uint256 got;
        uint256 hs;
        bool ok;
        bytes r;
    }

    function _chkEq(uint256 expected, uint256 actual, string memory what) internal {
        if (expected != actual) {
            console2.log(what, expected, actual);
            _violate(what);
        }
    }

    /// @dev exit previews may be a conservative floor (eETH share-floor transfers: documented
    ///      "empty recipient is the conservative native-transfer floor"); flag only overstatement
    ///      or an under-quote beyond 2 wei.
    function _chkExitPreview(uint256 expected, uint256 actual, string memory what) internal {
        if (actual < expected || actual > expected + 2) {
            console2.log(what, expected, actual);
            _violate(what);
        }
    }

    function _unbooked(address tok) internal view returns (uint256) {
        uint256 b = IERC20(tok).balanceOf(se);
        uint256 r = IBasicVault(se).reserveOfToken(tok);
        return b > r ? b - r : 0;
    }

    function _bareOnVault() internal view returns (uint256) {
        address b = host.bare();
        return b == address(0) ? 0 : IERC20(b).balanceOf(se);
    }

    function _noteBare(uint256 before_) internal {
        uint256 a = _bareOnVault();
        if (a > before_) ghostBareDonated += a - before_;
    }

    function _honestShares() internal view returns (uint256 s) {
        for (uint256 k; k < 3; ++k) s += IERC20(se).balanceOf(address(wallets[k]));
    }

    function _checkHonestUntouched(uint256 before_, string memory what) internal {
        if (_honestShares() != before_) _violate(string.concat(what, ": honest share balances changed by adversary op"));
    }

    function _exIn(Op memory o, address tin, uint256 amt, address tout, bool pre) internal {
        (o.ok, o.r) = _call(
            o.i, se, abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(tin), amt, IERC20(tout), 0, address(wallets[o.i]), pre, block.timestamp))
        );
        if (o.ok && o.r.length >= 64) (o.out,) = abi.decode(o.r, (uint256, uint256));
    }

    function _exOut(Op memory o, address tin, uint256 maxIn, address tout, uint256 amtOut, bool pre) internal {
        (o.ok, o.r) = _call(
            o.i, se, abi.encodeCall(IStandardExchangeOut.exchangeOut, (IERC20(tin), maxIn, IERC20(tout), amtOut, address(wallets[o.i]), pre, block.timestamp))
        );
        if (o.ok) o.out = _u(o.r);
    }

    function _bal(address tok, uint256 i) internal view returns (uint256) {
        return IERC20(tok).balanceOf(address(wallets[i]));
    }

    // ---- mint exact-in (asset -> SE) ----
    function mintExactIn(uint256 actorSeed, uint256 tokSeed, uint256 amt) external {
        bytes32 t = _tag("mintExactIn");
        Op memory o;
        o.i = _actor(actorSeed);
        o.tok = _tok(tokSeed);
        o.amt = bound(amt, 1e15, 200 ether);
        _fund(o.i, o.tok, o.amt + 2); // +2: rebasing-token mint rounding
        _approve(o.i, o.tok);
        Snap memory x = _snap();try IStandardExchangeIn(se).previewExchangeIn(IERC20(o.tok), o.amt, IERC20(se)) returns (uint256 p, uint256) { o.prev = p; } catch {}
        uint256 v = host.fairValue(o.tok, o.amt);
        _exIn(o, o.tok, o.amt, se, false);
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        _chkEq(o.prev, o.out, "mintExactIn: preview != execution");
        if (o.out > _sharesForMax(x, v)) {
            console2.log("mintExactIn out / fairMax / value", o.out, _sharesForMax(x, v), v);
            console2.log("  nav / supply", x.nav, x.supply);
            _violate("mintExactIn: free shares (out > fair)");
        }
        _checkVaultHeldUnchanged(o.i, x.vaultHeld, "mintExactIn");
    }

    // ---- mint exact-out (asset -> fixed SE shares) ----
    function mintExactOut(uint256 actorSeed, uint256 tokSeed, uint256 valueSeed) external {
        bytes32 t = _tag("mintExactOut");
        Op memory o;
        o.i = _actor(actorSeed);
        o.tok = _tok(tokSeed);
        Snap memory x = _snap();
        o.sh = _sharesFor(x, bound(valueSeed, 1e15, 200 ether));
        if (o.sh == 0) { ++skipCalls[t]; return; }
        try IStandardExchangeOut(se).previewExchangeOut(IERC20(o.tok), IERC20(se), o.sh) returns (uint256 p) { o.prev = p; } catch { ++skipCalls[t]; return; }
        if (o.prev == 0 || o.prev > 400 ether) { ++skipCalls[t]; return; }
        o.amt = o.prev + o.prev / 1e6 + 10; // maxAmountIn
        _fund(o.i, o.tok, o.amt); // funding a rebasing token can move its share ratio: re-quote after
        _approve(o.i, o.tok);
        try IStandardExchangeOut(se).previewExchangeOut(IERC20(o.tok), IERC20(se), o.sh) returns (uint256 p) { o.prev = p; } catch { ++skipCalls[t]; return; }
        o.balB = _bal(o.tok, o.i);
        _exOut(o, o.tok, o.amt, se, o.sh, false);
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        o.got = o.balB - _bal(o.tok, o.i); // paid
        _chkEq(o.prev, o.out, "mintExactOut: preview != execution");
        if (o.got + OP_TOL < o.out) _violate("mintExactOut: pulled less than reported");
        if (host.fairValue(o.tok, o.got) < _valueOfSharesMin(x, o.sh)) _violate("mintExactOut: free shares (paid < fair)");
        _checkVaultHeldUnchanged(o.i, x.vaultHeld, "mintExactOut");
    }

    function _pickOut(uint256 tokSeed, uint256 value) internal view returns (address tok, bool okPick) {
        address[] memory ts = host.tokens();
        for (uint256 k; k < ts.length; ++k) {
            tok = ts[(tokSeed + k) % ts.length];
            if (host.fairValue(tok, host.outCap(tok)) > value + value / 20 + 1e12) return (tok, true);
        }
        return (tok, false);
    }

    // ---- redeem exact-in (SE -> asset) ----
    function redeemExactIn(uint256 actorSeed, uint256 tokSeed, uint256 frac) external {
        bytes32 t = _tag("redeemExactIn");
        Op memory o;
        o.i = _actor(actorSeed);
        o.sh = _bal(se, o.i) * bound(frac, 1, 10_000) / 10_000;
        if (o.sh == 0) { ++skipCalls[t]; return; }
        Snap memory x = _snap();
        bool okp;
        (o.tok, okp) = _pickOut(tokSeed, _valueOfShares(x, o.sh));
        if (!okp) { ++skipCalls[t]; return; }try IStandardExchangeIn(se).previewExchangeIn(IERC20(se), o.sh, IERC20(o.tok)) returns (uint256 p, uint256) { o.prev = p; } catch {}
        o.balB = _bal(o.tok, o.i);
        _exIn(o, se, o.sh, o.tok, false);
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        o.got = _bal(o.tok, o.i) - o.balB;
        _chkExitPreview(o.prev, o.out, "redeemExactIn: preview != execution");
        if (host.fairValue(o.tok, o.got) > _valueOfShares(x, o.sh) + OP_TOL) _violate("redeemExactIn: exit pays more than share of backing");
        _checkVaultHeldUnchanged(o.i, x.vaultHeld, "redeemExactIn");
    }

    // ---- redeem exact-out (SE -> fixed asset) ----
    function redeemExactOut(uint256 actorSeed, uint256 tokSeed, uint256 frac) external {
        bytes32 t = _tag("redeemExactOut");
        Op memory o;
        o.i = _actor(actorSeed);
        uint256 bal = _bal(se, o.i);
        o.sh = bal * bound(frac, 1, 9_900) / 10_000;
        if (o.sh == 0) { ++skipCalls[t]; return; }
        Snap memory x = _snap();
        bool okp;
        (o.tok, okp) = _pickOut(tokSeed, _valueOfShares(x, o.sh));
        if (!okp) { ++skipCalls[t]; return; }try IStandardExchangeIn(se).previewExchangeIn(IERC20(se), o.sh, IERC20(o.tok)) returns (uint256 p, uint256) { o.amt = p; } catch {}
        if (o.amt == 0) { ++skipCalls[t]; return; }
        try IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(o.tok), o.amt) returns (uint256 p) { o.prev = p; } catch { ++skipCalls[t]; return; }
        o.balB = _bal(o.tok, o.i);
        o.shB = bal;
        _exOut(o, se, bal, o.tok, o.amt, false);
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        uint256 burned = o.shB - _bal(se, o.i);
        o.got = _bal(o.tok, o.i) - o.balB;
        _chkEq(o.prev, o.out, "redeemExactOut: preview != execution");
        if (burned != o.out) _violate("redeemExactOut: burned != reported");
        if (o.got + OP_TOL < o.amt) _violate("redeemExactOut: delivered < amountOut");
        if (host.fairValue(o.tok, o.got) > _valueOfShares(x, burned) + OP_TOL) _violate("redeemExactOut: exit pays more than share of backing");
        _checkVaultHeldUnchanged(o.i, x.vaultHeld, "redeemExactOut");
    }

    // ---- honest exit sized against the vault's liquid inventory of token 0 (WETH / receipt) ----
    // redeemExactOut sizes by share fraction, so it rarely fits the small liquid buffer; this one sizes the
    // amountOut as 10%..95% of outCap so deficits (and hence queue/claim paths) are actually reached.
    function redeemToLiquid(uint256 actorSeed, uint256 bps) external {
        bytes32 t = _tag("redeemToLiquid");
        Op memory o;
        o.i = _actor(actorSeed);
        o.tok = host.tokens()[0];
        uint256 bal = _bal(se, o.i);
        if (bal == 0) { ++skipCalls[t]; return; }
        o.amt = host.outCap(o.tok) * bound(bps, 1_000, 9_500) / 10_000;
        if (o.amt < 1e12) { ++skipCalls[t]; return; }
        try IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(o.tok), o.amt) returns (uint256 p) { o.prev = p; } catch { ++skipCalls[t]; return; }
        if (o.prev == 0 || o.prev > bal) { ++skipCalls[t]; return; }
        Snap memory x = _snap();
        o.balB = _bal(o.tok, o.i);
        _exOut(o, se, bal, o.tok, o.amt, false);
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        uint256 burned = bal - _bal(se, o.i);
        o.got = _bal(o.tok, o.i) - o.balB;
        _chkEq(o.prev, o.out, "redeemToLiquid: preview != execution");
        if (burned != o.out) _violate("redeemToLiquid: burned != reported");
        if (o.got + OP_TOL < o.amt) _violate("redeemToLiquid: delivered < amountOut");
        if (host.fairValue(o.tok, o.got) > _valueOfShares(x, burned) + OP_TOL) _violate("redeemToLiquid: exit pays more than share of backing");
        _checkVaultHeldUnchanged(o.i, x.vaultHeld, "redeemToLiquid");
    }

    // ---- asset -> asset ----
    function swapAssets(uint256 actorSeed, uint256 inSeed, uint256 outSeed, uint256 amt) external {
        bytes32 t = _tag("swapAssets");
        if (!host.supportsSwap()) { ++skipCalls[t]; return; }
        Op memory o;
        o.i = _actor(actorSeed);
        o.tok = _tok(inSeed);
        address tout = _tok(outSeed);
        if (o.tok == tout) tout = _tok(outSeed + 1);
        o.amt = bound(amt, 1e15, 50 ether);
        if (host.fairValue(tout, host.outCap(tout)) < host.fairValue(o.tok, o.amt) * 2) { ++skipCalls[t]; return; }
        _fund(o.i, o.tok, o.amt + 2); // +2: rebasing-token mint rounding
        _approve(o.i, o.tok);
        Snap memory x = _snap();
        bool previewOk;try IStandardExchangeIn(se).previewExchangeIn(IERC20(o.tok), o.amt, IERC20(tout)) returns (uint256 p, uint256) { o.prev = p; previewOk = true; } catch {}
        o.balB = _bal(tout, o.i);
        _exIn(o, o.tok, o.amt, tout, false);
        if (!o.ok && !previewOk) { ++skipCalls[_tag("swapAssets_routeUnsupported")]; return; } // route not offered
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        o.got = _bal(tout, o.i) - o.balB;
        _chkExitPreview(o.prev, o.out, "swapAssets: preview != execution");
        if (host.fairValue(tout, o.got) > host.fairValue(o.tok, o.amt) + OP_TOL) _violate("swapAssets: out value > in value");
        _checkVaultHeldUnchanged(o.i, x.vaultHeld, "swapAssets");
    }

    // ---- SY deposit / redeem (standard route) ----
    function syDeposit(uint256 actorSeed, uint256 tokSeed, uint256 amt) external {
        bytes32 t = _tag("syDeposit");
        Op memory o;
        o.i = _actor(actorSeed);
        o.tok = _tok(tokSeed);
        o.amt = bound(amt, 1e15, 200 ether);
        _fund(o.i, o.tok, o.amt + 2); // +2: rebasing-token mint rounding
        _approve(o.i, o.tok);
        Snap memory x = _snap();
        try ISYLocal(se).previewDeposit(o.tok, o.amt) returns (uint256 p) { o.prev = p; } catch {}
        uint256 v = host.fairValue(o.tok, o.amt);
        (o.ok, o.r) = _call(o.i, se, abi.encodeCall(ISYLocal.deposit, (address(wallets[o.i]), o.tok, o.amt, 0)));
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        o.out = _u(o.r);
        _chkEq(o.prev, o.out, "syDeposit: previewDeposit != execution");
        if (o.out > _sharesForMax(x, v)) {
            console2.log("syDeposit out / fairMax / value", o.out, _sharesForMax(x, v), v);
            console2.log("  nav / supply", x.nav, x.supply);
            _violate("syDeposit: free shares");
        }
        _checkVaultHeldUnchanged(o.i, x.vaultHeld, "syDeposit");
    }

    function syRedeem(uint256 actorSeed, uint256 tokSeed, uint256 frac) external {
        bytes32 t = _tag("syRedeem");
        Op memory o;
        o.i = _actor(actorSeed);
        o.shB = _bal(se, o.i);
        o.sh = o.shB * bound(frac, 1, 10_000) / 10_000;
        if (o.sh == 0) { ++skipCalls[t]; return; }
        Snap memory x = _snap();
        bool okp;
        (o.tok, okp) = _pickOut(tokSeed, _valueOfShares(x, o.sh));
        if (!okp) { ++skipCalls[t]; return; }
        try ISYLocal(se).previewRedeem(o.tok, o.sh) returns (uint256 p) { o.prev = p; } catch {}
        o.balB = _bal(o.tok, o.i);
        (o.ok, o.r) = _call(o.i, se, abi.encodeCall(ISYLocal.redeem, (address(wallets[o.i]), o.sh, o.tok, 0, false)));
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        o.got = _bal(o.tok, o.i) - o.balB;
        _chkExitPreview(o.prev, _u(o.r), "syRedeem: previewRedeem != execution");
        if (o.shB - _bal(se, o.i) != o.sh) _violate("syRedeem: burned != own shares requested");
        if (host.fairValue(o.tok, o.got) > _valueOfShares(x, o.sh) + OP_TOL) _violate("syRedeem: exit pays more than share of backing");
        _checkVaultHeldUnchanged(o.i, x.vaultHeld, "syRedeem");
    }

    // ---- honest atomic integrator pretransfer (router pattern, transfer+consume in one tx) ----
    function routerPretransferMint(uint256 actorSeed, uint256 tokSeed, uint256 amt, bool exactOut) external {
        bytes32 t = _tag(exactOut ? "routerPretransferMintOut" : "routerPretransferMintIn");
        Op memory o;
        o.i = _honest(actorSeed);
        o.tok = _tok(tokSeed);
        o.amt = bound(amt, 1e15, 100 ether);
        Snap memory x = _snap();
        bytes memory consume;
        if (exactOut) {
            o.sh = _sharesFor(x, host.fairValue(o.tok, o.amt)) / 2;
            if (o.sh == 0) { ++skipCalls[t]; return; }
            try IStandardExchangeOut(se).previewExchangeOut(IERC20(o.tok), IERC20(se), o.sh) returns (uint256 p) { o.amt = p; } catch { ++skipCalls[t]; return; }
            if (o.amt == 0) { ++skipCalls[t]; return; }
            consume = abi.encodeCall(IStandardExchangeOut.exchangeOut, (IERC20(o.tok), o.amt, IERC20(se), o.sh, address(wallets[o.i]), true, block.timestamp));
        } else {
            consume = abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(o.tok), o.amt, IERC20(se), 0, address(wallets[o.i]), true, block.timestamp));
        }
        _fund(o.i, o.tok, o.amt + 2); // +2: rebasing-token mint rounding (see note above)
        o.shB = _bal(se, o.i);
        o.balB = _bal(o.tok, o.i);
        try wallets[o.i].exec2(o.tok, abi.encodeCall(IERC20.transfer, (se, o.amt)), se, consume) { o.ok = true; } catch (bytes memory r) { o.r = r; }
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        uint256 minted = _bal(se, o.i) - o.shB;
        uint256 paid = o.balB - _bal(o.tok, o.i);
        if (minted > _sharesForMax(x, host.fairValue(o.tok, paid))) _violate("routerPretransferMint: free shares");
        if (IERC20(se).balanceOf(se) != x.vaultHeld) _violate("routerPretransferMint: vault-held shares changed");
    }

    // ================================================================== ADVERSARY
    function advDonate(uint256 tokSeed, uint256 amt, bool bareTok) external {
        bytes32 t = _tag("advDonate");
        address tok = _tok(tokSeed);
        if (bareTok && host.bare() != address(0)) tok = host.bare();
        amt = bound(amt, 1, 20 ether);
        _fund(ADV, tok, amt);
        uint256 vb = _bareOnVault();
        uint256 give = _bal(tok, ADV);
        if (give > amt) give = amt;
        (bool ok,) = _call(ADV, tok, abi.encodeCall(IERC20.transfer, (se, give)));
        _res(t, ok);
        _noteBare(vb);
    }

    function advDonateShares(uint256 frac) external {
        bytes32 t = _tag("advDonateShares");
        uint256 sh = _bal(se, ADV) * bound(frac, 1, 10_000) / 10_000;
        if (sh == 0) { ++skipCalls[t]; return; }
        (bool ok,) = _call(ADV, se, abi.encodeCall(IERC20.transfer, (se, sh)));
        _res(t, ok);
    }

    /// pretransfer `amt`, declare `decl` <= amt (surplus stays on the vault)
    function advPretransferMint(uint256 tokSeed, uint256 amt, uint256 declBps) external {
        bytes32 t = _tag("advPretransferMint");
        Op memory o;
        o.i = ADV;
        o.tok = _tok(tokSeed);
        o.amt = bound(amt, 1e15, 100 ether);
        uint256 decl = o.amt * bound(declBps, 1, 10_000) / 10_000;
        if (decl == 0) decl = o.amt;
        _fund(ADV, o.tok, o.amt + 2);
        Snap memory x = _snap();
        o.hs = _honestShares();
        o.shB = _bal(se, ADV);
        o.prev = _bareOnVault();
        try wallets[ADV].exec2(
            o.tok, abi.encodeCall(IERC20.transfer, (se, o.amt)),
            se, abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(o.tok), decl, IERC20(se), 0, address(wallets[ADV]), true, block.timestamp))
        ) { o.ok = true; } catch (bytes memory r) { o.r = r; }
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        _noteBare(o.prev);
        uint256 minted = _bal(se, ADV) - o.shB;
        if (minted > _sharesForMax(x, host.fairValue(o.tok, o.amt))) _violate("advPretransferMint: free shares");
        _checkHonestUntouched(o.hs, "advPretransferMint");
    }

    /// pretransfer + exact-out mint with unbounded maxAmountIn (exercises credit/refund-to-caller)
    function advPretransferMintOutSweep(uint256 tokSeed, uint256 amt, uint256 shareBps) external {
        bytes32 t = _tag("advPretransferMintOutSweep");
        Op memory o;
        o.i = ADV;
        o.tok = _tok(tokSeed);
        o.amt = bound(amt, 1e15, 100 ether);
        Snap memory x = _snap();
        o.sh = _sharesFor(x, host.fairValue(o.tok, o.amt)) * bound(shareBps, 1, 9_000) / 10_000;
        if (o.sh == 0) { ++skipCalls[t]; return; }
        try IStandardExchangeOut(se).previewExchangeOut(IERC20(o.tok), IERC20(se), o.sh) returns (uint256) {}
        catch { ++skipCalls[_tag("advPretransferMintOutSweep_routeUnsupported")]; return; }
        // pre-existing unbooked balance of tok = adversary's own earlier donation (honest never leave any)
        o.out = _unbooked(o.tok);
        _fund(ADV, o.tok, o.amt + 2);
        o.hs = _honestShares();
        o.shB = _bal(se, ADV);
        o.balB = _bal(o.tok, ADV);
        o.prev = _bareOnVault();
        try wallets[ADV].exec2(
            o.tok, abi.encodeCall(IERC20.transfer, (se, o.amt)),
            se, abi.encodeCall(IStandardExchangeOut.exchangeOut, (IERC20(o.tok), type(uint256).max, IERC20(se), o.sh, address(wallets[ADV]), true, block.timestamp))
        ) { o.ok = true; } catch (bytes memory r) { o.r = r; }
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        _noteBare(o.prev);
        uint256 minted = _bal(se, ADV) - o.shB;
        uint256 tA = _bal(o.tok, ADV);
        uint256 netPaid = o.balB > tA ? o.balB - tA : 0;
        if (minted != o.sh) _violate("advPretransferMintOutSweep: minted != amountOut");
        uint256 uv = host.fairValue(o.tok, o.out);
        x.nav = x.nav > uv ? x.nav - uv : 0; // the vault prices the mint ex-credit
        if (host.fairValue(o.tok, netPaid) + uv < _valueOfSharesMin(x, minted)) _violate("advPretransferMintOutSweep: free shares (net paid < fair)");
        _checkHonestUntouched(o.hs, "advPretransferMintOutSweep");
    }

    /// park shares on the vault then consume them through one of three pretransfer exits
    function advShareExit(uint256 tokSeed, uint256 frac, uint8 mode) external {
        mode = uint8(bound(mode, 0, 2));
        bytes32 t = _tag(mode == 0 ? "advShareExit_SYinternal" : (mode == 1 ? "advShareExit_outPretransfer" : "advShareExit_inPretransfer"));
        Op memory o;
        o.i = ADV;
        o.shB = _bal(se, ADV);
        o.sh = o.shB * bound(frac, 1, 10_000) / 10_000;
        if (o.sh == 0) { ++skipCalls[t]; return; }
        Snap memory x = _snap();
        bool okp;
        (o.tok, okp) = _pickOut(tokSeed, _valueOfShares(x, o.sh + x.vaultHeld));
        if (!okp) { ++skipCalls[t]; return; }
        bytes memory consume;
        if (mode == 0) {
            consume = abi.encodeCall(ISYLocal.redeem, (address(wallets[ADV]), o.sh, o.tok, 0, true));
        } else if (mode == 1) {try IStandardExchangeIn(se).previewExchangeIn(IERC20(se), o.sh / 2 + 1, IERC20(o.tok)) returns (uint256 p, uint256) { o.amt = p; } catch {}
            if (o.amt == 0) { ++skipCalls[t]; return; }
            consume = abi.encodeCall(IStandardExchangeOut.exchangeOut, (IERC20(se), o.sh, IERC20(o.tok), o.amt, address(wallets[ADV]), true, block.timestamp));
        } else {
            consume = abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(se), o.sh, IERC20(o.tok), 0, address(wallets[ADV]), true, block.timestamp));
        }
        o.hs = _honestShares();
        o.balB = _bal(o.tok, ADV);
        try wallets[ADV].exec2(se, abi.encodeCall(IERC20.transfer, (se, o.sh)), se, consume) { o.ok = true; } catch (bytes memory r) { o.r = r; }
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        o.got = _bal(o.tok, ADV) - o.balB;
        // SY redeem / pretransfer exits only own shares: consumption bounded by adversary-owned (parked + wallet)
        uint256 owned = x.vaultHeld + o.shB;
        uint256 after_ = IERC20(se).balanceOf(se) + _bal(se, ADV);
        if (after_ > owned) _violate("advShareExit: adversary share total increased");
        uint256 consumed = owned > after_ ? owned - after_ : 0;
        if (host.fairValue(o.tok, o.got) > _valueOfShares(x, consumed) + OP_TOL) _violate("advShareExit: exit pays more than share of backing");
        _checkHonestUntouched(o.hs, "advShareExit");
    }

    // ---- exogenous: rate move, finalize, warp ----
    function advRateMove(uint256 seed) external {
        bytes32 t = _tag("advRateMove");
        uint256[N] memory b;
        for (uint256 i; i < N; ++i) b[i] = wealth(i);
        uint256 bareB = _bareOnVault();
        bool moved = host.moveRate(seed);
        if (moved && ghostBareDonated + 1e6 >= bareB) _noteBare(bareB); // rebase of donated idle balance
        if (!moved) { ++skipCalls[t]; return; }
        ++rateMoves;
        for (uint256 i; i < N; ++i) exo[i] += int256(wealth(i)) - int256(b[i]);
        _res(t, true);
    }

    function finalizeQueue() external {
        bytes32 t = _tag("finalizeQueue");
        if (!host.hasQueue()) { ++skipCalls[t]; return; }
        (uint256 pend, uint256 fin) = host.portPending();
        if (pend == fin) { ++skipCalls[t]; return; }
        host.finalizeAll();
        _res(t, true);
    }

    function warp(uint256 secs) external {
        bytes32 t = _tag("warp");
        vm.warp(block.timestamp + bound(secs, 1, 7 days));
        _res(t, true);
    }

    // ---- rebalance (permissionless) with queue accounting check ----
    function rebalance(uint256 actorSeed) external {
        bytes32 t = _tag("rebalance");
        if (!host.hasRebalance()) { ++skipCalls[t]; return; }
        Op memory o;
        o.i = _actor(actorSeed);
        (uint256 pendB, uint256 finB) = host.hasQueue() ? host.portPending() : (0, 0);
        bool withPending = pendB > finB;
        if (!allowRequeue && withPending) {
            // QUARANTINE staking-rebalance-requeue-pending (confirmed_dos, no principal loss): rebalance with
            // unfinalized requests re-queues the deficit ignoring pending. Scoped narrowly: up to
            // REQUEUE_BUDGET such calls per run still execute (value invariants keep running over the
            // multi-request state); only the strict "pending <= max(deficit, existing)" bound is relaxed
            // to the weaker bound the known bug still satisfies: new face <= existing + deficit.
            if (requeueUsed >= REQUEUE_BUDGET) {
                ++skipCalls[_tag("rebalance_quarantined")];
                return;
            }
            ++requeueUsed;
            t = _tag("rebalance_withPending");
        }
        uint256 target = host.reportedNav() * _targetPct() / 1e18;
        uint256 liquidAfterClaim = _liquid() + finB;
        uint256 deficit = target > liquidAfterClaim ? target - liquidAfterClaim : 0;
        uint256 navFairB = host.fairNav();
        o.hs = _honestShares();
        (o.ok,) = _call(o.i, se, abi.encodeCall(IRebalanceLocal.rebalance, ()));
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        if (host.hasQueue()) {
            (uint256 pendA,) = host.portPending();
            uint256 existing = pendB - finB;
            if (withPending && !allowRequeue) {
                if (pendA > existing + deficit + 1e3) _qviolate("rebalance(withPending): new face > existing + deficit");
            } else {
                uint256 cap = deficit > existing ? deficit : existing;
                if (pendA > cap + 1e3) _qviolate("rebalance: pending face after > max(deficit, existing pending)");
            }
        }
        if (host.fairNav() + 1e6 < navFairB) _violate("rebalance: fair NAV dropped");
        _checkHonestUntouched(o.hs, "rebalance");
    }

    function _liquid() internal view returns (uint256) {
        (bool ok, bytes memory r) = se.staticcall(abi.encodeWithSignature("liquidReserveEth()"));
        return ok ? abi.decode(r, (uint256)) : 0;
    }

    function _targetPct() internal view returns (uint256) {
        (bool ok, bytes memory r) = se.staticcall(abi.encodeWithSignature("targetLiquidReservePercentage()"));
        return ok ? abi.decode(r, (uint256)) : 0;
    }

    // ---- IERC4626 mutators (quarantined on staking SEs: crane-erc4626facet-mint) ----
    function _q4626() internal returns (bool quarantined) {
        if (!host.has4626Mutators() && !allow4626) {
            ++skipCalls[_tag("erc4626_quarantined")];
            return true;
        }
    }

    function erc4626Deposit(uint256 actorSeed, uint256 amt) external {
        bytes32 t = _tag("erc4626Deposit");
        if (_q4626()) return;
        Op memory o;
        o.i = _actor(actorSeed);
        o.tok = IERC4626(se).asset();
        o.amt = bound(amt, 1e15, 100 ether);
        _fund(o.i, o.tok, o.amt);
        o.amt = _bal(o.tok, o.i) < o.amt ? _bal(o.tok, o.i) : o.amt;
        _approve(o.i, o.tok);
        Snap memory x = _snap();
        try IERC4626(se).previewDeposit(o.amt) returns (uint256 p) { o.prev = p; } catch {}
        (o.ok, o.r) = _call(o.i, se, abi.encodeCall(IERC4626.deposit, (o.amt, address(wallets[o.i]))));
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        o.out = _u(o.r);
        _chkEq(o.prev, o.out, "erc4626Deposit: previewDeposit != execution");
        if (o.out > _sharesForMax(x, host.fairValue(o.tok, o.amt))) _violate("erc4626Deposit: free shares");
        if (o.out == 0) _violate("erc4626Deposit: zero shares for nonzero deposit");
    }

    /// adversary: claim the vault's existing asset balance via IERC4626.deposit (no transfer)
    function erc4626DepositExisting() external {
        bytes32 t = _tag("erc4626DepositExisting");
        if (_q4626()) return;
        address a = IERC4626(se).asset();
        uint256 w = IERC20(a).balanceOf(se);
        if (w == 0) { ++skipCalls[t]; return; }
        uint256 shB = _bal(se, ADV);
        uint256 aB = _bal(a, ADV);
        (bool ok, bytes memory r) = _call(ADV, se, abi.encodeCall(IERC4626.deposit, (w, address(wallets[ADV]))));
        _res(t, ok, r);
        if (!ok) return;
        uint256 minted = _bal(se, ADV) - shB;
        if (minted > OP_TOL && _bal(a, ADV) == aB) _violate("erc4626DepositExisting: shares minted for zero transfer");
    }

    function erc4626Redeem(uint256 actorSeed, uint256 frac, bool viaWithdraw) external {
        bytes32 t = _tag(viaWithdraw ? "erc4626Withdraw" : "erc4626Redeem");
        if (_q4626()) return;
        Op memory o;
        o.i = _actor(actorSeed);
        o.tok = IERC4626(se).asset();
        o.shB = _bal(se, o.i);
        o.sh = o.shB * bound(frac, 1, 10_000) / 10_000;
        if (o.sh == 0) { ++skipCalls[t]; return; }
        Snap memory x = _snap();
        o.balB = _bal(o.tok, o.i);
        if (viaWithdraw) {
            try IERC4626(se).previewRedeem(o.sh) returns (uint256 p) { o.amt = p; } catch {}
            if (o.amt == 0) { ++skipCalls[t]; return; }
            (o.ok, o.r) = _call(o.i, se, abi.encodeCall(IERC4626.withdraw, (o.amt, address(wallets[o.i]), address(wallets[o.i]))));
        } else {
            (o.ok, o.r) = _call(o.i, se, abi.encodeCall(IERC4626.redeem, (o.sh, address(wallets[o.i]), address(wallets[o.i]))));
        }
        _res(t, o.ok, o.r);
        if (!o.ok) return;
        o.got = _bal(o.tok, o.i) - o.balB;
        uint256 burned = o.shB - _bal(se, o.i);
        if (host.fairValue(o.tok, o.got) > _valueOfShares(x, burned) + OP_TOL) _violate("erc4626Redeem: exit pays more than share of backing");
        if (burned > 0 && o.got == 0) _violate("erc4626Redeem: shares burned for zero assets");
    }

    // ================================================================== sanity-only (not fuzzed)
    function sanityFund(uint256 i, address token, uint256 amt) external {
        _fund(i, token, amt);
    }

    function sanityExec(uint256 i, address target, bytes calldata data) external returns (bytes memory) {
        return wallets[i].exec(target, data);
    }

    /// append one line per run (aggregated by the operator across runs for non-vacuity evidence)
    function persist(string memory path) external {
        // ts prefix: vm.writeLine appends across forge invocations; the aggregator keeps only lines
        // stamped after the invocation started (see tools/p4ssy/run.sh).
        string memory line = string.concat("ts=", vm.toString(vm.unixTime()), ";");
        for (uint256 k; k < tags.length; ++k) {
            bytes32 t = tags[k];
            line = string.concat(line, tagName[t], "=", vm.toString(okCalls[t]), "/", vm.toString(failCalls[t]), "/", vm.toString(skipCalls[t]), ";");
            for (uint256 j; j < failSels[t].length; ++j) {
                bytes4 sel = failSels[t][j];
                line = string.concat(line, tagName[t], "!", vm.toString(abi.encodePacked(sel)), "=", vm.toString(failSelCount[t][sel]), ";");
            }
        }
        line = string.concat(line, "viol=", vm.toString(violations), ";qviol=", vm.toString(queueViolations), ";rate=", vm.toString(rateMoves));
        vm.writeLine(path, line);
    }

    // ================================================================== reporting
    function report() external view {
        console2.log("---- per-selector calls (ok / fail / skip) ----");
        for (uint256 k; k < tags.length; ++k) {
            bytes32 t = tags[k];
            console2.log(string.concat(tagName[t], " ok/fail/skip"), okCalls[t], failCalls[t], skipCalls[t]);
            for (uint256 j; j < failSels[t].length; ++j) {
                console2.log("   revert sel / count", vm.toString(abi.encodePacked(failSels[t][j])), failSelCount[t][failSels[t][j]]);
            }
        }
        console2.log("violations", violations, "queueViolations", queueViolations);
        console2.log("rateMoves", rateMoves);
        for (uint256 i; i < N; ++i) {
            console2.log("actor", i);
            console2.logInt(netGain(i));
        }
    }

    function totals() external view returns (uint256 ok, uint256 fail) {
        for (uint256 k; k < tags.length; ++k) {
            if (!_isMoneyTag(tags[k])) continue;
            ok += okCalls[tags[k]];
            fail += failCalls[tags[k]];
        }
    }
}

/// @notice Shared invariant assertions; mixed into each family test contract.
abstract contract P4Invariants is Test {
    uint256 internal constant VALUE_TOL = 1e9; // 1 gwei of numeraire across a whole run

    function _h() internal view virtual returns (P4Handler);

    function _selectors() internal view returns (bytes4[] memory s) {
        bool with4626 = _h().host().has4626Mutators();
        bool withQueue = _h().host().hasQueue();
        bool withReb = _h().host().hasRebalance();
        s = new bytes4[](with4626 ? 21 : 18);
        s[17] = P4Handler.redeemToLiquid.selector;
        if (!with4626) {
            // QUARANTINE crane-erc4626facet-mint: IERC4626 mutators are excluded from targeting (not
            // just skipped in-handler) so they do not consume call budget; sanity test re-enables them.
            _fill(s);
            return _compact(s, withQueue, withReb);
        }
        _fill(s);
        s[18] = P4Handler.erc4626Deposit.selector;
        s[19] = P4Handler.erc4626Redeem.selector;
        s[20] = P4Handler.erc4626DepositExisting.selector;
        s = _compact(s, withQueue, withReb);
    }

    function _fill(bytes4[] memory s) internal pure {
        s[0] = P4Handler.mintExactIn.selector;
        s[1] = P4Handler.mintExactOut.selector;
        s[2] = P4Handler.redeemExactIn.selector;
        s[3] = P4Handler.redeemExactOut.selector;
        s[4] = P4Handler.swapAssets.selector;
        s[5] = P4Handler.syDeposit.selector;
        s[6] = P4Handler.syRedeem.selector;
        s[7] = P4Handler.routerPretransferMint.selector;
        s[8] = P4Handler.advDonate.selector;
        s[9] = P4Handler.advDonateShares.selector;
        s[10] = P4Handler.advPretransferMint.selector;
        s[11] = P4Handler.advPretransferMintOutSweep.selector;
        s[12] = P4Handler.advShareExit.selector;
        s[13] = P4Handler.advRateMove.selector;
        s[14] = P4Handler.finalizeQueue.selector;
        s[15] = P4Handler.warp.selector;
        s[16] = P4Handler.rebalance.selector;
    }

    /// @dev drop statically-inert selectors (finalizeQueue without a queue, rebalance without one)
    function _compact(bytes4[] memory s, bool withQueue, bool withReb) internal pure returns (bytes4[] memory r) {
        uint256 n;
        for (uint256 k; k < s.length; ++k) {
            if (!withQueue && s[k] == P4Handler.finalizeQueue.selector) continue;
            if (!withReb && s[k] == P4Handler.rebalance.selector) continue;
            ++n;
        }
        r = new bytes4[](n);
        n = 0;
        for (uint256 k; k < s.length; ++k) {
            if (!withQueue && s[k] == P4Handler.finalizeQueue.selector) continue;
            if (!withReb && s[k] == P4Handler.rebalance.selector) continue;
            r[n++] = s[k];
        }
    }

    function invariant_perOpChecks() public view {
        P4Handler h = _h();
        if (h.violations() != 0) console2.log("first:", h.firstViolation());
        assertEq(h.violations(), 0, "per-op: no free shares / exits <= share of backing / preview==exec");
    }

    function invariant_queueAccounting() public view {
        P4Handler h = _h();
        if (h.queueViolations() != 0) console2.log("first:", h.firstQueueViolation());
        assertEq(h.queueViolations(), 0, "queue: pending <= deficit");
    }

    function invariant_adversaryNoProfit() public view {
        P4Handler h = _h();
        int256 g = h.netGain(h.ADV());
        if (g > int256(VALUE_TOL)) console2.logInt(g);
        assertLe(g, int256(VALUE_TOL), "adversary extracted value at fair price");
    }

    function invariant_honestNoLoss() public view {
        P4Handler h = _h();
        for (uint256 i; i < 3; ++i) {
            int256 g = h.netGain(i);
            if (g < -int256(VALUE_TOL)) console2.logInt(g);
            assertGe(g, -int256(VALUE_TOL), "honest actor lost value at fair price");
        }
    }
}
