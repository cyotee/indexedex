// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {
    ITransparentProxyFactory
} from "@crane/contracts/protocols/lending/aave/v3.6/dependencies/solidity-utils/contracts/transparent-proxy/interfaces/ITransparentProxyFactory.sol";
import {
    StataTokenFactory
} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/StataTokenFactory.sol";
import {StataTokenV2} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/StataTokenV2.sol";
import {TestnetERC20} from "@crane/contracts/protocols/lending/aave/v3.6/utils/mocks/testnet-helpers/TestnetERC20.sol";
import {
    MockAggregator
} from "@crane/contracts/protocols/lending/aave/v3.6/utils/mocks/oracle/CLAggregators/MockAggregator.sol";
import {AaveV3Payload} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/v3-config-engine/AaveV3Payload.sol";
import {
    IAaveV3ConfigEngine as IEngine
} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/v3-config-engine/IAaveV3ConfigEngine.sol";
import {EngineFlags} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/v3-config-engine/EngineFlags.sol";
import {BaseTest} from "lib/crane/test/foundry/spec/protocols/lending/aave/3.6/extensions/stata-token/TestBase.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_AaveV3StataStandardExchange} from
    "contracts/test/bases/TestBase_AaveV3StataStandardExchange.sol";

/// @dev Crane listing payload (same path as `AaveV3MockListing` / ConfigEngine tests).
contract AaveV3StataDecimalsListing is AaveV3Payload {
    address public immutable ASSET_ADDRESS;
    address public immutable ASSET_FEED;

    constructor(address assetAddress, address assetFeed, address customEngine)
        AaveV3Payload(IEngine(customEngine))
    {
        ASSET_ADDRESS = assetAddress;
        ASSET_FEED = assetFeed;
    }

    function newListings() public view override returns (IEngine.Listing[] memory) {
        IEngine.Listing[] memory listings = new IEngine.Listing[](1);
        listings[0] = IEngine.Listing({
            asset: ASSET_ADDRESS,
            assetSymbol: "NINE",
            priceFeed: ASSET_FEED,
            rateStrategyParams: IEngine.InterestRateInputData({
                optimalUsageRatio: 80_00,
                baseVariableBorrowRate: 25,
                variableRateSlope1: 3_00,
                variableRateSlope2: 75_00
            }),
            enabledToBorrow: EngineFlags.ENABLED,
            borrowableInIsolation: EngineFlags.DISABLED,
            withSiloedBorrowing: EngineFlags.DISABLED,
            flashloanable: EngineFlags.DISABLED,
            ltv: 82_50,
            liqThreshold: 86_00,
            liqBonus: 5_00,
            reserveFactor: 10_00,
            supplyCap: 85_000,
            borrowCap: 60_000,
            debtCeiling: 0,
            liqProtocolFee: 10_00
        });
        return listings;
    }

    function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
        return IEngine.PoolContext({networkName: "Local", networkAbbreviation: "Loc"});
    }
}

/**
 * @title TestBase_AaveV3StataStandardExchange_Decimals
 * @notice Crane StataTokenV2 + IndexedEx SE whose configured underlying is 6-, 9- or 18-dec.
 * @dev Does not call Crane `BaseTest.setUp` as-is (that binds WETH/18). SE vaultShare stays 18.
 */
abstract contract TestBase_AaveV3StataStandardExchange_Decimals is
    TestBase_AaveV3StataStandardExchange,
    BaseTest
{
    address internal realVault;
    address internal realStata;
    address internal realBase;
    address internal attacker;
    address internal victim;

    function _underlyingDecimals() internal pure virtual returns (uint8);

    /// @dev Raw units of the configured Stata base (`human * 10 ** decimals`).
    function _u(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_underlyingDecimals()));
    }

    function setUp() public virtual override(TestBase_AaveV3StataStandardExchange, BaseTest) {
        _setUpCraneAaveStata();
        TestBase_AaveV3StataStandardExchange.setUp();
        _bindIndexedExRealVault();
    }

    /// @dev Crane pool + Stata factory, then bind usdx (U6) or listed NINE (U9).
    function _setUpCraneAaveStata() internal {
        userPrivateKey = 0xA11CE;
        spenderPrivateKey = 0xB0B0;
        user = address(vm.addr(userPrivateKey));
        user1 = address(vm.addr(2));
        spender = vm.addr(spenderPrivateKey);

        initTestEnvironment(false);

        rewardToken = address(new TestnetERC20("LM Reward ERC20", "RWD", 18, OWNER));
        rewardTokens.push(rewardToken);
        proxyFactory = ITransparentProxyFactory(report.transparentProxyFactory);
        factory = StataTokenFactory(report.staticATokenFactoryProxy);
        vm.expectRevert("Initializable: contract is already initialized");
        StataTokenFactory(report.staticATokenFactoryImplementation).initialize();

        underlying = _selectUnderlying();
        factory.createStataTokens(contracts.poolProxy.getReservesList());
        aToken = contracts.poolProxy.getReserveAToken(underlying);
        stataTokenV2 = StataTokenV2(factory.getStataToken(underlying));
        proxyAdmin = address(uint160(uint256(vm.load(address(stataTokenV2), ADMIN_SLOT))));

        require(aToken != address(0), "aToken");
        require(address(stataTokenV2) != address(0), "stata");
        require(IERC20Metadata(underlying).decimals() == _underlyingDecimals(), "underlying decimals");
        require(stataTokenV2.asset() == underlying, "stata asset");
    }

    function _selectUnderlying() internal returns (address) {
        uint8 d = _underlyingDecimals();
        if (d == 18) return tokenList.weth;
        if (d == 6) {
            return tokenList.usdx;
        }
        if (d == 9) {
            return _listNineDecimalAsset();
        }
        revert("unsupported Stata underlying decimals");
    }

    function _listNineDecimalAsset() internal returns (address asset) {
        asset = address(new TestnetERC20("Nine", "NINE", 9, poolAdmin));
        address feed = address(new MockAggregator(int256(1e8)));
        AaveV3StataDecimalsListing payload =
            new AaveV3StataDecimalsListing(asset, feed, report.configEngine);
        vm.prank(roleList.marketOwner);
        contracts.aclManager.addPoolAdmin(address(payload));
        payload.execute();
    }

    function _bindIndexedExRealVault() internal {
        realStata = address(stataTokenV2);
        realBase = underlying;
        realVault = _deployStataVault(realStata);
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");

        _fundUnderlying(_u(1000), address(this));
        IERC20(realBase).approve(realVault, type(uint256).max);
    }

    /// @dev Use the real manager. A zero per-vault override falls through to its default.
    function _setTestUsageFee(uint256 fee) internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(fee);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(realVault, fee);
        vm.stopPrank();
        assertEq(indexedexManager.usageFeeOfVault(realVault), fee, "actual configured fee");
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    /// @dev Stata shares from `underlyingAmt` of the configured base, sent to `to_`.
    function _acquireStata(address to_, uint256 underlyingAmt_) internal returns (uint256 stataShares_) {
        stataShares_ = _fund4626(underlyingAmt_, to_);
        require(stataShares_ > 0, "stata shares");
    }
}
