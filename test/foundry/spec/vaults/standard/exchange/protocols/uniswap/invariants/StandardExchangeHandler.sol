// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {DeliveryTestToken} from "../remediation/DeliveryTestToken.sol";

interface ISequenceEnvironment {
    function trade(bool zeroForOne, uint256 amount) external;
    function configureSleeve(uint256 percentage) external;
    function custodyAddresses() external view returns (address[3] memory);
    function slippageError() external pure returns (bytes4);
}

interface ISequenceReserve {
    function rebalanceLiquidReserve() external;
    function deployedReserve() external view returns (uint256, uint256);
}

/// @notice Production-proxy FullSpread campaign with three independently funded holders.
/// @dev The first eight calls cover three actions each; later calls vary one
/// action at a time. The repository's short default depth is also non-vacuous.
/// All counters start at zero; setup funding is not campaign activity. Only the
/// named attacks catch reverts, and they compare the full expected payload and
/// state digest. Any other revert fails the campaign (fail-on-revert is enabled).
/// Fee collection uses a funded deposit after a real trade: FullSpread has no
/// separate public collect selector. Callback probes use the configured token.
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

    struct Flow {
        AtomicPretransferCaller actor;
        IERC20 input;
        IERC20 output;
        uint256 amount;
        uint256 quoted;
        uint256 delivered;
        uint256 maximum;
        bool pushed;
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
        uint256 amount = bound(seed >> 16, 1e14, 0.1 ether);
        ++attempted[action];
        if (action < 12) {
            _moneyAction(action, actor, token, amount, seed);
            ++actorMoneyCalls[actorIndex];
        } else if (action == 12) {
            _shareTransfer(actorIndex, amount);
        } else if (action == 13) {
            environment.trade(seed & 1 == 0, amount);
            // Probe both sides before any vault action can synchronize books.
            _noDelivery(false, token0, amount);
            _noDelivery(false, token1, amount);
            _noDelivery(true, token, amount);
            expectedReverts[action] += 5;
        } else if (action == 14) {
            actor.execute(address(token), abi.encodeCall(IERC20.transfer, (address(vault), amount)));
            ISequenceReserve(address(vault)).rebalanceLiquidReserve();
        } else if (action == 15) {
            // Ensure deployed liquidity, accrue fees, then collect through the public mint route.
            environment.configureSleeve(0.02e18);
            ISequenceReserve(address(vault)).rebalanceLiquidReserve();
            environment.trade(seed & 1 == 0, amount);
            _exchangeIn(actor, token, IERC20(address(vault)), amount, false);
        } else if (action == 16) {
            uint256[4] memory choices = [uint256(0.02e18), 0.2e18, 0.5e18, 1e18];
            environment.configureSleeve(choices[(seed >> 4) % 4]);
            ISequenceReserve(address(vault)).rebalanceLiquidReserve();
        } else if (action == 17) {
            _noDelivery(false, token, amount);
            expectedReverts[action] += 2;
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
                _inCall(token, amount, IERC20(address(vault)), address(actor), true, 0),
                _deliveryError(amount, 0)
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

    function _moneyAction(uint256 action, AtomicPretransferCaller actor, IERC20 token, uint256 amount, uint256 seed)
        private
    {
        IERC20 shares = IERC20(address(vault));
        bool pushed = action % 2 == 1;
        if (action < 2) {
            _exchangeIn(actor, token, shares, amount, pushed);
        } else if (action < 4) {
            _exchangeIn(actor, shares, token, amount, pushed);
        } else if (action < 6) {
            _exchangeOut(actor, token, shares, amount, pushed, seed);
        } else if (action < 8) {
            _exchangeOut(actor, shares, token, amount, pushed, seed);
        } else if (action < 10) {
            _exchangeIn(actor, token, address(token) == address(token0) ? token1 : token0, amount, pushed);
        } else {
            _exchangeOut(actor, token, address(token) == address(token0) ? token1 : token0, amount, pushed, seed);
        }
    }

    function _exchangeIn(AtomicPretransferCaller actor, IERC20 input, IERC20 output, uint256 amount, bool pushed)
        private
        returns (uint256 received)
    {
        uint256 inputBefore = input.balanceOf(address(actor));
        uint256 outputBefore = output.balanceOf(address(actor));
        bytes32 others = _otherHolders(address(actor));
        bytes memory data = _inCall(input, amount, output, address(actor), pushed, 0);
        received = _fundedCall(actor, input, amount, pushed, data);
        assertGt(received, 0, "funded exact-in executed");
        assertEq(inputBefore - input.balanceOf(address(actor)), amount, "exact-in has no refund");
        assertEq(output.balanceOf(address(actor)) - outputBefore, received, "actual exact-in payout");
        assertEq(_otherHolders(address(actor)), others, "other holders unchanged");
        _attribute(input, output, amount, received);
    }

    function _exchangeOut(
        AtomicPretransferCaller actor,
        IERC20 input,
        IERC20 output,
        uint256 amount,
        bool pushed,
        uint256 seed
    ) private {
        Flow memory flow;
        flow.actor = actor;
        flow.input = input;
        flow.output = output;
        flow.amount = amount;
        flow.pushed = pushed;
        flow.quoted = vault.previewExchangeOut(input, output, amount);
        assertGt(flow.quoted, 0, "nonzero exact-out quote");
        flow.maximum = flow.quoted * 4 + 1;
        // Exercise full-max refunds, partial credit, and only-used under a fat max.
        uint256 mode = steps < ACTIONS ? (steps == 5 ? 2 : steps == 7 ? 1 : 0) : (seed >> 4) % 3;
        if (pushed) ++refundModes[mode];
        flow.delivered =
            !pushed || mode == 0 ? flow.quoted : mode == 1 ? flow.quoted + flow.quoted / 4 + 1 : flow.maximum;
        _executeOut(flow);
    }

    function _executeOut(Flow memory flow) private {
        address actor = address(flow.actor);
        uint256 inputBefore = flow.input.balanceOf(actor);
        uint256 outputBefore = flow.output.balanceOf(actor);
        bytes32 others = _otherHolders(actor);
        bytes memory data = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (flow.input, flow.maximum, flow.output, flow.amount, actor, flow.pushed, block.timestamp)
        );
        // False-flag approves the fat max; the vault must debit only the quote.
        uint256 used =
            _fundedCall(flow.actor, flow.input, flow.pushed ? flow.delivered : flow.maximum, flow.pushed, data);
        assertEq(used, flow.quoted, "exact-out preview/execute");
        assertEq(inputBefore - flow.input.balanceOf(actor), used, "only used debited; bounded refund");
        assertEq(flow.output.balanceOf(actor) - outputBefore, flow.amount, "exact requested payout");
        if (flow.pushed) {
            uint256 refunded = flow.input.balanceOf(actor) - (inputBefore - flow.delivered);
            assertEq(refunded, flow.delivered - used, "refund from actual delivered credit only");
            assertLe(refunded, flow.maximum - used, "refund below max minus used");
        } else if (address(flow.input) != address(vault)) {
            assertEq(flow.input.allowance(actor, address(vault)), flow.maximum - used, "pull used, not maximum");
        }
        assertEq(_otherHolders(actor), others, "other holders unchanged");
        _attribute(flow.input, flow.output, used, flow.amount);
    }

    function _fundedCall(AtomicPretransferCaller actor, IERC20 token, uint256 funding, bool pushed, bytes memory data)
        private
        returns (uint256)
    {
        actor.execute(
            address(token), abi.encodeCall(IERC20.approve, (pushed ? address(actor) : address(vault), funding))
        );
        bytes memory result = pushed
            ? actor.consumePretransfer(token, address(actor), address(vault), funding, data)
            : actor.execute(address(vault), data);
        return abi.decode(result, (uint256));
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
            _rejectContract(attacker, data, _deliveryError(amount, 0));
            uint256 quoted = vault.previewExchangeOut(token, IERC20(address(vault)), amount);
            data = abi.encodeCall(
                IStandardExchangeOut.exchangeOut,
                (token, quoted * 4, IERC20(address(vault)), amount, address(attacker), true, block.timestamp)
            );
            _rejectContract(attacker, data, _deliveryError(quoted, 0));
        }
    }

    function _shortAtomic(AtomicPretransferCaller actor, IERC20 token, uint256 amount) private {
        actor.execute(address(token), abi.encodeCall(IERC20.approve, (address(actor), amount - 1)));
        bytes32 beforeState = stateDigest();
        bytes memory data = _inCall(token, amount, IERC20(address(vault)), address(actor), true, 0);
        (bool ok, bytes memory reason) = address(actor)
            .call(
                abi.encodeCall(
                    AtomicPretransferCaller.consumePretransfer,
                    (token, address(actor), address(vault), amount - 1, data)
                )
            );
        assertFalse(ok);
        assertEq(reason, _deliveryError(amount, amount - 1));
        assertEq(stateDigest(), beforeState, "atomic short delivery restores tokens, shares, books and allowances");
        _stagedShortDelivery(actor, token, amount, data);
    }

    function _stagedShortDelivery(AtomicPretransferCaller actor, IERC20 token, uint256 amount, bytes memory data)
        private
    {
        uint256 payerBefore = token.balanceOf(address(actor));
        uint256 vaultBefore = token.balanceOf(address(vault));
        actor.execute(address(token), abi.encodeCall(IERC20.transfer, (address(vault), amount - 1)));
        _rejectContract(actor, data, _deliveryError(amount, amount - 1));
        assertEq(token.balanceOf(address(actor)), payerBefore - (amount - 1), "prior transfer stays spent");
        assertEq(token.balanceOf(address(vault)), vaultBefore + amount - 1, "prior transfer stays delivered");
        uint256 sharesBefore = vault.balanceOf(address(actor));
        data = _inCall(token, amount - 1, IERC20(address(vault)), address(actor), true, 0);
        uint256 minted = abi.decode(actor.execute(address(vault), data), (uint256));
        assertGt(minted, 0);
        assertEq(vault.balanceOf(address(actor)), sharesBefore + minted);
        issued += minted;
    }

    function _atomicSlippage(AtomicPretransferCaller actor, IERC20 token, uint256 amount) private {
        actor.execute(address(token), abi.encodeCall(IERC20.approve, (address(actor), amount)));
        bytes32 beforeState = stateDigest();
        // A real pool swap occurs before the impossible minOut check.
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
        assertEq(reason, abi.encodeWithSelector(environment.slippageError()));
        assertEq(stateDigest(), beforeState, "failed swap restores protocol custody and in-transaction approvals");
    }

    function _reentry(AtomicPretransferCaller actor, IERC20 token, uint256 amount) private {
        DeliveryTestToken hostile = DeliveryTestToken(address(token));
        hostile.setCallback(address(vault), abi.encodeCall(ISequenceReserve.rebalanceLiquidReserve, ()));
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
        payer.execute(address(token), abi.encodeCall(IERC20.transfer, (address(vault), paid)));
        bytes memory data = _inCall(token, amount, IERC20(address(vault)), address(consumer), true, 0);
        uint256 minted = abi.decode(consumer.execute(address(vault), data), (uint256));
        assertGt(minted, 0);
        assertEq(token.balanceOf(address(payer)), payerBefore - paid, "no exact-in excess refund");
        assertEq(token.balanceOf(address(consumer)), consumerBefore, "no consumer refund");
        assertEq(vault.balanceOf(address(consumer)), sharesBefore + minted);
        issued += minted;
        // The remainder is booked by completion; it cannot fund a repeated call.
        _rejectContract(consumer, data, _deliveryError(amount, 0));
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

    function _deliveryError(uint256 requested, uint256 delivered) private pure returns (bytes memory) {
        return abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, requested, delivered);
    }

    function _otherHolders(address except) private view returns (bytes32 digest) {
        for (uint256 i; i < 3; ++i) {
            if (address(actors[i]) != except) {
                digest = keccak256(abi.encode(digest, _accountDigest(address(actors[i]))));
            }
        }
        digest = keccak256(abi.encode(digest, _accountDigest(address(environment)), _accountDigest(address(0xdEaD))));
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
        (uint256 deployed0, uint256 deployed1) = ISequenceReserve(address(vault)).deployedReserve();
        return keccak256(abi.encode(digest, deployed0, deployed1));
    }

    function assertAccounting() public view {
        assertEq(vault.totalSupply(), initialSupply + issued - burned, "all mint and burn attributed");
        uint256 held = vault.balanceOf(address(environment)) + vault.balanceOf(address(0xdEaD));
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
        assertEq(vault.reserveOfToken(address(token0)), token0.balanceOf(address(vault)), "token0 custody fully booked");
        assertEq(vault.reserveOfToken(address(token1)), token1.balanceOf(address(vault)), "token1 custody fully booked");
    }

    function assertCampaignCoverage() external view {
        assertGe(steps, ACTIONS, "campaign reached every action");
        for (uint256 i; i < ACTIONS; ++i) {
            assertGt(attempted[i], 0, "required action attempted");
            if (_attackAction(i)) {
                uint256 checks = i == 17 || i == 19 ? 2 : 1;
                assertEq(expectedReverts[i], attempted[i] * checks, "expected attacks reached and rejected");
            } else {
                assertEq(succeeded[i], attempted[i], "every valid action succeeded");
            }
            assertEq(unexpectedReverts[i], 0);
        }
        assertGt(expectedReverts[21], 0, "callback reached lock");
        assertEq(expectedReverts[13], attempted[13] * 5, "post-trade checks reached before reserve sync");
        assertEq(expectedReverts[22], attempted[22], "partially consumed credit cannot be replayed");
        for (uint256 i; i < 3; ++i) {
            assertGt(actorMoneyCalls[i], 0, "each funded holder participated");
            assertGt(refundModes[i], 0, "full, partial and only-used credit exercised");
        }
    }

    function _attackAction(uint256 action) private pure returns (bool) {
        return action == 17 || action == 18 || action == 19 || action == 20 || action == 23;
    }
}
