// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

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
import { IDiamondPackageCallBackFactory } from "contracts/crane/interfaces/IDiamondPackageCallBackFactory.sol";

import "contracts/crane/constants/Crane_PATHS.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import "contracts/indexedex/constants/Indexedex_CONSTANTS.sol";
import "contracts/indexedex/constants/Indexedex_INITCODE.sol";
import "contracts/indexedex/constants/Indexedex_PATHS.sol";
import { Script_Indexedex_Balancer_V3 } from "contracts/indexedex/scripts/Script_Indexedex_Balancer_V3.sol";
import { Script_Indexedex_Uniswap_V2 } from "contracts/indexedex/scripts/Script_Indexedex_Uniswap_V2.sol";

contract Local_11_Indexedex_Platform
is
    Script_Indexedex_Balancer_V3,
    Script_Indexedex_Uniswap_V2
{

    using Address for address;
    using Address for address payable;

    VmSafe.Wallet dev0Wallet;

    function setUp() public virtual {
        dev0Wallet = vm.createWallet(WALLET_0_KEY);

        setDeployer(dev0Wallet.addr);
        setOwner(deployer());
        setDeploymentPath(string.concat(LOCAL_DEPLOYMENTS_PATH, INDEXEDEX_PLATFORM_FILE));

        /* --------------------- Indexedex Components 2 --------------------- */
        string memory indexedexComponents2DeploymentJson = loadDeployments(string.concat(LOCAL_DEPLOYMENTS_PATH, INDEXEDEX_COMPONENTS_2_FILE));
        balancerV3StandardExchangeRouterDFPkg(BalancerV3StandardExchangeRouterDFPkg(parseJsonAddress(indexedexComponents2DeploymentJson, "balancerV3StandardExchangeRouterDFPkg")));
        balancerV3StandardExchangeBatchRouterDFPkg(BalancerV3StandardExchangeBatchRouterDFPkg(parseJsonAddress(indexedexComponents2DeploymentJson, "balancerV3StandardExchangeBatchRouterDFPkg")));
    }

    function run() public virtual
    override(
        Script_Indexedex_Balancer_V3,
        Script_Indexedex_Uniswap_V2
    ) {
        vm.startBroadcast();

        declare("balancerV3StandardExchangeRouter", address(balancerV3StandardExchangeRouter()));
        declare("balancerV3StandardExchangeBatchRouter", address(balancerV3StandardExchangeBatchRouter()));

        vm.stopBroadcast();
        writeDeploymentJSON();
    }

}
