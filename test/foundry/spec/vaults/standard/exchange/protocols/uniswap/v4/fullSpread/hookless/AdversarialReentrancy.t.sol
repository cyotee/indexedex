// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {ReentrantERC20Harness} from "contracts/test/stubs/ReentrantERC20Harness.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.sol";

// tag::HooklessReentrancyTest[]
contract HooklessReentrancyTest is Acceptance {
    ReentrantERC20Harness internal hostileToken;

    function _deployTokenA() internal override returns (IERC20) {
        hostileToken = new ReentrantERC20Harness("Callback Token", "CB", 18);
        hostileToken.mint(address(this), 1e32);
        return IERC20(address(hostileToken));
    }

    function test_transferFromReentrancyCannotEnterMaintenance() public {
        _bootstrap();
        hostileToken.setReenter(address(vault), abi.encodeCall(Reserve.rebalanceLiquidReserve, ()));
        uint256 supply = vault.totalSupply();
        uint256 balance = hostileToken.balanceOf(address(this));
        vm.expectRevert(bytes("reenter-failed"));
        vault.exchangeIn(IERC20(address(hostileToken)), 1e18, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        assertEq(vault.totalSupply(), supply);
        assertEq(hostileToken.balanceOf(address(this)), balance);
        _assertBooked();
    }
}
// end::HooklessReentrancyTest[]
