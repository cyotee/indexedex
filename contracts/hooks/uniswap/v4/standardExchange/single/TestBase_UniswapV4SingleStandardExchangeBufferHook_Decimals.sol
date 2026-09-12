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
// Ensure PoolManager artifact is built under profile (deploy / new path).
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    IERC4626PermitDFPkg
} from "@crane/contracts/tokens/ERC4626/ERC4626PermitDFPkg.sol";
import {
    VaultComponentFactoryService
} from "contracts/vaults/VaultComponentFactoryService.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {
    PoolModifyLiquidityTest
} from "@crane/contracts/protocols/dexes/uniswap/v4/hooks/public/dependencies/v4-core/test/PoolModifyLiquidityTest.sol";

import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {
    IUniswapV4SingleStandardExchangeBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHook_FactoryService.sol";

/**
 * @title TestBase_UniswapV4SingleStandardExchangeBufferHook_Decimals
 * @notice Wrap hook TestBase with combo-decimal `pairToken`. Does not call gold wrap setUp.
 * @dev `pairToken` is `MintableERC20Decimals(_pairDecimals())`. Protocol vault is Crane ERC4626;
 *      SE via `_deployERC4626SE`. vaultShare / hook LP stay 18. Wrap pool is pair vs SE share.
 */
abstract contract TestBase_UniswapV4SingleStandardExchangeBufferHook_Decimals is TestBase_ERC4626StandardExchange {
    using BetterEfficientHashLib for bytes;
    using HookFactoryService for ICreate3FactoryProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    MintableERC20Decimals internal pairToken;
    IERC4626 internal protocolVault;
    address internal se;
    IPoolManager internal pm;
    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4SingleStandardExchangeBufferHookPackage internal hookPkg;
    address internal hook;
    IHook internal buffer;
    PoolKey internal poolKey;
    WrapperExactOutRouter internal swapRouter;
    PoolModifyLiquidityTest internal liqRouter;
    address internal user = address(0xBEEF);

    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    function _pairDecimals() internal pure virtual returns (uint8);

    /// @dev Raw pairToken units (`human * 10 ** _pairDecimals()`).
    function _uPair(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_pairDecimals()));
    }

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();

        pairToken = new MintableERC20Decimals("Pair", "PAIR", _pairDecimals());
        protocolVault = _deployCraneErc4626(address(pairToken));
        se = _deployERC4626SE(address(protocolVault));

        pm = IPoolManager(address(new PoolManager(address(this))));
        swapRouter = new WrapperExactOutRouter(pm);
        liqRouter = new PoolModifyLiquidityTest(pm);

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

        IFacet productFacet = PkgFactory.deployProductFacet(create3Factory);
        hookPkg = PkgFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4SingleStandardExchangeBufferHookPackage.PkgInit({
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                productFacet: productFacet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
            }),
            abi.encode(
                type(IUniswapV4SingleStandardExchangeBufferHookPackage).name, "v1", _pairDecimals()
            )._hash()
        );

        IUniswapV4SingleStandardExchangeBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        hook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hook);
        buffer = IHook(hook);
        _bindProductPoolKey();

        pairToken.mint(user, _uPair(1_000_000));
        vm.startPrank(user);
        pairToken.approve(se, type(uint256).max);
        pairToken.approve(address(swapRouter), type(uint256).max);
        IStandardExchangeIn(se).exchangeIn(
            IERC20(address(pairToken)),
            _uPair(200),
            IERC20(se),
            0,
            user,
            false,
            block.timestamp
        );
        // Crane ERC4626 offset-10: 6-dec pair * 1e10 can yield < 5e18 SE shares. Top up so
        // listed unwrap tests can spend 18-dec wad SE amounts (vaultShare stays 18).
        if (IERC20(se).balanceOf(user) < 20 ether) {
            IStandardExchangeIn(se).exchangeIn(
                IERC20(address(pairToken)),
                _uPair(10_000),
                IERC20(se),
                0,
                user,
                false,
                block.timestamp
            );
        }
        IERC20(se).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _defaultPkgArgs()
        internal
        view
        returns (IUniswapV4SingleStandardExchangeBufferHookPackage.PkgArgs memory)
    {
        return IUniswapV4SingleStandardExchangeBufferHookPackage.PkgArgs({
            poolManager: address(pm),
            standardExchange: se,
            pairToken: address(pairToken)
        });
    }

    /// @notice O17 only path for protocolVault: Crane ERC4626PermitDFPkg.
    function _deployCraneErc4626(address asset) internal returns (IERC4626 vault) {
        IERC4626PermitDFPkg pkg =
            create3Factory.deployERC4626PermitDFPkg(erc20Facet, erc5267Facet, erc2612Facet, erc4626Facet);
        IERC4626PermitDFPkg.PkgArgs memory args = IERC4626PermitDFPkg.PkgArgs({
            reserveAsset: IERC20Metadata(asset),
            optionalDecimalOffset: 0,
            optionalSalt: keccak256(abi.encode("buffer-hook-hermetic-decimals", asset, _pairDecimals())),
            optionalInitialDeposit: 0,
            depositor: address(0),
            recipient: address(0)
        });
        address deployed =
            diamondPackageFactory.deploy(IDiamondFactoryPackage(address(pkg)), abi.encode(args));
        vault = IERC4626(deployed);
    }

    /// @notice S42: one wrap-aware product door then finalize. Not pm.initialize.
    function _ensureProductDoorsAndFinalize(address hook_) internal {
        _ensureProductDoorsAndFinalize(hook_, address(pairToken), se);
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
        IUniswapV4SingleStandardExchangeBufferHookPackage.PkgArgs memory args
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
            currency0: Currency.wrap(buffer.currency0()),
            currency1: Currency.wrap(buffer.currency1()),
            fee: buffer.poolFee(),
            tickSpacing: buffer.tickSpacingHint(),
            hooks: IHooks(hook)
        });
    }

    /// @dev Kept for existing specs. Constructs the live product key; does not initialize.
    function _initPool() internal {
        _bindProductPoolKey();
    }

    function _isWrapZFO() internal view returns (bool) {
        return address(pairToken) < se;
    }

    function _sqrtLimit(bool zeroForOne) internal pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
    }

    /// @notice Success-path residual: free pair+SE on hook from this swap path (donation-aware callers set baseline).
    function _assertHookFlat() internal view {
        assertEq(pairToken.balanceOf(hook), 0, "hook free pair residual");
        assertEq(IERC20(se).balanceOf(hook), 0, "hook free SE residual");
    }

    function _assertHookFlatDelta(uint256 pairBefore, uint256 seBefore) internal view {
        assertEq(pairToken.balanceOf(hook), pairBefore, "hook pair delta residual");
        assertEq(IERC20(se).balanceOf(hook), seBefore, "hook SE delta residual");
    }

    function _wrapExactIn(uint256 amountIn) internal returns (uint256 seOut) {
        uint256 preview = buffer.previewWrap(amountIn);
        bool zfo = _isWrapZFO();
        uint256 seBefore = IERC20(se).balanceOf(user);
        vm.prank(user);
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({zeroForOne: zfo, amountSpecified: -int256(amountIn), sqrtPriceLimitX96: _sqrtLimit(zfo)}),
            ""
        );
        seOut = IERC20(se).balanceOf(user) - seBefore;
        assertEq(seOut, preview, "wrap exact-in preview!=exec");
    }

    function _unwrapExactIn(uint256 seIn) internal returns (uint256 pairOut) {
        uint256 preview = buffer.previewUnwrap(seIn);
        bool zfo = !_isWrapZFO();
        uint256 pairBefore = pairToken.balanceOf(user);
        vm.prank(user);
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({zeroForOne: zfo, amountSpecified: -int256(seIn), sqrtPriceLimitX96: _sqrtLimit(zfo)}),
            ""
        );
        pairOut = pairToken.balanceOf(user) - pairBefore;
        assertEq(pairOut, preview, "unwrap exact-in preview!=exec");
    }

    function _wrapExactOut(uint256 seOut) internal returns (uint256 amountIn) {
        amountIn = buffer.previewWrapExactOut(seOut);
        bool zfo = _isWrapZFO();
        uint256 seBefore = IERC20(se).balanceOf(user);
        uint256 pairBefore = pairToken.balanceOf(user);
        vm.prank(user);
        swapRouter.swapExactOut(
            poolKey,
            SwapParams({zeroForOne: zfo, amountSpecified: int256(seOut), sqrtPriceLimitX96: _sqrtLimit(zfo)}),
            amountIn,
            ""
        );
        assertEq(IERC20(se).balanceOf(user) - seBefore, seOut, "wrap exact-out se");
        assertEq(pairBefore - pairToken.balanceOf(user), amountIn, "wrap exact-out spend");
    }

    function _unwrapExactOut(uint256 pairOut) internal returns (uint256 seIn) {
        seIn = buffer.previewUnwrapExactOut(pairOut);
        bool zfo = !_isWrapZFO();
        uint256 seBefore = IERC20(se).balanceOf(user);
        uint256 pairBefore = pairToken.balanceOf(user);
        vm.prank(user);
        swapRouter.swapExactOut(
            poolKey,
            SwapParams({zeroForOne: zfo, amountSpecified: int256(pairOut), sqrtPriceLimitX96: _sqrtLimit(zfo)}),
            seIn,
            ""
        );
        assertEq(seBefore - IERC20(se).balanceOf(user), seIn, "unwrap exact-out se");
        assertEq(pairToken.balanceOf(user) - pairBefore, pairOut, "unwrap exact-out pair");
    }
}
