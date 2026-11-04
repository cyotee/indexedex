// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {TestBase_WeirVaults} from "contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol";
import {WeirVaults} from "contracts/protocols/strategy/weir/WeirVaults.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";

contract WeirVaults_CompoundInventoryTest is TestBase_WeirVaults {
    function _f0Position() internal returns (PoolKey memory key, PoolId id, address payer) {
        (key, id) = initF0();
        payer = makeAddr("payer");
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
    }

    function _donate(PoolKey memory key, uint256 amount0, uint256 amount1) internal {
        address donor = makeAddr("donor");
        if (amount0 > 0) fund(donor, SimpleMintableERC20(Currency.unwrap(key.currency0)), amount0, address(poolRouter));
        if (amount1 > 0) fund(donor, SimpleMintableERC20(Currency.unwrap(key.currency1)), amount1, address(poolRouter));
        vm.prank(donor);
        poolRouter.donate(key, amount0, amount1);
    }

    function test_AC30_F1() public {
        (PoolKey memory key, PoolId id,) = _f0Position();
        _donate(key, 20, 0);
        uint256 treasuryBefore = SimpleMintableERC20(Currency.unwrap(key.currency0)).balanceOf(treasury);
        vm.expectEmit(true, false, false, true, address(weir));
        emit WeirVaults.Compounded(id, 20, 0, 0);
        weir.compound(key, "");
        WeirVaults.Vault memory vault = weir.vault(id);
        assertEq(vault.liquidity, K);
        assertEq(vault.totalShares, K);
        assertEq(vault.idle0, 19);
        assertEq(vault.idle1, 0);
        assertEq(SimpleMintableERC20(Currency.unwrap(key.currency0)).balanceOf(treasury), treasuryBefore + 1);
        assertEq(SimpleMintableERC20(Currency.unwrap(key.currency0)).balanceOf(address(weir)), 19);
    }

    function test_AC30_F1_secondCompound() public {
        (PoolKey memory key, PoolId id,) = _f0Position();
        _donate(key, 20, 0);
        weir.compound(key, "");
        uint64 first = weir.vault(id).lastCompound;
        vm.warp(block.timestamp + 1);
        vm.recordLogs();
        weir.compound(key, "");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; i++) {
            assertTrue(logs[i].emitter != address(weir));
        }
        assertEq(weir.vault(id).idle0, 19);
        assertGt(weir.vault(id).lastCompound, first);
    }

    function test_AC31_F2() public {
        (PoolKey memory key, PoolId id,) = _f0Position();
        _donate(key, 20, 0);
        weir.compound(key, "");
        _donate(key, 0, 20);
        vm.expectEmit(true, false, false, true, address(weir));
        emit WeirVaults.Compounded(id, 0, 20, 17);
        weir.compound(key, "");
        WeirVaults.Vault memory vault = weir.vault(id);
        assertEq(vault.liquidity, K + 17);
        assertEq(vault.totalShares, K);
        assertEq(vault.idle0, 2);
        assertEq(vault.idle1, 2);
    }
}
