// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {DETFUsageFeeLib} from "contracts/vaults/detf/common/core/DETFUsageFeeLib.sol";

/// @notice T09 / L-STRUCT-1: single shared MintSplit definition is importable and usable.
contract T09_MintSplit_Test is Test {
    function test_sharedMintSplit_layoutAndSplitHelper() public pure {
        MintSplit memory s;
        s.grossDetf = 100e18;
        (uint256 afterFee, uint256 fee) = DETFUsageFeeLib._splitUsageFee(s.grossDetf, 0.01e18);
        s.feeToDetf = fee;
        s.userDetf = afterFee;
        s.inventoryDetf = 0;
        assertEq(s.userDetf + s.feeToDetf, s.grossDetf);
        assertEq(s.feeToDetf, 1e18);
    }
}
