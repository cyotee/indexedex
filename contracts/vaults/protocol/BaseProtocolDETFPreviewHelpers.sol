// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

/**
 * @title BaseProtocolDETFPreviewHelpers
 * @notice Library providing preview simulation helpers for Protocol DETF.
 * @dev Separated into its own compilation unit to avoid "stack too deep" errors
 *      when used from the larger ProtocolDETFCommon contract.
 */
library BaseProtocolDETFPreviewHelpers {
    struct RichirCalc {
        address balV3Vault;
        address reservePool;
        uint256 reservePoolSwapFee;
        uint256[] weightsArray;
        address chirWethVault;
        address richChirVault;
        // The Protocol DETF (CHIR) token address. In the diamond, this is `address(this)`.
        address chirToken;
        address wethToken;
        uint256[] poolBalsRaw;
        uint256 chirIdx;
        uint256 richIdx;
        uint256 vaultIdx;
        uint256 sharesAdded;
        uint256 poolSupply;
        uint256 bptAdded;
        uint256 newPosShares;
        uint256 newTotShares;
    }

    /* ---------------------------------------------------------------------- */
    /*                            Internal Helpers                             */
    /* ---------------------------------------------------------------------- */

    function _previewChirWethVaultSharesToWeth(RichirCalc memory calc_, uint256 chirWethVaultShares_)
        private
        view
        returns (uint256 wethOut_)
    {
        if (chirWethVaultShares_ == 0) return 0;

        // Delegate to the underlying vault's own preview implementation to
        // preserve any pool-specific rounding/fees logic.
        wethOut_ = IStandardExchange(calc_.chirWethVault).previewExchangeIn(
            IERC20(calc_.chirWethVault), chirWethVaultShares_, IERC20(calc_.wethToken)
        );
    }

    function _previewRichChirVaultSharesToWeth(RichirCalc memory calc_, uint256 richChirVaultShares_)
        private
        view
        returns (uint256 wethOut_)
    {
        if (richChirVaultShares_ == 0) return 0;

        uint256 chirOut = IStandardExchange(calc_.richChirVault).previewExchangeIn(
            IERC20(calc_.richChirVault), richChirVaultShares_, IERC20(calc_.chirToken)
        );
        if (chirOut == 0) return 0;

        wethOut_ = IStandardExchange(calc_.chirWethVault).previewExchangeIn(
            IERC20(calc_.chirToken), chirOut, IERC20(calc_.wethToken)
        );
    }

    /**
     * @notice Preview the WETH value of the protocol NFT after simulating a deposit.
     * @dev Mirrors `ProtocolDETFExchangeInQueryTarget.previewExchangeIn(BPT, amount, WETH)` semantics:
     *      - Value is defined by a proportional exit from BPT into both vault share tokens,
     *        then unwinding those vault shares into WETH.
     */
    function _previewWethValueAfterDeposit(RichirCalc memory calc_) private view returns (uint256 wethOut_) {
        if (calc_.newPosShares == 0) return 0;

        (uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) = _previewReservePoolExitProportional(calc_);

        uint256 wethFromChirWeth = _previewChirWethVaultSharesToWeth(calc_, chirWethVaultSharesOut);
        uint256 wethFromRichChir = _previewRichChirVaultSharesToWeth(calc_, richChirVaultSharesOut);

        wethOut_ = wethFromChirWeth + wethFromRichChir;
    }

    function _previewReservePoolExitProportional(RichirCalc memory calc_)
        private
        pure
        returns (uint256 chirWethVaultSharesOut_, uint256 richChirVaultSharesOut_)
    {
        uint256 simTotalSupply = calc_.poolSupply + calc_.bptAdded;
        if (simTotalSupply == 0) return (0, 0);

        // RICHIRTarget values the Protocol NFT's BPT using ProtocolDETF's own
        // `previewExchangeIn(BPT -> WETH)` implementation, which (by design) uses
        // raw balances for proportional exits.
        //
        // Mirror that raw, linear accounting here for the simulated post-deposit state.
        uint256 chirIdx = calc_.chirIdx;
        uint256 richIdx = calc_.richIdx;
        uint256 simChirRaw = calc_.poolBalsRaw[chirIdx];
        uint256 simRichRaw = calc_.poolBalsRaw[richIdx];

        if (calc_.vaultIdx == chirIdx) simChirRaw += calc_.sharesAdded;
        if (calc_.vaultIdx == richIdx) simRichRaw += calc_.sharesAdded;

        chirWethVaultSharesOut_ = (simChirRaw * calc_.newPosShares) / simTotalSupply;
        richChirVaultSharesOut_ = (simRichRaw * calc_.newPosShares) / simTotalSupply;
    }

    /**
     * @notice Compute the final RICHIR output amount from an unbalanced deposit simulation.
     * @dev Consolidates exit shares computation + WETH unwind + rate calculation into one call.
     *      This reduces stack pressure in callers by offloading all intermediate calculations.
     * @param calc_ All computation parameters grouped into a struct
     * @return richirOut_ Amount of RICHIR tokens that would be minted
     */
    function computeRichirOutFromDeposit(RichirCalc memory calc_) internal view returns (uint256 richirOut_) {
        // Execution mints shares 1:1 with BPT added, and the returned token amount
        // is derived from the post-mint redemption rate.
        // richirOut = (bptAdded * newWethValue) / newTotalShares
        // (see RICHIRTarget.mintFromNFTSale + _calcCurrentRedemptionRate)
        if (calc_.newTotShares == 0) return 0;

        uint256 newWethValue = _previewWethValueAfterDeposit(calc_);
        if (newWethValue == 0) return 0;

        richirOut_ = (calc_.bptAdded * newWethValue) / calc_.newTotShares;
    }
}
