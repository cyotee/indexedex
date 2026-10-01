// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {PonsV2MemeHook} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol";
import {PonsV2FeeEscrow} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2FeeEscrow.sol";
import {HookMiner} from "@crane/contracts/protocols/dexes/uniswap/v4/utils/HookMiner.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IUniswapV4FullSpreadPonsFamilyHookDFPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/IUniswapV4FullSpreadPonsFamilyHookDFPkg.sol";
import {
    UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService.sol";
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
    IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";

abstract contract TestBase_UniswapV4FullSpreadPonsFamilyHook is TestBase_Permit2, TestBase_VaultComponents {
    using UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService for IFacet;
    using UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService for IIndexedexManagerProxy;
    using UniswapV4TwapOracleFactoryService for ICreate3FactoryProxy;

    uint256 internal constant DEFAULT_V4_LIQUID_RESERVE_PCT = 0.2e18;

    IPoolManager internal poolManager;
    IWETH internal weth;
    PonsV2MemeHook internal ponsHook;
    IFacet internal uniswapV4StandardExchangeInFacet;
    IFacet internal uniswapV4StandardExchangeInQueryFacet;
    IFacet internal uniswapV4StandardExchangePositionImportFacet;
    IFacet internal uniswapV4StandardExchangeOutFacet;
    IFacet internal uniswapV4StandardExchangeOutQueryFacet;
    IFacet internal uniswapV4StandardExchangeLiquidReserveFacet;
    IFacet internal uniswapV4StandardExchangeInMultiFacet;
    IFacet internal uniswapV4StandardExchangeInMultiQueryFacet;
    IFacet internal uniswapV4StandardExchangeOutMultiFacet;
    IFacet internal uniswapV4StandardExchangeOutMultiQueryFacet;
    IUniswapV4FullSpreadPonsFamilyHookDFPkg internal uniswapV4StandardExchangeDFPkg;
    IFacet internal twapOracleFacet;
    IUniswapV4MultiPoolTwapOracleDFPkg internal twapOraclePkg;
    IUniswapV4MultiPoolTwapOracle internal twapOracle;

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        if (address(weth) == address(0)) {
            weth = IWETH(address(new WETH9()));
        }
        poolManager = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("TestBase_UniswapV4FullSpreadPonsFamilyHook_PoolManager")
        ));
        twapOracleFacet = create3Factory.deployUniswapV4MultiPoolTwapOracleFacet();
        twapOraclePkg =
            create3Factory.deployUniswapV4MultiPoolTwapOracleDFPkg(twapOracleFacet, diamondPackageFactory);
        twapOracle = twapOraclePkg.deployOracle(
            IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: address(poolManager)})
        );
        uniswapV4StandardExchangeInFacet = create3Factory.deployUniswapV4FullSpreadPonsFamilyHookInFacet();
        uniswapV4StandardExchangeInQueryFacet = create3Factory.deployUniswapV4FullSpreadPonsFamilyHookInQueryFacet();
        uniswapV4StandardExchangePositionImportFacet =
            create3Factory.deployUniswapV4FullSpreadPonsFamilyHookPositionImportFacet();
        uniswapV4StandardExchangeOutFacet = create3Factory.deployUniswapV4FullSpreadPonsFamilyHookOutFacet();
        uniswapV4StandardExchangeOutQueryFacet = create3Factory.deployUniswapV4FullSpreadPonsFamilyHookOutQueryFacet();
        uniswapV4StandardExchangeLiquidReserveFacet = create3Factory.deployUniswapV4FullSpreadPonsFamilyHookLiquidReserveFacet();
        uniswapV4StandardExchangeInMultiFacet = create3Factory.deployUniswapV4FullSpreadPonsFamilyHookInMultiFacet();
        uniswapV4StandardExchangeInMultiQueryFacet = create3Factory.deployUniswapV4FullSpreadPonsFamilyHookInMultiQueryFacet();
        uniswapV4StandardExchangeOutMultiFacet = create3Factory.deployUniswapV4FullSpreadPonsFamilyHookOutMultiFacet();
        uniswapV4StandardExchangeOutMultiQueryFacet = create3Factory.deployUniswapV4FullSpreadPonsFamilyHookOutMultiQueryFacet();

        _initializePonsHook();
        IPositionManager importManager = _positionManagerForTests();
        vm.startPrank(owner);
        // Type default 20% for V4 liquid-reserve fee type id (D5–D8 / H4).
        IVaultFeeOracleManager(address(indexedexManager))
            .setDefaultLiquidReservePercentageOfTypeId(
                type(IUniswapV4FullSpreadPonsFamilyHookLiquidReserve).interfaceId, DEFAULT_V4_LIQUID_RESERVE_PCT
            );

        IUniswapV4FullSpreadPonsFamilyHookDFPkg.PkgInit memory pkgInit =
            UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService.buildArgsUniswapV4FullSpreadPonsFamilyHookPkgInit(_univ4SePkgInitCore());
        pkgInit = UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService.attachTwapOracle(pkgInit, twapOracle);
        pkgInit.positionManager = importManager;
        pkgInit.expectedHook = address(ponsHook);
        pkgInit = UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService.attachUniswapV4FullSpreadPonsFamilyHookMultiFacets(
            pkgInit,
            uniswapV4StandardExchangeInMultiFacet,
            uniswapV4StandardExchangeInMultiQueryFacet,
            uniswapV4StandardExchangeOutMultiFacet,
            uniswapV4StandardExchangeOutMultiQueryFacet
        );
        uniswapV4StandardExchangeDFPkg = indexedexManager.deployUniswapV4FullSpreadPonsFamilyHookDFPkg(pkgInit);
        vm.stopPrank();
    }

    function _univ4SePkgInitCore()
        internal
        view
        returns (UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService.Univ4SePkgInitCore memory a)
    {
        a.erc20Facet = erc20Facet;
        a.erc5267Facet = erc5267Facet;
        a.erc2612Facet = erc2612Facet;
        a.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        a.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        a.uniswapV4StandardExchangeInFacet = uniswapV4StandardExchangeInFacet;
        a.uniswapV4StandardExchangeInQueryFacet = uniswapV4StandardExchangeInQueryFacet;
        a.uniswapV4StandardExchangePositionImportFacet = uniswapV4StandardExchangePositionImportFacet;
        a.uniswapV4StandardExchangeOutFacet = uniswapV4StandardExchangeOutFacet;
        a.uniswapV4StandardExchangeOutQueryFacet = uniswapV4StandardExchangeOutQueryFacet;
        a.uniswapV4StandardExchangeLiquidReserveFacet = uniswapV4StandardExchangeLiquidReserveFacet;
        a.vaultFeeOracleQuery = indexedexManager;
        a.vaultRegistryDeployment = indexedexManager;
        a.permit2 = permit2;
        a.poolManager = poolManager;
        a.weth = weth;
    }

    function _positionManagerForTests() internal virtual returns (IPositionManager) {
        return IPositionManager(address(0));
    }

    /// @dev Real hook with a local authorized registrar for arbitrary decimal/hostile token controls.
    /// Full launch/graduation coverage overrides this with the production Pons factory stack.
    function _initializePonsHook() internal virtual {
        PonsV2FeeEscrow escrow = new PonsV2FeeEscrow();
        bytes memory args = abi.encode(poolManager, escrow, address(0xfee), address(this));
        uint160 flags = uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG);
        (address predicted, bytes32 salt) = HookMiner.find(address(this), flags,
            ArtifactCreationCode.creationCode(create3Factory, "PonsV2MemeHook.sol:PonsV2MemeHook"), args);
        ponsHook = new PonsV2MemeHook{salt: salt}(poolManager, escrow, address(0xfee), address(this));
        assertEq(address(ponsHook), predicted);
        ponsHook.setFactory(address(this));
    }
}

// FactoryService loads these artifacts by name in focused build graphs.
