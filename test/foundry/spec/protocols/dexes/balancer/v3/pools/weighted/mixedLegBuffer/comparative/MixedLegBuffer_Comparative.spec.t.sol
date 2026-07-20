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

import {IMixedLegWeightedBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";
import {
    TestBase_MixedLegWeightedBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool.sol";

/**
 * @title MixedLegBuffer_Comparative
 * @notice MixedLeg ≈ normal BV3 weighted pool under frozen SE underlyings.
 * @dev Default fixture U=2 P=1 (USDC, WETH, DAI, SE shares). SE aero not traded after init.
 *      Fee equalized at package default 5e16. Tolerance 0.5% relative.
 */
contract MixedLegBuffer_Comparative is TestBase_MixedLegWeightedBufferPool, WeightedPoolContractsDeployer {
    using BetterEfficientHashLib for bytes;

    WeightedPoolFactory internal weightedFactory;
    address internal referencePool;

    uint256 internal constant REL_TOL = 0.005e18;

    function setUp() public virtual override {
        super.setUp();
        _deployReferenceWeightedPool();
        _initReferencePoolMatchingBuffer();
    }

    function _deployReferenceWeightedPool() internal {
        weightedFactory = deployWeightedPoolFactory(bv3Vault, 365 days, "wp-factory-ml", "wp-ml");
        IMixedLegWeightedBufferPool p = ml();
        uint256 n = p.tokenCount();

        TokenConfig[] memory tc = new TokenConfig[](n);
        uint256[] memory weights = new uint256[](n);
        for (uint256 t; t < n; ++t) {
            weights[t] = p.weight(t);
            (IMixedLegWeightedBufferPool.TokenKind kind, uint256 leg) = p.resolveTokenIndex(t);
            if (kind == IMixedLegWeightedBufferPool.TokenKind.Unpaired) {
                IRateProvider rp = p.unpairedRateProvider(leg);
                tc[t] = TokenConfig({
                    token: p.unpairedToken(leg),
                    tokenType: address(rp) == address(0) ? TokenType.STANDARD : TokenType.WITH_RATE,
                    rateProvider: rp,
                    paysYieldFees: false
                });
            } else if (kind == IMixedLegWeightedBufferPool.TokenKind.Buffer) {
                tc[t] = TokenConfig({
                    token: p.bufferToken(leg),
                    tokenType: TokenType.STANDARD,
                    rateProvider: IRateProvider(address(0)),
                    paysYieldFees: false
                });
            } else {
                tc[t] = TokenConfig({
                    token: p.shareToken(leg),
                    tokenType: TokenType.WITH_RATE,
                    rateProvider: p.pairRateProvider(leg),
                    paysYieldFees: false
                });
            }
        }

        PoolRoleAccounts memory roles =
            PoolRoleAccounts({pauseManager: address(0), swapFeeManager: address(0), poolCreator: address(0)});

        referencePool = weightedFactory.create(
            "RefWeightedML",
            "REFML",
            tc,
            weights,
            roles,
            5e16,
            address(0),
            false,
            false,
            abi.encode("MixedLegComparativeRef")._hash()
        );
        approveForPool(IERC20(referencePool));
        vm.label(referencePool, "ReferenceWeightedPoolML");
    }

    function _initReferencePoolMatchingBuffer() internal {
        IMixedLegWeightedBufferPool p = ml();
        uint256 n = p.tokenCount();

        // Fund lp for all legs matching mixed init depths.
        for (uint8 i; i < p.pairCount(); ++i) {
            mintSharesForPair(i, lp, ML_INIT_SHARES * 3);
            _mintToken(address(_bufferAt(i)), lp, ML_INIT_BUFFER * 2);
        }
        for (uint8 i; i < p.unpairedCount(); ++i) {
            _mintToken(address(_unpairedTokenAt(i)), lp, ML_INIT_UNPAIRED * 2);
        }

        (IERC20[] memory refTokens,,,) = bv3Vault.getPoolTokenInfo(referencePool);
        uint256[] memory refAmounts = new uint256[](n);
        for (uint256 t; t < n; ++t) {
            (IMixedLegWeightedBufferPool.TokenKind kind,) = p.resolveTokenIndex(t);
            if (kind == IMixedLegWeightedBufferPool.TokenKind.Unpaired) {
                refAmounts[t] = ML_INIT_UNPAIRED;
            } else if (kind == IMixedLegWeightedBufferPool.TokenKind.Buffer) {
                refAmounts[t] = p.virtualBuffer(0); // single pair in default fixture
                // For multi-pair comparative this helper is for default U2P1; buffer index via resolve
                for (uint8 pi; pi < p.pairCount(); ++pi) {
                    if (address(refTokens[t]) == address(p.bufferToken(pi))) {
                        refAmounts[t] = p.virtualBuffer(pi);
                        break;
                    }
                }
            } else {
                refAmounts[t] = ML_INIT_SHARES;
            }
        }

        vm.startPrank(lp);
        for (uint8 i; i < p.pairCount(); ++i) {
            _bufferAt(i).approve(address(router), type(uint256).max);
            IERC20(address(_seVaultAt(i))).approve(address(router), type(uint256).max);
        }
        for (uint8 i; i < p.unpairedCount(); ++i) {
            _unpairedTokenAt(i).approve(address(router), type(uint256).max);
        }
        router.initialize(referencePool, refTokens, refAmounts, 0, false, bytes(""));
        vm.stopPrank();
    }

    function test_comparative_exactIn_bufferToShares() public {
        uint256 amountIn = 1e18;
        dai.mint(alice, amountIn * 2);

        uint256 bufOut = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), amountIn);

        vm.startPrank(alice);
        uint256 refOut = router.swapSingleTokenExactIn(
            referencePool,
            IERC20(address(dai)),
            IERC20(address(seVault)),
            amountIn,
            0,
            type(uint256).max,
            false,
            bytes("")
        );
        vm.stopPrank();

        assertApproxEqRel(bufOut, refOut, REL_TOL, "buffer vs ref buffer->shares");
    }

    function test_comparative_exactIn_sharesToBuffer() public {
        uint256 amountIn = 1e18;
        mintSharesForPair(0, alice, amountIn * 2);

        uint256 bufOut = swapExactIn(alice, IERC20(address(seVault)), IERC20(address(dai)), amountIn);

        vm.startPrank(alice);
        uint256 refOut = router.swapSingleTokenExactIn(
            referencePool,
            IERC20(address(seVault)),
            IERC20(address(dai)),
            amountIn,
            0,
            type(uint256).max,
            false,
            bytes("")
        );
        vm.stopPrank();

        assertApproxEqRel(bufOut, refOut, REL_TOL, "buffer vs ref shares->buffer");
    }

    function test_comparative_exactIn_unpairedToUnpaired() public {
        uint256 amountIn = 1e18;
        usdc.mint(alice, amountIn * 2);

        uint256 bufOut = swapExactIn(alice, IERC20(address(usdc)), IERC20(address(weth)), amountIn);

        vm.startPrank(alice);
        uint256 refOut = router.swapSingleTokenExactIn(
            referencePool,
            IERC20(address(usdc)),
            IERC20(address(weth)),
            amountIn,
            0,
            type(uint256).max,
            false,
            bytes("")
        );
        vm.stopPrank();

        assertApproxEqRel(bufOut, refOut, REL_TOL, "buffer vs ref unpaired->unpaired");
    }

    function test_comparative_exactIn_unpairedToBuffer() public {
        uint256 amountIn = 1e18;
        usdc.mint(alice, amountIn * 2);

        uint256 bufOut = swapExactIn(alice, IERC20(address(usdc)), IERC20(address(dai)), amountIn);

        vm.startPrank(alice);
        uint256 refOut = router.swapSingleTokenExactIn(
            referencePool,
            IERC20(address(usdc)),
            IERC20(address(dai)),
            amountIn,
            0,
            type(uint256).max,
            false,
            bytes("")
        );
        vm.stopPrank();

        assertApproxEqRel(bufOut, refOut, REL_TOL, "buffer vs ref unpaired->buffer");
    }
}
