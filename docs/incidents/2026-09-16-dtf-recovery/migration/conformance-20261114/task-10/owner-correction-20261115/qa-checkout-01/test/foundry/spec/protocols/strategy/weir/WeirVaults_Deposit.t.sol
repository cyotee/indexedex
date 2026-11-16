// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {TestBase_WeirVaults} from "contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol";
import {WeirVaults} from "contracts/protocols/strategy/weir/WeirVaults.sol";
import {WeirMathOracle} from "contracts/protocols/strategy/weir/test/oracles/WeirMathOracle.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";

contract WeirVaults_DepositTest is TestBase_WeirVaults {
    using StateLibrary for IPoolManager;

    function test_AC09_F0_payerNotRecipient() public {
        (PoolKey memory key, PoolId id) = initF0();
        assertEq(WeirMathOracle.f0Liquidity(), uint128(K), "oracle liquidity");
        address payer = makeAddr("payer");
        address recipient = makeAddr("recipient");
        fund(payer, tokenA, K + 2, address(weir));
        fund(payer, tokenB, K + 2, address(weir));
        uint256 payerA = tokenA.balanceOf(payer);
        uint256 payerB = tokenB.balanceOf(payer);

        vm.prank(payer);
        uint256 shares = weir.deposit(
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
        assertEq(weir.sharesOf(id, payer), 0);
        WeirVaults.Vault memory vault = weir.vault(id);
        assertEq(vault.liquidity, K);
        assertEq(vault.totalShares, K);
        assertEq(vault.idle0, 0);
        assertEq(vault.idle1, 0);
        assertEq(tokenA.balanceOf(payer), payerA - K);
        assertEq(tokenB.balanceOf(payer), payerB - K);
        (uint128 position,,) = poolManager.getPositionInfo(id, address(weir), vault.tickLower, vault.tickUpper, bytes32(0));
        assertEq(position, K);
    }

    function test_AC21_F0_fullWithdraw() public {
        (PoolKey memory key, PoolId id) = initF0();
        address payer = makeAddr("payer");
        address recipient = makeAddr("recipient");
        fund(payer, tokenA, K + 2, address(weir));
        fund(payer, tokenB, K + 2, address(weir));
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
        uint256 before0 = tokenA.balanceOf(recipient);
        uint256 before1 = tokenB.balanceOf(recipient);
        vm.prank(payer);
        (uint256 out0, uint256 out1) = weir.withdraw(
            WeirVaults.WithdrawParams({
                key: key,
                shares: F0_SHARES,
                zapTo: 0,
                min0: F0_OUT,
                min1: F0_OUT,
                recipient: recipient,
                deadline: deadline(),
                hookData: ""
            })
        );
        assertEq(out0, F0_OUT);
        assertEq(out1, F0_OUT);
        assertEq(tokenA.balanceOf(recipient), before0 + F0_OUT);
        assertEq(tokenB.balanceOf(recipient), before1 + F0_OUT);
        assertEq(weir.sharesOf(id, payer), 0);
        WeirVaults.Vault memory vault = weir.vault(id);
        assertEq(vault.liquidity, 1000);
        assertEq(vault.totalShares, 1000);
        assertEq(vault.idle0, 0);
        assertEq(vault.idle1, 0);
    }
}
