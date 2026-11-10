// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4DetfMigrationSnapshot as Snapshot} from "./interfaces/IUniswapV4DetfMigrationSnapshot.sol";
import {IUniswapV4Detf} from "../detf/interfaces/IUniswapV4Detf.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookCapture as Capture} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookCapture.sol";
import {UniswapV4StandardExchangeWeightedBufferHookClaimLib as Claim} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHookMath as Weighted} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";
import {StandardExchangeFrozenQuoteLib as Quote} from "contracts/utils/StandardExchangeFrozenQuoteLib.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {DETFMintSplitLib} from "contracts/vaults/detf/common/core/DETFMintSplitLib.sol";

/// @notice Atomic acquisition and state-only original-credit evaluation.
/// @dev The composing package owns Source and the snapshot storage. Evaluation never
/// invokes live sources, even for errors. Only direct contribution-to-pair routes and
/// raw DETF output are admitted in format 1; enabled buffers require exact V3 inputs.
library UniswapV4DetfMigrationSnapshotLib {
    function capture(Snapshot.Source memory source) internal view returns (Snapshot.Snapshot memory s) {
        IUniswapV4Detf subject = IUniswapV4Detf(source.subject);
        address hook = subject.hook();
        if (!subject.isReserveLive() || !IUniswapV4SeBufferHook(hook).isLive()) {
            revert Snapshot.UnsupportedConfiguration(source.subject);
        }
        s.version = 1;
        s.chainId = block.chainid;
        s.consumer = address(this);
        s.source = source;
        s.blockNumber = block.number;
        s.timestamp = block.timestamp;
        s.parentBlockHash = block.number == 0 ? bytes32(0) : blockhash(block.number - 1);
        s.mintRoutes = subject.mintRoutes();
        s.book = Capture(hook).captureWeightedMintBook();
        if (s.book.hook != hook || s.book.legs.length < 2 || s.book.legs.length > 8) {
            revert Snapshot.InvalidCapture(hook);
        }
        s.hookCaptureFacet = IDiamondLoupe(hook).facetAddress(Capture.captureWeightedMintBook.selector);
        s.hookCaptureCodeHash = s.hookCaptureFacet.codehash;
        uint256 output = _index(s.book, source.subject);
        if (s.book.legs[output].standardExchange != address(0)) {
            revert Snapshot.UnsupportedConfiguration(source.subject);
        }
        s.pairOrder = new address[](s.book.legs.length - 1);
        uint256 next;
        for (uint256 i; i < s.book.legs.length; ++i) {
            if (i != output) s.pairOrder[next++] = s.book.legs[i].token;
        }
        s.routes[0] = _route(s, address(0), source.weth);
        s.routes[1] = _route(s, source.originalDtf, source.originalDtf);
        if (source.originalDtf == address(0) || source.originalDtf == source.weth) {
            revert Snapshot.UnsupportedConfiguration(source.originalDtf);
        }
        s.seigniorage = source.feeOracle == address(0) ? 0
            : IVaultFeeOracleQuery(source.feeOracle).seigniorageIncentivePercentageOfVault(source.subject);
        // Seal identity only after complete route acquisition. No storage has been written.
        s.id = keccak256(abi.encode("IndexedEx.frozen-original-credit", s));
    }

    function _route(Snapshot.Snapshot memory s, address contribution, address input)
        private view returns (Snapshot.Route memory route)
    {
        address exchange = _selected(s.mintRoutes, input);
        if (exchange == address(0)) revert Snapshot.UnsupportedContribution(contribution);
        for (uint256 p; p < s.pairOrder.length; ++p) {
            address pair = s.pairOrder[p];
            uint256 i = _index(s.book, pair);
            Capture.Leg memory leg = s.book.legs[i];
            if (_selected(s.mintRoutes, pair) != exchange && leg.standardExchange != exchange) continue;
            if (input != pair) revert Snapshot.UnsupportedRoute(exchange, input, pair);
            if (leg.standardExchange != address(0) && !_disabled(leg)) {
                if (!leg.depositSupported) revert Snapshot.UnsupportedRoute(leg.standardExchange, pair, leg.standardExchange);
                Quote.requireSupported(leg.deposit);
                Quote.requireRecognized(leg.captureFacet, leg.previewFacet);
                if (leg.deposit.exchange != leg.standardExchange || leg.deposit.request.tokenIn != pair
                    || leg.deposit.request.tokenOut != leg.standardExchange || leg.deposit.request.holder != s.book.hook
                    || leg.captureFacet == address(0) || leg.previewFacet == address(0)) {
                    revert Snapshot.InvalidCapture(leg.standardExchange);
                }
            }
            return Snapshot.Route(contribution, input, exchange, pair, i);
        }
        revert Snapshot.UnsupportedRoute(exchange, input, s.source.subject);
    }

    function _selected(IUniswapV4Detf.IoRoute[] memory routes, address token) private pure returns (address) {
        for (uint256 i; i < routes.length; ++i) {
            if (address(routes[i].token) == token) return address(routes[i].vault);
        }
        return address(0);
    }

    function _index(Capture.Book memory book, address token) private pure returns (uint256) {
        for (uint256 i; i < book.legs.length; ++i) if (book.legs[i].token == token) return i;
        revert("token");
    }

    function _rate(Capture.Leg memory leg) private pure returns (uint256) {
        return Claim.readCapturedRate(leg.provider, leg.rate.success, leg.rate.data);
    }

    function _bubble(Capture.Outcome memory outcome) private pure returns (bytes memory) {
        if (!outcome.success) {
            bytes memory reason = outcome.data;
            assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        }
        return outcome.data;
    }

    function _disabled(Capture.Leg memory leg) private pure returns (bool) {
        if (abi.decode(_bubble(leg.registration), (address)) == address(0)) revert Claim.BufferFailed();
        return abi.decode(_bubble(leg.disabled), (bool));
    }

    function _rated(Capture.Book memory book) private pure returns (uint256[] memory balances) {
        balances = new uint256[](book.legs.length);
        for (uint256 i; i < balances.length; ++i) {
            Capture.Leg memory leg = book.legs[i];
            uint256 units = leg.rawReserve;
            if (leg.standardExchange == address(0)) {
                if (leg.provider != address(0)) units = Weighted.ratedPairUnits(units, _rate(leg), leg.invScale, leg.ratedScale);
            } else if (leg.seReserve != 0) {
                if (leg.provider == address(0)) revert Claim.RateProviderRequired();
                units += Weighted.ratedPairUnits(leg.seReserve, _rate(leg), leg.invScale, leg.ratedScale);
            }
            balances[i] = Weighted.scaleTo(units, leg.ratedScale);
        }
    }

    function evaluateOriginal(Snapshot.Snapshot memory s, address contribution, uint256 amount)
        internal pure returns (Snapshot.Result memory r)
    {
        if (s.id == bytes32(0)) revert Snapshot.SnapshotNotCaptured();
        uint256 routeIndex;
        if (contribution == s.routes[1].contribution) routeIndex = 1;
        else if (contribution != s.routes[0].contribution) revert Snapshot.UnsupportedContribution(contribution);
        if (amount == 0) return r;
        Snapshot.Route memory route = s.routes[routeIndex];
        r.pairEquivalent = amount;
        r.boosted = Math.mulDiv(amount, 1e18 + s.seigniorage, 1e18);
        if (r.boosted == 0) revert Claim.ZeroAmount();
        if (route.pair == s.source.subject) revert Claim.InvalidPair();
        uint256 j = _index(s.book, s.source.subject);
        uint256[] memory balances = _rated(s.book);
        if (balances[route.index] == 0 || balances[j] == 0) revert Claim.SwapNotLive();
        uint256 fee = abi.decode(_bubble(s.book.fee), (uint256));
        if (fee >= 1e18) revert Claim.InvalidFeeWad();
        r.net = Weighted.applyTradingFeeNet(r.boosted, fee);
        Capture.Leg memory input = s.book.legs[route.index];
        uint256 units;
        if (input.standardExchange == address(0)) {
            units = input.provider == address(0) ? r.net : Math.mulDiv(r.net, _rate(input), 1e18);
        } else if (_disabled(input)) {
            units = r.net;
        } else {
            ExchangeInAmount.Result memory deposit = Quote.evaluate(input.deposit, r.net);
            ExchangeInAmount.consumedInput(r.net, deposit.amountRefunded);
            units = deposit.amountRefunded;
            if (deposit.amountOut != 0) units += Weighted.ratedPairUnits(
                deposit.amountOut, _rate(input), input.invScale, input.ratedScale
            );
        }
        r.ratedInflow = Weighted.scaleTo(units, input.ratedScale);
        Capture.Leg memory output = s.book.legs[j];
        uint256 budget = Claim.exactInputBudget(
            balances[route.index], input.weight, balances[j], output.weight, r.ratedInflow
        );
        r.gross = Claim.rawOutput(budget, output.ratedScale, output.rawReserve);
        (r.user,) = DETFMintSplitLib._splitLiveGross(r.gross, s.seigniorage);
    }

    function evaluateOriginals(Snapshot.Snapshot memory s, uint256 originalEth, uint256 originalDtf)
        internal pure returns (uint256)
    {
        return evaluateOriginal(s, s.routes[0].contribution, originalEth).user
            + evaluateOriginal(s, s.routes[1].contribution, originalDtf).user;
    }
}
