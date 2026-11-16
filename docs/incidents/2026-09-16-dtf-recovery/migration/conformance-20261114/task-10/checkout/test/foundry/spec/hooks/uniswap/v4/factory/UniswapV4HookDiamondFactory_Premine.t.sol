// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {
    TestBase_UniswapV4HookDiamondPackageCallBackFactory
} from "test/foundry/spec/hooks/uniswap/v4/factory/TestBase_UniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    IUniswapV4HookDiamondFactoryStubPackage
} from "test/foundry/spec/hooks/uniswap/v4/factory/stubs/IUniswapV4HookDiamondFactoryStubPackage.sol";

contract UniswapV4HookDiamondFactory_PremineTest is TestBase_UniswapV4HookDiamondPackageCallBackFactory {
    /// H5: deployWithMineNonce happy path
    function test_H5_premineHappyPath() public {
        address predicted = hookFactory.calcAddress(
            IUniswapV4HookDiamondPackage(address(stubPkg)), stubArgs, stubMineNonce
        );
        address proxy = _deployStubPremine();
        assertEq(proxy, predicted);
        assertTrue(proxy.code.length > 0);
    }

    /// H6: wrong nonce → InvalidHookFlags
    function test_H6_wrongNonceRevertsInvalidHookFlags() public {
        uint256 badNonce = stubMineNonce == 0 ? 1 : stubMineNonce - 1;
        address predicted = hookFactory.calcAddress(
            IUniswapV4HookDiamondPackage(address(stubPkg)), stubArgs, badNonce
        );
        uint160 want = stubPkg.requiredHookFlags() & hookFactory.FLAG_MASK();
        if ((uint160(predicted) & hookFactory.FLAG_MASK()) == want) {
            badNonce = stubMineNonce + 1;
            predicted = hookFactory.calcAddress(
                IUniswapV4HookDiamondPackage(address(stubPkg)), stubArgs, badNonce
            );
            while ((uint160(predicted) & hookFactory.FLAG_MASK()) == want) {
                badNonce++;
                predicted = hookFactory.calcAddress(
                    IUniswapV4HookDiamondPackage(address(stubPkg)), stubArgs, badNonce
                );
            }
        }
        uint160 got = uint160(predicted) & hookFactory.FLAG_MASK();
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapV4HookDiamondPackageCallBackFactory.InvalidHookFlags.selector, predicted, got, want
            )
        );
        hookFactory.deployWithMineNonce(IUniswapV4HookDiamondPackage(address(stubPkg)), stubArgs, badNonce);
    }

    function test_autoMineSmoke() public {
        bytes memory args = abi.encode(IUniswapV4HookDiamondFactoryStubPackage.PkgArgs({value: 99}));
        address proxy = hookFactory.deploy(IUniswapV4HookDiamondPackage(address(stubPkg)), args);
        assertTrue(proxy.code.length > 0);
        assertEq(uint160(proxy) & hookFactory.FLAG_MASK(), stubPkg.requiredHookFlags() & hookFactory.FLAG_MASK());
    }
}
