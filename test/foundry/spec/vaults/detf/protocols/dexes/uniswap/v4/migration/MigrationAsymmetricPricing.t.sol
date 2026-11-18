// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRateProvider} from "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {StandardExchangeFrozenQuoteLib as FrozenQuote} from "contracts/utils/StandardExchangeFrozenQuoteLib.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {DETFMintSplitLib} from "contracts/vaults/detf/common/core/DETFMintSplitLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHookMath as Weighted} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";
import {IUniswapV4StandardExchangeWeightedBufferHook as Hook} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";
import {IUniswapV4DetfMigrationWeightedPricingV3 as PricingV3} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricingV3.sol";
import {UniswapV4DetfMigrationWeightedPricingLib as PricingLib} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedPricingLib.sol";
import {Univ3LiquiditySeeder} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/// @notice Observed pricing against real 18/6 V3 pools; contribution currencies keep their required native18 units.
contract MigrationAsymmetricPricingTest is TestBase_UniswapV4DetfMigration {
    address private rateCurrency;

    function _deployRateFixture() internal override returns (address) {
        rateCurrency = create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory,
                "contracts/test/stubs/MintableERC20Decimals.sol:MintableERC20Decimals"),
            abi.encode("Six decimal rate fixture", "RATE6", uint8(6)), keccak256("migration.rate.six")
        );
        return rateCurrency;
    }

    /// @dev Size real liquidity from funded native units; the ordinary fixture assumes equal decimals.
    function _seedMigrationPool(IUniswapV3Pool pool_, bytes32 salt_) internal override {
        Univ3LiquiditySeeder seeder_ = Univ3LiquiditySeeder(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4DetfProductionSeDeployLib.sol:Univ3LiquiditySeeder"),
            "", salt_
        ));
        IERC20(pool_.token0()).transfer(address(seeder_), 2000 ether);
        IERC20(pool_.token1()).transfer(address(seeder_), 2000 ether);
        (uint160 price_,,,,,,) = pool_.slot0();
        uint128 liquidity_ = LiquidityAmounts.getLiquidityForAmounts(
            price_,
            TickMath.getSqrtPriceAtTick(TickMath.minUsableTick(pool_.tickSpacing())),
            TickMath.getSqrtPriceAtTick(TickMath.maxUsableTick(pool_.tickSpacing())),
            2000 ether, 2000 ether
        );
        seeder_.seedFullRange(pool_, liquidity_);
    }

    function test_observedAsymmetricDepositsAndWeightedQuotesMatchCanonicalPreviews() public {
        IERC20[] memory tokens_ = new IERC20[](2);
        tokens_[0] = IERC20(pairA);
        tokens_[1] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100 ether;
        amounts_[1] = 100 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp);
        (, uint256 refundA_) = IStandardExchangeIn(se0).previewExchangeIn(IERC20(pairA), 100 ether, IERC20(se0));
        (, uint256 refundB_) = IStandardExchangeIn(se1).previewExchangeIn(IERC20(pairB), 100 ether, IERC20(se1));
        uint256[] memory opening_ = migration.openingPairPerDetfWad();
        assertEq(opening_[0], opening_[1]);
        Migration.GenesisLeg[] memory legs_ = new Migration.GenesisLeg[](2);
        legs_[0] = Migration.GenesisLeg(IERC20(pairA), 100 ether, 1);
        legs_[1] = Migration.GenesisLeg(IERC20(pairB), 100 ether, 1);
        // Rounding differs between the pools: anchor issuance to the smaller actual contribution.
        vm.prank(migrationOwner);
        allocation.bootstrapMigrationReserve(legs_, refundA_ >= refundB_ ? 0 : 1, 1, block.timestamp);
        _setObservedPricing();
        assertEq(IERC20Metadata(rateCurrency).decimals(), 6);
        assertEq(IERC20Metadata(pairA).decimals(), 18);
        assertEq(IERC20Metadata(pairB).decimals(), 18);
        Pricing.BookV3 memory book_ = PricingV3(detf).migrationWeightedPricingV3();
        Hook hook_ = Hook(reserveHook);
        uint256 p_ = IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(detf);
        uint256 fee_ = IVaultFeeOracleQuery(address(indexedexManager)).dexSwapFeeOfVault(reserveHook);
        for (uint256 n_; n_ < 2; ++n_) {
            address pair_ = n_ == 0 ? pairA : pairB;
            address exchange_ = n_ == 0 ? se0 : se1;
            uint256 amount_ = (n_ + 2) * 1 ether;
            uint256 index_ = n_ == 0 ? book_.inputs.ethIndex : book_.inputs.dtfIndex;
            Pricing.Result memory result_ = PricingLib.evaluateOriginal(
                book_, n_ == 0 ? address(0) : pairB, amount_);
            uint256 boosted_ = Math.mulDiv(amount_, 1e18 + p_, 1e18);
            uint256 net_ = Weighted.applyTradingFeeNet(boosted_, fee_);
            (uint256 liveShares_, uint256 liveRefund_) =
                IStandardExchangeIn(exchange_).previewExchangeIn(IERC20(pair_), net_, IERC20(exchange_));
            ExchangeInAmount.Result memory frozen_ = FrozenQuote.evaluate(book_.inputs.legs[index_].deposit, net_);
            assertGt(liveShares_, 0, "actual asymmetric deposit issues shares");
            assertEq(frozen_.amountOut, liveShares_, "frozen shares match the real V3 preview");
            assertEq(frozen_.amountRefunded, liveRefund_, "frozen refund matches the real V3 preview");
            uint256 rated_ = Weighted.scaleTo(liveRefund_ + Weighted.ratedPairUnits(
                liveShares_, IRateProvider(hook_.rateProvider(index_)).getRate(),
                hook_.invScale(index_), hook_.ratedScale(index_)), hook_.ratedScale(index_));
            (uint256 gross_,) = IStandardExchangeIn(reserveHook).previewExchangeIn(
                IERC20(pair_), boosted_, IERC20(detf));
            (uint256 user_,) = DETFMintSplitLib._splitLiveGross(gross_, p_);
            assertEq(result_.pairEquivalent, amount_);
            assertEq(result_.boosted, boosted_);
            assertEq(result_.net, net_);
            assertEq(result_.ratedInflow, rated_);
            assertEq(result_.gross, gross_, "gross matches the real weighted hook");
            assertEq(result_.user, user_, "same native9 user-credit rounding");
        }
    }
}
