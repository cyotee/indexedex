// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4DetfMigrationSnapshot as Snapshot} from "./interfaces/IUniswapV4DetfMigrationSnapshot.sol";
import {UniswapV4DetfMigrationSnapshotLib as SnapshotLib} from "./UniswapV4DetfMigrationSnapshotLib.sol";
import {TestBase_UniswapV4Detf_Weighted_Univ3Se} from "../detf/TestBase_UniswapV4Detf_Weighted_Univ3Se.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {DETFMintSplitLib} from "contracts/vaults/detf/common/core/DETFMintSplitLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHookMath as Weighted} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";
import {UniswapV4StandardExchangeWeightedBufferHookClaimLib as Claim} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol";
import {StandardExchangeFrozenQuoteLib as FrozenQuote} from "contracts/utils/StandardExchangeFrozenQuoteLib.sol";
import {IUniswapV4StandardExchangeWeightedBufferHook as WeightedHook} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IRateProvider} from "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";

interface IMigrationPairPreview {
    function peekPairEq(address vault, address token, uint256 amount) external view returns (uint256);
}

/// @notice Legitimate one-shot library consumer, not a replacement hook/DETF/provider.
/// @dev Lifecycle authorization is deliberately not the final Migration package.
contract MigrationSnapshotConsumer {
    address public immutable subject;
    address public immutable feeOracle;
    address public immutable weth;
    address public immutable originalDtf;
    bytes private frozen;

    constructor(Snapshot.Source memory source) {
        subject = source.subject;
        feeOracle = source.feeOracle;
        weth = source.weth;
        originalDtf = source.originalDtf;
    }

    function capture() external returns (bytes32) {
        if (frozen.length != 0) revert Snapshot.SnapshotAlreadyCaptured();
        Snapshot.Snapshot memory s = SnapshotLib.capture(Snapshot.Source(subject, feeOracle, weth, originalDtf));
        frozen = abi.encode(s);
        return s.id;
    }

    function snapshotBytes() external view returns (bytes memory) { return frozen; }

    function evaluate(address contribution, uint256 amount) external view returns (Snapshot.Result memory) {
        if (frozen.length == 0) revert Snapshot.SnapshotNotCaptured();
        return SnapshotLib.evaluateOriginal(abi.decode(frozen, (Snapshot.Snapshot)), contribution, amount);
    }

    function evaluateOriginals(uint256 originalEth, uint256 originalDtfAmount) external view returns (uint256) {
        if (frozen.length == 0) revert Snapshot.SnapshotNotCaptured();
        return SnapshotLib.evaluateOriginals(abi.decode(frozen, (Snapshot.Snapshot)), originalEth, originalDtfAmount);
    }
}

/// @notice Unit-only exposure of canonical arithmetic and the pure evaluator.
contract MigrationSnapshotMathExposure {
    function requireRecognized(address captureFacet, address previewFacet) external view {
        FrozenQuote.requireRecognized(captureFacet, previewFacet);
    }
    function evaluate(Snapshot.Snapshot memory s, address token, uint256 amount)
        external pure returns (Snapshot.Result memory)
    { return SnapshotLib.evaluateOriginal(s, token, amount); }

    function budget(uint256 balance, uint256 wi, uint256 wo, uint256 inflow) external pure returns (uint256) {
        return Claim.exactInputBudget(balance, wi, balance, wo, inflow);
    }

    function rawOutput(uint256 budget_, uint256 scale, uint256 reserve) external pure returns (uint256) {
        return Claim.rawOutput(budget_, scale, reserve);
    }

    function net(uint256 amount, uint256 fee) external pure returns (uint256) {
        return Weighted.applyTradingFeeNet(amount, fee);
    }

    function scale(uint256 amount, uint256 factor) external pure returns (uint256) {
        return Weighted.scaleTo(amount, factor);
    }
}

/// @notice Real registered V3 SEs, weighted hook, DETF and external one-shot consumer.
abstract contract TestBase_UniswapV4DetfMigrationSnapshot is TestBase_UniswapV4Detf_Weighted_Univ3Se {
    MigrationSnapshotConsumer internal consumer;

    function setUp() public virtual override {
        TestBase_UniswapV4Detf_Weighted_Univ3Se.setUp();
        _firstBond(100 ether);
        consumer = _consumer(pairA, pairB, bytes32("snapshot"));
    }

    function _consumer(address originalEthPair, address originalDtfPair, bytes32 salt)
        internal returns (MigrationSnapshotConsumer)
    {
        return MigrationSnapshotConsumer(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "TestBase_UniswapV4DetfMigrationSnapshot.sol:MigrationSnapshotConsumer"),
            abi.encode(Snapshot.Source(detf, address(indexedexManager), originalEthPair, originalDtfPair)), salt
        ));
    }

    function _oracle(address pair, uint256 amount) internal view returns (Snapshot.Result memory r) {
        if (amount == 0) return r;
        address exchange = pair == pairA ? se0 : se1;
        r.pairEquivalent = IMigrationPairPreview(detf).peekPairEq(exchange, pair, amount);
        uint256 p = IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(detf);
        r.boosted = Math.mulDiv(r.pairEquivalent, 1e18 + p, 1e18);
        r.net = Weighted.applyTradingFeeNet(
            r.boosted, IVaultFeeOracleQuery(address(indexedexManager)).dexSwapFeeOfVault(reserveHook)
        );
        WeightedHook liveHook = WeightedHook(reserveHook);
        for (uint256 i; i < liveHook.numTokens(); ++i) {
            if (liveHook.token(i) != pair) continue;
            uint256 units = r.net;
            if (!IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(exchange)) {
                (uint256 shares, uint256 refund) = IStandardExchangeIn(exchange).previewExchangeIn(IERC20(pair), r.net, IERC20(exchange));
                units = refund;
                if (shares != 0) units += Weighted.ratedPairUnits(
                    shares, IRateProvider(liveHook.rateProvider(i)).getRate(), liveHook.invScale(i), liveHook.ratedScale(i)
                );
            }
            r.ratedInflow = Weighted.scaleTo(units, liveHook.ratedScale(i));
        }
        (r.gross,) = IStandardExchangeIn(reserveHook).previewExchangeIn(IERC20(pair), r.boosted, IERC20(detf));
        (r.user,) = DETFMintSplitLib._splitLiveGross(r.gross, p);
    }

    function _assertOracle(address contribution, address pair, uint256 amount) internal view {
        Snapshot.Result memory actual = consumer.evaluate(contribution, amount);
        Snapshot.Result memory expected = _oracle(pair, amount);
        assertEq(actual.pairEquivalent, expected.pairEquivalent, "pair conversion");
        assertEq(actual.boosted, expected.boosted, "uplift");
        assertEq(actual.net, expected.net, "single hook fee");
        assertEq(actual.ratedInflow, expected.ratedInflow, "exact nonlinear deposit and rate");
        assertEq(actual.gross, expected.gross, "gross primary mint");
        assertEq(actual.user, expected.user, "user floor");
    }
}
