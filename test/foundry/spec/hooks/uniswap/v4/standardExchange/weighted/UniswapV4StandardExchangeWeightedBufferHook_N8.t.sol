// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHook_N8
 * @notice n=8 smoke: deploy + all doors + first mint + one swap + one join.
 * @dev Creates additional tokens/SEs beyond TestBase's 4.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_N8 is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    function test_n8_smoke_deployDoorsMintSwapJoin() public {
        // Build 8 ascending tokens with ≥1 SE
        SimpleMintableERC20[8] memory toks;
        address[8] memory ses;
        toks[0] = token0;
        toks[1] = token1;
        toks[2] = token2;
        toks[3] = token3;
        ses[0] = se0;
        ses[1] = se1;
        ses[2] = se2;
        ses[3] = se3;
        for (uint256 i = 4; i < 8; ++i) {
            toks[i] = new SimpleMintableERC20(string.concat("T", vm.toString(i)), string.concat("T", vm.toString(i)));
            SimpleYieldERC4626 v = new SimpleYieldERC4626(toks[i]);
            ses[i] = _deployERC4626SE(address(v));
            toks[i].mint(user, FUND);
            vm.prank(user);
            toks[i].approve(hook, type(uint256).max); // will re-approve after redeploy
        }
        // Sort all 8 by address
        for (uint256 i; i < 8; ++i) {
            for (uint256 j = i + 1; j < 8; ++j) {
                if (address(toks[j]) < address(toks[i])) {
                    (toks[i], toks[j]) = (toks[j], toks[i]);
                    (ses[i], ses[j]) = (ses[j], ses[i]);
                }
            }
        }

        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory a;
        a.poolManager = address(pm);
        a.feeOracle = address(indexedexManager);
        a.n = 8;
        a.tokens = new address[](8);
        a.weights = new uint256[](8);
        a.standardExchanges = new address[](8);
        a.rateProviders = new address[](8);
        uint256 sum;
        for (uint256 i; i < 8; ++i) {
            a.tokens[i] = address(toks[i]);
            a.weights[i] = (i == 7) ? (WAD - sum) : (WAD / 8);
            sum += a.weights[i];
            // only first SE non-zero to keep matrix light but ≥1
            if (i == 0) a.standardExchanges[i] = ses[i];
        }

        _deployHookWithArgs(a);
        for (uint256 i; i < 8; ++i) {
            vm.prank(user);
            toks[i].approve(hook, type(uint256).max);
            vm.prank(user);
            toks[i].approve(address(swapRouter), type(uint256).max);
        }

        assertEq(weighted.numTokens(), 8);
        assertEq(weighted.pairDoorCount(), 28);
        _assertAllDoorsLive();

        uint256[] memory amounts = new uint256[](8);
        for (uint256 i; i < 8; ++i) {
            amounts[i] = 50 ether;
        }
        vm.prank(user);
        (uint256 shares,) = weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(shares, 0);

        // one single-asset join
        vm.prank(user);
        uint256 s2 = weighted.joinSingleAssetExactIn(
            a.tokens[1], 5 ether, user, 0, block.timestamp + 1 hours
        );
        assertGt(s2, 0);

        // one V4 swap between raw legs if possible
        _swapExactIn(a.tokens[1], a.tokens[2], 0.5 ether);
    }
}
