// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.30;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {LocalTestingDeploymentBase} from "../shared/LocalTestingDeploymentBase.sol";
import {ManifestEntry} from "../shared/ManifestEntry.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {CREATE3} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/solmate/CREATE3.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";

import {IWETH} from "@crane/contracts/external/balancer/v3/interfaces/contracts/solidity-utils/misc/IWETH.sol";
import {IWETH as ICraneWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {IAuthorizer} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IAuthorizer.sol";
import {IProtocolFeeController} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IProtocolFeeController.sol";

import {IBalancerV3VaultDFPkg} from "@crane/contracts/protocols/dexes/balancer/v3/vault/diamond/BalancerV3VaultDFPkg.sol";
import {IBalancerV3RouterDFPkg} from "@crane/contracts/protocols/dexes/balancer/v3/router/diamond/BalancerV3RouterDFPkg.sol";

import {IBalancerV3StandardExchangeRouterDFPkg} from "contracts/protocols/dexes/balancer/v3/routers/IBalancerV3StandardExchangeRouterDFPkg.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    BalancerV3StandardExchangeRouter_FactoryService
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_FactoryService.sol";

/// @title Script_03_DeployBaseProtocols
/// @notice Deploys local WETH, local Permit2, local Uniswap V2 core, and Balancer V3 core for local testing
contract Script_03_DeployBaseProtocols is LocalTestingDeploymentBase {
    using BetterEfficientHashLib for bytes;
    using BalancerV3StandardExchangeRouter_FactoryService for ICreate3FactoryProxy;
    using BalancerV3StandardExchangeRouter_FactoryService for IDiamondPackageCallBackFactory;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant ARTIFACT_FILE = "03_protocols_base.json";
    string internal constant ROUTER_VERSION = "BalancerV3Router v1";

    uint32 internal constant PAUSE_WINDOW_DURATION = 90 days;
    uint32 internal constant BUFFER_PERIOD_DURATION = 30 days;
    uint256 internal constant MIN_TRADE_AMOUNT = 0;
    uint256 internal constant MIN_WRAP_AMOUNT = 1;

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;

    address private localWeth;
    address private localPermit2;
    address private uniswapV2Factory;
    address private uniswapV2Router;

    address private balancerAuthorizer;
    address private balancerProtocolFeeController;
    address private balancerVaultAdmin;
    address private balancerVaultExtension;
    address private balancerVault;
    address private balancerRouter;
    address private balancerBatchRouter;
    address private balancerBufferRouter;
    address private balancerCompositeLiquidityRouter;
    IBalancerV3StandardExchangeRouterProxy private balancerV3StandardExchangeRouter;

    IBalancerV3VaultDFPkg private vaultPkg;
    IBalancerV3RouterDFPkg private routerPkg;

    function run() external {
        _loadConfig();
        _loadCraneFoundation();

        _logHeader("Stage 03: Deploy Base Protocols");

        if (_loadExistingProtocols()) {
            _exportJson();
            _exportFragments();
            _logResults();
            return;
        }

        vm.startBroadcast();

        _deployLocalTokensAndRouters();
        _deployBalancerCore();

        vm.stopBroadcast();

        _exportJson();
        _exportFragments();
        _logResults();
    }

    function _exportFragments() internal {
        if (localWeth == address(0)) return;

        // wrapUnwrap tag drives the WETH (Wrap/Unwrap) entry in the Select Pool menu.
        string[] memory tags = new string[](2);
        tags[0] = "weth";
        tags[1] = "wrapUnwrap";

        ManifestEntry memory entry = ManifestEntry({
            chainId: block.chainid,
            addr: localWeth,
            name: "Wrapped Ether",
            symbol: "WETH9",
            decimals: 18,
            tags: tags
        });
        _writeManifestEntry("tokens", "weth9", entry);
    }

    function _loadCraneFoundation() internal {
        address create3FactoryAddr = _readAddress(CRANE_FOUNDATION_FILE, "create3Factory");
        address diamondPackageFactoryAddr = _readAddress(CRANE_FOUNDATION_FILE, "diamondPackageFactory");

        require(create3FactoryAddr != address(0), "Create3Factory not found - run Script_01 first");
        require(diamondPackageFactoryAddr != address(0), "DiamondPackageFactory not found - run Script_01 first");

        create3Factory = ICreate3FactoryProxy(create3FactoryAddr);
        diamondPackageFactory = IDiamondPackageCallBackFactory(diamondPackageFactoryAddr);
    }

    function _loadExistingProtocols() internal returns (bool) {
        (address localWethAddr, bool hasLocalWeth) = _readAddressSafe(ARTIFACT_FILE, "weth");
        (address localPermit2Addr, bool hasLocalPermit2) = _readAddressSafe(ARTIFACT_FILE, "permit2");
        (address uniswapV2FactoryAddr, bool hasUniswapFactory) = _readAddressSafe(ARTIFACT_FILE, "uniswapV2Factory");
        (address uniswapV2RouterAddr, bool hasUniswapRouter) = _readAddressSafe(ARTIFACT_FILE, "uniswapV2Router");
        (address balancerVaultAddr, bool hasBalancerVault) = _readAddressSafe(ARTIFACT_FILE, "balancerV3Vault");
        (address balancerRouterAddr, bool hasBalancerRouter) = _readAddressSafe(ARTIFACT_FILE, "balancerV3Router");
        (address standardExchangeRouterAddr, bool hasStandardExchangeRouter) =
            _readAddressSafe(ARTIFACT_FILE, "balancerV3StandardExchangeRouter");

        bool hasRequired = hasLocalWeth && hasLocalPermit2 && hasUniswapFactory && hasUniswapRouter && hasBalancerVault
            && hasBalancerRouter && hasStandardExchangeRouter;

        if (!hasRequired) {
            return false;
        }

        if (
            localWethAddr.code.length == 0 || localPermit2Addr.code.length == 0 || uniswapV2FactoryAddr.code.length == 0
                || uniswapV2RouterAddr.code.length == 0 || balancerVaultAddr.code.length == 0
                || balancerRouterAddr.code.length == 0 || standardExchangeRouterAddr.code.length == 0
        ) {
            return false;
        }

        localWeth = localWethAddr;
        localPermit2 = localPermit2Addr;
        uniswapV2Factory = uniswapV2FactoryAddr;
        uniswapV2Router = uniswapV2RouterAddr;
        balancerVault = balancerVaultAddr;
        balancerRouter = balancerRouterAddr;
        balancerV3StandardExchangeRouter = IBalancerV3StandardExchangeRouterProxy(standardExchangeRouterAddr);

        (balancerAuthorizer, ) = _readAddressSafe(ARTIFACT_FILE, "balancerV3Authorizer");
        (balancerProtocolFeeController, ) = _readAddressSafe(ARTIFACT_FILE, "balancerV3ProtocolFeeController");
        (balancerVaultAdmin, ) = _readAddressSafe(ARTIFACT_FILE, "balancerV3VaultAdmin");
        (balancerVaultExtension, ) = _readAddressSafe(ARTIFACT_FILE, "balancerV3VaultExtension");
        (balancerBatchRouter, ) = _readAddressSafe(ARTIFACT_FILE, "balancerV3BatchRouter");
        (balancerBufferRouter, ) = _readAddressSafe(ARTIFACT_FILE, "balancerV3BufferRouter");
        (balancerCompositeLiquidityRouter, ) = _readAddressSafe(ARTIFACT_FILE, "balancerV3CompositeLiquidityRouter");

        return true;
    }

    function _deployLocalTokensAndRouters() internal {
        localWeth = _deployCreate3(ArtifactCreationCode.creationCode(create3Factory, "lib/crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol:WETH9"), _salt("LocalTestingWETH9"));
        localPermit2 = _deployCreate3(ArtifactCreationCode.creationCode(create3Factory, "BetterPermit2.sol:BetterPermit2"), _salt("LocalTestingBetterPermit2"));

        uniswapV2Factory = _deployWithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "UniV2Factory.sol:UniV2Factory"),
            abi.encode(owner),
            _salt("LocalTestingUniV2Factory")
        );

        uniswapV2Router = _deployWithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "UniV2Router02.sol:UniV2Router02"),
            abi.encode(uniswapV2Factory, localWeth),
            _salt("LocalTestingUniV2Router02")
        );
    }

    function _deployBalancerCore() internal {
        _deployVaultPackage();

        balancerAuthorizer = _deployCreate3(
            ArtifactCreationCode.creationCode(create3Factory, "lib/crane/contracts/protocols/dexes/balancer/v3/test/mocks/BasicAuthorizerMock.sol:BasicAuthorizerMock"),
            _salt("LocalTestingBalancerV3Authorizer")
        );

        balancerProtocolFeeController = address(0);

        balancerVault = vaultPkg.deployVault(
            MIN_TRADE_AMOUNT,
            MIN_WRAP_AMOUNT,
            PAUSE_WINDOW_DURATION,
            BUFFER_PERIOD_DURATION,
            IAuthorizer(balancerAuthorizer),
            IProtocolFeeController(address(0))
        );

        _deployRouterPackage();
        balancerRouter = routerPkg.deployRouter(
            IVault(payable(balancerVault)),
            IWETH(localWeth),
            IPermit2(localPermit2),
            ROUTER_VERSION
        );

        balancerBatchRouter = balancerRouter;
        balancerBufferRouter = balancerRouter;
        balancerCompositeLiquidityRouter = balancerRouter;
        balancerVaultAdmin = balancerVault;
        balancerVaultExtension = balancerVault;

        _deployBalancerStandardExchangeRouter();
    }

    function _deployBalancerStandardExchangeRouter() internal {
        IBalancerV3StandardExchangeRouterDFPkg.PkgInit memory pkgInit;
        pkgInit.senderGuardFacet = IFacet(
            create3Factory.deployFacet(
                ArtifactCreationCode.creationCode(create3Factory, "SenderGuardFacet.sol:SenderGuardFacet"),
                abi.encode("SenderGuardFacet", "LocalTesting")._hash()
            )
        );
        pkgInit.balancerV3StandardExchangeRouterExactInQueryFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterExactInQueryFacet();
        pkgInit.balancerV3StandardExchangeRouterExactInSwapFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterExactInSwapFacet();
        pkgInit.balancerV3StandardExchangeRouterExactOutQueryFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterExactOutQueryFacet();
        pkgInit.balancerV3StandardExchangeRouterExactOutSwapFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterExactOutSwapFacet();
        pkgInit.balancerV3StandardExchangeBatchRouterExactInFacet =
            create3Factory.deployBalancerV3StandardExchangeBatchRouterExactInFacet();
        pkgInit.balancerV3StandardExchangeBatchRouterExactOutFacet =
            create3Factory.deployBalancerV3StandardExchangeBatchRouterExactOutFacet();
        pkgInit.balancerV3StandardExchangeRouterPrepayFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterPrepayFacet();
        pkgInit.balancerV3StandardExchangeRouterPrepayHooksFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterPrepayHooksFacet();
        pkgInit.balancerV3StandardExchangePermit2WitnessFacet =
            create3Factory.deployBalancerV3StandardExchangeRouterPermit2WitnessFacet();
        pkgInit.balancerV3Vault = IVault(payable(balancerVault));
        pkgInit.permit2 = IPermit2(localPermit2);
        pkgInit.weth = ICraneWETH(localWeth);

        IBalancerV3StandardExchangeRouterDFPkg standardExchangeRouterPkg =
            create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(pkgInit);
        balancerV3StandardExchangeRouter =
            diamondPackageFactory.deployBalancerV3StandardExchangeRouter(standardExchangeRouterPkg);
    }

    function _salt(string memory name) internal pure returns (bytes32) {
        return abi.encode(name)._hash();
    }

    function _predictAddress(bytes32 salt) internal view returns (address) {
        return CREATE3.getDeployed(salt, address(create3Factory));
    }

    function _deployCreate3(bytes memory creationCode, bytes32 salt) internal returns (address deployed) {
        deployed = _predictAddress(salt);
        if (deployed.code.length == 0) {
            deployed = create3Factory.create3(creationCode, salt);
        }
    }

    function _deployWithArgs(bytes memory creationCode, bytes memory constructorArgs, bytes32 salt)
        internal
        returns (address deployed)
    {
        deployed = _predictAddress(salt);
        if (deployed.code.length == 0) {
            deployed = create3Factory.create3(bytes.concat(creationCode, constructorArgs), salt);
        }
    }

    function _deployFacet(bytes memory creationCode, string memory name) internal returns (IFacet facet) {
        address predicted = _predictAddress(_salt(name));
        if (predicted.code.length > 0) {
            return IFacet(predicted);
        }

        facet = IFacet(create3Factory.deployFacet(creationCode, _salt(name)));
    }

    function _deployVaultPackage() internal {
        vaultPkg = IBalancerV3VaultDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    ArtifactCreationCode.creationCode(create3Factory, "BalancerV3VaultDFPkg.sol:BalancerV3VaultDFPkg"),
                    abi.encode(
                        IBalancerV3VaultDFPkg.PkgInit({
                            vaultTransientFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "VaultTransientFacet.sol:VaultTransientFacet"), "VaultTransientFacet"),
                            vaultSwapFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "VaultSwapFacet.sol:VaultSwapFacet"), "VaultSwapFacet"),
                            vaultLiquidityFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "VaultLiquidityFacet.sol:VaultLiquidityFacet"), "VaultLiquidityFacet"),
                            vaultBufferFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "VaultBufferFacet.sol:VaultBufferFacet"), "VaultBufferFacet"),
                            vaultPoolTokenFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "VaultPoolTokenFacet.sol:VaultPoolTokenFacet"), "VaultPoolTokenFacet"),
                            vaultQueryFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "VaultQueryFacet.sol:VaultQueryFacet"), "VaultQueryFacet"),
                            vaultRegistrationFacet: _deployFacet(
                                ArtifactCreationCode.creationCode(create3Factory, "VaultRegistrationFacet.sol:VaultRegistrationFacet"), "VaultRegistrationFacet"
                            ),
                            vaultAdminFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "VaultAdminFacet.sol:VaultAdminFacet"), "VaultAdminFacet"),
                            vaultRecoveryFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "VaultRecoveryFacet.sol:VaultRecoveryFacet"), "VaultRecoveryFacet"),
                            diamondFactory: diamondPackageFactory
                        })
                    ),
                    _salt("BalancerV3VaultDFPkg")
                )
            )
        );
    }

    function _deployRouterPackage() internal {
        routerPkg = IBalancerV3RouterDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    ArtifactCreationCode.creationCode(create3Factory, "BalancerV3RouterDFPkg.sol:BalancerV3RouterDFPkg"),
                    abi.encode(
                        IBalancerV3RouterDFPkg.PkgInit({
                            routerSwapFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "RouterSwapFacet.sol:RouterSwapFacet"), "RouterSwapFacet"),
                            routerAddLiquidityFacet: _deployFacet(
                                ArtifactCreationCode.creationCode(create3Factory, "RouterAddLiquidityFacet.sol:RouterAddLiquidityFacet"), "RouterAddLiquidityFacet"
                            ),
                            routerRemoveLiquidityFacet: _deployFacet(
                                ArtifactCreationCode.creationCode(create3Factory, "RouterRemoveLiquidityFacet.sol:RouterRemoveLiquidityFacet"), "RouterRemoveLiquidityFacet"
                            ),
                            routerInitializeFacet: _deployFacet(
                                ArtifactCreationCode.creationCode(create3Factory, "RouterInitializeFacet.sol:RouterInitializeFacet"), "RouterInitializeFacet"
                            ),
                            routerCommonFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "RouterCommonFacet.sol:RouterCommonFacet"), "RouterCommonFacet"),
                            batchSwapFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "BatchSwapFacet.sol:BatchSwapFacet"), "BatchSwapFacet"),
                            bufferRouterFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "BufferRouterFacet.sol:BufferRouterFacet"), "BufferRouterFacet"),
                            compositeLiquidityERC4626Facet: _deployFacet(
                                ArtifactCreationCode.creationCode(create3Factory, "CompositeLiquidityERC4626Facet.sol:CompositeLiquidityERC4626Facet"),
                                "CompositeLiquidityERC4626Facet"
                            ),
                            compositeLiquidityNestedFacet: _deployFacet(
                                ArtifactCreationCode.creationCode(create3Factory, "CompositeLiquidityNestedFacet.sol:CompositeLiquidityNestedFacet"),
                                "CompositeLiquidityNestedFacet"
                            ),
                            diamondFactory: diamondPackageFactory
                        })
                    ),
                    _salt("BalancerV3RouterDFPkg")
                )
            )
        );
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("protocolsBase", "weth", localWeth);
        json = vm.serializeAddress("protocolsBase", "permit2", localPermit2);
        json = vm.serializeAddress("protocolsBase", "uniswapV2Factory", uniswapV2Factory);
        json = vm.serializeAddress("protocolsBase", "uniswapV2Router", uniswapV2Router);
        json = vm.serializeAddress("protocolsBase", "balancerV3Authorizer", balancerAuthorizer);
        json = vm.serializeAddress("protocolsBase", "balancerV3ProtocolFeeController", balancerProtocolFeeController);
        json = vm.serializeAddress("protocolsBase", "balancerV3VaultAdmin", balancerVaultAdmin);
        json = vm.serializeAddress("protocolsBase", "balancerV3VaultExtension", balancerVaultExtension);
        json = vm.serializeAddress("protocolsBase", "balancerV3Vault", balancerVault);
        json = vm.serializeAddress("protocolsBase", "balancerV3Router", balancerRouter);
        json = vm.serializeAddress("protocolsBase", "balancerV3BatchRouter", balancerBatchRouter);
        json = vm.serializeAddress("protocolsBase", "balancerV3BufferRouter", balancerBufferRouter);
        json = vm.serializeAddress("protocolsBase", "balancerV3CompositeLiquidityRouter", balancerCompositeLiquidityRouter);
        json = vm.serializeAddress("protocolsBase", "balancerV3StandardExchangeRouter", address(balancerV3StandardExchangeRouter));
        json = vm.serializeAddress("protocolsBase", "owner", owner);
        json = vm.serializeAddress("protocolsBase", "deployer", deployer);
        json = vm.serializeUint("protocolsBase", "chainId", block.chainid);
        json = vm.serializeString("protocolsBase", "networkProfile", _networkProfile());
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logString("Artifact:", ARTIFACT_FILE);
        _logAddress("Local WETH:", localWeth);
        _logAddress("Local Permit2:", localPermit2);
        _logAddress("UniV2 Factory:", uniswapV2Factory);
        _logAddress("UniV2 Router:", uniswapV2Router);
        _logAddress("Balancer Authorizer:", balancerAuthorizer);
        _logAddress("Balancer Vault:", balancerVault);
        _logAddress("Balancer Router:", balancerRouter);
        _logAddress("Balancer Standard Exchange Router:", address(balancerV3StandardExchangeRouter));
        _logUint("ChainId:", block.chainid);
        _logComplete("Stage 03");
    }
}