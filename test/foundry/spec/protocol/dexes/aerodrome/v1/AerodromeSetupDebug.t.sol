// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {
    TestBase_Aerodrome_Pools
} from "@crane/contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_Aerodrome_Pools.sol";
import {
    Aerodrome_Component_FactoryService
} from "contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {
    IAerodromeStandardExchangeDFPkg
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";

/**
 * @title AerodromeSetupDebug
 * @notice Iterative tests to debug Aerodrome test setup.
 * @dev Each test adds one more layer to isolate where setup fails.
 */

// Level 1: Just IndexedexTest
contract Debug_Level1_IndexedexTest is IndexedexTest {
    function test_Level1_IndexedexTestSetup() public view {
        console.log("=== Level 1: IndexedexTest Setup ===");
        console.log("owner:", owner);
        console.log("create3Factory:", address(create3Factory));
        console.log("diamondPackageFactory:", address(diamondPackageFactory));
        console.log("diamondCutFacet:", address(diamondCutFacet));
        console.log("multiStepOwnableFacet:", address(multiStepOwnableFacet));
        console.log("feeCollectorDFPkg:", address(feeCollectorDFPkg));
        console.log("feeCollector:", address(feeCollector));
        console.log("indexedexManagerDFPkg:", address(indexedexManagerDFPkg));
        console.log("indexedexManager:", address(indexedexManager));

        assertTrue(owner != address(0), "owner should be set");
        assertTrue(address(create3Factory) != address(0), "create3Factory should be set");
        assertTrue(address(diamondPackageFactory) != address(0), "diamondPackageFactory should be set");
        assertTrue(address(feeCollector) != address(0), "feeCollector should be set");
        assertTrue(address(indexedexManager) != address(0), "indexedexManager should be set");
    }
}

// Level 2: Add TestBase_VaultComponents
contract Debug_Level2_VaultComponents is TestBase_VaultComponents {
    function test_Level2_VaultComponentsSetup() public view {
        console.log("=== Level 2: TestBase_VaultComponents Setup ===");
        console.log("erc20Facet:", address(erc20Facet));
        console.log("erc2612Facet:", address(erc2612Facet));
        console.log("erc5267Facet:", address(erc5267Facet));
        console.log("erc4626Facet:", address(erc4626Facet));
        console.log("erc4626BasicVaultFacet:", address(erc4626BasicVaultFacet));
        console.log("erc4626StandardVaultFacet:", address(erc4626StandardVaultFacet));

        assertTrue(address(erc20Facet) != address(0), "erc20Facet should be set");
        assertTrue(address(erc2612Facet) != address(0), "erc2612Facet should be set");
        assertTrue(address(erc5267Facet) != address(0), "erc5267Facet should be set");
        assertTrue(address(erc4626Facet) != address(0), "erc4626Facet should be set");
        assertTrue(address(erc4626BasicVaultFacet) != address(0), "erc4626BasicVaultFacet should be set");
        assertTrue(address(erc4626StandardVaultFacet) != address(0), "erc4626StandardVaultFacet should be set");
    }
}

// Level 3: Add Permit2
contract Debug_Level3_Permit2 is TestBase_Permit2 {
    function test_Level3_Permit2Setup() public view {
        console.log("=== Level 3: TestBase_Permit2 Setup ===");
        console.log("permit2:", address(permit2));

        assertTrue(address(permit2) != address(0), "permit2 should be set");
    }
}

// Level 4: Add Aerodrome Pools
contract Debug_Level4_AerodromePools is TestBase_Aerodrome_Pools {
    function test_Level4_AerodromePoolsSetup() public view {
        console.log("=== Level 4: TestBase_Aerodrome_Pools Setup ===");
        console.log("aerodromeRouter:", address(aerodromeRouter));
        console.log("aerodromePoolFactory:", address(aerodromePoolFactory));
        console.log("aeroBalancedPool:", address(aeroBalancedPool));
        console.log("aeroUnbalancedPool:", address(aeroUnbalancedPool));
        console.log("aeroExtremeUnbalancedPool:", address(aeroExtremeUnbalancedPool));

        assertTrue(address(aerodromeRouter) != address(0), "aerodromeRouter should be set");
        assertTrue(address(aerodromePoolFactory) != address(0), "aerodromePoolFactory should be set");
        assertTrue(address(aeroBalancedPool) != address(0), "aeroBalancedPool should be set");
    }
}

