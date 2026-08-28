// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {UniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/UniswapV3Factory.sol";
import {
    IUniswapV3MintCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {ISwapRouter} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/ISwapRouter.sol";
import {SwapRouter} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/SwapRouter.sol";
import {INonfungiblePositionManager} from
    "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {NonfungiblePositionManager} from
    "@crane/contracts/protocols/dexes/uniswap/v3/periphery/NonfungiblePositionManager.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IPositionDescriptor} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionDescriptor.sol";
import {IWETH9} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/external/IWETH9.sol";
import {PositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionManager.sol";
import {PositionDescriptor} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionDescriptor.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {HookMiner} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/HookMiner.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {TickMath as TickMathV4} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IMorpho, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {Morpho} from "@crane/contracts/external/morpho/blue/Morpho.sol";
import {OracleMock} from "@crane/contracts/external/morpho/blue/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "@crane/contracts/external/morpho/blue-irm/AdaptiveCurveIrm.sol";
import {ORACLE_PRICE_SCALE} from "@crane/contracts/external/morpho/blue/libraries/ConstantsLib.sol";
import {PonsLaunchFactory} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v1/PonsLaunchFactory.sol";
import {PonsLaunchLocker} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v1/PonsLaunchLocker.sol";
import {PonsLauncherToken} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v1/PonsLauncherToken.sol";
import {PonsV2FeeEscrow} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2FeeEscrow.sol";
import {PonsV2BuybackVault} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2BuybackVault.sol";
import {PonsV2LaunchLocker} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LaunchLocker.sol";
import {PonsV2MemeHook} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol";
import {PonsV2LaunchFactory} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LaunchFactory.sol";
import {PonsV2LaunchDeployer} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LaunchDeployer.sol";
import {PonsV2GraduationExecutor} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2GraduationExecutor.sol";
import {PonsV2LauncherToken} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2LauncherToken.sol";
import {PonsV2BondingCurve} from
    "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2BondingCurve.sol";
import {
    GraduationPhase,
    IPonsV2LaunchFactory
} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/interfaces/ILaunchpadV2.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IUniswapV3StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeDFPkg.sol";
import {
    UniswapV3_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3_Component_FactoryService.sol";
import {
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";
import {
    IUniswapV4StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {
    UniswapV4_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
import {
    IUniswapV4StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4MultiPoolTwapOracleDFPkg
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol";
import {
    UniswapV4TwapOracleFactoryService
} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapOracleFactoryService.sol";
import {
    IMorphoBlueStandardExchangeDFPkg
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchangeDFPkg.sol";
import {
    MorphoBlue_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlue_Component_FactoryService.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

interface IProdSeMintable {
    function mint(address to, uint256 amount) external;
}

/// @dev Empty V3 NPM descriptor (metadata unused).
contract ProdSeMockTokenDescriptor {
    function tokenURI(address, uint256) external pure returns (string memory) {
        return "";
    }
}

/// @dev Hermetic Uni V3 full-range seeder. Holds inventory; pays mint callback.
contract Univ3LiquiditySeeder is IUniswapV3MintCallback {
    function seedFullRange(IUniswapV3Pool pool, uint128 liquidity) external {
        int24 tickSpacing = pool.tickSpacing();
        int24 tickLower = (-887220 / tickSpacing) * tickSpacing;
        int24 tickUpper = (887220 / tickSpacing) * tickSpacing;
        if (tickLower >= tickUpper) {
            tickLower = -tickSpacing * 1000;
            tickUpper = tickSpacing * 1000;
        }
        uint128 liq = liquidity < 1e18 ? 50_000_000e18 : liquidity;
        pool.mint(address(this), tickLower, tickUpper, liq, abi.encode(address(this)));
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data)
        external
        override
    {
        address payer = abi.decode(data, (address));
        require(payer == address(this), "unexpected payer");
        IUniswapV3Pool pool = IUniswapV3Pool(msg.sender);
        if (amount0Owed > 0) IERC20(pool.token0()).transfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) IERC20(pool.token1()).transfer(msg.sender, amount1Owed);
    }
}

/// @dev Hermetic Uni V4 ±120 tick seeder (PRD §5). Copy of FullRangeBookSeeder.
contract Univ4LiquiditySeeder is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager poolManager_) {
        poolManager = poolManager_;
    }

    function addLiquidity(PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity)
        external
    {
        poolManager.unlock(abi.encode(poolKey, tickLower, tickUpper, liquidity));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "not pm");
        (PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            abi.decode(data, (PoolKey, int24, int24, uint128));
        (BalanceDelta callerDelta,) = poolManager.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(uint256(liquidity)),
                salt: bytes32(0)
            }),
            bytes("")
        );
        _settle(poolKey.currency0, callerDelta.amount0());
        _settle(poolKey.currency1, callerDelta.amount1());
        return abi.encode(callerDelta);
    }

    function _settle(Currency currency, int128 delta) internal {
        if (delta < 0) {
            uint256 amount = uint128(-delta);
            poolManager.sync(currency);
            IERC20(Currency.unwrap(currency)).transfer(address(poolManager), amount);
            poolManager.settle();
        } else if (delta > 0) {
            poolManager.take(currency, address(this), uint128(delta));
        }
    }
}

/**
 * @title UniswapV4DetfProductionSeDeployLib
 * @notice SE-only deploy helpers for unified DETF × production SE fixtures. No DETF logic.
 */
library UniswapV4DetfProductionSeDeployLib {
    Vm internal constant vm = Vm(VM_ADDRESS);

    uint24 public constant GENERIC_V3_FEE = 3000;
    uint24 public constant GENERIC_V4_FEE = 3000;
    int24 public constant GENERIC_V4_TICK_SPACING = 60;
    uint256 internal constant V3_LIQUID_RESERVE_PCT = 0.20e18;
    uint256 internal constant V4_LIQUID_RESERVE_PCT = 0.2e18;
    uint256 internal constant MORPHO_LLTV = 0.8e18;
    uint256 internal constant PONS_LAUNCH_FEE = 0.0005 ether;
    uint256 internal constant PONS_SUPPLY = 1_000_000_000 ether;
    uint256 internal constant PONS_GRADUATION_THRESHOLD = 4.2 ether;
    int24 internal constant PONS_INITIAL_TICK = -204_200;
    uint16 internal constant PONS_MAX_WALLET_BPS = 500;
    uint16 internal constant PONS_MAX_TX_BPS = 550;
    uint32 internal constant PONS_RESTRICTION_BLOCKS = 2;
    uint24 public constant PONS_V1_POOL_FEE = 10_000;
    int24 internal constant PONS_V1_TICK_SPACING = 200;
    uint256 internal constant PONS_PROTOCOL_FEE_SHARE = 30;
    uint256 internal constant PONS_V2_SUPPLY = 1_000_000_000 ether;
    uint256 internal constant PONS_V2_PHANTOM_QUOTE = 1 ether;
    uint256 internal constant PONS_V2_GRADUATION_THRESHOLD = 4.2 ether;
    uint256 internal constant PONS_V2_CURVE_FEE_BPS = 100;
    uint24 internal constant PONS_V2_POOL_FEE = 0;
    int24 internal constant PONS_V2_TICK_SPACING = 60;
    uint160 internal constant MEME_HOOK_FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
    );

    struct CraneCtx {
        ICreate3FactoryProxy create3Factory;
        IIndexedexManagerProxy indexedexManager;
        IDiamondPackageCallBackFactory diamondPackageFactory;
        IPermit2 permit2;
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        address owner;
    }

    struct Univ3SePkg {
        IUniswapV3Factory factory;
        IUniswapV3StandardExchangeDFPkg pkg;
    }

    struct Univ4SePkg {
        IUniswapV4StandardExchangeDFPkg pkg;
        IUniswapV4MultiPoolTwapOracle twap;
        IWETH weth;
    }

    struct PonsV1Stack {
        IUniswapV3Factory v3Factory;
        IWETH weth;
        ISwapRouter swapRouter;
        INonfungiblePositionManager positionManager;
        PonsLaunchFactory ponsFactory;
        PonsLaunchLocker ponsLocker;
        uint256 dexId;
        uint256 launchConfigId;
        address ponsOwner;
        address ponsLauncher;
    }

    struct PonsV2Stack {
        IPositionManager positionManager;
        PonsV2MemeHook memeHook;
        PonsV2LaunchFactory factory;
        PonsV2FeeEscrow feeEscrow;
        address launchToken;
        address launchCurve;
        PoolKey graduatedPoolKey;
        address launcher;
        uint256 launchConfigId;
    }

    struct MorphoStack {
        IMorpho morpho;
        AdaptiveCurveIrm irm;
        OracleMock oracle;
        address dummyCollateral;
        address feeRecipient;
        address morphoOwner;
        IMorphoBlueStandardExchangeDFPkg pkg;
    }

    struct Univ3SeFacets {
        IFacet inFacet;
        IFacet inQuery;
        IFacet outFacet;
        IFacet outQuery;
        IFacet posImport;
        IFacet liquidReserve;
        IFacet inMulti;
        IFacet inMultiQuery;
        IFacet outMulti;
        IFacet outMultiQuery;
    }

    function _deployUniv3SeFacets(ICreate3FactoryProxy create3Factory)
        internal
        returns (Univ3SeFacets memory f)
    {
        f.inFacet = UniswapV3_Component_FactoryService.deployUniswapV3StandardExchangeInFacet(create3Factory);
        f.inQuery = UniswapV3_Component_FactoryService.deployUniswapV3StandardExchangeInQueryFacet(create3Factory);
        f.outFacet = UniswapV3_Component_FactoryService.deployUniswapV3StandardExchangeOutFacet(create3Factory);
        f.outQuery = UniswapV3_Component_FactoryService.deployUniswapV3StandardExchangeOutQueryFacet(create3Factory);
        f.posImport =
            UniswapV3_Component_FactoryService.deployUniswapV3StandardExchangePositionImportFacet(create3Factory);
        f.liquidReserve =
            UniswapV3_Component_FactoryService.deployUniswapV3StandardExchangeLiquidReserveFacet(create3Factory);
        f.inMulti = UniswapV3_Component_FactoryService.deployUniswapV3StandardExchangeInMultiFacet(create3Factory);
        f.inMultiQuery =
            UniswapV3_Component_FactoryService.deployUniswapV3StandardExchangeInMultiQueryFacet(create3Factory);
        f.outMulti = UniswapV3_Component_FactoryService.deployUniswapV3StandardExchangeOutMultiFacet(create3Factory);
        f.outMultiQuery =
            UniswapV3_Component_FactoryService.deployUniswapV3StandardExchangeOutMultiQueryFacet(create3Factory);
    }

    function deployUniv3SePkg(CraneCtx memory ctx, IUniswapV3Factory factory)
        internal
        returns (IUniswapV3StandardExchangeDFPkg pkg)
    {
        Univ3SeFacets memory f = _deployUniv3SeFacets(ctx.create3Factory);
        IUniswapV3StandardExchangeDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = ctx.erc20Facet;
        pkgInit.erc5267Facet = ctx.erc5267Facet;
        pkgInit.erc2612Facet = ctx.erc2612Facet;
        pkgInit.multiAssetBasicVaultFacet = ctx.multiAssetBasicVaultFacet;
        pkgInit.multiAssetStandardVaultFacet = ctx.multiAssetStandardVaultFacet;
        pkgInit.uniswapV3StandardExchangeInFacet = f.inFacet;
        pkgInit.uniswapV3StandardExchangeInQueryFacet = f.inQuery;
        pkgInit.uniswapV3StandardExchangeOutFacet = f.outFacet;
        pkgInit.uniswapV3StandardExchangeOutQueryFacet = f.outQuery;
        pkgInit.uniswapV3StandardExchangePositionImportFacet = f.posImport;
        pkgInit.uniswapV3StandardExchangeLiquidReserveFacet = f.liquidReserve;
        pkgInit = UniswapV3_Component_FactoryService.attachUniswapV3StandardExchangeMultiFacets(
            pkgInit, f.inMulti, f.inMultiQuery, f.outMulti, f.outMultiQuery
        );
        pkgInit.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(ctx.indexedexManager));
        pkgInit.vaultRegistryDeployment = IVaultRegistryDeployment(address(ctx.indexedexManager));
        pkgInit.permit2 = ctx.permit2;
        pkgInit.uniswapV3Factory = factory;

        vm.startPrank(ctx.owner);
        IVaultFeeOracleManager(address(ctx.indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(
            type(IUniswapV3StandardExchangeLiquidReserve).interfaceId, V3_LIQUID_RESERVE_PCT
        );
        pkg = UniswapV3_Component_FactoryService.deployUniswapV3StandardExchangeDFPkg(ctx.indexedexManager, pkgInit);
        vm.stopPrank();
    }

    function newUniv3Factory() internal returns (IUniswapV3Factory factory) {
        factory = new UniswapV3Factory();
        vm.label(address(factory), "uniswapV3Factory");
    }

    function createUniv3PoolOneToOne(IUniswapV3Factory factory, address tokenA, address tokenB, uint24 fee)
        internal
        returns (IUniswapV3Pool pool)
    {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pool = IUniswapV3Pool(factory.createPool(token0, token1, fee));
        pool.initialize(uint160(uint256(1) << 96));
        vm.label(address(pool), "V3Pool");
    }

    function seedUniv3Pool(IUniswapV3Pool pool) internal {
        Univ3LiquiditySeeder seeder = new Univ3LiquiditySeeder();
        IProdSeMintable(pool.token0()).mint(address(seeder), 100_000_000 ether);
        IProdSeMintable(pool.token1()).mint(address(seeder), 100_000_000 ether);
        seeder.seedFullRange(pool, 50_000_000e18);
    }

    function deployUniv3Vault(IUniswapV3StandardExchangeDFPkg pkg, IUniswapV3Pool pool)
        internal
        returns (address vault)
    {
        vault = pkg.deployVault(pool);
        vm.label(vault, "UniV3Se");
    }

    struct Univ4SeFacets {
        IFacet inFacet;
        IFacet inQuery;
        IFacet posImport;
        IFacet outFacet;
        IFacet outQuery;
        IFacet liquidReserve;
        IFacet inMulti;
        IFacet inMultiQuery;
        IFacet outMulti;
        IFacet outMultiQuery;
    }

    function _deployUniv4Twap(CraneCtx memory ctx, IPoolManager pm)
        internal
        returns (IUniswapV4MultiPoolTwapOracle twap)
    {
        IFacet twapFacet =
            UniswapV4TwapOracleFactoryService.deployUniswapV4MultiPoolTwapOracleFacet(ctx.create3Factory);
        IUniswapV4MultiPoolTwapOracleDFPkg twapPkg = UniswapV4TwapOracleFactoryService
            .deployUniswapV4MultiPoolTwapOracleDFPkg(ctx.create3Factory, twapFacet, ctx.diamondPackageFactory);
        twap = twapPkg.deployOracle(
            IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: address(pm)})
        );
    }

    function _deployUniv4SeFacets(ICreate3FactoryProxy create3Factory)
        internal
        returns (Univ4SeFacets memory f)
    {
        f.inFacet = UniswapV4_Component_FactoryService.deployUniswapV4StandardExchangeInFacet(create3Factory);
        f.inQuery = UniswapV4_Component_FactoryService.deployUniswapV4StandardExchangeInQueryFacet(create3Factory);
        f.posImport =
            UniswapV4_Component_FactoryService.deployUniswapV4StandardExchangePositionImportFacet(create3Factory);
        f.outFacet = UniswapV4_Component_FactoryService.deployUniswapV4StandardExchangeOutFacet(create3Factory);
        f.outQuery = UniswapV4_Component_FactoryService.deployUniswapV4StandardExchangeOutQueryFacet(create3Factory);
        f.liquidReserve =
            UniswapV4_Component_FactoryService.deployUniswapV4StandardExchangeLiquidReserveFacet(create3Factory);
        f.inMulti = UniswapV4_Component_FactoryService.deployUniswapV4StandardExchangeInMultiFacet(create3Factory);
        f.inMultiQuery =
            UniswapV4_Component_FactoryService.deployUniswapV4StandardExchangeInMultiQueryFacet(create3Factory);
        f.outMulti = UniswapV4_Component_FactoryService.deployUniswapV4StandardExchangeOutMultiFacet(create3Factory);
        f.outMultiQuery =
            UniswapV4_Component_FactoryService.deployUniswapV4StandardExchangeOutMultiQueryFacet(create3Factory);
    }

    function _univ4SeCore(CraneCtx memory ctx, Univ4SeFacets memory f, IPoolManager pm, IWETH weth)
        internal
        pure
        returns (UniswapV4_Component_FactoryService.Univ4SePkgInitCore memory core)
    {
        core.erc20Facet = ctx.erc20Facet;
        core.erc5267Facet = ctx.erc5267Facet;
        core.erc2612Facet = ctx.erc2612Facet;
        core.multiAssetBasicVaultFacet = ctx.multiAssetBasicVaultFacet;
        core.multiAssetStandardVaultFacet = ctx.multiAssetStandardVaultFacet;
        core.uniswapV4StandardExchangeInFacet = f.inFacet;
        core.uniswapV4StandardExchangeInQueryFacet = f.inQuery;
        core.uniswapV4StandardExchangePositionImportFacet = f.posImport;
        core.uniswapV4StandardExchangeOutFacet = f.outFacet;
        core.uniswapV4StandardExchangeOutQueryFacet = f.outQuery;
        core.uniswapV4StandardExchangeLiquidReserveFacet = f.liquidReserve;
        core.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(ctx.indexedexManager));
        core.vaultRegistryDeployment = IVaultRegistryDeployment(address(ctx.indexedexManager));
        core.permit2 = ctx.permit2;
        core.poolManager = pm;
        core.weth = weth;
    }

    function deployUniv4SePkg(CraneCtx memory ctx, IPoolManager pm, IWETH weth)
        internal
        returns (Univ4SePkg memory out)
    {
        out.weth = weth;
        out.twap = _deployUniv4Twap(ctx, pm);
        Univ4SeFacets memory f = _deployUniv4SeFacets(ctx.create3Factory);
        IUniswapV4StandardExchangeDFPkg.PkgInit memory pkgInit =
            UniswapV4_Component_FactoryService.buildArgsUniswapV4StandardExchangePkgInit(
                _univ4SeCore(ctx, f, pm, weth)
            );
        pkgInit = UniswapV4_Component_FactoryService.attachTwapOracle(pkgInit, out.twap);
        pkgInit = UniswapV4_Component_FactoryService.attachUniswapV4StandardExchangeMultiFacets(
            pkgInit, f.inMulti, f.inMultiQuery, f.outMulti, f.outMultiQuery
        );
        vm.startPrank(ctx.owner);
        IVaultFeeOracleManager(address(ctx.indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(
            type(IUniswapV4StandardExchangeLiquidReserve).interfaceId, V4_LIQUID_RESERVE_PCT
        );
        out.pkg = UniswapV4_Component_FactoryService.deployUniswapV4StandardExchangeDFPkg(
            ctx.indexedexManager, pkgInit
        );
        vm.stopPrank();
    }

    function genericV4PoolKey(address tokenA, address tokenB) internal pure returns (PoolKey memory key) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: GENERIC_V4_FEE,
            tickSpacing: GENERIC_V4_TICK_SPACING,
            hooks: IHooks(address(0))
        });
    }

    function initAndSeedUniv4Pool(IPoolManager pm, address tokenA, address tokenB)
        internal
        returns (PoolKey memory key)
    {
        key = genericV4PoolKey(tokenA, tokenB);
        pm.initialize(key, TickMathV4.getSqrtPriceAtTick(0));
        Univ4LiquiditySeeder seeder = new Univ4LiquiditySeeder(pm);
        IProdSeMintable(tokenA).mint(address(seeder), 1_000_000 ether);
        IProdSeMintable(tokenB).mint(address(seeder), 1_000_000 ether);
        int24 tickLower = -120;
        int24 tickUpper = 120;
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            TickMathV4.getSqrtPriceAtTick(0),
            TickMathV4.getSqrtPriceAtTick(tickLower),
            TickMathV4.getSqrtPriceAtTick(tickUpper),
            100_000 ether,
            100_000 ether
        );
        seeder.addLiquidity(key, tickLower, tickUpper, liq);
    }

    function deployUniv4Vault(IUniswapV4StandardExchangeDFPkg pkg, PoolKey memory key)
        internal
        returns (address vault)
    {
        vault = pkg.deployVault(key);
        vm.label(vault, "UniV4Se");
    }

    function newWeth() internal returns (IWETH weth) {
        weth = IWETH(address(new WETH9()));
        vm.label(address(weth), "WETH9");
    }

    function deployPonsV1Stack(IUniswapV3Factory v3Factory, IWETH weth)
        internal
        returns (PonsV1Stack memory s)
    {
        s.v3Factory = v3Factory;
        s.weth = weth;
        s.ponsOwner = vm.addr(uint256(keccak256("ponsOwner")));
        s.ponsLauncher = vm.addr(uint256(keccak256("ponsLauncher")));
        address ponsFeeSink = vm.addr(uint256(keccak256("ponsFeeSink")));
        vm.label(s.ponsOwner, "ponsOwner");
        vm.label(s.ponsLauncher, "ponsLauncher");

        address descriptor = address(new ProdSeMockTokenDescriptor());
        s.swapRouter = ISwapRouter(address(new SwapRouter(address(v3Factory), address(weth))));
        s.positionManager = INonfungiblePositionManager(
            address(new NonfungiblePositionManager(address(v3Factory), address(weth), descriptor))
        );

        vm.prank(s.ponsOwner);
        s.ponsLocker = new PonsLaunchLocker(s.ponsOwner, ponsFeeSink, PONS_PROTOCOL_FEE_SHARE);
        vm.prank(s.ponsOwner);
        s.ponsFactory = new PonsLaunchFactory(s.ponsOwner, address(s.ponsLocker), PONS_LAUNCH_FEE);
        vm.prank(s.ponsOwner);
        s.ponsLocker.initialize(address(s.ponsFactory));

        vm.startPrank(s.ponsOwner);
        s.dexId = s.ponsFactory.addDexConfig(
            PonsLaunchFactory.DexConfig({
                name: "uniswap v3",
                factory: address(v3Factory),
                positionManager: address(s.positionManager),
                swapRouter: address(s.swapRouter),
                poolFee: PONS_V1_POOL_FEE,
                tickSpacing: PONS_V1_TICK_SPACING,
                enabled: true
            })
        );
        s.launchConfigId = s.ponsFactory.addLaunchConfig(
            PonsLaunchFactory.LaunchConfig({
                pairToken: address(weth),
                graduationThreshold: PONS_GRADUATION_THRESHOLD,
                initialTick: PONS_INITIAL_TICK,
                supply: PONS_SUPPLY,
                maxWalletBps: PONS_MAX_WALLET_BPS,
                maxTxBps: PONS_MAX_TX_BPS,
                restrictionBlocks: PONS_RESTRICTION_BLOCKS,
                reservedFee: 0,
                enabled: true,
                routerRequiresDeadline: true
            })
        );
        s.ponsFactory.setLaunchEnabled(true);
        vm.stopPrank();

        vm.deal(s.ponsLauncher, 100 ether);
        vm.deal(address(this), 100 ether);
    }

    function ponsV1TokenParams(string memory name, string memory symbol)
        internal
        pure
        returns (PonsLaunchFactory.TokenParams memory)
    {
        return PonsLaunchFactory.TokenParams({
            name: name,
            symbol: symbol,
            logo: "ipfs://logo",
            description: "hermetic pons v1 Uni V3 SE wrap",
            socials: PonsLaunchFactory.Socials({
                twitter: "https://x.com/pons",
                telegram: "",
                discord: "",
                website: "https://pons.family",
                farcaster: ""
            }),
            feeWallet: address(0)
        });
    }

    function defaultPonsV1TokenParams() internal pure returns (PonsLaunchFactory.TokenParams memory) {
        return ponsV1TokenParams("Pons Hermetic", "PHRM");
    }

    function launchPonsV1(PonsV1Stack memory s, bytes32 saltStart) internal returns (address token) {
        return launchPonsV1Named(s, saltStart, "Pons Hermetic", "PHRM");
    }

    function launchPonsV1Named(
        PonsV1Stack memory s,
        bytes32 saltStart,
        string memory name,
        string memory symbol
    ) internal returns (address token) {
        vm.prank(s.ponsLauncher);
        token = s.ponsFactory.launchToken{value: PONS_LAUNCH_FEE}(
            ponsV1TokenParams(name, symbol), s.launchConfigId, s.dexId, saltStart
        );
    }

    function ponsV1Pool(address launchToken) internal view returns (IUniswapV3Pool) {
        return IUniswapV3Pool(PonsLauncherToken(launchToken).liquidityPool());
    }

    function warpPastPonsV1Restrictions(address token) internal {
        uint256 end = PonsLauncherToken(token).restrictionEndBlock();
        if (block.number <= end) {
            vm.roll(end + 1);
        }
    }

    function deployPonsV2Stack(IPoolManager pm, IPermit2 permit2, IWETH weth)
        internal
        returns (PonsV2Stack memory s)
    {
        address ponsV2Owner = vm.addr(uint256(keccak256("ponsV2Owner")));
        address ponsV2FeeSink = vm.addr(uint256(keccak256("ponsV2FeeSink")));
        s.launcher = vm.addr(uint256(keccak256("ponsV2Launcher")));
        vm.label(ponsV2Owner, "ponsV2Owner");
        vm.label(s.launcher, "ponsV2Launcher");

        IPositionDescriptor descriptor =
            new PositionDescriptor(pm, address(weth), bytes32("ETH"));
        s.positionManager = IPositionManager(
            address(
                new PositionManager(
                    pm, IAllowanceTransfer(address(permit2)), 100_000, descriptor, IWETH9(address(weth))
                )
            )
        );
        s.feeEscrow = new PonsV2FeeEscrow();

        bytes memory hookArgs = abi.encode(pm, s.feeEscrow, ponsV2FeeSink, ponsV2Owner);
        (address predictedHook, bytes32 hookSalt) =
            HookMiner.find(address(this), MEME_HOOK_FLAGS, type(PonsV2MemeHook).creationCode, hookArgs);
        s.memeHook = new PonsV2MemeHook{salt: hookSalt}(pm, s.feeEscrow, ponsV2FeeSink, ponsV2Owner);
        require(address(s.memeHook) == predictedHook, "hook address mismatch");

        vm.startPrank(ponsV2Owner);
        PonsV2BuybackVault buyback = new PonsV2BuybackVault(ponsV2Owner, s.memeHook, s.feeEscrow);
        PonsV2LaunchLocker locker = new PonsV2LaunchLocker(ponsV2Owner, address(s.positionManager));
        s.factory = new PonsV2LaunchFactory(
            ponsV2Owner,
            pm,
            s.positionManager,
            IAllowanceTransfer(address(permit2)),
            locker,
            s.memeHook,
            s.feeEscrow,
            buyback,
            PONS_LAUNCH_FEE
        );
        PonsV2LaunchDeployer deployer = new PonsV2LaunchDeployer(address(s.factory));
        PonsV2GraduationExecutor graduation = new PonsV2GraduationExecutor(
            s.positionManager, IAllowanceTransfer(address(permit2)), locker, address(s.factory)
        );
        s.memeHook.setFactory(address(s.factory));
        s.memeHook.setBuybackVault(buyback);
        buyback.setFactory(address(s.factory));
        locker.setFactory(address(s.factory));
        s.factory.setLaunchDeployer(deployer);
        s.factory.setGraduationExecutor(graduation);
        s.launchConfigId = s.factory.addLaunchConfig(
            PonsV2LaunchFactory.LaunchConfig({
                supply: PONS_V2_SUPPLY,
                curveFeeBps: PONS_V2_CURVE_FEE_BPS,
                phantomQuote: PONS_V2_PHANTOM_QUOTE,
                graduationThreshold: PONS_V2_GRADUATION_THRESHOLD,
                poolFee: PONS_V2_POOL_FEE,
                tickSpacing: PONS_V2_TICK_SPACING,
                enabled: true
            })
        );
        s.factory.setPairTokenEconomics(
            address(weth), PONS_V2_PHANTOM_QUOTE, PONS_V2_GRADUATION_THRESHOLD, 18
        );
        s.factory.setPairTokenApproved(address(weth), true);
        s.factory.setSnipeTaxStartBps(0);
        s.factory.setLaunchEnabled(true);
        vm.stopPrank();

        vm.deal(s.launcher, 100 ether);
        vm.deal(address(this), 100 ether);

        (s.launchToken, s.launchCurve, s.graduatedPoolKey) = launchAndGraduatePonsV2(
            s,
            weth,
            ponsV2TokenParams("Pons Se Wrap", "PSEW", keccak256("wp-udsm-cp-pons-v2"))
        );
    }

    function ponsV2TokenParams(string memory name, string memory symbol, bytes32 salt)
        internal
        pure
        returns (PonsV2LaunchFactory.TokenParams memory params)
    {
        params = PonsV2LaunchFactory.TokenParams({
            name: name,
            symbol: symbol,
            logo: "ipfs://logo",
            description: "hermetic pons v2 Uni V4 SE wrap",
            socials: PonsV2LauncherToken.Socials({
                twitter: "https://x.com/pons",
                telegram: "",
                discord: "",
                website: "https://pons.family",
                farcaster: ""
            }),
            creatorFeeRecipient: address(0),
            creatorTaxBps: 0,
            buybackEnabled: false,
            expectedEconomics: bytes32(0),
            salt: salt
        });
    }

    function _ponsV2LaunchToken(
        PonsV2Stack memory s,
        PonsV2LaunchFactory.TokenParams memory params,
        address quote
    ) internal returns (address token, address curve) {
        vm.prank(s.launcher);
        (token, curve) = s.factory.launchToken{value: PONS_LAUNCH_FEE}(params, s.launchConfigId, quote);
    }

    function _ponsV2BuyGraduateKey(
        PonsV2Stack memory s,
        IWETH weth,
        address launchToken,
        address curve,
        address buyRecipient
    ) internal returns (PoolKey memory key) {
        uint256 quoteIn = 10 ether;
        weth.deposit{value: quoteIn}();
        IERC20(address(weth)).approve(curve, quoteIn);
        PonsV2BondingCurve(payable(curve)).buy(quoteIn, 0, buyRecipient);

        IPonsV2LaunchFactory.LaunchedToken memory rec = s.factory.getLaunchedToken(launchToken);
        if (rec.phase == GraduationPhase.NotGraduated) {
            s.factory.graduate(launchToken);
            rec = s.factory.getLaunchedToken(launchToken);
        }
        if (rec.phase == GraduationPhase.Swept) {
            s.factory.createGraduatedPool(launchToken);
        }
        rec = s.factory.getLaunchedToken(launchToken);
        require(rec.phase == GraduationPhase.PoolCreated, "pons v2 not PoolCreated");

        address token0 = rec.pairToken < launchToken ? rec.pairToken : launchToken;
        address token1 = rec.pairToken < launchToken ? launchToken : rec.pairToken;
        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: rec.poolFee,
            tickSpacing: rec.tickSpacing,
            hooks: IHooks(address(s.memeHook))
        });
    }

    /// @notice Launch + curve buy + graduate to PoolCreated on an existing pons v2 stack.
    function launchAndGraduatePonsV2(
        PonsV2Stack memory s,
        IWETH weth,
        PonsV2LaunchFactory.TokenParams memory params
    ) internal returns (address launchToken, address curve, PoolKey memory key) {
        (launchToken, curve) = _ponsV2LaunchToken(s, params, address(weth));
        key = _ponsV2BuyGraduateKey(s, weth, launchToken, curve, address(this));
    }

    function launchAndGraduatePonsV2(
        PonsV2Stack memory s,
        IWETH weth,
        bytes32 salt,
        string memory name,
        string memory symbol
    ) internal returns (address token, address curve, PoolKey memory key) {
        return launchAndGraduatePonsV2(s, weth, ponsV2TokenParams(name, symbol, salt));
    }

    function launchGraduatePonsV2(
        PonsV2Stack memory s,
        IWETH weth,
        bytes32 salt,
        string memory symbol,
        address buyRecipient
    ) internal returns (address launchToken, address launchCurve, PoolKey memory key) {
        PonsV2LaunchFactory.TokenParams memory params = ponsV2TokenParams("Pons Se Wrap", symbol, salt);
        (launchToken, launchCurve) = _ponsV2LaunchToken(s, params, address(weth));
        key = _ponsV2BuyGraduateKey(s, weth, launchToken, launchCurve, buyRecipient);
    }

    function deployMorphoStack(CraneCtx memory ctx) internal returns (MorphoStack memory s) {
        s.morphoOwner = vm.addr(uint256(keccak256("MORPHO_OWNER")));
        s.feeRecipient = vm.addr(uint256(keccak256("FEE_RECIPIENT")));
        vm.label(s.morphoOwner, "OWNER");
        vm.label(s.feeRecipient, "FEE_RECIPIENT");

        s.morpho = IMorpho(address(new Morpho(s.morphoOwner)));
        s.irm = new AdaptiveCurveIrm(address(s.morpho));
        s.oracle = new OracleMock();
        s.oracle.setPrice(ORACLE_PRICE_SCALE);
        s.dummyCollateral = address(new SimpleMintableERC20("MorphoColl", "MC"));
        vm.label(address(s.morpho), "Morpho");
        vm.label(s.dummyCollateral, "MorphoDummyCollateral");

        vm.startPrank(s.morphoOwner);
        s.morpho.enableIrm(address(s.irm));
        s.morpho.enableLltv(MORPHO_LLTV);
        s.morpho.setFeeRecipient(s.feeRecipient);
        vm.stopPrank();

        IFacet erc4626F = MorphoBlue_Component_FactoryService.deployMorphoBlueERC4626Facet(ctx.create3Factory);
        IFacet inF = MorphoBlue_Component_FactoryService.deployMorphoBlueStandardExchangeInFacet(ctx.create3Factory);
        IFacet outF = MorphoBlue_Component_FactoryService.deployMorphoBlueStandardExchangeOutFacet(ctx.create3Factory);
        IFacet marker = MorphoBlue_Component_FactoryService.deployMorphoBlueStandardExchangeMarkerFacet(ctx.create3Factory);

        vm.prank(ctx.owner);
        IVaultFeeOracleManager(address(ctx.indexedexManager)).setDefaultUsageFee(0);
        vm.prank(ctx.owner);
        s.pkg = MorphoBlue_Component_FactoryService.deployMorphoBlueStandardExchangeDFPkg(
            ctx.indexedexManager,
            IMorphoBlueStandardExchangeDFPkg.PkgInit({
                erc20Facet: ctx.erc20Facet,
                erc2612Facet: ctx.erc2612Facet,
                erc5267Facet: ctx.erc5267Facet,
                morphoBlueErc4626Facet: erc4626F,
                multiAssetBasicVaultFacet: ctx.multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: ctx.multiAssetStandardVaultFacet,
                exchangeInFacet: inF,
                exchangeOutFacet: outF,
                markerFacet: marker,
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(ctx.indexedexManager)),
                vaultRegistryDeployment: IVaultRegistryDeployment(address(ctx.indexedexManager)),
                permit2: ctx.permit2
            })
        );
    }

    function createMarketAndDeployVault(MorphoStack memory s, address loanToken, address owner)
        internal
        returns (address vault, MarketParams memory params)
    {
        params = MarketParams({
            loanToken: loanToken,
            collateralToken: s.dummyCollateral,
            oracle: address(s.oracle),
            irm: address(s.irm),
            lltv: MORPHO_LLTV
        });
        s.morpho.createMarket(params);
        vm.prank(owner);
        vault = s.pkg.deployVault(
            IMorphoBlueStandardExchangeDFPkg.PkgArgs({morpho: s.morpho, marketParams: params})
        );
        vm.label(vault, "MorphoBlueSe");
    }
}
