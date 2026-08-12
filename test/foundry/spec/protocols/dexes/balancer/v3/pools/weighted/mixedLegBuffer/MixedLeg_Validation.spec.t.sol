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
 * @title MixedLeg_ValidationSpec
 * @notice Deploy-time validation: weights, layout, duplicate pair buffer/vault.
 * @dev Uses default U=2 P=1 fixture only for package availability; deploys additional pools.
 */
contract MixedLeg_ValidationSpec is TestBase_MixedLegWeightedBufferPool {
    function test_reject_weightsNotSumToOne() public {
        IMixedLegWeightedBufferPoolPkg.PkgArgs memory args = _buildPkgArgs(0, 1);
        args.weights[0] = 0.4e18;
        args.weights[1] = 0.4e18; // sum 0.8e18
        vm.expectRevert(IMixedLegWeightedBufferPool.InvalidWeights.selector);
        mixedLegPkg.deployPool(args);
    }

    function test_reject_weightBelowMin() public {
        IMixedLegWeightedBufferPoolPkg.PkgArgs memory args = _buildPkgArgs(0, 1);
        // min weight is 1e16 (1%); 0.5e16 is too small
        args.weights[0] = 0.5e16;
        args.weights[1] = 1e18 - 0.5e16;
        vm.expectRevert(IMixedLegWeightedBufferPool.InvalidWeights.selector);
        mixedLegPkg.deployPool(args);
    }

    function test_reject_weightLengthMismatch() public {
        IMixedLegWeightedBufferPoolPkg.PkgArgs memory args = _buildPkgArgs(0, 1);
        uint256[] memory bad = new uint256[](3);
        bad[0] = 0.34e18;
        bad[1] = 0.33e18;
        bad[2] = 0.33e18;
        args.weights = bad;
        vm.expectRevert(abi.encodeWithSelector(IMixedLegWeightedBufferPool.WeightLengthMismatch.selector, 2, 3));
        mixedLegPkg.deployPool(args);
    }

    function test_reject_arrayLengthMismatch_unpaired() public {
        IMixedLegWeightedBufferPoolPkg.PkgArgs memory args = _buildPkgArgs(0, 1);
        args.unpairedCount = 1;
        // unpairedTokens still length 0
        vm.expectRevert(IMixedLegWeightedBufferPool.ArrayLengthMismatch.selector);
        mixedLegPkg.deployPool(args);
    }

    function test_reject_duplicateBufferToken() public {
        // Need two pairs with same buffer - force after pair1 SE exists
        _deployExtraSeVault(1);
        IERC20[] memory unpaired = new IERC20[](0);
        IRateProvider[] memory unpairedRps = new IRateProvider[](0);
        IERC20[] memory buffers = new IERC20[](2);
        IStandardExchange[] memory vaults = new IStandardExchange[](2);
        IRateProvider[] memory pairRps = new IRateProvider[](2);
        buffers[0] = IERC20(address(dai));
        buffers[1] = IERC20(address(dai)); // duplicate buffer
        vaults[0] = IStandardExchange(address(seVault));
        vaults[1] = IStandardExchange(address(seVault1));
        pairRps[0] = IRateProvider(address(0));
        pairRps[1] = IRateProvider(address(0));
        uint256[] memory weights = new uint256[](4);
        for (uint256 i; i < 4; ++i) {
            weights[i] = 0.25e18;
        }

        IMixedLegWeightedBufferPoolPkg.PkgArgs memory args = IMixedLegWeightedBufferPoolPkg.PkgArgs({
            unpairedCount: 0,
            unpairedTokens: unpaired,
            unpairedRateProviders: unpairedRps,
            pairCount: 2,
            bufferTokens: buffers,
            standardExchangeVaults: vaults,
            pairRateProviders: pairRps,
            weights: weights
        });

        vm.expectRevert(
            abi.encodeWithSelector(IMixedLegWeightedBufferPool.DuplicatePoolToken.selector, address(dai))
        );
        mixedLegPkg.deployPool(args);
    }

    function test_reject_duplicateVaultShare() public {
        IERC20[] memory unpaired = new IERC20[](0);
        IRateProvider[] memory unpairedRps = new IRateProvider[](0);
        IERC20[] memory buffers = new IERC20[](2);
        IStandardExchange[] memory vaults = new IStandardExchange[](2);
        IRateProvider[] memory pairRps = new IRateProvider[](2);
        buffers[0] = IERC20(address(dai));
        buffers[1] = IERC20(address(usdt));
        vaults[0] = IStandardExchange(address(seVault));
        vaults[1] = IStandardExchange(address(seVault)); // same vault/share
        pairRps[0] = IRateProvider(address(0));
        pairRps[1] = IRateProvider(address(0));
        uint256[] memory weights = new uint256[](4);
        for (uint256 i; i < 4; ++i) {
            weights[i] = 0.25e18;
        }

        IMixedLegWeightedBufferPoolPkg.PkgArgs memory args = IMixedLegWeightedBufferPoolPkg.PkgArgs({
            unpairedCount: 0,
            unpairedTokens: unpaired,
            unpairedRateProviders: unpairedRps,
            pairCount: 2,
            bufferTokens: buffers,
            standardExchangeVaults: vaults,
            pairRateProviders: pairRps,
            weights: weights
        });

        vm.expectRevert(
            abi.encodeWithSelector(IMixedLegWeightedBufferPool.DuplicatePoolToken.selector, address(seVault))
        );
        mixedLegPkg.deployPool(args);
    }

    function test_reject_tooManyTokens() public {
        // U=1 P=4 → T=9 > 8
        IERC20[] memory unpaired = new IERC20[](1);
        IRateProvider[] memory unpairedRps = new IRateProvider[](1);
        unpaired[0] = IERC20(address(usdc));
        unpairedRps[0] = IRateProvider(address(0));
        IERC20[] memory buffers = new IERC20[](4);
        IStandardExchange[] memory vaults = new IStandardExchange[](4);
        IRateProvider[] memory pairRps = new IRateProvider[](4);
        // dummy distinct addresses for layout check only (validation hits before deploy)
        buffers[0] = IERC20(address(dai));
        buffers[1] = IERC20(address(usdt));
        buffers[2] = IERC20(address(weth));
        buffers[3] = IERC20(address(wsteth));
        vaults[0] = IStandardExchange(address(seVault));
        vaults[1] = IStandardExchange(bob);
        vaults[2] = IStandardExchange(lp);
        vaults[3] = IStandardExchange(alice);
        for (uint256 i; i < 4; ++i) {
            pairRps[i] = IRateProvider(address(0));
        }
        uint256[] memory weights = new uint256[](9);
        uint256 each = uint256(1e18) / 9;
        uint256 sum;
        for (uint256 i; i < 9; ++i) {
            weights[i] = each;
            sum += each;
        }
        weights[0] += uint256(1e18) - sum;

        IMixedLegWeightedBufferPoolPkg.PkgArgs memory args = IMixedLegWeightedBufferPoolPkg.PkgArgs({
            unpairedCount: 1,
            unpairedTokens: unpaired,
            unpairedRateProviders: unpairedRps,
            pairCount: 4,
            bufferTokens: buffers,
            standardExchangeVaults: vaults,
            pairRateProviders: pairRps,
            weights: weights
        });

        vm.expectRevert(abi.encodeWithSelector(IMixedLegWeightedBufferPool.InvalidTokenLayout.selector, uint8(1), uint8(4)));
        mixedLegPkg.deployPool(args);
    }
}
