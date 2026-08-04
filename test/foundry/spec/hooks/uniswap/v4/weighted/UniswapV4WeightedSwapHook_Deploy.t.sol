// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4WeightedSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {
    UniswapV4WeightedSwapHook_FactoryService as FactoryService
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHook_FactoryService.sol";

contract UniswapV4WeightedSwapHook_Deploy_Test is TestBase_UniswapV4WeightedSwapHook {
    function test_D1_deployN2_flagsAndImmutables() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        IUniswapV4WeightedSwapHook h = IUniswapV4WeightedSwapHook(hook);
        assertEq(address(h.poolManager()), address(pm));
        assertEq(address(h.feeOracle()), address(vaultFeeOracle));
        assertEq(h.numTokens(), 2);
        assertEq(h.token(0), address(t0));
        assertEq(h.token(1), address(t1));
        uint256[] memory w = h.getNormalizedWeights();
        assertEq(w[0] + w[1], 1e18);
        // hook address encodes required flags
        uint160 flags = FactoryService.requiredFlags();
        assertEq(uint160(hook) & flags, flags);
        // isFullBook false before mint
        assertFalse(h.isFullBook());
    }

    function test_D2_invalidWeightSumReverts() public {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        (MintableDec t0, MintableDec t1) = address(a) < address(b) ? (a, b) : (b, a);
        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 4e17; // sum != 1e18
        address[] memory providers = new address[](2);
        FactoryService.DeployParams memory p;
        p.create3Factory = create3Factory;
        p.poolManager = pm;
        p.feeOracle = vaultFeeOracle;
        p.tokens = tokens;
        p.weights = weights;
        p.rateProviders = providers;
        (uint256 mineNonce,) = FactoryService.mineNonceFor(p);
        vm.expectRevert();
        factory.deployWithMineNonce(tokens, weights, providers, "", mineNonce);
    }

    function test_D3_unsortedTokensRevert() public {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        address lo = address(a) < address(b) ? address(a) : address(b);
        address hi = address(a) < address(b) ? address(b) : address(a);
        address[] memory tokens = new address[](2);
        tokens[0] = hi;
        tokens[1] = lo; // unsorted
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
        // mine may still find nonce; deploy must revert on validation
        // If salt mine uses tokens as-is, just call deploy with nonce 0 after expect
        vm.expectRevert();
        factory.deployWithMineNonce(tokens, weights, providers, "", 0);
    }

    function test_D4_lpMetadataPrefix() public {
        (address hook,,) = _deployN2();
        // name/symbol via IERC20Metadata
        string memory sym = IERC20Meta(hook).symbol();
        assertTrue(bytes(sym).length >= 4);
        // WGT- prefix
        bytes memory b = bytes(sym);
        assertEq(b[0], "W");
        assertEq(b[1], "G");
        assertEq(b[2], "T");
        assertEq(b[3], "-");
    }
}

interface IERC20Meta {
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
}
