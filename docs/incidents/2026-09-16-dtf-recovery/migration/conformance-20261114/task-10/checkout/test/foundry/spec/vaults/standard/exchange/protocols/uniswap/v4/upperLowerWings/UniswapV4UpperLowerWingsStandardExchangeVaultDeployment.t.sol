// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4UpperLowerWingsStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultDeploymentTest[]
contract UniswapV4UpperLowerWingsStandardExchangeVaultDeploymentTest is TestBase_UniswapV4UpperLowerWingsStandardExchangeVault {
    function test_registryDeploymentIdentityMetadataAndEmptyBook() public view {
        assertTrue(indexedexManager.isVault(address(wings0)));
        assertTrue(indexedexManager.isVault(address(wings1)));
        assertNotEq(address(wings0), address(wings1));
        assertEq(wings0.targetToken(), address(token0));
        assertEq(wings1.targetToken(), address(token1));
        assertEq(address(wings0.poolManager()), address(pool));
        assertEq(abi.encode(wings0.poolKey()), abi.encode(key));
        assertEq(IERC20Metadata(address(wings0)).symbol(), "UV4W");
        assertEq(IERC20Metadata(address(wings0)).name(), "Uniswap V4 Upper Lower Wings Vault");
        assertEq(IERC20Metadata(address(wings0)).decimals(), token0.decimals());
        assertEq(IERC20Metadata(address(wings1)).decimals(), token1.decimals());
        assertEq(IERC20(address(wings0)).totalSupply(), 0);
        assertEq(wings0.liquidationValue().value, 0);
        address[] memory tokens = IBasicVault(address(wings0)).vaultTokens();
        assertEq(tokens.length, 1); assertEq(tokens[0], address(token0));
        IStandardVault.VaultConfig memory config = IStandardVault(address(wings1)).vaultConfig();
        assertEq(config.tokens.length, 1); assertEq(config.tokens[0], address(token1));
    }
    function test_packageSelectorsAndInterfacesInstalledOnProxy() public view {
        address[] memory facets = wingsPackage.facetAddresses();
        assertEq(facets.length, 13);
        bytes4[] memory selectors = queryFacet.facetFuncs();
        for (uint256 i; i < selectors.length; ++i) {
            assertEq(IDiamondLoupe(address(wings0)).facetAddress(selectors[i]), address(queryFacet));
        }
        bytes4[] memory ids = wingsPackage.facetInterfaces();
        for (uint256 i; i < ids.length; ++i) assertTrue(IERC165(address(wings0)).supportsInterface(ids[i]));
    }
    function test_identityIncludesTarget() public view {
        bytes32 salt0 = wingsPackage.calcSalt(abi.encode(IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgArgs(key, address(token0))));
        bytes32 salt1 = wingsPackage.calcSalt(abi.encode(IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgArgs(key, address(token1))));
        assertNotEq(salt0, salt1);
    }
    function test_unsolicitedCallbackRejected() public {
        (bool success, bytes memory result) = address(wings0).call(abi.encodeWithSignature("unlockCallback(bytes)", bytes("")));
        assertFalse(success);
        assertEq(bytes4(result), IUniswapV4UpperLowerWingsStandardExchangeVault.UnauthorizedCallback.selector);
        vm.prank(address(pool));
        (success, result) = address(wings0).call(abi.encodeWithSignature("unlockCallback(bytes)", bytes("")));
        assertFalse(success);
        assertEq(bytes4(result), IUniswapV4UpperLowerWingsStandardExchangeVault.UnauthorizedCallback.selector);
    }
    function test_invalidTargetRejected() public {
        vm.expectRevert(IUniswapV4UpperLowerWingsStandardExchangeVault.InvalidTarget.selector);
        wingsPackage.deployVault(IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgArgs(key, address(this)));
    }
    function test_nativeAndHookPoolsRejected() public {
        PoolKey memory invalid = key; invalid.currency0 = Currency.wrap(address(0));
        vm.expectRevert(IUniswapV4UpperLowerWingsStandardExchangeVault.InvalidPoolKey.selector);
        wingsPackage.deployVault(IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgArgs(invalid, address(token1)));
        invalid = key; invalid.hooks = IHooks(address(this));
        vm.expectRevert(IUniswapV4UpperLowerWingsStandardExchangeVault.InvalidPoolKey.selector);
        wingsPackage.deployVault(IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgArgs(invalid, address(token0)));
    }
    function test_uninitializedPoolRejected() public {
        PoolKey memory invalid = key; invalid.fee = 500;
        vm.expectRevert(IUniswapV4UpperLowerWingsStandardExchangeVault.InvalidPoolKey.selector);
        wingsPackage.deployVault(IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgArgs(invalid, address(token0)));
    }
    function test_lifecycleInitializationAndUpdatesNotPublic() public {
        bytes memory args = abi.encode(IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgArgs(key, address(token0)));
        vm.expectRevert(IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.NotCalledByRegistry.selector); wingsPackage.processArgs(args);
        vm.expectRevert(IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.InvalidComponent.selector); wingsPackage.initAccount(args);
        bytes32 binding = wingsPackage.bindingHash();
        assertTrue(wingsPackage.updatePkg(address(wings0), args));
        assertEq(wingsPackage.bindingHash(), binding);
        (bool success,) = address(wings0).call(abi.encodeCall(wingsPackage.initAccount, (args)));
        assertFalse(success);
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultDeploymentTest[]
