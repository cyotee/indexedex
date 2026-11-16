// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {SwapKind, VaultSwapParams} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {BalancerV3VaultAwareRepo} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {DETFBalancerReserveSwapRepo as SwapRepo} from "./DETFBalancerReserveSwapRepo.sol";

/// @notice Native reserve swaps for funded DETFs. Pool pricing and fees remain in Balancer.
abstract contract DETFBalancerReserveSwapTarget {
    using BetterSafeERC20 for IERC20;

    error UnauthorizedReserveSwap();
    error ReserveSwapFundingMismatch(uint256 expected, uint256 actual);

    /// @dev The outer standard route has already pulled its input and holds the DETF lock.
    function _reserveSwap(address pool_, IERC20 in_, IERC20 out_, uint256 amount_, uint256 min_)
        internal returns (uint256 received_)
    {
        VaultSwapParams memory p_ = VaultSwapParams({
            kind: SwapKind.EXACT_IN, pool: pool_, tokenIn: in_, tokenOut: out_,
            amountGivenRaw: amount_, limitRaw: min_, userData: ""
        });
        (, received_) = _requestReserveSwap(p_);
    }

    function _reserveSwapExactOut(address pool_, IERC20 in_, IERC20 out_, uint256 amount_, uint256 max_)
        internal returns (uint256 paid_)
    {
        VaultSwapParams memory p_ = VaultSwapParams({
            kind: SwapKind.EXACT_OUT, pool: pool_, tokenIn: in_, tokenOut: out_,
            amountGivenRaw: amount_, limitRaw: max_, userData: ""
        });
        (paid_,) = _requestReserveSwap(p_);
    }

    function _requestReserveSwap(VaultSwapParams memory p_) internal returns (uint256 paid_, uint256 received_) {
        if (!ReentrancyLockRepo._isLocked() || SwapRepo._layoutStruct().pendingSwap != bytes32(0)) {
            revert UnauthorizedReserveSwap();
        }
        SwapRepo._setPending(keccak256(abi.encode(p_)));
        (paid_, received_) = abi.decode(
            BalancerV3VaultAwareRepo._balancerV3Vault().unlock(
                abi.encodeCall(this.executeReserveSwap, (p_))
            ), (uint256, uint256)
        );
        if (SwapRepo._layoutStruct().pendingSwap != bytes32(0)) revert UnauthorizedReserveSwap();
    }

    /// @notice Authenticated callback only; never a user-facing alternative to Standard Exchange.
    function executeReserveSwap(VaultSwapParams calldata p_) external returns (uint256 paid_, uint256 received_) {
        IVault vault_ = BalancerV3VaultAwareRepo._balancerV3Vault();
        if (
            msg.sender != address(vault_) || !ReentrancyLockRepo._isLocked()
                || SwapRepo._layoutStruct().pendingSwap != keccak256(abi.encode(p_))
        ) revert UnauthorizedReserveSwap();
        SwapRepo._setPending(bytes32(0));
        (, paid_, received_) = vault_.swap(p_);
        if (p_.kind == SwapKind.EXACT_IN) {
            if (paid_ != p_.amountGivenRaw) revert ReserveSwapFundingMismatch(p_.amountGivenRaw, paid_);
        } else if (received_ != p_.amountGivenRaw) {
            revert ReserveSwapFundingMismatch(p_.amountGivenRaw, received_);
        }
        p_.tokenIn.safeTransfer(address(vault_), paid_);
        uint256 settled_ = vault_.settle(p_.tokenIn, paid_);
        if (settled_ != paid_) revert ReserveSwapFundingMismatch(paid_, settled_);
        uint256 before_ = p_.tokenOut.balanceOf(address(this));
        vault_.sendTo(p_.tokenOut, address(this), received_);
        uint256 delta_ = p_.tokenOut.balanceOf(address(this)) - before_;
        if (delta_ != received_) revert ReserveSwapFundingMismatch(received_, delta_);
    }
}
