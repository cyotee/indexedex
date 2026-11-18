// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as Family} from "../../interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {TestBase_UniswapV3FullSpreadAccounting} from "./TestBase_UniswapV3FullSpreadAccounting.sol";

/// @notice Shared real-proxy maintenance calls and independent event observations.
abstract contract TestBase_UniswapV3FullSpreadMaintenance is TestBase_UniswapV3FullSpreadAccounting {
    function setUp() public virtual override {
        super.setUp();
        _setFeeRecipient(alice);
    }

    function _donate(address caller_, address token_, uint256 amount_) internal {
        vm.prank(caller_);
        Family(address(vault)).donate(token_, amount_, false);
    }

    function _setDisabled(bool disabled_) internal {
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), disabled_);
    }

    function _maintenanceEvents(Vm.Log[] memory logs_, uint256 donations_, uint256 compounds_) internal view {
        uint256 actualDonations_;
        uint256 actualCompounds_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != address(vault) || logs_[i_].topics.length == 0) continue;
            bytes32 topic_ = logs_[i_].topics[0];
            if (topic_ == keccak256("Donation()") || topic_ == keccak256("Compounded()")) {
                assertEq(logs_[i_].topics.length, 1, "maintenance events have no indexed arguments");
                assertEq(logs_[i_].data.length, 0, "maintenance events have no data arguments");
                if (topic_ == keccak256("Donation()")) ++actualDonations_;
                else ++actualCompounds_;
            }
        }
        assertEq(actualDonations_, donations_, "exact Donation count");
        assertEq(actualCompounds_, compounds_, "exact Compounded count");
    }
}