// Level 5: Combine Permit2 + VaultComponents (the multi-inheritance challenge)
contract Debug_Level5_Permit2AndVaultComponents is TestBase_Permit2, TestBase_VaultComponents {
    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();
    }

    function test_Level5_CombinedSetup() public view {
        console.log("=== Level 5: Permit2 + VaultComponents Setup ===");
        console.log("permit2:", address(permit2));
        console.log("erc20Facet:", address(erc20Facet));
        console.log("indexedexManager:", address(indexedexManager));

        assertTrue(address(permit2) != address(0), "permit2 should be set");
        assertTrue(address(erc20Facet) != address(0), "erc20Facet should be set");
        assertTrue(address(indexedexManager) != address(0), "indexedexManager should be set");
    }
}

// Level 6: Full combination without DFPkg deployment
contract Debug_Level6_FullBaseWithoutDFPkg is TestBase_Permit2, TestBase_Aerodrome_Pools, TestBase_VaultComponents {
    using Aerodrome_Component_FactoryService for ICreate3FactoryProxy;

    IFacet aerodromeStandardExchangeInFacet;
    IFacet aerodromeStandardExchangeOutFacet;

    function setUp() public virtual override(TestBase_Permit2, TestBase_Aerodrome_Pools, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_Aerodrome_Pools.setUp();
        TestBase_VaultComponents.setUp();
    }

    function test_Level6_FullBaseSetup() public view {
        console.log("=== Level 6: Full Base Setup (no DFPkg) ===");
        console.log("permit2:", address(permit2));
        console.log("aerodromeRouter:", address(aerodromeRouter));
        console.log("indexedexManager:", address(indexedexManager));
        console.log("erc20Facet:", address(erc20Facet));

        assertTrue(address(permit2) != address(0), "permit2 should be set");
        assertTrue(address(aerodromeRouter) != address(0), "aerodromeRouter should be set");
        assertTrue(address(indexedexManager) != address(0), "indexedexManager should be set");
        assertTrue(address(erc20Facet) != address(0), "erc20Facet should be set");
    }

    function test_Level6_DeployFacets() public {
        console.log("=== Level 6: Deploy Aerodrome Facets ===");

        aerodromeStandardExchangeInFacet = create3Factory.deployAerodromeStandardExchangeInFacet();
        console.log("aerodromeStandardExchangeInFacet:", address(aerodromeStandardExchangeInFacet));
        assertTrue(
            address(aerodromeStandardExchangeInFacet) != address(0), "aerodromeStandardExchangeInFacet should be set"
        );

        aerodromeStandardExchangeOutFacet = create3Factory.deployAerodromeStandardExchangeOutFacet();
        console.log("aerodromeStandardExchangeOutFacet:", address(aerodromeStandardExchangeOutFacet));
        assertTrue(
            address(aerodromeStandardExchangeOutFacet) != address(0), "aerodromeStandardExchangeOutFacet should be set"
        );
    }
}

