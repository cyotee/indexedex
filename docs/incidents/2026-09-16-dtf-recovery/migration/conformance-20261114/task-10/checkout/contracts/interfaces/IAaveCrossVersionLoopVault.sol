// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/**
 * @title IAaveCrossVersionLoopVault
 * @author cyotee doge <doge.cyotee>
 * @notice Marker interface for the Aave V3.6 / V4 cross-version carry loop vault.
 * @dev The interfaceId of this interface is used as the vault fee type ID so the
 *      usage/performance fee for this vault type can be configured/overridden on the
 *      Vault Fee Oracle (PRD decisions 19, 26). A dedicated Marker Facet/Target
 *      implements it.
 *
 *      The vault runs a recursive leveraged carry loop between Aave V3.6 (`Pool`) and
 *      Aave V4 (`Spoke`/`Hub`) on a configurable token pair, capturing the cross-version
 *      rate differential. It is NOT an ERC4626 vault (two underlyings); shares are an
 *      LP-style proportional claim on the net reserves (PRD decisions 10, 11).
 * @custom:interfaceid 0x... (computed at build time)
 */
interface IAaveCrossVersionLoopVault {
    /// @notice The first base token of the configured pair.
    function tokenA() external view returns (IERC20);

    /// @notice The second base token of the configured pair.
    function tokenB() external view returns (IERC20);

    /// @notice The Aave V3.6 `Pool` this vault uses as its V3 source.
    function aaveV36Pool() external view returns (address);

    /// @notice The Aave V4 `Spoke` this vault uses as its V4 source.
    function aaveV4Spoke() external view returns (address);

    /// @notice The Aave V4 `Hub` backing the configured V4 `Spoke`.
    function aaveV4Hub() external view returns (address);

    /**
     * @notice Net balance of `token` across both versions, reconciled live from Aave.
     * @dev net = (supplied on V3.6 + supplied on V4) - (debt on V3.6 + debt on V4),
     *      i.e. the amount that would remain after fully unwinding the loop by repaying
     *      all debt (PRD decisions 2, 10). Always read live; repos are caches only.
     */
    function netBalanceOf(IERC20 token) external view returns (uint256);
}
