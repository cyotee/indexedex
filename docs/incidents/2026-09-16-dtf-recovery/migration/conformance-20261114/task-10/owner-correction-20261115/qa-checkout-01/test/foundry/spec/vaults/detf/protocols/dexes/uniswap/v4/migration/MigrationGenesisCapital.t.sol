// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
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

    /// @dev Whole externally observable capital/custody state, including both SEs.
    function _capitalState() internal view returns (bytes32 state_) {
        address[6] memory tokens_ = [pairA, pairB, se0, se1, detf, migration.hook()];
        address[7] memory holders_ = [address(this), detf, address(bonds), address(receipt), se0, se1, migration.hook()];
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
        assertEq(minted_, 100e9);
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
        assertEq(_requiredOther(IERC20(pairA), 100 ether, pairB), 100 ether);
        _reject(100 ether, 1 ether, 0);
    }

    function test_F1_oneNativeUnitBelowMinimumRejectsAtomically() public {
        uint256 required_ = _requiredOther(IERC20(pairA), 100 ether, pairB);
        _reject(100 ether, required_ - 1, 0);
    }

    function test_F1_alternateAnchorRejectsUnderfundedFirstLeg() public {
        assertEq(_requiredOther(IERC20(pairB), 100 ether, pairA), 100 ether);
        _reject(100 ether - 1, 100 ether, 1);
    }

    function test_F1_equalityAcceptsCanonicalMinimum() public { _accept(100 ether, 100 ether, 0); }
    function test_F1_oneUnitExcessRemainsValidDonation() public { _accept(100 ether, 100 ether + 1, 0); }
    function test_F1_alternateAnchorEqualityAccepts() public { _accept(100 ether, 100 ether, 1); }

    function test_F1_shareAnchorUsesPreconversionPairEquivalent() public {
        IERC20(pairA).approve(se0, 100 ether);
        (uint256 shares_,) = IStandardExchangeIn(se0).exchangeIn(
            IERC20(pairA), 100 ether, IERC20(se0), 1, address(this), false, block.timestamp
        );
        uint256 equivalent_ = IUniswapV4DetfSelfCall(detf).peekPairEq(se0, se0, shares_);
        uint256[] memory creation_ = migration.creationPairPerDetfWad();
        assertEq(creation_[0], creation_[1]);
        uint256 expected_ = equivalent_ * 1e9 / creation_[0];
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
        IERC20(pool_.token0()).transfer(address(seeder_), 2000 ether);
        IERC20(pool_.token1()).transfer(address(seeder_), 2000 ether);
        // L is the geometric mean of native inventories, not a human-token quantity.
        seeder_.seedFullRange(pool_, uint128(
            pool_.token0() == pairB || pool_.token1() == pairB ? 1000e12 : 1000 ether
        ));
    }

    function test_F1_sixDecimalMinimumRejectsOneNativeUnitShort() public {
        uint256 required_ = _requiredOther(IERC20(pairA), 100 ether, pairB);
        assertEq(required_, 100e6);
        _reject(100 ether, required_ - 1, 0);
    }

    function test_F1_sixDecimalMinimumEqualityAccepts() public { _accept(100 ether, 100e6, 0); }
}
