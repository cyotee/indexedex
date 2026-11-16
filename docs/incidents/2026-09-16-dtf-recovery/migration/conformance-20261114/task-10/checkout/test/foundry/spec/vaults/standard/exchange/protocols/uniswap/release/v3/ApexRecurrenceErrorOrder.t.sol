// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile_Test as Fixture} from "./UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

contract UniswapV3FullSpreadApexRecurrenceErrorOrderTest is Fixture {

    /// @dev REQ-C06 fixtures use distinct callers and recipients, a live share book, and zero short credit.
    struct C06Route {
        IStandardExchangeProxy target;
        IERC20 input;
        IERC20 output;
        uint256 requested;
        uint256 quoted;
        uint256 maximum;
        uint256 deadline;
    }

    /// @dev Snapshot every fixture token/share balance and reserve for caller, recipient, payer and vault.
    function _c06State(C06Route memory r, address caller, address recipient) internal view returns (bytes32 state) {
        IERC20[] memory tokens = _c06Tokens();
        address[4] memory accounts = [caller, recipient, address(this), address(r.target)];
        state = keccak256(abi.encode(r.target.totalSupply(), _c06Book()));
        for (uint256 i; i < tokens.length; ++i) {
            state = keccak256(abi.encode(state, r.target.reserveOfToken(address(tokens[i]))));
            for (uint256 j; j < accounts.length; ++j) {
                state = keccak256(abi.encode(state, tokens[i].balanceOf(accounts[j])));
            }
        }
    }

    function _c06Data(C06Route memory r, address recipient, bool prepaid) internal pure returns (bytes memory) {
        return abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (r.input, r.maximum, r.output, r.requested, recipient, prepaid, r.deadline));
    }

    function _c06Reject(uint8 branch, bool contractCaller) internal {
        C06Route memory r = _c06Route(branch);
        address recipient = makeAddr("C06 recipient");
        AtomicPretransferCaller wallet = new AtomicPretransferCaller();
        address caller = contractCaller ? address(wallet) : makeAddr("C06 EOA");
        assertEq(caller.code.length == 0, !contractCaller, "caller kind");
        bytes memory data = _c06Data(r, recipient, true);
        bytes32 beforeState = _c06State(r, caller, recipient);
        if (contractCaller) {
            vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, r.quoted, 0));
            wallet.execute(address(r.target), data);
        } else {
            vm.prank(caller);
            vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
            r.target.exchangeOut(r.input, r.maximum, r.output, r.requested, recipient, true, r.deadline);
        }
        assertEq(_c06State(r, caller, recipient), beforeState, "all balances, supply and books unchanged");
    }

    function _c06Pull(C06Route memory r) internal returns (uint256 paid) {
        address caller = makeAddr("C06 pull EOA");
        address recipient = makeAddr("C06 recipient");
        assertEq(caller.code.length, 0);
        r.input.transfer(caller, r.maximum);
        uint256 beforeInput = r.input.balanceOf(caller);
        uint256 beforeOutput = r.output.balanceOf(recipient);
        uint256 beforeSupply = r.target.totalSupply();
        vm.startPrank(caller);
        r.input.approve(address(r.target), r.maximum);
        uint256 used = r.target.exchangeOut(r.input, r.maximum, r.output, r.requested, recipient, false, r.deadline);
        vm.stopPrank();
        assertEq(used, r.quoted, "input equals fixture quote");
        assertLe(used, r.maximum, "maximum respected");
        assertEq(beforeInput - r.input.balanceOf(caller), used, "pull debits only used");
        paid = r.output.balanceOf(recipient) - beforeOutput;
        _c06Payout(r, paid);
        _c06Supply(r, beforeSupply, used);
    }

    function _c06Success(uint8 branch, bool prepaid) internal {
        C06Route memory r = _c06Route(branch);
        if (!prepaid) { _c06Pull(r); return; }
        // Compare the same unchanged route on the same initial state, including zap rounding.
        uint256 snap = vm.snapshotState();
        uint256 expectedPayout = _c06Pull(r);
        assertTrue(vm.revertToState(snap));
        AtomicPretransferCaller wallet = new AtomicPretransferCaller();
        address recipient = makeAddr("C06 recipient");
        uint256 beforeInput = r.input.balanceOf(address(this));
        uint256 beforeOutput = r.output.balanceOf(recipient);
        uint256 beforeSupply = r.target.totalSupply();
        r.input.approve(address(wallet), r.maximum);
        uint256 used = abi.decode(wallet.consumePretransfer(r.input, address(this), address(r.target), r.maximum,
            _c06Data(r, recipient, true)), (uint256));
        assertEq(used, r.quoted, "prepaid input equals quote");
        assertLe(used, r.maximum);
        assertEq(beforeInput - r.input.balanceOf(address(this)), r.maximum, "payer supplies credited maximum");
        assertEq(r.input.balanceOf(address(wallet)), r.maximum - used, "refund is credit minus used");
        assertEq(beforeInput - r.input.balanceOf(address(this)) - r.input.balanceOf(address(wallet)), used,
            "net input reconciles");
        assertEq(r.output.balanceOf(recipient) - beforeOutput, expectedPayout, "unchanged route payout");
        _c06Supply(r, beforeSupply, used);
    }

    function _c06Supply(C06Route memory r, uint256 beforeSupply, uint256 used) internal view {
        if (address(r.output) == address(r.target)) {
            assertEq(r.target.totalSupply(), beforeSupply + r.requested, "exact share issue");
        } else if (address(r.input) == address(r.target)) {
            assertEq(r.target.totalSupply(), beforeSupply - used, "shares burned equal input");
        } else {
            assertEq(r.target.totalSupply(), beforeSupply, "no share issue or burn");
        }
    }

    function _c06Tokens() internal view returns (IERC20[] memory tokens) {
        tokens = new IERC20[](3);
        tokens[0] = IERC20(_token0()); tokens[1] = IERC20(_token1()); tokens[2] = IERC20(address(vault));
    }

    function _c06Book() internal view returns (uint256) {
        (uint256 deployed0, uint256 deployed1) = liquid.deployedReserve();
        return uint256(keccak256(abi.encode(deployed0, deployed1, liquid.localReserve(_token0()), liquid.localReserve(_token1()))));
    }

    function _c06Payout(C06Route memory r, uint256 paid) internal view {
        assertEq(paid, r.requested, "exact requested shares");
    }

    function _c06Route(uint8 /* branch */) internal returns (C06Route memory r) {
        _dualJoin(1000 ether, 1000 ether);
        r.target = vault;
        r.input = IERC20(_token0());
        r.output = IERC20(address(vault));
        r.requested = vault.totalSupply() / 100;
        assertGt(r.target.totalSupply(), 0, "nonempty share book");
        assertGt(r.requested, 0, "positive output");
        r.deadline = block.timestamp + 1 hours;
        r.quoted = r.target.previewExchangeOut(r.input, r.output, r.requested);
        assertGt(r.quoted, 0, "supported positive quote");
        r.maximum = r.quoted + r.quoted / 10 + 1;
        assertGe(r.maximum, r.quoted, "ceiling admits quote");
        assertGe(r.deadline, block.timestamp, "valid deadline");
        assertEq(r.input.balanceOf(address(r.target)), r.target.reserveOfToken(address(r.input)), "no unbooked input");
        ERC20PermitMintableStub(address(r.input)).mint(address(this), r.maximum);
        assertGe(r.input.balanceOf(address(this)), r.maximum, "funded control available");
    }

    /// @notice REQ-C06 mint: Code-less short-credit caller is rejected before credit.
    function test_C06_mint_eoaShort() public { _c06Reject(0, false); }

    /// @notice REQ-C06 mint: Allowed contract caller retains the exact short-credit error.
    function test_C06_mint_contractShort() public { _c06Reject(0, true); }

    /// @notice REQ-C06 mint: Code-less false-flag caller pays the quoted input.
    function test_C06_mint_eoaPull() public { _c06Success(0, false); }

    /// @notice REQ-C06 mint: Funded contract prepayment reconciles output and refund.
    function test_C06_mint_contractFunded() public { _c06Success(0, true); }

    function test_review_directExactOutSupportedControl() public {
        IERC20 input = IERC20(_token0());
        IERC20 output = IERC20(pool.token1());
        uint256 requested = 1 ether;
        uint256 quoted = vault.previewExchangeOut(input, output, requested);
        assertGt(quoted, 0);
        ERC20PermitMintableStub(address(input)).mint(address(this), quoted);
        input.approve(address(vault), quoted);
        uint256 beforeOutput = output.balanceOf(address(this));
        uint256 used = vault.exchangeOut(input, quoted, output, requested, address(this), false, block.timestamp);
        assertEq(used, quoted);
        assertEq(output.balanceOf(address(this)) - beforeOutput, requested);
        _assertLocalReserveMatchesCustody();
    }

    function test_review_directExactOutRejectsUnfilledOutput() public {
        IERC20 input = IERC20(_token0());
        IERC20 output = IERC20(pool.token1());
        uint256 requested = output.balanceOf(address(pool)) + 1;
        uint256 beforeInput = input.balanceOf(address(this));
        uint256 beforeOutput = output.balanceOf(address(this));
        vm.expectPartialRevert(UniswapV3FullSpreadStandardExchangeVaultCommon.UniswapV3Exchange_ExactOutputNotFilled.selector);
        vault.previewExchangeOut(input, output, requested);
        assertEq(input.balanceOf(address(this)), beforeInput);
        assertEq(output.balanceOf(address(this)), beforeOutput);
        _assertLocalReserveMatchesCustody();
    }

    function test_review_eoaInternalSyRedeemConsumesSelfShares() public {
        _dualJoin(1000 ether, 1000 ether);
        uint256 shares = vault.balanceOf(address(this)) / 100;
        IERC20 output = IERC20(_token0());
        vault.transfer(address(vault), shares);
        address outsider = makeAddr("review SY outsider");
        assertEq(outsider.code.length, 0);
        uint256 supply = vault.totalSupply();
        uint256 balance = output.balanceOf(outsider);
        vm.prank(outsider);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardizedYield(address(vault)).redeem(outsider, shares, address(output), 0, true);
        assertEq(output.balanceOf(outsider), balance);
        assertEq(vault.balanceOf(address(vault)), shares);
        assertEq(vault.totalSupply(), supply);
    }

    /// @dev Former credit-first probe. A code-less short push now reaches the caller error first.
    function test_review_underfundedEoaExactOutObservesCreditError() public {
        _dualJoin(1000 ether, 1000 ether);
        IERC20 input = IERC20(_token0());
        uint256 shares = vault.totalSupply() / 100;
        uint256 used = vault.previewExchangeOut(input, IERC20(address(vault)), shares);
        assertGt(used, 0);
        uint256 supply = vault.totalSupply();
        uint256 held = input.balanceOf(address(vault));
        address outsider = makeAddr("review outsider");
        assertEq(outsider.code.length, 0);
        vm.prank(outsider);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeOut(input, used, IERC20(address(vault)), shares, outsider, true, block.timestamp);
        assertEq(vault.totalSupply(), supply);
        assertEq(input.balanceOf(address(vault)), held);
        _assertLocalReserveMatchesCustody();
    }

    function test_review_underfundedContractExactOutObservesCreditError() public {
        _dualJoin(1000 ether, 1000 ether);
        IERC20 input = IERC20(_token0());
        uint256 shares = vault.totalSupply() / 100;
        uint256 used = vault.previewExchangeOut(input, IERC20(address(vault)), shares);
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 supply = vault.totalSupply();
        uint256 held = input.balanceOf(address(vault));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, used, 0));
        caller.execute(address(vault), abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (input, used, IERC20(address(vault)), shares, address(caller), true, block.timestamp)
        ));
        assertEq(vault.totalSupply(), supply);
        assertEq(input.balanceOf(address(vault)), held);
        _assertLocalReserveMatchesCustody();
    }

    function test_review_underfundedEoaDirectExactOutObservesCallerError() public {
        _dualJoin(1000 ether, 1000 ether);
        IERC20 input = IERC20(_token0());
        IERC20 output = IERC20(pool.token1());
        uint256 requested = 1 ether;
        uint256 quoted = vault.previewExchangeOut(input, output, requested);
        address outsider = makeAddr("review direct outsider");
        assertEq(outsider.code.length, 0);
        uint256 held = input.balanceOf(address(vault));
        uint256 received = output.balanceOf(outsider);
        vm.prank(outsider);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeOut(input, quoted, output, requested, outsider, true, block.timestamp);
        assertEq(input.balanceOf(address(vault)), held);
        assertEq(output.balanceOf(outsider), received);
        _assertLocalReserveMatchesCustody();
    }

    function test_review_fundedContractDirectExactOutSpendsNoMoreThanMaximum() public {
        _dualJoin(1000 ether, 1000 ether);
        IERC20 input = IERC20(_token0());
        IERC20 output = IERC20(pool.token1());
        uint256 requested = 1 ether;
        uint256 quoted = vault.previewExchangeOut(input, output, requested);
        uint256 maximum = quoted;
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        ERC20PermitMintableStub(address(input)).mint(address(this), maximum);
        input.approve(address(caller), maximum);
        uint256 beforeOut = output.balanceOf(address(caller));
        uint256 spent = abi.decode(caller.consumePretransfer(
            input, address(this), address(vault), maximum,
            abi.encodeCall(IStandardExchangeOut.exchangeOut, (input, maximum, output, requested, address(caller), true, block.timestamp))
        ), (uint256));
        assertLe(spent, maximum);
        assertEq(spent, quoted);
        assertEq(output.balanceOf(address(caller)) - beforeOut, requested);
        _assertLocalReserveMatchesCustody();
    }

    function test_review_falseFlagEoaDirectExactOutDoesNotUseCallerGuard() public {
        _dualJoin(1000 ether, 1000 ether);
        IERC20 input = IERC20(_token0());
        IERC20 output = IERC20(pool.token1());
        uint256 requested = 1 ether;
        uint256 quoted = vault.previewExchangeOut(input, output, requested);
        address outsider = makeAddr("review false-flag outsider");
        assertEq(outsider.code.length, 0);
        ERC20PermitMintableStub(address(input)).mint(outsider, quoted);
        vm.startPrank(outsider);
        input.approve(address(vault), quoted);
        uint256 beforeOut = output.balanceOf(outsider);
        uint256 spent = vault.exchangeOut(input, quoted, output, requested, outsider, false, block.timestamp);
        vm.stopPrank();
        assertLe(spent, quoted);
        assertEq(spent, quoted);
        assertEq(output.balanceOf(outsider) - beforeOut, requested);
        _assertLocalReserveMatchesCustody();
    }
}
