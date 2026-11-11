// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {MigrationNftForkBase} from "./MigrationNftForkBase.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {MigrationLegacyRecoveryLib as Legacy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol";
import {
    IMigrationWeightedClaims, IMigrationWeightedReceipt, IMigrationLegacyExchange,
    IMigrationEarlierClaims, IMigrationEarlierSale, IMigrationEarlierReceipt
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol";

abstract contract MigrationRecoveryForkBase is MigrationNftForkBase {
    Recovery internal recovery;
    event RecoveryGas(bytes32 indexed stage, uint256 selected, uint256 custodyPopulation, uint256 gasUsed);

    function setUp() public virtual override {
        super.setUp();
        recovery = Recovery(detf);
        _bindRecoverySources();
    }

    function _bindRecoverySources() internal view {
        bytes32 proxy_ = 0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601;
        assertEq(Legacy.WEIGHTED_RECEIPT.codehash, proxy_);
        assertEq(Legacy.WEIGHTED_DETF.codehash, proxy_);
        assertEq(Legacy.EARLIER_RECEIPT.codehash, proxy_);
        assertEq(Legacy.EARLIER_DETF.codehash, proxy_);
        address stakingFacet_ = 0xB7581fe833a2B2380DD786B345D61FFB734D36EB;
        address exchangeFacet_ = 0x4886F86CD0DFFf8b8A836F858925eD4de3a2b291;
        address earlierFacet_ = 0x8333749Cc7b1f66b5be568257d362aA749497Cf0;
        address earlierReceiptFacet_ = 0x25E611FB63Eb904776678286EF5cbe2a931B4f9A;
        assertEq(stakingFacet_.codehash, 0xcb505aba37d6ad909d8fb33dbf0091be50c9dd37f43e5df506bd240fc711b361);
        assertEq(exchangeFacet_.codehash, 0x1eadaa06571b1cca173491d149bab9b07d5d1b9dc83d268654e49d3179b1a460);
        assertEq(earlierFacet_.codehash, 0x5b5f12902a0baeb235ec2dc91794c425a0c60a439a7d9070cb1abb17b094389d);
        assertEq(earlierReceiptFacet_.codehash, 0x31151be4bf8ff8e79f448872f9a0a5c37ee413ce7d2b15206f2debcc59d86ccc);
        assertEq(IDiamondLoupe(WEIGHTED).facetAddress(IMigrationWeightedClaims.claimBond.selector),
            0x3a07364eabA092472d40F0e6788b8891A31faD4D);
        assertEq(IDiamondLoupe(WEIGHTED).facetAddress(IMigrationWeightedClaims.claimPrincipal.selector),
            0x3a07364eabA092472d40F0e6788b8891A31faD4D);
        assertEq(IDiamondLoupe(WEIGHTED).facetAddress(IMigrationWeightedClaims.claimRewards.selector),
            0x3a07364eabA092472d40F0e6788b8891A31faD4D);
        assertEq(IDiamondLoupe(Legacy.WEIGHTED_RECEIPT).facetAddress(IMigrationLegacyExchange.exchangeIn.selector), stakingFacet_);
        assertEq(IDiamondLoupe(Legacy.WEIGHTED_RECEIPT).facetAddress(IMigrationWeightedReceipt.gonsOf.selector), stakingFacet_);
        assertEq(IDiamondLoupe(Legacy.WEIGHTED_RECEIPT).facetAddress(IMigrationWeightedReceipt.stakingState.selector), stakingFacet_);
        assertEq(IDiamondLoupe(Legacy.WEIGHTED_DETF).facetAddress(IMigrationLegacyExchange.exchangeIn.selector), exchangeFacet_);
        assertEq(IDiamondLoupe(Legacy.EARLIER_DETF).facetAddress(IMigrationEarlierSale.sellPositionToDetfNft.selector), earlierFacet_);
        assertEq(IDiamondLoupe(Legacy.EARLIER_RECEIPT).facetAddress(IMigrationEarlierReceipt.sharesOf.selector), earlierReceiptFacet_);
        assertEq(IDiamondLoupe(EARLIER).facetAddress(IMigrationEarlierClaims.claimRewards.selector),
            0x3AB85813785b43B864F9C171F7ac97d6B76c459b);
        address tokenFacet_ = 0x1d17acA0e0717d90cea916372070a1BE4652223F;
        assertEq(tokenFacet_.codehash, 0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50);
        assertEq(IDiamondLoupe(Legacy.WEIGHTED_DETF).facetAddress(IERC20.approve.selector), tokenFacet_);
        assertEq(IDiamondLoupe(Legacy.EARLIER_DETF).facetAddress(IERC20.balanceOf.selector), tokenFacet_);
    }

    function _take(address collection_, uint256 id_) internal returns (uint256 bond_) {
        _configureNft(collection_, id_);
        (bond_,) = _surrender(collection_, id_);
    }

    function _step(Recovery.Stage stage_, uint256 id_, uint256 amount_, uint256 minimum_)
        internal pure returns (Recovery.Step[] memory steps_)
    {
        steps_ = new Recovery.Step[](1);
        steps_[0] = Recovery.Step(stage_, id_, amount_, minimum_);
    }

    function _run(Recovery.Stage stage_, uint256 id_, uint256 amount_, uint256 minimum_) internal {
        Recovery.Step[] memory steps_ = _step(stage_, id_, amount_, minimum_);
        vm.prank(migrationOwner);
        recovery.recoverMigrationNfts(steps_, block.timestamp);
    }

    function _protected(uint256 bond_) internal view returns (bytes32) {
        return keccak256(abi.encode(
            bonds.positionOf(bond_), IERC721(address(bonds)).ownerOf(bond_),
            IERC20(detf).totalSupply(), IERC20(detf).balanceOf(address(receipt)),
            receipt.stakingState(), receipt.gonsOf(address(bonds)),
            receipt.gonsOf(address(stakingSy)), IERC20(detf).balanceOf(address(rawSy)),
            IERC20(detf).balanceOf(detf), migration.migrationBootstrapSelfMinted(),
            migration.migrationDonationInventory(IERC20(pairA)),
            migration.migrationDonationInventory(IERC20(pairB))
        ));
    }

    function _weightedAmount() internal view returns (uint256) {
        return recovery.migrationRecoveryInventory(Legacy.WEIGHTED_RECEIPT);
    }
}
