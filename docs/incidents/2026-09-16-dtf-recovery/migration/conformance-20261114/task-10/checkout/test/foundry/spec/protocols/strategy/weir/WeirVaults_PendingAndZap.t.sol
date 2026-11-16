// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {TestBase_WeirVaults} from "contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol";
import {WeirVaults} from "contracts/protocols/strategy/weir/WeirVaults.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

contract WithdrawReader {
    WeirVaults public weir;
    PoolId public id;
    address public user;
    uint256 public seenShares;

    function arm(WeirVaults target, PoolId poolId, address holder) external {
        weir = target;
        id = poolId;
        user = holder;
    }

    receive() external payable {
        seenShares = weir.sharesOf(id, user);
    }
}

contract WeirVaults_PendingAndZapTest is TestBase_WeirVaults {
    using StateLibrary for IPoolManager;
    function test_AC41_pendingInside() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        fund(payer, tokenA, K + 2, address(weir));
        fund(payer, tokenB, K + 2, address(weir));
        vm.prank(payer);
        weir.deposit(
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
        fund(donor, SimpleMintableERC20(Currency.unwrap(key.currency0)), 20, address(poolRouter));
        vm.prank(donor);
        poolRouter.donate(key, 20, 0);
        (uint256 fees0, uint256 fees1) = weir.pendingFees(id);
        assertEq(fees0, 20);
        assertEq(fees1, 0);
        assertEq(weir.vault(id).idle0, 0);
        assertEq(weir.sharesOf(id, payer), F0_SHARES);
        weir.compound(key, "");
        (fees0, fees1) = weir.pendingFees(id);
        assertEq(fees0, 0);
        assertEq(fees1, 0);
        assertEq(weir.vault(id).idle0, 19);
    }

    function test_AC48_nativeZapBalanced() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(tokenA)),
            fee: 0,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });
        PoolId id = initHookless(key, f0Sqrt());
        address payer = makeAddr("payer");
        address recipient = makeAddr("recipient");
        fund(payer, tokenA, K + 2, address(weir));
        vm.deal(payer, K + 2);
        vm.prank(payer);
        uint256 shares = weir.deposit{value: K + 2}(
            WeirVaults.DepositParams({
                key: key,
                amount0: K + 2,
                amount1: K + 2,
                zap: true,
                minShares: F0_SHARES,
                recipient: recipient,
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(shares, F0_SHARES);
        assertEq(weir.sharesOf(id, recipient), F0_SHARES);
        assertEq(payer.balance, 2);
        assertEq(tokenA.balanceOf(payer), 2);
        assertEq(weir.vault(id).liquidity, K);
    }

    function test_AC15_balancedNoSwap() public {
        (PoolKey memory key, PoolId id) = initF0();
        (uint160 before,,,) = poolManager.getSlot0(id);
        address payer = makeAddr("payer");
        fund(payer, tokenA, K + 2, address(weir));
        fund(payer, tokenB, K + 2, address(weir));
        vm.prank(payer);
        uint256 shares = weir.deposit(
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
        (uint160 afterPrice,,,) = poolManager.getSlot0(id);
        assertEq(shares, F0_SHARES);
        assertEq(afterPrice, before);
        assertEq(weir.vault(id).liquidity, K);
    }

    function test_AC61_debitPrecedesPayment() public {
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
        WithdrawReader recipient = new WithdrawReader();
        recipient.arm(weir, id, payer);
        vm.prank(payer);
        weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: F0_SHARES,
                zapTo: 0,
                min0: 0,
                min1: 0,
                recipient: address(recipient),
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(recipient.seenShares(), 0);
        assertEq(weir.sharesOf(id, payer), 0);
        assertEq(weir.vault(id).liquidity, 1000);
    }
}
