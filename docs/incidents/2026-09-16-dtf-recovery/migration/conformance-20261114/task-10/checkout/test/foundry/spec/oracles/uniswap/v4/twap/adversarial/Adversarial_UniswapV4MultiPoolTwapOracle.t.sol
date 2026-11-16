// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IOracle} from "@crane/contracts/external/morpho/blue/interfaces/IOracle.sol";
import {
    TestBase_UniswapV4MultiPoolTwapOracle
} from "contracts/test/bases/TestBase_UniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4TwapAdapterErrors
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4TwapAdapterErrors.sol";
import {
    UniswapV4TwapMorphoOracle
} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapMorphoOracle.sol";
import {
    UniswapV4TwapAggregatorV3Adapter
} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapAggregatorV3Adapter.sol";

/**
 * @title Adversarial_UniswapV4MultiPoolTwapOracle
 * @notice Adv-gap, poke-then-read, multi-block, card-1, wrong-dir, Adv-cross-instance, J, F1.
 * @dev Deferred: A0 / I1 / E6 / M / O — instance holds no inventory.
 *      L2 is N/A on the instance. FoT is still forbidden if this feed is wired as an IndexedEx underlying.
 */
contract Adversarial_UniswapV4MultiPoolTwapOracle is TestBase_UniswapV4MultiPoolTwapOracle {
    uint32 internal constant SECONDS_AGO = 30;
    uint32 internal constant MAX_WRITE_AGE = 120;

    function test_AdvGap_staleThenRestore() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        assertTrue(_poke(poolKey));
        UniswapV4TwapMorphoOracle morpho = UniswapV4TwapMorphoOracle(
            twapAdapterFactory.createMorphoOracle(twapOracle, poolKey, SECONDS_AGO, true, MAX_WRITE_AGE)
        );
        _warp(MAX_WRITE_AGE + 5);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapV4TwapAdapterErrors.StaleObservation.selector, MAX_WRITE_AGE + 5, MAX_WRITE_AGE
            )
        );
        morpho.price();
        assertTrue(_poke(poolKey));
        _warp(SECONDS_AGO);
        assertEq(morpho.price(), 1e36);
    }

    function test_pokeThenRead_truncatesVsPrevTick() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        tokenA.mint(address(poolHarness), 1_000_000_000 ether);
        tokenB.mint(address(poolHarness), 1_000_000_000 ether);
        _seedFullRange(poolKey, 100_000_000 ether, 100_000_000 ether);
        assertTrue(_poke(poolKey));
        _swapToTick(poolKey, 20_000);
        _warp(1);
        assertTrue(_poke(poolKey));
        _warp(1);
        UniswapV4TwapMorphoOracle morpho = UniswapV4TwapMorphoOracle(
            twapAdapterFactory.createMorphoOracle(twapOracle, poolKey, 1, true, MAX_WRITE_AGE)
        );
        (,,, int24 recorded,) = twapOracle.getState(poolKey.toId());
        assertEq(recorded, 9116);
        assertTrue(morpho.price() > 1e36);
    }

    function test_multiBlock_cannotExceed9116TimesN() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        tokenA.mint(address(poolHarness), 2_000_000_000 ether);
        tokenB.mint(address(poolHarness), 2_000_000_000 ether);
        _seedFullRange(poolKey, 200_000_000 ether, 200_000_000 ether);
        assertTrue(_poke(poolKey));
        int24 recorded;
        for (uint256 i; i < 3; ++i) {
            int24 target = int24(int256((i + 1) * 20_000));
            _swapToTick(poolKey, target);
            _warp(1);
            assertTrue(_poke(poolKey));
            (,,, recorded,) = twapOracle.getState(poolKey.toId());
        }
        assertTrue(recorded <= 9116 * 3);
        assertEq(recorded, 9116 * 3);
    }

    function test_card1_windowOlderThanOverwriteReverts() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        assertTrue(_poke(poolKey));
        _warp(10);
        assertTrue(_poke(poolKey));
        vm.expectRevert();
        twapOracle.consult(poolKey.toId(), 1);
        _warp(5);
        int24 mean = twapOracle.consult(poolKey.toId(), 4);
        assertEq(mean, 0);
        vm.expectRevert();
        twapOracle.consult(poolKey.toId(), 6);
    }

    function test_wrongDir_morphoAndAggregatorNotEqual() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(2_000));
        assertTrue(_poke(poolKey));
        _warp(SECONDS_AGO);
        UniswapV4TwapMorphoOracle fwd = UniswapV4TwapMorphoOracle(
            twapAdapterFactory.createMorphoOracle(twapOracle, poolKey, SECONDS_AGO, true, MAX_WRITE_AGE)
        );
        UniswapV4TwapMorphoOracle inv = UniswapV4TwapMorphoOracle(
            twapAdapterFactory.createMorphoOracle(twapOracle, poolKey, SECONDS_AGO, false, MAX_WRITE_AGE)
        );
        UniswapV4TwapAggregatorV3Adapter aggFwd = UniswapV4TwapAggregatorV3Adapter(
            twapAdapterFactory.createAggregatorV3(twapOracle, poolKey, SECONDS_AGO, false, MAX_WRITE_AGE)
        );
        UniswapV4TwapAggregatorV3Adapter aggInv = UniswapV4TwapAggregatorV3Adapter(
            twapAdapterFactory.createAggregatorV3(twapOracle, poolKey, SECONDS_AGO, true, MAX_WRITE_AGE)
        );
        assertTrue(IOracle(address(fwd)).price() != IOracle(address(inv)).price());
        (, int256 aFwd,,,) = aggFwd.latestRoundData();
        (, int256 aInv,,,) = aggInv.latestRoundData();
        assertTrue(aFwd != aInv);
    }

    function test_AdvCrossInstance_pokeBDoesNotMoveA() public {
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        assertTrue(_poke(poolKey));
        UniswapV4TwapMorphoOracle morphoA = UniswapV4TwapMorphoOracle(
            twapAdapterFactory.createMorphoOracle(twapOracle, poolKey, SECONDS_AGO, true, MAX_WRITE_AGE)
        );
        PoolManager pmB = new PoolManager(address(this));
        IUniswapV4MultiPoolTwapOracle oracleB = _deployOracle(pmB);
        _initPool(pmB, poolKey, TickMath.getSqrtPriceAtTick(5_000));
        assertTrue(oracleB.update(poolKey));
        _warp(MAX_WRITE_AGE + 1);
        vm.expectRevert();
        morphoA.price();
        assertTrue(oracleB.update(poolKey));
        vm.expectRevert();
        morphoA.price();
        (, uint16 cardA,, int24 tickA,) = twapOracle.getState(poolKey.toId());
        (, uint16 cardB,, int24 tickB,) = oracleB.getState(poolKey.toId());
        assertEq(cardA, 1);
        assertEq(tickA, 0);
        assertEq(cardB, 1);
        assertEq(tickB, 5_000);
    }

    function test_J_F1_proxySurfaceAndUnowned() public {
        assertEq(IDiamondLoupe(address(twapOracle)).facetAddress(IDiamondCut.diamondCut.selector), address(0));
        vm.expectRevert();
        IDiamondCut(address(twapOracle)).diamondCut(new IDiamond.FacetCut[](0), address(0), "");
        assertEq(twapOracle.poolManager(), address(poolManager));
    }
}
