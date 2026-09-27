// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

interface IInvariantHookLiquidity {
    function joinProportional(uint256[] calldata amounts, address to, uint256 minShares, uint256 deadline)
        external
        returns (uint256 shares, uint256[] memory used);
    function exitProportional(uint256 shares, address to, uint256[] calldata minAmounts, uint256 deadline)
        external
        returns (uint256[] memory amounts);
}

interface IInvariantCpLiquidity {
    function deposit(uint256 a0, uint256 a1, address to, uint256 minShares, uint256 deadline)
        external
        returns (uint256 shares, uint256 used0, uint256 used1);
    function withdraw(uint256 shares, address to, uint256 min0, uint256 min1, uint256 deadline)
        external
        returns (uint256 out0, uint256 out1);
}

interface IInvariantOrbitalLiquidity {
    function radius() external view returns (uint256);
    function effectiveReserves() external view returns (uint256, uint256, uint256);
    function addLiquidity(
        uint256 a0,
        uint256 a1,
        uint256 a2,
        address to,
        uint256 minShares,
        uint256 deadline,
        bytes calldata permit
    ) external returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2);
    function removeLiquidity(uint256 shares, address to, uint256 min0, uint256 min1, uint256 min2, uint256 deadline)
        external
        returns (uint256 out0, uint256 out1, uint256 out2);
}

