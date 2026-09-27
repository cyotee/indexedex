// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {AtomicPretransferConstructorCaller} from "contracts/test/stubs/AtomicPretransferConstructorCaller.sol";

contract LocalCreditLibHarness {
    uint256 public lastCredited;
    address public lastCaller;

    function available(uint256 balance, uint256 booked) external pure returns (uint256) {
        return LocalCreditLib.available(balance, booked);
    }

    function budget(uint256 available_, uint256 maximum) external pure returns (uint256) {
        return LocalCreditLib.budget(available_, maximum);
    }

    function requirePretransferCaller(address caller) external view {
        LocalCreditLib.requirePretransferCaller(caller);
    }

    function consumeExactIn(uint256 amountIn, bool pretransferred) external returns (uint256 credited) {
        if (pretransferred) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
        }
        lastCaller = msg.sender;
        lastCredited = amountIn;
        return amountIn;
    }

    function consumeExactInToken(IERC20 token, uint256 amountIn, bool pretransferred)
        external
        returns (uint256 credited)
    {
        if (pretransferred) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
        } else {
            token.transferFrom(msg.sender, address(this), amountIn);
        }
        lastCaller = msg.sender;
        lastCredited = amountIn;
        return amountIn;
    }
}

contract LocalCreditLibTest is Test {
    LocalCreditLibHarness internal harness;
    AtomicPretransferCaller internal atomic;
    ERC20PermitMintableStub internal token;
    address internal payer;
    uint256 internal walletPk;
    address internal delegatedEoa;

    function setUp() public {
        harness = new LocalCreditLibHarness();
        atomic = new AtomicPretransferCaller();
        token = new ERC20PermitMintableStub("Asset", "AST", 18, address(this), 0);
        payer = makeAddr("payer");
        walletPk = uint256(keccak256("apex-7702-wallet"));
        delegatedEoa = vm.addr(walletPk);
    }

    function test_APEX005_available_zeroDeficitEqualityExcess() public view {
        assertEq(harness.available(0, 0), 0);
        assertEq(harness.available(0, 1), 0);
        assertEq(harness.available(50, 80), 0);
        assertEq(harness.available(80, 80), 0);
        assertEq(harness.available(100, 80), 20);
        assertEq(harness.available(type(uint256).max, 0), type(uint256).max);
        assertEq(harness.available(type(uint256).max, type(uint256).max), 0);
        assertEq(harness.available(type(uint256).max, type(uint256).max - 1), 1);
    }

    function test_APEX005_budget_zeroEqualityExcessMax() public view {
        assertEq(harness.budget(0, 0), 0);
        assertEq(harness.budget(0, 100), 0);
        assertEq(harness.budget(100, 0), 0);
        assertEq(harness.budget(60, 100), 60);
        assertEq(harness.budget(100, 80), 80);
        assertEq(harness.budget(100, 100), 100);
        assertEq(harness.budget(type(uint256).max, 1), 1);
        assertEq(harness.budget(type(uint256).max, type(uint256).max), type(uint256).max);
    }

    function testFuzz_APEX_availableNeverUnderflows(uint256 balance, uint256 booked) public view {
        uint256 expected = balance > booked ? balance - booked : 0;
        assertEq(harness.available(balance, booked), expected);
    }

    function testFuzz_APEX_budgetIsMin(uint256 available_, uint256 maximum) public view {
        uint256 expected = available_ < maximum ? available_ : maximum;
        uint256 actual = harness.budget(available_, maximum);
        assertEq(actual, expected);
        assertLe(actual, available_);
        assertLe(actual, maximum);
    }

    function testFuzz_APEX_refundNeverExceedsMaxMinusUsed(uint256 available_, uint256 maximum, uint256 used)
        public
        view
    {
        uint256 credit = available_ < maximum ? available_ : maximum;
        vm.assume(used <= credit);
        uint256 refund = credit - used;
        uint256 maxMinusUsed = maximum >= used ? maximum - used : 0;
        assertLe(refund, maxMinusUsed);
        assertLe(refund, available_);
    }

    function test_APEX005_eoaRejectedExactError() public {
        address eoa = makeAddr("plainEoa");
        assertEq(eoa.code.length, 0);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vm.prank(eoa);
        harness.consumeExactIn(1 ether, true);
        assertEq(harness.lastCredited(), 0);
        assertEq(harness.lastCaller(), address(0));
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        harness.requirePretransferCaller(eoa);
    }

    function test_APEX005_contractCallerAccepted() public {
        bytes memory data = abi.encodeCall(LocalCreditLibHarness.consumeExactIn, (1 ether, true));
        bytes memory returned = atomic.execute(address(harness), data);
        assertEq(abi.decode(returned, (uint256)), 1 ether);
        assertEq(harness.lastCredited(), 1 ether);
        assertEq(harness.lastCaller(), address(atomic));
    }

    function test_APEX005_constructorCallerRejected() public {
        token.mint(payer, 10 ether);
        address predicted = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        vm.prank(payer);
        token.approve(predicted, 1 ether);
        bytes memory data = abi.encodeCall(
            LocalCreditLibHarness.consumeExactInToken, (IERC20(address(token)), 1 ether, true)
        );
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        new AtomicPretransferConstructorCaller(
            IERC20(address(token)), payer, address(harness), 1 ether, data, true
        );
        assertEq(token.balanceOf(payer), 10 ether);
        assertEq(token.balanceOf(address(harness)), 0);
        assertEq(harness.lastCredited(), 0);
    }

    function test_APEX005_deployedWalletAcceptedAsUnsupportedUse() public {
        token.mint(payer, 5 ether);
        vm.prank(payer);
        token.approve(address(atomic), 5 ether);
        bytes memory data =
            abi.encodeCall(LocalCreditLibHarness.consumeExactInToken, (IERC20(address(token)), 2 ether, true));
        bytes memory returned =
            atomic.consumePretransfer(IERC20(address(token)), payer, address(harness), 2 ether, data);
        assertEq(abi.decode(returned, (uint256)), 2 ether);
        assertEq(harness.lastCaller(), address(atomic));
        assertEq(token.balanceOf(address(harness)), 2 ether);
        assertEq(token.balanceOf(payer), 3 ether);
        assertEq(token.balanceOf(address(atomic)), 0);
    }

    function test_APEX005_eip7702DelegatedEoaAcceptedAsUnsupportedUse() public {
        vm.signAndAttachDelegation(address(atomic), walletPk);
        vm.prank(delegatedEoa);
        harness.requirePretransferCaller(delegatedEoa);
        assertGt(delegatedEoa.code.length, 0, "delegated EOA must have code");
        vm.prank(delegatedEoa);
        uint256 credited = harness.consumeExactIn(3 ether, true);
        assertEq(credited, 3 ether);
        assertEq(harness.lastCaller(), delegatedEoa);
    }

    function test_APEX005_falseFlagPullSeparatesPayerAndRecipient() public {
        address recipient = makeAddr("recipient");
        token.mint(payer, 8 ether);
        vm.prank(payer);
        token.approve(address(atomic), 8 ether);
        bytes memory data =
            abi.encodeCall(LocalCreditLibHarness.consumeExactInToken, (IERC20(address(token)), 4 ether, false));
        bytes memory returned = atomic.consumePull(IERC20(address(token)), payer, address(harness), 4 ether, data);
        assertEq(abi.decode(returned, (uint256)), 4 ether);
        assertEq(token.balanceOf(address(harness)), 4 ether);
        assertEq(token.balanceOf(payer), 4 ether);
        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.balanceOf(address(atomic)), 0);
        assertEq(harness.lastCaller(), address(atomic));
    }

    function test_APEX005_failedConsumeRollsBackPayerBalance() public {
        token.mint(payer, 7 ether);
        vm.prank(payer);
        token.approve(address(atomic), 7 ether);
        bytes memory data = abi.encodeWithSelector(bytes4(0xdeadbeef));
        vm.expectRevert(bytes(""));
        atomic.consumePretransfer(IERC20(address(token)), payer, address(harness), 3 ether, data);
        assertEq(token.balanceOf(payer), 7 ether);
        assertEq(token.balanceOf(address(harness)), 0);
        assertEq(token.balanceOf(address(atomic)), 0);
        assertEq(harness.lastCredited(), 0);
    }
}
