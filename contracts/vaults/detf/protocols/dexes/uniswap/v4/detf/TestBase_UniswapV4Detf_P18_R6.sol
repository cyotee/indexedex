// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";
/// @notice Combo `P18_R6`. pairToken 18-dec mint/bond input; other/rate role 6-dec.
/// @dev Gold CP has one ERC-4626 SE underlying (`pairToken`). vaultShare / detfToken / rebasingClaimToken / Bond NFT stay 18. Do not invent a non-18 vaultShare. After PoolKey sort, pairToken is still the pair role.
abstract contract TestBase_UniswapV4Detf_P18_R6 is TestBase_UniswapV4Detf_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 18; }
    function _rateDecimals() internal pure override returns (uint8) { return 6; }
}
