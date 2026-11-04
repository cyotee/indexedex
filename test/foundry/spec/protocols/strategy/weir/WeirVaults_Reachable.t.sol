// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {TestBase_WeirVaults} from "contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol";
import {WeirVaults} from "contracts/protocols/strategy/weir/WeirVaults.sol";
import {WeirMathOracle} from "contracts/protocols/strategy/weir/test/oracles/WeirMathOracle.sol";
import {WeirHostileToken} from "contracts/protocols/strategy/weir/test/peripherals/WeirHostileToken.sol";
import {WeirObserveHook} from "contracts/protocols/strategy/weir/test/peripherals/WeirObserveHook.sol";
import {WeirRejectReceiver} from "contracts/protocols/strategy/weir/test/peripherals/WeirRejectReceiver.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IHooks as HookFace} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {CustomRevert} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/CustomRevert.sol";
import {SafeERC20} from "@crane/contracts/external/openzeppelin-contracts-v5/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@crane/contracts/external/openzeppelin-contracts-v5/utils/ReentrancyGuard.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

contract TreasurySwitcher {
    WeirVaults public weir;
    address public next;

    function arm(WeirVaults target, address successor) external {
        weir = target;
        next = successor;
    }

    receive() external payable {
        weir.setTreasury(next);
    }
}

