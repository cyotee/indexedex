// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.30;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {DeploymentBase} from "../../anvil_base_main/DeploymentBase.sol";

import {BASE_SEPOLIA} from "@crane/contracts/constants/networks/BASE_SEPOLIA.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/external/balancer/v3/interfaces/contracts/solidity-utils/misc/IWETH.sol";
import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {IAuthorizer} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IAuthorizer.sol";
import {
    IProtocolFeeController
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IProtocolFeeController.sol";
import {CREATE3} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/solmate/CREATE3.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IBalancerV3VaultDFPkg} from "@crane/contracts/protocols/dexes/balancer/v3/vault/diamond/BalancerV3VaultDFPkg.sol";
import {IBalancerV3RouterDFPkg} from "@crane/contracts/protocols/dexes/balancer/v3/router/diamond/BalancerV3RouterDFPkg.sol";

contract Script_03B_DeployBalancerV3Core is DeploymentBase {
    using BetterEfficientHashLib for bytes;

    string internal constant ROUTER_VERSION = "BalancerV3Router v1";
    uint32 internal constant PAUSE_WINDOW_DURATION = 90 days;
    uint32 internal constant BUFFER_PERIOD_DURATION = 30 days;
    uint256 internal constant MIN_TRADE_AMOUNT = 0;
    uint256 internal constant MIN_WRAP_AMOUNT = 1;
    uint256 internal constant PROTOCOL_SWAP_FEE_PERCENTAGE = 0;
    uint256 internal constant PROTOCOL_YIELD_FEE_PERCENTAGE = 0;

    string internal constant OUTPUT_FILE = "03b_balancer_v3_core.json";

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;

    address private balancerAuthorizer;
    address private balancerProtocolFeeController;
    address private balancerVaultAdmin;
    address private balancerVaultExtension;
    address private balancerVault;
    address private balancerRouter;
    address private balancerBatchRouter;
    address private balancerBufferRouter;
    address private balancerCompositeLiquidityRouter;

    IBalancerV3VaultDFPkg private vaultPkg;
    IBalancerV3RouterDFPkg private routerPkg;

    function run() external {
        _loadConfig();

        create3Factory = ICreate3FactoryProxy(_readAddress("01_factories.json", "create3Factory"));
        diamondPackageFactory = IDiamondPackageCallBackFactory(_readAddress("01_factories.json", "diamondPackageFactory"));
        require(address(create3Factory) != address(0), "Create3Factory not found");
        require(address(diamondPackageFactory) != address(0), "DiamondPackageFactory not found");

        _logHeader("Base Stage 3B: Deploy Balancer V3 Core");

        vm.startBroadcast();
        _deployCore();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _deployCore() internal {
        IWETH weth_ = IWETH(BASE_SEPOLIA.WETH9);
        IPermit2 permit2_ = IPermit2(BASE_SEPOLIA.PERMIT2);

        require(address(weth_).code.length > 0, "Base Sepolia WETH9 missing");
        require(address(permit2_).code.length > 0, "Base Sepolia Permit2 missing");

        _deployVaultPackage();

        balancerAuthorizer = _deployCreate3(
            ArtifactCreationCode.creationCode(create3Factory, "lib/crane/contracts/protocols/dexes/balancer/v3/test/mocks/BasicAuthorizerMock.sol:BasicAuthorizerMock"),
            _salt("BaseSepoliaBalancerV3Authorizer")
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
        balancerRouter = routerPkg.deployRouter(IVault(payable(balancerVault)), weth_, permit2_, ROUTER_VERSION);
        balancerBatchRouter = balancerRouter;
        balancerBufferRouter = balancerRouter;
        balancerCompositeLiquidityRouter = balancerRouter;
        balancerVaultAdmin = balancerVault;
        balancerVaultExtension = balancerVault;
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
                            vaultTransientFacet: _deployFacet(
                                ArtifactCreationCode.creationCode(create3Factory, "VaultTransientFacet.sol:VaultTransientFacet"), "VaultTransientFacet"
                            ),
                            vaultSwapFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "VaultSwapFacet.sol:VaultSwapFacet"), "VaultSwapFacet"),
                            vaultLiquidityFacet: _deployFacet(
                                ArtifactCreationCode.creationCode(create3Factory, "VaultLiquidityFacet.sol:VaultLiquidityFacet"), "VaultLiquidityFacet"
                            ),
                            vaultBufferFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "VaultBufferFacet.sol:VaultBufferFacet"), "VaultBufferFacet"),
                            vaultPoolTokenFacet: _deployFacet(
                                ArtifactCreationCode.creationCode(create3Factory, "VaultPoolTokenFacet.sol:VaultPoolTokenFacet"), "VaultPoolTokenFacet"
                            ),
                            vaultQueryFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "VaultQueryFacet.sol:VaultQueryFacet"), "VaultQueryFacet"),
                            vaultRegistrationFacet: _deployFacet(
                                ArtifactCreationCode.creationCode(create3Factory, "VaultRegistrationFacet.sol:VaultRegistrationFacet"), "VaultRegistrationFacet"
                            ),
                            vaultAdminFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "VaultAdminFacet.sol:VaultAdminFacet"), "VaultAdminFacet"),
                            vaultRecoveryFacet: _deployFacet(
                                ArtifactCreationCode.creationCode(create3Factory, "VaultRecoveryFacet.sol:VaultRecoveryFacet"), "VaultRecoveryFacet"
                            ),
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
                            routerCommonFacet: _deployFacet(
                                ArtifactCreationCode.creationCode(create3Factory, "RouterCommonFacet.sol:RouterCommonFacet"), "RouterCommonFacet"
                            ),
                            batchSwapFacet: _deployFacet(ArtifactCreationCode.creationCode(create3Factory, "BatchSwapFacet.sol:BatchSwapFacet"), "BatchSwapFacet"),
                            bufferRouterFacet: _deployFacet(
                                ArtifactCreationCode.creationCode(create3Factory, "BufferRouterFacet.sol:BufferRouterFacet"), "BufferRouterFacet"
                            ),
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
        json = vm.serializeAddress("", "balancerV3Authorizer", balancerAuthorizer);
        json = vm.serializeAddress("", "balancerV3ProtocolFeeController", balancerProtocolFeeController);
        json = vm.serializeAddress("", "balancerV3VaultAdmin", balancerVaultAdmin);
        json = vm.serializeAddress("", "balancerV3VaultExtension", balancerVaultExtension);
        json = vm.serializeAddress("", "balancerV3Vault", balancerVault);
        json = vm.serializeAddress("", "balancerV3Router", balancerRouter);
        json = vm.serializeAddress("", "balancerV3BatchRouter", balancerBatchRouter);
        json = vm.serializeAddress("", "balancerV3BufferRouter", balancerBufferRouter);
        json = vm.serializeAddress("", "balancerV3CompositeLiquidityRouter", balancerCompositeLiquidityRouter);
        _writeJson(json, OUTPUT_FILE);
    }

    function _logResults() internal view {
        _logAddress("BalancerV3Authorizer:", balancerAuthorizer);
        _logAddress("BalancerV3ProtocolFeeController:", balancerProtocolFeeController);
        _logAddress("BalancerV3VaultAdmin:", balancerVaultAdmin);
        _logAddress("BalancerV3VaultExtension:", balancerVaultExtension);
        _logAddress("BalancerV3Vault:", balancerVault);
        _logAddress("BalancerV3Router:", balancerRouter);
        _logAddress("BalancerV3BatchRouter:", balancerBatchRouter);
        _logAddress("BalancerV3BufferRouter:", balancerBufferRouter);
        _logAddress("BalancerV3CompositeLiquidityRouter:", balancerCompositeLiquidityRouter);
        _logComplete("Base Stage 3B");
    }
}