// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";

// tag::HooklessEquivalentInterfacesTest[]
contract HooklessEquivalentInterfacesTest is Acceptance {
    function test_SYDepositMatchesExchangeAndEntireBook() public {
        _bootstrap();
        uint256 snapshot = vm.snapshotState();
        uint256 standard = vault.exchangeIn(token0, 1e18, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        bytes32 standardBook = _bookHash();
        assertTrue(vm.revertToStateAndDelete(snapshot));
        uint256 sy = IStandardizedYield(address(vault)).deposit(address(this), address(token0), 1e18, 0);
        assertEq(sy, standard);
        assertEq(_bookHash(), standardBook);
        _assertBooked();
    }

    function test_SYRedeemExternalMatchesExchangeAndEntireBook() public {
        _bootstrap();
        uint256 snapshot = vm.snapshotState();
        uint256 standard = vault.exchangeIn(IERC20(address(vault)), 1e18, token0, 0, address(this), false, block.timestamp);
        bytes32 standardBook = _bookHash();
        assertTrue(vm.revertToStateAndDelete(snapshot));
        uint256 sy = IStandardizedYield(address(vault)).redeem(address(this), 1e18, address(token0), 0, false);
        assertEq(sy, standard);
        assertEq(_bookHash(), standardBook);
        _assertBooked();
    }

    function test_SYInternalBalanceBurnsExactlyOnce() public {
        _bootstrap();
        uint256 supply = vault.totalSupply();
        uint256 quote = vault.previewExchangeIn(IERC20(address(vault)), 1e18, token1);
        vault.transfer(address(vault), 1e18);
        assertEq(IStandardizedYield(address(vault)).redeem(address(this), 1e18, address(token1), quote, true), quote);
        assertEq(vault.totalSupply(), supply - 1e18);
        assertEq(vault.balanceOf(address(vault)), 0);
        _assertBooked();
    }

    function _bookHash() internal view returns (bytes32) {
        (bytes memory state,) = Transition(address(vault)).quoteState(address(token0), address(this));
        return keccak256(abi.encode(state, token0.balanceOf(address(this)), token1.balanceOf(address(this)),
            vault.reserveOfToken(address(token0)), vault.reserveOfToken(address(token1)), vault.reserveOfToken(address(vault))));
    }
}
// end::HooklessEquivalentInterfacesTest[]
