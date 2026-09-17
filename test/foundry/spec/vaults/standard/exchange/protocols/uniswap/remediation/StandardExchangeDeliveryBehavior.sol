// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {StandardExchangeLockedCaller} from "./StandardExchangeLockedCaller.sol";
import {DeliveryTestToken} from "./DeliveryTestToken.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

/// @dev K1 live-book unsolicited donation is deferred as donor loss (D9).
// The same assertions run against independently deployed V3 and V4 diamonds.
abstract contract StandardExchangeDeliveryBehavior is Test {
    StandardExchangeLockedCaller internal lockedCaller;
    IStandardExchangeProxy internal subject;
    IERC20 internal asset0;
    IERC20 internal asset1;
    address internal constant FALSE_DEPOSITOR = address(0xBAD);

    function _trade(bool zeroForOne, uint256 amount) internal virtual;
    function _deployed() internal view virtual returns (uint256, uint256);
    function _rebalance() internal virtual;

    function _fund(IERC20 token, address recipient, uint256 amount) internal virtual {
        ERC20PermitMintableStub(address(token)).mint(recipient, amount);
    }

    function _bootstrap() internal {
        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = address(asset0); tokens[1] = address(asset1);
        amounts[0] = 1000 ether; amounts[1] = 1000 ether;
        _fund(asset0, address(this), amounts[0]);
        _fund(asset1, address(this), amounts[1]);
        asset0.approve(address(subject), amounts[0]);
        asset1.approve(address(subject), amounts[1]);
        IStandardExchangeInMulti(address(subject)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(subject)), 0, address(this), false, block.timestamp
        );
        (uint256 deployed0, uint256 deployed1) = _deployed();
        assertGt(deployed0, 0, "armed token0 position");
        assertGt(deployed1, 0, "armed token1 position");
        assertGt(asset0.balanceOf(address(subject)), 0, "token0 sleeve");
        assertGt(asset1.balanceOf(address(subject)), 0, "token1 sleeve");
    }

    function _depositCall(IERC20 token, uint256 amount, address recipient) internal view returns (bytes memory) {
        return abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (token, amount, IERC20(address(subject)), 0, recipient, true, block.timestamp));
    }



    function _deliveryError(uint256 required, uint256 delivered) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, required, delivered);
    }

    function _noDelivery(bytes memory data) internal view returns (bytes memory) {
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        bytes memory args = new bytes(data.length - 4);
        for (uint256 i; i < args.length; ++i) args[i] = data[i + 4];
        uint256 used;
        if (selector == IStandardExchangeIn.exchangeIn.selector) {
            (, used,,,,,) = abi.decode(args, (IERC20,uint256,IERC20,uint256,address,bool,uint256));
        } else if (selector == IStandardExchangeOut.exchangeOut.selector) {
            (IERC20 input,, IERC20 output, uint256 amount,,,) = abi.decode(args, (IERC20,uint256,IERC20,uint256,address,bool,uint256));
            used = subject.previewExchangeOut(input, output, amount);
        } else if (selector == IStandardExchangeInMulti.exchangeInManyToOne.selector) {
            (,uint256[] memory amounts,,,,,) = abi.decode(args, (address[],uint256[],IERC20,uint256,address,bool,uint256));
            used = amounts[0];
        } else {
            (IERC20 input,,address[] memory outputs,uint256[] memory amounts,,,) = abi.decode(args, (IERC20,uint256,address[],uint256[],address,bool,uint256));
            used = IStandardExchangeOutMulti(address(subject)).previewExchangeOutOneToMany(input, outputs, amounts);
        }
        return _deliveryError(used, 0);
    }

    function _execute(bytes memory data) internal returns (uint256 result) {
        (bool success, bytes memory returned) = address(subject).call(data);
        if (!success) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        result = abi.decode(returned, (uint256));
    }

    function _reject(bytes memory data, bytes memory expected) internal {
        uint256 supply = subject.totalSupply();
        uint256 balance0 = asset0.balanceOf(address(subject));
        uint256 balance1 = asset1.balanceOf(address(subject));
        uint256 holder = subject.balanceOf(address(this));
        uint256 selfShares = subject.balanceOf(address(subject));
        uint256 book0 = subject.reserveOfToken(address(asset0));
        uint256 book1 = subject.reserveOfToken(address(asset1));
        uint256 bookShares = subject.reserveOfToken(address(subject));
        (bool success, bytes memory returned) = address(subject).call(data);
        assertFalse(success, "unfunded/invalid operation succeeded");
        assertEq(returned, expected, "specific delivery error");
        assertEq(subject.totalSupply(), supply, "supply unchanged");
        assertEq(subject.balanceOf(address(this)), holder, "holder shares unchanged");
        assertEq(asset0.balanceOf(address(subject)), balance0, "token0 unchanged");
        assertEq(asset1.balanceOf(address(subject)), balance1, "token1 unchanged");
        assertEq(subject.balanceOf(address(subject)), selfShares, "self shares unchanged");
        assertEq(subject.reserveOfToken(address(asset0)), book0, "token0 book unchanged");
        assertEq(subject.reserveOfToken(address(asset1)), book1, "token1 book unchanged");
        assertEq(subject.reserveOfToken(address(subject)), bookShares, "share book unchanged");
    }

    function test_priceMoveCannotCreditPhantomDeposit_token0() public { _falseDeposit(true); }
    function test_priceMoveCannotCreditPhantomDeposit_token1() public { _falseDeposit(false); }

    function _falseDeposit(bool zeroForOne) internal {
        _bootstrap();
        (uint256 before0, uint256 before1) = _deployed();
        _trade(zeroForOne, 100 ether);
        (uint256 after0, uint256 after1) = _deployed();
        assertGt(zeroForOne ? after0 : after1, zeroForOne ? before0 : before1, "real price movement");
        IERC20 token = zeroForOne ? asset0 : asset1;
        assertEq(token.balanceOf(FALSE_DEPOSITOR), 0);
        bytes memory data = _depositCall(token, 25 ether, FALSE_DEPOSITOR);
        vm.startPrank(FALSE_DEPOSITOR);
        _reject(data, _noDelivery(data));

        _reject(data, _deliveryError(25 ether, 0));
        vm.stopPrank();
        assertEq(subject.balanceOf(FALSE_DEPOSITOR), 0);
        assertEq(token.balanceOf(FALSE_DEPOSITOR), 0);
    }

    function test_pullAndPushedDepositsAfterPriceMovement() public {
        _bootstrap(); _trade(true, 100 ether);
        _fund(asset0, address(this), 40 ether);
        asset0.approve(address(subject), 20 ether);
        uint256 pulled = subject.exchangeIn(asset0, 20 ether, IERC20(address(subject)), 0, address(this), false, block.timestamp);
        assertGt(pulled, 0);
        bytes memory data = _depositCall(asset0, 20 ether, address(this));

        asset0.transfer(address(subject), 20 ether);
        assertGt(_execute(data), 0);
        _reject(data, _noDelivery(data));
        assertEq(asset0.balanceOf(address(this)), 0, "only actual tokens credited");
    }



    function test_shortPushedTransferRejected() public { _wrongTransfer(24 ether); }
    function test_excessPushedTransferRejected() public { _wrongTransfer(26 ether); }
    function _wrongTransfer(uint256 delivered) internal {
        _bootstrap();
        bytes memory data = _depositCall(asset0, 25 ether, address(this));

        _fund(asset0, address(this), delivered);
        asset0.transfer(address(subject), delivered);
        _reject(data, _deliveryError(25 ether, delivered));
    }

    function test_fundedCallerMaySelectRecipient() public {
        _bootstrap();
        _fund(asset0, address(this), 25 ether);
        asset0.transfer(address(subject), 25 ether);
        vm.prank(FALSE_DEPOSITOR);
        uint256 minted = _execute(_depositCall(asset0, 25 ether, address(this)));
        assertGt(minted, 0);
        assertEq(subject.balanceOf(FALSE_DEPOSITOR), 0);
    }

    function test_rebalanceCannotCreatePushedCredit() public {
        _bootstrap(); _trade(true, 100 ether);
        bytes memory data = _depositCall(asset0, 25 ether, address(this));

        _rebalance();
        _reject(data, _deliveryError(25 ether, 0));
    }

    function test_pushedMultiDepositAndMissingSecondToken() public {
        _bootstrap(); _trade(false, 100 ether);
        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = address(asset0); tokens[1] = address(asset1);
        amounts[0] = 10 ether; amounts[1] = 10 ether;
        bytes memory data = abi.encodeCall(IStandardExchangeInMulti.exchangeInManyToOne,
            (tokens, amounts, IERC20(address(subject)), 0, address(this), true, block.timestamp));

        _fund(asset0, address(this), 10 ether); asset0.transfer(address(subject), 10 ether);
        _reject(data, _deliveryError(10 ether, 0));
        _fund(asset1, address(this), 10 ether); asset1.transfer(address(subject), 10 ether);
        assertGt(_execute(data), 0);
        _reject(data, _noDelivery(data));
    }

    function test_unpushedDirectSwapAndExactOutputRejected() public {
        _bootstrap(); _trade(true, 100 ether);
        bytes memory exactIn = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (asset0, 25 ether, asset1, 0, FALSE_DEPOSITOR, true, block.timestamp));
        _reject(exactIn, _noDelivery(exactIn));
        bytes memory exactOut = abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (asset0, 25 ether, asset1, 1 ether, FALSE_DEPOSITOR, true, block.timestamp));
        _reject(exactOut, _noDelivery(exactOut));
    }

    function test_pushedExactOutputRefundOnlyUnusedInput() public {
        _bootstrap(); _trade(true, 100 ether);
        bytes memory data = abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (asset0, 25 ether, asset1, 1 ether, address(this), true, block.timestamp));

        _fund(asset0, address(this), 25 ether); asset0.transfer(address(subject), 25 ether);
        uint256 used = _execute(data);
        assertGt(used, 0); assertLt(used, 25 ether);
        assertEq(asset0.balanceOf(address(this)), 25 ether - used, "exact per-call refund");
        assertGe(asset1.balanceOf(address(this)), 1 ether, "requested output");
        _reject(data, _noDelivery(data));
    }

    function test_pushedSharesRedeemAndCannotReplay() public {
        _bootstrap();
        uint256 shares = subject.balanceOf(address(this)) / 10;
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(subject)), shares, asset1, 0, address(this), true, block.timestamp));

        subject.transfer(address(subject), shares);
        assertGt(_execute(data), 0);
        _reject(data, _noDelivery(data));
        assertEq(subject.balanceOf(address(subject)), 0);
    }

    function test_bookedSharesCannotBeClaimed() public {
        _bootstrap();
        uint256 shares = subject.balanceOf(address(this)) / 10;
        subject.transfer(address(subject), shares);
        _rebalance(); // Book shares before the unfunded probe.
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(subject)), shares, asset1, 0, FALSE_DEPOSITOR, true, block.timestamp));
        _reject(data, _noDelivery(data));

        _reject(data, _deliveryError(shares, 0));
    }

    function test_proxyRemovedPreparationSurface() public {
        bytes4 selector = bytes4(keccak256("preparePretransfer(address[],uint256[],bytes32)"));
        assertEq(IDiamondLoupe(address(subject)).facetAddress(selector), address(0));
        assertFalse(IERC165(address(subject)).supportsInterface(selector));
        _reject(abi.encodeWithSelector(selector, new address[](0), new uint256[](0), bytes32(0)),
            abi.encodeWithSelector(Proxy.NoTargetFor.selector, selector));
        assertEq(subject.decimals(), 18);
    }

    function testFuzz_noPhantomCreditAfterTrade(bool zeroForOne, uint96 tradeSize) public {
        _bootstrap();
        _trade(zeroForOne, bound(uint256(tradeSize), 1e12, 500 ether));
        IERC20 token = zeroForOne ? asset0 : asset1;
        _reject(_depositCall(token, 1 ether, FALSE_DEPOSITOR), _deliveryError(1 ether, 0));
    }

    function _locked(bytes memory data, IERC20 token, uint256 amount) internal returns (uint256) {
        address[] memory tokens = new address[](amount == 0 ? 0 : 1);
        uint256[] memory amounts = new uint256[](tokens.length);
        if (amount != 0) { tokens[0] = address(token); amounts[0] = amount; }
        return lockedCaller.run(address(subject), data, tokens, amounts);
    }

    function test_lockedPushedDeposit() public {
        _bootstrap();
        _fund(asset0, address(lockedCaller), 20 ether);
        uint256 beforeShares = subject.balanceOf(address(this));
        uint256 minted = _locked(_depositCall(asset0, 20 ether, address(this)), asset0, 20 ether);
        assertGt(minted, 0);
        assertEq(subject.balanceOf(address(this)), beforeShares + minted);
        _rebalance();
    }

    function test_lockedExitSettlesBothEntitlements() public {
        _bootstrap();
        uint256 shares = subject.totalSupply() / 10;
        bytes memory quoteData = abi.encodeCall(IStandardExchangeIn.previewExchangeIn,
            (IERC20(address(subject)), shares, asset1));
        uint256 quoted = _locked(quoteData, asset0, 0);
        // Independent reference: remove (100,100), then exchange the 100 other
        // tokens against (900,900): 100 + 900*100/(900+100) = 190.
        assertApproxEqAbs(quoted, 190 ether, 5);
        subject.transfer(address(lockedCaller), shares);
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(subject)), shares, asset1, quoted, address(this), true, block.timestamp));
        assertEq(_locked(data, IERC20(address(subject)), shares), quoted);
        assertEq(asset1.balanceOf(address(this)), quoted);
        assertEq(subject.balanceOf(address(subject)), 0);
    }

    function test_lockedExactOutputRefundsPushedShares() public {
        _bootstrap();
        uint256 maximum = subject.totalSupply() / 10;
        bytes memory quoteData = abi.encodeCall(IStandardExchangeOut.previewExchangeOut,
            (IERC20(address(subject)), asset1, 19 ether));
        uint256 quoted = _locked(quoteData, asset0, 0);
        assertGt(quoted, 0); assertLt(quoted, maximum);
        subject.transfer(address(lockedCaller), maximum);
        bytes memory data = abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (IERC20(address(subject)), maximum, asset1, 19 ether, address(this), true, block.timestamp));
        assertEq(_locked(data, IERC20(address(subject)), maximum), quoted);
        assertEq(asset1.balanceOf(address(this)), 19 ether);
        assertEq(subject.balanceOf(address(lockedCaller)), maximum - quoted);
        assertEq(subject.balanceOf(address(subject)), 0);
    }

    function test_pushedExactOutputShareWithdrawal() public {
        _bootstrap();
        uint256 maximum = subject.totalSupply() / 10;
        bytes memory data = abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (IERC20(address(subject)), maximum, asset1, 10 ether, address(this), true, block.timestamp));

        subject.transfer(address(subject), maximum);
        uint256 used = _execute(data);
        assertGt(used, 0); assertLt(used, maximum);
        assertGe(asset1.balanceOf(address(this)), 10 ether);
        assertEq(subject.balanceOf(address(subject)), 0, "unused shares refunded");
        assertEq(subject.balanceOf(address(this)) + subject.balanceOf(address(0xdEaD)), subject.totalSupply());
    }

    function test_failedRouteRollsBackCreditAndCanRetry() public {
        _bootstrap();
        bytes memory data = _depositCall(asset0, 20 ether, address(this));

        _fund(asset0, address(this), 19 ether); asset0.transfer(address(subject), 19 ether);
        _reject(data, _deliveryError(20 ether, 19 ether));
        _fund(asset0, address(this), 1 ether); asset0.transfer(address(subject), 1 ether);
        assertGt(_execute(data), 0);
    }

    function test_feeOnTransferInputRejectedAndRolledBack() public {
        _bootstrap();
        DeliveryTestToken token = DeliveryTestToken(address(asset1));
        token.setFee(true);
        _fund(asset1, address(this), 100 ether);
        asset1.approve(address(subject), 100 ether);
        uint256 supply = subject.totalSupply();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 100 ether, 99 ether));
        subject.exchangeIn(asset1, 100 ether, IERC20(address(subject)), 0, address(this), false, block.timestamp);
        assertEq(subject.totalSupply(), supply);
        assertEq(asset1.balanceOf(address(this)), 100 ether);
    }

    function test_transferCallbackCannotReenter() public {
        _bootstrap();
        DeliveryTestToken token = DeliveryTestToken(address(asset1));
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(asset1); amounts[0] = 10 ether;
        bytes memory reentry = _depositCall(asset1, 10 ether, FALSE_DEPOSITOR);
        token.setCallback(address(subject), reentry);
        _fund(asset1, address(this), 10 ether);
        asset1.approve(address(subject), 10 ether);
        assertGt(subject.exchangeIn(asset1, 10 ether, IERC20(address(subject)), 0, address(this), false, block.timestamp), 0);
        assertEq(token.callbackError(), abi.encodeWithSelector(IReentrancyLock.IsLocked.selector));
        assertEq(subject.balanceOf(FALSE_DEPOSITOR), 0);
    }



    function test_noPositionNoMovementDoesNotEnableUnpushedInput() public {
        _rebalance();
        _reject(_depositCall(asset0, 10 ether, FALSE_DEPOSITOR), _deliveryError(10 ether, 0));
    }

    function test_pushedDualWithdrawalRefundsOnlyDeliveredShares() public {
        _bootstrap();
        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = address(asset0); tokens[1] = address(asset1);
        amounts[0] = 1 ether; amounts[1] = 1 ether;
        uint256 maximum = subject.totalSupply() / 10;
        bytes memory data = abi.encodeCall(IStandardExchangeOutMulti.exchangeOutOneToMany,
            (IERC20(address(subject)), maximum, tokens, amounts, address(this), true, block.timestamp));
        _reject(data, _noDelivery(data));

        subject.transfer(address(subject), maximum);
        uint256 used = _execute(data);
        assertGt(used, 0); assertLt(used, maximum);
        assertEq(asset0.balanceOf(address(this)), 1 ether);
        assertEq(asset1.balanceOf(address(this)), 1 ether);
        assertEq(subject.balanceOf(address(subject)), 0);
        _reject(data, _noDelivery(data));
    }

    function test_pushedDirectExactInputSwap() public {
        _bootstrap(); _trade(true, 100 ether);
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (asset0, 10 ether, asset1, 0, address(this), true, block.timestamp));

        _fund(asset0, address(this), 10 ether); asset0.transfer(address(subject), 10 ether);
        uint256 received = _execute(data);
        assertGt(received, 0);
        assertEq(asset1.balanceOf(address(this)), received);
        _reject(data, _noDelivery(data));
    }
}
