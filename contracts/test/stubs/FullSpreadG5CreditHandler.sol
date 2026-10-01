// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {FullSpreadG5GuardToken} from "contracts/test/stubs/FullSpreadG5GuardToken.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {IStandardizedYield as SY} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

interface IFullSpreadG5HistoryEnvironment {
    function g5HistoryTrade(bool direction_, uint256 amount_) external;
    function g5HistorySleeve(uint256 percentage_) external;
}

interface IFullSpreadG5HistoryReserve {
    function rebalanceLiquidReserve() external;
    function targetLiquidReservePercentage() external view returns (uint256);
}

// tag::FullSpreadG5CreditHandler[]
/// @notice Three funded contract-wallet actors exercise missing credit/custody histories.
/// @dev Eight scoped fuzz actions plus a separate mixed money/reentry history.
/// No catch-all success, fake core state or reset between steps. Formula correctness
/// remains with the existing independent campaign and route-specific reference suites.
contract FullSpreadG5CreditHandler is Test, IUnlockCallback {
    struct ExactShareFrame {
        uint256 used;
        uint256 maximum;
        uint256 delivered;
        uint256 beforeTokens;
        uint256 beforeOutput;
        bytes32 others;
    }
    struct MoneyFrame {
        uint256 inputBefore;
        uint256 outputBefore;
        uint256 quote;
        bytes32 others;
    }
    IStandardExchangeProxy public immutable vault;
    IPoolManager public immutable manager;
    address public immutable fixture;
    address public immutable hook;
    IERC20[2] public tokens;
    AtomicPretransferCaller[3] public actors;
    AtomicPretransferCaller public immutable attacker;
    address public constant EOA_ATTACKER = address(0x650BAD);
    FullSpreadG5GuardToken private callbackToken;
    uint256 private callbackShares;
    uint256[3] public mixedMoneyCalls;
    uint256 public mixedRejections;
    uint256[3] public expectedShares;
    uint256[3] public moneyCalls;
    uint256[3] public refundModes;
    uint256[8] public attempted;
    uint256[8] public succeeded;
    uint256[8] public expectedReverts;
    uint256 public steps;
    uint256 public issued;
    uint256 public burned;
    uint256 public initialSupply;
    uint256 public fixtureShares;
    uint256[2] private custody;
    bool private active;

    /// @notice Attach the real proxy and manager; callers fund actors before start().
    constructor(IStandardExchangeProxy vault_, IPoolManager manager_, IERC20 a_, IERC20 b_, address hook_) {
        vault = vault_; manager = manager_; tokens = [a_, b_]; fixture = msg.sender; hook = hook_;
        attacker = new AtomicPretransferCaller();
        for (uint256 i; i < 3; ++i) actors[i] = new AtomicPretransferCaller();
    }

    /// @notice Snapshot independently funded ledgers and approve only actual test wallets.
    function start() external {
        require(msg.sender == fixture && initialSupply == 0, "G5 start");
        initialSupply = vault.totalSupply(); fixtureShares = vault.balanceOf(fixture);
        assertGt(initialSupply, 0);
        for (uint256 i; i < 3; ++i) {
            expectedShares[i] = vault.balanceOf(address(actors[i]));
            assertGt(expectedShares[i], 0);
            actors[i].execute(address(vault), abi.encodeCall(IERC20.approve, (address(actors[i]), type(uint256).max)));
            for (uint256 leg; leg < 2; ++leg) {
                assertGt(tokens[leg].balanceOf(address(actors[i])), 0);
                actors[i].execute(address(tokens[leg]), abi.encodeCall(IERC20.approve, (address(vault), type(uint256).max)));
                actors[i].execute(address(tokens[leg]), abi.encodeCall(IERC20.approve, (address(actors[i]), type(uint256).max)));
            }
        }
        custody = [_custody(0), _custody(1)]; assertAccounting();
    }

    /// @notice Combined money, market-movement and callback history on all three real wallets.
    /// @dev Complements the 48-step fuzz path without requiring a literal legacy action-count clone.
    function runMixedHistories(FullSpreadG5GuardToken hostile_) external {
        require(msg.sender == fixture && steps == 0, "G5 mixed driver");
        require(address(hostile_) == address(tokens[0]) || address(hostile_) == address(tokens[1]), "G5 asset");
        callbackToken = hostile_;
        // Move above the tick-zero first-step boundary through actual core trading.
        IFullSpreadG5HistoryEnvironment(fixture).g5HistoryTrade(false, 1e18);
        for (uint256 actor; actor < 3; ++actor) {
            for (uint256 leg; leg < 2; ++leg) {
                _directExactOut(actor, leg, false);
                _directExactOut(actor, leg, true);
            }
        }
        for (uint256 actor; actor < 3; ++actor) {
            for (uint256 leg; leg < 2; ++leg) {
                for (uint256 funding; funding < 2; ++funding) {
                    bool pushed = funding == 1;
                    _moneyIn(actor, tokens[leg], IERC20(address(vault)), 1e18, pushed, false);
                    _moneyIn(actor, tokens[leg], tokens[1 - leg], 1e14, pushed, false);
                    _moneyIn(actor, IERC20(address(vault)), tokens[leg], 1e14, pushed, false);
                    _moneyIn(actor, IERC20(address(vault)), tokens[leg], 1e14, pushed, true);
                }
                _stagedShort(actor, tokens[leg], 1e14);
            }
            _postTradeFiveRejects(actor % 2 == 0);
            // Positive fee checkpoint follows the real trade and all five pre-sync rejects.
            _moneyIn(actor, tokens[actor % 2], IERC20(address(vault)), 1e18, false, false);
            _callbackHistory(actor);
            _atomicDirectSlippage(actor, tokens[actor % 2]);
            _donationAndRepair(actor, tokens[actor % 2]);
            assertAccounting();
        }
        uint256[4] memory sleeves = [uint256(0.02e18), 0.5e18, 1e18, 0.2e18];
        for (uint256 i; i < sleeves.length; ++i) {
            IFullSpreadG5HistoryEnvironment(fixture).g5HistorySleeve(sleeves[i]);
            assertEq(IFullSpreadG5HistoryReserve(address(vault)).targetLiquidReservePercentage(), sleeves[i]);
            _repairWithoutReward();
            _moneyIn(i % 3, tokens[i % 2], IERC20(address(vault)), 1e15, false, true);
        }
        assertEq(mixedRejections, 30, "five pre-sync + staged + callback + late swap guards");
        for (uint256 i; i < 3; ++i) assertEq(mixedMoneyCalls[i], i == 0 ? 27 : 26, "all scheduled money paths executed");
        assertGt(issued, 0); assertGt(burned, 0); assertEq(callbackShares, 3e18);
        assertAccounting();
    }

    function _moneyIn(uint256 index_, IERC20 input_, IERC20 output_, uint256 amount_, bool push_, bool blocked_) private {
        MoneyFrame memory frame;
        {
            bytes memory preview = abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (input_, amount_, output_));
            frame.quote = abi.decode(_actorCall(index_, _execute(preview), blocked_), (uint256));
        }
        assertGt(frame.quote, 0, "positive current-domain quote");
        frame.inputBefore = input_.balanceOf(address(actors[index_]));
        frame.outputBefore = output_.balanceOf(address(actors[index_]));
        frame.others = _otherHolders(index_);
        if (!push_ && address(input_) != address(vault)) {
            actors[index_].execute(address(input_), abi.encodeCall(IERC20.approve, (address(vault), amount_)));
        }
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (input_, amount_, output_, frame.quote, address(actors[index_]), push_, block.timestamp));
        uint256 received = abi.decode(_actorCall(index_,
            push_ ? _push(index_, input_, amount_, data) : _execute(data), blocked_), (uint256));
        assertEq(received, frame.quote);
        assertEq(frame.inputBefore - input_.balanceOf(address(actors[index_])), amount_, "EI no refund");
        assertEq(output_.balanceOf(address(actors[index_])) - frame.outputBefore, received, "EI exact receipt");
        assertEq(_otherHolders(index_), frame.others, "other holders' assets/shares/approvals unchanged");
        if (address(input_) == address(vault)) { expectedShares[index_] -= amount_; burned += amount_; }
        if (address(output_) == address(vault)) { expectedShares[index_] += received; issued += received; }
        ++mixedMoneyCalls[index_]; assertAccounting();
    }

    function _directExactOut(uint256 index_, uint256 leg_, bool push_) private {
        ExactShareFrame memory frame;
        IERC20 input = tokens[leg_];
        IERC20 output = tokens[1 - leg_];
        frame.used = vault.previewExchangeOut(input, output, 1e12);
        assertGt(frame.used, 0);
        frame.maximum = frame.used * 4 + 1;
        frame.delivered = index_ == 0 ? frame.used : index_ == 1 ? frame.used + frame.used / 4 + 1 : frame.maximum;
        frame.beforeTokens = input.balanceOf(address(actors[index_]));
        frame.beforeOutput = output.balanceOf(address(actors[index_]));
        frame.others = _otherHolders(index_);
        if (!push_) actors[index_].execute(address(input), abi.encodeCall(IERC20.approve, (address(vault), frame.maximum)));
        bytes memory data = abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (input, frame.maximum, output, 1e12, address(actors[index_]), push_, block.timestamp));
        assertEq(abi.decode(_actorCall(index_, push_ ? _push(index_, input, frame.delivered, data) : _execute(data), false), (uint256)), frame.used);
        assertEq(frame.beforeTokens - input.balanceOf(address(actors[index_])), frame.used);
        assertEq(output.balanceOf(address(actors[index_])) - frame.beforeOutput, 1e12);
        if (push_) assertEq(input.balanceOf(address(actors[index_])) - (frame.beforeTokens - frame.delivered), frame.delivered - frame.used);
        else assertEq(input.allowance(address(actors[index_]), address(vault)), frame.maximum - frame.used);
        assertEq(_otherHolders(index_), frame.others);
        ++mixedMoneyCalls[index_]; assertAccounting();
    }

    function _stagedShort(uint256 index_, IERC20 token_, uint256 requested_) private {
        uint256 payer = token_.balanceOf(address(actors[index_]));
        uint256 local = token_.balanceOf(address(vault));
        bytes32 others = _otherHolders(index_);
        actors[index_].execute(address(token_), abi.encodeCall(IERC20.transfer, (address(vault), requested_ - 1)));
        _reject(index_, _execute(_in(token_, requested_, index_, true, 0)), _delivery(requested_, requested_ - 1));
        ++mixedRejections;
        assertEq(token_.balanceOf(address(actors[index_])), payer - requested_ + 1);
        assertEq(token_.balanceOf(address(vault)), local + requested_ - 1);
        uint256 received = abi.decode(_blocked(index_, _execute(_in(token_, requested_ - 1, index_, true, 0))), (uint256));
        assertGt(received, 0); issued += received; expectedShares[index_] += received;
        assertEq(token_.balanceOf(address(actors[index_])), payer - requested_ + 1, "staged retry no refund");
        assertEq(_otherHolders(index_), others); assertAccounting();
    }

    function _postTradeFiveRejects(bool direction_) private {
        IFullSpreadG5HistoryEnvironment(fixture).g5HistoryTrade(direction_, 1e18);
        // No successful SE action, fee collection or reserve sync occurs between these probes.
        for (uint256 leg; leg < 2; ++leg) {
            bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
                (tokens[leg], 1e14, IERC20(address(vault)), 0, address(attacker), true, block.timestamp));
            _reject(3, _execute(data), _delivery(1e14, 0));
            uint256 needed = _quote(3, abi.encodeCall(IStandardExchangeOut.previewExchangeOut,
                (tokens[leg], IERC20(address(vault)), 1e14)));
            assertGt(needed, 0);
            data = abi.encodeCall(IStandardExchangeOut.exchangeOut,
                (tokens[leg], needed * 4, IERC20(address(vault)), 1e14, address(attacker), true, block.timestamp));
            _reject(3, _execute(data), _delivery(needed, 0));
        }
        bytes32 beforeState = _digest();
        vm.prank(EOA_ATTACKER);
        (bool ok, bytes memory errorData) = address(vault).call(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (tokens[0], 1e14, IERC20(address(vault)), 0, EOA_ATTACKER, true, block.timestamp)));
        assertFalse(ok); assertEq(errorData, abi.encodeWithSelector(ISecurePullErrors.EOAPretransferNotAllowed.selector));
        assertEq(_digest(), beforeState); mixedRejections += 5; assertAccounting();
    }

    function _callbackHistory(uint256 index_) private {
        actors[index_].execute(address(vault), abi.encodeCall(IERC20.transfer, (address(callbackToken), 1e18)));
        expectedShares[index_] -= 1e18; callbackShares += 1e18;
        IERC20 input = IERC20(address(callbackToken));
        IERC20 output = address(input) == address(tokens[0]) ? tokens[1] : tokens[0];
        for (uint256 mode; mode < 2; ++mode) {
            bytes memory nested = mode == 0
                ? abi.encodeCall(SY.redeem, (address(attacker), 1e14, address(output), 0, false))
                : abi.encodeCall(IStandardExchangeIn.exchangeIn,
                    (IERC20(address(vault)), 1e14, output, 0, address(attacker), false, block.timestamp));
            callbackToken.setCallback(address(vault), nested, false);
            _moneyIn(index_, input, IERC20(address(vault)), 1e15, false, true);
            assertEq(callbackToken.callbackAttempts(), 1);
            assertEq(callbackToken.callbackError(), abi.encodeWithSelector(IReentrancyLock.IsLocked.selector));
            assertEq(vault.balanceOf(address(callbackToken)), callbackShares);
            callbackToken.setCallback(address(vault), nested, true);
            actors[index_].execute(address(input), abi.encodeCall(IERC20.approve, (address(vault), 1e15)));
            _reject(index_, _execute(_in(input, 1e15, index_, false, 0)), abi.encodeWithSelector(IReentrancyLock.IsLocked.selector));
            ++mixedRejections; assertEq(callbackToken.callbackAttempts(), 0);
            callbackToken.setCallback(address(0), "", false);
            _moneyIn(index_, input, IERC20(address(vault)), 1e15, false, true);
        }
    }

    function _atomicDirectSlippage(uint256 index_, IERC20 input_) private {
        bytes memory data = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (input_, 1e15, address(input_) == address(tokens[0]) ? tokens[1] : tokens[0],
                type(uint256).max, address(actors[index_]), false, block.timestamp));
        bytes32 beforeState = _digest();
        (bool ok, bytes memory reason) = address(actors[index_]).call(abi.encodeCall(AtomicPretransferCaller.consumePull,
            (input_, address(actors[index_]), address(vault), 1e15, data)));
        assertFalse(ok); assertEq(reason, abi.encodeWithSignature("UniswapV4ExchangeIn_SlippageExceeded()"));
        assertEq(_digest(), beforeState, "actual idle swap and in-call approvals roll back");
        ++mixedRejections; assertAccounting();
    }

    function _donationAndRepair(uint256 index_, IERC20 token_) private {
        uint256 beforeBalance = token_.balanceOf(address(actors[index_]));
        actors[index_].execute(address(token_), abi.encodeCall(IERC20.transfer, (address(vault), 1e14)));
        _repairWithoutReward();
        assertEq(token_.balanceOf(address(actors[index_])), beforeBalance - 1e14);
    }
    function _repairWithoutReward() private {
        bytes32 holders = _allHolderAccounts();
        IFullSpreadG5HistoryReserve(address(vault)).rebalanceLiquidReserve();
        assertEq(_allHolderAccounts(), holders, "repair pays no caller/holder and changes no approvals");
        assertAccounting();
    }
    function _actorCall(uint256 index_, bytes memory payload_, bool blocked_) private returns (bytes memory) {
        if (blocked_) return _blocked(index_, payload_);
        (bool ok, bytes memory result) = address(actors[index_]).call(payload_);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        return abi.decode(result, (bytes));
    }

    /// @notice One sequential operation; deterministic scheduling guarantees every actor/action pair.
    function step(uint256 seed_) external {
        require(msg.sender == fixture, "G5 driver");
        uint256 action = steps % 8;
        uint256 actorIndex = (steps / 8) % 3;
        IERC20 token = tokens[(seed_ >> 8) % 2];
        uint256 amount = 1e14 * (1 + (seed_ >> 16) % 8);
        ++attempted[action];
        if (action == 0) _transfer(actorIndex, amount);
        else if (action == 1) _mint(actorIndex, token, amount, false);
        else if (action == 2) {
            _mint(actorIndex, token, amount, true);
            _reject(actorIndex, _execute(_in(token, amount, actorIndex, true, 0)), _delivery(amount, 0));
            ++expectedReverts[action];
        } else if (action == 3) {
            _reject(actorIndex, _push(actorIndex, token, amount - 1, _in(token, amount, actorIndex, true, 0)),
                _delivery(amount, amount - 1));
            ++expectedReverts[action];
        } else if (action == 4) _restingPartial(actorIndex, token, amount);
        else if (action == 5) {
            _reject(actorIndex, _push(actorIndex, token, amount, _in(token, amount, actorIndex, true, type(uint256).max)),
                abi.encodeWithSignature("UniswapV4ExchangeIn_SlippageExceeded()"));
            ++expectedReverts[action];
            _mint(actorIndex, token, amount, true);
        } else _exactShares(actorIndex, token, amount, action == 7);
        if (action != 3) ++succeeded[action];
        if (action != 0 && action != 3) ++moneyCalls[actorIndex];
        ++steps; assertAccounting();
    }

    function _transfer(uint256 index_, uint256 amount_) private {
        uint256 recipient = (index_ + 1) % 3;
        actors[index_].execute(address(vault), abi.encodeCall(IERC20.transfer, (address(actors[recipient]), amount_)));
        expectedShares[index_] -= amount_; expectedShares[recipient] += amount_;
    }
    function _mint(uint256 index_, IERC20 token_, uint256 amount_, bool push_) private {
        bytes32 others = _otherHolders(index_);
        uint256 quote = _quote(index_, abi.encodeCall(IStandardExchangeIn.previewExchangeIn,
            (token_, amount_, IERC20(address(vault)))));
        uint256 beforeTokens = token_.balanceOf(address(actors[index_]));
        if (!push_) actors[index_].execute(address(token_), abi.encodeCall(IERC20.approve, (address(vault), amount_)));
        bytes memory data = _in(token_, amount_, index_, push_, quote);
        uint256 received = abi.decode(_blocked(index_, push_ ? _push(index_, token_, amount_, data) : _execute(data)), (uint256));
        assertGt(received, 0); assertEq(received, quote);
        assertEq(beforeTokens - token_.balanceOf(address(actors[index_])), amount_);
        if (!push_) assertEq(token_.allowance(address(actors[index_]), address(vault)), 0);
        expectedShares[index_] += received; issued += received;
        assertEq(_otherHolders(index_), others);
    }
    function _restingPartial(uint256 index_, IERC20 token_, uint256 amount_) private {
        uint256 payer = (index_ + 1) % 3;
        uint256 beforePayer = token_.balanceOf(address(actors[payer]));
        uint256 beforeConsumer = token_.balanceOf(address(actors[index_]));
        actors[payer].execute(address(token_), abi.encodeCall(IERC20.transfer, (address(vault), amount_ * 2)));
        // This funding preceded the call: a failed route must leave it in custody.
        _reject(index_, _execute(_in(token_, amount_, index_, true, type(uint256).max)),
            abi.encodeWithSignature("UniswapV4ExchangeIn_SlippageExceeded()"));
        uint256 received = abi.decode(_blocked(index_, _execute(_in(token_, amount_, index_, true, 0))), (uint256));
        assertGt(received, 0); expectedShares[index_] += received; issued += received;
        assertEq(token_.balanceOf(address(actors[payer])), beforePayer - 2 * amount_);
        assertEq(token_.balanceOf(address(actors[index_])), beforeConsumer, "EI must not refund unclaimed surplus");
        assertEq(vault.reserveOfToken(address(token_)), token_.balanceOf(address(vault)));
        _reject(index_, _execute(_in(token_, amount_, index_, true, 0)), _delivery(amount_, 0));
        expectedReverts[4] += 2;
    }
    function _exactShares(uint256 index_, IERC20 token_, uint256 shares_, bool push_) private {
        ExactShareFrame memory frame;
        frame.others = _otherHolders(index_);
        frame.used = _quote(index_, abi.encodeCall(IStandardExchangeOut.previewExchangeOut,
            (token_, IERC20(address(vault)), shares_)));
        assertGt(frame.used, 0);
        frame.maximum = frame.used + 1e14;
        frame.delivered = frame.used;
        if (push_) {
            // Independently cover used-only, partial budget, and complete budget delivery.
            uint256 mode = index_;
            if (mode == 1) frame.delivered += 5e13;
            if (mode == 2) frame.delivered = frame.maximum;
            ++refundModes[mode];
        }
        frame.beforeTokens = token_.balanceOf(address(actors[index_]));
        if (!push_) actors[index_].execute(address(token_), abi.encodeCall(IERC20.approve, (address(vault), frame.used)));
        bytes memory data = abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (token_, frame.maximum, IERC20(address(vault)), shares_, address(actors[index_]), push_, block.timestamp));
        assertEq(abi.decode(_blocked(index_, push_ ? _push(index_, token_, frame.delivered, data) : _execute(data)), (uint256)), frame.used);
        assertEq(frame.beforeTokens - token_.balanceOf(address(actors[index_])), frame.used, "EO exact net debit/refund");
        if (!push_) assertEq(token_.allowance(address(actors[index_]), address(vault)), 0);
        expectedShares[index_] += shares_; issued += shares_;
        assertEq(_otherHolders(index_), frame.others);
    }
    function _in(IERC20 token_, uint256 amount_, uint256 index_, bool pushed_, uint256 minimum_)
        private view returns (bytes memory)
    {
        return abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (token_, amount_, IERC20(address(vault)), minimum_, address(actors[index_]), pushed_, block.timestamp));
    }
    function _execute(bytes memory data_) private view returns (bytes memory) {
        return abi.encodeCall(AtomicPretransferCaller.execute, (address(vault), data_));
    }
    function _push(uint256 index_, IERC20 token_, uint256 amount_, bytes memory data_) private view returns (bytes memory) {
        return abi.encodeCall(AtomicPretransferCaller.consumePretransfer,
            (token_, address(actors[index_]), address(vault), amount_, data_));
    }
    function _quote(uint256 index_, bytes memory data_) private returns (uint256) {
        return abi.decode(_blocked(index_, _execute(data_)), (uint256));
    }
    function _blocked(uint256 index_, bytes memory data_) private returns (bytes memory) {
        active = true;
        bytes memory result = manager.unlock(abi.encode(index_, data_));
        active = false;
        return abi.decode(result, (bytes)); // actor's execute/consume returns bytes
    }
    /// @notice Real outer manager session: the wallet calls the production vault as itself.
    function unlockCallback(bytes calldata data_) external returns (bytes memory result_) {
        require(msg.sender == address(manager) && active, "G5 callback");
        (uint256 index, bytes memory payload) = abi.decode(data_, (uint256, bytes));
        address caller = index == 3 ? address(attacker) : address(actors[index]);
        bool ok; (ok, result_) = caller.call(payload);
        if (!ok) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
    }
    function _reject(uint256 index_, bytes memory data_, bytes memory error_) private {
        bytes32 beforeState = _digest();
        active = true;
        (bool ok, bytes memory reason) = address(manager).call(abi.encodeCall(IPoolManager.unlock, (abi.encode(index_, data_))));
        active = false;
        assertFalse(ok, "G5 attack unexpectedly succeeded"); assertEq(reason, error_, "G5 exact rejection");
        assertEq(_digest(), beforeState, "G5 full actor/custody rollback");
    }
    function _delivery(uint256 requested_, uint256 available_) private pure returns (bytes memory) {
        return abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, requested_, available_);
    }
    function _custody(uint256 leg_) private view returns (uint256 sum_) {
        IERC20 token = tokens[leg_];
        sum_ = token.balanceOf(fixture) + token.balanceOf(address(vault)) + token.balanceOf(address(manager))
            + token.balanceOf(address(this)) + token.balanceOf(address(attacker)) + token.balanceOf(EOA_ATTACKER);
        if (hook != address(0)) sum_ += token.balanceOf(hook);
        if (address(callbackToken) != address(0)) sum_ += token.balanceOf(address(callbackToken));
        for (uint256 i; i < 3; ++i) sum_ += token.balanceOf(address(actors[i]));
    }
    function _digest() private view returns (bytes32 result_) {
        (bytes memory book,) = Transition(address(vault)).quoteState(address(tokens[0]), fixture);
        result_ = keccak256(abi.encode(book, vault.totalSupply(), vault.balanceOf(address(vault)),
            vault.reserveOfToken(address(vault)), _custody(0), _custody(1), _allHolderAccounts()));
        for (uint256 i; i < 3; ++i) {
            address actor = address(actors[i]);
            result_ = keccak256(abi.encode(result_, vault.balanceOf(actor), tokens[0].balanceOf(actor),
                tokens[1].balanceOf(actor), tokens[0].allowance(actor, address(vault)), tokens[1].allowance(actor, address(vault))));
        }
        for (uint256 leg; leg < 2; ++leg) result_ = keccak256(abi.encode(result_, tokens[leg].totalSupply(),
            tokens[leg].balanceOf(address(vault)), tokens[leg].balanceOf(address(manager)), tokens[leg].balanceOf(hook),
            vault.reserveOfToken(address(tokens[leg]))));
    }
    function _accountDigest(address account_) private view returns (bytes32 result_) {
        IERC20[3] memory assets = [tokens[0], tokens[1], IERC20(address(vault))];
        for (uint256 i; i < 3; ++i) result_ = keccak256(abi.encode(result_, assets[i].balanceOf(account_),
            assets[i].allowance(account_, address(vault)), assets[i].allowance(account_, account_)));
    }
    function _passiveAccounts() private view returns (bytes32) {
        return keccak256(abi.encode(_accountDigest(fixture), _accountDigest(address(0xdEaD)),
            _accountDigest(address(callbackToken)), _accountDigest(address(attacker)),
            _accountDigest(EOA_ATTACKER), _accountDigest(address(this))));
    }
    function _otherHolders(uint256 index_) private view returns (bytes32 result_) {
        result_ = _passiveAccounts();
        for (uint256 i; i < 3; ++i) if (i != index_) result_ = keccak256(abi.encode(result_, _accountDigest(address(actors[i]))));
    }
    function _allHolderAccounts() private view returns (bytes32 result_) {
        return _otherHolders(3);
    }
    /// @notice Reconcile every share holder, global custody, and all three locally booked assets.
    function assertAccounting() public view {
        assertEq(vault.totalSupply(), initialSupply + issued - burned);
        assertEq(vault.balanceOf(fixture), fixtureShares, "passive fixture shares");
        uint256 shareSum = fixtureShares + vault.balanceOf(address(0xdEaD)) + callbackShares;
        for (uint256 i; i < 3; ++i) {
            assertEq(vault.balanceOf(address(actors[i])), expectedShares[i]); shareSum += expectedShares[i];
        }
        assertEq(vault.balanceOf(address(this)), 0); assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.balanceOf(address(callbackToken)), callbackShares);
        assertEq(vault.balanceOf(address(attacker)), 0); assertEq(vault.balanceOf(EOA_ATTACKER), 0);
        assertEq(vault.totalSupply(), shareSum);
        assertEq(vault.reserveOfToken(address(vault)), 0);
        for (uint256 leg; leg < 2; ++leg) {
            assertEq(tokens[leg].balanceOf(address(attacker)), 0);
            assertEq(tokens[leg].balanceOf(EOA_ATTACKER), 0);
            assertEq(tokens[leg].balanceOf(address(this)), 0, "no handler reward");
            assertEq(_custody(leg), custody[leg]);
            assertEq(_custody(leg), tokens[leg].totalSupply(), "complete token custody universe");
            assertEq(vault.reserveOfToken(address(tokens[leg])), tokens[leg].balanceOf(address(vault)));
        }
        assertEq(address(vault).balance, 0);
    }
    /// @notice Require non-vacuous successes, known rejections, actors and all three refund budgets.
    function assertCoverage() external view {
        assertEq(steps, 48);
        for (uint256 i; i < 8; ++i) {
            assertEq(attempted[i], 6); assertEq(succeeded[i], i == 3 ? 0 : 6);
            uint256 rejects = i == 4 ? 12 : (i == 2 || i == 3 || i == 5 ? 6 : 0);
            assertEq(expectedReverts[i], rejects);
        }
        for (uint256 i; i < 3; ++i) { assertEq(moneyCalls[i], 12); assertEq(refundModes[i], 2); }
    }
}
// end::FullSpreadG5CreditHandler[]
