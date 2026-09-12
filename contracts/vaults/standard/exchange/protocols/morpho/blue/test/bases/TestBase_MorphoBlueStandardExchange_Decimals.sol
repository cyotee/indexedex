// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IMorpho, MarketParams, Id} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {Morpho} from "@crane/contracts/external/morpho/blue/Morpho.sol";
import {OracleMock} from "@crane/contracts/external/morpho/blue/mocks/OracleMock.sol";
import {ERC20Mock} from "@crane/contracts/external/morpho/blue/mocks/ERC20Mock.sol";
import {AdaptiveCurveIrm} from "@crane/contracts/external/morpho/blue-irm/AdaptiveCurveIrm.sol";
import {MarketParamsLib} from "@crane/contracts/external/morpho/blue/libraries/MarketParamsLib.sol";
import {ORACLE_PRICE_SCALE} from "@crane/contracts/external/morpho/blue/libraries/ConstantsLib.sol";
import {MorphoBalancesLib} from
    "@crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol";
import {MorphoBlueService} from
    "@crane/contracts/protocols/lending/morpho/blue/services/MorphoBlueService.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {
    IMorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";
import {
    IMorphoBlueStandardExchangeDFPkg
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchangeDFPkg.sol";
import {
    MorphoBlue_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlue_Component_FactoryService.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/**
 * @title TestBase_MorphoBlueStandardExchange_Decimals
 * @notice Morpho Blue SE with `MintableERC20Decimals` loan (6/9). Collateral stays 18-dec ERC20Mock.
 * @dev Does not call `TestBase_MorphoBlue.setUp` (that always constructs 18-dec `ERC20Mock` loan).
 *      Loan funding uses `mint`, not `setBalance`.
 */
abstract contract TestBase_MorphoBlueStandardExchange_Decimals is TestBase_Permit2, TestBase_VaultComponents {
    using MorphoBlue_Component_FactoryService for ICreate3FactoryProxy;
    using MorphoBlue_Component_FactoryService for IIndexedexManagerProxy;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    uint256 internal constant DEFAULT_LLTV = 0.8e18;

    address internal MORPHO_OWNER;
    address internal SUPPLIER;
    address internal BORROWER;
    address internal LIQUIDATOR;
    address internal FEE_RECIPIENT;

    IMorpho internal morpho;
    AdaptiveCurveIrm internal irm;
    OracleMock internal oracle;
    MintableERC20Decimals internal loanToken;
    ERC20Mock internal collateralToken;
    MarketParams internal marketParams;
    Id internal marketId;

    IFacet morphoBlueErc4626Facet;
    IFacet exchangeInFacet;
    IFacet exchangeOutFacet;
    IFacet markerFacet;
    IMorphoBlueStandardExchangeDFPkg morphoBlueStandardExchangeDFPkg;

    address internal se;
    IStandardExchangeIn internal seIn;
    IStandardExchangeOut internal seOut;
    IMorphoBlueStandardExchange internal mbse;
    IERC4626 internal se4626;

    address internal user;
    address internal attacker;

    function _loanDecimals() internal pure virtual returns (uint8);

    function _u(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_loanDecimals()));
    }

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);

        _deployMorphoWithDecimalLoan();

        user = makeAddr("mbseUser");
        attacker = makeAddr("mbseAttacker");

        morphoBlueErc4626Facet = create3Factory.deployMorphoBlueERC4626Facet();
        exchangeInFacet = create3Factory.deployMorphoBlueStandardExchangeInFacet();
        exchangeOutFacet = create3Factory.deployMorphoBlueStandardExchangeOutFacet();
        markerFacet = create3Factory.deployMorphoBlueStandardExchangeMarkerFacet();

        vm.prank(owner);
        morphoBlueStandardExchangeDFPkg =
            indexedexManager.deployMorphoBlueStandardExchangeDFPkg(_buildPkgInit());

        se = _deployVault(morpho, marketParams);
        seIn = IStandardExchangeIn(se);
        seOut = IStandardExchangeOut(se);
        mbse = IMorphoBlueStandardExchange(se);
        se4626 = IERC4626(se);

        _mintLoan(user, _u(1_000_000));
        vm.prank(user);
        loanToken.approve(se, type(uint256).max);
        _mintLoan(attacker, _u(1_000_000));
        vm.prank(attacker);
        loanToken.approve(se, type(uint256).max);
    }

    function _deployMorphoWithDecimalLoan() internal {
        MORPHO_OWNER = makeAddr("MORPHO_OWNER");
        SUPPLIER = makeAddr("SUPPLIER");
        BORROWER = makeAddr("BORROWER");
        LIQUIDATOR = makeAddr("LIQUIDATOR");
        FEE_RECIPIENT = makeAddr("FEE_RECIPIENT");

        morpho = IMorpho(address(new Morpho(MORPHO_OWNER)));
        irm = new AdaptiveCurveIrm(address(morpho));
        oracle = new OracleMock();
        oracle.setPrice(ORACLE_PRICE_SCALE);

        loanToken = new MintableERC20Decimals("Loan", "LOAN", _loanDecimals());
        collateralToken = new ERC20Mock();

        vm.startPrank(MORPHO_OWNER);
        morpho.enableIrm(address(irm));
        morpho.enableLltv(DEFAULT_LLTV);
        morpho.setFeeRecipient(FEE_RECIPIENT);
        vm.stopPrank();

        marketParams = MarketParams({
            loanToken: address(loanToken),
            collateralToken: address(collateralToken),
            oracle: address(oracle),
            irm: address(irm),
            lltv: DEFAULT_LLTV
        });
        marketId = marketParams.id();
        morpho.createMarket(marketParams);

        _approveAll(SUPPLIER);
        _approveAll(BORROWER);
        _approveAll(LIQUIDATOR);
        _approveAll(address(this));
    }

    function _approveAll(address who) internal {
        vm.startPrank(who);
        loanToken.approve(address(morpho), type(uint256).max);
        collateralToken.approve(address(morpho), type(uint256).max);
        vm.stopPrank();
    }

    function _buildPkgInit()
        internal
        view
        returns (IMorphoBlueStandardExchangeDFPkg.PkgInit memory)
    {
        return IMorphoBlueStandardExchangeDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc2612Facet: erc2612Facet,
            erc5267Facet: erc5267Facet,
            morphoBlueErc4626Facet: morphoBlueErc4626Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            exchangeInFacet: exchangeInFacet,
            exchangeOutFacet: exchangeOutFacet,
            markerFacet: markerFacet,
            vaultFeeOracleQuery: indexedexManager,
            vaultRegistryDeployment: indexedexManager,
            permit2: permit2
        });
    }

    function _deployVault(IMorpho morpho_, MarketParams memory params_)
        internal
        returns (address vault)
    {
        vm.prank(owner);
        vault = morphoBlueStandardExchangeDFPkg.deployVault(
            IMorphoBlueStandardExchangeDFPkg.PkgArgs({morpho: morpho_, marketParams: params_})
        );
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _expectedSupplyOf(address vault) internal view returns (uint256) {
        return morpho.expectedSupplyAssets(marketParams, vault);
    }

    function _idleOf(address vault) internal view returns (uint256) {
        return loanToken.balanceOf(vault);
    }

    function _wrapExactIn(address who, uint256 amountIn) internal returns (uint256 sharesOut) {
        vm.prank(who);
        sharesOut = seIn.exchangeIn(
            IERC20(address(loanToken)), amountIn, IERC20(se), 0, who, false, _deadline()
        );
    }

    function _mintLoan(address to, uint256 amount) internal {
        uint256 cur = loanToken.balanceOf(to);
        if (amount > cur) {
            loanToken.mint(to, amount - cur);
        }
    }

    function _mintCollateral(address to, uint256 amount) internal {
        collateralToken.setBalance(to, amount);
    }

    function _borrowFromMarket(uint256 collateral, uint256 debt) internal {
        _mintCollateral(BORROWER, collateral);
        vm.startPrank(BORROWER);
        MorphoBlueService._supplyCollateral(morpho, marketParams, collateral, BORROWER);
        MorphoBlueService._borrow(morpho, marketParams, debt, BORROWER, BORROWER);
        vm.stopPrank();
    }
}
