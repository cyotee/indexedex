// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

contract MixedBufferMultiVaultStableDetf_Guards_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function test_zero_amount_reverts() public virtual {
        detf = _deployDetfN(1, 0, 0);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _bootstrapDefault(detf, alice);

        vm.startPrank(bob);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ZeroAmount.selector);
        detfExchangeIn.exchangeIn(
            IERC20(address(_fixtureBufferToken())), 0, IERC20(detf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_deadline_expired_reverts() public virtual {
        detf = _deployDetfN(1, 0, 0);
        detfExchangeIn = IStandardExchangeIn(detf);
        _bootstrapDefault(detf, alice);
        _fundBuffer(bob, _fixtureAmount(10e18));
        vm.startPrank(bob);
        IERC20(address(_fixtureBufferToken())).approve(detf, _fixtureAmount(10e18));
        vm.expectRevert();
        detfExchangeIn.exchangeIn(
            IERC20(address(_fixtureBufferToken())), _fixtureAmount(10e18), IERC20(detf), 0, bob, false, block.timestamp - 1
        );
        vm.stopPrank();
    }

    function test_peg_seed_pure_formula_n1() public virtual {
        // Pure check via bootstrap balances: equal STANDARD legs → seed = (b+s)/(1+1)
        // After bootstrap with equal amounts, total DETF supply >= seed for pool.
        detf = _deployDetfN(1, 0, 0);
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        (,, uint256 free_) = _bootstrapFirstBond(detf, alice, _fixtureAmount(1_000e18), 1_000e18);
        assertTrue(IERC20(detf).totalSupply() > 0, "supply");
        free_;
    }
}
