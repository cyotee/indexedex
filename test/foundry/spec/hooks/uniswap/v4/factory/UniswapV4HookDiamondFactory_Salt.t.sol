// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {MinimalDiamondCallBackProxy} from "@crane/contracts/proxies/MinimalDiamondCallBackProxy.sol";

import {
    TestBase_UniswapV4HookDiamondPackageCallBackFactory
} from "test/foundry/spec/hooks/uniswap/v4/factory/TestBase_UniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";
import {
    UniswapV4HookDiamondFactoryStubPackage
} from "test/foundry/spec/hooks/uniswap/v4/factory/stubs/UniswapV4HookDiamondFactoryStubPackage.sol";
import {
    IUniswapV4HookDiamondFactoryStubPackage
} from "test/foundry/spec/hooks/uniswap/v4/factory/stubs/IUniswapV4HookDiamondFactoryStubPackage.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

contract UniswapV4HookDiamondFactory_SaltTest is TestBase_UniswapV4HookDiamondPackageCallBackFactory {
    using BetterEfficientHashLib for bytes;

    /// H13: off-chain create2 equals factory.calcAddress
    function test_H13_offChainCreate2MatchesCalcAddress() public {
        address predicted = hookFactory.calcAddress(
            IUniswapV4HookDiamondPackage(address(stubPkg)), stubArgs, stubMineNonce
        );
        bytes memory processed = stubPkg.processArgs(stubArgs);
        bytes32 packageSalt = stubPkg.calcSalt(processed);
        address offChain = Create2Lib.predictAddress(
            address(hookFactory), hookFactory.PROXY_INIT_HASH(), packageSalt, stubMineNonce
        );
        assertEq(predicted, offChain, "calcAddress must match pure create2 recipe");
    }

    /// H7: mine lib exhausts with maxLoop=0; production MAX_LOOP constant is 160_444
    function test_H7_mineExhaustionAndProductionMaxLoop() public view {
        assertEq(hookFactory.MAX_LOOP(), 160_444);
        assertEq(Create2Lib.MAX_LOOP, 160_444);

        bytes32 packageSalt = stubPkg.calcSalt(stubArgs);
        // maxLoop=0 guarantees no iterations → HookMineExhausted (H7 unit proof).
        try this._mineExhaust(packageSalt) {
            revert("expected HookMineExhausted");
        } catch (bytes memory reason) {
            assertEq(bytes4(reason), Create2Lib.HookMineExhausted.selector);
        }
    }

    function _mineExhaust(bytes32 packageSalt) external pure {
        Create2Lib.findMineNonce(address(1), bytes32(uint256(2)), packageSalt, 1, 0);
    }

    /// H8: two stub package addresses, same PRODUCT_ID + args → same predicted; second returns existing
    function test_H8_packageAddressNotInSalt_sameBinding() public {
        UniswapV4HookDiamondFactoryStubPackage pkg2 = new UniswapV4HookDiamondFactoryStubPackage(
            IVaultRegistryDeployment(address(indexedexManager))
        );
        // Same PRODUCT_ID + value → same packageSalt regardless of package address.
        bytes32 salt1 = stubPkg.calcSalt(stubArgs);
        bytes32 salt2 = pkg2.calcSalt(stubArgs);
        assertEq(salt1, salt2, "package address must not enter calcSalt");

        address first = _deployStubPremine();
        address second = hookFactory.deployWithMineNonce(
            IUniswapV4HookDiamondPackage(address(pkg2)), stubArgs, stubMineNonce
        );
        assertEq(first, second, "first-deployer-wins across package address swap");
    }

    function test_previewFinalSaltComposition() public pure {
        bytes32 packageSalt = keccak256("pkg");
        uint256 mineNonce = 7;
        assertEq(
            Create2Lib.previewFinalSalt(packageSalt, mineNonce),
            keccak256(abi.encode(packageSalt, mineNonce))
        );
    }

    function test_PROXY_INIT_HASH_stable() public view {
        assertEq(hookFactory.PROXY_INIT_HASH(), keccak256(type(MinimalDiamondCallBackProxy).creationCode));
    }
}
