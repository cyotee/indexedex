// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {TestBase_MorphoBlueStandardExchange} from "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange.sol";

contract MorphoBlueStandardExchange_PretransferParity_Test is TestBase_MorphoBlueStandardExchange {
    function test_atomicExactInMatchesPullAndPriorPreview() public {
        _wrapExactIn(user, 100 ether);
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        vm.prank(attacker);
        loanToken.approve(address(caller), type(uint256).max);
        uint256 amount = 100 ether;
        uint256 quoted = seIn.previewExchangeIn(IERC20(address(loanToken)), amount, IERC20(se));
        uint256 snapshot = vm.snapshotState();
        uint256 pullShares = _executeExactIn(caller, amount, quoted, false);
        assertEq(pullShares, quoted, "pull positive control matches quote");
        assertTrue(vm.revertToState(snapshot));
        uint256 prepaidShares = _executeExactIn(caller, amount, 0, true);
        assertEq(prepaidShares, pullShares, "atomic pretransfer must not enter pre-deposit NAV");
        assertEq(IERC20(se).balanceOf(attacker), prepaidShares, "recipient received priced shares");
    }

    function test_atomicExactOutMatchesPullAndPriorPreview() public {
        _assertExactOutParity(false);
    }

    function test_atomicExactOutRefundsOnlyUnusedBoundedCredit() public {
        _assertExactOutParity(true);
    }

    function _assertExactOutParity(bool overpay_) internal {
        _wrapExactIn(user, 100 ether);
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        vm.prank(attacker);
        loanToken.approve(address(caller), type(uint256).max);
        uint256 sharesOut = 100 ether;
        uint256 quoted = seOut.previewExchangeOut(IERC20(address(loanToken)), IERC20(se), sharesOut);
        uint256 credit = overpay_ ? quoted * 2 : quoted;
        uint256 snapshot = vm.snapshotState();
        uint256 pullUsed = _executeExactOut(caller, sharesOut, quoted, false);
        assertEq(pullUsed, quoted, "pull positive control matches quote");
        assertTrue(vm.revertToState(snapshot));
        uint256 prepaidUsed = _executeExactOut(caller, sharesOut, credit, true);
        assertEq(prepaidUsed, pullUsed, "atomic pretransfer must consume prior quote");
        assertEq(IERC20(se).balanceOf(attacker), sharesOut, "recipient received requested shares");
        assertEq(loanToken.balanceOf(address(caller)), credit - quoted, "only unused bounded credit refunded");
    }

    function _executeExactIn(
        AtomicPretransferCaller caller_, uint256 amount_, uint256 minimum_, bool prepaid_
    ) internal returns (uint256) {
        bytes memory data = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (IERC20(address(loanToken)), amount_, IERC20(se), minimum_, attacker, prepaid_, _deadline())
        );
        return _fundAndCall(caller_, amount_, prepaid_, data);
    }

    function _executeExactOut(
        AtomicPretransferCaller caller_, uint256 sharesOut_, uint256 funding_, bool prepaid_
    ) internal returns (uint256) {
        bytes memory data = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (IERC20(address(loanToken)), funding_, IERC20(se), sharesOut_, attacker, prepaid_, _deadline())
        );
        return _fundAndCall(caller_, funding_, prepaid_, data);
    }

    function _fundAndCall(AtomicPretransferCaller caller_, uint256 funding_, bool prepaid_, bytes memory data_)
        internal returns (uint256)
    {
        bytes memory result = prepaid_
            ? caller_.consumePretransfer(IERC20(address(loanToken)), attacker, se, funding_, data_)
            : caller_.consumePull(IERC20(address(loanToken)), attacker, se, funding_, data_);
        return abi.decode(result, (uint256));
    }

}
