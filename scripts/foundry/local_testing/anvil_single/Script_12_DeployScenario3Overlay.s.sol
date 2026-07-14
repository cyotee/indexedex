// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {LocalTestingDeploymentBase} from "../shared/LocalTestingDeploymentBase.sol";
import {ManifestEntry} from "../shared/ManifestEntry.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {CREATE3} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/solmate/CREATE3.sol";
import {WeightedPool8020Factory} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool8020Factory.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {TokenConfig, TokenType} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    IBalancerV3ConstantProductPoolStandardVaultPkg
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {
    IUniswapV4StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {
    UniswapV4_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/reusable/DetfFacetFactoryService.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/reusable/DetfComponentFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/reusable/DetfPkgFactoryService.sol";
import {
    SingleVaultDetf_Component_FactoryService
} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Component_FactoryService.sol";
import {
    SingleVaultDetf_Facet_FactoryService
} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Facet_FactoryService.sol";
import {
    SingleVaultDetf_Pkg_FactoryService
} from "contracts/vaults/detf/composed/single/SingleVaultDetf_Pkg_FactoryService.sol";
import {
    ISingleVaultDetfDFPkg
} from "contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/protocol/DETFNFTVaultDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/protocol/RebasingClaimTokenDFPkg.sol";
import {DetfSuperchainBridgeRepo} from "contracts/vaults/detf/DetfSuperchainBridgeRepo.sol";

import {
    ISuperChainBridgeTokenRegistry
} from "@crane/contracts/interfaces/ISuperChainBridgeTokenRegistry.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";

import {SingleVaultDetfUniswapV4LiquiditySeeder} from "../../shared/SingleVaultDetfUniswapV4LiquiditySeeder.sol";

/// @title Script_12_DeployScenario3Overlay
/// @notice Deploys Scenario 3: a Single Vault DETF and an outer Balancer WETH/DETF pool for local testing
contract Script_12_DeployScenario3Overlay is LocalTestingDeploymentBase {
    using BetterEfficientHashLib for bytes;
    using UniswapV4_Component_FactoryService for ICreate3FactoryProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using SingleVaultDetf_Facet_FactoryService for ICreate3FactoryProxy;
    using DetfFacetFactoryService for ICreate3FactoryProxy;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant INDEXEDEX_CORE_FILE = "02_indexedex_core.json";
    string internal constant PROTOCOLS_BASE_FILE = "03_protocols_base.json";
    string internal constant FOUNDATION_PACKAGES_FILE = "05_foundation_packages.json";
    string internal constant FOUNDATION_ASSETS_FILE = "06_foundation_assets.json";
    string internal constant ARTIFACT_FILE = "12_scenario_3.json";

    uint256 private constant INITIAL_WETH_DEPOSIT = 10e18;
    uint256 private constant INITIAL_RICH_DEPOSIT = 10e18;
    uint24 private constant WETH_RICH_WIDTH_MULTIPLIER = 60;
    uint24 private constant WETH_RICH_FEE = 3000;
    int24 private constant WETH_RICH_TICK_SPACING = 60;

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    IVaultRegistryDeployment private vaultRegistry;
    IVaultFeeOracleQuery private feeOracle;

    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private erc4626BasicVaultFacet;
    IFacet private erc4626StandardVaultFacet;
    IFacet private operableFacet;

    IBalancerVault private balancerV3Vault;
    IBalancerV3StandardExchangeRouterProxy private balancerV3StandardExchangeRouter;
    IWeightedPool8020Factory private weightedPool8020Factory;
    IStandardExchangeRateProviderDFPkg private rateProviderPkg;
    IBalancerV3ConstantProductPoolStandardVaultPkg private balConstProdPkg;
    IPermit2 private permit2;
    IWETH private weth;

    IFacet private multiAssetBasicVaultFacet;
    IFacet private multiAssetStandardVaultFacet;
    IFacet private singleVaultDetfExchangeInFacet;
    IFacet private singleVaultDetfExchangeInQueryFacet;
    IFacet private singleVaultDetfInfoFacet;
    IFacet private singleVaultDetfExchangeOutFacet;
    IFacet private singleVaultDetfBondingFacet;
    IFacet private detfNFTVaultFacet;
    IFacet private rebasingClaimTokenFacet;
    IFacet private uniswapV4StandardExchangeInFacet;
    IFacet private uniswapV4StandardExchangeInQueryFacet;
    IFacet private uniswapV4StandardExchangePositionImportFacet;
    IFacet private uniswapV4StandardExchangeOutFacet;
    IFacet private erc721Facet;

    IDetfSelfNftInventoryDFPkg private detfNFTVaultPkg;
    IRebasingClaimTokenDFPkg private rebasingClaimTokenPkg;
    IUniswapV4StandardExchangeDFPkg private underlyingVaultPkg;
    ISingleVaultDetfDFPkg private protocolDetfPkg;
    IPoolManager private poolManager;
    SingleVaultDetfUniswapV4LiquiditySeeder private liquiditySeeder;

    address private pairToken;
    address private protocolDetf;
    address private protocolNftVault;
    address private rebasingClaimToken;
    address private reservePool;
    address private underlyingVault;
    address private weightedPool;

    function run() external {
        _loadConfig();
        _loadDependencies();

        _logHeader("Stage 12: Deploy Scenario 3 Overlay");

        if (_loadExistingScenario()) {
            // Re-emit JSON + fragments so the tokenlist aggregator and chain
            // platform synthesis always see the Single Vault DETF (CHIR) even
            // when the on-chain instance was already deployed.
            _exportJson();
            _exportFragments();
            _logResults();
            return;
        }

        vm.startBroadcast();
        _deployWeightedPool8020FactoryIfNeeded();
        _deployFacets();
        _deployUniswapV4PoolInfra();
        _seedWethRichPool();
        _deployPkgs();
        _deployProtocolDetf();
        _deployOuterPool();
        vm.stopBroadcast();

        _exportJson();
        _exportFragments();
        _logResults();
    }

    function _loadDependencies() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress(CRANE_FOUNDATION_FILE, "create3Factory"));
        diamondPackageFactory = IDiamondPackageCallBackFactory(_readAddress(CRANE_FOUNDATION_FILE, "diamondPackageFactory"));
        vaultRegistry = IVaultRegistryDeployment(_readAddress(INDEXEDEX_CORE_FILE, "indexedexManager"));
        feeOracle = IVaultFeeOracleQuery(_readAddress(INDEXEDEX_CORE_FILE, "vaultFeeOracle"));

        erc20Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc20Facet"));
        erc2612Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc2612Facet"));
        erc5267Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc5267Facet"));
        erc4626BasicVaultFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc4626BasicVaultFacet"));
        erc4626StandardVaultFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc4626StandardVaultFacet"));
        operableFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "operableFacet"));

        permit2 = IPermit2(_readAddress(PROTOCOLS_BASE_FILE, "permit2"));
        weth = IWETH(_readAddress(PROTOCOLS_BASE_FILE, "weth"));
        balancerV3Vault = IBalancerVault(_readAddress(PROTOCOLS_BASE_FILE, "balancerV3Vault"));
        balancerV3StandardExchangeRouter = IBalancerV3StandardExchangeRouterProxy(
            _readAddress(PROTOCOLS_BASE_FILE, "balancerV3StandardExchangeRouter")
        );

        rateProviderPkg = IStandardExchangeRateProviderDFPkg(_readAddress(FOUNDATION_PACKAGES_FILE, "rateProviderPkg"));
        balConstProdPkg = IBalancerV3ConstantProductPoolStandardVaultPkg(
            _readAddress(FOUNDATION_PACKAGES_FILE, "balancerV3ConstantProductPoolStandardVaultPkg")
        );

        pairToken = _readAddress(FOUNDATION_ASSETS_FILE, "pairToken");

        require(address(create3Factory) != address(0), "Create3Factory not found - run Script_01 first");
        require(address(vaultRegistry) != address(0), "IndexedexManager not found - run Script_02 first");
        require(address(balancerV3Vault) != address(0), "Balancer V3 vault not found - run Script_03 first");
        require(address(balancerV3StandardExchangeRouter) != address(0), "Standard exchange router not found - run Script_03 first");
        require(address(rateProviderPkg) != address(0), "Rate provider pkg not found - run Script_05 first");
        require(address(balConstProdPkg) != address(0), "Balancer const-prod pkg not found - run Script_05 first");
        require(pairToken != address(0), "RICH token not found - run Script_06 first");
    }

    function _loadExistingScenario() internal returns (bool) {
        (address detf, bool hasDetf) = _readAddressSafe(ARTIFACT_FILE, "protocolDetf");
        (address outerPool, bool hasOuterPool) = _readAddressSafe(ARTIFACT_FILE, "balancerWethDetfPool");
        (address poolManagerAddr, bool hasPoolManager) = _readAddressSafe(ARTIFACT_FILE, "poolManager");

        if (!hasDetf || !hasOuterPool || !hasPoolManager) {
            return false;
        }

        if (detf.code.length == 0 || outerPool.code.length == 0 || poolManagerAddr.code.length == 0) {
            return false;
        }

        protocolDetf = detf;
        weightedPool = outerPool;
        poolManager = IPoolManager(poolManagerAddr);

        (protocolNftVault, ) = _readAddressSafe(ARTIFACT_FILE, "protocolNftVault");
        (rebasingClaimToken, ) = _readAddressSafe(ARTIFACT_FILE, "rebasingClaimToken");
        (reservePool, ) = _readAddressSafe(ARTIFACT_FILE, "reservePool");
        (underlyingVault, ) = _readAddressSafe(ARTIFACT_FILE, "underlyingVault");

        // Reload package + factory addresses so resume re-exports do not clobber
        // non-zero artifact fields with zero-initialized storage.
        (address weightedPoolFactoryAddr, bool hasWeightedPoolFactory) =
            _readAddressSafe(ARTIFACT_FILE, "weightedPool8020Factory");
        if (hasWeightedPoolFactory && weightedPoolFactoryAddr != address(0) && weightedPoolFactoryAddr.code.length > 0) {
            weightedPool8020Factory = IWeightedPool8020Factory(weightedPoolFactoryAddr);
        }

        (address detfPkgAddr, ) = _readAddressSafe(ARTIFACT_FILE, "protocolDetfPkg");
        if (detfPkgAddr != address(0)) {
            protocolDetfPkg = ISingleVaultDetfDFPkg(detfPkgAddr);
        }
        (address nftPkgAddr, ) = _readAddressSafe(ARTIFACT_FILE, "detfNFTVaultPkg");
        if (nftPkgAddr != address(0)) {
            detfNFTVaultPkg = IDetfSelfNftInventoryDFPkg(nftPkgAddr);
        }
        (address rebasingClaimTokenPkgAddr, ) = _readAddressSafe(ARTIFACT_FILE, "rebasingClaimTokenPkg");
        if (rebasingClaimTokenPkgAddr != address(0)) {
            rebasingClaimTokenPkg = IRebasingClaimTokenDFPkg(rebasingClaimTokenPkgAddr);
        }
        (address underlyingVaultPkgAddr, ) = _readAddressSafe(ARTIFACT_FILE, "underlyingVaultPkg");
        if (underlyingVaultPkgAddr != address(0)) {
            underlyingVaultPkg = IUniswapV4StandardExchangeDFPkg(underlyingVaultPkgAddr);
        }
        (address seederAddr, ) = _readAddressSafe(ARTIFACT_FILE, "liquiditySeeder");
        if (seederAddr != address(0) && seederAddr.code.length > 0) {
            liquiditySeeder = SingleVaultDetfUniswapV4LiquiditySeeder(seederAddr);
        }

        return true;
    }

    function _deployWeightedPool8020FactoryIfNeeded() internal {
        (address existingFactory, bool hasExistingFactory) = _readAddressSafe(ARTIFACT_FILE, "weightedPool8020Factory");
        if (hasExistingFactory && existingFactory != address(0) && existingFactory.code.length > 0) {
            weightedPool8020Factory = IWeightedPool8020Factory(existingFactory);
            return;
        }

        weightedPool8020Factory = IWeightedPool8020Factory(
            create3Factory.create3WithArgs(
                type(WeightedPool8020Factory).creationCode,
                abi.encode(address(balancerV3Vault), uint32(365 days), "Factory v1", "8020Pool v1"),
                keccak256("LocalTestingScenario3WeightedPool8020Factory")
            )
        );
    }

    function _deployFacets() internal {
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();

        singleVaultDetfExchangeInFacet = create3Factory.deploySingleVaultDetfExchangeInFacet();
        singleVaultDetfExchangeInQueryFacet = create3Factory.deploySingleVaultDetfExchangeInQueryFacet();
        singleVaultDetfInfoFacet = create3Factory.deploySingleVaultDetfInfoFacet();
        singleVaultDetfExchangeOutFacet = create3Factory.deploySingleVaultDetfExchangeOutFacet();
        singleVaultDetfBondingFacet = create3Factory.deploySingleVaultDetfBondingFacet();

        detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();
        rebasingClaimTokenFacet = create3Factory.deployRebasingClaimTokenFacet();
        uniswapV4StandardExchangeInFacet = create3Factory.deployUniswapV4StandardExchangeInFacet();
        uniswapV4StandardExchangeInQueryFacet = create3Factory.deployUniswapV4StandardExchangeInQueryFacet();
        uniswapV4StandardExchangePositionImportFacet = create3Factory.deployUniswapV4StandardExchangePositionImportFacet();
        uniswapV4StandardExchangeOutFacet = create3Factory.deployUniswapV4StandardExchangeOutFacet();

        erc721Facet = IFacet(
            create3Factory.deployFacet(
                type(ERC721Facet).creationCode,
                keccak256("LocalTestingScenario3_ERC721Facet")
            )
        );
    }

    function _deployUniswapV4PoolInfra() internal {
        (address existingPoolManager, bool hasPoolManager) = _readAddressSafe(ARTIFACT_FILE, "poolManager");
        if (hasPoolManager && existingPoolManager != address(0) && existingPoolManager.code.length > 0) {
            poolManager = IPoolManager(existingPoolManager);
        } else {
            poolManager = IPoolManager(
                create3Factory.create3WithArgs(
                    type(PoolManager).creationCode,
                    abi.encode(owner),
                    keccak256("LocalTestingScenario3PoolManager")
                )
            );
        }

        (address existingSeeder, bool hasSeeder) = _readAddressSafe(ARTIFACT_FILE, "liquiditySeeder");
        if (hasSeeder && existingSeeder != address(0) && existingSeeder.code.length > 0) {
            liquiditySeeder = SingleVaultDetfUniswapV4LiquiditySeeder(existingSeeder);
        } else {
            liquiditySeeder = SingleVaultDetfUniswapV4LiquiditySeeder(
                create3Factory.create3WithArgs(
                    type(SingleVaultDetfUniswapV4LiquiditySeeder).creationCode,
                    abi.encode(poolManager),
                    keccak256("LocalTestingScenario3LiquiditySeeder")
                )
            );
        }
    }

    function _seedWethRichPool() internal {
        PoolKey memory poolKey = _buildPoolKey();
        PoolManager(address(poolManager)).initialize(poolKey, TickMath.getSqrtPriceAtTick(0));

        weth.deposit{value: INITIAL_WETH_DEPOSIT}();
        IERC20(address(weth)).transfer(address(liquiditySeeder), INITIAL_WETH_DEPOSIT);
        IERC20(pairToken).transfer(address(liquiditySeeder), INITIAL_RICH_DEPOSIT);

        liquiditySeeder.addLiquidity(
            poolKey,
            -int24(WETH_RICH_TICK_SPACING),
            int24(WETH_RICH_TICK_SPACING),
            LiquidityAmounts.getLiquidityForAmounts(
                TickMath.getSqrtPriceAtTick(0),
                TickMath.getSqrtPriceAtTick(-int24(WETH_RICH_TICK_SPACING)),
                TickMath.getSqrtPriceAtTick(int24(WETH_RICH_TICK_SPACING)),
                INITIAL_WETH_DEPOSIT,
                INITIAL_RICH_DEPOSIT
            )
        );
    }

    function _deployPkgs() internal {
        detfNFTVaultPkg = IDetfSelfNftInventoryDFPkg(
            address(
                DetfPkgFactoryService.deployDETFNFTVaultDFPkg(
                    vaultRegistry,
                    DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
                        erc721Facet,
                        erc4626BasicVaultFacet,
                        erc4626StandardVaultFacet,
                        detfNFTVaultFacet,
                        feeOracle,
                        vaultRegistry
                    )
                )
            )
        );

        rebasingClaimTokenPkg = DetfPkgFactoryService.deployRebasingClaimTokenDFPkg(
            create3Factory,
            DetfComponentFactoryService.buildRICHIRPkgInit(
                erc20Facet,
                erc5267Facet,
                erc2612Facet,
                rebasingClaimTokenFacet,
                diamondPackageFactory
            )
        );

        underlyingVaultPkg = UniswapV4_Component_FactoryService.deployUniswapV4StandardExchangeDFPkgFromVaultRegistry(
            vaultRegistry,
            UniswapV4_Component_FactoryService.buildArgsUniswapV4StandardExchangePkgInit(
                erc20Facet,
                erc5267Facet,
                erc2612Facet,
                multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet,
                uniswapV4StandardExchangeInFacet,
                uniswapV4StandardExchangeInQueryFacet,
                uniswapV4StandardExchangePositionImportFacet,
                uniswapV4StandardExchangeOutFacet,
                feeOracle,
                vaultRegistry,
                permit2,
                poolManager
            )
        );

        DetfSuperchainBridgeRepo.BridgeConfig memory bridgeConfig = _emptyBridgeConfig();
        protocolDetfPkg = SingleVaultDetf_Pkg_FactoryService.deploySingleVaultDetfDFPkg(
            vaultRegistry,
            SingleVaultDetf_Component_FactoryService.buildPkgInit(
                SingleVaultDetf_Component_FactoryService.SingleVaultDetfFacets({
                    erc20Facet: erc20Facet,
                    erc5267Facet: erc5267Facet,
                    erc2612Facet: erc2612Facet,
                    multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                    multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                    exchangeInFacet: singleVaultDetfExchangeInFacet,
                    exchangeInQueryFacet: singleVaultDetfExchangeInQueryFacet,
                    infoFacet: singleVaultDetfInfoFacet,
                    exchangeOutFacet: singleVaultDetfExchangeOutFacet,
                    bondingFacet: singleVaultDetfBondingFacet,
                    operableFacet: operableFacet
                }),
                SingleVaultDetf_Component_FactoryService.SingleVaultDetfInfra({
                    feeOracle: feeOracle,
                    vaultRegistryDeployment: vaultRegistry,
                    permit2: permit2,
                    rateAsset: IERC20(address(weth)),
                    balancerV3Vault: balancerV3Vault,
                    balancerV3PrepayRouter: balancerV3StandardExchangeRouter,
                    weightedPool8020Factory: weightedPool8020Factory,
                    bridgeTokenRegistry: bridgeConfig.bridgeTokenRegistry,
                    standardBridge: bridgeConfig.standardBridge,
                    messenger: bridgeConfig.messenger,
                    localRelayer: bridgeConfig.localRelayer,
                    peerRelayer: bridgeConfig.peerRelayer,
                    underlyingVaultPkg: underlyingVaultPkg,
                    detfNFTVaultPkg: detfNFTVaultPkg,
                    rebasingClaimTokenPkg: rebasingClaimTokenPkg,
                    rateProviderPkg: rateProviderPkg,
                    diamondFactory: diamondPackageFactory
                })
            )
        );
    }

    function _deployProtocolDetf() internal {
        protocolDetf = vaultRegistry.deployVault(
            IStandardVaultPkg(address(protocolDetfPkg)),
            abi.encode(
                SingleVaultDetf_Component_FactoryService.buildPkgArgs(
                    "Single Vault DETF CHIR",
                    "CHIR",
                    IERC20(pairToken),
                    INITIAL_RICH_DEPOSIT,
                    INITIAL_WETH_DEPOSIT,
                    _buildPoolKey(),
                    WETH_RICH_WIDTH_MULTIPLIER
                )
            )
        );

        IProtocolDETF detf = IProtocolDETF(protocolDetf);
        protocolNftVault = address(detf.detfNFTVault());
        rebasingClaimToken = address(detf.rebasingClaimToken());
        reservePool = detf.reservePool();
        underlyingVault = address(ISingleVaultDetf(protocolDetf).underlyingVault());
    }

    function _deployOuterPool() internal {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _standardTokenConfig(address(weth));
        cfg[1] = _standardTokenConfig(protocolDetf);
        weightedPool = balConstProdPkg.deployVault(cfg, address(0));
    }

    function _standardTokenConfig(address token) internal pure returns (TokenConfig memory cfg) {
        cfg = TokenConfig({
            token: IERC20(token),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
    }

    function _buildPoolKey() internal view returns (PoolKey memory poolKey) {
        (address token0, address token1) =
            address(weth) < pairToken ? (address(weth), pairToken) : (pairToken, address(weth));

        poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: WETH_RICH_FEE,
            tickSpacing: WETH_RICH_TICK_SPACING,
            hooks: IHooks(address(0))
        });
    }

    function _emptyBridgeConfig() internal pure returns (DetfSuperchainBridgeRepo.BridgeConfig memory config) {
        config = DetfSuperchainBridgeRepo.BridgeConfig({
            bridgeTokenRegistry: ISuperChainBridgeTokenRegistry(address(0)),
            standardBridge: IStandardBridge(payable(address(0))),
            messenger: ICrossDomainMessenger(address(0)),
            localRelayer: address(0),
            peerRelayer: address(0)
        });
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("scenario3", "pairToken", pairToken);
        json = vm.serializeAddress("scenario3", "weightedPool8020Factory", address(weightedPool8020Factory));
        json = vm.serializeAddress("scenario3", "protocolDetfPkg", address(protocolDetfPkg));
        json = vm.serializeAddress("scenario3", "detfNFTVaultPkg", address(detfNFTVaultPkg));
        json = vm.serializeAddress("scenario3", "rebasingClaimTokenPkg", address(rebasingClaimTokenPkg));
        json = vm.serializeAddress("scenario3", "underlyingVaultPkg", address(underlyingVaultPkg));
        json = vm.serializeAddress("scenario3", "poolManager", address(poolManager));
        json = vm.serializeAddress("scenario3", "liquiditySeeder", address(liquiditySeeder));
        json = vm.serializeAddress("scenario3", "protocolDetf", protocolDetf);
        json = vm.serializeAddress("scenario3", "protocolNftVault", protocolNftVault);
        json = vm.serializeAddress("scenario3", "rebasingClaimToken", rebasingClaimToken);
        json = vm.serializeAddress("scenario3", "reservePool", reservePool);
        json = vm.serializeAddress("scenario3", "underlyingVault", underlyingVault);
        json = vm.serializeAddress("scenario3", "balancerWethDetfPool", weightedPool);
        json = vm.serializeAddress("scenario3", "owner", owner);
        json = vm.serializeAddress("scenario3", "deployer", deployer);
        json = vm.serializeUint("scenario3", "chainId", block.chainid);
        json = vm.serializeString("scenario3", "networkProfile", _networkProfile());
        _writeJson(json, ARTIFACT_FILE);
    }

    function _exportFragments() internal {
        _writeFragment("tokens", "richir", rebasingClaimToken, "Rich Reserve Token", "RICHIR", new string[](0));
        _writeFragment(
            "vaults/protocolDetf",
            "protocolDetf",
            protocolDetf,
            "Single Vault DETF CHIR",
            "CHIR",
            new string[](0)
        );
        _writeFragment(
            "vaults/strategy",
            "underlyingVault",
            underlyingVault,
            "WETH/RICH Strategy Vault",
            "wethRichVlt",
            new string[](0)
        );
        _writeFragment(
            "pools/balancerV3",
            "balancerWethDetfPool",
            weightedPool,
            "Balancer 80/20 WETH/DETF Pool",
            "wethDetfBP",
            new string[](0)
        );
        _writeFragment(
            "pools/balancerV3",
            "reservePool",
            reservePool,
            "DETF Reserve Pool",
            "reserveBP",
            new string[](0)
        );
    }

    function _writeFragment(
        string memory typeDir,
        string memory key,
        address addr,
        string memory name,
        string memory symbol,
        string[] memory tags
    ) internal {
        if (addr == address(0)) return;
        ManifestEntry memory entry = ManifestEntry({
            chainId: block.chainid,
            addr: addr,
            name: name,
            symbol: symbol,
            decimals: 18,
            tags: tags
        });
        _writeManifestEntry(typeDir, key, entry);
    }

    function _logResults() internal view {
        _logString("Artifact:", ARTIFACT_FILE);
        _logAddress("WeightedPool8020Factory:", address(weightedPool8020Factory));
        _logAddress("Single Vault DETF:", protocolDetf);
        _logAddress("Protocol NFT Vault:", protocolNftVault);
        _logAddress("RICHIR:", rebasingClaimToken);
        _logAddress("Reserve Pool:", reservePool);
        _logAddress("WETH/RICH Vault:", underlyingVault);
        _logAddress("Balancer WETH/DETF Pool:", weightedPool);
        _logComplete("Stage 12");
    }
}