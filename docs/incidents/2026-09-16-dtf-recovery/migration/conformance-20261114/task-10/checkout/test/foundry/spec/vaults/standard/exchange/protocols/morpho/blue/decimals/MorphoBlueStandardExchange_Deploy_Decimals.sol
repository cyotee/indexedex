// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IMorpho, Id, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MarketParamsLib} from "@crane/contracts/external/morpho/blue/libraries/MarketParamsLib.sol";
import {ERC20Mock} from "@crane/contracts/external/morpho/blue/mocks/ERC20Mock.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IMorphoBlueStandardExchange} from
    "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";
import {TestBase_MorphoBlueStandardExchange_Decimals} from
    "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange_Decimals.sol";

/// @notice D1–D2 only (J1–J3 EX-J). Combo ID is the concrete suite name.
abstract contract MorphoBlueStandardExchange_Deploy_Decimals is
    TestBase_MorphoBlueStandardExchange_Decimals
{
    using MarketParamsLib for MarketParams;

    function test_D1_registryDeploy_assetLoanToken_vaultTokens_marker() public view {
        assertEq(se4626.asset(), address(loanToken), "asset() == loanToken");
        assertEq(loanToken.decimals(), _loanDecimals(), "loan decimals");
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
        vm.expectRevert();
        _deployVault(morpho, missing);
    }
}
