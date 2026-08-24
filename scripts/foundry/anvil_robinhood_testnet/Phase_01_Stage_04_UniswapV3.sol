// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {ROBINHOOD_TESTNET} from "@crane/contracts/constants/networks/ROBINHOOD_TESTNET.sol";
import {UniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/UniswapV3Factory.sol";

/// @title Phase_01_Stage_04_UniswapV3
/// @notice Pin this-chain V3 factory if it has code; else rehearsal `new UniswapV3Factory` + enableFeeAmount(100,1).
library Phase_01_Stage_04_UniswapV3 {
    Vm internal constant vm = Vm(VM_ADDRESS);

    uint24 internal constant FEE_ONE_BP = 100;
    int24 internal constant TICK_SPACING_ONE_BP = 1;

    function execute() internal returns (address v3Factory, bool v3Local) {
        address pin = ROBINHOOD_TESTNET.UNISWAP_V3_FACTORY;
        if (pin != address(0) && pin.code.length > 0) {
            return (pin, false);
        }
        UniswapV3Factory factory_ = new UniswapV3Factory();
        factory_.enableFeeAmount(FEE_ONE_BP, TICK_SPACING_ONE_BP);
        vm.label(address(factory_), "UniswapV3Factory-rehearsal");
        return (address(factory_), true);
    }
}
