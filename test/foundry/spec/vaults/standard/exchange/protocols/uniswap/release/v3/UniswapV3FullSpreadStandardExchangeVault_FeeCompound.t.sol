// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FullSpreadReleaseFixture} from "./harness/FullSpreadReleaseFixture.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @notice D27 migrated to V3-ACC-09/11/20: fees are booked once, outside mint liquidity.
contract UniswapV3FullSpreadStandardExchangeVault_FeeCompound_Test is FullSpreadReleaseFixture {
    function test_outsidePoolTrade_refreshesEconomicReservesWithoutMinting() public {
        _join(200 ether, 200 ether);
        uint256 beforeReserve0 = vault.reserveOfToken(address(token0));
        uint256 beforeReserve1 = vault.reserveOfToken(address(token1));
        uint256 supply = vault.totalSupply();
        _externalSwapExactIn(pool, true, 50_000 ether);
        _assertReserves();
        assertTrue(vault.reserveOfToken(address(token0)) != beforeReserve0 ||
            vault.reserveOfToken(address(token1)) != beforeReserve1, "economic reserves follow the position");
        assertEq(vault.totalSupply(), supply);
        uint128 liquidity = _liquidity();
        (uint256 quote,) = vault.previewExchangeIn(token0, 1 ether, IERC20(address(vault)));
        (uint256 minted,) = _mintOne(token0, 1 ether, alice);
        assertEq(minted, quote);
        assertEq(minted, uint256(_liquidity() - liquidity) * supply / liquidity);
    }

    function test_d27_subsequentTinyZap_booksFeesWithoutCreditingNewDepositor() public {
        uint256 incumbent = _join(200 ether, 200 ether);
        _externalSwapExactIn(pool, true, 50_000 ether);
        _externalSwapExactIn(pool, false, 50_000 ether);
        uint256 supply = vault.totalSupply();
        uint128 liquidity = _liquidity();
        uint256 snap = vm.snapshotState();
        _externalSwapExactIn(pool, true, uint256(1 ether) * 49 / 100);
        (uint256 collected0, uint256 collected1) = _fees();
        assertGt(collected0 + collected1, 0);
        assertTrue(vm.revertToState(snap));
        (uint256 issued,) = _mintOne(token0, 1 ether, bob);
        assertGt(issued, 0);
        assertEq(issued, uint256(_liquidity() - liquidity) * supply / liquidity);
        assertEq(vault.balanceOf(address(this)), incumbent);
        assertEq(token0.balanceOf(address(vault)), collected0);
        assertEq(token1.balanceOf(address(vault)), collected1);
        _assertReserves();
        uint256 shares = incumbent / 3;
        uint256 enlarged = vault.totalSupply();
        assertEq(enlarged, supply + issued);
        assertLt(collected0 * shares / enlarged, collected0 * shares / supply, "copied mint dilutes booked claim per share");
        uint128 removed = uint128(uint256(_liquidity()) * shares / enlarged);
        (uint256 principal0, uint256 principal1) = _principal(removed);
        uint256[] memory paid = _bundleExit(shares);
        assertEq(paid[0], principal0 + collected0 * shares / enlarged);
        assertEq(paid[1], principal1 + collected1 * shares / enlarged);
        assertEq(token0.balanceOf(address(vault)), collected0 - collected0 * shares / enlarged);
        assertEq(token1.balanceOf(address(vault)), collected1 - collected1 * shares / enlarged);
    }
}
