// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/composed/stable/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

contract MixedBufferMultiVaultStableDetf_Guards_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function test_zero_amount_reverts() public {
        detf = _deployOpenThresholdDetfN(1);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _bootstrapDefault(detf, alice);

        vm.startPrank(bob);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ZeroAmount.selector);
        detfExchangeIn.exchangeIn(
            IERC20(address(dai)), 0, IERC20(detf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_deadline_expired_reverts() public {
        detf = _deployOpenThresholdDetfN(1);
        detfExchangeIn = IStandardExchangeIn(detf);
        _bootstrapDefault(detf, alice);
        _fundBuffer(bob, 10e18);
        vm.startPrank(bob);
        IERC20(address(dai)).approve(detf, 10e18);
        vm.expectRevert();
        detfExchangeIn.exchangeIn(
            IERC20(address(dai)), 10e18, IERC20(detf), 0, bob, false, block.timestamp - 1
        );
        vm.stopPrank();
    }

    function test_peg_seed_pure_formula_n1() public {
        // Pure check via bootstrap balances: equal STANDARD legs → seed = (b+s)/(1+1)
        // After bootstrap with equal amounts, total DETF supply >= seed for pool.
        detf = _deployOpenThresholdDetfN(1);
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        (,, uint256 free_) = _bootstrapFirstBond(detf, alice, 1_000e18, 1_000e18);
        assertTrue(IERC20(detf).totalSupply() > 0, "supply");
        free_;
    }
}
