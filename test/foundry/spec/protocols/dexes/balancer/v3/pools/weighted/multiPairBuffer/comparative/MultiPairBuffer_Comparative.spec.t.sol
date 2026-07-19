// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    TokenConfig,
    TokenType,
    PoolRoleAccounts
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {
    WeightedPoolFactory
} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {
    WeightedPoolContractsDeployer
} from "@crane/contracts/protocols/dexes/balancer/v3/test/utils/WeightedPoolContractsDeployer.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {
    TestBase_MultiPairStandardExchangeBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/bases/TestBase_MultiPairStandardExchangeBufferPool.sol";
import {IMultiPairStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/IMultiPairStandardExchangeBufferPool.sol";

/**
 * @title MultiPairBuffer_Comparative
 * @notice Buffer ≈ normal BV3 weighted pool under frozen SE underlyings (L15/L16).
 * @dev SE underlying (Aerodrome) is not traded after pool init for these asserts.
 *      Swap fee equalized: reference uses same static fee as multi-pair package default (0.05%).
 *      Tolerance: 0.5% relative for EXACT_IN (fees + weighted rounding).
 */
contract MultiPairBuffer_Comparative is TestBase_MultiPairStandardExchangeBufferPool, WeightedPoolContractsDeployer {
    using BetterEfficientHashLib for bytes;

    WeightedPoolFactory internal weightedFactory;
    address internal referencePool;

    uint256 internal constant REL_TOL = 0.005e18; // 0.5%

    function setUp() public virtual override {
        super.setUp();
        _deployReferenceWeightedPool();
        _initReferencePoolMatchingBuffer();
    }

    function _deployReferenceWeightedPool() internal {
        weightedFactory = deployWeightedPoolFactory(bv3Vault, 365 days, "wp-factory", "wp");
        IMultiPairStandardExchangeBufferPool p = mp();

        TokenConfig[] memory tc = new TokenConfig[](2);
        uint256 bIdx = p.bufferIndex(0);
        uint256 sIdx = p.shareIndex(0);
        tc[bIdx] = TokenConfig({
            token: p.bufferToken(0),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
        tc[sIdx] = TokenConfig({
            token: p.shareToken(0),
            tokenType: TokenType.WITH_RATE,
            rateProvider: p.rateProvider(0),
            paysYieldFees: false
        });

        uint256[] memory weights = new uint256[](2);
        weights[0] = p.weight(0);
        weights[1] = p.weight(1);

        PoolRoleAccounts memory roles =
            PoolRoleAccounts({pauseManager: address(0), swapFeeManager: address(0), poolCreator: address(0)});

        // Same default fee as multi-pair pkg (5e16).
        referencePool = weightedFactory.create(
            "RefWeighted",
            "REF",
            tc,
            weights,
            roles,
            5e16,
            address(0),
            false,
            false,
            abi.encode("MultiPairComparativeRef")._hash()
        );
        approveForPool(IERC20(referencePool));
        vm.label(referencePool, "ReferenceWeightedPool");
    }

    function _initReferencePoolMatchingBuffer() internal {
        // Match live balances: raw buffer = virtualBuffer; raw shares = buffer pool raw shares.
        IMultiPairStandardExchangeBufferPool p = mp();
        uint256 virt = p.virtualBuffer(0);
        // Match reference init to buffer live state (L25): buffer raw = virtual; shares = init seed.
        uint256 shareSeed = MP_INIT_SHARES;
        mintShares(lp, shareSeed * 3);
        dai.mint(lp, virt * 2);

        (IERC20[] memory refTokens,,,) = bv3Vault.getPoolTokenInfo(referencePool);
        uint256[] memory refAmounts = new uint256[](2);
        for (uint256 i; i < 2; ++i) {
            if (address(refTokens[i]) == address(p.bufferToken(0))) {
                refAmounts[i] = virt;
            } else {
                refAmounts[i] = shareSeed;
            }
        }

        vm.startPrank(lp);
        dai.approve(address(router), type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        router.initialize(referencePool, refTokens, refAmounts, 0, false, bytes(""));
        vm.stopPrank();
    }

    function test_comparative_exactIn_bufferToShares() public {
        // L15: do not trade Aerodrome underlying after setup.
        uint256 amountIn = 1e18;
        dai.mint(alice, amountIn * 2);

        uint256 bufOut = swapExactIn(alice, tta, IERC20(address(seVault)), amountIn);

        vm.startPrank(alice);
        uint256 refOut = router.swapSingleTokenExactIn(
            referencePool, tta, IERC20(address(seVault)), amountIn, 0, block.timestamp, false, bytes("")
        );
        vm.stopPrank();

        assertApproxEqRel(bufOut, refOut, REL_TOL, "buffer vs ref buffer->shares");
    }

    function test_comparative_exactIn_sharesToBuffer() public {
        uint256 amountIn = 1e18;
        mintShares(alice, amountIn * 2);

        uint256 bufOut = swapExactIn(alice, IERC20(address(seVault)), tta, amountIn);

        vm.startPrank(alice);
        uint256 refOut = router.swapSingleTokenExactIn(
            referencePool, IERC20(address(seVault)), tta, amountIn, 0, block.timestamp, false, bytes("")
        );
        vm.stopPrank();

        assertApproxEqRel(bufOut, refOut, REL_TOL, "buffer vs ref shares->buffer");
    }
}
