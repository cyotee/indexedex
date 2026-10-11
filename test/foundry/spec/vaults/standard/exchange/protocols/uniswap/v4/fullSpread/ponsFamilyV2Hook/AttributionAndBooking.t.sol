// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookAttributionAndBookingTest[]
contract UniswapV4FullSpreadPonsFamilyHookAttributionAndBookingTest is Acceptance {
    function test_pretransferUnderclaimAbsorbsUnclaimedSurplusWithoutRefund() public {
        _bootstrap();
        token0.transfer(address(vault), 1e18);
        uint256 expected = vault.previewExchangeIn(token0, 1e18, IERC20(address(vault)));
        token0.transfer(address(vault), 1e18);
        uint256 beforeBalance = token0.balanceOf(address(this));
        assertEq(vault.exchangeIn(token0, 1e18, IERC20(address(vault)), expected, address(this), true, block.timestamp), expected);
        assertEq(token0.balanceOf(address(this)), beforeBalance);
        _assertBooked();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e18, 0));
        vault.exchangeIn(token0, 1e18, IERC20(address(vault)), 0, address(this), true, block.timestamp);
    }

    function test_priorFeesIncludedOnceAndNotCallerCredit() public {
        _bootstrap();
        _externalSwap(true, 100e18);
        // Pons has no swap LP fee. A real core donation supplies earned position
        // growth so this test still exercises E->F attribution rather than zero E.
        _donate(10e18, 10e18);
        uint256 expected = vault.previewExchangeIn(token1, 1e18, IERC20(address(vault)));
        assertEq(vault.exchangeIn(token1, 1e18, IERC20(address(vault)), expected, address(this), false, block.timestamp), expected);
        _assertBooked();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1, 0));
        vault.exchangeIn(token0, 1, IERC20(address(vault)), 0, address(this), true, block.timestamp);
    }

    function test_outsidePoolTradeDoesNotRefreshVaultBook() public {
        _bootstrap();
        uint256 book0 = IBasicVault(address(vault)).reserveOfToken(address(token0));
        uint256 book1 = IBasicVault(address(vault)).reserveOfToken(address(token1));
        uint256 supply = IERC20(address(vault)).totalSupply();
        _externalSwap(false, 100e18);
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(token0)), book0, "outside trade leaves token0 book unchanged");
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(token1)), book1, "outside trade leaves token1 book unchanged");
        assertEq(IERC20(address(vault)).totalSupply(), supply, "outside trade mints no shares");
        uint256 beforeShares = IERC20(address(vault)).balanceOf(address(this));
        uint256 preview = vault.previewExchangeIn(token1, 1e18, IERC20(address(vault)));
        uint256 minted = vault.exchangeIn(token1, 1e18, IERC20(address(vault)), preview, address(this), false, block.timestamp);
        assertEq(minted, preview, "later deposit credits only the funded input");
        assertEq(IERC20(address(vault)).balanceOf(address(this)) - beforeShares, minted, "caller receives only the funded credit");
        _assertBooked();
    }

    function test_poolRepricingDoesNotCreatePretransferCredit() public {
        _bootstrap();
        _externalSwap(false, 100e18);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1, 0));
        vault.exchangeIn(token0, 1, IERC20(address(vault)), 0, address(this), true, block.timestamp);
    }

    function test_pullAndPushProduceIdenticalMintAndCustody() public {
        _bootstrap();
        uint256 snapshot = vm.snapshotState();
        uint256 pulled = vault.exchangeIn(token0, 1e18, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        uint256 free0 = token0.balanceOf(address(vault));
        uint256 free1 = token1.balanceOf(address(vault));
        assertTrue(vm.revertToStateAndDelete(snapshot));
        token0.transfer(address(vault), 1e18);
        assertEq(vault.exchangeIn(token0, 1e18, IERC20(address(vault)), 0, address(this), true, block.timestamp), pulled);
        assertEq(token0.balanceOf(address(vault)), free0);
        assertEq(token1.balanceOf(address(vault)), free1);
        _assertBooked();
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookAttributionAndBookingTest[]
