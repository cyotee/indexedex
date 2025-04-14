// SPDX-License-Identifier: BUSL-1.1
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

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {
    StandardExchangeRateProviderRepo
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderRepo.sol";

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
        StandardExchangeRateProviderRepo.Storage storage layout = StandardExchangeRateProviderRepo._layout();
        uint256 totalShares = IERC20(address(layout.reserveVault)).totalSupply();

        if (totalShares == 0) {
            return 0;
        }

        // Start from a 1e18 raw-share quote when possible, but never exceed the
        // vault's actual total supply. Some fresh exchange vaults mint far fewer
        // than 1e18 raw share units, so quoting 1e18 would effectively ask to
        // redeem non-existent shares and collapse to zero.
        uint256 quoteAmount = totalShares < ONE_WAD ? totalShares : ONE_WAD;
        uint256 out =
            layout.reserveVault.previewExchangeIn(IERC20(address(layout.reserveVault)), quoteAmount, layout.rateTarget);

        for (uint256 i = 0; out == 0 && quoteAmount < totalShares && i < 18; ++i) {
            uint256 nextQuote = quoteAmount * 10;
            if (nextQuote > totalShares) {
                nextQuote = totalShares;
            }
            if (nextQuote == quoteAmount) {
                break;
            }
            quoteAmount = nextQuote;
            out = layout.reserveVault.previewExchangeIn(
                IERC20(address(layout.reserveVault)), quoteAmount, layout.rateTarget
            );
        }

        if (quoteAmount != ONE_WAD) {
            out = out._mulDiv(ONE_WAD, quoteAmount, Math.Rounding.Ceil);
        }

        uint8 targetDecimals = layout.rateTargetDecimals;
        if (targetDecimals == 18) {
            return out;
        }

        if (targetDecimals < 18) {
            return out * (10 ** (18 - targetDecimals));
        }

        return out / (10 ** (targetDecimals - 18));
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
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IRateProvider).interfaceId;
        interfaces_[1] = type(IStandardExchangeRateProvider).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](3);
        funcs_[0] = IRateProvider.getRate.selector;
        funcs_[1] = IStandardExchangeRateProvider.reserveVault.selector;
        funcs_[2] = IStandardExchangeRateProvider.rateTarget.selector;
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
