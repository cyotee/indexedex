// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {ProtocolDETFRichBridgeUnitTestBase} from "test/foundry/spec/vaults/protocol/ProtocolDETFRichBridge_UnitTestBase.t.sol";
import {
    ProtocolDETFIntegrationBase as EthereumProtocolDETFIntegrationTestBase
} from "test/foundry/spec/vaults/protocol/EthereumProtocolDETF_IntegrationBase.t.sol";

contract EthereumProtocolDETFRichBridgeLocalTest is
    EthereumProtocolDETFIntegrationTestBase,
    ProtocolDETFRichBridgeUnitTestBase
{
    address internal bridgeRelayer;

    function setUp() public override {
        EthereumProtocolDETFIntegrationTestBase.setUp();
        bridgeRelayer = makeAddr("bridgeRelayer");
        _setUpLocalBridgeConfig();
    }

    function _detf() internal view override returns (IProtocolDETF) {
        return IProtocolDETF(address(detf));
    }

    function _rich() internal view override returns (IERC20) {
        return rich;
    }

    function _richir() internal view override returns (IRICHIR) {
        return richir;
    }

    function _protocolNFTVault() internal view override returns (IProtocolNFTVault) {
        return protocolNFTVault;
    }

    function _alice() internal view override returns (address) {
        return detfAlice;
    }

    function _owner() internal view override returns (address) {
        return bridgeRelayer;
    }

    function _mintRich(address recipient, uint256 amount) internal override {
        vm.prank(owner);
        rich.transfer(recipient, amount);
    }

    function _applyBridgeInit(bytes memory initData) internal override {
        _initBridge(initData);
    }
}