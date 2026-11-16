// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {ROBINHOOD_TESTNET} from "@crane/contracts/constants/networks/ROBINHOOD_TESTNET.sol";
import {IMorpho} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {Morpho} from "@crane/contracts/external/morpho/blue/Morpho.sol";
import {AdaptiveCurveIrm} from "@crane/contracts/external/morpho/blue-irm/AdaptiveCurveIrm.sol";
import {OracleMock} from "@crane/contracts/external/morpho/blue/mocks/OracleMock.sol";
import {ORACLE_PRICE_SCALE} from "@crane/contracts/external/morpho/blue/libraries/ConstantsLib.sol";

/// @title Phase_01_Stage_05_MorphoBlue
/// @notice Pin this-chain Morpho if it has code; else rehearsal Morpho + IRM + OracleMock.
/// @dev No createMarket. Do not write Robinhood main CREATE2 when that address has no code.
library Phase_01_Stage_05_MorphoBlue {
    Vm internal constant vm = Vm(VM_ADDRESS);

    function execute(LaunchState storage s, address owner_) internal {
        address pin = ROBINHOOD_TESTNET.MORPHO;
        if (pin != address(0) && pin.code.length > 0) {
            s.morpho = pin;
            s.morphoLocal = false;
            address irm = ROBINHOOD_TESTNET.MORPHO_ADAPTIVE_CURVE_IRM;
            if (irm.code.length > 0) s.morphoIrm = irm;
            address oracle = ROBINHOOD_TESTNET.MORPHO_CHAINLINK_ORACLE_V2_FACTORY;
            if (oracle.code.length > 0) s.morphoOracle = oracle;
            return;
        }
        IMorpho morpho_ = IMorpho(address(new Morpho(owner_)));
        AdaptiveCurveIrm irm_ = new AdaptiveCurveIrm(address(morpho_));
        OracleMock oracle_ = new OracleMock();
        oracle_.setPrice(ORACLE_PRICE_SCALE);
        morpho_.enableIrm(address(irm_));
        morpho_.enableLltv(FixtureEconomics.MORPHO_LLTV);
        s.morpho = address(morpho_);
        s.morphoIrm = address(irm_);
        s.morphoOracle = address(oracle_);
        s.morphoLocal = true;
        vm.label(s.morpho, "Morpho-rehearsal");
        vm.label(s.morphoIrm, "AdaptiveCurveIrm");
        vm.label(s.morphoOracle, "OracleMock");
    }
}
