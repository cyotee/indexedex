// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {IERC20MinterFacade} from "@crane/contracts/tokens/ERC20/IERC20MinterFacade.sol";

import {BridgeTokenPlanning} from "../shared/BridgeTokenPlanning.sol";
import {SharedDeploymentBase} from "../shared/SharedDeploymentBase.sol";

contract Script_17_BridgeTokensToBase is SharedDeploymentBase {
    address private constant BASE_SEPOLIA_L1_STANDARD_BRIDGE = 0xfd0Bf71F60660E2f608ed56e1659C450eB113120;

    IERC20MinterFacade private erc20MinterFacade;

    address private ttaL1;
    address private ttbL1;
    address private ttcL1;
    address private demoWethL1;
    address private richL1;

    address private ttaL2;
    address private ttbL2;
    address private ttcL2;
    address private demoWethL2;
    address private richL2;

    uint256 private ttaAmount;
    uint256 private ttbAmount;
    uint256 private ttcAmount;
    uint256 private demoWethAmount;
    uint256 private richAmount;

    function run() external {
        _setupShared();
        _loadArtifacts();
        _deriveAmounts();

        vm.startBroadcast();
        _topUpMintableBalances();
        _bridgeAll();
        vm.stopBroadcast();

        _exportExecutionPlan();
    }

    function _loadArtifacts() internal {
        string memory ethereumOutDir = _ethereumOutDir();
        string memory sharedOutDir = _sharedOutDir();

        erc20MinterFacade = IERC20MinterFacade(_readAddressFrom(ethereumOutDir, "07_test_tokens.json", "erc20MinterFacade"));

        ttaL1 = _readAddressFrom(sharedOutDir, "bridge_token_manifest.json", "ttaL1Token");
        ttbL1 = _readAddressFrom(sharedOutDir, "bridge_token_manifest.json", "ttbL1Token");
        ttcL1 = _readAddressFrom(sharedOutDir, "bridge_token_manifest.json", "ttcL1Token");
        demoWethL1 = _readAddressFrom(sharedOutDir, "bridge_token_manifest.json", "demoWethL1Token");
        richL1 = _readAddressFrom(sharedOutDir, "bridge_token_manifest.json", "richL1Token");

        ttaL2 = _readAddressFrom(sharedOutDir, "bridge_token_manifest.json", "ttaL2Token");
        ttbL2 = _readAddressFrom(sharedOutDir, "bridge_token_manifest.json", "ttbL2Token");
        ttcL2 = _readAddressFrom(sharedOutDir, "bridge_token_manifest.json", "ttcL2Token");
        demoWethL2 = _readAddressFrom(sharedOutDir, "bridge_token_manifest.json", "demoWethL2Token");
        richL2 = _readAddressFrom(sharedOutDir, "bridge_token_manifest.json", "richL2Token");
    }

    function _deriveAmounts() internal {
        ttaAmount = BridgeTokenPlanning.bridgeAmountTTA();
        ttbAmount = BridgeTokenPlanning.bridgeAmountTTB();
        ttcAmount = BridgeTokenPlanning.bridgeAmountTTC();
        demoWethAmount = BridgeTokenPlanning.bridgeAmountDemoWeth();
        richAmount = IERC20(richL1).balanceOf(deployer) / 2;
    }

    function _topUpMintableBalances() internal {
        _ensureMintableBalance(ttaL1, ttaAmount);
        _ensureMintableBalance(ttbL1, ttbAmount);
        _ensureMintableBalance(ttcL1, ttcAmount);
        _ensureMintableBalance(demoWethL1, demoWethAmount);

        require(IERC20(richL1).balanceOf(deployer) >= richAmount, "Insufficient RICH balance for bridge");
    }

    function _ensureMintableBalance(address token, uint256 amount) internal {
        uint256 currentBalance = IERC20(token).balanceOf(deployer);
        if (currentBalance >= amount) {
            return;
        }

        erc20MinterFacade.mintToken(IERC20MintBurn(token), amount - currentBalance, deployer);
    }

    function _bridgeAll() internal {
        _bridgeToken(ttaL1, ttaL2, ttaAmount);
        _bridgeToken(ttbL1, ttbL2, ttbAmount);
        _bridgeToken(ttcL1, ttcL2, ttcAmount);
        _bridgeToken(demoWethL1, demoWethL2, demoWethAmount);
        _bridgeToken(richL1, richL2, richAmount);
    }

    function _bridgeToken(address l1Token, address l2Token, uint256 amount) internal {
        IERC20(l1Token).approve(BASE_SEPOLIA_L1_STANDARD_BRIDGE, 0);
        IERC20(l1Token).approve(BASE_SEPOLIA_L1_STANDARD_BRIDGE, amount);

        IStandardBridge(payable(BASE_SEPOLIA_L1_STANDARD_BRIDGE)).bridgeERC20To(
            l1Token, l2Token, deployer, amount, BridgeTokenPlanning.BRIDGE_MIN_GAS_LIMIT, bytes("")
        );
    }

    function _exportExecutionPlan() internal {
        string memory json;
        json = vm.serializeAddress("bridgePlan", "recipient", deployer);
        json = vm.serializeAddress("bridgePlan", "l1StandardBridge", BASE_SEPOLIA_L1_STANDARD_BRIDGE);
        json = vm.serializeUint("bridgePlan", "ttaAmount", ttaAmount);
        json = vm.serializeUint("bridgePlan", "ttbAmount", ttbAmount);
        json = vm.serializeUint("bridgePlan", "ttcAmount", ttcAmount);
        json = vm.serializeUint("bridgePlan", "demoWethAmount", demoWethAmount);
        json = vm.serializeUint("bridgePlan", "richAmount", richAmount);
        json = vm.serializeAddress("bridgePlan", "ttaL1Token", ttaL1);
        json = vm.serializeAddress("bridgePlan", "ttaL2Token", ttaL2);
        json = vm.serializeAddress("bridgePlan", "ttbL1Token", ttbL1);
        json = vm.serializeAddress("bridgePlan", "ttbL2Token", ttbL2);
        json = vm.serializeAddress("bridgePlan", "ttcL1Token", ttcL1);
        json = vm.serializeAddress("bridgePlan", "ttcL2Token", ttcL2);
        json = vm.serializeAddress("bridgePlan", "demoWethL1Token", demoWethL1);
        json = vm.serializeAddress("bridgePlan", "demoWethL2Token", demoWethL2);
        json = vm.serializeAddress("bridgePlan", "richL1Token", richL1);
        json = vm.serializeAddress("bridgePlan", "richL2Token", richL2);
        _writeJsonTo(_sharedOutDir(), "bridge_execution_plan.json", json);
    }
}