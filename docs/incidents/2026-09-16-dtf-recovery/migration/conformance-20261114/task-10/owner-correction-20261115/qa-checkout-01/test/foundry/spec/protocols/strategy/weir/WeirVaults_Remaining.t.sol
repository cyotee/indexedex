// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {TestBase_WeirVaults} from "contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol";
import {WeirVaults} from "contracts/protocols/strategy/weir/WeirVaults.sol";
import {WeirBase} from "contracts/protocols/strategy/weir/base/WeirBase.sol";
import {WeirMathOracle} from "contracts/protocols/strategy/weir/test/oracles/WeirMathOracle.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

contract WeirVaults_RemainingTest is TestBase_WeirVaults {
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

    function _donate0(PoolKey memory key, uint256 amount) internal {
        address donor = makeAddr("donor");
        fund(donor, SimpleMintableERC20(Currency.unwrap(key.currency0)), amount, address(poolRouter));
        vm.prank(donor);
        poolRouter.donate(key, amount, 0);
    }

    function test_AC14_F3_idleDilution() public {
        (PoolKey memory key, PoolId id) = initF0();
        address first = makeAddr("first");
        address second = makeAddr("second");
        _pair(first, key, K + 2, F0_SHARES);
        _donate0(key, 20);
        assertEq(_pair(second, key, K + 2, K), K);
        WeirVaults.Vault memory before = weir.vault(id);
        (uint256 base0, uint256 base1) = WeirMathOracle.amountsForLiquidity(
            f0Sqrt(),
            TickMath.getSqrtPriceAtTick(before.tickLower),
            TickMath.getSqrtPriceAtTick(before.tickUpper),
            uint128(K)
        );
        vm.prank(second);
        (uint256 out0, uint256 out1) = weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: K,
                zapTo: 0,
                min0: 0,
                min1: 0,
                recipient: second,
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(out0, base0 + 9);
        assertEq(out1, base1);
        assertEq(weir.vault(id).idle0, 10);
        assertEq(weir.sharesOf(id, first), F0_SHARES);
        assertEq(weir.vault(id).liquidity, K);
        assertEq(weir.vault(id).totalShares, K);
    }

    function test_AC17_minSharesEqualAndPlusOne() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        fund(payer, tokenA, K + 2, address(weir));
        fund(payer, tokenB, K + 2, address(weir));
        uint256 checkpoint = snap();
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
        assertEq(shares, F0_SHARES);
        restore(checkpoint);
        vm.prank(payer);
        vm.expectRevert(WeirVaults.Slippage.selector);
        weir.deposit(
            WeirVaults.DepositParams({
                key: key,
                amount0: K + 2,
                amount1: K + 2,
                zap: false,
                minShares: F0_SHARES + 1,
                recipient: payer,
                deadline: deadline(),
                hookData: ""
            })
        );
        assertFalse(weir.vault(id).exists);
        assertEq(weir.vaultCount(), 0);
        assertEq(tokenA.balanceOf(payer), K + 2);
    }

    function test_AC32_fee0AndFee1000() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _pair(payer, key, K + 2, F0_SHARES);
        vm.prank(owner);
        weir.setPerfFee(0);
        _donate0(key, 20);
        weir.compound(key, "");
        assertEq(weir.vault(id).idle0, 20);
        assertEq(SimpleMintableERC20(Currency.unwrap(key.currency0)).balanceOf(treasury), 0);
        vm.prank(owner);
        weir.setPerfFee(1000);
        _donate0(key, 20);
        weir.compound(key, "");
        assertEq(weir.vault(id).idle0, 20 + 18);
        assertEq(SimpleMintableERC20(Currency.unwrap(key.currency0)).balanceOf(treasury), 2);
    }

    function test_AC32_gross19CutsZero() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        _pair(payer, key, K + 2, F0_SHARES);
        _donate0(key, 19);
        weir.compound(key, "");
        assertEq(weir.vault(id).idle0, 19);
        assertEq(SimpleMintableERC20(Currency.unwrap(key.currency0)).balanceOf(treasury), 0);
    }

    function test_AC36_noAllowanceAndNoBalance() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        tokenA.mint(payer, K + 2);
        tokenB.mint(payer, K + 2);
        vm.prank(payer);
        vm.expectRevert(bytes("allowance"));
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
        address broke = makeAddr("broke");
        vm.prank(broke);
        tokenA.approve(address(weir), type(uint256).max);
        vm.prank(broke);
        tokenB.approve(address(weir), type(uint256).max);
        vm.prank(broke);
        vm.expectRevert(bytes("balance"));
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
        assertFalse(weir.vault(id).exists);
    }

    function test_AC46_timestampWrapAndDeadline() public {
        (PoolKey memory key, PoolId id) = initF0();
        weir.createVault(key);
        vm.warp(type(uint64).max);
        weir.compound(key, "");
        assertEq(weir.vault(id).lastCompound, type(uint64).max);
        vm.warp(uint256(type(uint64).max) + 1);
        weir.compound(key, "");
        assertEq(weir.vault(id).lastCompound, 0);
        vm.warp((uint256(type(uint64).max) + 1) + 7);
        weir.compound(key, "");
        assertEq(weir.vault(id).lastCompound, 7);
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
                minShares: 0,
                recipient: payer,
                deadline: block.timestamp,
                hookData: ""
            })
        );
        assertEq(shares, F0_SHARES);
        uint64 stored = weir.vault(id).lastCompound;
        vm.prank(payer);
        vm.expectRevert(WeirBase.Expired.selector);
        weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: 1,
                zapTo: 0,
                min0: 0,
                min1: 0,
                recipient: payer,
                deadline: block.timestamp - 1,
                hookData: ""
            })
        );
        assertEq(weir.vault(id).lastCompound, stored);
        assertEq(weir.sharesOf(id, payer), F0_SHARES);
    }

    function test_AC48_nativePaired() public {
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
                zap: false,
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
}
