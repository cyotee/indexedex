// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4WeightedSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ModifyLiquidityParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";

contract UniswapV4WeightedSwapHook_Safety_Test is TestBase_UniswapV4WeightedSwapHook {
    function test_X1_clLiquidityBlocked() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        PoolKey memory key = _pairPoolKeys(hook)[0];
        ModifyLiquidityParams memory p;
        p.tickLower = -100;
        p.tickUpper = 100;
        p.liquidityDelta = 1e18;
        // only PoolManager may call; prank as PM
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook).beforeAddLiquidity(address(this), key, p, "");
        t0;
        t1;
    }

    function test_X2_donateBlocked() public {
        (address hook,,) = _deployN2();
        PoolKey memory key = _pairPoolKeys(hook)[0];
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook).beforeDonate(address(this), key, 1, 1, "");
    }

    function test_X3_donationIgnored() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        _joinFullN2(hook, t0, t1, 1000);
        uint256 r0 = IUniswapV4WeightedSwapHook(hook).reserveOf(address(t0));
        // transfer extra tokens to hook (donation)
        t0.mint(address(hook), _raw(t0, 100));
        assertEq(IUniswapV4WeightedSwapHook(hook).reserveOf(address(t0)), r0); // Repo unchanged
    }

    function test_X4_notPoolManagerRevertsOnCallback() public {
        (address hook,,) = _deployN2();
        PoolKey memory key = _pairPoolKeys(hook)[0];
        vm.expectRevert();
        IHooks(hook).beforeInitialize(address(this), key, 0);
    }

    function test_X5_invalidPoolKey_wrongFee() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(t0)),
            currency1: Currency.wrap(address(t1)),
            fee: 3000, // not DYNAMIC
            tickSpacing: 1,
            hooks: IHooks(hook)
        });
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook).beforeInitialize(address(this), key, 0);
    }
}
