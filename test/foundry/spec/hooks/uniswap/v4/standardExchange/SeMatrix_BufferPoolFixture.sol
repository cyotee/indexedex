// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_StandardExchangeBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";
import {
    IStandardExchangeBufferPool
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {
    IStandardExchangeBufferPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPoolPkg.sol";
import {
    ISeMatrixBalancerHarness,
    SeMatrix_BalancerBufferPoolFixtureBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_BalancerBufferPoolFixtureBase.sol";

/// @dev Const-prod buffer pool TestBase driven as a harness: full `setUp` (Vault, nested IndexedEx
///      manager, Aerodrome DAI/USDC SE, rate provider, package, pool, `router.initialize`).
contract SeMatrix_BufferPoolHarness is TestBase_StandardExchangeBufferPool, ISeMatrixBalancerHarness {
    address private reusePkg;

    function matrixProtocol(address existingPkg) external override {
        reusePkg = existingPkg;
        setUp();
    }

    function _deployBufferPoolPkg() internal override {
        if (reusePkg != address(0)) {
            bufferPoolPkg = IStandardExchangeBufferPoolPkg(reusePkg);
            return;
        }
        super._deployBufferPoolPkg();
    }

    function matrixPool() external view override returns (address) {
        return bufferPool;
    }

    function matrixPkg() external view override returns (address) {
        return address(bufferPoolPkg);
    }

    function matrixLegSe() external view override returns (address) {
        return address(seVault);
    }

    function matrixBufferToken() external view override returns (address) {
        return address(tta);
    }

    function matrixBalancerVault() external view override returns (address) {
        return address(bv3Vault);
    }

    function matrixBalancerRouter() external view override returns (address) {
        return address(router);
    }

    function matrixMintLegShares(address recipient, uint256 tokenAmount) external override returns (uint256) {
        return mintShares(recipient, tokenAmount);
    }

    function matrixBufferBooked() external view override returns (uint256) {
        return IStandardExchangeBufferPool(bufferPool).virtualTTA();
    }
}

/**
 * @title SeMatrix_BufferPoolFixture
 * @notice StandardExchangeBufferPool SE row fixture (WP6). SE = the const-prod buffer-pool diamond
 *         (its BPT is the SE share, D38); face = the leg-0 Aerodrome SE share (18 decimals), the
 *         pool's only physical input on its native BPT route. Rounding-to-zero control (no R14 case).
 */
contract SeMatrix_BufferPoolFixture is SeMatrix_BalancerBufferPoolFixtureBase {
    constructor(Ctx memory c, address existingPkg) SeMatrix_BalancerBufferPoolFixtureBase(c) {
        _bind(new SeMatrix_BufferPoolHarness(), existingPkg);
    }

    function familyName() external pure override returns (string memory) {
        return "StandardExchangeBufferPool";
    }
}