/// @notice Stateful production liquidity, swap, inventory and rollback accounting for six LP hook families.
/// @dev No successful actions are seeded in setup; no action failure is swallowed. Cycle order guarantees
///      every category and all three honest actors execute during each 64-call campaign. Funding amounts,
///      partial burns, share recipients and trade sizes remain randomized. Callback-token reentrancy and
///      fee administration are covered by their dedicated hostile-token/governance suites, not this fixture.
contract HookLiquidityInvariantHandler is Test {
    using BalanceDeltaLibrary for BalanceDelta;

    struct Config {
        address hook;
        SimpleMintableERC20[] tokens;
        uint8 mode; // 0 proportional, 1 constant product, 2 orbital
        address input;
        address output;
        address inputSE;
        address inputVault;
        address feeRecipient;
        WrapperExactOutRouter router;
        PoolKey key;
        IERC20[] observedTokens;
        address[] observedHolders;
    }
    address public immutable hook;
    uint8 internal immutable mode;
    SimpleMintableERC20[] internal tokens;
    IERC20 internal immutable input;
    IERC20 internal immutable output;
    address internal immutable inputSE;
    address internal immutable inputVault;
    address internal immutable feeRecipient;
    uint256 internal immutable initialSupply;
    uint256 internal immutable initialFeeShares;
    uint256 internal immutable initialLockedShares;
    WrapperExactOutRouter internal immutable router;
    PoolKey internal key;
    IERC20[] internal observedTokens;
    address[] internal observedHolders;
    AtomicPretransferCaller public immutable caller;
    address[3] public actors = [address(0xCA1101), address(0xCA1102), address(0xCA1103)];
    address public constant attacker = address(0xBAD110);
    uint256 public ghost_join;
    uint256 public ghost_exit;
    uint256 public attempted;
    uint256 public ghost_minted;
    uint256 public ghost_burned;
    mapping(address actor => uint256 shares) public expectedShares;
    uint256[8] public actionAttempts;
    uint256[8] public actionSuccesses;
    uint256[8] public expectedReverts;
    uint256 public unexpectedReverts;

    constructor(Config memory c) {
        hook = c.hook;
        mode = c.mode;
        tokens = c.tokens;
        input = IERC20(c.input);
        output = IERC20(c.output);
        inputSE = c.inputSE;
        inputVault = c.inputVault;
        feeRecipient = c.feeRecipient;
        initialSupply = IERC20(c.hook).totalSupply();
        initialFeeShares = IERC20(c.hook).balanceOf(c.feeRecipient);
        initialLockedShares = IERC20(c.hook).balanceOf(address(0));
        router = c.router;
        key = c.key;
        observedTokens = c.observedTokens;
        observedHolders = c.observedHolders;
        caller = new AtomicPretransferCaller();
    }

    function cycle(uint256 amountSeed, uint256 recipientSeed, uint256 exitSeed) public {
        uint256 step = attempted++;
        // The first 24 randomized funded cycles guarantee every actor/action pair. Remaining
        // campaign cycles randomize ordering as well as amounts; setup performs no handler actions.
        address actor = actors[(step < 24 ? step : recipientSeed) % 3];
        uint256 action = (step < 24 ? step : amountSeed) % 8;
        uint256 amountToJoin = bound(amountSeed, 1 ether, 20 ether);
        if (mode == 2 && IERC20(hook).totalSupply() != 0) {
            // Orbital's radius is fixed at bootstrap. Construct a valid funded join from its
            // public admission bound instead of repeatedly adding until the documented cap fails.
            (uint256 e0, uint256 e1, uint256 e2) = IInvariantOrbitalLiquidity(hook).effectiveReserves();
            uint256 largest = e0 > e1 ? e0 : e1;
            if (e2 > largest) largest = e2;
            uint256 cap = (IInvariantOrbitalLiquidity(hook).radius() - largest) / 4;
            assertGt(cap, 1e12, "orbital campaign retains funded join headroom");
            if (amountToJoin > cap) amountToJoin = cap;
        }
        uint256 minted = _join(actor, amountToJoin);
        uint256 toBurn = mode == 2
            ? bound(exitSeed, IERC20(hook).balanceOf(actor) / 2, IERC20(hook).balanceOf(actor) * 3 / 4)
            : bound(exitSeed, minted / 4, minted / 2);
        _exit(actor, toBurn);
        ++actionAttempts[action];
        uint256 amount = bound(amountSeed, 1e12, 1e15);
        if (action < 4) _trade(actor, amount, action);
        else if (action == 4) _donateAndTransfer(actor, recipientSeed, amount);
        else if (action == 5) _unfundedControls(amount);
        else if (action == 6) _rollback(actor, amount);
        else _poolTrade(actor, amount);
        ++actionSuccesses[action];
    }

    function _join(address actor, uint256 amount) internal returns (uint256 minted) {
        uint256[] memory amounts = new uint256[](tokens.length);
        uint256[] memory beforeBalances = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; ++i) {
            tokens[i].mint(actor, amount);
            amounts[i] = amount;
            beforeBalances[i] = tokens[i].balanceOf(actor);
            vm.prank(actor);
            tokens[i].approve(hook, amount);
        }
        uint256 beforeShares = IERC20(hook).balanceOf(actor);
        uint256[] memory used = new uint256[](tokens.length);
        vm.prank(actor);
        if (mode == 0) {
            (minted, used) =
                IInvariantHookLiquidity(hook).joinProportional(amounts, actor, 1, block.timestamp + 1 hours);
        } else if (mode == 1) {
            (minted, used[0], used[1]) =
                IInvariantCpLiquidity(hook).deposit(amount, amount, actor, 1, block.timestamp + 1 hours);
        } else {
            (minted, used[0], used[1], used[2]) = IInvariantOrbitalLiquidity(hook)
                .addLiquidity(amount, amount, amount, actor, 1, block.timestamp + 1 hours, "");
        }
        assertGt(minted, 0, "funded join mints");
        assertEq(IERC20(hook).balanceOf(actor) - beforeShares, minted, "actual LP issuance");
        for (uint256 i; i < tokens.length; ++i) {
            assertEq(beforeBalances[i] - tokens[i].balanceOf(actor), used[i], "join input delta");
            assertLe(used[i], amount, "join budget");
        }
        expectedShares[actor] += minted;
        ghost_minted += minted;
        ++ghost_join;
    }

    function _exit(address actor, uint256 shares) internal {
        uint256[] memory beforeBalances = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; ++i) {
            beforeBalances[i] = tokens[i].balanceOf(actor);
        }
        uint256 beforeShares = IERC20(hook).balanceOf(actor);
        uint256[] memory out = new uint256[](tokens.length);
        vm.prank(actor);
        if (mode == 0) {
            out = IInvariantHookLiquidity(hook)
                .exitProportional(shares, actor, new uint256[](tokens.length), block.timestamp + 1 hours);
        } else if (mode == 1) {
            (out[0], out[1]) = IInvariantCpLiquidity(hook).withdraw(shares, actor, 0, 0, block.timestamp + 1 hours);
        } else {
            (out[0], out[1], out[2]) =
                IInvariantOrbitalLiquidity(hook).removeLiquidity(shares, actor, 0, 0, 0, block.timestamp + 1 hours);
        }
        assertEq(beforeShares - IERC20(hook).balanceOf(actor), shares, "exact burn");
        uint256 totalOut;
        for (uint256 i; i < tokens.length; ++i) {
            assertEq(tokens[i].balanceOf(actor) - beforeBalances[i], out[i], "exit delivery");
            totalOut += out[i];
        }
        assertGt(totalOut, 0, "partial exit pays");
        expectedShares[actor] -= shares;
        ghost_burned += shares;
        ++ghost_exit;
    }

    function _inData(uint256 amount, uint256 minOut, address recipient, bool prepaid)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (input, amount, output, minOut, recipient, prepaid, block.timestamp + 1 hours)
        );
    }

    struct TradeState {
        bool exactOut;
        bool prepaid;
        uint256 quote;
        uint256 budget;
        uint256 actorBefore;
        uint256 callerBefore;
        uint256 outBefore;
    }

    function _trade(address actor, uint256 amount, uint256 action) internal {
        TradeState memory v;
        v.exactOut = action % 2 == 1;
        v.prepaid = action >= 2;
        v.quote = v.exactOut
            ? IStandardExchangeOut(hook).previewExchangeOut(input, output, amount)
            : IStandardExchangeIn(hook).previewExchangeIn(input, amount, output);
        v.budget = v.exactOut ? v.quote * 2 : amount;
        SimpleMintableERC20(address(input)).mint(actor, v.budget);
        vm.prank(actor);
        input.approve(v.prepaid ? address(caller) : hook, v.budget);
        v.actorBefore = input.balanceOf(actor);
        v.callerBefore = input.balanceOf(address(caller));
        v.outBefore = output.balanceOf(actor);
        bytes memory data = v.exactOut
            ? abi.encodeCall(
                IStandardExchangeOut.exchangeOut,
                (input, v.budget, output, amount, actor, v.prepaid, block.timestamp + 1 hours)
            )
            : _inData(amount, v.quote, actor, v.prepaid);
        bytes memory returned;
        if (v.prepaid) {
            returned = caller.consumePretransfer(input, actor, hook, v.budget, data);
        } else {
            vm.prank(actor);
            bool ok;
            (ok, returned) = hook.call(data);
            if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        }
        uint256 result = abi.decode(returned, (uint256));
        assertEq(result, v.quote, "swap matches executable quote");
        assertEq(output.balanceOf(actor) - v.outBefore, v.exactOut ? amount : v.quote, "exact delivery");
        assertEq(
            v.actorBefore - input.balanceOf(actor),
            v.prepaid ? v.budget : (v.exactOut ? v.quote : amount),
            "caller debit"
        );
        assertEq(
            input.balanceOf(address(caller)) - v.callerBefore,
            v.prepaid && v.exactOut ? v.budget - v.quote : 0,
            "bounded refund to caller"
        );
        if (v.prepaid) {
            _expectFailure(
                address(caller),
                _inData(amount, 0, attacker, true),
                abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, amount, 0),
                action
            );
        }
    }

    function _donateAndTransfer(address actor, uint256 recipientSeed, uint256 amount) internal {
        SimpleMintableERC20(address(input)).mint(actor, amount);
        vm.startPrank(actor);
        input.approve(inputSE, amount);
        uint256 shares = IStandardExchangeIn(inputSE)
            .exchangeIn(input, amount, IERC20(inputSE), 1, actor, false, block.timestamp + 1 hours);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 bookBefore = IERC20(inputSE).balanceOf(hook);
        IERC20(inputSE).transfer(hook, shares);
        vm.stopPrank();
        assertEq(IERC20(inputSE).balanceOf(hook) - bookBefore, shares, "donation custody");
        assertEq(IERC20(hook).totalSupply(), supplyBefore, "donation mints no LP");
        uint256 actorIndex = actor == actors[0] ? 0 : actor == actors[1] ? 1 : 2;
        address recipient = actors[(actorIndex + 1 + recipientSeed % 2) % 3];
        uint256 transferShares = IERC20(hook).balanceOf(actor) / 7;
        uint256 beforeActor = IERC20(hook).balanceOf(actor);
        uint256 beforeRecipient = IERC20(hook).balanceOf(recipient);
        vm.prank(actor);
        IERC20(hook).transfer(recipient, transferShares);
        expectedShares[actor] -= transferShares;
        expectedShares[recipient] += transferShares;
        assertEq(beforeActor - IERC20(hook).balanceOf(actor), transferShares, "share sender debit");
        assertEq(IERC20(hook).balanceOf(recipient) - beforeRecipient, transferShares, "share receiver credit");
        assertEq(IERC20(hook).totalSupply(), supplyBefore, "share transfer supply");
        // External yield changes the real ERC4626 protocol rate; the next production action must
        // account for it without treating buffered face value as local prepaid inventory.
        SimpleMintableERC20(address(input)).mint(inputVault, amount);
        assertEq(IERC20(hook).totalSupply(), supplyBefore, "external yield cannot directly mint LP");
    }

    function _unfundedControls(uint256 amount) internal {
        _expectFailure(
            attacker,
            _inData(amount, 0, attacker, true),
            abi.encodeWithSelector(ISecurePullErrors.EOAPretransferNotAllowed.selector),
            5
        );
        _expectFailure(
            address(caller),
            _inData(amount, 0, attacker, true),
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, amount, 0),
            5
        );
    }

    function _expectFailure(address sender, bytes memory data, bytes memory errorData, uint256 action) internal {
        bytes32 beforeState = _snapshot();
        bool ok;
        bytes memory reason;
        if (sender == address(caller)) {
            (ok, reason) = address(caller).call(abi.encodeCall(AtomicPretransferCaller.execute, (hook, data)));
        } else {
            vm.prank(sender);
            (ok, reason) = hook.call(data);
        }
        if (ok || keccak256(reason) != keccak256(errorData)) ++unexpectedReverts;
        assertFalse(ok, "attack must fail");
        assertEq(reason, errorData, "intended complete error");
        assertEq(_snapshot(), beforeState, "failed call rolls back balances, books, supply and allowances");
        ++expectedReverts[action];
    }

    function _rollback(address actor, uint256 amount) internal {
        // A preceding transfer is outside the subsequently reverted integrating call.
        SimpleMintableERC20(address(input)).mint(actor, amount * 2);
        vm.startPrank(actor);
        input.transfer(hook, amount);
        input.approve(address(caller), amount);
        vm.stopPrank();
        bytes32 beforeState = _snapshot();
        uint256 quote = IStandardExchangeIn(hook).previewExchangeIn(input, amount, output);
        bytes memory expected =
            abi.encodeWithSelector(bytes4(keccak256(bytes(mode == 0 ? "Slippage()" : "InsufficientTokenOut()"))));
        (bool ok, bytes memory reason) = address(caller)
            .call(
                abi.encodeCall(
                    AtomicPretransferCaller.consumePretransfer,
                    (input, actor, hook, amount, _inData(amount, quote + 1, actor, true))
                )
            );
        assertFalse(ok, "slippage call fails");
        assertEq(reason, expected, "slippage intended error");
        assertEq(_snapshot(), beforeState, "atomic transfer and allowances roll back; prior transfer remains");
        ++expectedReverts[6];
        // Consume the independently resting face once, then reject reuse.
        uint256 beforeOut = output.balanceOf(actor);
        uint256 delivered = abi.decode(caller.execute(hook, _inData(amount, quote, actor, true)), (uint256));
        assertEq(delivered, quote, "resting credit once");
        assertEq(output.balanceOf(actor) - beforeOut, quote, "resting credit delivery");
        _expectFailure(
            address(caller),
            _inData(amount, 0, attacker, true),
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, amount, 0),
            6
        );
    }

    function _poolTrade(address actor, uint256 amount) internal {
        bool zeroForOne = Currency.unwrap(key.currency0) == address(input);
        SimpleMintableERC20(address(input)).mint(actor, amount);
        vm.prank(actor);
        input.approve(address(router), amount);
        uint256 inBefore = input.balanceOf(actor);
        uint256 outBefore = output.balanceOf(actor);
        vm.prank(actor);
        BalanceDelta delta = router.swapExactIn(
            key,
            SwapParams(
                zeroForOne, -int256(amount), zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            ),
            ""
        );
        int128 inDelta = zeroForOne ? delta.amount0() : delta.amount1();
        int128 outDelta = zeroForOne ? delta.amount1() : delta.amount0();
        assertEq(inBefore - input.balanceOf(actor), amount, "pool exact input");
        assertEq(uint256(-int256(inDelta)), amount, "pool input delta");
        assertGt(outDelta, 0, "pool output positive");
        assertEq(output.balanceOf(actor) - outBefore, uint256(int256(outDelta)), "pool actual delivery");
    }

    function _snapshot() internal view returns (bytes32 state) {
        for (uint256 i; i < observedTokens.length; ++i) {
            IERC20 token = observedTokens[i];
            state = keccak256(abi.encode(state, token.totalSupply()));
            for (uint256 j; j < observedHolders.length; ++j) {
                address holder = observedHolders[j];
                state = keccak256(
                    abi.encode(
                        state, token.balanceOf(holder), token.allowance(holder, hook), token.allowance(holder, inputSE)
                    )
                );
            }
            for (uint256 j; j < 6; ++j) {
                address holder = j < 3 ? actors[j] : j == 3 ? attacker : j == 4 ? address(caller) : address(this);
                state = keccak256(
                    abi.encode(
                        state,
                        token.balanceOf(holder),
                        token.allowance(holder, hook),
                        token.allowance(holder, address(caller)),
                        token.allowance(holder, address(router)),
                        token.allowance(holder, inputSE)
                    )
                );
            }
        }
        for (uint256 i; i < tokens.length; ++i) {
            (bool ok, bytes memory book) =
                hook.staticcall(abi.encodeWithSignature("reserveOfToken(address)", address(tokens[i])));
            state = keccak256(abi.encode(state, ok, book));
        }
    }

    function assertAccounting() public view {
        assertEq(ghost_join, attempted, "every randomized join succeeds");
        assertEq(ghost_exit, attempted, "every randomized exit succeeds");
        uint256 shares;
        for (uint256 i; i < 3; ++i) {
            assertEq(IERC20(hook).balanceOf(actors[i]), expectedShares[actors[i]], "each honest holder entitlement");
            shares += IERC20(hook).balanceOf(actors[i]);
        }
        assertEq(shares, ghost_minted - ghost_burned, "all honest LP entitlements accounted exactly");
        assertEq(
            IERC20(hook).totalSupply() - initialSupply,
            shares + IERC20(hook).balanceOf(feeRecipient) - initialFeeShares + IERC20(hook).balanceOf(address(0))
                - initialLockedShares,
            "supply partition: honest, protocol fee and permanently locked shares"
        );
        assertEq(unexpectedReverts, 0, "no unexpected failure");
        for (uint256 i; i < 8; ++i) {
            assertEq(actionAttempts[i], actionSuccesses[i], "every supplementary action succeeds");
        }
    }

    function assertCampaign() external view {
        assertAccounting();
        for (uint256 i; i < 8; ++i) {
            assertGt(actionSuccesses[i], 0, "campaign executes every action");
        }
        assertGt(expectedReverts[2], 0, "exact-in repeated credit rejected");
        assertGt(expectedReverts[3], 0, "exact-out repeated credit rejected");
        assertGt(expectedReverts[5], 1, "EOA and contract rejected");
        assertGt(expectedReverts[6], 1, "rollback and separate credit boundary exercised");
    }
}
