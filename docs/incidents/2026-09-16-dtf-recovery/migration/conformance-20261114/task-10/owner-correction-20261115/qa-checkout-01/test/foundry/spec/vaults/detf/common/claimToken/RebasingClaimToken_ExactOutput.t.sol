// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookMath as CpMath} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";

/// @notice Independent large-integer CP quote regressions retained from the former claim suite.
/// @dev Funded native exact-output accounting is covered by RebasingClaimToken_TrustFlags_Test.
contract ConstantProductLargeReserveRegressionTest is Test {
    function test_largeReserve_zapSplit_matchesIndependentIntegerRoots() public pure {
        // Roots evaluated independently with arbitrary-precision integer square roots.
        assertEq(CpMath.swapDepositSaleAmt(1e38, 1e39), 48_882_173_994_193_580_692_720_962_042_048_031_728);
        assertEq(CpMath.swapDepositSaleAmt(1e33, 1e12), 31_670_317_759_975_314_128_799);
        assertEq(
            CpMath.swapDepositSaleAmt(1_468_412_954_698_849_018_164_308_302_468_434, 1_039_960_158_295_632_572_962_576_340_945_594_816_728),
            735_309_181_950_135_285_813_052_533_171_955
        );
    }

}
