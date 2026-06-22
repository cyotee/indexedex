// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAccessManager} from
    "@crane/contracts/external/openzeppelin-contracts/access/manager/IAccessManager.sol";

import {IHub} from "@crane/contracts/protocols/lending/aave/v4/hub/interfaces/IHub.sol";
import {ISpoke} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/ISpoke.sol";
import {IAaveOracle as IAaveOracleV4} from
    "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";
import {AaveOracle} from "@crane/contracts/protocols/lending/aave/v4/spoke/AaveOracle.sol";
import {HubInstance} from "@crane/contracts/protocols/lending/aave/v4/hub/instances/HubInstance.sol";
import {SpokeInstance} from "@crane/contracts/protocols/lending/aave/v4/spoke/instances/SpokeInstance.sol";
import {IAssetInterestRateStrategy} from
    "@crane/contracts/protocols/lending/aave/v4/hub/interfaces/IAssetInterestRateStrategy.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {Roles} from "@crane/contracts/protocols/lending/aave/v4/deployments/utils/libraries/Roles.sol";
import {AaveV4HubConfiguratorRolesProcedure} from
    "@crane/contracts/protocols/lending/aave/v4/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol";
import {AaveV4SpokeConfiguratorRolesProcedure} from
    "@crane/contracts/protocols/lending/aave/v4/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol";

import {AaveV4TestOrchestration} from
    "@crane/test/foundry/spec/protocols/lending/aave/v4/deployments/orchestration/AaveV4TestOrchestration.sol";
import {ConfigData} from "@crane/test/foundry/spec/protocols/lending/aave/v4/utils/ConfigData.sol";
import {TestTypes} from "@crane/test/foundry/spec/protocols/lending/aave/v4/utils/TestTypes.sol";
import {MockPriceFeed} from "@crane/test/foundry/spec/protocols/lending/aave/v4/helpers/mocks/MockPriceFeed.sol";

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {TestBase_AaveCrossVersionLoop} from "contracts/test/bases/TestBase_AaveCrossVersionLoop.sol";

/**
 * @title TestBase_AaveCrossVersionLoopV4Market
 * @author cyotee doge <doge.cyotee>
 * @notice Stands up a local Aave V4 market (1 Hub + 1 Spoke) listing the two pair test tokens, using
 *         Crane's deploy orchestration but feeding `type(HubInstance/SpokeInstance).creationCode`
 *         instead of `vm.getCode` (which isn't portable into this project). Rates/caps/collateral
 *         factors are fully configurable, enabling deterministic profitable-loop tests.
 */
