// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
// Ensure PoolManager artifact is built under the default hermetic profile.
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";

import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IDualHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService as DualFactory
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol";

/**
 * @title TestBase_UniswapV4DualSEBCPHook
 * @notice Hermetic dual SE buffer CP hook: package → registry → hook factory + two ERC-4626 SE legs.
 */
abstract contract TestBase_UniswapV4DualSEBCPHook is TestBase_ERC4626StandardExchange {
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    SimpleMintableERC20 internal tokenA;
    SimpleMintableERC20 internal tokenB;
    SimpleYieldERC4626 internal vaultA;
    SimpleYieldERC4626 internal vaultB;
    address internal seA;
    address internal seB;
    IPoolManager internal pm;
    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4DualStandardExchangeBufferConstantProductHookPackage internal hookPkg;
    address internal hook;
    IDualHook internal dual;
    PoolKey internal poolKey;
    address internal user = address(0xBEEF);

    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    uint256 internal constant DUST = 10;

    address internal constant PERMIT2_ADDR = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();

        // Product PullLib uses the Uniswap well-known Permit2 address; etch hermetic bytecode there.
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        tokenA = new SimpleMintableERC20("TokenA", "TKA");
        tokenB = new SimpleMintableERC20("TokenB", "TKB");
        vaultA = new SimpleYieldERC4626(tokenA);
        vaultB = new SimpleYieldERC4626(tokenB);
        seA = _deployERC4626SE(address(vaultA));
        seB = _deployERC4626SE(address(vaultB));

        pm = IPoolManager(address(new PoolManager(address(this))));

        // --- Hook diamond factory ---
        IFacet hookFlagsFacet = HookFactoryService.deployUniswapV4HookFlagsFacet(create3Factory);
        IFacetRegistry facetReg = IFacetRegistry(address(create3Factory));
        hookFactory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(
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

        // --- Product package ---
        IFacet hooksFacet = DualFactory.deployHooksFacet(create3Factory);
        IFacet depositFacet = DualFactory.deployDepositFacet(create3Factory);
        IFacet withdrawFacet = DualFactory.deployWithdrawFacet(create3Factory);
        IFacet seFacet = DualFactory.deploySeFacet(create3Factory);
        hookPkg = DualFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgInit({
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                hooksFacet: hooksFacet,
                depositFacet: depositFacet,
                withdrawFacet: withdrawFacet,
                seFacet: seFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
            }),
            abi.encode(type(IUniswapV4DualStandardExchangeBufferConstantProductHookPackage).name, "v1")._hash()
        );

        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _defaultPkgArgs();
        uint256 mineNonce = DualFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = DualFactory.deployHook(hookPkg, args, mineNonce);
        dual = IDualHook(hook);

        // Non-zero SE buffer usage fees for DoD (D70)
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seA, 0.01e18);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seB, 0.01e18);
        vm.stopPrank();

        // Fund user
        tokenA.mint(user, 1_000_000 ether);
        tokenB.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        tokenA.approve(hook, type(uint256).max);
        tokenB.approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function _defaultPkgArgs()
        internal
        view
        returns (IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs memory)
    {
        return IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            standardExchange0: seA,
            token0: address(tokenA),
            standardExchange1: seB,
            token1: address(tokenB)
        });
    }

    function _initPool() internal {
        poolKey = PoolKey({
            currency0: Currency.wrap(dual.currency0()),
            currency1: Currency.wrap(dual.currency1()),
            fee: 0,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
        pm.initialize(poolKey, SQRT_PRICE_1_1);
    }

    function _amountForCurrency(address currency, uint256 amtA, uint256 amtB)
        internal
        view
        returns (uint256)
    {
        if (currency == address(tokenA)) return amtA;
        if (currency == address(tokenB)) return amtB;
        revert("unknown currency");
    }

    function _depositBoth(uint256 amtA, uint256 amtB) internal returns (uint256 lp) {
        uint256 a0 = _amountForCurrency(dual.currency0(), amtA, amtB);
        uint256 a1 = _amountForCurrency(dual.currency1(), amtA, amtB);
        vm.prank(user);
        (lp,,) = dual.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
    }

    /// @dev Mint pair tokens, exchange into SE shares for `user` (B6 LP funding).
    function _userAcquireSeShares(address se, SimpleMintableERC20 pairToken, uint256 pairAmt)
        internal
        returns (uint256 seOut)
    {
        pairToken.mint(user, pairAmt);
        vm.startPrank(user);
        pairToken.approve(se, type(uint256).max);
        seOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(pairToken)),
            pairAmt,
            IERC20(se),
            0,
            user,
            false,
            block.timestamp + 1 hours
        );
        IERC20(se).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function _enableProtocolFee(uint256 feeWad) internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(hook, feeWad);
        vm.stopPrank();
    }

    function _assertVaultRegistered() internal view {
        assertTrue(IBasicVault(hook).vaultTokens().length == 2, "vaultTokens");
        IStandardVault(hook).vaultConfig();
    }
}
