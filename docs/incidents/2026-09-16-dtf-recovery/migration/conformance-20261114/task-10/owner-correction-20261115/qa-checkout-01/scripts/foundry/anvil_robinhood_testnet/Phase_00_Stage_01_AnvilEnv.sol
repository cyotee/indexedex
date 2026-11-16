// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";

/// @title Phase_00_Stage_01_AnvilEnv
/// @notice Anvil-only sanity: chain 46630 and fund Dev 0 / Dev 1 when balances are low.
library Phase_00_Stage_01_AnvilEnv {
    Vm internal constant vm = Vm(VM_ADDRESS);

    address internal constant DEV0 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address internal constant DEV1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint256 internal constant MIN_BAL = 1000 ether;
    uint256 internal constant FUND_BAL = 10_000 ether;

    function execute() internal {
        require(block.chainid == 46630, "Phase 00-01: chainId must be 46630");
        if (DEV0.balance < MIN_BAL) vm.deal(DEV0, FUND_BAL);
        if (DEV1.balance < MIN_BAL) vm.deal(DEV1, FUND_BAL);
    }
}
