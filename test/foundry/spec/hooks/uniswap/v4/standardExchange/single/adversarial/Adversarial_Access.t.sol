// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {
    TestBase_UniswapV4SingleSEBufferHook_Adversarial as AdvBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/adversarial/TestBase_UniswapV4SingleSEBufferHook_Adversarial.sol";

contract Adversarial_Access_Test is AdvBase {
    /// @notice F1: non-PM calls beforeSwap -> NotPoolManager
    function test_F1_nonPoolManager_beforeSwap_reverts() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true, amountSpecified: -1e18, sqrtPriceLimitX96: 0
        });
        vm.expectRevert();
        IHooks(hook).beforeSwap(address(this), poolKey, params, "");
    }

    /// @notice F2: diamondCut missing on live hook
    function test_F2_diamondCut_reverts() public {
        // No diamondCut facet — call should fail (no function / revert)
        (bool ok,) = hook.call(
            abi.encodeWithSelector(
                IDiamondCut.diamondCut.selector,
                new IDiamond.FacetCut[](0),
                address(0),
                ""
            )
        );
        assertFalse(ok, "diamondCut must not succeed");
    }

    /// @notice F3: no public re-bind of Repo
    function test_F3_noRebindSurface() public view {
        // Bindings immutable after init — only getters exist
        assertEq(buffer.pairToken(), address(pairToken));
        assertEq(buffer.standardExchange(), se);
        assertEq(address(buffer.poolManager()), address(pm));
    }
}
