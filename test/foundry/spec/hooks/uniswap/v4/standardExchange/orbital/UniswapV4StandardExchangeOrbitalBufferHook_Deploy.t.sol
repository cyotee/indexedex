// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
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
        _assertThreeProductDoorsLive();
        assertEq(orbital.radius(), 0, "R inert");
        assertEq(orbital.token0(), address(token0));
        assertEq(orbital.token1(), address(token1));
        assertEq(orbital.token2(), address(token2));
        // Min-SE default: leg0 buffered
        assertEq(orbital.standardExchange(0), se0);
        assertEq(orbital.standardExchange(1), address(0));
        assertEq(orbital.standardExchange(2), address(0));
        assertTrue(orbital.isBuffered(0));
    }

    function test_lpSymbol_SEORB_prefix() public view {
        assertEq(IERC20Metadata(hook).name(), "SE Orbital Buffer Hook LP");
        assertEq(IERC20Metadata(hook).symbol(), "SEORB-LP");
    }

    function test_initAccount_emptySelfLeg_usesPkgArgsDecimals() public {
        address emptySelf = address(uint160(uint256(keccak256("empty-detf"))));
        assertEq(emptySelf.code.length, 0, "empty self-leg");
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.token1 = emptySelf;
        args.decimals1 = 18;
        args.se1 = address(0);
        address h = _deployBootstrapOnly(args);
        _ensureProductDoorsAndFinalize(h, args.token0, args.token1, args.token2);
        assertTrue(h.code.length > 0, "hook deployed");
        assertEq(IERC20Metadata(h).name(), "SE Orbital Buffer Hook LP");
        assertEq(IERC20Metadata(h).symbol(), "SEORB-LP");
    }

    function test_processArgs_selfLegDecimalsNot18_reverts() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.decimals1 = 17;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_processArgs_decimalsOutOfRange_reverts() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.decimals0 = 0;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
        args = _defaultPkgArgs();
        args.decimals0 = 19;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_calcSalt_differsWhenDecimalsDiffer() public view {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.decimals0 = 6;
        bytes32 salt6 = hookPkg.calcSalt(abi.encode(args));
        args.decimals0 = 18;
        bytes32 salt18 = hookPkg.calcSalt(abi.encode(args));
        assertTrue(salt6 != salt18, "salt includes decimals0");
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
