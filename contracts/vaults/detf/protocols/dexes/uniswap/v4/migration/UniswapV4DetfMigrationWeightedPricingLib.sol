// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from "./interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";
import {IStandardExchangeFrozenQuoteInputs as Frozen} from "contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol";
import {UniswapV4StandardExchangeWeightedBufferHookClaimLib as Claim} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHookMath as Weighted} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";
import {StandardExchangeFrozenQuoteLib as Quote} from "contracts/utils/StandardExchangeFrozenQuoteLib.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {DETFMintSplitLib} from "contracts/vaults/detf/common/core/DETFMintSplitLib.sol";

/// @notice Structural validation and pure original-credit evaluation of manual operands.
/// @dev No source acquisition, authentication or live provider call belongs in this library.
library UniswapV4DetfMigrationWeightedPricingLib {
    function validate(Pricing.Book memory book_) public pure {
        validate(normalize(book_));
    }

    /// @notice Adapt legacy operands without changing their economic meaning, version or book identity.
    function normalize(Pricing.Book memory book_) public pure returns (Pricing.BookV3 memory normalized_) {
        Pricing.Inputs memory legacy_ = book_.inputs;
        Pricing.InputsV3 memory inputs_;
        inputs_.swapFeeWad = legacy_.swapFeeWad;
        inputs_.seigniorage = legacy_.seigniorage;
        inputs_.ethIndex = legacy_.ethIndex;
        inputs_.dtfIndex = legacy_.dtfIndex;
        inputs_.detfIndex = legacy_.detfIndex;
        inputs_.legs = new Pricing.LegV3[](legacy_.legs.length);
        Frozen.Inputs memory empty_;
        bytes32 emptyHash_ = keccak256(abi.encode(empty_));
        for (uint256 i_; i_ < legacy_.legs.length; ++i_) {
            Pricing.Leg memory leg_ = legacy_.legs[i_];
            Frozen.VersionedInputs memory deposit_;
            if (keccak256(abi.encode(leg_.deposit)) != emptyHash_) {
                deposit_ = Frozen.VersionedInputs(1, abi.encode(leg_.deposit));
            }
            inputs_.legs[i_] = Pricing.LegV3(
                leg_.token, leg_.standardExchange, leg_.mode, leg_.rawReserve, leg_.seReserve,
                leg_.weight, leg_.invScale, leg_.ratedScale, leg_.rate, deposit_
            );
        }
        normalized_ = Pricing.BookV3(
            book_.version, book_.chainId, book_.consumer, book_.weth, book_.originalDtf, book_.id, inputs_
        );
    }

    function validate(Pricing.BookV3 memory book_) public pure {
        if (book_.version != 2 && book_.version != 3) revert Pricing.MigrationWeightedPricingInvalid();
        Pricing.InputsV3 memory inputs_ = book_.inputs;
        uint256 n_ = inputs_.legs.length;
        if (n_ < 3 || n_ > 8 || inputs_.ethIndex >= n_ || inputs_.dtfIndex >= n_ || inputs_.detfIndex >= n_
            || inputs_.ethIndex == inputs_.dtfIndex || inputs_.ethIndex == inputs_.detfIndex
            || inputs_.dtfIndex == inputs_.detfIndex || inputs_.swapFeeWad >= 1e18 || inputs_.seigniorage > 1e18) {
            revert Pricing.MigrationWeightedPricingInvalid();
        }
        if (inputs_.legs[inputs_.ethIndex].token != book_.weth
            || inputs_.legs[inputs_.dtfIndex].token != book_.originalDtf
            || inputs_.legs[inputs_.detfIndex].token != book_.consumer
            || inputs_.legs[inputs_.ethIndex].ratedScale != 1e18
            || inputs_.legs[inputs_.dtfIndex].ratedScale != 1e18
            || inputs_.legs[inputs_.detfIndex].ratedScale != 1e27
            || uint256(inputs_.legs[inputs_.detfIndex].mode) > uint256(Pricing.LegMode.RawRate)) {
            revert Pricing.MigrationWeightedPricingInvalid();
        }
        uint256 sum_;
        for (uint256 i_; i_ < n_; ++i_) {
            Pricing.LegV3 memory leg_ = inputs_.legs[i_];
            if (leg_.token == address(0) || leg_.weight < 1e16 || leg_.weight > 1e18
                || !_scale(leg_.invScale) || !_scale(leg_.ratedScale)) revert Pricing.MigrationWeightedPricingInvalid();
            for (uint256 j_; j_ < i_; ++j_) {
                if (inputs_.legs[j_].token == leg_.token) revert Pricing.MigrationWeightedPricingInvalid();
            }
            sum_ += leg_.weight;
            if (leg_.mode == Pricing.LegMode.Raw || leg_.mode == Pricing.LegMode.RawRate) {
                if (leg_.standardExchange != address(0) || leg_.seReserve != 0 || leg_.invScale != leg_.ratedScale
                    || (leg_.mode == Pricing.LegMode.Raw ? leg_.rate != 0 : leg_.rate == 0)) {
                    revert Pricing.MigrationWeightedPricingInvalid();
                }
            } else {
                if (leg_.standardExchange == address(0) || leg_.standardExchange == leg_.token) {
                    revert Pricing.MigrationWeightedPricingInvalid();
                }
                if (leg_.mode == Pricing.LegMode.DisabledBuffer
                    && (leg_.seReserve == 0 ? leg_.rate != 0 : leg_.rate == 0)) {
                    revert Pricing.MigrationWeightedPricingInvalid();
                }
            }
            if (leg_.mode == Pricing.LegMode.EnabledV3Buffer) {
                if (leg_.rate == 0 || leg_.deposit.version != (book_.version == 2 ? 1 : 2)) {
                    revert Pricing.MigrationWeightedPricingInvalid();
                }
                Quote.requireSupported(leg_.deposit);
                if (book_.version == 2) {
                    Frozen.Inputs memory q_ = abi.decode(leg_.deposit.data, (Frozen.Inputs));
                    if (q_.exchange != leg_.standardExchange || q_.request.tokenIn != leg_.token
                        || q_.request.holder != address(0) || q_.token0 == address(0) || q_.token1 == address(0)
                        || q_.token0 == q_.token1) revert Pricing.MigrationWeightedPricingInvalid();
                } else {
                    Frozen.SwapDepositV2 memory q_ = abi.decode(leg_.deposit.data, (Frozen.SwapDepositV2));
                    if (q_.exchange != leg_.standardExchange || q_.request.tokenIn != leg_.token) {
                        revert Pricing.MigrationWeightedPricingInvalid();
                    }
                }
            } else {
                if (leg_.deposit.version != 0 || leg_.deposit.data.length != 0) {
                    revert Pricing.MigrationWeightedPricingInvalid();
                }
            }
            if ((leg_.mode == Pricing.LegMode.RawRate || leg_.mode == Pricing.LegMode.EnabledV3Buffer
                || leg_.seReserve != 0) && leg_.invScale > leg_.ratedScale
                && leg_.invScale / leg_.ratedScale > 1e18) revert Pricing.MigrationWeightedPricingInvalid();
        }
        if (sum_ != 1e18) revert Pricing.MigrationWeightedPricingInvalid();
        uint256[] memory balances_ = _rated(inputs_);
        if (balances_[inputs_.ethIndex] == 0 || balances_[inputs_.dtfIndex] == 0
            || balances_[inputs_.detfIndex] == 0) revert Pricing.MigrationWeightedPricingInvalid();
    }

    function _scale(uint256 scale_) private pure returns (bool) {
        if (scale_ == 0 || scale_ > 1e30) return false;
        while (scale_ > 1 && scale_ % 10 == 0) scale_ /= 10;
        return scale_ == 1;
    }

    function _rated(Pricing.InputsV3 memory inputs_) private pure returns (uint256[] memory balances_) {
        balances_ = new uint256[](inputs_.legs.length);
        for (uint256 i_; i_ < balances_.length; ++i_) {
            Pricing.LegV3 memory leg_ = inputs_.legs[i_];
            uint256 units_ = leg_.rawReserve;
            if (leg_.mode == Pricing.LegMode.RawRate) {
                units_ = Weighted.ratedPairUnits(units_, leg_.rate, leg_.invScale, leg_.ratedScale);
            } else if (leg_.seReserve != 0) {
                units_ += Weighted.ratedPairUnits(leg_.seReserve, leg_.rate, leg_.invScale, leg_.ratedScale);
            }
            balances_[i_] = Weighted.scaleTo(units_, leg_.ratedScale);
        }
    }

    function evaluateOriginal(Pricing.Book memory book_, address contribution_, uint256 amount_)
        public pure returns (Pricing.Result memory r_)
    {
        return evaluateOriginal(normalize(book_), contribution_, amount_);
    }

    function evaluateOriginal(Pricing.BookV3 memory book_, address contribution_, uint256 amount_)
        public pure returns (Pricing.Result memory r_)
    {
        if (book_.id == bytes32(0)) revert Pricing.MigrationWeightedPricingNotSet();
        Pricing.InputsV3 memory inputs_ = book_.inputs;
        uint256 i_ = contribution_ == address(0) ? inputs_.ethIndex : inputs_.dtfIndex;
        if (contribution_ != address(0) && contribution_ != book_.originalDtf) {
            revert Pricing.MigrationWeightedPricingInvalid();
        }
        if (amount_ == 0) return r_;
        r_.pairEquivalent = amount_;
        r_.boosted = Math.mulDiv(amount_, 1e18 + inputs_.seigniorage, 1e18);
        if (r_.boosted == 0) revert Claim.ZeroAmount();
        uint256[] memory balances_ = _rated(inputs_);
        r_.net = Weighted.applyTradingFeeNet(r_.boosted, inputs_.swapFeeWad);
        Pricing.LegV3 memory input_ = inputs_.legs[i_];
        uint256 units_;
        if (input_.mode == Pricing.LegMode.RawRate) {
            units_ = Math.mulDiv(r_.net, input_.rate, 1e18);
        } else if (input_.mode == Pricing.LegMode.EnabledV3Buffer) {
            ExchangeInAmount.Result memory deposit_ = Quote.evaluate(input_.deposit, r_.net);
            ExchangeInAmount.consumedInput(r_.net, deposit_.amountRefunded);
            units_ = deposit_.amountRefunded;
            if (deposit_.amountOut != 0) units_ += Weighted.ratedPairUnits(
                deposit_.amountOut, input_.rate, input_.invScale, input_.ratedScale
            );
        } else {
            units_ = r_.net;
        }
        r_.ratedInflow = Weighted.scaleTo(units_, input_.ratedScale);
        Pricing.LegV3 memory output_ = inputs_.legs[inputs_.detfIndex];
        uint256 budget_ = Claim.exactInputBudget(
            balances_[i_], input_.weight, balances_[inputs_.detfIndex], output_.weight, r_.ratedInflow
        );
        r_.gross = Claim.rawOutput(budget_, output_.ratedScale, output_.rawReserve);
        (r_.user,) = DETFMintSplitLib._splitLiveGross(r_.gross, inputs_.seigniorage);
    }

    function evaluateOriginals(Pricing.Book memory book_, uint256 originalEth_, uint256 originalDtf_)
        public pure returns (uint256)
    {
        return evaluateOriginals(normalize(book_), originalEth_, originalDtf_);
    }

    function evaluateOriginals(Pricing.BookV3 memory book_, uint256 originalEth_, uint256 originalDtf_)
        public pure returns (uint256)
    {
        return evaluateOriginal(book_, address(0), originalEth_).user
            + evaluateOriginal(book_, book_.originalDtf, originalDtf_).user;
    }
}
