// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation}
    from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from "../interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {IUniswapV4DetfMigrationStakedDETF as MigrationReceipt} from "../claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {IUniswapV4DetfMigrationBondNFTVault as Bonds} from "../bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";
import {IMigrationWeightedReceipt, IMigrationWeightedSynchronization} from "../legacy/IMigrationLegacyRecovery.sol";
import {IMigrationWeightedNft} from "../legacy/IMigrationLegacyNft.sol";
import {MigrationLegacyRecoveryLib as Legacy} from "../legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Real ordinary-SY original wallet and its native9 Q/C ghost ledger.
/// @dev Not a claimed-origin source wallet. No raw TokenStaking admission is implied.
// allow: SIZE_OK - Cohesive original-wallet/custody ledger; claims and recovery actions are separate.
abstract contract MigrationLegacyHandler is Test, IERC721Receiver {
    struct OriginalNft {
        address collection;
        uint256 id;
        address wallet;
        uint256 original;
        uint256 remaining;
        uint256 credit;
    }
    struct Funded {
        uint256 id;
        address wallet;
        uint256 principal;
        uint256 gons;
        uint256 start;
        uint256 claimed;
        bool retired;
    }
    Migration public parent;
    Recovery public recovery;
    Bonds public bonds;
    MigrationReceipt public receipt;
    bytes32 public constant ORIGIN = keccak256("phase24 ordinary SY canonical original");
    address public constant OTHER = address(0x2466);
    uint256 public constant Q0 = 8000;
    uint256 public remainingQ = Q0;
    uint256 public remainingC;
    uint256 public immutable C0;
    uint256 public delivered;
    uint256 public syInventory;
    uint256 public recoveryGons;
    uint256 public liquidInventory;
    uint256 public dtfInventory;
    uint256 public earlierInventory;
    uint256 public donatedDtf;
    uint256 public retainedDonation;
    uint256 public sourceClaims;
    uint256 public successes;
    uint256 public rejections;
    uint256 public callbacks;
    uint256 public rollbackWitnesses;
    uint256 internal baseSupply;
    uint256 internal baseBacking;
    uint256 internal baseBondGons;
    uint256 internal newGons;
    uint256 internal issued;
    uint256 internal unbookedDtf;
    uint256 internal k;
    bool internal rejectBond;
    bytes32 internal frozen;
    OriginalNft[2] internal nft;
    bool[2] internal consumed;
    bool[2] internal sourceBurned;
    Funded[] internal funded;
    event LegacyAction(bytes4 indexed action, uint256 successes, uint256 rejections);

    constructor(Migration m_, OriginalNft[2] memory n_, uint256 c_) {
        parent = m_; recovery = Recovery(address(m_));
        bonds = Bonds(m_.bondNftVault());
        receipt = MigrationReceipt(m_.rebasingClaimToken());
        nft = n_; C0 = c_; remainingC = c_;
        baseSupply = IERC20(address(m_)).totalSupply();
        baseBacking = IERC20(address(m_)).balanceOf(address(receipt));
        baseBondGons = receipt.gonsOf(address(bonds));
        k = receipt.stakingState().gonsPerUnit;
        frozen = keccak256(abi.encode(m_.migrationWeightedPricing()));
        // The base donates exactly 1 DTF before genesis, without selecting it for
        // bootstrap. All other initial DTF is the paid reserve's spendable residual,
        // not recovery inventory or an unsolicited/protected donation.
        unbookedDtf = 1 ether;
        assertEq(m_.migrationDonationInventory(IERC20(Legacy.DTF)), unbookedDtf);
        retainedDonation = IERC20(Legacy.DTF).balanceOf(address(m_)) - unbookedDtf;
        emit log_named_uint("initial protected DTF donation", unbookedDtf);
        emit log_named_uint("initial spendable protocol DTF residual", retainedDonation);
        IERC20(Legacy.WEIGHTED_SY).approve(address(m_), type(uint256).max);
    }

    function surrender(uint256 seed_) public {
        if (remainingQ == 0) {
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedSyQuantity.selector, 1, 0));
            parent.surrenderMigrationWeightedSy(ORIGIN, 1, 0, block.timestamp);
            ++rejections;
        } else {
            uint256 q_ = seed_ % remainingQ + 1;
            uint256 credit_ = q_ == remainingQ ? remainingC : Math.mulDiv(remainingC, q_, remainingQ);
            uint256 before_ = IERC20(Legacy.WEIGHTED_SY).balanceOf(address(parent));
            (uint256 id_, uint256 paid_) = parent.surrenderMigrationWeightedSy(ORIGIN, q_, credit_, block.timestamp);
            assertEq(paid_, credit_);
            assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(address(parent)) - before_, q_);
            remainingQ -= q_; remainingC -= credit_; delivered += credit_; syInventory += q_;
            _funded(id_, address(this), credit_);
            ++successes;
        }
        assertAll();
        emit LegacyAction(this.surrender.selector, successes, rejections);
    }

    function failedIssuance() public {
        if (remainingQ == 0) { surrender(0); return; }
        bytes32 before_ = economicState();
        rejectBond = true;
        vm.expectCall(address(receipt), abi.encodeWithSignature(
            "exchangeIn(address,uint256,address,uint256,address,bool,uint256)", address(parent), remainingC,
            address(receipt), remainingC, address(bonds), false, block.timestamp
        ));
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(this)));
        parent.surrenderMigrationWeightedSy(ORIGIN, remainingQ, remainingC, block.timestamp);
        rejectBond = false;
        assertEq(economicState(), before_, "late receiver failure restores custody credit backing and NFT");
        ++rejections; ++rollbackWitnesses;
        assertAll();
    }

    function transferAndReject() public {
        bytes32 before_ = economicState();
        if (remainingQ != 0) {
            assertTrue(IERC20(Legacy.WEIGHTED_SY).transfer(OTHER, 1));
            vm.prank(OTHER);
            vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalWeightedSyWallet.selector, OTHER, address(this)));
            parent.surrenderMigrationWeightedSy(ORIGIN, 1, 0, block.timestamp);
            vm.prank(OTHER);
            assertTrue(IERC20(Legacy.WEIGHTED_SY).transfer(address(this), 1));
            successes += 2;
        } else {
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedSyEntitlement.selector, bytes32("absent")));
            parent.surrenderMigrationWeightedSy(bytes32("absent"), 1, 0, block.timestamp);
        }
        ++rejections;
        assertEq(economicState(), before_);
        assertAll();
    }

    /// @notice Guaranteed absent-record rejection, independent of the remaining SY domain.
    function missingRecord() public {
        bytes32 before_ = economicState();
        vm.expectRevert(abi.encodeWithSelector(Migration.InvalidWeightedSyEntitlement.selector, bytes32("absent")));
        parent.surrenderMigrationWeightedSy(bytes32("absent"), 1, 0, block.timestamp);
        assertEq(economicState(), before_);
        ++rejections;
        for (uint256 i_; i_ < 2; ++i_) {
            address collection_ = nft[i_].collection;
            uint256 id_ = i_ == 0 ? 26 : 4;
            address holder_ = IERC721(collection_).ownerOf(id_);
            address approval_ = IERC721(collection_).getApproved(id_);
            assertNotEq(holder_, address(0), "real unconfigured NFT");
            vm.prank(holder_);
            vm.expectRevert(abi.encodeWithSelector(Migration.InvalidNftEntitlement.selector, collection_, id_));
            parent.surrenderMigrationNft(collection_, id_, 0, block.timestamp);
            assertEq(IERC721(collection_).ownerOf(id_), holder_);
            assertEq(IERC721(collection_).getApproved(id_), approval_);
            assertFalse(parent.nftSurrender(collection_, id_).consumed);
            assertEq(economicState(), before_);
            ++rejections;
        }
        assertAll();
    }

    /// @notice Both historical originals must regain actual ownership and approve the proxy.
    function rejectNftControl(uint256 which_) public {
        uint256 i_ = which_ % 2;
        if (consumed[i_]) { takeNft(i_); return; }
        OriginalNft memory n_ = nft[i_];
        assertEq(IERC721(n_.collection).getApproved(n_.id), address(0), "actual transferred-back approval");
        bytes32 before_ = economicState();
        vm.prank(n_.wallet);
        vm.expectRevert(abi.encodeWithSelector(
            IERC721Errors.ERC721InsufficientApproval.selector, address(parent), n_.id));
        parent.surrenderMigrationNft(n_.collection, n_.id, 0, block.timestamp);
        assertEq(economicState(), before_);
        assertEq(IERC721(n_.collection).ownerOf(n_.id), n_.wallet);
        vm.prank(n_.wallet); IERC721(n_.collection).transferFrom(n_.wallet, OTHER, n_.id);
        vm.prank(OTHER);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotOriginalNftWallet.selector, OTHER, n_.wallet));
        parent.surrenderMigrationNft(n_.collection, n_.id, 0, block.timestamp);
        vm.prank(n_.wallet);
        vm.expectRevert(abi.encodeWithSelector(Migration.NotNftHolder.selector, n_.wallet, OTHER));
        parent.surrenderMigrationNft(n_.collection, n_.id, 0, block.timestamp);
        assertEq(economicState(), before_);
        assertEq(IERC721(n_.collection).ownerOf(n_.id), OTHER);
        assertFalse(parent.nftSurrender(n_.collection, n_.id).consumed);
        vm.prank(OTHER); IERC721(n_.collection).transferFrom(OTHER, n_.wallet, n_.id);
        rejections += 3; successes += 2;
        assertAll();
    }

    function takeNft(uint256 which_) public {
        uint256 i_ = which_ % 2;
        OriginalNft memory n_ = nft[i_];
        if (consumed[i_]) {
            vm.prank(n_.wallet);
            vm.expectRevert(abi.encodeWithSelector(Migration.NftAlreadyConsumed.selector, n_.collection, n_.id));
            parent.surrenderMigrationNft(n_.collection, n_.id, 0, block.timestamp);
            ++rejections;
        } else {
            uint256 expected_ = Math.mulDiv(n_.credit, n_.remaining, n_.original);
            vm.startPrank(n_.wallet);
            IERC721(n_.collection).approve(address(parent), n_.id);
            (uint256 id_, uint256 paid_) = parent.surrenderMigrationNft(n_.collection, n_.id, expected_, block.timestamp);
            vm.stopPrank();
            assertEq(paid_, expected_);
            consumed[i_] = true;
            _funded(id_, n_.wallet, paid_);
            ++successes;
        }
        assertAll();
    }

    function _funded(uint256 id_, address wallet_, uint256 principal_) internal {
        uint256 gons_ = principal_ * k;
        funded.push(Funded(id_, wallet_, principal_, gons_, block.timestamp, 0, false));
        issued += principal_;
        newGons += gons_;
    }

    /// @notice Callback mutations are exercised only by the ordinary-SY contract original.
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        require(msg.sender == address(bonds), "actual bond child only");
        (bool ok_, bytes memory reason_) = address(parent).call(abi.encodeCall(
            Migration.surrenderMigrationWeightedSy, (ORIGIN, 1, 0, block.timestamp)));
        assertFalse(ok_);
        assertEq(reason_, abi.encodeWithSignature("IsLocked()"));
        (ok_, reason_) = address(parent).call(abi.encodeCall(Allocation.activateMigration, ()));
        assertFalse(ok_);
        assertEq(reason_, abi.encodeWithSignature("NoTargetFor(bytes4)", Allocation.activateMigration.selector));
        ++callbacks;
        return rejectBond ? bytes4(0) : IERC721Receiver.onERC721Received.selector;
    }

    function economicState() public view returns (bytes32) {
        return keccak256(abi.encode(parent.weightedSySurrender(ORIGIN),
            IERC20(Legacy.WEIGHTED_SY).balanceOf(address(this)),
            IERC20(Legacy.WEIGHTED_SY).balanceOf(address(parent)),
            IERC20(Legacy.WEIGHTED_SY).allowance(address(this), address(parent)),
            receipt.stakingState(), receipt.gonsOf(address(bonds)), IERC20(address(parent)).totalSupply(),
            IERC20(address(parent)).balanceOf(address(receipt)), IERC721(address(bonds)).balanceOf(address(this)),
            recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY)));
    }

    function assertAll() public view {
        Migration.WeightedSySurrender memory s_ = parent.weightedSySurrender(ORIGIN);
        assertEq(s_.remainingUnits, remainingQ); assertEq(s_.consumedUnits, Q0 - remainingQ);
        assertEq(s_.remainingCredit, remainingC); assertEq(s_.deliveredCredit, delivered);
        assertEq(delivered + remainingC, C0);
        assertEq(parent.weightedSyEntitlement(ORIGIN).original.originalWallet, address(this));
        assertEq(parent.weightedSyEntitlement(ORIGIN).credit, C0);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(address(this)), remainingQ);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(OTHER), 0);
        assertEq(IERC20(Legacy.WEIGHTED_SY).balanceOf(address(parent)), syInventory);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_SY), syInventory);
        assertEq(recovery.migrationRecoveryGons(), recoveryGons);
        assertEq(IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).gonsOf(address(parent)), recoveryGons);
        assertEq(recovery.migrationRecoveryInventory(Legacy.WEIGHTED_DETF), liquidInventory);
        assertEq(IERC20(Legacy.WEIGHTED_DETF).balanceOf(address(parent)), liquidInventory);
        assertEq(recovery.migrationRecoveryInventory(Legacy.DTF), dtfInventory);
        assertEq(IERC20(Legacy.DTF).balanceOf(address(parent)), unbookedDtf + dtfInventory + retainedDonation);
        assertEq(recovery.migrationRecoveryInventory(Legacy.EARLIER_DETF), earlierInventory);
        assertEq(IERC20(address(parent)).totalSupply(), baseSupply + issued);
        assertEq(IERC20(address(parent)).balanceOf(address(receipt)), baseBacking + issued);
        assertEq(receipt.stakingState().gonsPerUnit, k);
        assertEq(receipt.gonsOf(address(bonds)), baseBondGons + newGons);
        assertEq(keccak256(abi.encode(parent.migrationWeightedPricing())), frozen);
        for (uint256 i_; i_ < funded.length; ++i_) {
            Funded memory f_ = funded[i_];
            if (f_.retired) {
                assertEq(IERC721(address(bonds)).ownerOf(f_.id), address(0));
                continue;
            }
            assertEq(bonds.positionOf(f_.id).principal, f_.principal);
            assertEq(bonds.positionOf(f_.id).claimedPrincipal, f_.claimed);
            assertEq(bonds.positionOf(f_.id).stakingGons, f_.gons);
            assertEq(bonds.positionOf(f_.id).startTimestamp, f_.start);
            assertEq(bonds.positionOf(f_.id).vestingDuration, 90 days);
            assertEq(IERC721(address(bonds)).ownerOf(f_.id), f_.wallet);
            assertGe(f_.gons / k, f_.principal - f_.claimed);
            if (block.timestamp < f_.start + 90 days) {
                assertEq(f_.claimed, 0);
                assertEq(bonds.previewClaim(f_.id).principalDue, 0);
            }
        }
        for (uint256 i_; i_ < 2; ++i_) {
            address expectedOwner_ = sourceBurned[i_] ? address(0)
                : consumed[i_] ? address(parent) : nft[i_].wallet;
            assertEq(IERC721(nft[i_].collection).ownerOf(nft[i_].id), expectedOwner_,
                "actual persistent legacy NFT custody");
            Migration.NftSurrender memory n_ = parent.nftSurrender(nft[i_].collection, nft[i_].id);
            assertEq(n_.consumed, consumed[i_]);
            if (consumed[i_]) {
                assertEq(n_.remainingUnits, nft[i_].remaining);
                assertEq(n_.credit, Math.mulDiv(nft[i_].credit, nft[i_].remaining, nft[i_].original));
                assertEq(parent.nftCustody(nft[i_].collection, nft[i_].id).collection, nft[i_].collection);
            }
        }
    }
}
