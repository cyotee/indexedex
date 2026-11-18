// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FullSpreadReleaseFixture} from "./harness/FullSpreadReleaseFixture.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

/// @notice R3.3 migrated to V3-ACC-09/11: deployed reserves and booked custody are distinct.
contract UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile_Test is FullSpreadReleaseFixture {
    function test_R3_3_deployedReserves_afterDeposit() public {
        _join(1_000_000 ether, 1_000_000 ether);
        _assertReserves();
        (uint256 p0, uint256 p1) = _principal(_liquidity());
        assertEq(vault.reserveOfToken(address(token0)), p0);
        assertEq(vault.reserveOfToken(address(token1)), p1);
        assertEq(vault.reserveOfToken(address(0x1234)), 0);
        assertEq(token0.balanceOf(address(vault)), 0, "proportional join retains no sleeve");
        assertEq(token1.balanceOf(address(vault)), 0);
    }

    function test_R3_3_liquidReserveConfiguration_doesNotChangeAccounting() public {
        uint256 snap = vm.snapshotState();
        uint256 expected = _join(1000 ether, 1000 ether);
        uint128 expectedLiquidity = _liquidity();
        assertTrue(vm.revertToState(snap));
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(address(vault), 1e18);
        assertEq(_join(1000 ether, 1000 ether), expected);
        assertEq(_liquidity(), expectedLiquidity, "there is no sleeve target");
        _assertReserves();
    }

    function test_R3_3_feesThenTrade_bookingStaysConsistent() public {
        _join(1000 ether, 1000 ether);
        _externalSwapExactIn(pool, true, 50_000 ether);
        _externalSwapExactIn(pool, false, 50_000 ether);
        (uint256 fees0, uint256 fees1) = _fees();
        assertGt(fees0 + fees1, 0);
        _assertReserves();
        _join(10 ether, 10 ether);
        (uint256 unpaid0, uint256 unpaid1) = _fees();
        assertEq(unpaid0, 0);
        assertEq(unpaid1, 0);
        assertEq(token0.balanceOf(address(vault)), fees0);
        assertEq(token1.balanceOf(address(vault)), fees1);
        _assertReserves();
        for (uint256 i; i < 2; ++i) _assertNoDeliveryThenFunded(i == 0 ? token0 : token1);
    }

    function _assertNoDeliveryThenFunded(IERC20 input) internal {
        AtomicPretransferCaller wallet = new AtomicPretransferCaller();
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (input, uint256(1 ether), IERC20(address(vault)), uint256(1), address(wallet), true, block.timestamp));
        bytes32 beforeState = _state(address(wallet));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, 1, 0));
        wallet.execute(address(vault), data);
        assertEq(_state(address(wallet)), beforeState, "booked fees are not unfunded credit");
        _fund(input, address(this), 1 ether);
        input.approve(address(wallet), 1 ether);
        (uint256 quoted,) = vault.previewExchangeIn(input, 1 ether, IERC20(address(vault)));
        (uint256 shares, uint256 refund) = abi.decode(wallet.consumePretransfer(input, address(this), address(vault), 1 ether, data), (uint256, uint256));
        assertGt(quoted, 0);
        assertEq(shares, quoted);
        assertEq(vault.balanceOf(address(wallet)), shares);
        assertEq(input.balanceOf(address(wallet)), refund);
        _assertReserves();
    }
}
