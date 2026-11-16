// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {EETH} from "@crane/contracts/external/etherfi/core/EETH.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

/// @dev Non-SUT administrative dependencies; token transfers and wrapping use the vendored tokens.
contract NativeEtherFiPolicy {
    function nonBlacklisted(address) external pure {}

    function blacklistedUntil(address) external pure returns (uint256) {
        return 0;
    }
    function consumeToken(bytes32, uint64) external pure {}
}

/// @dev External LP fixture with the protocol's native share/pooled-ETH conversion and deposit order.
contract NativeEtherFiPool {
    EETH public eETH;
    NativeEtherFiPolicy public immutable blacklister;
    uint256 public pooled;
    bool public paused;
    uint256 public pausedUntil;

    constructor(NativeEtherFiPolicy policy_) {
        blacklister = policy_;
    }

    function bind(EETH token_) external {
        require(address(eETH) == address(0));
        eETH = token_;
    }

    function getTotalPooledEther() external view returns (uint256) {
        return pooled;
    }

    function totalValueInLp() external view returns (uint256) {
        return address(this).balance;
    }

    function getTotalEtherClaimOf(address user_) external view returns (uint256) {
        return amountForShare(eETH.shares(user_));
    }

    function sharesForAmount(uint256 amount_) public view returns (uint256) {
        return pooled == 0 ? amount_ : Math.mulDiv(amount_, eETH.totalShares(), pooled);
    }

    function sharesForWithdrawalAmount(uint256 amount_) external view returns (uint256) {
        return pooled == 0 ? amount_ : Math.mulDiv(amount_, eETH.totalShares(), pooled, Math.Rounding.Ceil);
    }

    function amountForShare(uint256 shares_) public view returns (uint256) {
        uint256 supply_ = eETH.totalShares();
        return supply_ == 0 ? 0 : Math.mulDiv(shares_, pooled, supply_);
    }

    function deposit() external payable returns (uint256 minted_) {
        require(!paused && pausedUntil < block.timestamp);
        minted_ = sharesForAmount(msg.value);
        pooled += msg.value;
        eETH.mintShares(msg.sender, minted_);
    }

    /// @dev Simulate consensus rewards or slashing on the external protocol, never on the vault.
    function setPooled(uint256 pooled_) external {
        require(pooled_ > 0);
        pooled = pooled_;
    }
}