contract WeirVaults_ReachableTest is TestBase_WeirVaults {
    using PoolIdLibrary for PoolKey;
    function _pair(address payer, PoolKey memory key, uint256 amount, uint256 minShares) internal returns (uint256) {
        fund(payer, tokenA, amount, address(weir));
        fund(payer, tokenB, amount, address(weir));
        vm.prank(payer);
        return weir.deposit(
            WeirVaults.DepositParams({
                key: key,
                amount0: amount,
                amount1: amount,
                zap: false,
                minShares: minShares,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
    }

    function _donate(PoolKey memory key, uint256 amount0, uint256 amount1) internal {
        address donor = makeAddr("donor");
        if (amount0 > 0) fund(donor, SimpleMintableERC20(Currency.unwrap(key.currency0)), amount0, address(poolRouter));
        if (amount1 > 0) fund(donor, SimpleMintableERC20(Currency.unwrap(key.currency1)), amount1, address(poolRouter));
        vm.prank(donor);
        poolRouter.donate(key, amount0, amount1);
    }

    function _amounts(WeirVaults.Vault memory vault, uint128 liquidity) internal view returns (uint256, uint256) {
        return WeirMathOracle.amountsForLiquidity(
            f0Sqrt(),
            TickMath.getSqrtPriceAtTick(vault.tickLower),
            TickMath.getSqrtPriceAtTick(vault.tickUpper),
            liquidity
        );
    }

    function test_AC11_oneSidedFreshAndExisting() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        fund(payer, tokenA, K + 2, address(weir));
        fund(payer, tokenB, K + 2, address(weir));
        vm.prank(payer);
        vm.expectRevert(WeirVaults.ZeroShares.selector);
        weir.deposit(
            WeirVaults.DepositParams({
                key: key,
                amount0: K + 2,
                amount1: 0,
                zap: false,
                minShares: 0,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(weir.vaultCount(), 0);
        _pair(payer, key, K + 2, F0_SHARES);
        vm.prank(payer);
        vm.expectRevert(WeirVaults.ZeroShares.selector);
        weir.deposit(
            WeirVaults.DepositParams({
                key: key,
                amount0: 0,
                amount1: K + 2,
                zap: false,
                minShares: 0,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(weir.sharesOf(id, payer), F0_SHARES);
        assertEq(weir.vault(id).liquidity, K);
    }

    function test_AC18_selfWeirAndUnknownZero() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _pair(payer, key, K + 2, F0_SHARES);
        vm.prank(payer);
        weir.transferShares(id, payer, 10);
        assertEq(weir.sharesOf(id, payer), F0_SHARES);
        vm.prank(payer);
        weir.transferShares(id, address(weir), 10);
        assertEq(weir.sharesOf(id, payer), F0_SHARES - 10);
        assertEq(weir.sharesOf(id, address(weir)), 10);
        PoolId unknown = ercKey(address(tokenB), address(tokenC), 0, 1, IHooks(address(0))).toId();
        vm.prank(payer);
        weir.transferShares(unknown, payer, 0);
        assertEq(weir.sharesOf(unknown, payer), 0);
        vm.prank(payer);
        vm.expectRevert(WeirVaults.ZeroAddress.selector);
        weir.transferShares(id, address(0), 1);
        assertEq(weir.sharesOf(id, payer), F0_SHARES - 10);
    }

    function test_AC22_subsetAfterFees() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _pair(payer, key, K + 2, F0_SHARES);
        _donate(key, 20, 0);
        weir.compound(key, "");
        uint256 shares = F0_SHARES / 2;
        uint128 removed = uint128((K * shares) / K);
        uint256 idleClaim = (19 * shares) / K;
        (uint256 base0, uint256 base1) = _amounts(weir.vault(id), removed);
        vm.prank(payer);
        (uint256 out0, uint256 out1) = weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: shares,
                zapTo: 0,
                min0: 0,
                min1: 0,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(out0, base0 + idleClaim);
        assertEq(out1, base1);
        assertEq(weir.vault(id).idle0, 19 - idleClaim);
        assertEq(weir.vault(id).liquidity, K - removed);
        assertEq(weir.vault(id).totalShares, K - shares);
        assertEq(weir.sharesOf(id, payer), F0_SHARES - shares);
    }

    function test_AC26_min1PlusOne() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _pair(payer, key, K + 2, F0_SHARES);
        vm.prank(payer);
        vm.expectRevert(WeirVaults.Slippage.selector);
        weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: F0_SHARES,
                zapTo: 0,
                min0: F0_OUT,
                min1: F0_OUT + 1,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(weir.sharesOf(id, payer), F0_SHARES);
        assertEq(weir.vault(id).liquidity, K);
    }

    function test_AC32_selfTreasury() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _pair(payer, key, K + 2, F0_SHARES);
        vm.prank(owner);
        weir.setTreasury(address(weir));
        _donate(key, 20, 0);
        weir.compound(key, "");
        assertEq(weir.vault(id).idle0, 19);
        assertEq(weir.vault(id).liquidity, K);
        assertEq(weir.vault(id).totalShares, K);
        assertEq(SimpleMintableERC20(Currency.unwrap(key.currency0)).balanceOf(address(weir)), 20);
        vm.warp(block.timestamp + 1);
        weir.compound(key, "");
        assertEq(weir.vault(id).idle0, 19);
        assertEq(SimpleMintableERC20(Currency.unwrap(key.currency0)).balanceOf(address(weir)), 20);
    }

    function test_AC34_selfRecipientWithdraw() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _pair(payer, key, K + 2, F0_SHARES);
        vm.prank(payer);
        (uint256 out0, uint256 out1) = weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: F0_SHARES,
                zapTo: 0,
                min0: F0_OUT,
                min1: F0_OUT,
                recipient: address(weir),
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(out0, F0_OUT);
        assertEq(out1, F0_OUT);
        assertEq(weir.vault(id).idle0, 0);
        assertEq(weir.vault(id).idle1, 0);
        assertEq(weir.vault(id).liquidity, 1000);
        assertEq(weir.vault(id).totalShares, 1000);
        assertEq(weir.sharesOf(id, payer), 0);
        assertEq(tokenA.balanceOf(address(weir)), F0_OUT);
        assertEq(tokenB.balanceOf(address(weir)), F0_OUT);
    }

    function test_AC35_sharedCurrencyIsolation() public {
        (PoolKey memory first, PoolId firstId) = initF0();
        PoolKey memory second = ercKey(address(tokenA), address(tokenC), 0, 1, IHooks(address(0)));
        PoolId secondId = initHookless(second, f0Sqrt());
        address payer = makeAddr("payer");
        _pair(payer, first, K + 2, F0_SHARES);
        fund(payer, tokenA, K + 2, address(weir));
        fund(payer, tokenC, K + 2, address(weir));
        vm.prank(payer);
        weir.deposit(
            WeirVaults.DepositParams({
                key: second,
                amount0: K + 2,
                amount1: K + 2,
                zap: false,
                minShares: F0_SHARES,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        uint256 side0 = Currency.unwrap(first.currency0) == address(tokenA) ? 20 : 0;
        uint256 side1 = side0 == 0 ? 20 : 0;
        _donate(first, side0, side1);
        weir.compound(first, "");
        assertEq(side0 == 20 ? weir.vault(firstId).idle0 : weir.vault(firstId).idle1, 19);
        assertEq(weir.vault(secondId).idle0, 0);
        assertEq(weir.vault(secondId).idle1, 0);
        assertEq(weir.vault(secondId).liquidity, K);
        assertEq(weir.sharesOf(secondId, payer), F0_SHARES);
        assertEq(tokenA.balanceOf(address(weir)), 19);
    }

    function test_AC57_treasuryChangesBetweenTakes() public {
        TreasurySwitcher switcher = new TreasurySwitcher();
        address next = makeAddr("nextTreasury");
        WeirVaults local = new WeirVaults(poolManager, address(switcher), address(switcher));
        switcher.arm(local, next);
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(tokenA)),
            fee: 0,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });
        PoolId id = initHookless(key, f0Sqrt());
        address payer = makeAddr("payer");
        fund(payer, tokenA, K + 2, address(local));
        vm.deal(payer, K + 2);
        vm.prank(payer);
        local.deposit{value: K + 2}(
            WeirVaults.DepositParams({
                key: key,
                amount0: K + 2,
                amount1: K + 2,
                zap: false,
                minShares: F0_SHARES,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        address donor = makeAddr("donor");
        fund(donor, tokenA, 20, address(poolRouter));
        vm.deal(donor, 20);
        vm.prank(donor);
        poolRouter.donate{value: 20}(key, 20, 20);
        uint256 before = address(switcher).balance;
        local.compound(key, "");
        assertEq(local.treasury(), next);
        assertEq(address(switcher).balance, before + 1);
        assertEq(tokenA.balanceOf(next), 1);
        assertEq(local.vault(id).totalShares, K);
    }

    function test_AC40_previewEqualsExecution() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _pair(payer, key, K + 2, F0_SHARES);
        (uint256 q0, uint256 q1) = weir.previewRedeem(id, F0_SHARES);
        vm.prank(payer);
        (uint256 out0, uint256 out1) = weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: F0_SHARES,
                zapTo: 0,
                min0: 0,
                min1: 0,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(q0, out0);
        assertEq(q1, out1);
        assertEq(out0, F0_OUT);
        assertEq(out1, F0_OUT);
    }

    function test_AC50_rejectingTake() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(tokenA)),
            fee: 0,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });
        PoolId id = initHookless(key, f0Sqrt());
        address payer = makeAddr("payer");
        fund(payer, tokenA, K + 2, address(weir));
        vm.deal(payer, K + 2);
        vm.prank(payer);
        weir.deposit{value: K + 2}(
            WeirVaults.DepositParams({
                key: key,
                amount0: K + 2,
                amount1: K + 2,
                zap: false,
                minShares: F0_SHARES,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        WeirRejectReceiver recipient = new WeirRejectReceiver();
        vm.prank(payer);
        (bool ok, bytes memory ret) = address(weir).call(
            abi.encodeCall(
                weir.withdraw,
                (WeirVaults.WithdrawParams({
                    key: key,
                    shares: F0_SHARES,
                    zapTo: 0,
                    min0: 0,
                    min1: 0,
                    recipient: address(recipient),
                    deadline: deadline(),
                    hookData: ""
                }))
            )
        );
        assertFalse(ok);
        assertEq(bytes4(ret), CustomRevert.WrappedError.selector);
        assertTrue(_hasSelector(ret, WeirRejectReceiver.RejectedNative.selector));
        assertEq(weir.sharesOf(id, payer), F0_SHARES);
        assertEq(weir.vault(id).liquidity, K);
    }

    function test_AC54_reenterOnPull() public {
        WeirHostileToken hostile = new WeirHostileToken();
        PoolKey memory key = ercKey(address(tokenA), address(hostile), 0, 1, IHooks(address(0)));
        initHookless(key, f0Sqrt());
        address payer = makeAddr("payer");
        tokenA.mint(payer, K + 2);
        hostile.mint(payer, K + 2);
        vm.prank(payer);
        tokenA.approve(address(weir), type(uint256).max);
        vm.prank(payer);
        hostile.approve(address(weir), type(uint256).max);
        WeirVaults.DepositParams memory nested = WeirVaults.DepositParams({
            key: key,
            amount0: 1,
            amount1: 1,
            zap: false,
            minShares: 0,
            recipient: payer,
            deadline: deadline(),
            hookData: ""
        });
        hostile.setCallback(address(weir), abi.encodeCall(weir.deposit, (nested)));
        hostile.setMode(WeirHostileToken.Mode.CALLBACK);
        vm.prank(payer);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        weir.deposit(
            WeirVaults.DepositParams({
                key: key,
                amount0: K + 2,
                amount1: K + 2,
                zap: false,
                minShares: 0,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(weir.vaultCount(), 0);
    }

    function test_AC55_falseExplicitAndEmpty() public {
        (WeirHostileToken hostile, PoolKey memory key, PoolId id) = _hostilePool();
        address payer = makeAddr("payer");
        _fundHostile(payer, hostile);
        hostile.setMode(WeirHostileToken.Mode.FALSE_RETURN);
        vm.prank(payer);
        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(hostile)));
        _hostileDeposit(payer, key);
        assertEq(weir.vaultCount(), 0);
        hostile.setMode(WeirHostileToken.Mode.EXPLICIT_REVERT);
        vm.prank(payer);
        vm.expectRevert(WeirHostileToken.HostileExplicit.selector);
        _hostileDeposit(payer, key);
        hostile.setMode(WeirHostileToken.Mode.EMPTY_RETURN);
        vm.prank(payer);
        uint256 shares = _hostileDeposit(payer, key);
        assertEq(shares, F0_SHARES);
        assertEq(weir.sharesOf(id, payer), F0_SHARES);
    }

    function test_AC55_shortAndZeroDoNotCheckInbound() public {
        (WeirHostileToken hostile, PoolKey memory key,) = _hostilePool();
        address payer = makeAddr("payer");
        _fundHostile(payer, hostile);
        hostile.setMode(WeirHostileToken.Mode.SHORT);
        vm.prank(payer);
        vm.expectRevert(bytes4(0x5212cba1));
        _hostileDeposit(payer, key);
        assertEq(weir.vaultCount(), 0);
        hostile.mint(address(weir), 1);
        vm.prank(payer);
        vm.expectRevert(bytes4(0x5212cba1));
        _hostileDeposit(payer, key);
        hostile.setMode(WeirHostileToken.Mode.ZERO);
        vm.prank(payer);
        vm.expectRevert(bytes4(0x5212cba1));
        _hostileDeposit(payer, key);
        assertEq(hostile.balanceOf(address(weir)), 1);
    }

    function test_AC59_hookOrder() public {
        (address predicted, bytes32 salt) =
            mineHook(observeFlags(), type(WeirObserveHook).creationCode, abi.encode(poolManager));
        WeirObserveHook hook = new WeirObserveHook{salt: salt}(poolManager);
        assertEq(address(hook), predicted);
        PoolKey memory key = ercKey(address(tokenA), address(tokenB), 0, 1, IHooks(address(hook)));
        initHookless(key, f0Sqrt());
        assertEq(hook.callCount(), 0);
        weir.createVault(key);
        assertEq(hook.callCount(), 0);
        address payer = makeAddr("payer");
        _pair(payer, key, K + 2, F0_SHARES);
        assertEq(hook.callCount(), 2);
        WeirObserveHook.Call memory first = hook.callAt(0);
        assertEq(first.selector, HookFace.beforeAddLiquidity.selector);
        assertEq(first.liquidityDelta, int256(uint256(K)));
        _donate(key, 20, 0);
        weir.compound(key, hex"01");
        assertEq(hook.callCount(), 4);
        WeirObserveHook.Call memory poke = hook.callAt(2);
        assertEq(poke.selector, HookFace.beforeRemoveLiquidity.selector);
        assertEq(poke.liquidityDelta, 0);
        assertEq(poke.hookData, hex"01");
        _donate(key, 0, 20);
        weir.compound(key, hex"02");
        poke = hook.callAt(4);
        WeirObserveHook.Call memory add = hook.callAt(6);
        assertEq(poke.selector, HookFace.beforeRemoveLiquidity.selector);
        assertEq(poke.liquidityDelta, 0);
        assertEq(add.selector, HookFace.beforeAddLiquidity.selector);
        assertGt(add.liquidityDelta, 0);
        assertEq(add.hookData, hex"02");
    }

    function _hostilePool() internal returns (WeirHostileToken hostile, PoolKey memory key, PoolId id) {
        hostile = new WeirHostileToken();
        key = ercKey(address(tokenA), address(hostile), 0, 1, IHooks(address(0)));
        id = initHookless(key, f0Sqrt());
    }

    function _fundHostile(address payer, WeirHostileToken hostile) internal {
        tokenA.mint(payer, K + 2);
        hostile.mint(payer, K + 2);
        vm.prank(payer);
        tokenA.approve(address(weir), type(uint256).max);
        vm.prank(payer);
        hostile.approve(address(weir), type(uint256).max);
    }

    function _hostileDeposit(address payer, PoolKey memory key) internal returns (uint256) {
        return weir.deposit(
            WeirVaults.DepositParams({
                key: key,
                amount0: K + 2,
                amount1: K + 2,
                zap: false,
                minShares: 0,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
    }

    function _hasSelector(bytes memory data, bytes4 selector) internal pure returns (bool) {
        for (uint256 i; i + 4 <= data.length; i++) {
            bytes4 word;
            assembly {
                word := mload(add(add(data, 0x20), i))
            }
            if (word == selector) return true;
        }
        return false;
    }
}
