// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {BasicVaultCommon} from "contracts/vaults/basic/BasicVaultCommon.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAaveV3StataStandardVault} from "contracts/interfaces/IAaveV3StataStandardVault.sol";
import {IERC20AaveLM} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IERC20AaveLM.sol";

/**
 * @title AaveV3StataStandardExchangeCommon
 * @notice Shared logic for the Stata Standard Exchange vault.
 * Includes:
 * - Usage fee inflation on share mints (entry fee)
 * - Reward collection from Stata + forward to feeTo on every operation
 * - ERC4626 share math helpers for Stata delta <-> SE Vault shares
 */
contract AaveV3StataStandardExchangeCommon is BasicVaultCommon {
    using ERC20Repo for ERC20Repo.Storage;
    using SafeERC20 for IERC20;

    uint256 internal constant FEE_DENOMINATOR = 1e18; // WAD

    /* ------------------------------------------------------------------ */
    /*                        Usage Fee on Mint                           */
    /* ------------------------------------------------------------------ */

    /**
     * @dev Applies the usage fee (if > 0) by inflating total supply with fee shares,
     *      then mints the full `sharesForDeposit` to the recipient.
     *
     * Mint fee logic (per user spec):
     *   if (usageFee > 0) {
     *     feeShares = sharesForDeposit * usageFee / FEE_DENOMINATOR
     *     _mint(feeTo, feeShares)   // inflates total supply as the % of shares being minted for this deposit
     *   }
     *   _mint(recipient, sharesForDeposit);
     */
    function _mintSharesWithUsageFee(address recipient, uint256 sharesForDeposit) internal {
        if (sharesForDeposit == 0) {
            return;
        }

        uint256 usageFee = _getCurrentUsageFee();

        if (usageFee > 0) {
            uint256 feeShares = (sharesForDeposit * usageFee) / FEE_DENOMINATOR;

            address feeRecipient = address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo());
            if (feeShares > 0 && feeRecipient != address(0)) {
                ERC20Repo._mint(feeRecipient, feeShares);
            }
        }

        ERC20Repo._mint(recipient, sharesForDeposit);
    }

    function _getCurrentUsageFee() internal view returns (uint256 fee_) {
        // The marker interface ID declared in the DFPkg allows the fee oracle
        // to override usage fee per-type (0 in production for this wrapper).
        fee_ = VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this));
    }

    /* ------------------------------------------------------------------ */
    /*                     ERC4626 Share Math Helpers                     */
    /* ------------------------------------------------------------------ */

    /**
     * @dev Converts a delta in StataToken (the reserve asset) into the number
     *      of SE Vault shares it justifies, using pre-delta totalAssets / totalSupply.
     *      This is the `sharesForDeposit` before any usage fee inflation.
     */
    function _convertStataDeltaToShares(uint256 deltaStata, uint256 totalAssetsBefore)
        internal
        view
        returns (uint256 shares)
    {
        uint256 totalSupply_ = ERC20Repo._totalSupply();
        if (totalSupply_ == 0 || totalAssetsBefore == 0) {
            return deltaStata; // 1:1 on first deposit
        }
        // Simple proportional (in practice use the project's ERC4626 rounding logic)
        shares = (deltaStata * totalSupply_) / totalAssetsBefore;
    }

    /**
     * @dev Converts SE Vault shares back to equivalent StataToken amount (for exits).
     */
    function _convertSharesToStata(uint256 shares) internal view returns (uint256 stataAmount) {
        address stata = IAaveV3StataStandardVault(address(this)).stataToken();
        uint256 totalAssets_ = IERC20(stata).balanceOf(address(this)); // the ERC4626 totalAssets is the stata held
        uint256 totalSupply_ = ERC20Repo._totalSupply();
        if (totalSupply_ == 0) return 0;
        stataAmount = (shares * totalAssets_) / totalSupply_;
    }

    /* ------------------------------------------------------------------ */
    /*                     Reward Collection & Forward                    */
    /* ------------------------------------------------------------------ */

    /**
     * @dev On every operation:
     * 1. Pulls latest rewards into the Stata contract for our position.
     * 2. Claims those rewards from the Stata contract and sends them to feeTo().
     *
     * This is the temporary behavior (raw reward tokens go to feeTo).
     */
    function _collectAndForwardRewards() internal {
        address stata = IAaveV3StataStandardVault(address(this)).stataToken();
        IERC20AaveLM lm = IERC20AaveLM(stata);

        // Refresh known rewards (safe)
        try lm.refreshRewardTokens() {} catch {}

        address[] memory rewards = lm.rewardTokens();
        if (rewards.length == 0) return;

        address feeRecipient = address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo());
        if (feeRecipient == address(0)) return;

        // 1. Collect fresh rewards into the stata contract (for our holding)
        for (uint256 i = 0; i < rewards.length; i++) {
            try lm.collectAndUpdateRewards(rewards[i]) {} catch {}
        }

        // 2. Claim the rewards that accrued to *this contract's* stata balance
        //    and forward them directly to the fee recipient.
        try lm.claimRewards(feeRecipient, rewards) {} catch {}
    }
}
