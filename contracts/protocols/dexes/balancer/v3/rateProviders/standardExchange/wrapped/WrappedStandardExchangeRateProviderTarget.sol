// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
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

	function getRate() public view returns (uint256) {
		WrappedStandardExchangeRateProviderRepo.Storage storage layoutStruct = WrappedStandardExchangeRateProviderRepo
			._layoutStruct();

		IERC4626 subject_ = layoutStruct.rateSubject;
		uint256 totalShares = subject_.totalSupply();
		if (totalShares == 0) {
			return 0;
		}

		// 1e18 wrapper shares can redeem to dust after nested virtual offsets, and the
		// inner SE quote then floors to 0. Start at min(1e18, supply) and scale up.
		uint256 quoteShares = totalShares < ONE_WAD ? totalShares : ONE_WAD;
		uint256 reserveShareAmount = subject_.previewRedeem(quoteShares);
		(bool success, uint256 quotedOut) = reserveShareAmount == 0
			? (false, uint256(0))
			: _safePreviewExchangeIn(
				layoutStruct.standardExchange, layoutStruct.reserveVaultToken, reserveShareAmount, layoutStruct.rateTarget
			);

		for (uint256 i = 0; (!success || quotedOut == 0) && quoteShares < totalShares && i < 18; ++i) {
			uint256 nextQuote = quoteShares * 10;
			if (nextQuote > totalShares) {
				nextQuote = totalShares;
			}
			if (nextQuote == quoteShares) {
				break;
			}
			uint256 nextRedeem = subject_.previewRedeem(nextQuote);
			if (nextRedeem == 0) {
				quoteShares = nextQuote;
				continue;
			}
			(bool nextSuccess, uint256 nextOut) = _safePreviewExchangeIn(
				layoutStruct.standardExchange, layoutStruct.reserveVaultToken, nextRedeem, layoutStruct.rateTarget
			);
			quoteShares = nextQuote;
			reserveShareAmount = nextRedeem;
			success = nextSuccess;
			quotedOut = nextOut;
		}

		if (!success || quotedOut == 0 || quoteShares == 0) {
			return 0;
		}

		if (quoteShares != ONE_WAD) {
			quotedOut = quotedOut._mulDiv(ONE_WAD, quoteShares, Math.Rounding.Ceil);
		}

		uint8 targetDecimals = layoutStruct.rateTargetDecimals;
		if (targetDecimals == 18) {
			return quotedOut;
		}

		if (targetDecimals < 18) {
			return quotedOut * (10 ** (18 - targetDecimals));
		}

		return quotedOut / (10 ** (targetDecimals - 18));
	}

	function _safePreviewExchangeIn(
		IStandardExchangeIn standardExchange_,
		IERC20 reserveVaultToken_,
		uint256 reserveShareAmount_,
		IERC20 rateTarget_
	) internal view returns (bool success_, uint256 out_) {
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