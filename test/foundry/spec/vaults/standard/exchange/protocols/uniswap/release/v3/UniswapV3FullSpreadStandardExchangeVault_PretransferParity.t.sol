// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile_Test as Fixture} from "./UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

/// @notice V3-ACC-10: pull and atomic pretransfer use the same declared exact-input budget.
contract UniswapV3FullSpreadStandardExchangeVault_PretransferParity_Test is Fixture {
    function test_atomicMintExactInMatchesPullAndPriorPreview() public { _assertMintParity(false); }
    function test_atomicMintExactInRefundsOnlyUnusedDeclaredCredit() public { _assertMintParity(true); }

    function _assertMintParity(bool overpay) internal {
        _join(1000 ether, 1000 ether);
        AtomicPretransferCaller wallet = new AtomicPretransferCaller();
        uint256 declared = 10 ether;
        uint256 delivered = overpay ? 20 ether : declared;
        _fund(token0, address(this), delivered);
        token0.approve(address(wallet), delivered);
        (uint256 quoted,) = vault.previewExchangeIn(token0, declared, IERC20(address(vault)));
        assertGt(quoted, 0);
        uint256 snap = vm.snapshotState();
        (uint256 pulled, uint256 pullRefund) = abi.decode(wallet.consumePull(token0, address(this), address(vault), declared,
            _route(address(wallet), declared, false)), (uint256, uint256));
        uint256 held = token0.balanceOf(address(vault));
        assertEq(pulled, quoted);
        assertEq(token0.balanceOf(address(wallet)), pullRefund);
        assertTrue(vm.revertToState(snap));
        (uint256 prepaid, uint256 refund) = abi.decode(wallet.consumePretransfer(token0, address(this), address(vault), delivered,
            _route(address(wallet), declared, true)), (uint256, uint256));
        assertEq(prepaid, pulled);
        assertEq(refund, pullRefund);
        assertEq(vault.balanceOf(address(wallet)), quoted);
        assertEq(token0.balanceOf(address(wallet)), refund, "refund excludes excess outside the declaration");
        assertEq(token0.balanceOf(address(vault)), held + delivered - declared);
    }

    function _route(address recipient, uint256 amount, bool prepaid) private view returns (bytes memory) {
        return abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (token0, amount, IERC20(address(vault)), uint256(0), recipient, prepaid, block.timestamp));
    }
}
