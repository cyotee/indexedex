// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {TestBase_WeirVaults} from "contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol";
import {WeirVaults} from "contracts/protocols/strategy/weir/WeirVaults.sol";
import {WeirBase} from "contracts/protocols/strategy/weir/base/WeirBase.sol";
import {Pausable} from "@crane/contracts/external/openzeppelin-contracts-v5/utils/Pausable.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";

/// @notice Callback and entry-guard cases using the AC labels in the assignment.
/// @dev Expectations follow the frozen WeirVaults and WeirBase, without swaps.
contract WeirVaults_Callbacks_Test is TestBase_WeirVaults {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using TransientStateLibrary for IPoolManager;

    event SharesTransferred(PoolId indexed id, address indexed from, address indexed to, uint256 shares);

    /// @notice AC10: zero inputs cannot mint shares or retain auto-created state.
    function test_AC10_zeroDepositRollsBack() public {
        (PoolKey memory key, PoolId id) = initF0();
        address user = makeAddr("user");
        WeirVaults.DepositParams memory p = _depositParams(key, user);
        p.amount0 = 0;
        p.amount1 = 0;
        bytes32 beforeState = _state(id, user, user);
        uint256 checkpoint = snap();
        vm.prank(user);
        vm.expectRevert(WeirVaults.ZeroShares.selector);
        weir.deposit(p);
        assertEq(weir.sharesOf(id, user), 0);
        assertEq(_state(id, user, user), beforeState);
        restore(checkpoint);
    }

    /// @notice AC17: strictly expired deposit and withdrawal fail before token pulls.
    function test_AC17_expiredDepositAndWithdraw() public {
        (PoolKey memory key, PoolId id, address user) = _fundedF0();
        vm.warp(block.timestamp + 1 hours);
        WeirVaults.DepositParams memory p = _depositParams(key, user);
        WeirVaults.WithdrawParams memory w = _withdrawParams(key, user);
        p.deadline = block.timestamp - 1;
        w.deadline = block.timestamp - 1;
        bytes32 beforeState = _state(id, user, user);
        uint256 checkpoint = snap();
        _expectNoPull(user);
        vm.prank(user);
        vm.expectRevert(WeirBase.Expired.selector);
        weir.deposit(p);
        assertEq(_state(id, user, user), beforeState);
        vm.prank(user);
        vm.expectRevert(WeirBase.Expired.selector);
        weir.withdraw(w);
        assertEq(_state(id, user, user), beforeState);
        restore(checkpoint);
    }

    /// @notice AC18: zero recipient is rejected before the deposit pulls either token.
    function test_AC18_zeroRecipientBeforePull() public {
        (PoolKey memory key, PoolId id) = initF0();
        address user = makeAddr("user");
        fund(user, tokenA, K + 2, address(weir));
        fund(user, tokenB, K + 2, address(weir));
        WeirVaults.DepositParams memory p = _depositParams(key, address(0));
        bytes32 beforeState = _state(id, user, address(0));
        uint256 checkpoint = snap();
        _expectNoPull(user);
        vm.prank(user);
        vm.expectRevert(WeirVaults.ZeroAddress.selector);
        weir.deposit(p);
        assertEq(_state(id, user, address(0)), beforeState);
        restore(checkpoint);
    }

    /// @notice AC19: zero withdrawal and overspending a transfer preserve the ledger.
    /// @dev Frozen transferShares permits zero; ZeroShares belongs to withdraw.
    function test_AC19_zeroWithdrawAndOverBalanceTransfer() public {
        (PoolKey memory key, PoolId id, address user) = _fundedF0();
        address recipient = makeAddr("recipient");
        WeirVaults.WithdrawParams memory w = _withdrawParams(key, recipient);
        w.shares = 0;
        bytes32 beforeState = _state(id, user, recipient);
        uint256 checkpoint = snap();
        vm.prank(user);
        vm.expectRevert(WeirVaults.ZeroShares.selector);
        weir.withdraw(w);
        assertEq(_state(id, user, recipient), beforeState);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
        weir.transferShares(id, recipient, F0_SHARES + 1);
        assertEq(_state(id, user, recipient), beforeState);
        restore(checkpoint);
    }

    /// @notice AC19: transferring every assigned share pays no tokens and emits exact ledger data.
    function test_AC19_transferAllShares() public {
        (, PoolId id, address user) = _fundedF0();
        address recipient = makeAddr("recipient");
        bytes memory beforeVault = abi.encode(weir.vault(id));
        bytes32 beforeBalances = _balances(user, recipient);
        assertEq(weir.sharesOf(id, user), F0_SHARES);
        assertEq(weir.sharesOf(id, recipient), 0);
        vm.expectEmit(true, true, true, true, address(weir));
        emit SharesTransferred(id, user, recipient, F0_SHARES);
        vm.prank(user);
        weir.transferShares(id, recipient, F0_SHARES);
        assertEq(weir.sharesOf(id, user), 0);
        assertEq(weir.sharesOf(id, recipient), F0_SHARES);
        assertEq(abi.encode(weir.vault(id)), beforeVault);
        assertEq(_balances(user, recipient), beforeBalances);
    }

    /// @notice AC20: pause rejects deposits before pulling but preserves a funded user's exit.
    function test_AC20_pausedDepositAndWithdraw() public {
        (PoolKey memory key, PoolId id, address user) = _fundedF0();
        address recipient = makeAddr("recipient");
        vm.prank(owner);
        weir.pause();
        WeirVaults.DepositParams memory p = _depositParams(key, user);
        bytes32 beforeState = _state(id, user, recipient);
        uint256 checkpoint = snap();
        _expectNoPull(user);
        vm.prank(user);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        weir.deposit(p);
        assertEq(_state(id, user, recipient), beforeState);
        restore(checkpoint);

        WeirVaults.WithdrawParams memory w = _withdrawParams(key, recipient);
        vm.prank(user);
        (uint256 out0, uint256 out1) = weir.withdraw(w);
        assertEq(out0, F0_OUT);
        assertEq(out1, F0_OUT);
        assertEq(tokenA.balanceOf(recipient), F0_OUT);
        assertEq(tokenB.balanceOf(recipient), F0_OUT);
        assertEq(tokenA.balanceOf(user), 3 * (K + 2) + 2);
        assertEq(tokenB.balanceOf(user), 3 * (K + 2) + 2);
        assertEq(tokenA.balanceOf(address(poolManager)), 1_001);
        assertEq(tokenB.balanceOf(address(poolManager)), 1_001);
        assertEq(tokenA.balanceOf(address(weir)), 0);
        assertEq(tokenB.balanceOf(address(weir)), 0);
        assertEq(weir.sharesOf(id, user), 0);
        WeirVaults.Vault memory v = weir.vault(id);
        assertEq(v.totalShares, 1_000);
        assertEq(v.liquidity, 1_000);
        assertEq(v.idle0, 0);
        assertEq(v.idle1, 0);
        assertTrue(weir.paused());
        assertFalse(poolManager.isUnlocked());
    }

    /// @notice AC46/AC63: callback authorization runs before decoding caller-supplied data.
    function test_AC46_AC63_nonManagerCallback() public {
        (, PoolId id, address user) = _fundedF0();
        bytes32 beforeState = _state(id, user, user);
        uint256 checkpoint = snap();
        vm.prank(user);
        vm.expectRevert(WeirBase.NotPoolManager.selector);
        weir.unlockCallback("");
        assertEq(_state(id, user, user), beforeState);
        restore(checkpoint);
    }

    /// @notice AC47: bubbling and caught nested compound fail with the manager's exact error.
    function test_AC47_compoundWhileUnlocked() public {
        (PoolKey memory key, PoolId id, address user) = _fundedF0();
        // Make an erroneously retained lastCompound update observable.
        vm.warp(block.timestamp + 1 hours);
        bytes memory data = abi.encodeCall(WeirVaults.compound, (key, bytes("")));
        bytes32 beforeState = _state(id, user, address(callRouter));
        uint256 checkpoint = snap();
        vm.expectRevert(bytes4(0x5090d6c6));
        callRouter.callWhileUnlocked(address(weir), data);
        assertEq(_state(id, user, address(callRouter)), beforeState);
        restore(checkpoint);

        checkpoint = snap();
        (bool ok, bytes memory ret) = callRouter.callCaught(address(weir), data);
        assertFalse(ok);
        assertEq(ret, abi.encodeWithSelector(bytes4(0x5090d6c6)));
        assertEq(_state(id, user, address(callRouter)), beforeState);
        assertFalse(poolManager.isUnlocked());
        restore(checkpoint);
    }

    /// @notice AC51: an earlier ERC20 sync makes the first native payment fail.
    /// @dev syncThen catches only the Weir subtree; restore isolates its retained sync.
    function test_AC51_syncedERC20RejectsNativePayment() public {
        uint256 checkpoint = snap();
        PoolKey memory key = ercKey(address(0), address(tokenA), 0, 1, IHooks(address(0)));
        PoolId id = initHookless(key, f0Sqrt());
        fund(address(callRouter), tokenA, K + 2, address(weir));
        vm.deal(address(callRouter), K + 2);
        address recipient = makeAddr("recipient");
        WeirVaults.DepositParams memory p = _depositParams(key, recipient);
        bytes32 beforeState = _state(id, address(callRouter), recipient);
        assertFalse(weir.vault(id).exists);
        (bool ok, bytes memory ret) = callRouter.syncThen(
            Currency.wrap(address(tokenA)), address(weir), abi.encodeCall(WeirVaults.deposit, (p)), K + 2
        );
        assertFalse(ok);
        assertEq(ret, abi.encodeWithSelector(bytes4(0xb0ec849e)));
        assertEq(_state(id, address(callRouter), recipient), beforeState);
        assertEq(address(callRouter).balance, K + 2);
        assertEq(tokenA.balanceOf(address(callRouter)), K + 2);
        assertEq(address(weir).balance, 0);
        assertEq(address(poolManager).balance, 0);
        assertFalse(weir.vault(id).exists);
        restore(checkpoint);
    }

    /// @notice AC63: EOA deposits close the unlock and permit the next deposit on the same vault.
    function test_AC63_successiveEOADepositsRelockManager() public {
        (PoolKey memory key, PoolId id, address user) = _fundedF0();
        assertEq(user.code.length, 0);
        assertFalse(poolManager.isUnlocked());
        WeirVaults.DepositParams memory p = _depositParams(key, user);
        vm.prank(user);
        uint256 shares = weir.deposit(p);
        assertEq(shares, K);
        assertEq(weir.sharesOf(id, user), F0_SHARES + K);
        WeirVaults.Vault memory v = weir.vault(id);
        assertEq(v.totalShares, 2 * K);
        assertEq(v.liquidity, 2 * K);
        assertEq(v.idle0, 0);
        assertEq(v.idle1, 0);
        assertEq(tokenA.balanceOf(user), 2 * (K + 2) + 4);
        assertEq(tokenB.balanceOf(user), 2 * (K + 2) + 4);
        assertEq(tokenA.balanceOf(address(poolManager)), 2 * K);
        assertEq(tokenB.balanceOf(address(poolManager)), 2 * K);
        assertEq(tokenA.balanceOf(address(weir)), 0);
        assertEq(tokenB.balanceOf(address(weir)), 0);
        assertFalse(poolManager.isUnlocked());
    }

    /// @dev F0 costs K per token and refunds two to the payer.
    function _fundedF0() internal returns (PoolKey memory key, PoolId id, address user) {
        (key, id) = initF0();
        user = makeAddr("user");
        fund(user, tokenA, 4 * (K + 2), address(weir));
        fund(user, tokenB, 4 * (K + 2), address(weir));
        WeirVaults.DepositParams memory p = _depositParams(key, user);
        vm.prank(user);
        assertEq(weir.deposit(p), F0_SHARES);
        assertEq(weir.sharesOf(id, user), F0_SHARES);
        assertEq(weir.vault(id).liquidity, K);
        assertEq(weir.vault(id).totalShares, K);
        assertEq(tokenA.balanceOf(user), 3 * (K + 2) + 2);
        assertEq(tokenB.balanceOf(user), 3 * (K + 2) + 2);
        assertEq(tokenA.balanceOf(address(poolManager)), K);
        assertEq(tokenB.balanceOf(address(poolManager)), K);
    }

    /// @dev Paired, non-zapped F0 entry.
    function _depositParams(PoolKey memory key, address recipient)
        internal
        view
        returns (WeirVaults.DepositParams memory)
    {
        return WeirVaults.DepositParams(key, K + 2, K + 2, false, 0, recipient, deadline(), "");
    }

    /// @dev Redeem all genesis-assigned shares to a separate recipient without a swap.
    function _withdrawParams(PoolKey memory key, address recipient)
        internal
        view
        returns (WeirVaults.WithdrawParams memory)
    {
        return WeirVaults.WithdrawParams(key, F0_SHARES, 0, 0, 0, recipient, deadline(), "");
    }

    /// @dev Zero exact-input transferFrom calls prove the guard preceded either pull.
    function _expectNoPull(address payer) internal {
        bytes memory data =
            abi.encodeWithSignature("transferFrom(address,address,uint256)", payer, address(weir), K + 2);
        vm.expectCall(address(tokenA), data, uint64(0));
        vm.expectCall(address(tokenB), data, uint64(0));
    }

    /// @dev Compare accounting, actual salt-zero position, custody, allowances, and lock state.
    /// Synced currency is deliberately excluded: a caught inner revert need not reset it.
    function _state(PoolId id, address user, address recipient) internal view returns (bytes32) {
        WeirVaults.Vault memory v = weir.vault(id);
        (uint128 liquidity, uint256 growth0, uint256 growth1) =
            poolManager.getPositionInfo(id, address(weir), v.tickLower, v.tickUpper, bytes32(0));
        return keccak256(
            abi.encode(
                v,
                weir.vaultCount(),
                weir.sharesOf(id, user),
                weir.sharesOf(id, recipient),
                liquidity,
                growth0,
                growth1,
                _balances(user, recipient),
                poolManager.isUnlocked()
            )
        );
    }

    /// @dev Include every fixture custody endpoint, native balances, and payer allowances.
    function _balances(address user, address recipient) internal view returns (bytes32 result) {
        address[6] memory accounts =
            [user, recipient, address(weir), address(poolManager), treasury, address(callRouter)];
        for (uint256 i; i < accounts.length; ++i) {
            result = keccak256(
                abi.encode(
                    result,
                    tokenA.balanceOf(accounts[i]),
                    tokenB.balanceOf(accounts[i]),
                    tokenC.balanceOf(accounts[i]),
                    accounts[i].balance,
                    tokenA.allowance(accounts[i], address(weir)),
                    tokenB.allowance(accounts[i], address(weir))
                )
            );
        }
    }
}
