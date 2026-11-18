// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeBundleIn} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/SqrtPriceMath.sol";
import {Univ3LiquiditySeeder} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {IUniswapV4DetfSelfCall} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4DetfSelfCall.sol";
import {Vm} from "forge-std/Vm.sol";
import {TestBase_UniswapV4DetfMigration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";

/// @notice F1 regressions on registry-deployed production proxies, not the historical witness.
abstract contract MigrationGenesisCapitalBase is TestBase_UniswapV4DetfMigration {
    function _donate(uint256 a_, uint256 b_) internal {
        IERC20[] memory tokens_ = new IERC20[](2);
        tokens_[0] = IERC20(pairA);
        tokens_[1] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = a_;
        amounts_[1] = b_;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp);
    }

    function _legs(uint256 a_, uint256 b_) internal view returns (Migration.GenesisLeg[] memory legs_) {
        legs_ = new Migration.GenesisLeg[](2);
        legs_[0] = Migration.GenesisLeg(IERC20(pairA), a_, 1);
        legs_[1] = Migration.GenesisLeg(IERC20(pairB), b_, 1);
    }

    function _requiredOther(IERC20 anchor_, uint256 amount_, address other_) internal view returns (uint256) {
        (address[] memory tokens_, uint256[] memory amounts_) = migration.previewFirstBondPayments(anchor_, amount_);
        for (uint256 i_; i_ < tokens_.length; ++i_) if (tokens_[i_] == other_) return amounts_[i_];
        revert("other payment missing");
    }

    function _expectedMint(address pair_, uint256 paid_) internal view returns (uint256) {
        uint256[] memory opening_ = migration.openingPairPerDetfWad();
        assertEq(opening_[0], 1e18);
        assertEq(opening_[1], 1e18);
        return (paid_ * (10 ** (18 - IERC20Metadata(pair_).decimals()))) * 1e9 / opening_[0];
    }

    /// @dev Counterpart quotes are processed payments, not gross inputs to its SE.
    function _minimumOther(uint256 anchor_) internal view returns (uint256 gross_) {
        address anchorPair_ = anchor_ == 0 ? pairA : pairB;
        address otherPair_ = anchor_ == 0 ? pairB : pairA;
        address anchorSe_ = anchor_ == 0 ? se0 : se1;
        address otherSe_ = anchor_ == 0 ? se1 : se0;
        (, uint256 refund_) = IStandardExchangeIn(anchorSe_).previewExchangeIn(
            IERC20(anchorPair_), 100 ether, IERC20(anchorSe_)
        );
        uint256 required_ = _expectedMint(anchorPair_, 100 ether - refund_) * 1e9;
        assertEq(_requiredOther(IERC20(anchorPair_), 100 ether, otherPair_), required_);
        uint256 low_ = required_;
        gross_ = 100 ether;
        (uint256 shares_, uint256 upperRefund_) = IStandardExchangeIn(otherSe_).previewExchangeIn(
            IERC20(otherPair_), gross_, IERC20(otherSe_)
        );
        assertGt(shares_, 0, "gross upper bound is executable");
        assertGe(gross_ - upperRefund_, required_);
        while (low_ < gross_) {
            uint256 mid_ = low_ + (gross_ - low_) / 2;
            (, refund_) = IStandardExchangeIn(otherSe_).previewExchangeIn(
                IERC20(otherPair_), mid_, IERC20(otherSe_)
            );
            if (mid_ - refund_ >= required_) gross_ = mid_;
            else low_ = mid_ + 1;
        }
        (shares_, refund_) = IStandardExchangeIn(otherSe_).previewExchangeIn(
            IERC20(otherPair_), gross_, IERC20(otherSe_)
        );
        assertGt(shares_, 0);
        assertGe(gross_ - refund_, required_);
        (, refund_) = IStandardExchangeIn(otherSe_).previewExchangeIn(
            IERC20(otherPair_), gross_ - 1, IERC20(otherSe_)
        );
        assertLt(gross_ - 1 - refund_, required_, "predecessor misses processed payment");
    }

    /// @dev Whole externally observable capital/custody state, including both SEs.
    function _capitalState() internal view returns (bytes32 state_) {
        address[6] memory tokens_ = [pairA, pairB, se0, se1, detf, migration.hook()];
        address[9] memory holders_ = [address(this), detf, address(bonds), address(receipt), se0, se1,
            migration.hook(), address(migrationPoolA), address(migrationPoolB)];
        state_ = keccak256(abi.encode(
            migration.isReserveLive(), migration.migrationBootstrapSelfMinted(), receipt.stakingState()
        ));
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            IERC20 token_ = IERC20(tokens_[i_]);
            state_ = keccak256(abi.encode(state_, token_.totalSupply(),
                migration.migrationDonationInventory(token_)));
            for (uint256 j_; j_ < holders_.length; ++j_) {
                state_ = keccak256(abi.encode(state_, token_.balanceOf(holders_[j_]),
                    token_.allowance(detf, holders_[j_]), token_.allowance(address(this), holders_[j_]),
                    token_.allowance(address(bonds), holders_[j_])));
            }
        }
    }

    function _reject(uint256 a_, uint256 b_, uint256 anchor_) internal {
        _donate(a_, b_);
        bytes32 before_ = _capitalState();
        Migration.GenesisLeg[] memory legs_ = _legs(a_, b_);
        address other_ = anchor_ == 0 ? pairB : pairA;
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidGenesisLeg.selector, other_));
        allocation.bootstrapMigrationReserve(legs_, anchor_, 1, block.timestamp);
        assertEq(_capitalState(), before_, "failed genesis must preserve all capital and allowances");
    }

    function _accept(uint256 a_, uint256 b_, uint256 anchor_) internal {
        _donate(a_, b_);
        Migration.GenesisLeg[] memory legs_ = _legs(a_, b_);
        uint256 aBefore_ = IERC20(pairA).balanceOf(detf);
        uint256 bBefore_ = IERC20(pairB).balanceOf(detf);
        (, uint256 refundA_) = IStandardExchangeIn(se0).previewExchangeIn(IERC20(pairA), a_, IERC20(se0));
        (, uint256 refundB_) = IStandardExchangeIn(se1).previewExchangeIn(IERC20(pairB), b_, IERC20(se1));
        uint256 expected_ = anchor_ == 0 ? _expectedMint(pairA, a_ - refundA_) : _expectedMint(pairB, b_ - refundB_);
        vm.recordLogs();
        vm.prank(migrationOwner);
        (uint256 minted_, uint256 lp_) = allocation.bootstrapMigrationReserve(legs_, anchor_, 1, block.timestamp);
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        uint256 consumedA_;
        uint256 consumedB_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter == detf && logs_[i_].topics.length == 2
                && logs_[i_].topics[0] == keccak256("MigrationCapitalConsumed(address,uint256)")) {
                if (logs_[i_].topics[1] == bytes32(uint256(uint160(pairA)))) consumedA_ += abi.decode(logs_[i_].data, (uint256));
                if (logs_[i_].topics[1] == bytes32(uint256(uint160(pairB)))) consumedB_ += abi.decode(logs_[i_].data, (uint256));
            }
        }
        assertEq(consumedA_, a_ - refundA_, "actual pair input equals pre-conversion preview");
        assertEq(consumedB_, b_ - refundB_, "actual other input equals pre-conversion preview");
        assertEq(minted_, expected_, "mint uses the pre-conversion processed anchor payment");
        assertEq(IERC20(detf).totalSupply(), minted_);
        assertEq(IERC20(migration.hook()).balanceOf(address(bonds)), lp_);
        assertGt(lp_, 0);
        assertTrue(migration.isReserveLive());
        assertEq(receipt.totalSupply(), 0);
        assertEq(migration.independentAllocation(address(this)).configurationId, bytes32(0));
        assertFalse(migration.independentIssuance(address(this)).issued);
        assertEq(migration.independentIssuance(address(this)).credit, 0);
        assertEq(IERC20(pairA).allowance(detf, se0), 0);
        assertEq(IERC20(pairB).allowance(detf, se1), 0);
        assertEq(migration.migrationDonationInventory(IERC20(pairA)), IERC20(pairA).balanceOf(detf));
        assertEq(migration.migrationDonationInventory(IERC20(pairB)), IERC20(pairB).balanceOf(detf));
        assertLt(IERC20(pairA).balanceOf(detf), aBefore_);
        assertLt(IERC20(pairB).balanceOf(detf), bBefore_);
    }

}

