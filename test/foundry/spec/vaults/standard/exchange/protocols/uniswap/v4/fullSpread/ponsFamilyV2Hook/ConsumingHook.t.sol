// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {UniswapV4FullSpreadPonsFamilyHookConsumingHook as Consumer} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/harness/UniswapV4FullSpreadPonsFamilyHookConsumingHook.sol";
import {HookMiner} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/HookMiner.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookConsumingHookTest[]
contract UniswapV4FullSpreadPonsFamilyHookConsumingHookTest is Acceptance {
    function test_realConsumingHookUsesFundedBlockedVaultWithoutNestedUnlock() public {
        _bootstrap();
        (, bytes32 salt) = HookMiner.find(address(this), Hooks.BEFORE_SWAP_FLAG, type(Consumer).creationCode,
            abi.encode(poolManager, address(vault), token0));
        Consumer hook = new Consumer{salt: salt}(poolManager, address(vault), token0);
        token0.transfer(address(hook), 1e18);
        poolKey.hooks = IHooks(address(hook));
        poolManager.initialize(poolKey, uint160(1) << 96);
        _seedPool(1_000_000e18);
        _externalSwap(true, 1e18);
        assertTrue(hook.observedBlocked());
        assertGt(hook.minted(), 0);
        assertEq(vault.balanceOf(address(hook)), hook.minted());
        _assertBooked();
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookConsumingHookTest[]
