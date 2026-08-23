// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IMorpho, Id, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MarketParamsLib} from "@crane/contracts/external/morpho/blue/libraries/MarketParamsLib.sol";
import {ERC20Mock} from "@crane/contracts/external/morpho/blue/mocks/ERC20Mock.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {
    IMorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";
import {
    IMorphoBlueStandardExchangeDFPkg
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchangeDFPkg.sol";
import {
    TestBase_MorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange.sol";

/**
 * @title MorphoBlueStandardExchange_Deploy
 * @notice D1–D2 registry deploy + J1–J3 facet surface on the production proxy.
 */
contract MorphoBlueStandardExchange_Deploy is TestBase_MorphoBlueStandardExchange {
    using MarketParamsLib for MarketParams;

    function test_D1_registryDeploy_assetLoanToken_vaultTokens_marker() public view {
        assertEq(se4626.asset(), address(loanToken), "asset() == loanToken");
        address[] memory tokens = IBasicVault(se).vaultTokens();
        assertEq(tokens.length, 1, "vaultTokens length");
        assertEq(tokens[0], address(loanToken), "vaultTokens[0] == loanToken");
        assertEq(address(mbse.morpho()), address(morpho), "morpho()");
        assertEq(mbse.loanToken(), address(loanToken), "loanToken()");
        MarketParams memory p = mbse.marketParams();
        assertEq(p.loanToken, marketParams.loanToken);
        assertEq(p.collateralToken, marketParams.collateralToken);
        assertEq(p.oracle, marketParams.oracle);
        assertEq(p.irm, marketParams.irm);
        assertEq(p.lltv, marketParams.lltv);
        assertEq(Id.unwrap(mbse.marketId()), Id.unwrap(marketId));
    }

    function test_D2_deployVault_neverCreatedMarket_revertsMarketNotCreated() public {
        ERC20Mock missingLoan = new ERC20Mock();
        ERC20Mock missingColl = new ERC20Mock();
        MarketParams memory missing = MarketParams({
            loanToken: address(missingLoan),
            collateralToken: address(missingColl),
            oracle: address(oracle),
            irm: address(irm),
            lltv: DEFAULT_LLTV
        });
        Id missingId = missing.id();
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IMorphoBlueStandardExchange.MarketNotCreated.selector, missingId)
        );
        morphoBlueStandardExchangeDFPkg.deployVault(
            IMorphoBlueStandardExchangeDFPkg.PkgArgs({morpho: morpho, marketParams: missing})
        );
    }

    function test_J1_targetSelectors_onFacetFuncs() public view {
        bytes4[] memory inFuncs = IFacet(address(exchangeInFacet)).facetFuncs();
        bytes4[] memory outFuncs = IFacet(address(exchangeOutFacet)).facetFuncs();
        bytes4[] memory mFuncs = IFacet(address(markerFacet)).facetFuncs();
        bytes4[] memory eFuncs = IFacet(address(morphoBlueErc4626Facet)).facetFuncs();
        assertTrue(_contains(inFuncs, IStandardExchangeIn.previewExchangeIn.selector), "J1 in preview");
        assertTrue(_contains(inFuncs, IStandardExchangeIn.exchangeIn.selector), "J1 in exec");
        assertTrue(_contains(outFuncs, IStandardExchangeOut.previewExchangeOut.selector), "J1 out preview");
        assertTrue(_contains(outFuncs, IStandardExchangeOut.exchangeOut.selector), "J1 out exec");
        assertTrue(_contains(mFuncs, IMorphoBlueStandardExchange.morpho.selector), "J1 morpho");
        assertTrue(_contains(mFuncs, IMorphoBlueStandardExchange.marketParams.selector), "J1 marketParams");
        assertTrue(_contains(mFuncs, IMorphoBlueStandardExchange.marketId.selector), "J1 marketId");
        assertTrue(_contains(mFuncs, IMorphoBlueStandardExchange.loanToken.selector), "J1 loanToken");
        assertTrue(_contains(eFuncs, IERC4626.deposit.selector), "J1 deposit");
        assertTrue(_contains(eFuncs, IERC4626.mint.selector), "J1 mint");
        assertTrue(_contains(eFuncs, IERC4626.withdraw.selector), "J1 withdraw");
        assertTrue(_contains(eFuncs, IERC4626.redeem.selector), "J1 redeem");
        assertEq(eFuncs.length, 16, "J1 all 16 IERC4626 selectors");
    }

    function test_J2_cuts_includeFacetSelectors() public view {
        bytes4[] memory inFuncs = IFacet(address(exchangeInFacet)).facetFuncs();
        bytes4[] memory cuts = _allCutSelectors();
        for (uint256 i; i < inFuncs.length; ++i) {
            assertTrue(_contains(cuts, inFuncs[i]), "J2 in selector in cuts");
        }
    }

    function test_J3_proxyLoupe_andSmoke() public {
        IDiamondLoupe loupe = IDiamondLoupe(se);
        assertTrue(loupe.facetAddress(IStandardExchangeIn.exchangeIn.selector) != address(0), "J3 in");
        assertTrue(loupe.facetAddress(IStandardExchangeOut.exchangeOut.selector) != address(0), "J3 out");
        assertTrue(loupe.facetAddress(IERC4626.deposit.selector) != address(0), "J3 deposit");
        assertTrue(loupe.facetAddress(IMorphoBlueStandardExchange.morpho.selector) != address(0), "J3 marker");

        uint256 preview = seIn.previewExchangeIn(IERC20(address(loanToken)), 1 ether, IERC20(se));
        uint256 out = _wrapExactIn(user, 1 ether);
        assertEq(out, preview, "J3 proxy wrap smoke");
        assertEq(mbse.loanToken(), address(loanToken));
        assertEq(se4626.asset(), address(loanToken));
    }

    function _allCutSelectors() internal view returns (bytes4[] memory sels) {
        sels = morphoBlueStandardExchangeDFPkg.facetCuts()[6].functionSelectors;
    }

    function _contains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }
}
