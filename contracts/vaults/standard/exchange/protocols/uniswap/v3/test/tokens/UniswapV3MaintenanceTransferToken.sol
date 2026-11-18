// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {ERC20} from "@crane/contracts/tokens/ERC20/ERC20.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @notice Real ERC-20 that transfers separate custody during a vault callback payment.
/// @dev The requested payment is unchanged: this is neither a fee nor a rebase.
contract UniswapV3MaintenanceTransferToken is ERC20 {
    error BlockedTransfer();
    error ReentryRejected(bytes reason);
    error ReentryUnexpectedlySucceeded();

    struct Trigger {
        address vault;
        address pool;
        IERC20 strayToken;
        uint256 strayAmount;
        bool fail;
    }

    Trigger internal trigger;
    address internal reentryVault;
    bytes internal reentryCall;

    constructor() ERC20("Maintenance transfer", "MT") {}

    function mint(address account_, uint256 amount_) external returns (bool) {
        _mint(account_, amount_);
        return true;
    }

    function arm(Trigger memory trigger_) external {
        trigger = trigger_;
    }

    function armFundingReentry(address vault_, bytes memory call_) external {
        reentryVault = vault_;
        reentryCall = call_;
    }

    function transferFrom(address sender_, address recipient_, uint256 amount_) public override returns (bool) {
        bool paid_ = super.transferFrom(sender_, recipient_, amount_);
        if (msg.sender == reentryVault && recipient_ == reentryVault) {
            (bool success_, bytes memory reason_) = reentryVault.call(reentryCall);
            if (success_) revert ReentryUnexpectedlySucceeded();
            // Preserve the observed proxy error through the production funding boundary.
            revert ReentryRejected(reason_);
        }
        return paid_;
    }

    function transfer(address recipient_, uint256 amount_) public override returns (bool) {
        Trigger memory current_ = trigger;
        if (msg.sender == current_.vault && recipient_ == current_.pool) {
            if (current_.fail) revert BlockedTransfer();
            delete trigger;
            bool paid_ = super.transfer(recipient_, amount_);
            if (current_.strayAmount != 0) {
                require(current_.strayToken.transfer(current_.vault, current_.strayAmount), "stray transfer failed");
            }
            return paid_;
        }
        return super.transfer(recipient_, amount_);
    }
}
