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
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

contract WeirVaults_ScriptedTest is TestBase_WeirVaults {
    using StateLibrary for IPoolManager;
    using TransientStateLibrary for IPoolManager;

    uint256 public deposits;
    uint256 public withdrawals;
    uint256 public transfers;
    uint256 public compounds;
    uint256 public donations;
    uint256 public pauses;
    uint256 public ownerChanges;

    function test_AC63_scriptedDimensions() public {
        address[3] memory users = [makeAddr("u0"), makeAddr("u1"), makeAddr("u2")];
        (PoolKey memory first, PoolId firstId) = initF0();
        PoolKey memory second = ercKey(address(tokenA), address(tokenC), 0, 1, IHooks(address(0)));
        PoolId secondId = initHookless(second, f0Sqrt());
        for (uint256 i; i < users.length; i++) {
            fund(users[i], tokenA, 4 * (K + 2), address(weir));
            fund(users[i], tokenB, 2 * (K + 2), address(weir));
            fund(users[i], tokenC, 2 * (K + 2), address(weir));
        }
        _deposit(users[0], first, firstId);
        _deposit(users[1], second, secondId);
        vm.prank(users[0]);
        weir.transferShares(firstId, users[2], 100);
        transfers++;
        _check(first, firstId);
        address donor = makeAddr("donor");
        fund(donor, SimpleMintableERC20(Currency.unwrap(first.currency0)), 20, address(poolRouter));
        vm.prank(donor);
        poolRouter.donate(first, 20, 0);
        donations++;
        weir.compound(first, "");
        compounds++;
        _check(first, firstId);
        vm.prank(users[0]);
        weir.withdraw(
            WeirVaults.WithdrawParams({
                key: first,
                shares: 100,
                zapTo: 0,
                min0: 0,
                min1: 0,
                recipient: users[0],
                deadline: deadline(),
                hookData: ""
            })
        );
        withdrawals++;
        _check(first, firstId);
        _check(second, secondId);
        vm.prank(owner);
        weir.pause();
        pauses++;
        vm.prank(users[2]);
        vm.expectRevert();
        weir.deposit(
            WeirVaults.DepositParams({
                key: first,
                amount0: K + 2,
                amount1: K + 2,
                zap: false,
                minShares: 0,
                recipient: users[2],
                deadline: deadline(),
                hookData: ""
            })
        );
        address next = makeAddr("next");
        vm.prank(owner);
        weir.transferOwnership(next);
        vm.prank(next);
        weir.acceptOwnership();
        ownerChanges++;
        assertEq(weir.owner(), next);
        assertGt(deposits, 0);
        assertGt(withdrawals, 0);
        assertGt(transfers, 0);
        assertGt(compounds, 0);
        assertGt(donations, 0);
        assertGt(pauses, 0);
        assertGt(ownerChanges, 0);
    }

    function _deposit(address user, PoolKey memory key, PoolId id) internal {
        vm.prank(user);
        weir.deposit(
            WeirVaults.DepositParams({
                key: key,
                amount0: K + 2,
                amount1: K + 2,
                zap: false,
                minShares: 0,
                recipient: user,
                deadline: deadline(),
                hookData: ""
            })
        );
        deposits++;
        _check(key, id);
    }

    function _check(PoolKey memory key, PoolId id) internal view {
        WeirVaults.Vault memory vault = weir.vault(id);
        if (!vault.exists) return;
        (uint128 position,,) =
            poolManager.getPositionInfo(id, address(weir), vault.tickLower, vault.tickUpper, bytes32(0));
        assertEq(position, vault.liquidity);
        assertFalse(poolManager.isUnlocked());
        assertGe(vault.totalShares, vault.liquidity == 0 ? 0 : 1000);
    }
}
