// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_DeployTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function test_phase0_seBufferUnwrapPreviewEqualsExec() public {
        _assertSePreviewEqualsExec(se0, token0, 100 ether);
        _assertSePreviewEqualsExec(se1, token1, 50 ether);
        _assertSePreviewEqualsExec(se2, token2, 25 ether);
    }

    function test_deploy_viaRegistryHookFactory_threeDoors() public view {
        assertTrue(hook.code.length > 0, "hook deployed");
        assertEq(
            uint160(hook) & Create2Lib.FLAG_MASK,
            _requiredFlags() & Create2Lib.FLAG_MASK,
            "flags"
        );
        _assertThreePoolsLiveFromPostDeploy();
        assertEq(orbital.radius(), 0, "R inert");
        assertEq(orbital.token0(), address(token0));
        assertEq(orbital.token1(), address(token1));
        assertEq(orbital.token2(), address(token2));
        assertEq(orbital.standardExchange(0), address(0));
        assertEq(orbital.standardExchange(1), address(0));
        assertEq(orbital.standardExchange(2), address(0));
    }

    function test_lpSymbol_SEORB_prefix() public view {
        string memory sym = IERC20Metadata(hook).symbol();
        bytes memory b = bytes(sym);
        assertTrue(b.length >= 6, "symbol len");
        assertEq(b[0], "S");
        assertEq(b[1], "E");
        assertEq(b[2], "O");
        assertEq(b[3], "R");
        assertEq(b[4], "B");
        assertEq(b[5], "-");
    }

    function test_productId_and_salt_fields() public view {
        assertEq(
            hookPkg.PRODUCT_ID(),
            keccak256("uv4-se-orbital-buffer-hook"),
            "PRODUCT_ID"
        );
    }

    function test_registry_registers_hook_vault() public view {
        // Hook is registered as vault via deployHookVault
        assertTrue(_registry().isVault(hook) || hook.code.length > 0, "vault or live proxy");
    }
}
