// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from "./interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";
import {UniswapV4DetfMigrationWeightedPricingLib as PricingLib} from "./UniswapV4DetfMigrationWeightedPricingLib.sol";
import {TestBase_UniswapV4Detf_Weighted_Univ3Se} from "../detf/TestBase_UniswapV4Detf_Weighted_Univ3Se.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4Detf} from "../detf/interfaces/IUniswapV4Detf.sol";
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

import {IUniswapV4StandardExchangeWeightedBufferHookCapture as Capture} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookCapture.sol";
import {IStandardExchangeFrozenQuoteInputs as Frozen} from "contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol";
import {UniswapV3FrozenQuoteFixture as V3Capture} from "./UniswapV3FrozenQuoteFixture.sol";

interface IMigrationPairPreview {
    function peekPairEq(address vault, address token, uint256 amount) external view returns (uint256);
}

/// @notice Differential fixture acquisition only; production manual pricing never calls this library.
library MigrationWeightedPricingFixture {
    function observed(
        address subject_, address oracle_, address weth_, address originalDtf_, V3Capture.Binding[] memory bindings_
    ) internal view returns (Pricing.InputsV3 memory inputs_)
    {
        return observedHook(
            subject_,
            IUniswapV4Detf(subject_).hook(),
            IVaultFeeOracleQuery(oracle_).seigniorageIncentivePercentageOfVault(subject_),
            weth_,
            originalDtf_,
            bindings_
        );
    }

    /// @notice Capture a real comparison hook while retaining the genuine parent/output identity.
    function observedHook(
        address consumer_, address hook_, uint256 seigniorage_, address weth_, address originalDtf_,
        V3Capture.Binding[] memory bindings_
    ) internal view returns (Pricing.InputsV3 memory inputs_)
    {
        Capture.Book memory captured_ = Capture(hook_).captureWeightedMintBook();
        inputs_.swapFeeWad = abi.decode(captured_.fee.data, (uint256));
        inputs_.seigniorage = seigniorage_;
        inputs_.legs = new Pricing.LegV3[](captured_.legs.length);
        for (uint256 i_; i_ < captured_.legs.length; ++i_) {
            Capture.Leg memory c_ = captured_.legs[i_];
            Pricing.LegV3 memory leg_;
            leg_.token = c_.token;
            leg_.standardExchange = c_.standardExchange;
            leg_.rawReserve = c_.rawReserve;
            leg_.seReserve = c_.seReserve;
            leg_.weight = c_.weight;
            leg_.invScale = c_.invScale;
            leg_.ratedScale = c_.ratedScale;
            if (c_.standardExchange == address(0)) {
                leg_.mode = c_.provider == address(0) ? Pricing.LegMode.Raw : Pricing.LegMode.RawRate;
                if (c_.provider != address(0)) leg_.rate = abi.decode(c_.rate.data, (uint256));
            } else if (abi.decode(c_.disabled.data, (bool))) {
                leg_.mode = Pricing.LegMode.DisabledBuffer;
                if (c_.seReserve != 0) leg_.rate = abi.decode(c_.rate.data, (uint256));
            } else {
                leg_.mode = Pricing.LegMode.EnabledV3Buffer;
                leg_.rate = abi.decode(c_.rate.data, (uint256));
                bool bound_;
                for (uint256 j_; j_ < bindings_.length; ++j_) {
                    if (bindings_[j_].exchange != leg_.standardExchange) continue;
                    require(!bound_, "duplicate V3 capture binding");
                    leg_.deposit = V3Capture.capture(bindings_[j_], leg_.token);
                    bound_ = true;
                }
                require(bound_, "missing V3 capture binding");
            }
            inputs_.legs[i_] = leg_;
            if (c_.token == weth_) inputs_.ethIndex = i_;
            if (c_.token == originalDtf_) inputs_.dtfIndex = i_;
            if (c_.token == consumer_) inputs_.detfIndex = i_;
        }
    }
}

/// @notice Pure evaluator consumer for comparison with ordinary production Weighted proxies.
contract MigrationSnapshotConsumer {
    address public immutable subject;
    address public immutable weth;
    address public immutable originalDtf;
    bytes private pricing;

    constructor(address subject_, address weth_, address originalDtf_) {
        subject = subject_;
        weth = weth_;
        originalDtf = originalDtf_;
    }

    function set(Pricing.InputsV3 memory inputs_) external returns (bytes32) {
        Pricing.BookV3 memory book_ = Pricing.BookV3(3, block.chainid, subject, weth, originalDtf, bytes32(0), inputs_);
        PricingLib.validate(book_);
        book_.id = keccak256(abi.encode("IndexedEx.manual-weighted-original-credit", book_));
        pricing = abi.encode(book_);
        return book_.id;
    }

    function snapshotBytes() external view returns (bytes memory) { return pricing; }

    function evaluate(address contribution_, uint256 amount_) external view returns (Pricing.Result memory) {
        if (pricing.length == 0) revert Pricing.MigrationWeightedPricingNotSet();
        return PricingLib.evaluateOriginal(abi.decode(pricing, (Pricing.BookV3)), contribution_, amount_);
    }

    function evaluateOriginals(uint256 originalEth_, uint256 originalDtf_) external view returns (uint256) {
        if (pricing.length == 0) revert Pricing.MigrationWeightedPricingNotSet();
        return PricingLib.evaluateOriginals(abi.decode(pricing, (Pricing.BookV3)), originalEth_, originalDtf_);
    }
}

/// @notice Unit-only exposure of canonical arithmetic and the pure evaluator.
contract MigrationSnapshotMathExposure {
    function requireSupported(Frozen.VersionedInputs memory inputs_) external pure {
        FrozenQuote.requireSupported(inputs_);
    }
    function evaluate(Pricing.BookV3 memory s, address token, uint256 amount)
        external pure returns (Pricing.Result memory)
    { return PricingLib.evaluateOriginal(s, token, amount); }

    function v3Shares(Frozen.VersionedInputs memory inputs_, uint256 amount_) external pure returns (uint256) {
        return FrozenQuote.evaluate(inputs_, amount_).amountOut;
    }
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
            abi.encode(detf, originalEthPair, originalDtfPair), salt
        ));
    }

    function _v3PricingBindings() internal view returns (V3Capture.Binding[] memory bindings_) {
        bindings_ = new V3Capture.Binding[](2);
        bindings_[0] = V3Capture.Binding(se0, address(univ3Pool0), address(indexedexManager));
        bindings_[1] = V3Capture.Binding(se1, address(univ3Pool1), address(indexedexManager));
    }

    function _observedInputs() internal view returns (Pricing.InputsV3 memory) {
        return MigrationWeightedPricingFixture.observed(
            detf, address(indexedexManager), pairA, pairB, _v3PricingBindings()
        );
    }

    function _oracle(address pair, uint256 amount) internal view returns (Pricing.Result memory r) {
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
        Pricing.Result memory actual = consumer.evaluate(contribution, amount);
        Pricing.Result memory expected = _oracle(pair, amount);
        assertEq(actual.pairEquivalent, expected.pairEquivalent, "pair conversion");
        assertEq(actual.boosted, expected.boosted, "uplift");
        assertEq(actual.net, expected.net, "single hook fee");
        assertEq(actual.ratedInflow, expected.ratedInflow, "exact nonlinear deposit and rate");
        assertEq(actual.gross, expected.gross, "gross primary mint");
        assertEq(actual.user, expected.user, "user floor");
    }
}
