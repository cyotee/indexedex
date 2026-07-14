// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { betterconsole as console } from "@crane/contracts/utils/vm/foundry/tools/betterconsole.sol";

import {DeploymentBase} from "./DeploymentBase.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/interfaces/ISuperChainBridgeTokenRegistry.sol";
import {ETHEREUM_SEPOLIA} from "@crane/contracts/constants/networks/ETHEREUM_SEPOLIA.sol";

import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";
import {IWeightedPool8020Factory} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {WeightedPool8020Factory} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPool8020Factory.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IBalancerV3StandardExchangeRouterProxy} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";

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
    SingleVaultDetfUniswapV4LiquiditySeeder
} from "../shared/SingleVaultDetfUniswapV4LiquiditySeeder.sol";

contract Script_16_DeployProtocolDETF is DeploymentBase {
    using BetterEfficientHashLib for bytes;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using UniswapV4_Component_FactoryService for ICreate3FactoryProxy;
    using SingleVaultDetf_Facet_FactoryService for ICreate3FactoryProxy;
    using DetfFacetFactoryService for ICreate3FactoryProxy;

    uint256 private constant RICH_TOTAL_SUPPLY = 1_000_000_000e18;
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
    IFacet private multiAssetBasicVaultFacet;
    IFacet private multiAssetStandardVaultFacet;

    IBalancerV3StandardExchangeRouterProxy private balancerV3StandardExchangeRouter;
    IStandardExchangeRateProviderDFPkg private rateProviderPkg;
    IWeightedPool8020Factory private weightedPool8020Factory;

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

    IERC20PermitDFPkg private pairTokenPkg;
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
    address private underlyingVault;

    function run() external virtual {
        _runProtocolDetfStage16();
    }

    function _runProtocolDetfStage16() internal {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 16: Deploy Single Vault DETF (CHIR)");

        vm.startBroadcast();
        _deployWeightedPool8020FactoryIfNeeded();
        _deployFacets();
        _deployRichToken();
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

        (address weightedPoolFactoryAddr, bool weightedPoolFactoryExists) =
            _readAddressSafe("15_seigniorage_detfs.json", "weightedPool8020Factory");
        if (weightedPoolFactoryExists && weightedPoolFactoryAddr != address(0)) {
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
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("SingleVaultDetf_ERC721Facet"))
        );
    }

    function _deployRichToken() internal {
        pairTokenPkg = IERC20PermitDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitDFPkg).creationCode,
                    abi.encode(
                        IERC20PermitDFPkg.PkgInit({
                            erc20Facet: erc20Facet,
                            erc5267Facet: erc5267Facet,
                            erc2612Facet: erc2612Facet
                        })
                    ),
                    abi.encode(type(ERC20PermitDFPkg).name, "SingleVaultDetfRich")._hash()
                )
            )
        );

        pairToken = diamondPackageFactory.deploy(
            IDiamondFactoryPackage(address(pairTokenPkg)),
            abi.encode(
                IERC20PermitDFPkg.PkgArgs({
                    name: "Rich Token",
                    symbol: "RICH",
                    decimals: 18,
                    totalSupply: RICH_TOTAL_SUPPLY,
                    recipient: owner,
                    optionalSalt: keccak256("SingleVaultDetfRichToken")
                })
            )
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
        detfNFTVaultPkg = DetfPkgFactoryService.deployDETFNFTVaultDFPkg(
            vaultRegistry,
            DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
                erc721Facet,
                erc4626BasicVaultFacet,
                erc4626StandardVaultFacet,
                detfNFTVaultFacet,
                feeOracle,
                vaultRegistry
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

        DetfSuperchainBridgeRepo.BridgeConfig memory bridgeConfig_ = _bridgePkgConfigOrEmpty();
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
                    bridgeTokenRegistry: bridgeConfig_.bridgeTokenRegistry,
                    standardBridge: bridgeConfig_.standardBridge,
                    messenger: bridgeConfig_.messenger,
                    localRelayer: bridgeConfig_.localRelayer,
                    peerRelayer: bridgeConfig_.peerRelayer,
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
                    "Protocol DETF CHIR",
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
        underlyingVault = address(ISingleVaultDetf(protocolDetf).underlyingVault());
    }

    function _buildPoolKey() internal view returns (PoolKey memory poolKey_) {
        (address token0, address token1) = address(weth) < pairToken ? (address(weth), pairToken) : (pairToken, address(weth));

        poolKey_ = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: WETH_RICH_FEE,
            tickSpacing: WETH_RICH_TICK_SPACING,
            hooks: IHooks(address(0))
        });
    }

    function _emptyBridgeConfig() internal pure returns (DetfSuperchainBridgeRepo.BridgeConfig memory config_) {
        config_ = DetfSuperchainBridgeRepo.BridgeConfig({
            bridgeTokenRegistry: ISuperChainBridgeTokenRegistry(address(0)),
            standardBridge: IStandardBridge(payable(address(0))),
            messenger: ICrossDomainMessenger(address(0)),
            localRelayer: address(0),
            peerRelayer: address(0)
        });
    }

    function _bridgePkgConfigOrEmpty() internal view returns (DetfSuperchainBridgeRepo.BridgeConfig memory bridgeConfig_) {
        string memory remoteOutDir;
        try vm.envString("REMOTE_OUT_DIR") returns (string memory envRemoteOutDir) {
            if (bytes(envRemoteOutDir).length == 0) {
                return _emptyBridgeConfig();
            }
            remoteOutDir = envRemoteOutDir;
        } catch {
            return _emptyBridgeConfig();
        }

        string memory localBridgeJson;
        try vm.readFile(string.concat(_outDir(), "/24_superchain_bridge.json")) returns (string memory json) {
            localBridgeJson = json;
        } catch {
            return _emptyBridgeConfig();
        }

        address bridgeRegistry = vm.parseJsonAddress(localBridgeJson, ".bridgeTokenRegistry");
        address localRelayer = vm.parseJsonAddress(localBridgeJson, ".tokenTransferRelayer");
        address peerRelayer = _readAddressFromDir(remoteOutDir, "24_superchain_bridge.json", "tokenTransferRelayer");

        bridgeConfig_ = DetfSuperchainBridgeRepo.BridgeConfig({
            bridgeTokenRegistry: ISuperChainBridgeTokenRegistry(bridgeRegistry),
            standardBridge: IStandardBridge(payable(ETHEREUM_SEPOLIA.BASE_L1_STANDARD_BRIDGE)),
            messenger: ICrossDomainMessenger(ETHEREUM_SEPOLIA.BASE_L1_CROSS_DOMAIN_MESSENGER),
            localRelayer: localRelayer,
            peerRelayer: peerRelayer
        });
    }

    function _readAddressFromDir(string memory outDir, string memory file, string memory key) internal view returns (address) {
        string memory json = vm.readFile(string.concat(outDir, "/", file));
        return vm.parseJsonAddress(json, string.concat(".", key));
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("", "pairToken", pairToken);
        json = vm.serializeAddress("", "pairTokenPkg", address(pairTokenPkg));
        json = vm.serializeAddress("", "protocolDetfPkg", address(protocolDetfPkg));
        json = vm.serializeAddress("", "detfNFTVaultPkg", address(detfNFTVaultPkg));
        json = vm.serializeAddress("", "rebasingClaimTokenPkg", address(rebasingClaimTokenPkg));
        json = vm.serializeAddress("", "underlyingVaultPkg", address(underlyingVaultPkg));
        json = vm.serializeAddress("", "poolManager", address(poolManager));
        json = vm.serializeAddress("", "protocolDetf", protocolDetf);
        json = vm.serializeAddress("", "protocolNftVault", protocolNftVault);
        json = vm.serializeAddress("", "rebasingClaimToken", rebasingClaimToken);
        json = vm.serializeAddress("", "reservePool", reservePool);
        json = vm.serializeAddress("", "underlyingVault", underlyingVault);
        json = vm.serializeAddress("", "underlyingVault", underlyingVault);
        _writeJson(json, "16_protocol_detf.json");
    }

    function _logResults() internal view {
        _logAddress("RICH:", pairToken);
        _logAddress("Single Vault DETF (CHIR):", protocolDetf);
        _logAddress("Protocol NFT Vault:", protocolNftVault);
        _logAddress("RICHIR:", rebasingClaimToken);
        _logAddress("Reserve Pool:", reservePool);
        _logAddress("WETH/RICH Vault:", underlyingVault);
        _logComplete("Stage 16");
    }
}
