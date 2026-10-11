// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IWrappedStandardExchangeRateProvider} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/IWrappedStandardExchangeRateProvider.sol";

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



contract WrappedStandardExchangeRateProviderTarget is IWrappedStandardExchangeRateProvider {
	using BetterMath for uint256;

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
        WrappedStandardExchangeRateProviderRepo.Storage storage l =
            WrappedStandardExchangeRateProviderRepo._layoutStruct();
        IERC4626 subject = l.rateSubject;
        uint256 supply = subject.totalSupply();
        if (supply == 0) return 0;
        uint8 subjectDecimals = IERC20Metadata(address(subject)).decimals();
        // Convert all outstanding wrapper shares once, then value that exact
        // underlying claim in the requested live or projected SE state.
        uint256 reserveShares = subject.previewRedeem(supply);
        if (reserveShares == 0) return 0;
        (bool success, uint256 out) = _safePreviewExchangeIn(reserveShares, state);
        if (!success || out == 0) return 0;
        uint256 numeratorDecimals = 18 + uint256(subjectDecimals);
        if (numeratorDecimals >= l.rateTargetDecimals) {
            return Math.mulDiv(out, 10 ** (numeratorDecimals - l.rateTargetDecimals), supply, Math.Rounding.Ceil);
        }
        return Math.ceilDiv(Math.ceilDiv(out, supply), 10 ** (l.rateTargetDecimals - numeratorDecimals));
    }

    function _safePreviewExchangeIn(uint256 reserveShareAmount_, bytes memory state)
        private view returns (bool success_, uint256 out_)
    {
        WrappedStandardExchangeRateProviderRepo.Storage storage l = WrappedStandardExchangeRateProviderRepo._layoutStruct();
        IStandardExchangeIn standardExchange_ = l.standardExchange;
        IERC20 reserveVaultToken_ = l.reserveVaultToken;
        IERC20 rateTarget_ = l.rateTarget;
        bytes memory input = state.length != 0
            ? abi.encodeCall(IStandardExchangeTransitionQuote.quoteAssets, (state, reserveShareAmount_))
            : abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (reserveVaultToken_, reserveShareAmount_, rateTarget_));
        (bool ok, bytes memory data) = address(standardExchange_).staticcall(input);
        if (!ok || data.length != 32) return (false, 0);
        return (true, abi.decode(data, (uint256)));
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