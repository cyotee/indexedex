// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

import {
    IMixedBufferMultiVaultStablePoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolStandardVaultPkg.sol";
import {
    TestBase_MixedBufferMultiVaultStablePool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/bases/TestBase_MixedBufferMultiVaultStablePool.sol";

/// @dev Controllable non-SUT rate provider for WITH_RATE matrix.
contract ControllableRateProvider is IRateProvider {
    uint256 public rate;

    constructor(uint256 rate_) {
        rate = rate_;
    }

    function getRate() external view returns (uint256) {
        return rate;
    }

    function setRate(uint256 rate_) external {
        rate = rate_;
    }
}

/**
 * @notice WITH_RATE matrix: RP0 STANDARD (covered elsewhere), RP1 unpaired, RP2 share, RP3 mixed.
 * @dev Redeploys pool with custom RPs after base setUp scaffolding (facets/pkg already live).
 */
contract MixedBufferMultiVaultStable_RateProviders is TestBase_MixedBufferMultiVaultStablePool {
    ControllableRateProvider internal unpairedRp;
    ControllableRateProvider internal shareRp;

    function setUp() public override {
        // Full base setUp deploys STANDARD C0; we re-deploy WITH_RATE instance in each test.
        super.setUp();
        unpairedRp = new ControllableRateProvider(1e18);
        shareRp = new ControllableRateProvider(1e18);
    }

    function _redeployWithRps(bool unpairedWithRate, bool shareWithRate) internal {
        IMixedBufferMultiVaultStablePoolPkg.PkgArgs memory args = _buildPkgArgs(1, 1);
        if (unpairedWithRate) {
            args.unpairedRateProviders[0] = IRateProvider(address(unpairedRp));
        }
        if (shareWithRate) {
            args.vaultShareRateProviders[0] = IRateProvider(address(shareRp));
        }
        mbmvsPool = mbmvsPkg.deployPool(args);
        bufferPool = mbmvsPool;
        approveForPool(IERC20(mbmvsPool));
        _initPool();
    }

    function test_RP1_unpaired_with_rate() public {
        _redeployWithRps(true, false);
        assertEq(address(mbmvs().unpairedRateProvider(0)), address(unpairedRp));
        assertEq(address(mbmvs().vaultShareRateProvider(0)), address(0));
        usdc.mint(alice, 5e18);
        vm.prank(alice);
        usdc.approve(address(router), type(uint256).max);
        assertGt(swapExactIn(alice, IERC20(address(usdc)), IERC20(address(dai)), 5e18), 0);
    }

    function test_RP2_share_with_rate() public {
        _redeployWithRps(false, true);
        assertEq(address(mbmvs().vaultShareRateProvider(0)), address(shareRp));
        dai.mint(alice, 10e18);
        assertGt(swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), 10e18), 0);
    }

    function test_RP3_mixed_with_rate() public {
        _redeployWithRps(true, true);
        assertEq(address(mbmvs().unpairedRateProvider(0)), address(unpairedRp));
        assertEq(address(mbmvs().vaultShareRateProvider(0)), address(shareRp));
        dai.mint(alice, 8e18);
        assertGt(swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), 8e18), 0);
    }

    function test_RP0_standard_baseline() public view {
        // Original setUp pool is STANDARD
        assertEq(address(mbmvs().unpairedRateProvider(0)), address(0));
        assertEq(address(mbmvs().vaultShareRateProvider(0)), address(0));
    }
}
