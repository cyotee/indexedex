// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
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

        uint256 held_ = IERC20(mintToken).balanceOf(detf);
        uint256 quoted_ = IStandardExchangeIn(se).previewExchangeIn(IERC20(mintToken), held_, IERC20(se));
        bool retained_ = quoted_ == 0 || _hookPreviewIsZero(held_);
        uint256 callerBefore_ = IERC20(mintToken).balanceOf(address(this));
        uint256 feeBefore_ = IERC20(mintToken).balanceOf(address(feeCollector));
        detfInfo.sweepDust{gas: 30_000_000}();
        if (retained_) {
            assertEq(IERC20(mintToken).balanceOf(detf), held_, "unmintable complete route retains all custody");
            assertEq(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), lpBefore_, "retention issues no LP");
        } else {
            assertLt(IERC20(mintToken).balanceOf(detf), held_, "mintable residual is deployed");
            assertGt(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), lpBefore_, "deployment mints LP");
        }

        assertEq(IERC20(mintToken).balanceOf(detfUser), userBefore_, "sweep cannot charge donor again");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "dust creates no user entitlement");
        assertGe(IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()), lpBefore_, "protocol LP custody preserved");
        assertEq(IERC20(reserveHook).balanceOf(detf), 0, "LP belongs in NFT custody");
        uint256 remaining_ = IERC20(mintToken).balanceOf(detf);
        if (remaining_ != 0) {
            uint256 seQuote_ = IStandardExchangeIn(se).previewExchangeIn(IERC20(mintToken), remaining_, IERC20(se));
            assertTrue(seQuote_ == 0 || _hookPreviewIsZero(remaining_), "remaining tokens cannot mint through either complete route");
        }
        assertEq(IBasicVault(detf).reserveOfToken(mintToken), remaining_, "all local custody is booked to holders");
        assertEq(IERC20(mintToken).balanceOf(address(this)), callerBefore_, "no caller payout");
        assertEq(IERC20(mintToken).balanceOf(address(feeCollector)), feeBefore_, "no fee-recipient payout");
        assertEq(IERC20(se).balanceOf(detf), 0, "sweep leaves no loose SE shares");
        assertEq(IERC20(mintToken).allowance(detf, reserveHook), 0, "join approval cleared");
        assertEq(IERC20(mintToken).allowance(detf, se), 0, "wrap approval cleared");
        _assertSeAllowancesZero();
    }

    function _hookPreviewIsZero(uint256 amount_) internal view returns (bool) {
        address[] memory tokens_ = new address[](1);
        uint256[] memory amounts_ = new uint256[](1);
        tokens_[0] = mintToken;
        amounts_[0] = amount_;
        // A reverting preview is an error, never evidence that retaining custody is valid.
        if (IUniswapV4SeBufferHook(reserveHook).previewJoinUnbalanced(tokens_, amounts_) != 0) return false;
        return IUniswapV4SeBufferHook(reserveHook).previewJoinSingleAssetExactIn(mintToken, amount_) == 0;
    }
}