contract TestBase_AaveCrossVersionLoopV4Market is TestBase_AaveCrossVersionLoop {
    // CREATE2 factory used by Crane's deploy orchestration (etched in-place for tests).
    // Named distinctly to avoid shadowing forge-std's CREATE2_FACTORY.
    address internal constant AAVE_V4_CREATE2_FACTORY = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;
    bytes internal constant AAVE_V4_CREATE2_FACTORY_BYTECODE =
        hex"7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3";

    IHub internal v4Hub;
    ISpoke internal v4Spoke;
    IAaveOracleV4 internal v4Oracle;
    address internal v4IrStrategy;
    address internal v4AccessManager;

    uint256 internal v4ReserveIdA;
    uint256 internal v4ReserveIdB;
    uint256 internal v4AssetIdA;
    uint256 internal v4AssetIdB;

    function setUp() public virtual override {
        TestBase_AaveCrossVersionLoop.setUp();
        _setUpV4Market();
    }

    function _setUpV4Market() internal {
        // 1. CREATE2 factory + native wrapper.
        if (AAVE_V4_CREATE2_FACTORY.code.length == 0) {
            vm.etch(AAVE_V4_CREATE2_FACTORY, AAVE_V4_CREATE2_FACTORY_BYTECODE);
        }
        WETH9 weth = new WETH9();

        // 2. Deploy a 1-hub / 1-spoke env with compile-time bytecode (portable; no vm.getCode).
        TestTypes.TestEnvReport memory report = AaveV4TestOrchestration.deployTestEnv({
            admin: address(this),
            treasuryAdmin: address(this),
            hubCount: 1,
            spokeCount: 1,
            nativeWrapper: address(weth),
            hubBytecode: type(HubInstance).creationCode,
            spokeBytecode: type(SpokeInstance).creationCode,
            salt: keccak256("indexedex.aave.cross-version.v4")
        });

        v4Hub = IHub(report.hubReports[0].hub);
        v4IrStrategy = report.hubReports[0].irStrategy;
        v4Spoke = ISpoke(report.spokeReports[0].spoke);
        v4Oracle = IAaveOracleV4(report.spokeReports[0].aaveOracle);
        v4AccessManager = report.accessManager;

        // 3. Roles (this contract is the AccessManager admin from `admin` above).
        AaveV4TestOrchestration.setRolesTestEnv(report);
        AaveV4TestOrchestration.grantRolesTestEnv(report, address(this), address(this), address(this));
        AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles(v4AccessManager, address(this));
        AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles(v4AccessManager, address(this));

        // 4. List both tokens (asset -> spoke -> reserve) with mock price feeds + tunable IR.
        IAccessManager(v4AccessManager).grantRole(Roles.HUB_CONFIGURATOR_ROLE, address(this), 0);
        IAccessManager(v4AccessManager).grantRole(Roles.SPOKE_CONFIGURATOR_ROLE, address(this), 0);

        AaveV4TestOrchestration.configureHubsAssets(_v4AddAssetParams());
        v4AssetIdA = v4Hub.getAssetId(address(tokenA));
        v4AssetIdB = v4Hub.getAssetId(address(tokenB));

        AaveV4TestOrchestration.configureHubsSpokes(_v4AddSpokeParams());
        TestTypes.SpokeReserveId[] memory ids =
            AaveV4TestOrchestration.configureSpokes(_v4LiquidationParams(), _v4ReserveParams());
        v4ReserveIdA = ids[0].reserveId;
        v4ReserveIdB = ids[1].reserveId;

        IAccessManager(v4AccessManager).renounceRole(Roles.HUB_CONFIGURATOR_ROLE, address(this));
        IAccessManager(v4AccessManager).renounceRole(Roles.SPOKE_CONFIGURATOR_ROLE, address(this));
    }

    function _v4IrData() internal pure returns (bytes memory) {
        return abi.encode(
            IAssetInterestRateStrategy.InterestRateData({
                optimalUsageRatio: 90_00,
                baseDrawnRate: 5_00,
                rateGrowthBeforeOptimal: 5_00,
                rateGrowthAfterOptimal: 5_00
            })
        );
    }

    function _v4AddAssetParams() internal view returns (ConfigData.AddAssetParams[] memory params) {
        params = new ConfigData.AddAssetParams[](2);
        params[0] = ConfigData.AddAssetParams({
            hub: address(v4Hub),
            underlying: address(tokenA),
            decimals: IERC20Metadata(address(tokenA)).decimals(),
            feeReceiver: address(this),
            liquidityFee: 10_00,
            irStrategy: v4IrStrategy,
            reinvestmentController: address(0),
            irData: _v4IrData()
        });
        params[1] = ConfigData.AddAssetParams({
            hub: address(v4Hub),
            underlying: address(tokenB),
            decimals: IERC20Metadata(address(tokenB)).decimals(),
            feeReceiver: address(this),
            liquidityFee: 10_00,
            irStrategy: v4IrStrategy,
            reinvestmentController: address(0),
            irData: _v4IrData()
        });
    }

    function _v4SpokeConfig() internal pure returns (IHub.SpokeConfig memory) {
        return IHub.SpokeConfig({
            addCap: type(uint40).max,
            drawCap: type(uint40).max,
            riskPremiumThreshold: 100_00,
            active: true,
            halted: false
        });
    }

    function _v4AddSpokeParams() internal view returns (ConfigData.AddSpokeParams[] memory params) {
        params = new ConfigData.AddSpokeParams[](2);
        params[0] = ConfigData.AddSpokeParams({
            hub: address(v4Hub),
            assetId: v4Hub.getAssetId(address(tokenA)),
            spoke: address(v4Spoke),
            config: _v4SpokeConfig()
        });
        params[1] = ConfigData.AddSpokeParams({
            hub: address(v4Hub),
            assetId: v4Hub.getAssetId(address(tokenB)),
            spoke: address(v4Spoke),
            config: _v4SpokeConfig()
        });
    }

    function _v4LiquidationParams()
        internal
        view
        returns (ConfigData.UpdateLiquidationConfigParams[] memory params)
    {
        params = new ConfigData.UpdateLiquidationConfigParams[](1);
        params[0] = ConfigData.UpdateLiquidationConfigParams({
            spoke: address(v4Spoke),
            config: ISpoke.LiquidationConfig({
                targetHealthFactor: 1.05e18,
                healthFactorForMaxBonus: 0.7e18,
                liquidationBonusFactor: 20_00
            })
        });
    }

    function _v4ReserveConfig() internal pure returns (ISpoke.ReserveConfig memory) {
        return ISpoke.ReserveConfig({
            paused: false,
            frozen: false,
            borrowable: true,
            receiveSharesEnabled: true,
            collateralRisk: 15_00
        });
    }

    function _v4ReserveParams() internal returns (ConfigData.AddReserveParams[] memory params) {
        params = new ConfigData.AddReserveParams[](2);
        params[0] = ConfigData.AddReserveParams({
            spoke: address(v4Spoke),
            hub: address(v4Hub),
            assetId: v4Hub.getAssetId(address(tokenA)),
            priceSource: _v4MockPriceFeed(2000e8),
            config: _v4ReserveConfig(),
            dynamicConfig: ISpoke.DynamicReserveConfig({
                collateralFactor: 80_00,
                maxLiquidationBonus: 105_00,
                liquidationFee: 10_00
            })
        });
        params[1] = ConfigData.AddReserveParams({
            spoke: address(v4Spoke),
            hub: address(v4Hub),
            assetId: v4Hub.getAssetId(address(tokenB)),
            priceSource: _v4MockPriceFeed(1e8),
            config: _v4ReserveConfig(),
            dynamicConfig: ISpoke.DynamicReserveConfig({
                collateralFactor: 78_00,
                maxLiquidationBonus: 102_00,
                liquidationFee: 10_00
            })
        });
    }

    function _v4MockPriceFeed(uint256 price) internal returns (address) {
        return address(new MockPriceFeed(AaveOracle(address(v4Oracle)).decimals(), "mock price feed", price));
    }
}