contract MigrationGenesisCapitalTest is MigrationGenesisCapitalBase {
    function test_F1_historicalUnderfundingRejectsAtomically() public {
        assertGt(_minimumOther(0), 1 ether);
        _reject(100 ether, 1 ether, 0);
    }

    function test_F1_oneNativeUnitBelowMinimumRejectsAtomically() public {
        _reject(100 ether, _minimumOther(0) - 1, 0);
    }

    function test_F1_alternateAnchorRejectsUnderfundedFirstLeg() public {
        _reject(_minimumOther(1) - 1, 100 ether, 1);
    }

    function test_F1_equalityAcceptsCanonicalMinimum() public { _accept(100 ether, _minimumOther(0), 0); }
    function test_F1_oneUnitExcessRemainsValidDonation() public { _accept(100 ether, _minimumOther(0) + 1, 0); }
    function test_F1_alternateAnchorEqualityAccepts() public { _accept(_minimumOther(1), 100 ether, 1); }

    function test_F1_shareAnchorUsesPreconversionPairEquivalent() public {
        IERC20(pairA).approve(se0, 100 ether);
        (uint256 shares_,) = IStandardExchangeIn(se0).exchangeIn(
            IERC20(pairA), 100 ether, IERC20(se0), 1, address(this), false, block.timestamp
        );
        (uint256 equivalent_,) = IStandardExchangeIn(se0).previewExchangeIn(IERC20(se0), shares_, IERC20(pairA));
        uint256[] memory creation_ = migration.creationPairPerDetfWad();
        assertEq(creation_[0], creation_[1]);
        uint256 expected_ = _expectedMint(pairA, equivalent_);
        IERC20(se0).approve(detf, shares_);
        IERC20[] memory tokens_ = new IERC20[](2);
        tokens_[0] = IERC20(se0); tokens_[1] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = shares_; amounts_[1] = 100 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp);
        Migration.GenesisLeg[] memory legs_ = _legs(shares_, 100 ether);
        legs_[0].token = IERC20(se0);
        // Re-read after donation: booking cannot mutate the underlying SE book.
        assertEq(IUniswapV4DetfSelfCall(detf).peekPairEq(se0, se0, shares_), equivalent_);
        vm.prank(migrationOwner);
        (uint256 minted_, uint256 lp_) = allocation.bootstrapMigrationReserve(legs_, 0, 1, block.timestamp);
        assertEq(minted_, expected_);
        assertEq(IERC20(detf).totalSupply(), expected_);
        assertEq(IERC20(migration.hook()).balanceOf(address(bonds)), lp_);
        assertEq(migration.migrationDonationInventory(IERC20(se0)), IERC20(se0).balanceOf(detf));
        assertEq(IERC20(se0).allowance(detf, migration.hook()), 0);
    }
}

