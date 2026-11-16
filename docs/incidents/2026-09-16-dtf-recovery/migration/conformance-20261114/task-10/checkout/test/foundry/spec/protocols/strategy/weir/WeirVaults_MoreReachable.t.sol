// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {TestBase_WeirVaults} from "contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol";
import {WeirVaults} from "contracts/protocols/strategy/weir/WeirVaults.sol";
import {WeirBase} from "contracts/protocols/strategy/weir/base/WeirBase.sol";
import {WeirHostileToken} from "contracts/protocols/strategy/weir/test/peripherals/WeirHostileToken.sol";
import {WeirObserveHook} from "contracts/protocols/strategy/weir/test/peripherals/WeirObserveHook.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";

contract RefundReader {
    WeirVaults public weir;
    PoolId public id;
    address public recipient;
    uint256 public seenShares;

    function run(WeirVaults target, PoolKey calldata key, PoolId poolId, address to) external payable {
        weir = target;
        id = poolId;
        recipient = to;
        weir.deposit{value: msg.value}(
            WeirVaults.DepositParams({
                key: key,
                amount0: msg.value,
                amount1: msg.value,
                zap: false,
                minShares: 0,
                recipient: to,
                deadline: block.timestamp + 1 hours,
                hookData: ""
            })
        );
    }

    receive() external payable {
        seenShares = weir.sharesOf(id, recipient);
    }
}

contract WeirVaults_MoreReachableTest is TestBase_WeirVaults {
    using PoolIdLibrary for PoolKey;

    function test_AC51_syncDuringCallback() public {
        (address predicted, bytes32 salt) =
            mineHook(observeFlags(), type(WeirObserveHook).creationCode, abi.encode(poolManager));
        WeirObserveHook hook = new WeirObserveHook{salt: salt}(poolManager);
        assertEq(address(hook), predicted);
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(tokenA)),
            fee: 0,
            tickSpacing: 1,
            hooks: IHooks(address(hook))
        });
        PoolId id = initHookless(key, f0Sqrt());
        hook.setLeaveSyncOpen(Currency.wrap(address(tokenA)), true);
        address payer = makeAddr("payer");
        fund(payer, tokenA, K + 2, address(weir));
        vm.deal(payer, K + 2);
        vm.prank(payer);
        vm.expectRevert(bytes4(0xb0ec849e));
        weir.deposit{value: K + 2}(
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
        assertFalse(weir.vault(id).exists);
        assertEq(payer.balance, K + 2);
    }

    function test_AC56_callbackTransferShares() public {
        WeirHostileToken hostile = new WeirHostileToken();
        PoolKey memory key = ercKey(address(tokenA), address(hostile), 0, 1, IHooks(address(0)));
        PoolId id = initHookless(key, f0Sqrt());
        address payer = makeAddr("payer");
        tokenA.mint(payer, 2 * (K + 2));
        hostile.mint(payer, 2 * (K + 2));
        vm.prank(payer);
        tokenA.approve(address(weir), type(uint256).max);
        vm.prank(payer);
        hostile.approve(address(weir), type(uint256).max);
        vm.prank(payer);
        weir.deposit(
            WeirVaults.DepositParams({
                key: key,
                amount0: K + 2,
                amount1: K + 2,
                zap: false,
                minShares: 0,
                recipient: address(hostile),
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(weir.sharesOf(id, address(hostile)), F0_SHARES);
        address sink = makeAddr("sink");
        hostile.setCallback(address(weir), abi.encodeCall(weir.transferShares, (id, sink, 1)));
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
        assertEq(shares, K);
        assertEq(weir.sharesOf(id, sink), 3);
        assertEq(weir.sharesOf(id, address(hostile)), F0_SHARES - 3);
        assertEq(weir.sharesOf(id, payer), K);
    }

    function test_AC58_outsiderMalformed() public {
        address user = makeAddr("user");
        vm.prank(user);
        vm.expectRevert(WeirBase.NotPoolManager.selector);
        weir.unlockCallback(hex"01");
        vm.prank(user);
        vm.expectRevert(WeirBase.NotPoolManager.selector);
        weir.unlockCallback(abi.encode(uint8(1), bytes32(uint256(1)), bytes("not-a-vault")));
    }

    function test_AC61_creditPrecedesRefund() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(tokenA)),
            fee: 0,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });
        PoolId id = initHookless(key, f0Sqrt());
        RefundReader payer = new RefundReader();
        address recipient = makeAddr("recipient");
        fund(address(payer), tokenA, K + 2, address(weir));
        vm.deal(address(this), K + 2);
        payer.run{value: K + 2}(weir, key, id, recipient);
        assertEq(payer.seenShares(), F0_SHARES);
        assertEq(weir.sharesOf(id, recipient), F0_SHARES);
        assertEq(address(payer).balance, 2);
    }
}
