// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {Univ3LiquiditySeeder} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {TestBase_UniswapV4DetfMigration} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol";
import {IMigrationLegacyNft, IMigrationWeightedNft, IMigrationEarlierNft} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyNft.sol";

interface IWeightedClaims {
    function claimPrincipal(uint256 id_, address recipient_) external returns (uint256);
}
interface IEarlierClaims {
    function claimRewards(uint256 id_, address recipient_) external returns (uint256);
    function convertToAssets(uint256 shares_) external view returns (uint256);
}
interface IEarlierParent {
    function sellPositionToDetfNft(uint256 id_, address recipient_) external returns (uint256);
    function closeBondMature(uint256 id_, uint256[] calldata minimums_, address recipient_, uint256 deadline_)
        external returns (uint256[] memory);
}

/// @notice Real pinned legacy bytecode plus a fresh genuine manager-registry Migration deployment.
/// @dev Large local contribution liquidity is real fixture funding, not legacy/SUT storage mutation.
abstract contract MigrationNftForkBase is TestBase_UniswapV4DetfMigration {
    address internal constant WEIGHTED = 0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E;
    address internal constant EARLIER = 0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391;
    address internal constant EARLIER_PARENT = 0xaf0E1967c8F755c747615c5427108Bc549CA1122;
    uint256 internal constant PIN = 108944663;
    bytes32 internal constant PIN_HASH = 0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733;

    function setUp() public virtual override {
        vm.createSelectFork("robinhood_mainnet_alchemy", PIN);
        assertEq(block.chainid, 4663);
        string memory header_ = vm.rpcJson("eth_getBlockByNumber", '["0x67e5d17",false]');
        // Orbit exposes the header's L1 number through BLOCKNUMBER; fork selection uses the L2 number.
        assertEq(vm.parseJsonString(header_, ".number"), "0x67e5d17");
        assertEq(vm.parseJsonString(header_, ".l1BlockNumber"), "0x19256ab");
        assertEq(block.number, 26367659);
        assertEq(vm.parseJsonBytes32(header_, ".hash"), PIN_HASH);
        assertEq(vm.parseJsonBytes32(header_, ".stateRoot"),
            0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071);
        _bindSources();
        super.setUp();
        _fundHistoricalBook();
    }

    function _bindSources() private view {
        bytes32 proxy_ = 0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601;
        assertEq(WEIGHTED.codehash, proxy_);
        assertEq(EARLIER.codehash, proxy_);
        address ownerFacet_ = 0xde5a691CEFE1830e8Ff2b65F6657738b0d9B9279;
        address weightedFacet_ = 0x3a07364eabA092472d40F0e6788b8891A31faD4D;
        address earlierFacet_ = 0x3AB85813785b43B864F9C171F7ac97d6B76c459b;
        assertEq(ownerFacet_.codehash, 0xf709b5311471ef0b02cf7ddaa8f48b9da30647ab9958a3efde1813e5ac4337b8);
        assertEq(weightedFacet_.codehash, 0x325a3b9bf3e616386e03d2a14d0a1fb29820f104a5f433d0b08a88dbdd0bef52);
        assertEq(earlierFacet_.codehash, 0xe44c05ff19808e8e7096c7e470cb1d40ddaf057f4e53818f1e749621d3632027);
        assertEq(IDiamondLoupe(WEIGHTED).facetAddress(IMigrationLegacyNft.ownerOf.selector), ownerFacet_);
        assertEq(IDiamondLoupe(EARLIER).facetAddress(IMigrationLegacyNft.ownerOf.selector), ownerFacet_);
        assertEq(IDiamondLoupe(WEIGHTED).facetAddress(IMigrationWeightedNft.positionOf.selector), weightedFacet_);
        assertEq(IDiamondLoupe(EARLIER).facetAddress(IMigrationEarlierNft.getPosition.selector), earlierFacet_);
        assertEq(IDiamondLoupe(WEIGHTED).facetAddress(IMigrationLegacyNft.safeTransferFrom.selector), weightedFacet_);
        assertEq(IDiamondLoupe(EARLIER).facetAddress(IMigrationLegacyNft.safeTransferFrom.selector), earlierFacet_);
        assertEq(IDiamondLoupe(WEIGHTED).facetAddress(IERC721.approve.selector), ownerFacet_);
        assertEq(IDiamondLoupe(EARLIER).facetAddress(IERC721.approve.selector), ownerFacet_);
    }

    function _seedMigrationPool(IUniswapV3Pool pool_, bytes32 salt_) internal virtual override {
        vm.deal(address(this), 1e15 ether);
        address[2] memory tokens_ = [pool_.token0(), pool_.token1()];
        Univ3LiquiditySeeder seeder_ = Univ3LiquiditySeeder(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4DetfProductionSeDeployLib.sol:Univ3LiquiditySeeder"),
            "", salt_
        ));
        for (uint256 i_; i_ < 2; ++i_) {
            if (tokens_[i_] == pairA) IWETH(pairA).deposit{value: 1e12 ether}();
            else SimpleMintableERC20(tokens_[i_]).mint(address(this), 1e12 ether);
            IERC20(tokens_[i_]).transfer(address(seeder_), 1e12 ether);
        }
        seeder_.seedFullRange(pool_, uint128(1e12 ether));
    }

    function _fundHistoricalBook() internal virtual {
        IWETH(pairA).deposit{value: 1e8 ether}();
        SimpleMintableERC20(pairB).mint(address(this), 1e8 ether);
        IERC20(pairA).approve(address(migration), type(uint256).max);
        IERC20(pairB).approve(address(migration), type(uint256).max);
        IERC20[] memory tokens_ = new IERC20[](2);
        tokens_[0] = IERC20(pairA); tokens_[1] = IERC20(pairB);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 1e8 ether; amounts_[1] = 1e8 ether;
        migration.donateMigrationCapital(tokens_, amounts_, 0, 0, block.timestamp);
        Migration.GenesisLeg[] memory legs_ = new Migration.GenesisLeg[](2);
        legs_[0] = Migration.GenesisLeg(IERC20(pairA), amounts_[0], 1);
        legs_[1] = Migration.GenesisLeg(IERC20(pairB), amounts_[1], 1);
        vm.startPrank(migrationOwner);
        allocation.bootstrapMigrationReserve(legs_, 0, 1, block.timestamp);
        allocation.captureMigrationSnapshot();
        vm.stopPrank();
    }

    /// @dev Exact phase01 receipt joins: weighted purchase receipts and earlier NewLock/direct inputs.
    /// No current balance, effective reward weight or routed intermediate is used as contribution.
    function _original(address collection_, uint256 id_)
        internal pure returns (Migration.NftEntitlementInput memory a_)
    {
        a_.collection = collection_; a_.tokenId = id_; a_.contributionsKnown = true;
        if (collection_ == WEIGHTED) {
            if (id_ == 3) {
                a_.originalWallet = address(bytes20(hex"72bea6fa3e68ef18c87d045aac7c4aa5249d933b"));
                a_.originalUnits = 3772281649;
                a_.originalEth = 999999000000000;
                a_.originalDtf = 362893857600000000000;
                a_.evidenceId = 0x140c83d7c5a5170424fe13788194f21d1f30694bc166134ae486681a1fa3c624;
            } else if (id_ == 4) {
                a_.originalWallet = address(bytes20(hex"ec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8"));
                a_.originalUnits = 281387179;
                a_.originalEth = 30000000000000000;
                a_.evidenceId = 0x2595bbc003c11cf938ea4da468676ca5eb46241b6bdc4e3cc0ae108df7211bfe;
            } else if (id_ == 26) {
                a_.originalWallet = address(bytes20(hex"c379feb4182211abe71a34858265e4bf5ff35e06"));
                a_.originalUnits = 56299; a_.originalDtf = 50 ether;
                a_.evidenceId = 0x03a24910340df937a7597382909e015284f60432f266e63ffc163dc559255e0d;
            } else if (id_ == 32) {
                a_.originalWallet = address(bytes20(hex"4dfebb21d855115d4019819393e514977e490e5d"));
                a_.originalUnits = 54436459; a_.originalDtf = 56017714220190058289217;
                a_.evidenceId = 0x66c1011955675c6927bf67fd64935a147dec659a1791e8ee86ea5cacfdd70914;
            } else if (id_ == 25) {
                a_.originalWallet = address(bytes20(hex"f0f80dd7e46ee7c3e7bd68f806bab1875f069530"));
                a_.originalUnits = 53274997; a_.originalDtf = 50000 ether;
                a_.evidenceId = 0xbaf5a8671bb876febd555fdfc95ad53289598eb90e0cdb535c5d54a6bb533970;
            } else revert("unlisted weighted fixture");
        } else if (collection_ == EARLIER) {
            if (id_ == 3) {
                a_.originalWallet = address(bytes20(hex"495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed"));
                a_.originalUnits = 562524912595035608166; a_.originalEth = 2 ether;
                a_.evidenceId = 0xc0a74f69a4a58540168c070968bb8f2d13759195e4ccabfe469ba3ad3d3d1c75;
            } else if (id_ == 4) {
                a_.originalWallet = address(bytes20(hex"230f95db9644c5b3608ba676d18426d03e435b1d"));
                a_.originalUnits = 2281854312954086546; a_.originalDtf = 7215852540309913726431;
                a_.evidenceId = 0x0fc1a71638d581251317d0d83a248e1cc3317af73b07205120083ab32eaf8fc4;
            } else if (id_ == 12) {
                a_.originalWallet = address(bytes20(hex"52f5e84f5ef47a9a0ee998856ec2ee5c27ea8497"));
                a_.originalUnits = 47848240999749918187208884; a_.originalDtf = 75081277576132719227716;
                a_.evidenceId = 0x75555879247aa52ce308f86f50f9f3330ccdef438072726a63d55d5ca915ab24;
            } else revert("unlisted earlier fixture");
        } else revert("unlisted source fixture");
    }

    function _configureNft(address collection_, uint256 id_) internal returns (uint256 credit_) {
        Migration.NftEntitlementInput[] memory a_ = new Migration.NftEntitlementInput[](1);
        a_[0] = _original(collection_, id_);
        vm.prank(migrationOwner);
        allocation.configureNftEntitlements(a_);
        return migration.nftEntitlement(collection_, id_).credit;
    }

    function _surrender(address collection_, uint256 id_) internal returns (uint256 newId_, uint256 credit_) {
        address holder_ = IERC721(collection_).ownerOf(id_);
        assertEq(holder_, migration.nftEntitlement(collection_, id_).original.originalWallet);
        vm.startPrank(holder_);
        IERC721(collection_).approve(detf, id_);
        (newId_, credit_) = migration.surrenderMigrationNft(collection_, id_, 1, block.timestamp);
        vm.stopPrank();
        assertEq(IERC721(collection_).ownerOf(id_), detf);
        assertEq(IERC721(collection_).getApproved(id_), address(0));
        assertFalse(IERC721(collection_).isApprovedForAll(detf, holder_));
        assertEq(IERC721(address(bonds)).ownerOf(newId_), holder_);
        assertEq(bonds.positionOf(newId_).principal, credit_);
        assertEq(bonds.positionOf(newId_).startTimestamp, block.timestamp);
        assertEq(bonds.positionOf(newId_).vestingDuration, 90 days);
        assertTrue(bonds.isMigrationPosition(newId_));
        assertEq(IERC20(detf).allowance(detf, address(bonds)), 0);
        assertEq(IERC20(detf).allowance(address(bonds), address(receipt)), 0);
    }

    /// @dev A real holder transaction returns a transferred fixture; it does not rewrite its entitlement.
    function _returnToOriginal(address collection_, uint256 id_) internal {
        address holder_ = IERC721(collection_).ownerOf(id_);
        address original_ = migration.nftEntitlement(collection_, id_).original.originalWallet;
        vm.prank(holder_);
        IERC721(collection_).transferFrom(holder_, original_, id_);
    }

    function _assertNotConsumed(address collection_, uint256 id_, address holder_, uint256 supply_) internal view {
        assertEq(IERC721(collection_).ownerOf(id_), holder_);
        assertFalse(migration.nftSurrender(collection_, id_).consumed);
        assertEq(migration.nftCustody(collection_, id_).collection, address(0));
        assertEq(IERC20(detf).totalSupply(), supply_);
        assertEq(receipt.stakingState().totalGons, 0);
        assertEq(IERC20(detf).balanceOf(address(receipt)), 0);
        assertEq(IERC20(detf).allowance(detf, address(bonds)), 0);
    }
}
