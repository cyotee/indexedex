// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4WeightedSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {
    UniswapV4WeightedSwapHook_FactoryService as FactoryService
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHook_FactoryService.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";

contract UniswapV4WeightedSwapHook_Factory_Test is TestBase_UniswapV4WeightedSwapHook {
    function test_F1_deployCreatesAllDoors_n2() public {
        (address hook,,) = _deployN2();
        PoolKey[] memory keys = factory.pairPoolKeys(hook);
        assertEq(keys.length, 1); // binom(2,2)=1
        assertEq(keys[0].fee, LPFeeLibrary.DYNAMIC_FEE_FLAG);
        assertEq(keys[0].tickSpacing, 1);
        assertTrue(factory.isDeployedByFactory(hook));
    }

    function test_F2_deployCreatesAllDoors_n3() public {
        (address hook,,,) = _deployN3();
        PoolKey[] memory keys = factory.pairPoolKeys(hook);
        assertEq(keys.length, 3); // binom(3,2)=3
    }

    function test_F3_deployCreatesAllDoors_n4() public {
        (address hook,,,,) = _deployN4();
        PoolKey[] memory keys = factory.pairPoolKeys(hook);
        assertEq(keys.length, 6); // binom(4,2)=6
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
        // find a valid nonce then use invalid
        FactoryService.DeployParams memory p;
        p.create3Factory = create3Factory;
        p.poolManager = pm;
        p.feeOracle = vaultFeeOracle;
        p.tokens = tokens;
        p.weights = weights;
        p.rateProviders = providers;
        (uint256 goodNonce,) = FactoryService.mineNonceFor(p);
        uint256 bad = goodNonce + 1;
        // may accidentally match; scan for one that doesn't
        for (uint256 i; i < 50; ++i) {
            address pred = factory.predictHookAddress(tokens, weights, providers, "", bad);
            if (uint160(pred) & FactoryService.requiredFlags() != FactoryService.requiredFlags()) {
                vm.expectRevert(FactoryService.InvalidMineNonce.selector);
                factory.deployWithMineNonce(tokens, weights, providers, "", bad);
                return;
            }
            ++bad;
        }
    }

    function test_F5_idempotentRedeploy() public {
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
        FactoryService.DeployParams memory p;
        p.create3Factory = create3Factory;
        p.poolManager = pm;
        p.feeOracle = vaultFeeOracle;
        p.tokens = tokens;
        p.weights = weights;
        p.rateProviders = providers;
        (uint256 mineNonce,) = FactoryService.mineNonceFor(p);
        (address h1,) = factory.deployWithMineNonce(tokens, weights, providers, "", mineNonce);
        (address h2,) = factory.deployWithMineNonce(tokens, weights, providers, "", mineNonce);
        assertEq(h1, h2);
    }

    function test_F6_ensurePairPools_notFactoryReverts() public {
        vm.expectRevert();
        factory.ensurePairPools(address(0xDEAD));
    }

    function test_F7_ensurePairPools_idempotent() public {
        (address hook,,) = _deployN2();
        (PoolKey[] memory keys, uint8 created) = factory.ensurePairPools(hook);
        assertEq(keys.length, 1);
        assertEq(created, 0); // already live
    }

    function test_F8_predictMatchesDeploy() public {
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
        FactoryService.DeployParams memory p;
        p.create3Factory = create3Factory;
        p.poolManager = pm;
        p.feeOracle = vaultFeeOracle;
        p.tokens = tokens;
        p.weights = weights;
        p.rateProviders = providers;
        (uint256 mineNonce, address predicted) = FactoryService.mineNonceFor(p);
        assertEq(factory.predictHookAddress(tokens, weights, providers, "", mineNonce), predicted);
        (address hook,) = factory.deployWithMineNonce(tokens, weights, providers, "", mineNonce);
        assertEq(hook, predicted);
    }
}
