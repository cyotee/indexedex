// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_BindingTest is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function test_binding_0se_rawOnly() public view {
        assertFalse(orbital.isBuffered(0));
        assertFalse(orbital.isBuffered(1));
        assertFalse(orbital.isBuffered(2));
    }

    function test_binding_1se_leg0() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            _argsWithSE(true, false, false);
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        assertTrue(h.code.length > 0);
        // Read via low-level: standardExchange(0)
        (bool ok, bytes memory data) =
            h.staticcall(abi.encodeWithSignature("standardExchange(uint8)", uint8(0)));
        assertTrue(ok);
        assertEq(abi.decode(data, (address)), se0);
        (ok, data) = h.staticcall(abi.encodeWithSignature("isBuffered(uint8)", uint8(0)));
        assertTrue(ok && abi.decode(data, (bool)));
    }

    function test_binding_2se_legs01() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            _argsWithSE(true, true, false);
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        (bool ok, bytes memory data) =
            h.staticcall(abi.encodeWithSignature("standardExchange(uint8)", uint8(1)));
        assertTrue(ok);
        assertEq(abi.decode(data, (address)), se1);
    }

    function test_binding_3se_allLegs() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            _argsWithSE(true, true, true);
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        for (uint8 i; i < 3; i++) {
            (bool ok, bytes memory data) =
                h.staticcall(abi.encodeWithSignature("isBuffered(uint8)", i));
            assertTrue(ok && abi.decode(data, (bool)), "buffered");
        }
    }

    function test_binding_reject_sameSE() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.se0 = se0;
        args.se1 = se0; // same SE on two legs — reject
        vm.expectRevert();
        hookPkg.processArgs(abi.encode(args));
    }

    function test_binding_reject_rpWithoutSE() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.rp0 = address(0xB0B); // RP without SE
        vm.expectRevert();
        hookPkg.processArgs(abi.encode(args));
    }

    function test_binding_reject_sameTokens() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        args.token1 = args.token0;
        vm.expectRevert();
        hookPkg.processArgs(abi.encode(args));
    }
}
