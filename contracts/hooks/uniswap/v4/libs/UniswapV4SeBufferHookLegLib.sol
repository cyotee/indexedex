// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote, IStandardExchangeRateQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

/**
 * @title UniswapV4SeBufferHookLegLib
 * @notice Classify join/swap addresses as DETF self-leg, pair, or Standard Exchange share.
 * @dev PRD §15.12.1. Membership is AddressSetRepo._contains only. Do not scan tokens().
 */
library UniswapV4SeBufferHookLegLib {
    using AddressSetRepo for AddressSet;

    enum LegKind {
        Unknown,
        Detf,
        Pair,
        StandardExchange
    }

    struct Layout {
        address detfToken;
        AddressSet pairTokens;
        AddressSet standardExchanges;
        mapping(address pair => address se) standardExchangeOf;
        mapping(address se => address pair) pairOfStandardExchange;
    }


    /// @dev A separate caller converts its input before the owner swaps the
    /// proceeds. Preserve the buffered holder's inventory and project provider
    /// fees, supply, backing and pool changes before quoting the reserve intake.
    struct ExternalQuote {
        IStandardExchangeTransitionQuote exchange;
        bytes state;
        uint256 assets;
        uint256 heldAssets;
        uint256 heldShares;
    }

    function afterExternalExchange(address se, address pair, address tokenIn, uint256 amountIn, address holder)
        external view returns (ExternalQuote memory q)
    {
        q.exchange = IStandardExchangeTransitionQuote(se);
        (q.state,) = q.exchange.quoteState(pair, holder);
        if (tokenIn == se) {
            (q.state,,,) = q.exchange.quoteTransition(
                q.state, IStandardExchangeTransitionQuote.Operation.ReceiveShares, amountIn
            );
            (q.state,, q.assets, q.heldAssets) = q.exchange.quoteTransition(
                q.state, IStandardExchangeTransitionQuote.Operation.RedeemExactIn, amountIn
            );
        } else {
            (q.state, q.assets, q.heldAssets) = IStandardExchangeExternalQuote(se)
                .quoteExternalExchange(q.state, tokenIn, amountIn);
        }
        q.heldShares = q.exchange.quoteShareBalance(q.state);
    }

    function afterExternalDeposit(address se, address pair, address tokenIn, uint256 amountIn, address holder)
        external view returns (ExternalQuote memory q)
    {
        q.exchange = IStandardExchangeTransitionQuote(se);
        (q.state,) = q.exchange.quoteState(pair, holder);
        (q.state, q.assets, q.heldAssets) = IStandardExchangeExternalQuote(se)
            .quoteExternalDeposit(q.state, tokenIn, amountIn);
        q.heldShares = q.exchange.quoteShareBalance(q.state);
    }

    function depositAfterExchange(ExternalQuote memory q, uint256 assets)
        external view returns (uint256 minted, uint256 heldAssetsAfter)
    {
        (,, minted, heldAssetsAfter) = q.exchange.quoteTransition(
            q.state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, assets
        );
    }

    /// @dev Match the family's full-current-LP proportional exit quote after
    /// external SE issuance, including protocol LP dilution and any retained dust.
    function matchingLiquidityDetf(
        ExternalQuote memory q, uint256 rawReserve, uint256 pairValue, uint256 projectedSupply, uint256 dust
    )
        external view returns (uint256) {
        uint256 supply = IERC20(address(this)).totalSupply();
        if (supply == 0 || projectedSupply == 0) return 0;
        uint256 rawOut = Math.mulDiv(rawReserve, supply, projectedSupply);
        uint256 shareOut = Math.mulDiv(q.heldShares, supply, projectedSupply);
        if (dust != 0) {
            uint256 rawCap = rawReserve > dust ? rawReserve - dust : 0;
            uint256 shareCap = q.heldShares > dust ? q.heldShares - dust : 0;
            if (rawOut > rawCap) rawOut = rawCap;
            if (shareOut > shareCap) shareOut = shareCap;
        }
        uint256 pairOut = q.exchange.quoteAssets(q.state, shareOut);
        return rawOut == 0 || pairOut == 0 ? 0 : Math.mulDiv(rawOut, pairValue, pairOut);
    }

    error RateProviderFailed();

    function rateAfterExchange(ExternalQuote memory q, address pair, address provider)
        external view returns (uint256 rate)
    {
        bool projected;
        try IERC165(provider).supportsInterface(type(IStandardExchangeRateQuote).interfaceId)
            returns (bool supported) { projected = supported; }
        catch {}
        bytes memory input = projected
            ? abi.encodeCall(IStandardExchangeRateQuote.quoteRate, (address(q.exchange), pair, q.state))
            : abi.encodeCall(IRateProvider.getRate, ());
        (bool ok, bytes memory data) = provider.staticcall(input);
        if (!ok || data.length != 32) revert RateProviderFailed();
        rate = abi.decode(data, (uint256));
        if (rate == 0) revert RateProviderFailed();
    }

    error ZeroAddress();
    error PairSeOverlap(address pair, address se);
    error DetfTokenInSets(address detfToken);
    error SeAlreadyBound(address se, address existingPair);

    function classify(Layout storage layoutStruct, address addr) internal view returns (LegKind) {
        address detfToken_ = layoutStruct.detfToken;
        if (detfToken_ != address(0) && addr == detfToken_) {
            return LegKind.Detf;
        }
        if (layoutStruct.pairTokens._contains(addr)) {
            return LegKind.Pair;
        }
        if (layoutStruct.standardExchanges._contains(addr)) {
            return LegKind.StandardExchange;
        }
        return LegKind.Unknown;
    }

    /// @notice True when pool inventory is static wrapper shares: pair token is the
    ///         wrapper diamond and `asset()` is a different non-zero underlying.
    function isWrapperShareInventory(address pair, address se) internal view returns (bool) {
        if (pair == address(0) || pair != se) return false;
        (bool ok, bytes memory data) = pair.staticcall(abi.encodeWithSelector(bytes4(0x38d52e0f)));
        if (!ok || data.length < 32) return false;
        address underlying = abi.decode(data, (address));
        return underlying != address(0) && underlying != pair;
    }

    function wrapperShareDecimalsOk(uint8 d) internal pure returns (bool) {
        return d >= 19 && d <= 36;
    }

    function addPairSe(Layout storage layoutStruct, address pair, address se) internal {
        if (pair == address(0) || se == address(0)) {
            revert ZeroAddress();
        }
        if (pair == se && !isWrapperShareInventory(pair, se)) {
            revert PairSeOverlap(pair, se);
        }
        address detfToken_ = layoutStruct.detfToken;
        if (pair == detfToken_ || se == detfToken_) {
            revert DetfTokenInSets(detfToken_);
        }
        if (layoutStruct.standardExchanges._contains(pair) || layoutStruct.pairTokens._contains(se)) {
            revert PairSeOverlap(pair, se);
        }
        address existingPair_ = layoutStruct.pairOfStandardExchange[se];
        if (existingPair_ != address(0) && existingPair_ != pair) {
            revert SeAlreadyBound(se, existingPair_);
        }
        layoutStruct.pairTokens._add(pair);
        layoutStruct.standardExchanges._add(se);
        layoutStruct.standardExchangeOf[pair] = se;
        layoutStruct.pairOfStandardExchange[se] = pair;
    }
}
