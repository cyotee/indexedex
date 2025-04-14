// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/* ---------------------------------------------------------------------- */
/*                                  Enums                                 */
/* ---------------------------------------------------------------------- */

enum VaultFeeType {
    USAGE,
    DEX,
    BOND,
    SEIGNIORAGE,
    LENDING
    // TBD0,
    // TBD1,
    // TBD2
}

/* ---------------------------------------------------------------------- */
/*                                 Structs                                */
/* ---------------------------------------------------------------------- */

struct BondTerms {
    uint256 minLockDuration;
    uint256 maxLockDuration;
    // TODO Change to min and max bonus percentage
    uint256 minBonusPercentage;
    uint256 maxBonusPercentage;
}

// struct DexTerms {
//     uint256 swapFee;
//     uint256 makerFee;
// }

// struct KinkLendingTerms {
//     uint256 baseRate;
//     uint256 baseMultiplier;
//     uint256 kinkRate;
//     uint256 kinkMultiplier;
// }

struct VaultFeeTypeIds {
    bytes4 usage;
    bytes4 dex;
    bytes4 bond;
    bytes4 seigniorage;
    bytes4 lending;
    // bytes4 tbd0;
    // bytes4 tbd1;
    // bytes4 tbd2;
}
