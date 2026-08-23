// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IMorpho, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from
    "@crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol";
import {MorphoBlueService} from
    "@crane/contracts/protocols/lending/morpho/blue/services/MorphoBlueService.sol";
import {TestBase_MorphoBlue} from
    "@crane/contracts/protocols/lending/morpho/blue/test/bases/TestBase_MorphoBlue.sol";
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

/**
 * @title TestBase_MorphoBlueStandardExchange
 * @notice Permit2 + VaultComponents + hermetic MorphoBlue, then CREATE3 facets, registry DFPkg, deployVault.
 * @dev Parent setUp order: Permit2, VaultComponents (IndexedEx stack), MorphoBlue (`new Morpho` + createMarket),
 *      then facets + `vm.prank(owner)` registry deploy on the already-created market.
 */
contract TestBase_MorphoBlueStandardExchange is
    TestBase_Permit2,
    TestBase_VaultComponents,
    TestBase_MorphoBlue
{
    using MorphoBlue_Component_FactoryService for ICreate3FactoryProxy;
    using MorphoBlue_Component_FactoryService for IIndexedexManagerProxy;
    using MorphoBalancesLib for IMorpho;

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

    function setUp()
        public
        virtual
        override(TestBase_Permit2, TestBase_VaultComponents, TestBase_MorphoBlue)
    {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        TestBase_MorphoBlue.setUp();

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

        _mintLoan(user, 1_000_000 ether);
        vm.prank(user);
        loanToken.approve(se, type(uint256).max);
        _mintLoan(attacker, 1_000_000 ether);
        vm.prank(attacker);
        loanToken.approve(se, type(uint256).max);
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

    /// @dev Drive utilization: borrower posts collateral and borrows `debt` of loanToken from the bound market.
    function _borrowFromMarket(uint256 collateral, uint256 debt) internal {
        _mintCollateral(BORROWER, collateral);
        vm.startPrank(BORROWER);
        MorphoBlueService._supplyCollateral(morpho, marketParams, collateral, BORROWER);
        MorphoBlueService._borrow(morpho, marketParams, debt, BORROWER, BORROWER);
        vm.stopPrank();
    }
}
