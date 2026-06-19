// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Test} from "forge-std/Test.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";
import {StataTokenFactory} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/StataTokenFactory.sol";
import {IStataTokenV2} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IStataTokenV2.sol";
import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {TestBase_BaseFork} from "test/foundry/fork/base_main/TestBase_BaseFork.sol";
import {TestBase_AaveV3StataStandardExchange} from "contracts/test/bases/TestBase_AaveV3StataStandardExchange.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/**
 * @title TestBase_AaveV3StataFork
 * @notice Fork test base for Aave V3.6 Stata Standard Exchange on Base mainnet.
 *         Uses live production Aave Pool + live StataTokenV2 contracts.
 *         Deploys the IndexedEx vault DFPkg + vault instance against the live stata.
 *         Intended for preview-matches-execution, route, fee, pretransferred, fuzz tests.
 */
contract TestBase_AaveV3StataFork is TestBase_BaseFork, TestBase_AaveV3StataStandardExchange {
    /* ---------------------------------------------------------------------- */
    /*                              Live Aave + Stata                         */
    /* ---------------------------------------------------------------------- */

    address public constant LIVE_POOL = BASE_MAIN.AAVE_V3_POOL;
    address public constant LIVE_STATA_FACTORY = BASE_MAIN.AAVE_V3_STATIC_A_TOKEN_FACTORY;

    // Example live stata for WETH (production deployed) - resolved dynamically via factory in practice
    address public constant LIVE_STATA_WETH = 0xe298b938631f750DD409fB18227C4a23dCdaab9b;

    address public liveStata;
    address public liveUnderlying; // WETH
    address public liveAToken;
    IPool public livePool;

    // The vault instance bound to live stata (set by _deploy after DFPkg setup)
    address public vault;

    function setUp() public override(TestBase_BaseFork, TestBase_AaveV3StataStandardExchange) {
        // 1. Fork Base mainnet using the RPC alias defined in foundry.toml
        //    (e.g. base_mainnet_alchemy). This follows the project convention in TestBase_BaseFork
        //    and allows proper resolution of ${ALCHEMY_KEY} etc.
        TestBase_BaseFork.setUp();

        // 2. Setup IndexedEx side (owner, create3Factory, manager, permit2, core facets, deploys the AaveStata DFPkg)
        TestBase_AaveV3StataStandardExchange.setUp();

        // 3. Switch to live production stata + aave (the fork is now active)
        livePool = IPool(LIVE_POOL);
        liveUnderlying = 0x4200000000000000000000000000000000000006; // WETH9

        // Get (or ensure) live stata from production factory
        liveStata = StataTokenFactory(LIVE_STATA_FACTORY).getStataToken(liveUnderlying);
        if (liveStata == address(0)) {
            // In case not pre-created for this asset on the fork block, create it (factory is permissionless for this)
            address[] memory toCreate = new address[](1);
            toCreate[0] = liveUnderlying;
            StataTokenFactory(LIVE_STATA_FACTORY).createStataTokens(toCreate);
            liveStata = StataTokenFactory(LIVE_STATA_FACTORY).getStataToken(liveUnderlying);
        }
        require(liveStata != address(0), "Live stata must exist on fork");

        liveAToken = IStataTokenV2(liveStata).aToken();

        // 4. Deploy (or rebind) the vault against the *live production* stata using the DFPkg
        //    (the super setup created a mock one; we create a fresh one bound to live)
        vault = _deployStataVault(liveStata);

        // 5. Wire fee oracle (use 0 for clean tests; can be overridden per test)
        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IVaultFeeOracleQuery.usageFeeOfVault.selector, vault),
            abi.encode(uint256(0))
        );
        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IVaultFeeOracleQuery.feeTo.selector),
            abi.encode(address(this))
        );

        // 6. Labels + funding
        vm.label(liveStata, "LIVE_STATA_WETH");
        vm.label(liveAToken, "LIVE_ATOKEN_WETH");
        vm.label(LIVE_POOL, "LIVE_AAVE_POOL");
        vm.label(LIVE_STATA_FACTORY, "LIVE_STATA_FACTORY");

        // Fund tester with WETH on the fork (deal works)
        deal(liveUnderlying, address(this), 1000e18);
        // approve for base-> routes
        IERC20(liveUnderlying).approve(vault, type(uint256).max);
    }

}