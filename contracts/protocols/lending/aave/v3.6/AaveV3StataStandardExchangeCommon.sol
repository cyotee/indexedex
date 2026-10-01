// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {Math} from "@crane/contracts/utils/Math.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {BasicVaultCommon} from "contracts/vaults/basic/BasicVaultCommon.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAaveV3StataStandardVault} from "contracts/interfaces/IAaveV3StataStandardVault.sol";
import {IERC20AaveLM} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IERC20AaveLM.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStataTokenV2} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IStataTokenV2.sol";
import {
    ReceiptBackedERC4626AccountingLib
} from "contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol";

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

    /// @notice A receipt-denominated payout exceeded the Stata receipts actually held (R14.15).
    error InsufficientReceiptInventory(uint256 required, uint256 held);

    /* ------------------------------------------------------------------ */
    /*                 Local-plus-receipt backing (D22/D45/R14)            */
    /* ------------------------------------------------------------------ */

    /// @dev Same Stata backing as the shared adapter: held receipts plus one conversion of
    ///      booked underlying and booked expected-hold extras (aToken when registered).
    function _stataBacking() internal view returns (uint256) {
        IStataTokenV2 stata_ = IStataTokenV2(IAaveV3StataStandardVault(address(this)).stataToken());
        return ReceiptBackedERC4626AccountingLib.backingReceiptUnits(IERC4626(address(stata_)), address(this), true);
    }

    /// @dev Active D16 availability. Base checked subtraction remains the historical default.
    function _unbookedSurplus(IERC20 token) internal view override returns (uint256) {
        return LocalCreditLib.available(token.balanceOf(address(this)), _bookedReserve(token));
    }

    /// @dev D22/D31: precheck `maxDeposit`, sweep previously booked underlying first, re-read the
    ///      capacity, then invest this caller's credited input up to the remaining capacity. Any
    ///      uninvested input stays booked as local reserve at the end-of-route sync. Prechecks
    ///      only; a `deposit` that still reverts propagates unchanged (D30/D34).
    function _investUnderlyingIntoStata(IStataTokenV2 stata_, IERC20 underlying_, uint256 actualIn_)
        internal
        returns (uint256 deposited_)
    {
        uint256 capacity_ = stata_.maxDeposit(address(this));
        uint256 booked_ = _bookedReserve(underlying_);
        uint256 sweep_ = booked_ < capacity_ ? booked_ : capacity_;
        if (sweep_ > 0) {
            underlying_.forceApprove(address(stata_), sweep_);
            stata_.deposit(sweep_, address(this));
            underlying_.forceApprove(address(stata_), 0);
            capacity_ = stata_.maxDeposit(address(this));
        }
        deposited_ = actualIn_ < capacity_ ? actualIn_ : capacity_;
        if (deposited_ > 0) {
            underlying_.forceApprove(address(stata_), deposited_);
            stata_.deposit(deposited_, address(this));
            underlying_.forceApprove(address(stata_), 0);
        }
    }

    /// @dev R14.15: underlying payouts spend booked local cash first and withdraw only the
    ///      shortfall from the Stata receipts.
    function _payUnderlying(IStataTokenV2 stata_, uint256 due_, address to_) internal returns (uint256) {
        IERC20 underlying_ = IERC20(stata_.asset());
        uint256 local_ = _bookedReserve(underlying_);
        uint256 bal_ = underlying_.balanceOf(address(this));
        if (local_ > bal_) local_ = bal_;
        uint256 fromLocal_ = due_ < local_ ? due_ : local_;
        uint256 shortfall_ = due_ - fromLocal_;
        if (shortfall_ > 0) stata_.withdraw(shortfall_, to_, address(this));
        if (fromLocal_ > 0) underlying_.safeTransfer(to_, fromLocal_);
        return due_;
    }

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
            uint256 feeShares = Math.mulDiv(sharesForDeposit, usageFee, FEE_DENOMINATOR);

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
        shares = Math.mulDiv(deltaStata, totalSupply_, totalAssetsBefore);
    }

    /**
     * @dev Converts SE Vault shares back to equivalent StataToken amount (for exits).
     */
    function _convertSharesToStata(uint256 shares) internal view returns (uint256 stataAmount) {
        uint256 totalAssets_ = _stataBacking(); // held Stata plus booked local underlying (R14.14)
        uint256 totalSupply_ = ERC20Repo._totalSupply();
        if (totalSupply_ == 0) return 0;
        stataAmount = Math.mulDiv(shares, totalAssets_, totalSupply_);
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

        lm.refreshRewardTokens();

        address[] memory rewards = lm.rewardTokens();
        if (rewards.length == 0) return;

        address feeRecipient = address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo());
        if (feeRecipient == address(0)) return;

        for (uint256 i = 0; i < rewards.length; i++) {
            lm.collectAndUpdateRewards(rewards[i]);
        }
        lm.claimRewards(feeRecipient, rewards);
    }

    function _secureTokenTransfer(IERC20 tokenIn, uint256 amountTokenToDeposit, bool pretransferred)
        internal
        virtual
        override
        returns (uint256 actualIn)
    {
        if (pretransferred) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            uint256 avail = LocalCreditLib.available(
                tokenIn.balanceOf(address(this)), _bookedReserve(tokenIn)
            );
            if (amountTokenToDeposit > avail) {
                revert ISecurePullErrors.TransferDeltaInsufficient(amountTokenToDeposit, avail);
            }
            return amountTokenToDeposit;
        }
        uint256 B0 = tokenIn.balanceOf(address(this));
        if (tokenIn.allowance(msg.sender, address(this)) < amountTokenToDeposit) {
            Permit2AwareRepo._permit2()
                .transferFrom(msg.sender, address(this), uint160(amountTokenToDeposit), address(tokenIn));
        } else {
            tokenIn.safeTransferFrom(msg.sender, address(this), amountTokenToDeposit);
        }
        uint256 delta = tokenIn.balanceOf(address(this)) - B0;
        if (delta != amountTokenToDeposit) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amountTokenToDeposit, delta);
        }
        return amountTokenToDeposit;
    }

    function _secureSelfBurn(address owner, uint256 burnAmount, bool preTransferred)
        internal
        virtual
        override
    {
        if (preTransferred) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            // D23/R7.3: no self-share book exists here; short self-shares revert with the shared error.
            uint256 selfBal = IERC20(address(this)).balanceOf(address(this));
            if (burnAmount > selfBal) revert ISecurePullErrors.TransferDeltaInsufficient(burnAmount, selfBal);
        }
        super._secureSelfBurn(owner, burnAmount, preTransferred);
    }
}
