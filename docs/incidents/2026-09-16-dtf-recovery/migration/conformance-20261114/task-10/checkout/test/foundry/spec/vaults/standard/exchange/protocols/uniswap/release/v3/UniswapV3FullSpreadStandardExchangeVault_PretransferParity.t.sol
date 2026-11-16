// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile_Test} from "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol";

contract UniswapV3FullSpreadStandardExchangeVault_PretransferParity_Test is UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile_Test {
    function test_atomicMintExactOutMatchesPullAndPriorPreview() public {
        _assertMintParity(false);
    }

    function test_atomicMintExactOutRefundsOnlyUnusedBoundedCredit() public {
        _assertMintParity(true);
    }

    function _assertMintParity(bool overpay_) internal {
        _dualJoin(1_000 ether, 1_000 ether);
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        IERC20 input = IERC20(_token0());
        uint256 sharesOut = IERC20(address(vault)).totalSupply() / 10;
        uint256 quoted = vault.previewExchangeOut(input, IERC20(address(vault)), sharesOut);
        assertGt(quoted, 0);
        uint256 credit = overpay_ ? quoted * 2 : quoted;
        ERC20PermitMintableStub(address(input)).mint(address(this), credit);
        input.approve(address(caller), credit);
        uint256 snapshot = vm.snapshotState();
        uint256 pullUsed = _executeExactOut(caller, input, sharesOut, quoted, false);
        assertEq(pullUsed, quoted, "pull positive control matches quote");
        assertEq(IERC20(address(vault)).balanceOf(address(caller)), sharesOut, "pull minted requested shares");
        assertTrue(vm.revertToState(snapshot));
        uint256 prepaidUsed = _executeExactOut(caller, input, sharesOut, credit, true);
        assertEq(prepaidUsed, pullUsed, "atomic pretransfer must not increase exact-out price");
        assertEq(IERC20(address(vault)).balanceOf(address(caller)), sharesOut, "pretransfer minted requested shares");
        assertEq(input.balanceOf(address(caller)), credit - quoted, "only unused bounded credit refunded");
    }

    function _executeExactOut(
        AtomicPretransferCaller caller_, IERC20 input_, uint256 sharesOut_, uint256 funding_, bool prepaid_
    ) internal returns (uint256) {
        bytes memory data = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (input_, funding_, IERC20(address(vault)), sharesOut_, address(caller_), prepaid_, _deadline())
        );
        bytes memory result = prepaid_
            ? caller_.consumePretransfer(input_, address(this), address(vault), funding_, data)
            : caller_.consumePull(input_, address(this), address(vault), funding_, data);
        return abi.decode(result, (uint256));
    }

}
