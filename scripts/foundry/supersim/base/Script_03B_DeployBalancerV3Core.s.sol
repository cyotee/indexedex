// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

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

import {BasicAuthorizerMock} from "@crane/contracts/protocols/dexes/balancer/v3/test/mocks/BasicAuthorizerMock.sol";
import {
    BalancerV3VaultDFPkg,
    IBalancerV3VaultDFPkg
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/diamond/BalancerV3VaultDFPkg.sol";
import {
    BalancerV3RouterDFPkg,
    IBalancerV3RouterDFPkg
} from "@crane/contracts/protocols/dexes/balancer/v3/router/diamond/BalancerV3RouterDFPkg.sol";
import {VaultTransientFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/diamond/facets/VaultTransientFacet.sol";
import {VaultSwapFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/diamond/facets/VaultSwapFacet.sol";
import {VaultLiquidityFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/diamond/facets/VaultLiquidityFacet.sol";
import {VaultBufferFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/diamond/facets/VaultBufferFacet.sol";
import {VaultPoolTokenFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/diamond/facets/VaultPoolTokenFacet.sol";
import {VaultQueryFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/diamond/facets/VaultQueryFacet.sol";
import {VaultRegistrationFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/diamond/facets/VaultRegistrationFacet.sol";
import {VaultAdminFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/diamond/facets/VaultAdminFacet.sol";
import {VaultRecoveryFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/diamond/facets/VaultRecoveryFacet.sol";
import {RouterSwapFacet} from "@crane/contracts/protocols/dexes/balancer/v3/router/diamond/facets/RouterSwapFacet.sol";
import {
    RouterAddLiquidityFacet
} from "@crane/contracts/protocols/dexes/balancer/v3/router/diamond/facets/RouterAddLiquidityFacet.sol";
import {
    RouterRemoveLiquidityFacet
} from "@crane/contracts/protocols/dexes/balancer/v3/router/diamond/facets/RouterRemoveLiquidityFacet.sol";
import {
    RouterInitializeFacet
} from "@crane/contracts/protocols/dexes/balancer/v3/router/diamond/facets/RouterInitializeFacet.sol";
import {
    RouterCommonFacet
} from "@crane/contracts/protocols/dexes/balancer/v3/router/diamond/facets/RouterCommonFacet.sol";
import {BatchSwapFacet} from "@crane/contracts/protocols/dexes/balancer/v3/router/diamond/facets/BatchSwapFacet.sol";
import {
    BufferRouterFacet
} from "@crane/contracts/protocols/dexes/balancer/v3/router/diamond/facets/BufferRouterFacet.sol";
import {
    CompositeLiquidityERC4626Facet
} from "@crane/contracts/protocols/dexes/balancer/v3/router/diamond/facets/CompositeLiquidityERC4626Facet.sol";
import {
    CompositeLiquidityNestedFacet
} from "@crane/contracts/protocols/dexes/balancer/v3/router/diamond/facets/CompositeLiquidityNestedFacet.sol";

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
            type(BasicAuthorizerMock).creationCode,
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
                    type(BalancerV3VaultDFPkg).creationCode,
                    abi.encode(
                        IBalancerV3VaultDFPkg.PkgInit({
                            vaultTransientFacet: _deployFacet(
                                type(VaultTransientFacet).creationCode, type(VaultTransientFacet).name
                            ),
                            vaultSwapFacet: _deployFacet(type(VaultSwapFacet).creationCode, type(VaultSwapFacet).name),
                            vaultLiquidityFacet: _deployFacet(
                                type(VaultLiquidityFacet).creationCode, type(VaultLiquidityFacet).name
                            ),
                            vaultBufferFacet: _deployFacet(type(VaultBufferFacet).creationCode, type(VaultBufferFacet).name),
                            vaultPoolTokenFacet: _deployFacet(
                                type(VaultPoolTokenFacet).creationCode, type(VaultPoolTokenFacet).name
                            ),
                            vaultQueryFacet: _deployFacet(type(VaultQueryFacet).creationCode, type(VaultQueryFacet).name),
                            vaultRegistrationFacet: _deployFacet(
                                type(VaultRegistrationFacet).creationCode, type(VaultRegistrationFacet).name
                            ),
                            vaultAdminFacet: _deployFacet(type(VaultAdminFacet).creationCode, type(VaultAdminFacet).name),
                            vaultRecoveryFacet: _deployFacet(
                                type(VaultRecoveryFacet).creationCode, type(VaultRecoveryFacet).name
                            ),
                            diamondFactory: diamondPackageFactory
                        })
                    ),
                    _salt(type(BalancerV3VaultDFPkg).name)
                )
            )
        );
    }

    function _deployRouterPackage() internal {
        routerPkg = IBalancerV3RouterDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(BalancerV3RouterDFPkg).creationCode,
                    abi.encode(
                        IBalancerV3RouterDFPkg.PkgInit({
                            routerSwapFacet: _deployFacet(type(RouterSwapFacet).creationCode, type(RouterSwapFacet).name),
                            routerAddLiquidityFacet: _deployFacet(
                                type(RouterAddLiquidityFacet).creationCode, type(RouterAddLiquidityFacet).name
                            ),
                            routerRemoveLiquidityFacet: _deployFacet(
                                type(RouterRemoveLiquidityFacet).creationCode, type(RouterRemoveLiquidityFacet).name
                            ),
                            routerInitializeFacet: _deployFacet(
                                type(RouterInitializeFacet).creationCode, type(RouterInitializeFacet).name
                            ),
                            routerCommonFacet: _deployFacet(
                                type(RouterCommonFacet).creationCode, type(RouterCommonFacet).name
                            ),
                            batchSwapFacet: _deployFacet(type(BatchSwapFacet).creationCode, type(BatchSwapFacet).name),
                            bufferRouterFacet: _deployFacet(
                                type(BufferRouterFacet).creationCode, type(BufferRouterFacet).name
                            ),
                            compositeLiquidityERC4626Facet: _deployFacet(
                                type(CompositeLiquidityERC4626Facet).creationCode,
                                type(CompositeLiquidityERC4626Facet).name
                            ),
                            compositeLiquidityNestedFacet: _deployFacet(
                                type(CompositeLiquidityNestedFacet).creationCode,
                                type(CompositeLiquidityNestedFacet).name
                            ),
                            diamondFactory: diamondPackageFactory
                        })
                    ),
                    _salt(type(BalancerV3RouterDFPkg).name)
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