// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {
    Roles,
    MarketConfig,
    DeployFlags,
    MarketReport
} from "@crane/contracts/protocols/lending/aave/v3.6/deployments/interfaces/IMarketReportTypes.sol";
import {DefaultMarketInput} from
    "@crane/contracts/protocols/lending/aave/v3.6/deployments/inputs/DefaultMarketInput.sol";
import {AaveV3BatchOrchestration} from
    "@crane/contracts/protocols/lending/aave/v3.6/deployments/projects/aave-v3-batched/AaveV3BatchOrchestration.sol";
import {IAaveV3ConfigEngine} from
    "@crane/contracts/protocols/lending/aave/v3.6/extensions/v3-config-engine/IAaveV3ConfigEngine.sol";
import {EngineFlags} from
    "@crane/contracts/protocols/lending/aave/v3.6/extensions/v3-config-engine/EngineFlags.sol";
import {IACLManager} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IACLManager.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {MockPriceFeed} from "@crane/test/foundry/spec/protocols/lending/aave/v4/helpers/mocks/MockPriceFeed.sol";

import {TestBase_AaveCrossVersionLoopV4Market} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol";

/**
 * @title TestBase_AaveCrossVersionLoopV3Market
 * @author cyotee doge <doge.cyotee>
 * @notice Adds a local Aave V3.6 market (full Pool/Configurator/Oracle/ConfigEngine) on top of the
 *         V4 market + test tokens, completing the local cross-version environment. The V3 batch
 *         orchestration is already `new`-based (portable). Reserve listing of our tokens is added
 *         in a follow-up; this base proves the V3 market stands up.
 */
contract TestBase_AaveCrossVersionLoopV3Market is TestBase_AaveCrossVersionLoopV4Market, DefaultMarketInput {
    IPool internal v36Pool;
    address internal v36AddressesProvider;
    address internal v36PoolConfigurator;
    address internal v36Oracle;
    address internal v36AclManager;
    address internal v36ConfigEngine;
    address internal v36DataProvider;
    MarketReport internal v36Report;

    function setUp() public virtual override {
        TestBase_AaveCrossVersionLoopV4Market.setUp();
        _setUpV3Market();
    }

    function _setUpV3Market() internal {
        (Roles memory roles, MarketConfig memory config, DeployFlags memory flags, MarketReport memory empty) =
            _getMarketInput(address(this));

        config.wrappedNativeToken = address(new WETH9());

        v36Report = AaveV3BatchOrchestration.deployAaveV3(address(this), roles, config, flags, empty);

        v36Pool = IPool(v36Report.poolProxy);
        v36AddressesProvider = v36Report.poolAddressesProvider;
        v36PoolConfigurator = v36Report.poolConfiguratorProxy;
        v36Oracle = v36Report.aaveOracle;
        v36AclManager = v36Report.aclManager;
        v36ConfigEngine = v36Report.configEngine;
        v36DataProvider = v36Report.protocolDataProvider;

        _listV3Reserves();
    }

    /// @dev Lists tokenA and tokenB as V3.6 reserves (collateral + borrowable) via the ConfigEngine,
    ///      with mock price feeds and tunable rate strategies. The engine is granted pool-admin so it
    ///      can drive the PoolConfigurator.
    function _listV3Reserves() internal {
        IACLManager(v36AclManager).addPoolAdmin(v36ConfigEngine);

        IAaveV3ConfigEngine.PoolContext memory ctx =
            IAaveV3ConfigEngine.PoolContext({networkName: "IndexedEx Test", networkAbbreviation: "ITEST"});

        IAaveV3ConfigEngine.Listing[] memory listings = new IAaveV3ConfigEngine.Listing[](2);
        listings[0] = _v3Listing(address(tokenA), "CLTA", _v3MockPriceFeed(2000e8));
        listings[1] = _v3Listing(address(tokenB), "CLTB", _v3MockPriceFeed(1e8));

        IAaveV3ConfigEngine(v36ConfigEngine).listAssets(ctx, listings);
    }

    function _v3Listing(address asset, string memory symbol, address priceFeed)
        internal
        pure
        returns (IAaveV3ConfigEngine.Listing memory)
    {
        return IAaveV3ConfigEngine.Listing({
            asset: asset,
            assetSymbol: symbol,
            priceFeed: priceFeed,
            rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
                optimalUsageRatio: 80_00,
                baseVariableBorrowRate: 25,
                variableRateSlope1: 3_00,
                variableRateSlope2: 75_00
            }),
            enabledToBorrow: EngineFlags.ENABLED,
            borrowableInIsolation: EngineFlags.DISABLED,
            withSiloedBorrowing: EngineFlags.DISABLED,
            flashloanable: EngineFlags.DISABLED,
            ltv: 70_00,
            liqThreshold: 75_00,
            liqBonus: 5_00,
            reserveFactor: 10_00,
            supplyCap: 1_000_000_000,
            borrowCap: 1_000_000_000,
            debtCeiling: 0,
            liqProtocolFee: 10_00
        });
    }

    function _v3MockPriceFeed(uint256 price) internal returns (address) {
        // V3 AaveOracle base currency unit is 1e8 (USD, 8 decimals).
        return address(new MockPriceFeed(8, "mock price feed", price));
    }
}
