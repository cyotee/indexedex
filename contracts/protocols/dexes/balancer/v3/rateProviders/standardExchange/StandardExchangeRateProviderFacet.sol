// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeTransitionQuote, IStandardExchangeRateQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {
    StandardExchangeRateProviderRepo
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderRepo.sol";

interface IStandardExchangeRateProvider is IRateProvider {
    function reserveVault() external view returns (IStandardExchange);
    function rateTarget() external view returns (IERC20);
}

contract StandardExchangeRateProviderFacet is IStandardExchangeRateProvider, IFacet {
    using BetterSafeERC20 for IERC20Metadata;
    using BetterMath for uint256;

    /* ---------------------------------------------------------------------- */
    /*                              IRateProvider                             */
    /* ---------------------------------------------------------------------- */

    function getRate() external view returns (uint256) {
        return _getRate("");
    }

    function quoteRate(address exchange, address asset, bytes calldata state) external view returns (uint256) {
        StandardExchangeRateProviderRepo.Storage storage l = StandardExchangeRateProviderRepo._layout();
        address subject = address(l.rateSubject);
        if (subject == address(0)) subject = address(l.reserveVault);
        // An independent subject keeps its live rate. The projected state belongs
        // only to the supplied SE and is denominated in its selected quote asset.
        if (exchange != address(l.reserveVault) || asset != address(l.rateTarget) || subject != exchange) {
            return _getRate("");
        }
        return _getRate(state);
    }

    function _getRate(bytes memory state) private view returns (uint256) {
        StandardExchangeRateProviderRepo.Storage storage layoutStruct = StandardExchangeRateProviderRepo._layout();
        IERC20 subject_ = layoutStruct.rateSubject;
        if (address(subject_) == address(0)) {
            subject_ = IERC20(address(layoutStruct.reserveVault));
        }
        uint256 totalShares = state.length == 0 ? subject_.totalSupply()
            : IStandardExchangeTransitionQuote(address(layoutStruct.reserveVault)).quoteTotalSupply(state);

        if (totalShares == 0) {
            return 0;
        }

        // Quote one whole subject token, capped by actual supply. DETF and sDETF
        // use nine decimals; treating 1e18 raw units as one token misprices them.
        uint256 subjectUnit = 10 ** IERC20Metadata(address(subject_)).decimals();
        uint256 quoteAmount = totalShares < subjectUnit ? totalShares : subjectUnit;
        (bool success, uint256 out) =
            _safePreviewExchangeIn(quoteAmount, state);

        for (uint256 i = 0; !success && quoteAmount > 1 && i < 18; ++i) {
            quoteAmount /= 2;
            (success, out) =
                _safePreviewExchangeIn(quoteAmount, state);
        }

        if (!success || quoteAmount == 0) {
            return 0;
        }

        for (uint256 i = 0; out == 0 && quoteAmount < totalShares && i < 18; ++i) {
            uint256 nextQuote = quoteAmount * 10;
            if (nextQuote > totalShares) {
                nextQuote = totalShares;
            }
            if (nextQuote == quoteAmount) {
                break;
            }
            (bool nextSuccess, uint256 nextOut) =
                _safePreviewExchangeIn(nextQuote, state);
            if (!nextSuccess) {
                break;
            }
            quoteAmount = nextQuote;
            out = nextOut;
        }

        if (quoteAmount != subjectUnit) {
            out = out._mulDiv(subjectUnit, quoteAmount, Math.Rounding.Ceil);
        }

        uint8 targetDecimals = layoutStruct.rateTargetDecimals;
        if (targetDecimals == 18) {
            return out;
        }

        if (targetDecimals < 18) {
            return out * (10 ** (18 - targetDecimals));
        }

        return out / (10 ** (targetDecimals - 18));
    }

    function _safePreviewExchangeIn(uint256 quoteAmount_, bytes memory state)
        private view returns (bool success_, uint256 out_)
    {
        StandardExchangeRateProviderRepo.Storage storage l = StandardExchangeRateProviderRepo._layout();
        IStandardExchange reserveVault_ = l.reserveVault;
        IERC20 subject_ = address(l.rateSubject) == address(0) ? IERC20(address(reserveVault_)) : l.rateSubject;
        IERC20 rateTarget_ = l.rateTarget;
        if (state.length != 0) {
            try IStandardExchangeTransitionQuote(address(reserveVault_)).quoteAssets(state, quoteAmount_)
                returns (uint256 quotedOut) { return (true, quotedOut); }
            catch { return (false, 0); }
        }
        try reserveVault_.previewExchangeIn(subject_, quoteAmount_, rateTarget_) returns (uint256 quotedOut) {
            return (true, quotedOut);
        } catch {
            return (false, 0);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                        IStandardExchangeRateProvider                    */
    /* ---------------------------------------------------------------------- */

    function reserveVault() external view returns (IStandardExchange) {
        return StandardExchangeRateProviderRepo._reserveVault();
    }

    function rateTarget() external view returns (IERC20) {
        return StandardExchangeRateProviderRepo._rateTarget();
    }

    /* ---------------------------------------------------------------------- */
    /*                                  IFacet                                */
    /* ---------------------------------------------------------------------- */

    function facetName() public pure returns (string memory name) {
        return type(StandardExchangeRateProviderFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](3);
        interfaces_[0] = type(IRateProvider).interfaceId;
        interfaces_[1] = type(IStandardExchangeRateProvider).interfaceId;
        interfaces_[2] = type(IStandardExchangeRateQuote).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](4);
        funcs_[0] = IRateProvider.getRate.selector;
        funcs_[1] = IStandardExchangeRateProvider.reserveVault.selector;
        funcs_[2] = IStandardExchangeRateProvider.rateTarget.selector;
        funcs_[3] = IStandardExchangeRateQuote.quoteRate.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
