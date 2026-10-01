// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_MixedLegWeightedBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool.sol";
import {
    IMixedLegWeightedBufferPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPoolPkg.sol";
import {
    ISeMatrixBalancerHarness,
    SeMatrix_BalancerBufferPoolFixtureBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_BalancerBufferPoolFixtureBase.sol";

/// @dev Mixed-leg weighted buffer pool TestBase driven as a harness: full `setUp` (Vault, nested
///      IndexedEx manager, Aerodrome DAI/USDC SE pair 0, USDC + WETH unpaired legs, rate provider,
///      package, pool, `router.initialize`). The pre-M10 stub skipped `_initPool`.
contract SeMatrix_MixedLegHarness is TestBase_MixedLegWeightedBufferPool, ISeMatrixBalancerHarness {
    address private reusePkg;

    function matrixProtocol(address existingPkg) external override {
        reusePkg = existingPkg;
        setUp();
    }

    function _deployBufferPoolPkg() internal override {
        if (reusePkg != address(0)) {
            mixedLegPkg = IMixedLegWeightedBufferPoolPkg(reusePkg);
            return;
        }
        super._deployBufferPoolPkg();
    }

    function matrixPool() external view override returns (address) {
        return mixedLegPool;
    }

    function matrixPkg() external view override returns (address) {
        return address(mixedLegPkg);
    }

    function matrixLegSe() external view override returns (address) {
        return address(_seVaultAt(0));
    }

    function matrixBufferToken() external view override returns (address) {
        return address(_bufferAt(0));
    }

    function matrixBalancerVault() external view override returns (address) {
        return address(bv3Vault);
    }

    function matrixBalancerRouter() external view override returns (address) {
        return address(router);
    }

    function matrixMintLegShares(address recipient, uint256 tokenAmount) external override returns (uint256) {
        return mintSharesForPair(0, recipient, tokenAmount);
    }

    function matrixBufferBooked() external view override returns (uint256) {
        return ml().virtualBuffer(0);
    }
}

/**
 * @title SeMatrix_MixedLegFixture
 * @notice MixedLegWeightedBufferPool SE row fixture (WP6). SE = the pool diamond (its BPT is the
 *         SE share, D38); face = the pair-0 Aerodrome SE share (18 decimals). The USDC and WETH
 *         unpaired legs are physical inputs too, but the face stays the SE share for parity with the
 *         other five Balancer families. Rounding-to-zero control (no R14 case).
 */
contract SeMatrix_MixedLegFixture is SeMatrix_BalancerBufferPoolFixtureBase {
    constructor(Ctx memory c, address existingPkg) SeMatrix_BalancerBufferPoolFixtureBase(c) {
        _bind(new SeMatrix_MixedLegHarness(), existingPkg);
    }

    function familyName() external pure override returns (string memory) {
        return "MixedLegWeightedBufferPool";
    }
}
