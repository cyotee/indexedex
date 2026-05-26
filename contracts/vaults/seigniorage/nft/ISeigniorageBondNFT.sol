// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface ISeigniorageBondNFT {

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error DeadlineExceeded(uint256 deadline, uint256 currentTimestamp);

    error NotBondHolder(address owner, address caller);
    
    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    event NewBond(
        uint256 indexed tokenId, address indexed recipient, uint256 shares, uint256 bonusMultiplier, uint256 unlockTime
    );

}