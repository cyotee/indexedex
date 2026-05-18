// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { betterconsole as console } from "@crane/contracts/utils/vm/foundry/tools/betterconsole.sol";

import {DeploymentBase as AnvilDeploymentBase} from "../../anvil_sepolia/DeploymentBase.sol";

import {ETHEREUM_SEPOLIA} from "@crane/contracts/constants/networks/ETHEREUM_SEPOLIA.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/interfaces/ISuperChainBridgeTokenRegistry.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IERC20MinterFacade} from "@crane/contracts/tokens/ERC20/IERC20MinterFacade.sol";
import {IWeightedPool8020Factory} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {WeightedPool8020Factory} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool8020Factory.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IBalancerV3StandardExchangeRouterProxy} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";
import {
    IUniswapV4StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {
    UniswapV4_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
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
import {
    BaseProtocolDETF_Component_FactoryService
} from "contracts/vaults/protocol/BaseProtocolDETF_Component_FactoryService.sol";
import {BaseProtocolDETF_Facet_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Facet_FactoryService.sol";
import {BaseProtocolDETF_Pkg_FactoryService} from "contracts/vaults/protocol/BaseProtocolDETF_Pkg_FactoryService.sol";
import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {IRICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";

import {
    SingleVaultDetfUniswapV4LiquiditySeeder
} from "../../shared/SingleVaultDetfUniswapV4LiquiditySeeder.sol";

contract Script_16_DeployProtocolDETF is AnvilDeploymentBase {
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using UniswapV4_Component_FactoryService for ICreate3FactoryProxy;
    using SingleVaultDetf_Facet_FactoryService for ICreate3FactoryProxy;

    uint256 private constant INITIAL_DEMO_WETH_DEPOSIT = 10e18;
    uint256 private constant INITIAL_RICH_DEPOSIT = 10e18;
    uint24 private constant WETH_RICH_WIDTH_MULTIPLIER = 60;
    uint24 private constant WETH_RICH_FEE = 3000;
    int24 private constant WETH_RICH_TICK_SPACING = 60;

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    IVaultRegistryDeployment private vaultRegistry;
    IVaultFeeOracleQuery private feeOracle;
    IERC20MinterFacade private erc20MinterFacade;

    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private erc4626BasicVaultFacet;
    IFacet private erc4626StandardVaultFacet;
    IFacet private operableFacet;
    IFacet private multiAssetBasicVaultFacet;
    IFacet private multiAssetStandardVaultFacet;

    IBalancerV3StandardExchangeRouterProxy private balancerV3StandardExchangeRouter;
    IStandardExchangeRateProviderDFPkg private rateProviderPkg;
    IWeightedPool8020Factory private weightedPool8020Factory;

    IFacet private singleVaultDetfExchangeInFacet;
    IFacet private singleVaultDetfExchangeInQueryFacet;
    IFacet private singleVaultDetfExchangeOutFacet;
    IFacet private singleVaultDetfBondingFacet;
    IFacet private protocolNFTVaultFacet;
    IFacet private richirFacet;
    IFacet private uniswapV4StandardExchangeInFacet;
    IFacet private uniswapV4StandardExchangeOutFacet;
    IFacet private erc721Facet;

    IProtocolNFTVaultDFPkg private protocolNFTVaultPkg;
    IRICHIRDFPkg private richirPkg;
    IUniswapV4StandardExchangeDFPkg private wethRichVaultPkg;
    ISingleVaultDetfDFPkg private protocolDetfPkg;

    IPoolManager private poolManager;
    SingleVaultDetfUniswapV4LiquiditySeeder private liquiditySeeder;

    address private demoWeth;
    address private richToken;
    address private protocolDetf;
    address private protocolNftVault;
    address private richirToken;
    address private reservePool;
    address private chirWethVault;
    address private richChirVault;

    function run() external virtual {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 16: Deploy Single Vault DETF (CHIR) - Public Sepolia");

        vm.startBroadcast();
        _deployWeightedPool8020FactoryIfNeeded();
        _deployFacets();
        _deployUniswapV4PoolInfra();
        _seedWethRichPool();
        _deployPkgs();
        _deployProtocolDetf();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress("01_factories.json", "create3Factory"));
        diamondPackageFactory = IDiamondPackageCallBackFactory(_readAddress("01_factories.json", "diamondPackageFactory"));
        vaultRegistry = IVaultRegistryDeployment(_readAddress("03_core_proxies.json", "vaultRegistry"));
        feeOracle = IVaultFeeOracleQuery(_readAddress("03_core_proxies.json", "vaultFeeOracle"));

        erc20Facet = IFacet(_readAddress("02_shared_facets.json", "erc20Facet"));
        erc2612Facet = IFacet(_readAddress("02_shared_facets.json", "erc2612Facet"));
        erc5267Facet = IFacet(_readAddress("02_shared_facets.json", "erc5267Facet"));
        erc4626BasicVaultFacet = IFacet(_readAddress("02_shared_facets.json", "erc4626BasicVaultFacet"));
        erc4626StandardVaultFacet = IFacet(_readAddress("02_shared_facets.json", "erc4626StandardVaultFacet"));
        operableFacet = IFacet(_readAddress("02_shared_facets.json", "operableFacet"));

        balancerV3StandardExchangeRouter = IBalancerV3StandardExchangeRouterProxy(
            _readAddress("04_balancer_v3.json", "balancerV3StandardExchangeRouter")
        );
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(_readAddress("04_balancer_v3.json", "rateProviderPkg"));
        erc20MinterFacade = IERC20MinterFacade(_readAddress("07_test_tokens.json", "erc20MinterFacade"));
        demoWeth = _readAddress("07_test_tokens.json", "demoWeth");
        richToken = _readAddress("07_test_tokens.json", "richToken");

        (address weightedPoolFactoryAddr, bool wpExists) = _readAddressSafe("15_seigniorage_detfs.json", "weightedPool8020Factory");
        if (wpExists && weightedPoolFactoryAddr != address(0)) {
            weightedPool8020Factory = IWeightedPool8020Factory(weightedPoolFactoryAddr);
        }
    }

    function _deployWeightedPool8020FactoryIfNeeded() internal {
        if (address(weightedPool8020Factory) != address(0)) {
            return;
        }

        weightedPool8020Factory = IWeightedPool8020Factory(
            create3Factory.create3WithArgs(
                type(WeightedPool8020Factory).creationCode,
                abi.encode(balancerV3Vault, uint32(365 days), "Factory v1", "8020Pool v1"),
                keccak256("SingleVaultDetfWeightedPool8020Factory")
            )
        );
    }

    function _deployFacets() internal {
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();
        singleVaultDetfExchangeInFacet = create3Factory.deploySingleVaultDetfExchangeInFacet();
        singleVaultDetfExchangeInQueryFacet = create3Factory.deploySingleVaultDetfExchangeInQueryFacet();
        singleVaultDetfExchangeOutFacet = create3Factory.deploySingleVaultDetfExchangeOutFacet();
        singleVaultDetfBondingFacet = create3Factory.deploySingleVaultDetfBondingFacet();
        protocolNFTVaultFacet = BaseProtocolDETF_Facet_FactoryService.deployProtocolNFTVaultFacet(create3Factory);
        richirFacet = BaseProtocolDETF_Facet_FactoryService.deployRICHIRFacet(create3Factory);
        uniswapV4StandardExchangeInFacet = create3Factory.deployUniswapV4StandardExchangeInFacet();
        uniswapV4StandardExchangeOutFacet = create3Factory.deployUniswapV4StandardExchangeOutFacet();
        erc721Facet = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("SingleVaultDetf_ERC721Facet"))
        );
    }

    function _deployUniswapV4PoolInfra() internal {
        poolManager = IPoolManager(
            create3Factory.create3WithArgs(
                type(PoolManager).creationCode,
                abi.encode(owner),
                keccak256("SingleVaultDetfPoolManager")
            )
        );
        liquiditySeeder = SingleVaultDetfUniswapV4LiquiditySeeder(
            create3Factory.create3WithArgs(
                type(SingleVaultDetfUniswapV4LiquiditySeeder).creationCode,
                abi.encode(poolManager),
                keccak256("SingleVaultDetfLiquiditySeeder")
            )
        );
    }

    function _seedWethRichPool() internal {
        erc20MinterFacade.mintToken(IERC20MintBurn(demoWeth), INITIAL_DEMO_WETH_DEPOSIT, owner);

        PoolKey memory poolKey = _buildPoolKey();
        PoolManager(address(poolManager)).initialize(poolKey, TickMath.getSqrtPriceAtTick(0));

        IERC20(demoWeth).transfer(address(liquiditySeeder), INITIAL_DEMO_WETH_DEPOSIT);
        IERC20(richToken).transfer(address(liquiditySeeder), INITIAL_RICH_DEPOSIT);

        liquiditySeeder.addLiquidity(
            poolKey,
            -int24(WETH_RICH_TICK_SPACING),
            int24(WETH_RICH_TICK_SPACING),
            LiquidityAmounts.getLiquidityForAmounts(
                TickMath.getSqrtPriceAtTick(0),
                TickMath.getSqrtPriceAtTick(-int24(WETH_RICH_TICK_SPACING)),
                TickMath.getSqrtPriceAtTick(int24(WETH_RICH_TICK_SPACING)),
                INITIAL_DEMO_WETH_DEPOSIT,
                INITIAL_RICH_DEPOSIT
            )
        );
    }

    function _deployPkgs() internal {
        protocolNFTVaultPkg = BaseProtocolDETF_Pkg_FactoryService.deployProtocolNFTVaultDFPkg(
            vaultRegistry,
            BaseProtocolDETF_Component_FactoryService.buildProtocolNFTVaultPkgInit(
                erc721Facet,
                erc4626BasicVaultFacet,
                erc4626StandardVaultFacet,
                protocolNFTVaultFacet,
                feeOracle,
                vaultRegistry
            )
        );

        richirPkg = BaseProtocolDETF_Pkg_FactoryService.deployRICHIRDFPkg(
            create3Factory,
            BaseProtocolDETF_Component_FactoryService.buildRICHIRPkgInit(
                erc20Facet,
                erc5267Facet,
                erc2612Facet,
                richirFacet,
                diamondPackageFactory
            )
        );

        wethRichVaultPkg = UniswapV4_Component_FactoryService.deployUniswapV4StandardExchangeDFPkgFromVaultRegistry(
            vaultRegistry,
            UniswapV4_Component_FactoryService.buildArgsUniswapV4StandardExchangePkgInit(
                erc20Facet,
                erc5267Facet,
                erc2612Facet,
                multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet,
                uniswapV4StandardExchangeInFacet,
                uniswapV4StandardExchangeOutFacet,
                feeOracle,
                vaultRegistry,
                permit2,
                poolManager
            )
        );

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
                    exchangeOutFacet: singleVaultDetfExchangeOutFacet,
                    bondingFacet: singleVaultDetfBondingFacet,
                    operableFacet: operableFacet
                }),
                SingleVaultDetf_Component_FactoryService.SingleVaultDetfInfra({
                    feeOracle: feeOracle,
                    vaultRegistryDeployment: vaultRegistry,
                    permit2: permit2,
                    wethToken: IERC20(demoWeth),
                    balancerV3Vault: balancerV3Vault,
                    balancerV3PrepayRouter: balancerV3StandardExchangeRouter,
                    weightedPool8020Factory: weightedPool8020Factory,
                    bridgeConfig: _bridgePkgConfig(),
                    wethRichVaultPkg: wethRichVaultPkg,
                    protocolNFTVaultPkg: protocolNFTVaultPkg,
                    richirPkg: richirPkg,
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
                    "Protocol DETF CHIR",
                    "CHIR",
                    IERC20(richToken),
                    INITIAL_RICH_DEPOSIT,
                    INITIAL_DEMO_WETH_DEPOSIT,
                    _buildPoolKey(),
                    WETH_RICH_WIDTH_MULTIPLIER
                )
            )
        );

        IProtocolDETF detf = IProtocolDETF(protocolDetf);
        protocolNftVault = address(detf.protocolNFTVault());
        richirToken = address(detf.richirToken());
        reservePool = detf.reservePool();
        chirWethVault = address(ISingleVaultDetf(protocolDetf).wethRichVault());
        richChirVault = address(ISingleVaultDetf(protocolDetf).wethRichVault());
    }

    function _buildPoolKey() internal view returns (PoolKey memory poolKey_) {
        (address token0, address token1) = demoWeth < richToken ? (demoWeth, richToken) : (richToken, demoWeth);

        poolKey_ = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: WETH_RICH_FEE,
            tickSpacing: WETH_RICH_TICK_SPACING,
            hooks: IHooks(address(0))
        });
    }

    function _bridgePkgConfig() internal view returns (ProtocolDETFSuperchainBridgeRepo.BridgeConfig memory bridgeConfig) {
        string memory remoteOutDir = _requiredEnvString("REMOTE_OUT_DIR");
        address bridgeRegistry = _readAddress("24_superchain_bridge.json", "bridgeTokenRegistry");
        address localRelayer = _readAddress("24_superchain_bridge.json", "tokenTransferRelayer");
        address peerRelayer = _readAddressFromDir(remoteOutDir, "24_superchain_bridge.json", "tokenTransferRelayer");

        bridgeConfig = ProtocolDETFSuperchainBridgeRepo.BridgeConfig({
            bridgeTokenRegistry: ISuperChainBridgeTokenRegistry(bridgeRegistry),
            standardBridge: IStandardBridge(payable(ETHEREUM_SEPOLIA.BASE_L1_STANDARD_BRIDGE)),
            messenger: ICrossDomainMessenger(ETHEREUM_SEPOLIA.BASE_L1_CROSS_DOMAIN_MESSENGER),
            localRelayer: localRelayer,
            peerRelayer: peerRelayer
        });
    }

    function _requiredEnvString(string memory key) internal view returns (string memory value) {
        value = vm.envString(key);
        require(bytes(value).length > 0, "Missing required env string");
    }

    function _readAddressFromDir(string memory outDir, string memory file, string memory key) internal view returns (address) {
        string memory json = vm.readFile(string.concat(outDir, "/", file));
        return vm.parseJsonAddress(json, string.concat(".", key));
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("", "demoWeth", demoWeth);
        json = vm.serializeAddress("", "richToken", richToken);
        json = vm.serializeAddress("", "protocolDetfPkg", address(protocolDetfPkg));
        json = vm.serializeAddress("", "protocolNFTVaultPkg", address(protocolNFTVaultPkg));
        json = vm.serializeAddress("", "richirPkg", address(richirPkg));
        json = vm.serializeAddress("", "wethRichVaultPkg", address(wethRichVaultPkg));
        json = vm.serializeAddress("", "poolManager", address(poolManager));
        json = vm.serializeAddress("", "protocolDetf", protocolDetf);
        json = vm.serializeAddress("", "protocolNftVault", protocolNftVault);
        json = vm.serializeAddress("", "richirToken", richirToken);
        json = vm.serializeAddress("", "reservePool", reservePool);
        json = vm.serializeAddress("", "chirWethVault", chirWethVault);
        json = vm.serializeAddress("", "richChirVault", richChirVault);
        _writeJson(json, "16_protocol_detf.json");
    }

    function _logResults() internal view {
        _logAddress("DemoWETH:", demoWeth);
        _logAddress("RICH:", richToken);
        _logAddress("Single Vault DETF (CHIR):", protocolDetf);
        _logAddress("Protocol NFT Vault:", protocolNftVault);
        _logAddress("RICHIR:", richirToken);
        _logAddress("Reserve Pool:", reservePool);
        _logComplete("Stage 16 (Public Sepolia - DemoWETH)");
    }
}
