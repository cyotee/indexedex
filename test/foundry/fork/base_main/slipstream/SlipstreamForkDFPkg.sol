// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Crane                                     */
/* -------------------------------------------------------------------------- */

import {ICLFactory} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLFactory.sol";
import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                 Indexedex                                   */
/* -------------------------------------------------------------------------- */

import {
    ISlipstreamStandardExchangeDFPkg,
    SlipstreamStandardExchangeDFPkg
} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeDFPkg.sol";

/**
 * @title SlipstreamForkDFPkg
 * @notice Concrete Diamond Factory Package for Slipstream Standard Exchange Vaults on Base mainnet fork.
 * @dev Extends the abstract SlipstreamStandardExchangeDFPkg with a concrete implementation
 *      suitable for deployment via CREATE3. This contract is used exclusively in fork tests
 *      where the abstract base cannot be deployed directly.
 *
 *      The vault deployment follows the standard IndexedEx pattern:
 *      1. DFPkg deployed via IVaultRegistryDeployment.deployPkg()
 *      2. Vault instances created via deployVault(pool, widthMultiplier)
 */
contract SlipstreamForkDFPkg is SlipstreamStandardExchangeDFPkg {
    constructor(PkgInit memory pkgInit) SlipstreamStandardExchangeDFPkg(pkgInit) {}
}
