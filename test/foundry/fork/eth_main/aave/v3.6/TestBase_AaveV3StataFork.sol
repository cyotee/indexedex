// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Test} from "forge-std/Test.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ETHEREUM_MAIN} from "@crane/contracts/constants/networks/ETHEREUM_MAIN.sol";
import {StataTokenFactory} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/StataTokenFactory.sol";
import {IStataTokenV2} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IStataTokenV2.sol";
import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {TestBase_AaveV3StataStandardExchange} from "contracts/test/bases/TestBase_AaveV3StataStandardExchange.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/**
 * @title TestBase_AaveV3StataFork (Ethereum)
 * @notice Fork test base for Aave V3.6 Stata Standard Exchange on Ethereum mainnet.
 *         Uses live production Aave Pool + live StataTokenV2 contracts.
 *         Deploys the IndexedEx vault DFPkg + vault instance against the live stata.
 *
 *         Uses DEFAULT_FORK_BLOCK and addresses from Crane network constants.
 */
contract TestBase_AaveV3StataFork is Test, TestBase_AaveV3StataStandardExchange {
    /* ---------------------------------------------------------------------- */
    /*                              Live Aave + Stata                         */
    /* ---------------------------------------------------------------------- */

    uint256 internal constant ETH_CHAIN_ID = ETHEREUM_MAIN.CHAIN_ID;
    uint256 internal constant DEFAULT_FORK_BLOCK = ETHEREUM_MAIN.DEFAULT_FORK_BLOCK;
    string internal constant ETH_RPC_ENDPOINT = "ethereum_mainnet_alchemy";

    address public constant LIVE_POOL = ETHEREUM_MAIN.AAVE_V3_POOL;
    address public constant LIVE_STATA_FACTORY = ETHEREUM_MAIN.AAVE_V3_STATIC_A_TOKEN_FACTORY;

    address public liveStata;
    address public liveUnderlying; // WETH on ETH
    address public liveAToken;
    IPool public livePool;

    // The vault instance bound to live stata
    address public vault;

    uint256 internal ethForkId;
    uint256 internal forkBlock;

    function setUp() public override(TestBase_AaveV3StataStandardExchange) virtual {
        // 1. Fork Ethereum mainnet using RPC alias from foundry.toml
        forkBlock = _getForkBlock();

        if (forkBlock > 0) {
            ethForkId = vm.createSelectFork(ETH_RPC_ENDPOINT, forkBlock);
        } else {
            ethForkId = vm.createSelectFork(ETH_RPC_ENDPOINT);
            forkBlock = block.number;
        }

        require(block.chainid == ETH_CHAIN_ID, "Must be Ethereum mainnet fork");

        // 2. Setup IndexedEx side
        TestBase_AaveV3StataStandardExchange.setUp();

        // 3. Switch to live production stata
        livePool = IPool(LIVE_POOL);
        liveUnderlying = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on ETH

        liveStata = StataTokenFactory(LIVE_STATA_FACTORY).getStataToken(liveUnderlying);
        if (liveStata == address(0)) {
            address[] memory toCreate = new address[](1);
            toCreate[0] = liveUnderlying;
            StataTokenFactory(LIVE_STATA_FACTORY).createStataTokens(toCreate);
            liveStata = StataTokenFactory(LIVE_STATA_FACTORY).getStataToken(liveUnderlying);
        }
        require(liveStata != address(0), "Live stata must exist on fork");

        liveAToken = IStataTokenV2(liveStata).aToken();

        // 4. Deploy vault on live stata
        vault = _deployStataVault(liveStata);

        // 5. Fee oracle
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
        vm.label(liveStata, "LIVE_STATA_WETH_ETH");
        vm.label(liveAToken, "LIVE_ATOKEN_WETH_ETH");
        vm.label(LIVE_POOL, "LIVE_AAVE_POOL_ETH");
        vm.label(LIVE_STATA_FACTORY, "LIVE_STATA_FACTORY_ETH");

        deal(liveUnderlying, address(this), 1000e18);
        IERC20(liveUnderlying).approve(vault, type(uint256).max);
    }

    function _getForkBlock() internal view returns (uint256 blockNumber) {
        try vm.envUint("ETH_FORK_BLOCK") returns (uint256 envBlock) {
            return envBlock;
        } catch {
            return DEFAULT_FORK_BLOCK;
        }
    }
}