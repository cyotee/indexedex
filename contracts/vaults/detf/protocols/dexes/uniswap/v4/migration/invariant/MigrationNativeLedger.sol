// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IUniswapV4DetfMigration as Migration} from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationStakedDETF as MigrationReceipt} from "../claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {IUniswapV4DetfMigrationBondNFTVault as Bonds} from "../bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";
import {DETFFundedStakingMath as BondTypes} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";

/// @notice Independent integer ledger for the bounded native state machine.
/// @dev No SUT math library is used. BondTypes supplies ABI structs only.
abstract contract MigrationNativeLedger is Test {
    struct Seed {
        Migration parent;
        address registry;
        address registryOwner;
        address owner;
        address pair;
        address otherPair;
        address se;
        address isolated;
        bytes32 isolatedBook;
        uint256 bootstrapSupply;
        uint256 paidPrincipal;
        uint256 paidReward;
        uint256 paidSelf;
        uint256 feeFraction;
        uint256 creatorFraction;
        uint256 firstCredit;
        uint256 secondCredit;
        uint256[3] quotes;
    }
    struct Position {
        uint256 id;
        address holder;
        uint256 principal;
        uint256 claimed;
        uint256 gons;
        uint256 start;
        bool cliff;
        bool retired;
    }
    Migration public parent;
    MigrationReceipt public staking;
    Bonds public child;
    Seed internal seed;
    Position[] internal positions;
    IStakedDETF.StakingState internal book;
    mapping(address => uint256) internal walletGons;
    address[8] internal actors;
    uint256 internal expectedSupply;
    uint256 internal roleGons;
    uint256 internal feeGons;
    uint256 internal creatorGons;
    uint256 internal feeFraction;
    uint256 internal creatorFraction;
    bytes32 internal snapshotHash;
    bytes32 internal snapshotId;
    address public currentOwner;
    bool public active;
    uint256[3] internal frozenQuotes;
    uint256 public successes;
    uint256 public rejections;
    uint256 public zeroClaims;
    uint256 public laterPaidBonds;
    uint256 public laterFundedRewards;
    mapping(bytes4 => uint256) public calls;
    event Action(bytes4 indexed selector, uint256 successes, uint256 rejections);

    constructor(Seed memory s_) {
        seed = s_;
        parent = s_.parent;
        staking = MigrationReceipt(parent.rebasingClaimToken());
        child = Bonds(parent.bondNftVault());
        currentOwner = s_.owner;
        feeFraction = s_.feeFraction;
        creatorFraction = s_.creatorFraction;
        frozenQuotes = s_.quotes;
        snapshotHash = keccak256(abi.encode(parent.migrationSnapshot()));
        snapshotId = parent.migrationSnapshot().id;
        for (uint256 i_; i_ < 8; ++i_) actors[i_] = address(uint160(0x2400 + i_));
        book.gonsPerUnit = 1e36;
        _recordPosition(3, actors[0], s_.firstCredit, true);
        _recordPosition(4, actors[1], s_.secondCredit, true);
        _recordPosition(5, s_.owner, s_.paidPrincipal, false);
        expectedSupply = s_.bootstrapSupply + s_.firstCredit + s_.secondCredit
            + s_.paidPrincipal + s_.paidSelf + s_.paidReward;
        _fundReward(s_.paidReward);
    }

    function _recordPosition(uint256 id_, address holder_, uint256 principal_, bool cliff_) internal {
        uint256 gons_ = principal_ * book.gonsPerUnit;
        positions.push(Position(id_, holder_, principal_, 0, gons_, block.timestamp, cliff_, false));
        book.totalGons += gons_;
        book.accountedBacking += principal_;
        _topUp();
    }

    function _topUp() internal {
        uint256 total_ = Math.mulDiv(book.totalGons, 1e18, 1e18 - feeFraction - creatorFraction);
        uint256 f_ = Math.mulDiv(total_, feeFraction, 1e18);
        uint256 c_ = Math.mulDiv(total_, creatorFraction, 1e18);
        if (f_ > book.feeWeight) book.feeWeight = f_;
        if (c_ > book.creatorWeight) book.creatorWeight = c_;
    }

    function _fundReward(uint256 reward_) internal {
        uint256 rps_ = Math.mulDiv(
            reward_ + book.allocationDust, 1e54, book.totalGons + book.feeWeight + book.creatorWeight
        );
        uint256 ordinary_ = Math.mulDiv(book.totalGons, rps_, 1e54);
        uint256 fee_ = Math.mulDiv(book.feeWeight, rps_, 1e54);
        uint256 creator_ = Math.mulDiv(book.creatorWeight, rps_, 1e54);
        book.allocationDust = reward_ + book.allocationDust - ordinary_ - fee_ - creator_;
        uint256 before_ = book.totalGons / book.gonsPerUnit;
        uint256 target_ = before_ + ordinary_ + book.stakingDust;
        book.gonsPerUnit = (book.totalGons + target_ - 1) / target_;
        book.stakingDust = target_ - book.totalGons / book.gonsPerUnit;
        uint256 addedFee_ = fee_ * book.gonsPerUnit;
        uint256 addedCreator_ = creator_ * book.gonsPerUnit;
        if (active) {
            walletGons[IERC721(address(child)).ownerOf(1)] += addedFee_;
            walletGons[IERC721(address(child)).ownerOf(2)] += addedCreator_;
        } else {
            feeGons += addedFee_;
            creatorGons += addedCreator_;
            roleGons += addedFee_ + addedCreator_;
        }
        book.totalGons += addedFee_ + addedCreator_;
        book.accountedBacking += reward_;
        _topUp();
    }

    function _positionClaim(uint256 index_, bool reward_) internal {
        Position storage p_ = positions[index_];
        if (p_.retired) {
            vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", p_.id));
            child.positionOf(p_.id);
            ++rejections;
            return;
        }
        uint256 due_;
        if (reward_) due_ = p_.gons / book.gonsPerUnit - (p_.principal - p_.claimed);
        else {
            uint256 elapsed_ = block.timestamp - p_.start;
            uint256 vested_ = elapsed_ >= 90 days ? p_.principal
                : p_.cliff ? 0 : Math.mulDiv(p_.principal, elapsed_, 90 days);
            due_ = vested_ - p_.claimed;
        }
        uint256 before_ = staking.balanceOf(p_.holder);
        vm.prank(p_.holder);
        uint256 paid_ = reward_ ? child.claimRewards(p_.id, p_.holder) : child.claimPrincipal(p_.id, p_.holder);
        assertEq(paid_, due_, "independent claim amount");
        assertEq(staking.balanceOf(p_.holder) - before_, due_, "exact receipt delivery");
        p_.gons -= due_ * book.gonsPerUnit;
        if (!reward_) p_.claimed += due_;
        walletGons[p_.holder] += due_ * book.gonsPerUnit;
        if (p_.claimed == p_.principal && p_.gons < book.gonsPerUnit) {
            uint256 old_ = book.totalGons / book.gonsPerUnit;
            book.totalGons -= p_.gons;
            book.stakingDust += old_ - book.totalGons / book.gonsPerUnit;
            p_.gons = 0;
            p_.retired = true;
            _topUp();
        }
        if (paid_ == 0) ++zeroClaims;
        else ++successes;
    }

    /// @notice Every live bond, exact backing partition and independent expected index.
    function assertAccounting() public view {
        assertEq(abi.encode(staking.stakingState()), abi.encode(book), "complete independent staking ledger");
        assertEq(IERC20(address(parent)).totalSupply(), expectedSupply, "authorized supply only");
        assertEq(IERC20(address(parent)).balanceOf(address(staking)), book.accountedBacking, "actual funding");
        uint256 attributed_;
        for (uint256 i_; i_ < positions.length; ++i_) {
            Position memory p_ = positions[i_];
            if (p_.retired) {
                assertEq(IERC721(address(child)).ownerOf(p_.id), address(0), "retirement");
                continue;
            }
            BondTypes.BondPosition memory actual_ = child.positionOf(p_.id);
            assertEq(actual_.principal, p_.principal);
            assertEq(actual_.claimedPrincipal, p_.claimed);
            assertEq(actual_.stakingGons, p_.gons);
            assertEq(actual_.startTimestamp, p_.start);
            assertEq(actual_.vestingDuration, 90 days);
            assertEq(IERC721(address(child)).ownerOf(p_.id), p_.holder);
            assertGe(p_.gons / book.gonsPerUnit, p_.principal - p_.claimed, "principal solvency");
            if (p_.cliff && block.timestamp < p_.start + 90 days) {
                assertEq(p_.claimed, 0, "no principal before own cliff");
                assertEq(child.previewClaim(p_.id).principalDue, 0);
            }
            attributed_ += p_.gons;
        }
        assertEq(child.attributedBondGons(), attributed_);
        assertEq(staking.gonsOf(address(child)), attributed_);
        assertEq(staking.gonsOf(address(staking)), roleGons);
        for (uint256 i_; i_ < actors.length; ++i_) assertEq(staking.gonsOf(actors[i_]), walletGons[actors[i_]]);
        assertEq(staking.gonsOf(seed.owner), walletGons[seed.owner]);
        assertEq(staking.gonsOf(IERC721(address(child)).ownerOf(1)), walletGons[IERC721(address(child)).ownerOf(1)]);
        assertEq(staking.gonsOf(IERC721(address(child)).ownerOf(2)), walletGons[IERC721(address(child)).ownerOf(2)]);
        assertEq(book.totalGons / book.gonsPerUnit + book.allocationDust + book.stakingDust, book.accountedBacking);
    }

    /// @notice Current tracked position count includes later issues and actual ordinary purchases.
    function positionCount() external view returns (uint256) { return positions.length; }

    /// @notice Original clock from the ghost, including a retired position.
    function positionStart(uint256 index_) external view returns (uint256) { return positions[index_].start; }

    /// @notice Same actual second proxy/children are checked, never the mutable fixture hook member.
    function isolatedBook(address address_) public view returns (bytes32) {
        Migration m_ = Migration(address_);
        return keccak256(abi.encode(m_.owner(), m_.hook(), m_.rebasingClaimToken(), m_.bondNftVault(),
            m_.migrationSnapshot(), m_.independentAllocation(address(0x2499)),
            m_.independentIssuance(address(0x2499)), IERC20(address_).totalSupply(),
            MigrationReceipt(m_.rebasingClaimToken()).stakingState(), Bonds(m_.bondNftVault()).positionOf(3)));
    }

    function _count(bytes4 selector_) internal {
        ++calls[selector_];
        emit Action(selector_, successes, rejections);
    }
}
