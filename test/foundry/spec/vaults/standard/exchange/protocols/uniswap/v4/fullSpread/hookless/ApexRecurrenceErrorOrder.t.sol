// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve as C06LiquidReserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

/// @notice Review probes of the documented D9/R13 error contract on real registry proxies.
contract HooklessApexRecurrenceErrorOrderTest is Acceptance {

    struct C06Route {
        IERC20 output;
        uint256 requested;
        uint256 quoted;
        uint256 maximum;
        uint256 deadline;
        bool mint;
    }

    /// @dev Both mint controls use the same bootstrapped book and real manager session for quoting.
    function _c06Route(bool mint) internal returns (C06Route memory r) {
        _bootstrap();
        r.mint = mint;
        r.output = mint ? IERC20(address(vault)) : token0;
        r.requested = mint ? vault.totalSupply() / 100 : unit0;
        r.deadline = block.timestamp + 1 hours;
        assertGt(vault.totalSupply(), 0, "nonempty share book");
        assertGt(r.requested, 0);
        if (mint) {
            r.quoted = abi.decode(_nested(abi.encodeCall(IStandardExchangeOut.previewExchangeOut,
                (token1, r.output, r.requested))), (uint256));
        } else {
            r.quoted = vault.previewExchangeOut(token1, r.output, r.requested);
        }
        assertGt(r.quoted, 0, "supported positive quote");
        r.maximum = r.quoted + unit1;
        assertGe(r.maximum, r.quoted, "ceiling admits quote");
        assertGe(r.deadline, block.timestamp, "valid deadline");
        assertEq(token1.balanceOf(address(vault)), vault.reserveOfToken(address(token1)), "no unbooked credit");
        assertGe(token1.balanceOf(address(this)), r.maximum, "funded control available");
    }

    function _c06Data(C06Route memory r, address recipient, bool prepaid) internal view returns (bytes memory) {
        return abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (token1, r.maximum, r.output, r.requested, recipient, prepaid, r.deadline));
    }

    /// @dev External boundary makes the entire real nested session part of the rejected transaction.
    function c06Nested(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(this), "test driver only");
        return _nested(data);
    }

    function _c06State(address caller, address recipient) internal view returns (bytes32 state) {
        IERC20[3] memory tokens = [token0, token1, IERC20(address(vault))];
        address[4] memory accounts = [caller, recipient, address(this), address(vault)];
        (uint256 deployed0, uint256 deployed1) = C06LiquidReserve(address(vault)).deployedReserve();
        state = keccak256(abi.encode(vault.totalSupply(), deployed0, deployed1));
        for (uint256 i; i < tokens.length; ++i) {
            state = keccak256(abi.encode(state, vault.reserveOfToken(address(tokens[i]))));
            for (uint256 j; j < accounts.length; ++j) {
                state = keccak256(abi.encode(state, tokens[i].balanceOf(accounts[j])));
            }
        }
    }

    function _c06Reject(bool mint, bool contractCaller) internal {
        C06Route memory r = _c06Route(mint);
        AtomicPretransferCaller wallet = new AtomicPretransferCaller();
        address caller = contractCaller ? (mint ? address(this) : address(wallet)) : makeAddr("C06 EOA");
        address recipient = makeAddr("C06 recipient");
        assertEq(caller.code.length == 0, !contractCaller);
        bytes memory data = _c06Data(r, recipient, true);
        bytes32 beforeState = _c06State(caller, recipient);
        if (contractCaller) {
            vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, r.quoted, 0));
            if (mint) this.c06Nested(data);
            else wallet.execute(address(vault), data);
        } else {
            vm.prank(caller);
            vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
            vault.exchangeOut(token1, r.maximum, r.output, r.requested, recipient, true, r.deadline);
        }
        assertEq(_c06State(caller, recipient), beforeState, "all balances, supply and books unchanged");
        _assertBooked();
    }

    function _c06Success(bool mint, bool prepaid) internal {
        C06Route memory r = _c06Route(mint);
        AtomicPretransferCaller wallet = new AtomicPretransferCaller();
        address caller = mint ? address(this) : (prepaid ? address(wallet) : makeAddr("C06 pull EOA"));
        address recipient = makeAddr("C06 recipient");
        uint256 beforePayer = token1.balanceOf(address(this));
        uint256 beforeOutput = r.output.balanceOf(recipient);
        uint256 beforeSupply = vault.totalSupply();
        uint256 used;
        if (mint) {
            if (prepaid) token1.transfer(address(vault), r.maximum);
            used = abi.decode(_nested(_c06Data(r, recipient, prepaid)), (uint256));
            assertEq(beforePayer - token1.balanceOf(address(this)), used, "nested net input after refund");
        } else if (prepaid) {
            token1.approve(caller, r.maximum);
            used = abi.decode(wallet.consumePretransfer(token1, address(this), address(vault), r.maximum,
                _c06Data(r, recipient, true)), (uint256));
            assertEq(beforePayer - token1.balanceOf(address(this)), r.maximum);
            assertEq(token1.balanceOf(caller), r.maximum - used, "refund equals credited maximum minus input");
        } else {
            assertEq(caller.code.length, 0);
            token1.transfer(caller, r.maximum);
            vm.startPrank(caller);
            token1.approve(address(vault), r.maximum);
            used = vault.exchangeOut(token1, r.maximum, r.output, r.requested, recipient, false, r.deadline);
            vm.stopPrank();
            assertEq(token1.balanceOf(caller), r.maximum - used, "only used debited");
        }
        assertEq(used, r.quoted, "quote parity");
        assertLe(used, r.maximum);
        assertEq(r.output.balanceOf(recipient) - beforeOutput, r.requested, "exact output");
        assertEq(vault.totalSupply(), beforeSupply + (mint ? r.requested : 0), "exact share issue");
        _assertBooked();
    }

    /// @notice REQ-C06 mint: code-less true-flag caller is rejected even outside a manager session.
    function test_C06_mint_eoaShort() public { _c06Reject(true, false); }

    /// @notice REQ-C06 mint: the Acceptance caller reaches the credit comparison inside a real session.
    function test_C06_mint_contractShort() public { _c06Reject(true, true); }

    /// @notice REQ-C06 mint: idle false-flag caller retains InvalidRoute and changes no balances or books.
    function test_C06_mint_idleEoaPullRetainsInvalidRoute() public {
        C06Route memory r = _c06Route(true);
        address caller = makeAddr("C06 idle EOA");
        address recipient = makeAddr("C06 recipient");
        assertEq(caller.code.length, 0);
        token1.transfer(caller, r.maximum);
        vm.prank(caller);
        token1.approve(address(vault), r.maximum);
        bytes32 beforeState = _c06State(caller, recipient);
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(token1), address(vault)));
        vault.exchangeOut(token1, r.maximum, r.output, r.requested, recipient, false, r.deadline);
        assertEq(_c06State(caller, recipient), beforeState);
    }

    /// @notice REQ-C06 mint: funded false-flag nested route succeeds with exact share issue.
    function test_C06_mint_nestedPull() public { _c06Success(true, false); }

    /// @notice REQ-C06 mint: funded nested prepayment reconciles its refund and exact share issue.
    function test_C06_mint_contractFunded() public { _c06Success(true, true); }

    /// @notice REQ-C06 direct-out: code-less short credit reaches the caller error.
    function test_C06_directOut_eoaShort() public { _c06Reject(false, false); }

    /// @notice REQ-C06 direct-out: allowed contract short credit reaches the exact credit error.
    function test_C06_directOut_contractShort() public { _c06Reject(false, true); }

    /// @notice REQ-C06 direct-out: code-less pull pays only the quote and receives exact output.
    function test_C06_directOut_eoaPull() public { _c06Success(false, false); }

    /// @notice REQ-C06 direct-out: contract prepayment refunds only unused credit.
    function test_C06_directOut_contractFunded() public { _c06Success(false, true); }

    function test_review_eoaInternalSyRedeemConsumesSelfShares() public {
        _bootstrap();
        uint256 shares = vault.balanceOf(address(this)) / 100;
        IERC20 output = token0;
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
        _bootstrap();
        uint256 output = unit0;
        uint256 used = vault.previewExchangeOut(token1, token0, output);
        assertGt(used, 0, "supported positive quote");
        uint256 supply = vault.totalSupply();
        uint256 local0 = token0.balanceOf(address(vault));
        uint256 local1 = token1.balanceOf(address(vault));
        address outsider = makeAddr("review outsider");
        assertEq(outsider.code.length, 0);
        vm.prank(outsider);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeOut(token1, used, token0, output, outsider, true, block.timestamp);
        assertEq(vault.totalSupply(), supply);
        assertEq(token0.balanceOf(address(vault)), local0);
        assertEq(token1.balanceOf(address(vault)), local1);
        _assertBooked();
    }

    function test_review_underfundedContractExactOutObservesCreditError() public {
        _bootstrap();
        uint256 output = unit0;
        uint256 used = vault.previewExchangeOut(token1, token0, output);
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 supply = vault.totalSupply();
        uint256 local0 = token0.balanceOf(address(vault));
        uint256 local1 = token1.balanceOf(address(vault));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, used, 0));
        caller.execute(address(vault), abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (token1, used, token0, output, address(caller), true, block.timestamp)
        ));
        assertEq(vault.totalSupply(), supply);
        assertEq(token0.balanceOf(address(vault)), local0);
        assertEq(token1.balanceOf(address(vault)), local1);
        _assertBooked();
    }

    function test_review_fundedContractExactOutSpendsNoMoreThanMaximum() public {
        _bootstrap();
        uint256 output = 1e15;
        uint256 quote = vault.previewExchangeOut(token1, token0, output);
        uint256 maximum = quote + 1e18;
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        token1.approve(address(caller), maximum);
        uint256 beforeOut = token0.balanceOf(address(caller));
        uint256 spent = abi.decode(caller.consumePretransfer(
            token1, address(this), address(vault), maximum,
            abi.encodeCall(IStandardExchangeOut.exchangeOut, (token1, maximum, token0, output, address(caller), true, block.timestamp))
        ), (uint256));
        assertLe(spent, maximum);
        assertEq(spent, quote);
        assertEq(token0.balanceOf(address(caller)) - beforeOut, output);
        _assertBooked();
    }

    function test_review_falseFlagEoaExactOutDoesNotUseCallerGuard() public {
        _bootstrap();
        uint256 output = 1e15;
        uint256 quote = vault.previewExchangeOut(token1, token0, output);
        address outsider = makeAddr("review false-flag outsider");
        assertEq(outsider.code.length, 0);
        token1.transfer(outsider, quote);
        vm.startPrank(outsider);
        token1.approve(address(vault), quote);
        uint256 beforeOut = token0.balanceOf(outsider);
        uint256 spent = vault.exchangeOut(token1, quote, token0, output, outsider, false, block.timestamp);
        vm.stopPrank();
        assertLe(spent, quote);
        assertEq(spent, quote);
        assertEq(token0.balanceOf(outsider) - beforeOut, output);
        _assertBooked();
    }

    function test_review_fundedEoaExactOutReachesCallerGuard() public {
        _bootstrap();
        uint256 output = unit0;
        uint256 used = vault.previewExchangeOut(token1, token0, output);
        assertGt(used, 0, "supported positive quote");
        token1.transfer(address(vault), used);
        uint256 supply = vault.totalSupply();
        uint256 held = token1.balanceOf(address(vault));
        address outsider = makeAddr("review outsider");
        vm.prank(outsider);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeOut(token1, used, token0, output, outsider, true, block.timestamp);
        assertEq(vault.totalSupply(), supply);
        assertEq(token1.balanceOf(address(vault)), held, "prior separate prepayment remains");
    }
}
