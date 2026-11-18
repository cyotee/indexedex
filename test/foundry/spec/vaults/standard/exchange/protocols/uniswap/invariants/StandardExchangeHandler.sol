// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {DeliveryTestToken} from "../remediation/DeliveryTestToken.sol";
import {IOperable} from "@crane/contracts/access/operable/IOperable.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IMaintenance} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";

interface ISequenceEnvironment {
    function trade(bool zeroForOne, uint256 amount) external;
    function assertPositionAccounting() external view;
    function positionDigest() external view returns (bytes32);
    function booked() external view returns (uint256, uint256);
    function positionLiquidity() external view returns (uint256);
    function bundleClaim(uint256 shares) external view returns (uint256, uint256);
    function maintain(IERC20 token, uint256 amount) external;
    function custodyAddresses() external view returns (address[3] memory);
}

/// @notice Production-proxy FullSpread campaign with three independently funded holders.
/// @dev The first eight calls cover three actions each; later calls vary one
/// action at a time. The repository's short default depth is also non-vacuous.
/// All counters start at zero; setup funding is not campaign activity. Only the
/// named attacks catch reverts, and they compare the full expected payload and
/// state digest. Any other revert fails the campaign (fail-on-revert is enabled).
/// Exact-out actions now prove fail-closed behavior. User deposits refund dust;
/// authorized maintenance alone deploys booked fees and remainders.
contract StandardExchangeHandler is Test {
    uint256 public constant ACTIONS = 24;
    address public constant EOA_ATTACKER = address(0xBAD);
    ISequenceEnvironment public immutable environment;
    IStandardExchangeProxy public immutable vault;
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    AtomicPretransferCaller[3] public actors;
    AtomicPretransferCaller public immutable attacker;
    uint256 public immutable initialSupply;
    uint256 public issued;
    uint256 public burned;
    uint256 public steps;
    uint256 public campaignCalls;
    uint256[ACTIONS] public attempted;
    uint256[ACTIONS] public succeeded;
    uint256[ACTIONS] public expectedReverts;
    // An unexpected revert propagates; it cannot be persisted in reverted state.
    uint256[ACTIONS] public unexpectedReverts;
    uint256[3] public actorMoneyCalls;
    uint256[3] public refundModes;

    struct ActionReceipt {
        uint256 inputBefore;
        uint256 outputBefore;
        uint256 quoted;
        uint256 refund;
        bytes32 others;
    }

    constructor(ISequenceEnvironment env, IStandardExchangeProxy vault_, IERC20 a, IERC20 b) {
        environment = env;
        vault = vault_;
        token0 = a;
        token1 = b;
        initialSupply = vault_.totalSupply();
        attacker = new AtomicPretransferCaller();
        for (uint256 i; i < 3; ++i) {
            actors[i] = new AtomicPretransferCaller();
        }
    }

    function step(uint256 seed) external {
        ++campaignCalls;
        uint256 count = steps < ACTIONS ? 3 : 1;
        for (uint256 i; i < count; ++i) {
            _step(uint256(keccak256(abi.encode(seed, i))));
        }
    }

    function _step(uint256 seed) private {
        uint256 action = steps < ACTIONS ? steps : seed % ACTIONS;
        uint256 actorIndex = steps < ACTIONS ? steps % 3 : (seed >> 8) % 3;
        AtomicPretransferCaller actor = actors[actorIndex];
        IERC20 token = seed & 1 == 0 ? token0 : token1;
        uint256 amount = bound(seed >> 16, 1e8, 1e11);
        ++attempted[action];
        if (action < 12) {
            _moneyAction(action, actor, token, amount);
            ++actorMoneyCalls[actorIndex];
        } else if (action == 12) {
            _shareTransfer(actorIndex, amount);
        } else if (action == 13) {
            environment.trade(seed & 1 == 0, amount);
            // Probe both sides before any vault action can synchronize books.
            _noDelivery(false, token0, amount);
            _noDelivery(false, token1, amount);
            _noDelivery(true, token, amount);
            expectedReverts[action] += 3;
        } else if (action == 14) {
            _bundleIn(actor, amount, amount * 2, false);
            _bundleIn(actor, amount * 2, amount, true);
        } else if (action == 15) {
            environment.trade(seed & 1 == 0, amount);
            _exchangeIn(actor, token, IERC20(address(vault)), amount, false);
        } else if (action == 16) {
            _maintenance(token, amount);
        } else if (action == 17) {
            _noDelivery(false, token, amount);
            ++expectedReverts[action];
        } else if (action == 18) {
            _noDelivery(true, token, amount);
            ++expectedReverts[action];
        } else if (action == 19) {
            _shortAtomic(actor, token, amount);
            expectedReverts[action] += 2;
        } else if (action == 20) {
            _exchangeIn(actor, token, IERC20(address(vault)), amount, true);
            _rejectContract(
                actor,
                _inCall(token, amount, IERC20(address(vault)), address(actor), true, 1),
                _minimumError(1, 0)
            );
            ++expectedReverts[action];
        } else if (action == 21) {
            _reentry(actor, token, amount);
            ++expectedReverts[action];
        } else if (action == 22) {
            _restingPartial(actorIndex, token, amount);
            ++expectedReverts[action];
        } else {
            _atomicSlippage(actor, token, amount);
            ++expectedReverts[action];
        }
        if (!_attackAction(action)) ++succeeded[action];
        ++steps;
        assertAccounting();
    }

    function _moneyAction(uint256 action, AtomicPretransferCaller actor, IERC20 token, uint256 amount)
        private
    {
        IERC20 shares = IERC20(address(vault));
        bool pushed = action % 2 == 1;
        if (action < 2) {
            _exchangeIn(actor, token, shares, amount, pushed);
        } else if (action < 4) {
            _exchangeIn(actor, shares, token, amount, pushed);
        } else if (action < 6) {
            _exchangeOut(actor, token, shares, amount, pushed);
            ++expectedReverts[action];
        } else if (action < 8) {
            _exchangeOut(actor, shares, token, amount, pushed);
            ++expectedReverts[action];
        } else if (action < 10) {
            _exchangeIn(actor, token, address(token) == address(token0) ? token1 : token0, amount, pushed);
        } else {
            _exchangeOut(actor, token, address(token) == address(token0) ? token1 : token0, amount, pushed);
            ++expectedReverts[action];
            _bundleOut(actor, amount, pushed);
        }
    }

    function _exchangeIn(AtomicPretransferCaller actor, IERC20 input, IERC20 output, uint256 amount, bool pushed)
        private
        returns (uint256 received)
    {
        ActionReceipt memory receipt;
        receipt.inputBefore = input.balanceOf(address(actor));
        receipt.outputBefore = output.balanceOf(address(actor));
        receipt.others = _otherHolders(address(actor));
        uint256[4] memory basis = _basis();
        (receipt.quoted, receipt.refund) =
            IStandardExchangeIn(address(vault)).previewExchangeIn(input, amount, output);
        bytes memory data = _inCall(input, amount, output, address(actor), pushed, 0);
        // Exit shares stay with the caller under either flag.
        uint256 returnedRefund;
        (received, returnedRefund) = _fundedCall(actor, input, amount, pushed, data);
        assertGt(received, 0, "funded exact-in executed");
        assertEq(received, receipt.quoted, "exact-in preview matches receipt");
        assertEq(returnedRefund, receipt.refund, "exact-in preview matches refund");
        assertEq(receipt.inputBefore - input.balanceOf(address(actor)), amount - receipt.refund, "only kept input debited");
        assertEq(output.balanceOf(address(actor)) - receipt.outputBefore, received, "actual exact-in payout");
        assertEq(_otherHolders(address(actor)), receipt.others, "other holders unchanged");
        if (address(output) == address(vault)) _assertMintBasis(basis, received);
        else if (address(input) == address(vault)) _assertBurnBasis(basis, amount);
        else {
            uint256[4] memory afterBasis = _basis();
            for (uint256 i; i < 4; ++i) assertEq(afterBasis[i], basis[i], "pass-through cannot deploy books or issue shares");
        }
        _attribute(input, output, amount, received);
    }

    function _exchangeOut(
        AtomicPretransferCaller actor,
        IERC20 input,
        IERC20 output,
        uint256 amount,
        bool pushed
    ) private {
        assertEq(vault.previewExchangeOut(input, output, amount), 0, "exact-out preview is unavailable");
        // Even a funded allowance cannot make the retired route move tokens.
        actor.execute(address(input), abi.encodeCall(IERC20.approve, (address(vault), amount * 4)));
        bytes memory data = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (input, amount * 4, output, amount, address(actor), pushed, block.timestamp)
        );
        _rejectContract(actor, data, abi.encodeWithSelector(IStandardExchangeOut.ExchangeOutNotAvailable.selector));
    }

    function _fundedCall(AtomicPretransferCaller actor, IERC20 token, uint256 funding, bool pushed, bytes memory data)
        private
        returns (uint256, uint256)
    {
        if (address(token) == address(vault)) {
            return abi.decode(actor.execute(address(vault), data), (uint256, uint256));
        }
        actor.execute(
            address(token), abi.encodeCall(IERC20.approve, (pushed ? address(actor) : address(vault), funding))
        );
        bytes memory result = pushed
            ? actor.consumePretransfer(token, address(actor), address(vault), funding, data)
            : actor.execute(address(vault), data);
        return abi.decode(result, (uint256, uint256));
    }

    function _amounts(uint256 a, uint256 b) private pure returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = a;
        amounts[1] = b;
    }

    function _tokens() private view returns (address[] memory tokens) {
        tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
    }

    /// @dev Both funding modes must pay exactly each budget minus its returned refund.
    function _bundleIn(AtomicPretransferCaller actor, uint256 a, uint256 b, bool pushed) private {
        uint256[4] memory basis = _basis();
        ActionReceipt memory receipt;
        receipt.inputBefore = token0.balanceOf(address(actor));
        receipt.outputBefore = token1.balanceOf(address(actor));
        uint256 beforeShares = vault.balanceOf(address(actor));
        receipt.others = _otherHolders(address(actor));
        uint256[] memory refunds;
        (receipt.quoted, refunds) =
            IStandardExchangeBundleIn(address(vault)).previewExchangeBundleInForSingleOut(_amounts(a, b), address(vault));
        IERC20[2] memory tokens = [token0, token1];
        for (uint256 i; i < 2; ++i) {
            actor.execute(address(tokens[i]), abi.encodeCall(IERC20.approve, (address(vault), i == 0 ? a : b)));
            if (pushed) actor.execute(address(tokens[i]), abi.encodeCall(IERC20.transfer, (address(vault), i == 0 ? a : b)));
        }
        (uint256 minted, uint256[] memory returned) = abi.decode(
            actor.execute(address(vault), abi.encodeCall(IStandardExchangeBundleIn.exchangeBundleInForSingleOut,
                (_amounts(a, b), address(vault), receipt.quoted, address(actor), pushed, block.timestamp))),
            (uint256, uint256[])
        );
        assertEq(minted, receipt.quoted, "bundle net share quote");
        assertGt(minted, 0, "bundle added liquidity");
        assertEq(returned, refunds, "bundle per-token refund quote");
        assertEq(receipt.inputBefore - token0.balanceOf(address(actor)), a - returned[0], "bundle token0 debit");
        assertEq(receipt.outputBefore - token1.balanceOf(address(actor)), b - returned[1], "bundle token1 debit");
        assertEq(vault.balanceOf(address(actor)), beforeShares + minted, "bundle shares attributed");
        assertEq(_otherHolders(address(actor)), receipt.others, "bundle leaves other holders unchanged");
        _assertMintBasis(basis, minted);
        issued += minted;
        ++refundModes[0];
    }

    /// @dev Both flags burn caller-held exact-in shares, with no transfer or approval.
    function _bundleOut(AtomicPretransferCaller actor, uint256 amount, bool pushed) private {
        uint256[4] memory basis = _basis();
        ActionReceipt memory receipt;
        receipt.inputBefore = token0.balanceOf(address(actor));
        receipt.outputBefore = token1.balanceOf(address(actor));
        uint256 beforeShares = vault.balanceOf(address(actor));
        receipt.others = _otherHolders(address(actor));
        (uint256[] memory quote, uint256 quoteRefund) =
            IStandardExchangeBundleOut(address(vault)).previewExchangeBundleOut(address(vault), amount, _tokens());
        {
            (uint256 claim0, uint256 claim1) = environment.bundleClaim(amount);
            assertEq(quote, _amounts(claim0, claim1), "independent principal, unpaid fee and book claim");
        }
        (uint256[] memory paid, uint256 refund) = abi.decode(
            actor.execute(address(vault), abi.encodeCall(IStandardExchangeBundleOut.exchangeBundleOut,
                (address(vault), amount, _tokens(), quote, address(actor), pushed, block.timestamp))),
            (uint256[], uint256)
        );
        assertEq(paid, quote, "bundle exit quote");
        assertEq(refund, 0, "exact share exit has no refund");
        assertEq(quoteRefund, 0, "bundle exit preview refund");
        assertEq(token0.balanceOf(address(actor)), receipt.inputBefore + paid[0], "bundle exit token0 receipt");
        assertEq(token1.balanceOf(address(actor)), receipt.outputBefore + paid[1], "bundle exit token1 receipt");
        assertEq(vault.balanceOf(address(actor)), beforeShares - amount, "caller shares burned");
        assertEq(_otherHolders(address(actor)), receipt.others, "bundle exit leaves other holders unchanged");
        _assertBurnBasis(basis, amount);
        burned += amount;
    }

    function _basis() private view returns (uint256[4] memory basis) {
        basis[0] = vault.totalSupply();
        basis[1] = environment.positionLiquidity();
        (basis[2], basis[3]) = environment.booked();
    }

    /// @dev The canonical fixture has zero usage fee; raw liquidity alone sets issuance.
    function _assertMintBasis(uint256[4] memory beforeBasis, uint256 minted) private view {
        uint256[4] memory afterBasis = _basis();
        uint256 added = afterBasis[1] - beforeBasis[1];
        assertEq(minted, added * beforeBasis[0] / beforeBasis[1], "raw-liquidity share issuance");
        assertEq(afterBasis[0], beforeBasis[0] + minted, "deposit supply delta");
        assertGe(afterBasis[2], beforeBasis[2], "deposit cannot deploy incumbent token0 book");
        assertGe(afterBasis[3], beforeBasis[3], "deposit cannot deploy incumbent token1 book");
    }

    function _assertBurnBasis(uint256[4] memory beforeBasis, uint256 shares) private view {
        assertEq(vault.totalSupply(), beforeBasis[0] - shares, "exit burns exact input shares");
        assertEq(environment.positionLiquidity(),
            beforeBasis[1] - beforeBasis[1] * shares / beforeBasis[0], "exit removes raw-liquidity fraction");
    }

    function _maintenance(IERC20 token, uint256 amount) private {
        bytes32 holders = _otherHolders(address(0));
        uint256 supply = vault.totalSupply();
        uint256 liquidity = environment.positionLiquidity();
        _rejectContract(attacker, abi.encodeCall(IMaintenance.compound, ()),
            abi.encodeWithSelector(IOperable.NotOperator.selector, address(attacker)));
        _rejectContract(attacker, abi.encodeCall(IMaintenance.donate, (address(token), amount, false)),
            abi.encodeWithSelector(IOperable.NotOperator.selector, address(attacker)));
        expectedReverts[16] += 2;
        environment.maintain(token, amount);
        assertGt(environment.positionLiquidity(), liquidity, "authorized donation deploys liquidity");
        assertEq(vault.totalSupply(), supply, "token maintenance cannot issue shares");
        assertEq(_otherHolders(address(0)), holders, "maintenance cannot pay holders");
    }

    function _attribute(IERC20 input, IERC20 output, uint256 amountIn, uint256 amountOut) private {
        if (address(input) == address(vault)) burned += amountIn;
        if (address(output) == address(vault)) issued += amountOut;
    }

    function _shareTransfer(uint256 actorIndex, uint256 amount) private {
        address from = address(actors[actorIndex]);
        address to = address(actors[(actorIndex + 1) % 3]);
        uint256 beforeFrom = vault.balanceOf(from);
        uint256 beforeTo = vault.balanceOf(to);
        actors[actorIndex].execute(address(vault), abi.encodeCall(IERC20.transfer, (to, amount)));
        assertEq(vault.balanceOf(from), beforeFrom - amount);
        assertEq(vault.balanceOf(to), beforeTo + amount);
    }

    function _noDelivery(bool eoa, IERC20 token, uint256 amount) private {
        bytes memory data =
            _inCall(token, amount, IERC20(address(vault)), eoa ? EOA_ATTACKER : address(attacker), true, 0);
        if (eoa) {
            bytes32 beforeState = stateDigest();
            vm.prank(EOA_ATTACKER);
            (bool ok, bytes memory reason) = address(vault).call(data);
            assertFalse(ok);
            assertEq(reason, abi.encodeWithSelector(ISecurePullErrors.EOAPretransferNotAllowed.selector));
            assertEq(stateDigest(), beforeState, "EOA rejection rolls back");
        } else {
            bytes32 beforeState = stateDigest();
            (uint256 minted, uint256 refund) = abi.decode(attacker.execute(address(vault), data), (uint256, uint256));
            assertEq(minted, 0, "missing delivery cannot issue shares");
            assertEq(refund, 0, "no imaginary refund");
            assertEq(stateDigest(), beforeState, "no delivery changes no state");
            _rejectContract(attacker,
                _inCall(token, amount, IERC20(address(vault)), address(attacker), true, 1), _minimumError(1, 0));
        }
    }

    function _shortAtomic(AtomicPretransferCaller actor, IERC20 token, uint256 amount) private {
        actor.execute(address(token), abi.encodeCall(IERC20.approve, (address(actor), amount - 1)));
        bytes32 beforeState = stateDigest();
        bytes memory data = _inCall(token, amount, IERC20(address(vault)), address(actor), true, 1);
        (bool ok, bytes memory reason) = address(actor)
            .call(
                abi.encodeCall(
                    AtomicPretransferCaller.consumePretransfer,
                    (token, address(actor), address(vault), amount - 1, data)
                )
            );
        assertFalse(ok);
        assertEq(reason, _minimumError(1, 0));
        assertEq(stateDigest(), beforeState, "atomic short delivery restores tokens, shares, books and allowances");
        _stagedShortDelivery(actor, token, amount, data);
    }

    function _stagedShortDelivery(AtomicPretransferCaller actor, IERC20 token, uint256 amount, bytes memory data)
        private
    {
        uint256 payerBefore = token.balanceOf(address(actor));
        uint256 vaultBefore = token.balanceOf(address(vault));
        actor.execute(address(token), abi.encodeCall(IERC20.transfer, (address(vault), amount - 1)));
        _rejectContract(actor, data, _minimumError(1, 0));
        assertEq(token.balanceOf(address(actor)), payerBefore - (amount - 1), "prior transfer stays spent");
        assertEq(token.balanceOf(address(vault)), vaultBefore + amount - 1, "prior transfer stays delivered");
        uint256 sharesBefore = vault.balanceOf(address(actor));
        data = _inCall(token, amount, IERC20(address(vault)), address(actor), true, 0);
        (uint256 minted, uint256 refund) = abi.decode(actor.execute(address(vault), data), (uint256, uint256));
        assertEq(minted, 0, "oversized pretransfer cannot mint or pull shortfall");
        assertEq(refund, amount - 1, "oversized maximum refunds actual credit only");
        assertEq(token.balanceOf(address(actor)), payerBefore, "short delivery returned");
        assertEq(token.balanceOf(address(vault)), vaultBefore, "booked balance untouched");
        assertEq(vault.balanceOf(address(actor)), sharesBefore);
        ++refundModes[1];
    }

    function _atomicSlippage(AtomicPretransferCaller actor, IERC20 token, uint256 amount) private {
        actor.execute(address(token), abi.encodeCall(IERC20.approve, (address(actor), amount)));
        bytes32 beforeState = stateDigest();
        IERC20 output = address(token) == address(token0) ? token1 : token0;
        (uint256 quoted,) = IStandardExchangeIn(address(vault)).previewExchangeIn(token, amount, output);
        // The exact plan must roll back with the caller's atomic funding.
        bytes memory data = _inCall(
            token, amount, address(token) == address(token0) ? token1 : token0, address(actor), false, type(uint256).max
        );
        (bool ok, bytes memory reason) = address(actor)
            .call(
                abi.encodeCall(
                    AtomicPretransferCaller.consumePull, (token, address(actor), address(vault), amount, data)
                )
            );
        assertFalse(ok);
        assertEq(reason, _minimumError(type(uint256).max, quoted));
        assertEq(stateDigest(), beforeState, "failed swap restores protocol custody and in-transaction approvals");
    }

    function _reentry(AtomicPretransferCaller actor, IERC20 token, uint256 amount) private {
        DeliveryTestToken hostile = DeliveryTestToken(address(token));
        hostile.setCallback(address(vault), abi.encodeCall(IMaintenance.compound, ()));
        _exchangeIn(actor, token, IERC20(address(vault)), amount, false);
        assertEq(hostile.callbackError(), abi.encodeWithSelector(IReentrancyLock.IsLocked.selector));
        hostile.setCallback(address(0), "");
    }

    function _restingPartial(uint256 actorIndex, IERC20 token, uint256 amount) private {
        AtomicPretransferCaller payer = actors[actorIndex];
        AtomicPretransferCaller consumer = actors[(actorIndex + 1) % 3];
        uint256 paid = amount * 2;
        uint256 payerBefore = token.balanceOf(address(payer));
        uint256 consumerBefore = token.balanceOf(address(consumer));
        uint256 sharesBefore = vault.balanceOf(address(consumer));
        // Deliberately stage a separate transfer. D12 allows another contract to
        // consume part of this available credit; it does not own the sender's credit.
        {
            (uint256 book0, uint256 book1) = environment.booked();
            uint256 reserve0 = vault.reserveOfToken(address(token0));
            uint256 reserve1 = vault.reserveOfToken(address(token1));
            payer.execute(address(token), abi.encodeCall(IERC20.transfer, (address(vault), paid)));
            (uint256 afterBook0, uint256 afterBook1) = environment.booked();
            assertEq(afterBook0, book0, "stray token0 not booked");
            assertEq(afterBook1, book1, "stray token1 not booked");
            assertEq(vault.reserveOfToken(address(token0)), reserve0, "stray custody not token0 reserves");
            assertEq(vault.reserveOfToken(address(token1)), reserve1, "stray custody not token1 reserves");
            environment.assertPositionAccounting();
        }
        bytes memory data = _inCall(token, amount, IERC20(address(vault)), address(consumer), true, 0);
        uint256[4] memory basis = _basis();
        (uint256 minted, uint256 refund) = abi.decode(consumer.execute(address(vault), data), (uint256, uint256));
        _assertMintBasis(basis, minted);
        assertGt(minted, 0);
        assertEq(token.balanceOf(address(payer)), payerBefore - paid, "staged payer retains no ownership");
        assertEq(token.balanceOf(address(consumer)), consumerBefore + refund, "consumer receives unused declared input");
        assertEq(vault.balanceOf(address(consumer)), sharesBefore + minted);
        issued += minted;
        environment.assertPositionAccounting();
        // Above-maximum credit remains unbooked and can fund one more contract call.
        basis = _basis();
        (uint256 second, uint256 secondRefund) = abi.decode(consumer.execute(address(vault), data), (uint256, uint256));
        _assertMintBasis(basis, second);
        assertGt(second, 0, "remaining credit stays available");
        issued += second;
        assertEq(vault.balanceOf(address(consumer)), sharesBefore + minted + second);
        assertEq(token.balanceOf(address(consumer)), consumerBefore + refund + secondRefund);
        _rejectContract(consumer,
            _inCall(token, amount, IERC20(address(vault)), address(consumer), true, 1), _minimumError(1, 0));
        ++refundModes[2];
    }

    function _rejectContract(AtomicPretransferCaller caller, bytes memory data, bytes memory expected) private {
        bytes32 beforeState = stateDigest();
        (bool ok, bytes memory reason) =
            address(caller).call(abi.encodeCall(AtomicPretransferCaller.execute, (address(vault), data)));
        assertFalse(ok, "invalid delivery succeeded");
        assertEq(reason, expected, "attack reached intended check");
        assertEq(stateDigest(), beforeState, "failed call restores all measured state");
    }

    function _inCall(IERC20 input, uint256 amount, IERC20 output, address recipient, bool pushed, uint256 minimum)
        private
        view
        returns (bytes memory)
    {
        return abi.encodeCall(
            IStandardExchangeIn.exchangeIn, (input, amount, output, minimum, recipient, pushed, block.timestamp)
        );
    }

    function _minimumError(uint256 minimum, uint256 actual) private pure returns (bytes memory) {
        return abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, minimum, actual);
    }

    function _otherHolders(address except) private view returns (bytes32 digest) {
        for (uint256 i; i < 3; ++i) {
            if (address(actors[i]) != except) {
                digest = keccak256(abi.encode(digest, _accountDigest(address(actors[i]))));
            }
        }
        if (except != address(0)) {
            digest = keccak256(abi.encode(digest, _accountDigest(address(environment))));
        }
        digest = keccak256(abi.encode(digest, _accountDigest(address(0))));
    }

    function _accountDigest(address account) private view returns (bytes32 digest) {
        IERC20[3] memory tokens = [token0, token1, IERC20(address(vault))];
        for (uint256 i; i < 3; ++i) {
            digest = keccak256(
                abi.encode(
                    digest,
                    tokens[i].balanceOf(account),
                    tokens[i].allowance(account, address(vault)),
                    tokens[i].allowance(account, account)
                )
            );
        }
    }

    function stateDigest() public view returns (bytes32 digest) {
        digest = keccak256(
            abi.encode(
                vault.totalSupply(),
                token0.totalSupply(),
                token1.totalSupply(),
                vault.reserveOfToken(address(token0)),
                vault.reserveOfToken(address(token1)),
                vault.reserveOfToken(address(vault))
            )
        );
        for (uint256 i; i < 3; ++i) {
            digest = keccak256(abi.encode(digest, _accountDigest(address(actors[i]))));
        }
        address[3] memory custody = environment.custodyAddresses();
        for (uint256 i; i < 3; ++i) {
            digest = keccak256(abi.encode(digest, _accountDigest(custody[i])));
        }
        digest = keccak256(
            abi.encode(
                digest,
                _accountDigest(address(environment)),
                _accountDigest(address(vault)),
                _accountDigest(address(this)),
                _accountDigest(address(attacker)),
                _accountDigest(EOA_ATTACKER)
            )
        );
        return keccak256(abi.encode(digest, environment.positionDigest()));
    }

    function assertAccounting() public view {
        assertEq(vault.totalSupply(), initialSupply + issued - burned, "all mint and burn attributed");
        uint256 held = vault.balanceOf(address(environment)) + vault.balanceOf(address(0));
        for (uint256 i; i < 3; ++i) {
            held += vault.balanceOf(address(actors[i]));
        }
        assertEq(vault.totalSupply(), held, "all holders reconciled");
        assertEq(vault.balanceOf(address(vault)), 0, "no orphan input shares");
        assertEq(vault.balanceOf(address(attacker)), 0, "no attacker shares");
        assertEq(vault.balanceOf(EOA_ATTACKER), 0, "no EOA shares");
        assertEq(token0.balanceOf(address(attacker)) + token1.balanceOf(address(attacker)), 0, "no attacker payout");
        assertEq(token0.balanceOf(EOA_ATTACKER) + token1.balanceOf(EOA_ATTACKER), 0, "no EOA payout");
        assertEq(
            token0.balanceOf(address(this)) + token1.balanceOf(address(this)),
            0,
            "maintenance caller receives no assets"
        );
        assertEq(vault.balanceOf(address(0)), 1000, "genesis floor remains at zero address");
        environment.assertPositionAccounting();
    }

    function assertCampaignCoverage() external view {
        assertGe(steps, ACTIONS, "campaign reached every action");
        for (uint256 i; i < ACTIONS; ++i) {
            assertGt(attempted[i], 0, "required action attempted");
            if (_attackAction(i)) {
                uint256 checks = i == 19 ? 2 : 1;
                assertEq(expectedReverts[i], attempted[i] * checks, "expected attacks reached and rejected");
            } else {
                assertEq(succeeded[i], attempted[i], "every valid action succeeded");
            }
            assertEq(unexpectedReverts[i], 0);
        }
        assertGt(expectedReverts[21], 0, "callback reached lock");
        assertEq(expectedReverts[10], attempted[10], "token-token pull exact-out rejected");
        assertEq(expectedReverts[11], attempted[11], "token-token pretransfer exact-out rejected");
        assertEq(expectedReverts[16], attempted[16] * 2, "both maintenance selectors enforce authorization");
        assertEq(expectedReverts[13], attempted[13] * 3, "post-trade checks do not treat fees as credit");
        assertEq(expectedReverts[22], attempted[22], "fully consumed credit cannot be replayed");
        for (uint256 i; i < 3; ++i) {
            assertGt(actorMoneyCalls[i], 0, "each funded holder participated");
            assertGt(refundModes[i], 0, "bundle, oversized and remaining-credit refunds exercised");
        }
    }

    function _attackAction(uint256 action) private pure returns (bool) {
        return (action >= 4 && action < 8) || action == 17 || action == 18
            || action == 19 || action == 20 || action == 23;
    }
}
