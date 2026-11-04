// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {TestBase_WeirVaults} from "contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol";
import {WeirVaults} from "contracts/protocols/strategy/weir/WeirVaults.sol";
import {WeirBase} from "contracts/protocols/strategy/weir/base/WeirBase.sol";
import {WeirRejectReceiver} from "contracts/protocols/strategy/weir/test/peripherals/WeirRejectReceiver.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";

contract WeirVaults_NativeAccessTest is TestBase_WeirVaults {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    function _nativeKey() internal view returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(tokenA)),
            fee: 0,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });
    }

    function test_AC48_nativeValueLowAndHigh() public {
        PoolKey memory key = _nativeKey();
        initHookless(key, f0Sqrt());
        address payer = makeAddr("payer");
        fund(payer, tokenA, K + 2, address(weir));
        vm.deal(payer, 10 ether);
        vm.prank(payer);
        vm.expectRevert(WeirBase.BadNativeAmount.selector);
        weir.deposit{value: K + 1}(
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
        vm.prank(payer);
        vm.expectRevert(WeirBase.BadNativeAmount.selector);
        weir.deposit{value: K + 3}(
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

    function test_AC48_erc20ValueRejected() public {
        (PoolKey memory key,) = initF0();
        address payer = makeAddr("payer");
        fund(payer, tokenA, K + 2, address(weir));
        fund(payer, tokenB, K + 2, address(weir));
        vm.deal(payer, 1 ether);
        vm.prank(payer);
        vm.expectRevert(WeirBase.BadNativeAmount.selector);
        weir.deposit{value: 1}(
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

    function test_AC52_feeBoundsAndPauseRepeat() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", makeAddr("stranger")));
        weir.setPerfFee(0);
        vm.startPrank(owner);
        weir.setPerfFee(0);
        assertEq(weir.perfFeeBps(), 0);
        weir.setPerfFee(1000);
        assertEq(weir.perfFeeBps(), 1000);
        vm.expectRevert(WeirVaults.FeeTooHigh.selector);
        weir.setPerfFee(1001);
        vm.expectRevert(WeirVaults.ZeroAddress.selector);
        weir.setTreasury(address(0));
        weir.pause();
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        weir.pause();
        weir.unpause();
        vm.expectRevert(abi.encodeWithSignature("ExpectedPause()"));
        weir.unpause();
        vm.stopPrank();
    }

    function test_AC53_twoStepAndRenounceWhilePaused() public {
        address next = makeAddr("next");
        vm.prank(owner);
        weir.transferOwnership(next);
        assertEq(weir.pendingOwner(), next);
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", makeAddr("stranger")));
        weir.acceptOwnership();
        vm.prank(next);
        weir.acceptOwnership();
        assertEq(weir.owner(), next);
        assertEq(weir.pendingOwner(), address(0));
        vm.prank(next);
        weir.pause();
        vm.prank(next);
        weir.renounceOwnership();
        assertEq(weir.owner(), address(0));
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", owner));
        weir.unpause();
    }

    function test_AC49_rejectingRefund() public {
        PoolKey memory key = _nativeKey();
        initHookless(key, f0Sqrt());
        WeirRejectReceiver payer = new WeirRejectReceiver();
        fund(address(payer), tokenA, K + 2, address(weir));
        vm.deal(address(payer), K + 2);
        uint256 id = snap();
        vm.prank(address(payer));
        vm.expectRevert();
        weir.deposit{value: K + 2}(
            WeirVaults.DepositParams({
                key: key,
                amount0: K + 2,
                amount1: K + 2,
                zap: false,
                minShares: 0,
                recipient: address(payer),
                deadline: deadline(),
                hookData: ""
            })
        );
        restore(id);
    }
}
