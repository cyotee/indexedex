// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";

/// @notice Native-unit funded claim and exact held-DETF redemption.
abstract contract UniswapV4Detf_Close_Decimals is TestBase_UniswapV4Detf_Decimals {
    function test_T7_12_matureClaimAndUnstakePreserveReserveLp() public {
        (uint256 id_, uint256 principal_) = _firstBond(_uPair(100));
        assertGt(principal_, 0, "funded native DETF principal");
        _assertFundedMatureClaim(detf, id_, detfUser);
        _assertNoJoinableDust();
    }
}
