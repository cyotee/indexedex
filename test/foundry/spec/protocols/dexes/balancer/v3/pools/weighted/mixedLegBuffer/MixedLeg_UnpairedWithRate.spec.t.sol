// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

import {IMixedLegWeightedBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";
import {
    IMixedLegWeightedBufferPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolStandardVaultPkg.sol";
import {
    TestBase_MixedLegWeightedBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool.sol";

/**
 * @title FixedRateProvider
 * @notice Test-only constant rate provider for unpaired WITH_RATE legs.
 */
contract FixedRateProvider is IRateProvider {
    uint256 public immutable rate;

    constructor(uint256 rate_) {
        rate = rate_;
    }

    function getRate() external view returns (uint256) {
        return rate;
    }
}

/**
 * @title MixedLeg_UnpairedWithRateSpec
 * @notice Q9: unpaired optional rate provider → WITH_RATE; swap still works.
 * @dev Deploys a second pool (U=2 P=1) with fixed 1.0e18 RP on USDC unpaired leg.
 *      Skips default pool usage for the rated pool path.
 */
contract MixedLeg_UnpairedWithRateSpec is TestBase_MixedLegWeightedBufferPool {
    address internal ratedPool;
    FixedRateProvider internal fixedRp;

    function setUp() public virtual override {
        super.setUp();
        fixedRp = new FixedRateProvider(1e18);
        ratedPool = _deployRatedUnpairedPool();
        _initRatedPool(ratedPool);
    }

    function _deployRatedUnpairedPool() internal returns (address pool) {
        IERC20[] memory unpaired = new IERC20[](2);
        IRateProvider[] memory unpairedRps = new IRateProvider[](2);
        unpaired[0] = IERC20(address(usdc));
        unpaired[1] = IERC20(address(weth));
        unpairedRps[0] = IRateProvider(address(fixedRp));
        unpairedRps[1] = IRateProvider(address(0)); // STANDARD weth

        IERC20[] memory buffers = new IERC20[](1);
        IStandardExchange[] memory vaults = new IStandardExchange[](1);
        IRateProvider[] memory pairRps = new IRateProvider[](1);
        buffers[0] = IERC20(address(dai));
        vaults[0] = IStandardExchange(address(seVault));
        pairRps[0] = IRateProvider(address(0));

        uint256[] memory weights = _equalWeights(4);

        pool = mixedLegPkg.deployPool(
            IMixedLegWeightedBufferPoolPkg.PkgArgs({
                unpairedCount: 2,
                unpairedTokens: unpaired,
                unpairedRateProviders: unpairedRps,
                pairCount: 1,
                bufferTokens: buffers,
                standardExchangeVaults: vaults,
                pairRateProviders: pairRps,
                weights: weights
            })
        );
        approveForPool(IERC20(pool));
        vm.label(pool, "MixedLegRatedUnpaired");
    }

    function _initRatedPool(address pool) internal {
        mintSharesForPair(0, alice, ML_INIT_SHARES * 3);
        dai.mint(alice, ML_INIT_BUFFER * 2);
        usdc.mint(alice, ML_INIT_UNPAIRED * 2);
        _mintToken(address(weth), alice, ML_INIT_UNPAIRED * 2);

        IMixedLegWeightedBufferPool p = IMixedLegWeightedBufferPool(pool);
        vm.startPrank(alice);
        dai.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        IERC20(address(weth)).approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);

        (IERC20[] memory toks,,,) = bv3Vault.getPoolTokenInfo(pool);
        uint256[] memory amounts = new uint256[](toks.length);
        for (uint256 t; t < toks.length; ++t) {
            (IMixedLegWeightedBufferPool.TokenKind kind,) = p.resolveTokenIndex(t);
            if (kind == IMixedLegWeightedBufferPool.TokenKind.Unpaired) amounts[t] = ML_INIT_UNPAIRED;
            else if (kind == IMixedLegWeightedBufferPool.TokenKind.Buffer) amounts[t] = ML_INIT_BUFFER;
            else amounts[t] = ML_INIT_SHARES;
        }
        router.initialize(pool, toks, amounts, 0, false, bytes(""));
        vm.stopPrank();
    }

    function test_unpairedRateProvider_stored() public view {
        IMixedLegWeightedBufferPool p = IMixedLegWeightedBufferPool(ratedPool);
        assertEq(address(p.unpairedRateProvider(0)), address(fixedRp));
        assertEq(address(p.unpairedRateProvider(1)), address(0));
    }

    function test_swap_ratedUnpaired_to_buffer() public {
        uint256 amt = 5e18;
        usdc.mint(alice, amt);
        uint256 vtBefore = IMixedLegWeightedBufferPool(ratedPool).virtualBuffer(0);

        vm.startPrank(alice);
        usdc.approve(address(router), type(uint256).max);
        uint256 out = router.swapSingleTokenExactIn(
            ratedPool, IERC20(address(usdc)), IERC20(address(dai)), amt, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();

        assertGt(out, 0);
        assertLt(IMixedLegWeightedBufferPool(ratedPool).virtualBuffer(0), vtBefore);
    }

    function test_swap_ratedUnpaired_to_unpaired() public {
        uint256 amt = 5e18;
        usdc.mint(alice, amt);
        uint256 wethBefore = weth.balanceOf(alice);

        vm.startPrank(alice);
        usdc.approve(address(router), type(uint256).max);
        uint256 out = router.swapSingleTokenExactIn(
            ratedPool, IERC20(address(usdc)), IERC20(address(weth)), amt, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();

        assertGt(out, 0);
        assertEq(weth.balanceOf(alice), wethBefore + out);
    }
}
