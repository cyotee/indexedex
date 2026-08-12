// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

/// @title Script_12_FundUiWalletEth
/// @notice Ensure UI wallet (#1) has ETH for gas. Never deal RICH.
contract Script_21_FundUiWalletEth is DeploymentBase {
    string internal constant ARTIFACT_FILE = "21_ui_wallet.json";
    uint256 internal constant MIN_UI_ETH = 100 ether;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        _logHeader("Stage 21: UI wallet ETH check");

        uint256 bal = uiWallet.balance;
        bool funded;

        if (bal < MIN_UI_ETH) {
            uint256 need = MIN_UI_ETH - bal;
            vm.startBroadcast();
            (bool ok,) = uiWallet.call{value: need}("");
            require(ok, "ETH transfer to UI wallet failed");
            vm.stopBroadcast();
            funded = true;
            bal = uiWallet.balance;
        }

        require(bal >= MIN_UI_ETH, "UI wallet ETH below minimum");

        string memory json;
        json = vm.serializeAddress("ui", "uiWallet", uiWallet);
        json = vm.serializeAddress("ui", "deployer", deployer);
        json = vm.serializeUint("ui", "uiWalletEthWei", bal);
        json = vm.serializeBool("ui", "fundedThisRun", funded);
        json = vm.serializeString("ui", "notes", "Do not deal RICH; buy on pool in UI");
        json = vm.serializeUint("ui", "chainId", block.chainid);
        _writeJson(json, ARTIFACT_FILE);

        _logAddress("uiWallet:", uiWallet);
        _logUint("uiWalletEthWei:", bal);
        _logComplete("Stage 21");
    }
}
