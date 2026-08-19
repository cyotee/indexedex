// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
// Ensure PoolManager artifact is built under FOUNDRY_PROFILE=single_se_buffer_cp_hook (deployCode path).
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
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
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";

/**
 * @title TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook
 * @notice Package-adjacent gold TestBase: ERC-4626 wrapper SE + Option B hook diamond path.
 */
abstract contract TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook is
    TestBase_ERC4626StandardExchange
{
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    SimpleMintableERC20 internal rawToken;
    SimpleMintableERC20 internal pairToken;
    SimpleYieldERC4626 internal pairProtocolVault;
    address internal se;
    IPoolManager internal pm;
    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage internal hookPkg;
    address internal hook;
    IHook internal single;
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

        // --- Phase 0: real ERC-4626 wrapper SE (pair-side only) ---
        rawToken = new SimpleMintableERC20("Raw", "RAW");
        pairToken = new SimpleMintableERC20("Pair", "PAIR");
        pairProtocolVault = new SimpleYieldERC4626(pairToken);
        se = _deployERC4626SE(address(pairProtocolVault));

        // Hermetic Uniswap V4 PoolManager (production type; artifact forced via import above)
        pm = IPoolManager(address(new PoolManager(address(this))));

        // --- Hook diamond factory (Option B) ---
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

        // --- Product package: ERC20Permit LP facets + MultiAsset vault + product facets ---
        IFacet seFacet = PkgFactory.deploySeFacet(create3Factory);
        IFacet depositFacet = PkgFactory.deployDepositFacet(create3Factory);
        IFacet withdrawFacet = PkgFactory.deployWithdrawFacet(create3Factory);
        hookPkg = PkgFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgInit({
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                seFacet: seFacet,
                depositFacet: depositFacet,
                withdrawFacet: withdrawFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                multiStepOwnableFacet: multiStepOwnableFacet
            }),
            abi.encode(type(IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage).name, "v1")._hash()
        );

        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _defaultPkgArgs();
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hook);
        single = IHook(hook);
        _bindProductPoolKey();

        // Fund user
        rawToken.mint(user, 1_000_000 ether);
        pairToken.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        rawToken.approve(hook, type(uint256).max);
        pairToken.approve(hook, type(uint256).max);
        IERC20(se).approve(hook, type(uint256).max);
        IERC20(se).approve(se, type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Mint pair, buffer into SE, leave SE shares on `user` (B6 funding helper).
    function _mintSeSharesToUser(uint256 pairAmount) internal returns (uint256 seShares) {
        pairToken.mint(user, pairAmount);
        vm.startPrank(user);
        pairToken.approve(se, type(uint256).max);
        seShares = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(pairToken)),
            pairAmount,
            IERC20(se),
            0,
            user,
            false,
            block.timestamp
        );
        IERC20(se).approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    /// @notice B6 proportional deposit: face raw + SE vault shares for buffered leg.
    function _depositBothSeShares(uint256 amtRaw, uint256 amtSe) internal returns (uint256 lp) {
        vm.prank(user);
        (lp,,) = single.depositWithSeShares(amtRaw, amtSe, user, 0, block.timestamp + 1 hours);
    }

    function _defaultPkgArgs() internal view returns (IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory) {
        return IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            standardExchange: se,
            pairToken: address(pairToken),
            rawToken: address(rawToken),
            ownerOnlyLiquidity: _pkgOwnerOnlyLiquidity(),
            owner: _pkgOwner()
        });
    }

    function _pkgOwnerOnlyLiquidity() internal view virtual returns (bool) {
        return false;
    }

    function _pkgOwner() internal view virtual returns (address) {
        return owner;
    }

    /// @notice Phase 0 proof: pair ↔ SE preview == execution on real wrapper SE.
    function _assertSePreviewEqualsExec(uint256 amountIn) internal {
        pairToken.mint(user, amountIn);
        vm.startPrank(user);
        pairToken.approve(se, type(uint256).max);
        uint256 previewIn =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(address(pairToken)), amountIn, IERC20(se));
        uint256 seOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(pairToken)),
            amountIn,
            IERC20(se),
            previewIn,
            user,
            false,
            block.timestamp
        );
        assertEq(seOut, previewIn, "SE pair->shares preview!=exec");

        IERC20(se).approve(se, type(uint256).max);
        uint256 previewOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seOut, IERC20(address(pairToken)));
        uint256 pairOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(se), seOut, IERC20(address(pairToken)), previewOut, user, false, block.timestamp
        );
        assertEq(pairOut, previewOut, "SE shares->pair preview!=exec");
        vm.stopPrank();
    }

    /// @notice S42: one public product door then finalize. Not pm.initialize.
    function _ensureProductDoorsAndFinalize(address hook_) internal {
        _ensureProductDoorsAndFinalize(hook_, address(rawToken), address(pairToken));
    }

    function _ensureProductDoorsAndFinalize(address hook_, address tokenA_, address tokenB_)
        internal
    {
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook_);
        init.deployPair(tokenA_, tokenB_);
        bool ok = init.finalizeInitialization();
        require(ok, "finalize");
    }

    /// @notice S43: deploy via package path without opening the door or finalizing.
    function _deployBootstrapOnly(
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args
    ) internal returns (address) {
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        return PkgFactory.deployHook(hookPkg, args, mineNonce);
    }

    function _registry() internal view returns (IVaultRegistryVaultQuery) {
        return IVaultRegistryVaultQuery(address(indexedexManager));
    }

    /// @notice Construct the product PoolKey. Door is already live after S42; do not initialize.
    function _bindProductPoolKey() internal {
        poolKey = PoolKey({
            currency0: Currency.wrap(single.currency0()),
            currency1: Currency.wrap(single.currency1()),
            fee: 0,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
    }

    /// @dev Kept for existing product specs. Constructs the live product key; does not initialize.
    function _initPool() internal {
        _bindProductPoolKey();
    }

    function _amountForCurrency(address currency, uint256 amtRaw, uint256 amtPair)
        internal
        view
        returns (uint256)
    {
        if (currency == address(rawToken)) return amtRaw;
        if (currency == address(pairToken)) return amtPair;
        revert("unknown currency");
    }

    function _depositBoth(uint256 amtRaw, uint256 amtPair) internal returns (uint256 lp) {
        uint256 a0 = _amountForCurrency(single.currency0(), amtRaw, amtPair);
        uint256 a1 = _amountForCurrency(single.currency1(), amtRaw, amtPair);
        vm.prank(user);
        (lp,,) = single.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
    }

    function _enableProtocolFee(uint256 feeWad) internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(hook, feeWad);
        vm.stopPrank();
    }

    function _seedLiveLiquidity() internal returns (uint256 lp) {
        _initPool();
        lp = _depositBoth(200 ether, 200 ether);
    }

    function _feeTo() internal view virtual returns (address feeTo_) {
        (feeTo_,) = single.dexSwapFeeAndFeeTo();
    }

    function _isRawCurrency0() internal view returns (bool) {
        return single.currency0() == address(rawToken);
    }
}
