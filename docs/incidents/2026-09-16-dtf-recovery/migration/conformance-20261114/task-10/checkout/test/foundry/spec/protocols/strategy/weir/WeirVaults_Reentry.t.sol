// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {TestBase_WeirVaults} from "contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol";
import {WeirVaults} from "contracts/protocols/strategy/weir/WeirVaults.sol";
import {WeirBase} from "contracts/protocols/strategy/weir/base/WeirBase.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {CustomRevert} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/CustomRevert.sol";
import {ReentrancyGuard} from "@crane/contracts/external/openzeppelin-contracts-v5/utils/ReentrancyGuard.sol";
import {WeirObserveHook} from "contracts/protocols/strategy/weir/test/peripherals/WeirObserveHook.sol";
import {WeirHostileToken} from "contracts/protocols/strategy/weir/test/peripherals/WeirHostileToken.sol";
import {Pausable} from "@crane/contracts/external/openzeppelin-contracts-v5/utils/Pausable.sol";

contract TakeReenter {
    WeirVaults public weir;

    function arm(WeirVaults target) external {
        weir = target;
    }

    receive() external payable {
        weir.deposit(
            WeirVaults.DepositParams({
                key: PoolKey({
                    currency0: Currency.wrap(address(0)),
                    currency1: Currency.wrap(address(0)),
                    fee: 0,
                    tickSpacing: 1,
                    hooks: IHooks(address(0))
                }),
                amount0: 0,
                amount1: 0,
                zap: false,
                minShares: 0,
                recipient: address(this),
                deadline: block.timestamp + 1,
                hookData: ""
            })
        );
    }
}

contract RefundReenter {
    WeirVaults public weir;
    PoolKey public key;

    function arm(WeirVaults target, PoolKey calldata poolKey) external {
        weir = target;
        key = poolKey;
    }

    function run() external payable {
        weir.deposit{value: msg.value}(
            WeirVaults.DepositParams({
                key: key,
                amount0: msg.value,
                amount1: msg.value,
                zap: false,
                minShares: 0,
                recipient: address(this),
                deadline: block.timestamp + 1 hours,
                hookData: ""
            })
        );
    }

    receive() external payable {
        weir.deposit(
            WeirVaults.DepositParams({
                key: key,
                amount0: 0,
                amount1: 0,
                zap: false,
                minShares: 0,
                recipient: address(this),
                deadline: block.timestamp + 1 hours,
                hookData: ""
            })
        );
    }
}

contract PauseThenDeposit {
    function accept(WeirVaults target) external {
        target.acceptOwnership();
    }

    function go(WeirVaults target, WeirVaults.DepositParams calldata nested) external {
        target.pause();
        target.deposit(nested);
    }

    function setFee(WeirVaults target, uint16 bps) external {
        target.setPerfFee(bps);
    }

    function handOff(WeirVaults target, address next) external {
        target.transferOwnership(next);
    }
}

contract WeirVaults_ReentryTest is TestBase_WeirVaults {
    function test_AC54_reenterOnTake() public {
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
        TakeReenter recipient = new TakeReenter();
        recipient.arm(weir);
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
        assertTrue(_hasSelector(ret, ReentrancyGuard.ReentrancyGuardReentrantCall.selector));
        assertEq(weir.sharesOf(id, payer), F0_SHARES);
        assertEq(weir.vault(id).liquidity, K);
    }

    function test_AC54_reenterOnHook() public {
        (address predicted, bytes32 salt) =
            mineHook(observeFlags(), type(WeirObserveHook).creationCode, abi.encode(poolManager));
        WeirObserveHook hook = new WeirObserveHook{salt: salt}(poolManager);
        assertEq(address(hook), predicted);
        PoolKey memory key = ercKey(address(tokenA), address(tokenB), 0, 1, IHooks(address(hook)));
        initHookless(key, f0Sqrt());
        hook.setReenter(
            address(weir),
            abi.encodeCall(
                weir.deposit,
                (WeirVaults.DepositParams({
                    key: key,
                    amount0: 1,
                    amount1: 1,
                    zap: false,
                    minShares: 0,
                    recipient: address(this),
                    deadline: deadline(),
                    hookData: ""
                }))
            )
        );
        address payer = makeAddr("payer");
        fund(payer, tokenA, K + 2, address(weir));
        fund(payer, tokenB, K + 2, address(weir));
        vm.prank(payer);
        (bool ok, bytes memory ret) = address(weir).call(
            abi.encodeCall(
                weir.deposit,
                (WeirVaults.DepositParams({
                    key: key,
                    amount0: K + 2,
                    amount1: K + 2,
                    zap: false,
                    minShares: 0,
                    recipient: payer,
                    deadline: deadline(),
                    hookData: ""
                }))
            )
        );
        assertFalse(ok);
        assertTrue(_hasSelector(ret, ReentrancyGuard.ReentrancyGuardReentrantCall.selector));
        assertEq(weir.vaultCount(), 0);
    }

    function test_AC54_reenterOnRefund() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(tokenA)),
            fee: 0,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });
        PoolId id = initHookless(key, f0Sqrt());
        RefundReenter payer = new RefundReenter();
        payer.arm(weir, key);
        fund(address(payer), tokenA, K + 2, address(weir));
        vm.deal(address(this), K + 2);
        (bool ok, bytes memory ret) = address(payer).call{value: K + 2}(abi.encodeCall(payer.run, ()));
        assertFalse(ok);
        assertEq(bytes4(ret), WeirBase.NativeTransferFailed.selector);
        assertFalse(weir.vault(id).exists);
    }

    function test_AC54_pauseInsideCallback() public {
        PauseThenDeposit actor = new PauseThenDeposit();
        vm.prank(owner);
        weir.transferOwnership(address(actor));
        actor.accept(weir);
        assertEq(weir.owner(), address(actor));
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
        hostile.setCallback(
            address(actor),
            abi.encodeCall(
                actor.go,
                (weir, WeirVaults.DepositParams({
                    key: key,
                    amount0: 0,
                    amount1: 0,
                    zap: false,
                    minShares: 0,
                    recipient: payer,
                    deadline: deadline(),
                    hookData: ""
                }))
            )
        );
        hostile.setMode(WeirHostileToken.Mode.CALLBACK);
        vm.prank(payer);
        vm.expectRevert(Pausable.EnforcedPause.selector);
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
        assertFalse(weir.paused());
        assertEq(weir.owner(), address(actor));
    }

    function test_AC56_ownerCallbackSetter() public {
        PauseThenDeposit actor = new PauseThenDeposit();
        vm.prank(owner);
        weir.transferOwnership(address(actor));
        actor.accept(weir);
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
        hostile.setCallback(address(actor), abi.encodeCall(actor.setFee, (weir, 1000)));
        hostile.setMode(WeirHostileToken.Mode.CALLBACK);
        vm.prank(payer);
        uint256 shares = weir.deposit(
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
        assertEq(shares, F0_SHARES);
        assertEq(weir.perfFeeBps(), 1000);
        assertEq(weir.owner(), address(actor));
        address next = makeAddr("next");
        hostile.setCallback(address(actor), abi.encodeCall(actor.handOff, (weir, next)));
        tokenA.mint(payer, K + 2);
        hostile.mint(payer, K + 2);
        vm.prank(payer);
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
        assertEq(weir.pendingOwner(), next);
        assertEq(weir.owner(), address(actor));
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
