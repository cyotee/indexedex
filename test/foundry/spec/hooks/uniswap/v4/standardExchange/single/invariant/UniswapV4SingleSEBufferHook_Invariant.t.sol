// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferHook as IBuffer
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHook.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

/// @notice The wrap-only hook is exercised through its actual PoolManager door, never substituted with SE calls.
contract Handler_NonCpSingleHook is Test {
    using BalanceDeltaLibrary for BalanceDelta;
    IBuffer public immutable hook;
    SimpleMintableERC20 public immutable pair;
    IERC20 public immutable se;
    WrapperExactOutRouter public immutable router;
    AtomicPretransferCaller public immutable caller;
    IERC20 internal immutable vault;
    PoolKey internal key;
    address[3] public actors = [address(0xCA1101), address(0xCA1102), address(0xCA1103)];
    address public constant attacker = address(0xBAD110);
    uint256 public attempted;
    uint256 public ghost_in;
    uint256 public ghost_out;
    uint256 public ghost_minted;
    uint256 public ghost_burned;
    uint256 public ghost_donated;
    mapping(address actor => uint256 shares) public expectedShares;
    uint256[4] public actionAttempts;
    uint256[4] public actionSuccesses;
    uint256[4] public expectedReverts;

    constructor(
        address hook_,
        SimpleMintableERC20 pair_,
        address se_,
        WrapperExactOutRouter router_,
        PoolKey memory key_,
        IERC20 vault_
    ) {
        hook = IBuffer(hook_);
        pair = pair_;
        se = IERC20(se_);
        router = router_;
        key = key_;
        vault = vault_;
        caller = new AtomicPretransferCaller();
    }

    function cycle(uint256 amountSeed, uint256 recipientSeed, uint256 exitSeed) external {
        uint256 step = attempted++;
        address actor = actors[(step < 24 ? step : recipientSeed) % 3];
        uint256 action = (step < 24 ? step : amountSeed) % 4;
        uint256 amount = bound(amountSeed, 1 ether, 20 ether);
        pair.mint(actor, amount);
        uint256 shares = _swap(actor, true, false, amount);
        _swap(actor, false, false, bound(exitSeed, shares / 4, shares / 2));
        ++actionAttempts[action];
        if (action == 0) {
            // Both exact-output directions with fat max input and exact refund accounting.
            uint256 wanted = bound(amountSeed, 1e12, 1e15);
            pair.mint(actor, hook.previewWrapExactOut(wanted) * 2);
            _swap(actor, true, true, wanted);
            _swap(actor, false, true, hook.previewUnwrap(wanted / 2));
        } else if (action == 1) {
            _donateAndTransfer(actor, recipientSeed);
        } else if (action == 2) {
            _attackControls();
        } else {
            _atomicRollback(actor, bound(amountSeed, 1e12, 1e15));
        }
        ++actionSuccesses[action];
    }

    function _params(bool wrap, bool exactOut, uint256 amount) internal view returns (SwapParams memory) {
        bool zeroForOne = (Currency.unwrap(key.currency0) == address(pair)) == wrap;
        return SwapParams(
            zeroForOne,
            exactOut ? int256(amount) : -int256(amount),
            zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        );
    }

    struct SwapState {
        IERC20 input;
        IERC20 output;
        uint256 quote;
        uint256 budget;
        uint256 beforeIn;
        uint256 beforeOut;
        uint256 restingInput;
        uint256 restingOutput;
    }

    function _swap(address actor, bool wrap, bool exactOut, uint256 amount) internal returns (uint256 result) {
        SwapState memory v;
        v.input = wrap ? IERC20(address(pair)) : se;
        v.output = wrap ? se : IERC20(address(pair));
        v.quote = exactOut
            ? (wrap ? hook.previewWrapExactOut(amount) : hook.previewUnwrapExactOut(amount))
            : (wrap ? hook.previewWrap(amount) : hook.previewUnwrap(amount));
        v.budget = exactOut ? v.quote * 2 : amount;
        v.beforeIn = v.input.balanceOf(actor);
        v.beforeOut = v.output.balanceOf(actor);
        v.restingInput = v.input.balanceOf(address(hook));
        v.restingOutput = v.output.balanceOf(address(hook));
        vm.prank(actor);
        v.input.approve(address(router), v.budget);
        SwapParams memory params = _params(wrap, exactOut, amount);
        vm.prank(actor);
        BalanceDelta delta =
            exactOut ? router.swapExactOut(key, params, v.budget, "") : router.swapExactIn(key, params, "");
        uint256 paid = v.beforeIn - v.input.balanceOf(actor);
        result = v.output.balanceOf(actor) - v.beforeOut;
        assertEq(paid, exactOut ? v.quote : amount, "input consumption and max refund");
        assertEq(result, exactOut ? amount : v.quote, "exact receiver delivery");
        assertEq(paid, uint256(-int256(params.zeroForOne ? delta.amount0() : delta.amount1())), "pool input accounting");
        assertEq(
            result, uint256(int256(params.zeroForOne ? delta.amount1() : delta.amount0())), "pool output accounting"
        );
        assertEq(v.input.balanceOf(address(hook)), v.restingInput, "resting input untouched");
        assertEq(v.output.balanceOf(address(hook)), v.restingOutput, "resting output untouched");
        assertGt(result, 0, "funded route pays");
        if (wrap) {
            expectedShares[actor] += result;
            ghost_minted += result;
            ++ghost_in;
        } else {
            expectedShares[actor] -= paid;
            ghost_burned += paid;
            ++ghost_out;
        }
    }

    function _donateAndTransfer(address actor, uint256 recipientSeed) internal {
        uint256 shares = se.balanceOf(actor) / 20;
        uint256 supplyBefore = se.totalSupply();
        uint256 custodyBefore = se.balanceOf(address(hook));
        vm.prank(actor);
        se.transfer(address(hook), shares);
        expectedShares[actor] -= shares;
        ghost_donated += shares;
        assertEq(se.balanceOf(address(hook)) - custodyBefore, shares, "donation custody");
        uint256 actorIndex = actor == actors[0] ? 0 : actor == actors[1] ? 1 : 2;
        address recipient = actors[(actorIndex + 1 + recipientSeed % 2) % 3];
        uint256 beforeActor = se.balanceOf(actor);
        uint256 beforeRecipient = se.balanceOf(recipient);
        vm.prank(actor);
        se.transfer(recipient, shares);
        expectedShares[actor] -= shares;
        expectedShares[recipient] += shares;
        assertEq(beforeActor - se.balanceOf(actor), shares, "share sender debit");
        assertEq(se.balanceOf(recipient) - beforeRecipient, shares, "share recipient credit");
        assertEq(se.totalSupply(), supplyBefore, "donation and transfer cannot mint");
    }

    function _attackControls() internal {
        bytes memory data = abi.encodeCall(IHooks.beforeSwap, (attacker, key, _params(true, false, 1e12), bytes("")));
        bytes memory expected = abi.encodeWithSelector(bytes4(keccak256("NotPoolManager()")));
        _reject(attacker, data, expected, 2);
        _reject(address(caller), data, expected, 2);
        // Repeat the contract attempt while the hook has donated inventory from earlier cycles.
        _reject(address(caller), data, expected, 2);
    }

    function _reject(address sender, bytes memory data, bytes memory expected, uint256 action) internal {
        bytes32 beforeState = _snapshot();
        bool ok;
        bytes memory reason;
        if (sender == address(caller)) {
            (ok, reason) = address(caller).call(abi.encodeCall(AtomicPretransferCaller.execute, (address(hook), data)));
        } else {
            vm.prank(sender);
            (ok, reason) = address(hook).call(data);
        }
        assertFalse(ok, "unauthorized call rejected");
        assertEq(reason, expected, "complete intended error");
        assertEq(_snapshot(), beforeState, "rejection preserves all balances supply allowances");
        ++expectedReverts[action];
    }

    function _atomicRollback(address actor, uint256 amount) internal {
        pair.mint(actor, amount * 2);
        vm.startPrank(actor);
        pair.transfer(address(hook), amount);
        pair.approve(address(caller), amount);
        vm.stopPrank();
        bytes memory unsupported = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (IERC20(address(pair)), amount, se, 0, actor, true, block.timestamp + 1 hours)
        );
        bytes32 beforeState = _snapshot();
        (bool ok, bytes memory reason) = address(caller)
            .call(
                abi.encodeCall(
                    AtomicPretransferCaller.consumePretransfer,
                    (IERC20(address(pair)), actor, address(hook), amount, unsupported)
                )
            );
        assertFalse(ok, "wrap-only hook has no direct prepaid SE route");
        assertEq(
            reason,
            abi.encodeWithSelector(Proxy.NoTargetFor.selector, IStandardExchangeIn.exchangeIn.selector),
            "unsupported selector exact error"
        );
        assertEq(_snapshot(), beforeState, "atomic transfer rolls back, separate transfer remains");
        ++expectedReverts[3];
        _reject(
            attacker,
            unsupported,
            abi.encodeWithSelector(Proxy.NoTargetFor.selector, IStandardExchangeIn.exchangeIn.selector),
            3
        );
    }

    function _snapshot() internal view returns (bytes32 state) {
        IERC20[3] memory observed = [IERC20(address(pair)), se, vault];
        address[11] memory holders = [
            actors[0],
            actors[1],
            actors[2],
            attacker,
            address(caller),
            address(hook),
            address(se),
            address(vault),
            address(router),
            address(router.manager()),
            address(this)
        ];
        for (uint256 i; i < 3; ++i) {
            state = keccak256(abi.encode(state, observed[i].totalSupply()));
            for (uint256 j; j < holders.length; ++j) {
                state = keccak256(
                    abi.encode(
                        state,
                        observed[i].balanceOf(holders[j]),
                        observed[i].allowance(holders[j], address(caller)),
                        observed[i].allowance(holders[j], address(router)),
                        observed[i].allowance(holders[j], address(hook)),
                        observed[i].allowance(holders[j], address(se))
                    )
                );
            }
        }
    }

    function assertAccounting() public view {
        assertGe(ghost_in, attempted, "every lifecycle wrapped");
        assertGe(ghost_out, attempted, "every lifecycle unwrapped nonzero");
        uint256 holderShares;
        for (uint256 i; i < 3; ++i) {
            assertEq(se.balanceOf(actors[i]), expectedShares[actors[i]], "each honest holder entitlement");
            holderShares += se.balanceOf(actors[i]);
        }
        assertEq(holderShares, ghost_minted - ghost_burned - ghost_donated, "exact honest share conservation");
        assertEq(se.balanceOf(address(hook)), ghost_donated, "donated shares never credited to new trades");
        for (uint256 i; i < 4; ++i) {
            assertEq(actionAttempts[i], actionSuccesses[i], "no ignored action failures");
        }
    }

    function assertCampaign() external view {
        assertAccounting();
        for (uint256 i; i < 4; ++i) {
            assertGt(actionSuccesses[i], 0, "campaign exercised every action");
        }
        assertGt(expectedReverts[2], 2, "EOA contract and repeated attempt controls");
        assertGt(expectedReverts[3], 1, "atomic and staged-transfer rollback controls");
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract UniswapV4SingleSEBufferHook_Invariant is TestBase {
    Handler_NonCpSingleHook internal handler;

    function setUp() public override {
        super.setUp();
        _initPool();
        handler = new Handler_NonCpSingleHook(hook, pairToken, se, swapRouter, poolKey, IERC20(address(protocolVault)));
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_liquidityAccounting() public view {
        handler.assertAccounting();
    }

    function afterInvariant() public view {
        handler.assertCampaign();
    }

    function test_deterministicLifecycle() public {
        for (uint256 i; i < 24; ++i) {
            handler.cycle(10 ether, i, i);
        }
        assertEq(handler.attempted(), 24);
        handler.assertCampaign();
    }
}
