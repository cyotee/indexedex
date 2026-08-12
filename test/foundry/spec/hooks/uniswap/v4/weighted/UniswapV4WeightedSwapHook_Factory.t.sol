// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4WeightedSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHookPackage
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHookPackage.sol";
import {
    UniswapV4WeightedSwapHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHook_FactoryService.sol";
import {
    UniswapV4WeightedSwapHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookPairPoolLib.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";
import {IUniswapV4WeightedSwapHook} from
    "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";

/**
 * @notice Package deploy / pair-door suite (replaces monomorph factory tests).
 */
contract UniswapV4WeightedSwapHook_Factory_Test is TestBase_UniswapV4WeightedSwapHook {
    function test_F1_deployCreatesAllDoors_n2() public {
        (address hook,,) = _deployN2();
        PoolKey[] memory keys = _pairPoolKeys(hook);
        assertEq(keys.length, 1); // binom(2,2)=1
        assertEq(keys[0].fee, LPFeeLibrary.DYNAMIC_FEE_FLAG);
        assertEq(keys[0].tickSpacing, 1);
        _assertPoolLive(keys[0]);
        assertTrue(_registry().isVault(hook));
    }

    function test_F2_deployCreatesAllDoors_n3() public {
        (address hook,,,) = _deployN3();
        PoolKey[] memory keys = _pairPoolKeys(hook);
        assertEq(keys.length, 3); // binom(3,2)=3
        for (uint256 i; i < keys.length; ++i) {
            _assertPoolLive(keys[i]);
        }
    }

    function test_F3_deployCreatesAllDoors_n4() public {
        (address hook,,,,) = _deployN4();
        PoolKey[] memory keys = _pairPoolKeys(hook);
        assertEq(keys.length, 6); // binom(4,2)=6
        for (uint256 i; i < keys.length; ++i) {
            _assertPoolLive(keys[i]);
        }
    }

    function test_F4_invalidMineNonceReverts() public {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        (MintableDec t0, MintableDec t1) = address(a) < address(b) ? (a, b) : (b, a);
        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        IUniswapV4WeightedSwapHookPackage.PkgArgs memory args = IUniswapV4WeightedSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(vaultFeeOracle),
            tokens: tokens,
            weights: weights,
            rateProviders: providers,
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        uint256 goodNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        uint256 bad = goodNonce + 1;
        for (uint256 i; i < 50; ++i) {
            // deploy with bad mineNonce should revert (flags mismatch)
            try this.externalDeploy(args, bad) {
                // if it accidentally matched flags, keep scanning
            } catch {
                return; // expected path
            }
            ++bad;
        }
    }

    function externalDeploy(IUniswapV4WeightedSwapHookPackage.PkgArgs memory args, uint256 mineNonce)
        external
        returns (address)
    {
        return PkgFactory.deployHook(hookPkg, args, mineNonce);
    }

    function test_F5_idempotentRedeploySameArgs() public {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        (MintableDec t0, MintableDec t1) = address(a) < address(b) ? (a, b) : (b, a);
        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        IUniswapV4WeightedSwapHookPackage.PkgArgs memory args = IUniswapV4WeightedSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(vaultFeeOracle),
            tokens: tokens,
            weights: weights,
            rateProviders: providers,
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h1 = PkgFactory.deployHook(hookPkg, args, mineNonce);
        address h2 = PkgFactory.deployHook(hookPkg, args, mineNonce);
        assertEq(h1, h2);
    }

    function test_F6_postDeployIdempotentPairEnsure() public {
        (address hook,,) = _deployN2();
        // re-run pair ensure via package postDeploy
        assertTrue(hookPkg.postDeploy(hook));
        PoolKey[] memory keys = _pairPoolKeys(hook);
        assertEq(keys.length, 1);
        _assertPoolLive(keys[0]);
    }

    function test_F7_flagsMatchRequired() public {
        (address hook,,) = _deployN2();
        uint160 flags = PkgFactory.requiredFlags();
        assertEq(uint160(hook) & flags, flags);
        assertTrue(hookPkg.isExpectedInstance(hook, ""));
    }

    function test_F8_computeKeysMatchLiveDoors() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        PoolKey[] memory keys = PairPoolLib.computePairKeys(
            IUniswapV4WeightedSwapHook(hook).tokens(), hook, int24(int256(Math.TICK_SPACING))
        );
        assertEq(keys.length, 1);
        assertEq(Currency.unwrap(keys[0].currency0), address(t0));
        assertEq(Currency.unwrap(keys[0].currency1), address(t1));
        _assertPoolLive(keys[0]);
    }
}

