// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_CommonBufferMultiVaultWeightedPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultWeightedPool.sol";
import {
    ICommonBufferMultiVaultWeightedPoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/ICommonBufferMultiVaultWeightedPoolPkg.sol";
import {
    ISeMatrixBalancerHarness,
    SeMatrix_BalancerBufferPoolFixtureBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_BalancerBufferPoolFixtureBase.sol";

/// @dev Common-buffer multi-vault weighted pool TestBase driven as a harness: full `setUp`
///      (Vault, nested IndexedEx manager, Aerodrome DAI/USDC SE leg, rate provider, package, pool,
///      `router.initialize`). The pre-M10 stub skipped `_initPool`; section 11 removed the cause.
contract SeMatrix_CbmvHarness is TestBase_CommonBufferMultiVaultWeightedPool, ISeMatrixBalancerHarness {
    address private reusePkg;

    function matrixProtocol(address existingPkg) external override {
        reusePkg = existingPkg;
        setUp();
    }

    function _deployBufferPoolPkg() internal override {
        if (reusePkg != address(0)) {
            cbmvPkg = ICommonBufferMultiVaultWeightedPoolPkg(reusePkg);
            return;
        }
        super._deployBufferPoolPkg();
    }

    function matrixPool() external view override returns (address) {
        return cbmvPool;
    }

    function matrixPkg() external view override returns (address) {
        return address(cbmvPkg);
    }

    function matrixLegSe() external view override returns (address) {
        return address(_seVaultAt(0));
    }

    function matrixBufferToken() external view override returns (address) {
        return address(_bufferToken());
    }

    function matrixBalancerVault() external view override returns (address) {
        return address(bv3Vault);
    }

    function matrixBalancerRouter() external view override returns (address) {
        return address(router);
    }

    function matrixMintLegShares(address recipient, uint256 tokenAmount) external override returns (uint256) {
        return mintSharesForVault(0, recipient, tokenAmount);
    }

    function matrixBufferBooked() external view override returns (uint256) {
        return cbmv().virtualBuffer();
    }
}

/**
 * @title SeMatrix_CbmvFixture
 * @notice CommonBufferMultiVaultWeightedPool SE row fixture (WP6). SE = the pool diamond (its BPT
 *         is the SE share, D38); face = the leg-0 Aerodrome SE share (18 decimals), a physical pool
 *         token on the native BPT route. Rounding-to-zero control (no R14 case).
 */
contract SeMatrix_CbmvFixture is SeMatrix_BalancerBufferPoolFixtureBase {
    constructor(Ctx memory c, address existingPkg) SeMatrix_BalancerBufferPoolFixtureBase(c) {
        _bind(new SeMatrix_CbmvHarness(), existingPkg);
    }

    function familyName() external pure override returns (string memory) {
        return "CommonBufferMultiVaultWeightedPool";
    }
}
