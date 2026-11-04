// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookPairPoolLib as PairPoolLib} from
    "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookPairPoolLib.sol";

interface IMintable { function mint(address to, uint256 amount) external; }
interface IYield { function simulateYield(uint256 assets) external; }

/// @notice Stateful handler for the CP (single SE buffer) Uniswap V4 DETF.
/// The handler contract itself is the ADVERSARY (it has bytecode, so it passes every EOA-pretransfer gate).
/// Honest actors are EOAs driven with vm.prank. A neutral arbitrageur (EOA) keeps the reserve pool at the
/// handler's external fair price `pFair` around every honest action (honest users trade at fair price).
///
/// QUARANTINE (known confirmed findings, see p3_result.json):
///   - detf-spot-mint (mint priced from spot hook quote) and detf-bond-spot-valuation (bond g/principal from
///     spot composition, CONFIRMED on this CP fixture): every mint / bond (honest or adversarial) is executed
///     only after the arbitrageur restores the pool to pFair, i.e. "price move -> mint/bond" is excluded.
///   - hunt-detf-entry-no-unlock-gate: mint/bond inside an attacker-held PoolManager unlock is excluded.
///   - adversary bonding / staking are not adversary actions (bond bonus and staking yield are by-design income).
/// `quarantine=false` re-enables the trivially re-triggering paths (used only by the sanity tests).
contract DetfHandler is Test, IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    // ------------------------------------------------------------------ refs
    address public detf;
    IUniswapV4Detf public info;
    address public hook;
    IERC20 public pair;
    address public se;
    address public pv; // ERC4626 protocol vault under the SE (exogenous yield source)
    address public staking;
    address public bondNft;
    IPoolManager public pm;

    address public alice = address(0xA11CE); // honest minter / burner / round-tripper
    address public bob = address(0xB0B);     // honest bonder / claimer / staker
    address public carol = address(0xCA201); // passive DETF holder (non-participant)
    address public dave = address(0xDA7E);   // passive sDETF staker (non-participant)
    address public arb = address(0xA4B);     // neutral arbitrageur (external market)
    address public yieldSrc = address(0x71E1D);

    uint256 public pFair;  // pair wei per 1e9 DETF wei (1 DETF)
    uint256 public pFair0;
    bool public quarantine = true;
    /// H5 (detf-expansion-spot) was confirmed by this harness (low impact, see test_H5_expansionSpot_quantified);
    /// once known it is QUARANTINED from the invariant assertion (still measured in ghost_expViol / ghost_maxExpExcess).
    bool public assertExpansion = false;
    uint256 constant FEE = 3e15; // CP hook trading fee 0.3%
    uint256 constant MIN_LOCK = 30 days;
    uint256 constant MAX_LOCK = 180 days;
    uint256 constant P_SEIGNIORAGE = 5e16;

    // adversary baseline holdings
    uint256 public advPair0;
    uint256 public advSe0;
    uint256 public advDetf0;

    // ------------------------------------------------------------------ ghosts
    int256 public ghost_maxAdvProfit = type(int256).min;
    uint256 public ghost_mintViol;
    uint256 public ghost_bondViol;
    uint256 public ghost_roundTripViol;
    uint256 public ghost_leakViol;
    uint256 public ghost_expViol;
    uint256 public ghost_maxLeakPpb;      // worst protocol-equity drop per adversary action beyond slack (pair wei)
    uint256 public ghost_maxMintExcessBps;
    uint256 public ghost_maxBondExcessBps;
    uint256 public ghost_maxExpExcess;    // DETF wei realized above the fair-state realization
    uint256 public ghost_expShortfall;    // epochs consumed at a manipulated (lower) price: informational
    uint256 public ghost_arbFail;
    uint256 public ghost_arbShort;
    uint256 public ghost_overclaimAttempts;
    uint256 public ghost_overclaimAccepted;
    uint256 public ghost_overclaimSelfFunded; // over-claim covered by the adversary's own earlier unbooked gifts
    mapping(address => mapping(address => uint256)) public advGifts; // dst => token => cumulative raw transfers
    uint256 internal _lastExtra;
    address internal _lastDst;
    address internal _lastTok;
    uint256 public ghost_arbRevert;
    uint256 public ghost_arbNoConverge;
    uint256 public ghost_mintGate;   // proportional (gate-open) issuance mints
    uint256 public ghost_mintSwap;   // gate-closed swap-mint fallback
    uint256 public ghost_burnGate;   // proportional (gate-open) redemptions
    uint256 public ghost_burnSwap;   // gate-closed swap-burn fallback
    uint256 public ghost_expansionTotal;
    string public lastViolation;

    uint256[] public bobIds;
    uint256 public firstBondId;

    // ------------------------------------------------------------------ non-vacuity counters
    uint256 constant N = 23;
    uint256[N] public calls;
    uint256[N] public oks;
    string[N] internal names;

    bytes32 constant EXP_TOPIC = keccak256("NaturalSupplyExpanded(uint256,uint256,uint256)");
    bytes32 constant FUND_TOPIC = keccak256("RewardsFunded(uint256,uint256,uint256,uint256,uint256)");
    uint256 internal _lastFunded;   // DETF funded to stakers (expansion + issuance seigniorage) in the last parsed logs
    uint256 internal _potCap;       // by-design issuance seigniorage allowance set by the mint executed in this action
    uint256 public ghost_potExcess; // actions whose issuance pot exceeded p * paid value (excess is NOT excluded)
    uint256 public ghost_potTotal;

    constructor(
        address detf_, address hook_, address pair_, address se_, address pv_, address pm_, uint256 firstBondId_
    ) {
        detf = detf_;
        info = IUniswapV4Detf(detf_);
        hook = hook_;
        pair = IERC20(pair_);
        se = se_;
        pv = pv_;
        pm = IPoolManager(pm_);
        staking = info.rebasingClaimToken();
        bondNft = info.bondNftVault();
        firstBondId = firstBondId_;
        names[0] = "h_mint"; names[1] = "h_burn"; names[2] = "h_bond"; names[3] = "h_claim";
        names[4] = "h_stake"; names[5] = "h_unstake"; names[6] = "h_roundTrip"; names[7] = "h_marketMove";
        names[8] = "h_yield"; names[9] = "h_warp"; names[10] = "a_swap"; names[11] = "a_swapOut";
        names[12] = "a_burn"; names[13] = "a_mint"; names[14] = "a_donate"; names[15] = "a_pretransfer";
        names[16] = "a_pretransferClaim"; names[17] = "a_sweep"; names[18] = "a_sync"; names[19] = "a_pmSwapOp";
        names[20] = "a_syncManip"; names[21] = "a_bondNftDonate"; names[22] = "h_donate";
    }

    /// @dev called once by the test after funding.
    function init() external {
        pFair = _mid();
        pFair0 = pFair;
        address[3] memory spenders = [detf, hook, address(pm)];
        for (uint256 i; i < 3; ++i) {
            pair.approve(spenders[i], type(uint256).max);
            IERC20(detf).approve(spenders[i], type(uint256).max);
            IERC20(se).approve(spenders[i], type(uint256).max);
        }
        pair.approve(se, type(uint256).max);
        pair.approve(bondNft, type(uint256).max);
        IERC20(se).approve(bondNft, type(uint256).max);
        advPair0 = pair.balanceOf(address(this));
        advSe0 = IERC20(se).balanceOf(address(this));
        advDetf0 = IERC20(detf).balanceOf(address(this));
        advBase = int256(advValue());
    }

    function setQuarantine(bool q) external { quarantine = q; }

    function setAssertExpansion(bool a) external { assertExpansion = a; }

    function nameOf(uint256 i) external view returns (string memory) { return names[i]; }

    // ================================================================== views / valuation

    function reserves() public view returns (uint256 x, uint256 y) {
        uint256 lp = IERC20(hook).totalSupply();
        if (lp == 0) return (0, 0);
        (x, y) = _legs(lp);
    }

    function _legs(uint256 lp) internal view returns (uint256 x, uint256 y) {
        uint256[] memory a = IUniswapV4SeBufferHook(hook).previewExitProportional(lp);
        address[] memory t = IUniswapV4SeBufferHook(hook).tokens();
        for (uint256 i; i < t.length && i < a.length; ++i) {
            if (t[i] == detf) y = a[i];
            else if (t[i] == address(pair)) x = a[i];
        }
    }

    function _mid() internal view returns (uint256) {
        (uint256 x, uint256 y) = reserves();
        if (y == 0) return 0;
        return x * 1e9 / y;
    }

    function mid() external view returns (uint256) { return _mid(); }

    function protocolLp() public view returns (uint256) {
        return IERC20(hook).balanceOf(detf) + IERC20(hook).balanceOf(bondNft);
    }

    function _seValue(uint256 shares) internal view returns (uint256) {
        if (shares == 0) return 0;try IStandardExchangeIn(se).previewExchangeIn(IERC20(se), shares, pair) returns (uint256 v, uint256) { return v; }
        catch { return 0; }
    }

    /// @notice Arb-normalized protocol fair EQUITY in pair wei: E = X* + loose non-DETF assets - P * circulating.
    /// The protocol CP position is re-priced (fee-less, along its own curve) to pFair: X* = sqrt(kP), Y* = sqrt(k/P).
    /// Protocol-held DETF (pool leg Y*, loose DETF on diamond / bond NFT) is neither asset nor liability:
    /// circulating = supply - Y* - looseDETF - supplyAdj (supplyAdj removes by-design expansion minted in the action).
    /// Selling/buying protocol DETF at pFair is equity-neutral; fees and below-fair redemptions are equity-positive.
    /// `slack` = generous second-order (CP triangle) allowance for single-sided joins of loose residuals.
    function equity(uint256 supplyAdj) public view returns (int256 e, uint256 slack) {
        uint256 lp = protocolLp();
        uint256 xs;
        uint256 ys;
        if (lp > 0) {
            (uint256 x, uint256 y) = _legs(lp);
            uint256 k = x * y;
            xs = _sqrt(k / 1e9 * pFair);
            ys = _sqrt(k / pFair * 1e9);
        }
        uint256 looseD = IERC20(detf).balanceOf(detf) + IERC20(detf).balanceOf(bondNft);
        uint256 looseX = pair.balanceOf(detf) + pair.balanceOf(bondNft)
            + _seValue(IERC20(se).balanceOf(detf) + IERC20(se).balanceOf(bondNft));
        // QUARANTINE (root cause of confirmed detf-bond-spot-valuation: protocol-owned single-sided LP adds at the
        // live pool composition, no price guard): loose residuals are valued at their marginal join value at the
        // CURRENT composition, so sweeping them into a mispriced pool is equity-neutral here (first order).
        // Pair: sqrt(yP/x) per pair; DETF: sqrt(xP/y) per DETF (pair units).
        // (audit fix) loose residuals are valued at PAR (pFair), not at their join value at the live composition:
        // the composition-dependent valuation made a STANDING residual's value swing with every adversary swap
        // (false INV-4 drops), and it was then papered over with a static whole-residual slack. A residual actually
        // joined into a mispriced pool in an action is covered (up to the value consumed) in _checkLeak.
        uint256 looseVal = looseX;
        uint256 looseDVal = looseD * pFair / 1e9;
        // loose protocol DETF is kept in `circ` and valued as an asset at its join value (neutral at fair price).
        int256 circ = int256(IERC20(detf).totalSupply()) - int256(ys + supplyAdj);
        e = int256(xs + looseVal + looseDVal) - circ * int256(pFair) / 1e9;
        if (ys > 0) slack += looseD * looseD / ys * pFair / 1e9 / 2;
        if (xs > 0) slack += looseX * looseX / xs / 2;
        // NOTE (audit fix): the residual-sandwich allowance is no longer a static `looseX + looseD*P` term here
        // (that disabled INV-4 by up to the whole standing residual on EVERY action while a pretransfer sat on the
        // diamond). It is now granted per action in _checkLeak, only for residual value actually CONSUMED in it.
        slack += xs / 1e9 + 1e9; // rounding allowance: 1 ppb of the pair leg + 1 gwei
    }

    /// @notice redemption backing per DETF (pair leg of protocol LP / supply), informational.
    function redemptionBacking() public view returns (uint256) {
        uint256 lp = protocolLp();
        if (lp == 0) return 0;
        (uint256 x,) = _legs(lp);
        return x * 1e18 / IERC20(detf).totalSupply();
    }

    function advValue() public view returns (uint256 v) {
        v = pair.balanceOf(address(this)) + _seValue(IERC20(se).balanceOf(address(this)));
        v += (IERC20(detf).balanceOf(address(this)) + IERC20(staking).balanceOf(address(this))) * pFair / 1e9;
        v += IERC20(hook).balanceOf(address(this)) > 0 ? 1e30 : 0; // adversary must never hold reserve LP
    }

    /// @dev mark-to-market baseline: starts at the initial fair value; moved ONLY by exogenous repricing of the
    /// adversary's *current* holdings (external market moves of pFair, SE yield). Every trade/action is thus judged
    /// at the fair price prevailing when it happened.
    int256 public advBase;

    function advProfit() public view returns (int256) {
        return int256(advValue()) - advBase;
    }

    function bobIdsLength() external view returns (uint256) { return bobIds.length; }

    // ================================================================== arbitrage (external market)

    function _arb() internal returns (bool) {
        for (uint256 i; i < 8; ++i) {
            (uint256 x, uint256 y) = reserves();
            if (x == 0 || y == 0) return false;
            uint256 m = x * 1e9 / y;
            uint256 diff = m > pFair ? m - pFair : pFair - m;
            if (diff * 1e6 <= pFair * 20) return true; // within 0.2 bp
            uint256 k = x * y;
            if (m < pFair) {
                uint256 xt = _sqrt(k / 1e9 * pFair);
                if (xt <= x) return true;
                uint256 dx = (xt - x) * 1e18 / (1e18 - FEE) + 1;
                IMintable(address(pair)).mint(arb, dx);
                vm.prank(arb);try IStandardExchangeIn(hook).exchangeIn(pair, dx, IERC20(detf), 0, arb, false, block.timestamp) {}
                catch { ++ghost_arbFail; ++ghost_arbRevert; return false; }
            } else {
                uint256 yt = _sqrt(k / pFair * 1e9);
                if (yt <= y) return true;
                uint256 dy = (yt - y) * 1e18 / (1e18 - FEE) + 1;
                if (IERC20(detf).balanceOf(arb) < dy) { ++ghost_arbFail; ++ghost_arbShort; return false; }
                vm.prank(arb);try IStandardExchangeIn(hook).exchangeIn(IERC20(detf), dy, pair, 0, arb, false, block.timestamp) {}
                catch { ++ghost_arbFail; ++ghost_arbRevert; return false; }
            }
        }
        (uint256 x2, uint256 y2) = reserves();
        uint256 m2 = x2 * 1e9 / y2;
        uint256 d2 = m2 > pFair ? m2 - pFair : pFair - m2;
        if (d2 * 1e6 <= pFair * 50) return true; // 0.5 bp
        ++ghost_arbFail;
        ++ghost_arbNoConverge;
        return false;
    }

    function _requireArb() internal {
        if (!_arb()) revert("arb");
    }

    function arbNow() external returns (bool) { return _arb(); }

    // ================================================================== bookkeeping wrappers

    function _expansionFromLogs() internal returns (uint256 e) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 f;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == detf && logs[i].topics.length > 0 && logs[i].topics[0] == EXP_TOPIC) {
                (uint256 amt,,) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                e += amt;
            } else if (logs[i].emitter == staking && logs[i].topics.length > 0 && logs[i].topics[0] == FUND_TOPIC) {
                (uint256 amt,,,,) = abi.decode(logs[i].data, (uint256, uint256, uint256, uint256, uint256));
                f += amt;
            }
        }
        _lastFunded = f;
    }

    /// @dev supply adjustment for the leak check: natural expansion (by design, H5 tracked separately) plus the
    /// issuance seigniorage pot funded to stakers, the latter capped at p * (value paid by the mint in this action).
    function _supplyAdj(uint256 nat) internal returns (uint256) {
        uint256 pot = _lastFunded > nat ? _lastFunded - nat : 0;
        ghost_potTotal += pot;
        if (pot > _potCap) { ++ghost_potExcess; pot = _potCap; }
        return nat + pot;
    }

    function _notePot(uint256 pairEq) internal {
        _potCap += pairEq * P_SEIGNIORAGE / 1e18 * 10_005 / 10_000 * 1e9 / pFair + 1e3;
    }

    /// @dev adversary action wrapper: atomic (self-call + try), leak + profit checks.
    function _adv(uint256 id, bytes memory call_, bool leakChecked) internal returns (bool ok) {
        ++calls[id];
        (int256 b0, uint256 sl0) = equity(0);
        _loose0 = _looseValue();
        _potCap = 0;
        vm.recordLogs();
        (ok,) = address(this).call(call_);
        uint256 e = _expansionFromLogs();
        ghost_expansionTotal += e;
        if (ok) ++oks[id];
        if (ok && leakChecked) _checkLeak(id, b0, sl0, _supplyAdj(e));
        _checkProfit(id);
    }

    function _honest(uint256 id, bytes memory call_) internal {
        ++calls[id];
        vm.recordLogs();
        (bool ok,) = address(this).call(call_);
        ghost_expansionTotal += _expansionFromLogs();
        if (ok) ++oks[id];
        _arb(); // honest flow is always followed by the external market restoring fair price
        _checkProfit(id);
    }

    uint256 internal _loose0;
    uint256 public ghost_residualAllowanceUsed; // leak checks that passed ONLY thanks to the consumed-residual allowance
    uint256 public ghost_maxResidualAllowance;

    function _checkLeak(uint256 id, int256 e0, uint256 slack0, uint256 exp) internal {
        (int256 e1,) = equity(exp);
        // QUARANTINE of the NEW donate/residual-sandwich class (test_donateSandwich_quantified): loose residuals
        // (pretransfers, dust) are joined single-sided at the live composition (DETF.donate minLpOut = 0; sweep joins
        // at the live book). A same-action price move can capture up to the residual consumed in THIS action.
        uint256 l1 = _looseValue();
        uint256 resid = _loose0 > l1 ? _loose0 - l1 : 0;
        if (e1 + int256(slack0) < e0 && e1 + int256(slack0 + resid) >= e0) {
            ++ghost_residualAllowanceUsed;
            if (uint256(e0 - e1) - slack0 > ghost_maxResidualAllowance) ghost_maxResidualAllowance = uint256(e0 - e1) - slack0;
        }
        slack0 += resid;
        if (e1 + int256(slack0) < e0) {
            ++ghost_leakViol;
            uint256 d = uint256(e0 - e1);
            if (d > ghost_maxLeakPpb) {
                ghost_maxLeakPpb = d;
                lastViolation = string.concat("protocol equity drop in ", names[id]);
            }
        }
    }

    function _checkProfit(uint256 id) internal {
        int256 p = advProfit();
        if (p > ghost_maxAdvProfit) {
            ghost_maxAdvProfit = p;
            if (p > 1e15) lastViolation = string.concat("adv profit after ", names[id]);
        }
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "self");
        _;
    }

    function _dl() internal view returns (uint256) { return block.timestamp + 1 hours; }

    // ================================================================== HONEST ACTIONS

    function h_mint(uint256 amt) external { _honest(0, abi.encodeCall(this.i_mint, (alice, bound(amt, 1e15, 200 ether)))); }

    function _noteMintGate() internal {
        if (info.isMintingAllowed(pair)) ++ghost_mintGate; else ++ghost_mintSwap;
    }

    function _noteBurnGate() internal {
        if (info.isBurningAllowed(pair)) ++ghost_burnGate; else ++ghost_burnSwap;
    }

    function i_mint(address who, uint256 amt) external onlySelf {
        if (quarantine) _requireArb();
        _noteMintGate();
        vm.prank(who);(uint256 out,) = IStandardExchangeIn(detf).exchangeIn(pair, amt, IERC20(detf), 0, who, false, _dl());
        _checkMintFair(out, amt);
    }

    function _checkMintFair(uint256 out, uint256 pairEq) internal {
        uint256 val = out * pFair / 1e9;
        if (val > pairEq + pairEq / 2000 + 1e9) { // > 5 bp above fair
            ++ghost_mintViol;
            uint256 bps = (val - pairEq) * 1e4 / pairEq;
            if (bps > ghost_maxMintExcessBps) ghost_maxMintExcessBps = bps;
            lastViolation = "mint above fair";
        }
    }

    function h_burn(uint256 frac) external { _honest(1, abi.encodeCall(this.i_burn, (alice, bound(frac, 1, 10_000)))); }

    function i_burn(address who, uint256 frac) external onlySelf {
        _requireArb();
        uint256 amt = IERC20(detf).balanceOf(who) * frac / 10_000;
        require(amt > 0, "zero");
        _noteBurnGate();
        vm.prank(who);IStandardExchangeIn(detf).exchangeIn(IERC20(detf), amt, pair, 0, who, false, _dl());
    }

    function h_bond(uint256 amt, uint256 lock) external {
        _honest(2, abi.encodeCall(this.i_bond, (bound(amt, 1 ether, 200 ether), bound(lock, MIN_LOCK, MAX_LOCK + 30 days))));
    }

    function i_bond(uint256 amt, uint256 lock) external onlySelf {
        if (quarantine) _requireArb();
        vm.prank(bob);
        (uint256 id,) = info.bond(pair, amt, lock, bob, false, _dl());
        bobIds.push(id);
        uint256 principal = IDetfBondNFT(bondNft).positionOf(id).principal;
        _checkBondFair(principal, amt, lock);
    }

    function bondMultiplier(uint256 lock) public pure returns (uint256) {
        uint256 l = lock > MAX_LOCK ? MAX_LOCK : lock;
        uint256 n = (l - MIN_LOCK) * 1e18 / (MAX_LOCK - MIN_LOCK);
        return 1e18 + 5e17 * (n * n / 1e18) / 1e18;
    }

    function _checkBondFair(uint256 principal, uint256 amt, uint256 lock) internal {
        uint256 fair = amt * bondMultiplier(lock) / 1e18;
        uint256 val = principal * pFair / 1e9;
        if (val > fair + fair / 2000 + 1e9) {
            ++ghost_bondViol;
            uint256 bps = (val - fair) * 1e4 / fair;
            if (bps > ghost_maxBondExcessBps) ghost_maxBondExcessBps = bps;
            lastViolation = "bond principal above fair";
        }
    }

    /// honest donor (carol's friend = alice) donates pair through DETF.donate. QUARANTINED: arb to pFair first
    /// (DETF.donate forwards minLpOut = 0, so a price move before the donation is the NEW donate-sandwich finding).
    function h_donate(uint256 amt) external { _honest(22, abi.encodeCall(this.i_donate_h, (bound(amt, 1e15, 100 ether)))); }

    function i_donate_h(uint256 amt) external onlySelf {
        if (quarantine) _requireArb();
        vm.prank(alice);
        info.donate(pair, amt, false);
    }

    function h_claim(uint256 idx) external {
        ++calls[3];
        if (bobIds.length == 0) return;
        uint256 id = bobIds[idx % bobIds.length];
        vm.recordLogs();
        vm.prank(bob);
        try IDetfBondNFT(bondNft).claimBond{gas: 30_000_000}(id, bob) { ++oks[3]; } catch {}
        ghost_expansionTotal += _expansionFromLogs();
        _checkProfit(3);
    }

    function h_stake(uint256 frac) external { _honest(4, abi.encodeCall(this.i_stake, (bound(frac, 1, 10_000)))); }

    function i_stake(uint256 frac) external onlySelf {
        uint256 amt = IERC20(detf).balanceOf(bob) * frac / 10_000;
        require(amt > 0, "zero");
        vm.prank(bob);if (frac % 2 == 0) IStandardExchangeIn(staking).exchangeIn(IERC20(detf), amt, IERC20(staking), 0, bob, false, _dl());else IStandardExchangeIn(detf).exchangeIn(IERC20(detf), amt, IERC20(staking), 0, bob, false, _dl());
    }

    function h_unstake(uint256 frac) external { _honest(5, abi.encodeCall(this.i_unstake, (bound(frac, 1, 10_000)))); }

    function i_unstake(uint256 frac) external onlySelf {
        uint256 amt = IERC20(staking).balanceOf(bob) * frac / 10_000;
        require(amt > 0, "zero");
        vm.prank(bob);IStakedDETF(staking).exchangeIn(IERC20(staking), amt, IERC20(detf), 0, bob, false, _dl());
    }

    function h_roundTrip(uint256 amt) external { _honest(6, abi.encodeCall(this.i_roundTrip, (bound(amt, 1e15, 100 ether)))); }

    function _looseValue() internal view returns (uint256) {
        return pair.balanceOf(detf) + pair.balanceOf(bondNft) + _seValue(IERC20(se).balanceOf(detf) + IERC20(se).balanceOf(bondNft))
            + (IERC20(detf).balanceOf(detf) + IERC20(detf).balanceOf(bondNft)) * pFair / 1e9;
    }

    uint256 public ghost_roundTripResidualCapture; // round-trip gains explained by sweeping loose residuals (quarantined class)

    function i_roundTrip(uint256 amt) external onlySelf {
        _requireArb();
        uint256 loose = _looseValue();
        vm.startPrank(alice);(uint256 m,) = IStandardExchangeIn(detf).exchangeIn(pair, amt, IERC20(detf), 0, alice, false, _dl());(uint256 out,) = IStandardExchangeIn(detf).exchangeIn(IERC20(detf), m, pair, 0, alice, false, _dl());
        vm.stopPrank();
        if (out > amt) {
            // QUARANTINE (NEW residual-sandwich class): the mint's sweep joins loose residuals single-sided, moving
            // the price the immediate burn sells into; gains up to the residual's value are that known class.
            if (out <= amt + loose) {
                ++ghost_roundTripResidualCapture;
            } else {
                ++ghost_roundTripViol;
                lastViolation = "mint->burn round trip profitable";
            }
        }
    }

    function h_marketMove(uint256 bps, bool up) external {
        ++calls[7];
        bps = bound(bps, 1, 3000);
        uint256 np = up ? pFair * (10_000 + bps) / 10_000 : pFair * (10_000 - bps) / 10_000;
        if (np < pFair0 / 2 || np > pFair0 * 35 / 10) return;
        uint256 old = pFair;
        int256 v0 = int256(advValue());
        pFair = np;
        if (_arb()) { ++oks[7]; } else { pFair = old; _arb(); }
        advBase += int256(advValue()) - v0; // exogenous repricing (arb does not touch adversary holdings)
        _checkProfit(7);
    }

    function h_yield(uint256 amt) external {
        ++calls[8];
        amt = bound(amt, 1e15, 50 ether);
        IMintable(address(pair)).mint(yieldSrc, amt);
        vm.startPrank(yieldSrc);
        pair.approve(pv, amt);
        int256 v0 = int256(advValue());
        try IYield(pv).simulateYield(amt) { ++oks[8]; } catch {}
        vm.stopPrank();
        advBase += int256(advValue()) - v0; // exogenous SE yield on adversary-held SE shares
        _arb();
        _checkProfit(8);
    }

    function h_warp(uint256 secs) external {
        ++calls[9];
        vm.warp(block.timestamp + bound(secs, 1 hours, 10 days));
        ++oks[9];
    }

    // ================================================================== ADVERSARY ACTIONS

    /// @param dir 0 pair->DETF, 1 DETF->pair, 2 se->DETF, 3 DETF->se
    function a_swap(uint256 dir, uint256 amtSeed) external {
        _adv(10, abi.encodeCall(this.i_swap, (dir % 2, amtSeed)), true);
    }

    function _tokIn(uint256 dir) internal view returns (IERC20 tin, IERC20 tout) {
        if (dir == 0) return (pair, IERC20(detf));
        if (dir == 1) return (IERC20(detf), pair);
        if (dir == 2) return (IERC20(se), IERC20(detf));
        return (IERC20(detf), IERC20(se));
    }

    function i_swap(uint256 dir, uint256 amtSeed) external onlySelf {
        (IERC20 tin, IERC20 tout) = _tokIn(dir);
        uint256 bal = tin.balanceOf(address(this));
        uint256 amt = bound(amtSeed, 1, bal == 0 ? 1 : bal);IStandardExchangeIn(hook).exchangeIn(tin, amt, tout, 0, address(this), false, _dl());
    }

    function a_swapOut(uint256 dir, uint256 outSeed) external {
        _adv(11, abi.encodeCall(this.i_swapOut, (dir % 2, outSeed)), true);
    }

    function i_swapOut(uint256 dir, uint256 outSeed) external onlySelf {
        (IERC20 tin, IERC20 tout) = _tokIn(dir);
        uint256 res = tout.balanceOf(hook);
        if (address(tout) == address(pair)) (res,) = reserves();
        uint256 amtOut = bound(outSeed, 1, res / 3 + 1);
        IStandardExchangeOut(hook).exchangeOut(tin, tin.balanceOf(address(this)), tout, amtOut, address(this), false, _dl());
    }

    /// @param outSel 0 pair, 1 se
    function a_burn(uint256 frac, uint256 outSel) external {
        _adv(12, abi.encodeCall(this.i_burnAdv, (bound(frac, 1, 10_000), outSel % 2)), true);
    }

    function i_burnAdv(uint256 frac, uint256 outSel) external onlySelf {
        uint256 amt = IERC20(detf).balanceOf(address(this)) * frac / 10_000;
        require(amt > 0, "zero");
        _noteBurnGate();IStandardExchangeIn(detf).exchangeIn(IERC20(detf), amt, outSel == 0 ? pair : IERC20(se), 0, address(this), false, _dl());
    }

    /// @param inSel 0 pair, 1 se   (QUARANTINED: arb to pFair first)
    function a_mint(uint256 amtSeed, uint256 inSel) external {
        _adv(13, abi.encodeCall(this.i_mintAdv, (amtSeed, inSel % 2)), true);
    }

    function i_mintAdv(uint256 amtSeed, uint256 inSel) external onlySelf {
        if (quarantine) _requireArb();
        IERC20 tin = inSel == 0 ? pair : IERC20(se);
        uint256 bal = tin.balanceOf(address(this));
        require(bal > 1e12, "nobal");
        uint256 amt = bound(amtSeed, 1e12, bal);
        uint256 pairEq = inSel == 0 ? amt : _seValue(amt);
        _notePot(pairEq);
        _noteMintGate();(uint256 out,) = IStandardExchangeIn(detf).exchangeIn(tin, amt, IERC20(detf), 0, address(this), false, _dl());
        _checkMintFair(out, pairEq);
    }

    /// @param tokSel 0 pair, 1 se
    function a_donate(uint256 tokSel, uint256 amtSeed) external {
        _adv(14, abi.encodeCall(this.i_donate, (tokSel % 2, amtSeed)), true);
    }

    function i_donate(uint256 tokSel, uint256 amtSeed) external onlySelf {
        IERC20 t = tokSel == 0 ? pair : IERC20(se);
        uint256 bal = t.balanceOf(address(this));
        uint256 amt = amtSeed % 4 == 0 ? bound(amtSeed, 1, 1e12) : bound(amtSeed, 1e12, bal / 4 + 1e12);
        info.donate(t, amt, false);
    }

    function a_bondNftDonate(uint256 tokSel, uint256 amtSeed) external {
        _adv(21, abi.encodeCall(this.i_bondNftDonate, (tokSel % 2, amtSeed)), true);
    }

    function i_bondNftDonate(uint256 tokSel, uint256 amtSeed) external onlySelf {
        IERC20 t = tokSel == 0 ? pair : IERC20(se);
        uint256 bal = t.balanceOf(address(this));
        uint256 amt = amtSeed % 4 == 0 ? bound(amtSeed, 1, 1e12) : bound(amtSeed, 1e12, bal / 4 + 1e12);
        IDetfNftReserveDonation(bondNft).donate(t, amt, 0, false, _dl());
    }

    /// @notice raw transfer (pretransfer without claiming) of pair/se/DETF to diamond/hook/bondNft/staking.
    function a_pretransfer(uint256 tokSel, uint256 dstSel, uint256 amtSeed) external {
        _adv(15, abi.encodeCall(this.i_pretransfer, (tokSel % 3, dstSel % 4, amtSeed)), true);
    }

    function i_pretransfer(uint256 tokSel, uint256 dstSel, uint256 amtSeed) external onlySelf {
        IERC20 t = tokSel == 0 ? pair : (tokSel == 1 ? IERC20(se) : IERC20(detf));
        address dst = dstSel == 0 ? detf : (dstSel == 1 ? hook : (dstSel == 2 ? bondNft : staking));
        uint256 bal = t.balanceOf(address(this));
        // mostly dust-sized, sometimes large
        uint256 amt = amtSeed % 3 == 0 ? bound(amtSeed, 1, bal / 10 + 1) : bound(amtSeed, 1, 1e6);
        require(amt <= bal, "bal");
        t.transfer(dst, amt);
        advGifts[dst][address(t)] += amt;
    }

    /// @notice pretransfer `amt` then claim `amt + extra` through a pretransferred=true entrypoint.
    /// op: 0 mint (QUARANTINED: arb first), 1 stake DETF->sDETF, 2 donate, 3 bondNft donate
    function a_pretransferClaim(uint256 tokSel, uint256 amtSeed, uint256 extraSeed, uint256 op) external {
        op = op % 4;
        _lastExtra = 0;
        bool ok = _adv(16, abi.encodeCall(this.i_pretransferClaim, (tokSel % 2, amtSeed, extraSeed, op)), true);
        if (extraSeed % 2 == 1) {
            ++ghost_overclaimAttempts;
            if (ok && _lastExtra > 0) {
                // claimed more than this action paid in: only acceptable if covered by the adversary's own earlier
                // unbooked pretransfers to the same destination (APEX-003/004 class credit = unbooked balance).
                // (audit fix) gifts are consumed when used, so one gift cannot excuse unlimited over-claims.
                if (_lastExtra <= advGifts[_lastDst][_lastTok]) {
                    ++ghost_overclaimSelfFunded;
                    advGifts[_lastDst][_lastTok] -= _lastExtra;
                } else {
                    ++ghost_overclaimAccepted;
                }
            }
        }
    }

    function i_pretransferClaim(uint256 tokSel, uint256 amtSeed, uint256 extraSeed, uint256 op) external onlySelf {
        IERC20 t = op == 1 ? IERC20(detf) : (tokSel == 0 ? pair : IERC20(se));
        uint256 bal = t.balanceOf(address(this));
        uint256 unit = op == 1 ? 1e6 : 1e12;
        require(bal > 2 * unit, "bal");
        uint256 amt = amtSeed % 4 == 0 ? bound(amtSeed, 1, unit) : bound(amtSeed, unit, bal / 4);
        uint256 extra = extraSeed % 2 == 0 ? 0 : bound(extraSeed, 1, amt);
        address dst = op >= 2 ? bondNft : detf; // bond-NFT donate (incl. DETF-forwarded) measures the bond NFT's balance
        t.transfer(dst, amt);
        _lastExtra = extra;
        _lastDst = dst;
        _lastTok = address(t);
        if (op == 0) {
            if (quarantine) _requireArb();
            uint256 pairEq = tokSel == 0 ? amt + extra : _seValue(amt + extra);
            _notePot(pairEq * amt / (amt + extra));(uint256 out,) = IStandardExchangeIn(detf).exchangeIn(t, amt + extra, IERC20(detf), 0, address(this), true, _dl());
            _checkMintFair(out, pairEq * amt / (amt + extra)); // fair against what was actually paid
        } else if (op == 1) {(uint256 sOut,) = IStandardExchangeIn(detf).exchangeIn(t, amt + extra, IERC20(staking), 0, address(this), true, _dl());// unstake in the same action: staking yield is by-design income, not adversary profit
            IStakedDETF(staking).exchangeIn(IERC20(staking), sOut, IERC20(detf), 0, address(this), false, _dl());
        } else if (op == 2) {
            info.donate(t, amt + extra, true);
        } else {
            IDetfNftReserveDonation(bondNft).donate(t, amt + extra, 0, true, _dl());
        }
    }

    function a_sweep() external { _adv(17, abi.encodeCall(this.i_sweep, ()), true); }

    function i_sweep() external onlySelf { info.sweepDust(); }

    function a_sync() external { _adv(18, abi.encodeCall(this.i_sync, ()), true); }

    function i_sync() external onlySelf { IDETFFundedRewards(detf).synchronizeRewards(); }

    // ---------------------------------------------------------------- PoolManager unlock path
    /// @param op 0 none, 1 burn DETF->pair, 2 sweepDust, 3 synchronizeRewards, 4 donate pair,
    ///           5 mint (QUARANTINED: only when quarantine=false)
    function a_pmSwapOp(bool zeroForOne, uint256 amtSeed, uint256 op, uint256 opSeed, bool swapBack) external {
        if (op % 6 == 5) ++ghost_unlockMintAttempts;
        _adv(19, abi.encodeCall(this.i_pmSwapOp, (zeroForOne, amtSeed, op % 6, opSeed, swapBack)), true);
    }

    PoolKey internal _key;

    function i_pmSwapOp(bool zeroForOne, uint256 amtSeed, uint256 op, uint256 opSeed, bool swapBack) external onlySelf {
        _key = PairPoolLib.pairKey(detf, address(pair), PairPoolLib.PRODUCT_TICK_SPACING, IHooks(hook));
        address tin = zeroForOne ? Currency.unwrap(_key.currency0) : Currency.unwrap(_key.currency1);
        uint256 bal = IERC20(tin).balanceOf(address(this));
        require(bal > 0, "bal");
        uint256 amt = bound(amtSeed, 1, bal);
        if (op == 5 && quarantine) {
            // (audit fix) previously a blanket revert: the in-unlock mint path was never exercised. Quarantine only the
            // confirmed detf-spot-mint root cause (price move -> mint): restore pFair, keep the in-unlock swap at
            // ~1 ppm of the input-side reserve, so the unlock-held mint itself is executed and checked (INV-2a/INV-4).
            _requireArb();
            (uint256 rx, uint256 ry) = reserves();
            uint256 rin = tin == address(pair) ? rx : ry;
            uint256 cap = rin / 1e6;
            amt = bound(amtSeed, 1, (cap == 0 ? 1 : cap) < bal ? (cap == 0 ? 1 : cap) : bal);
        }
        pm.unlock(abi.encode(zeroForOne, amt, op, opSeed, swapBack));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(pm), "pm");
        (bool zfo, uint256 amt, uint256 op, uint256 opSeed, bool swapBack) =
            abi.decode(data, (bool, uint256, uint256, uint256, bool));
        // pre-pay the input (an empty PoolManager cannot fund the hook's take of the input currency)
        _pay(zfo ? _key.currency0 : _key.currency1, amt);
        BalanceDelta d1 = pm.swap(_key, SwapParams(zfo, -int256(amt), zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), "");
        int256 n0 = d1.amount0() + (zfo ? int256(amt) : int256(0));
        int256 n1 = d1.amount1() + (zfo ? int256(0) : int256(amt));
        // take the output now so the in-unlock op can use it
        _settle(_key.currency0, n0);
        _settle(_key.currency1, n1);
        _inUnlockOp(op, opSeed);
        if (swapBack) {
            int256 gotS = zfo ? n1 : n0;
            if (gotS > 0) {
                uint256 got = uint256(gotS);
                _pay(zfo ? _key.currency1 : _key.currency0, got);
                BalanceDelta d2 = pm.swap(_key, SwapParams(!zfo, -int256(got), !zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1), "");
                _settle(_key.currency0, d2.amount0() + (!zfo ? int256(got) : int256(0)));
                _settle(_key.currency1, d2.amount1() + (!zfo ? int256(0) : int256(got)));
            }
        }
        return "";
    }

    function _pay(Currency c, uint256 a) internal {
        pm.sync(c);
        IERC20(Currency.unwrap(c)).transfer(address(pm), a);
        pm.settle();
    }

    function _inUnlockOp(uint256 op, uint256 opSeed) internal {
        if (op == 1) {
            uint256 amt = IERC20(detf).balanceOf(address(this)) * bound(opSeed, 1, 5000) / 10_000;if (amt > 0) IStandardExchangeIn(detf).exchangeIn(IERC20(detf), amt, pair, 0, address(this), false, _dl());
        } else if (op == 2) {
            info.sweepDust();
        } else if (op == 3) {
            IDETFFundedRewards(detf).synchronizeRewards();
        } else if (op == 4) {
            uint256 amt = bound(opSeed, 1, pair.balanceOf(address(this)) / 10 + 1);
            info.donate(pair, amt, false);
        } else if (op == 5) {
            uint256 amt = bound(opSeed, 1e12, pair.balanceOf(address(this)) / 4 + 1e12);
            _notePot(amt);(uint256 out,) = IStandardExchangeIn(detf).exchangeIn(pair, amt, IERC20(detf), 0, address(this), false, _dl());
            _checkMintFair(out, amt);
            ++ghost_unlockMintOk;
        }
    }

    uint256 public ghost_unlockMintAttempts;
    uint256 public ghost_unlockMintOk;

    function _settle(Currency c, int256 d) internal {
        if (d < 0) {
            pm.sync(c);
            IERC20(Currency.unwrap(c)).transfer(address(pm), uint256(-d));
            pm.settle();
        } else if (d > 0) {
            pm.take(c, address(this), uint256(d));
        }
    }

    // ---------------------------------------------------------------- expansion at manipulated price (H5)
    /// @notice Warp, then compare expansion realized at the adversary-manipulated spot vs. at the arb-normalized
    /// state (snapshot/revert). Adversary pumps/dumps DETF spot through the hook then calls synchronizeRewards().
    function a_syncManip(uint256 warpSecs, uint256 dir, uint256 amtSeed) external {
        ++calls[20];
        vm.warp(block.timestamp + bound(warpSecs, 0, 3 days));
        uint256 snap = vm.snapshotState();
        _arb();
        vm.recordLogs();
        try IDETFFundedRewards(detf).synchronizeRewards() {} catch {}
        uint256 eFair = _expansionFromLogs();
        vm.revertToState(snap);
        (int256 b0, uint256 sl0) = equity(0);
        _loose0 = _looseValue();
        vm.recordLogs();
        (bool ok,) = address(this).call(abi.encodeCall(this.i_syncManip, (dir % 2, amtSeed)));
        uint256 eAct = _expansionFromLogs();
        ghost_expansionTotal += eAct;
        if (ok) {
            ++oks[20];
            if (eAct > eFair + eFair / 100 + 2) {
                ++ghost_expViol;
                if (eAct - eFair > ghost_maxExpExcess) ghost_maxExpExcess = eAct - eFair;
                lastViolation = "expansion realized above fair-state expansion";
            } else if (eFair > eAct + eAct / 100 + 2) {
                ghost_expShortfall += eFair - eAct;
            }
            _potCap = 0;
            _checkLeak(20, b0, sl0, _supplyAdj(eAct));
        }
        _checkProfit(20);
    }

    function i_syncManip(uint256 dir, uint256 amtSeed) external onlySelf {
        IERC20 tin = dir == 0 ? pair : IERC20(detf);
        IERC20 tout = dir == 0 ? IERC20(detf) : pair;
        uint256 bal = tin.balanceOf(address(this));
        require(bal > 0, "bal");IStandardExchangeIn(hook).exchangeIn(tin, bound(amtSeed, 1, bal), tout, 0, address(this), false, _dl());
        IDETFFundedRewards(detf).synchronizeRewards();
    }

    // ================================================================== utils

    function _sqrt(uint256 x) internal pure returns (uint256 z) {
        if (x == 0) return 0;
        z = x;
        uint256 y = x / 2 + 1;
        while (y < z) {
            z = y;
            y = (x / y + y) / 2;
        }
    }
}
