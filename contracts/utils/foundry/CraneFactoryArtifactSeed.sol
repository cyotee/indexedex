// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ERC20Facet} from "@crane/contracts/tokens/ERC20/ERC20Facet.sol";
import {ERC2612Facet} from "@crane/contracts/tokens/ERC2612/ERC2612Facet.sol";
import {ERC4626Facet} from "@crane/contracts/tokens/ERC4626/ERC4626Facet.sol";
import {ERC5267Facet} from "@crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol";
import {ERC4626PermitDFPkg} from "@crane/contracts/tokens/ERC4626/ERC4626PermitDFPkg.sol";
import {BalancerV3VaultAwareFacet} from
    "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareFacet.sol";
import {BalancerV3PoolTokenFacet} from
    "@crane/contracts/protocols/dexes/balancer/v3/vault/BetterBalancerV3PoolTokenFacet.sol";
import {BalancerV3AuthenticationFacet} from
    "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3AuthenticationFacet.sol";
import {BalancerV3ConstantProductPoolFacet} from
    "@crane/contracts/protocols/dexes/balancer/v3/pool-constProd/BalancerV3ConstantProductPoolFacet.sol";
import {ERC20MintBurnOwnableFacet} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableFacet.sol";
import {ERC20MintBurnOwnableOperableDFPkg} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {StablePoolFactory} from "@crane/contracts/external/balancer/v3/pool-stable/contracts/StablePoolFactory.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {HubInstance} from "@crane/contracts/protocols/lending/aave/v4/hub/instances/HubInstance.sol";
import {SpokeInstance} from "@crane/contracts/protocols/lending/aave/v4/spoke/instances/SpokeInstance.sol";
import {SenderGuardFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/SenderGuardFacet.sol";
import {WeightedPoolFactory} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";

/**
 * @title CraneFactoryArtifactSeed
 * @notice Src compile root for Crane implementations IndexedEx FactoryServices deploy.
 * @dev Do not import this file from FactoryServices, TestBases, or scripts.
 */
library CraneFactoryArtifactSeed {
    function artifactNames() internal pure returns (string memory) {
        return string.concat(
            type(ERC20Facet).name,
            type(ERC2612Facet).name,
            type(ERC4626Facet).name,
            type(ERC5267Facet).name,
            type(ERC4626PermitDFPkg).name,
            type(BalancerV3VaultAwareFacet).name,
            type(BalancerV3PoolTokenFacet).name,
            type(BalancerV3AuthenticationFacet).name,
            type(BalancerV3ConstantProductPoolFacet).name,
            type(ERC20MintBurnOwnableFacet).name,
            type(ERC20MintBurnOwnableOperableDFPkg).name,
            type(ERC721Facet).name,
            type(StablePoolFactory).name,
            type(PoolManager).name,
            type(HubInstance).name,
            type(SpokeInstance).name,
            type(SenderGuardFacet).name,
            type(WeightedPoolFactory).name
        );
    }
}
