// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_MultiPairStandardExchangeBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/bases/TestBase_MultiPairStandardExchangeBufferPool.sol";
import {
    IMultiPairStandardExchangeBufferPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/IMultiPairStandardExchangeBufferPoolPkg.sol";
import {
    ISeMatrixBalancerHarness,
    SeMatrix_BalancerBufferPoolFixtureBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_BalancerBufferPoolFixtureBase.sol";

/// @dev Multi-pair weighted buffer pool TestBase driven as a harness: full `setUp` (Vault, nested
///      IndexedEx manager, Aerodrome DAI/USDC SE pair 0, rate provider, package, pool,
///      `router.initialize`). The pre-M10 stub skipped `_initPool`; section 11 removed the cause.
contract SeMatrix_MultiPairHarness is TestBase_MultiPairStandardExchangeBufferPool, ISeMatrixBalancerHarness {
    address private reusePkg;

    function matrixProtocol(address existingPkg) external override {
        reusePkg = existingPkg;
        setUp();
    }

    function _deployBufferPoolPkg() internal override {
        if (reusePkg != address(0)) {
            multiPairPkg = IMultiPairStandardExchangeBufferPoolPkg(reusePkg);
            return;
        }
        super._deployBufferPoolPkg();
    }

    function matrixPool() external view override returns (address) {
        return multiPairPool;
    }

    function matrixPkg() external view override returns (address) {
        return address(multiPairPkg);
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
        return mp().virtualBuffer(0);
    }
}

/**
 * @title SeMatrix_MultiPairFixture
 * @notice MultiPairStandardExchangeBufferPool SE row fixture (WP6). SE = the pool diamond (its BPT
 *         is the SE share, D38); face = the pair-0 Aerodrome SE share (18 decimals), a physical
 *         pool token on the native BPT route. Rounding-to-zero control (no R14 case).
 */
contract SeMatrix_MultiPairFixture is SeMatrix_BalancerBufferPoolFixtureBase {
    constructor(Ctx memory c, address existingPkg) SeMatrix_BalancerBufferPoolFixtureBase(c) {
        _bind(new SeMatrix_MultiPairHarness(), existingPkg);
    }

    function familyName() external pure override returns (string memory) {
        return "MultiPairStandardExchangeBufferPool";
    }
}
