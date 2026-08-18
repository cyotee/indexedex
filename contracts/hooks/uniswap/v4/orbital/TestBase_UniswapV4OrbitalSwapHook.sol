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
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";

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
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    UniswapV4OrbitalSwapHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook_FactoryService.sol";
import {
    UniswapV4OrbitalSwapHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookPairPoolLib.sol";

/**
 * @title TestBase_UniswapV4OrbitalSwapHook
 * @notice Package path TestBase: hook factory + registry deployHookVault + three pair doors.
 * @dev Ladder: CraneTest → IndexedexTest → TestBase_VaultComponents → this.
 */
abstract contract TestBase_UniswapV4OrbitalSwapHook is TestBase_VaultComponents {
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;

    SimpleMintableERC20 internal token0;
    SimpleMintableERC20 internal token1;
    SimpleMintableERC20 internal token2;
    IPoolManager internal pm;
    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4OrbitalSwapHookPackage internal hookPkg;
    address internal hook;
    IUniswapV4OrbitalSwapHook internal orbital;
    PoolKey internal poolKey01;
    PoolKey internal poolKey12;
    PoolKey internal poolKey02;
    WrapperExactOutRouter internal swapRouter;

    address internal user = address(0xBEEF);
    address internal feeRecipient;

    uint256 internal constant FUND = 1_000_000 ether;

    function setUp() public virtual override {
        TestBase_VaultComponents.setUp();
        feeRecipient = address(feeCollector);

        token0 = new SimpleMintableERC20("Token0", "T0");
        token1 = new SimpleMintableERC20("Token1", "T1");
        token2 = new SimpleMintableERC20("Token2", "T2");
        require(
            address(token0) != address(token1) && address(token1) != address(token2)
                && address(token0) != address(token2),
            "token addr"
        );

        pm = IPoolManager(address(new PoolManager(address(this))));

        // --- Shared hook diamond factory ---
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
        IFacet hooksFacet = PkgFactory.deployHooksFacet(create3Factory);
        IFacet liquidityFacet = PkgFactory.deployLiquidityFacet(create3Factory);
        hookPkg = PkgFactory.deployPackage(
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
            abi.encode(type(IUniswapV4OrbitalSwapHookPackage).name, "v1")._hash()
        );

        IUniswapV4OrbitalSwapHookPackage.PkgArgs memory args = _defaultPkgArgs();
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hook);
        orbital = IUniswapV4OrbitalSwapHook(hook);

        // Pure key construction for tests — does NOT call initialize (S42 public ABI already did).
        int24 spacing = 60;
        poolKey01 = PairPoolLib.pairKey(address(token0), address(token1), spacing, IHooks(hook));
        poolKey12 = PairPoolLib.pairKey(address(token1), address(token2), spacing, IHooks(hook));
        poolKey02 = PairPoolLib.pairKey(address(token0), address(token2), spacing, IHooks(hook));

        swapRouter = new WrapperExactOutRouter(pm);

        token0.mint(user, FUND);
        token1.mint(user, FUND);
        token2.mint(user, FUND);
        vm.startPrank(user);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);
        token2.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _defaultPkgArgs()
        internal
        view
        returns (IUniswapV4OrbitalSwapHookPackage.PkgArgs memory)
    {
        return IUniswapV4OrbitalSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            token0: address(token0),
            token1: address(token1),
            token2: address(token2),
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
    }

    function _addLiquidity(uint256 a0, uint256 a1, uint256 a2)
        internal
        returns (uint256 shares, uint256 u0, uint256 u1, uint256 u2)
    {
        vm.prank(user);
        return orbital.addLiquidity(a0, a1, a2, user, 0, block.timestamp + 1 hours, "");
    }

    function _seedThreeLeg(uint256 amount) internal returns (uint256 shares) {
        (shares,,,) = _addLiquidity(amount, amount, amount);
    }

    function _setDexFee(uint256 feeWad) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(hook, feeWad);
    }

    function _setUsageFee(uint256 feeWad) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook, feeWad);
    }

    function _sqrtLimit(bool zeroForOne) internal pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    function _poolKeyFor(address a, address b) internal view returns (PoolKey memory key) {
        (address c0, address c1) = a < b ? (a, b) : (b, a);
        key = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
    }

    function _swapExactIn(address tokenIn, address tokenOut, uint256 amountIn) internal {
        PoolKey memory key = _poolKeyFor(tokenIn, tokenOut);
        bool zeroForOne = tokenIn == Currency.unwrap(key.currency0);
        vm.prank(user);
        swapRouter.swapExactIn(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: _sqrtLimit(zeroForOne)
            }),
            ""
        );
    }

    function _registry() internal view returns (IVaultRegistryVaultQuery) {
        return IVaultRegistryVaultQuery(address(indexedexManager));
    }

    function _requiredFlags() internal pure returns (uint160) {
        return PkgFactory.requiredFlags();
    }

    /// @notice S42: three public door calls then finalize. Not PairPoolLib.ensureThreePairPools.
    function _ensureProductDoorsAndFinalize(address hook_) internal {
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook_);
        init.deployPair(address(token0), address(token1));
        init.deployPair(address(token1), address(token2));
        init.deployPair(address(token0), address(token2));
        bool ok = init.finalizeInitialization();
        require(ok, "finalize");
    }

    /// @notice S43: deploy via package path without opening doors or finalizing.
    function _deployBootstrapOnly(IUniswapV4OrbitalSwapHookPackage.PkgArgs memory args)
        internal
        returns (address)
    {
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        return PkgFactory.deployHook(hookPkg, args, mineNonce);
    }

    /// @notice On-chain proof a pair door is live on PoolManager.
    function _assertPoolLive(PoolKey memory key) internal view {
        assertTrue(PairPoolLib.isPoolLive(pm, key), "pair door not initialized on PoolManager");
        assertEq(address(key.hooks), hook, "hooks must be product proxy");
        assertEq(key.fee, LPFeeLibrary.DYNAMIC_FEE_FLAG, "DYNAMIC_FEE");
    }

    function _assertThreeProductDoorsLive() internal view {
        _assertPoolLive(poolKey01);
        _assertPoolLive(poolKey12);
        _assertPoolLive(poolKey02);
    }
}
