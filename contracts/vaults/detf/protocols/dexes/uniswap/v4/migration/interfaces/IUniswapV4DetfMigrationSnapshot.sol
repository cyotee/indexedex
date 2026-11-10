// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4StandardExchangeWeightedBufferHookCapture as Capture} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookCapture.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";

/// @notice Pricing primitive only; no entitlement, custody, or activation ABI.
interface IUniswapV4DetfMigrationSnapshot {
    /// @dev Composition-owned identities, not caller-supplied prices. The quote subject's fee
    /// oracle must be the one installed by its package; ordinary DETF has no public oracle getter.
    struct Source {
        address subject;
        address feeOracle;
        address weth;
        address originalDtf;
    }

    struct Route {
        address contribution;
        address tokenIn;
        address exchange;
        address pair;
        uint256 index;
    }

    struct Snapshot {
        uint256 version;
        uint256 chainId;
        address consumer;
        Source source;
        uint256 blockNumber;
        uint256 timestamp;
        bytes32 parentBlockHash;
        bytes32 id;
        address hookCaptureFacet;
        bytes32 hookCaptureCodeHash;
        IUniswapV4Detf.IoRoute[] mintRoutes;
        address[] pairOrder;
        Route[2] routes;
        uint256 seigniorage;
        Capture.Book book;
    }

    struct Result {
        uint256 pairEquivalent;
        uint256 boosted;
        uint256 net;
        uint256 ratedInflow;
        uint256 gross;
        uint256 user;
    }

    error SnapshotAlreadyCaptured();
    error SnapshotNotCaptured();
    error UnsupportedConfiguration(address source);
    error UnsupportedContribution(address contribution);
    error UnsupportedRoute(address exchange, address tokenIn, address tokenOut);
    error InvalidCapture(address source);
}
