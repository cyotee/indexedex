// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IStandardExchangeTransitionQuote, IStandardExchangeRateQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
	WrappedStandardExchangeRateProviderRepo
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderRepo.sol";

interface IWrappedStandardExchangeRateProvider is IRateProvider {
	function rateSubject() external view returns (IERC4626);
	function standardExchange() external view returns (IStandardExchangeIn);
	function rateTarget() external view returns (IERC20);
}

contract WrappedStandardExchangeRateProviderTarget is IWrappedStandardExchangeRateProvider {
	using BetterMath for uint256;

    struct RateQuote {
        uint256 totalShares;
        uint256 subjectUnit;
        uint256 quoteShares;
        uint256 quotedOut;
        bool success;
    }


	function getRate() public view returns (uint256) {
        return _getRate("");
    }

    function quoteRate(address exchange, address asset, bytes calldata state) external view returns (uint256) {
        WrappedStandardExchangeRateProviderRepo.Storage storage l = WrappedStandardExchangeRateProviderRepo._layoutStruct();
        if (exchange != address(l.standardExchange) || asset != address(l.rateTarget)
            || address(l.reserveVaultToken) != exchange) return _getRate("");
        return _getRate(state);
    }

    function _getRate(bytes memory state) private view returns (uint256) {
        RateQuote memory q;
		WrappedStandardExchangeRateProviderRepo.Storage storage layoutStruct = WrappedStandardExchangeRateProviderRepo
			._layoutStruct();

		IERC4626 subject_ = layoutStruct.rateSubject;
		q.totalShares = subject_.totalSupply();
		if (q.totalShares == 0) {
			return 0;
		}

		// Start with one whole subject token in its own native decimals.
		q.subjectUnit = 10 ** IERC20Metadata(address(subject_)).decimals();
		q.quoteShares = q.totalShares < q.subjectUnit ? q.totalShares : q.subjectUnit;
		uint256 reserveShareAmount = subject_.previewRedeem(q.quoteShares);
		(q.success, q.quotedOut) = reserveShareAmount == 0
			? (false, uint256(0))
			: _safePreviewExchangeIn(
				reserveShareAmount, state
			);

		for (uint256 i = 0; (!q.success || q.quotedOut == 0) && q.quoteShares < q.totalShares && i < 18; ++i) {
			uint256 nextQuote = q.quoteShares > q.totalShares / 10 ? q.totalShares : q.quoteShares * 10;
			if (nextQuote > q.totalShares) {
				nextQuote = q.totalShares;
			}
			if (nextQuote == q.quoteShares) {
				break;
			}
			uint256 nextRedeem = subject_.previewRedeem(nextQuote);
			if (nextRedeem == 0) {
				q.quoteShares = nextQuote;
				continue;
			}
			(bool nextSuccess, uint256 nextOut) = _safePreviewExchangeIn(
				nextRedeem, state
			);
			q.quoteShares = nextQuote;
			q.success = nextSuccess;
			q.quotedOut = nextOut;
		}

		if (!q.success || q.quotedOut == 0 || q.quoteShares == 0) {
			return 0;
		}

		if (q.quoteShares != q.subjectUnit) {
			q.quotedOut = q.quotedOut._mulDiv(q.subjectUnit, q.quoteShares, Math.Rounding.Ceil);
		}

		uint8 targetDecimals = layoutStruct.rateTargetDecimals;
		if (targetDecimals == 18) {
			return q.quotedOut;
		}

		if (targetDecimals < 18) {
			return q.quotedOut * (10 ** (18 - targetDecimals));
		}

		return q.quotedOut / (10 ** (targetDecimals - 18));
	}

    function _safePreviewExchangeIn(uint256 reserveShareAmount_, bytes memory state)
        private view returns (bool success_, uint256 out_)
    {
        WrappedStandardExchangeRateProviderRepo.Storage storage l = WrappedStandardExchangeRateProviderRepo._layoutStruct();
        IStandardExchangeIn standardExchange_ = l.standardExchange;
        IERC20 reserveVaultToken_ = l.reserveVaultToken;
        IERC20 rateTarget_ = l.rateTarget;
        if (state.length != 0) {
            try IStandardExchangeTransitionQuote(address(standardExchange_)).quoteAssets(state, reserveShareAmount_)
                returns (uint256 quotedOut) { return (true, quotedOut); }
            catch { return (false, 0); }
        }
		try standardExchange_.previewExchangeIn(reserveVaultToken_, reserveShareAmount_, rateTarget_) returns (
			uint256 quotedOut
		) {
			return (true, quotedOut);
		} catch {
			return (false, 0);
		}
	}

	function rateSubject() public view returns (IERC4626) {
		return WrappedStandardExchangeRateProviderRepo._rateSubject();
	}

	function standardExchange() public view returns (IStandardExchangeIn) {
		return WrappedStandardExchangeRateProviderRepo._standardExchange();
	}

	function rateTarget() public view returns (IERC20) {
		return WrappedStandardExchangeRateProviderRepo._rateTarget();
	}

}