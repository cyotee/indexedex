// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    TestBase_UniswapV4SingleSEBufferHook_Adversarial as AdvBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/adversarial/TestBase_UniswapV4SingleSEBufferHook_Adversarial.sol";

contract Adversarial_Economic_Test is AdvBase {
    /// @notice B1: SE usage fee on — feeTo mints; donation cannot beat SE preview
    function test_B1_usageFee_previewIncludesFee_donationNoFreeLunch() public {
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        require(feeTo != address(0), "feeTo");

        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 0.02e18);

        uint256 amountIn = 10 ether;
        uint256 preview = buffer.previewWrap(amountIn);

        // Donate pair — still only get SE preview amount (no free lunch)
        pairToken.mint(address(this), 100 ether);
        pairToken.transfer(hook, 100 ether);
        uint256 seBefore = IERC20(se).balanceOf(user);
        uint256 feeBefore = IERC20(se).balanceOf(feeTo);
        _wrapExactIn(amountIn);
        assertEq(IERC20(se).balanceOf(user) - seBefore, preview, "cannot beat SE via donation");
        assertEq(IERC20(se).balanceOf(feeTo) - feeBefore, preview / 50, "2% fee to feeTo");
    }

    /// @notice B2: dilution fee mints fee shares; unwrap still matches SE preview only
    function test_B2_nonOneToOne_unwrapPerSEOnly() public {
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        require(feeTo != address(0), "feeTo");

        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 0.01e18);

        uint256 seOut = _wrapExactIn(20 ether);
        assertGt(IERC20(se).balanceOf(feeTo), 0, "fee minted (non-1:1 supply)");
        uint256 pairOut = buffer.previewUnwrap(seOut);
        uint256 got = _unwrapExactIn(seOut);
        assertEq(got, pairOut, "unwrap only per SE preview");
    }
}
