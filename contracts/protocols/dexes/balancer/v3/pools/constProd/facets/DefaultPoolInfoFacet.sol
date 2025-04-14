// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.30;

/* -------------------------------------------------------------------------- */
/*                                OpenZeppelin                                */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IPoolInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolInfo.sol";
import {PoolConfig, TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";

contract DefaultPoolInfoFacet is IFacet, IPoolInfo {
    /* ---------------------------------------------------------------------- */
    /*                                   IFacet                               */
    /* ---------------------------------------------------------------------- */

    function facetName() public pure returns (string memory name) {
        return type(DefaultPoolInfoFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IPoolInfo).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](5);
        funcs[0] = IPoolInfo.getTokens.selector;
        funcs[1] = IPoolInfo.getTokenInfo.selector;
        funcs[2] = IPoolInfo.getCurrentLiveBalances.selector;
        funcs[3] = IPoolInfo.getStaticSwapFeePercentage.selector;
        funcs[4] = IPoolInfo.getAggregateFeePercentages.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }

    /* ---------------------------------------------------------------------- */
    /*                                  IPoolInfo                             */
    /* ---------------------------------------------------------------------- */

    function getTokens() external view returns (IERC20[] memory tokens) {
        return BalancerV3VaultAwareRepo._balancerV3Vault().getPoolTokens(address(this));
    }

    function getTokenInfo()
        external
        view
        returns (
            IERC20[] memory tokens,
            TokenInfo[] memory tokenInfo,
            uint256[] memory balancesRaw,
            uint256[] memory lastBalancesLiveScaled18
        )
    {
        return BalancerV3VaultAwareRepo._balancerV3Vault().getPoolTokenInfo(address(this));
    }

    function getCurrentLiveBalances() external view returns (uint256[] memory balancesLiveScaled18) {
        return BalancerV3VaultAwareRepo._balancerV3Vault().getCurrentLiveBalances(address(this));
    }

    function getStaticSwapFeePercentage() external view returns (uint256) {
        return BalancerV3VaultAwareRepo._balancerV3Vault().getStaticSwapFeePercentage(address(this));
    }

    function getAggregateFeePercentages()
        external
        view
        returns (uint256 aggregateSwapFeePercentage, uint256 aggregateYieldFeePercentage)
    {
        PoolConfig memory poolConfig = BalancerV3VaultAwareRepo._balancerV3Vault().getPoolConfig(address(this));
        aggregateSwapFeePercentage = poolConfig.aggregateSwapFeePercentage;
        aggregateYieldFeePercentage = poolConfig.aggregateYieldFeePercentage;
    }
}
