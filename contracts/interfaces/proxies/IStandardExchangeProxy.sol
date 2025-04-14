// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC4626PermitProxy} from "@crane/contracts/interfaces/proxies/IERC4626PermitProxy.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IVautlFeeOracleQueryAware} from "contracts/interfaces/IVautlFeeOracleQueryAware.sol";

/**
 * @title IStandardExchangeProxy
 * @notice Composite interface for Standard Exchange vault proxies.
 * @dev Composes all interfaces exposed by standard exchange DFPkgs:
 *      - IERC4626PermitProxy: ERC20 + ERC20Metadata + ERC20Permit + ERC5267 + ERC4626
 *      - IBasicVault: vaultTokens, reserves, reserveOfToken
 *      - IStandardVault: vaultFeeTypeIds, contentsId, vaultTypes, vaultConfig
 *      - IStandardExchangeIn: previewExchangeIn, exchangeIn
 *      - IStandardExchangeOut: previewExchangeOut, exchangeOut
 *      - IVautlFeeOracleQueryAware: vaultFeeOracleQuery
 */
interface IStandardExchangeProxy is
    IERC4626PermitProxy,
    IBasicVault,
    IStandardVault,
    IStandardExchangeIn,
    IStandardExchangeOut,
    IVautlFeeOracleQueryAware
{}
