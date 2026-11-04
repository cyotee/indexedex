// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {TestBase_WeirVaults} from "contracts/protocols/strategy/weir/test/bases/TestBase_WeirVaults.sol";
import {WeirVaults} from "contracts/protocols/strategy/weir/WeirVaults.sol";
import {WeirHostileToken} from "contracts/protocols/strategy/weir/test/peripherals/WeirHostileToken.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {SafeERC20} from "@crane/contracts/external/openzeppelin-contracts-v5/token/ERC20/utils/SafeERC20.sol";

contract WeirVaults_HostileCampaignTest is TestBase_WeirVaults {
    function test_AC64_classifiedHostileCases() public {
        _expectFailure(WeirHostileToken.Mode.FALSE_RETURN, abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(0)), true);
        _expectFailure(WeirHostileToken.Mode.EXPLICIT_REVERT, abi.encodeWithSelector(WeirHostileToken.HostileExplicit.selector), false);
        _expectFailure(WeirHostileToken.Mode.SHORT, abi.encodeWithSelector(bytes4(0x5212cba1)), false);
        _expectFailure(WeirHostileToken.Mode.ZERO, abi.encodeWithSelector(bytes4(0x5212cba1)), false);
        (WeirHostileToken hostile, PoolKey memory key) = _pool();
        address payer = makeAddr("payer");
        _fund(payer, hostile);
        hostile.setMode(WeirHostileToken.Mode.EMPTY_RETURN);
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
    }

    function _expectFailure(WeirHostileToken.Mode mode, bytes memory expected, bool replaceToken) internal {
        (WeirHostileToken hostile, PoolKey memory key) = _pool();
        address payer = makeAddr("payer");
        _fund(payer, hostile);
        hostile.setMode(mode);
        if (replaceToken) {
            expected = abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(hostile));
        }
        vm.prank(payer);
        vm.expectRevert(expected);
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
    }

    function _pool() internal returns (WeirHostileToken hostile, PoolKey memory key) {
        hostile = new WeirHostileToken();
        key = ercKey(address(tokenA), address(hostile), 0, 1, IHooks(address(0)));
        initHookless(key, f0Sqrt());
    }

    function _fund(address payer, WeirHostileToken hostile) internal {
        tokenA.mint(payer, K + 2);
        hostile.mint(payer, K + 2);
        vm.prank(payer);
        tokenA.approve(address(weir), type(uint256).max);
        vm.prank(payer);
        hostile.approve(address(weir), type(uint256).max);
    }
}