/// @notice Canonical native-six other-leg boundary, with real V3 SE and reserve conversion.
contract MigrationGenesisCapitalDecimalsTest is MigrationGenesisCapitalBase {
    function _deployContributionFixture() internal override returns (address) {
        return create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "contracts/test/stubs/MintableERC20Decimals.sol:MintableERC20Decimals"),
            abi.encode("External six decimal contribution", "SIX", uint8(6)), keccak256("migration.six")
        );
    }

    function _seedMigrationPool(IUniswapV3Pool pool_, bytes32 salt_) internal override {
        Univ3LiquiditySeeder seeder_ = Univ3LiquiditySeeder(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4DetfProductionSeDeployLib.sol:Univ3LiquiditySeeder"),
            "", salt_
        ));
        // Fund rounded native debts, not nominal human amounts: a Q96 price
        // below one can require an extra token0 unit after rounding.
        uint128 liquidity_ = uint128(
            pool_.token0() == pairB || pool_.token1() == pairB ? 2000e12 : 2000 ether
        );
        (uint160 price_,,,,,,) = pool_.slot0();
        uint160 lower_ = TickMath.getSqrtRatioAtTick(TickMath.minUsableTick(pool_.tickSpacing()));
        uint160 upper_ = TickMath.getSqrtRatioAtTick(TickMath.maxUsableTick(pool_.tickSpacing()));
        IERC20(pool_.token0()).transfer(
            address(seeder_), SqrtPriceMath.getAmount0Delta(price_, upper_, liquidity_, true)
        );
        IERC20(pool_.token1()).transfer(
            address(seeder_), SqrtPriceMath.getAmount1Delta(lower_, price_, liquidity_, true)
        );
        seeder_.seedFullRange(pool_, liquidity_);
    }

    function test_F1_sixDecimalOneSidedUnrepresentableOutputFullyRefunds() public {
        (uint256 quote_, uint256 quotedRefund_) =
            IStandardExchangeIn(se1).previewExchangeIn(IERC20(pairB), 100e6, IERC20(se1));
        assertEq(quote_, 0);
        assertEq(quotedRefund_, 100e6);
        IERC20(pairB).approve(se1, 0);
        bytes32 before_ = _capitalState();
        IERC20(pairB).approve(se1, 100e6);
        (uint256 shares_, uint256 refund_) = IStandardExchangeIn(se1).exchangeIn(
            IERC20(pairB), 100e6, IERC20(se1), 0, address(this), false, block.timestamp
        );
        IERC20(pairB).approve(se1, 0);
        assertEq(shares_, 0);
        assertEq(refund_, 100e6);
        assertEq(_capitalState(), before_, "full refund cannot book swapped-output dust");
        _reject(100 ether, 100e6, 0);
    }

    /// @dev A real two-token bundle avoids the unsupported one-sided SIX entry.
    /// Search SE shares by their independently previewed native-six redemption.
    function _sixDecimalBoundary() internal returns (Migration.GenesisLeg[] memory legs_) {
        address[] memory tokens_ = IBasicVault(se1).vaultTokens();
        uint256[] memory amounts_ = new uint256[](2);
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            amounts_[i_] = tokens_[i_] == pairB ? 100e6 : 100 ether;
            IERC20(tokens_[i_]).approve(se1, amounts_[i_]);
        }
        uint256 shares_;
        {
            (uint256 quote_, uint256[] memory quotedRefunds_) =
                IStandardExchangeBundleIn(se1).previewExchangeBundleInForSingleOut(amounts_, se1);
            uint256[] memory refunds_;
            (shares_, refunds_) = IStandardExchangeBundleIn(se1).exchangeBundleInForSingleOut(
                amounts_, se1, quote_, address(this), false, block.timestamp
            );
            assertGt(shares_, 0);
            assertEq(shares_, quote_);
            assertEq(refunds_, quotedRefunds_);
        }
        uint256 required_ = _requiredOther(IERC20(pairA), 100 ether, pairB);
        (, uint256 refundA_) = IStandardExchangeIn(se0).previewExchangeIn(IERC20(pairA), 100 ether, IERC20(se0));
        assertEq(required_, _expectedMint(pairA, 100 ether - refundA_) / 1e3);
        (uint256 equivalent_,) = IStandardExchangeIn(se1).previewExchangeIn(IERC20(se1), shares_, IERC20(pairB));
        assertGe(equivalent_, required_, "bundle funds the native-six boundary");
        uint256 low_ = 1;
        uint256 high_ = shares_;
        while (low_ < high_) {
            uint256 mid_ = low_ + (high_ - low_) / 2;
            (equivalent_,) = IStandardExchangeIn(se1).previewExchangeIn(IERC20(se1), mid_, IERC20(pairB));
            if (equivalent_ >= required_) high_ = mid_;
            else low_ = mid_ + 1;
        }
        (equivalent_,) = IStandardExchangeIn(se1).previewExchangeIn(IERC20(se1), high_, IERC20(pairB));
        assertEq(equivalent_, required_, "exact native-six counterpart");
        (equivalent_,) = IStandardExchangeIn(se1).previewExchangeIn(IERC20(se1), high_ - 1, IERC20(pairB));
        assertEq(equivalent_, required_ - 1, "predecessor is one native-six unit short");
        IERC20[] memory donated_ = new IERC20[](2);
        donated_[0] = IERC20(pairA); donated_[1] = IERC20(se1);
        amounts_[0] = 100 ether; amounts_[1] = shares_;
        IERC20(se1).approve(detf, shares_);
        migration.donateMigrationCapital(donated_, amounts_, 0, 0, block.timestamp);
        legs_ = _legs(100 ether, high_);
        legs_[1].token = IERC20(se1);
    }

    function test_F1_sixDecimalMinimumRejectsOneNativeUnitShort() public {
        Migration.GenesisLeg[] memory legs_ = _sixDecimalBoundary();
        --legs_[1].amount;
        bytes32 before_ = _capitalState();
        vm.prank(migrationOwner);
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidGenesisLeg.selector, pairB));
        allocation.bootstrapMigrationReserve(legs_, 0, 1, block.timestamp);
        assertEq(_capitalState(), before_, "native-six rejection preserves all capital and allowances");
    }

    function test_F1_sixDecimalMinimumEqualityAccepts() public {
        Migration.GenesisLeg[] memory legs_ = _sixDecimalBoundary();
        uint256 sharesBefore_ = IERC20(se1).balanceOf(detf);
        (, uint256 refund_) = IStandardExchangeIn(se0).previewExchangeIn(IERC20(pairA), 100 ether, IERC20(se0));
        uint256 expected_ = _expectedMint(pairA, 100 ether - refund_);
        vm.prank(migrationOwner);
        (uint256 minted_, uint256 lp_) = allocation.bootstrapMigrationReserve(legs_, 0, 1, block.timestamp);
        assertEq(minted_, expected_);
        assertEq(IERC20(detf).totalSupply(), expected_);
        assertEq(migration.migrationBootstrapSelfMinted(), expected_);
        assertEq(IERC20(migration.hook()).balanceOf(address(bonds)), lp_);
        assertGt(lp_, 0);
        assertTrue(migration.isReserveLive());
        assertEq(receipt.totalSupply(), 0);
        assertEq(migration.independentAllocation(address(this)).configurationId, bytes32(0));
        assertFalse(migration.independentIssuance(address(this)).issued);
        assertEq(migration.independentIssuance(address(this)).credit, 0);
        assertEq(IERC20(pairA).allowance(detf, se0), 0);
        assertEq(IERC20(pairB).allowance(detf, se1), 0);
        assertEq(IERC20(se1).allowance(detf, migration.hook()), 0);
        assertEq(migration.migrationDonationInventory(IERC20(pairA)), IERC20(pairA).balanceOf(detf));
        assertEq(migration.migrationDonationInventory(IERC20(pairB)), IERC20(pairB).balanceOf(detf));
        assertEq(migration.migrationDonationInventory(IERC20(se1)), IERC20(se1).balanceOf(detf));
        assertEq(IERC20(pairA).balanceOf(detf), refund_, "only actual anchor refunds remain");
        assertLt(IERC20(se1).balanceOf(detf), sharesBefore_, "real donated shares enter the reserve");
    }
}
