// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @notice DEPRECATED - This script uses `new` deployments instead of CREATE3 factory.
 * @dev For Base mainnet fork deployments, use:
 *      scripts/foundry/anvil_base_main/Script_AnvilBaseMain_DeployAll.s.sol
 *
 * This file is kept for reference only. The `new UniV2Router02()` pattern violates
 * the CREATE3-only deployment convention required by IDXEX-009.
 */

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import { VmSafe } from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import { IWETH } from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import "contracts/crane/constants/CraneINITCODE.sol";
import { betterconsole as console } from "contracts/crane/utils/vm/foundry/tools/betterconsole.sol";
import {
    WALLET_0_KEY,
    WALLET_1_KEY,
    WALLET_2_KEY,
    WALLET_3_KEY,
    WALLET_4_KEY,
    WALLET_5_KEY,
    WALLET_6_KEY,
    WALLET_7_KEY,
    WALLET_8_KEY,
    WALLET_9_KEY
} from "contracts/crane/constants/FoundryConstants.sol";
import { ETHEREUM_SEPOLIA } from "contracts/crane/constants/networks/ETHEREUM_SEPOLIA.sol";
import { BetterAddress as Address } from "contracts/crane/utils/BetterAddress.sol";
import { ICreate2CallbackFactory } from "contracts/crane/interfaces/ICreate2CallbackFactory.sol";
import { IOperable } from "contracts/crane/interfaces/IOperable.sol";
import { IUniswapV2Factory } from "contracts/crane/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "contracts/crane/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import { IUniswapV2Router } from "contracts/crane/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import { UniV2Factory } from "contracts/crane/protocols/dexes/uniswap/v2/UniV2Factory.sol";
import { UniV2Router02 } from "contracts/crane/protocols/dexes/uniswap/v2/UniV2Router02.sol";

import "contracts/crane/constants/Crane_PATHS.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import "contracts/indexedex/constants/Indexedex_CONSTANTS.sol";
import "contracts/indexedex/constants/Indexedex_INITCODE.sol";
import { Script_Indexedex_Balancer_V3 } from "contracts/indexedex/scripts/Script_Indexedex_Balancer_V3.sol";
import { Script_Indexedex_Uniswap_V2 } from "contracts/indexedex/scripts/Script_Indexedex_Uniswap_V2.sol";

contract Local_04_Uniswap_V2
is
    Script_Indexedex_Balancer_V3,
    Script_Indexedex_Uniswap_V2
{

    using Address for address;
    using Address for address payable;

    VmSafe.Wallet dev0Wallet;

    function setUp() public virtual {
        dev0Wallet = vm.createWallet(WALLET_0_KEY);
        // feeCollector(dev0Wallet.addr);
        // setOwner(feeCollector());
        setDeployer(dev0Wallet.addr);
        uniswapV2FeeTo(deployer());
        setDeploymentPath(string.concat(LOCAL_DEPLOYMENTS_PATH, UNISWAP_V2_FILE));
        string memory weth9DeploymentJson = loadDeployments(string.concat(LOCAL_DEPLOYMENTS_PATH, WETH9_FILE));
        weth9(IWETH(parseJsonAddress(weth9DeploymentJson, "weth9")));
        // Can reuse existing Sepolia UniswapV2Factory because it is NOT dependent on the WETH9
        declare("uniswapV2Factory", address(uniswapV2Factory()));

    }

    function run() public virtual
    override(
        Script_Indexedex_Balancer_V3,
        Script_Indexedex_Uniswap_V2
    ) {
        vm.startBroadcast();

        // Must deploy custom UniV2Router02 because it is dependent on the WETH9
        // Deploying with same WETH9 as Sepolia Balancer V3.
        uniswapV2Router(
            IUniswapV2Router(address(new UniV2Router02(address(uniswapV2Factory()), address(weth9()))))
        );
        declare("uniswapV2Router", address(uniswapV2Router()));

        writeDeploymentJSON();
    }

}
