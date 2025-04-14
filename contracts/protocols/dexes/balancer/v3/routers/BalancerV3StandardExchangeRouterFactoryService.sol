// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Vm} from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {SenderGuardFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/SenderGuardFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInQueryFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactInSwapFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutQueryFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutSwapFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactInFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactOutFacet.sol";
import "contracts/protocols/dexes/balancer/v3/routers/prepay/BalancerV3StandardExchangeRouterPrepayHooksFacet.sol";

library BalancerV3StandardExchangeRouterFactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);
}
