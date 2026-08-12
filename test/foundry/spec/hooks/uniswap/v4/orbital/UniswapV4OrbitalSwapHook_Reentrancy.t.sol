// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {ReentrantMockERC20} from "contracts/test/stubs/ReentrantMockERC20.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";
import {
    IUniswapV4OrbitalSwapHookPackage
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHookPackage.sol";
import {
    UniswapV4OrbitalSwapHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook_FactoryService.sol";

/**
 * @title UniswapV4OrbitalSwapHook_Reentrancy_Test
 * @notice Hostile ERC-20 re-enters addLiquidity during transferFrom; global lock reverts Reentrancy.
 */
contract UniswapV4OrbitalSwapHook_Reentrancy_Test is TestBase_VaultComponents {
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    SimpleMintableERC20 internal token0;
    SimpleMintableERC20 internal token1;
    ReentrantMockERC20 internal hostile;
    IUniswapV4OrbitalSwapHook internal orbital;
    address internal hook;
    address internal user = address(0xBEEF);

    function setUp() public override {
        TestBase_VaultComponents.setUp();

        token0 = new SimpleMintableERC20("T0", "T0");
        token1 = new SimpleMintableERC20("T1", "T1");
        hostile = new ReentrantMockERC20("HOST", "HOST", 18);

        IPoolManager pm = IPoolManager(address(new PoolManager(address(this))));

        IFacet hookFlagsFacet = HookFactoryService.deployUniswapV4HookFlagsFacet(create3Factory);
        IFacetRegistry facetReg = IFacetRegistry(address(create3Factory));
        IUniswapV4HookDiamondPackageCallBackFactory hookFactory =
            HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(
                create3Factory,
                IUniswapV4HookDiamondPackageCallBackFactory.InitArgs({
                    erc165Facet: facetReg.canonicalFacet(type(IERC165).interfaceId),
                    diamondLoupeFacet: facetReg.canonicalFacet(type(IDiamondLoupe).interfaceId),
                    erc8109IntrospectionFacet: facetReg.canonicalFacet(type(IERC8109Introspection).interfaceId),
                    postDeployHookFacet: facetReg.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                    hookFlagsFacet: hookFlagsFacet
                })
            );
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(hookFactory));

        IFacet hooksFacet = PkgFactory.deployHooksFacet(create3Factory);
        IFacet liquidityFacet = PkgFactory.deployLiquidityFacet(create3Factory);
        IUniswapV4OrbitalSwapHookPackage hookPkg = PkgFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4OrbitalSwapHookPackage.PkgInit({
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                hooksFacet: hooksFacet,
                liquidityFacet: liquidityFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
            }),
            abi.encode("orbital-reentrancy", "v1")._hash()
        );

        IUniswapV4OrbitalSwapHookPackage.PkgArgs memory args = IUniswapV4OrbitalSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            token0: address(token0),
            token1: address(token1),
            token2: address(hostile),
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        orbital = IUniswapV4OrbitalSwapHook(hook);

        token0.mint(user, 1_000_000 ether);
        token1.mint(user, 1_000_000 ether);
        hostile.mint(user, 1_000_000 ether);

        vm.startPrank(user);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        hostile.approve(hook, type(uint256).max);
        vm.stopPrank();

        // Live book so subsequent add pulls hostile (token2)
        vm.prank(user);
        orbital.addLiquidity(100 ether, 100 ether, 100 ether, user, 0, block.timestamp + 1 hours, "");
    }

    function test_reentrancy_addLiquidity_duringTransferFrom_reverts() public {
        uint256 sharesBefore = IERC20(hook).balanceOf(user);

        bytes memory reentry = abi.encodeWithSelector(
            IUniswapV4OrbitalSwapHook.addLiquidity.selector,
            uint256(1 ether),
            uint256(1 ether),
            uint256(1 ether),
            user,
            uint256(0),
            block.timestamp + 1 hours,
            bytes("")
        );
        hostile.arm(hook, reentry);

        vm.prank(user);
        (bool ok,) = address(orbital).call(
            abi.encodeWithSelector(
                IUniswapV4OrbitalSwapHook.addLiquidity.selector,
                uint256(10 ether),
                uint256(10 ether),
                uint256(10 ether),
                user,
                uint256(0),
                block.timestamp + 1 hours,
                bytes("")
            )
        );
        assertFalse(ok, "outer addLiquidity must fail under reentrancy");
        assertEq(
            IERC20(hook).balanceOf(user),
            sharesBefore,
            "no LP minted when reentrancy blocked mid-pull"
        );
    }
}
