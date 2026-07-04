// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";

/// @dev Test-only. Production DETF never sees this interface.
interface IStandardExchangeVaultProvider {
    /// Deploy or bind a live Standard Exchange vault + share token + rateTarget for outer DETF.
    function provideStandardExchangeVault()
        external
        returns (IStandardExchangeProxy seVault, IERC20 seShare, IERC20 rateTarget);

    /// Fund `to` with production SE vault shares (provider-specific path).
    function fundForShareMint(address to, uint256 amount) external returns (uint256 shares);

    /// Human label for logs (e.g. "AerodromeStandardExchange", "DualLiquidityCrossVersion").
    function providerLabel() external pure returns (string memory);
}
