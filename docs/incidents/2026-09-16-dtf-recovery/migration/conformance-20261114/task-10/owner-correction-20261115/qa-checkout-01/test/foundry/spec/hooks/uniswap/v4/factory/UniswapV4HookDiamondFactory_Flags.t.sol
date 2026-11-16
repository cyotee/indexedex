// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {
    TestBase_UniswapV4HookDiamondPackageCallBackFactory
} from "test/foundry/spec/hooks/uniswap/v4/factory/TestBase_UniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    IUniswapV4HookFlags
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookFlags.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";

contract UniswapV4HookDiamondFactory_FlagsTest is TestBase_UniswapV4HookDiamondPackageCallBackFactory {
    /// H3: deployed address flags == package pure flags
    function test_H3_addressFlagsMatchPackage() public {
        address proxy = _deployStubPremine();
        uint160 want = stubPkg.requiredHookFlags() & Create2Lib.FLAG_MASK;
        assertEq(uint160(proxy) & Create2Lib.FLAG_MASK, want);
    }

    /// H12: instance requiredHookFlags() == package pure
    function test_H12_instanceFlagsMatchPackage() public {
        address proxy = _deployStubPremine();
        assertEq(
            IUniswapV4HookFlags(proxy).requiredHookFlags(),
            stubPkg.requiredHookFlags() & hookFactory.FLAG_MASK()
        );
    }
}
