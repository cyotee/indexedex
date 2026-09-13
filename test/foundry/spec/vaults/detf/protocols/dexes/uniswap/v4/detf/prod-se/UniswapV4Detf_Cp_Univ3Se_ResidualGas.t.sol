// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_UniswapV4Detf_Cp_Univ3Se} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_Univ3Se.sol";

contract UniswapV4Detf_Cp_Univ3Se_ResidualGas is TestBase_UniswapV4Detf_Cp_Univ3Se {
    function test_residualSweep_nativeUnit() public {
        _checkResidualSweep(1);
    }

    function test_residualSweep_localRehearsalAmount() public {
        _checkResidualSweep(1_197_351_233);
    }

    function testFuzz_residualSweep_smallAmounts(uint256 amount_) public {
        amount_ = bound(amount_, 1, 2_000_000_000);
        _checkResidualSweep(amount_);
    }

    function _checkResidualSweep(uint256 amount_) internal {
        _firstBond(100 ether);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 lpBefore_ = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault());
        vm.prank(detfUser);
        IERC20(mintToken).transfer(detf, amount_);
        uint256 userBefore_ = IERC20(mintToken).balanceOf(detfUser);

        detfInfo.sweepDust{gas: 30_000_000}();

        assertEq(IERC20(mintToken).balanceOf(detfUser), userBefore_, "sweep cannot charge donor again");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "dust creates no user entitlement");
        assertGe(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), lpBefore_, "protocol LP custody preserved");
        assertEq(IERC20(reserveHook).balanceOf(detf), 0, "LP belongs in NFT custody");
        assertLe(IERC20(mintToken).balanceOf(detf), 10, "only native pair dust remains");
        assertLe(IERC20(se).balanceOf(detf), 10, "only native SE dust remains");
        assertEq(IERC20(mintToken).allowance(detf, reserveHook), 0, "join approval cleared");
        assertEq(IERC20(mintToken).allowance(detf, se), 0, "wrap approval cleared");
        _assertSeAllowancesZero();
    }
}