// Level 7: Deploy the DFPkg
contract Debug_Level7_DeployDFPkg is TestBase_Permit2, TestBase_Aerodrome_Pools, TestBase_VaultComponents {
    using Aerodrome_Component_FactoryService for ICreate3FactoryProxy;
    using Aerodrome_Component_FactoryService for IIndexedexManagerProxy;

    IFacet aerodromeStandardExchangeInFacet;
    IFacet aerodromeStandardExchangeOutFacet;
    IAerodromeStandardExchangeDFPkg aerodromeStandardExchangeDFPkg;

    function setUp() public virtual override(TestBase_Permit2, TestBase_Aerodrome_Pools, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_Aerodrome_Pools.setUp();
        TestBase_VaultComponents.setUp();

        aerodromeStandardExchangeInFacet = create3Factory.deployAerodromeStandardExchangeInFacet();
        aerodromeStandardExchangeOutFacet = create3Factory.deployAerodromeStandardExchangeOutFacet();
    }

    function test_Level7_VerifyDependencies() public view {
        console.log("=== Level 7: Verify All Dependencies Before DFPkg ===");
        console.log("erc20Facet:", address(erc20Facet));
        console.log("erc2612Facet:", address(erc2612Facet));
        console.log("erc5267Facet:", address(erc5267Facet));
        console.log("erc4626Facet:", address(erc4626Facet));
        console.log("erc4626BasicVaultFacet:", address(erc4626BasicVaultFacet));
        console.log("erc4626StandardVaultFacet:", address(erc4626StandardVaultFacet));
        console.log("aerodromeStandardExchangeInFacet:", address(aerodromeStandardExchangeInFacet));
        console.log("aerodromeStandardExchangeOutFacet:", address(aerodromeStandardExchangeOutFacet));
        console.log("indexedexManager:", address(indexedexManager));
        console.log("permit2:", address(permit2));
        console.log("aerodromeRouter:", address(aerodromeRouter));

        assertTrue(address(erc20Facet) != address(0), "erc20Facet");
        assertTrue(address(erc2612Facet) != address(0), "erc2612Facet");
        assertTrue(address(erc5267Facet) != address(0), "erc5267Facet");
        assertTrue(address(erc4626Facet) != address(0), "erc4626Facet");
        assertTrue(address(erc4626BasicVaultFacet) != address(0), "erc4626BasicVaultFacet");
        assertTrue(address(erc4626StandardVaultFacet) != address(0), "erc4626StandardVaultFacet");
        assertTrue(address(aerodromeStandardExchangeInFacet) != address(0), "aerodromeStandardExchangeInFacet");
        assertTrue(address(aerodromeStandardExchangeOutFacet) != address(0), "aerodromeStandardExchangeOutFacet");
        assertTrue(address(indexedexManager) != address(0), "indexedexManager");
        assertTrue(address(permit2) != address(0), "permit2");
        assertTrue(address(aerodromeRouter) != address(0), "aerodromeRouter");
    }

    function test_Level7_DeployDFPkg() public {
        console.log("=== Level 7: Deploy AerodromeStandardExchangeDFPkg ===");

        // Verify all dependencies first
        require(address(erc20Facet) != address(0), "erc20Facet is zero");
        require(address(erc2612Facet) != address(0), "erc2612Facet is zero");
        require(address(erc5267Facet) != address(0), "erc5267Facet is zero");
        require(address(erc4626Facet) != address(0), "erc4626Facet is zero");
        require(address(erc4626BasicVaultFacet) != address(0), "erc4626BasicVaultFacet is zero");
        require(address(erc4626StandardVaultFacet) != address(0), "erc4626StandardVaultFacet is zero");
        require(address(aerodromeStandardExchangeInFacet) != address(0), "aerodromeStandardExchangeInFacet is zero");
        require(address(aerodromeStandardExchangeOutFacet) != address(0), "aerodromeStandardExchangeOutFacet is zero");
        require(address(indexedexManager) != address(0), "indexedexManager is zero");
        require(address(permit2) != address(0), "permit2 is zero");
        require(address(aerodromeRouter) != address(0), "aerodromeRouter is zero");

        vm.startPrank(owner);
        aerodromeStandardExchangeDFPkg = indexedexManager.deployAerodromeStandardExchangeDFPkg(
            erc20Facet,
            erc2612Facet,
            erc5267Facet,
            erc4626Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            aerodromeStandardExchangeInFacet,
            aerodromeStandardExchangeOutFacet,
            indexedexManager,
            indexedexManager,
            permit2,
            aerodromeRouter,
            aerodromePoolFactory
        );
        vm.stopPrank();

        console.log("aerodromeStandardExchangeDFPkg:", address(aerodromeStandardExchangeDFPkg));
        assertTrue(address(aerodromeStandardExchangeDFPkg) != address(0), "DFPkg should be deployed");
    }
}
