// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {TestBase_WeirVaults} from "contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol";
import {WeirVaults} from "contracts/protocols/strategy/weir/WeirVaults.sol";
import {WeirBase} from "contracts/protocols/strategy/weir/base/WeirBase.sol";
import {WeirMathOracle} from "contracts/protocols/strategy/weir/test/oracles/WeirMathOracle.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

contract WeirVaults_MoneyPathsTest is TestBase_WeirVaults {
    using PoolIdLibrary for PoolKey;
    function _deposit(address payer, PoolKey memory key, uint256 amount0, uint256 amount1, uint256 minShares)
        internal
        returns (uint256 shares)
    {
        vm.prank(payer);
        shares = weir.deposit(
            WeirVaults.DepositParams({
                key: key,
                amount0: amount0,
                amount1: amount1,
                zap: false,
                minShares: minShares,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
    }

    function _fundPair(address payer, uint256 amount) internal {
        fund(payer, tokenA, amount, address(weir));
        fund(payer, tokenB, amount, address(weir));
    }

    function _donate0(PoolKey memory key, uint256 amount0) internal {
        address donor = makeAddr("donor");
        fund(donor, SimpleMintableERC20(Currency.unwrap(key.currency0)), amount0, address(poolRouter));
        vm.prank(donor);
        poolRouter.donate(key, amount0, 0);
    }

    function test_AC10_raw1002() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _fundPair(payer, 1002);
        uint256 idSnap = snap();
        vm.prank(payer);
        vm.expectRevert(WeirVaults.ZeroShares.selector);
        weir.deposit(
            WeirVaults.DepositParams({
                key: key,
                amount0: 1002,
                amount1: 1002,
                zap: false,
                minShares: 0,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(weir.sharesOf(id, payer), 0);
        assertEq(weir.vaultCount(), 0);
        restore(idSnap);
    }

    function test_AC10_raw1003() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _fundPair(payer, 1003);
        uint256 shares = _deposit(payer, key, 1003, 1003, 1);
        assertEq(shares, 1);
        assertEq(weir.sharesOf(id, payer), 1);
        WeirVaults.Vault memory vault = weir.vault(id);
        assertEq(vault.liquidity, 1001);
        assertEq(vault.totalShares, 1001);
        assertEq(tokenA.balanceOf(payer), 2);
        assertEq(tokenB.balanceOf(payer), 2);
    }

    function test_AC12_secondPairedDeposit() public {
        (PoolKey memory key, PoolId id) = initF0();
        address first = makeAddr("first");
        address second = makeAddr("second");
        _fundPair(first, K + 2);
        _fundPair(second, K + 2);
        _deposit(first, key, K + 2, K + 2, F0_SHARES);
        uint256 shares = _deposit(second, key, K + 2, K + 2, K);
        assertEq(shares, K);
        assertEq(weir.sharesOf(id, first), F0_SHARES);
        assertEq(weir.sharesOf(id, second), K);
        WeirVaults.Vault memory vault = weir.vault(id);
        assertEq(vault.liquidity, 2 * K);
        assertEq(vault.totalShares, 2 * K);
        assertEq(vault.totalShares - weir.sharesOf(id, first) - weir.sharesOf(id, second), 1000);
    }

    function test_AC13_depositAfterRealFees() public {
        (PoolKey memory key, PoolId id) = initF0();
        address first = makeAddr("first");
        address second = makeAddr("second");
        _fundPair(first, K + 2);
        _fundPair(second, K + 2);
        _deposit(first, key, K + 2, K + 2, F0_SHARES);
        _donate0(key, 20);
        uint256 shares = _deposit(second, key, K + 2, K + 2, K);
        assertEq(shares, K);
        WeirVaults.Vault memory vault = weir.vault(id);
        assertEq(vault.liquidity, 2 * K);
        assertEq(vault.totalShares, 2 * K);
        assertEq(vault.idle0, 19);
        assertEq(weir.sharesOf(id, first), F0_SHARES);
    }

    function test_AC26_minimaEqual() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _fundPair(payer, K + 2);
        _deposit(payer, key, K + 2, K + 2, F0_SHARES);
        vm.prank(payer);
        (uint256 out0, uint256 out1) = weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: F0_SHARES,
                zapTo: 0,
                min0: F0_OUT,
                min1: F0_OUT,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(out0, F0_OUT);
        assertEq(out1, F0_OUT);
        assertEq(weir.sharesOf(id, payer), 0);
    }

    function test_AC26_min0PlusOne() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _fundPair(payer, K + 2);
        _deposit(payer, key, K + 2, K + 2, F0_SHARES);
        uint256 idSnap = snap();
        vm.prank(payer);
        vm.expectRevert(WeirVaults.Slippage.selector);
        weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: F0_SHARES,
                zapTo: 0,
                min0: F0_OUT + 1,
                min1: F0_OUT,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(weir.sharesOf(id, payer), F0_SHARES);
        assertEq(weir.vault(id).liquidity, K);
        restore(idSnap);
    }

    function test_AC27_orderedFaults() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _fundPair(payer, K + 2);
        _deposit(payer, key, K + 2, K + 2, F0_SHARES);
        vm.warp(block.timestamp + 2 hours);
        vm.prank(payer);
        vm.expectRevert(WeirBase.Expired.selector);
        weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: 0,
                zapTo: 9,
                min0: 0,
                min1: 0,
                recipient: address(0),
                deadline: block.timestamp - 1,
                hookData: ""
            })
        );
        vm.warp(block.timestamp - 2 hours);
        vm.prank(payer);
        vm.expectRevert(WeirVaults.BadZap.selector);
        weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: 1,
                zapTo: 3,
                min0: 0,
                min1: 0,
                recipient: address(0),
                deadline: deadline(),
                hookData: ""
            })
        );
        vm.prank(payer);
        vm.expectRevert(WeirVaults.ZeroAddress.selector);
        weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: 1,
                zapTo: 0,
                min0: 0,
                min1: 0,
                recipient: address(0),
                deadline: deadline(),
                hookData: ""
            })
        );
        PoolKey memory missing = f0Key();
        missing.fee = 100;
        vm.prank(payer);
        vm.expectRevert(WeirVaults.NoVault.selector);
        weir.withdraw(
            WeirVaults.WithdrawParams({
                key: missing,
                shares: 1,
                zapTo: 0,
                min0: 0,
                min1: 0,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        vm.prank(payer);
        vm.expectRevert(WeirVaults.ZeroShares.selector);
        weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: 0,
                zapTo: 0,
                min0: 0,
                min1: 0,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        vm.prank(payer);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: F0_SHARES + 1,
                zapTo: 0,
                min0: 0,
                min1: 0,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(weir.sharesOf(id, payer), F0_SHARES);
    }

    function test_AC28_emptyCompoundTwice() public {
        (PoolKey memory key, PoolId id) = initF0();
        weir.createVault(key);
        vm.warp(1000);
        vm.recordLogs();
        weir.compound(key, "");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; i++) {
            assertTrue(logs[i].emitter != address(weir));
        }
        assertEq(weir.vault(id).lastCompound, 1000);
        assertEq(weir.vault(id).liquidity, 0);
        vm.warp(1001);
        weir.compound(key, "");
        assertEq(weir.vault(id).lastCompound, 1001);
    }

    function test_AC29_unknownCompound() public {
        (PoolKey memory key, PoolId id) = initF0();
        vm.expectRevert(WeirVaults.NoVault.selector);
        weir.compound(key, "");
        assertEq(weir.vault(id).lastCompound, 0);
        assertFalse(weir.vault(id).exists);
    }

    function test_AC34_directDonationDoesNotBook() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _fundPair(payer, K + 2);
        _deposit(payer, key, K + 2, K + 2, F0_SHARES);
        tokenA.mint(address(weir), 5);
        WeirVaults.Vault memory vault = weir.vault(id);
        assertEq(vault.idle0, 0);
        assertEq(vault.idle1, 0);
        assertEq(vault.liquidity, K);
        assertEq(weir.sharesOf(id, payer), F0_SHARES);
        (uint256 q0, uint256 q1) = weir.previewRedeem(id, 1);
        assertEq(q0, 0);
        assertEq(q1, 0);
    }

    function test_AC38_previewFractionAndAll() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _fundPair(payer, K + 2);
        _deposit(payer, key, K + 2, K + 2, F0_SHARES);
        WeirVaults.Vault memory vault = weir.vault(id);
        (uint256 q0, uint256 q1) = weir.previewRedeem(id, 0);
        assertEq(q0, 0);
        assertEq(q1, 0);
        (q0, q1) = weir.previewRedeem(id, F0_SHARES);
        (uint256 e0, uint256 e1) = WeirMathOracle.amountsForLiquidity(
            f0Sqrt(),
            TickMath.getSqrtPriceAtTick(vault.tickLower),
            TickMath.getSqrtPriceAtTick(vault.tickUpper),
            uint128(F0_SHARES)
        );
        assertEq(q0, e0);
        assertEq(q1, e1);
        (q0, q1) = weir.previewRedeem(id, vault.totalShares);
        (e0, e1) = WeirMathOracle.amountsForLiquidity(
            f0Sqrt(), TickMath.getSqrtPriceAtTick(vault.tickLower), TickMath.getSqrtPriceAtTick(vault.tickUpper), uint128(K)
        );
        assertEq(q0, e0);
        assertEq(q1, e1);
        assertEq(weir.sharesOf(id, payer), F0_SHARES);
    }

    function test_AC39_shareCastFitsAndOverflow() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _fundPair(payer, K + 2);
        _deposit(payer, key, K + 2, K + 2, F0_SHARES);
        (uint256 q0, uint256 q1) = weir.previewRedeem(id, 2 ** 128 + 7);
        assertEq(q0, 6);
        assertEq(q1, 6);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        weir.previewRedeem(id, 2 ** 236);
        PoolId unknown = f0Key().toId();
        (q0, q1) = weir.previewRedeem(unknown, 1);
        assertEq(q0, 0);
        assertEq(q1, 0);
    }

    function test_AC62_nonpayableValue() public {
        (PoolKey memory key,) = initF0();
        (bool ok, bytes memory data) = address(weir).call{value: 1}(abi.encodeCall(weir.createVault, (key)));
        assertFalse(ok);
        assertEq(data.length, 0);
        assertEq(weir.vaultCount(), 0);
    }
}
