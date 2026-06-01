// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

import {
    IStandardExchangeBufferPoolPkg,
    StandardExchangeBufferPoolStandardVaultPkg
} from "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolStandardVaultPkg.sol";

/**
 * @title StandardExchangeBufferPoolPkg_Smoke
 * @notice Smoke test: instantiate the DFPkg with mock addresses and assert
 *         the static metadata arrays have the correct lengths.
 *         No deployment or Vault interaction is required.
 */
contract StandardExchangeBufferPoolPkg_Smoke is Test {
    StandardExchangeBufferPoolStandardVaultPkg pkg;

    function setUp() public {
        // Use address(this) as a stand-in for IVaultFeeOracleQuery so that
        // feeTo() returns a non-zero address (required by BalancerV3BasePoolFactoryRepo._initialize).
        vm.mockCall(address(this), abi.encodeWithSelector(IVaultFeeOracleQuery.feeTo.selector), abi.encode(address(0xFEE)));

        IStandardExchangeBufferPoolPkg.PkgInit memory init = IStandardExchangeBufferPoolPkg.PkgInit({
            basicVaultFacet:                          IFacet(address(0xF1)),
            standardVaultFacet:                       IFacet(address(0xF2)),
            balancerV3VaultAwareFacet:                IFacet(address(0xF3)),
            betterBalancerV3PoolTokenFacet:           IFacet(address(0xF4)),
            defaultPoolInfoFacet:                     IFacet(address(0xF5)),
            standardSwapFeePercentageBoundsFacet:     IFacet(address(0xF6)),
            unbalancedLiquidityInvariantRatioBoundsFacet: IFacet(address(0xF7)),
            balancerV3AuthenticationFacet:            IFacet(address(0xF8)),
            bufferPoolFacet:                          IFacet(address(0xF9)),
            poolLiquidityFacet:                       IFacet(address(0xFA)),
            hookFacet:                                IFacet(address(0xFB)),
            vaultRegistry:                            IVaultRegistryDeployment(address(0xAA)),
            vaultFeeOracle:                           IVaultFeeOracleQuery(address(this)),
            balancerV3Vault:                          IVault(address(0xBB)),
            diamondFactory:                           IDiamondPackageCallBackFactory(address(0xCC))
        });

        pkg = new StandardExchangeBufferPoolStandardVaultPkg(init);
    }

    function test_facetAddresses_length() public view {
        assertEq(pkg.facetAddresses().length, 11);
    }

    function test_facetInterfaces_length() public view {
        assertEq(pkg.facetInterfaces().length, 15);
    }

    function test_facetAddresses_matchesInit() public view {
        address[] memory addrs = pkg.facetAddresses();
        assertEq(addrs[0],  address(0xF1));
        assertEq(addrs[1],  address(0xF2));
        assertEq(addrs[2],  address(0xF3));
        assertEq(addrs[3],  address(0xF4));
        assertEq(addrs[4],  address(0xF5));
        assertEq(addrs[5],  address(0xF6));
        assertEq(addrs[6],  address(0xF7));
        assertEq(addrs[7],  address(0xF8));
        assertEq(addrs[8],  address(0xF9));
        assertEq(addrs[9],  address(0xFA));
        assertEq(addrs[10], address(0xFB));
    }

    function test_packageName_notEmpty() public view {
        assertFalse(bytes(pkg.packageName()).length == 0);
    }

    function test_name_matchesPackageName() public view {
        assertEq(pkg.name(), pkg.packageName());
    }

    function test_vaultRegistry_immutable() public view {
        assertEq(address(pkg.VAULT_REGISTRY()), address(0xAA));
    }

    function test_balancerV3Vault_immutable() public view {
        assertEq(address(pkg.BALANCER_V3_VAULT()), address(0xBB));
    }
}
