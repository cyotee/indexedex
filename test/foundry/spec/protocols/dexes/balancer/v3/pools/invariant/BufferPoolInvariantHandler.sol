// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRouter} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouter.sol";
import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {PoolSwapParams, SwapKind} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

interface IBufferInvariantFunding {
    /// @dev TestBase adapter funds external tokens or acquires SE shares through the real protocol.
    function fundInvariantToken(address actor, IERC20 token, uint256 amount) external;
}

/// @dev Integration fixture which treats the documented false callback as a failed operation.
contract AtomicFalseHookCaller {
    error CallbackRejected();
    function transferAndCheck(IERC20 token, address payer, address target, uint256 amount, bytes calldata data) external {
        token.transferFrom(payer, target, amount);
        (bool ok, bytes memory returned) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        if (!abi.decode(returned, (bool))) revert CallbackRejected();
    }
}

/// @notice Real Balancer router lifecycles with funded actions, three holders and exact accounting.
/// @dev D32 callbacks reject unauthorized callers by returning false. The handler asserts that exact
///      status and complete rollback at a checking integration boundary. No action is catch-and-ignored.
contract BufferPoolInvariantHandler is Test {
    struct Config {
        address pool;
        IRouter router;
        IVault vault;
        IAllowanceTransfer permit2;
        IERC20 buffer;
        IERC20 shares;
        IERC20[] buffers;
        IERC20 unpaired;
        IBufferInvariantFunding funding;
        bytes[] bookCalls;
        uint256 virtualBookCount;
    }
    address public immutable pool;
    IRouter internal immutable router;
    IVault internal immutable vault;
    IAllowanceTransfer internal immutable permit2;
    IBufferInvariantFunding internal immutable funding;
    IERC20 internal immutable buffer;
    IERC20 internal immutable share;
    IERC20 internal immutable unpaired;
    mapping(IERC20 => bool) internal isBuffer;
    IERC20[] internal tokens;
    bytes[] internal bookCalls;
    uint256 internal immutable virtualBookCount;
    uint256 internal immutable bufferIndex;
    uint256 internal immutable shareIndex;
    uint256 internal immutable initialSupply;
    AtomicPretransferCaller public immutable attackerContract;
    AtomicFalseHookCaller public immutable integrator;
    address[3] public actors = [address(0xBA1101), address(0xBA1102), address(0xBA1103)];
    address public constant attacker = address(0xBAD211);
    uint256 public attempted;
    uint256 public joined;
    uint256 public exited;
    uint256 public minted;
    uint256 public burned;
    mapping(address => uint256) public expectedShares;
    uint256[8] public actionAttempts;
    uint256[8] public actionSuccesses;
    uint256[8] public expectedRejections;

    constructor(Config memory c) {
        pool = c.pool;
        router = c.router;
        vault = c.vault;
        permit2 = c.permit2;
        funding = c.funding;
        buffer = c.buffer;
        share = c.shares;
        unpaired = c.unpaired;
        for (uint256 i; i < c.buffers.length; ++i) isBuffer[c.buffers[i]] = true;
        bookCalls = c.bookCalls;
        virtualBookCount = c.virtualBookCount;
        (IERC20[] memory listed,,,) = c.vault.getPoolTokenInfo(c.pool);
        tokens = listed;
        uint256 bi;
        uint256 si;
        for (uint256 i; i < listed.length; ++i) {
            if (listed[i] == c.buffer) bi = i;
            if (listed[i] == c.shares) si = i;
            for (uint256 j; j < 3; ++j) {
                vm.startPrank(actors[j]);
                listed[i].approve(address(c.permit2), type(uint256).max);
                c.permit2.approve(address(listed[i]), address(c.router), type(uint160).max, type(uint48).max);
                vm.stopPrank();
            }
        }
        bufferIndex = bi;
        shareIndex = si;
        for (uint256 j; j < 3; ++j) {
            vm.startPrank(actors[j]);
            IERC20(c.pool).approve(address(c.router), type(uint256).max);
            IERC20(c.pool).approve(address(c.permit2), type(uint256).max);
            c.permit2.approve(c.pool, address(c.router), type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }
        initialSupply = IERC20(c.pool).totalSupply();
        attackerContract = new AtomicPretransferCaller();
        integrator = new AtomicFalseHookCaller();
    }

    function cycle(uint256 amountSeed, uint256 actorSeed, uint256 exitSeed) external {
        uint256 step = attempted++;
        address actor = actors[(step < 24 ? step : actorSeed) % 3];
        uint256 action = (step < 24 ? step : amountSeed) % 8;
        uint256 bpt = _join(actor, amountSeed);
        _exit(actor, bound(exitSeed, bpt / 4, bpt / 2));
        ++actionAttempts[action];
        uint256 amount = bound(amountSeed, 1e12, 1e15);
        if (action < 4) _swap(actor, amount, action);
        else if (action == 4) _donateAndTransfer(actor, actorSeed, amount);
        else if (action == 5) _falseControls();
        else if (action == 6) _atomicRollback(actor, amount);
        else {
            _joinUnbalanced(actor, amount);
            if (address(unpaired) != address(0)) _swapUnpaired(actor, amount);
        }
        ++actionSuccesses[action];
    }

    function _fundAtLeast(address actor, IERC20 token, uint256 required) internal {
        // Existing honest balances fund subsequent actions. Reacquire external protocol shares
        // only when necessary; do not fabricate shares or skip an action for insufficient funds.
        if (token.balanceOf(actor) < required) funding.fundInvariantToken(actor, token, 100 ether);
        assertGe(token.balanceOf(actor), required, "production funding covers the action");
    }

    function _join(address actor, uint256 seed) internal returns (uint256 bpt) {
        uint256[] memory maxIn = new uint256[](tokens.length);
        uint256[] memory beforeBalances = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; ++i) _fundAtLeast(actor, tokens[i], 1 ether);
        // Acquiring a share token can also move its underlying face token. Snapshot only after
        // all production funding routes finish, immediately before the liquidity operation.
        for (uint256 i; i < tokens.length; ++i) {
            beforeBalances[i] = tokens[i].balanceOf(actor);
            maxIn[i] = beforeBalances[i];
        }
        // Physical buffer can remain after initialization; fund every registered token so the
        // proportional route satisfies the live production book, including any residual face.
        bpt = bound(seed, 1e12, IERC20(pool).totalSupply() / 10000);
        uint256 lpBefore = IERC20(pool).balanceOf(actor);
        uint256 supplyBefore = IERC20(pool).totalSupply();
        int256[] memory booksBefore = _readBooks();
        vm.prank(actor);
        uint256[] memory used = router.addLiquidityProportional(pool, maxIn, bpt, false, "");
        assertEq(IERC20(pool).balanceOf(actor) - lpBefore, bpt, "exact BPT issuance");
        uint256 totalUsed;
        for (uint256 i; i < tokens.length; ++i) {
            totalUsed += used[i];
            assertEq(beforeBalances[i] - tokens[i].balanceOf(actor), used[i], "proportional input debit");
            assertLe(used[i], maxIn[i], "proportional input budget");
        }
        assertGt(totalUsed, 0, "successful join consumes real input");
        _assertScaledBooks(booksBefore, bpt, supplyBefore, true);
        expectedShares[actor] += bpt;
        minted += bpt;
        ++joined;
    }

    function _exit(address actor, uint256 bpt) internal {
        uint256[] memory beforeBalances = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; ++i) beforeBalances[i] = tokens[i].balanceOf(actor);
        uint256 lpBefore = IERC20(pool).balanceOf(actor);
        uint256 supplyBefore = IERC20(pool).totalSupply();
        int256[] memory booksBefore = _readBooks();
        vm.prank(actor);
        uint256[] memory paid = router.removeLiquidityProportional(pool, bpt, new uint256[](tokens.length), false, "");
        assertEq(lpBefore - IERC20(pool).balanceOf(actor), bpt, "exact BPT burn");
        uint256 total;
        for (uint256 i; i < tokens.length; ++i) {
            assertEq(tokens[i].balanceOf(actor) - beforeBalances[i], paid[i], "partial exit delivery");
            total += paid[i];
        }
        assertGt(total, 0, "partial exit is funded");
        _assertScaledBooks(booksBefore, bpt, supplyBefore, false);
        expectedShares[actor] -= bpt;
        burned += bpt;
        ++exited;
    }

    function _swap(address actor, uint256 amount, uint256 action) internal {
        IERC20 input = action % 2 == 0 ? buffer : share;
        IERC20 output = action % 2 == 0 ? share : buffer;
        _fundAtLeast(actor, input, 1 ether);
        uint256 beforeInput = input.balanceOf(actor);
        uint256 beforeOutput = output.balanceOf(actor);
        vm.prank(actor);
        uint256 result = action < 2
            ? router.swapSingleTokenExactIn(pool, input, output, amount, 1, block.timestamp + 1 hours, false, "")
            : router.swapSingleTokenExactOut(pool, input, output, amount, beforeInput, block.timestamp + 1 hours, false, "");
        assertGt(result, 0, "funded trade executes");
        assertEq(beforeInput - input.balanceOf(actor), action < 2 ? amount : result, "trade input debit/refund");
        assertEq(output.balanceOf(actor) - beforeOutput, action < 2 ? result : amount, "trade output delivery");
    }

    function _swapUnpaired(address actor, uint256 amount) internal {
        _fundAtLeast(actor, unpaired, 1 ether);
        uint256 beforeIn = unpaired.balanceOf(actor);
        uint256 beforeOut = buffer.balanceOf(actor);
        vm.prank(actor);
        uint256 out = router.swapSingleTokenExactIn(pool, unpaired, buffer, amount, 1, block.timestamp + 1 hours, false, "");
        assertEq(beforeIn - unpaired.balanceOf(actor), amount, "unpaired trade input debit");
        assertEq(buffer.balanceOf(actor) - beforeOut, out, "unpaired trade delivery");
        assertGt(out, 0, "unpaired trade pays");
    }

    function _joinUnbalanced(address actor, uint256 amount) internal {
        _fundAtLeast(actor, share, 1 ether);
        uint256[] memory amounts = new uint256[](tokens.length);
        amounts[shareIndex] = amount;
        uint256 beforeShare = share.balanceOf(actor);
        uint256 beforeBpt = IERC20(pool).balanceOf(actor);
        vm.prank(actor);
        uint256 out = router.addLiquidityUnbalanced(pool, amounts, 1, false, "");
        assertGt(out, 0, "unbalanced join mints");
        assertEq(IERC20(pool).balanceOf(actor) - beforeBpt, out, "unbalanced mint accounting");
        assertEq(beforeShare - share.balanceOf(actor), amount, "unbalanced exact input");
        expectedShares[actor] += out;
        minted += out;
    }

    function _donateAndTransfer(address actor, uint256 seed, uint256 amount) internal {
        _fundAtLeast(actor, share, 1 ether);
        uint256[] memory amounts = new uint256[](tokens.length);
        amounts[shareIndex] = amount;
        uint256 supply = IERC20(pool).totalSupply();
        bytes32 virtualBefore = _virtualHash();
        uint256 shareBefore = share.balanceOf(actor);
        vm.prank(actor);
        router.donate(pool, amounts, false, "");
        assertEq(shareBefore - share.balanceOf(actor), amount, "donation exact debit");
        assertEq(IERC20(pool).totalSupply(), supply, "donation mints no BPT");
        assertEq(_virtualHash(), virtualBefore, "donation cannot fabricate virtual backing");
        uint256 index = actor == actors[0] ? 0 : actor == actors[1] ? 1 : 2;
        address recipient = actors[(index + 1 + seed % 2) % 3];
        uint256 moved = expectedShares[actor] / 7;
        vm.prank(actor);
        IERC20(pool).transfer(recipient, moved);
        expectedShares[actor] -= moved;
        expectedShares[recipient] += moved;
        assertEq(IERC20(pool).totalSupply(), supply, "transfer preserves supply");
    }

    function _callbackData() internal view returns (bytes memory) {
        return abi.encodeCall(IHooks.onBeforeSwap, (PoolSwapParams({kind: SwapKind.EXACT_IN,
            amountGivenScaled18: 1e12, balancesScaled18: new uint256[](tokens.length),
            indexIn: bufferIndex, indexOut: shareIndex, router: address(router), userData: ""}), pool));
    }

    function _falseControls() internal {
        bytes32 beforeState = _snapshot();
        bytes memory data = _callbackData();
        vm.prank(attacker);
        (bool ok, bytes memory returned) = pool.call(data);
        assertTrue(ok, "D32 unauthorized callback returns normally");
        assertEq(returned, abi.encode(false), "D32 exact false status");
        assertEq(_snapshot(), beforeState, "EOA false callback unchanged");
        for (uint256 i; i < 2; ++i) {
            returned = attackerContract.execute(pool, data);
            assertEq(returned, abi.encode(false), "D32 contract and repeat false status");
            assertEq(_snapshot(), beforeState, "contract false callback unchanged");
        }
        expectedRejections[5] += 3;
    }

    function _atomicRollback(address actor, uint256 amount) internal {
        _fundAtLeast(actor, buffer, amount * 2);
        vm.startPrank(actor);
        buffer.transfer(pool, amount);
        buffer.approve(address(integrator), amount);
        vm.stopPrank();
        bytes32 beforeState = _snapshot();
        (bool ok, bytes memory reason) = address(integrator).call(abi.encodeCall(AtomicFalseHookCaller.transferAndCheck,
            (buffer, actor, pool, amount, _callbackData())));
        assertFalse(ok, "false callback cannot complete checked atomic transfer");
        assertEq(reason, abi.encodeWithSelector(AtomicFalseHookCaller.CallbackRejected.selector), "intended integration rejection");
        assertEq(_snapshot(), beforeState, "atomic transfer and allowance roll back; prior transfer remains");
        ++expectedRejections[6];
    }

    function _snapshot() internal view returns (bytes32 state) {
        (,, uint256[] memory raw, uint256[] memory live) = vault.getPoolTokenInfo(pool);
        state = keccak256(abi.encode(raw, live, IERC20(pool).totalSupply()));
        for (uint256 i; i < bookCalls.length; ++i) {
            (bool ok, bytes memory value) = pool.staticcall(bookCalls[i]);
            assertTrue(ok, "configured public accounting view exists");
            state = keccak256(abi.encode(state, value));
        }
        for (uint256 i; i <= tokens.length; ++i) {
            IERC20 token = i == tokens.length ? IERC20(pool) : tokens[i];
            state = keccak256(abi.encode(state, token.totalSupply(), token.balanceOf(pool), token.balanceOf(address(vault)),
                token.balanceOf(address(router)), token.balanceOf(attacker), token.balanceOf(address(attackerContract)),
                token.balanceOf(address(integrator))));
            for (uint256 j; j < 3; ++j) state = keccak256(abi.encode(state, token.balanceOf(actors[j]),
                token.allowance(actors[j], address(permit2)), token.allowance(actors[j], address(integrator)),
                token.allowance(actors[j], address(router))));
        }
    }

    function _readBooks() internal view returns (int256[] memory result) {
        result = new int256[](bookCalls.length);
        for (uint256 i; i < bookCalls.length; ++i) {
            (bool ok, bytes memory value) = pool.staticcall(bookCalls[i]);
            assertTrue(ok, "public accounting view exists");
            result[i] = abi.decode(value, (int256));
        }
    }

    function _assertScaledBooks(int256[] memory beforeBooks, uint256 bpt, uint256 supply, bool adding) internal view {
        int256[] memory afterBooks = _readBooks();
        for (uint256 i; i < beforeBooks.length; ++i) {
            int256 delta = beforeBooks[i] * int256(bpt) / int256(supply);
            assertEq(afterBooks[i], adding ? beforeBooks[i] + delta : beforeBooks[i] - delta,
                "virtual backing and signed share obligations scale with exact LP ownership");
        }
    }

    function _virtualHash() internal view returns (bytes32 result) {
        for (uint256 i; i < virtualBookCount; ++i) {
            (bool ok, bytes memory value) = pool.staticcall(bookCalls[i]);
            assertTrue(ok, "public virtual book exists");
            result = keccak256(abi.encode(result, value));
        }
    }

    function assertAccounting() public view {
        (,, uint256[] memory raw,) = vault.getPoolTokenInfo(pool);
        assertGt(raw[shareIndex], 0, "funded pool share backing remains positive");
        for (uint256 i; i < tokens.length; ++i) {
            assertLt(raw[i], type(uint128).max, "native pool accounting bounded");
            if (isBuffer[tokens[i]]) assertLt(raw[i], 50_000 ether, "physical buffer does not accumulate unboundedly");
        }
        for (uint256 i; i < bookCalls.length; ++i) {
            (bool ok, bytes memory value) = pool.staticcall(bookCalls[i]);
            assertTrue(ok, "public accounting view exists");
            if (i < virtualBookCount) {
                uint256 virtualBalance = abi.decode(value, (uint256));
                assertGt(virtualBalance, 0, "virtual backing remains positive");
                assertLt(virtualBalance, type(uint128).max, "virtual backing bounded");
            } else {
                int256 delta = abi.decode(value, (int256));
                assertGt(delta, -int256(uint256(type(uint128).max)), "negative delta bounded");
                assertLt(delta, int256(uint256(type(uint128).max)), "positive delta bounded");
            }
        }
        assertEq(joined, attempted, "every randomized proportional join succeeds");
        assertEq(exited, attempted, "every randomized partial exit succeeds");
        for (uint256 i; i < 3; ++i) assertEq(IERC20(pool).balanceOf(actors[i]), expectedShares[actors[i]], "each honest LP entitlement");
        assertEq(IERC20(pool).totalSupply(), initialSupply + minted - burned, "exact aggregate BPT supply");
        for (uint256 i; i < 8; ++i) assertEq(actionAttempts[i], actionSuccesses[i], "no ignored action failure");
    }

    function assertCampaign() external view {
        assertAccounting();
        for (uint256 i; i < 8; ++i) assertGt(actionSuccesses[i], 0, "every required action executed in campaign");
        assertGt(expectedRejections[5], 2, "EOA contract and repeated callback controls reached");
        assertGt(expectedRejections[6], 0, "atomic false-status rollback reached");
    }
}
