// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Test} from 'forge-std/Test.sol';

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {BASE_MAIN} from '@crane/contracts/constants/networks/BASE_MAIN.sol';

/**
 * @title TestBase_BaseFork
 * @notice Base test contract for Base mainnet fork tests.
 * @dev Provides infrastructure for testing against live Base mainnet:
 *      - Fork selection with optional block pinning via BASE_FORK_BLOCK env var
 *      - Chain ID verification
 *      - Helper functions for code existence checks
 *      - Address labeling for debugging
 *      - Sanity checks for critical mainnet contracts
 */
contract TestBase_BaseFork is Test {
    /* ---------------------------------------------------------------------- */
    /*                              Constants                                 */
    /* ---------------------------------------------------------------------- */

    /// @notice Base mainnet chain ID
    uint256 internal constant BASE_CHAIN_ID = 8453;

    /// @notice Default fork block (pinned for deterministic tests)
    uint256 internal constant DEFAULT_FORK_BLOCK = 40_446_736;

    /// @notice RPC endpoint name configured in foundry.toml
    string internal constant BASE_RPC_ENDPOINT = 'base_mainnet_alchemy';

    /* ---------------------------------------------------------------------- */
    /*                              State                                     */
    /* ---------------------------------------------------------------------- */

    /// @notice The fork ID for this test session
    uint256 internal baseForkId;

    /// @notice The block number at which the fork was created
    uint256 internal forkBlock;

    /* ---------------------------------------------------------------------- */
    /*                               Setup                                    */
    /* ---------------------------------------------------------------------- */

    function setUp() public virtual {
        // Determine fork block: use BASE_FORK_BLOCK env var if set, otherwise default
        forkBlock = _getForkBlock();

        // Create and select the fork
        if (forkBlock > 0) {
            baseForkId = vm.createSelectFork(BASE_RPC_ENDPOINT, forkBlock);
        } else {
            baseForkId = vm.createSelectFork(BASE_RPC_ENDPOINT);
            forkBlock = block.number;
        }

        // Verify we're on Base mainnet
        assertEq(block.chainid, BASE_CHAIN_ID, 'Fork should be on Base mainnet (chainid 8453)');

        // Label mainnet addresses for debugging
        _labelBaseMainAddresses();

        // Run sanity checks
        _sanityCheckMainnetContracts();
    }

    /* ---------------------------------------------------------------------- */
    /*                           Fork Block Selection                         */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Get the fork block from environment variable or return default.
     * @return blockNumber The block number to fork at (0 means use latest)
     */
    function _getForkBlock() internal view returns (uint256 blockNumber) {
        try vm.envUint('BASE_FORK_BLOCK') returns (uint256 envBlock) {
            return envBlock;
        } catch {
            return DEFAULT_FORK_BLOCK;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                           Helper Functions                             */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Check if an address has deployed code.
     * @param addr The address to check
     * @return hasCode True if the address has code deployed
     */
    function _hasCode(address addr) internal view returns (bool hasCode) {
        return addr.code.length > 0;
    }

    /**
     * @notice Assert that an address has deployed code.
     * @param addr The address to check
     * @param name Human-readable name for error messages
     */
    function _assertHasCode(address addr, string memory name) internal view {
        assertTrue(_hasCode(addr), string.concat(name, ' should have deployed code'));
    }

    /* ---------------------------------------------------------------------- */
    /*                           Address Labeling                             */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Label all known Base mainnet addresses for debugging.
     * @dev Helps identify addresses in forge traces and stack traces.
     */
    function _labelBaseMainAddresses() internal virtual {
        // WETH
        vm.label(BASE_MAIN.WETH9, 'WETH9');

        // Aerodrome Core
        vm.label(BASE_MAIN.AERODROME_ROUTER, 'AERODROME_ROUTER');
        vm.label(BASE_MAIN.AERODROME_POOL_FACTORY, 'AERODROME_POOL_FACTORY');
        vm.label(BASE_MAIN.AERODROME_FACTORY_REGISTRY, 'AERODROME_FACTORY_REGISTRY');
        vm.label(BASE_MAIN.AERODROME_VOTER, 'AERODROME_VOTER');
        vm.label(BASE_MAIN.AERODROME_AERO, 'AERODROME_AERO');
        vm.label(BASE_MAIN.AERODROME_VOTING_ESCROW, 'AERODROME_VOTING_ESCROW');
        vm.label(BASE_MAIN.AERODROME_MINTER, 'AERODROME_MINTER');
        vm.label(BASE_MAIN.AERODROME_GAUGE_FACTORY, 'AERODROME_GAUGE_FACTORY');
        vm.label(BASE_MAIN.AERODROME_REWARDS_DISTRIBUTOR, 'AERODROME_REWARDS_DISTRIBUTOR');
        vm.label(BASE_MAIN.AERODROME_POOL_IMPLEMENTATION, 'AERODROME_POOL_IMPLEMENTATION');

        // Balancer V3 Core
        vm.label(BASE_MAIN.BALANCER_V3_VAULT, 'BALANCER_V3_VAULT');
        vm.label(BASE_MAIN.BALANCER_V3_ROUTER, 'BALANCER_V3_ROUTER');
        vm.label(BASE_MAIN.BALANCER_V3_BATCH_ROUTER, 'BALANCER_V3_BATCH_ROUTER');
        vm.label(BASE_MAIN.BALANCER_V3_VAULT_EXTENSION, 'BALANCER_V3_VAULT_EXTENSION');
        vm.label(BASE_MAIN.BALANCER_V3_VAULT_ADMIN, 'BALANCER_V3_VAULT_ADMIN');

        // Balancer V3 Pool Factories
        vm.label(BASE_MAIN.BALANCER_V3_WEIGHTED_POOL_FACTORY, 'BALANCER_V3_WEIGHTED_POOL_FACTORY');
        vm.label(BASE_MAIN.BALANCER_V3_STABLE_POOL_FACTORY, 'BALANCER_V3_STABLE_POOL_FACTORY');
        vm.label(BASE_MAIN.BALANCER_V3_COMPOSITE_LIQUIDITY_ROUTER, 'BALANCER_V3_COMPOSITE_LIQUIDITY_ROUTER');
    }

    /* ---------------------------------------------------------------------- */
    /*                          Sanity Checks                                 */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Verify critical mainnet contracts exist and have code.
     * @dev Called during setUp to ensure the fork is valid.
     */
    function _sanityCheckMainnetContracts() internal view virtual {
        // Aerodrome contracts
        _assertHasCode(BASE_MAIN.AERODROME_ROUTER, 'AERODROME_ROUTER');
        _assertHasCode(BASE_MAIN.AERODROME_POOL_FACTORY, 'AERODROME_POOL_FACTORY');

        // Balancer V3 contracts
        _assertHasCode(BASE_MAIN.BALANCER_V3_VAULT, 'BALANCER_V3_VAULT');
        _assertHasCode(BASE_MAIN.BALANCER_V3_ROUTER, 'BALANCER_V3_ROUTER');
        _assertHasCode(BASE_MAIN.BALANCER_V3_WEIGHTED_POOL_FACTORY, 'BALANCER_V3_WEIGHTED_POOL_FACTORY');
    }

    /* ---------------------------------------------------------------------- */
    /*                           Sanity Test                                  */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Dedicated sanity test to verify fork is working.
     * @dev Can be run standalone: forge test --match-test test_sanity_forkIsValid
     */
    function test_sanity_forkIsValid() public view {
        // Verify chain ID
        assertEq(block.chainid, BASE_CHAIN_ID, 'Should be on Base mainnet');

        // Verify fork block is set
        assertGt(forkBlock, 0, 'Fork block should be set');

        // Verify all critical contracts have code
        assertTrue(_hasCode(BASE_MAIN.AERODROME_ROUTER), 'Aerodrome Router should have code');
        assertTrue(_hasCode(BASE_MAIN.AERODROME_POOL_FACTORY), 'Aerodrome Pool Factory should have code');
        assertTrue(_hasCode(BASE_MAIN.BALANCER_V3_VAULT), 'Balancer V3 Vault should have code');
        assertTrue(_hasCode(BASE_MAIN.BALANCER_V3_ROUTER), 'Balancer V3 Router should have code');
        assertTrue(
            _hasCode(BASE_MAIN.BALANCER_V3_WEIGHTED_POOL_FACTORY), 'Balancer V3 Weighted Pool Factory should have code'
        );
    }
}
