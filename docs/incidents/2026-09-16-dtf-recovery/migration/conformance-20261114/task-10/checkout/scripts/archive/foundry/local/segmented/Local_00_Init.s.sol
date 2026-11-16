// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import { VmSafe } from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

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
import { BetterAddress as Address } from "contracts/crane/utils/BetterAddress.sol";
import { Script_Crane } from "contracts/crane/script/Script_Crane.sol";

contract Local_00_Init_Script
is
    Script_Crane
{

    using Address for address;
    using Address for address payable;

    VmSafe.Wallet dev0Wallet;
    VmSafe.Wallet dev1Wallet;
    VmSafe.Wallet dev2Wallet;
    VmSafe.Wallet dev3Wallet;
    VmSafe.Wallet dev4Wallet;
    VmSafe.Wallet dev5Wallet;
    VmSafe.Wallet dev6Wallet;
    VmSafe.Wallet dev7Wallet;
    VmSafe.Wallet dev8Wallet;
    VmSafe.Wallet dev9Wallet;

    function setUp() public virtual {
        dev0Wallet = vm.createWallet(WALLET_0_KEY);
        dev1Wallet = vm.createWallet(WALLET_1_KEY);
        dev2Wallet = vm.createWallet(WALLET_2_KEY);
        dev3Wallet = vm.createWallet(WALLET_3_KEY);
        dev4Wallet = vm.createWallet(WALLET_4_KEY);
        dev5Wallet = vm.createWallet(WALLET_5_KEY);
        dev6Wallet = vm.createWallet(WALLET_6_KEY);
        dev7Wallet = vm.createWallet(WALLET_7_KEY);
        dev8Wallet = vm.createWallet(WALLET_8_KEY);
        dev9Wallet = vm.createWallet(WALLET_9_KEY);

    }

    function run() public virtual
    override(
        Script_Crane
    ) {
        vm.startBroadcast(WALLET_1_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_2_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_3_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_4_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_5_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_6_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_7_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_8_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_9_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();
    }

}