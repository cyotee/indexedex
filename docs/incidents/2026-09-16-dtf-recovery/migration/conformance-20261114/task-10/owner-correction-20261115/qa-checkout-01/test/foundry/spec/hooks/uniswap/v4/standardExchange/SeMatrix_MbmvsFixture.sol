// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_MixedBufferMultiVaultStablePool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/bases/TestBase_MixedBufferMultiVaultStablePool.sol";
import {
    IMixedBufferMultiVaultStablePoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePoolPkg.sol";
import {
    ISeMatrixBalancerHarness,
    SeMatrix_BalancerBufferPoolFixtureBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_BalancerBufferPoolFixtureBase.sol";

/// @dev Mixed-buffer multi-vault stable pool TestBase driven as a harness: full `setUp`
///      (Vault, nested IndexedEx manager, Aerodrome DAI/USDC SE leg, USDC unpaired leg, rate
///      provider, package, pool, `router.initialize`). The pre-M10 stub skipped `_initPool`.
contract SeMatrix_MbmvsHarness is TestBase_MixedBufferMultiVaultStablePool, ISeMatrixBalancerHarness {
    address private reusePkg;

    function matrixProtocol(address existingPkg) external override {
        reusePkg = existingPkg;
        setUp();
    }

    function _deployBufferPoolPkg() internal override {
        if (reusePkg != address(0)) {
            mbmvsPkg = IMixedBufferMultiVaultStablePoolPkg(reusePkg);
            return;
        }
        super._deployBufferPoolPkg();
    }

    function matrixPool() external view override returns (address) {
        return mbmvsPool;
    }

    function matrixPkg() external view override returns (address) {
        return address(mbmvsPkg);
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
        return mbmvs().virtualBuffer();
    }
}

/**
 * @title SeMatrix_MbmvsFixture
 * @notice MixedBufferMultiVaultStablePool SE row fixture (WP6). SE = the pool diamond (its BPT is
 *         the SE share, D38); face = the leg-0 Aerodrome SE share (18 decimals). The pool's USDC
 *         unpaired leg is also a physical input but the face stays the SE share for parity with the
 *         other five Balancer families. Rounding-to-zero control (no R14 case).
 */
contract SeMatrix_MbmvsFixture is SeMatrix_BalancerBufferPoolFixtureBase {
    constructor(Ctx memory c, address existingPkg) SeMatrix_BalancerBufferPoolFixtureBase(c) {
        _bind(new SeMatrix_MbmvsHarness(), existingPkg);
    }

    function familyName() external pure override returns (string memory) {
        return "MixedBufferMultiVaultStablePool";
    }
}
