// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {
	WrappedStandardExchangeRateProviderRepo
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderRepo.sol";

interface IWrappedStandardExchangeRateProvider is IRateProvider {
	function rateSubject() external view returns (IERC4626);
	function standardExchange() external view returns (IStandardExchangeIn);
	function rateTarget() external view returns (IERC20);
}

contract WrappedStandardExchangeRateProviderTarget is IWrappedStandardExchangeRateProvider {
	function getRate() public view returns (uint256) {
		WrappedStandardExchangeRateProviderRepo.Storage storage layoutStruct = WrappedStandardExchangeRateProviderRepo
			._layoutStruct();

		uint256 reserveShareAmount = layoutStruct.rateSubject.previewRedeem(ONE_WAD);
		if (reserveShareAmount == 0) {
			return 0;
		}

		(bool success, uint256 quotedOut) =
			_safePreviewExchangeIn(layoutStruct.standardExchange, layoutStruct.reserveVaultToken, reserveShareAmount, layoutStruct.rateTarget);
		if (!success || quotedOut == 0) {
			return 0;
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